# Codex 工作台产品化与公开发行 Spec

## 背景和目标

工作台已经整合操作日志和既有 Profile Switcher 能力，但仍以开发者本机安装为前提，并保留重复的未来入口。目标是把它收敛为唯一日常 Codex 工具，并通过 GitHub Releases 提供普通用户可直接安装的 Apple Silicon DMG。

## 用户场景

### 场景 1：普通单账号用户首次安装

用户只有官方 Codex App 和默认 `~/.codex`。下载 DMG、拖入 Applications 并打开后，工作台直接识别当前账号、额度、重置卡和 Codex 工作状态，不要求创建 profile、软链或安装 Python。

### 场景 2：既有多账号用户继续切换

用户已有 `~/.codex-profiles`。工作台识别既有账号并继续提供额度、重置卡、安全切换和重启，不改变认证文件或 profile 结构。

### 场景 3：重启当前 Codex

Codex 空闲时，用户一键安全重启；存在运行中、待接手或未知状态时，工作台先说明可能中断任务并要求确认。

### 场景 4：排查本机集成

用户从账号页打开“诊断与修复”，查看官方 App 安装、重复 `ChatGPT.app` / `Codex.app`、运行进程、账号模式、后端和最近失败阶段，并执行刷新、打开 App、重启或显示文件等安全操作。

### 场景 5：手动升级

用户从 GitHub Releases 下载新 DMG，并用新版 App 覆盖旧版。App 不自动检查或安装更新，本地数据和账号目录不随覆盖删除。

## 范围

- 侧栏收敛为概览、操作日志、账号管理、项目与任务、工具与自动化。
- 项目排行与任务 / 对话元数据合并展示；上下文摘要状态进入任务详情。
- 工具 / Skill 与 Hook / Automation 合并展示。
- 本机单账号只读识别和既有 Profiles 模式选择。
- 当前账号安全重启、风险确认、结果验证与操作日志。
- 真实诊断页、脱敏摘要和安全动作。
- 原 Profile Switcher 版本化冷备与恢复说明。
- App 展示名收敛为“Codex 工作台”，保持 bundle id 不变。
- `arm64` 自包含账号后端、Developer ID 签名、Hardened Runtime、公证 DMG、SHA-256 和 GitHub Release 手动发布脚本。
- 自动化、真实本机、干净测试用户、视觉和无障碍验收。

## 非目标

- 不支持 Intel 或 Universal 构建。
- 不上 Mac App Store、TestFlight 或 Homebrew。
- 不做 Sparkle、后台版本检查或自动更新。
- 不新增、导入、删除或登录账号，不实现单账号转 Profiles。
- 不改变认证格式、profile 目录和既有切换事务。
- 不删除 Profile Switcher 冷备、源码或 CLI。
- 不复制 Codex 聊天 UI，不重做操作日志 V1.4。
- 不新增遥测、云端账号服务或分析上报。
- 单账号模式首发不执行自动重置卡消费；该能力只在既有 Profiles 模式维持现状。

## 验收标准

### AC-PD-001 唯一日常 App 与冷备

- 主 App 展示名为“Codex 工作台”，bundle id 继续为 `com.hd2yao.codex-workbench`。
- 工作台运行时旧 Profile Switcher 保持退出，版本化冷备和恢复说明仍存在。
- 安装脚本能从旧“Codex 观测站”原子迁移，并在失败时恢复。

### AC-PD-002 信息架构收敛

- 侧栏只显示五个稳定模块，不再显示“即将推出”。
- “项目与任务”同时展示项目统计和最近任务 / 对话元数据。
- “工具与自动化”同时展示工具、Skill、Hook 和 Automation。
- 上下文状态只基于可验证的摘要卡和读取错误，不虚构健康分数。

### AC-PD-003 本机单账号识别

- 没有 profiles 但 `~/.codex` 可用时返回 `local_default` 模式和一个只读本机账号。
- 通过 `~/.codex` 的本机 Codex App Server 读取账号与额度，不移动 `auth.json`、不创建 profile 或软链。
- UI 显示“本机当前账号”，不显示空的账号切换区或新增账号入口。
- Codex 关闭时，只要 App Server 能确认默认 home，仍可显示账号额度；运行状态单独显示未运行 / 空闲。

### AC-PD-004 既有 Profiles 不缩水

- profiles 存在且有效时继续进入 `managed_profiles` 模式。
- 当前账号语义、额度、重置卡、自动重置、双向切换和切换后验证保持通过。
- 不修改 profile 名称、路径和认证桥接格式。

