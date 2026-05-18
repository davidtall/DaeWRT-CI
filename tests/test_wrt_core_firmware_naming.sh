#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"

[ -f "$WORKFLOW" ] || { echo "missing WRT-CORE workflow"; exit 1; }

grep -q 'NEW_FILE="$NAME"-"$WRT_DATE"."$EXT"' "$WORKFLOW" || {
	echo "WRT-CORE does not use the upstream simplified firmware filename"
	exit 1
}

if grep -q 'NEW_FILE="$WRT_CONFIG"-"$WRT_BRANCH"-"$NAME"-"$WRT_DATE"."$EXT"' "$WORKFLOW"; then
	echo "WRT-CORE still prefixes firmware filenames with config and branch"
	exit 1
fi

echo "WRT-CORE firmware naming test passed"
