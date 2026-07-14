# vm103-failover

`vm103-failover` is a topology-specific OpenWrt package for the home RE-CS-07 router and VM103 GRE backup path. It packages the byte-for-byte program and init script verified on the live router and in the post-backup copy. It is not a generic failover package and its gateways, interfaces, policy tables, probe targets, and thresholds must not be reused on another topology.

## Installed files

- `/usr/sbin/vm103-failover`: the verified route monitor and state machine
- `/etc/init.d/vm103-failover`: the procd service wrapper

The package does not create or change UCI network or firewall configuration, does not perform an automatic restore, and does not remotely enable the service. Network and firewall state comes from the device's wrtbak or keep-config recovery path.

OpenWrt package installation may enable the init script through the normal package lifecycle. When started, the service waits until both `wan` and `gre4-gre_vm103` are ready before monitoring. Stopping the service invokes `vm103-failover --primary`, which restores the primary default route and removes the backup IPv6 policy rule.
