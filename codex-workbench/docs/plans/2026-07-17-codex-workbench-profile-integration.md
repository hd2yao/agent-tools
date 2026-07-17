# Codex 工作台账号整合 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 Codex Profile Switcher 的成熟账号能力完整迁入 Codex 工作台，使工作台成为唯一日常 App，同时保留旧 App 为冷备直到用户验收。

**Architecture:** 继续使用现有 Python 账号引擎作为认证、账号状态、切换和重置卡 RPC 的唯一权威来源。Swift Core 承载完整 payload、展示契约、切换验证和自动重置纯策略；工作台 App 承载唯一刷新协调器、系统通知、冷备进程互斥、菜单栏和页面。

**Tech Stack:** Swift 6、SwiftUI、AppKit、UserNotifications、ServiceManagement、Swift Package Manager、Python 3 `unittest`、本机 Codex App Server、shell 构建 / 安装脚本。

---

执行前先读：

- `codex-workbench/docs/plans/2026-07-17-codex-workbench-profile-integration-design.md`
- `codex-workbench/specs/profile-integration/spec.md`
- `codex-workbench/specs/profile-integration/execution-contract.md`
- `codex-workbench/DESIGN.md`

所有业务行为使用 `@superpowers:test-driven-development`。遇到测试失败或真实状态不符时使用 `@superpowers:systematic-debugging`。每个任务提交前按 `@superpowers:verification-before-completion` 检查当前证据。

### Task 1：固定冷备基线并同步 Profile Switcher v0.10.1

**Files:**

- Modify: `codex-profile-switcher/README.md`
- Modify: `codex-profile-switcher/build-menubar-app.sh`
- Modify: `codex-profile-switcher/codex_profile.py`
- Modify: `codex-profile-switcher/tests/test_codex_profile.py`
- Create: `codex-workbench/docs/profile-switcher-cold-backup.md`

**Step 1：记录冷备安装产物身份**

运行：

```bash
defaults read "$HOME/Applications/Codex Profile Switcher.app/Contents/Info.plist" CFBundleShortVersionString
shasum -a 256 "$HOME/Applications/Codex Profile Switcher.app/Contents/MacOS/Codex Profile Switcher"
stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S%z' "$HOME/Applications/Codex Profile Switcher.app"
```

预期：版本为 `0.10.1`，生成非空 SHA-256 和安装时间。把非敏感身份写入 `docs/profile-switcher-cold-backup.md`；不得记录认证文件。

**Step 2：运行同步前基线测试**

运行：

```bash
cd codex-profile-switcher
python3 -m unittest -v
cd ../codex-workbench
./test.sh
```

预期：Python 和 Swift Core 全部 PASS。若失败，先定位现有基线问题，不得带着未知失败迁移。

**Step 3：同步单独的 v0.10.1 安全提交**

运行：

```bash
git cherry-pick 732682fe8fa0b01618c7b8f8cbbc7605cf1585cb
```

预期：只更新上述 Profile Switcher 四个 tracked 文件；不触碰主工作树未跟踪的 `tests/ui_snapshot/`。

**Step 4：验证同步结果**

运行：

```bash
cd codex-profile-switcher
python3 -m unittest -v
python3 -m py_compile codex_profile.py codex_profile_dashboard.py
```

预期：全部 PASS；`cmd_app` 在重启前执行凭据 reconciliation，账号冲突时中止。

**Step 5：提交冷备文档**

```bash
git add codex-workbench/docs/profile-switcher-cold-backup.md
git commit -m "docs: record profile switcher cold backup"
```

### Task 2：扩展完整账号 payload 与展示契约

**Files:**

- Modify: `codex-workbench/Sources/CodexWorkbenchCore/AccountModels.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchCore/AccountPresentation.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/AccountGatewayTests.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/AccountPresentationTests.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/main.swift`

**Step 1：写失败的完整 payload 解码测试**

测试 fixture 必须包含：

