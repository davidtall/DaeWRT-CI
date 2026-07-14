# OpenWrt Nikki Geodata Auto-Update Design

**Date:** 2026-03-25

**Status:** Approved design, pending implementation planning

## Goal

Add a firmware-bundled, runtime-safe Nikki geodata updater that:

- updates `/etc/nikki/run/geoip.dat`
- updates `/etc/nikki/run/geosite.dat`
- updates `/etc/nikki/run/geoip.metadb`
- prefers MetaCubeX official release URLs with checksum verification
- falls back to jsDelivr mirrors for payload downloads without skipping checksum validation
- only replaces files after the entire batch has been downloaded and verified
- restarts `nikki` only when at least one file actually changed
- rolls back previous files if restart fails
- ships enabled-by-default weekly cron wiring in the built firmware

## Background

This repository already preloads Nikki geodata into the firmware overlay at build time through [Scripts/Handles.sh](/C:/Users/pylyz/Documents/project/OpenWRT-CI/.worktrees/nikki-geodata-updater/Scripts/Handles.sh). That solves first-boot availability, but Nikki does not currently receive a repository-owned runtime auto-update path for `/etc/nikki/run/`.

There is also an existing `v2ray-geodata-updater` implementation in [package/v2ray-geodata/v2ray-geodata-updater](/C:/Users/pylyz/Documents/project/OpenWRT-CI/.worktrees/nikki-geodata-updater/package/v2ray-geodata/v2ray-geodata-updater), plus a cron injection pattern in [package/v2ray-geodata/init.sh](/C:/Users/pylyz/Documents/project/OpenWRT-CI/.worktrees/nikki-geodata-updater/package/v2ray-geodata/init.sh). Those provide useful style references, but the Nikki updater must be safer than the existing v2ray script:

- no partial updates
- checksum-first flow
- file-by-file change detection
- restart rollback
- configurable source overrides

## Scope

### In Scope

- Add a standalone runtime updater at `/usr/bin/nikki-geodata-updater`
- Bundle that updater into the firmware via repository `files/`
- Add a first-boot cron injector that schedules weekly Sunday 03:30 updates
- Keep build-time Nikki geodata preload unchanged
- Add static repository guards
- Add a local-fixture-driven dynamic test that does not depend on public internet
- Inspect existing cron logic for obvious conflict, but avoid destructive cleanup of unknown tasks

### Out of Scope

- Changing Nikki package internals
- Replacing build-time geodata preload with runtime-only downloads
- Deleting unrelated cron jobs automatically
- Forcing a fixed proxy configuration
- Claiming public internet validation when DNS, TLS, or proxy layers are unstable

## User-Facing Behavior

After firmware is built and flashed:

- `/usr/bin/nikki-geodata-updater` exists immediately
- the image already contains preloaded Nikki geodata under `/etc/nikki/run/`
- a cron job is installed on first boot for weekly Sunday 03:30 updates:
  - `30 3 * * 0 /usr/bin/nikki-geodata-updater >/tmp/nikki-geodata-updater.log 2>&1`
- running the updater manually is safe if no new data exists
- if a download or checksum fails, the updater exits non-zero and leaves existing files untouched
- if files change and `nikki` restart succeeds, the new files remain in place
- if files change but `nikki` restart fails, old files are restored and the service is started again on a best-effort basis

## Design Overview

The feature is split into three parts:

1. **Runtime updater script**
   A shell script in `files/usr/bin/` handles downloading, verifying, staging, replacing, permission fixing, restart, and rollback.

2. **Cron bootstrap**
   A `uci-defaults` script injects the desired cron entry once, without overwriting unrelated cron contents.

3. **Repository validation**
   Static tests confirm the script contract and cron wiring. A local-fixture dynamic test validates full update behavior without relying on real public endpoints.

## Repository Changes

### New Runtime Script

Add:

- `files/usr/bin/nikki-geodata-updater`

Required properties:

- `#!/bin/sh`
- `set -eu`
- logger-backed status output
- lock directory to prevent concurrent runs
- temporary staging directory under configurable `TMP_ROOT`
- official primary download base:
  - `https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest`
- checksum base defaults to the official primary base
- mirror download bases default to:
  - `https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release`
  - `https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release`

Environment variables to support:

- `LOGGER_TAG`
- `TARGET_DIR`
- `SERVICE_NAME`
- `LOCK_DIR`
- `TMP_ROOT`
- `PRIMARY_BASE`
- `CHECKSUM_BASE`
- `MIRROR_BASES`
- `PROXY_URL`
- `PROXY_USER`

