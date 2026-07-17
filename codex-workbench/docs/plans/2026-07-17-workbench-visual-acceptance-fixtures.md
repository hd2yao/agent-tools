# Codex 工作台受控视觉验收模式 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 给正式工作台二进制增加显式、隔离、可测试的视觉验收模式，补齐深色、暂存、错误和切换中截图而不触碰真实账号状态。

**Architecture:** Core 解析环境变量并生成脱敏展示快照；AppModel 在 fixture 模式跳过所有真实副作用，AppDelegate 只对当前进程设置外观。普通启动没有有效配置时继续走现有账号网关和台账路径。

**Tech Stack:** Swift 6、SwiftUI、AppKit、现有自定义 Core 测试 harness、macOS `NSAppearance`、正式 `.app` 构建与签名脚本。

---

### Task 1: 视觉验收配置与快照纯逻辑

**Files:**
- Create: `Sources/CodexWorkbenchCore/WorkbenchVisualAcceptance.swift`
- Create: `Tests/CodexWorkbenchCoreTests/WorkbenchVisualAcceptanceTests.swift`
- Modify: `Tests/CodexWorkbenchCoreTests/main.swift`

**Step 1: 写失败测试**

覆盖默认关闭、`stale/error/switching`、`dark/light`、未知值忽略，以及 fixture 快照不含认证内容。

**Step 2: 验证 RED**

Run: `./test.sh`

Expected: 编译失败，提示缺少 `WorkbenchVisualAcceptanceConfiguration`。

**Step 3: 最小实现**

实现：

```swift
public struct WorkbenchVisualAcceptanceConfiguration: Equatable, Sendable {
    public enum Fixture: String, Sendable { case stale, error, switching }
    public enum Appearance: String, Sendable { case dark, light }
    public let fixture: Fixture?
    public let appearance: Appearance?

    public static func parse(environment: [String: String]) -> Self
}
```

并提供纯值 `WorkbenchVisualAcceptanceSnapshot.make(for:)`。

**Step 4: 验证 GREEN**

Run: `./test.sh`

Expected: `PASS: CodexWorkbenchCoreTests`。

**Step 5: 提交**

```bash
git add Sources/CodexWorkbenchCore/WorkbenchVisualAcceptance.swift \
  Tests/CodexWorkbenchCoreTests/WorkbenchVisualAcceptanceTests.swift \
  Tests/CodexWorkbenchCoreTests/main.swift
git commit -m "test: define visual acceptance fixture contract"
```

### Task 2: App 副作用隔离与进程级外观

**Files:**
- Modify: `Sources/CodexWorkbenchApp/AppModel.swift`
- Modify: `Sources/CodexWorkbenchApp/WorkbenchAppDelegate.swift`
- Modify: `Sources/CodexWorkbenchApp/AccountsView.swift`
- Modify: `Sources/CodexWorkbenchApp/MenuBarView.swift`
- Modify: `Sources/CodexWorkbenchApp/CodexWorkbenchApp.swift`
- Modify: `Sources/CodexWorkbenchApp/WorkbenchShell.swift`

**Step 1: 扩展失败测试**

为 Core 快照增加三种状态、切换目标和 fixture 标识断言，先确认当前实现缺失。

**Step 2: 验证 RED**

Run: `./test.sh`

Expected: 新状态断言失败。

**Step 3: 最小接入**

- AppModel 初始化时读取配置；有 fixture 时应用快照。
- fixture 模式的 `bootstrap`、`refreshAll`、`switchProfile` 立即返回，不启动观察器或自动化。
- AppDelegate 只为当前进程设置 `.darkAqua` / `.aqua`。
- 账号页和菜单栏显示可见 fixture 标识。
- fixture 使用独立 window scene ID；`CODEX_WORKBENCH_VISUAL_SURFACE=menu` 只在 fixture 中复用同一 `MenuBarView` 生成菜单证据。

**Step 4: 验证 GREEN**

Run: `./test.sh && swift build`

Expected: Core 全通过，Swift build 无错误或警告。

**Step 5: 提交**

```bash
git add Sources/CodexWorkbenchApp/AppModel.swift \
  Sources/CodexWorkbenchApp/WorkbenchAppDelegate.swift \
  Sources/CodexWorkbenchApp/AccountsView.swift \
  Sources/CodexWorkbenchApp/MenuBarView.swift
git commit -m "feat: isolate visual acceptance states"
```

### Task 3: 正式安装包视觉与安全验收

**Files:**
- Modify: `specs/profile-integration/tasks.md`
- Modify: `docs/profile-integration-live-acceptance.md`
- Create: `screenshots/profile-integration/accounts-1160-dark.png`
- Create: `screenshots/profile-integration/menu-dark.png`
- Create: `screenshots/profile-integration/accounts-1160-stale.png`
- Create: `screenshots/profile-integration/accounts-1160-error.png`
- Create: `screenshots/profile-integration/accounts-1160-switching.png`

**Step 1: 完整验证并安装**

Run: `./test.sh && swift build && ./install-app.sh && ./verify-install.sh`

Expected: 全通过，安装包 commit/fingerprint 与当前源码一致。

**Step 2: 记录真实基线**

记录当前账号、重置卡数量、ledger 行数、App 偏好和旧 App 进程状态；不得输出敏感字段。

**Step 3: 逐状态启动同一安装二进制并截图**

显式设置环境变量启动，固定窗口为 `1160×780`；截图必须包含 fixture 标识。深色菜单栏和账号页使用当前进程 `.darkAqua`。

**Step 4: 清理并普通重启**

退出 fixture 进程，不持久化环境变量；普通启动后再次读取真实 Blackwell、ledger、重置卡、签名和进程。

**Step 5: Visual Verdict 与文档**

按 `DESIGN.md` 逐项评分；只有无裁切、状态可读、深色 token 一致且前后真实状态不变时，才勾选 T007/T008/T012/T013。

**Step 6: 提交**

```bash
git add specs/profile-integration/tasks.md \
  docs/profile-integration-live-acceptance.md \
  screenshots/profile-integration
git commit -m "docs: complete workbench migration acceptance"
```
