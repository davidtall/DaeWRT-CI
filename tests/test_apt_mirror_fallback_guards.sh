#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"

[ -f "$WORKFLOW" ] || { echo "missing WRT-CORE workflow"; exit 1; }

grep -q 'reset_ubuntu_mirrors()' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not define an Ubuntu mirror reset helper"
  exit 1
}

grep -q 'apt_retry_update()' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not define an apt update retry helper"
  exit 1
}

grep -q 'retry_cmd 3 15 run_apt update' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not retry apt update before falling back"
  exit 1
}

grep -q 'reset_ubuntu_mirrors' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not call the Ubuntu mirror reset helper"
  exit 1
}

grep -q 'retry_cmd 3 15 run_apt full-upgrade' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not retry apt full-upgrade"
  exit 1
}

grep -q 'retry_cmd 3 15 run_apt install dos2unix python3-netifaces libfuse-dev' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not retry apt package installation"
  exit 1
}

echo "apt mirror fallback guards test passed"
