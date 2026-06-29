# Codex Profile Dashboard Design

## 背景

Codex Profile Switcher 已经解决了两个账号之间切换时，本地历史、技能、Pet、自定义资源等状态过度隔离的问题。下一步目标是做一个可视化界面：在同一个本地工具里看到账号状态、额度、重置时间和 token 使用情况，并能一键切换到目标账号打开 Codex Desktop。

## 设计结论

优先使用 Codex 官方 app-server JSON-RPC 作为账号额度和使用量来源。它已经暴露 `account/rateLimits/read` 和 `account/usage/read`，可以按 profile 启动独立的 `codex app-server`，通过 `CODEX_HOME=~/.codex-profiles/<name>` 读取对应账号状态。

本地 `~/.codex/sessions/**/rollout-*.jsonl` 里的 `token_count` 事件作为第二来源。它适合做近实时 token 使用统计、离线兜底和 app-server 不可用时的展示，但不能完全等同于账号服务端额度。

OpenAI Platform Usage/Costs API 只适合 API key/project 计费场景，不作为 Codex ChatGPT 账号额度的默认来源。

直接调用 `chatgpt.com/backend-api/wham/*` 这类内部 HTTP 接口只保留为未来实验开关，不在 MVP 默认启用。原因是它更容易受接口变动和条款边界影响，而 app-server 已经提供了更贴近 Codex 客户端的通道。

## 数据来源优先级

1. **Codex app-server JSON-RPC**
   - 每个 profile 单独启动一次 `codex app-server`。
   - 设置 `CODEX_HOME` 指向对应 profile。
   - 调用 `initialize`，带 `capabilities.experimentalApi=true`。
   - 调用 `account/rateLimits/read` 获取额度、窗口、已用百分比、重置时间、credits。
   - 调用 `account/usage/read` 获取 summary 和 daily buckets。

2. **本地 token_count 快照**
   - 扫描共享 Codex home 下的 `sessions` 和 `archived_sessions`。
   - 解析 rollout JSONL 中 `event_msg.type == "token_count"` 的事件。
   - 统计 input、output、cached、reasoning、total。
   - 读取最新事件里的 rate limit 快照，作为 app-server 失败时的 stale snapshot。

3. **SQLite 历史汇总**
   - 读取共享 `state_5.sqlite` 的 `threads.tokens_used`。
   - 只展示为本地历史总量，不用于判断服务端额度。

## MVP 界面

入口命令：

```bash
python3 codex_profile.py ui
```

默认启动本地 HTTP 服务：

```text
http://127.0.0.1:8765
```

首版不做 Electron/Tauri 打包，先用 Python 标准库 HTTP server 加静态 HTML/CSS/JS。这样不引入构建链，也便于快速验证数据准确性。后续稳定后再迁移为 Tauri 或菜单栏应用。

界面结构：

- 顶部状态栏：当前 active profile、刷新时间、数据源健康状态。
- 账号卡片：profile 名、登录状态、配置状态、计划类型、额度剩余、重置时间。
- 限额窗口：primary/secondary 的 used percent、remaining percent、window duration、resetsAt。
- 使用量：今日 token、输入、输出、缓存命中、reasoning，以及 daily buckets。
- 操作区：刷新、切换到该账号、打开登录、运行 doctor。
- 诊断区：app-server 错误、本地快照时间、是否 stale。

## 切换行为

前端的“切换”按钮复用现有 `app` 命令逻辑：

1. 校验 profile 存在。
2. 确保共享状态 symlink/merge 完成。
3. 退出已运行的 Codex Desktop。
4. 用目标 profile 的 `CODEX_HOME` 执行 `codex app`。

这样可以避免 Desktop 里长驻 app-server 沿用旧 `CODEX_HOME`，导致看起来“重启后又切账号”。

## 安全边界

- 不读取、不打印、不回传 `auth.json` token 内容。
- app-server 调用只通过本地子进程和 stdio。
- HTTP server 默认只绑定 `127.0.0.1`。
- 不新增遥测或远程网络调用。
- 错误日志只记录 profile 名、方法名、状态和异常类型，不记录凭据。

## 失败模式

- profile 未登录：显示 `auth: missing`，额度区域标为 unavailable。
- app-server 不支持方法：显示 unsupported，并回退本地 token_count。
- app-server 超时：终止子进程，显示 timeout，并回退本地快照。
- 网络不可用：app-server 返回错误，界面显示 service unavailable。
- 本地 rollout 解析失败：跳过坏行，保留错误计数。
- Codex Desktop 已经运行在旧 profile：切换时强制 restart。

## 测试策略

- 单元测试 JSON-RPC 响应归一化。
- 单元测试 rollout token_count 解析和坏行跳过。
- 单元测试 profile dashboard JSON payload 不包含 token 内容。
- 单元测试 `ui` 命令注册和默认端口。
- smoke test：启动本地服务，访问 `/api/profiles`，确认返回两个 profile 的结构化数据。

## 后续打包路线

1. CLI 内置 dashboard，完成数据准确性和一键切换。
2. 增加“当前 Desktop 实际 CODEX_HOME”检测。
3. 增加菜单栏/桌面壳，优先 Tauri。
4. 增加后台刷新和系统通知。
5. 打包签名，形成独立小软件。
