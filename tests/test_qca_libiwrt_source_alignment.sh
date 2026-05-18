#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/QCA-6.12-LiBwrt.yml"
DIY_SH="$ROOT_DIR/diy.sh"
README="$ROOT_DIR/README.md"

[ -f "$WORKFLOW" ] || { echo "missing QCA-6.12-LiBwrt workflow"; exit 1; }
[ -f "$DIY_SH" ] || { echo "missing diy.sh"; exit 1; }
[ -f "$README" ] || { echo "missing README"; exit 1; }

grep -q 'SOURCE: \[davidtall/LiBwrt-openwrt-6.x\]' "$WORKFLOW" || {
  echo "QCA-6.12-LiBwrt workflow is not pinned to the davidtall LiBwrt source that provides k6.12-nss"
  exit 1
}

grep -q 'BRANCH: \[k6.12-nss\]' "$WORKFLOW" || {
  echo "QCA-6.12-LiBwrt workflow does not keep the expected k6.12-nss branch"
  exit 1
}

grep -q "^#WRT_REPO='https://github.com/davidtall/LiBwrt-openwrt-6.x'" "$DIY_SH" || {
  echo "diy.sh does not document the working LiBwrt repository source"
  exit 1
}

grep -q "^#WRT_BRANCH='k6.12-nss'" "$DIY_SH" || {
  echo "diy.sh does not document the working LiBwrt branch"
  exit 1
}

grep -q '^https://github.com/davidtall/LiBwrt-openwrt-6.x$' "$README" || {
  echo "README does not document the working LiBwrt repository source"
  exit 1
}

echo "QCA LiBwrt source alignment test passed"