```json
{
  "active_profile": "hd-master",
  "runtime_status": {
    "state": "running",
    "light": "green",
    "label": "运行中",
    "active_process_count": 1,
    "recent_process_count": 1,
    "latest_activity_age_ms": 1200
  },
  "profiles": [{
    "name": "hd-master",
    "account": {"available": true, "plan_type": "plus", "email_present": true, "requires_openai_auth": true},
    "rate_limits": {
      "primary": {"remaining_percent": 87, "window_minutes": 300, "resets_at": 1784632385},
      "secondary": {"remaining_percent": 62, "window_minutes": 10080, "resets_at": 1785032385}
    },
    "reset_credit_details": {
      "available_count": 2,
      "total_earned_count": 4,
      "earliest_expires_at": 1784732385,
      "credits": [{"id": "masked", "used": false, "status": "available", "expires_at": 1784732385, "reminders": [{"kind": "one_hour", "at": 1784728785}]}]
    },
    "usage_metrics": {"today_tokens": 1234, "today_available": true, "last_7_tokens": 9000, "last_14_tokens": 17000}
  }],
  "project_rankings": {"available": true, "projects": [{"name": "tools", "path": "/safe/tools", "thread_count": 3, "tokens_used": 1000, "latest_updated_at": 1784632000}]},
  "tool_rankings": {"available": true, "tools": [{"id": "functions.exec", "namespace": "functions", "name": "exec", "call_count": 9, "latest_updated_at": 1784632000, "thread_tokens": 3000}]},
  "skill_rankings": {"available": true, "skills": [{"name": "brainstorming", "use_count": 2, "latest_timestamp": "2026-07-17T08:00:00Z"}], "bad_line_count": 0}
}
```

断言 runtime、两档额度、逐张卡、用量和三个排行均被解码。运行：

```bash
cd codex-workbench
./test.sh
```

预期：FAIL，缺少对应模型字段。

**Step 2：实现完整可选模型**

在 `AccountModels.swift` 增加：

```swift
public struct AccountRuntimeStatus: Codable, Equatable, Sendable {
    public let state: String
    public let light: String
    public let label: String
    public let activeProcessCount: Int
    public let recentProcessCount: Int
    public let latestActivityAgeMs: Int?
}

public struct AccountResetCreditCard: Codable, Identifiable, Equatable, Sendable {
    public let id: String?
    public let status: String?
    public let used: Bool?
    public let title: String?
    public let expiresAt: TimeInterval?
    public let reminders: [AccountResetCreditReminder]?
    public var stableID: String { id ?? "expiry-\(expiresAt ?? 0)" }
}
```

按 fixture 增加 account、usage、project、tool、skill 模型；所有演进字段用可选值，保持旧 fixture 可解码。

**Step 3：实现当前账号和菜单栏纯展示逻辑**

`AccountPresentation.swift` 至少提供：

```swift
public struct AccountMenuPresentation: Equatable, Sendable {
    public let profile: String?
    public let quotaText: String
    public let runtimeLabel: String
    public let runtimeSymbol: String
    public let accessibilityLabel: String
}

public enum AccountPresentationBuilder {
    public static func menu(payload: AccountDashboardPayload?) -> AccountMenuPresentation
}
```

规则：只用 `activeProfile` / `desktopStatus.activeProfile`；额度缺失为 `--`；运行状态用不同 SF Symbol 和文字，不只依赖颜色。

**Step 4：运行测试并提交**

```bash
cd codex-workbench
./test.sh
git add Sources/CodexWorkbenchCore/AccountModels.swift Sources/CodexWorkbenchCore/AccountPresentation.swift Tests/CodexWorkbenchCoreTests
git commit -m "feat: decode complete account dashboard payload"
```

预期：全部 PASS。

### Task 3：把 Python 后端纳入安装 freshness

**Files:**

- Modify: `codex-workbench/build-app.sh`
- Modify: `codex-workbench/verify-install.sh`
- Create: `codex-workbench/scripts/account-resource-fingerprint.sh`
- Create: `codex-workbench/Tests/Scripts/test-account-resource-freshness.sh`

**Step 1：写失败的脚本测试**

测试构建到临时安装根后修改打包的 `codex_profile.py`，再运行 verifier，断言非零退出且包含：

```text
FAIL: 打包的账号后端不是当前源码
```

运行：

```bash
cd codex-workbench
bash Tests/Scripts/test-account-resource-freshness.sh
```

预期：FAIL，因为当前 fingerprint 不覆盖 Python。

**Step 2：实现统一资源指纹**

`account-resource-fingerprint.sh` 对下列文件按固定顺序计算 SHA-256：

```text
../codex-profile-switcher/codex_profile.py
../codex-profile-switcher/codex_profile_dashboard.py
```

`build-app.sh` 把结果写入 `WorkbenchAccountBackendFingerprint`；`verify-install.sh` 对 installed resources 计算并与源码、plist 同时比较。

**Step 3：验证并提交**

