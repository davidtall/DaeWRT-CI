# CPE 7.06 Baseline Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pin CPE-5G to the boot-verified 7.06 source and generate controlled NOWIFI A/B artifacts that isolate the CPE feature overlay.

**Architecture:** The existing reusable WRT-CORE keeps its optional immutable checkout path. A new boolean feature-overlay input lets the A job omit only CPE/Lucky/Tailscale/Headscale/wrtbak additions while B retains them; both jobs share the same source SHA and NOWIFI profile.

**Tech Stack:** GitHub Actions YAML, POSIX/Bash tests, OpenWrt build configuration, jq, sha256sum.

## Global Constraints

- Never reset, force-push, or revert unrelated hotwa changes.
- CPE source is exactly `0bad892975fe49fd180f99b414a7f168bb694dd7`.
- Ordinary QCA workflow source selection remains unchanged.
- Historical fallback remains `42a1f64b5dbd2a99d05daca94ae5a87eebff59b4` / Linux `6.18.35`.

---

### Task 1: Encode baseline and A/B invariants

**Files:**
- Modify: `tests/test_cpe_verified_source_baseline.sh`
- Create: `tests/test_cpe_706_controlled_builds.sh`

- [x] Write tests requiring the full 7.06 SHA, NOWIFI A/B jobs, feature-overlay isolation and rollback documentation.
- [x] Run both tests and observe failures against the old 6.25/WIFI-YES workflow.

### Task 2: Implement controlled build plumbing

**Files:**
- Modify: `.github/workflows/CPE-5G.yml`
- Modify: `.github/workflows/WRT-CORE.yml`
- Modify: `Scripts/Packages.sh`

- [x] Add `WRT_FEATURE_OVERLAY` and `WRT_REQUIRED_DEVICE` reusable inputs.
- [x] Define A and B with identical full SHA and `IPQ60XX-WIFI-NO`, differing only in CPE feature overlay and its LAN settings.
- [x] Require factory/sysupgrade and generate `metadata.json` plus `SHA256SUMS` for non-TEST artifacts.

### Task 3: Record provenance and rollback policy

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `docs/cpe-5g-preset.md`
- Create: `docs/superpowers/specs/2026-07-11-cpe-706-baseline-isolation-design.md`

- [x] Record the Release/source boundary, kernel/NSS/SSDK/Qualcommax/DTS/factory provenance and both baseline points.
- [x] Document A/B interpretation and the delayed WiFi test.

### Task 4: Verify and publish

**Files:** all changed files above.

- [ ] Run every `tests/test_*.sh`, `git diff --check`, and parse every workflow YAML file.
- [ ] Commit and push `work2ai/cpe-706-baseline-20260711` without rewriting history.
- [ ] Merge main only when GitHub reports no conflicts.
- [ ] Dispatch CPE-5G with `TEST=true`; inspect both final configs and exact source checkout.
- [ ] Dispatch with `TEST=false`; verify both artifacts contain RE-SS-01 factory/sysupgrade, `SHA256SUMS`, and `metadata.json` before scheduling real-device tests.
