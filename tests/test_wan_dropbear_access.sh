#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/Scripts/ConfigureWanDropbearAccess.sh"
WRT_CORE="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
WORKFLOWS=(
  "$ROOT_DIR/.github/workflows/QCA-6.18-VIKINGYFY.yml"
  "$ROOT_DIR/.github/workflows/QCA-6.12-VIKINGYFY.yml"
  "$ROOT_DIR/.github/workflows/QCA-6.12-LiBwrt.yml"
)

[ -f "$SCRIPT" ] || { echo "missing WAN Dropbear configurator"; exit 1; }
[ -f "$WRT_CORE" ] || { echo "missing WRT-CORE workflow"; exit 1; }

[ "$(git ls-files --stage -- "$SCRIPT" | awk '{print $1}')" = "100755" ] || {
  echo "WAN Dropbear configurator is not executable"
  exit 1
}

grep -q 'WRT_WAN_SSH:' "$WRT_CORE" || {
  echo "WRT-CORE does not expose WRT_WAN_SSH"
  exit 1
}

grep -q 'ConfigureWanDropbearAccess.sh' "$WRT_CORE" || {
  echo "WRT-CORE does not call the WAN Dropbear configurator"
  exit 1
}

for workflow in "${WORKFLOWS[@]}"; do
  [ -f "$workflow" ] || { echo "missing workflow $workflow"; exit 1; }
  grep -q 'WAN_SSH:' "$workflow" || {
    echo "$workflow does not expose WAN_SSH"
    exit 1
  }
  grep -q 'WAN_SSH_PORT:' "$workflow" || {
    echo "$workflow does not expose WAN_SSH_PORT"
    exit 1
  }
  grep -q 'WAN_SSH_SOURCE:' "$workflow" || {
    echo "$workflow does not expose WAN_SSH_SOURCE"
    exit 1
  }
  grep -q 'WRT_WAN_SSH:' "$workflow" || {
    echo "$workflow does not pass WRT_WAN_SSH"
    exit 1
  }
done

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

bash "$SCRIPT" "$WORK_DIR/disabled" false 52022 203.0.113.10/32 >"$WORK_DIR/disabled.log"
[ ! -e "$WORK_DIR/disabled/etc/uci-defaults/89-wan-dropbear-access" ] || {
  echo "disabled WAN SSH should not create a uci-defaults script"
  exit 1
}

bash "$SCRIPT" "$WORK_DIR/enabled" true 52022 203.0.113.10/32 >"$WORK_DIR/enabled.log"
DEFAULTS="$WORK_DIR/enabled/etc/uci-defaults/89-wan-dropbear-access"
[ -x "$DEFAULTS" ] || {
  echo "enabled WAN SSH did not create an executable uci-defaults script"
  exit 1
}

grep -q "WAN_SSH_PORT='52022'" "$DEFAULTS" || {
  echo "WAN SSH defaults script did not preserve the requested port"
  exit 1
}

grep -q "WAN_SSH_SOURCE='203.0.113.10/32'" "$DEFAULTS" || {
  echo "WAN SSH defaults script did not preserve the source CIDR"
  exit 1
}

grep -q "dropbear.main.Port=\"\\\$WAN_SSH_PORT\"" "$DEFAULTS" || {
  echo "WAN SSH defaults script does not configure Dropbear port"
  exit 1
}

grep -q "firewall.wan_dropbear_ssh.src='wan'" "$DEFAULTS" || {
  echo "WAN SSH defaults script does not bind the firewall rule to wan"
  exit 1
}

grep -q "firewall.wan_dropbear_ssh.dest_port=\"\\\$WAN_SSH_PORT\"" "$DEFAULTS" || {
  echo "WAN SSH defaults script does not open the requested port"
  exit 1
}

grep -q "firewall.wan_dropbear_ssh.src_ip=\"\\\$WAN_SSH_SOURCE\"" "$DEFAULTS" || {
  echo "WAN SSH defaults script does not optionally restrict source IP"
  exit 1
}

if bash "$SCRIPT" "$WORK_DIR/bad-port" true 0 "" >/dev/null 2>&1; then
  echo "WAN SSH configurator accepted an invalid port"
  exit 1
fi

if bash "$SCRIPT" "$WORK_DIR/bad-source" true 22 "203.0.113.10/32;reboot" >/dev/null 2>&1; then
  echo "WAN SSH configurator accepted an unsafe source string"
  exit 1
fi

echo "WAN Dropbear access guard passed"
