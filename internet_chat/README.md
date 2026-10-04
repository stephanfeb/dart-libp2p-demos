# internet_chat

A chat between dart_libp2p peers over the internet. One public node is both
the relay and the DHT bootstrap node. Peers behind NAT reserve a slot on the
relay, find each other through the DHT, chat over GossipSub, and hole-punch
direct connections with DCUtR.

The full guide, with how it works and how to run the relay on a server, is
[doc/internet-chat.md](../doc/internet-chat.md).

## Quick start

```sh
dart pub get

# Terminal 1: the relay. Note one of the addresses it prints.
dart run bin/internet_chat.dart relay

# Terminals 2 and 3: two peers.
dart run bin/internet_chat.dart peer --nick alice --key alice.key --relay <relay address>
dart run bin/internet_chat.dart peer --nick bob --key bob.key --relay <relay address>
```

Type a line to send it. `/peers` shows each connection and whether it is
direct or relayed.

## Across simulated NATs

```sh
docker compose -f docker/compose.yml up --build
NAT_TYPE=symmetric docker compose -f docker/compose.yml up --build
```

The first run ends with a direct connection through two cone NATs. The
second one stays on the relay, because hole punching cannot get through
symmetric NATs.
