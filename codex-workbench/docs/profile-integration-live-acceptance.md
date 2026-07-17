# Codex 工作台账号整合真实验收记录

记录时间：2026-07-17（Asia/Shanghai）

## 当前结论

**PASS。** Codex 观测站已经完整承接 Profile Switcher 的账号后端、当前账号、额度、重置卡、切换、运行状态、通知与自动重置能力，并成为唯一日常运行的 App。真实双向切换、安装包身份、深浅色与状态视觉、性能、台账回归和基础无障碍门禁均已通过。

旧 `Codex Profile Switcher.app` 仍按迁移约定作为冷备保留且停止运行；本阶段只证明已经具备退役条件，不删除冷备。后续删除 App 或归档源码仍需用户再次确认。

## 安装身份

- 工作台：`/Users/dysania/Applications/Codex 观测站.app`
- Bundle ID：`com.hd2yao.codex-workbench`
- 版本：`0.2.0`
- 安装二进制源码提交：`74abc7c`（后续 `42f9920` 仅更新验收截图）
- 账号后端指纹：`82355f935efff1f88727f7d08bacf515d31c5cb64686d2992862dfe79a1891c5`
- 安装验证：通过；内置 Login Helper、源码指纹、账号资源 freshness 和 codesign 均通过。
- 冷备：`/Users/dysania/Applications/Codex Profile Switcher.app`，`com.hd2yao.codex-profile-switcher`，`0.10.1 (21)`；已同步共享自动重置锁，仍安装且验收结束时进程数为 0。更新前安装包在废纸篓保留为可恢复副本。
- 包内未发现 `__pycache__`；人工后端只读检查均设置 `PYTHONDONTWRITEBYTECODE=1`，没有再次破坏签名。

## 真实账号与双向切换

最终只读快照不包含认证数据、token、Cookie、完整重置卡 ID 或其他秘密：

- 当前真实登录账号：`hd-sarah-blackwell`；桌面状态为托管；Codex 状态为“运行中”。
- `hd-master`：Plus，官方首要窗口 `10080` 分钟（7 日），采样时剩余 `53%`，第二窗口缺失，2 张可用重置卡。
- `hd-sarah-blackwell`：Plus，官方首要窗口 `10080` 分钟（7 日），最终门禁时剩余 `25%`，第二窗口缺失，1 张可用重置卡。验收期间从 41% 持续下降来自当前 Codex 的真实使用，不是 fixture 写入。
- UI 按官方 `window_minutes` 显示“7 日额度”，第二窗口缺失时显示“其他额度 —”；没有“桌面默认账号”这一套额外语义。

额度会随真实 Codex 使用继续变化；验收只要求账号归属与窗口语义正确，不把百分比固定为常量。

2026-07-17 13:32（Asia/Shanghai）完成真实恢复链路：

1. `hd-sarah-blackwell → hd-master`，台账时间 `2026-07-17T05:32:04.036Z`。
2. `hd-master → hd-sarah-blackwell`，台账时间 `2026-07-17T05:32:30.147Z`。

两条事件均为 `account_switched / success`，actor 为 `codex-workbench`，来源链包含工作台与 Profile Switcher 账号引擎；切换后真实登录账号和托管状态均通过验证。此前任务繁忙时的安全中止记录仍以 `account_switch_failed` 保留，证明失败不会伪写成功。验收没有消费任何真实重置卡。

## 受控视觉验收与安全边界

用户批准方式 A 后，正式安装包增加显式、隔离的视觉验收模式：

- `CODEX_WORKBENCH_VISUAL_FIXTURE=stale|error|switching`
- `CODEX_WORKBENCH_VISUAL_APPEARANCE=dark|light`
- `CODEX_WORKBENCH_VISUAL_SURFACE=menu` 仅在 fixture 有效时开放，用同一 `MenuBarView` 生成菜单预览。
- fixture 不加载 Python 后端，不刷新或写入台账，不启动轮询、通知、官方额度观察或自动重置，刷新与切换控件禁用。
- fixture 在 App 初始化阶段也跳过 `SMAppService` 登录项迁移，不注册或注销任何真实登录启动项。
- fixture 使用独立窗口 scene ID，不覆盖普通工作台的窗口保存状态；深浅色只应用于当前进程，不修改 macOS 全局或 App 持久外观。
- 所有 synthetic 截图均显示“视觉验收模式 · 不执行真实账号操作”，其中 49% / 53% 为固定展示样例，不是验收结束时的实时额度。

安全前后对照：

| 项目 | fixture 前 | fixture 后 | 结果 |
|---|---|---|---|
| 当前真实账号 | `hd-sarah-blackwell` | `hd-sarah-blackwell` | PASS |
| Blackwell / Master 重置卡 | `1 / 2` | `1 / 2` | PASS |
| 台账原始行数 | `362` | `362` | PASS |
| 旧 App 进程 | `0` | `0` | PASS |
| 持久视觉环境键 | 无 | 无 | PASS |
| 普通窗口 | `1160×780` | `1160×780` | PASS |
| 安装包签名 | 有效 | 有效 | PASS |

