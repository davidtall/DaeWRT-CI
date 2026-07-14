# CPE-5G A Baseline Pin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the CPE-5G workflow reproducibly build the verified 2026-06-25 RE-SS-01 firmware source baseline while preserving all current hotwa CI and CPE features.

**Architecture:** Add an optional immutable source commit input to the reusable workflow. Only CPE-5G supplies the verified SHA; all other callers retain their existing moving-branch behavior. Document both the complete baseline tuple and the real-device promotion/rollback policy.

**Tech Stack:** GitHub Actions YAML, Bash, Git, Markdown, shell regression tests.

## Global Constraints

- Verified firmware source is exactly `VIKINGYFY/immortalwrt@42a1f64b5dbd2a99d05daca94ae5a87eebff59b4`.
- The verified kernel is Linux `6.18.35`.
- Existing CPE USB/5G, `192.168.13.1`, Lucky, Tailscale/Headscale, wrtbak, WAN SSH policy, and private-build behavior must remain unchanged.
- The pin must affect only CPE-5G; ordinary QCA workflows remain unpinned.
- A missing, unavailable, or mismatched requested commit must fail the build.
- Never commit credentials or private build values.

---

### Task 1: Define and test the immutable source contract

**Files:**
- Create: `tests/test_cpe_verified_source_baseline.sh`
- Modify: `.github/workflows/WRT-CORE.yml`
- Modify: `.github/workflows/CPE-5G.yml`

**Interfaces:**
- Consumes: existing `WRT_REPO`, `WRT_BRANCH`, and CPE reusable-workflow call.
- Produces: optional `WRT_COMMIT` workflow input and environment value; exact checkout for CPE-5G.

- [ ] **Step 1: Write the failing test**

Create a shell test that requires the 40-character A SHA in CPE-5G, requires `WRT_COMMIT` input/environment plumbing in WRT-CORE, requires fetch/detached checkout plus `git rev-parse HEAD` verification, and rejects the A SHA from the ordinary QCA 6.18 workflow.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_cpe_verified_source_baseline.sh`

Expected: FAIL because `WRT_COMMIT` is not declared or passed.

- [ ] **Step 3: Implement the minimal workflow behavior**

Add optional `WRT_COMMIT` to `workflow_call.inputs` and `env`. After the existing shallow branch clone, validate a non-empty value as a full hexadecimal SHA, fetch that exact object with depth one, checkout detached, compare requested and resolved SHA, then continue existing patches. Record the resolved full SHA in `WRT_HASH`. Set the CPE workflow value to `42a1f64b5dbd2a99d05daca94ae5a87eebff59b4`.

- [ ] **Step 4: Run focused tests**

Run:

```bash
bash tests/test_cpe_verified_source_baseline.sh
bash tests/test_cpe_5g_preset.sh
```

Expected: both PASS.

- [ ] **Step 5: Commit workflow and test**

```bash
git add .github/workflows/WRT-CORE.yml .github/workflows/CPE-5G.yml tests/test_cpe_verified_source_baseline.sh
git commit -m "build: pin CPE firmware to verified source baseline"
```

### Task 2: Publish the verified baseline and rollback policy

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `docs/cpe-5g-preset.md`
- Test: `tests/test_cpe_verified_source_baseline.sh`

**Interfaces:**
- Consumes: the exact workflow values from Task 1 and component provenance from the approved design.
- Produces: operator-facing current-baseline table and agent-facing update gate.

- [ ] **Step 1: Extend the test so documentation requirements fail**

Require README and AGENTS to contain the full source SHA, Linux 6.18.35, the NSS/SSDK/Qualcommax/DTB/factory component names, and a real-device verification/rollback rule.

- [ ] **Step 2: Run test to verify documentation assertions fail**

Run: `bash tests/test_cpe_verified_source_baseline.sh`

Expected: FAIL on the first missing README or AGENTS baseline marker.

- [ ] **Step 3: Add concise source-of-truth documentation**

Add the approved baseline table to README, hard maintenance rules to AGENTS, and the exact pin plus candidate-promotion process to the CPE preset guide. State that `davidtall/immortalwrt:stable` is an upstream candidate, not an automatically trusted production baseline.

- [ ] **Step 4: Run focused tests**

Run: `bash tests/test_cpe_verified_source_baseline.sh`

Expected: PASS.

- [ ] **Step 5: Commit documentation**

```bash
git add README.md AGENTS.md docs/cpe-5g-preset.md tests/test_cpe_verified_source_baseline.sh
git commit -m "docs: record verified RE-SS-01 firmware baseline"
```

### Task 3: Verify, integrate, and trigger

**Files:**
- Verify all modified files and existing tests.

**Interfaces:**
- Consumes: Tasks 1 and 2 commits.
- Produces: tested branch, merged remote main, and one CPE-5G Action run.

- [ ] **Step 1: Run repository validation**

Run every `tests/test_*.sh`, `git diff --check`, inspect the final branch diff against `origin/main`, and scan modified files for credential-like values.

Expected: all tests pass, no whitespace errors, only scoped workflow/test/documentation changes, no secrets.

- [ ] **Step 2: Push the isolated branch**

Push `work2ai/cpe-a-baseline-pin-20260711` without force.

- [ ] **Step 3: Integrate without rewriting main history**

Update from remote main, confirm the branch contains all current main commits, merge or fast-forward through a normal non-force operation, and push main. Do not reset main to an older CI commit.

- [ ] **Step 4: Trigger CPE-5G**

Dispatch `.github/workflows/CPE-5G.yml` on main with `LAN_IP=192.168.13.1`, `TEST=false`, and the default-disabled wrtbak firstboot restore switch.

- [ ] **Step 5: Confirm the run uses the pin**

Record the run URL and confirm its workflow checkout uses `42a1f64b5dbd2a99d05daca94ae5a87eebff59b4`. Build completion and real-device validation remain separate gates.
