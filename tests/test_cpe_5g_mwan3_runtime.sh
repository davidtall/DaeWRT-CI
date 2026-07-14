#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATOR="$ROOT_DIR/Scripts/ConfigureCpe5G.sh"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

OVERLAY="$WORK_DIR/overlay"
BIN_DIR="$WORK_DIR/bin"
STATE="$WORK_DIR/uci.state"
LOG="$WORK_DIR/uci.log"
mkdir -p "$OVERLAY" "$BIN_DIR"
"$GENERATOR" "$OVERLAY" true >/dev/null
RECONCILE="$OVERLAY/usr/libexec/cpe5g-mwan3-reconcile"
GATED="$OVERLAY/usr/libexec/cpe5g-mwan3-gated-reconcile"

cat >"$BIN_DIR/uci" <<'EOF'
#!/bin/sh
set -eu
quiet=0
if [ "${1:-}" = -q ]; then quiet=1; shift; fi
cmd="${1:-}"; shift || true
key="${1:-}"
case "$cmd" in
  get)
    value=$(sed -n "s|^${key}=||p" "$TEST_UCI_STATE" | tail -n 1)
    [ -n "$value" ] || { [ "$quiet" = 1 ] && exit 1; exit 1; }
    printf '%s\n' "$value"
    ;;
  show)
    if [ "$key" = mwan3 ]; then
      sed -n '/^mwan3\./p' "$TEST_UCI_STATE"
    else
      sed -n "\\|^${key}=|p; \\|^${key}\\.|p" "$TEST_UCI_STATE"
    fi
    ;;
  set)
    pair="$key"; name=${pair%%=*}; value=${pair#*=}; value=${value#\'}; value=${value%\'}
    sed -i "\\|^${name}=|d" "$TEST_UCI_STATE"
    printf '%s=%s\n' "$name" "$value" >>"$TEST_UCI_STATE"
    printf 'set %s\n' "$name" >>"$TEST_UCI_LOG"
    ;;
  delete)
    sed -i "\\|^${key}=|d; \\|^${key}\\.|d" "$TEST_UCI_STATE"
    printf 'delete %s\n' "$key" >>"$TEST_UCI_LOG"
    ;;
  add_list)
    pair="$key"; name=${pair%%=*}; value=${pair#*=}; value=${value#\'}; value=${value%\'}
    printf '%s=%s\n' "$name" "$value" >>"$TEST_UCI_STATE"
    printf 'add_list %s=%s\n' "$name" "$value" >>"$TEST_UCI_LOG"
    ;;
  reorder)
    section=${key%%=*}
    tmp="$TEST_UCI_STATE.reorder"
    {
      sed -n "\\|^${section}=|p; \\|^${section}\\.|p" "$TEST_UCI_STATE"
      sed "\\|^${section}=|d; \\|^${section}\\.|d" "$TEST_UCI_STATE"
    } >"$tmp"
    mv "$tmp" "$TEST_UCI_STATE"
    printf 'reorder %s\n' "$key" >>"$TEST_UCI_LOG"
    ;;
  commit)
    printf 'commit %s\n' "$key" >>"$TEST_UCI_LOG"
    ;;
  *) exit 2 ;;
esac
EOF
cat >"$BIN_DIR/mwan3" <<'EOF'
#!/bin/sh
printf 'mwan3 %s\n' "$*" >>"$TEST_UCI_LOG"
EOF
cat >"$BIN_DIR/ubus" <<'EOF'
#!/bin/sh
if [ -f "$TEST_ROOT/ubus-fail" ]; then
  exit 1
fi
printf 'ubus %s\n' "$*" >>"$TEST_UCI_LOG"
printf '{}\n'
EOF
cat >"$BIN_DIR/ipcalc.sh" <<'EOF'
#!/bin/sh
case "$1${2:+/$2}" in
  192.168.13.1/24|192.168.13.1/255.255.255.0)
    printf 'NETWORK=192.168.13.0\nPREFIX=24\n'
    ;;
  10.23.5.1/255.255.254.0)
    printf 'NETWORK=10.23.4.0\nPREFIX=23\n'
    ;;
  *) exit 1 ;;
