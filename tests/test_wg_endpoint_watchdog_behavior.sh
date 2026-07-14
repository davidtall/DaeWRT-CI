#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$ROOT_DIR/package/wg-endpoint-watchdog"
REFRESH_SCRIPT="$PKG_DIR/files/usr/bin/wg-endpoint-refresh"
WATCHDOG_SCRIPT="$PKG_DIR/files/usr/bin/wg-endpoint-watchdog"
HOTPLUG_SCRIPT="$PKG_DIR/files/etc/hotplug.d/iface/99-wg-endpoint-watchdog"
TMP_DIR="$(mktemp -d)"
LOG_FILE="$TMP_DIR/calls.log"
STUB_DIR="$TMP_DIR/bin"
INIT_DIR="$TMP_DIR/init.d"
HOOK_DIR="$TMP_DIR/hooks"
FUNCTIONS_LIB="$TMP_DIR/functions.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$STUB_DIR" "$INIT_DIR" "$HOOK_DIR"
: > "$LOG_FILE"

cat > "$FUNCTIONS_LIB" <<'EOF'
config_load() {
  return 0
}

config_foreach() {
  callback="$1"
  type="$2"
  [ "$type" = "instance" ] || return 0
  "$callback" example
}

config_get() {
  __var="$1"
  __section="$2"
  __option="$3"
  __default="${4:-}"
  __value="$__default"

  case "$__option" in
    interface) __value="wg_test" ;;
    max_handshake_age) __value="${WG_TEST_MAX_HANDSHAKE_AGE:-600}" ;;
    boot_delay) __value="1" ;;
    wan_ifup_delay) __value="${WG_TEST_WAN_IFUP_DELAY:-1}" ;;
    refresh_dnsmasq) __value="1" ;;
    refresh_ddns_service) __value="${WG_TEST_DDNS_SERVICE:-ddns-go}" ;;
    endpoint_host_option) __value="network.wg_test_peer.endpoint_host" ;;
    proxy_bypass) __value="${WG_TEST_PROXY_BYPASS:-1}" ;;
    proxy_bypass_udp_sport) __value="${WG_TEST_PROXY_BYPASS_UDP_SPORT:-51820}" ;;
    pre_refresh_hook) __value="${WG_TEST_PRE_HOOK:-}" ;;
    post_refresh_hook) __value="${WG_TEST_POST_HOOK:-}" ;;
  esac

  eval "$__var=\$__value"
}

config_get_bool() {
  __var="$1"
  __section="$2"
  __option="$3"
  __default="${4:-0}"
  __value="$__default"

  case "$__option" in
    enabled) __value="${WG_TEST_ENABLED:-1}" ;;
    refresh_dnsmasq) __value="${WG_TEST_REFRESH_DNSMASQ:-1}" ;;
    proxy_bypass) __value="${WG_TEST_PROXY_BYPASS:-1}" ;;
  esac

  case "$__value" in
    1|on|true|yes|enabled) __value=1 ;;
    *) __value=0 ;;
  esac

  eval "$__var=\$__value"
}
EOF

cat > "$STUB_DIR/logger" <<'EOF'
#!/bin/sh
printf 'logger %s\n' "$*" >> "$WG_TEST_LOG"
if [ "$#" -gt 0 ] && [ "$1" = "-t" ]; then
  while IFS= read -r line; do
    printf 'logger-stdin %s\n' "$line" >> "$WG_TEST_LOG"
  done
fi
EOF

cat > "$STUB_DIR/sleep" <<'EOF'
#!/bin/sh
printf 'sleep %s\n' "$*" >> "$WG_TEST_LOG"
EOF

cat > "$STUB_DIR/ifdown" <<'EOF'
#!/bin/sh
printf 'ifdown %s\n' "$*" >> "$WG_TEST_LOG"
EOF

cat > "$STUB_DIR/ifup" <<'EOF'
#!/bin/sh
printf 'ifup %s\n' "$*" >> "$WG_TEST_LOG"
EOF

cat > "$STUB_DIR/ip" <<'EOF'
#!/bin/sh
if [ "$1" = "rule" ] && [ "$2" = "show" ]; then
  printf 'ip rule show\n' >> "$WG_TEST_LOG"
  if [ "${WG_TEST_RULE_EXISTS:-0}" = "1" ]; then
    echo "1000: from all ipproto udp sport 51820 lookup main"
  fi
  exit 0
fi

printf 'ip %s\n' "$*" >> "$WG_TEST_LOG"
EOF

cat > "$STUB_DIR/wg" <<'EOF'
#!/bin/sh
printf 'wg %s\n' "$*" >> "$WG_TEST_LOG"
if [ "$1" = "show" ] && [ "$3" = "endpoints" ]; then
  echo "peer endpoint.example.invalid:51820"
elif [ "$1" = "show" ] && [ "$3" = "latest-handshakes" ]; then
  if [ "${WG_TEST_LATEST_HANDSHAKE:-0}" != "__empty" ]; then
    echo "peer ${WG_TEST_LATEST_HANDSHAKE:-0}"
  fi
