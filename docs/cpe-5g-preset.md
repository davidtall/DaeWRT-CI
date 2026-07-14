# CPE-5G 固件预设

`CPE-5G` 是为连接 UDX710 CPE 的 `jdcloud,re-ss-01` 路由器准备的手动构建预设。当前生产基线是 B 功能对照：2026-07-06 的 `VIKINGYFY/immortalwrt@0bad892975fe49fd180f99b414a7f168bb694dd7`（Linux `6.18.37`，`IPQ60XX-706-NOWIFI`，feature overlay 开启）。A 纯底层对照也已正常启动，保留为隔离基线；2026-06-25 的 `42a1f64b5dbd2a99d05daca94ae5a87eebff59b4`（Linux `6.18.35`）保留为历史回退点。

该固定只覆盖 CPE-5G；普通 QCA 工作流仍按各自分支构建。`davidtall/immortalwrt:stable` 是候选上游，不是自动生产基线。DaeWRT-CI Source code tar.gz 只用于核对 CI 脚本/配置/补丁层，不作为内核源码 provenance。

## 7.06 provenance

完整记录见 README；核心身份为：qca-nss tree `16f46086b41275bcc004e534f966f9cd509cd146`、qca-nss-dp `d8f802f0`、qca-nss-drv `6aa14c7` r18、qca-nss-ecm `8c7355b` r8、qca-ssdk `d9a19649` r1、Qualcommax patches tree `d211c3263007c73642721596c4004424b32016a8`、RE-SS-01 DTS blob `a278a87acb783e546cc473878cb8fe5ca3d50a92`，factory pipeline 为 `append-kernel | pad-to 6144k | append-rootfs | append-metadata`（blob `44a7716b4009d8be76c4c54fa399cf89bec4a838`）。

## A/B 隔离顺序

- A：`0bad892...` + 从 7.06 CI tag 保存的 `IPQ60XX-706-NOWIFI`，关闭 CPE 网络及 Lucky/Tailscale/Headscale/wrtbak feature overlay，LAN `192.168.10.1`。
- B：同一 SHA、同一 NOWIFI 配置，只开启当前 CPE overlay，LAN `192.168.13.1`。
- 只有 A 可启动而 B 不可启动，才归因并继续排查 overlay；A、B 都可启动后才新增 WiFi-YES 测试。

日常 Action 触发保持 `BUILD_BASELINE_A=false`，只构建 B。仅当需要隔离底层 kernel/NSS/设备树问题与 feature overlay 问题时设为 `true`，让 A 与 B 同时生成；完成诊断后恢复默认关闭。

## Lucky 与公网 IPv6 服务

推荐链路：

```text
CPE 公网动态 IPv6:外部端口
  -> CPE IPv6-to-IPv4 relay
  -> OpenWrt usb0 192.168.66.2:Lucky入口端口
  -> Lucky 按 Host/端口反代
  -> 192.168.13.x:目标服务端口
```

Lucky 监听 `192.168.66.2` 或 `0.0.0.0` 即可接收 CPE relay；不是让每个 LAN 服务主动转发到 `192.168.66.2`。CPE 和 OpenWrt 防火墙只开放列入清单的入口端口，Lucky 只配置明确目标，避免公开整个 LAN。

## RA、PD 与 NDP 实验边界

- 最理想的是运营商向 CPE提供 DHCPv6-PD，CPE再把独立前缀委派给 OpenWrt；目前没有观察到 PD 证据。
- CPE 自己拥有公网 `/64` 地址，不等于可以把这个 `/64` 直接下发给 OpenWrt LAN。
- 无 PD 时需要 RA relay + NDP proxy/relay，并维护邻居发现、回程路径、前缀变化和 IPv6 firewall；蜂窝重拨换前缀后必须自动重建状态。
- 该方案开发难度中高、强依赖 CPE 内核能力和运营商网络行为。生产默认继续使用已验证的 IPv6 端口转发；实验必须放在独立插件/分支，并保留 A/B 与 U-Boot 回滚路径。

## 2026-07-12 实机结果