### AC-PD-005 当前账号安全重启

- 空闲状态可直接重启当前 Codex。
- 运行中、待接手和未知状态必须先确认；取消不执行命令。
- 重启复用后端的安全退出、等待、启动和启动验证。
- Profiles 模式重启后仍验证原账号；单账号模式验证 `local_default` 模式和 Codex 进程。
- 成功、失败和取消写入脱敏操作日志，不消费重置卡。

### AC-PD-006 诊断与修复

- “账号来源说明”与“诊断与修复”分离，诊断入口可点击。
- 诊断展示 bundle id 解析、重复安装、运行路径 / 版本、账号模式、默认 home、Profiles、内置后端及最近失败阶段。
- 只提供刷新、打开 Codex、重启、Finder 显示和复制脱敏摘要。
- 不自动删除 App、修复软链或修改认证文件。

### AC-PD-007 菜单栏与账号页面

- 菜单栏仍以当前实际账号额度和 Codex 工作状态为主，并增加“重启当前 Codex”。
- 单账号模式自然省略快速切换；Profiles 模式保留快速切换。
- 账号页面在加载、暂存、错误、重启中和确认状态下保持最近成功数据与稳定布局。

### AC-PD-008 自包含 Apple Silicon 产物

- Release 构建仅包含 `arm64` Mach-O。
- App 内账号后端无需系统、Homebrew 或用户安装的 Python 即可启动。
- Swift Release 运行时只解析包内固定后端路径；开发模式的外部 Python 回退不得进入 Release App。
- 包内所有 Mach-O、dylib、helper 和 App 按从内到外顺序签名并通过严格验证。

### AC-PD-009 签名、公证和 DMG

- Developer ID + Hardened Runtime 构建通过 `codesign --verify --deep --strict`。
- DMG 通过 `notarytool`、`stapler validate` 和 `spctl`。
- DMG 名称包含版本和 `arm64`，并生成 SHA-256。
- 没有签名身份、公证凭据或任一验证失败时，发布脚本必须停止。

### AC-PD-010 GitHub 手动发行

- 发布脚本只在显式提供版本 / tag 和确认参数时创建 GitHub Release。
- Release 包含 DMG、SHA-256、macOS 13+、Apple Silicon 限制和手动升级说明。
- App 不自动请求 GitHub API，不包含后台更新器。

### AC-PD-011 隐私与安全

- 不输出、持久化或复制 token、Cookie、认证正文和完整重置卡 ID。
- 诊断摘要只包含类别化路径、版本、状态、错误类型和时间。
- 单账号测试使用临时目录；不得把真实 `~/.codex` 转换成 profile。
- 真实运行中任务不得为了验收被强制重启。

### AC-PD-012 视觉、无障碍与回归

- 五个模块和诊断 sheet 遵守 `DESIGN.md`，在 900×640、1160×780、1440×900 无裁切或横向滚动。
- 菜单栏、重启确认、诊断项和状态具备可访问性名称，不只依赖颜色。
- 操作日志 V1.4、Profiles 切换、通知和自动重置测试保持通过。
- 正式安装产物完成浅色 / 深色和关键错误状态截图验收。

### AC-PD-013 干净安装

- 在 Apple Silicon 干净测试用户中，不安装 Python、Homebrew 或仓库源码即可运行 DMG 内 App。
- 只有默认 `~/.codex` 时能显示当前账号、额度和运行状态，不创建 profiles / 软链。
- 覆盖安装新版后，账本、设置和账号状态仍存在。

## 约束和假设

- 目标平台为 Apple Silicon、macOS 13 及以上。
- 现有 Swift Package、Design Lock 和 bundle id 保持不变。
- Python 账号逻辑继续是既有 Profiles 认证与切换的权威实现。
- 自包含后端优先采用 PyInstaller `--onedir --target-arch arm64`；它是构建依赖，不是用户运行依赖。
- 当前机器没有可用 Developer ID 签名身份；这不阻断功能和发行脚本开发，但阻断真实公证 DMG 与 GitHub 正式 Release。
- GitHub 远端和 CLI 已可用；任何真实发布仍必须等签名、公证门禁通过。

## 待确认问题

- 正式发行前需要用户提供 Apple Developer Program 下的 Developer ID Application 身份和 `notarytool` Keychain profile；不得把凭据写入仓库或命令输出。
- 项目是否声明为开源及采用何种源码许可证不在本阶段自行决定；Release 可先作为公开二进制分发，但不得在未授权时添加许可证声明。
