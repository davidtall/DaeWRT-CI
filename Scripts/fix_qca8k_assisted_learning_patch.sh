#!/bin/bash
set -euo pipefail

WRT_ROOT="${1:-./wrt}"
PATCH_FILE="$WRT_ROOT/target/linux/generic/pending-6.12/712-net-dsa-qca8k-enable-assisted-learning-on-CPU-port.patch"
HUNK_HEADER='@@ -2046,11 +2052,6 @@ qca8k_setup(struct dsa_switch *ds)'
NEXT_HUNK='@@ -2107,6 +2108,9 @@ qca8k_setup(struct dsa_switch *ds)'

[ -f "$PATCH_FILE" ] || exit 0

if ! grep -Fqx "$HUNK_HEADER" "$PATCH_FILE"; then
	echo "qca8k assisted-learning patch does not need compatibility adjustment"
	exit 0
fi

sed -i "/^@@ -2046,11 +2052,6 @@ qca8k_setup/,/^@@ -2107,6 +2108,9 @@ qca8k_setup/{ /^@@ -2107,6 +2108,9 @@ qca8k_setup/!d; }" "$PATCH_FILE"

grep -Fqx "$NEXT_HUNK" "$PATCH_FILE"
if grep -Fqx "$HUNK_HEADER" "$PATCH_FILE"; then
	echo "ERROR: failed to remove obsolete qca8k assisted-learning hunk" >&2
	exit 1
fi

echo "Removed obsolete qca8k learning-disable hunk already present in Linux 6.12.94"
