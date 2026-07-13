# 重置卡提醒与布局修复 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 使用官方 app-server 精确到期时间，增加本地提醒和额度耗尽自动使用，并修复三处 Dashboard 排版。

**Architecture:** Python 继续作为 Codex app-server 适配层，在同一进程内读取重置卡并使用最早到期卡，Swift 只接收脱敏状态并负责通知调度、自动使用状态机和 AppKit 布局。自动使用由官方 `rateLimitReachedType` 门控，并以稳定指纹和 UUID 保证同一次逻辑尝试幂等。

**Tech Stack:** Python 3 标准库、Codex app-server JSON-RPC、Swift/AppKit、UserNotifications、unittest、源码级 AppKit 回归测试。

---

### Task 1: 锁定官方重置卡使用契约

**Files:**
- Modify: `tests/test_dashboard.py`
- Modify: `tests/test_codex_profile.py`
- Modify: `codex_profile_dashboard.py`
- Modify: `codex_profile.py`

1. 为最早到期卡选择、consume JSON-RPC、结果归一化和 CLI 参数写失败测试。
2. 运行定向测试，确认因函数和命令不存在而失败。
3. 实现 `consume_next_expiring_reset_credit`，opaque id 只留在 Python 进程内。
4. 增加 `consume-reset-credit <profile> --idempotency-key <uuid>` 命令并输出脱敏 JSON。
5. 运行定向测试转绿，不调用真实账号。

### Task 2: 增加提醒时间计划与自动使用状态机

**Files:**
- Modify: `tests/test_menubar_ui_source.py`
- Modify: `macos/CodexProfileMenuBar.swift`
- Modify: `build-menubar-app.sh`

1. 为工作日提醒规则、通知标识、UserNotifications 接入和耗尽门槛写失败测试。
2. 运行定向测试，确认 RED。
3. 实现纯 Swift `ResetCreditReminderPlan`，输出前一工作日、当天上午和提前一小时提醒时间。
4. 实现 `ResetCreditNotificationScheduler`，权限失败不得影响主流程。
5. 实现自动使用指纹、幂等键持久化和 outcome 处理；仅 `rateLimitReachedType` 非空时触发。
6. 在状态刷新成功后同步提醒和自动使用。
7. 为构建脚本增加 UserNotifications framework 并运行定向测试转绿。

### Task 3: 修复重置卡详情和概览层级

**Files:**
- Modify: `tests/test_menubar_ui_source.py`
- Modify: `macos/CodexProfileMenuBar.swift`

1. 为逐行时间、动态高度、无空格卡数和收敛字号写失败源码测试。
2. 运行测试确认 RED。
3. 把 `ResetCreditCompactStripView` 改为每张卡一行，显示精确北京时间和相对到期状态。
4. 调整 `PopoverQuotaColumnView` 字号、字重、间距，并统一 `3张` 文案。
5. 运行定向测试转绿。

### Task 4: 修复项目活动概览列对齐

**Files:**
- Modify: `tests/test_menubar_ui_source.py`
- Modify: `macos/CodexProfileMenuBar.swift`

1. 写失败测试，要求 title/value 使用稳定列宽并设置截断策略。
2. 运行测试确认 RED。
3. 修改 `ProjectActivityPanelView.metricRow` 的三列约束。
4. 运行定向测试转绿。

### Task 5: 发布和真实验收

**Files:**
- Modify: `build-menubar-app.sh`
- Modify: `verify-menubar-install.sh`（仅在需要新增运行文案门禁时）
- Modify: `README.md`

1. 更新 README 的官方数据源、提醒和自动使用边界。
2. 版本升级为 `0.10.0 (20)`。
3. 运行 `python3 -m unittest discover -s tests`。
4. 运行 `swiftc macos/CodexProfileMenuBar.swift -framework AppKit -framework UserNotifications -o /tmp/codex-profile-switcher-check`。
5. 运行 build/install、完全退出旧进程并启动新安装版。
6. 核对安装版本、进程时间、实时脱敏 profile 数据和通知权限状态。
7. 捕获弹窗、重置卡详情和项目排行真实截图，检查裁切、字号、间距和列对齐。
8. 不主动调用 consume 做测试；若生产状态已满足耗尽门槛，只记录实际 outcome 和刷新后状态。
9. focused diff review，提交独立 commit 并打 `v0.10.0` tag。
