#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DNS_GUARD="$ROOT_DIR/files/etc/init.d/tailscale-dns-mode-guard"
MAGICDNS_DEFAULTS="$ROOT_DIR/files/etc/uci-defaults/98-tailscale-magicdns-forward"

[ -f "$DNS_GUARD" ] || {
	echo "missing tailscale DNS mode guard init script"
	exit 1
}

[ "$(git ls-files --stage -- "$DNS_GUARD" | awk '{print $1}')" = "100755" ] || {
	echo "tailscale DNS mode guard init script is not marked executable"
	exit 1
}

grep -q '^START=99$' "$DNS_GUARD" || {
	echo "DNS mode guard must run after mosdns START=75"
	exit 1
}

for expected in \
	"/headscale.jmsu.top/223.5.5.5" \
	"/headplane.jmsu.top/223.5.5.5" \
	"/derper.jmsu.top/223.5.5.5" \
	"/hs.jmsu.top/100.100.100.100@tailscale0" \
	"dhcp.@dnsmasq[0].rebind_domain" \
	"hs.jmsu.top" \
	"/var/etc/mosdns.json" \
	"forward_tailscale_magicdns" \
	"bind_to_device" \
	"tailscale0" \
	"jq"; do
	grep -F "$expected" "$DNS_GUARD" >/dev/null || {
		echo "DNS mode guard missing compatibility marker: $expected"
		exit 1
	}
done

grep -q '/etc/init.d/tailscale-dns-mode-guard enable' "$MAGICDNS_DEFAULTS" || {
	echo "MagicDNS defaults do not enable DNS mode guard"
	exit 1
}

grep -q '/etc/init.d/tailscale-dns-mode-guard start' "$MAGICDNS_DEFAULTS" || {
	echo "MagicDNS defaults do not start DNS mode guard"
	exit 1
}

grep -Fq '/headplane.jmsu.top/223.5.5.5' "$MAGICDNS_DEFAULTS" || {
	echo "MagicDNS defaults do not pin headplane.jmsu.top to direct DNS"
	exit 1
}

echo "tailscale DNS mode guard test passed"
