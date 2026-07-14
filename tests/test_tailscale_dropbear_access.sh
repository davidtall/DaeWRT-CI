#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULTS="$ROOT_DIR/files/etc/uci-defaults/90-tailscale-dropbear-access"
INJECTOR="$ROOT_DIR/Scripts/DropbearAuthorizedKeys.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
DOC="$ROOT_DIR/docs/headscale-auto-enroll.md"
AGENTS="$ROOT_DIR/AGENTS.md"

[ -f "$DEFAULTS" ] || { echo "missing tailscale Dropbear access defaults"; exit 1; }
[ -f "$INJECTOR" ] || { echo "missing Dropbear authorized_keys CI injector"; exit 1; }
[ -f "$DOC" ] || { echo "missing Headscale auto-enroll docs"; exit 1; }
[ -f "$AGENTS" ] || { echo "missing AGENTS.md"; exit 1; }

[ "$(git ls-files --stage -- "$DEFAULTS" | awk '{print $1}')" = "100755" ] || {
  echo "tailscale Dropbear defaults script is not marked executable"
  exit 1
}

[ "$(git ls-files --stage -- "$INJECTOR" | awk '{print $1}')" = "100755" ] || {
  echo "Dropbear authorized_keys injector is not marked executable"
  exit 1
}

grep -q "uci -q delete network.tailscale" "$DEFAULTS" || {
  echo "defaults must not let netifd manage tailscale0"
  exit 1
}

grep -q "firewall.tailscale.device='tailscale0'" "$DEFAULTS" || {
  echo "defaults must bind the firewall zone to device tailscale0"
  exit 1
}

grep -q "firewall.tailscale.input='ACCEPT'" "$DEFAULTS" || {
  echo "tailscale zone must allow input to the router"
  exit 1
}

grep -q "firewall.tailscale.forward='REJECT'" "$DEFAULTS" || {
  echo "tailscale zone must reject forwarding by default"
  exit 1
}

grep -q "dropbear.main.DirectInterface" "$DEFAULTS" || {
  echo "defaults must remove Dropbear DirectInterface binding"
  exit 1
}

grep -q "dropbear.main.Interface" "$DEFAULTS" || {
  echo "defaults must remove Dropbear Interface binding"
  exit 1
}

grep -q "OPENWRT_DROPBEAR_AUTHORIZED_KEYS" "$WORKFLOW" || {
  echo "workflow does not expose optional Dropbear authorized_keys material"
  exit 1
}

grep -q "Scripts/DropbearAuthorizedKeys.sh" "$WORKFLOW" || {
  echo "workflow does not call the Dropbear authorized_keys injector"
  exit 1
}

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

TEST_KEY_1="ssh-rsa AAAATESTDROPBEARKEY1 test-one@example.invalid"
TEST_KEY_2="ssh-ed25519 AAAATESTDROPBEARKEY2 test-two@example.invalid"
INJECT_LOG="$WORK_DIR/inject.log"

OPENWRT_DROPBEAR_AUTHORIZED_KEYS="$(printf '%s\n%s\n' "$TEST_KEY_1" "$TEST_KEY_2")" \
  bash "$INJECTOR" "$WORK_DIR" >"$INJECT_LOG"

[ -f "$WORK_DIR/etc/dropbear/authorized_keys" ] || {
  echo "injector did not create authorized_keys"
  exit 1
}

grep -qxF "$TEST_KEY_1" "$WORK_DIR/etc/dropbear/authorized_keys" || {
  echo "injector did not preserve the first public key"
  exit 1
}

grep -qxF "$TEST_KEY_2" "$WORK_DIR/etc/dropbear/authorized_keys" || {
  echo "injector did not preserve the second public key"
  exit 1
}

if grep -q "$TEST_KEY_1" "$INJECT_LOG" || grep -q "$TEST_KEY_2" "$INJECT_LOG"; then
  echo "injector leaked authorized_keys material to logs"
  exit 1
fi

if grep -R --exclude-dir=.git -n -E 'BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY' "$ROOT_DIR" >/dev/null; then
  echo "repository contains a private SSH key"
  exit 1
fi

grep -q 'ordinary SSH to the router over its Tailscale IP' "$DOC" || {
  echo "docs do not describe ordinary SSH over the Tailscale IP"
  exit 1
}

grep -q 'Dropbear over Tailscale' "$AGENTS" || {
  echo "AGENTS.md does not document Dropbear over Tailscale"
  exit 1
}

echo "tailscale Dropbear access test passed"
