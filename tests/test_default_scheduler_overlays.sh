#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTOREBOOT_CONFIG="$ROOT_DIR/files/etc/config/autoreboot"
MOSDNS_CONFIG="$ROOT_DIR/files/etc/config/mosdns"
AUTOREBOOT_ENABLE="$ROOT_DIR/files/etc/uci-defaults/93-autoreboot-enable"
MOSDNS_CRON_BOOTSTRAP="$ROOT_DIR/files/etc/uci-defaults/92-mosdns-geo-cron"

[ -f "$AUTOREBOOT_CONFIG" ] || {
  echo "missing autoreboot config overlay"
  exit 1
}

[ -f "$MOSDNS_CONFIG" ] || {
  echo "missing mosdns config overlay"
  exit 1
}

[ -f "$AUTOREBOOT_ENABLE" ] || {
  echo "missing autoreboot enable defaults"
  exit 1
}

[ -f "$MOSDNS_CRON_BOOTSTRAP" ] || {
  echo "missing mosdns geo cron bootstrap"
  exit 1
}

tr -d '\r' < "$AUTOREBOOT_CONFIG" | grep -q "^config schedule$" || {
  echo "autoreboot config does not define a schedule section"
  exit 1
}

tr -d '\r' < "$AUTOREBOOT_CONFIG" | grep -q "^	option enabled '1'$" || {
  echo "autoreboot config does not enable scheduled reboot"
  exit 1
}

tr -d '\r' < "$AUTOREBOOT_CONFIG" | grep -q "^	option week '0'$" || {
  echo "autoreboot config does not pin Sunday reboot"
  exit 1
}

tr -d '\r' < "$AUTOREBOOT_CONFIG" | grep -q "^	option hour '5'$" || {
  echo "autoreboot config does not move reboot to 05:00"
  exit 1
}

tr -d '\r' < "$AUTOREBOOT_CONFIG" | grep -q "^	option minute '0'$" || {
  echo "autoreboot config does not reboot on minute 0"
  exit 1
}

tr -d '\r' < "$MOSDNS_CONFIG" | grep -q "^config mosdns 'config'$" || {
  echo "mosdns config does not define the main config section"
  exit 1
}

tr -d '\r' < "$MOSDNS_CONFIG" | grep -q "^	option geo_auto_update '1'$" || {
  echo "mosdns config does not enable geo auto update"
  exit 1
}

tr -d '\r' < "$MOSDNS_CONFIG" | grep -q "^	option geo_update_week_time '\*'$" || {
  echo "mosdns config does not schedule updates every day of week"
  exit 1
}

tr -d '\r' < "$MOSDNS_CONFIG" | grep -q "^	option geo_update_day_time '2'$" || {
  echo "mosdns config does not schedule updates at 02:00"
  exit 1
}

grep -q '/etc/init.d/autoreboot enable' "$AUTOREBOOT_ENABLE" || {
  echo "autoreboot defaults do not enable the autoreboot service"
  exit 1
}

grep -q '/etc/init.d/autoreboot start' "$AUTOREBOOT_ENABLE" || {
  echo "autoreboot defaults do not start the autoreboot service"
  exit 1
}

grep -q '/etc/crontabs/root' "$MOSDNS_CRON_BOOTSTRAP" || {
  echo "mosdns cron bootstrap does not target /etc/crontabs/root"
  exit 1
}

grep -q '/usr/share/mosdns/mosdns.uc update' "$MOSDNS_CRON_BOOTSTRAP" || {
  echo "mosdns cron bootstrap does not install the geo update command"
  exit 1
}

grep -q "0 2 \\* \\* \\* /usr/share/mosdns/mosdns.uc update" "$MOSDNS_CRON_BOOTSTRAP" || {
  echo "mosdns cron bootstrap does not schedule the 02:00 daily update"
  exit 1
}

echo "default scheduler overlays test passed"
