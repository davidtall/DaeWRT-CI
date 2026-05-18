#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAILSCALE_CONFIG="$ROOT_DIR/files/etc/config/tailscale"
TAILSCALE_FALLBACK="$ROOT_DIR/files/etc/uci-defaults/96-tailscale-uci-fallback"
TAILSCALE_SETTINGS_ENABLE="$ROOT_DIR/files/etc/uci-defaults/94-tailscale-settings-enable"

[ -f "$TAILSCALE_CONFIG" ] || { echo "missing tailscale config overlay"; exit 1; }
[ -f "$TAILSCALE_FALLBACK" ] || { echo "missing tailscale fallback defaults"; exit 1; }
[ ! -e "$TAILSCALE_SETTINGS_ENABLE" ] || {
  echo "tailscale-settings enable defaults should be absent so the reconciler stays opt-in"
  exit 1
}

tr -d '\r' < "$TAILSCALE_CONFIG" | grep -q "^	option disable_magic_dns '1'$" || {
  echo "tailscale config does not explicitly disable MagicDNS takeover"
  exit 1
}

grep -q "option disable_magic_dns '1'" "$TAILSCALE_FALLBACK" || {
  echo "tailscale fallback defaults do not recreate disable_magic_dns"
  exit 1
}

echo "tailscale settings opt-in test passed"
