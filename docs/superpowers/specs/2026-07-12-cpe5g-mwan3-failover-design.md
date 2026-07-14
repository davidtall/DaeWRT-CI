# CPE-5G mwan3 WAN Failover Design

## Goal

Make Ethernet WAN the normal uplink for the CPE-5G B firmware and use the
UDX710 USB 5G interface only when WAN has lost real Internet reachability.
Automatically return to WAN after stable recovery without changing ordinary
router builds or the CPE A reproduction baseline.

## Scope

This change applies only to the CPE-5G B job in CPE-5G.yml. It installs mwan3
and luci-app-mwan3 through that job's WRT_PACKAGE input and extends the existing
ConfigureCpe5G overlay. It does not enable mwan3 in Config/GENERAL.txt, CPE A,
or any ordinary QCA workflow.

The change does not alter Headscale route acceptance, Nikki rules, Lucky
certificates, wrtbak restore gates, LAN addressing, or firewall zone ownership.

## Interface and Routing Model

- wan remains DHCP and receives network metric 10.
- 5G remains DHCP on usb0, receives network metric 20, and becomes a candidate
  default route managed by mwan3.
- Both interfaces stay in the existing wan firewall zone.
- Peer DNS from 5G is disabled so normal DNS does not consume SIM traffic while
  WAN is healthy. Existing router DNS policy remains authoritative.
- Directly connected routes for 192.168.66.0/24 and 192.168.13.0/24 must bypass
  the default failover policy. Repository fixtures assert the managed rules and
  live tests inspect ip rules, nft marks, conntrack, and selected egress.
  CPE-originated Lucky traffic is accepted only after its response is observed
  returning through usb0 in both WAN-online and 5G-selected states; connected
  routes alone are not sufficient evidence.

## Health Checks and Hysteresis

Both interfaces track multiple independent IPv4 targets suitable for mainland
China and the public Internet: 223.5.5.5, 119.29.29.29, and 1.1.1.1. At least
two targets must succeed.

Initial WAN parameters are count 1, timeout 2 seconds, normal interval 5
seconds, down threshold 3, and up threshold 5. The 5G backup uses a materially
slower 60-second normal interval so it does not continuously consume meaningful
SIM data while idle; failure/recovery intervals may temporarily become faster
during a transition. Runtime evidence may justify later tuning.

The requirement is not literal zero SIM traffic: WAN-normal user business
traffic must not use 5G, while bounded health probes are permitted. Runtime
acceptance records the SIM counter delta over a representative window and the
estimated 24-hour probe budget.

## Policy

The default policy contains a WAN member at metric 10 followed by a 5G member
at metric 20. It is failover, not load balancing. When both links are healthy,
new outbound Internet traffic uses WAN. When WAN is declared offline, new
traffic uses 5G. When WAN passes five consecutive recovery checks, new traffic
returns to WAN. If both links fail, the policy reports unreachable rather than
silently selecting an unverified path.

mwan3 must use its normal mark space and must not change Headscale
accept_routes=0. Repository tests assert configuration shape, but only live
tests can establish whether a particular Nikki mode uses compatible marks.

## Nikki and Lucky Boundaries

Nikki remains responsible for deciding which client traffic is proxied. mwan3
selects the physical uplink after that decision. The firmware must not claim
that Nikki automatically proxies all 5G failover traffic; live verification
must record the active Nikki instance, nftables/ip rules, and observed public
egress IP in both WAN and 5G states.

Lucky inbound service traffic arrives from CPE address 192.168.66.1 to OpenWrt
192.168.66.2:8443. Its response uses the connected usb0 route, not the default
WAN policy. A correct-SNI request and a wrong-SNI rejection must be tested in
both uplink states.

## Generated Configuration

ConfigureCpe5G.sh continues to emit an idempotent first-boot overlay. The
overlay configures network metrics, creates named mwan3 interface/member/policy
and default-rule sections, commits network and mwan3, and enables/restarts
mwan3 only after all required UCI sections exist.

The generator must be safe on repeated execution, must not duplicate list
values, and must fail before committing if wan or 5G cannot be identified. It
must not overwrite unrelated user-created mwan3 sections. The two mwan3
interface sections must be named `wan` and `5G` because mwan3 resolves section
names as netifd interface names; reconcile owns their required tracking values
while retaining unrelated options. Generated members, policies and rules use a
`cpe5g_` prefix, and policy/rule identifiers remain within mwan3's 15-character
hard limit. The stock `https` and `default_rule_v4` example rules are removed
only when every field still matches the package signature: they precede
appended rules and select the stock `balanced` policy, which would silently
defeat 5G failover. Modified/user-named rules and IPv6 defaults are preserved.
Because wrtbak may restore an older network or
mwan3 file before Headscale enrollment, the same versioned managed-config
reconcile runs after the restore gate reaches a terminal state. Tests must prove
that reconcile restores only cpe5g-owned sections and preserves user sections.

## Existing Device Rollout

Before changing the online router, capture a fresh sysupgrade/config backup,
UCI exports for network/firewall/mwan3/Nikki, routes, rules, nftables, current
public egress, and Tailscale status. Install or stage only the required packages
and apply the same generated configuration used by the firmware overlay.

Non-disruptive checks run first. A real WAN-loss test can disconnect the only
remote maintenance path, so it is permitted only while a local operator has
LAN or serial/UBoot recovery access. Without that recovery window, repository
implementation may complete but the destructive live failover gate remains
explicitly pending.

Rollback restores the saved network and mwan3 configuration, disables mwan3,
restores 5G defaultroute=0, reloads network/firewall, and verifies the original
WAN default route and Tailnet reachability.

## Verification

Repository tests must prove:

1. CPE B alone installs mwan3 and luci-app-mwan3.
2. CPE A and ordinary builds do not install or configure mwan3.
3. WAN metric 10 and 5G metric 20 are generated.
4. 5G becomes an mwan3 candidate route but does not provide peer DNS.
5. Three tracking targets, reliability 2, down 3, and up 5 are generated.
6. The policy orders WAN before 5G and the default rule selects that policy.
7. Re-running the bootstrap is idempotent and preserves unrelated sections.
8. Restore-terminal reconciliation recreates missing managed sections without
overwriting user-owned mwan3 sections. The bootstrap enables and starts only
this gated worker, and a process lock suppresses duplicate init/recovery
execution. A preserved user IPv4 catch-all is treated as an intentional
override and logged because it can shadow the managed default. LAN
bypass CIDR is derived from the runtime UCI address and mask. Changed network
options trigger a controlled netifd reload; reload failure restores the prior
network values and leaves an explicit failure for recovery.
9. Direct LAN/CPE networks have explicit bypass coverage and runtime evidence.
10. Shell syntax, all tests/test_*.sh, workflow YAML parsing, and git diff
   checks pass.

Live verification must record normal WAN egress, simulated WAN failure,
confirmed 5G egress, SIM counters, WAN recovery, automatic return, CPE Lucky
8443 symmetry, Nikki state, and Tailnet recovery. TEST=true configuration
validation precedes any TEST=false firmware build.

## Branch and Integration Strategy

Use the single short-lived branch work2ai/cpe5g-mwan3-failover-20260712 based
on the post-PR-12 main. Merge normally after tests and review, then delete the
branch. The CPE B workflow already lives on main, so no historical CPE branch
is recreated and no force-push is permitted.
