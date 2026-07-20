# Codex 工作台产品化基线

记录时间：2026-07-20T14:25:05+08:00

源码提交：`c01f3ac19ba09559d84b379ce6619ed70c258c83`

## 当前工作台产物

- 安装路径：`/Users/dysania/Applications/Codex 观测站.app`
- App 名称：`Codex 观测站`
- Bundle ID：`com.hd2yao.codex-workbench`
- 版本：`0.2.0 (2)`
- 架构：仅 `arm64`
- 主二进制 SHA-256：`03c775bdfbf5644e36c3f21e18591a5bc4ccd9e26a3ec1a0091a419315812051`
- 安装产物源码标识：`74abc7c`
- 签名：ad-hoc，未设置 TeamIdentifier。
- 进程快照：工作台正在运行；`Codex Profile Switcher.app` 未并行运行。

## 当前运行时依赖

工作台仍把 `codex_profile.py` 和 `codex_profile_dashboard.py` 作为源码资源复制进 App。Release Gateway 会按顺序查找 Homebrew、Framework 或系统 `python3`，再用外部 Python 执行包内脚本，因此当前产物还不是普通用户可直接分发的自包含 App。

目标产物必须把账号后端冻结为 App 内 `arm64` onedir helper。Release Gateway 只能执行该固定包内路径；外部 Python 查找只允许保留在源码开发模式。

## 公开发行门禁

- `security find-identity -v -p codesigning` 当前返回 `0 valid identities found`。
- 当前 App 只有 ad-hoc 签名，未完成 Developer ID、Hardened Runtime、公证、staple 或 Gatekeeper 发行验证。
- 当前 App 依赖外部 Python，尚未通过无 Python / Homebrew 的干净用户验收。
- 正式 GitHub Release 必须等待自包含 helper、从内到外签名、公证 DMG、SHA-256、干净用户和视觉 / 无障碍门禁全部通过。
- 没有 Developer ID Application 身份与 `notarytool` Keychain profile 时，只能验证功能、发行脚本和无凭据 fail-closed 行为，不能宣称正式发行完成。

## 恢复入口

- 冷备 App：`/Users/dysania/Applications/Codex Profile Switcher.app`
- 冷备基线与恢复顺序：[profile-switcher-cold-backup.md](profile-switcher-cold-backup.md)
- 账号链路异常时先退出工作台并确认进程停止，再手动打开冷备；两个 App 不得并行执行刷新、切换或自动重置。
- 恢复过程不复制、移动或记录 `auth.json`，也不改变 `~/.codex` 与 `~/.codex-profiles`。
