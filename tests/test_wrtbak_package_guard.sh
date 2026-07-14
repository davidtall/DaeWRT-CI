#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERAL="$ROOT_DIR/Config/GENERAL.txt"
PACKAGES_SH="$ROOT_DIR/Scripts/Packages.sh"
WRT_CORE="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
QCA_WORKFLOWS=(
	"$ROOT_DIR/.github/workflows/QCA-6.12-LiBwrt.yml"
	"$ROOT_DIR/.github/workflows/QCA-6.12-VIKINGYFY.yml"
	"$ROOT_DIR/.github/workflows/QCA-6.18-VIKINGYFY.yml"
)

[ -f "$GENERAL" ] || { echo "missing GENERAL config"; exit 1; }
[ -f "$PACKAGES_SH" ] || { echo "missing Packages.sh"; exit 1; }
[ -f "$WRT_CORE" ] || { echo "missing WRT-CORE workflow"; exit 1; }

grep -q '^CONFIG_PACKAGE_luci-app-wrtbak=y$' "$GENERAL" || {
	echo "GENERAL config does not enable luci-app-wrtbak"
	exit 1
}

grep -Fq 'WRTBAK_PACKAGE_BRANCH=main' "$PACKAGES_SH" || {
	echo "Packages.sh does not use the stable wrtbak main branch as its fetch base"
	exit 1
}

grep -Fq 'WRTBAK_PACKAGE_COMMIT=338492873bbc07af5cbfa7aa19d84e3f39215b93' "$PACKAGES_SH" || {
	echo "Packages.sh does not pin the reviewed wrtbak commit"
	exit 1
}

grep -Fq 'UPDATE_PACKAGE "luci-app-wrtbak" "hotwa/luci-app-wrtbak" "$WRTBAK_PACKAGE_BRANCH" "" "" "$WRTBAK_PACKAGE_COMMIT"' "$PACKAGES_SH" || {
	echo "Packages.sh does not checkout the pinned wrtbak commit"
	exit 1
}

grep -q 'CONFIG_PACKAGE_luci-app-wrtbak=y' "$WRT_CORE" || {
	echo "WRT-CORE does not verify luci-app-wrtbak remains enabled after defconfig"
	exit 1
}

grep -Fq 'WRTBAK_R2_PREFIX' "$WRT_CORE"
grep -Fq 'Scripts/WrtbakR2Config.sh' "$WRT_CORE"
grep -Fq 'Scripts/PrivateFirmwareGuard.sh' "$WRT_CORE"
grep -Fq "if: env.WRT_PRIVATE_BUILD != 'true'" "$WRT_CORE"

for workflow in "${QCA_WORKFLOWS[@]}"; do
	grep -Fq 'WRTBAK_DEVICE_ALIAS:' "$workflow" || {
		echo "$(basename "$workflow") missing WRTBAK_DEVICE_ALIAS input"
		exit 1
	}
	grep -Fq 'WRTBAK_PROXY_PROFILE:' "$workflow" || {
		echo "$(basename "$workflow") missing WRTBAK_PROXY_PROFILE input"
		exit 1
	}
	grep -Fq "WRTBAK_DEVICE_ALIAS: \${{ inputs.WRTBAK_DEVICE_ALIAS || '' }}" "$workflow" || {
		echo "$(basename "$workflow") does not pass WRTBAK_DEVICE_ALIAS into WRT-CORE"
		exit 1
	}
	grep -Fq "WRTBAK_PROXY_PROFILE: \${{ inputs.WRTBAK_PROXY_PROFILE || 'auto' }}" "$workflow" || {
		echo "$(basename "$workflow") does not pass WRTBAK_PROXY_PROFILE into WRT-CORE"
		exit 1
	}
done

echo "wrtbak package wiring checks passed"
