#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOT_GUARD="$ROOT_DIR/files/etc/init.d/tailscale-nikki-guard"

[ -f "$BOOT_GUARD" ] || {
	echo "missing Nikki tailscale boot guard init script"
	exit 1
}

grep -q '/etc/config/nikki' "$BOOT_GUARD" || {
	echo "boot guard does not gate itself on Nikki being installed"
	exit 1
}

grep -q 'nikki.@router_access_control\[0\].enabled' "$BOOT_GUARD" || {
	echo "boot guard does not gate itself on the router access control section"
	exit 1
}

grep -q '100.64.0.0/10' "$BOOT_GUARD" || {
	echo "boot guard does not preserve the Tailscale CGNAT range"
	exit 1
}

grep -q 'fd7a:115c:a1e0::/48' "$BOOT_GUARD" || {
	echo "boot guard does not preserve the Tailscale ULA range"
	exit 1
}

grep -q 'services/mosdns' "$BOOT_GUARD" || {
	echo "boot guard does not preserve the mosdns router access bypass"
	exit 1
}

grep -q 'services/dnsmasq' "$BOOT_GUARD" || {
	echo "boot guard does not preserve the dnsmasq router access bypass"
	exit 1
}

grep -q 'services/tailscale' "$BOOT_GUARD" || {
	echo "boot guard does not preserve the tailscale router access bypass"
	exit 1
}

grep -q '/etc/nikki/ucode/hijack.ut' "$BOOT_GUARD" || {
	echo "boot guard does not patch the Nikki DNS hijack template"
	exit 1
}

grep -q 'chain router_dns_hijack' "$BOOT_GUARD" || {
	echo "boot guard does not target the router DNS hijack chain"
	exit 1
}

grep -q 'ip daddr \$TAILSCALE_IPV4_RANGE return' "$BOOT_GUARD" || {
	echo "boot guard does not add an IPv4 Tailscale DNS bypass rule"
	exit 1
}

grep -q 'ip6 daddr \$TAILSCALE_IPV6_RANGE return' "$BOOT_GUARD" || {
	echo "boot guard does not add an IPv6 Tailscale DNS bypass rule"
	exit 1
}

grep -q 'udp://100.100.100.100:53#tailscale0' "$BOOT_GUARD" || {
	echo "boot guard does not bind Quad100 DNS lookups to tailscale0"
	exit 1
}

grep -q 'current_profile_path()' "$BOOT_GUARD" || {
	echo "boot guard does not locate the active Nikki profile before patching DNS policy"
	exit 1
}

grep -q 'nft list table inet nikki' "$BOOT_GUARD" || {
	echo "boot guard does not verify the live Nikki nft table"
	exit 1
}

grep -q 'fd7a:115c:a1e0::/48' "$BOOT_GUARD" || {
	echo "boot guard does not check the live Tailscale ULA range"
	exit 1
}

grep -q 'config_load tailscale' "$BOOT_GUARD" || {
	echo "boot guard does not load tailscale UCI for LAN bypass hosts"
	exit 1
}

grep -q 'lan_bypass_host' "$BOOT_GUARD" || {
	echo "boot guard does not support tailscale LAN bypass host sections"
	exit 1
}

grep -q 'tailscale_managed' "$BOOT_GUARD" || {
	echo "boot guard does not mark managed Nikki LAN bypass sections"
	exit 1
}

grep -q 'local value="\$1"' "$BOOT_GUARD" || {
	echo "boot guard does not accept config_list_foreach values first for managed bypass copies"
	exit 1
}

grep -q 'local option="\$2"' "$BOOT_GUARD" || {
	echo "boot guard does not pass the destination option as the second append_bypass_value argument"
	exit 1
}

grep -Eq 'fd7a:115c:a1e0::/48\|fc00::/7|fc00::/7\|fd7a:115c:a1e0::/48' "$BOOT_GUARD" || {
	echo "boot guard does not accept a covering fc00::/7 runtime set for the Tailscale ULA range"
	exit 1
}

grep -q 'nft list chain inet nikki router_dns_hijack' "$BOOT_GUARD" || {
	echo "boot guard does not verify the live router DNS hijack chain"
	exit 1
}

echo "tailscale Nikki boot guard test passed"
