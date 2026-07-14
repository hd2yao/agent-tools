# Codex 工具台 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建一个独立、可安装、无需手动启动服务的原生 macOS Codex 工具台，提供概览、跨任务操作日志、账号管理和菜单栏入口。

**Architecture:** Swift Package 将纯模型与本地数据访问放在 `CodexWorkbenchCore`，将 SwiftUI/AppKit scene 放在 `CodexWorkbenchApp`。App 读取独立 JSONL operation ledger，通过只读 reconciler 补扫本地证据，并通过隔离的 `AccountGateway` 调用打包的 Profile Switcher Python 后端。

**Tech Stack:** Swift 6、SwiftUI、AppKit、Foundation、ServiceManagement、Python 3（仅打包既有账号后端）、仓库内零依赖 Swift 测试 harness（本机工具链不提供 XCTest/Testing 模块）。

---

### Task 1: 建立可测试、可封装的 Swift 工程

**Files:**
- Create: `codex-workbench/Package.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchCore/AppContracts.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/CodexWorkbenchApp.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/AppContractsTests.swift`
- Create: `codex-workbench/test.sh`
- Create: `codex-workbench/build-app.sh`

**Step 1: 写失败测试**

测试 `AppModule` 固定包含 `overview/activity/accounts`，中文标题和 SF Symbol 非空。

**Step 2: 运行测试并确认失败**

Run: `cd codex-workbench && ./test.sh`

Expected: FAIL，目标类型尚不存在。

**Step 3: 最小实现**

添加 package、Core enum 和最小 SwiftUI `@main`，主窗口设置 `900×640` 最小、`1160×780` 默认。

**Step 4: 运行测试并构建**

Run: `cd codex-workbench && ./test.sh && swift build`

Expected: PASS，debug executable 构建成功。

**Step 5: 添加 `.app` 构建脚本并验证 plist**

Run: `cd codex-workbench && ./build-app.sh && plutil -lint 'build/Codex 工具台.app/Contents/Info.plist'`

Expected: `OK`。

**Step 6: Commit**

```bash
git add codex-workbench
git commit -m "feat: scaffold native Codex workbench"
```

### Task 2: 实现事件 schema、读取、排序与筛选

**Files:**
- Create: `codex-workbench/Sources/CodexWorkbenchCore/OperationEvent.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchCore/LedgerRepository.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchCore/ActivityFilter.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/LedgerRepositoryTests.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/ActivityFilterTests.swift`

**Step 1: 写事件解码失败测试**

覆盖 snake_case、可选任务/账号、certainty、before/after 和 evidence。

**Step 2: 确认失败**

Run: `./test.sh`

Expected: FAIL，事件模型不存在。

**Step 3: 最小实现并转绿**

实现 Codable 模型和单行 JSON 解码。

**Step 4: 写坏行容错、去重、倒序和 2,000 条上限失败测试**

Expected: 首轮 FAIL。

**Step 5: 实现 repository 并转绿**

坏行记录 warning，不阻塞有效行；`id` 去重，`occurred_at` 倒序。

**Step 6: 写并实现筛选测试**

覆盖 query、importance、actor、status 和 thread 文本。

**Step 7: Commit**

```bash
git add codex-workbench/Sources/CodexWorkbenchCore codex-workbench/Tests
git commit -m "feat: add operation ledger core"
```

### Task 3: 实现本地证据补扫与历史重置事件

**Files:**
- Create: `codex-workbench/Sources/CodexWorkbenchCore/EvidenceReconciler.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchCore/EvidenceSources.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/EvidenceReconcilerTests.swift`

**Step 1: 写确定性事件 ID 测试**

相同 evidence key 重复扫描必须生成同一 ID。

**Step 2: 确认失败并最小实现**

Run: `./test.sh`

**Step 3: 写 context card / reset outcome fixture 测试**

断言事件 category、actor、certainty、occurredAt、before/after 不泄露原始敏感字段。

**Step 4: 实现只读 sources 和 reconciliation**

扫描失败降级为 warning；不修改来源文件。

**Step 5: 在本机执行 dry-run**

只输出事件计数、分类和脱敏标题，不打印原始 session 文本。

**Step 6: Commit**

```bash
git add codex-workbench/Sources/CodexWorkbenchCore codex-workbench/Tests
git commit -m "feat: reconcile Codex activity evidence"
```

### Task 4: 实现账号数据适配与切换命令契约

**Files:**
- Create: `codex-workbench/Sources/CodexWorkbenchCore/AccountModels.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchCore/AccountGateway.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/AccountGatewayTests.swift`
- Modify: `codex-workbench/build-app.sh`

**Step 1: 写最小 payload 解码失败测试**

覆盖 `active_profile`、`desktop_status`、`profile_roles`、profiles、primary/secondary limit 和 reset credits。

**Step 2: 确认失败并实现 Codable 模型**

Run: `./test.sh`

**Step 3: 写命令构造失败测试**

