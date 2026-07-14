#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_SH="$ROOT_DIR/Scripts/Packages.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
HANDLES_SH="$ROOT_DIR/Scripts/Handles.sh"
TAILSCALE_CONFIG="$ROOT_DIR/files/etc/config/tailscale"
TAILSCALE_SETTINGS_ENABLE="$ROOT_DIR/files/etc/uci-defaults/94-tailscale-settings-enable"
TAILSCALE_UCI_DEFAULTS="$ROOT_DIR/files/etc/uci-defaults/96-tailscale-uci-fallback"
TAILSCALE_DNS_GUARD="$ROOT_DIR/files/etc/init.d/tailscale-accept-dns-guard"
TAILSCALE_NIKKI_GUARD="$ROOT_DIR/files/etc/uci-defaults/97-tailscale-nikki-guard"
TAILSCALE_NIKKI_BOOT_GUARD="$ROOT_DIR/files/etc/init.d/tailscale-nikki-guard"
TAILSCALE_MAGICDNS_FORWARD="$ROOT_DIR/files/etc/uci-defaults/98-tailscale-magicdns-forward"
TAILSCALE_QUAD100_HEALTH="$ROOT_DIR/files/etc/init.d/tailscale-quad100-health"
TAILSCALE_QUAD100_HEALTH_DEFAULTS="$ROOT_DIR/files/etc/uci-defaults/99-tailscale-quad100-health"

[ -f "$PACKAGES_SH" ] || { echo "missing Packages.sh"; exit 1; }
[ -f "$WORKFLOW" ] || { echo "missing WRT-CORE workflow"; exit 1; }
[ -f "$HANDLES_SH" ] || { echo "missing Handles.sh"; exit 1; }
[ -f "$TAILSCALE_CONFIG" ] || { echo "missing default tailscale UCI config overlay"; exit 1; }
[ ! -e "$TAILSCALE_SETTINGS_ENABLE" ] || {
  echo "tailscale settings enable defaults script should be absent so tailscale-settings stays opt-in"
  exit 1
}
[ -f "$TAILSCALE_UCI_DEFAULTS" ] || { echo "missing tailscale UCI fallback defaults script"; exit 1; }
[ -f "$TAILSCALE_DNS_GUARD" ] || { echo "missing tailscale DNS guard init script"; exit 1; }
[ -f "$TAILSCALE_NIKKI_GUARD" ] || { echo "missing Nikki tailscale compatibility guard"; exit 1; }
[ -f "$TAILSCALE_NIKKI_BOOT_GUARD" ] || { echo "missing Nikki tailscale boot guard init script"; exit 1; }
[ -f "$TAILSCALE_MAGICDNS_FORWARD" ] || { echo "missing tailscale MagicDNS forwarding defaults script"; exit 1; }
[ -f "$TAILSCALE_QUAD100_HEALTH" ] || { echo "missing tailscale Quad100 health init script"; exit 1; }
[ -f "$TAILSCALE_QUAD100_HEALTH_DEFAULTS" ] || { echo "missing tailscale Quad100 health defaults script"; exit 1; }
[ "$(git ls-files --stage -- "$TAILSCALE_NIKKI_BOOT_GUARD" | awk '{print $1}')" = "100755" ] || {
  echo "Nikki tailscale boot guard init script is not marked executable"
  exit 1
}
[ "$(git ls-files --stage -- "$TAILSCALE_QUAD100_HEALTH" | awk '{print $1}')" = "100755" ] || {
  echo "tailscale Quad100 health init script is not marked executable"
  exit 1
}

grep -q 'UPDATE_PACKAGE "luci-app-tailscale-community" "hotwa/luci-app-tailscale-community" "main" "pkg"' "$PACKAGES_SH" || {
  echo "Packages.sh does not pull luci-app-tailscale-community from the hotwa fork main branch"
  exit 1
}

grep -q 'rm -f luci-app-tailscale-community/root/etc/config/tailscale' "$PACKAGES_SH" || {
  echo "Packages.sh does not remove the luci-app-tailscale-community packaged /etc/config/tailscale that conflicts with tailscale"
  exit 1
}

