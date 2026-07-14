#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
	echo "usage: $0 <files-overlay-dir> <true|false>" >&2
	exit 1
fi

FILES_DIR="$1"
ENABLE="$2"
BOOTSTRAP="$FILES_DIR/etc/uci-defaults/92-cpe-5g-network"
RECONCILE="$FILES_DIR/usr/libexec/cpe5g-mwan3-reconcile"
GATED_RECONCILE="$FILES_DIR/usr/libexec/cpe5g-mwan3-gated-reconcile"
INIT_SCRIPT="$FILES_DIR/etc/init.d/cpe5g-mwan3-reconcile"

case "$ENABLE" in
	true|false) ;;
	*)
		echo "ERROR: CPE-5G network input must be true or false, got: $ENABLE" >&2
		exit 1
		;;
esac

[ -d "$FILES_DIR" ] || {
	echo "ERROR: files overlay directory does not exist: $FILES_DIR" >&2
	exit 1
}

[ "$ENABLE" = true ] || exit 0

mkdir -p "$(dirname "$BOOTSTRAP")" "$(dirname "$RECONCILE")" "$(dirname "$INIT_SCRIPT")"

cat >"$RECONCILE" <<'EOF'
#!/bin/sh
set -eu

TAG='cpe5g-mwan3-reconcile'
MWAN3_INIT="${CPE5G_MWAN3_INIT:-/etc/init.d/mwan3}"
UBUS="${CPE5G_UBUS:-ubus}"
LOCK_DIR="${CPE5G_RECONCILE_LOCK_DIR:-/var/run/cpe5g-mwan3-reconcile.lock}"
IPTABLES_SAVE="${CPE5G_IPTABLES_SAVE:-/usr/sbin/iptables-save}"
IP6TABLES_SAVE="${CPE5G_IP6TABLES_SAVE:-/usr/sbin/ip6tables-save}"
NFT="${CPE5G_NFT:-/usr/sbin/nft}"

log() {
	logger -t "$TAG" "$*" 2>/dev/null || true
}

release_lock() {
	[ -d "$LOCK_DIR" ] || return 0
	[ "$(sed -n '1p' "$LOCK_DIR/pid" 2>/dev/null || true)" = "$$" ] || return 0
	rm -rf "$LOCK_DIR"
}

acquire_lock() {
	local owner
	if mkdir "$LOCK_DIR" 2>/dev/null; then
		printf '%s\n' "$$" >"$LOCK_DIR/pid"
		trap release_lock EXIT
		trap 'release_lock; exit 1' HUP INT TERM
		return 0
	fi
	owner="$(sed -n '1p' "$LOCK_DIR/pid" 2>/dev/null || true)"
	case "$owner" in
		''|*[!0-9]*) ;;
		*) kill -0 "$owner" 2>/dev/null && { log 'another reconcile is active'; return 1; } ;;
	esac
	rm -rf "$LOCK_DIR"
	mkdir "$LOCK_DIR"
	printf '%s\n' "$$" >"$LOCK_DIR/pid"
	trap release_lock EXIT
	trap 'release_lock; exit 1' HUP INT TERM
}

require_interface() {
	local interface="$1"
	[ "$(uci -q get "network.$interface" 2>/dev/null || true)" = 'interface' ] || {
		log "required network interface is missing: $interface"
		return 1
	}
}

reset_managed_section() {
	local section="$1" type="$2"
	uci -q delete "mwan3.$section" 2>/dev/null || true
	uci set "mwan3.$section=$type"
}

stock_rule_equals() {
	local section="$1" type="$2" key expected actual expected_lines actual_lines
	shift 2
	[ "$(uci -q get "mwan3.$section" 2>/dev/null || true)" = "$type" ] || return 1
	expected_lines=1
	while [ "$#" -gt 0 ]; do
		key="$1" expected="$2"; shift 2
		actual="$(uci -q get "mwan3.$section.$key" 2>/dev/null || true)"
		[ "$actual" = "$expected" ] || return 1
		expected_lines=$((expected_lines + 1))
	done
	actual_lines="$(uci -q show "mwan3.$section" 2>/dev/null | wc -l | tr -d ' ')"
	[ "$actual_lines" = "$expected_lines" ]
}

restore_network_option() {
	local key="$1" value="$2"
	if [ "$value" = '__missing__' ]; then
		uci -q delete "$key" 2>/dev/null || true
	else
		uci set "$key=$value"
	fi
}

set_network_option() {
	local key="$1" wanted="$2" current
	current="$(uci -q get "$key" 2>/dev/null || true)"
	[ "$current" = "$wanted" ] && return 0
	uci set "$key=$wanted"
	network_changed=1
}

