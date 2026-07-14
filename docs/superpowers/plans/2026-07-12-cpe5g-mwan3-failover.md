# CPE-5G mwan3 Failover Implementation Plan

Goal: implement WAN-primary and 5G-backup failover only for CPE-5G B while
preserving ordinary QCA and CPE A behavior.

Architecture: the CPE B workflow installs mwan3 packages and the existing
ConfigureCpe5G helper emits a versioned managed-config script plus first-boot
invocation. Managed UCI sections use a cpe5g prefix, are reconciled after the
wrtbak terminal gate, and preserve unrelated user sections.

## Constraints

- Work only in work2ai/cpe5g-mwan3-failover-20260712.
- Fetch and normally merge newer main before final verification.
- Do not edit Config/GENERAL.txt or Packages.sh for mwan3.
- Do not alter Headscale auth keys, wrtbak credentials, Nikki policy, Lucky,
  firewall zone ownership, LAN addressing, or CPE A.
- Tests precede implementation. No reset, rebase of pushed history, or
  force-push.
- Online WAN-loss testing requires local rescue and a timed rollback watchdog.

### Task 1: Add red tests for package isolation and generated policy

Files:
- Modify tests/test_cpe_5g_preset.sh
- Modify tests/test_configure_cpe_5g.sh
- Create tests/test_cpe_5g_mwan3_runtime.sh

Steps:
1. Assert only the B job includes mwan3 and luci-app-mwan3.
2. Assert CPE A and shared GENERAL remain free of enabled mwan3 packages.
3. Replace the old 5G defaultroute=0 expectation with WAN metric 10, 5G
   metric 20, 5G peerdns=0, and candidate default-route expectations.
4. Assert three track targets, reliability 2, WAN interval 5, 5G interval 60,
   down 3, up 5, members, failover policy, unreachable last resort, and default
   rule.
5. Runtime fixture uses fake UCI/init commands to prove repeat execution,
   preservation of a user section, missing-interface failure before commit,
   direct-network bypass sections, and restore-terminal reconcile behavior.
6. Run the focused tests and capture expected failures.

### Task 2: Implement the managed mwan3 generator

Files:
- Modify Scripts/ConfigureCpe5G.sh
- Add generated /usr/libexec/cpe5g-mwan3-reconcile in the overlay
- Add generated first-boot/hotplug integration only if required by tested
  restore ordering

Steps:
1. Generate a single idempotent reconcile script used by first boot and restore
   terminal handling.
2. Set WAN and 5G network options without overwriting unrelated interfaces;
   reload netifd only on changes and restore prior values on reload failure.
3. Manage the required `wan` and `5G` interface tracking options (their names
   must match netifd), and create only cpe5g-prefixed members, policies, rules,
   and direct-network bypass sections.
4. Validate wan and 5G before any commit.
5. Commit network/mwan3 only after complete generation, enable mwan3, and
   reload/restart with bounded behavior.
6. Preserve user-created mwan3 sections, safely recognize stock rules, derive
   the dynamic LAN CIDR, serialize execution with a lock, and support repeats.
7. Run focused tests to green, then refactor without changing behavior.

### Task 3: Wire packages only into CPE B and document behavior

Files:
- Modify .github/workflows/CPE-5G.yml
- Modify docs/cpe-5g-preset.md
- Modify README.md and AGENTS.md only where needed and after merging latest
  main to minimize conflicts

Steps:
1. Add CONFIG_PACKAGE_mwan3=y and CONFIG_PACKAGE_luci-app-mwan3=y only to B
   WRT_PACKAGE.
2. Keep A WRT_PACKAGE and Config/GENERAL.txt unchanged.
3. Document metrics, probe budget, non-seamless existing connections, Nikki
   runtime gate, direct-network handling, wrtbak reconcile, and rescue boundary.
4. Run focused preset/generator/runtime tests.

### Task 4: Full repository verification and review

Steps:
1. Run all tests/test_*.sh using the repository-supported shell environment.
2. Run sh -n on changed/generated shell scripts.
3. Parse every workflow YAML.
4. Run git diff --check and secret scans.
5. Review the complete diff against the spec and final Goal.
6. Commit in logical batches and push the one short-lived branch.

### Task 5: GitHub gates and merge

