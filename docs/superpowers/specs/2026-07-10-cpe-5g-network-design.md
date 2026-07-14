# CPE-5G Network Bootstrap Design

## Goal

Ensure a clean-flashed CPE-5G firmware lets clients on the configured LAN (default `192.168.13.0/24`) reach the UDX710 management service at `192.168.66.1:6677` through OpenWrt `usb0`.

## Design

Add a reusable build helper, `Scripts/ConfigureCpe5G.sh`, controlled by the reusable-workflow input `WRT_CPE_5G`. When enabled, the helper writes an idempotent `/etc/uci-defaults/92-cpe-5g-network` overlay script. On first boot it creates the DHCP interface `network.5G` on `usb0`, disables its default route, adds `5G` to the existing `wan` firewall zone, and ensures `lan -> wan` forwarding exists.

The dedicated `.github/workflows/CPE-5G.yml` always passes `WRT_CPE_5G: true`. All ordinary QCA workflows omit the input and inherit the reusable workflow's `false` default, so their firmware contents and network behavior remain unchanged.

## Safety and idempotence

- Locate the firewall zones by UCI section name instead of assuming `@zone[1]`.
- Add `5G` and `lan -> wan` only when absent, preventing duplicate list and forwarding entries.
- Exit without generating an overlay when the feature flag is false.
- Preserve `defaultroute=0`, so the CPE management link cannot replace the router's normal WAN default route.

## Verification

Repository tests must prove the disabled path creates nothing, the enabled path produces the expected UCI commands, the CPE workflow enables the flag, and the reusable workflow defaults it to false. After building and flashing, runtime verification is `ubus call network.interface.5G status` plus an HTTP request from a `192.168.13.x` LAN client to `http://192.168.66.1:6677/`.
