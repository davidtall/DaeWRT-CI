# Nikki Geodata Updater Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a firmware-bundled Nikki geodata updater with weekly cron wiring, checksum-verified batch replacement, rollback-safe Nikki restarts, and repository-level static and dynamic validation.

**Architecture:** Keep build-time Nikki geodata preload in `Scripts/Handles.sh` unchanged, and add a separate runtime updater through the OpenWrt `files/` overlay. The updater will use official checksum files, primary and mirror payload URLs, a lock directory, a temp staging directory, and all-or-nothing replacement semantics. First-boot cron wiring will be handled by a `uci-defaults` script so the updater is available immediately after flashing without modifying Nikki package internals.

**Tech Stack:** POSIX shell, OpenWrt `files/` overlay, `uci-defaults`, `curl`, `sha256sum`, `logger`, repository bash guard tests, Python `http.server` for local fixture validation

---

## File Structure

**Create**

- `files/usr/bin/nikki-geodata-updater`
- `files/etc/uci-defaults/99-nikki-geodata-cron`
- `tests/test_nikki_geodata_updater.sh`
- `tests/test_nikki_geodata_updater_fixture.sh`

**Modify**

- none required for application logic unless repository guard patterns reveal a workflow assertion gap

**Reference During Implementation**

- `Scripts/Handles.sh`
- `package/v2ray-geodata/v2ray-geodata-updater`
- `package/v2ray-geodata/init.sh`
- `tests/test_nikki_geodata_preload.sh`
- `docs/superpowers/specs/2026-03-25-nikki-geodata-updater-design.md`

## Chunk 1: Runtime Script and Static Contract

### Task 1: Add a failing repository guard for the Nikki updater contract

**Files:**
- Create: `tests/test_nikki_geodata_updater.sh`

- [ ] **Step 1: Write the failing static guard test**

Create `tests/test_nikki_geodata_updater.sh` with checks for:

This first guard intentionally covers only the runtime updater script. The cron bootstrap assertions are added in Task 3, when `files/etc/uci-defaults/99-nikki-geodata-cron` is introduced.

```bash
#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATER="$ROOT_DIR/files/usr/bin/nikki-geodata-updater"

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

echo "nikki geodata updater static guard test passed"
```

- [ ] **Step 2: Run the new test to verify it fails**

Run:

```bash
bash tests/test_nikki_geodata_updater.sh
```

Expected: FAIL because neither the updater script nor the cron bootstrap exists yet.

- [ ] **Step 3: Commit the failing-test checkpoint**

```bash
git add tests/test_nikki_geodata_updater.sh
git commit -m "test: add nikki geodata updater guard"
```

### Task 2: Implement the runtime Nikki geodata updater script

**Files:**
- Create: `files/usr/bin/nikki-geodata-updater`
- Modify: `tests/test_nikki_geodata_updater.sh`

- [ ] **Step 1: Write the minimal shell script skeleton**

Create `files/usr/bin/nikki-geodata-updater` with the required variable surface and support functions:

```sh
#!/bin/sh

set -eu

LOGGER_TAG="${LOGGER_TAG:-nikki-geodata-updater}"
TARGET_DIR="${TARGET_DIR:-/etc/nikki/run}"
SERVICE_NAME="${SERVICE_NAME:-nikki}"
LOCK_DIR="${LOCK_DIR:-/var/run/nikki-geodata-updater.lock}"
TMP_ROOT="${TMP_ROOT:-/tmp}"
PROXY_URL="${PROXY_URL:-}"
PROXY_USER="${PROXY_USER:-}"

FILES="geoip.dat geosite.dat geoip.metadb"
PRIMARY_BASE="${PRIMARY_BASE:-https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest}"
CHECKSUM_BASE="${CHECKSUM_BASE:-$PRIMARY_BASE}"
DEFAULT_MIRROR_BASES='https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release
https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release'
MIRROR_BASES="${MIRROR_BASES:-$DEFAULT_MIRROR_BASES}"
```

- [ ] **Step 2: Add logging, cleanup, and dependency checks**

Implement:

```sh
log() {
	echo "$@"
	logger -t "$LOGGER_TAG" "$@"
}

cleanup() {
	local rc="$?"
	[ -n "${TMP_DIR:-}" ] && rm -rf "$TMP_DIR"
	if [ "${LOCK_ACQUIRED:-0}" = "1" ]; then
		rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
	fi
	exit "$rc"
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || {
		log "missing required command: $1"
		exit 1
	}
}
```

- [ ] **Step 3: Add a proxy-aware fetch helper**

Implement `fetch_file()` using `curl -fsSL`, optional `--proxy` / `--proxy-user`, and bounded retry behavior:

