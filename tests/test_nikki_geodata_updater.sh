#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATER="$ROOT_DIR/files/usr/bin/nikki-geodata-updater"
CRON_BOOTSTRAP="$ROOT_DIR/files/etc/uci-defaults/99-nikki-geodata-cron"

[ -f "$UPDATER" ] || { echo "missing nikki geodata updater script"; exit 1; }

sh -n "$UPDATER"

grep -q 'set -eu' "$UPDATER" || {
  echo "updater script does not enable set -eu"
  exit 1
}

grep -q 'geoip.dat geosite.dat geoip.metadb' "$UPDATER" || {
  echo "updater script does not target all Nikki geodata files"
  exit 1
}

grep -q 'mkdir "$LOCK_DIR"' "$UPDATER" || {
  echo "updater script does not use a lock directory"
  exit 1
}

grep -q '\.sha256sum' "$UPDATER" || {
  echo "updater script does not fetch checksum files first"
  exit 1
}

grep -q 'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest' "$UPDATER" || {
  echo "updater script does not use the MetaCubeX primary source"
  exit 1
}

grep -q 'https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release' "$UPDATER" || {
  echo "updater script does not include the jsDelivr mirror"
  exit 1
}

grep -q 'https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release' "$UPDATER" || {
  echo "updater script does not include the testingcf jsDelivr mirror"
  exit 1
}

grep -q 'chmod 644 "$target_file"' "$UPDATER" || {
  echo "updater script does not normalize replaced files to mode 644"
  exit 1
}

grep -q '/etc/init.d/"$SERVICE_NAME" restart' "$UPDATER" || {
  echo "updater script does not restart Nikki after updates"
  exit 1
}

grep -q 'restoring previous geodata after restart failure' "$UPDATER" || {
  echo "updater script does not log rollback on restart failure"
  exit 1
}

[ -f "$CRON_BOOTSTRAP" ] || { echo "missing Nikki cron bootstrap script"; exit 1; }

sh -n "$CRON_BOOTSTRAP"

grep -q '/etc/crontabs/root' "$CRON_BOOTSTRAP" || {
  echo "cron bootstrap does not target /etc/crontabs/root"
  exit 1
}

grep -q 'grep -qF' "$CRON_BOOTSTRAP" || {
  echo "cron bootstrap does not de-duplicate the cron job"
  exit 1
}

grep -q 'crontab /etc/crontabs/root' "$CRON_BOOTSTRAP" || {
  echo "cron bootstrap does not reload crond after modifications"
  exit 1
}

grep -q '/usr/bin/nikki-geodata-updater' "$CRON_BOOTSTRAP" || {
  echo "cron bootstrap does not inspect existing Nikki updater cron entries conservatively"
  exit 1
}

grep -q '30 3 \* \* 0 /usr/bin/nikki-geodata-updater >/tmp/nikki-geodata-updater.log 2>&1' "$CRON_BOOTSTRAP" || {
  echo "cron bootstrap does not install the weekly Nikki geodata update job"
  exit 1
}

echo "nikki geodata updater static guard test passed"
