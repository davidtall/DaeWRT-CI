#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/Config/IPQ60XX-RE-CS-07-NOWIFI.txt"

[ -f "$CONFIG" ] || { echo "missing RE-CS-07 config"; exit 1; }
grep -qx 'CONFIG_TARGET_qualcommax=y' "$CONFIG"
grep -qx 'CONFIG_TARGET_qualcommax_ipq60xx=y' "$CONFIG"
grep -qx 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-07=y' "$CONFIG"

[ "$(grep -Ec '^CONFIG_TARGET_DEVICE_.*=y$' "$CONFIG")" -eq 1 ] || {
	echo "RE-CS-07 config must enable exactly one device"
	exit 1
}
for package in gre luci-proto-gre ip-full luci-app-wrtbak vm103-failover; do
	grep -qx "CONFIG_PACKAGE_${package}=y" "$CONFIG"
done
for package in hostapd-common iw iwinfo kmod-ath kmod-ath11k kmod-cfg80211 kmod-mac80211 wifi-scripts wireless-regdb wpad-openssl; do
	grep -qx "# CONFIG_PACKAGE_${package} is not set" "$CONFIG"
done
echo "RE-CS-07 config guards passed"
