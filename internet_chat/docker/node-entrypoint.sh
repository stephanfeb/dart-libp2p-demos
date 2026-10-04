#!/bin/sh
# Starts internet_chat with the arguments given, after two optional steps:
#
# NAT_GATEWAY / PUBLIC_NET: route the simulated internet through the home
#   network's NAT gateway, as a home router would.
# RELAY_ADDR_FILE: wait until the relay has written its addresses there,
#   then pass each one as --relay.
set -e

if [ -n "$NAT_GATEWAY" ]; then
    ip route replace "$PUBLIC_NET" via "$NAT_GATEWAY"
fi

if [ -n "$RELAY_ADDR_FILE" ]; then
    echo "Waiting for the relay to write $RELAY_ADDR_FILE..."
    while [ ! -s "$RELAY_ADDR_FILE" ]; do sleep 0.5; done
    for addr in $(cat "$RELAY_ADDR_FILE"); do
        set -- "$@" --relay "$addr"
    done
fi

exec internet_chat "$@"
