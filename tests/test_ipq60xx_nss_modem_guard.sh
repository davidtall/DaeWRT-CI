#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERAL_CONFIG="$ROOT_DIR/Config/GENERAL.txt"
FUNCTIONS_SH="$ROOT_DIR/Scripts/function.sh"

[ -f "$GENERAL_CONFIG" ] || { echo "missing GENERAL.txt"; exit 1; }
[ -f "$FUNCTIONS_SH" ] || { echo "missing function.sh"; exit 1; }

grep -q 'CONFIG_PACKAGE_kmod-qca-nss-ecm=y' "$FUNCTIONS_SH" || {
	echo "expected NSS ECM acceleration to remain enabled in function.sh"
	exit 1
}

for symbol in \
	CONFIG_PACKAGE_kmod-usb-net-qmi-wwan \
	CONFIG_PACKAGE_kmod-usb-net-qmi-wwan-fibocom \
	CONFIG_PACKAGE_kmod-usb-net-qmi-wwan-quectel \
	CONFIG_PACKAGE_luci-app-qmodem \
	CONFIG_PACKAGE_luci-app-qmodem_INCLUDE_ndisc6 \
	CONFIG_PACKAGE_luci-app-qmodem_INCLUDE_vendor-qmi-wwan \
	CONFIG_PACKAGE_luci-app-qmodem_USE_TOM_CUSTOMIZED_QUECTEL_CM \
	CONFIG_PACKAGE_luci-proto-mbim \
	CONFIG_PACKAGE_luci-proto-qmi \
	CONFIG_PACKAGE_qmodem \
	CONFIG_PACKAGE_uqmi \
	CONFIG_PACKAGE_umbim
do
	if grep -q "^${symbol}=y$" "$GENERAL_CONFIG"; then
		echo "unsafe modem symbol still enabled with NSS ECM: ${symbol}"
		exit 1
	fi
	if grep -q "^${symbol}=y$" "$FUNCTIONS_SH"; then
		echo "unsafe modem symbol still emitted by function.sh: ${symbol}"
		exit 1
	fi
done

echo "ipq60xx NSS modem guard test passed"
