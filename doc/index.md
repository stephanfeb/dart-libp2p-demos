# Demos

Complete, runnable programs that you can copy as the start of your own app.
Each one depends only on published packages: the Dart demos are small Dart
packages with their own `pubspec.yaml`, and the Ricochet demo is a Go program
in the go-ricochet module.

| Demo | What it shows |
|---|---|
| [Internet chat](internet-chat.md) | Peers behind NAT routers find each other through a DHT, chat over GossipSub, and hole-punch direct connections, with one public relay as the only server. Runs on one machine, across simulated NATs in Docker, or over the internet. |
| [Ricochet mailbox](https://cryptopeer.net/ricochet/mailbox/) | Messages for peers that are offline: a Go client stores end-to-end encrypted messages on a Ricochet server, and the recipient collects them later or gets them pushed. The code is in [go-ricochet](https://github.com/stephanfeb/go-ricochet/tree/main/examples/mailbox). |

Each demo also has a Docker Compose setup, so you can watch it work across
several networks on one machine.

The Dart demos live in the
[dart-libp2p-demos](https://github.com/stephanfeb/dart-libp2p-demos)
repository.
