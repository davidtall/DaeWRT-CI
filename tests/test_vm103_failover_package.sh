#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$ROOT_DIR/package/vm103-failover"
MAKEFILE="$PKG_DIR/Makefile"
PROGRAM="$PKG_DIR/files/usr/sbin/vm103-failover"
INIT="$PKG_DIR/files/etc/init.d/vm103-failover"

[ -f "$MAKEFILE" ] || { echo "missing vm103-failover Makefile"; exit 1; }
[ -f "$PROGRAM" ] || { echo "missing vm103-failover program"; exit 1; }
[ -f "$INIT" ] || { echo "missing vm103-failover init script"; exit 1; }

[ "$(sha256sum "$PROGRAM" | cut -d ' ' -f 1)" = 'e7279acc688a09c29f553d349c52ac65213a2239bac7cb18a62c36acb89e1aee' ]
[ "$(sha256sum "$INIT" | cut -d ' ' -f 1)" = '63467355c228aed63187a480c08f8fc2196240e617f9376946d978a3f3f8b968' ]

grep -Fq '# SPDX-License-Identifier: MIT' "$MAKEFILE"
grep -Eq '^[[:space:]]*PKGARCH:=all$' "$MAKEFILE"
grep -Eq '^[[:space:]]*DEPENDS:=.*\+gre([[:space:]]|$)' "$MAKEFILE"
grep -Eq '^[[:space:]]*DEPENDS:=.*\+ip-full([[:space:]]|$)' "$MAKEFILE"
grep -Fq '$(INSTALL_BIN) $(CURDIR)/files/usr/sbin/vm103-failover $(1)/usr/sbin/vm103-failover' "$MAKEFILE"
grep -Fq '$(INSTALL_BIN) $(CURDIR)/files/etc/init.d/vm103-failover $(1)/etc/init.d/vm103-failover' "$MAKEFILE"

grep -qx 'USE_PROCD=1' "$INIT"
grep -Fq 'procd_set_param command /usr/sbin/vm103-failover' "$INIT"
grep -Fq 'procd_set_param respawn 3600 5 5' "$INIT"
grep -Fq '/usr/sbin/vm103-failover --primary >/dev/null 2>&1 || true' "$INIT"

for constant in \
	'PRIMARY_GW="192.168.9.1"' \
	'PRIMARY_DEV="wan"' \
	'PRIMARY_SRC="192.168.9.243"' \
	'PRIMARY_TABLE="201"' \
	'PRIMARY_RULE_PREF="1100"' \
	'BACKUP_GW="172.31.103.1"' \
	'BACKUP_DEV="gre4-gre_vm103"' \
	'BACKUP_SRC="172.31.103.2"' \
	'BACKUP_TABLE="203"' \
	'BACKUP_RULE_PREF="1110"' \
	'LAN_DEV="br-lan"' \
	'BACKUP6_GW="fd42:103:1::1"' \
	'BACKUP6_DEV="gre4-gre_vm103"' \
	'BACKUP6_SRC="fd42:103:1::2"' \
	'BACKUP6_TABLE="204"' \
	'BACKUP6_RULE_PREF="1090"' \
	'TARGETS="223.5.5.5 119.29.29.29 9.9.9.9"' \
	'RELIABILITY="2"' \
	'DOWN_THRESHOLD="3"' \
	'UP_THRESHOLD="5"' \
	'INTERVAL="5"' \
	'STATE_FILE="/var/run/vm103-failover.state"'; do
	grep -Fqx "$constant" "$PROGRAM"
done
grep -Fq '[ "$down_count" -ge "$DOWN_THRESHOLD" ]' "$PROGRAM"
grep -Fq '[ "$up_count" -ge "$UP_THRESHOLD" ]' "$PROGRAM"

if grep -RniE '(pppoe|password|passwd|secret|token|credential|access[_-]?key|private[_-]?key|proxy_auth|(^|[^[:alnum:]_])r2([^[:alnum:]_]|$))' "$PKG_DIR"; then
	echo "vm103-failover package contains a forbidden credential field"
	exit 1
fi
if grep -RniE 'uci[[:space:]]+(set|add|commit)|/etc/uci-defaults|firstboot' "$PKG_DIR"; then
	echo "vm103-failover package contains automatic configuration or restore logic"
	exit 1
fi

echo "vm103-failover package guards passed"
