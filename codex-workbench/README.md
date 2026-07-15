# Codex 观测站

一个独立的原生 macOS Dashboard，用来查看跨任务的 Codex 关键操作、上下文压缩、额度重置、任务关系和账号状态。

它是上层工具壳，不属于任何单一账号。`Codex Profile Switcher` 仍保持独立，只作为“账号管理”模块的数据与切换后端。

## 功能

- 概览：Codex 运行状态、桌面账号、今日事件、需关注事件和最近活动。
- 操作日志：最新在上、按日期分组，支持搜索、级别/来源/状态筛选和详情 inspector。
- 任务定位：有有效任务 ID 时，可直接回到对应 Codex 任务。
- 账号管理：区分最近任务、桌面默认和统计归因，复用现有安全切换路径。
- 菜单栏：随时查看最近三条重要操作，打开观测站或切到 Codex。
- 启动关联：可选登录 Mac 时启动；可选在 Codex 启动时显示观测站。
- 状态监听：官方额度通知近实时触发完整快照，另有 60 秒、启动与唤醒补扫；普通额度消耗只更新基线，不刷日志。
- 全局台账：记录额度、项目空间、对话接续、摘要及规则/Skill/Hook/Plugin/Automation 变化。

## 安装与打开

```bash
./install-app.sh
./verify-install.sh
open "$HOME/Applications/Codex 观测站.app"
```

安装后可以直接从 Finder、Spotlight 或菜单栏打开，不需要手动运行 Python 命令或启动本地服务。账号模块所需的既有 Python 后端已随 App 打包。

## 数据位置与隐私

- 操作台账：`~/.codex/operation-ledger/events.jsonl`
- 观察基线：`~/.codex/operation-ledger/state/observation-state.json`
- 只补扫本地可解释证据；坏行会降级提示，不阻塞其他事件。
- 不记录 token、Cookie、密码、认证文件内容、完整提示词或完整回复。
- 事实、推断和无法证实的事件会分别标注。

## 开发验证

```bash
./test.sh
swift build
./build-app.sh
```

目标平台为 macOS 13 及以上。视觉契约见 [DESIGN.md](DESIGN.md)，功能与验收标准见 [specs/codex-workbench/spec.md](specs/codex-workbench/spec.md)。
