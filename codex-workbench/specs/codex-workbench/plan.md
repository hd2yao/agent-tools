# Codex 观测站实现方案

## 推荐方案

新建独立原生 macOS App `Codex 观测站.app`。App 由一个常驻但轻量的状态层、一个窗口 Dashboard 和一个菜单栏入口组成。账号管理通过适配器调用构建时打包的 Profile Switcher 后端；跨任务日志使用独立的追加式 operation ledger，并由 reconciliation 层从现有本地证据补扫。

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

删除 `Codex 观测站.app` 和 `~/.codex/operation-ledger/` 即可完整回滚；不会改变 Codex session 和账号认证数据。

## V1.1 状态变化扩展

- 新增 `QuotaObservation` 差异分类器和持久化状态基线；先确认变化事实，再按 `resetsAt` 与本地重置证据解释原因。
- 当前桌面账号使用 app-server 稀疏通知近实时触发完整快照，所有账号 60 秒补扫；断线不阻塞现有 Dashboard。
- 新增 SQLite 线程目录与工作流文件指纹目录，为 context card、项目空间、对话接续、摘要和全局能力变更补充证据。
- 重要性扩展为 `关键 / 重要 / 常规 / 诊断`；普通额度消耗和单独的刷新时间变化只更新基线，不进入时间轴。
- 产品改名为 `Codex 观测站`，bundle id 不变，安装脚本负责旧 App 名称迁移。

## V1.2 工作流变更解释方案

- `WorkflowFileFingerprint` 增加可选的脱敏语义快照；旧观察状态仍可解码，新状态不保存完整 prompt。
- Automation 快照解析 `name / status / rrule / target_thread_id`，并从 prompt 派生稳定的能力标签；新旧快照差异生成 `EventChange`。
- `OperationEvent` 增加可选的 `scope / changes / related_threads`，兼容现有 schema；`thread` 保留主要定位，`related_threads` 明确角色。
- 新增本地 Session 证据关联器：只扫描事件时间附近的 rollout 结构化工具调用，提取 Automation ID、来源线程和目标线程，不保存调用原文。
- 新增追加式事件 revision：相同事件 ID 以更新的 `recorded_at` 追加增强版本，Repository 继续选择最新版本；不原地破坏历史 JSONL。
- 时间轴行优先显示可读摘要与“全局工作流 / 来源对话”标签；详情顺序调整为“本次改动 -> 归属 -> 来源 -> 技术状态 -> 证据”。

### V1.2 第一性原理评审

- 真实目标是让用户恢复因果关系，不是展示文件监视器内部实现。
- 最小可用结果必须同时包含改动内容、修改来源和运行目标；只有其中一项仍不足以解释事件。
- 直接保存完整 prompt 虽然最容易做 diff，但违反隐私与低噪声边界；稳定能力标签和结构化字段差异足以覆盖本轮需求。

### V1.2 风险与回滚

| 风险 | 缓解 | 回滚 |
|---|---|---|
| Session 关联误配 | 时间窗口 + Automation ID + 结构化工具名三重约束；无法唯一匹配则不关联 | 停用 Session 回填，仅保留文件语义差异 |
| 旧观察状态不兼容 | 新字段全部可选，fixture 覆盖旧 JSON 解码 | 删除新可选字段，继续读取 fingerprint |
| 能力摘要误导 | 只使用显式命令/关键词映射；无法识别时显示降级文案 | 仅显示字段变化和文件路径 |
| revision 重复增长 | 追加前比较可见语义、关联关系与证据；完全等价时不生成新 revision | 停用 revision 写入，内存展示不落盘 |

## V1.3 工作流语义说明方案

- 把 `WorkflowSemanticSnapshot` 扩展为跨类型安全快照：保留 Automation 结构字段，并增加 `purpose`、公开 `interfaces` 与稳定 `capabilities`。
- 为 Skill front matter / Markdown 标题和 Hook Python 模块说明 / 入口标记建立确定性解析；只输出有限中文标签，不持久化源文件正文。
- 差异生成分三档：完整前后快照生成精确变化；新增文件生成用途与主要能力；旧快照缺失时生成“更新后职责”并附证据不足说明。
- 扩展历史 revision：Automation 支持变量式更新调用；Skill/Hook 通用历史事件从当前安全快照生成诚实降级说明。所有 revision 保留稳定事件 ID 并幂等追加。
- UI 继续复用现有时间轴和 inspector，不改变 Design Lock；fingerprint 只留在“技术状态”，语义说明固定置于“本次改动”。

### V1.3 风险与回滚

| 风险 | 缓解 | 回滚 |
|---|---|---|
| 标签分类过度概括 | 只匹配显式标题、入口或稳定 marker；无匹配时使用用途/当前职责 | 退回用途说明，不输出能力差异 |
| 历史旧版本缺失 | 明示“更新后职责”，不把当前状态写成新增 | 关闭历史降级回填，只影响旧事件 |
| 变量式调用误配 | 时间窗 + 更新工具名 + Automation ID 字面量或已读取配置引用 | 保持不关联并显示未定位来源 |
| 快照泄露源码 | 编码测试断言正文 marker 不进入 ledger/state | 删除扩展字段并重建观察基线 |

