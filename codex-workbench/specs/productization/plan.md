# Codex 工作台产品化与公开发行实现方案

## 推荐方案

以现有工作台和成熟 Profile 后端为基础增加“双模式账号适配”，而不是重写认证：既有 profiles 继续走原事务，单账号把默认 `~/.codex` 作为只读本机账号来源。Swift Core 负责模式、重启风险、诊断和展示契约；App 层负责系统进程、路径探测和 UI；发布层把 Python 后端冻结为包内 `arm64` onedir helper，再从内到外签名并制作 DMG。

## 第一性原理评审

### 真实目标

用户需要的是“别人下载一个 DMG 就能用”的唯一工作台，不是完整的软件商店、自动更新平台或新的账号系统。

### 最小可用结果

- 单账号用户零迁移看到当前额度。
- 既有多账号能力不缩水。
- 当前账号能安全重启，诊断真的可用。
- 侧栏不再承诺重复模块。
- Apple Silicon DMG 自包含、签名、公证并能在干净用户中运行。

### 更简单路径

- 只支持 `arm64`，不制作 Universal。
- 只发 GitHub Release，不做 App Store、Homebrew 和自动更新。
- 不实现新增账号。
- 用构建期 PyInstaller 封装成熟 Python，而不是发行时要求 Python 或重写认证。

## 架构和数据流

### 账号模式

Python payload 新增 `account_mode`：

- `managed_profiles`：保持现有 profile 列表和 active profile 规则。
- `local_default`：profile 集合为空时读取 shared home，并返回内部键 `local-default` 的只读账号；不写 active profile 记录。
- `unavailable`：默认 home 不存在或不可读。

Swift `AccountDashboardPayload` 解码模式并由 `AccountPresentationBuilder` 统一选择当前账号。`local-default` 在 UI 永远显示为“本机当前账号”，不出现在切换目标中，也不进入自动重置消费。

### 工作区目录

`LocalEvidenceReader` 已读取 thread catalog、context cards 和 workflow files。`WorkbenchAppModel` 公开经过裁剪的工作区快照：

- 项目与任务：项目排行 + 最近 thread metadata + 可验证摘要卡状态；点击只负责打开 Codex thread。
- 工具与自动化：现有工具 / Skill 排行 + Hook / Automation fingerprint 和语义快照。
- 概览：只显示确定性读取警告和摘要卡状态，不计算虚构的上下文健康分数。

### 重启

`AccountRestartPolicy` 根据 runtime 决定直接执行或确认。后端新增 `restart` 命令：Profiles 模式复用当前 profile 的 `app` 事务；单账号模式安全退出后用默认 home 启动。Swift 在命令结束后刷新并用 `AccountRestartVerifier` 验证原账号 / 模式和进程状态。

### 诊断

App 层收集可注入的原始探测结果；Core `WorkbenchDiagnosticsBuilder` 转成分级、脱敏、可测试的 finding。UI 分成账号来源 DisclosureGroup 和诊断 sheet，所有修改性高的动作继续禁用。

### 自包含后端

PyInstaller 6.x onedir 产物放在 `Contents/Helpers/CodexAccountBackend/`。Release Gateway 直接执行其中主二进制；开发 Gateway 可继续用仓库 Python。构建测试明确在移除 Homebrew / 系统 Python 路径时执行 helper `--help` 和 fixture status。

### 发行

发布脚本分层：

1. 构建自包含 helper 和 Swift `arm64` Release。
2. 组装 `Codex 工作台.app`。
3. 从 helper 内嵌 Mach-O 到登录 helper、主 App 逐层 Developer ID 签名。
4. 生成 DMG 和 SHA-256。
5. `notarytool submit --wait`、staple、`spctl`。
6. 只有显式 `--publish` 才调用 `gh release create`。

## 变更文件

### Python 账号后端

