# Headscale Auto Enroll

This firmware overlay can join the private Headscale tailnet after WAN is ready. It is designed for router management, not for replacing the local rescue path.

## Runtime model

- Keep Dropbear with key-based LAN SSH as the rescue path.
- Use ordinary SSH to the router over its Tailscale IP for normal management after the router joins Headscale, for example `ssh root@100.64.x.x`.
- `tailscale up --ssh` enables Tailscale's built-in SSH path. It does not modify Dropbear, but it can claim port `22` for traffic arriving at the router's Tailscale IP; LAN/rescue SSH still uses Dropbear.
- Keep `accept_dns` disabled so Tailscale MagicDNS does not take over dnsmasq, mosdns, Nikki, or DAE DNS split routing.
- Keep `accept_routes` disabled by default. Enable it only after checking it will not conflict with WireGuard, WAN policy routing, DAE, or Nikki.

## Files

- `/etc/config/headscale_auto_enroll` controls enrollment.
- `/usr/sbin/headscale-auto-enroll` performs enrollment.
- `/etc/init.d/headscale-auto-enroll` runs it through procd.
- `/etc/hotplug.d/iface/95-headscale-auto-enroll` retries enrollment when an interface comes up.
- `/etc/tailscale/headscale.authkey` is the optional one-line auth key file.
- `/etc/tailscale/auto-enroll.done` marks a successful enrollment.
- `/root/wrtbak/firstboot/gate.json` is the wrtbak recovery gate used to stop a factory image from registering a temporary node before a saved Tailscale state has been restored.
- `/etc/uci-defaults/90-tailscale-dropbear-access` keeps Dropbear reachable through `tailscale0` and creates a fw4 `tailscale` zone with router input allowed and forwarding rejected.
- `/etc/dropbear/authorized_keys` can be injected into private firmware builds through GitHub Actions.

The default config is disabled:

```text
config enroll 'main'
	option enabled '0'
	option login_server 'https://headscale.jmsu.top'
	option auth_key_file '/etc/tailscale/headscale.authkey'
	option provision_url ''
	option hostname_prefix 'openwrt'
	option ssh '1'
	option accept_dns '0'
	option accept_routes '0'
	option advertise_routes ''
```

## Recommended first test

On a flashed router:

```sh
mkdir -p /etc/tailscale
printf '%s\n' 'REDACTED_HEADSCALE_AUTH_KEY' >/etc/tailscale/headscale.authkey
chmod 600 /etc/tailscale/headscale.authkey
uci set headscale_auto_enroll.main.enabled='1'
uci commit headscale_auto_enroll
/etc/init.d/headscale-auto-enroll restart
logread -e headscale-auto-enroll
tailscale status
```

After a successful enrollment the script removes `/etc/tailscale/headscale.authkey` by default.

## GitHub Actions secret pattern

Do not commit an auth key to this repository. If a private firmware build must auto-enroll during first boot, store the key as the GitHub Actions secret `HEADSCALE_OPENWRT_AUTHKEY`. The workflow calls `Scripts/HeadscaleAutoEnroll.sh` after copying the overlay into `wrt/files`; when the secret is present it writes `/etc/tailscale/headscale.authkey` into that private build root and sets `headscale_auto_enroll.main.enabled=1`. When the secret is empty, the script leaves firmware auto-enroll disabled.

The resulting firmware artifact contains the enrollment key until the router boots and the script deletes `/etc/tailscale/headscale.authkey`. Keep those artifacts private and rotate the key if an artifact leaks.

Optional non-secret environment variables:

```text
HEADSCALE_LOGIN_SERVER=https://headscale.jmsu.top
HEADSCALE_OPENWRT_HOSTNAME_PREFIX=openwrt
HEADSCALE_OPENWRT_ENABLE_SSH=1
HEADSCALE_OPENWRT_ACCEPT_ROUTES=0
HEADSCALE_OPENWRT_ADVERTISE_ROUTES=
```

For Dropbear-backed ordinary SSH over the Tailscale IP, store one or more public keys in the GitHub Actions secret `OPENWRT_DROPBEAR_AUTHORIZED_KEYS`. The workflow writes those keys to `/etc/dropbear/authorized_keys` in the private build overlay. Do not put private keys in this secret and do not commit private keys to the repository. If Tailscale SSH is enabled and allowed by policy, tailnet port `22` connections use Tailscale SSH authorization instead of Dropbear keys.

The Tailscale firewall overlay intentionally uses `firewall.tailscale.device='tailscale0'` instead of creating `network.tailscale`. Tailscaled owns the TUN address and routes; letting netifd manage `tailscale0` can remove the assigned `100.64.0.0/10` address and make `ssh root@100.64.x.x` time out.

When `/etc/config/headscale_auto_enroll` has `option ssh '1'`, the auto-enroll script applies `tailscale set --ssh=true` even if the node is already enrolled. This keeps recovered or LuCI-enrolled routers from staying in `RunSSH=false`.

## wrtbak recovery gate

When `wrtbak.main.firstboot_auto_enabled=1`, Headscale registration waits for the wrtbak recovery gate. `pending` and `reboot_pending` keep registration closed. `already_done` and `restored` cause tailscaled to reload the recovered state before any auth key is read. `no_backup`, `failed_final`, and `disabled` allow a new registration. The wait is bounded; after the configured timeout, registration proceeds to preserve the Tailnet rescue path.

The init service and WAN hotplug hook can fire close together. A PID-aware runtime lock serializes these attempts, reclaims stale locks after service restart, and prevents two concurrent `tailscale up` calls.

Prefer a tagged, router-scoped key with the narrow tags needed by the router:

- `tag:service-host`
- `tag:ssh-target`
- `tag:subnet-router`
- `tag:peer-relay-client` only for routers that should use Peer Relay

Long-lived reusable keys are operationally convenient but are enrollment secrets. If one leaks, revoke it from Headscale and rotate the GitHub secret.

## Deployment cautions for 192.168.12.1

Flashing a new image may reset DAE, mosdns, Nikki, WireGuard, and DHCP-specific runtime config. Keep a separate post-flash restore workflow for proxy mode and WireGuard settings. This auto-enroll layer only restores tailnet reachability so the router can be managed again over Headscale.
