#!/bin/bash
set -euo pipefail

TARGET_FILES="${1:-${GITHUB_WORKSPACE:-$(pwd)}/wrt/files}"
CONFIG_FILE="$TARGET_FILES/etc/config/wrtbak"
DEFAULTS_FILE="$TARGET_FILES/etc/uci-defaults/91-wrtbak-r2-defaults"
NIKKI_BYPASS_FILE="$TARGET_FILES/etc/uci-defaults/92-wrtbak-nikki-r2-bypass"

R2_ENDPOINT="${WRTBAK_R2_ENDPOINT:-https://a15eff50866373c517f961928c24c54a.r2.cloudflarestorage.com}"
R2_REGION="${WRTBAK_R2_REGION:-auto}"
R2_BUCKET="${WRTBAK_R2_BUCKET:-knowledge}"
R2_PREFIX="${WRTBAK_R2_PREFIX:-openwrt-config-backup/wrtbak}"
R2_ACCESS_KEY_ID="${WRTBAK_R2_ACCESS_KEY_ID:-}"
R2_SECRET_ACCESS_KEY="${WRTBAK_R2_SECRET_ACCESS_KEY:-}"
R2_FORCE_PATH_STYLE="${WRTBAK_R2_FORCE_PATH_STYLE:-1}"
DEVICE_ALIAS="${WRTBAK_DEVICE_ALIAS:-}"
SITE_NAME="${WRTBAK_SITE:-}"
PROXY_PROFILE="${WRTBAK_PROXY_PROFILE:-}"
PROXY_ARTIFACTS_ENABLED="${WRTBAK_PROXY_ARTIFACTS_ENABLED:-1}"
PROXY_UPDATE_MODE="${WRTBAK_PROXY_UPDATE_MODE:-review-required}"
PROXY_URL="${WRTBAK_PROXY_URL:-}"
FIRSTBOOT_AUTO_ENABLED="${WRTBAK_FIRSTBOOT_AUTO_ENABLED:-0}"
FIRSTBOOT_AUTO_TARGET="${WRTBAK_FIRSTBOOT_AUTO_TARGET:-s3}"
FIRSTBOOT_AUTO_ATTEMPTS="${WRTBAK_FIRSTBOOT_AUTO_ATTEMPTS:-18}"
FIRSTBOOT_AUTO_SLEEP="${WRTBAK_FIRSTBOOT_AUTO_SLEEP:-10}"
FIRSTBOOT_AUTO_REBOOT="${WRTBAK_FIRSTBOOT_AUTO_REBOOT:-1}"

has_newline_or_quote() {
	case "$1" in
		*$'\n'*|*$'\r'*|*"'"*)
			return 0
			;;
	esac
	return 1
}

require_uci_safe() {
	local name="$1"
	local value="$2"

	if has_newline_or_quote "$value"; then
		echo "wrtbak R2 config: $name contains unsupported newline or single quote" >&2
		exit 1
	fi
}

require_simple_name() {
	local name="$1"
	local value="$2"

	case "$value" in
		""|*[!A-Za-z0-9._-]*)
			if [ -n "$value" ]; then
				echo "wrtbak R2 config: $name must match [A-Za-z0-9._-]+" >&2
				exit 1
			fi
			;;
	esac
}

require_bool_01() {
	local name="$1"
	local value="$2"

	case "$value" in
		0|1) ;;
		*)
			echo "wrtbak R2 config: $name must be 0 or 1" >&2
			exit 1
			;;
	esac
}

require_uint() {
	local name="$1"
	local value="$2"

	case "$value" in
		""|*[!0-9]*)
			echo "wrtbak R2 config: $name must be a non-negative integer" >&2
			exit 1
			;;
	esac
}

normalize_path() {
	local value="$1"

	while [ "${value#/}" != "$value" ]; do
		value="${value#/}"
	done
	while [ "${value%/}" != "$value" ]; do
		value="${value%/}"
	done

	if [ -n "$value" ]; then
		printf '/%s\n' "$value"
	else
		printf '/\n'
	fi
}

endpoint_host() {
	local value="$1"

	case "$value" in
		*://*) value="${value#*://}" ;;
	esac
	value="${value%%/*}"
	value="${value%%:*}"
	printf '%s\n' "$value"
}

site_proxy_profile() {
	case "${WRT_IP:-}" in
		192.168.10.*) printf 'home\n' ;;
		192.168.11.*) printf 'office\n' ;;
		192.168.12.*) printf 'dorm\n' ;;
		*) printf '\n' ;;
	esac
}

resolve_proxy_url() {
	local profile="$1"

	if [ -n "$PROXY_URL" ]; then
		printf '%s\n' "$PROXY_URL"
		return 0
	fi

	if [ -z "$profile" ] || [ "$profile" = "auto" ]; then
		profile="$(site_proxy_profile)"
	fi

	case "$profile" in
		home) printf '%s\n' "${WRTBAK_HOME_PROXY_URL:-}" ;;
		office) printf '%s\n' "${WRTBAK_OFFICE_PROXY_URL:-}" ;;
		dorm) printf '%s\n' "${WRTBAK_DORM_PROXY_URL:-}" ;;
		"") printf '\n' ;;
		*)
			echo "wrtbak R2 config: unknown WRTBAK_PROXY_PROFILE '$profile'" >&2
			exit 1
			;;
	esac
}

