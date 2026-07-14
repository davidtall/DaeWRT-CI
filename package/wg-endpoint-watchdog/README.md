# wg-endpoint-watchdog

`wg-endpoint-watchdog` is an opt-in OpenWrt package that refreshes WireGuard interfaces when endpoint DNS records change, WAN links come back online, or WireGuard latest-handshake timestamps become stale.

The package ships only generic recovery logic. It does not include site-specific domains, public IP addresses, private routing ranges, cloud provider credentials, WireGuard secrets, or DDNS-GO credentials. The default UCI instance is disabled.

## Files

- `/etc/config/wg_endpoint_watchdog`: opt-in UCI instances
- `/usr/bin/wg-endpoint-refresh`: refresh one enabled instance or all enabled instances
- `/usr/bin/wg-endpoint-watchdog`: check latest-handshake age and refresh stale instances
- `/etc/hotplug.d/iface/99-wg-endpoint-watchdog`: refresh enabled instances after WAN ifup
- `/etc/init.d/wg-endpoint-watchdog`: procd-managed 10 minute watchdog loop plus optional boot-delay refresh

## Enable After Flashing

```sh
uci set wg_endpoint_watchdog.wg_dorm=instance
uci set wg_endpoint_watchdog.wg_dorm.enabled='1'
uci set wg_endpoint_watchdog.wg_dorm.interface='wg_dorm'
uci set wg_endpoint_watchdog.wg_dorm.max_handshake_age='600'
uci set wg_endpoint_watchdog.wg_dorm.refresh_ddns_service='ddns-go'
uci set wg_endpoint_watchdog.wg_dorm.proxy_bypass='1'
uci set wg_endpoint_watchdog.wg_dorm.proxy_bypass_udp_sport='51821'
uci commit wg_endpoint_watchdog
/etc/init.d/wg-endpoint-watchdog enable
/etc/init.d/wg-endpoint-watchdog restart
```

Use `endpoint_host_option` only when you want the refresh script to verify that a WireGuard peer endpoint UCI path is readable:

```sh
uci set wg_endpoint_watchdog.wg_dorm.endpoint_host_option='network.wg_dorm_peer_remote.endpoint_host'
uci commit wg_endpoint_watchdog
```

Set `refresh_ddns_service` to an empty value when DDNS should not be restarted:

```sh
uci set wg_endpoint_watchdog.wg_dorm.refresh_ddns_service=''
uci commit wg_endpoint_watchdog
```

## Notes

- DDNS-GO configuration under `/etc/ddns-go/ddns-go-config.yaml` must be restored by the user.
- WireGuard key material must be restored by the user through their own backup or UCI workflow.
- Domains, ports, and routing ranges should come from the user's own `network` and `firewall` configuration.
- Hook options execute user-provided executable paths with `instance`, `reason`, and `interface` arguments; no hook script is bundled.
- `proxy_bypass_udp_sport` is empty by default. No `ip rule` is added unless both `proxy_bypass=1` and a UDP source port are configured.
