#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT_DIR/.github/workflows/WRT-CORE.yml"

grep -A4 'WRT_SPLIT_DEVICE_ARTIFACTS:' "$CORE" | grep -Fq 'default: true'
grep -Fq 'WRT_SPLIT_DEVICE_ARTIFACTS: ${{inputs.WRT_SPLIT_DEVICE_ARTIFACTS}}' "$CORE"
grep -Fq 'Scripts/SplitFirmwareArtifacts.sh" ./upload ./artifact-groups' "$CORE"

split_guard="inputs.WRT_SPLIT_DEVICE_ARTIFACTS == true && env.WRT_PRIVATE_BUILD != 'true' && env.WRT_BUILD_ONLY != 'true' && env.WRT_TEST != 'true'"
combined_guard="inputs.WRT_SPLIT_DEVICE_ARTIFACTS == false || env.WRT_PRIVATE_BUILD == 'true' || env.WRT_BUILD_ONLY == 'true' || env.WRT_TEST == 'true'"
grep -Fq "if: $split_guard" "$CORE"
grep -Fq "if: $combined_guard" "$CORE"

for group in jdcloud_re-ss-01 jdcloud_re-cs-02 jdcloud_re-cs-07 other-devices; do
	grep -Fq "name: \${{env.CI_NAME}}-\${{env.WRT_CONFIG}}_\${{env.WRT_DATE}}-public-$group" "$CORE"
	grep -Fq "path: ./wrt/artifact-groups/$group/" "$CORE"
done

echo "WRT-CORE device artifact guards passed"
