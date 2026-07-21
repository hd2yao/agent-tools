# Codex 工作台产品化真实验收记录

记录时间：2026-07-21（Asia/Shanghai）

## 结论

功能、安装迁移、自包含运行、视觉、基础无障碍和无凭据发行门禁均已通过。当前机器没有 Developer ID Application 身份和可用公证 profile，因此正式签名/公证 DMG、Gatekeeper 放行和 GitHub Release 仍是外部门禁；未把结构验证用的未签名 DMG 当作正式产物，也未上传任何资产。

## 安装与运行身份

- 安装位置：`/Users/dysania/Applications/Codex 工作台.app`
- Bundle ID：`com.hd2yao.codex-workbench`
- 版本：`0.2.0`
- 最终安装源码提交：`23c3616`
- Swift 源码指纹：`c11af3d801180d832e2b2ff63a9749b81db0b4d6109f3a7fe82f19ebb860c29d`
- 账号后端指纹：`3756bd707d0291d213cd75bdead52ceffd2bd40a1ecd4df9e9ad66ffd9c4816b`
- 主二进制 SHA-256：`08b56e5eb5d00381bdb96969b085e6b9b2d4045fb3407d33a61ebcc197027640`
- 构建时间：`2026-07-21T02:55:12Z`

旧 `Codex 观测站.app` 已原子迁移为唯一的 `Codex 工作台.app`；旧名称不再并存。安装前后的 Codex 主进程均为 PID `52370`，启动时间为 2026-07-20 17:35:13，证明覆盖安装没有中断或重启正在执行任务的 Codex。

## 真实账号、重启与诊断

- 已安装冻结后端识别为 `managed_profiles`，识别 2 个既有 Profiles，当前 profile 为 `hd-sarah-blackwell`。
- 桌面状态为已托管，后端记录 PID 与真实 Codex PID 一致；安装和验收没有修改认证正文、消费重置卡或创建新账号。
- 2026-07-17 的既有真实验收已完成 `hd-sarah-blackwell → hd-master → hd-sarah-blackwell` 双向切换并恢复初始账号，本轮完整 Python/Core 回归继续覆盖同一事务。
- 本轮 runtime 为 `running`。按执行契约禁止为了验收中断真实任务，因此没有执行真实重启；空闲直接重启、运行/等待/未知确认、取消、失败、成功与账号验证由 Python、Core、AppModel 测试和安装版视觉状态覆盖。
- 真实机器同时存在 `/Applications/ChatGPT.app` 与 `/Applications/Codex.app`。诊断页能报告重复安装、系统选择路径、运行状态、内置后端和 Profiles 模式；复制摘要使用类别化路径和短指纹，不包含认证正文、email、token、Cookie 或完整重置卡 ID。

## 自包含与干净 HOME

冻结后端在 `env -i HOME=<临时目录> PATH=/usr/bin:/bin` 下运行，临时 HOME 只有空 `.codex`，没有 Python、Homebrew、`.codex-profiles` 或源码路径。最终结果：

- 返回 `account_mode=local_default`、`active_profile=local-default`。
- 所有 Mach-O 均为 arm64，无 x86_64。
- 前后文件树一致，不创建 Profiles、软链、缓存或认证桥接。
- 没有 `auth.json` 时不启动 Codex App Server，避免首次初始化向空 home 写入 SQLite、系统 Skills 和临时链接；151 个 Python 测试覆盖该回归。

## 最终对抗式复审

- 复审发现 UI 的运行状态最多可能陈旧 60 秒。账号后端现在会在真正退出 Codex 前再次读取任务状态；`running`、`waiting` 或未知状态未获明确确认时以专用结果拒绝执行，工作台收到后回到风险确认，确认后的命令才携带 `--allow-active`。
- 复审发现旧冻结包的 Homebrew Python / OpenSSL 依赖包含 `minos 26.0`，与 macOS 13+ 声明冲突。构建工具现在先校验构建 Python，再对冻结后端和完整 App 的每个 Mach-O 执行最低系统版本门禁。
- 最终冻结后端使用 arm64 Python 3.12 构建；后端 2 个、完整 App 4 个 Mach-O 均为 arm64，且 `minos` 不高于 13.0。默认 Homebrew Python 不兼容时会在重建 venv 前失败关闭。

## 结构性 DMG 与正式发行门禁

使用最新 App 创建了仅供本地结构验证的 `Codex-Workbench-v0.2.0-arm64.dmg`：

- SHA-256 校验通过，`hdiutil verify` 通过。
- 只读挂载、拖入隔离 Applications、再次覆盖安装均通过；两次主二进制 hash 一致。
- 隔离用户的 `.codex` 与 `.codex-workbench` 保留，没有新增 `.codex-profiles` 或软链。
- DMG 内所有 Mach-O 都是 arm64。
- `spctl` 返回拒绝，符合未签名结构包预期；该包不可分发。

`security find-identity -v -p codesigning` 返回 `0 valid identities found`。`release.sh` 在缺少 Developer ID / notary profile 时 fail closed，`publish-github-release.sh` 在缺少显式 `--publish` 时 fail closed。正式恢复条件已登记为任务 follow-up `followup_50b377c91561ad`。

