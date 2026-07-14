#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT_SCRIPT="$ROOT_DIR/files/etc/init.d/tailscale-accept-dns-guard"
UCI_DEFAULTS="$ROOT_DIR/files/etc/uci-defaults/95-tailscale-accept-dns-guard"

[ -f "$INIT_SCRIPT" ] || { echo "missing tailscale DNS guard init script"; exit 1; }
[ -f "$UCI_DEFAULTS" ] || { echo "missing tailscale DNS guard uci-defaults"; exit 1; }

grep -q 'tailscale set --accept-dns=false' "$INIT_SCRIPT" || {
  echo "init script does not enforce accept-dns=false"
  exit 1
}

grep -q '/etc/init.d/tailscale-accept-dns-guard enable' "$UCI_DEFAULTS" || {
  echo "uci-defaults does not enable tailscale DNS guard"
  exit 1
}

echo "tailscale DNS guard test passed"
