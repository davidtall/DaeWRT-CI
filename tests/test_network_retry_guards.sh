#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RETRY_HELPER="$ROOT_DIR/Scripts/retry.sh"
PACKAGES_SH="$ROOT_DIR/Scripts/Packages.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"

[ -f "$RETRY_HELPER" ] || { echo "missing retry helper"; exit 1; }
[ -f "$PACKAGES_SH" ] || { echo "missing Packages.sh"; exit 1; }
[ -f "$WORKFLOW" ] || { echo "missing WRT-CORE workflow"; exit 1; }

grep -q '^retry_cmd()' "$RETRY_HELPER" || {
  echo "retry helper does not define retry_cmd"
  exit 1
}

grep -q 'retry_cmd 5 15 git clone --depth=1 --single-branch --branch \$PKG_BRANCH "https://github.com/\$PKG_REPO.git"' "$PACKAGES_SH" || {
  echo "Packages.sh does not retry package git clone"
  exit 1
}

grep -q 'retry_cmd 5 15 git -C "\$REPO_NAME" fetch --depth=1 origin "\$PKG_COMMIT"' "$PACKAGES_SH" || {
  echo "Packages.sh does not retry package git fetch"
  exit 1
}

grep -q 'dos2unix "\$GITHUB_WORKSPACE/Scripts/init_build_environment.sh"' "$WORKFLOW" || {
  echo "workflow does not normalize the bundled init script before running it"
  exit 1
}

grep -q '\${SUDO} bash "\$GITHUB_WORKSPACE/Scripts/init_build_environment.sh"' "$WORKFLOW" || {
  echo "workflow does not run the bundled init script"
  exit 1
}

grep -q 'retry_cmd 5 15 git clone --depth=1 --single-branch --branch \$WRT_BRANCH \$WRT_REPO ./wrt/' "$WORKFLOW" || {
  echo "workflow does not retry source git clone"
  exit 1
}

grep -q 'retry_cmd 5 15 ./scripts/feeds update -a' "$WORKFLOW" || {
  echo "workflow does not retry feeds update"
  exit 1
}

grep -q 'retry_cmd 5 15 ./scripts/feeds install -a' "$WORKFLOW" || {
  echo "workflow does not retry feeds install"
  exit 1
}

echo "network retry guards test passed"