```bash
cd codex-workbench
bash Tests/Scripts/test-account-resource-freshness.sh
./build-app.sh
git add build-app.sh verify-install.sh scripts/account-resource-fingerprint.sh Tests/Scripts/test-account-resource-freshness.sh
git commit -m "build: verify bundled account backend freshness"
```

预期：测试先证明篡改失败，再证明正常构建 PASS。

### Task 4：实现切换后真实验证

**Files:**

- Modify: `codex-workbench/Sources/CodexWorkbenchCore/AccountGateway.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchCore/AccountSwitchVerification.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/AccountGatewayTests.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/AccountSwitchVerificationTests.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/main.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/AppModel.swift`

**Step 1：写失败的 verifier 测试**

覆盖：目标匹配且 managed、目标不匹配、状态未知、后端错误。公开结果：

```swift
public enum AccountSwitchVerification: Equatable, Sendable {
    case verified(profile: String)
    case mismatch(expected: String, actual: String?)
    case unmanaged(profile: String?)
}
```

运行 `./test.sh`，预期 FAIL。

**Step 2：扩展 Gateway 命令与错误**

增加 `switchAndLoadStatus(profile:)`：先调用现有 `app` 命令，成功后强制调用 `status --json --refresh-reset-credits`。不得在 Core 中直接操作认证文件。

**Step 3：实现 AppModel 切换阶段**

发布：

```swift
enum AccountSwitchStage: Equatable {
    case switching(profile: String)
    case verifying(profile: String)
}
```

只有 verifier 为 `.verified` 才更新 payload、记录 `account_switched`；其他结果写失败状态且不写成功事件。

**Step 4：验证并提交**

```bash
cd codex-workbench
./test.sh
git add Sources/CodexWorkbenchCore/AccountGateway.swift Sources/CodexWorkbenchCore/AccountSwitchVerification.swift Sources/CodexWorkbenchApp/AppModel.swift Tests/CodexWorkbenchCoreTests
git commit -m "feat: verify account after profile switch"
```

### Task 5：迁移运行状态与冷备进程互斥

**Files:**

- Create: `codex-workbench/Sources/CodexWorkbenchApp/AccountRuntimeServices.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/AppModel.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/OverviewView.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/RuntimePresentationTests.swift`

**Step 1：写状态展示测试**

覆盖 `green/running`、`yellow/waiting`、`red/idle`、unknown，断言 label、symbol 和可访问性文字。运行 `./test.sh`，预期 FAIL。

**Step 2：实现可注入进程检测器**

App target 提供：

```swift
protocol LegacyProfileSwitcherDetecting: Sendable {
    func isRunning() async -> Bool
}
```

真实实现用 bundle id `com.hd2yao.codex-profile-switcher`。AppModel 发布 `isLegacyProfileSwitcherRunning`；为 true 时不触发自动重置并显示冲突提示。

**Step 3：替换旧的 `isCodexRunning` 主语义**

概览和菜单栏使用 payload `runtimeStatus`。Codex App 进程是否存在只作为启动按钮状态，不包装成对话“运行中”。

**Step 4：验证并提交**

```bash
cd codex-workbench
./test.sh
swift build
git add Sources/CodexWorkbenchApp Sources/CodexWorkbenchCore Tests/CodexWorkbenchCoreTests
git commit -m "feat: share codex runtime status across workbench"
```

### Task 6：迁移重置卡通知和自动重置状态机

**Files:**

- Create: `codex-workbench/Sources/CodexWorkbenchCore/AutomaticResetPolicy.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/AutomaticResetPolicyTests.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/main.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/ResetCreditNotificationService.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/AccountRuntimeServices.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchCore/AccountGateway.swift`

**Step 1：写自动重置失败测试**

至少覆盖：

- reached type + 有有效卡 → 选择最早到期卡；
- 仅到期临近但未耗尽 → `.none`；
- 耗尽但无卡 → `.none`；
- expiry 已过 → `.none`；
- 十分钟内已有尝试 → `.retryLater`；
- outcome 已为终态 → `.none`；
- 同 fingerprint 重用 idempotency key。

运行 `./test.sh`，预期 FAIL。

**Step 2：实现纯策略**

公开输入 / 输出：

```swift
public struct AutomaticResetContext: Equatable, Sendable {
    public let profile: AccountProfile
    public let now: Date
    public let previousOutcome: String?
    public let lastAttempt: Date?
    public let idempotencyKey: String?
}

public enum AutomaticResetDecision: Equatable, Sendable {
    case none
    case retryLater
    case consume(fingerprint: String, idempotencyKey: String)
}
```

