#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_SH="$ROOT_DIR/Scripts/Packages.sh"
NIKKI_GUARD="$ROOT_DIR/files/etc/uci-defaults/97-tailscale-nikki-guard"
TAILSCALE_GUARD_TEST="$ROOT_DIR/tests/test_tailscale_package_guards.sh"

[ -f "$PACKAGES_SH" ] || { echo "missing Packages.sh"; exit 1; }
[ -f "$NIKKI_GUARD" ] || { echo "missing Nikki tailscale guard script"; exit 1; }
[ -f "$TAILSCALE_GUARD_TEST" ] || { echo "missing tailscale package guard test"; exit 1; }

grep -q 'UPDATE_PACKAGE "luci-app-tailscale-community" "hotwa/luci-app-tailscale-community" "main" "pkg"' "$PACKAGES_SH" || {
	echo "Packages.sh does not pull luci-app-tailscale-community from the hotwa fork main branch"
	exit 1
}

grep -q '100.64.0.0/10' "$NIKKI_GUARD" || {
	echo "Nikki guard does not preserve the Tailscale CGNAT range"
	exit 1
}

grep -q 'fd7a:115c:a1e0::/48' "$NIKKI_GUARD" || {
	echo "Nikki guard does not preserve the Tailscale ULA range"
	exit 1
}

grep -q "/etc/config/nikki" "$NIKKI_GUARD" || {
	echo "Nikki guard does not gate itself on Nikki being installed"
	exit 1
}

grep -q 'nikki.@router_access_control\[0\].enabled' "$NIKKI_GUARD" || {
	echo "Nikki guard does not gate itself on the router access control section"
	exit 1
}

grep -q 'services/mosdns' "$NIKKI_GUARD" || {
	echo "Nikki guard does not preserve the mosdns router access bypass"
	exit 1
}

grep -q 'services/dnsmasq' "$NIKKI_GUARD" || {
	echo "Nikki guard does not preserve the dnsmasq router access bypass"
	exit 1
}

grep -q 'services/tailscale' "$NIKKI_GUARD" || {
	echo "Nikki guard does not preserve the tailscale router access bypass"
	exit 1
}

echo "tailscale upstream source and Nikki guard test passed"