resolve_site_name() {
	local profile="$1"

	if [ -n "$SITE_NAME" ]; then
		printf '%s\n' "$SITE_NAME"
		return 0
	fi

	if [ -z "$profile" ] || [ "$profile" = "auto" ]; then
		profile="$(site_proxy_profile)"
	fi

	printf '%s\n' "$profile"
}

case "${R2_ACCESS_KEY_ID:+set}:${R2_SECRET_ACCESS_KEY:+set}" in
	:)
		echo "wrtbak R2 config: credentials are empty; leaving remote target disabled"
		exit 0
		;;
	set:set)
		;;
	*)
		echo "wrtbak R2 config: access key and secret key must be provided together" >&2
		exit 1
		;;
esac

require_uci_safe endpoint "$R2_ENDPOINT"
R2_ENDPOINT_HOST="$(endpoint_host "$R2_ENDPOINT")"
[ -n "$R2_ENDPOINT_HOST" ] || { echo "wrtbak R2 config: endpoint host is empty" >&2; exit 1; }
require_uci_safe endpoint_host "$R2_ENDPOINT_HOST"
case "$R2_ENDPOINT_HOST" in
	*.r2.cloudflarestorage.com) R2_ENDPOINT_SUFFIX="+.r2.cloudflarestorage.com" ;;
	*) R2_ENDPOINT_SUFFIX="" ;;
esac
require_uci_safe endpoint_suffix "$R2_ENDPOINT_SUFFIX"
require_uci_safe region "$R2_REGION"
require_uci_safe bucket "$R2_BUCKET"
require_uci_safe prefix "$R2_PREFIX"
require_uci_safe access_key "$R2_ACCESS_KEY_ID"
require_uci_safe secret_key "$R2_SECRET_ACCESS_KEY"
require_uci_safe device_alias "$DEVICE_ALIAS"

SITE_NAME="$(resolve_site_name "$PROXY_PROFILE")"
PROXY_URL="$(resolve_proxy_url "$PROXY_PROFILE")"
require_uci_safe proxy_url "$PROXY_URL"
require_uci_safe site "$SITE_NAME"
require_uci_safe proxy_artifacts_enabled "$PROXY_ARTIFACTS_ENABLED"
require_uci_safe proxy_update_mode "$PROXY_UPDATE_MODE"
require_uci_safe firstboot_auto_target "$FIRSTBOOT_AUTO_TARGET"
require_simple_name site "$SITE_NAME"
require_bool_01 proxy_artifacts_enabled "$PROXY_ARTIFACTS_ENABLED"
require_bool_01 firstboot_auto_enabled "$FIRSTBOOT_AUTO_ENABLED"
require_bool_01 firstboot_auto_reboot "$FIRSTBOOT_AUTO_REBOOT"
require_uint firstboot_auto_attempts "$FIRSTBOOT_AUTO_ATTEMPTS"
require_uint firstboot_auto_sleep "$FIRSTBOOT_AUTO_SLEEP"
case "$PROXY_UPDATE_MODE" in
	review-required|disabled) ;;
	*)
		echo "wrtbak R2 config: proxy_update_mode must be review-required or disabled" >&2
		exit 1
		;;
esac
case "$FIRSTBOOT_AUTO_TARGET" in
	default|webdav|s3) ;;
	*)
		echo "wrtbak R2 config: firstboot_auto_target must be default, webdav, or s3" >&2
		exit 1
		;;
esac
R2_PREFIX="$(normalize_path "$R2_PREFIX")"

mkdir -p "$(dirname "$CONFIG_FILE")"
umask 077

cat >"$CONFIG_FILE" <<EOF
config wrtbak 'main'
	option enabled '1'
	option max_upload_mb '32'
	option output_dir '/tmp/wrtbak'
	option rollback_dir '/overlay/wrtbak/rollback'
	option default_mode 'review-required'
	option default_target 's3'
	option device_alias '$DEVICE_ALIAS'
	option site '$SITE_NAME'
	option proxy_artifacts_enabled '$PROXY_ARTIFACTS_ENABLED'
	option proxy_update_mode '$PROXY_UPDATE_MODE'
	option proxy_url '$PROXY_URL'
	option firstboot_auto_enabled '$FIRSTBOOT_AUTO_ENABLED'
	option firstboot_auto_target '$FIRSTBOOT_AUTO_TARGET'
	option firstboot_auto_attempts '$FIRSTBOOT_AUTO_ATTEMPTS'
	option firstboot_auto_sleep '$FIRSTBOOT_AUTO_SLEEP'
	option firstboot_auto_reboot '$FIRSTBOOT_AUTO_REBOOT'
	option history_file '/overlay/wrtbak/remote-history.jsonl'
	option history_max_entries '20'
	option keep_local_after_upload '0'

