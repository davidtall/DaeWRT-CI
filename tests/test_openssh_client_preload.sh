#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERAL_CONFIG="$ROOT_DIR/Config/GENERAL.txt"

[ -f "$GENERAL_CONFIG" ] || {
  echo "missing GENERAL config"
  exit 1
}

grep -q '^CONFIG_PACKAGE_openssh-client=y$' "$GENERAL_CONFIG" || {
  echo "GENERAL config does not preload openssh-client"
  exit 1
}

echo "openssh-client preload test passed"
