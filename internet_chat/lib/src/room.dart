import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_libp2p/dart_libp2p.dart' hide Subscription;
import 'package:dart_libp2p_pubsub/dart_libp2p_pubsub.dart';
import 'package:dcid/dcid.dart';

/// The GossipSub topic of the chat room [room].
String roomTopic(String room) => '/internet-chat/1.0.0/room/$room';

/// The DHT key that the members of [room] provide, so they can find each
/// other.
///
/// It is a CIDv0, whose bytes are exactly a sha2-256 multihash. go-libp2p's
/// DHT keys provider records by multihash, so a go peer that provides the
/// same multihash meets the Dart peers here.
CID rendezvousKey(String room) => CID.fromData(
      CID.V0,
      'dag-pb',
      Uint8List.fromList(utf8.encode('/internet-chat/1.0.0/rendezvous/$room')),
    );

/// A chat message as it travels over GossipSub: JSON with a nickname and a
/// text. The sender's peer ID comes from the signed GossipSub message itself.
class ChatMessage {
  ChatMessage({required this.from, required this.nick, required this.text});

  final PeerId from;
  final String nick;
  final String text;

  static Uint8List encode(String nick, String text) =>
      Uint8List.fromList(utf8.encode(jsonEncode({'nick': nick, 'text': text})));

  /// Decodes [message], or returns null for data that is not a chat message.
  static ChatMessage? decode(PubSubMessage message) {
    try {
      final json = jsonDecode(utf8.decode(message.data)) as Map<String, dynamic>;
      return ChatMessage(
        from: message.from,
        nick: json['nick'] as String,
        text: json['text'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

/// One joined chat room: GossipSub publishing and the messages of others.
class ChatRoom {
  ChatRoom._(this.name, this._pubsub, this._subscription, this._self) {
    _subscription.stream.listen((dynamic m) {
      if (m is! PubSubMessage || m.from == _self) return;
      final chat = ChatMessage.decode(m);
      if (chat == null) return;
      nicks[chat.from] = chat.nick;
      _messages.add(chat);
    });
  }

  /// Subscribes to the room's topic.
  static ChatRoom join(PubSub pubsub, String name, PeerId self) =>
      ChatRoom._(name, pubsub, pubsub.subscribe(roomTopic(name)), self);

  final String name;
  final PubSub _pubsub;
  final Subscription _subscription;
  final PeerId _self;
  final _messages = StreamController<ChatMessage>.broadcast();

  /// The last nickname seen from each peer.
  final Map<PeerId, String> nicks = {};

  /// Messages from other peers.
  Stream<ChatMessage> get messages => _messages.stream;

  Future<void> say(String nick, String text) =>
      _pubsub.publish(roomTopic(name), ChatMessage.encode(nick, text));

  /// A short, readable name for [peer].
  String nameOf(PeerId peer) {
    final id = peer.toBase58();
    final short = id.substring(id.length - 6);
    final nick = nicks[peer];
    return nick == null ? '…$short' : '$nick (…$short)';
  }
}
