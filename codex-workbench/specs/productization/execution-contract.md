# Codex 工作台产品化与公开发行执行契约

## Intent Lock

- 本次只解决：把现有工作台收敛为唯一日常 App，兼容本机单账号与既有 Profiles，补齐重启、诊断、合并模块和 GitHub DMG 手动发行闭环。

## Scope Fence

### 范围内

- 五模块信息架构。
- 本机单账号只读适配和既有 Profiles 兼容。
- 当前账号重启与诊断。
- Apple Silicon 自包含 helper、签名、公证、DMG 和 GitHub Release 脚本。
- 冷备、真实、干净用户、视觉和无障碍验收。

### 范围外

- Intel / Universal、App Store、Homebrew、自动更新。
- 新增 / 登录 / 导入 / 删除账号或单账号转 profile。
- 修改认证格式、删除冷备、复制聊天 UI。
- 遥测、云端同步和后台 GitHub 请求。
- 单账号自动消费重置卡。

## Approved Behavior

### 必须满足

- 单账号默认 home 零迁移识别；既有 Profiles 能力不缩水。
- 当前实际账号是菜单栏和账号页的主语义。
- 高风险重启必须确认并在完成后验证。
- 诊断只报告和执行安全动作，不自动改认证或删除 App。
- Release 用户不安装 Python；产物只含 arm64。
- GitHub Release 由用户重新下载升级，App 不自动更新。
- 冷备保持可恢复且不与工作台并行运行。

### 明确不改变

- bundle id、macOS 13 最低版本和 Design Lock。
- Profile Switcher 的认证格式、桥接事务、切换验证与自动重置规则。
- 操作日志 V1.4 数据和解释边界。
- 用户 `~/.codex` 与 `~/.codex-profiles` 的既有内容。

## Design Constraints

### 架构约束

- 一个账号协调器、一个 payload、一个运行状态快照。
- Core 承载模式、策略、验证和脱敏；App 承载 NSWorkspace / FileManager / SwiftUI。
- 单账号与 Profiles 用显式 enum 区分，不从 profiles 数量在 UI 中临时猜测。
- 自包含 helper 使用 onedir，放置在 App 规范的 Helpers 位置并从内到外签名。

### 接口约束

- 后端 payload 只新增可选字段；旧 fixture 必须继续解码。
- Release Gateway 只执行包内主二进制；开发 fallback 不得被复制进发行包。
- 发布脚本必须 fail closed，外部上传必须显式 `--publish`。

### 数据约束

- 单账号适配只读默认 home，不写 active profile 记录。
- 不把 `auth.json` 或认证正文复制到临时磁盘；只允许在 0700 临时 home 中创建短生命周期符号链接，并以系统沙盒拒绝 App Server 对原默认 home、认证实际目标及临时 home 非白名单路径的写入。白名单只包含已核实的状态 SQLite 文件与 `installation_id`；沙盒缺失时失败关闭。
- 诊断摘要不包含认证正文、email、token、Cookie 或完整重置卡 ID。
- 测试默认使用临时 home；真实 home 只做只读验收和已批准的既有切换 / 空闲重启。

### 依赖约束

- 不新增第三方 Swift package。
- PyInstaller 仅为 pinned 构建依赖；CPython / PyInstaller notices 随发行文档保存。
- 不因公证困难添加宽泛 Hardened Runtime 例外；需要新 entitlement 时先解释最小权限。

## Task Batches

- Batch 1：基线冷备、单账号 Python payload、Swift 双模式契约。
- Batch 2：自包含 helper 与 Release Gateway。
- Batch 3：安全重启、诊断和日志。
- Batch 4：侧栏、项目与任务、工具与自动化 UI。
- Batch 5：命名迁移、签名、公证、DMG 与手动发布。
- Batch 6：真实、干净用户、视觉、无障碍和收敛。

## Test Obligations

### 必须验证

- 每条 AC 至少映射一个自动化或真实证据。
- Python 完整测试、Swift Core 完整测试、Release build 和安装 verifier。
- 临时单账号 home 前后文件树一致。
- 临时单账号读取必须断言认证入口始终为符号链接而非普通文件，原子替换与任意未知暂存文件均被沙盒拒绝；App Server 写入只出现在临时 home 的非认证白名单，源 home 文件树与 hash 不变。
- Profiles 双向切换恢复初始账号。
- 自包含 helper 在无外部 Python 环境运行。
- 每个嵌套 Mach-O 架构与签名、Hardened Runtime、DMG 和公证。
- 正式安装产物视觉与 AX。

### 边界情况

- 默认 home 缺失 / 不可读、App Server 失败、Codex 未安装 / 未运行。
- Profiles 根目录存在但为空、active profile 无效、桥接损坏。
- 重启处于 running / waiting / idle / unknown、取消、退出超时、启动超时和验证不匹配。
- 两个同 bundle id App、只有 ChatGPT.app、只有 Codex.app、Launch Services 指向不同路径。
- 缺少签名身份、公证 profile、错误架构、陈旧 helper、SHA 不匹配。

### 禁止验证方式

- 不强制中断真实运行任务。
- 不消费真实重置卡。
- 不把源码断言代替正式 App / DMG 行为。
- 不用真实账号目录验证单账号迁移写保护。

## Review Gates

### 实现前

- `spec → tasks`、`plan → tasks`、风险 → 测试 / 回滚无 Critical 缺口。
- 工作树无意外改动，设计和实施计划已独立提交。
- 明确当前 `security find-identity` 为 0；正式 Release 仍有外部凭据门禁。

### 实现中

- 每批先失败测试，再最小实现，再相关测试、focused diff 和独立提交。
- 修改账号模式、认证、发布权限、entitlement 或最低系统版本时先更新本契约。
- 发现 PyInstaller 需要宽泛运行时例外或无法干净公证时停止发行轨道，其他安全轨道可继续。

### 实现后

- 全量门禁、安装身份、运行身份、视觉和 AC 收敛通过。
- 用户账号和冷备未损坏，Profiles 验收恢复初始账号。
- 没有 Developer ID / notary 凭据时只能交付“功能完成 + 发行脚本通过无凭据门禁”，不得宣称正式 DMG 已发布。

## Rewind Triggers

### 回到 spec

- 需要新增账号、自动更新、Intel、App Store、认证格式变更或删除冷备。
- 单账号无法在不写默认 home 的前提下确认账号。

### 回到 plan / contract

- 自包含 helper 不能以最小 entitlement 签名 / 公证。
- 原生重启与既有后端的安全事务产生冲突。
- 产品改名导致 bundle identity 或设置迁移变化。

### 暂停并询问用户

- 需要 Apple Developer 账号、Developer ID 或公证凭据。
- 真实验收发现账号冲突、需重新登录或无法恢复初始账号。
- 需要中断真实运行任务或消费真实重置卡。
- 需要覆盖已有 GitHub Release 或删除外部资产。
