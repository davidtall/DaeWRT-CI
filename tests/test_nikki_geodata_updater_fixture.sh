#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATER="$ROOT_DIR/files/usr/bin/nikki-geodata-updater"
PYTHON_BIN="${PYTHON_BIN:-python3}"

if ! "$PYTHON_BIN" --version >/dev/null 2>&1; then
  PYTHON_BIN=python
fi

"$PYTHON_BIN" --version >/dev/null 2>&1 || {
  echo "missing python interpreter for fixture test"
  exit 1
}

WORK_DIR="$(mktemp -d)"
FIXTURE_DIR="$WORK_DIR/fixture"
TARGET_DIR="$WORK_DIR/target"
FAKE_ROOT="$WORK_DIR/fake-root"
TEST_UPDATER="$WORK_DIR/nikki-geodata-updater.test"
LOG_FILE="$WORK_DIR/service.log"
HTTP_PORT=18888
HTTP_PID=""

cleanup() {
  local rc=$?
  [ -n "$HTTP_PID" ] && kill "$HTTP_PID" >/dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
  exit "$rc"
}
trap cleanup EXIT INT TERM

mkdir -p "$FIXTURE_DIR" "$TARGET_DIR" "$FAKE_ROOT/etc/init.d" "$FAKE_ROOT/usr/bin"

"$PYTHON_BIN" - "$UPDATER" "$TEST_UPDATER" "$FAKE_ROOT/etc/init.d" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1]).read_text()
src = src.replace('/etc/init.d/', sys.argv[3] + '/')
Path(sys.argv[2]).write_text(src)
PY

printf 'old-geoip' >"$TARGET_DIR/geoip.dat"
printf 'old-geosite' >"$TARGET_DIR/geosite.dat"
printf 'old-metadb' >"$TARGET_DIR/geoip.metadb"

printf 'new-geoip' >"$FIXTURE_DIR/geoip.dat"
printf 'new-geosite' >"$FIXTURE_DIR/geosite.dat"
printf 'new-metadb' >"$FIXTURE_DIR/geoip.metadb"

(cd "$FIXTURE_DIR" && sha256sum geoip.dat >geoip.dat.sha256sum)
(cd "$FIXTURE_DIR" && sha256sum geosite.dat >geosite.dat.sha256sum)
(cd "$FIXTURE_DIR" && sha256sum geoip.metadb >geoip.metadb.sha256sum)

cat >"$FAKE_ROOT/etc/init.d/fake-nikki" <<'EOF'
#!/bin/sh
set -eu
LOG_FILE="${LOG_FILE:?}"
STATE_FILE="${STATE_FILE:?}"
cmd="${1:-}"
echo "$cmd" >>"$LOG_FILE"
case "$cmd" in
  restart)
    echo running >"$STATE_FILE"
    ;;
  running)
    [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "running" ]
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$FAKE_ROOT/etc/init.d/fake-nikki"

cat >"$FAKE_ROOT/usr/bin/logger" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_ROOT/usr/bin/logger"

"$PYTHON_BIN" -m http.server "$HTTP_PORT" --directory "$FIXTURE_DIR" >/dev/null 2>&1 &
HTTP_PID=$!

for _ in $(seq 1 20); do
  if curl -fsS "http://127.0.0.1:$HTTP_PORT/geoip.dat.sha256sum" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

curl -fsS "http://127.0.0.1:$HTTP_PORT/geoip.dat.sha256sum" >/dev/null 2>&1 || {
  echo "fixture HTTP server did not become ready"
  exit 1
}

PATH="$FAKE_ROOT/usr/bin:$PATH" \
LOG_FILE="$LOG_FILE" \
STATE_FILE="$WORK_DIR/service.state" \
TARGET_DIR="$TARGET_DIR" \
SERVICE_NAME="fake-nikki" \
LOCK_DIR="$WORK_DIR/nikki-geodata-updater.lock" \
PRIMARY_BASE="http://127.0.0.1:$HTTP_PORT" \
CHECKSUM_BASE="http://127.0.0.1:$HTTP_PORT" \
MIRROR_BASES="" \
TMP_ROOT="$WORK_DIR" \
sh "$TEST_UPDATER"

test "$(cat "$TARGET_DIR/geoip.dat")" = "new-geoip"
test "$(cat "$TARGET_DIR/geosite.dat")" = "new-geosite"
test "$(cat "$TARGET_DIR/geoip.metadb")" = "new-metadb"
test "$(stat -c '%a' "$TARGET_DIR/geoip.dat")" = "644"
test "$(stat -c '%a' "$TARGET_DIR/geosite.dat")" = "644"
test "$(stat -c '%a' "$TARGET_DIR/geoip.metadb")" = "644"
grep -q '^restart$' "$LOG_FILE"

before_restarts="$(grep -c '^restart$' "$LOG_FILE")"
PATH="$FAKE_ROOT/usr/bin:$PATH" \
LOG_FILE="$LOG_FILE" \
STATE_FILE="$WORK_DIR/service.state" \
TARGET_DIR="$TARGET_DIR" \
SERVICE_NAME="fake-nikki" \
LOCK_DIR="$WORK_DIR/nikki-geodata-updater.lock" \
PRIMARY_BASE="http://127.0.0.1:$HTTP_PORT" \
CHECKSUM_BASE="http://127.0.0.1:$HTTP_PORT" \
MIRROR_BASES="" \
TMP_ROOT="$WORK_DIR" \
sh "$TEST_UPDATER"
after_restarts="$(grep -c '^restart$' "$LOG_FILE")"
[ "$before_restarts" -eq "$after_restarts" ] || {
  echo "updater restarted the service even though nothing changed"
  exit 1
}

echo "nikki geodata updater fixture test passed"
