#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/Scripts/SplitFirmwareArtifacts.sh"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

INPUT="$WORK_DIR/upload"
OUTPUT="$WORK_DIR/groups"
mkdir -p "$INPUT"

printf 'sysupgrade\n' >"$INPUT/openwrt-jdcloud_re-cs-07-squashfs-sysupgrade.bin"
printf 'factory\n' >"$INPUT/openwrt-jdcloud_re-cs-07-squashfs-factory.bin"
printf 'other\n' >"$INPUT/openwrt-xiaomi_ax1800-squashfs-sysupgrade.bin"
printf 'config\n' >"$INPUT/Config-IPQ60XX-WIFI-YES.txt"
printf 'manifest\n' >"$INPUT/openwrt-qualcommax-ipq60xx.manifest"
printf '{}\n' >"$INPUT/metadata.json"
printf 'old sums\n' >"$INPUT/SHA256SUMS"

"$SCRIPT" "$INPUT" "$OUTPUT"

test -f "$OUTPUT/jdcloud_re-cs-07/openwrt-jdcloud_re-cs-07-squashfs-sysupgrade.bin"
test -f "$OUTPUT/jdcloud_re-cs-07/openwrt-jdcloud_re-cs-07-squashfs-factory.bin"
test -f "$OUTPUT/other-devices/openwrt-xiaomi_ax1800-squashfs-sysupgrade.bin"

for group in jdcloud_re-cs-07 other-devices; do
	test -f "$OUTPUT/$group/Config-IPQ60XX-WIFI-YES.txt"
	test -f "$OUTPUT/$group/openwrt-qualcommax-ipq60xx.manifest"
	test -f "$OUTPUT/$group/metadata.json"
	test -s "$OUTPUT/$group/SHA256SUMS"
	(cd "$OUTPUT/$group" && sha256sum -c SHA256SUMS >/dev/null)
done

test ! -e "$OUTPUT/jdcloud_re-cs-07/openwrt-xiaomi_ax1800-squashfs-sysupgrade.bin"
test ! -e "$OUTPUT/other-devices/openwrt-jdcloud_re-cs-07-squashfs-sysupgrade.bin"
test ! -d "$OUTPUT/metadata"

echo "firmware artifact splitter tests passed"
