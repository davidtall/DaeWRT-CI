#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTIONS_SH="$ROOT_DIR/Scripts/function.sh"
TMP_DIR="$(mktemp -d)"
FUNCTIONS_COPY="$TMP_DIR/function.sh"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

[ -f "$FUNCTIONS_SH" ] || { echo "missing function.sh"; exit 1; }
tr -d '\r' < "$FUNCTIONS_SH" > "$FUNCTIONS_COPY"
chmod +x "$FUNCTIONS_COPY"

mkdir -p "$TMP_DIR/target/linux/qualcommax/image"
cat > "$TMP_DIR/target/linux/qualcommax/image/ipq60xx.mk" <<'EOF'
define Device/emmc-common
  KERNEL_SIZE := 6144k
endef

define Device/link_nn6000-common
  KERNEL_SIZE := 6144k
endef
EOF

(
	cd "$TMP_DIR"
	source "$FUNCTIONS_COPY"
	set_kernel_size >/dev/null
)

awk '
	/^define Device\/link_nn6000-common/ { in_block=1; next }
	in_block && /KERNEL_SIZE := 12288k/ { found=1 }
	in_block && /^endef/ { exit(found ? 0 : 1) }
	END { exit(found ? 0 : 1) }
' "$TMP_DIR/target/linux/qualcommax/image/ipq60xx.mk" || {
	echo "set_kernel_size did not expand link_nn6000-common kernel size to 12288k"
	exit 1
}

echo "ipq60xx link_nn6000 kernel size guard test passed"
