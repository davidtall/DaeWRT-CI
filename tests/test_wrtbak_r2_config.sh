#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/Scripts/WrtbakR2Config.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"

[ -f "$SCRIPT" ] || { echo "missing WrtbakR2Config.sh"; exit 1; }
[ "$(git ls-files --stage -- "$SCRIPT" | awk '{print $1}')" = "100755" ] || {
	echo "WrtbakR2Config.sh is not marked executable"
	exit 1
}

grep -q 'WRTBAK_R2_ACCESS_KEY_ID' "$WORKFLOW" || {
	echo "WRT-CORE.yml does not expose WRTBAK_R2_ACCESS_KEY_ID"
	exit 1
}

grep -q 'Scripts/WrtbakR2Config.sh' "$WORKFLOW" || {
	echo "WRT-CORE.yml does not call the wrtbak R2 injector"
	exit 1
}

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

clean_wrtbak_env() {
	env \
		-u WRTBAK_R2_ENDPOINT \
		-u WRTBAK_R2_REGION \
		-u WRTBAK_R2_BUCKET \
		-u WRTBAK_R2_PREFIX \
		-u WRTBAK_R2_ACCESS_KEY_ID \
		-u WRTBAK_R2_SECRET_ACCESS_KEY \
		-u WRTBAK_R2_FORCE_PATH_STYLE \
		-u WRTBAK_DEVICE_ALIAS \
		-u WRTBAK_SITE \
		-u WRTBAK_PROXY_PROFILE \
		-u WRTBAK_PROXY_ARTIFACTS_ENABLED \
		-u WRTBAK_PROXY_UPDATE_MODE \
		-u WRTBAK_PROXY_URL \
		-u WRTBAK_FIRSTBOOT_AUTO_ENABLED \
		-u WRTBAK_FIRSTBOOT_AUTO_TARGET \
		-u WRTBAK_FIRSTBOOT_AUTO_ATTEMPTS \
		-u WRTBAK_FIRSTBOOT_AUTO_SLEEP \
		-u WRTBAK_FIRSTBOOT_AUTO_REBOOT \
		-u WRTBAK_HOME_PROXY_URL \
		-u WRTBAK_OFFICE_PROXY_URL \
		-u WRTBAK_DORM_PROXY_URL \
		"$@"
}

EMPTY_LOG="$WORK_DIR/empty.log"
clean_wrtbak_env bash "$SCRIPT" "$WORK_DIR/empty" >"$EMPTY_LOG"
[ ! -e "$WORK_DIR/empty/etc/config/wrtbak" ] || {
	echo "injector should not create wrtbak config when credentials are empty"
	exit 1
}

ACCESS_KEY="test-access-key"
SECRET_KEY="test-secret-key"
PROXY_URL="http://user:pass@127.0.0.1:7890"
INJECT_LOG="$WORK_DIR/inject.log"

clean_wrtbak_env env \
	WRTBAK_R2_ENDPOINT="https://example.r2.cloudflarestorage.com" \
	WRTBAK_R2_REGION="auto" \
	WRTBAK_R2_BUCKET="knowledge" \
	WRTBAK_R2_PREFIX="openwrt-config-backup/wrtbak/" \
	WRTBAK_R2_ACCESS_KEY_ID="$ACCESS_KEY" \
	WRTBAK_R2_SECRET_ACCESS_KEY="$SECRET_KEY" \
	WRTBAK_DEVICE_ALIAS="office-re-ss-01" \
	WRTBAK_PROXY_PROFILE="office" \
	WRTBAK_OFFICE_PROXY_URL="$PROXY_URL" \
	bash "$SCRIPT" "$WORK_DIR/private" >"$INJECT_LOG"

CONFIG="$WORK_DIR/private/etc/config/wrtbak"
[ -f "$CONFIG" ] || { echo "injector did not create /etc/config/wrtbak"; exit 1; }
DEFAULTS="$WORK_DIR/private/etc/uci-defaults/91-wrtbak-r2-defaults"
BYPASS="$WORK_DIR/private/etc/uci-defaults/92-wrtbak-nikki-r2-bypass"