wait_for_network_object() {
	local interface="$1" attempt=0
	while [ "$attempt" -lt 15 ]; do
		"$UBUS" -S call "network.interface.$interface" status >/dev/null 2>&1 && return 0
		attempt=$((attempt + 1))
		sleep 1
	done
	log "netifd object did not settle after reload: $interface"
	return 1
}

cleanup_incompatible_mangle_table() {
	local family="$1" saver="$2" table chains chain
	[ -x "$saver" ] || return 0
	"$saver" -t mangle >/dev/null 2>&1 && return 0
	[ -x "$NFT" ] || {
		log "$family mangle is incompatible and nft is unavailable"
		return 1
	}
	table="$($NFT list table "$family" mangle 2>/dev/null || true)"
	[ -n "$table" ] || {
		log "$family mangle is incompatible but cannot be inspected"
		return 1
	}
	chains="$(printf '%s\n' "$table" | sed -n 's/^[[:space:]]*chain \([^ {]*\).*/\1/p')"
	for chain in $chains; do
		case "$chain" in
			PREROUTING|OUTPUT|mwan3_*) ;;
			*)
				log "refusing to delete $family mangle with foreign chain: $chain"
				return 1
				;;
		esac
	done
	$NFT delete table "$family" mangle
	log "removed incompatible mwan3-owned $family mangle table"
}

# Validate every required input before making or committing any change. This is
# important when an old wrtbak archive is restored onto a newer CPE image.
require_interface wan
require_interface 5G
acquire_lock || exit 0

lan_ip="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"
lan_mask="$(uci -q get network.lan.netmask 2>/dev/null || true)"
[ -n "$lan_ip" ] || {
	log 'LAN ipaddr is unavailable; refusing a partial policy'
	exit 1
}
command -v ipcalc.sh >/dev/null 2>&1 || {
	log 'ipcalc.sh is unavailable; cannot derive the LAN bypass prefix'
	exit 1
}
if [ -n "$lan_mask" ]; then
	lan_calc="$(ipcalc.sh "$lan_ip" "$lan_mask")"
