# Profile Switcher 冷备基线

记录时间：2026-07-17

## 安装产物

- 路径：`/Users/dysania/Applications/Codex Profile Switcher.app`
- Bundle ID：`com.hd2yao.codex-profile-switcher`
- 版本：`0.10.1 (21)`
- 安装时间：`2026-07-15T17:10:37+0800`
- 主二进制 SHA-256：`bfcda6e965c320bdf0f7432c4724b6550018c78db370a37bb6b24853a9c6d37e`
- 基线记录时进程：正在运行；真实迁移验收前按冷备约定退出，不卸载。

## 基线验证

- Profile Switcher：`python3 -m unittest -v`，136 项通过。
- Codex 工作台：`./test.sh`，`CodexWorkbenchCoreTests` 通过。

## 使用边界

- 迁移期间保留该安装产物作为冷备。
- 日常使用工作台时冷备必须退出，避免重复刷新、通知和自动重置竞争。
- 如果工作台账号切换链路失败，应先退出工作台，再手动打开冷备。
- 用户完成迁移成果验收前不得删除或覆盖此冷备基线。
- 本文不记录账号认证内容、token、Cookie 或重置卡原始标识。
