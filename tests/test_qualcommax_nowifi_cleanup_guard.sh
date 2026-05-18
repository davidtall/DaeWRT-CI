#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTIONS_SH="$ROOT_DIR/Scripts/function.sh"

[ -f "$FUNCTIONS_SH" ] || { echo "missing function.sh"; exit 1; }

grep -q '\[\[ "\$WRT_CONFIG" == \*"NOWIFI"\* || "\$WRT_CONFIG" == \*"WIFI-NO"\* \]\]' "$FUNCTIONS_SH" || {
	echo "function.sh does not trigger qualcommax Wi-Fi cleanup for WIFI-NO configs"
	exit 1
}

for token in ath11k-firmware ipq-wifi kmod-ath11k kmod-mac80211 kmod-cfg80211 wpad- hostapd-; do
	grep -q "local wifi_pkg_pattern=.*${token}" "$FUNCTIONS_SH" || {
		echo "function.sh no longer strips ${token} during no-Wi-Fi builds"
		exit 1
	}
done

grep -q 'kmod-qca-nss-drv-wifi-meshmgr' "$FUNCTIONS_SH" || {
	echo "function.sh no longer strips kmod-qca-nss-drv-wifi-meshmgr during no-Wi-Fi builds"
	exit 1
}

echo "qualcommax no-wifi cleanup guard test passed"