else
	case "$lan_ip" in
		*/*) lan_calc="$(ipcalc.sh "$lan_ip")" ;;
		*) log 'LAN netmask is unavailable and ipaddr is not CIDR'; exit 1 ;;
	esac
fi
lan_network="$(printf '%s\n' "$lan_calc" | sed -n 's/^NETWORK=//p' | sed -n '1p')"
lan_prefix="$(printf '%s\n' "$lan_calc" | sed -n 's/^PREFIX=//p' | sed -n '1p')"
case "$lan_network" in
	*.*.*.*) ;;
	*) log 'ipcalc.sh returned an invalid LAN network'; exit 1 ;;
esac
case "$lan_prefix" in
	''|*[!0-9]*) log 'ipcalc.sh returned an invalid LAN prefix'; exit 1 ;;
esac
lan_cidr="$lan_network/$lan_prefix"

old_wan_metric="$(uci -q get network.wan.metric 2>/dev/null || printf '__missing__')"
old_5g_metric="$(uci -q get network.5G.metric 2>/dev/null || printf '__missing__')"
old_5g_defaultroute="$(uci -q get network.5G.defaultroute 2>/dev/null || printf '__missing__')"
old_5g_peerdns="$(uci -q get network.5G.peerdns 2>/dev/null || printf '__missing__')"
network_changed=0

set_network_option network.wan.metric 10
set_network_option network.5G.metric 20
set_network_option network.5G.defaultroute 1
set_network_option network.5G.peerdns 0

uci set mwan3.wan='interface'
uci set mwan3.wan.enabled='1'
uci set mwan3.wan.family='ipv4'
uci set mwan3.wan.reliability='2'
uci set mwan3.wan.count='1'
uci set mwan3.wan.timeout='2'
uci set mwan3.wan.interval='5'
uci set mwan3.wan.failure_interval='2'
uci set mwan3.wan.recovery_interval='2'
uci set mwan3.wan.down='3'
uci set mwan3.wan.up='5'
uci -q delete mwan3.wan.track_ip 2>/dev/null || true
uci add_list mwan3.wan.track_ip='223.5.5.5'
uci add_list mwan3.wan.track_ip='119.29.29.29'
uci add_list mwan3.wan.track_ip='1.1.1.1'

uci set mwan3.5G='interface'
uci set mwan3.5G.enabled='1'
uci set mwan3.5G.family='ipv4'
uci set mwan3.5G.reliability='2'
uci set mwan3.5G.count='1'
uci set mwan3.5G.timeout='2'
uci set mwan3.5G.interval='60'
uci set mwan3.5G.failure_interval='5'
uci set mwan3.5G.recovery_interval='5'
uci set mwan3.5G.down='3'
uci set mwan3.5G.up='5'
uci -q delete mwan3.5G.track_ip 2>/dev/null || true
uci add_list mwan3.5G.track_ip='223.5.5.5'
uci add_list mwan3.5G.track_ip='119.29.29.29'
uci add_list mwan3.5G.track_ip='1.1.1.1'

reset_managed_section cpe5g_wan_m10 member
uci set mwan3.cpe5g_wan_m10.interface='wan'
uci set mwan3.cpe5g_wan_m10.metric='10'
uci set mwan3.cpe5g_wan_m10.weight='1'

reset_managed_section cpe5g_5g_m20 member
uci set mwan3.cpe5g_5g_m20.interface='5G'
uci set mwan3.cpe5g_5g_m20.metric='20'
uci set mwan3.cpe5g_5g_m20.weight='1'

reset_managed_section cpe5g_failover policy
uci add_list mwan3.cpe5g_failover.use_member='cpe5g_wan_m10'
uci add_list mwan3.cpe5g_failover.use_member='cpe5g_5g_m20'
uci set mwan3.cpe5g_failover.last_resort='unreachable'

# Remove the IPv4 examples only while their routing signature is still stock.
# A locally modified section is user policy and is deliberately preserved.
if stock_rule_equals https rule sticky 1 dest_port 443 proto tcp use_policy balanced; then
	uci -q delete mwan3.https 2>/dev/null || true
fi
if stock_rule_equals default_rule_v4 rule dest_ip 0.0.0.0/0 use_policy balanced family ipv4; then
	uci -q delete mwan3.default_rule_v4 2>/dev/null || true
fi

for rule in $(uci -q show mwan3 2>/dev/null | sed -n 's/^mwan3\.\([^.=]*\)=rule$/\1/p'); do
	case "$rule" in cpe5g_cpe|cpe5g_lan|cpe5g_default) continue ;; esac
	if [ "$(uci -q get "mwan3.$rule.family" 2>/dev/null || true)" != 'ipv6' ] &&
	   [ "$(uci -q get "mwan3.$rule.dest_ip" 2>/dev/null || true)" = '0.0.0.0/0' ]; then
		log "user IPv4 catch-all rule may override CPE failover: $rule"
	fi
done

# Explicitly keep directly connected management/LAN traffic out of mwan3's
# default policy. This preserves symmetric replies to the CPE/Lucky path.
reset_managed_section cpe5g_cpe rule
uci set mwan3.cpe5g_cpe.family='ipv4'
uci set mwan3.cpe5g_cpe.proto='all'
uci set mwan3.cpe5g_cpe.dest_ip='192.168.66.0/24'
uci set mwan3.cpe5g_cpe.use_policy='default'

reset_managed_section cpe5g_lan rule
uci set mwan3.cpe5g_lan.family='ipv4'
uci set mwan3.cpe5g_lan.proto='all'
uci set "mwan3.cpe5g_lan.dest_ip=$lan_cidr"
uci set mwan3.cpe5g_lan.use_policy='default'

reset_managed_section cpe5g_default rule
uci set mwan3.cpe5g_default.family='ipv4'
uci set mwan3.cpe5g_default.proto='all'
uci set mwan3.cpe5g_default.dest_ip='0.0.0.0/0'
uci set mwan3.cpe5g_default.use_policy='cpe5g_failover'

# mwan3 evaluates rules in UCI order and has no priority option. Put the two
# safety bypasses first; the newly recreated catch-all remains last.
uci reorder mwan3.cpe5g_lan=0
uci reorder mwan3.cpe5g_cpe=0

uci commit network
uci commit mwan3

if [ "$network_changed" -eq 1 ]; then
	if ! "$UBUS" call network reload >/dev/null 2>&1; then
		restore_network_option network.wan.metric "$old_wan_metric"
		restore_network_option network.5G.metric "$old_5g_metric"
		restore_network_option network.5G.defaultroute "$old_5g_defaultroute"
		restore_network_option network.5G.peerdns "$old_5g_peerdns"
		uci commit network
		"$UBUS" call network reload >/dev/null 2>&1 || true
		log 'network reload failed; restored prior network options'
		exit 1
	fi
	wait_for_network_object wan || true
	wait_for_network_object 5G || true
fi

if [ -x "$MWAN3_INIT" ]; then
	"$MWAN3_INIT" enable
	"$MWAN3_INIT" stop >/dev/null 2>&1 || true
	cleanup_ok=1
	cleanup_incompatible_mangle_table ip "$IPTABLES_SAVE" || cleanup_ok=0
	cleanup_incompatible_mangle_table ip6 "$IP6TABLES_SAVE" || cleanup_ok=0
	if [ "$cleanup_ok" -ne 1 ]; then
		"$MWAN3_INIT" start >/dev/null 2>&1 || true
		log 'mwan3 table cleanup was unsafe; service start attempted without deleting foreign state'
		exit 1
	fi
	"$MWAN3_INIT" start
else
	log "mwan3 init script is unavailable; configuration was committed"
fi
log 'managed WAN-primary/5G-backup policy reconciled'
EOF
chmod 755 "$RECONCILE"

cat >"$GATED_RECONCILE" <<'EOF'
#!/bin/sh
set -eu

GATE_FILE="${CPE5G_WRTBAK_GATE_FILE:-/root/wrtbak/firstboot/gate.json}"
MAX_ATTEMPTS="${CPE5G_GATE_MAX_ATTEMPTS:-180}"
INTERVAL="${CPE5G_GATE_INTERVAL:-10}"
RECONCILE_BIN="${CPE5G_RECONCILE_BIN:-/usr/libexec/cpe5g-mwan3-reconcile}"

restore_enabled="$(uci -q get wrtbak.main.firstboot_auto_enabled 2>/dev/null || true)"
case "$restore_enabled" in
	1|true|yes|on|enabled) ;;
	*) exec "$RECONCILE_BIN" ;;
esac

attempt=0
while [ "$attempt" -lt "$MAX_ATTEMPTS" ]; do
	state='missing'
	if [ -f "$GATE_FILE" ]; then
		if command -v jsonfilter >/dev/null 2>&1; then
			state="$(jsonfilter -i "$GATE_FILE" -e '@.state' 2>/dev/null || true)"
		else
			state="$(sed -n 's/.*"state"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$GATE_FILE" | sed -n '1p')"
		fi
	fi
	case "$state" in
		already_done|restored|no_backup|failed_final|disabled)
			exec "$RECONCILE_BIN"
			;;
	esac
	attempt=$((attempt + 1))
	[ "$attempt" -lt "$MAX_ATTEMPTS" ] || break
	sleep "$INTERVAL"
done

logger -t cpe5g-mwan3-reconcile 'wrtbak gate timed out; reconciling managed network policy' 2>/dev/null || true
exec "$RECONCILE_BIN"
EOF
chmod 755 "$GATED_RECONCILE"

cat >"$INIT_SCRIPT" <<'EOF'
#!/bin/sh /etc/rc.common
USE_PROCD=1
START=96

start_service() {
	procd_open_instance
	procd_set_param command /usr/libexec/cpe5g-mwan3-gated-reconcile
	procd_set_param stdout 1
	procd_set_param stderr 1
	procd_set_param term_timeout 5
	procd_close_instance
}
EOF
chmod 755 "$INIT_SCRIPT"

cat >"$BOOTSTRAP" <<'EOF'
#!/bin/sh
set -eu

uci set network.5G='interface'
uci set network.5G.proto='dhcp'
uci set network.5G.device='usb0'

wan_zone=''
for section in $(uci show firewall | sed -n 's/^firewall\.\([^.=]*\)=zone$/\1/p'); do
	if [ "$(uci -q get "firewall.$section.name" || true)" = 'wan' ]; then
		wan_zone="$section"
		break
	fi
done

[ -n "$wan_zone" ] || {
	echo 'ERROR: CPE-5G bootstrap could not find the wan firewall zone' >&2
	exit 1
}

case " $(uci -q get "firewall.$wan_zone.network" || true) " in
	*' 5G '*) ;;
	*) uci add_list firewall.$wan_zone.network='5G' ;;
esac

forwarding=''
for section in $(uci show firewall | sed -n 's/^firewall\.\([^.=]*\)=forwarding$/\1/p'); do
	if [ "$(uci -q get "firewall.$section.src" || true)" = 'lan' ] &&
	   [ "$(uci -q get "firewall.$section.dest" || true)" = 'wan' ]; then
		forwarding="$section"
		break
	fi
done

if [ -z "$forwarding" ]; then
	forwarding="$(uci add firewall forwarding)"
	uci set firewall.$forwarding.src='lan'
	uci set firewall.$forwarding.dest='wan'
fi

uci commit network
uci commit firewall
/etc/init.d/cpe5g-mwan3-reconcile enable
/etc/init.d/cpe5g-mwan3-reconcile start
exit 0
EOF
chmod 755 "$BOOTSTRAP"

echo "CPE-5G network bootstrap: WAN-primary/usb0-5G-backup managed by mwan3"
