#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDLES="$ROOT_DIR/Scripts/Handles.sh"

[ -f "$HANDLES" ] || { echo "missing Handles.sh"; exit 1; }

grep -q 'PROCD_MAKEFILE="../package/system/procd/Makefile"' "$HANDLES" || {
	echo "Handles.sh is missing procd Makefile fallback path"
	exit 1
}

grep -q 'PKG_SOURCE_URL:=https://github.com/openwrt/procd.git' "$HANDLES" || {
	echo "Handles.sh does not switch procd source URL to GitHub mirror"
	exit 1
}

echo "procd source fallback guard test passed"