策略不得持有 UserDefaults 或调用网络。

**Step 3：实现旧偏好域存储**

App target 只通过 `UserDefaults(suiteName: "com.hd2yao.codex-profile-switcher")` 读写：

```text
automatic-reset.outcome.*
automatic-reset.last-attempt.*
automatic-reset.idempotency.*
```

不得读取其他旧偏好键。

**Step 4：实现消费命令和通知**

Gateway 调用：

```text
consume-reset-credit <profile> --idempotency-key <key>
```

通知 identifier 继续使用 `com.hd2yao.codex-profile-switcher.reset-credit.` 前缀，避免冷备残留重复请求。通知内容只包含 profile 显示名和到期时间。

**Step 5：验证并提交**

```bash
cd codex-workbench
./test.sh
swift build
git add Sources/CodexWorkbenchCore Sources/CodexWorkbenchApp Tests/CodexWorkbenchCoreTests
git commit -m "feat: migrate reset credit automation"
```

不得调用真实 consume 命令作为本任务测试。

### Task 7：重做动态菜单栏

**Files:**

- Modify: `codex-workbench/Sources/CodexWorkbenchApp/CodexWorkbenchApp.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/MenuBarView.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/DesignSystem.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/AccountPresentationTests.swift`

**Step 1：补展示契约测试**

断言当前 `hd-master + 87% + running` 生成：

```text
quotaText = "87%"
runtimeLabel = "运行中"
accessibilityLabel = "当前登录账号 hd-master，5小时剩余 87%，Codex 运行中"
```

未知额度为 `--`，不得为 `0%`。

**Step 2：实现动态 MenuBarExtra label**

label 使用 `runtimeSymbol + quotaText`，状态通过符号和文字双重表达。若 fresh install 截图无法显示动态文本或符号，停止并按执行契约回到 plan，改用 AppKit `NSStatusItem`。

**Step 3：重做面板**

顺序固定：当前账号 / 运行状态 → 两档额度 / 重置卡 → 快速切换 → 最近重要操作 → 工作台 / Codex / 刷新 → 设置 / 退出。宽约 `380pt`，高不超过 `520pt`。

**Step 4：构建和提交**

```bash
cd codex-workbench
./test.sh
swift build
git add Sources/CodexWorkbenchApp Tests/CodexWorkbenchCoreTests
git commit -m "feat: make account quota the workbench menu status"
```

### Task 8：重构账号管理页

**Files:**

- Replace: `codex-workbench/Sources/CodexWorkbenchApp/AccountsView.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/DesignSystem.swift`

**Step 1：建立页面 preview / fixture 模式**

增加仅开发构建可用的脱敏 fixture，覆盖两个账号、两档额度、两张卡、用量、切换中、暂存和错误。不得把真实账号认证内容写入 fixture。

**Step 2：实现六个区块**

按 Design Lock 实现：当前登录账号、官方额度、逐张重置卡、其他账号、账号用量、高级诊断。移除顶部三张同权角色卡和“独立 Profile Switcher 仍可继续使用”的日常文案；冷备说明只在冲突 / 错误时出现。

**Step 3：编译和局部截图**

```bash
cd codex-workbench
swift build
./build-app.sh
```

预期：最小窗口无横向滚动，最长 profile 名不推走按钮，逐张重置卡可完整阅读。

**Step 4：提交**

```bash
git add Sources/CodexWorkbenchApp/AccountsView.swift Sources/CodexWorkbenchApp/DesignSystem.swift
git commit -m "feat: bring full account management into workbench"
```

### Task 9：新增项目分析与工具 / Skill 模块

**Files:**

- Modify: `codex-workbench/Sources/CodexWorkbenchCore/AppContracts.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/AppContractsTests.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/ProjectsView.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/ToolsSkillsView.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/WorkbenchShell.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/OverviewView.swift`

**Step 1：写失败的模块顺序测试**

预期：

```swift
AppModule.allCases == [.overview, .activity, .accounts, .projects, .toolsSkills]
```

运行 `./test.sh`，预期 FAIL。

**Step 2：实现真实项目页面**

展示 name、path、threadCount、tokensUsed、latestUpdatedAt；空 / 错 / 暂存状态使用 QuietEmptyState 或局部错误卡。

**Step 3：实现工具与 Skill 页面**

