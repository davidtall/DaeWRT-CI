#!/bin/bash
set -euo pipefail

TARGET_FILES="${1:-${GITHUB_WORKSPACE:-$(pwd)}/wrt/files}"
CONFIG_FILE="$TARGET_FILES/etc/config/headscale_auto_enroll"
AUTH_KEY_FILE="$TARGET_FILES/etc/tailscale/headscale.authkey"

HEADSCALE_LOGIN_SERVER="${HEADSCALE_LOGIN_SERVER:-https://headscale.jmsu.top}"
HEADSCALE_OPENWRT_HOSTNAME_PREFIX="${HEADSCALE_OPENWRT_HOSTNAME_PREFIX:-openwrt}"
HEADSCALE_OPENWRT_HOSTNAME="${HEADSCALE_OPENWRT_HOSTNAME:-}"
HEADSCALE_OPENWRT_ENABLE_SSH="${HEADSCALE_OPENWRT_ENABLE_SSH:-1}"
HEADSCALE_OPENWRT_ACCEPT_ROUTES="${HEADSCALE_OPENWRT_ACCEPT_ROUTES:-0}"
HEADSCALE_OPENWRT_ADVERTISE_ROUTES="${HEADSCALE_OPENWRT_ADVERTISE_ROUTES:-}"

set_config_option() {
	local option="$1"
	local value="$2"

	if grep -q "^[[:space:]]*option ${option} " "$CONFIG_FILE"; then
		sed -i "s#^[[:space:]]*option ${option} .*#	option ${option} '${value}'#" "$CONFIG_FILE"
	else
		printf "\toption %s '%s'\n" "$option" "$value" >> "$CONFIG_FILE"
	fi
}

sanitize_hostname() {
	printf '%s' "$1" |
		tr '[:upper:]' '[:lower:]' |
		tr -cs 'a-z0-9_.-' '-' |
		sed -e 's/^-*//' -e 's/-*$//' -e 's/--*/-/g'
}

lan_ip_site_id() {
	local ip="$1"
	local third

	case "$ip" in
		192.168.*.*)
			third="${ip#192.168.}"
			printf '%s' "${third%%.*}"
			;;
		10.*.*.*)
			printf '%s' "$ip" | tr '.' '-'
			;;
		172.*.*.*)
			printf '%s' "$ip" | tr '.' '-'
			;;
		*)
			printf ''
			;;
	esac
}

derive_headscale_hostname() {
	local explicit="$1"
	local prefix="$2"
	local wrt_name="${3:-router}"
	local wrt_ip="${4:-}"
	local site_id base

	if [ -n "$explicit" ]; then
		sanitize_hostname "$explicit"
		return 0
	fi

	base="$(sanitize_hostname "${prefix}-${wrt_name}")"
	site_id="$(lan_ip_site_id "$wrt_ip")"
	if [ -n "$site_id" ]; then
		printf '%s-%s' "$base" "$site_id" | sed -e 's/--*/-/g'
	else
		printf '%s' "$base"
	fi
}

if [ -z "${HEADSCALE_OPENWRT_AUTHKEY:-}" ]; then
	echo "headscale auto-enroll: HEADSCALE_OPENWRT_AUTHKEY is empty; leaving firmware auto-enroll disabled"
	exit 0
fi

case "$HEADSCALE_OPENWRT_AUTHKEY" in
	hskey-auth-*) ;;
	*)
		echo "headscale auto-enroll: HEADSCALE_OPENWRT_AUTHKEY does not look like a Headscale preauth key" >&2
		exit 1
		;;
esac

[ -f "$CONFIG_FILE" ] || {
	echo "headscale auto-enroll: missing $CONFIG_FILE" >&2
	exit 1
}

mkdir -p "$(dirname "$AUTH_KEY_FILE")"
chmod 700 "$(dirname "$AUTH_KEY_FILE")" 2>/dev/null || true
umask 077
printf '%s\n' "$HEADSCALE_OPENWRT_AUTHKEY" >"$AUTH_KEY_FILE"

set_config_option enabled 1
set_config_option login_server "$HEADSCALE_LOGIN_SERVER"
set_config_option hostname_prefix "$HEADSCALE_OPENWRT_HOSTNAME_PREFIX"
set_config_option hostname_override "$(derive_headscale_hostname "$HEADSCALE_OPENWRT_HOSTNAME" "$HEADSCALE_OPENWRT_HOSTNAME_PREFIX" "${WRT_NAME:-router}" "${WRT_IP:-}")"
set_config_option ssh "$HEADSCALE_OPENWRT_ENABLE_SSH"
set_config_option accept_dns 0
set_config_option accept_routes "$HEADSCALE_OPENWRT_ACCEPT_ROUTES"
set_config_option advertise_routes "$HEADSCALE_OPENWRT_ADVERTISE_ROUTES"
set_config_option auth_key_file /etc/tailscale/headscale.authkey
set_config_option delete_auth_key_file 1

echo "headscale auto-enroll: enabled for $HEADSCALE_LOGIN_SERVER with auth key redacted"
