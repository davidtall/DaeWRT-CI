#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/Scripts/PrivateFirmwareGuard.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"

[ -f "$SCRIPT" ] || { echo "missing PrivateFirmwareGuard.sh"; exit 1; }
[ "$(git ls-files --stage -- "$SCRIPT" | awk '{print $1}')" = "100755" ] || {
	echo "PrivateFirmwareGuard.sh is not marked executable"
	exit 1
}

grep -q 'Scripts/PrivateFirmwareGuard.sh' "$WORKFLOW" || {
	echo "WRT-CORE.yml does not call the private firmware guard"
	exit 1
}

grep -q "if: env.WRT_PRIVATE_BUILD != 'true'" "$WORKFLOW" || {
	echo "Release Firmware step is not gated for private builds"
	exit 1
}

grep -q 'WRT_ARTIFACT_PRIVACY_SUFFIX' "$WORKFLOW" || {
	echo "artifact name does not include privacy suffix"
	exit 1
}

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

bash "$SCRIPT" "$WORK_DIR/empty" >"$WORK_DIR/public.env" 2>"$WORK_DIR/public.log"
grep -qx 'WRT_PRIVATE_BUILD=false' "$WORK_DIR/public.env" || {
	echo "empty overlay should not be private"
	exit 1
}

mkdir -p "$WORK_DIR/wrtbak/etc/config"
cat >"$WORK_DIR/wrtbak/etc/config/wrtbak" <<'EOT'
config wrtbak 'main'
	option proxy_url ''

config remote 's3'
	option access_key 'test-access'
	option secret_key 'test-secret'
EOT

bash "$SCRIPT" "$WORK_DIR/wrtbak" >"$WORK_DIR/wrtbak.env" 2>"$WORK_DIR/wrtbak.log"
grep -qx 'WRT_PRIVATE_BUILD=true' "$WORK_DIR/wrtbak.env" || {
	echo "wrtbak credentials should mark firmware private"
	exit 1
}
grep -q 'wrtbak-r2-secret-key' "$WORK_DIR/wrtbak.env" || {
	echo "wrtbak secret reason is missing"
	exit 1
}
if grep -q 'test-secret' "$WORK_DIR/wrtbak.log"; then
	echo "guard leaked wrtbak secret to logs"
	exit 1
fi

mkdir -p "$WORK_DIR/headscale/etc/tailscale"
printf '%s\n' 'hskey-auth-''testredacted' >"$WORK_DIR/headscale/etc/tailscale/headscale.authkey"
bash "$SCRIPT" "$WORK_DIR/headscale" >"$WORK_DIR/headscale.env" 2>/dev/null
grep -qx 'WRT_PRIVATE_BUILD=true' "$WORK_DIR/headscale.env" || {
	echo "headscale authkey should mark firmware private"
	exit 1
}
grep -q 'headscale-authkey' "$WORK_DIR/headscale.env" || {
	echo "headscale private reason is missing"
	exit 1
}

mkdir -p "$WORK_DIR/dropbear/etc/dropbear"
printf '%s\n' 'ssh-ed25519 AAAATEST public@example.invalid' >"$WORK_DIR/dropbear/etc/dropbear/authorized_keys"
bash "$SCRIPT" "$WORK_DIR/dropbear" >"$WORK_DIR/dropbear.env" 2>/dev/null
grep -qx 'WRT_PRIVATE_BUILD=false' "$WORK_DIR/dropbear.env" || {
	echo "public Dropbear authorized_keys alone should not mark firmware private"
	exit 1
}

echo "wrtbak private firmware guard test passed"