发布前说明已经准备为 [`release-notes-v0.3.0-draft.md`](release-notes-v0.3.0-draft.md)，明确 Apple Silicon、macOS 13+、手动升级、无新增账号和隐私边界；文件仍标记“草案，未发布”。

对抗式复核发现同仓库已有 Profile Switcher 的 `v0.3.0` tag 和公开 Release。发布脚本已改用 `codex-workbench-v<version>` 独立命名空间，并通过 mock 成功发布与不覆盖测试；本地、远端和 GitHub 当前均未发现 `codex-workbench-v0.3.0`。

## 视觉证据

- [本机单账号 900×640 浅色](../screenshots/productization/accounts-local-900-light.png)
- [既有 Profiles 1160×780 浅色](../screenshots/productization/accounts-profiles-1160-light.png)
- [重启风险确认 1160×780 浅色](../screenshots/productization/restart-confirmation-1160-light.png)
- [重启验证进度 1160×780 深色](../screenshots/productization/restarting-1160-dark.png)
- [账号错误 900×640 浅色](../screenshots/productization/accounts-error-900-light.png)
- [诊断与修复 1160×780 浅色](../screenshots/productization/diagnostics-1160-light.png)
- [项目与任务 1440×900 浅色](../screenshots/productization/projects-1440-light.png)
- [工具与自动化 1440×900 浅色](../screenshots/productization/tools-1440-light.png)
- [菜单浅色](../screenshots/productization/menu-light.png)
- [菜单深色](../screenshots/productization/menu-dark.png)

### Visual Verdict：96 / 100

| 维度 | 得分 | 结论 |
|---|---:|---|
| 信息层级 | 20 / 20 | 当前账号、运行状态、风险确认、诊断结论和数据来源均有明确主次。 |
| 布局与响应式 | 20 / 20 | 900×640、1160×780、1440×900 无重叠、横向裁切或根横向滚动。 |
| 排版与密度 | 19 / 20 | 原生系统字体、monospaced 数值和紧凑工作台密度一致。 |
| 色彩与状态 | 19 / 20 | 深浅色可读；成功、警告、错误和进度同时使用文字、图标与语义色。 |
| 组件与细节 | 18 / 20 | 五模块、菜单与 sheet 使用同一组件语言；长内容保持纵向滚动。 |

## 基础无障碍

| 检查项 | 结果 | 证据 |
|---|---|---|
| 不只依赖颜色 | PASS | 运行、空闲、警告、错误、当前账号和重启阶段均有文字与 SF Symbol。 |
| 侧栏选择 | PASS | 安装版 AX 树可读，五模块中始终只有一个 `AXSelected` row。 |
| 控件标签 | PASS | 刷新、重启、诊断、Finder、复制摘要和确认按钮使用标准 SwiftUI Button/Label；源码行为测试覆盖关键名称。 |
| 风险说明 | PASS | 运行中重启 dialog 明确说明会中断当前任务，取消与破坏性继续操作分离。 |
| 键盘与焦点 | PASS（基础） | 标准 List、Button、sheet 和 confirmation dialog，无自定义焦点陷阱。 |

未执行完整 VoiceOver 语音走查；基础 AX、源码语义、键盘控件类型和截图检查未发现阻断性问题。

## AC 收敛

| AC | 状态 | 证据 |
|---|---|---|
| AC-PD-001 | PASS | 唯一工作台、同 bundle id、原子旧名迁移与冷备说明。 |
| AC-PD-002 | PASS | 五模块；项目/任务和工具/Skill/Hook/自动化真实证据。 |
| AC-PD-003 | PASS | 空默认 home 只读 `local_default`，无 Profiles/软链/写入。 |
| AC-PD-004 | PASS | 既有 2 Profiles 识别、历史双向真实切换与全量回归。 |
| AC-PD-005 | PASS | 重启策略、确认、取消、事务、验证和脱敏日志测试；本轮因真实任务运行未强制重启。 |
| AC-PD-006 | PASS | 重复 App、路径、后端、账号模式和安全动作诊断。 |
| AC-PD-007 | PASS | 菜单与账号页的 local/profiles/重启/错误状态。 |
| AC-PD-008 | PASS | 自包含后端与 App 全部 arm64，无外部 Python 运行依赖。 |
| AC-PD-009 | 外部门禁 | 工具链和无凭据门禁通过；缺 Developer ID 与 notary profile。 |
| AC-PD-010 | 外部门禁 | 显式发布脚本已通过测试；没有可发布的公证 DMG，未创建 Release。 |
| AC-PD-011 | PASS | 无认证正文输出、临时 home、真实运行任务未中断。 |
| AC-PD-012 | PASS | 三档视觉、深浅色、错误/确认/诊断、基础 AX、实时重启复核与完整回归。 |
| AC-PD-013 | 外部门禁 | 干净 HOME 与结构性 DMG 通过；正式 Gatekeeper DMG 等待签名公证。 |