- 修改 `codex-profile-switcher/codex_profile.py`：`restart` 命令、本机单账号 status 编排。
- 修改 `codex-profile-switcher/codex_profile_dashboard.py`：`local_default` payload。
- 修改 `codex-profile-switcher/tests/test_codex_profile.py`、`test_dashboard.py`。

### Swift Core

- 修改 `Sources/CodexWorkbenchCore/AccountModels.swift`、`AccountPresentation.swift`、`AccountGateway.swift`、`AccountRuntimePolicy.swift`、`AppContracts.swift`。
- 新增 `AccountRestartPolicy.swift`、`WorkbenchDiagnostics.swift`、`WorkspaceCatalogPresentation.swift`。
- 修改 `AccountOperationEventFactory.swift`。
- 新增并注册对应 Core tests。

### Swift App / UI

- 修改 `AppModel.swift`、`AccountRuntimeServices.swift`、`CodexIntegrationService.swift`、`WorkbenchShell.swift`、`AccountsView.swift`、`MenuBarView.swift`、`OverviewView.swift`、`ProjectsView.swift`、`ToolsSkillsView.swift`。
- 新增 `DiagnosticsView.swift`。
- 按需扩展视觉验收 fixture，但不改变 Design Lock。

### 构建与发行

- 新增 `requirements-build.txt`、`scripts/build-account-backend.sh`、`scripts/sign-app.sh`、`scripts/create-dmg.sh`、`scripts/release.sh`、`scripts/publish-github-release.sh`。
- 新增 `Resources/AccountBackend.entitlements`、`Resources/CodexWorkbench.entitlements`、`THIRD_PARTY_NOTICES.md`。
- 修改 `build-app.sh`、`install-app.sh`、`verify-install.sh`、`Resources/Info.plist`、`README.md`。
- 新增脚本测试，覆盖架构、自包含、签名门禁、DMG 命名和无凭据拒绝。

## 测试和验证

- Python：`python3 -m unittest -v`。
- Core：`./codex-workbench/test.sh`。
- Swift：`swift build -c release --arch arm64`。
- 自包含：清空外部 Python 路径后执行包内 helper。
- App：`build-app.sh`、`install-app.sh`、`verify-install.sh`。
- 发行：`file`、`codesign`、`spctl`、`notarytool`、`stapler`、`hdiutil verify`、SHA-256。
- 真实行为：双向 profile 切换并恢复初始账号；只在空闲时执行真实重启。
- 干净用户：临时 macOS 用户或等价隔离环境，只有默认 `~/.codex`。
- UI：900 / 1160 / 1440，浅色 / 深色，单账号、Profiles、确认、错误和诊断 sheet。

## 风险和回滚

| 风险 | 缓解 | 回滚 |
|---|---|---|
| 本机单账号被误当成 profile | 显式 account mode、临时目录测试、只读适配 | 禁用 local 模式，Profiles 路径不变 |
| 单账号进入自动重置消费 | Core / Coordinator 双重模式门禁 | 停止自动化，保留只读额度 |
| 重启中断真实任务 | runtime policy + 用户确认；验收不打断运行任务 | 取消操作或手动打开 Codex |
| PyInstaller helper 无法公证 | onedir、arm64、从内到外签名、最早发行门禁 | 回到自包含方案评审，不改写认证 |
| 重复 App 路径判断错误 | bundle id + 常见路径 + 运行实例交叉显示 | 只报告，不自动删除 / 修复 |
| App 改名造成旧观测站并存 | 安装脚本识别旧名并原子迁移 | 恢复 stage 中旧 App |
| 缺少 Developer ID / notary 凭据 | 发布脚本 fail closed | 完成功能与测试 DMG，不创建正式 Release |
| 公开发布破坏用户数据 | DMG 仅覆盖 App；干净用户和覆盖安装测试 | 回退上一 Release，用户目录不变 |

## 执行契约

独立契约见 `specs/productization/execution-contract.md`。认证格式、账号新增、自动更新、Intel、App Store、真实运行任务强制重启或冷备删除都属于 rewind trigger。
