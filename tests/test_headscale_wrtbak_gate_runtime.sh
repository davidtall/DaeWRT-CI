#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/files/usr/sbin/headscale-auto-enroll"
WORK_DIR="$(mktemp -d)"
BIN_DIR="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/calls.log"
GATE_FILE="$WORK_DIR/gate.json"
LOCK_DIR="$WORK_DIR/enroll.lock"

cleanup() {
	rm -rf "$WORK_DIR"
}
trap cleanup EXIT
mkdir -p "$BIN_DIR"

cat >"$BIN_DIR/uci" <<'EOF'
#!/bin/sh
for arg in "$@"; do key=$arg; done
case "$key" in
	headscale_auto_enroll.main.enabled) printf '1\n' ;;
	headscale_auto_enroll.main.login_server) printf 'https://headscale.example.invalid\n' ;;
	headscale_auto_enroll.main.auth_key_file) printf '%s/authkey\n' "$TEST_ROOT" ;;
	headscale_auto_enroll.main.hostname_override) printf 'test-router\n' ;;
	headscale_auto_enroll.main.hostname_prefix) printf 'openwrt\n' ;;
	headscale_auto_enroll.main.ssh) printf '1\n' ;;
	headscale_auto_enroll.main.accept_dns) printf '0\n' ;;
	headscale_auto_enroll.main.accept_routes) printf '0\n' ;;
	headscale_auto_enroll.main.max_attempts) printf '1\n' ;;
	headscale_auto_enroll.main.retry_interval) printf '0\n' ;;
	headscale_auto_enroll.main.restore_gate_file) printf '%s/gate.json\n' "$TEST_ROOT" ;;
	headscale_auto_enroll.main.restore_gate_attempts) printf '2\n' ;;
	headscale_auto_enroll.main.restore_gate_interval) printf '0\n' ;;
	headscale_auto_enroll.main.delete_auth_key_file) printf '0\n' ;;
	wrtbak.main.firstboot_auto_enabled) printf '1\n' ;;
	*) exit 1 ;;
esac
EOF

cat >"$BIN_DIR/tailscale" <<'EOF'
#!/bin/sh
command=$1
shift || true
case "$command" in
	status)
		if [ -f "$TEST_ROOT/state-running" ]; then
			printf '{"BackendState":"Running"}\n'
		else
			printf '{"BackendState":"Stopped"}\n'
		fi
		;;
	up|set)
		printf '%s %s\n' "$command" "$*" >>"$TEST_LOG"
		;;
esac
EOF

cat >"$BIN_DIR/tailscale-init" <<'EOF'
#!/bin/sh
printf 'init %s\n' "$*" >>"$TEST_LOG"
if [ "${1:-}" = restart ]; then
	touch "$TEST_ROOT/state-running"
fi
EOF

cat >"$BIN_DIR/sleep" <<'EOF'
#!/bin/sh
printf 'sleep %s\n' "$*" >>"$TEST_LOG"
if [ "${TEST_SCENARIO:-}" = gate-transition ]; then
	printf '{"state":"no_backup"}\n' >"$TEST_ROOT/gate.json"
fi
EOF

cat >"$BIN_DIR/ip" <<'EOF'
#!/bin/sh
exit 0
EOF

cat >"$BIN_DIR/logger" <<'EOF'
#!/bin/sh
exit 0
EOF

chmod +x "$BIN_DIR"/*
printf 'test-auth-key\n' >"$WORK_DIR/authkey"
export PATH="$BIN_DIR:$PATH"
export TEST_ROOT="$WORK_DIR"
export TEST_LOG="$LOG_FILE"
export HEADSCALE_AUTO_ENROLL_LOCK_DIR="$LOCK_DIR"
export HEADSCALE_AUTO_ENROLL_TAILSCALE_INIT="$BIN_DIR/tailscale-init"
export HEADSCALE_AUTO_ENROLL_DONE_FILE="$WORK_DIR/auto-enroll.done"

# A pending recovery decision must be observed before a terminal no-backup
# decision allows registration.
printf '{"state":"pending"}\n' >"$GATE_FILE"
TEST_SCENARIO=gate-transition "$SCRIPT"
sleep_line=$(grep -n '^sleep ' "$LOG_FILE" | sed -n '1s/:.*//p')
up_line=$(grep -n '^up ' "$LOG_FILE" | sed -n '1s/:.*//p')
[ -n "$sleep_line" ] && [ -n "$up_line" ] && [ "$sleep_line" -lt "$up_line" ] || {
	echo "Headscale registered before wrtbak reached a terminal decision" >&2
	exit 1
}

# A restored state must be reloaded and reused without consuming the auth key.
: >"$LOG_FILE"
rm -f "$WORK_DIR/state-running" "$WORK_DIR/auto-enroll.done"
printf '{"state":"restored"}\n' >"$GATE_FILE"
TEST_SCENARIO=restored "$SCRIPT"
grep -q '^init restart$' "$LOG_FILE"
grep -q '^set ' "$LOG_FILE"
if grep -q '^up ' "$LOG_FILE"; then
	echo "Headscale created a new node instead of reusing restored state" >&2
	exit 1
fi

# An active lock represents the procd/hotplug peer and must suppress re-entry.
: >"$LOG_FILE"
rm -f "$WORK_DIR/state-running" "$WORK_DIR/auto-enroll.done"
mkdir -p "$LOCK_DIR"
printf '%s\n' "$$" >"$LOCK_DIR/pid"
TEST_SCENARIO=locked "$SCRIPT"
[ ! -s "$LOG_FILE" ] || {
	echo "concurrent Headscale enrollment was not suppressed" >&2
	exit 1
}

echo "headscale wrtbak gate runtime fixture passed"