工具和 Skill 分区展示 call / use count、最近时间和数据健康。不得把项目或工具排行继续放在账号管理页。

**Step 4：验证并提交**

```bash
cd codex-workbench
./test.sh
swift build
git add Sources/CodexWorkbenchCore/AppContracts.swift Sources/CodexWorkbenchApp Tests/CodexWorkbenchCoreTests/AppContractsTests.swift
git commit -m "feat: add project and tool modules to workbench"
```

### Task 10：实现登录启动辅助入口

**Files:**

- Modify: `codex-workbench/Package.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchLoginLauncher/main.swift`
- Create: `codex-workbench/Resources/LoginLauncher-Info.plist`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/CodexWorkbenchApp.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/WorkbenchPreferences.swift`
- Modify: `codex-workbench/build-app.sh`
- Modify: `codex-workbench/verify-install.sh`
- Create: `codex-workbench/Tests/Scripts/test-login-launcher-bundle.sh`

**Step 1：写失败的 bundle 测试**

断言构建后存在：

```text
Codex 观测站.app/Contents/Library/LoginItems/Codex Workbench Login Launcher.app
```

且 helper bundle id 为 `com.hd2yao.codex-workbench.login-launcher`、`LSUIElement=true`。运行脚本，预期 FAIL。

**Step 2：实现 launcher target**

launcher 用 `NSWorkspace.OpenConfiguration.arguments = ["--login-item"]` 打开主 App 后退出，不呈现 Dock 或窗口。

**Step 3：实现主 App 启动语义**

- `--login-item`：隐藏 / 关闭初始主窗口但保留菜单栏。
- 手动正常启动：显示主窗口。
- 已后台运行时收到 reopen：显示主窗口。
- 设置页使用 `SMAppService.loginItem(identifier:)` 管理 helper，不再使用 `SMAppService.mainApp`。

**Step 4：验证并提交**

```bash
cd codex-workbench
bash Tests/Scripts/test-login-launcher-bundle.sh
swift build
./build-app.sh
git add Package.swift Sources/CodexWorkbenchLoginLauncher Resources/LoginLauncher-Info.plist Sources/CodexWorkbenchApp build-app.sh verify-install.sh Tests/Scripts/test-login-launcher-bundle.sh
git commit -m "feat: keep login launch in the menu bar"
```

### Task 11：完善账号事件并回归操作日志

**Files:**

- Modify: `codex-workbench/Sources/CodexWorkbenchApp/AppModel.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchCore/EvidenceReconciler.swift`（仅在新服务证据需要时）
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/EvidenceReconcilerTests.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/ObservationStateTests.swift`

**Step 1：写失败事件测试**

覆盖：验证成功切换、验证不匹配、自动重置成功、重置次数变化、旧 App 冲突。成功事件必须包含 before / after、account 和 source chain；失败不得伪装 success。

**Step 2：实现最小事件接入**

工作台 actor 使用 `codex-workbench`，后端 source chain 保留 `codex-profile-switcher` 和 `automatic-reset`。不得写入 idempotency key 或原始 card ID。

**Step 3：全量 V1.4 回归**

```bash
cd codex-workbench
./test.sh
```

预期：所有 context / workflow enrichment 与新账号测试 PASS。

**Step 4：提交**

```bash
git add Sources Tests
git commit -m "feat: record verified workbench account operations"
```

### Task 12：安装并执行真实双向账号验收

**Files:**

- Modify: `codex-workbench/install-app.sh`
- Modify: `codex-workbench/verify-install.sh`
- Create: `codex-workbench/docs/profile-integration-live-acceptance.md`

**Step 1：记录真实初始状态**

使用打包前源码后端读取 `status --json`，只记录 `active_profile`、两档剩余值、重置卡数量和生成时间；不要保存完整 payload。记录旧 App 安装存在和当前进程状态。

**Step 2：退出冷备进程**

只退出 `com.hd2yao.codex-profile-switcher`，确认 App 仍存在。不得卸载。

**Step 3：全量构建安装**

```bash
cd codex-workbench
./test.sh
swift build
./install-app.sh
./verify-install.sh
```

预期：全部 PASS，安装指纹包含后端 fingerprint。

**Step 4：真实读取两个账号**

从已安装工作台触发刷新，核对两个 profiles、两档额度、逐张重置卡和 runtime。与源码后端的脱敏摘要一致。

**Step 5：真实双向切换**

设初始账号为 A，另一个为 B：

