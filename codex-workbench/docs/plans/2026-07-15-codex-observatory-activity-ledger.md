# Codex Observatory Activity Ledger Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 Codex 工具台升级为 Codex 观测站，近实时记录额度、项目空间、对话接续、摘要、错误与全局工作流的可解释状态变化。

**Architecture:** 保留追加式 operation ledger，新增持久化状态基线与纯 Core 差异分类器。App 对当前桌面账号维持 app-server 通知监听，同时以 60 秒快照和启动/唤醒补扫兜底；SQLite、摘要文件和受控工作流文件只读生成稳定事件。SwiftUI 时间轴用 scope chips 与重要性层级呈现，不改变现有三模块 shell。

**Tech Stack:** Swift 6、SwiftUI、AppKit、Foundation `Process`、SQLite CLI 只读适配、Codex app-server JSON-RPC、JSONL、shell app packaging。

---

### Task 1: 锁定 V1.1 事件契约

**Files:**
- Modify: `specs/codex-workbench/spec.md`
- Modify: `specs/codex-workbench/plan.md`
- Modify: `specs/codex-workbench/tasks.md`
- Modify: `DESIGN.md`

**Steps:**
1. 写入命名、事件覆盖、额度判定窗口、重要性和不记录边界。
2. 对照 AC 为后续每个任务分配验证方式。
3. 运行 `git diff --check`，确认文档无格式错误。
4. 提交 `docs: lock observatory ledger v1.1 design`。

### Task 2: 额度快照差异分类

**Files:**
- Create: `Sources/CodexWorkbenchCore/QuotaObservation.swift`
- Create: `Tests/CodexWorkbenchCoreTests/QuotaObservationTests.swift`
- Modify: `Tests/CodexWorkbenchCoreTests/main.swift`

**Steps:**
1. 先写失败测试：正常刷新、官方恢复、本地消费、次数增减、额度下降、相同状态无事件。
2. 运行 `./test.sh`，确认因缺少 `QuotaObservation`/分类器而失败。
3. 实现脱敏 observation、状态指纹和事件工厂。
4. 再运行 `./test.sh`，确认新增测试和全部 Core 测试通过。
5. 提交 `feat: classify official quota state changes`。

### Task 3: 线程、项目与工作流证据目录

**Files:**
- Create: `Sources/CodexWorkbenchCore/CodexMetadataCatalog.swift`
- Create: `Sources/CodexWorkbenchCore/WorkflowEvidence.swift`
- Modify: `Sources/CodexWorkbenchCore/EvidenceSources.swift`
- Modify: `Sources/CodexWorkbenchCore/EvidenceReconciler.swift`
- Create: `Tests/CodexWorkbenchCoreTests/CodexMetadataCatalogTests.swift`
- Create: `Tests/CodexWorkbenchCoreTests/WorkflowEvidenceTests.swift`
- Modify: `Tests/CodexWorkbenchCoreTests/main.swift`

**Steps:**
1. 先写失败测试：线程标题解析、项目 scope、新项目基线/增量、结构化续接、digest、Skill/Hook/规则文件变更。
2. 运行 `./test.sh`，确认测试因 API 不存在而失败。
3. 实现只读元数据与指纹状态，不保存提示词和文件正文。
4. 让 context card 和 lifecycle 事件补全真实项目/对话名称，并过滤普通新建对话事件。
5. 运行 Core 测试与本机 dry-run，确认稳定 ID、无历史基线洪泛和无敏感正文。
6. 提交 `feat: collect project and workflow evidence`。

### Task 4: 官方通知监听与 60 秒补扫

**Files:**
- Create: `Sources/CodexWorkbenchCore/AppServerNotification.swift`
- Create: `Tests/CodexWorkbenchCoreTests/AppServerNotificationTests.swift`
- Create: `Sources/CodexWorkbenchApp/OfficialRateLimitObserver.swift`
- Modify: `Sources/CodexWorkbenchCore/AccountModels.swift`
- Modify: `Sources/CodexWorkbenchApp/AppModel.swift`

