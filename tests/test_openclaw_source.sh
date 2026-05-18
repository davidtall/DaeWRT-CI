#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_SH="$ROOT_DIR/Scripts/Packages.sh"

[ -f "$PACKAGES_SH" ] || { echo "missing Packages.sh"; exit 1; }

grep -q 'UPDATE_PACKAGE "openclaw" "hotwa/luci-app-openclaw" "main"' "$PACKAGES_SH" || {
  echo "openclaw source is not pinned to hotwa/luci-app-openclaw main"
  exit 1
}

echo "openclaw source test passed"
