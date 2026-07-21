# Codex 工作台 v0.3.0 发布说明（草案，未发布）

> 当前文件只用于发布前复核。缺少 Developer ID 签名或 Apple 公证时，不得把本地结构验证包作为本版本资产上传。

预定 GitHub Release tag：`codex-workbench-v0.3.0`。工作台使用独立命名空间，不复用同仓库 Profile Switcher 已存在的 `v0.3.0`。

## 系统要求

- Apple Silicon（M 系列）Mac。
- macOS 13 或更高版本。
- 已安装并登录官方 Codex App。
- 不支持 Intel / Universal，不通过 App Store 或 Homebrew 分发。

## 本版内容

- 将日常入口统一为“Codex 工作台”，保留旧 Profile Switcher 冷备和恢复说明。
- 支持只有默认 `~/.codex` 的本机单账号只读识别，也兼容既有 `~/.codex-profiles`。
- 增加当前账号安全重启、风险确认、结果验证和脱敏操作日志。
- 增加可执行的“诊断与修复”，识别重复 Codex/ChatGPT App、运行路径、内置后端和账号模式。
- 侧栏收敛为概览、操作日志、账号管理、项目与任务、工具与自动化。
- App 内置 arm64 自包含账号后端，用户不需要安装 Python 或运行构建脚本。

## 安装

1. 从本 Release 下载 `Codex-Workbench-v0.3.0-arm64.dmg` 和对应 `.sha256`。
2. 可选执行 `shasum -a 256 -c Codex-Workbench-v0.3.0-arm64.dmg.sha256`。
3. 打开 DMG，把“Codex 工作台”拖入 Applications。
4. 从 Finder 或 Spotlight 打开。正式资产应已完成 Developer ID 签名、公证和 stapling，不需要绕过 Gatekeeper。

## 手动升级

本版不包含自动更新。升级时下载新版 DMG，用新版“Codex 工作台.app”覆盖旧版；`~/.codex`、`~/.codex-profiles` 和操作台账不会随 App 覆盖删除。

## 账号边界

- 单账号模式只识别本机现有账号，不提供新增、导入、登录或删除账号。
- 已有 Profiles 用户继续使用原有安全切换与自动重置能力。
- 不会把默认单账号自动转换为 Profile，也不会为了诊断自动修改认证文件或删除重复 App。

## 隐私

工作台只读取本地可解释证据，不加入 analytics、telemetry 或后台 GitHub 更新请求。日志与诊断摘要不会记录 token、Cookie、密码、认证正文或完整重置卡 ID。
