#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOWIFI_CONFIG="$ROOT_DIR/Config/IPQ60XX-WIFI-NO.txt"
WIFI_CONFIG="$ROOT_DIR/Config/IPQ60XX-WIFI-YES.txt"
QCA_618_WORKFLOW="$ROOT_DIR/.github/workflows/QCA-6.18-VIKINGYFY.yml"

[ -f "$NOWIFI_CONFIG" ] || { echo "missing IPQ60XX-WIFI-NO config"; exit 1; }
[ -f "$WIFI_CONFIG" ] || { echo "missing IPQ60XX-WIFI-YES config"; exit 1; }

for config in "$NOWIFI_CONFIG" "$WIFI_CONFIG"; do
	if grep -q '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_link_nn6000-v1=y$' "$config"; then
		echo "$(basename "$config") still enables link_nn6000-v1"
		exit 1
	fi

	if grep -q '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_link_nn6000-v2=y$' "$config"; then
		echo "$(basename "$config") still enables link_nn6000-v2"
		exit 1
	fi
done

if [ -f "$QCA_618_WORKFLOW" ]; then
	grep -q 'CONFIG: \[IPQ60XX-WIFI-NO, IPQ60XX-WIFI-YES\]' "$QCA_618_WORKFLOW" || {
		echo "QCA-6.18 workflow does not use existing IPQ60XX config names"
		exit 1
	}

	if grep -q 'IPQ60XX-NOWIFI\|IPQ60XX-WIFI]' "$QCA_618_WORKFLOW"; then
		echo "QCA-6.18 workflow still references missing upstream config names"
		exit 1
	fi
fi

echo "ipq60xx link_nn6000 device exclusion test passed"