esac
EOF
cat >"$BIN_DIR/logger" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$BIN_DIR/iptables-save" <<'EOF'
#!/bin/sh
[ ! -f "$TEST_ROOT/mangle-ip-incompatible" ] && [ ! -f "$TEST_ROOT/mangle-foreign" ]
EOF
cat >"$BIN_DIR/ip6tables-save" <<'EOF'
#!/bin/sh
[ ! -f "$TEST_ROOT/mangle-ip6-incompatible" ]
EOF
cat >"$BIN_DIR/nft" <<'EOF'
#!/bin/sh
case "$*" in
  'list table ip mangle'|'list table ip6 mangle')
    if [ -f "$TEST_ROOT/mangle-foreign" ]; then
      printf '%s\n' 'table ip mangle {' ' chain third_party {' '}'
    else
      printf '%s\n' \
        'table ip mangle {' \
        ' chain PREROUTING {' \
        ' chain OUTPUT {' \
        ' chain mwan3_hook {' \
        '}'
    fi
    ;;
  'delete table ip mangle')
    rm -f "$TEST_ROOT/mangle-ip-incompatible"
    printf 'nft delete ip mangle\n' >>"$TEST_UCI_LOG"
    ;;
  'delete table ip6 mangle')
    rm -f "$TEST_ROOT/mangle-ip6-incompatible"
    printf 'nft delete ip6 mangle\n' >>"$TEST_UCI_LOG"
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$BIN_DIR"/*

export PATH="$BIN_DIR:$PATH"
export TEST_UCI_STATE="$STATE"
export TEST_UCI_LOG="$LOG"
export TEST_ROOT="$WORK_DIR"
export CPE5G_MWAN3_INIT="$BIN_DIR/mwan3"
export CPE5G_UBUS="$BIN_DIR/ubus"
export CPE5G_RECONCILE_LOCK_DIR="$WORK_DIR/reconcile.lock"
export CPE5G_IPTABLES_SAVE="$BIN_DIR/iptables-save"
export CPE5G_IP6TABLES_SAVE="$BIN_DIR/ip6tables-save"
export CPE5G_NFT="$BIN_DIR/nft"
printf '%s\n' \
  'network.wan=interface' \
  'network.5G=interface' \
  'network.lan=interface' \
  'network.lan.ipaddr=192.168.13.1' \
  'network.lan.netmask=255.255.255.0' \
  'mwan3.https=rule' \
  'mwan3.https.sticky=1' \
  'mwan3.https.dest_port=443' \
  'mwan3.https.proto=tcp' \
  'mwan3.https.use_policy=balanced' \
  'mwan3.default_rule_v4=rule' \
  'mwan3.default_rule_v4.dest_ip=0.0.0.0/0' \
  'mwan3.default_rule_v4.use_policy=balanced' \
  'mwan3.default_rule_v4.family=ipv4' \
  'mwan3.default_rule_v6=rule' \
  'mwan3.default_rule_v6.use_policy=balanced' \
  'mwan3.user_rule=rule' \
  'mwan3.user_rule.dest_ip=203.0.113.0/24' >"$STATE"
: >"$LOG"
touch "$WORK_DIR/mangle-ip-incompatible" "$WORK_DIR/mangle-ip6-incompatible"

"$RECONCILE"
"$RECONCILE"

[ ! -e "$WORK_DIR/mangle-ip-incompatible" ]
[ ! -e "$WORK_DIR/mangle-ip6-incompatible" ]
grep -q '^nft delete ip mangle$' "$LOG"
grep -q '^nft delete ip6 mangle$' "$LOG"

grep -q '^mwan3.user_rule=rule$' "$STATE"
grep -q '^mwan3.user_rule.dest_ip=203.0.113.0/24$' "$STATE"
if grep -q '^mwan3\.\(https\|default_rule_v4\)=' "$STATE"; then
  echo "stock IPv4 catch-all/example rules still shadow CPE failover" >&2
  exit 1
