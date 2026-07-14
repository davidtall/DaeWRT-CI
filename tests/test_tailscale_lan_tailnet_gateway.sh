#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAILSCALE_CONFIG="$ROOT_DIR/files/etc/config/tailscale"
FALLBACK="$ROOT_DIR/files/etc/uci-defaults/96-tailscale-uci-fallback"
GATEWAY_INIT="$ROOT_DIR/files/etc/init.d/tailscale-lan-tailnet"
GATEWAY_DEFAULTS="$ROOT_DIR/files/etc/uci-defaults/91-tailscale-lan-tailnet"
MAGICDNS_DEFAULTS="$ROOT_DIR/files/etc/uci-defaults/98-tailscale-magicdns-forward"
NIKKI_BOOT_GUARD="$ROOT_DIR/files/etc/init.d/tailscale-nikki-guard"

for file in "$TAILSCALE_CONFIG" "$FALLBACK" "$GATEWAY_INIT" "$GATEWAY_DEFAULTS" "$MAGICDNS_DEFAULTS" "$NIKKI_BOOT_GUARD"; do
	[ -f "$file" ] || {
		echo "missing LAN-to-tailnet gateway file: $file"
		exit 1
	}
done

[ "$(git ls-files --stage -- "$GATEWAY_INIT" | awk '{print $1}')" = "100755" ] || {
	echo "tailscale LAN-to-tailnet init script is not marked executable"
	exit 1
}

[ "$(git ls-files --stage -- "$GATEWAY_DEFAULTS" | awk '{print $1}')" = "100755" ] || {
	echo "tailscale LAN-to-tailnet defaults script is not marked executable"
	exit 1
}

tr -d '\r' <"$TAILSCALE_CONFIG" | grep "^config lan_to_tailnet 'lan_to_tailnet'$" >/dev/null || {
	echo "tailscale config missing lan_to_tailnet section"
	exit 1
}

tr -d '\r' <"$TAILSCALE_CONFIG" | grep "^	option enabled '0'$" >/dev/null || {
	echo "lan_to_tailnet must be disabled by default"
	exit 1
}

for expected in \
	"option cidr4 '100.64.0.0/10'" \
	"option cidr6 'fd7a:115c:a1e0::/48'" \
	"option dns_domain 'hs.jmsu.top'" \
	"option magicdns '100.100.100.100'" \
	"option masq '1'"; do
	grep -q "$expected" "$TAILSCALE_CONFIG" || {
		echo "tailscale config missing $expected"
		exit 1
	}
	grep -q "$expected" "$FALLBACK" || {
		echo "tailscale UCI fallback missing $expected"
		exit 1
	}
done

grep -q '/etc/init.d/tailscale-lan-tailnet enable' "$GATEWAY_DEFAULTS" || {
	echo "defaults script does not enable tailscale-lan-tailnet"
	exit 1
}

grep -q '/etc/init.d/tailscale-lan-tailnet start' "$GATEWAY_DEFAULTS" || {
	echo "defaults script does not start tailscale-lan-tailnet"
	exit 1
}

grep -q 'config_load tailscale' "$GATEWAY_INIT" || {
	echo "gateway script does not load tailscale UCI"
	exit 1
}

grep -q "config_get enabled.*lan_to_tailnet" "$GATEWAY_INIT" || {
	echo "gateway script does not gate on lan_to_tailnet enabled"
	exit 1
}

grep -q 'ensure_default_option "tailscale.\$SECTION.enabled" "0"' "$GATEWAY_INIT" || {
	echo "gateway script must preserve an operator-enabled LAN-to-tailnet switch"
	exit 1
}

if grep -q 'ensure_option "tailscale.\$SECTION.enabled" "0"' "$GATEWAY_INIT"; then
	echo "gateway script must not reset lan_to_tailnet.enabled on every start"
	exit 1
fi

for expected in \
	"firewall.tailscale.forward='REJECT'" \
	"firewall.tailscale.input='ACCEPT'" \
	"firewall.tailscale.output='ACCEPT'" \
	"firewall.tailscale.masq" \
	"src='lan'" \
	"dest='tailscale'" \
	"tailscale_lan_to_tailnet='1'"; do
	grep -q "$expected" "$GATEWAY_INIT" || {
		echo "gateway script missing firewall guard: $expected"
		exit 1
	}
done

if grep -q "src='tailscale'.*dest='lan'" "$GATEWAY_INIT"; then
	echo "gateway script must not add tailnet-to-LAN forwarding"
	exit 1
fi

for expected in \
	"/hs.jmsu.top/100.100.100.100@tailscale0" \
	"dhcp.@dnsmasq[0].rebind_domain" \
	"hs.jmsu.top" \
	"100.100.100.100@tailscale0"; do
	grep -F "$expected" "$GATEWAY_INIT" >/dev/null || {
		echo "gateway script missing DNS guard: $expected"
		exit 1
	}
done

for expected in \
	"/hs.jmsu.top/100.100.100.100@tailscale0" \
	"dhcp.@dnsmasq[0].rebind_domain"; do
	grep -F "$expected" "$MAGICDNS_DEFAULTS" >/dev/null || {
		echo "MagicDNS defaults missing $expected"
		exit 1
	}
done

for expected in \
	"/etc/mosdns/tailscale-magicdns.yaml" \
	"qname suffix:hs.jmsu.top" \
	"forward_tailscale_magicdns" \
	"bind_to_device" \
	"tailscale0" \
	"/var/etc/mosdns.json" \
	"jq"; do
	grep -q "$expected" "$GATEWAY_INIT" || {
		echo "gateway script missing mosdns compatibility guard: $expected"
		exit 1
	}
done

grep -q '/etc/init.d/tailscale-nikki-guard start' "$GATEWAY_INIT" || {
	echo "gateway script does not re-apply Nikki tailnet bypass guard"
	exit 1
}

grep -q '100.64.0.0/10' "$NIKKI_BOOT_GUARD" || {
	echo "Nikki guard no longer preserves tailnet CIDR"
	exit 1
}

grep -q 'udp://100.100.100.100:53#tailscale0' "$NIKKI_BOOT_GUARD" || {
	echo "Nikki guard no longer binds Quad100 to tailscale0"
	exit 1
}

echo "tailscale LAN-to-tailnet gateway test passed"
