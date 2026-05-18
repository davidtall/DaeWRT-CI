#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_SH="$ROOT_DIR/Scripts/Settings.sh"

[ -f "$SETTINGS_SH" ] || { echo "missing Settings.sh"; exit 1; }

grep -q 'CONFIG_PACKAGE_luci-app-ramfree=/d' "$SETTINGS_SH" || {
  echo "Settings.sh does not strip luci-app-ramfree from the generated .config"
  exit 1
}

grep -q 'CONFIG_PACKAGE_luci-app-ramfree is not set' "$SETTINGS_SH" || {
  echo "Settings.sh does not force luci-app-ramfree off after stripping"
  exit 1
}

echo "ramfree guard test passed"
