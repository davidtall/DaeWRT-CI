#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"

[ -f "$WORKFLOW" ] || { echo "missing WRT-CORE workflow"; exit 1; }

grep -q 'name: Upload Firmware Artifact' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not upload firmware artifacts before release"
  exit 1
}

grep -q 'uses: actions/upload-artifact@v4' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not use the official upload-artifact@v4 action"
  exit 1
}

grep -q 'name: Release Firmware' "$WORKFLOW" || {
  echo "WRT-CORE.yml is missing the Release Firmware step"
  exit 1
}

grep -q 'gh release create' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not use the official gh CLI to create releases"
  exit 1
}

grep -q 'gh release upload' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not use the official gh CLI to upload release assets"
  exit 1
}

grep -q 'gh release create -R "$GITHUB_REPOSITORY"' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not force gh release create to target the workflow repository"
  exit 1
}

grep -q 'gh release upload -R "$GITHUB_REPOSITORY"' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not force gh release upload to target the workflow repository"
  exit 1
}

grep -q 'WRT_INFO_VALUE="${WRT_SOURCE%%/\*}"' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not compute a fallback release filename prefix"
  exit 1
}

grep -q 'GH_TOKEN: ${{secrets.GITHUB_TOKEN}}' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not pass GITHUB_TOKEN to gh as GH_TOKEN"
  exit 1
}

grep -q 'actions: write' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not grant actions: write permission for cache cleanup"
  exit 1
}

grep -q 'retry_cmd 5 15 gh release upload' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not retry gh release upload"
  exit 1
}

grep -q 'for asset in "${assets\[@\]}"; do' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not upload release assets one by one"
  exit 1
}

grep -q 'WARN: failed to delete cache \$key' "$WORKFLOW" || {
  echo "WRT-CORE.yml does not tolerate cache deletion failures"
  exit 1
}

echo "release fallback guards test passed"
