# Headscale enrollment after wrtbak recovery

## Goal

Prevent a factory-flashed router from registering a temporary Headscale node
before wrtbak has decided whether an existing Tailscale state can be restored.
The behavior applies to the shared firmware overlay, including the CPE-5G B
preset already merged into `main`.

## Startup contract

When `wrtbak.main.firstboot_auto_enabled=1`, `wrtbak-firstboot-auto` owns the
recovery decision and writes an atomic, mode-0600 gate receipt at
`/root/wrtbak/firstboot/gate.json`. The receipt has one of these states:

- `pending`: recovery is still running; Headscale enrollment must wait.
- `reboot_pending`: a restore was applied and an automatic reboot is pending;
  enrollment must continue waiting.
- `already_done`: a matching restore receipt already exists; enrollment may
  inspect the restored Tailscale state.
- `restored`: restore completed without an automatic reboot; enrollment must
  reload tailscaled before deciding whether a new registration is needed.
- `no_backup`: the configured retry window found no current-device backup;
  enrollment may create a new node.
- `failed_final`: recovery exhausted its retry window; enrollment may create a
  new node so that remote management is not blocked permanently.
- `disabled`: automatic restore is disabled; enrollment keeps its existing
  behavior.

If wrtbak is missing or disabled, Headscale does not wait for the receipt.

## Enrollment behavior

`headscale-auto-enroll` first reuses an already-running Tailscale identity. If
no identity is running and wrtbak recovery is enabled, it waits for a terminal
gate state. After `already_done` or `restored`, it restarts tailscaled and checks
the recovered state again. It reads an auth key only when no recovered identity
is usable.

A PID-aware lock prevents procd and WAN hotplug retries from running concurrent
registrations. A stale lock is reclaimed safely.

## Branch and delivery

Both repositories use the short-lived branch
`work2ai/headscale-wrtbak-gate-20260712`. The wrtbak branch is merged first;
OpenWRT-CI then pins that merged package revision/branch, runs all shell tests,
and merges into `main`. Because CPE B is already the default CPE-5G workflow on
`main`, no separate long-lived CPE branch is created.

## Safety

No Tailscale state or Headscale key is committed. A recovery failure eventually
opens the gate to preserve the rescue path. Existing enrolled nodes are not
forced through the recovery gate during ordinary keep-config sysupgrade.