```sh
fetch_file() {
	local url="$1"
	local out="$2"

	if [ -n "$PROXY_URL" ]; then
		if [ -n "$PROXY_USER" ]; then
			curl -fsSL --proxy "$PROXY_URL" --proxy-user "$PROXY_USER" \
				--connect-timeout 10 --max-time 180 --retry 2 --retry-delay 2 --retry-all-errors \
				-o "$out" "$url"
		else
			curl -fsSL --proxy "$PROXY_URL" \
				--connect-timeout 10 --max-time 180 --retry 2 --retry-delay 2 --retry-all-errors \
				-o "$out" "$url"
		fi
	else
		curl -fsSL \
			--connect-timeout 10 --max-time 180 --retry 2 --retry-delay 2 --retry-all-errors \
			-o "$out" "$url"
	fi
}
```

- [ ] **Step 4: Add checksum retrieval and verified payload download helpers**

Implement:

```sh
fetch_expected_sum() {
	local file="$1"
	local out="$2"

	fetch_file "$CHECKSUM_BASE/$file.sha256sum" "$out"
}

download_verified_file() {
	local file="$1"
	local expected_sum="$2"
	local out="$3"
	local url

	for url in "$PRIMARY_BASE/$file"; do
		if fetch_file "$url" "$out" && [ "$(sha256sum "$out" | awk '{print $1}')" = "$expected_sum" ]; then
			return 0
		fi
		rm -f "$out"
	done

	for url in $MIRROR_BASES; do
		if fetch_file "$url/$file" "$out" && [ "$(sha256sum "$out" | awk '{print $1}')" = "$expected_sum" ]; then
			return 0
		fi
		rm -f "$out"
	done

	return 1
}
```

- [ ] **Step 5: Add restart verification and rollback-safe update flow**

Implement:

```sh
restart_service() {
	if ! /etc/init.d/"$SERVICE_NAME" restart; then
		log "failed to restart $SERVICE_NAME"
		return 1
	fi

	if ! /etc/init.d/"$SERVICE_NAME" running >/dev/null 2>&1; then
		log "$SERVICE_NAME is not running after restart"
		return 1
	fi

	return 0
}
```

Then implement the main flow exactly as described in the spec:

- require `curl`, `sha256sum`, and `awk`
- acquire the lock with `mkdir "$LOCK_DIR"`
- set `LOCK_ACQUIRED=1` only after `mkdir "$LOCK_DIR"` succeeds
- create `TMP_DIR="$(mktemp -d "$TMP_ROOT/nikki-geodata-updater.XXXXXX")"`
- `trap cleanup EXIT INT TERM`
- `mkdir -p "$TARGET_DIR"`
- for each file:
  - fetch checksum
  - parse expected sum with `awk 'NR==1 {print $1}'`
  - skip if current target hash already matches
  - otherwise download a verified staged copy
- if no file changed, log success and exit `0`
- if files changed:
  - backup old targets to `"$TMP_DIR/$file.bak"` when present
  - copy staged files into place
  - `chmod 644 "$target_file"`
- if `restart_service` succeeds, log the completed update and exit `0`
- if `restart_service` fails:
  - restore backups for changed files
  - reapply `chmod 644`
  - `restart_service || true`
  - exit `1`

- [ ] **Step 6: Mark the updater executable in git**

Run:

```bash
git update-index --add --chmod=+x files/usr/bin/nikki-geodata-updater
```

- [ ] **Step 7: Run the static guard to verify it passes**

Run:

```bash
bash tests/test_nikki_geodata_updater.sh
```

Expected: PASS with `nikki geodata updater static guard test passed`.

- [ ] **Step 8: Commit the runtime script**

```bash
git add files/usr/bin/nikki-geodata-updater tests/test_nikki_geodata_updater.sh
git commit -m "feat: add runtime nikki geodata updater"
```

## Chunk 2: Cron Wiring and Dynamic Fixture Validation

### Task 3: Add first-boot cron wiring for weekly Nikki geodata updates

**Files:**
- Create: `files/etc/uci-defaults/99-nikki-geodata-cron`
- Modify: `tests/test_nikki_geodata_updater.sh`

- [ ] **Step 1: Extend the static test with cron bootstrap contract**

If the initial version of `tests/test_nikki_geodata_updater.sh` does not already assert these exact behaviors, add checks for:

```bash
CRON_BOOTSTRAP="$ROOT_DIR/files/etc/uci-defaults/99-nikki-geodata-cron"
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
```

- [ ] **Step 2: Run the static guard and verify it fails**

Run:

```bash
bash tests/test_nikki_geodata_updater.sh
```

Expected: FAIL because the cron bootstrap script still does not exist.

- [ ] **Step 3: Implement the cron bootstrap**

Create `files/etc/uci-defaults/99-nikki-geodata-cron`:

