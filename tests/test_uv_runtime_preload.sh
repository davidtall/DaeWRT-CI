#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERAL="$ROOT_DIR/Config/GENERAL.txt"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
FETCH_SCRIPT="$ROOT_DIR/Scripts/fetch_uv_runtime.sh"

[ -f "$GENERAL" ] || { echo "missing GENERAL config"; exit 1; }
[ -f "$WORKFLOW" ] || { echo "missing WRT-CORE workflow"; exit 1; }
[ -f "$FETCH_SCRIPT" ] || { echo "missing fetch_uv_runtime.sh"; exit 1; }

grep -q '^CONFIG_PACKAGE_python3=y$' "$GENERAL" || {
  echo "GENERAL.txt does not enable full python3"
  exit 1
}

grep -q '^CONFIG_PACKAGE_python3-venv=y$' "$GENERAL" || {
  echo "GENERAL.txt does not enable python3-venv"
  exit 1
}

grep -q '\$GITHUB_WORKSPACE/Scripts/fetch_uv_runtime.sh' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not run fetch_uv_runtime.sh"
  exit 1
}

grep -q "python3-venv was dropped from .config after defconfig" "$WORKFLOW" || {
  echo "WRT-CORE.yml does not guard python3-venv after defconfig"
  exit 1
}

if grep -q "python3-light is still enabled after defconfig" "$WORKFLOW"; then
  echo "WRT-CORE.yml still treats python3-light as a failure after defconfig"
  exit 1
fi

FETCH_LINE="$(grep -n '\$GITHUB_WORKSPACE/Scripts/fetch_uv_runtime.sh' "$WORKFLOW" | head -n1 | cut -d: -f1)"
COPY_LINE="$(grep -n 'cp -rf ./files/. ./wrt/files/' "$WORKFLOW" | head -n1 | cut -d: -f1)"
[ -n "$FETCH_LINE" ] || { echo "missing fetch script line number"; exit 1; }
[ -n "$COPY_LINE" ] || { echo "missing files copy line number"; exit 1; }
[ "$FETCH_LINE" -lt "$COPY_LINE" ] || {
  echo "WRT-CORE.yml runs fetch_uv_runtime.sh after files/ has already been staged"
  exit 1
}

grep -q 'cp -rf ./files/. ./wrt/files/' "$WORKFLOW" || {
  echo "WRT-CORE.yml no longer stages files/ into wrt/files"
  exit 1
}

grep -q 'uv-aarch64-unknown-linux-musl' "$FETCH_SCRIPT" || {
  echo "fetch_uv_runtime.sh does not support aarch64 musl uv assets"
  exit 1
}

grep -q 'uv-x86_64-unknown-linux-musl' "$FETCH_SCRIPT" || {
  echo "fetch_uv_runtime.sh does not support x86_64 musl uv assets"
  exit 1
}

grep -q 'UV_PYTHON_INSTALL_MIRROR' "$FETCH_SCRIPT" || {
  echo "fetch_uv_runtime.sh does not prepare a local Python install mirror"
  exit 1
}

grep -q 'python-build-standalone' "$FETCH_SCRIPT" || {
  echo "fetch_uv_runtime.sh does not mirror python-build-standalone assets"
  exit 1
}

grep -q "3.10 3.11 3.12 3.13" "$FETCH_SCRIPT" || {
  echo "fetch_uv_runtime.sh does not target Python 3.10-3.13"
  exit 1
}

echo "uv runtime preload guard test passed"
