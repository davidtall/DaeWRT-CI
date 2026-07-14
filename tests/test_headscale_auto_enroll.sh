#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/files/etc/config/headscale_auto_enroll"
SCRIPT="$ROOT_DIR/files/usr/sbin/headscale-auto-enroll"
INIT="$ROOT_DIR/files/etc/init.d/headscale-auto-enroll"
DEFAULTS="$ROOT_DIR/files/etc/uci-defaults/94-headscale-auto-enroll"
HOTPLUG="$ROOT_DIR/files/etc/hotplug.d/iface/95-headscale-auto-enroll"
CI_INJECTOR="$ROOT_DIR/Scripts/HeadscaleAutoEnroll.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
CALLER_WORKFLOWS=(
  "$ROOT_DIR/.github/workflows/QCA-6.12-LiBwrt.yml"
  "$ROOT_DIR/.github/workflows/QCA-6.12-VIKINGYFY.yml"
  "$ROOT_DIR/.github/workflows/QCA-6.18-VIKINGYFY.yml"
)
DOC="$ROOT_DIR/docs/headscale-auto-enroll.md"
AGENTS="$ROOT_DIR/AGENTS.md"

[ -f "$CONFIG" ] || { echo "missing headscale auto-enroll config"; exit 1; }
[ -f "$SCRIPT" ] || { echo "missing headscale auto-enroll script"; exit 1; }
[ -f "$INIT" ] || { echo "missing headscale auto-enroll init script"; exit 1; }
[ -f "$DEFAULTS" ] || { echo "missing headscale auto-enroll uci-defaults"; exit 1; }
[ -f "$HOTPLUG" ] || { echo "missing headscale auto-enroll hotplug retry hook"; exit 1; }
[ -f "$CI_INJECTOR" ] || { echo "missing headscale auto-enroll CI injector"; exit 1; }
[ -f "$DOC" ] || { echo "missing headscale auto-enroll docs"; exit 1; }
[ -f "$AGENTS" ] || { echo "missing AGENTS.md"; exit 1; }

[ "$(git ls-files --stage -- "$SCRIPT" | awk '{print $1}')" = "100755" ] || {
  echo "headscale auto-enroll script is not marked executable"
  exit 1
}

[ "$(git ls-files --stage -- "$INIT" | awk '{print $1}')" = "100755" ] || {
  echo "headscale auto-enroll init script is not marked executable"
  exit 1
}

[ "$(git ls-files --stage -- "$CI_INJECTOR" | awk '{print $1}')" = "100755" ] || {
  echo "headscale auto-enroll CI injector is not marked executable"
  exit 1
}

tr -d '\r' < "$CONFIG" | grep -q "^	option enabled '0'$" || {
  echo "headscale auto-enroll must be disabled by default"
  exit 1
}

grep -q "option login_server 'https://headscale.jmsu.top'" "$CONFIG" || {
  echo "headscale login server default is missing"
  exit 1
}

grep -q "option auth_key_file '/etc/tailscale/headscale.authkey'" "$CONFIG" || {
  echo "headscale auth key file default is missing"
  exit 1
}

grep -q "option hostname_override ''" "$CONFIG" || {
  echo "headscale hostname override default is missing"
  exit 1
}

grep -q "option accept_dns '0'" "$CONFIG" || {
  echo "headscale auto-enroll must not accept Tailscale DNS by default"
  exit 1
}

grep -q "option accept_routes '0'" "$CONFIG" || {
  echo "headscale auto-enroll must not accept routes by default"
  exit 1
}

grep -q "option restore_gate_file '/root/wrtbak/firstboot/gate.json'" "$CONFIG" || {
  echo "headscale auto-enroll does not declare the wrtbak recovery gate"
  exit 1
}

grep -q "option restore_gate_attempts '90'" "$CONFIG" || {
  echo "headscale auto-enroll does not bound the wrtbak gate wait"
  exit 1
}

grep -q -- '--accept-dns=' "$SCRIPT" || {
  echo "script does not pass accept-dns explicitly"
  exit 1
}

grep -q -- '--ssh=' "$SCRIPT" || {
  echo "script does not enable configurable Tailscale SSH"
  exit 1
}

grep -q 'apply_runtime_preferences' "$SCRIPT" || {
  echo "script does not re-apply runtime preferences to already-enrolled nodes"
  exit 1
}

grep -q 'wait_for_wrtbak_gate' "$SCRIPT" || {
  echo "script does not wait for the wrtbak firstboot decision"
  exit 1
}

grep -q 'reload_recovered_state' "$SCRIPT" || {
  echo "script does not reload a recovered Tailscale state"
  exit 1
}

grep -q 'acquire_enroll_lock' "$SCRIPT" || {
  echo "script does not serialize init and hotplug enrollment attempts"
  exit 1
}

grep -q 'reboot_pending' "$SCRIPT" || {
  echo "script does not keep enrollment closed while restore reboot is pending"
  exit 1
}

grep -q 'hostname_override="$(cfg hostname_override' "$SCRIPT" || {
  echo "script does not read the hostname override"
  exit 1
}

grep -q 'build_hostname "$hostname_override" "$hostname_prefix"' "$SCRIPT" || {
  echo "script does not prefer hostname_override before hostname_prefix"
  exit 1
}

grep -q 'tailscale set' "$SCRIPT" || {
  echo "script does not use tailscale set for already-enrolled nodes"
  exit 1
}

grep -q 'tailscale already enrolled; runtime preferences applied' "$SCRIPT" || {
  echo "script does not log runtime preference application on already-enrolled nodes"
  exit 1
}

