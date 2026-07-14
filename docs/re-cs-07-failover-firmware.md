# RE-CS-07 disaster-recovery firmware

## Phase-one boundary

This workflow produces a dedicated, build-only image for
`jdcloud_re-cs-07`. GitHub Actions builds and uploads the artifact; it does
not release firmware, connect to the router, or perform a remote flash.

The recovery model has four separate layers:

1. **Dedicated firmware package** — one RE-CS-07 sysupgrade image, its
   manifest, the final build config, and `SHA256SUMS`.
2. **Canonical wrtbak R2 backup** — the authoritative configuration backup,
   addressed by the stable alias `home-re-cs-07`.
3. **keep-config** — a normal sysupgrade may retain the current local
   configuration, but this is not a substitute for a verified backup.
4. **Local human confirmation** — a person on site confirms device identity,
   power/network readiness, and the intended recovery mode before flashing or
   restoring.

Regular upgrades keep wrtbak first-boot automatic restore disabled. A disaster
recovery restore must pass three gates before any write: the observed device
UID must match the intended backup identity, the backup manifest must match the
device and requested restore scope, and a readback/dry-run must show the exact
objects that will be restored. A mismatch stops recovery for manual review.

## Artifact guard

When `WRT_EXPECTED_DEVICE` is set, WRT-CORE verifies the post-defconfig
selection and then stages a strict four-file artifact. The config must select
only `jdcloud_re-cs-07`; the manifest must include `gre`,
`luci-proto-gre`, `ip-full`, `luci-app-wrtbak`, and `vm103-failover`.
Factory, initramfs, rootfs, and other-device outputs are rejected.

## Phase two

Phase two packages `vm103-failover` for the home RE-CS-07/VM103 topology.
The program and init source were hash-verified against both the live router
and the post-backup copy before being packaged byte for byte. Package tests
lock those hashes, the established interface and route constants, the 3-check
failover threshold, the 5-check failback threshold, and stop-time restoration
of the primary route.

This repository change has not run GitHub Actions, compiled firmware, or
flashed a device. The package only preserves the existing monitor behavior;
it does not generate UCI network or firewall configuration, perform a
first-boot automatic restore, or remotely enable the service. The device's
`network` and `firewall` configuration must be recovered through wrtbak or a
normal keep-config sysupgrade path. If the package lifecycle enables the init
script, service startup waits for `wan` and `gre4-gre_vm103`; stopping the
service restores the primary route.
