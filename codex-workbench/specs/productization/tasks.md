# Codex 工作台产品化与公开发行任务拆分

- [x] **T001 固定产品化基线与冷备**
  映射：AC-PD-001、AC-PD-011
  验收：记录当前工作台与 Profile Switcher 产物、源码、hash、进程和恢复路径；不读取凭据正文。
  验证：git / bundle / hash / process 清单与恢复演练说明；证据见 `docs/productization-baseline.md` 与 `docs/profile-switcher-cold-backup.md`。

- [x] **T002 本机单账号后端契约**
  映射：AC-PD-003、AC-PD-004、AC-PD-011
  验收：无 profiles 时返回 `local_default` 只读账号；不创建 profile、active record 或软链；Profiles fixture 无回归。
  验证：Python RED/GREEN、临时目录文件树 diff、完整 Python tests。

- [x] **T003 Swift 双模式账号展示与自动化门禁**
  映射：AC-PD-003、AC-PD-004、AC-PD-007
  验收：Core 解码 account mode，正确选择本机 / profile 当前账号；单账号无切换区且不自动消费卡。
  验证：Core RED/GREEN、payload fixture、Coordinator policy 测试。

- [x] **T004 自包含 arm64 账号后端**
  映射：AC-PD-008、AC-PD-011、AC-PD-013
  验收：PyInstaller onedir helper 在没有外部 Python 的环境中执行；所有 Mach-O 为 arm64；Release Gateway 无外部 Python 回退。
  验证：脚本测试、`file`、清空 PATH smoke、payload fixture、license notice。

- [x] **T005 当前账号安全重启**
  映射：AC-PD-005、AC-PD-007、AC-PD-011
  验收：空闲直接执行，高风险确认，取消无副作用；后端安全重启并验证；日志不含凭据。
  验证：Python / Core RED/GREEN、AppModel 注入测试、空闲真实重启。

- [x] **T006 诊断与修复**
  映射：AC-PD-006、AC-PD-011、AC-PD-012
  验收：可点击诊断 sheet 显示真实脱敏结果和安全动作；识别重复官方 App；无删除 / 认证修复。
  验证：Core fixture、App 服务注入、AX、当前机器真实诊断截图。

- [x] **T007 信息架构与工作区目录**
  映射：AC-PD-002、AC-PD-012
  验收：五模块侧栏；项目与任务、工具与自动化包含合并后的真实数据；上下文状态不虚构。
  验证：Core presentation 测试、源码行为测试、三档窗口截图。

- [x] **T008 产品命名、安装和冷备迁移**
  映射：AC-PD-001、AC-PD-013
  验收：App 显示名为 Codex 工作台；旧观测站原子迁移；失败恢复；用户目录不变。
  验证：临时 install root 脚本测试、bundle metadata、覆盖安装 smoke。

- [ ] **T009 Developer ID、DMG 与手动 Release 工具链**
  映射：AC-PD-008、AC-PD-009、AC-PD-010
  验收：arm64 DMG、SHA、内外签名、公证、fail-closed 发布脚本；无更新器。
  验证：无凭据失败、结构性 DMG、SHA、arm64、Mach-O `minos <= 13.0`、独立 `codex-workbench-v<version>` tag 和显式发布门禁已通过；正式 `codesign` / `spctl` / `notarytool` / `stapler` 等待 Developer ID 与 notary profile。

- [x] **T010 真实行为、视觉和无障碍验收**
  映射：AC-PD-004 至 AC-PD-007、AC-PD-011、AC-PD-012
  验收：双向切换恢复初始账号；空闲重启；诊断；菜单栏和页面关键状态截图通过。
  验证：正式安装产物、AX、10 张截图、运行身份和操作日志通过；本轮 runtime 为 running，按安全契约未强制真实重启，重启事务由自动化与受控夹具验收。

- [ ] **T011 干净用户与 DMG 验收**
  映射：AC-PD-003、AC-PD-008、AC-PD-009、AC-PD-013
  验收：无 Python / Homebrew / profiles 的 Apple Silicon 干净用户可直接安装并识别默认账号；覆盖安装保留数据。
  验证：隔离 HOME 文件树前后 diff、自包含运行、结构性 DMG 挂载/覆盖/arm64/SHA 已通过；正式 Gatekeeper 放行等待签名公证。

- [ ] **T012 文档、GitHub Release 与收敛**
  映射：AC-PD-001 至 AC-PD-013
  验收：README、安装 / 手动升级 / 隐私 / 冷备 / 发行说明与真实产物一致；全部 AC 收敛；有凭据后才创建 Release。
  验证：文档、全量门禁、focused diff、任务状态与待发布说明继续收敛；正式 Release 资产和 GitHub 发布等待外部门禁。
