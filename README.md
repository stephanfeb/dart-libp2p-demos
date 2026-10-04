# dart-libp2p demos

Complete, runnable programs built on
[dart_libp2p](https://pub.dev/packages/dart_libp2p) and the packages around
it. Each demo is a standalone Dart package that depends on the published
packages, so you can copy one out as the start of your own app.

| Demo | What it shows |
|---|---|
| [`internet_chat`](internet_chat/) | A chat between peers behind NAT: a public relay that is also the DHT bootstrap node, DHT rendezvous, GossipSub, and DCUtR hole punching to direct connections. Includes a Docker setup with simulated NAT routers. |

The guides are in [`doc/`](doc/) and on
[cryptopeer.net](https://cryptopeer.net/demos/).

## Developing against local checkouts

Each demo builds against the packages on pub.dev. To try it with local
checkouts of the libraries, create a `pubspec_overrides.yaml` (git-ignored)
in the demo's directory:

```yaml
dependency_overrides:
  dart_libp2p:
    path: ../../dart-libp2p
  dart_libp2p_kad_dht:
    path: ../../dart-libp2p-kad-dht
  dart_libp2p_pubsub:
    path: ../../dart-libp2p-pubsub
```

The Docker images build from pub.dev and ignore that file.

## License

MIT. See [LICENSE](LICENSE).