grep -q 'rm -f luci-app-tailscale-community/root/etc/init.d/tailscale' "$PACKAGES_SH" || {
  echo "Packages.sh does not remove the luci-app-tailscale-community packaged /etc/init.d/tailscale that conflicts with tailscale"
  exit 1
}

grep -q 'CONFIG_PACKAGE_tailscale=y' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not verify tailscale remains enabled after defconfig"
  exit 1
}

grep -q 'CONFIG_PACKAGE_luci-app-tailscale-community=y' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not verify luci-app-tailscale-community remains enabled after defconfig"
  exit 1
}

grep -q 'for test_file in ./tests/test_\*.sh; do' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not execute repository smoke tests"
  exit 1
}

if grep -q 'sed -i '\''/\\/files/d'\'' \$TS_FILE' "$HANDLES_SH"; then
  echo "Handles.sh still strips tailscale package files, which removes /etc/config/tailscale at runtime"
  exit 1
fi

tr -d '\r' < "$TAILSCALE_CONFIG" | grep -q "^config settings 'settings'$" || {
  echo "default tailscale UCI config overlay is missing the settings section"
  exit 1
}

tr -d '\r' < "$TAILSCALE_CONFIG" | grep -q "^	option fw_mode 'nftables'$" || {
  echo "default tailscale UCI config overlay is missing fw_mode nftables"
  exit 1
}

tr -d '\r' < "$TAILSCALE_CONFIG" | grep -q "^	option disable_magic_dns '1'$" || {
  echo "default tailscale UCI config overlay is missing disable_magic_dns"
  exit 1
}

tr -d '\r' < "$TAILSCALE_CONFIG" | grep -q "^config lan_bypass_host$" || {
  echo "default tailscale UCI config overlay is missing the LAN bypass host section"
  exit 1
}

tr -d '\r' < "$TAILSCALE_CONFIG" | grep -q "^	option enabled '0'$" || {
  echo "default tailscale UCI config overlay is missing the disabled LAN bypass host template"
  exit 1
}

if tr -d '\r' < "$TAILSCALE_CONFIG" | grep -q "^	list ip '192.168.11.2'$"; then
  echo "default tailscale UCI config overlay still hardcodes a LAN bypass sample IP"
  exit 1
fi

grep -q '\[ -f "/etc/config/tailscale" \] && exit 0' "$TAILSCALE_UCI_DEFAULTS" || {
  echo "tailscale UCI fallback defaults script does not preserve existing config"
  exit 1
}

grep -q "config settings 'settings'" "$TAILSCALE_UCI_DEFAULTS" || {
  echo "tailscale UCI fallback defaults script does not recreate the settings section"
  exit 1
}

grep -q "option disable_magic_dns '1'" "$TAILSCALE_UCI_DEFAULTS" || {
  echo "tailscale UCI fallback defaults script does not recreate disable_magic_dns"
  exit 1
}

grep -q "config lan_bypass_host" "$TAILSCALE_UCI_DEFAULTS" || {
  echo "tailscale UCI fallback defaults script does not recreate the LAN bypass host template"
  exit 1
}

if grep -q "list ip '192.168.11.2'" "$TAILSCALE_UCI_DEFAULTS"; then
  echo "tailscale UCI fallback defaults script still hardcodes a LAN bypass sample IP"
  exit 1
fi

grep -q '/etc/config/tailscale' "$TAILSCALE_DNS_GUARD" || {
  echo "tailscale DNS guard does not ensure the runtime UCI config exists"
  exit 1
}

grep -q '/etc/config/nikki' "$TAILSCALE_NIKKI_GUARD" || {
  echo "Nikki tailscale compatibility guard does not gate itself on Nikki being installed"
  exit 1
}

grep -q 'nikki.@router_access_control\[0\].enabled' "$TAILSCALE_NIKKI_GUARD" || {
  echo "Nikki tailscale compatibility guard does not verify the router access control section exists"
  exit 1
}

