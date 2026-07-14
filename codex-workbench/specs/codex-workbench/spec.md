# Codex 工具台 Spec

## 背景和目标

当前 Codex 的账号切换、线程接续、上下文压缩、Hook、Skill、Plugin 和额度重置分散在不同任务与工具中。用户能够看到某个任务内的局部信息，但难以回答“刚才系统到底做了什么、由谁触发、发生在哪个任务、能否回到那里”。

本项目提供一个独立的原生 macOS App——“Codex 工具台”，把跨任务的关键运行事实收敛为可随时打开的 Dashboard。它是上层工具壳，不属于任何单一账号；`Codex Profile Switcher` 作为“账号管理”模块继续保持独立边界。

## 用户场景

1. 用户发现额度从 0% 可用变为 99% 可用、重置卡减少，希望确认是否发生了自动重置、发生时间、触发者和账号。
2. 用户在多个 Codex 任务之间切换，希望看到线程创建、接续、上下文压缩等跨任务事件并跳回对应任务。
3. 用户希望知道某次行为由 Agent、App、Plugin、Skill、Hook 还是 Automation 触发，并查看证据与置信度。
4. 用户希望从菜单栏快速查看 Codex 状态和最近重要事件，也能打开完整工具台或 Codex。

## 范围

### V1 模块

- 概览：Codex 运行状态、桌面默认账号、今日事件、需关注事件和最近活动。
- 操作日志：最新在上、按日期分组、可搜索筛选、可展开详情、可跳转任务。
- 账号管理：复用现有 Profile Switcher 的账号状态数据和切换能力，明确区分“最近任务推断账号”“桌面默认账号”“统计归因账号”。
- 菜单栏：Codex 状态、最近重要事件、打开 Codex、打开工具台。
- 启动关联：可选登录时启动工具台；工具台运行时检测 Codex 启动并显示主窗口。

### 日志事件分级

| 级别 | 默认展示 | 事件 | 原因 |
|---|---|---|---|
| P0 关键 | 是 | 重置卡消耗、额度重置、账号切换、登录状态变化、线程创建/接续/归档、上下文压缩、Hook/Automation 失败、配置或能力变更 | 会改变资源、身份、上下文或可恢复性 |
| P1 重要 | 是，可折叠 | Skill/Plugin/Hook/Automation 的开始与完成、Codex 启停、工具台数据源异常、任务跳转 | 有助于解释“谁做了什么” |
| P2 诊断 | 默认隐藏 | 后台同步、周期刷新、重试、缓存命中、扫描统计 | 排障有用但频率高 |
| 不记录 | 否 | 鼠标悬停、普通导航点击、流式 token、完整提示词/回复、密钥/Cookie/认证内容、每个底层工具调用参数 | 噪声高或涉及隐私 |

## 非目标

- 不把全局日志集成进 `Codex Profile Switcher`，也不让账号工具成为上层容器。
- 不在 V1 中合并喝水提醒等与 Codex 无关的工具。
- 不修改、注入或逆向控制 Codex App 内部 UI。
- 不承诺捕获 Codex 未公开且本地无证据的所有“内核操作”；无法证实时必须标为“推断”或“无法证实”。
- 不引入云端服务、analytics、telemetry 或新的外部网络上报。
- 不记录 secrets、token、Cookie、完整账号邮箱或认证文件内容。

## 事件数据契约

事件采用追加写入的 JSONL，默认目录为 `~/.codex/operation-ledger/`。V1 schema：

```json
{
  "schema_version": 1,
  "id": "evt_<uuid>",
  "occurred_at": "2026-07-14T19:13:00+08:00",
  "recorded_at": "2026-07-14T19:13:01+08:00",
  "category": "quota",
  "action": "reset_credit_consumed",
  "title": "已使用 1 次额度重置",
  "summary": "hd-master 的可用额度恢复为 100%",
  "status": "success",
  "importance": "critical",
  "certainty": "confirmed",
  "actor": {"type": "app", "id": "codex-profile-switcher", "label": "Profile Switcher"},
  "thread": {"id": null, "title": null, "relation": "active_at_time"},
  "project": {"name": "agent-tools", "path": "/redacted/agent-tools"},
  "account": {"profile": "hd-master"},
  "source_chain": [
    {"type": "app", "id": "codex-profile-switcher"},
    {"type": "state_machine", "id": "automatic-reset"}
  ],
  "before": {"remaining_percent": 0, "reset_credits": 2},
  "after": {"remaining_percent": 100, "reset_credits": 1},
  "evidence": [{"kind": "user_defaults", "label": "automatic-reset outcome"}]
}
```

### 字段语义

- `occurred_at` 是实际发生时间；`recorded_at` 是写入台账时间，允许补录。
- `certainty` 只能是 `confirmed`、`inferred`、`unverified`。
- `thread.relation` 只能是 `triggered_by`、`source`、`target`、`active_at_time`、`unrelated`。
- `actor.type` 支持 `user`、`agent`、`app`、`plugin`、`skill`、`hook`、`automation`、`system`。
- `before`、`after` 和 `evidence` 只保留脱敏后的解释性事实，不保留原始认证数据。

## 验收标准

- **AC-001**：安装后可从 Finder/Spotlight 正常打开“Codex 工具台.app”，无需手动运行 Python 服务。
- **AC-002**：主窗口至少包含“概览 / 操作日志 / 账号管理”三个可用模块，侧栏选中状态明确。
- **AC-003**：操作日志默认按 `occurred_at` 倒序，最新事件位于最上方，并按日期分组。
- **AC-004**：日志行显示动作、时间、状态、来源主体、任务关系和置信度；点击后可查看 before/after、来源链和证据。
- **AC-005**：带有效任务 ID 的事件可通过 `codex://threads/<id>` 回到对应 Codex 任务。
- **AC-006**：搜索和筛选至少支持事件级别、来源类型、状态、任务/标题文本。
- **AC-007**：账号管理展示真实账号状态与额度；账号切换复用 Profile Switcher 的既有业务路径，不读取或展示认证内容。
- **AC-008**：菜单栏可显示 Codex 运行状态和最近重要事件，并提供“打开 Codex / 打开工具台”。
- **AC-009**：日志读取支持 App 关闭后的补扫；坏行不阻塞其他事件加载，并显示数据源降级提示。
- **AC-010**：最小、默认、宽屏三档无重叠、裁切和非预期横向滚动；长中文/英文混排可截断或换行。
- **AC-011**：浅色和深色模式均保持语义颜色、可读对比和原生窗口层级。
- **AC-012**：不得写入 secrets、token、Cookie、认证文件内容或完整请求/响应正文。

## 约束和假设

- 目标平台为 macOS 13+，使用 SwiftUI + AppKit；本机 Swift 工具链可直接构建 `.app`。
- Codex bundle id 为 `com.openai.codex`；任务深链使用本机已验证的 `codex://threads/<id>`。
- 账号模块 V1 在构建时打包 Profile Switcher 当前 Python 后端；源代码仍由账号模块维护，后续再抽取共享 Profile Core。
- V1 允许从现有 session JSONL、context card、UserDefaults 和已有 ledgers 补录事件；补录必须标明证据和置信度。
- 事件展示是“可解释事实台账”，不是逐指令 tracing 系统。

## 待确认问题

无阻断问题。登录时启动、Codex 启动时自动显示工具台默认提供可关闭设置，不强制开启。
