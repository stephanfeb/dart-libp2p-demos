# The internet_chat binary, for the relay and for the peers.
# Build context: the internet_chat directory (see compose.yml).

FROM dart:stable AS build
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get
COPY bin/ bin/
COPY lib/ lib/
RUN dart pub get --offline \
    && mkdir -p /out \
    && dart compile exe bin/internet_chat.dart -o /out/internet_chat

FROM debian:bookworm-slim
# iproute2: a peer behind the simulated NAT routes the "internet" subnet
# through its NAT gateway (see node-entrypoint.sh).
RUN apt-get update \
    && apt-get install -y --no-install-recommends iproute2 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /out/internet_chat /usr/local/bin/internet_chat
COPY docker/node-entrypoint.sh /usr/local/bin/node-entrypoint.sh
RUN chmod +x /usr/local/bin/node-entrypoint.sh
ENTRYPOINT ["node-entrypoint.sh"]