fi
EOF

cat > "$INIT_DIR/ddns-go" <<'EOF'
#!/bin/sh
printf 'init ddns-go %s\n' "$*" >> "$WG_TEST_LOG"
EOF

cat > "$INIT_DIR/dnsmasq" <<'EOF'
#!/bin/sh
printf 'init dnsmasq %s\n' "$*" >> "$WG_TEST_LOG"
EOF

cat > "$HOOK_DIR/pre" <<'EOF'
#!/bin/sh
printf 'pre-hook %s\n' "$*" >> "$WG_TEST_LOG"
EOF

cat > "$HOOK_DIR/post" <<'EOF'
#!/bin/sh
printf 'post-hook %s\n' "$*" >> "$WG_TEST_LOG"
EOF

chmod +x "$STUB_DIR"/* "$INIT_DIR"/* "$HOOK_DIR"/*

export PATH="$STUB_DIR:$PATH"
export WG_TEST_LOG="$LOG_FILE"
export WG_ENDPOINT_WATCHDOG_FUNCTIONS="$FUNCTIONS_LIB"
export WG_ENDPOINT_WATCHDOG_INIT_DIR="$INIT_DIR"
export WG_TEST_PRE_HOOK="$HOOK_DIR/pre"
export WG_TEST_POST_HOOK="$HOOK_DIR/post"

sh "$REFRESH_SCRIPT" example manual

grep -q '^pre-hook example manual wg_test$' "$LOG_FILE" || {
  echo "refresh did not execute the configured pre hook"
  exit 1
}

grep -q '^init ddns-go restart$' "$LOG_FILE" || {
  echo "refresh did not restart the configured optional DDNS service"
  exit 1
}

grep -q '^init dnsmasq restart$' "$LOG_FILE" || {
  echo "refresh did not restart dnsmasq when enabled"
  exit 1
}

grep -q '^ip rule add pref 1000 ipproto udp sport 51820 lookup main$' "$LOG_FILE" || {
  echo "refresh did not add the WireGuard UDP source-port bypass rule"
  exit 1
}

grep -q '^ifdown wg_test$' "$LOG_FILE" || {
  echo "refresh did not bring the WireGuard interface down"
  exit 1
}

grep -q '^ifup wg_test$' "$LOG_FILE" || {
  echo "refresh did not bring the WireGuard interface up"
  exit 1
}

grep -q '^post-hook example manual wg_test$' "$LOG_FILE" || {
  echo "refresh did not execute the configured post hook"
  exit 1
}

: > "$LOG_FILE"
WG_TEST_RULE_EXISTS=1 sh "$REFRESH_SCRIPT" example manual
! grep -q '^ip rule add pref 1000 ipproto udp sport 51820 lookup main$' "$LOG_FILE" || {
  echo "refresh duplicated an existing WireGuard UDP source-port bypass rule"
  exit 1
}

REFRESH_STUB="$TMP_DIR/refresh-stub"
cat > "$REFRESH_STUB" <<'EOF'
#!/bin/sh
printf 'refresh-stub %s\n' "$*" >> "$WG_TEST_LOG"
EOF
chmod +x "$REFRESH_STUB"
export WG_ENDPOINT_REFRESH_BIN="$REFRESH_STUB"

: > "$LOG_FILE"
WG_TEST_LATEST_HANDSHAKE=0 sh "$WATCHDOG_SCRIPT"
grep -q '^refresh-stub example watchdog$' "$LOG_FILE" || {
  echo "watchdog did not refresh a zero latest-handshake"
  exit 1
}

: > "$LOG_FILE"
WG_TEST_LATEST_HANDSHAKE=__empty sh "$WATCHDOG_SCRIPT"
grep -q '^refresh-stub example watchdog$' "$LOG_FILE" || {
  echo "watchdog did not refresh an empty latest-handshake output"
  exit 1
}

: > "$LOG_FILE"
WG_TEST_LATEST_HANDSHAKE="$(date +%s)" sh "$WATCHDOG_SCRIPT"
! grep -q '^refresh-stub example watchdog$' "$LOG_FILE" || {
  echo "watchdog refreshed a healthy WireGuard handshake"
  exit 1
}

: > "$LOG_FILE"
ACTION=ifup INTERFACE=wan sh "$HOTPLUG_SCRIPT"
/bin/sleep 1
grep -q '^refresh-stub example wan-ifup$' "$LOG_FILE" || {
  echo "hotplug did not schedule refresh on wan ifup"
  exit 1
}

: > "$LOG_FILE"
ACTION=ifup INTERFACE=lan sh "$HOTPLUG_SCRIPT"
/bin/sleep 1
! grep -q '^refresh-stub example wan-ifup$' "$LOG_FILE" || {
  echo "hotplug should ignore non-WAN interfaces"
  exit 1
}

echo "wg-endpoint-watchdog behavior test passed"
