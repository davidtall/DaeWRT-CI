#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
FETCH_SCRIPT="$ROOT_DIR/Scripts/fetch_viewturbocore.sh"
RC_LOCAL="$ROOT_DIR/files/etc/rc.local"

[ -f "$WORKFLOW" ] || { echo "missing WRT-CORE workflow"; exit 1; }
[ -f "$FETCH_SCRIPT" ] || { echo "missing fetch_viewturbocore.sh"; exit 1; }
[ -f "$RC_LOCAL" ] || { echo "missing rc.local overlay"; exit 1; }

grep -q '\$GITHUB_WORKSPACE/Scripts/fetch_viewturbocore.sh' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not run fetch_viewturbocore.sh"
  exit 1
}

FETCH_LINE="$(grep -n '\$GITHUB_WORKSPACE/Scripts/fetch_viewturbocore.sh' "$WORKFLOW" | head -n1 | cut -d: -f1)"
COPY_LINE="$(grep -n 'cp -rf ./files/. ./wrt/files/' "$WORKFLOW" | head -n1 | cut -d: -f1)"
[ -n "$FETCH_LINE" ] || { echo "missing viewturbocore fetch line number"; exit 1; }
[ -n "$COPY_LINE" ] || { echo "missing files copy line number"; exit 1; }
[ "$FETCH_LINE" -lt "$COPY_LINE" ] || {
  echo "WRT-CORE.yml runs fetch_viewturbocore.sh after files/ has already been staged"
  exit 1
}

grep -q '/usr/local/bin/viewturbocore' "$FETCH_SCRIPT" || {
  echo "fetch_viewturbocore.sh does not install to /usr/local/bin/viewturbocore"
  exit 1
}

grep -q 'ViewTurboCore-x86_64-unknown-linux-gnu' "$FETCH_SCRIPT" || {
  echo "fetch_viewturbocore.sh does not support x86_64 assets"
  exit 1
}

grep -q 'ViewTurboCore-aarch64-unknown-linux-gnu' "$FETCH_SCRIPT" || {
  echo "fetch_viewturbocore.sh does not support aarch64 assets"
  exit 1
}

grep -q 'curl -fsSL' "$FETCH_SCRIPT" || {
  echo "fetch_viewturbocore.sh does not download binaries with curl"
  exit 1
}

tr -d '\r' < "$RC_LOCAL" | grep -q '^rm -rf /.config$' || {
  echo "rc.local does not clear /.config before startup"
  exit 1
}

tr -d '\r' < "$RC_LOCAL" | grep -q '^ln -sf /root/.config /.config$' || {
  echo "rc.local does not relink /.config to /root/.config"
  exit 1
}

tr -d '\r' < "$RC_LOCAL" | grep -q '^/usr/local/bin/viewturbocore --start$' || {
  echo "rc.local does not start viewturbocore"
  exit 1
}

echo "viewturbocore preload test passed"