grep -q 'rm -f "$auth_key_file"' "$SCRIPT" || {
  echo "script does not remove the auth key file after successful enrollment"
  exit 1
}

grep -q '/etc/init.d/headscale-auto-enroll enable' "$DEFAULTS" || {
  echo "uci-defaults does not enable headscale auto-enroll service"
  exit 1
}

grep -q '\[ "\$ACTION" = "ifup" \]' "$HOTPLUG" || {
  echo "hotplug hook does not gate itself on interface ifup"
  exit 1
}

grep -q '/etc/init.d/headscale-auto-enroll restart' "$HOTPLUG" || {
  echo "hotplug hook does not retry headscale auto-enroll"
  exit 1
}

grep -q 'HEADSCALE_OPENWRT_AUTHKEY' "$WORKFLOW" || {
  echo "workflow does not expose the optional Headscale OpenWrt auth key secret"
  exit 1
}

grep -q 'Scripts/HeadscaleAutoEnroll.sh' "$WORKFLOW" || {
  echo "workflow does not call the Headscale auto-enroll injector"
  exit 1
}

for caller_workflow in "${CALLER_WORKFLOWS[@]}"; do
  grep -q 'secrets: inherit' "$caller_workflow" || {
    echo "$(basename "$caller_workflow") does not pass repository secrets to WRT-CORE"
    exit 1
  }
done

grep -q 'auth key redacted' "$CI_INJECTOR" || {
  echo "CI injector does not redact the auth key in logs"
  exit 1
}

grep -q 'set_config_option accept_dns 0' "$CI_INJECTOR" || {
  echo "CI injector does not force accept_dns off"
  exit 1
}

grep -q 'derive_headscale_hostname' "$CI_INJECTOR" || {
  echo "CI injector does not derive a stable Headscale hostname"
  exit 1
}

grep -q 'set_config_option hostname_override' "$CI_INJECTOR" || {
  echo "CI injector does not write hostname_override"
  exit 1
}

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/etc/config"
cp "$CONFIG" "$WORK_DIR/etc/config/headscale_auto_enroll"
TEST_AUTH_KEY="hskey-auth-""testredacted"
INJECT_LOG="$WORK_DIR/inject.log"
HEADSCALE_OPENWRT_AUTHKEY="$TEST_AUTH_KEY" \
HEADSCALE_OPENWRT_ACCEPT_ROUTES=1 \
HEADSCALE_OPENWRT_ADVERTISE_ROUTES=192.168.12.0/24 \
WRT_NAME=DAE-WRT \
WRT_IP=192.168.12.1 \
bash "$CI_INJECTOR" "$WORK_DIR" >"$INJECT_LOG"

grep -q "option enabled '1'" "$WORK_DIR/etc/config/headscale_auto_enroll" || {
  echo "CI injector does not enable auto-enroll when the secret is present"
  exit 1
}

grep -q "option accept_dns '0'" "$WORK_DIR/etc/config/headscale_auto_enroll" || {
  echo "CI injector does not keep accept_dns disabled"
  exit 1
}

grep -q "option accept_routes '1'" "$WORK_DIR/etc/config/headscale_auto_enroll" || {
  echo "CI injector does not honor accept-routes override"
  exit 1
}

grep -q "option advertise_routes '192.168.12.0/24'" "$WORK_DIR/etc/config/headscale_auto_enroll" || {
  echo "CI injector does not honor advertise-routes override"
  exit 1
}

grep -q "option hostname_override 'openwrt-dae-wrt-12'" "$WORK_DIR/etc/config/headscale_auto_enroll" || {
  echo "CI injector does not derive hostname_override from WRT_NAME and WRT_IP"
  exit 1
}

[ "$(cat "$WORK_DIR/etc/tailscale/headscale.authkey")" = "$TEST_AUTH_KEY" ] || {
  echo "CI injector does not write the auth key file"
  exit 1
}

if grep -q "$TEST_AUTH_KEY" "$INJECT_LOG"; then
  echo "CI injector leaked the auth key to logs"
  exit 1
fi

SECOND_WORK_DIR="$(mktemp -d)"
mkdir -p "$SECOND_WORK_DIR/etc/config"
cp "$CONFIG" "$SECOND_WORK_DIR/etc/config/headscale_auto_enroll"
HEADSCALE_OPENWRT_AUTHKEY="$TEST_AUTH_KEY" \
HEADSCALE_OPENWRT_HOSTNAME="Lab Router 12" \
bash "$CI_INJECTOR" "$SECOND_WORK_DIR" >/dev/null

grep -q "option hostname_override 'lab-router-12'" "$SECOND_WORK_DIR/etc/config/headscale_auto_enroll" || {
  echo "CI injector does not honor and sanitize explicit HEADSCALE_OPENWRT_HOSTNAME"
  exit 1
}

grep -q 'Do not commit an auth key' "$DOC" || {
  echo "docs do not warn against committed auth keys"
  exit 1
}

grep -q 'firmware artifact contains the enrollment key' "$DOC" || {
  echo "docs do not warn that private firmware artifacts contain the enrollment key"
  exit 1
}

grep -q 'Dropbear' "$AGENTS" || {
  echo "AGENTS.md does not document Dropbear as rescue path"
  exit 1
}

grep -q 'wrtbak recovery gate' "$DOC" || {
  echo "docs do not explain the wrtbak recovery gate"
  exit 1
}

if grep -R --exclude-dir=.git -n -E 'hskey-auth-[A-Za-z0-9_-]+' "$ROOT_DIR" >/dev/null; then
  echo "repository contains a real-looking Headscale auth key"
  exit 1
fi

echo "headscale auto-enroll test passed"
