# Codex 工作台账号整合实现方案

## 推荐方案

保持现有 Python Profile Switcher 后端为单一账号引擎，把独立 App 中的原生运行时服务迁入工作台，并用工作台 Design Lock 重做菜单栏和页面。旧 App 在迁移期不改为主入口，只保留为冷备。

## 第一性原理评审

### 真实目标

用户需要的是一个可信、完整、日常只启动一次的 Codex 工作台，而不是把两个 App 的窗口机械拼接在一起。

### 最小可用结果

最小可用结果必须同时满足：

- 菜单栏显示当前真实登录账号的额度和工作状态；
- 工作台能够安全切换两个账号并验证结果；
- 额度、逐张重置卡、通知和自动重置不缩水；
- 用量、项目和工具统计在工作台内可见；
- 旧 App 可冷备回退。

只迁移账号卡片或把旧面板嵌入工作台都不满足目标。

### 真实约束

- Python 后端已经处理认证原子替换、冲突和 Codex 重启顺序，不能重写。
- 自动重置具有真实资源消耗风险，必须保留幂等与冷备兼容。
- 工作台目标 macOS 13，不能依赖更新系统独有的窗口启动 API。

### 更简单路径

复用后端和 payload，迁移纯运行时服务、重做界面，比重写认证或嵌入 5,000 行旧 AppKit 页面更简单且可长期维护。

## 架构和数据流

### Core

- 扩展 `AccountModels.swift` 解码 runtime、account、usage、reset cards 和 rankings。
- 扩展 `AccountGateway.swift` 支持重置卡消费命令和切换后状态读取。
- 新建纯逻辑：菜单栏展示、切换验证、自动重置决策与状态键。
- 所有纯逻辑使用自定义 Swift test harness TDD。

### App

- `WorkbenchAppModel` 继续作为主窗口与菜单栏共享的唯一 `ObservableObject`。
- 新建账号运行时服务负责通知、自动重置持久化、旧 App 进程检测和后台调用。
- `refreshAll` 仍并行刷新 ledger 与账号，但账号刷新、官方通知和自动化统一进入同一串行协调路径。
- 切换完成后强制重新读取并验证 payload。

### UI

- 动态 `MenuBarExtra` label 展示额度与状态语义符号；若系统限制无法满足截图门禁，按契约回退到 AppKit `NSStatusItem`。
- 重做 `MenuBarView` 和 `AccountsView`。
- 新建 `ProjectsView`、`ToolsSkillsView`，扩展 `AppModule` 和侧栏。
- 保持 V1.4 `ActivityView` 结构不变，只接入新的账号事件。

### 启动

- 新增轻量登录辅助 executable，嵌入主 App `Contents/Library/LoginItems`。
- 辅助入口用 `--login-item` 启动主 App；主 App 在该模式只保留菜单栏。
- 手动打开和再次激活显示主窗口。

## 变更文件

### 账号后端

- 修改 `codex-profile-switcher/codex_profile.py`：同步 `v0.10.1` 凭据刷新保护。
- 修改 `codex-profile-switcher/tests/test_codex_profile.py`：保留对应回归。
- 不修改认证数据格式。

### Core

- 修改 `Sources/CodexWorkbenchCore/AccountModels.swift`。
- 修改 `Sources/CodexWorkbenchCore/AccountGateway.swift`。
- 修改 `Sources/CodexWorkbenchCore/AppContracts.swift`。
- 新建 `Sources/CodexWorkbenchCore/AccountPresentation.swift`。
- 新建 `Sources/CodexWorkbenchCore/AccountSwitchVerification.swift`。
- 新建 `Sources/CodexWorkbenchCore/AutomaticResetPolicy.swift`。
- 修改 / 新建对应 `Tests/CodexWorkbenchCoreTests/` 测试并注册到 `main.swift`。

### App

- 修改 `Sources/CodexWorkbenchApp/AppModel.swift`。
- 新建 `Sources/CodexWorkbenchApp/AccountRuntimeServices.swift`。
- 新建 `Sources/CodexWorkbenchApp/ResetCreditNotificationService.swift`。
- 修改 `Sources/CodexWorkbenchApp/CodexWorkbenchApp.swift`。
- 修改 `Sources/CodexWorkbenchApp/WorkbenchPreferences.swift`。
- 修改 `Sources/CodexWorkbenchApp/MenuBarView.swift`。
- 修改 `Sources/CodexWorkbenchApp/AccountsView.swift`。
- 新建 `Sources/CodexWorkbenchApp/ProjectsView.swift`。
- 新建 `Sources/CodexWorkbenchApp/ToolsSkillsView.swift`。
- 修改 `Sources/CodexWorkbenchApp/WorkbenchShell.swift`。
- 按需修改 `OverviewView.swift` 和 `DesignSystem.swift`。

### 登录辅助与构建

- 修改 `Package.swift`，增加 `CodexWorkbenchLoginLauncher` executable target。
- 新建 `Sources/CodexWorkbenchLoginLauncher/main.swift`。
- 新建 `Resources/LoginLauncher-Info.plist`。
- 修改 `build-app.sh`、`install-app.sh` 和 `verify-install.sh`。

### 文档和截图

- 修改 `README.md`、`DESIGN.md`、现有 spec 总览和视觉验收报告。
- 新增 `screenshots/profile-integration/` 证据。

## 测试和验证

### 自动测试

- `python3 -m unittest -v`
- `./codex-workbench/test.sh`
- `swift build`
- `./codex-workbench/build-app.sh`
- `./codex-workbench/verify-install.sh`

### 真实验证

- 读取并保存初始账号名称。
- 退出旧冷备进程但保留 App。
- 安装并启动新工作台。
- 对照真实 payload 检查两个账号、额度和重置卡。
- 执行初始账号 → 另一个账号 → 初始账号，并在每次切换后验证实际状态。
- 检查只有工作台 App 运行。

### 视觉验证

- 菜单栏浅色 / 深色。
- 账号页 `900×640`、`1160×780`、`1440×900`。
- 项目和工具页默认窗口。
- 切换中、暂存、错误和长内容状态。
- 运行产物 commit、fingerprint、build time、binary hash、PID 与启动时间齐全。

## 风险和回滚

| 风险 | 缓解 | 回滚 |
|---|---|---|
| Swift payload 与 Python 演进不一致 | 可选字段、真实 fixture、完整契约测试 | 保留上次成功快照和冷备 |
| 自动重置重复消费 | 旧偏好域、同一 fingerprint/idempotency、冷备进程互斥 | 停止工作台自动化，启用冷备 |
| 切换命令返回成功但账号未切换 | 强制重新读取并验证 active profile | 显示失败，不写成功事件 |
| 登录启动弹窗 | 独立辅助入口和 `--login-item` 行为测试 | 暂时关闭登录启动，不影响手动使用 |
| MenuBarExtra 无法动态呈现 | 新鲜安装截图门禁 | 回退 AppKit NSStatusItem |
| Python 打包陈旧 | fingerprint 覆盖实际资源、verifier 改写测试 | 安装器恢复前一版本 |
| V1.4 日志回归 | 全量 Core 测试与真实 ledger 复查 | 回滚独立账号批次提交 |

## 执行契约

独立契约见 `specs/profile-integration/execution-contract.md`。任何认证格式、外部网络、真实重置卡消费或旧 App 删除需求都必须暂停并回到 spec。
