# codexU 同构界面重构 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让主窗口和菜单弹窗在布局、密度、材质和信息层级上与 codexU v1.0.2 同构，同时保留 profile 切换并改用当前 app-server 重置卡数据。

**Architecture:** Python 状态层继续产出脱敏 JSON；重置卡详情并入现有 app-server RPC 结果。AppKit UI 使用一个固定 window surface、一个仅纵向滚动的 documentView 和固定 footer；所有区域宽度由 clipView 推导，不再依赖 1080 固定画布。

**Tech Stack:** Python 3 标准库、AppKit/Swift、`unittest`、本地 ChatGPT.app Codex app-server。

---

### Task 1: 锁定新版 app-server 数据契约

**Files:**
- Modify: `tests/test_dashboard.py`
- Modify: `codex_profile_dashboard.py`

1. 为 `rateLimitsByLimitId.codex`、`rateLimitResetCredits.credits`、title/description/expiry 和 usage summary 写失败测试。
2. 运行 `python3 -m unittest tests/test_dashboard.py`，确认因字段缺失而失败。
3. 让 `normalize_rate_limits` 选择 codex bucket，并从 app-server 结果生成脱敏 `reset_credit_details`。
4. 默认路径停止读取 auth 和私有 reset-credit HTTP endpoint；保留测试注入兼容面。
5. 重新运行 dashboard 测试。

### Task 2: 锁定窗口与滚动容器契约

**Files:**
- Modify: `tests/test_menubar_ui_source.py`
- Modify: `macos/CodexProfileMenuBar.swift`

1. 添加窗口 820x720、min/max、documentView 等宽、禁横向滚动/弹性、固定 footer 的源码测试。
2. 添加禁止 `drawPattern` 和彩色根渐变的测试，确认 RED。
3. 将主窗口改为 760-1180 宽、620-920 高；默认 820x720。
4. 将 documentView 宽度严格绑定 clipView，内容宽度由 viewport 推导并在 resize 后重建。
5. 使用不透明度稳定的系统 surface 覆盖 viewport，footer 固定在滚动区外。

### Task 3: 同构 codexU 主窗口首屏

**Files:**
- Modify: `tests/test_menubar_ui_source.py`
- Modify: `macos/CodexProfileMenuBar.swift`

1. 为 codexU overview 顺序和账号切换常驻入口写失败测试。
2. 实现双环 + reset summary、Today/7d/Lifetime 三卡、重置卡到期进度。
3. 将账号切换做成 header/overview 之间的紧凑 segmented strip。
4. tabs 使用短文本 + SF Symbols，并让内容区使用统一 section surface。
5. 运行源码测试和 Swift 编译。

### Task 4: 同构 codexU 菜单弹窗

**Files:**
- Modify: `tests/test_menubar_ui_source.py`
- Modify: `macos/CodexProfileMenuBar.swift`

1. 为 380px 宽、单 Runtime 卡、固定命令区、账号切换写失败测试。
2. 移除弹窗背景图案，改为系统 surface + 可读卡片。
3. 对齐 codexU 的 header、额度三列、来源说明和底部命令密度。
4. 保留刷新、面板、重启/接管、退出。

### Task 5: 边界与视觉验收

**Files:**
- Modify: `tests/test_menubar_ui_source.py`
- Create only if needed: `tests/fixtures/ui-boundary-payload.json`

1. 注入最长账号名、最大数字、0 和缺失值。
2. 编译并安装候选 App。
3. 在干净桌面截取菜单弹窗；主窗口分别截取 760x620、820x720、1180x920 的顶部和底部。
4. 检查子视图 frame、document/clip 宽度、scroller 和重叠；生成 codexU/current 并排图。
5. 按 Visual Verdict 复评；未到 95 则每轮只修 3 项。

### Task 6: 完整验证和提交

**Files:**
- Modify: `build-menubar-app.sh`（仅在发布候选通过后 bump）

1. 运行 `python3 -m unittest discover -s tests`。
2. 运行 `swiftc macos/CodexProfileMenuBar.swift -framework AppKit -o /tmp/codex-profile-switcher-check`。
3. 运行 build/install 脚本并检查已安装版本。
4. 运行 `git diff --check` 和 focused diff review。
5. 只有 Visual Verdict >= 95 且工作树范围正确时才提交；本轮不预先打 tag。
