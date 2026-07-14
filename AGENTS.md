# AGENTS.md

## Headscale auto-enroll

- Read `docs/headscale-auto-enroll.md` before changing the Tailscale or Headscale first-boot path.
- Do not commit a real Headscale auth key, GitHub token, Tailscale state file, or private SSH key.
- The firmware overlay may contain `/etc/config/headscale_auto_enroll`, but it must remain disabled by default unless a private CI build injects a secret at build time.
- Keep `accept_dns=0` by default. DNS control belongs to dnsmasq, mosdns, Nikki, or DAE.
- Keep `accept_routes=0` by default. Route acceptance can conflict with WireGuard, DAE, Nikki, or WAN policy routing.
- Tailscale SSH does not require replacing Dropbear or installing OpenSSH server. Keep Dropbear key-based SSH as the LAN/rescue path.
- Dropbear over Tailscale is provided by `/etc/uci-defaults/90-tailscale-dropbear-access`: do not bind Dropbear only to `br-lan`, do not create `network.tailscale`, and keep fw4 using `device 'tailscale0'` with input accepted and forwarding rejected.
- `headscale-auto-enroll` must apply `tailscale set --ssh=true` for already-enrolled nodes when `headscale_auto_enroll.main.ssh=1`; otherwise LuCI-enrolled or previously enrolled routers can remain at `RunSSH=false`.
- When wrtbak firstboot restore is enabled, preserve the wrtbak recovery gate: Headscale must not consume an auth key until restore reaches a terminal decision, and must reload a restored Tailscale state first.
- Public SSH keys for firmware images should be injected with `OPENWRT_DROPBEAR_AUTHORIZED_KEYS`. Do not commit private keys or Tailscale state.
- For router auth keys, prefer Headscale preauth keys scoped to `tag:service-host`, `tag:ssh-target`, and `tag:subnet-router`; add `tag:peer-relay-client` only for routers that should use Peer Relay.

## CPE-5G verified firmware baseline

- The current production CPE feature baseline is controlled build B at 2026-07-06 `VIKINGYFY/immortalwrt@0bad892975fe49fd180f99b414a7f168bb694dd7`, Linux `6.18.37`, `IPQ60XX-706-NOWIFI`. On 2026-07-12 both A and B booted successfully on RE-SS-01; B also exposed `usb0=192.168.66.2/24` and reached `192.168.66.1:6677` from OpenWrt.
- Retain 2026-06-25 `42a1f64b5dbd2a99d05daca94ae5a87eebff59b4` / Linux `6.18.35` as the historical known-bootable fallback. 回退源码时不得撤销无关 hotwa 功能提交。
- Keep `.github/workflows/CPE-5G.yml` pinned to the full 40-character preferred SHA and preserve exact fetch, detached checkout and SHA mismatch failure.
- `davidtall/immortalwrt:stable` is a candidate upstream only, never an automatic production baseline.
- Controlled NOWIFI A remains the no-feature-overlay isolation baseline; B is promoted for CPE use. WiFi-YES still requires a separate real-device gate.
- Normal CPE-5G dispatches must leave `BUILD_BASELINE_A=false` and build only B. Enable A only to isolate source/kernel/NSS boot failures from the CPE/Lucky/Tailscale/Headscale/wrtbak overlay; do not promote A as the daily firmware.
- mwan3 is a CPE-5G B-only package and overlay. Keep Ethernet `wan` primary and `5G`/usb0 backup, preserve the explicit CPE/LAN bypass rules, and run the post-wrtbak managed reconcile. Do not enable mwan3 in `Config/GENERAL.txt`, CPE A, or ordinary QCA workflows.
- Never perform a real WAN-loss test remotely without an independent local/serial/UBoot rescue path and a timed rollback. Existing sessions do not migrate across mwan3 failover; validate new connections plus Lucky usb0 return symmetry, Nikki marks, Tailnet, and SIM probe counters.
- For public services, prefer CPE IPv6 port relay to a Lucky listener on OpenWrt `192.168.66.2`, then reverse proxy only approved `192.168.13.x` services. Do not expose the whole LAN.
- Treat DHCPv6-PD/RA/NDP proxy as experimental until the cellular carrier is proven to delegate a prefix. A single CPE `/64` address is not proof of PD support.
- Treat `davidtall/immortalwrt:stable` as a candidate upstream, not an automatically trusted production baseline. A moving branch name is never sufficient evidence of the source used for a firmware artifact.
- Any change to Linux kernel, qca-nss, qca-nss-dp, qca-nss-drv, qca-nss-ecm, qca-ssdk, Qualcommax kernel patches, RE-SS-01 DTB, factory pipeline, or the firmware source commit must update the baseline table in `README.md`.
- Before promoting a candidate, record the exact source SHA and Action/artifact SHA256, then complete RE-SS-01 实机验证: successful flash, LAN/WAN and NSS checks, two soft reboots, one cold boot, and the CPE `192.168.66.1:6677` management path.
- If an upstream candidate fails to boot or regresses Ethernet/NSS/factory behavior, 回退 only the CPE firmware source pin to the last verified complete SHA. Do not revert unrelated hotwa CPE, Lucky, Tailscale/Headscale, wrtbak, or network feature commits.