```sh
#!/bin/sh

CRON_FILE=/etc/crontabs/root
CRON_LINE='30 3 * * 0 /usr/bin/nikki-geodata-updater >/tmp/nikki-geodata-updater.log 2>&1'

mkdir -p /etc/crontabs
[ -f "$CRON_FILE" ] || touch "$CRON_FILE"

if grep -qF "$CRON_LINE" "$CRON_FILE"; then
	exit 0
fi

if grep -q '/usr/bin/nikki-geodata-updater' "$CRON_FILE"; then
	exit 0
fi

if ! grep -qF "$CRON_LINE" "$CRON_FILE"; then
	echo "$CRON_LINE" >>"$CRON_FILE"
	crontab "$CRON_FILE"
fi

exit 0
```

Do not remove unrelated cron lines. Do not attempt to delete `v2ray-geodata-updater` jobs.

- [ ] **Step 4: Run the static guard and verify it passes**

Run:

```bash
bash tests/test_nikki_geodata_updater.sh
```

Expected: PASS.

- [ ] **Step 5: Commit the cron bootstrap**

```bash
git add files/etc/uci-defaults/99-nikki-geodata-cron tests/test_nikki_geodata_updater.sh
git commit -m "feat: schedule weekly nikki geodata updates"
```

### Task 4: Add a local-fixture-driven dynamic test for the updater

**Files:**
- Create: `tests/test_nikki_geodata_updater_fixture.sh`

- [ ] **Step 1: Write the failing dynamic test**

Create `tests/test_nikki_geodata_updater_fixture.sh` with the following structure:

```bash
#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATER="$ROOT_DIR/files/usr/bin/nikki-geodata-updater"

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

python3 - "$UPDATER" "$TEST_UPDATER" "$FAKE_ROOT/etc/init.d" <<'PY'
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

(cd "$FIXTURE_DIR" && sha256sum geoip.dat > geoip.dat.sha256sum)
(cd "$FIXTURE_DIR" && sha256sum geosite.dat > geosite.dat.sha256sum)
(cd "$FIXTURE_DIR" && sha256sum geoip.metadb > geoip.metadb.sha256sum)

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

python3 -m http.server "$HTTP_PORT" --directory "$FIXTURE_DIR" >/dev/null 2>&1 &
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
```

- [ ] **Step 2: Run the dynamic test to verify it fails**

Run:

```bash
bash tests/test_nikki_geodata_updater_fixture.sh
```

Expected: FAIL until the updater can successfully find the fake init script and complete the update flow.

- [ ] **Step 3: Keep production script surface unchanged and route the fixture through a temporary test copy**

Do not add a new production environment variable for init script roots. Instead, keep the shipped updater fixed to `/etc/init.d/$SERVICE_NAME`, and let the fixture test run a temporary copy whose absolute init path is rewritten to the fake root. This preserves the production contract from the spec while still allowing safe local validation.

- [ ] **Step 4: Run the static and dynamic tests to verify they pass**

Run:

```bash
bash tests/test_nikki_geodata_updater.sh
bash tests/test_nikki_geodata_updater_fixture.sh
```

Expected: both PASS.

- [ ] **Step 5: Commit the dynamic test support**

```bash
git add files/usr/bin/nikki-geodata-updater tests/test_nikki_geodata_updater.sh tests/test_nikki_geodata_updater_fixture.sh
git commit -m "test: validate nikki geodata updates with local fixtures"
```

## Chunk 3: Full Repository Verification and Integration Finish

### Task 5: Verify the full repository guard suite with the new Nikki updater

**Files:**
- Test: `tests/test_*.sh`

- [ ] **Step 1: Run the Nikki-specific tests together**

Run:

```bash
bash tests/test_nikki_geodata_updater.sh
bash tests/test_nikki_geodata_updater_fixture.sh
bash tests/test_nikki_geodata_preload.sh
```

Expected: all PASS.

- [ ] **Step 2: Run the entire repository guard suite**

Run:

```bash
for test_file in ./tests/test_*.sh; do
  bash "$test_file"
done
```

Expected: all tests PASS, including the new Nikki updater guards and the existing uv / tailscale / preload tests.

- [ ] **Step 3: Record any conflict findings in the implementation notes**

If execution reveals an existing Nikki-specific cron entry or a repository-owned conflicting updater, document the exact finding in the final change summary. Do not silently remove unknown cron jobs unless their ownership and replacement are explicit.

- [ ] **Step 4: Commit the final verification checkpoint**

```bash
git add tests/test_nikki_geodata_updater.sh tests/test_nikki_geodata_updater_fixture.sh files/etc/uci-defaults/99-nikki-geodata-cron files/usr/bin/nikki-geodata-updater
git commit -m "test: verify nikki geodata updater integration"
```
