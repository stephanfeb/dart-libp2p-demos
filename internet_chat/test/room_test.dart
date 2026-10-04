import 'package:internet_chat/internet_chat.dart';
import 'package:test/test.dart';

void main() {
  test('the rendezvous key is a CIDv0, whose bytes are a sha2-256 multihash', () {
    final bytes = rendezvousKey('lobby').toBytes();
    // 0x12 = sha2-256, 0x20 = 32-byte digest: what go-libp2p keys providers by.
    expect(bytes.sublist(0, 2), [0x12, 0x20]);
    expect(bytes, hasLength(34));
  });

  test('rooms get different rendezvous keys and topics', () {
    expect(rendezvousKey('a').toString(), isNot(rendezvousKey('b').toString()));
    expect(roomTopic('a'), '/internet-chat/1.0.0/room/a');
  });
}