grep -q "option default_target 's3'" "$CONFIG" || { echo "default target is not s3"; exit 1; }
grep -q "option device_alias 'office-re-ss-01'" "$CONFIG" || { echo "device alias was not written"; exit 1; }
grep -q "option proxy_url '$PROXY_URL'" "$CONFIG" || { echo "profile proxy url was not written"; exit 1; }
grep -q "option site 'office'" "$CONFIG" || { echo "site was not derived from proxy profile"; exit 1; }
grep -q "option proxy_artifacts_enabled '1'" "$CONFIG" || { echo "proxy artifact updates were not enabled"; exit 1; }
grep -q "option proxy_update_mode 'review-required'" "$CONFIG" || { echo "proxy update mode was not written"; exit 1; }
grep -q "option firstboot_auto_enabled '0'" "$CONFIG" || { echo "firstboot auto must stay disabled by default"; exit 1; }
grep -q "option endpoint 'https://example.r2.cloudflarestorage.com'" "$CONFIG" || { echo "endpoint was not written"; exit 1; }
grep -q "option bucket 'knowledge'" "$CONFIG" || { echo "bucket was not written"; exit 1; }
grep -q "option access_key '$ACCESS_KEY'" "$CONFIG" || { echo "access key was not written"; exit 1; }
grep -q "option secret_key '$SECRET_KEY'" "$CONFIG" || { echo "secret key was not written"; exit 1; }
grep -q "option path '/openwrt-config-backup/wrtbak'" "$CONFIG" || { echo "prefix was not normalized"; exit 1; }
grep -q "option force_path_style '1'" "$CONFIG" || { echo "force_path_style was not written"; exit 1; }
grep -q "option enabled '0'" "$CONFIG" || { echo "auto schedule should stay disabled by default"; exit 1; }

[ -f "$DEFAULTS" ] || { echo "injector did not create keep-config uci-defaults migration"; exit 1; }
[ -f "$BYPASS" ] || { echo "injector did not create Nikki R2 fake-ip bypass defaults"; exit 1; }
grep -q "uci set nikki.mixin.fake_ip_filter" "$BYPASS" || { echo "Nikki R2 bypass does not enable fake_ip_filter"; exit 1; }
grep -q "example.r2.cloudflarestorage.com" "$BYPASS" || { echo "Nikki R2 bypass does not include exact R2 endpoint host"; exit 1; }
grep -q "+.r2.cloudflarestorage.com" "$BYPASS" || { echo "Nikki R2 bypass does not include Cloudflare R2 suffix"; exit 1; }
grep -q "uci commit nikki" "$BYPASS" || { echo "Nikki R2 bypass does not commit nikki config"; exit 1; }
grep -q "uci -q get wrtbak.main.site" "$DEFAULTS" || { echo "uci-defaults does not guard existing site"; exit 1; }
grep -q "uci set wrtbak.main.site='office'" "$DEFAULTS" || { echo "uci-defaults does not seed site"; exit 1; }
grep -q "uci set wrtbak.main.proxy_artifacts_enabled='1'" "$DEFAULTS" || { echo "uci-defaults does not seed proxy artifact enable"; exit 1; }
grep -q "uci set wrtbak.main.proxy_update_mode='review-required'" "$DEFAULTS" || { echo "uci-defaults does not seed proxy update mode"; exit 1; }
! grep -q 'wrtbak.main.proxy_url' "$DEFAULTS" || { echo "uci-defaults must not overwrite a preserved daily proxy"; exit 1; }
grep -q "uci set wrtbak.main.firstboot_auto_enabled='0'" "$DEFAULTS" || { echo "uci-defaults does not seed disabled firstboot auto"; exit 1; }
grep -q "uci commit wrtbak" "$DEFAULTS" || { echo "uci-defaults does not commit wrtbak"; exit 1; }

if grep -q "$ACCESS_KEY" "$INJECT_LOG" || grep -q "$SECRET_KEY" "$INJECT_LOG" || grep -q "$PROXY_URL" "$INJECT_LOG"; then
	echo "injector leaked credentials to logs"
	exit 1
fi

PARTIAL_LOG="$WORK_DIR/partial.log"
if clean_wrtbak_env env WRTBAK_R2_ACCESS_KEY_ID="$ACCESS_KEY" bash "$SCRIPT" "$WORK_DIR/partial" >"$PARTIAL_LOG" 2>&1; then
	echo "injector should reject partial credentials"
	exit 1
fi

AUTO_PROFILE_DIR="$WORK_DIR/auto-profile"
clean_wrtbak_env env \
	WRTBAK_R2_ACCESS_KEY_ID="$ACCESS_KEY" \
	WRTBAK_R2_SECRET_ACCESS_KEY="$SECRET_KEY" \
	WRTBAK_PROXY_PROFILE="auto" \
	WRT_IP="192.168.12.1" \
	WRTBAK_DORM_PROXY_URL="http://dorm-proxy.invalid:7890" \
	bash "$SCRIPT" "$AUTO_PROFILE_DIR" >/dev/null

grep -q "option proxy_url 'http://dorm-proxy.invalid:7890'" "$AUTO_PROFILE_DIR/etc/config/wrtbak" || {
	echo "auto proxy profile did not derive dorm proxy from WRT_IP"
	exit 1
}

grep -q "option site 'dorm'" "$AUTO_PROFILE_DIR/etc/config/wrtbak" || {
	echo "auto proxy profile did not derive dorm site from WRT_IP"
	exit 1
}

echo "wrtbak R2 config injector test passed"
