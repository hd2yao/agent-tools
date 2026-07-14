# Codex 工具台任务拆分

- [ ] **T001 项目骨架与构建契约**  
  映射：AC-001、AC-011  
  验收：Swift package 可测试，可封装为正常 `.app`。  
  验证：`swift test`、`./build-app.sh`、`plutil -lint`。

- [ ] **T002 事件模型与 JSONL 仓库**  
  映射：AC-003、AC-004、AC-006、AC-009、AC-012  
  验收：支持解码、坏行容错、倒序、日期分组、筛选、去重和脱敏字段。  
  验证：Core 单元测试。

- [ ] **T003 本地证据补扫**  
  映射：AC-003、AC-004、AC-009  
  验收：可从已有 ledger/context card/reset outcome 生成标注证据与置信度的事件。  
  验证：fixture 测试和本机只读 dry-run。

- [ ] **T004 账号模块适配器**  
  映射：AC-007、AC-012  
  验收：读取打包后的 Profile Switcher payload，展示状态并通过既有 `app <profile>` 路径切换。  
  验证：payload 解码测试、命令参数契约测试、手动状态加载。

- [ ] **T005 原生 App Shell 与 Design System**  
  映射：AC-002、AC-010、AC-011  
  验收：侧栏/toolbar/内容表面满足 `DESIGN.md`，窗口三档响应稳定。  
  验证：编译、最小/默认/宽屏截图。

- [ ] **T006 概览、日志、账号三页**  
  映射：AC-002 至 AC-007、AC-009 至 AC-011  
  验收：三页真实可用，日志可筛选、选择和展开，账号状态不混淆。  
  验证：Core 测试、交互检查、页面截图。

- [ ] **T007 菜单栏、Codex 联动与任务深链**  
  映射：AC-005、AC-008  
  验收：菜单栏快捷面板、打开 Codex、打开工具台、有效任务跳转可用。  
  验证：URL 构造测试和本机交互验证。

- [ ] **T008 安装、文档、视觉与收敛验收**  
  映射：AC-001 至 AC-012  
  验收：安装到用户 Applications，产物身份可核验，Visual Verdict ≥ 90。  
  验证：全量测试、freshness 验证、浅/深色截图、AC 对照表。