1. 在工作台切换 A → B。
2. 等待 UI 验证 B，另用已安装后端 `status --json` 复核 `active_profile=B` 和 managed。
3. 在工作台切换 B → A。
4. 同样复核 `active_profile=A`，确保恢复初始状态。

任一步出现认证冲突、需要重新登录或不能恢复，立即停止并保留冷备，不继续视觉验收。

**Step 6：记录进程和事件证据**

确认只有工作台 App 运行，旧 App 仍安装但无进程；检查两次切换日志与实际账号一致。

**Step 7：提交安装文档**

```bash
git add codex-workbench/install-app.sh codex-workbench/verify-install.sh codex-workbench/docs/profile-integration-live-acceptance.md
git commit -m "test: verify integrated account switching"
```

### Task 13：视觉、性能和可访问性验收

**Files:**

- Create: `codex-workbench/screenshots/profile-integration/`
- Create: `codex-workbench/docs/profile-integration-visual-acceptance.md`
- Modify: UI files only if a screenshot gate fails

**Step 1：记录运行产物身份**

记录源码 commit、dirty fingerprint、安装 build time、binary SHA、PID 和启动时间。旧进程或身份不明时截图无效。

**Step 2：截取规定状态**

- `menubar-light.png`
- `menubar-dark.png`
- `accounts-light-900x640.png`
- `accounts-light-1160x780.png`
- `accounts-light-1440x900.png`
- `accounts-stale-or-error.png`
- `projects-light-1160x780.png`
- `tools-skills-light-1160x780.png`

切换中状态可用脱敏 fixture；真实当前账号、额度和重置卡主截图必须来自已安装 App。

**Step 3：检查 AX 与几何**

验证菜单栏状态项可读名称、账号切换按钮、额度文字、逐张卡列表、滚动边界、最长 profile 名和窗口三档。任何错误当前账号、越界、裁切或横向滚动直接 FAIL。

**Step 4：观察稳定内存**

刷新完成后观察至少两个 60 秒周期，RSS 不持续增长；记录稳定范围。若明显增长，使用 systematic-debugging 定位再继续。

**Step 5：完成 Visual Verdict 并提交**

总分必须 ≥ 90；设计健康和技术健康每项 ≥ 3/4。

```bash
git add codex-workbench/screenshots/profile-integration codex-workbench/docs/profile-integration-visual-acceptance.md
git commit -m "docs: verify integrated workbench visuals"
```

### Task 14：文档、收敛和长期记录

**Files:**

- Modify: `README.md`
- Modify: `codex-workbench/README.md`
- Modify: `codex-workbench/DESIGN.md`
- Modify: `codex-workbench/specs/profile-integration/tasks.md`
- Modify: `codex-workbench/docs/profile-integration-live-acceptance.md`
- Modify: `/Users/dysania/program/documents/obsidian_vault/03_Resources/Codex工作台/Codex 变更日志.md`

**Step 1：更新产品和模块说明**

README 明确工作台是唯一日常入口、旧 App 是冷备、CLI 是内部账号引擎；删除“独立 Profile Switcher 仍是高级入口”等过期描述。

**Step 2：更新 Design Lock**

把账号页和菜单栏契约改为本设计；增加项目分析、工具与 Skill 页面验收截图。保留 V1.4 操作日志契约。

**Step 3：执行 HD2YAO converge**

逐条列出 AC-PI-001 至 AC-PI-016 的证据状态：已满足、部分、未满足、超范围。任何弱证据保持未完成，不得为了结束改写 AC。

**Step 4：最终验证**

```bash
cd codex-profile-switcher
python3 -m unittest -v
cd ../codex-workbench
./test.sh
swift build
./build-app.sh
./verify-install.sh
git diff --check
git status --short
```

另检查：初始账号已恢复、旧 App 仍安装且无进程、工作台安装进程身份匹配。

**Step 5：回流 Obsidian**

先读取 Vault 根 `AGENTS.md`，只记录“单一工作台入口、账号能力迁移、真实验收和冷备仍保留”的事实，不写完整对话、认证值或测试日志。

**Step 6：提交最终文档**

```bash
git add README.md codex-workbench/README.md codex-workbench/DESIGN.md codex-workbench/specs/profile-integration codex-workbench/docs
git commit -m "docs: close workbench profile integration"
```

完成本计划后只向用户展示迁移成果和证据，不删除旧 Profile Switcher。旧 App 的停止登录项、归档和卸载必须另开退役设计并再次取得批准。
