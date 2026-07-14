#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QCA_612="$ROOT_DIR/.github/workflows/QCA-6.12-VIKINGYFY.yml"
QCA_618="$ROOT_DIR/.github/workflows/QCA-6.18-VIKINGYFY.yml"
AUTO_CLEAN="$ROOT_DIR/.github/workflows/Auto-Clean.yml"
WRT_CORE="$ROOT_DIR/.github/workflows/WRT-CORE.yml"

[ -f "$QCA_612" ] || { echo "missing QCA-6.12 workflow"; exit 1; }
[ -f "$QCA_618" ] || { echo "missing QCA-6.18 workflow"; exit 1; }
[ -f "$AUTO_CLEAN" ] || { echo "missing Auto-Clean workflow"; exit 1; }
[ -f "$WRT_CORE" ] || { echo "missing WRT-CORE workflow"; exit 1; }

grep -q "定时编译已迁移到 QCA-6.18-VIKINGYFY" "$QCA_612" || {
  echo "QCA-6.12 workflow does not document the schedule migration"
  exit 1
}

if grep -q "cron: '0 1 \\* \\* \\*'" "$QCA_612"; then
  echo "QCA-6.12 workflow still has the daily scheduled build"
  exit 1
fi

if grep -q "cron: '0 1 \\* \\* \\*'" "$QCA_618"; then
  echo "QCA-6.18 workflow still has the daily scheduled build"
  exit 1
fi

if grep -q "workflow_run:" "$QCA_618"; then
  echo "QCA-6.18 workflow still has the Auto-Clean workflow_run trigger"
  exit 1
fi

grep -q "secrets: inherit" "$QCA_618" || {
  echo "QCA-6.18 workflow does not pass secrets into WRT-CORE"
  exit 1
}

grep -q "Scripts/HeadscaleAutoEnroll.sh" "$WRT_CORE" || {
  echo "WRT-CORE does not inject Headscale auto-enroll settings"
  exit 1
}

if grep -q "TARGET_PREFIX='QCA-6.18-VIKINGYFY-AUTO-'" "$AUTO_CLEAN"; then
  echo "Auto-Clean still targets QCA-6.18 auto-build releases"
  exit 1
fi

if grep -q "TARGET_PREFIX='QCA-6.12-VIKINGYFY-AUTO-'" "$AUTO_CLEAN"; then
  echo "Auto-Clean still targets QCA-6.12 auto-build releases"
  exit 1
fi

echo "QCA-6.18 manual-only build trigger test passed"
