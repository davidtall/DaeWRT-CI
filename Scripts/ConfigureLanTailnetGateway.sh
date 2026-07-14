#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
	echo "usage: $0 <files-overlay-dir> <true|false>" >&2
	exit 1
fi

FILES_DIR="$1"
ENABLE="$2"
TAILSCALE_CONFIG="$FILES_DIR/etc/config/tailscale"

case "$ENABLE" in
	true|false) ;;
	*)
		echo "ERROR: LAN-to-tailnet gateway input must be true or false, got: $ENABLE" >&2
		exit 1
		;;
esac

[ -d "$FILES_DIR" ] || {
	echo "ERROR: files overlay directory does not exist: $FILES_DIR" >&2
	exit 1
}

mkdir -p "$(dirname "$TAILSCALE_CONFIG")"
if [ ! -f "$TAILSCALE_CONFIG" ]; then
	cat >"$TAILSCALE_CONFIG" <<'EOF'
config settings 'settings'
	option log_stderr '1'
	option log_stdout '1'
	option port '41641'
	option state_file '/etc/tailscale/tailscaled.state'
	option fw_mode 'nftables'
	option disable_magic_dns '1'

config lan_bypass_host
	option enabled '0'

config lan_to_tailnet 'lan_to_tailnet'
	option enabled '0'
	option cidr4 '100.64.0.0/10'
	option cidr6 'fd7a:115c:a1e0::/48'
	option dns_domain 'hs.jmsu.top'
	option magicdns '100.100.100.100'
	option masq '1'
EOF
fi

tmp="$(mktemp)"
awk -v enabled="$([ "$ENABLE" = true ] && printf 1 || printf 0)" '
	BEGIN {
		in_section = 0
		section_seen = 0
		enabled_seen = 0
	}
	function maybe_insert_enabled() {
		if (in_section && !enabled_seen) {
			print "\toption enabled '\''" enabled "'\''"
			enabled_seen = 1
		}
	}
	/^config[[:space:]]+/ {
		maybe_insert_enabled()
		in_section = ($0 == "config lan_to_tailnet '\''lan_to_tailnet'\''")
		if (in_section) {
			section_seen = 1
			enabled_seen = 0
		}
		print
		next
	}
	in_section && /^[[:space:]]*option[[:space:]]+enabled[[:space:]]+/ {
		print "\toption enabled '\''" enabled "'\''"
		enabled_seen = 1
		next
	}
	{ print }
	END {
		maybe_insert_enabled()
		if (!section_seen) {
			print ""
			print "config lan_to_tailnet '\''lan_to_tailnet'\''"
			print "\toption enabled '\''" enabled "'\''"
			print "\toption cidr4 '\''100.64.0.0/10'\''"
			print "\toption cidr6 '\''fd7a:115c:a1e0::/48'\''"
			print "\toption dns_domain '\''hs.jmsu.top'\''"
			print "\toption magicdns '\''100.100.100.100'\''"
			print "\toption masq '\''1'\''"
		}
	}
' "$TAILSCALE_CONFIG" >"$tmp"
cat "$tmp" >"$TAILSCALE_CONFIG"
rm -f "$tmp"

exit 0
