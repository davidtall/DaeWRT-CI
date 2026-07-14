#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PATCH_DIR="$TMP_DIR/wrt/target/linux/generic/pending-6.12"
mkdir -p "$PATCH_DIR"
cp "$ROOT_DIR/tests/fixtures/qca8k-assisted-learning.patch" \
	"$PATCH_DIR/712-net-dsa-qca8k-enable-assisted-learning-on-CPU-port.patch"

bash "$ROOT_DIR/Scripts/fix_qca8k_assisted_learning_patch.sh" "$TMP_DIR/wrt"

PATCH_FILE="$PATCH_DIR/712-net-dsa-qca8k-enable-assisted-learning-on-CPU-port.patch"
! grep -Fq '@@ -2046,11 +2052,6 @@' "$PATCH_FILE"
grep -Fq '@@ -2022,6 +2022,12 @@' "$PATCH_FILE"
grep -Fq '@@ -2107,6 +2108,9 @@' "$PATCH_FILE"

# The adjustment must remain safe to run more than once.
bash "$ROOT_DIR/Scripts/fix_qca8k_assisted_learning_patch.sh" "$TMP_DIR/wrt"
