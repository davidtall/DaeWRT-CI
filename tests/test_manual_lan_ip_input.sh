#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QCA_612="$ROOT_DIR/.github/workflows/QCA-6.12-VIKINGYFY.yml"
QCA_618="$ROOT_DIR/.github/workflows/QCA-6.18-VIKINGYFY.yml"
QCA_LIBWRT="$ROOT_DIR/.github/workflows/QCA-6.12-LiBwrt.yml"
WRT_CORE="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
VALIDATOR="$ROOT_DIR/Scripts/ValidateLanIp.sh"

for workflow in "$QCA_612" "$QCA_618" "$QCA_LIBWRT"; do
  [ -f "$workflow" ] || { echo "missing workflow $workflow"; exit 1; }

  grep -q "LAN_IP:" "$workflow" || {
    echo "$workflow missing workflow_dispatch LAN_IP input"
    exit 1
  }

  grep -q "default: '192.168.10.1'" "$workflow" || {
    echo "$workflow missing default LAN IP 192.168.10.1"
    exit 1
  }

  grep -q "WRT_IP: \${{ inputs.LAN_IP || '192.168.10.1' }}" "$workflow" || {
    echo "$workflow does not pass LAN_IP into WRT-CORE with default fallback"
    exit 1
  }
done

grep -q "Scripts/ValidateLanIp.sh" "$WRT_CORE" || {
  echo "WRT-CORE does not validate WRT_IP before building"
  exit 1
}

[ -x "$VALIDATOR" ] || {
  echo "missing executable LAN IP validator"
  exit 1
}

for ip in 192.168.10.1 192.168.12.1 10.0.70.3 172.16.0.1 172.31.255.254; do
  "$VALIDATOR" "$ip" >/dev/null || {
    echo "validator rejected valid LAN IP $ip"
    exit 1
  }
done

for ip in "" 192.168.10.0 192.168.10.255 172.15.0.1 172.32.0.1 100.64.0.17 8.8.8.8 192.168.1 192.168.1.1/24 "192.168.1.1;echo x"; do
  if "$VALIDATOR" "$ip" >/dev/null 2>&1; then
    echo "validator accepted invalid LAN IP $ip"
    exit 1
  fi
done

echo "manual LAN IP input test passed"
