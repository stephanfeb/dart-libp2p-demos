import 'dart:async';
import 'dart:io';

import 'package:dart_libp2p/dart_libp2p.dart';
import 'package:dart_libp2p_kad_dht/dart_libp2p_kad_dht.dart';
import 'package:dart_libp2p_pubsub/dart_libp2p_pubsub.dart';

import 'host.dart';
import 'identity.dart';
import 'room.dart';
import 'shutdown.dart';

/// GossipSub settings for this demo. The router builds its mesh once per
/// heartbeat, and dart_libp2p_pubsub uses `fanoutTTL` as the heartbeat
/// interval, so a short one lets a new peer join the mesh within seconds.
final gossipParams = GossipSubParams(fanoutTTL: const Duration(seconds: 5));

/// Runs the public node: a Circuit Relay v2 relay, a DHT server that peers
/// bootstrap from, and a GossipSub member of [rooms], so that chat messages
/// still flow through it when two peers cannot connect to each other.
Future<void> runRelay({
  required String keyFile,
  required int port,
  required List<MultiAddr> announce,
  required List<String> rooms,
  String? addrFile,
}) async {
  // Remove addresses left by an earlier run, so that a script waiting for
  // the file does not read them before this relay is listening.
  if (addrFile != null && await File(addrFile).exists()) {
    await File(addrFile).delete();
  }

  final identity = await loadOrCreateIdentity(keyFile);
  final host = await createHost(
    identity: identity,
    relay: true,
    port: port,
    announce: announce,
  );

  // Start the DHT before the host, so that Identify advertises the DHT
  // protocol from the first connection on.
  final dht = IpfsDHTv2(
    host: host,
    providerStore: MemoryProviderStore(),
    options: DHTOptions(mode: DHTMode.server),
  );
  await dht.start();
  await host.start();

  final pubsub = PubSub(host, GossipSubRouter(params: gossipParams));
  await pubsub.start();
  for (final room in rooms) {
    ChatRoom.join(pubsub, room, host.id);
  }

  print('Relay running. Peer ID: ${host.id.toBase58()}');
  final relayAddrs = [
    for (final a in host.addrs.where((a) => !a.hasProtocol('p2p-circuit')))
      '$a/p2p/${host.id.toBase58()}',
  ];
  print('Peers can use any of these addresses as --relay:');
  for (final a in relayAddrs) {
    print('  $a');
  }
  if (addrFile != null) {
    await File(addrFile).writeAsString('${relayAddrs.join('\n')}\n');
  }
  print('Rooms carried over GossipSub: ${rooms.join(', ')}');

  var known = <PeerId>{};
  final watch = Timer.periodic(const Duration(seconds: 5), (_) {
    final now = host.network.peers.toSet();
    for (final p in now.difference(known)) {
      print('+ ${p.toBase58()} connected (${now.length} peers)');
    }
    for (final p in known.difference(now)) {
      print('- ${p.toBase58()} disconnected (${now.length} peers)');
    }
    known = now;
  });

  await shutdownSignal();
  print('Shutting down...');
  watch.cancel();
  await pubsub.stop();
  await dht.close();
  await host.close();
}
