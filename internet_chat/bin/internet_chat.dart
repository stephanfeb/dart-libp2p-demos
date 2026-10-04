import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_libp2p/dart_libp2p.dart';
import 'package:internet_chat/internet_chat.dart';
import 'package:logging/logging.dart';

ArgParser _relayParser() => ArgParser()
  ..addOption('key', defaultsTo: 'relay.key', help: 'Identity file. Created if missing.')
  ..addOption('port', defaultsTo: '4001', help: 'UDP (UDX) and TCP port to listen on.')
  ..addMultiOption('announce',
      help: 'Extra address to advertise, such as the public IP of a cloud VM: '
          '/ip4/203.0.113.7/udp/4001/udx. Repeat for each address.')
  ..addMultiOption('room', defaultsTo: ['lobby'], help: 'Rooms to carry over GossipSub.')
  ..addOption('addr-file',
      help: 'Also write the relay addresses to this file, one per line, for scripts.');

ArgParser _peerParser() => ArgParser()
  ..addMultiOption('relay',
      help: 'Relay address with its peer ID, as the relay prints it. Repeat for each relay.')
  ..addOption('key', defaultsTo: 'peer.key', help: 'Identity file. Created if missing.')
  ..addOption('nick', defaultsTo: Platform.environment['USER'] ?? 'anon')
  ..addOption('room', defaultsTo: 'lobby')
  ..addOption('say', help: 'Text to send on a timer, for runs without a terminal.')
  ..addOption('say-every', defaultsTo: '15', help: 'Seconds between --say messages.');

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('log', defaultsTo: 'OFF', help: 'Log level for all libraries: OFF, SEVERE, WARNING, INFO, FINE.')
    ..addMultiOption('debug',
        help: 'Log this logger at FINE, whatever --log says. Repeat for more. '
            'For example: p2p-holepunch, RelayFinder, CircuitV2Client, identify.')
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addCommand('relay', _relayParser())
    ..addCommand('peer', _peerParser());

  final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    _usage(parser, e.message);
    exit(64);
  }
  final command = results.command;
  if (results['help'] as bool || command == null) {
    _usage(parser);
    exit(command == null && !(results['help'] as bool) ? 64 : 0);
  }

  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.LEVELS.firstWhere(
    (l) => l.name == (results['log'] as String).toUpperCase(),
    orElse: () => Level.OFF,
  );
  for (final name in results['debug'] as List<String>) {
    Logger(name).level = Level.FINE;
  }
  Logger.root.onRecord.listen((r) {
    stderr.writeln('${r.level.name} ${r.loggerName}: ${r.message}');
  });

  switch (command.name) {
    case 'relay':
      await runRelay(
        keyFile: command['key'] as String,
        port: int.parse(command['port'] as String),
        announce: (command['announce'] as List<String>).map(MultiAddr.new).toList(),
        rooms: command['room'] as List<String>,
        addrFile: command['addr-file'] as String?,
      );
    case 'peer':
      final relays = command['relay'] as List<String>;
      if (relays.isEmpty) {
        _usage(parser, 'peer needs at least one --relay address');
        exit(64);
      }
      await runPeer(
        keyFile: command['key'] as String,
        relays: relays,
        nick: command['nick'] as String,
        room: command['room'] as String,
        say: command['say'] as String?,
        sayEvery: Duration(seconds: int.parse(command['say-every'] as String)),
      );
  }
  exit(0);
}

void _usage(ArgParser parser, [String? error]) {
  if (error != null) stderr.writeln('Error: $error\n');
  stderr.writeln('''
Usage:
  internet_chat relay [--port 4001] [--announce <multiaddr>] [--key relay.key]
  internet_chat peer --relay <relay multiaddr> [--nick alice] [--room lobby]

Global options:
${parser.usage}

relay options:
${parser.commands['relay']!.usage}

peer options:
${parser.commands['peer']!.usage}''');
}
