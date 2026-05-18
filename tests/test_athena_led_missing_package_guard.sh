#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTIONS_SH="$ROOT_DIR/Scripts/function.sh"
CONFIG_TEST="$ROOT_DIR/Config/TEST.txt"
PACKAGES_SH="$ROOT_DIR/Scripts/Packages.sh"

[ -f "$FUNCTIONS_SH" ] || { echo "missing function.sh"; exit 1; }
[ -f "$CONFIG_TEST" ] || { echo "missing TEST.txt"; exit 1; }
[ -f "$PACKAGES_SH" ] || { echo "missing Packages.sh"; exit 1; }

if grep -q 'haipengno1/luci-app-athena-led' "$PACKAGES_SH"; then
	echo "Packages.sh still overrides the source tree athena-led package with haipengno1"
	exit 1
fi

grep -q '^UPDATE_PACKAGE "luci-app-athena-led" "NONGFAH/luci-app-athena-led" "main"$' "$PACKAGES_SH" || {
	echo "Packages.sh does not pin luci-app-athena-led to the known-working NONGFAH package"
	exit 1
}

grep -q '^CONFIG_TARGET_DEVICE_PACKAGES_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=".*luci-app-athena-led' "$CONFIG_TEST" || {
	echo "TEST config does not keep luci-app-athena-led scoped to jdcloud_re-cs-02"
	exit 1
}

if grep -q '^CONFIG_PACKAGE_luci-app-athena-led=[ym]' "$CONFIG_TEST"; then
	echo "TEST config globally selects luci-app-athena-led instead of scoping it to jdcloud_re-cs-02"
	exit 1
fi

if grep -q 'luci-i18n-athena-led-zh-cn' "$CONFIG_TEST"; then
	echo "TEST config still references missing standalone athena-led i18n package"
	exit 1
fi

grep -q "find ./package ./feeds .*luci-app-athena-led/Makefile" "$FUNCTIONS_SH" || {
	echo "function.sh does not check whether luci-app-athena-led exists before keeping it"
	exit 1
}

grep -q 'luci-i18n-athena-led-zh-cn' "$FUNCTIONS_SH" || {
	echo "function.sh does not strip the missing standalone athena-led i18n package"
	exit 1
}

echo "athena-led device package guard test passed"
