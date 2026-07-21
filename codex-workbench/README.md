# Codex 工作台

一个原生 macOS Codex 工作台，用同一个 App 承载账号管理、操作日志、项目与任务、工具与自动化。

`Codex 工作台.app` 是唯一日常入口。成熟的 Profile Switcher 账号引擎会以 arm64 自包含后端随 App 安装，继续提供额度、重置卡、切换和运行状态，不要求用户安装 Python。旧 `Codex Profile Switcher.app` 在用户确认正式退役前只作为退出工作台后手动启用的冷备份保留。

## 功能

- 概览：Codex 运行状态、当前实际登录账号、今日事件、需关注事件和最近活动。
- 操作日志：最新在上、按日期分组，支持搜索、级别/来源/状态筛选和详情 inspector。
- 任务定位：有有效任务 ID 时，可直接回到对应 Codex 任务。
- 账号管理：查看当前真实登录账号、官方额度窗口、逐张重置卡、账号用量和其他账号；复用既有安全切换路径并在完成后验证真实登录状态。
- 项目与任务：查看本地真实项目、任务、Tokens、上下文摘要和接续关系。
- 工具与自动化：查看真实工具调用、Skill 使用排行、Hook 和自动化状态。
- 菜单栏：显示当前真实登录账号的首要额度和 Codex 工作状态，并提供额度摘要、快速切换、最近操作及工作台快捷入口。
- 启动关联：可选登录 Mac 时启动；可选在 Codex 启动时显示观测站。
- 状态监听：官方额度通知近实时触发完整快照，另有 60 秒、启动与唤醒补扫；只记录恢复、耗尽和重置次数变化，普通消耗与刷新时间漂移不刷日志。
- 全局台账：记录额度、项目空间、对话接续、摘要及规则/配置/Skill/Hook/Plugin/Automation 变化；上下文压缩详情展示实际保留的用户要求与压缩前进展，工作流详情展示脱敏的具体增删、修改来源对话和投递目标对话。

## 安装与打开

```bash
./install-app.sh
./verify-install.sh
open "$HOME/Applications/Codex 工作台.app"
```

安装脚本会原子替换同 bundle id 的旧工作台，并迁移旧 `Codex 观测站.app` / `Codex 工具台.app`；失败时恢复旧 App，且不会改动 `~/.codex` 或 `~/.codex-profiles`。安装后可以直接从 Finder、Spotlight 或菜单栏打开，不需要手动运行 Python 命令或启动本地服务。手动打开会显示主窗口；可选的登录启动由内置 Login Helper 提供，只驻留菜单栏。

不要同时运行工作台和旧 Profile Switcher。若工作台账号链路出现问题，应先退出工作台，再手动打开旧 App；没有用户新的明确确认，不会删除冷备安装产物。

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

目标平台为 Apple Silicon（M 系列）和 macOS 13 及以上，不构建 Intel 或 Universal 版本。视觉契约见 [DESIGN.md](DESIGN.md)，功能与验收标准见 [specs/productization/spec.md](specs/productization/spec.md)。

## GitHub Releases 发行

首发只通过 GitHub Releases 提供手动下载安装的 DMG，不接 App Store、Homebrew 或自动更新。升级时重新下载新版 DMG 并覆盖安装。

当前代码、arm64 自包含构建、结构性 DMG、SHA 和 fail-closed 发布脚本已经完成；当前开发机没有有效 Developer ID Application 身份，因此仓库尚未产出或发布正式公证 DMG。`.build/productization-acceptance-*` 中的未签名结构包只用于本地挂载和覆盖安装验证，不能上传或分发。正式状态见 [产品化真实验收记录](docs/productization-live-acceptance.md)。

发布机必须在 Keychain 中已有 `Developer ID Application` 身份，并预先用 `notarytool store-credentials` 保存公证 profile；不要把证书、profile 凭据或密码写入仓库或命令输出。

冻结后端的构建 Python 也必须是 arm64，且自身最低系统版本不高于 macOS 13。脚本会检查 App 内每个 Mach-O 的 `minos`，不兼容的 Homebrew / 系统 Python 会直接失败；发布机可显式指定已验证的 Python 3.12 运行时：

```bash
CODEX_WORKBENCH_BUILD_PYTHON="/path/to/compatible/python3.12" \
  ./scripts/bootstrap-release-tools.sh
./scripts/build-account-backend.sh
```

```bash
./Tests/Scripts/test-release-guardrails.sh
./scripts/release.sh --version 0.3.0 --dry-run

./scripts/release.sh \
  --version 0.3.0 \
  --sign-identity "$CODEX_WORKBENCH_SIGN_IDENTITY" \
  --notary-profile "$CODEX_WORKBENCH_NOTARY_PROFILE"
```

成功后会生成：

- `dist/Codex-Workbench-v0.3.0-arm64.dmg`
- `dist/Codex-Workbench-v0.3.0-arm64.dmg.sha256`

GitHub 发布另有显式门禁；工作台使用独立 tag `codex-workbench-v<version>`，避免与同仓库的 Profile Switcher `v<version>` 冲突。不传 `--publish` 不会调用 `gh release create`，已存在的 tag / Release 也不会被覆盖。上传前会重新执行 DMG、stapler 和 Gatekeeper 校验，并要求工作树干净、当前 HEAD 已成为远端分支 tip；新 tag 会通过 `--target` 明确绑定该提交：

```bash
./scripts/publish-github-release.sh \
  --version 0.3.0 \
  --notes-file ./release-notes.md \
  --publish
```

正式发布说明可从 [v0.3.0 草案](docs/release-notes-v0.3.0-draft.md) 复核并复制；发布前必须替换草案状态、核对版本号，并确认 DMG 已完成 Apple 公证和 stapling。
