# Codex 工作台产品化真实验收记录

记录时间：2026-07-21（Asia/Shanghai）

## 结论

功能、安装迁移、自包含运行、视觉、基础无障碍和无凭据发行门禁均已通过。当前机器没有 Developer ID Application 身份和可用公证 profile，因此正式签名/公证 DMG、Gatekeeper 放行和 GitHub Release 仍是外部门禁；未把结构验证用的未签名 DMG 当作正式产物，也未上传任何资产。

## 安装与运行身份

- 安装位置：`/Users/dysania/Applications/Codex 工作台.app`
- Bundle ID：`com.hd2yao.codex-workbench`
- 版本：`0.2.0`
- 最终安装源码提交：`a9cbe4f`
- Swift 源码指纹：`2c0431096693bd01a23ec5e23c36e4449ae31d4371a78dc92cbcdbda0303f82b`
- 账号后端指纹：`564675d1197374116306abdb86a09188a876dacc2145a8eee4bf70cd8eab008f`
- 主二进制 SHA-256：`5864cbf9d396bba2491e1a03d10f44a296a110e077600721a495d2e4dbae8053`
- 构建时间：`2026-07-21T05:48:34Z`

旧 `Codex 观测站.app` 已原子迁移为唯一的 `Codex 工作台.app`；旧名称不再并存。安装前后的 Codex 主进程均为 PID `52370`，启动时间为 2026-07-20 17:35:13，证明覆盖安装没有中断或重启正在执行任务的 Codex。

## 真实账号、重启与诊断

- 已安装冻结后端识别为 `managed_profiles`，识别 2 个既有 Profiles，当前 profile 为 `hd-sarah-blackwell`。
- 桌面状态为已托管，后端记录 PID 与真实 Codex PID 一致；安装和验收没有修改认证正文、消费重置卡或创建新账号。
- 2026-07-17 的既有真实验收已完成 `hd-sarah-blackwell → hd-master → hd-sarah-blackwell` 双向切换并恢复初始账号，本轮完整 Python/Core 回归继续覆盖同一事务。
- 本轮 runtime 为 `running`。按执行契约禁止为了验收中断真实任务；安装版后端在执行前实时复核并以退出码 3 拒绝无确认重启，Codex PID 保持 `52370`。空闲直接重启、运行/等待/未知确认、取消、失败、成功与账号验证由 Python、Core、直接 AppModel 测试和安装版视觉状态覆盖。
- 真实机器同时存在 `/Applications/ChatGPT.app` 与 `/Applications/Codex.app`。诊断页能报告 bundle id 解析、重复安装、系统选择路径、运行状态、默认 Codex home、内置后端和 Profiles 模式；复制摘要使用类别化路径和短指纹，不包含认证正文、email、token、Cookie 或完整重置卡 ID。

## 自包含与干净 HOME

冻结后端在 `env -i HOME=<临时目录> PATH=/usr/bin:/bin` 下分别验证缺少认证入口和仅有测试认证入口两种状态，没有 Python、Homebrew、`.codex-profiles` 或源码路径。最终结果：

- 缺少 `auth.json` 或只有空 `.codex` 时返回 `account_mode=unavailable`、`active_profile=null`，不会把空目录冒充当前账号。
- 测试 `auth.json` 存在时返回 `account_mode=local_default`，但账号不可确认，因此 Swift 不显示当前账号。账号读取不会复制认证正文：权限为 0700 的临时 `CODEX_HOME` 只保存一个指向原认证入口的临时软链接，并由系统沙盒禁止 App Server 写入认证入口所在目录、最终目标目录以及临时 home 的非白名单路径；沙盒不可用时失败关闭。
- 写入白名单只包含 4 组已核实的状态 SQLite 文件及 `installation_id`。真实 App Server 在该白名单下成功完成账号读取，临时认证入口始终保持软链接，未知暂存文件和 `auth.json` 原子替换均被拒绝；读取结束后临时目录清理。两种状态的源 HOME 前后文件树与文件 hash 一致，不创建 Profiles、系统 Skills、缓存或认证副本。
- 所有冻结后端 Mach-O 均为 arm64，无 x86_64；157 个 Python 测试和 App 源码级默认 home 测试覆盖上述回归。

## 最终对抗式复审

