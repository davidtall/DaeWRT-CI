#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/Scripts/GuardReCs07Artifact.sh"
DEVICE='jdcloud_re-cs-07'

[ -f "$SCRIPT" ] || { echo "missing GuardReCs07Artifact.sh"; exit 1; }
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cat >"$WORK_DIR/.config" <<'EOT'
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-07=y
CONFIG_PACKAGE_gre=y
CONFIG_PACKAGE_luci-proto-gre=y
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_luci-app-wrtbak=y
CONFIG_PACKAGE_vm103-failover=y
EOT
bash "$SCRIPT" defconfig "$WORK_DIR/.config" "$DEVICE"

mkdir -p "$WORK_DIR/bin/targets/qualcommax/ipq60xx" "$WORK_DIR/upload"
printf 'firmware\n' >"$WORK_DIR/bin/targets/qualcommax/ipq60xx/openwrt-qualcommax-ipq60xx-jdcloud_re-cs-07-squashfs-sysupgrade.bin"
cat >"$WORK_DIR/bin/targets/qualcommax/ipq60xx/qualcommax-ipq60xx-generic.manifest" <<'EOT'
gre - 1
luci-proto-gre - 1
ip-full - 1
luci-app-wrtbak - 1
vm103-failover - 1
EOT
cp "$WORK_DIR/.config" "$WORK_DIR/upload/Config-IPQ60XX-RE-CS-07-NOWIFI.txt"
bash "$SCRIPT" stage "$WORK_DIR/bin/targets" "$WORK_DIR/upload" "$DEVICE"
bash "$SCRIPT" verify "$WORK_DIR/upload" "$DEVICE"
[ "$(find "$WORK_DIR/upload" -maxdepth 1 -type f | wc -l)" -eq 4 ]
(cd "$WORK_DIR/upload" && sha256sum -c SHA256SUMS >/dev/null)

# Verification rejects a manifest missing the topology-specific package.
cp -a "$WORK_DIR/upload" "$WORK_DIR/missing-package-upload"
sed -i '/^vm103-failover[[:space:]]/d' "$WORK_DIR/missing-package-upload/qualcommax-ipq60xx-generic.manifest"
if bash "$SCRIPT" verify "$WORK_DIR/missing-package-upload" "$DEVICE" >"$WORK_DIR/missing-package.err" 2>&1; then
	echo "artifact guard accepted a manifest without vm103-failover"
	exit 1
fi
grep -Fq 'manifest is missing required package: vm103-failover' "$WORK_DIR/missing-package.err"

# Verification rejects nested paths, even when the four top-level files are valid.
mkdir -p "$WORK_DIR/upload/nested"
printf 'unexpected\n' >"$WORK_DIR/upload/nested/file"
! bash "$SCRIPT" verify "$WORK_DIR/upload" "$DEVICE" >/dev/null 2>&1
rm -rf "$WORK_DIR/upload/nested"

# SHA256SUMS must contain exactly the three artifact payload names.
cp "$WORK_DIR/upload/SHA256SUMS" "$WORK_DIR/SHA256SUMS.good"
sed -n '1,2p' "$WORK_DIR/SHA256SUMS.good" >"$WORK_DIR/upload/SHA256SUMS"
! bash "$SCRIPT" verify "$WORK_DIR/upload" "$DEVICE" >/dev/null 2>&1
cp "$WORK_DIR/SHA256SUMS.good" "$WORK_DIR/upload/SHA256SUMS"
printf '%064d  extra-file\n' 0 >>"$WORK_DIR/upload/SHA256SUMS"
! bash "$SCRIPT" verify "$WORK_DIR/upload" "$DEVICE" >/dev/null 2>&1
cp "$WORK_DIR/SHA256SUMS.good" "$WORK_DIR/upload/SHA256SUMS"

cp "$WORK_DIR/.config" "$WORK_DIR/multi.config"
printf '%s\n' 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=y' >>"$WORK_DIR/multi.config"
! bash "$SCRIPT" defconfig "$WORK_DIR/multi.config" "$DEVICE" >/dev/null 2>&1
grep -v '^CONFIG_PACKAGE_gre=y$' "$WORK_DIR/.config" >"$WORK_DIR/missing.config"
! bash "$SCRIPT" defconfig "$WORK_DIR/missing.config" "$DEVICE" >/dev/null 2>&1
grep -v '^CONFIG_PACKAGE_vm103-failover=y$' "$WORK_DIR/.config" >"$WORK_DIR/missing-vm103.config"
! bash "$SCRIPT" defconfig "$WORK_DIR/missing-vm103.config" "$DEVICE" >/dev/null 2>&1
printf 'factory\n' >"$WORK_DIR/upload/openwrt-jdcloud_re-cs-07-factory.bin"
! bash "$SCRIPT" verify "$WORK_DIR/upload" "$DEVICE" >/dev/null 2>&1
rm "$WORK_DIR/upload/openwrt-jdcloud_re-cs-07-factory.bin"

# Stage rejects a non-flat upload staging tree.
mkdir -p "$WORK_DIR/nested-upload/nested"
cp "$WORK_DIR/.config" "$WORK_DIR/nested-upload/Config-IPQ60XX-RE-CS-07-NOWIFI.txt"
printf 'unexpected\n' >"$WORK_DIR/nested-upload/nested/file"
! bash "$SCRIPT" stage "$WORK_DIR/bin/targets" "$WORK_DIR/nested-upload" "$DEVICE" >/dev/null 2>&1

# A unique generic manifest in a stale sibling directory is not bound to the image.
mkdir -p "$WORK_DIR/wrong-source/device" "$WORK_DIR/wrong-source/wrong/stale" "$WORK_DIR/wrong-upload"
cp "$WORK_DIR/bin/targets/qualcommax/ipq60xx/"*jdcloud_re-cs-07*sysupgrade.bin "$WORK_DIR/wrong-source/device/"
cp "$WORK_DIR/bin/targets/qualcommax/ipq60xx/"*.manifest "$WORK_DIR/wrong-source/wrong/stale/"
cp "$WORK_DIR/.config" "$WORK_DIR/wrong-upload/Config-IPQ60XX-RE-CS-07-NOWIFI.txt"
! bash "$SCRIPT" stage "$WORK_DIR/wrong-source" "$WORK_DIR/wrong-upload" "$DEVICE" >/dev/null 2>&1

printf 'other firmware\n' >"$WORK_DIR/bin/targets/qualcommax/ipq60xx/openwrt-qualcommax-ipq60xx-jdcloud_re-cs-02-squashfs-sysupgrade.bin"
! bash "$SCRIPT" stage "$WORK_DIR/bin/targets" "$WORK_DIR/upload" "$DEVICE" >/dev/null 2>&1

echo "RE-CS-07 artifact guard tests passed"
