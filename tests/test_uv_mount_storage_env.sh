#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT_DIR/files/etc/profile.d/uv.sh"
INIT="$ROOT_DIR/files/etc/init.d/uv-storage"
RC_LINK="$ROOT_DIR/files/etc/rc.d/S99uv-storage"
SMOKE="$ROOT_DIR/files/usr/bin/uv-runtime-smoke"

[ -f "$PROFILE" ] || { echo "missing uv profile script"; exit 1; }
[ -f "$INIT" ] || { echo "missing uv init script"; exit 1; }
[ -e "$RC_LINK" ] || { echo "missing uv init enablement entry"; exit 1; }

if [ -L "$RC_LINK" ]; then
  [ "$(readlink "$RC_LINK")" = "../init.d/uv-storage" ] || {
    echo "uv init enablement does not target ../init.d/uv-storage"
    exit 1
  }
else
  SYMLINK_MODE="$(git -C "$ROOT_DIR" ls-files -s -- "files/etc/rc.d/S99uv-storage" | awk '{print $1}')"
  [ "$SYMLINK_MODE" = "120000" ] || {
    echo "uv init enablement is not recorded as a git symlink"
    exit 1
  }
  [ "$(cat "$RC_LINK")" = "../init.d/uv-storage" ] || {
    echo "uv init enablement placeholder does not target ../init.d/uv-storage"
    exit 1
  }
fi

[ -x "$INIT" ] || { echo "uv init script is not executable"; exit 1; }

grep -q '/tmp/uv-env.sh' "$PROFILE" || {
  echo "uv profile script does not source /tmp/uv-env.sh"
  exit 1
}

grep -q 'UV_PYTHON_INSTALL_MIRROR=file:///opt/uv/python-mirror' "$PROFILE" || {
  echo "uv profile script does not export the immutable Python mirror"
  exit 1
}

grep -q '/mnt/mmc' "$INIT" || {
  echo "uv init script does not prefer /mnt/mmc"
  exit 1
}

grep -q 'UV_CACHE_DIR' "$INIT" || {
  echo "uv init script does not write UV_CACHE_DIR"
  exit 1
}

grep -q 'UV_PYTHON_INSTALL_DIR' "$INIT" || {
  echo "uv init script does not write UV_PYTHON_INSTALL_DIR"
  exit 1
}

grep -q 'UV_PYTHON_CACHE_DIR' "$INIT" || {
  echo "uv init script does not write UV_PYTHON_CACHE_DIR"
  exit 1
}

[ -f "$SMOKE" ] || { echo "missing uv runtime smoke helper"; exit 1; }

grep -q 'python3 -m venv /tmp/uv-smoke-venv' "$SMOKE" || {
  echo "uv runtime smoke helper does not validate python3 -m venv"
  exit 1
}

grep -q '. /tmp/uv-env.sh' "$SMOKE" || {
  echo "uv runtime smoke helper does not source /tmp/uv-env.sh"
  exit 1
}

echo "uv mount-aware storage guard test passed"
