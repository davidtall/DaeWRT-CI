#!/bin/bash
set -euo pipefail

TARGET_FILES="${1:-${GITHUB_WORKSPACE:-$(pwd)}/wrt/files}"

uci_option_value() {
	local file="$1"
	local section_type="$2"
	local section_name="$3"
	local option_name="$4"

	[ -r "$file" ] || return 0
	awk -v wanted_type="$section_type" -v wanted_name="$section_name" -v wanted_option="$option_name" '
		function unquote(value) {
			if (substr(value, 1, 1) == "\047" && substr(value, length(value), 1) == "\047") {
				return substr(value, 2, length(value) - 2)
			}
			if (substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") {
				return substr(value, 2, length(value) - 2)
			}
			return value
		}
		$1 == "config" {
			section_type = $2
			section_name = unquote($3)
			in_section = (section_type == wanted_type && section_name == wanted_name)
			next
		}
		in_section && $1 == "option" && $2 == wanted_option {
			$1 = ""
			$2 = ""
			sub(/^[ \t]+/, "")
			print unquote($0)
			found = 1
			exit
		}
	' "$file"
}

add_reason() {
	local reason="$1"

	case " $reasons " in
		*" $reason "*) ;;
		*) reasons="${reasons:+$reasons,}$reason" ;;
	esac
}

reasons=
wrtbak_config="$TARGET_FILES/etc/config/wrtbak"
headscale_authkey="$TARGET_FILES/etc/tailscale/headscale.authkey"

if [ -r "$wrtbak_config" ]; then
	access_key="$(uci_option_value "$wrtbak_config" remote s3 access_key)"
	secret_key="$(uci_option_value "$wrtbak_config" remote s3 secret_key)"
	proxy_url="$(uci_option_value "$wrtbak_config" wrtbak main proxy_url)"
	[ -z "$access_key" ] || add_reason wrtbak-r2-access-key
	[ -z "$secret_key" ] || add_reason wrtbak-r2-secret-key
	[ -z "$proxy_url" ] || add_reason wrtbak-proxy-url
fi

if [ -s "$headscale_authkey" ]; then
	add_reason headscale-authkey
fi

if [ -n "$reasons" ]; then
	printf 'WRT_PRIVATE_BUILD=true\n'
	printf 'WRT_PRIVATE_BUILD_REASON=%s\n' "$reasons"
	printf 'WRT_ARTIFACT_PRIVACY_SUFFIX=private\n'
	echo "private firmware guard: private-only build detected ($reasons)" >&2
else
	printf 'WRT_PRIVATE_BUILD=false\n'
	printf 'WRT_PRIVATE_BUILD_REASON=\n'
	printf 'WRT_ARTIFACT_PRIVACY_SUFFIX=public\n'
	echo "private firmware guard: no secret-bearing overlay detected" >&2
fi
