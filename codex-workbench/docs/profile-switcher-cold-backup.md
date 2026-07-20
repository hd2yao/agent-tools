# Profile Switcher 冷备基线

记录时间：2026-07-17

最近复核：2026-07-20T14:25:05+08:00

## 安装产物

- 路径：`/Users/dysania/Applications/Codex Profile Switcher.app`
- Bundle ID：`com.hd2yao.codex-profile-switcher`
- 版本：`0.10.1 (21)`
- 稳定源码基线：`d4b90af`（包含账号路由修复 `be77c97` 与自动重置串行化修复 `a6b9d54`）。
- 当前安全更新：`2026-07-17T14:37:19+0800`
- 主二进制 SHA-256：`83f5ba376c90f5dd2be67a575eeaee0f7061037d14b82325105f9990cd867d40`
- 当前进程：停止；只在工作台退出后手动启用。
- 更新内容：仅同步账号路由修复与跨进程自动重置 claim；产品版本和冷备用途不变。
- 迁移前安装包已移至 `/Users/dysania/.Trash/Codex Profile Switcher pre-lock-20260717.app`，需要时仍可恢复；没有直接删除旧二进制。

## 基线验证

- Profile Switcher：Python 138 项通过，旧 App build / install verifier 通过。
- Codex 工作台：`./test.sh`，`CodexWorkbenchCoreTests` 通过。

## 使用边界

- 迁移期间保留该安装产物作为冷备。
- 日常使用工作台时冷备必须退出，避免重复刷新、通知和自动重置竞争。
- 如果工作台账号链路失败，按顺序退出工作台、确认工作台进程已停止、手动打开上述冷备 App，再复核当前账号；不要同时重试两个 App。
- 用户以后明确确认正式退役前，不删除当前冷备 App；安全更新使用可回滚替换。
- 本文不记录账号认证内容、token、Cookie 或重置卡原始标识。
