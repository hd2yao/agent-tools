# Codex 观测站

一个原生 macOS Codex 工作台，用同一个 App 承载账号管理、操作日志、项目分析、工具 / Skill 统计和后续 Codex 小工具。

`Codex 观测站.app` 是唯一日常入口。成熟的 Profile Switcher Python 账号引擎作为工作台内置后端继续提供额度、重置卡、切换和运行状态，不再形成第二套 UI 或状态源。迁移验收期间，旧 `Codex Profile Switcher.app` 只作为退出工作台后手动启用的冷备份保留。

## 功能

- 概览：Codex 运行状态、当前实际登录账号、今日事件、需关注事件和最近活动。
- 操作日志：最新在上、按日期分组，支持搜索、级别/来源/状态筛选和详情 inspector。
- 任务定位：有有效任务 ID 时，可直接回到对应 Codex 任务。
- 账号管理：查看当前真实登录账号、官方额度窗口、逐张重置卡、账号用量和其他账号；复用既有安全切换路径并在完成后验证真实登录状态。
- 项目分析：查看本地真实项目、对话、Tokens 和最近活动。
- 工具 / Skill：查看真实工具调用与 Skill 使用排行及数据健康。
- 菜单栏：显示当前真实登录账号的首要额度和 Codex 工作状态，并提供额度摘要、快速切换、最近操作及工作台快捷入口。
- 启动关联：可选登录 Mac 时启动；可选在 Codex 启动时显示观测站。
- 状态监听：官方额度通知近实时触发完整快照，另有 60 秒、启动与唤醒补扫；只记录恢复、耗尽和重置次数变化，普通消耗与刷新时间漂移不刷日志。
- 全局台账：记录额度、项目空间、对话接续、摘要及规则/配置/Skill/Hook/Plugin/Automation 变化；上下文压缩详情展示实际保留的用户要求与压缩前进展，工作流详情展示脱敏的具体增删、修改来源对话和投递目标对话。

## 安装与打开

```bash
./install-app.sh
./verify-install.sh
open "$HOME/Applications/Codex 观测站.app"
```

安装后可以直接从 Finder、Spotlight 或菜单栏打开，不需要手动运行 Python 命令或启动本地服务。手动打开会显示主窗口；可选的登录启动由内置 Login Helper 提供，只驻留菜单栏。

迁移期不要同时运行工作台和旧 Profile Switcher。若工作台账号链路出现问题，应先退出工作台，再手动打开旧 App；用户验收完成前不会删除冷备安装产物。

## 数据位置与隐私

- 操作台账：`~/.codex/operation-ledger/events.jsonl`
- 观察基线：`~/.codex/operation-ledger/state/observation-state.json`
- 只补扫本地可解释证据；坏行会降级提示，不阻塞其他事件。
- 不记录 token、Cookie、密码、认证文件内容、完整提示词、完整回复或完整 patch；摘要和变更说明均有长度与敏感值过滤。
- 事实、推断和无法证实的事件会分别标注。

## 开发验证

```bash
./test.sh
swift build
./build-app.sh
```

目标平台为 macOS 13 及以上。视觉契约见 [DESIGN.md](DESIGN.md)，功能与验收标准见 [specs/codex-workbench/spec.md](specs/codex-workbench/spec.md)。
