# 重置卡详情、提醒与额度耗尽自动使用设计

## 目标

- 完整展示每张重置卡的北京时间到期时间，不把多个时间压成单行省略。
- 收敛弹窗概览的字号层级和“3张”间距。
- 让项目活动概览的标题、值和说明形成稳定三列。
- 在重置卡到期前发送本地系统提醒。
- 仅在官方明确报告额度耗尽时，自动使用最早到期的可用重置卡。

## 权威数据与官方边界

- 权威读取接口：Codex app-server `account/rateLimits/read`。
- 每张卡直接使用 `rateLimitResetCredits.credits[].expiresAt`，不推算到期时间。
- 官方文档说明 `expiresAt` 是可空的 Unix 秒时间戳；明细可能被服务端截断，卡片总数以 `availableCount` 为准。
- 官方使用接口：`account/rateLimitResetCredit/consume`。每次逻辑尝试使用 UUID 作为 `idempotencyKey`，优先传入同一次 `account/rateLimits/read` 中最早到期卡的 opaque `creditId`。
- 不把 opaque id、auth 内容或 token 传给 Swift/UI/日志。
- 官方文档：<https://learn.chatgpt.com/docs/app-server#auth-endpoints>。

## 行为设计

### 到期提醒

每张未使用且有 `expiresAt` 的卡安排以下通知：

1. 前一工作日 16:30。周一到期时回退到上周五；周末到期也回退到周五。
2. 若卡在工作日 11:00 之后到期，当天 09:30 再提醒。
3. 到期前 1 小时发送最后提醒。

提醒时间由 Python 适配层按北京时间生成并随脱敏卡片 payload 返回，便于覆盖工作日和周末单元测试；macOS `UNUserNotificationCenter` 只负责调度。通知标识由 profile、到期时间和提醒类型组成；重复刷新不得重复安排。权限未授权时不阻塞额度读取和账号切换。

### 自动使用

- 默认启用“额度耗尽时自动使用”。
- 触发条件必须同时满足：`rateLimitReachedType` 非空、可用卡数大于 0、存在未到期卡。
- 不因“即将过期”单独消耗卡，避免额度尚未耗尽时浪费。
- 同一 profile + 限额窗口 + 最早到期时间形成逻辑尝试指纹；失败重试复用同一幂等键。
- `reset` 和 `alreadyRedeemed` 视为成功并立即刷新额度；`nothingToReset`、`noCredit` 和 RPC 错误只通知，不循环消耗。
- 单元测试只验证请求、状态机和幂等；不通过测试夹具或真实账号主动消耗卡。安装后若真实账号已经耗尽，生产逻辑可按上述条件执行。

## UI 设计契约

### 重置卡详情

- `ResetCreditCompactStripView` 每张卡独占一行。
- 左列显示 `M月d日 周X HH:mm`，右列显示相对时间或“即将到期”。
- 最多展示服务端返回的 4 条明细；若 `availableCount` 更大，补一行“另有 N 张未展开”。
- 卡片高度由可见行数计算，当前 3+1 张数据必须完整落在 310pt 面板内。
- 无 `expiresAt` 时显示“到期时间暂不可用”，不伪造日期。

### 弹窗概览

- 三列标题 9.5pt，主值 14pt semibold/bold，说明 8.5pt，保留额度和卡数为视觉重点但不做夸张对比。
- 卡数统一显示为 `3张`，不在数字和量词间加入空格。
- 三列宽度和间距保持稳定，不改变弹窗整体宽度。

### 项目活动概览

- 使用固定的标题列和值列宽度，说明列统一从同一 x 坐标开始。
- 最长项目名中间截断，数值和说明不得互相挤压。
- 最小、默认和较宽窗口下列起点一致。

## 非目标

- 不修改账号切换、auth/profile/symlink 结构。
- 不调用旧私有 HTTP reset-credit endpoint。
- 不在额度未耗尽时为测试消耗任何重置卡。
- 不重构整个 Dashboard 或改变现有 light Design Lock。

## 验收

- master 的 3 个到期时间逐行完整显示；sarah 的单个时间完整显示。
- 弹窗“90% / 0 / 3张”字号层级协调，`3张` 无异常间隔。
- 项目概览四行的说明列左边缘一致。
- 提醒计划测试覆盖工作日上午、工作日下午、周一、周末和一小时提醒。
- consume 测试覆盖最早到期选择、幂等键、`reset`、`alreadyRedeemed`、`nothingToReset`、`noCredit`，但不发起真实消耗。
- 完整 unittest、Swift 编译、build/install、新进程身份和真实截图通过。
