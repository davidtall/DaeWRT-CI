#!/bin/sh
set -u

KEEPALIVE_URL="${KEEPALIVE_URL:-}"
KEEPALIVE_INTERVAL="${KEEPALIVE_INTERVAL:-300}"

if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
    echo 1 > /proc/sys/net/ipv4/ip_forward \
        || { echo "failed to enable IPv4 forwarding (NET_ADMIN required)" >&2; exit 1; }
fi

/usr/local/bin/corplink-rs "$@" &
corplink_pid=$!

# SNAT traffic forwarded from the Docker bridge into the VPN tunnel.
iptables -t nat -A POSTROUTING -o corplink -j MASQUERADE

cleanup() {
    kill -TERM "$corplink_pid" 2>/dev/null || true
    wait "$corplink_pid" 2>/dev/null || true
}
trap cleanup INT TERM

if [ -n "$KEEPALIVE_URL" ]; then
    (
        # Give corplink time to establish the tunnel before the first request.
        sleep 20
        while kill -0 "$corplink_pid" 2>/dev/null; do
            curl --fail --silent --show-error \
                --connect-timeout 10 \
                --max-time 30 \
                "$KEEPALIVE_URL" >/dev/null || true
            sleep "$KEEPALIVE_INTERVAL"
        done
    ) &
    keepalive_pid=$!
fi

wait "$corplink_pid"
status=$?

if [ -n "${keepalive_pid:-}" ]; then
    kill "$keepalive_pid" 2>/dev/null || true
fi

exit "$status"
