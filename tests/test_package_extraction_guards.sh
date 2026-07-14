#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_SH="$ROOT_DIR/Scripts/Packages.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"

[ -f "$PACKAGES_SH" ] || { echo "missing Packages.sh"; exit 1; }
[ -f "$WORKFLOW" ] || { echo "missing WRT-CORE workflow"; exit 1; }

if grep -q 'cp -rf {} ./' "$PACKAGES_SH"; then
  echo "Packages.sh still extracts pkg repositories directly into package/, which deletes packages when repo and package names match"
  exit 1
fi

grep -q "CONFIG_PACKAGE_tailscale=y" "$WORKFLOW" || {
  echo "WRT-CORE.yml does not verify tailscale remains enabled after defconfig"
  exit 1
}

grep -q "CONFIG_PACKAGE_luci-app-tailscale-community=y" "$WORKFLOW" || {
  echo "WRT-CORE.yml does not verify luci-app-tailscale-community remains enabled after defconfig"
  exit 1
}

echo "package extraction guards test passed"
