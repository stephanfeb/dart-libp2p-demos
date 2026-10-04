import 'dart:io';

import 'package:dart_libp2p/dart_libp2p.dart';
import 'package:internet_chat/internet_chat.dart';
import 'package:test/test.dart';

void main() {
  test('an identity file keeps the peer ID across restarts', () async {
    final dir = await Directory.systemTemp.createTemp('internet_chat');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/node.key';

    final first = await loadOrCreateIdentity(path);
    final second = await loadOrCreateIdentity(path);

    expect(PeerId.fromPublicKey(second.publicKey), PeerId.fromPublicKey(first.publicKey));
    expect((await File(path).readAsString()).trim(), hasLength(64));
  });

  test('a malformed identity file is rejected', () async {
    final dir = await Directory.systemTemp.createTemp('internet_chat');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/node.key';
    await File(path).writeAsString('abcd\n');

    expect(loadOrCreateIdentity(path), throwsFormatException);
  });
}
