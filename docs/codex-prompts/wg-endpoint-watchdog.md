# wg-endpoint-watchdog Codex Prompt

Implement or maintain the generic OpenWrt package `wg-endpoint-watchdog`.

The package must provide recovery logic only:

- monitor enabled WireGuard interfaces by `wg show <interface> latest-handshakes`
- refresh stale instances by restarting optional DDNS service, restarting dnsmasq when configured, ensuring an optional UDP source-port main-table bypass rule, then running `ifdown`, `ifup`, and logging WireGuard endpoint state
- trigger delayed refresh after WAN `ifup`
- run a procd-managed watchdog loop every 10 minutes

Safety requirements:

- default UCI instances must be disabled
- do not commit private domains, private routing ranges, public site IPs, cloud provider credentials, DDNS-GO credentials, WireGuard secrets, or PSK material
- do not bundle any user identity; users restore their own DDNS-GO and WireGuard configuration after flashing
- hooks are only user-configured executable paths and must not include bundled secrets

Build integration:

- keep the implementation in POSIX shell
- keep DDNS-GO optional by service name, not a hard package dependency
- select `CONFIG_PACKAGE_wg-endpoint-watchdog=y` only so the generic disabled package is included in images

Validation before finishing:

- run shell syntax checks for all package shell scripts
- run the package guard and behavior tests
- check that no private markers or key-field names were introduced