config remote 'webdav'
	option enabled '0'
	option driver 'curl'
	option url ''
	option username ''
	option password ''
	option path '/'

config remote 's3'
	option enabled '1'
	option driver 'rclone'
	option endpoint '$R2_ENDPOINT'
	option region '$R2_REGION'
	option bucket '$R2_BUCKET'
	option access_key '$R2_ACCESS_KEY_ID'
	option secret_key '$R2_SECRET_ACCESS_KEY'
	option path '$R2_PREFIX'
	option force_path_style '$R2_FORCE_PATH_STYLE'

config schedule 'auto'
	option enabled '0'
	option frequency 'daily'
	option time '03:30'
	option weekday '0'
	option day_of_month '1'
	option profile 'auto'
	option items 'all'
	option format 'wrtbak'
	option max_backups '0'
	option target 's3'
EOF

chmod 600 "$CONFIG_FILE" 2>/dev/null || true

mkdir -p "$(dirname "$DEFAULTS_FILE")"
cat >"$DEFAULTS_FILE" <<EOF
#!/bin/sh
set -eu

changed=0
uci -q get wrtbak.main >/dev/null || {
	uci set wrtbak.main='wrtbak'
	changed=1
}

if ! uci -q get wrtbak.main.site >/dev/null; then
	uci set wrtbak.main.site='$SITE_NAME'
	changed=1
fi

if ! uci -q get wrtbak.main.proxy_artifacts_enabled >/dev/null; then
	uci set wrtbak.main.proxy_artifacts_enabled='$PROXY_ARTIFACTS_ENABLED'
	changed=1
fi

if ! uci -q get wrtbak.main.proxy_update_mode >/dev/null; then
	uci set wrtbak.main.proxy_update_mode='$PROXY_UPDATE_MODE'
	changed=1
fi

if ! uci -q get wrtbak.main.firstboot_auto_enabled >/dev/null; then
	uci set wrtbak.main.firstboot_auto_enabled='$FIRSTBOOT_AUTO_ENABLED'
	changed=1
fi

if ! uci -q get wrtbak.main.firstboot_auto_target >/dev/null; then
	uci set wrtbak.main.firstboot_auto_target='$FIRSTBOOT_AUTO_TARGET'
	changed=1
fi

if ! uci -q get wrtbak.main.firstboot_auto_attempts >/dev/null; then
	uci set wrtbak.main.firstboot_auto_attempts='$FIRSTBOOT_AUTO_ATTEMPTS'
	changed=1
fi

if ! uci -q get wrtbak.main.firstboot_auto_sleep >/dev/null; then
	uci set wrtbak.main.firstboot_auto_sleep='$FIRSTBOOT_AUTO_SLEEP'
	changed=1
fi

if ! uci -q get wrtbak.main.firstboot_auto_reboot >/dev/null; then
	uci set wrtbak.main.firstboot_auto_reboot='$FIRSTBOOT_AUTO_REBOOT'
	changed=1
fi

if [ "\$changed" = "1" ]; then
	uci commit wrtbak
fi

exit 0
EOF
chmod 755 "$DEFAULTS_FILE" 2>/dev/null || true

mkdir -p "$(dirname "$NIKKI_BYPASS_FILE")"
cat >"$NIKKI_BYPASS_FILE" <<EOF
#!/bin/sh
set -eu

uci -q get nikki.mixin >/dev/null || exit 0

changed=0

ensure_list_value() {
	value=\$1
	if ! uci -q get nikki.mixin.fake_ip_filters | tr ' ' '\n' | grep -Fx "\$value" >/dev/null 2>&1; then
		uci add_list nikki.mixin.fake_ip_filters="\$value"
		changed=1
	fi
}

if [ "\$(uci -q get nikki.mixin.fake_ip_filter || true)" != "1" ]; then
	uci set nikki.mixin.fake_ip_filter='1'
	changed=1
fi

ensure_list_value '$R2_ENDPOINT_HOST'
EOF
if [ -n "$R2_ENDPOINT_SUFFIX" ]; then
	printf "ensure_list_value '%s'\n" "$R2_ENDPOINT_SUFFIX" >>"$NIKKI_BYPASS_FILE"
fi
cat >>"$NIKKI_BYPASS_FILE" <<'EOF'

if [ "$changed" = "1" ]; then
	uci commit nikki
fi

exit 0
EOF
chmod 755 "$NIKKI_BYPASS_FILE" 2>/dev/null || true

if [ -n "$PROXY_URL" ]; then
	proxy_status=present
else
	proxy_status=empty
fi

echo "wrtbak R2 config: enabled endpoint=$R2_ENDPOINT bucket=$R2_BUCKET prefix=$R2_PREFIX alias=${DEVICE_ALIAS:-unset} site=${SITE_NAME:-unset} proxy=$proxy_status proxy_artifacts=$PROXY_ARTIFACTS_ENABLED firstboot_auto=$FIRSTBOOT_AUTO_ENABLED"
