#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERAL="$ROOT_DIR/Config/GENERAL.txt"
PACKAGES="$ROOT_DIR/Scripts/Packages.sh"
SETTINGS="$ROOT_DIR/Scripts/Settings.sh"

[ -f "$GENERAL" ] || { echo "missing GENERAL config"; exit 1; }
[ -f "$PACKAGES" ] || { echo "missing Packages.sh"; exit 1; }
[ -f "$SETTINGS" ] || { echo "missing Settings.sh"; exit 1; }

grep -q '^CONFIG_PACKAGE_luci-app-tailscale-community=y$' "$GENERAL" || {
  echo "GENERAL config does not enable luci-app-tailscale-community"
  exit 1
}

if grep -q '^CONFIG_PACKAGE_luci-app-tailscale=y$' "$GENERAL"; then
  echo "GENERAL config still enables luci-app-tailscale"
  exit 1
fi

grep -q '^CONFIG_PACKAGE_luci-app-dae=y$' "$GENERAL" || {
  echo "GENERAL config does not enable luci-app-dae"
  exit 1
}

grep -q '^CONFIG_PACKAGE_luci-app-daed=y$' "$GENERAL" || {
  echo "GENERAL config does not enable luci-app-daed"
  exit 1
}

grep -q '^UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "kix"$' "$PACKAGES" || {
  echo "Packages.sh does not align luci-app-daed to the upstream source"
  exit 1
}

grep -q '^rm -rf luci-app-daed/daed/Makefile && cp -r \$GITHUB_WORKSPACE/patches/daed/Makefile luci-app-daed/daed/$' "$PACKAGES" || {
  echo "Packages.sh does not apply the daed Makefile web build fix"
  exit 1
}

grep -q 'procd_set_param command' "$PACKAGES" || {
  echo "Packages.sh does not patch luci_daed init script command placement"
  exit 1
}

DAED_MAKEFILE="$ROOT_DIR/patches/daed/Makefile"
[ -f "$DAED_MAKEFILE" ] || { echo "missing daed Makefile patch"; exit 1; }

grep -Fq 'PKG_VERSION:=2026.05.03' "$DAED_MAKEFILE" || {
  echo "daed Makefile patch is not aligned to the latest daed package version"
  exit 1
}

grep -q 'HUSKY=0' "$DAED_MAKEFILE" || {
  echo "daed Makefile patch does not disable husky hooks during CI web build"
  exit 1
}

grep -q 'pnpm --filter daed\.\.\. build' "$DAED_MAKEFILE" || {
  echo "daed Makefile patch does not build the daed web frontend"
  exit 1
}

grep -q 'pnpm install --no-frozen-lockfile' "$DAED_MAKEFILE" || {
  echo "daed Makefile patch does not tolerate upstream pnpm lockfile/catalog drift"
  exit 1
}

grep -Fq '[ ! -d "$(DAED_BUILD_DIR)/apps/web/dist" ]' "$DAED_MAKEFILE" || {
  echo "daed Makefile patch does not validate the current daed web dist output"
  exit 1
}

grep -Fq 'find "$(DAED_BUILD_DIR)/apps/web/dist" -type f -print > "$(DAED_BUILD_DIR)/.web-dist-files"' "$DAED_MAKEFILE" || {
  echo "daed Makefile patch still relies on fragile find -quit or command substitution checks"
  exit 1
}

grep -Fq 'cp -a $(DAED_BUILD_DIR)/apps/web/dist/.' "$DAED_MAKEFILE" || {
  echo "daed Makefile patch does not copy the current daed web dist output"
  exit 1
}

grep -q 'rm -rf $(PKG_BUILD_DIR) ; \\' "$DAED_MAKEFILE" || {
  echo "daed Makefile patch does not remove stale or extracted wing directory before cloning"
  exit 1
}

grep -q 'currentRuntimeStatsStore' "$DAED_MAKEFILE" || {
  echo "daed Makefile patch does not skip obsolete runtime stats patch on newer dae-core"
  exit 1
}

grep -q 'patch -p2 --forward --batch' "$DAED_MAKEFILE" || {
  echo "daed Makefile patch does not apply runtime stats fallback patch non-interactively with the right strip level"
  exit 1
}

if grep -q 'fix-runtime-stats.patch | patch -p1' "$DAED_MAKEFILE"; then
  echo "daed Makefile still applies runtime stats patch with the wrong strip level"
  exit 1
fi

grep -q 'UPDATE_PACKAGE "gecoosac" "laipeng668/luci-app-gecoosac" "main"' "$PACKAGES" || {
  echo "Packages.sh does not align gecoosac to the upstream source"
  exit 1
}

grep -q '^echo "CONFIG_PACKAGE_luci-app-\$WRT_THEME-config=y" >> \./\.config$' "$SETTINGS" || {
  echo "Settings.sh does not auto-enable the selected theme config package"
  exit 1
}

echo "upstream plugin alignment test passed"
