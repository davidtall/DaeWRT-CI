# CPE-5G 已验证 A 基线固定与回退设计

## 目标

为 `jdcloud,re-ss-01` 的 CPE-5G 固件建立可复现、可审计、可回退的已验证源码基线。保留当前仓库已有的 CPE USB/5G 网络、`192.168.13.1` LAN、Lucky、Tailscale/Headscale、wrtbak 和私有构建逻辑，只改变 CPE-5G 使用的 ImmortalWrt 源码选择与基线记录。

## 已验证 A 基线

以下组合来自能够在 RE-SS-01 上正常启动的 2026-06-25 固件。整套源码以完整提交 SHA 固定，不以移动的 `main` 或 `stable` 分支作为可复现标识。

| 组件 | 已验证值 | 在 A 基线中的来源/最后相关提交 |
| --- | --- | --- |
| 固件源码 | `VIKINGYFY/immortalwrt@42a1f64b5dbd2a99d05daca94ae5a87eebff59b4` | A 基线唯一源码身份 |
| Linux kernel | `6.18.35` | `a1a3659c2918f20a45b82875fdf5f7bbf431e34a` |
| qca-nss 补丁树 | A 基线 `package/qca-nss` 完整内容 | `ad0b63563ff89ac01b09c6977d226d4587de2938` |
| qca-nss-dp | 上游 `d8f802f08fd8ff31057ba58edb20bbe448e7b505`，源码日期 `2026-01-19` | 包装/补丁最后相关提交 `ad0b63563ff89ac01b09c6977d226d4587de2938` |
| qca-nss-drv | 上游 `6aa14c7`，源码日期 `2026-01-12`，`PKG_RELEASE=18` | 包装/补丁最后相关提交 `5f520e5c2bc7ee41b0a3e25c0686be22d59af34f` |
| qca-nss-ecm | 上游 `8c7355b`，源码日期 `2026-04-03`，`PKG_RELEASE=7` | 包装/补丁最后相关提交 `38e28da69292dda73196b31e243985f742a30bdc` |
| qca-ssdk | 上游 `d9a196497ecee2530722d906e0efe1b7408b6ef6`，源码日期 `2025-11-14` | 包装/补丁最后相关提交 `38e28da69292dda73196b31e243985f742a30bdc` |
| Qualcommax 6.18 补丁 | A 基线 `target/linux/qualcommax/patches-6.18` 完整内容 | 最后相关提交 `38e28da69292dda73196b31e243985f742a30bdc` |
| RE-SS-01 DTB | `target/linux/qualcommax/dts/ipq6000-re-ss-01.dts` | `0c453396bfed1b3c18a77bd0fd58396da223e514` |
| RE-SS-01 factory pipeline | `target/linux/qualcommax/image/ipq60xx.mk` | `ac6d2f17ddcc6ae33c12e246f848ca0d06b5cd84` |

单个“最后相关提交”只用于解释组件来源；复现固件时必须 checkout 完整源码提交 `42a1f64b5dbd2a99d05daca94ae5a87eebff59b4`，不能分别拼接表中的提交。

## 工作流设计

1. `WRT-CORE.yml` 增加可选字符串输入 `WRT_COMMIT`，默认留空，确保普通 QCA、LiBWrt 等现有工作流继续按原分支构建。
2. 源码 clone 完成后，仅当 `WRT_COMMIT` 非空时执行精确提交 checkout，并验证 `git rev-parse HEAD` 与请求 SHA 一致。无法取得或不匹配时立即终止构建，禁止静默退回分支 HEAD。
3. `CPE-5G.yml` 继续保留 `VIKINGYFY/immortalwrt` 与 `main` 作为仓库及获取上下文，但明确传入 A 基线完整 SHA。
4. 构建日志和固件信息记录实际源码 SHA，使 Action 产物能够追溯到源码，不再依赖构建时间猜测分支位置。
5. 不修改普通 `QCA-6.18-VIKINGYFY` 工作流；A 基线固定只影响 CPE-5G 手动预设。

## 文档与维护规则

- `README.md` 增加“上游关系与已验证固件基线”，区分 CI 上游 `davidtall/DaeWRT-CI`、固件源码上游 `davidtall/immortalwrt:stable` 和当前生产已验证 A 快照。
- `AGENTS.md` 增加代理维护硬约束：更新 kernel、qca-nss、qca-nss-dp、qca-nss-drv、qca-nss-ecm、qca-ssdk、Qualcommax 补丁、RE-SS-01 DTB/factory pipeline 或固件源码 SHA 时，必须更新基线表、构建候选固件并完成实机验证。
- “上游对齐”表示候选版本来源与 `davidtall/immortalwrt` 的目标提交一致，不表示移动的 `stable` 自动成为生产已验证版本。
- 上游更新出现无法启动、网口缺失、NSS 异常或 factory/sysupgrade 异常时，先退回上一个标记为“实机已验证”的完整源码 SHA，不撤销 CPE/Lucky/网络等 hotwa 定制提交。

## 实机验证门槛

候选源码只有满足以下项目后，才能替换 README 和 AGENTS 中的“当前已验证基线”：

1. RE-SS-01 factory 或 sysupgrade 刷写成功并进入系统。
2. 连续软重启至少两次、断电冷启动至少一次。
3. LAN、WAN 和交换机端口正常，NSS-DP/DRV/ECM 模块加载无关键错误。
4. `usb0`/5G 获得 `192.168.66.2`，`192.168.13.x` 能访问 `192.168.66.1:6677`。
5. Lucky、Tailscale/Headscale、wrtbak 的既有行为无回归。
6. 记录 Action run、artifact SHA256、实际固件源码 SHA 和验证日期。

在完成上述验证前，新版本只能标记为“候选”，不能覆盖 A 基线。

## 自动化验证

- 新增测试断言 CPE-5G 使用完整 40 位 A 基线 SHA。
- 新增测试断言 `WRT-CORE` 声明、传递并校验 `WRT_COMMIT`。
- 测试普通 QCA 工作流没有被强制绑定到 CPE A 基线。
- 保留并运行现有完整 shell 测试集，确认其他构建和设备配置不受影响。

## 非目标

- 本次不把 `davidtall/immortalwrt:stable` 当前 HEAD 设为生产基线。
- 本次不撤销或重写 hotwa 现有功能提交。
- 本次不修改 RE-CS-02、RE-CS-07 或普通 QCA 固件的源码选择。
- 本次不声称仅凭 CI 构建成功就完成实机验证。