**Steps:**
1. 先写失败测试，锁定 `account/rateLimits/updated` 识别和其他通知忽略。
2. 运行 `./test.sh` 确认 RED。
3. 实现当前桌面 profile 的 app-server 常驻连接；收到稀疏通知后触发完整账号刷新。
4. 增加 60 秒补扫、启动/唤醒立即刷新、状态基线持久化和事件追加。
5. 模拟通知与断线，验证不会重复写相同快照。
6. 提交 `feat: observe official rate limit updates`。

### Task 5: 时间轴信息层级与产品命名

**Files:**
- Modify: `Sources/CodexWorkbenchCore/OperationEvent.swift`
- Modify: `Sources/CodexWorkbenchCore/ActivityFilter.swift`
- Modify: `Sources/CodexWorkbenchApp/DesignSystem.swift`
- Modify: `Sources/CodexWorkbenchApp/ActivityView.swift`
- Modify: `Sources/CodexWorkbenchApp/WorkbenchShell.swift`
- Modify: `Sources/CodexWorkbenchApp/CodexWorkbenchApp.swift`
- Modify: `Sources/CodexWorkbenchApp/MenuBarView.swift`
- Modify: `Resources/Info.plist`
- Modify: `README.md`

**Steps:**
1. 先写/更新契约测试，要求 `routine` 重要性可解码和筛选。
2. 实现项目、对话、账号/全局 scope chips，行内必须首屏可见。
3. 将 `确定` 改为 `已核实`，关系值本地化，Inspector 先显示对话名称再显示 ID。
4. 用节点尺寸、强调线、文字标签表达重要性，保持 Design Lock 的克制色彩。
5. 全局文案改为 `Codex 观测站`。
6. 运行测试和 release build 后提交 `feat: refine observatory activity timeline`。

### Task 6: App 图标与安装迁移

**Files:**
- Create: `Resources/AppIcon-1024.png`
- Modify: `Resources/Info.plist`
- Modify: `build-app.sh`
- Modify: `install-app.sh`
- Modify: `verify-install.sh`

**Steps:**
1. 按批准的时间轴 `C` + 三节点方向生成 1024×1024 图标并保存到项目。
2. 构建时生成标准 `.iconset`/`.icns`，写入 `CFBundleIconFile`。
3. 安装脚本以事务方式把旧 `Codex 工具台.app` 迁移为 `Codex 观测站.app`，失败时恢复旧包。
4. 验证 Spotlight/Finder 名称、Dock 图标、bundle id 和 codesign。
5. 提交 `feat: brand app as Codex Observatory`。

### Task 7: 真实数据与视觉验收

**Files:**
- Modify: `docs/visual-acceptance.md`
- Modify: `specs/codex-workbench/tasks.md`

**Steps:**
1. 运行 `./test.sh && ./build-app.sh && ./install-app.sh && ./verify-install.sh`。
2. 完全退出旧进程，记录源码 fingerprint、安装路径、二进制 hash、PID 和启动时间。
3. 回放真实数据，确认正常刷新/官方恢复/项目/对话/规则事件的字段与排序。
4. 截取 `900×640`、`1160×780`、`1440×900`，覆盖浅色、深色、selected inspector 和长标题。
5. 执行可访问性基础检查与 Visual Verdict；低于 90 或存在裁切直接返工。
6. 更新 AC 收敛结果并提交 `docs: record observatory v1.1 acceptance`。

### Task 8: 长期记录回流

**Files:**
- Modify: `/Users/dysania/program/documents/obsidian_vault/03_Resources/Codex工作台/Codex 变更日志.md`

**Steps:**
1. 读取 Vault 根 `AGENTS.md` 和 `obsidian-memory-workflow`。
2. 记录产品改名、事件覆盖、额度判定、验证与安装路径。
3. 本轮没有创建或修改 Skill，不更新 Skills 搜索索引。