fi
grep -q '^mwan3.default_rule_v6=rule$' "$STATE"
[ "$(grep -c '^mwan3.wan.track_ip=' "$STATE")" -eq 3 ] || {
  echo "repeat reconcile duplicated or lost WAN track targets" >&2
  exit 1
}
[ "$(grep -c '^mwan3.cpe5g_failover.use_member=' "$STATE")" -eq 2 ] || {
  echo "repeat reconcile duplicated or lost failover members" >&2
  exit 1
}
grep -q '^mwan3.cpe5g_cpe.use_policy=default$' "$STATE"
grep -q '^mwan3.cpe5g_lan.use_policy=default$' "$STATE"
grep -q '^mwan3.cpe5g_lan.dest_ip=192.168.13.0/24$' "$STATE"
grep -q '^reorder mwan3.cpe5g_lan=0$' "$LOG"
grep -q '^reorder mwan3.cpe5g_cpe=0$' "$LOG"
grep -q '^ubus call network reload$' "$LOG"
grep -q '^ubus -S call network.interface.wan status$' "$LOG"
grep -q '^ubus -S call network.interface.5G status$' "$LOG"
grep -q '^mwan3 enable$' "$LOG"
grep -q '^mwan3 stop$' "$LOG"
grep -q '^mwan3 start$' "$LOG"
rule_order="$(sed -n 's/^mwan3\.\([^.=]*\)=rule$/\1/p' "$STATE")"
[ "$(printf '%s\n' "$rule_order" | sed -n '1p')" = cpe5g_cpe ]
[ "$(printf '%s\n' "$rule_order" | sed -n '2p')" = cpe5g_lan ]
[ "$(printf '%s\n' "$rule_order" | tail -n 1)" = cpe5g_default ]

# Current CPE images write the LAN address in CIDR form and omit a separate
# netmask option. This must produce the same direct-network bypass as the
# legacy ipaddr + netmask representation used above.
sed -i 's|^network.lan.ipaddr=.*|network.lan.ipaddr=192.168.13.1/24|; /^network.lan.netmask=/d' "$STATE"
if ! "$RECONCILE"; then
  echo "reconcile rejected CIDR-style LAN ipaddr without netmask" >&2
  exit 1
fi
grep -q '^mwan3.cpe5g_lan.dest_ip=192.168.13.0/24$' "$STATE"

# A dynamic workflow LAN address must change the bypass prefix, including a
# non-/24 mask, without hard-coded 192.168.13.0 assumptions.
sed -i 's/^network.lan.ipaddr=.*/network.lan.ipaddr=10.23.5.1/; /^network.lan.netmask=/d' "$STATE"
printf '%s\n' 'network.lan.netmask=255.255.254.0' >>"$STATE"
"$RECONCILE"
grep -q '^mwan3.cpe5g_lan.dest_ip=10.23.4.0/23$' "$STATE"

# Locally modified stock-named rules are user policy and must survive.
printf '%s\n' \
  'mwan3.https=rule' \
  'mwan3.https.sticky=1' \
  'mwan3.https.dest_port=443' \
  'mwan3.https.proto=tcp' \
  'mwan3.https.use_policy=user_https' >>"$STATE"
"$RECONCILE"
grep -q '^mwan3.https.use_policy=user_https$' "$STATE"

# Simulate an older wrtbak restore deleting only project-owned sections. The
# same reconcile must recreate them while preserving the user's rule.
sed -i '/^mwan3\.cpe5g_/d; /^mwan3\.wan/d; /^mwan3\.5G/d' "$STATE"
"$RECONCILE"
grep -q '^mwan3.cpe5g_default=rule$' "$STATE"
grep -q '^mwan3.wan=interface$' "$STATE"
grep -q '^mwan3.5G=interface$' "$STATE"
grep -q '^mwan3.user_rule=rule$' "$STATE"

# A terminal wrtbak receipt must invoke the same reconcile path in practice.
sed -i '/^mwan3\.cpe5g_/d; /^mwan3\.wan/d; /^mwan3\.5G/d' "$STATE"
printf '%s\n' 'wrtbak.main.firstboot_auto_enabled=1' >>"$STATE"
printf '%s\n' '{"state":"restored"}' >"$WORK_DIR/gate.json"
CPE5G_WRTBAK_GATE_FILE="$WORK_DIR/gate.json" \
CPE5G_RECONCILE_BIN="$RECONCILE" \
CPE5G_GATE_MAX_ATTEMPTS=1 \
CPE5G_GATE_INTERVAL=0 \
  "$GATED"