状态读取只能是 `status --json`；切换只能是 `app <safe-profile>`；拒绝不安全 profile 名。

**Step 4: 实现 gateway 并转绿**

Process 在后台执行；stdout 解码；stderr 脱敏后转为局部错误。

**Step 5: 构建时打包账号后端**

复制 sibling source 到 app Resources，保持单一源代码所有权。

**Step 6: Commit**

```bash
git add codex-workbench
git commit -m "feat: integrate account management adapter"
```

### Task 5: 实现 App Shell 与 Design System

**Files:**
- Create: `codex-workbench/Sources/CodexWorkbenchApp/DesignSystem.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/AppModel.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/WorkbenchShell.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/Components/StatusChip.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/Components/SurfaceCard.swift`

**Step 1: 添加可测试的布局常量断言**

在 Core contract 中断言 min/default/sidebar/spacing 符合 `DESIGN.md`。

**Step 2: 确认失败并实现 token**

所有颜色使用 semantic roles，间距只用 4/8/12/16/24/32。

**Step 3: 实现 NavigationSplitView shell**

侧栏模块分组、统一单色 SF Symbols、toolbar Codex 状态和打开动作。

**Step 4: 构建并手动缩放窗口**

Expected: 最小尺寸无横向滚动，侧栏可隐藏。

**Step 5: Commit**

```bash
git add codex-workbench/Sources codex-workbench/Tests
git commit -m "feat: build Codex workbench shell"
```

### Task 6: 实现概览、操作日志和账号管理页面

**Files:**
- Create: `codex-workbench/Sources/CodexWorkbenchApp/Overview/OverviewView.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/Activity/ActivityView.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/Activity/ActivityRow.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/Activity/ActivityInspector.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/Accounts/AccountsView.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/Accounts/AccountCard.swift`

**Step 1: 先实现 loading/empty/error fixture 状态**

确保布局稳定，再接真实 store。

**Step 2: 实现概览信息层级**

四个紧凑状态块 + 最近活动 + 数据源健康，不使用大 KPI。

**Step 3: 实现日志筛选、日期分组和选择**

默认最新在上；宽屏 inspector，窄屏页内详情。

**Step 4: 实现账号角色与 profile 列表**

事实/推断明确区分，切换按钮写明会重启 Codex。

**Step 5: 运行测试和 debug build**

Run: `./test.sh && swift build`

**Step 6: Commit**

```bash
git add codex-workbench/Sources
git commit -m "feat: add workbench dashboard modules"
```

### Task 7: 实现菜单栏、Codex 联动和任务深链

**Files:**
- Create: `codex-workbench/Sources/CodexWorkbenchApp/MenuBar/MenuBarView.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchCore/CodexIntegration.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/CodexIntegrationTests.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/CodexWorkbenchApp.swift`

**Step 1: 写 URL 和 bundle id 失败测试**

有效 UUID 生成 `codex://threads/<id>`；非法 ID 返回 nil。

**Step 2: 实现并转绿**

使用 `NSWorkspace` 打开 Codex 和任务 URL。

**Step 3: 添加 MenuBarExtra**

显示状态、最近三条重要事件和两个主操作。

**Step 4: 添加可选启动关联**

监听 `didLaunchApplicationNotification`；设置项关闭时不得自动显示窗口。

**Step 5: Commit**

```bash
git add codex-workbench/Sources codex-workbench/Tests
git commit -m "feat: add menu bar and Codex integration"
```

### Task 8: 安装、视觉验收、文档和收敛

**Files:**
- Create: `codex-workbench/install-app.sh`
- Create: `codex-workbench/verify-install.sh`
- Create: `codex-workbench/README.md`
- Create: `codex-workbench/docs/visual-acceptance.md`
- Modify: `README.md`
- Modify: `codex-workbench/specs/codex-workbench/tasks.md`

**Step 1: 全量验证**

Run: `./test.sh && ./build-app.sh && ./verify-install.sh`

Expected: 全部通过且无 warning/error。

**Step 2: focused diff review**

Run: `git diff --check && git status --short && git diff --stat`

确认没有认证数据、绝对个人账号内容和无关文件。

**Step 3: 安装并记录产物身份**

记录 commit、构建时间、app 路径、binary SHA-256、PID/启动时间。

**Step 4: 截图验收**

按 `DESIGN.md` 生成最小/默认/宽屏、浅色/深色和菜单栏截图，检查长文本、空值、错误状态。

**Step 5: 视觉与 AC 收敛**

在 `docs/visual-acceptance.md` 记录 Visual Verdict 和 AC-001 至 AC-012 的证据；低于 90 分或硬失败必须修复后重测。

**Step 6: 更新文档与任务勾选**

说明日志分级、数据目录、隐私边界、构建安装和账号模块关系。

**Step 7: Commit**

```bash
git add README.md codex-workbench
git commit -m "docs: ship Codex workbench app"
```