- 复审发现 UI 的运行状态最多可能陈旧 60 秒。账号后端现在会在真正退出 Codex 前再次读取任务状态；`running`、`waiting` 或未知状态未获明确确认时以专用结果拒绝执行，工作台收到后回到风险确认，确认后的命令才携带 `--allow-active`。
- 复审发现旧冻结包的 Homebrew Python / OpenSSL 依赖包含 `minos 26.0`，与 macOS 13+ 声明冲突。构建工具现在先校验构建 Python，再对冻结后端和完整 App 的每个 Mach-O 执行最低系统版本门禁。
- 最终冻结后端使用 arm64 Python 3.12 构建；后端 2 个、完整 App 4 个 Mach-O 均为 arm64，且 `minos` 不高于 13.0。默认 Homebrew Python 不兼容时会在重建 venv 前失败关闭。
- 单账号 App Server 读取曾可能把初始化数据库和系统 Skills 写回真实 `~/.codex`；初版隔离修复又会把完整 `auth.json` 复制到临时磁盘，第二版仍允许 App Server 在临时 home 原子替换软链接并留下认证副本，均违反 AC-PD-011。最终实现只创建临时软链接，并以最小写入白名单阻断临时认证暂存与原子替换，同时保护直接来源目录和认证文件最终目标目录；真实默认 home 保持只读，沙盒缺失时不读取账号。
- GitHub 发布脚本曾只检查文件存在；现在上传前重新验证 SHA、DMG 结构、公证票据和 Gatekeeper，并要求工作树干净、HEAD 已是远端分支 tip、本地/远端 tag 与 Release 均不存在，最终 tag 通过 `--target` 绑定该 HEAD。
- AppModel 新增源码级状态机 runner，直接覆盖实时拒绝后恢复确认、取消零命令、成功后验证与账号不一致失败；测试初始化不请求系统通知，也不触碰真实后台刷新。

## 结构性 DMG 与正式发行门禁

使用最新 App 创建了仅供本地结构验证的 `Codex-Workbench-v0.2.0-arm64.dmg`：

- SHA-256 校验通过，`hdiutil verify` 通过。
- 只读挂载、拖入隔离 Applications、再次覆盖安装均通过；两次主二进制 hash 一致。
- 隔离用户的 `.codex` 与 `.codex-workbench` 保留，没有新增 `.codex-profiles` 或软链。
- DMG 内所有 Mach-O 都是 arm64。
- DMG 内 4 个 Mach-O 的 `minos` 均不高于 13.0；主二进制 SHA-256 与已安装最终 App 一致，为 `5864cbf9d396bba2491e1a03d10f44a296a110e077600721a495d2e4dbae8053`。
- `spctl` 返回拒绝，符合未签名结构包预期；该包不可分发。

`security find-identity -v -p codesigning` 返回 `0 valid identities found`。`release.sh` 在缺少 Developer ID / notary profile 时以退出码 2 fail closed；`publish-github-release.sh` 对当前未公证结构包在任何 GitHub 调用前拒绝上传。正式恢复条件已登记为任务 follow-up `followup_50b377c91561ad`。

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
| AC-PD-003 | PASS | 空默认 home 返回 unavailable；认证入口存在时以临时链接和最小写入白名单隔离读取，只在账号确认后展示，无 Profiles、认证副本或源 HOME 写入。 |
| AC-PD-004 | PASS | 既有 2 Profiles 识别、历史双向真实切换与全量回归。 |
| AC-PD-005 | PASS | 重启策略、实时二次复核、确认、取消、事务、验证和脱敏日志测试；安装版对运行任务拒绝无确认重启并保持 PID。 |
| AC-PD-006 | PASS | bundle id、重复 App、路径、默认 home、后端、账号模式和安全动作诊断。 |
| AC-PD-007 | PASS | 菜单与账号页的 local/profiles/重启/错误状态。 |
| AC-PD-008 | PASS | 自包含后端与 App 全部 arm64，无外部 Python 运行依赖。 |
| AC-PD-009 | 外部门禁 | 工具链和无凭据门禁通过；缺 Developer ID 与 notary profile。 |
| AC-PD-010 | 外部门禁 | 显式发布脚本、远端 HEAD/tag 绑定和公证资产二次校验已通过测试；没有可发布的公证 DMG，未创建 Release。 |
| AC-PD-011 | PASS | 无认证正文输出或复制；沙盒拒绝临时认证暂存与原子替换并保护认证来源，真实运行任务未中断。 |
| AC-PD-012 | PASS | 三档视觉、深浅色、错误/确认/新鲜诊断截图、基础 AX、直接 AppModel 状态机测试与完整回归。 |
| AC-PD-013 | 外部门禁 | 干净 HOME 与结构性 DMG 通过；正式 Gatekeeper DMG 等待签名公证。 |
