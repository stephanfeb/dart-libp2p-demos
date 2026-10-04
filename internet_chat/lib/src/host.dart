import 'package:dart_libp2p/config/config.dart';
import 'package:dart_libp2p/dart_libp2p.dart' hide Option;
import 'package:dart_libp2p/p2p/transport/connection_manager.dart';
import 'package:dart_libp2p/p2p/transport/tcp_transport.dart';
import 'package:dart_libp2p/p2p/transport/udx_transport.dart';

/// The user agent this demo reports through Identify.
const userAgent = 'internet-chat/0.1.0';

/// Creates (but does not start) a libp2p host that listens on UDX and TCP.
///
/// UDX runs over UDP, which is what hole punching needs. TCP is there for
/// networks that block UDP. Both listen on [port]; 0 picks a free port.
///
/// A [relay] host runs the Circuit Relay v2 service and declares itself
/// publicly reachable, since the relay service starts only on a host that
/// knows it is public. Every other host is a NAT'd peer: it dials
/// [relayServers] on start, reserves a slot on them with AutoRelay so other
/// peers can reach it through the relay, and upgrades relayed connections to
/// direct ones with DCUtR hole punching.
///
/// [announce] adds addresses the host cannot see on its own interfaces, such
/// as the public IP of a cloud VM whose interface has a private address.
Future<Host> createHost({
  required KeyPair identity,
  required bool relay,
  int port = 0,
  List<MultiAddr> announce = const [],
  List<String> relayServers = const [],
}) async {
  final connManager = ConnectionManager();
  final options = <Option>[
    Libp2p.identity(identity),
    Libp2p.connManager(connManager),
    Libp2p.transport(UDXTransport(connManager: connManager)),
    Libp2p.transport(TCPTransport(
      resourceManager: NullResourceManager(),
      connManager: connManager,
    )),
    Libp2p.listenAddrs([
      MultiAddr('/ip4/0.0.0.0/udp/$port/udx'),
      MultiAddr('/ip4/0.0.0.0/tcp/$port'),
    ]),
    Libp2p.userAgent(userAgent),
    Libp2p.identifyUserAgent(userAgent),
    Libp2p.addrsFactory((addrs) => _advertised(addrs, announce)),
    Libp2p.holePunching(true),
    if (relay) ...[
      Libp2p.relay(true),
      Libp2p.forceReachability(Reachability.public),
    ] else ...[
      Libp2p.autoRelay(true),
      Libp2p.relayServers(relayServers),
      // A peer learns its public address from what other peers observe.
      // By default an address counts only after 4 peers report it, but a
      // peer that knows only its relay has 1 observer. Hole punching needs
      // the public address, so accept the relay's observation.
      Libp2p.observedAddrActivationThreshold(1),
    ],
  ];
  return Libp2p.new_(options);
}

/// The addresses the host tells other peers about: its own, without loopback
/// and unspecified (0.0.0.0) addresses, plus the [announce] addresses.
List<MultiAddr> _advertised(List<MultiAddr> addrs, List<MultiAddr> announce) {
  final result = addrs.where((a) {
    if (a.isLoopback()) return false;
    final ip4 = a.valueForProtocol('ip4');
    final ip6 = a.valueForProtocol('ip6');
    return ip4 != '0.0.0.0' && ip6 != '::';
  }).toList();
  for (final a in announce) {
    if (!result.any((r) => r.toString() == a.toString())) {
      result.add(a);
    }
  }
  return result;
}

/// Whether [conn] is a connection through a relay, not a direct one.
bool isRelayed(Conn conn) => conn.remoteMultiaddr.hasProtocol('p2p-circuit');
