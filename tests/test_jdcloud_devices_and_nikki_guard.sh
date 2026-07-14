#!/bin/bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GENERAL="$ROOT_DIR/Config/GENERAL.txt"
NOWIFI_CONFIG="$ROOT_DIR/Config/IPQ60XX-WIFI-NO.txt"
WIFI_CONFIG="$ROOT_DIR/Config/IPQ60XX-WIFI-YES.txt"

failures=0

if [ ! -f "$GENERAL" ]; then
	echo "missing GENERAL config"
	failures=$((failures + 1))
elif ! grep -q '^CONFIG_PACKAGE_luci-app-nikki=y$' "$GENERAL"; then
	echo "GENERAL config does not keep luci-app-nikki enabled"
	failures=$((failures + 1))
fi

if [ ! -f "$NOWIFI_CONFIG" ]; then
	echo "missing IPQ60XX-WIFI-NO config"
	failures=$((failures + 1))
fi

if [ ! -f "$WIFI_CONFIG" ]; then
	echo "missing IPQ60XX-WIFI-YES config"
	failures=$((failures + 1))
fi

for device in jdcloud_re-cs-02 jdcloud_re-cs-07 jdcloud_re-ss-01; do
	if [ -f "$NOWIFI_CONFIG" ] && ! grep -q "^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_${device}=y$" "$NOWIFI_CONFIG"; then
		echo "IPQ60XX-WIFI-NO does not keep ${device}"
		failures=$((failures + 1))
	fi
done

for device in jdcloud_re-cs-02 jdcloud_re-ss-01; do
	if [ -f "$WIFI_CONFIG" ] && ! grep -q "^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_${device}=y$" "$WIFI_CONFIG"; then
		echo "IPQ60XX-WIFI-YES does not keep ${device}"
		failures=$((failures + 1))
	fi
done

if [ "$failures" -ne 0 ]; then
	exit 1
fi

echo "jdcloud devices and Nikki guard test passed"
