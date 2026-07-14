#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
HANDLES_SH="$ROOT_DIR/Scripts/Handles.sh"

[ -f "$WORKFLOW" ] || { echo "missing WRT-CORE workflow"; exit 1; }
[ -f "$HANDLES_SH" ] || { echo "missing Handles.sh"; exit 1; }

grep -q 'mkdir -p "\$GITHUB_WORKSPACE/files/etc/nikki/run"' "$HANDLES_SH" || {
  echo "Handles.sh does not create the Nikki geodata staging directory"
  exit 1
}

grep -q 'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat' "$HANDLES_SH" || {
  echo "Handles.sh does not download geoip.dat from MetaCubeX"
  exit 1
}

grep -q 'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat' "$HANDLES_SH" || {
  echo "Handles.sh does not download geosite.dat from MetaCubeX"
  exit 1
}

grep -q 'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb' "$HANDLES_SH" || {
  echo "Handles.sh does not download geoip.metadb from MetaCubeX"
  exit 1
}

grep -q '\$GITHUB_WORKSPACE/files/etc/nikki/run/geoip.dat' "$HANDLES_SH" || {
  echo "Handles.sh does not stage geoip.dat into files/etc/nikki/run"
  exit 1
}

grep -q '\$GITHUB_WORKSPACE/files/etc/nikki/run/geosite.dat' "$HANDLES_SH" || {
  echo "Handles.sh does not stage geosite.dat into files/etc/nikki/run"
  exit 1
}

grep -q '\$GITHUB_WORKSPACE/files/etc/nikki/run/geoip.metadb' "$HANDLES_SH" || {
  echo "Handles.sh does not stage geoip.metadb into files/etc/nikki/run"
  exit 1
}

grep -q 'mkdir -p ./wrt/files' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not create the OpenWrt files overlay directory"
  exit 1
}

grep -q 'cp -rf ./files/. ./wrt/files/' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not copy repository files overlays into ./wrt/files"
  exit 1
}

echo "nikki geodata preload test passed"