### V1.3 实施结果

- Skill、Hook 与 Automation 已统一生成脱敏语义快照；列表摘要优先显示能力变化，详情保留用途和模块差异。
- 历史 Skill/Hook 先用 after fingerprint 匹配本地 Git blob 并恢复真实父版本；只有无精确版本时才显示“更新后职责 / 证据边界”。
- 变量式 Automation 更新已覆盖 `cfg.id`、内联 `.replace` 与命名替换块，真实 11:18、11:19 事件完成幂等回填。
- 最终安装包 commit 为 `20d4f56`；最小与宽屏截图位于 `screenshots/v1.3/`，事件按钮 AX 树具备按钮角色、可读摘要值和详情提示。

## V1.4 压缩摘要与全类型解释方案

- `ContextCardEvidence` 解析 context card 的“当前主题 / 最近用户请求 / 最近助手进展”，过滤系统注入项并生成受限长度的结构化摘要；`ContextCardEventFactory` 将其写为事件变化项。
- 新增上下文历史增强器，以同一事件 ID 追加 revision，使已有“摘要卡片已生成”事件无需重新压缩即可显示实际保留内容。
- `WorkflowSemanticSnapshot` 增加安全声明集合：全局规则保留顶层规则，配置只保留允许公开的设置，Plugin 保留名称、说明和公开声明；不保存文件全文。
- 新增结构化 patch 证据收集器：按事件时间、目标文件和唯一 rollout 三重约束读取增删行，输出规则/设置/能力/函数级变化，并关联修改来源对话。
- `WorkflowEventHistoryEnricher` 的支持范围扩展到 rule/configuration/plugin；只有具体变化才可替换通用文案，精确 Git 证据仍优先于当前快照降级。
- UI 保持 Design Lock；上下文事件将“本次改动”改名为“压缩后摘要”，证据区提供打开完整摘要卡片的原生按钮。

### V1.4 风险与回滚

| 风险 | 缓解 | 回滚 |
|---|---|---|
| 摘要预览泄露完整对话 | 只读 context card 已归纳区；过滤内部注入；单项截断；隐私测试检查 marker | 停用预览字段，保留卡片路径 |
| patch 关联到错误对话 | 事件时间窗 + 目标文件路径/类型 + 唯一匹配；多候选不关联 | 停用 patch 回填，保留语义快照差异 |
| 规则快照过大或包含敏感值 | 只保存顶层规则与安全设置，限制条数/长度并过滤赋值型敏感字段 | 退回章节/能力标签快照 |
| 通用事件反复追加 revision | 可见语义与证据完全等价时不追加 | 停用历史增强写入，仅内存显示 |

### V1.4 实施结果

- 上下文压缩事件从 context card 提取最近有效用户要求与至多两条压缩前进展；系统注入内容被过滤，列表和详情不再只显示“摘要卡片已生成”。
- 全局规则、Codex 配置、Plugin、Skill、Hook 与 Automation 均生成安全语义变化；`hooks.json` 会显示 `SessionStart / PreCompact` 对应的具体 Hook 命令。
- 结构化 patch 支持重复重试的语义合并：完全相同的重复调用视为同一份证据，不同改动仍拒绝猜测；历史事件继续以相同 ID 追加 revision。
- rollout 证据读取限制为单文件尾部 8 MiB、单轮复用并只保留 Automation/patch/旧配置证据行；正式 App 刷新后的稳定 RSS 由约 846 MiB 降至约 277 MiB。
- 真实台账收敛检查中，受控工作流最新事件命中“内容已调整 / 实现内容已调整 / 无说明已新增 / 全局工作流定义已更新”为 0；上下文压缩最新事件缺少摘要明细为 0。
- 安装产物的定向截图位于 `screenshots/v1.4/context-summary-wide.png` 与 `screenshots/v1.4/workflow-rule-wide.png`。

## 执行契约

### Intent Lock

- 本次只交付独立工具台 V1、跨任务操作日志、概览、账号模块和菜单栏入口。

### Scope Fence

- 范围内：新 App、新 ledger、现有本地证据读取、账号后端适配、构建安装和截图验收。
- 范围外：喝水提醒、Codex 注入、云同步、完整 tracing、重写 Profile Switcher 核心。

### Approved Behavior

- 必须把事实、推断、无法证实明确分开。
- 明确不改变现有 Profile Switcher 独立运行能力和账号认证文件内容。
- V1.2 不记录完整 Automation prompt 或完整 Session 内容，只记录脱敏结构化差异和线程定位元数据。

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
- 如果来源对话只能依赖标题相似或宽泛时间猜测，停止关联并降级为“未定位”，不得写成已核实。