grep -q '/etc/init.d/tailscale-nikki-guard enable' "$TAILSCALE_NIKKI_GUARD" || {
  echo "Nikki tailscale compatibility guard does not enable the boot guard"
  exit 1
}

grep -q '100.64.0.0/10' "$TAILSCALE_NIKKI_GUARD" || {
  echo "Nikki tailscale compatibility guard does not preserve the CGNAT range"
  exit 1
}

grep -q 'fd7a:115c:a1e0::/48' "$TAILSCALE_NIKKI_GUARD" || {
  echo "Nikki tailscale compatibility guard does not preserve the Tailscale ULA range"
  exit 1
}

grep -q 'services/mosdns' "$TAILSCALE_NIKKI_GUARD" || {
  echo "Nikki tailscale compatibility guard does not preserve the mosdns router access bypass"
  exit 1
}

grep -q 'services/dnsmasq' "$TAILSCALE_NIKKI_GUARD" || {
  echo "Nikki tailscale compatibility guard does not preserve the dnsmasq router access bypass"
  exit 1
}

grep -q 'services/tailscale' "$TAILSCALE_NIKKI_GUARD" || {
  echo "Nikki tailscale compatibility guard does not preserve the tailscale router access bypass"
  exit 1
}

grep -q '/etc/nikki/ucode/hijack.ut' "$TAILSCALE_NIKKI_BOOT_GUARD" || {
  echo "Nikki tailscale boot guard does not patch the Nikki DNS hijack template"
  exit 1
}

grep -q 'chain router_dns_hijack' "$TAILSCALE_NIKKI_BOOT_GUARD" || {
  echo "Nikki tailscale boot guard does not target router_dns_hijack"
  exit 1
}

grep -q 'ip daddr \$TAILSCALE_IPV4_RANGE return' "$TAILSCALE_NIKKI_BOOT_GUARD" || {
  echo "Nikki tailscale boot guard does not add an IPv4 Tailscale DNS bypass"
  exit 1
}

grep -q 'ip6 daddr \$TAILSCALE_IPV6_RANGE return' "$TAILSCALE_NIKKI_BOOT_GUARD" || {
  echo "Nikki tailscale boot guard does not add an IPv6 Tailscale DNS bypass"
  exit 1
}

grep -q 'udp://100.100.100.100:53#tailscale0' "$TAILSCALE_NIKKI_BOOT_GUARD" || {
  echo "Nikki tailscale boot guard does not bind Quad100 DNS lookups to tailscale0"
  exit 1
}

grep -q '/etc/init.d/tailscale-nikki-guard start' "$TAILSCALE_NIKKI_GUARD" || {
  echo "Nikki tailscale compatibility guard does not start the boot guard during first boot"
  exit 1
}

grep -q '/headscale.jmsu.top/223.5.5.5' "$TAILSCALE_MAGICDNS_FORWARD" || {
  echo "MagicDNS forwarding defaults script does not pin headscale.jmsu.top to 223.5.5.5"
  exit 1
}

grep -q '/derper.jmsu.top/223.5.5.5' "$TAILSCALE_MAGICDNS_FORWARD" || {
  echo "MagicDNS forwarding defaults script does not pin derper.jmsu.top to 223.5.5.5"
  exit 1
}

grep -q '/hs.jmsu.top/100.100.100.100@tailscale0' "$TAILSCALE_MAGICDNS_FORWARD" || {
  echo "MagicDNS forwarding defaults script does not forward hs.jmsu.top to 100.100.100.100"
  exit 1
}

grep -q '100.100.100.100' "$TAILSCALE_QUAD100_HEALTH" || {
  echo "tailscale Quad100 health guard does not target Quad100"
  exit 1
}

grep -q '/etc/init.d/tailscale-quad100-health enable' "$TAILSCALE_QUAD100_HEALTH_DEFAULTS" || {
  echo "tailscale Quad100 health defaults script does not enable the guard"
  exit 1
}

echo "tailscale package guards test passed"
