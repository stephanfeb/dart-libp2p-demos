# Demos

Complete, runnable programs built on the Dart libp2p stack. Each demo is a
small Dart package with its own `pubspec.yaml` that depends on the published
packages, so you can copy one out as the start of your own app.

| Demo | What it shows |
|---|---|
| [Internet chat](internet-chat.md) | Peers behind NAT routers find each other through a DHT, chat over GossipSub, and hole-punch direct connections, with one public relay as the only server. Runs on one machine, across simulated NATs in Docker, or over the internet. |

Each demo also has a Docker Compose setup, so you can watch it work across
several networks on one machine.

The demos live in the
[dart-libp2p-demos](https://github.com/stephanfeb/dart-libp2p-demos)
repository.
