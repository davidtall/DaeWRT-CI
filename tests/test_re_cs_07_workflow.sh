#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
DEDICATED="$ROOT_DIR/.github/workflows/RE-CS-07-BUILD.yml"

[ -f "$CORE" ] || { echo "missing WRT-CORE workflow"; exit 1; }
[ -f "$DEDICATED" ] || { echo "missing RE-CS-07 dedicated workflow"; exit 1; }

grep -Fq 'WRT_BUILD_ONLY:' "$CORE"
grep -Fq 'WRT_EXPECTED_DEVICE:' "$CORE"
grep -Fq 'WRT_BUILD_ONLY: ${{inputs.WRT_BUILD_ONLY}}' "$CORE"
grep -Fq 'WRT_EXPECTED_DEVICE: ${{inputs.WRT_EXPECTED_DEVICE}}' "$CORE"
grep -Fq "if: inputs.WRT_EXPECTED_DEVICE != ''" "$CORE"
grep -Fq "if: env.WRT_PRIVATE_BUILD != 'true' && env.WRT_BUILD_ONLY != 'true' && env.WRT_TEST != 'true'" "$CORE"

if grep -Eq '(defconfig|stage)[[:space:]]+\+' "$CORE"; then
	echo "WRT-CORE contains a literal plus concatenated to a guard command"
	exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

extract_run_block() {
	local step_name="$1" output="$2"
	awk -v wanted="      - name: $step_name" '
		$0 == wanted { in_step = 1; next }
		in_step && $0 == "        run: |" { in_run = 1; next }
		in_run && /^      - name:/ { exit }
		in_run && /^          / { sub(/^          /, ""); print; next }
		in_run && /^[[:space:]]*$/ { print ""; next }
		in_run { exit }
	' "$CORE" >"$output"
	[ -s "$output" ] || {
		echo "could not extract run block for $step_name"
		exit 1
	}
}

extract_run_block 'Guard Expected Device Config' "$WORK_DIR/guard-config.sh"
extract_run_block 'Package Firmware' "$WORK_DIR/package-firmware.sh"
bash -n "$WORK_DIR/guard-config.sh"
bash -n "$WORK_DIR/package-firmware.sh"
grep -Fq 'GuardReCs07Artifact.sh" defconfig \' "$WORK_DIR/guard-config.sh"
grep -Fq 'GuardReCs07Artifact.sh" stage \' "$WORK_DIR/package-firmware.sh"

grep -Fq 'name: RE-CS-07 Build Only' "$DEDICATED"
grep -Fq 'workflow_dispatch:' "$DEDICATED"
grep -Fq 'actions: write' "$DEDICATED"
grep -Fq 'contents: write' "$DEDICATED"
grep -Fq 'WRT_CONFIG: IPQ60XX-RE-CS-07-NOWIFI' "$DEDICATED"
grep -Fq 'WRT_REPO: https://github.com/VIKINGYFY/immortalwrt.git' "$DEDICATED"
grep -Fq 'WRT_BRANCH: main' "$DEDICATED"
grep -Fq 'WRT_BUILD_ONLY: true' "$DEDICATED"
grep -Fq 'WRT_EXPECTED_DEVICE: jdcloud_re-cs-07' "$DEDICATED"
grep -Fq "WRTBAK_FIRSTBOOT_AUTO_ENABLED: '0'" "$DEDICATED"
grep -Fq 'WRTBAK_DEVICE_ALIAS: home-re-cs-07' "$DEDICATED"

if grep -Fq 'secrets: inherit' "$DEDICATED"; then
	echo "dedicated workflow inherits all secrets"
	exit 1
fi
for secret in WRTBAK_R2_ENDPOINT WRTBAK_R2_REGION WRTBAK_R2_BUCKET WRTBAK_R2_PREFIX WRTBAK_R2_ACCESS_KEY_ID WRTBAK_R2_SECRET_ACCESS_KEY; do
	grep -Fq "$secret: \${{ secrets.$secret }}" "$DEDICATED"
done
if grep -Eq 'HEADSCALE|DROPBEAR|SSH|PROXY_URL|WRT_PACKAGE:|WRT_TEST:' "$DEDICATED"; then
	echo "dedicated workflow forwards forbidden controls or secrets"
	exit 1
fi

echo "RE-CS-07 workflow guards passed"
