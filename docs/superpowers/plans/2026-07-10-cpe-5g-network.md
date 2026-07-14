# CPE-5G Network Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate an opt-in first-boot CPE network configuration that routes LAN clients to `192.168.66.1` over `usb0`.

**Architecture:** A build-time helper writes one idempotent `uci-defaults` script into the firmware overlay. A reusable workflow boolean controls generation, and only the CPE-5G preset enables it.

**Tech Stack:** Bash, OpenWrt UCI, GitHub Actions reusable workflows.

## Global Constraints

- Ordinary QCA firmware must default `WRT_CPE_5G` to false.
- CPE management DHCP must use `usb0` with `defaultroute=0`.
- The generated configuration must not duplicate firewall zone networks or forwarding sections.

---

### Task 1: Specify CPE network generation

**Files:**
- Modify: `tests/test_cpe_5g_preset.sh`
- Create: `tests/test_configure_cpe_5g.sh`
- Create: `Scripts/ConfigureCpe5G.sh`

**Interfaces:**
- Consumes: overlay directory and boolean enabled flag.
- Produces: `<overlay>/etc/uci-defaults/92-cpe-5g-network` when enabled.

- [ ] Add tests for disabled and enabled generation paths and workflow wiring.
- [ ] Run the tests and confirm they fail because the helper and workflow input are absent.
- [ ] Implement the minimal idempotent overlay generator.
- [ ] Run both focused tests and confirm they pass.

### Task 2: Wire, document, and verify the preset

**Files:**
- Modify: `.github/workflows/WRT-CORE.yml`
- Modify: `.github/workflows/CPE-5G.yml`
- Modify: `docs/cpe-5g-preset.md`

**Interfaces:**
- Consumes: reusable workflow input `WRT_CPE_5G`.
- Produces: CPE-only invocation of `ConfigureCpe5G.sh` during Custom Packages.

- [ ] Add the reusable input with a false default and export it to the build job.
- [ ] Invoke the helper after the common overlay is copied.
- [ ] Enable the flag only in `CPE-5G.yml` and document the clean-flash behavior.
- [ ] Run every `tests/test_*.sh`, `git diff --check`, and YAML parsing checks.
- [ ] Commit, push, and trigger `.github/workflows/CPE-5G.yml` with `LAN_IP=192.168.13.1`.
