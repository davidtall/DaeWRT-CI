#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$ROOT_DIR/package/wg-endpoint-watchdog"
CONFIG_FILE="$PKG_DIR/files/etc/config/wg_endpoint_watchdog"
MAKEFILE="$PKG_DIR/Makefile"
GENERAL_CONFIG="$ROOT_DIR/Config/GENERAL.txt"
PROMPT_DOC="$ROOT_DIR/docs/codex-prompts/wg-endpoint-watchdog.md"

required_files=(
  "$MAKEFILE"
  "$CONFIG_FILE"
  "$PKG_DIR/files/etc/init.d/wg-endpoint-watchdog"
  "$PKG_DIR/files/usr/bin/wg-endpoint-refresh"
  "$PKG_DIR/files/usr/bin/wg-endpoint-watchdog"
  "$PKG_DIR/files/etc/hotplug.d/iface/99-wg-endpoint-watchdog"
  "$PKG_DIR/README.md"
  "$PROMPT_DOC"
)

for file in "${required_files[@]}"; do
  [ -f "$file" ] || {
    echo "missing required wg-endpoint-watchdog file: $file"
    exit 1
  }
done

tr -d '\r' <"$MAKEFILE" | grep '^PKG_NAME:=wg-endpoint-watchdog$' >/dev/null || {
  echo "Makefile does not define the expected package name"
  exit 1
}

tr -d '\r' <"$MAKEFILE" | grep '^  PKGARCH:=all$' >/dev/null || {
  echo "Makefile should mark this POSIX shell package as PKGARCH:=all"
  exit 1
}

grep -q '+wireguard-tools' "$MAKEFILE" || {
  echo "wg-endpoint-watchdog should depend on wireguard-tools"
  exit 1
}

! grep -q '+ddns-go' "$MAKEFILE" || {
  echo "ddns-go must stay optional and not become a hard dependency"
  exit 1
}

tr -d '\r' <"$GENERAL_CONFIG" | grep "^CONFIG_PACKAGE_wg-endpoint-watchdog=y$" >/dev/null || {
  echo "wg-endpoint-watchdog is not selected in the default build config"
  exit 1
}

tr -d '\r' < "$CONFIG_FILE" | grep -q "^	option enabled '0'$" || {
  echo "default UCI instance must be disabled"
  exit 1
}

tr -d '\r' < "$CONFIG_FILE" | grep -q "^	option proxy_bypass '0'$" || {
  echo "default proxy bypass must be disabled"
  exit 1
}

tr -d '\r' < "$CONFIG_FILE" | grep -q "^	option proxy_bypass_udp_sport ''$" || {
  echo "default proxy bypass port must be empty"
  exit 1
}

for forbidden in \
  "office-wg.jmsu"'.top' \
  "dorm-wg.jmsu"'.top' \
  "192.168.11.0"'/24' \
  "192.168.12.0"'/24' \
  "Access"'Key' \
  "private"'_key' \
  "preshared"'_key'; do
  ! grep -R --fixed-strings "$forbidden" \
    "$PKG_DIR" "$PROMPT_DOC" "$GENERAL_CONFIG" >/dev/null || {
    echo "forbidden private value marker found: $forbidden"
    exit 1
  }
done

echo "wg-endpoint-watchdog package guard test passed"