grep -q '^mwan3.cpe5g_failover=policy$' "$STATE"
grep -q '^mwan3.user_rule=rule$' "$STATE"

# Every documented terminal state, plus the bounded timeout path, must release
# the gate. Use a marker to isolate gate behavior from UCI behavior.
cat >"$BIN_DIR/reconcile-marker" <<'EOF'
#!/bin/sh
printf 'called\n' >>"$TEST_ROOT/gate-calls"
EOF
chmod +x "$BIN_DIR/reconcile-marker"
: >"$WORK_DIR/gate-calls"
for terminal in already_done restored no_backup failed_final disabled; do
  printf '{"state":"%s"}\n' "$terminal" >"$WORK_DIR/gate.json"
  CPE5G_WRTBAK_GATE_FILE="$WORK_DIR/gate.json" \
  CPE5G_RECONCILE_BIN="$BIN_DIR/reconcile-marker" \
  CPE5G_GATE_MAX_ATTEMPTS=1 CPE5G_GATE_INTERVAL=0 "$GATED"
done
printf '%s\n' '{"state":"pending"}' >"$WORK_DIR/gate.json"
CPE5G_WRTBAK_GATE_FILE="$WORK_DIR/gate.json" \
CPE5G_RECONCILE_BIN="$BIN_DIR/reconcile-marker" \
CPE5G_GATE_MAX_ATTEMPTS=1 CPE5G_GATE_INTERVAL=0 "$GATED"
[ "$(grep -c '^called$' "$WORK_DIR/gate-calls")" -eq 6 ] || {
  echo "wrtbak terminal/timeout gate paths did not reconcile exactly once" >&2
  exit 1
}

# With wrtbak disabled, the first-boot gate-aware service path immediately
# performs exactly one reconcile.
printf '%s\n' 'wrtbak.main.firstboot_auto_enabled=0' >>"$STATE"
: >"$WORK_DIR/gate-calls"
CPE5G_RECONCILE_BIN="$BIN_DIR/reconcile-marker" "$GATED"
[ "$(grep -c '^called$' "$WORK_DIR/gate-calls")" -eq 1 ]

# A live lock represents the only other reconcile worker and suppresses all
# duplicate writes/restarts.
mkdir -p "$WORK_DIR/reconcile.lock"
printf '%s\n' "$$" >"$WORK_DIR/reconcile.lock/pid"
: >"$LOG"
"$RECONCILE"
[ ! -s "$LOG" ] || {
  echo "concurrent reconcile was not suppressed" >&2
  exit 1
}
rm -rf "$WORK_DIR/reconcile.lock"

# A failed netifd reload restores the prior network options and reports
# failure; it must not silently leave a partially applied routing baseline.
sed -i 's/^network.wan.metric=.*/network.wan.metric=99/' "$STATE"
touch "$WORK_DIR/ubus-fail"
if "$RECONCILE" >/dev/null 2>&1; then
  echo "reconcile ignored a failed network reload" >&2
  exit 1
fi
rm -f "$WORK_DIR/ubus-fail"
grep -q '^network.wan.metric=99$' "$STATE"

# An incompatible table with any non-mwan chain is not owned by this preset.
# Reconcile must fail closed instead of deleting another package's state.
touch "$WORK_DIR/mangle-foreign"
: >"$LOG"
if "$RECONCILE" >/dev/null 2>&1; then
  echo "reconcile deleted or accepted a foreign mangle table" >&2
  exit 1
fi
if grep -q '^nft delete ip mangle$' "$LOG"; then
  echo "reconcile deleted a foreign mangle table" >&2
  exit 1
fi
rm -f "$WORK_DIR/mangle-foreign"

# Required interfaces are validated before the first commit.
sed -i '/^network\.5G=/d' "$STATE"
: >"$LOG"
if "$RECONCILE" >/dev/null 2>&1; then
  echo "reconcile accepted a missing 5G interface" >&2
  exit 1
fi
if grep -q '^commit ' "$LOG"; then
  echo "reconcile committed partial state after validation failure" >&2
  exit 1
fi

echo "CPE-5G mwan3 runtime fixture passed"
