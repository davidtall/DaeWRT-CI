#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/CPE-5G.yml"
CORE="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
CONFIG="$ROOT_DIR/Config/IPQ60XX-706-NOWIFI.txt"
SHA='0bad892975fe49fd180f99b414a7f168bb694dd7'

grep -A5 '^      BUILD_BASELINE_A:' "$WORKFLOW" | grep -Eq "default: ('false'|false)" || {
  echo 'CPE workflow must default BUILD_BASELINE_A to false'
  exit 1
}

grep -A3 '^  baseline_a:' "$WORKFLOW" | grep -q 'if:.*inputs.BUILD_BASELINE_A' || {
  echo 'A must run only when BUILD_BASELINE_A is explicitly enabled'
  exit 1
}

[ "$(grep -c 'WRT_CONFIG: IPQ60XX-706-NOWIFI' "$WORKFLOW")" -eq 2 ] || {
  echo 'CPE A/B controls must both use the 7.06 IPQ60XX-NOWIFI config'
  exit 1
}

grep -q 'QCA-6.18-VIKINGYFY-IPQ60XX-NOWIFI_26.07.06-12.47.00' "$CONFIG" || {
  echo '7.06 NOWIFI config provenance is missing'
  exit 1
}

[ "$(grep -c '^CONFIG_TARGET_DEVICE_.*=y$' "$CONFIG")" -eq 1 ] &&
  grep -q '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y$' "$CONFIG" || {
  echo 'controlled config must build only jdcloud_re-ss-01'
  exit 1
}

for job in baseline_a cpe_overlay_b; do
  grep -q "^  $job:" "$WORKFLOW" || {
    echo "missing controlled build job: $job"
    exit 1
  }
done

[ "$(grep -c "WRT_COMMIT: $SHA" "$WORKFLOW")" -eq 2 ] || {
  echo 'A and B must use the same immutable 7.06 source SHA'
  exit 1
}

grep -A35 '^  baseline_a:' "$WORKFLOW" | grep -q 'WRT_CPE_5G: false' || {
  echo 'A must not include the CPE network overlay'
  exit 1
}

grep -A35 '^  cpe_overlay_b:' "$WORKFLOW" | grep -q 'WRT_CPE_5G: true' || {
  echo 'B must include the CPE network overlay'
  exit 1
}

grep -A35 '^  baseline_a:' "$WORKFLOW" | grep -q 'WRT_FEATURE_OVERLAY: false' || {
  echo 'A must disable Lucky/Tailscale/Headscale/wrtbak feature overlays'
  exit 1
}

grep -A35 '^  cpe_overlay_b:' "$WORKFLOW" | grep -q 'WRT_FEATURE_OVERLAY: true' || {
  echo 'B must enable Lucky/Tailscale/Headscale/wrtbak feature overlays'
  exit 1
}

grep -A4 '^      WRT_FEATURE_OVERLAY:' "$CORE" | grep -q 'type: boolean' || {
  echo 'WRT-CORE must expose a boolean feature-overlay control'
  exit 1
}

for required in 'missing ${WRT_REQUIRED_DEVICE} factory image' 'missing ${WRT_REQUIRED_DEVICE} sysupgrade image' 'metadata.json' 'SHA256SUMS'; do
  grep -Fq "$required" "$CORE" || {
    echo "WRT-CORE is missing the CPE artifact gate: $required"
    exit 1
  }
done

echo 'CPE 7.06 controlled A/B build test passed'
