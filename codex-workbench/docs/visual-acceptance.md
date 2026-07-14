# Codex 工具台视觉与验收报告

验收日期：2026-07-14

验收对象：已安装的 `/Users/dysania/Applications/Codex 工具台.app`

视觉方向：Calm Operations Console

## 结论

**PASS，Visual Verdict：95 / 100。**

界面符合“成熟原生 Mac 工具”的目标：层级明确、信息密度稳定、浅深色语义一致，没有营销式大数字、渐变背景或彩虹卡片墙。最小、默认、宽屏三档未发现文字重叠、内容越界或根窗口横向滚动。

| 维度 | 得分 | 结论 |
|---|---:|---|
| 信息层级 | 20 / 20 | 概览、日志、账号三页主任务清楚；最近活动优先于次要说明。 |
| 布局与响应式 | 19 / 20 | 900×640、1160×780、1440×900 均稳定；宽屏 inspector 正常出现。 |
| 排版与密度 | 19 / 20 | 系统字体、monospaced 数值和 8pt 节奏统一；一屏可查看足够多的事件。 |
| 色彩与模式 | 19 / 20 | 浅深色均使用语义表面；成功、额度、选择状态同时有文字说明。 |
| 组件与细节 | 18 / 20 | 侧栏、筛选、时间轴、账号角色卡和菜单栏语言一致，交互反馈克制。 |

## 截图证据

- `overview-light-900x640.png`：严格最小窗口，实际窗口尺寸 900×640。
- `overview-light-1160x780.png`：默认浅色概览，账号和本地事件已加载。
- `activity-light-1440x900-selected.png`：浅色宽屏日志，选中 19:13 自动额度重置并显示 inspector。
- `activity-dark-1160x780.png`：深色默认宽度时间轴。
- `activity-dark-1440x900-reset-selected.png`：深色宽屏额度重置详情，含来源链、before/after 与证据。
- `accounts-light-1160x780.png`：真实账号角色、额度、重置卡和切换入口。
- `menubar-dark.png`：菜单栏状态、最近三条重要操作、打开工具台和切到 Codex。

截图目录：`/Users/dysania/.codex/visualizations/2026/07/14/019f6067-342c-7b22-a9fc-cd50ded08d86/codex-workbench/final/`

## 基础无障碍检查

| 检查项 | 结果 | 证据 |
|---|---|---|
| 不只依赖颜色 | PASS | 成功、确定、推断、当前账号等均有文字或图标标签。 |
| 表单控件标签 | PASS | AX 实测为“搜索操作日志 / 级别 / 来源 / 状态”。 |
| 工具栏按钮标签 | PASS | AX 实测为“切到 Codex / 刷新”，侧栏隐藏按钮也有系统标签。 |
| 键盘焦点 | PASS | 系统焦点可在侧栏与搜索框间移动；Picker 使用原生 SwiftUI 控件。 |
| 减少动态效果 | PASS | 日志展开在 `accessibilityReduceMotion` 开启时不执行动画。 |
| 浅深色可读性 | PASS | 使用系统 label、separator、controlBackground 语义色，关键文字对比清楚。 |

未执行完整 VoiceOver 语音走查；本轮完成了 AX 语义、标签和焦点的程序化检查，未发现阻断性缺失。

## AC 对照

| AC | 结果 | 主要证据 |
|---|---|---|
| AC-001 | PASS | 安装到用户 Applications，可直接打开，无需手动 Python 服务。 |
| AC-002 | PASS | 三个侧栏模块均可用，选中态明确。 |
| AC-003 | PASS | 日志倒序且按本地日期分组。 |
| AC-004 | PASS | 行与 inspector 显示时间、状态、来源、任务、置信度、变化和证据。 |
| AC-005 | PASS | 有效 UUID 构造本机确认过的 `codex://threads/<id>`，非法 ID 拒绝。 |
| AC-006 | PASS | 搜索及级别、来源、状态筛选已实现并有 Core 测试。 |
| AC-007 | PASS | 打包既有账号后端，真实额度与切换按钮见账号截图。 |
| AC-008 | PASS | 菜单栏已实际打开并截图；关闭主窗后仍可重新打开工具台。 |
| AC-009 | PASS | ledger 坏行容错、去重、补扫均有测试；UI 有降级提示。 |
| AC-010 | PASS | 三档截图尺寸准确，无重叠、裁切和根横向滚动。 |
| AC-011 | PASS | 浅色和深色截图均通过。 |
| AC-012 | PASS | ledger schema 只保存脱敏解释性事实；未加入 telemetry 或外部上报。 |