Steps:
1. Trigger CPE-5G TEST=true and monitor to completion.
2. Confirm no configuration or artifact regression and no 50 KB false artifact.
3. Open one PR, require no conflicts and passing checks, then normally merge
   main.
4. Delete the short-lived branch after merge.
5. Trigger TEST=false from final main.
6. Verify RE-SS-01 factory/sysupgrade images, metadata, SHA256SUMS, artifact
   digest, and reasonable size. Do not flash automatically.

### Task 6: Online staging and conditional live failover

Steps:
1. Capture a fresh device backup and redacted network/mwan/Nikki/Tailnet state.
2. Confirm package ABI matches the running snapshot; use matching artifact IPKs
   only. If no match exists, do not install packages on the running router.
3. Apply the generated reconcile non-destructively and verify state/routes.
4. Verify WAN-normal new-connection egress, 5G probe SIM delta, direct CPE/LAN
   routing, Lucky correct/wrong SNI, Nikki state, and Tailnet.
5. Only with local rescue, arm a timed rollback and simulate WAN loss, verify
   new-connection 5G egress, then WAN recovery and automatic return.
6. Cancel the watchdog only after all recovery checks pass; otherwise restore
   the backup and record the gate as pending/failed.

### Task 7: Evidence and handoff to core Goal workstreams B through F

Steps:
1. Update OpenWRT-CI design/plan/docs with actual test/run/merge evidence.
2. Record final commits, PR, workflow runs, artifact IDs, hashes, and rollback.
3. Resume final-goal-reviewed.md workstream B without repeating healthy
   certificate deployment.

## Implementation evidence

- Local full gate (2026-07-12): every `tests/test_*.sh` passed, changed shell
  scripts passed `bash -n`, every workflow YAML parsed, and `git diff --check`
  passed.
- Independent review found and drove fixes for mwan3 interface naming, the
  15-character rule limit, stock rule shadowing, dynamic LAN CIDR, netifd
  reload rollback, first-boot service start, wrtbak ordering and concurrency.
- Branch TEST=true run:
  [29203906558](https://github.com/hotwa/OpenWRT-CI/actions/runs/29203906558),
  commit `afee29af2b44c9fc2ee7ece63ea8641a2695e408`, B succeeded and A was
  skipped as designed.
- TEST=true artifact `8263247401` is intentionally configuration-only:
  compressed size `49,870` bytes; extracted `.config` size `324,280` bytes.
  It contains `CONFIG_PACKAGE_mwan3=y`,
  `CONFIG_PACKAGE_luci-app-mwan3=y`, and the existing Lucky package. It must
  not be mistaken for or flashed as a firmware image.
- PR [#13](https://github.com/hotwa/OpenWRT-CI/pull/13) was normally merged
  to main as `13c984d70139436205177f0a8640a29d87787e5c`; the implementation
  branch was deleted after ancestry verification.
- Final-main TEST=false run
  [29204310241](https://github.com/hotwa/OpenWRT-CI/actions/runs/29204310241)
  completed successfully. Artifact `8264724224` is `416,207,857` bytes with
  ZIP digest `f5b40733961930b145e3c4278f46013018b27e29c0be70cbb22ad856397455b9`.
- RE-SS-01 factory: `212,885,673` bytes,
  SHA256 `94a062d54846f5b4bf32114da99377421f8538bd268a42d228136a1a1e899aba`.
  RE-SS-01 sysupgrade: `208,107,792` bytes,
  SHA256 `7b8c9b2f66ea67898535129d316837a9293cd35665e7b87fb517b098d8fceb78`.
  Every `SHA256SUMS` entry passed `sha256sum -c`.
- Metadata confirms source `0bad892975fe49fd180f99b414a7f168bb694dd7`,
  profile `IPQ60XX-706-NOWIFI`, required device `jdcloud_re-ss-01`, and
  `feature_overlay=true`. The manifest contains mwan3 2.12.1, LuCI mwan3,
  firewall4, iptables-nft/ip6tables-nft, xtables-nft, kmod-nft-compat, Nikki
  and Lucky.
- The validated files are stored outside the repository at
  `C:\Users\pylyz\Downloads\OpenWRT-CI-CPE5G-29204310241`; no automatic
  flash was performed. Live package/route/Nikki/failover validation remains
  gated on an independent local rescue path and timed rollback watchdog.
