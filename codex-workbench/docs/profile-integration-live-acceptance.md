# Codex 工作台账号整合真实验收记录

记录时间：2026-07-17（Asia/Shanghai）

## 当前结论

工作台已完成账号后端、菜单栏、账号管理、项目分析、工具 / Skill、登录辅助和账号操作日志的整合，并通过真实安装读取两个账号。当前仍为迁移验收阶段：旧 Profile Switcher 冷备保留且不运行；真实双向切换因为本次 Codex 任务正在运行、桌面端无法在安全时限内退出而尚未完成，因此 T012 和最终退役门禁不得标记为通过。

## 安装身份

- 工作台：`/Users/dysania/Applications/Codex 观测站.app`
- Bundle ID：`com.hd2yao.codex-workbench`
- 版本：`0.2.0`
- 源码提交：`bf4181e`
- 账号后端指纹：`35e6b086f32fd6e97791e658b1662d8e0daca2517322aef1644dccd0656d67c5`
- verifier：通过；内置 Login Helper 与账号后端 freshness 测试通过。
- 最终门禁曾发现一次人工状态检查漏带 `PYTHONDONTWRITEBYTECODE=1`，在已签名包内生成 `.pyc` 并使验签失败；已用原子安装器重装，确认包内无 `__pycache__`、codesign 再次通过。工作台正常网关本身始终会设置该环境变量。
- 冷备：`/Users/dysania/Applications/Codex Profile Switcher.app`，`com.hd2yao.codex-profile-switcher`，`0.10.1`；仍安装，验收时未运行。

## 真实账号快照

本次快照只记录展示所需的脱敏字段，不包含认证数据、token、Cookie 或重置卡原始 ID。

- 当前真实登录账号：`hd-sarah-blackwell`；桌面状态为托管；Codex 状态为“运行中”。
- `hd-master`：Plus，官方首要窗口 `10080` 分钟（7 日），采样时剩余 `53%`，第二窗口缺失，2 张可用重置卡。
- `hd-sarah-blackwell`：Plus，官方首要窗口 `10080` 分钟（7 日），采样时剩余 `53%`，第二窗口缺失，1 张可用重置卡。
- UI 按官方 `window_minutes` 显示“7 日额度”，第二窗口缺失时显示“其他额度 —”；不会用“桌面默认账号”或任务归因替代当前登录账号。

额度会随官方状态刷新变化，截图中的百分比与本段采样值不要求恒定。

## 账号切换验收

已从工作台发起一次 `hd-sarah-blackwell → hd-master`。既有 Python 后端发现 Codex 当前仍有任务，桌面端在 12 秒安全时限内无法退出，因此中止切换：

- 实际登录账号保持 `hd-sarah-blackwell`，没有破坏或覆盖两个账号。
- 工作台显示安全中文错误，不暴露后端原始 stderr。
- 操作台账写入 `account_switch_failed`，actor 为 `codex-workbench`，来源链包含工作台和 Profile Switcher 账号引擎。
- 没有写入 `account_switched` 成功事件。
- 本次验收没有消费真实重置卡。

待当前 Codex 任务结束后，需要在无任务运行时完成 `hd-sarah-blackwell → hd-master → hd-sarah-blackwell`，并再次核对真实登录状态、菜单栏和两条成功日志。续作登记 ID：`followup_de7188ab8d614d`。

## 操作台账回归

- JSONL 原始追加行：358。
- 按事件 ID 收敛后的最新事件：182。
- 最新视图中的空泛工作流说明：0。
- 上下文压缩缺少摘要明细：0。
- 最新视图中的附件、AGENTS、插件推荐或线程委派元数据污染：0。
- 历史 revision 中 3 条早期委派包装仍按追加式审计原则保留，但最新 revision 已全部清理；页面不会展示旧污染版本。
- Core 全量回归：`PASS: CodexWorkbenchCoreTests`。

## 视觉与无障碍

- [账号管理 900 浅色](../screenshots/profile-integration/accounts-900-light.png)
- [账号管理 1160 浅色](../screenshots/profile-integration/accounts-1160-light.png)
- [概览 1440 浅色](../screenshots/profile-integration/overview-1440-light.png)
- [项目分析 1160 浅色](../screenshots/profile-integration/projects-1160-light.png)
- [工具 / Skill 1160 浅色](../screenshots/profile-integration/tools-1160-light.png)
- [菜单栏浅色](../screenshots/profile-integration/menu-light.png)

已核对：窗口无横向滚动；项目日期可读；状态同时使用图标与文字；侧栏可用键盘移动；账号按钮暴露标准 Button 角色、`AXPress` 动作和完整操作提示。System Events 对 SwiftUI 隐藏语义 representation 没有提供稳定的普通 `AXDescription` 字段，因此保留为注意项，不虚报为完整通过。

应用专用 `AppleInterfaceStyle=Dark` 试验没有让 SwiftUI 窗口进入深色；误标截图已删除，临时偏好已清理，未修改系统全局外观。深色截图门禁仍未通过。

## 性能与启动

- 工作台重启后 RSS 三次采样约为 `253408 KB`、`283712 KB`、`280112 KB`；后两次间隔采样没有继续增长，打开 / 关闭设置窗口后的内存稳定在约 280 MB。
- 手动打开工作台会显示主窗口。
- Login Helper 已嵌入并签名；启动策略测试确认 `--login-item` 只驻留菜单栏。
- 工作台设置中“登录 Mac 时启动观测站”当前为关闭；验收没有擅自修改用户偏好。

## 未完成门禁

1. Codex 空闲后完成真实双向切换并恢复 Blackwell。
2. 补齐深色菜单栏及账号页证据。
3. 补齐安装版暂存、错误、切换中状态视觉证据。
4. 完成最终 AC 对照、长期变更记录和用户确认；在此之前不得删除旧 App。