## 视觉证据

真实数据与常规页面：

- [账号管理 900 浅色](../screenshots/profile-integration/accounts-900-light.png)
- [账号管理 1160 浅色](../screenshots/profile-integration/accounts-1160-light.png)
- [菜单栏浅色](../screenshots/profile-integration/menu-light.png)
- [概览 1440 浅色](../screenshots/profile-integration/overview-1440-light.png)
- [项目分析 1160 浅色](../screenshots/profile-integration/projects-1160-light.png)
- [工具 / Skill 1160 浅色](../screenshots/profile-integration/tools-1160-light.png)

同一正式安装二进制的受控状态证据：

- [账号管理 1160 深色](../screenshots/profile-integration/accounts-1160-dark.png)
- [菜单栏深色](../screenshots/profile-integration/menu-dark.png)
- [账号暂存状态](../screenshots/profile-integration/accounts-1160-stale.png)
- [账号错误状态](../screenshots/profile-integration/accounts-1160-error.png)
- [账号切换中状态](../screenshots/profile-integration/accounts-1160-switching.png)

### Visual Verdict：95 / 100

| 维度 | 得分 | 结论 |
|---|---:|---|
| 信息层级 | 20 / 20 | 当前真实账号、额度、重置卡、错误和切换阶段都在首屏明确可见。 |
| 布局与响应式 | 19 / 20 | 900、1160、1440 证据齐全；无重叠、裁切、越界或根横向滚动。 |
| 排版与密度 | 19 / 20 | 系统字体、monospaced 数值、8pt 节奏和工作型密度一致。 |
| 色彩与状态 | 19 / 20 | 深浅色均使用系统语义 token；状态同时使用文字与图标，不只依赖颜色。 |
| 组件与细节 | 18 / 20 | 主窗口与菜单栏复用同一 presentation；验收提示克制且 synthetic 身份明确。 |

## 基础无障碍检查

| 检查项 | 结果 | 证据 |
|---|---|---|
| 颜色与文本替代 | PASS | 成功、警告、切换中、当前账号均同时使用文字和 SF Symbol；深浅色截图可读。 |
| 键盘与焦点 | PASS | 新提示为只读内容，不新增焦点陷阱；刷新与切换均为标准 Button，fixture 中使用语义禁用。 |
| 控件标签 | PASS | 刷新使用显式 accessibility representation；切换按钮包含目标账号、完整动作与提示。 |
| 状态描述 | PASS | 当前账号菜单状态使用组合 accessibility label；切换进度在顶部显示目标账号和阶段。 |

此前安装版已验证账号切换按钮暴露标准 Button 角色和 `AXPress`。本轮 macOS 终端辅助功能权限不可用，Computer Use 客户端也存在版本不匹配，因此没有虚报新的完整 VoiceOver 语音走查；新增内容没有新的无标签交互控件，已完成源码语义与截图底线检查。

## 独立复审收敛

第一次独立复审发现 4 个 Important，最终结论曾撤回；本轮按 TDD 全部关闭：

- 认证桥接成功后、启动 Codex 前立即记录目标账号路由；启动成功后再补 PID。手动启动恢复时不会继续沿用旧账号记录。
- 只有桌面正在运行、已托管且 active / desktop 账号一致时，菜单和账号页才标记“当前登录账号”；不一致或非托管时明确显示未知。
- 新旧 App 对同一额度 fingerprint 使用同一路径、同一文件名算法和同一旧偏好域的跨进程 claim；工作台在 claim 前后和后端调用前实时复查冷备进程。并发测试证明只能进入一次消费调用。
- 账号最后成功读取时间与工作台刷新时间分开；失败保留旧 payload，并显示“正在展示 N 分钟前成功读取的暂存数据”。A 方式截图复用同一生产逻辑。

二次独立复审未发现 Critical / Important。唯一 Minor 是冷备身份文档仍引用更新前 hash，已在同轮修正。

## 操作台账、性能与启动

- JSONL 原始追加行：`362`；唯一事件 ID：`186`。
- 两条最新真实双向切换成功记录与一条早期安全失败记录均保留。
- V1.4 上下文摘要、具体工作流变更与元数据过滤继续由 Core 全量回归覆盖：`PASS: CodexWorkbenchCoreTests`。
- 普通安装版重启后 RSS 采样约 `245968 KB`，与此前修复后的稳态范围一致，没有恢复到历史 846 MB 高占用。
- 手动打开显示主窗口；Login Helper 继续只负责登录启动时驻留菜单栏。
- 验收结束时只运行一个普通模式 `Codex 观测站`，旧 Profile Switcher 不运行。

## AC 收敛

AC-PI-001 至 AC-PI-016 全部通过。旧 App 的删除不是本次 AC，也没有执行；下一阶段若用户确认退役，再单独处理应用卸载、源码归档和冷备恢复说明。
