#!/bin/bash
set -euo pipefail

WRT_TREE="${1:-}"
WRT_SOURCE="${2:-}"
WRT_BRANCH="${3:-}"

if [ -z "$WRT_TREE" ] || [ -z "$WRT_SOURCE" ] || [ -z "$WRT_BRANCH" ]; then
	echo "usage: $0 <wrt-tree> <wrt-source> <wrt-branch>" >&2
	exit 1
fi

if [ "$WRT_SOURCE" != "davidtall/LiBwrt-openwrt-6.x" ] || [ "$WRT_BRANCH" != "k6.12-nss" ]; then
	exit 0
fi

PATCH_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/patches/libiwrt/999-fix-k612-net-device-cacheline-assert.patch"
PATCH_TARGET_DIR="$WRT_TREE/target/linux/qualcommax/patches-6.12"
PATCH_TARGET="$PATCH_TARGET_DIR/999-fix-k612-net-device-cacheline-assert.patch"

[ -f "$PATCH_SOURCE" ] || {
	echo "missing LiBwrt cacheline compatibility patch source: $PATCH_SOURCE" >&2
	exit 1
}

mkdir -p "$PATCH_TARGET_DIR"
cp -f "$PATCH_SOURCE" "$PATCH_TARGET"
echo "LiBwrt k6.12 cacheline compatibility patch injected: $PATCH_TARGET"