The script must update exactly:

- `geoip.dat`
- `geosite.dat`
- `geoip.metadb`

### Update Algorithm

For each target file:

1. Download `file.sha256sum` from `CHECKSUM_BASE`
2. Parse the expected SHA-256
3. If the current target file already matches, skip downloading the payload
4. Otherwise try the payload from `PRIMARY_BASE/file`
5. If primary download fails or hash mismatches, try each mirror payload URL
6. Accept a payload only if its computed SHA-256 matches the checksum fetched from the official checksum source

Batch semantics:

- if any changed file fails checksum or download, abort the whole run before replacement
- if no file changed, exit successfully without restarting Nikki
- if one or more files changed, replace all changed files together
- after replacement, run `chmod 644` on all replaced files

Restart semantics:

- restart `/etc/init.d/$SERVICE_NAME`
- verify `/etc/init.d/$SERVICE_NAME running`
- if restart verification fails:
  - restore backups for the changed files
  - reapply `chmod 644`
  - try to bring the service back up again
  - return failure

## Cron Integration

Add:

- `files/etc/uci-defaults/99-nikki-geodata-cron`

Responsibilities:

- ensure `/etc/crontabs/root` exists
- append the target cron line if and only if it is not already present
- run `crontab /etc/crontabs/root` after modifications
- avoid deleting unknown cron jobs
- if obviously conflicting Nikki-specific update lines are found, do not remove them silently; at most, add a comment or skip duplication logic conservatively

Target cron line:

- `30 3 * * 0 /usr/bin/nikki-geodata-updater >/tmp/nikki-geodata-updater.log 2>&1`

## Conflict Handling

The repository should inspect existing geodata update references but not aggressively rewrite them.

Known references:

- `v2ray-geodata-updater` cron injection under `package/v2ray-geodata/init.sh`
- build-time Nikki preload in `Scripts/Handles.sh`

Expected handling:

- keep build-time Nikki preload unchanged
- do not delete `v2ray-geodata-updater` logic because it targets different paths and packages
- do not assume Nikki already auto-updates geodata

## Validation Strategy

### Static Validation

Add:

- `tests/test_nikki_geodata_updater.sh`

It should verify:

- updater script exists
- cron injector exists
- target filenames are correct
- checksum-first logic exists
- mirrors are present
- `chmod 644` is enforced
- restart and rollback logic exist
- lock directory logic exists
- cron line is Sunday 03:30 and points to `/tmp/nikki-geodata-updater.log`

Also run:

- `sh -n files/usr/bin/nikki-geodata-updater`
- `sh -n files/etc/uci-defaults/99-nikki-geodata-cron`

### Dynamic Validation

Add a local-fixture-driven test script under `tests/` that:

- builds a temporary fixture directory with fake:
  - `geoip.dat`
  - `geosite.dat`
  - `geoip.metadb`
  - matching `.sha256sum` files
- starts a temporary local HTTP server
- points `PRIMARY_BASE` and `CHECKSUM_BASE` at that local server
- sets `TARGET_DIR` to a temp directory
- overrides `SERVICE_NAME` by shadowing `/etc/init.d/<service>` through a fake init script rooted in a temporary test environment
- verifies:
  - all three files land in the target directory
  - permissions are `644`
  - updater exits `0` on success
  - the fake service restart path was invoked
  - a second run with unchanged files does not trigger another restart

The dynamic test should not require public internet and should not modify the host system's real `/etc/init.d`.

## Acceptance Criteria

This feature is complete when:

- firmware contains `/usr/bin/nikki-geodata-updater`
- first boot installs the weekly Sunday 03:30 cron entry
- static tests pass
- dynamic local-fixture test passes
- existing repository guard suite still passes
- implementation does not claim public internet success unless that path is explicitly tested and verified

## Risks and Mitigations

### Public Endpoint Instability

Risk:

- GitHub DNS, TLS, or proxy behavior may fail on some routers

Mitigation:

- keep checksum source explicit
- keep mirror payload fallbacks
- support proxy environment variables
- fail safely without replacing existing files

### Partial Update Corruption

Risk:

- replacing one file before the others are verified could leave Nikki in an inconsistent state

Mitigation:

- all changed files stage in temp first
- replacements happen only after the full batch is verified

### Duplicate Cron Entries

Risk:

- repeated first-boot logic could append duplicate jobs

Mitigation:

- cron injector must grep for the exact line before appending
