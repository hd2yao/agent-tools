# Codex 观测站实现方案

## 推荐方案

新建独立原生 macOS App `Codex 工具台.app`。App 由一个常驻但轻量的状态层、一个窗口 Dashboard 和一个菜单栏入口组成。账号管理通过适配器调用构建时打包的 Profile Switcher 后端；跨任务日志使用独立的追加式 operation ledger，并由 reconciliation 层从现有本地证据补扫。

## 第一性原理评审

- 真实目标不是“多一个日志页面”，而是让用户在跨任务工作流中恢复因果关系和定位入口。
- 最小可用结果必须同时具备：独立 App、可解释时间轴、真实账号模块、可跳回任务；静态效果图不够。
- 不需要为此启动 localhost 服务，也不需要修改 Codex 本体；原生 App 可直接读取授权范围内的本地文件并打开 URL scheme。
- Profile Switcher 的账号逻辑可复用，但所有权方向必须是“工具台依赖账号模块”，不能反转。

## 架构和数据流

```text
Codex sessions / context cards / existing ledgers / UserDefaults
                         |
                         v
                 Evidence Reconciler
                         |
                         v
          ~/.codex/operation-ledger/events.jsonl
                         |
              LedgerRepository (Swift)
                 |                |
                 v                v
          Dashboard Store     Menu Bar Store
            /    |    \             |
        概览  操作日志  账号管理      快捷面板
                         |
                  AccountGateway
                         |
      bundled codex_profile.py + codex_profile_dashboard.py
```

### 模块边界

- `CodexWorkbenchCore`：事件模型、JSONL 读取、筛选、聚合、账号 payload 解码、进程/深链协议。
- `CodexWorkbenchApp`：SwiftUI scenes、设计系统、各页面、菜单栏、窗口与 Codex 联动。
- `AccountGateway`：唯一允许调用账号后端的适配器；UI 不直接拼装 Python 命令。
- `EvidenceReconciler`：只读扫描本地证据并生成可去重事件；不修改 Codex session。
- `OperationLedger`：跨模块的独立事实层，不放进 Profile Switcher 私有目录。

## 数据策略

- JSONL 采用追加写、单行容错和稳定事件 ID；同一证据补扫时通过确定性指纹去重。
- UI 内存中按 `occurred_at` 倒序，日期分组；默认只加载最近 30 天和上限 2,000 条。
- 文件变化使用轻量定时刷新，App 再次打开后执行补扫。
- 账号后端输出只解码显示所需字段；stderr 和异常转换为明确错误状态，不展示敏感内容。

## 设计方案

Design Lock 详见项目根目录 `DESIGN.md`。核心是“Calm Operations Console”：原生侧栏、连续内容表面、少量摘要卡、紧凑时间轴、语义色而非彩虹色、宽屏详情 inspector。

## 变更文件

- 新建 `codex-workbench/Package.swift`。
- 新建 `codex-workbench/Sources/CodexWorkbenchCore/`。
- 新建 `codex-workbench/Sources/CodexWorkbenchApp/`。
- 新建 `codex-workbench/Tests/CodexWorkbenchCoreTests/`。
- 新建 `codex-workbench/build-app.sh`、`install-app.sh`、`verify-install.sh`。
- 更新 `agent-tools/README.md` 增加上层工具台入口。
- V1 不修改现有 Profile Switcher 状态机；通过适配器复用其后端，并由补扫层读取历史证据。

## 测试和验证

- Core 单元测试：通过仓库内零依赖 Swift test harness 覆盖事件解码、坏行容错、倒序/分组、过滤、去重、账号 payload 解码、深链；本机工具链不提供 XCTest/Testing 模块。
- 构建测试：`swift test`、`./build-app.sh`、Info.plist/bundle/resource 验证。
- 行为测试：账号状态加载、打开 Codex、打开任务深链、空/错/加载状态。
- 视觉测试：最小 `900×640`、默认 `1160×780`、宽屏 `1440×900`；概览、日志、账号三页；浅色/深色各至少一轮。
- 可访问性：控件 label、键盘焦点、颜色非唯一状态表达、Reduce Motion。

## 风险和回滚

| 风险 | 缓解 | 回滚 |
|---|---|---|
| Profile Switcher payload 演进 | 解码字段可选、适配器隔离、契约测试 | 隐藏账号详情并保留独立 Profile Switcher 打开入口 |
| session 文件量大 | 增量扫描、时间窗与条数上限、后台队列 | 关闭自动补扫，仅读取 operation ledger |
| 推断被误认为事实 | 强制 certainty 与 evidence，文案区分 | 降级为 `unverified` 或不展示 |
| 自动显示窗口打扰用户 | 设置项默认可控，监听仅在工具台已运行时生效 | 关闭关联设置 |
| UI 材质导致可读性差 | 内容卡使用不透明语义表面，截图在干净背景复验 | 切换为系统 window background |

删除 `Codex 工具台.app` 和 `~/.codex/operation-ledger/` 即可完整回滚；不会改变 Codex session 和账号认证数据。

## V1.1 状态变化扩展

- 新增 `QuotaObservation` 差异分类器和持久化状态基线；先确认变化事实，再按 `resetsAt` 与本地重置证据解释原因。
- 当前桌面账号使用 app-server 稀疏通知近实时触发完整快照，所有账号 60 秒补扫；断线不阻塞现有 Dashboard。
- 新增 SQLite 线程目录与工作流文件指纹目录，为 context card、项目空间、对话接续、摘要和全局能力变更补充证据。
- 重要性扩展为 `关键 / 重要 / 常规 / 诊断`；连续使用变化允许进入诊断层，主时间轴保持重点明确。
- 产品改名为 `Codex 观测站`，bundle id 不变，安装脚本负责旧 App 名称迁移。

## 执行契约

### Intent Lock

- 本次只交付独立工具台 V1、跨任务操作日志、概览、账号模块和菜单栏入口。

### Scope Fence

- 范围内：新 App、新 ledger、现有本地证据读取、账号后端适配、构建安装和截图验收。
- 范围外：喝水提醒、Codex 注入、云同步、完整 tracing、重写 Profile Switcher 核心。

### Approved Behavior

- 必须把事实、推断、无法证实明确分开。
- 明确不改变现有 Profile Switcher 独立运行能力和账号认证文件内容。

### Design Constraints

- 架构：工具台是上层 shell；账号模块是依赖，不是宿主。
- 数据：追加写、脱敏、坏行容错、稳定去重。
- UI：原生 macOS，遵循 `DESIGN.md`，不得用营销 Dashboard 模板替代。
- 依赖：V1 不新增第三方 Swift package，不新增外部网络调用。

### Test Obligations

- 所有 Core 行为先写失败测试再实现。
- 每个验收标准必须由自动测试、构建验证或截图证据覆盖。
- 安装包截图前必须校验源码、二进制时间/hash 与进程启动时间。

### Review Gates

- 实现前：确认 spec/plan/tasks/Design Lock 一致。
- 实现中：每个可独立回滚批次通过最快测试并提交。
- 实现后：逐项对照 AC，做 focused diff 与视觉评分。

### Rewind Triggers

- 如果需要修改认证存储、Codex 私有协议或新增网络服务，回到 spec 并暂停。
- 如果真实 payload 无法支持账号页面，回到 plan 重新定义适配边界。
- 如果任一截图存在越界、裁切、错误“当前账号”语义，视为失败并返工。
