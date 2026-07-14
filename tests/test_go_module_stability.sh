#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
INIT_SCRIPT="$ROOT_DIR/Scripts/init_build_environment.sh"

[ -f "$WORKFLOW" ] || { echo "missing workflow"; exit 1; }
[ -f "$INIT_SCRIPT" ] || { echo "missing init script"; exit 1; }

grep -q 'GOPROXY=https://proxy.golang.org|https://goproxy.cn|direct' "$WORKFLOW" || {
  echo "workflow missing GOPROXY export"
  exit 1
}

grep -q 'go env -w GOPROXY="https://proxy.golang.org|https://goproxy.cn|direct"' "$INIT_SCRIPT" || {
  echo "init script missing quoted GOPROXY setting"
  exit 1
}

grep -q 'GOSUMDB=sum.golang.org' "$WORKFLOW" || {
  echo "workflow missing GOSUMDB sum.golang.org export"
  exit 1
}

grep -q 'uses: actions/setup-go@v6' "$WORKFLOW" || {
  echo "workflow missing setup-go fallback for Go 1.26"
  exit 1
}

grep -q "go-version: '1.26'" "$WORKFLOW" || {
  echo "workflow setup-go fallback does not request Go 1.26"
  exit 1
}

if grep -q 'GOSUMDB=off' "$WORKFLOW"; then
  echo "workflow disables GOSUMDB, which breaks Go toolchain downloads"
  exit 1
fi

grep -q './wrt/dl/go-mod-cache' "$WORKFLOW" || {
  echo "workflow missing go mod cache path"
  exit 1
}

grep -q './wrt/tmp/go-build' "$WORKFLOW" || {
  echo "workflow missing go build cache path"
  exit 1
}

grep -q 'go env -w GOSUMDB=sum.golang.org' "$INIT_SCRIPT" || {
  echo "init script missing GOSUMDB sum.golang.org setting"
  exit 1
}

if grep -q 'go env -w GOSUMDB=off' "$INIT_SCRIPT"; then
  echo "init script disables GOSUMDB, which breaks Go toolchain downloads"
  exit 1
fi

echo "go module stability test passed"
