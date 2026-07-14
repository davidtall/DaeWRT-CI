#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CPE_WORKFLOW="$ROOT_DIR/.github/workflows/CPE-5G.yml"
CORE_WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
QCA_WORKFLOW="$ROOT_DIR/.github/workflows/QCA-6.18-VIKINGYFY.yml"
README="$ROOT_DIR/README.md"
AGENT_GUIDE="$ROOT_DIR/AGENTS.md"
CPE_DOC="$ROOT_DIR/docs/cpe-5g-preset.md"
VERIFIED_SOURCE_SHA='0bad892975fe49fd180f99b414a7f168bb694dd7'
ROLLBACK_SOURCE_SHA='42a1f64b5dbd2a99d05daca94ae5a87eebff59b4'
VERIFIED_RUN_ID='29160402065'
VERIFIED_B_ARTIFACT_SHA='bad3ff165840c982ed2ae337532ca456eb940560ae71665196cfa4245ce7631d'

grep -q "WRT_COMMIT: $VERIFIED_SOURCE_SHA" "$CPE_WORKFLOW" || {
  echo "CPE-5G does not pin the verified firmware source commit"
  exit 1
}

grep -A4 '^      WRT_COMMIT:' "$CORE_WORKFLOW" | grep -q 'type: string' || {
  echo "WRT-CORE does not declare the optional WRT_COMMIT string input"
  exit 1
}

grep -q '^  WRT_COMMIT: \${{inputs.WRT_COMMIT}}$' "$CORE_WORKFLOW" || {
  echo "WRT-CORE does not export the WRT_COMMIT input"
  exit 1
}

grep -Eq 'git .*fetch.*WRT_COMMIT' "$CORE_WORKFLOW" || {
  echo "WRT-CORE does not fetch the requested immutable source commit"
  exit 1
}

grep -q 'git checkout --detach.*WRT_COMMIT' "$CORE_WORKFLOW" || {
  echo "WRT-CORE does not checkout the requested source commit detached"
  exit 1
}

grep -q 'git rev-parse HEAD' "$CORE_WORKFLOW" || {
  echo "WRT-CORE does not resolve and verify the checked out source commit"
  exit 1
}

if grep -q "$VERIFIED_SOURCE_SHA" "$QCA_WORKFLOW"; then
  echo "ordinary QCA 6.18 builds must not inherit the CPE-only source pin"
  exit 1
fi

for document in "$README" "$AGENT_GUIDE" "$CPE_DOC"; do
  grep -q "$VERIFIED_SOURCE_SHA" "$document" || {
    echo "$(basename "$document") does not record the full verified source SHA"
    exit 1
  }
done

for document in "$README" "$CPE_DOC"; do
  grep -q "$VERIFIED_RUN_ID" "$document" || {
    echo "$(basename "$document") does not record the A/B real-device validation run"
    exit 1
  }
  grep -q "$VERIFIED_B_ARTIFACT_SHA" "$document" || {
    echo "$(basename "$document") does not record the verified B artifact digest"
    exit 1
  }
done

grep -q 'Linux.*6\.18\.37\|Linux kernel.*6\.18\.37' "$README" || {
  echo "README does not record the preferred Linux 6.18.37 baseline"
  exit 1
}

for document in "$README" "$AGENT_GUIDE" "$CPE_DOC"; do
  grep -q "$ROLLBACK_SOURCE_SHA" "$document" || {
    echo "$(basename "$document") does not retain the historical rollback SHA"
    exit 1
  }
  grep -q '6\.18\.35' "$document" || {
    echo "$(basename "$document") does not retain the historical rollback kernel"
    exit 1
  }
done

for component in qca-nss qca-nss-dp qca-nss-drv qca-nss-ecm qca-ssdk Qualcommax DTB factory; do
  grep -q "$component" "$README" || {
    echo "README does not track verified component: $component"
    exit 1
  }
done

grep -q '实机验证' "$AGENT_GUIDE" || {
  echo "AGENTS does not require real-device validation before baseline promotion"
  exit 1
}

grep -q '回退' "$AGENT_GUIDE" || {
  echo "AGENTS does not define the verified-baseline rollback rule"
  exit 1
}

echo "CPE verified source baseline test passed"
