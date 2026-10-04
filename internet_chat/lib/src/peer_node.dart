import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_libp2p/dart_libp2p.dart';
import 'package:dart_libp2p/p2p/host/autorelay/autorelay.dart';
import 'package:dart_libp2p_kad_dht/dart_libp2p_kad_dht.dart';
import 'package:dart_libp2p_pubsub/dart_libp2p_pubsub.dart';

import 'host.dart';
import 'identity.dart';
import 'relay_node.dart' show gossipParams;
import 'room.dart';
import 'shutdown.dart';

/// How often a peer announces itself under the room's rendezvous key. DHT
/// provider records expire, so the announcement is repeated.
const _provideInterval = Duration(minutes: 1);

/// How often a peer looks up the other members of its room.
const _findInterval = Duration(seconds: 10);

/// Runs a chat peer that may be behind NAT.
///
/// The peer connects to the [relays], reserves a relay slot so that others
/// can reach it, and bootstraps its DHT from the relays. It then provides
/// the room's rendezvous key in the DHT and looks up the other providers.
/// It dials each one through a relay, and DCUtR upgrades the relayed
/// connection to a direct one when the two NATs allow it. Chat messages go
/// over GossipSub.
///
/// Lines typed on stdin are sent to the room. With [say], the peer also
/// sends that text every [sayEvery], for runs without a terminal.
Future<void> runPeer({
  required String keyFile,
  required List<String> relays,
  required String nick,
  required String room,
  String? say,
  Duration sayEvery = const Duration(seconds: 15),
}) async {
  final identity = await loadOrCreateIdentity(keyFile);
  final host = await createHost(
    identity: identity,
    relay: false,
    relayServers: relays,
  );

  // A peer behind NAT cannot answer DHT queries, so it runs as a client.
  final dht = IpfsDHTv2(
    host: host,
    providerStore: MemoryProviderStore(),
    options: DHTOptions(
      mode: DHTMode.client,
      bootstrapPeers: relays.map(MultiAddr.new).toList(),
    ),
  );
  await dht.start();
  // Starting the host also dials the relays.
  await host.start();

  final pubsub = PubSub(host, GossipSubRouter(params: gossipParams));
  await pubsub.start();
  // Joining sends our subscription to the peers we are connected to by now,
  // which includes the relays.
  final chat = ChatRoom.join(pubsub, room, host.id);

  print('Peer ID: ${host.id.toBase58()}');
  print('Joined room "$room" as $nick. Type a message and press Enter.');
  print('Commands: /peers, /addrs, /quit');

  try {
    await dht.bootstrap();
  } catch (e) {
    print('! DHT bootstrap failed: $e');
  }

  final subscriptions = <StreamSubscription<dynamic>>[];
  final timers = <Timer>[];

  subscriptions.add(chat.messages.listen((m) {
    print('<${m.nick}> ${m.text}');
  }));

  subscriptions.add(host.eventBus
      .subscribe(EvtAutoRelayAddrsUpdated)
      .stream
      .listen((dynamic e) {
    if (e is! EvtAutoRelayAddrsUpdated) return;
    final viaRelay = e.advertisableAddrs.where((a) => a.hasProtocol('p2p-circuit'));
    if (viaRelay.isNotEmpty) {
      print('* Reachable through the relay at:');
      for (final a in viaRelay) {
        print('    $a');
      }
    }
  }));

  final relayIds = {
    for (final r in relays) AddrInfo.fromMultiaddr(MultiAddr(r)).id,
  };
  final rendezvous = rendezvousKey(room);
  final members = <PeerId>{};
  final dialing = <PeerId>{};

  Future<void> provide() async {
    try {
      await dht.provide(rendezvous, true);
    } catch (e) {
      print('! Could not announce in the DHT: $e');
    }
  }

  // Dials [peer] through every relay. The relayed connection is enough to
  // chat; the side that accepts it starts DCUtR to get a direct one.
  Future<void> dial(PeerId peer) async {
    if (!dialing.add(peer)) return;
    try {
      final viaRelays = [
        for (final r in relays) MultiAddr('$r/p2p-circuit/p2p/${peer.toBase58()}'),
      ];
      await host.connect(AddrInfo(peer, viaRelays));
      // GossipSub only tells the peers it is connected to about our
      // subscriptions when we subscribe, so tell this new one now.
      pubsub.announceSubscriptionsTo(peer);
    } catch (e) {
      // Usually the peer has no relay reservation yet. The next lookup
      // round tries again.
      print('! Could not reach ${chat.nameOf(peer)} through the relay yet; '
          'trying again in ${_findInterval.inSeconds}s');
    } finally {
      dialing.remove(peer);
    }
  }

  // Reconnects to relays that are down, such as one that started after this
  // peer or restarted. AutoRelay then reserves a slot on it again.
  Future<void> keepRelays() async {
    for (final r in relays) {
      final info = AddrInfo.fromMultiaddr(MultiAddr(r));
      if (host.network.connsToPeer(info.id).isNotEmpty) continue;
      try {
        await host.connect(info);
        pubsub.announceSubscriptionsTo(info.id);
        print('* Connected to the relay ${info.id.toBase58()}');
      } catch (e) {
        print('! Relay ${info.id.toBase58()} is unreachable: $e');
      }
    }
  }

  Future<void> find() async {
    await keepRelays();
    try {
      await for (final provider in dht.findProvidersAsync(rendezvous, 20)) {
        final peer = provider.id;
        if (peer == host.id || relayIds.contains(peer)) continue;
        if (members.add(peer)) {
          print('* Found ${chat.nameOf(peer)} in the DHT');
        }
        // Two peers that find each other at the same time would otherwise
        // dial each other at once. Each would then start a hole punch as
        // the side with the inbound relayed connection, and the two punches
        // would collide. So only the peer with the lower ID dials; the other
        // one waits for it.
        if (host.id.toBase58().compareTo(peer.toBase58()) < 0 &&
            host.network.connsToPeer(peer).isEmpty) {
          unawaited(dial(peer));
        }
      }
    } catch (e) {
      print('! DHT lookup failed: $e');
    }
  }

  await provide();
  await find();
  timers.add(Timer.periodic(_provideInterval, (_) => provide()));
  timers.add(Timer.periodic(_findInterval, (_) => find()));

  // Report each change in how we are connected to the other members.
  final state = <PeerId, String>{};
  timers.add(Timer.periodic(const Duration(seconds: 2), (_) {
    for (final peer in members) {
      final conns = host.network.connsToPeer(peer);
      final direct = conns.where((c) => !isRelayed(c)).toList();
      final now = conns.isEmpty
          ? 'none'
          : direct.isNotEmpty
              ? 'direct'
              : 'relayed';
      final before = state[peer] ?? 'none';
      if (now == before) continue;
      state[peer] = now;
      final name = chat.nameOf(peer);
      switch (now) {
        case 'direct':
          print('* Direct connection to $name: ${direct.first.remoteMultiaddr}');
        case 'relayed':
          print('* Connected to $name through the relay');
        default:
          print('* Lost the connection to $name');
      }
    }
  }));

  if (say != null) {
    var n = 0;
    timers.add(Timer.periodic(sayEvery, (_) {
      n++;
      chat.say(nick, '$say #$n').catchError((Object e) {
        print('! Send failed: $e');
      });
    }));
  }

  final quit = Completer<void>();
  subscriptions.add(stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) async {
    final text = line.trim();
    if (text.isEmpty) return;
    switch (text) {
      case '/quit':
        if (!quit.isCompleted) quit.complete();
      case '/addrs':
        for (final a in host.addrs) {
          print('  $a');
        }
      case '/peers':
        _printPeers(host, chat, relayIds);
      default:
        try {
          await chat.say(nick, text);
        } catch (e) {
          print('! Send failed: $e');
        }
    }
  }));

  await Future.any([quit.future, shutdownSignal()]);
  print('Leaving...');
  for (final t in timers) {
    t.cancel();
  }
  for (final s in subscriptions) {
    await s.cancel();
  }
  await pubsub.stop();
  await dht.close();
  await host.close();
}

void _printPeers(Host host, ChatRoom chat, Set<PeerId> relayIds) {
  final peers = host.network.peers;
  if (peers.isEmpty) {
    print('  (not connected to anyone)');
    return;
  }
  for (final peer in peers) {
    final role = relayIds.contains(peer) ? ' [relay]' : '';
    print('  ${chat.nameOf(peer)}$role');
    for (final c in host.network.connsToPeer(peer)) {
      final kind = isRelayed(c) ? 'relayed' : 'direct';
      print('      $kind  ${c.remoteMultiaddr}');
    }
  }
}
