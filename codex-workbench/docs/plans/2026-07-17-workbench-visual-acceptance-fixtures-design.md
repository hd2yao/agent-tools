# Codex 工作台受控视觉验收模式设计

## 目标

为正式安装的 `Codex 观测站.app` 提供一个仅在显式环境变量存在时启用的视觉验收模式，稳定呈现深色、暂存、错误和切换中状态。该模式只补充视觉证据，不替代真实账号后端、真实双向切换或操作日志验收。

## 已批准方案

采用“同一正式二进制 + 显式环境变量 + 进程级隔离”。不修改 macOS 全局外观，不人为破坏账号后端，不执行真实账号切换，不消费重置卡，也不创建第二个长期状态源。

### 环境契约

- `CODEX_WORKBENCH_VISUAL_FIXTURE=stale|error|switching`
- `CODEX_WORKBENCH_VISUAL_APPEARANCE=dark|light`
- 缺失或未知值全部忽略，应用按正常模式启动。
- 外观可以独立于 fixture 使用；仅指定 `dark` 时仍读取真实账号数据。

## 架构

### Core

新增纯逻辑 `WorkbenchVisualAcceptanceConfiguration`，负责解析环境变量；新增 `WorkbenchVisualAcceptanceSnapshot`，为三种 fixture 生成脱敏、确定性的账号展示状态。Core 负责给出 payload、错误文案和切换目标，不接触 AppKit、文件系统或真实账号命令。

### App

- `WorkbenchAppDelegate` 只在显式外观配置有效时给当前进程设置 `NSAppearance`。
- `WorkbenchAppModel` 只在 fixture 有效时应用 Core 快照，并跳过 bootstrap、轮询、通知、自动重置、刷新和真实切换。
- fixture 模式公开只读标识，账号页和菜单栏显示“视觉验收模式 · 不执行真实账号操作”。
- 普通启动路径保持现有账号网关、台账、观察器和自动化行为。

## 固定展示数据

fixture 使用无认证内容的脱敏样例：当前账号 `hd-sarah-blackwell`、其他账号 `hd-master`、7 日主额度、缺失第二窗口和有限重置卡。样例只验证布局和状态层级，不声明为实时额度。

## 状态语义

| fixture | payload | 错误/提示 | 切换阶段 |
|---|---|---|---|
| `stale` | 保留 | 显示“正在展示暂存数据” | 无 |
| `error` | 无 | 显示账号模块不可用 | 无 |
| `switching` | 保留 | 无 | 切换到 `hd-master` |

## Design Lock

- 保持 Calm Operations Console、系统语义色、现有侧栏、卡片密度和响应式几何。
- fixture 标识使用次要提示条，不抢占当前账号和主操作层级。
- 深色只验证现有语义 token，不新增独立深色配色表。
- 不改变正常模式文案、账号排序、额度来源或切换按钮语义。

## 安全边界

- fixture 模式不调用 Python 后端，不写 `~/.codex/operation-ledger/`，不启动自动重置协调器或官方额度观察器。
- fixture 模式下刷新和切换入口不执行真实操作。
- 不输出 token、Cookie、认证内容或重置卡原始 ID。
- 截图必须显示 fixture 标识；真实双向切换证据仍来自正式后端和台账。

## 验收

- 纯逻辑测试覆盖：默认关闭、已知值解析、未知值忽略、三种 fixture 和脱敏边界。
- 普通安装启动后仍读取当前真实 Blackwell，且签名、资源指纹和台账不回退。
- 使用正式安装包同一二进制生成：账号页深色、菜单栏深色、暂存、错误、切换中截图。
- fixture 前后比较真实台账行数、当前账号、重置卡数量和应用偏好；必须完全不变。
- fixture 退出后普通重启，确认无环境变量、无 App 外观残留、旧 Profile Switcher 未运行。