- Action run：[`29160402065`](https://github.com/hotwa/OpenWRT-CI/actions/runs/29160402065)，A/B 均构建成功且均能刷入、进入系统。
- B artifact：`sha256:bad3ff165840c982ed2ae337532ca456eb940560ae71665196cfa4245ce7631d`；B sysupgrade：`bb69688f6a4385e897d1cf6f9c355d22d279d94e9b9e3e87d9a15c434682485b`。
- B 运行态：`JDCloud RE-SS-01`、Linux `6.18.37`、revision `r0-0bad892`；`5G` DHCP 接口已启用，`usb0=192.168.66.2/24`，到 `192.168.66.1` 直连，6677 返回 HTTP 200。
- 双网卡 Windows 上旧的永久路由 `192.168.66.0/24 via 192.168.11.247` 会让请求从 WAN 进入并被拒绝；客户端应改经 `192.168.13.1` LAN 网关。该客户端路由问题不属于 B overlay 回归。

## 2026-07-13 最终整合构建证据

- 当前 `main@13c984d70139436205177f0a8640a29d87787e5c` 的 TEST=false Action run：[`29204310241`](https://github.com/hotwa/OpenWRT-CI/actions/runs/29204310241)，结论为 `success`。
- 合并前的 TEST=true run [`29203906558`](https://github.com/hotwa/OpenWRT-CI/actions/runs/29203906558) 成功，B 配置包含 mwan3/LuCI mwan3，A 正确跳过；约 50 KB artifact 是预期配置包，不是可刷写固件。
- artifact `8264724224`：`CPE-706-B-6.18-MANUAL-IPQ60XX-706-NOWIFI_26.07.13-02.45.58-private`，大小 `416207857` bytes；GitHub artifact digest 与下载 ZIP 的本地 SHA256 均为 `f5b40733961930b145e3c4278f46013018b27e29c0be70cbb22ad856397455b9`。
- RE-SS-01 factory 为 `212885673` bytes，SHA256 `94a062d54846f5b4bf32114da99377421f8538bd268a42d228136a1a1e899aba`；sysupgrade 为 `208107792` bytes，SHA256 `7b8c9b2f66ea67898535129d316837a9293cd35665e7b87fb517b098d8fceb78`。artifact 内全部 5 个 `SHA256SUMS` 条目均已在下载后逐项复核。
- `metadata.json` 记录 `source_commit=0bad892975fe49fd180f99b414a7f168bb694dd7`、`config=IPQ60XX-706-NOWIFI`、`required_device=jdcloud_re-ss-01`、`feature_overlay=true`；factory、sysupgrade、`SHA256SUMS`、metadata 和 manifest 均齐全。
- manifest 包含 mwan3 2.12.1、LuCI mwan3、firewall4、iptables-nft/ip6tables-nft、xtables-nft、kmod-nft-compat、Nikki 和 Lucky。产物保存在仓库外的 `C:\Users\pylyz\Downloads\OpenWRT-CI-CPE5G-29204310241`。
- 该证据只证明当前 main 的构建与离线产物完整性；本轮未自动刷机，尚未替代实机启动、wrtbak 恢复门、Headscale 身份复用、Lucky/5G、mwan3/Nikki fwmark 故障切换、SIM 计数及重启/冷启动验收。刷写前必须再次确认现场 LAN/U-Boot 管理路径、定时回滚和 7.06 已知可启动回滚固件。

`davidtall/immortalwrt:stable` 只作为下一版候选上游。候选版本必须记录完整源码 SHA、Action run 和 artifact SHA256，并在 RE-SS-01 上完成刷写、LAN/WAN/NSS、两次软重启、一次冷启动和 `192.168.66.1:6677` 管理链路验证，才能更新这里及 README 的“当前已验证基线”。验证失败时只回退源码 SHA，不撤销 hotwa 已有功能提交。

## 网络规划

| 网络 | 用途 |
| --- | --- |
| `192.168.66.0/24` | CPE 与 OpenWrt 的 USB/5G 管理链路；CPE 为 `192.168.66.1`，OpenWrt 的 5G 接口通常为 `192.168.66.2`。 |
| `192.168.13.0/24` | CPE-5G OpenWrt LAN；默认路由器地址为 `192.168.13.1`。 |

`192.168.13.0/24` 避免与既有的 `192.168.10.0/24`、`192.168.11.0/24`、`192.168.12.0/24` 网段重叠，适合后续作为 Headscale 子网路由的唯一 LAN 前缀。

## 内置服务

- `luci-app-lucky` 由共享 `GENERAL` 配置全局启用。
- CPE-5G B 固件单独内置 `mwan3` 与 `luci-app-mwan3`；A 和普通 QCA 固件不因此启用 mwan3。
- 首次启动创建 DHCP 接口 `5G`（设备 `usb0`），将其加入 `wan` 防火墙区域，并确保存在 `lan -> wan` 转发。`wan` 路由 metric 为 `10`，`5G` 为 `20`；两者均可提供候选默认路由，但 mwan3 只在 WAN 连续探测失败后把新连接切到 5G，WAN 连续恢复后自动切回。
- WAN 每 5 秒、5G 每 60 秒分别探测 `223.5.5.5`、`119.29.29.29`、`1.1.1.1`，至少两个成功才视为在线；连续失败 3 次下线、连续成功 5 次恢复。5G 禁用 peer DNS。5G 空闲时仍有少量健康探测流量，并非绝对零流量。
- `192.168.66.0/24` 与运行时从 `network.lan.ipaddr/netmask` 计算出的 LAN 前缀使用 mwan3 `default` 旁路规则，CPE→Lucky 入站连接的响应应继续经 usb0 直连返回。已有连接不会在链路切换时无缝迁移，验收以新连接为准。
- reconcile 管理 `wan`/`5G` 必要探测项及 `cpe5g_` 前缀成员、策略和规则。mwan3 软件包自带的 `https`、`default_rule_v4` 只有在名称、字段和值仍完整匹配出厂签名时才删除，避免 stock `balanced` 提前截获 IPv4；任何新增/修改字段都视为用户策略并保留，用户命名规则与 IPv6 默认规则同样保留。
- bootstrap 不直接运行 reconcile，只启用并启动唯一的 gate-aware procd 服务，保证 factory 首启本轮即可收敛。服务持有进程锁，等待 wrtbak `gate.json` 终态后幂等修复；network 值改变时受控 reload netifd，reload 失败恢复修改前的 metric/defaultroute/peerdns 并返回失败。用户保留的 IPv4 `0.0.0.0/0` 规则属于显式 override，可能先于 CPE failover 匹配，运行日志会告警。
- Nikki 位于策略路由上层，但不同 TUN/规则模式对 fwmark 和出口选择的实际兼容性必须在设备上验证，不能仅凭固件配置断言。
- `tailscale` 与 `luci-app-tailscale-community` 已内置。私有构建中只有在注入 `HEADSCALE_OPENWRT_AUTHKEY` Secret 时才会首启自动加入 Headscale；该密钥不写入仓库。
- CPE-5G 预设默认不启用 LAN 到 Tailnet 的转发。路由器本身可经 Tailnet 管理；如需让 LAN 客户端访问 Tailnet，必须在触发构建前单独评估并启用对应策略。
- `luci-app-wrtbak` 固定使用经过审查的提交。日常 R2 上传继续按 LAN/IP 推导站点代理；首启恢复通过 `WRTBAK_S3_FORCE_DIRECT` 强制直连 R2，避免依赖代理链路。
- `WRTBAK_FIRSTBOOT_AUTO_ENABLED` 只在 CPE-5G 工作流中提供，默认 `0`。只有已确认恢复来源和回滚路径时才应设为 `1`；恢复完成后该上游功能会按配置重启设备。
- B 预设启用 wrtbak 首启恢复时，Headscale 自动注册受 `/root/wrtbak/firstboot/gate.json` 门禁约束：必须先复用恢复的 `tailscaled.state`，确认没有备份或恢复最终失败后才允许消耗 auth key 注册新节点。该规则来自共享 feature overlay，已随 `main` 的 CPE-5G B 构建生效。

## 触发构建

GitHub Actions 选择 **CPE-5G**。日常保持 `BUILD_BASELINE_A=false`，先以 `TEST=true` 验证 B 配置，再以 `TEST=false` 生成 B artifact；需要故障隔离时才打开 A。每个可刷写 artifact 必须同时包含 RE-SS-01 factory、sysupgrade、`SHA256SUMS` 和 `metadata.json`。

固件刷入后，先确认 `usb0`/5G 接口自动获得 `192.168.66.2`，再从 `192.168.13.x` LAN 客户端访问 `http://192.168.66.1:6677/`，并确认 Lucky 页面可访问、以及 `tailscale status` 已加入 Headscale。普通 QCA 工作流默认关闭该首启配置，不受此预设影响。

真实拔线/断 WAN 测试可能切断远程维护路径，只有现场 LAN、串口或 U-Boot 救援可用且已设置定时回滚时才能执行。上线前先备份 network/firewall/mwan3/Nikki/Tailscale 状态；再验证 WAN 正常出口、5G 探测流量、WAN 故障后的新连接出口、WAN 恢复自动切回、Lucky 正确/错误 SNI、Tailnet 与 Nikki。未满足现场救援条件时只完成固件和非破坏性验证，不远程模拟断网。
