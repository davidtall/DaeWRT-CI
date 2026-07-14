#!/bin/bash
set -euo pipefail

TARGET_FILES="${1:-${GITHUB_WORKSPACE:-$(pwd)}/wrt/files}"
WAN_SSH_ENABLED="${2:-false}"
WAN_SSH_PORT="${3:-22}"
WAN_SSH_SOURCE="${4:-}"
DEFAULTS_FILE="$TARGET_FILES/etc/uci-defaults/89-wan-dropbear-access"

enabled_value() {
	case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
		1|true|yes|on) return 0 ;;
		0|false|no|off|"") return 1 ;;
		*)
			echo "WAN SSH: invalid enable value '$1'; use true or false" >&2
			exit 1
			;;
	esac
}

validate_port() {
	case "$1" in
		""|*[!0-9]*)
			echo "WAN SSH: invalid port '$1'" >&2
			exit 1
			;;
	esac
	if [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
		echo "WAN SSH: port out of range '$1'" >&2
		exit 1
	fi
}

validate_source() {
	[ -z "$1" ] && return 0
	case "$1" in
		*[!A-Za-z0-9:./_-]*)
			echo "WAN SSH: invalid source '$1'; use one IP or CIDR such as 203.0.113.10/32" >&2
			exit 1
			;;
	esac
}

if ! enabled_value "$WAN_SSH_ENABLED"; then
	rm -f "$DEFAULTS_FILE"
	echo "WAN SSH: disabled; leaving WAN Dropbear firewall closed"
	exit 0
fi

validate_port "$WAN_SSH_PORT"
validate_source "$WAN_SSH_SOURCE"

mkdir -p "$(dirname "$DEFAULTS_FILE")"

cat >"$DEFAULTS_FILE" <<EOF
#!/bin/sh

# Generated at firmware build time by Scripts/ConfigureWanDropbearAccess.sh.
# This opens router-local Dropbear SSH from the wan firewall zone.
WAN_SSH_PORT='$WAN_SSH_PORT'
WAN_SSH_SOURCE='$WAN_SSH_SOURCE'

uci set dropbear.main='dropbear'
uci set dropbear.main.enable='1'
uci set dropbear.main.Port="\$WAN_SSH_PORT"
uci -q delete dropbear.main.Interface >/dev/null 2>&1 || true
uci -q delete dropbear.main.DirectInterface >/dev/null 2>&1 || true
uci -q delete dropbear.main._direct >/dev/null 2>&1 || true
uci commit dropbear >/dev/null 2>&1 || true

uci -q delete firewall.wan_dropbear_ssh >/dev/null 2>&1 || true
uci set firewall.wan_dropbear_ssh='rule'
uci set firewall.wan_dropbear_ssh.name='Allow-Dropbear-WAN'
uci set firewall.wan_dropbear_ssh.src='wan'
uci set firewall.wan_dropbear_ssh.proto='tcp'
uci set firewall.wan_dropbear_ssh.dest_port="\$WAN_SSH_PORT"
uci set firewall.wan_dropbear_ssh.target='ACCEPT'
if [ -n "\$WAN_SSH_SOURCE" ]; then
	uci set firewall.wan_dropbear_ssh.src_ip="\$WAN_SSH_SOURCE"
fi
uci commit firewall >/dev/null 2>&1 || true

[ -x /etc/init.d/dropbear ] && /etc/init.d/dropbear enable >/dev/null 2>&1 || true
[ -x /etc/init.d/dropbear ] && /etc/init.d/dropbear restart >/dev/null 2>&1 || true
[ -x /etc/init.d/firewall ] && /etc/init.d/firewall restart >/dev/null 2>&1 || true

exit 0
EOF

chmod 755 "$DEFAULTS_FILE"
echo "WAN SSH: enabled on wan tcp/$WAN_SSH_PORT${WAN_SSH_SOURCE:+ from $WAN_SSH_SOURCE}"
