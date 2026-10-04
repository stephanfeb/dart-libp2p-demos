import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_libp2p/dart_libp2p.dart';

/// Loads the node's Ed25519 identity from [path], or creates one there.
///
/// The file holds the 32-byte private key seed as hex. A node that keeps its
/// key file keeps its peer ID across restarts, which a relay needs: peers
/// dial it by an address that contains its peer ID.
///
/// The seed is stored instead of a marshalled libp2p key because
/// `Ed25519PrivateKey.marshal` in dart_libp2p 4.0.x does not write the
/// private key bytes, so a marshalled key cannot be loaded again.
Future<KeyPair> loadOrCreateIdentity(String path) async {
  final file = File(path);
  if (await file.exists()) {
    final hex = (await file.readAsString()).trim();
    final seed = _fromHex(hex);
    if (seed.length != 32) {
      throw FormatException('$path must hold a 32-byte seed as 64 hex digits');
    }
    return generateEd25519KeyPairFromSeed(seed);
  }

  final random = Random.secure();
  final seed = Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
  await file.parent.create(recursive: true);
  await file.writeAsString('${_toHex(seed)}\n');
  if (!Platform.isWindows) {
    await Process.run('chmod', ['600', path]);
  }
  return generateEd25519KeyPairFromSeed(seed);
}

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _fromHex(String hex) {
  if (hex.length.isOdd) {
    throw FormatException('odd number of hex digits');
  }
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}
