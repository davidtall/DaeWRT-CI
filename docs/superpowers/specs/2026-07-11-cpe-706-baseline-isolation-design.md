# CPE 7.06 基线对齐与启动问题隔离设计

## 目标

将 CPE-5G 唯一底层源码固定为已在 RE-SS-01 启动成功的 `0bad892975fe49fd180f99b414a7f168bb694dd7`，并以同源码、同 NOWIFI 配置的 A/B 产物隔离 CPE 功能 overlay 是否影响启动。普通 QCA 工作流保持移动上游策略。

## Provenance 边界

DaeWRT-CI Release Source code tar.gz 只证明 CI 脚本、配置和补丁层。内核、NSS/SSDK、Qualcommax patches、DTS/DTB 与 factory pipeline 必须由 Release sysupgrade 和该完整 ImmortalWrt commit 交叉验证。当前优先基线为 7.06 / `0bad892...` / Linux 6.18.37；6.25 / `42a1f64...` / Linux 6.18.35 仅作为历史回退点。

## 受控构建

- A 使用 `IPQ60XX-WIFI-NO`、LAN `192.168.10.1`，关闭 CPE 网络和 Lucky/Tailscale/Headscale/wrtbak feature overlay。
- B 使用完全相同的 SHA 和 NOWIFI 配置，只打开 CPE feature overlay，并设置 LAN `192.168.13.1`。
- A、B 均能启动后，才建立独立 WiFi-YES 实机测试；WiFi 不进入本次变量集合。

## 失败与产物门禁

源码必须精确 fetch、detached checkout，并在 SHA 不一致时终止。非 TEST 构建若缺少 RE-SS-01 factory 或 sysupgrade 立即失败；上传前生成 `metadata.json` 和覆盖全部上传文件的 `SHA256SUMS`。A/B 的启动结果分别记录，不以编译成功代替实机启动验证。

## 验证

Shell 测试断言完整 SHA、普通 QCA 未被 pin、A/B 同 SHA 与同 NOWIFI、feature overlay 唯一变量、文档 provenance 和历史回退点。合并前运行全部 `tests/test_*.sh`、`git diff --check` 和 YAML 解析。
