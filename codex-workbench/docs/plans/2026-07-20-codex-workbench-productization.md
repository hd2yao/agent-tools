# Codex 工作台产品化与公开发行 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 Codex 工作台收敛为唯一日常 App，兼容默认单账号与既有 Profiles，补齐安全重启、真实诊断和合并模块，并产出只支持 Apple Silicon、可从 GitHub Releases 手动下载安装的自包含公证 DMG。

**Architecture:** 现有 Python Profile 后端继续负责账号与切换，但新增 `local_default` 只读模式并冻结为 App 内 `arm64` onedir helper。Swift Core 承载模式、重启风险、验证、诊断和工作区展示契约，SwiftUI/AppKit 承载系统探测和界面；发行脚本从内到外签名，创建并公证 DMG，最后以显式参数发布 GitHub Release。

**Tech Stack:** Swift 6、SwiftUI、AppKit、Python 3 标准库、PyInstaller 6.21 onedir、bash、Developer ID、`notarytool`、`hdiutil`、GitHub CLI。

---

## 实施前提

- 已批准设计：`docs/plans/2026-07-20-codex-workbench-productization-design.md`。
- Spec / 契约：`specs/productization/`。
- 当前机器 `security find-identity -v -p codesigning` 返回 0 个有效身份。Task 1–8、无凭据发行门禁和测试 DMG 可以继续；真实公证与 GitHub 正式 Release 必须等待 Developer ID 和 notary profile。
- 发行参考：[PyInstaller macOS usage](https://pyinstaller.org/en/stable/usage.html)、[Apple distribution signing](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/)、[Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)。
- 下列命令块都从仓库根目录开始执行；同一命令块内的 `cd` 会持续生效，不跨命令块继承。

### Task 1：固定基线、冷备与任务门禁

**Files:**
- Modify: `codex-workbench/docs/profile-switcher-cold-backup.md`
- Create: `codex-workbench/docs/productization-baseline.md`
- Modify: `codex-workbench/specs/productization/tasks.md`

**Step 1：记录只读基线**

运行：

```bash
git status --short --branch
git rev-parse HEAD
codesign -dvv "$HOME/Applications/Codex 观测站.app" 2>&1 || true
codesign -dvv "$HOME/Applications/Codex Profile Switcher.app" 2>&1 || true
shasum -a 256 "$HOME/Applications/Codex 观测站.app/Contents/MacOS/CodexWorkbenchApp"
pgrep -lf 'Codex 观测站|Codex Profile Switcher' || true
```

Expected：只输出 bundle 身份、hash 和进程；不输出认证内容。

**Step 2：更新冷备文档**

在 `docs/profile-switcher-cold-backup.md` 写入当前稳定源码提交、App 路径、二进制 hash、默认退出要求和恢复顺序。不要复制 `auth.json`。

**Step 3：建立产品化基线文档**

`docs/productization-baseline.md` 至少记录：当前 App 名 / bundle id / 版本 / 架构、当前外部 Python 依赖、签名身份缺口、公开发行门禁和恢复入口。

**Step 4：复核范围**

运行：

```bash
rg -n 'Intel|Universal|App Store|Homebrew|自动更新|新增账号' \
  codex-workbench/specs/productization \
  codex-workbench/docs/plans/2026-07-20-codex-workbench-productization*.md
```

Expected：这些内容只出现在明确非目标、限制或禁止项中。

**Step 5：提交**

```bash
git add codex-workbench/docs/profile-switcher-cold-backup.md \
  codex-workbench/docs/productization-baseline.md \
  codex-workbench/specs/productization/tasks.md
git commit -m "docs: freeze productization baseline"
```

### Task 2：本机单账号 Python payload

**Files:**
- Modify: `codex-profile-switcher/codex_profile_dashboard.py:1679-1847`
- Modify: `codex-profile-switcher/codex_profile.py:977-993`
- Modify: `codex-profile-switcher/tests/test_dashboard.py`
- Modify: `codex-profile-switcher/tests/test_codex_profile.py`

**Step 1：写失败的单账号测试**

在 `test_dashboard.py` 使用临时 `shared_home`，不创建 profile root 内的目录；注入 remote reader：

```python
def test_default_home_becomes_read_only_local_account_when_profiles_are_absent(self):
    shared_home = self.root / ".codex"
    shared_home.mkdir()
    (shared_home / "auth.json").write_text("{}", encoding="utf-8")
    before = sorted(path.relative_to(shared_home) for path in shared_home.rglob("*"))

    payload = build_profiles_payload(
        self.root / ".codex-profiles",
        shared_home,
        remote_reader=lambda home: remote_snapshot(remaining=43),
    )

    self.assertEqual(payload["account_mode"], "local_default")
    self.assertEqual(payload["active_profile"], "local-default")
    self.assertEqual([row["name"] for row in payload["profiles"]], ["local-default"])
    self.assertEqual(payload["profiles"][0]["path"], str(shared_home))
    self.assertEqual(before, sorted(path.relative_to(shared_home) for path in shared_home.rglob("*")))
```

同时增加：Profiles 存在时为 `managed_profiles`；默认 home 不存在时为 `unavailable`；本机账号不创建 active record / symlink。

**Step 2：运行测试确认失败**

Run：

```bash
cd codex-profile-switcher
python3 -m unittest -v tests.test_dashboard tests.test_codex_profile
```

Expected：FAIL，缺少 `account_mode` 或 profiles 为空。

**Step 3：最小实现 account source 列表**

在 `build_profiles_payload` 将“磁盘 profile 路径”与“payload 名称”分离：

```python
managed_paths = sorted(path for path in profile_root.iterdir() if path.is_dir()) \
    if profile_root.exists() else []
if managed_paths:
    account_mode = "managed_profiles"
    account_sources = [(path.name, path) for path in managed_paths]
elif shared_home.is_dir():
    account_mode = "local_default"
    account_sources = [("local-default", shared_home)]
else:
    account_mode = "unavailable"
    account_sources = []
```

所有 cache key、remote reader、reset details 和 output name 使用逻辑名称；文件读取使用实际 home。`local_default` 只读，不记录 attribution baseline，不进入 profile bridge repair。

App Server 不得直接写默认 home，也不得把认证正文复制到临时文件。读取时在权限为 0700 的临时 `CODEX_HOME` 中只建立指向原 `auth.json` 的短生命周期符号链接，并用 `/usr/bin/sandbox-exec` 禁止子进程写入原默认 home、认证实际目标和临时 home 的其他路径；只允许已核实的状态 SQLite 文件与 `installation_id` 写入，`auth.json` 原子替换和任意未知暂存文件都必须失败。沙盒不可用或无法建立链接时返回账号不可用，不回退为复制或直接运行。

**Step 4：让 status 顶层语义一致**

`build_status_payload` 根据 `account_mode` 设置：

```python
if payload["account_mode"] == "local_default":
    payload["active_profile"] = "local-default"
    payload["desktop_status"] = {
        **build_desktop_status(),
        "active_profile": "local-default",
        "state": "local_default",
        "message": "使用本机默认 Codex 账号",
    }
```

不得把 `managed` 改成 true；Swift 用显式模式确认本机账号。

**Step 5：运行 Python 全量测试**

```bash
cd codex-profile-switcher
python3 -m unittest -v
```

Expected：PASS；临时 home 文件树无新增 profile / bridge 文件。

**Step 6：提交**

```bash
git add codex-profile-switcher/codex_profile.py \
  codex-profile-switcher/codex_profile_dashboard.py \
  codex-profile-switcher/tests/test_codex_profile.py \
  codex-profile-switcher/tests/test_dashboard.py
git commit -m "feat: detect the local default Codex account"
```

### Task 3：Swift 双模式账号契约与自动化门禁

**Files:**
- Modify: `codex-workbench/Sources/CodexWorkbenchCore/AccountModels.swift:478-520`
- Modify: `codex-workbench/Sources/CodexWorkbenchCore/AccountPresentation.swift:95-200`
- Modify: `codex-workbench/Sources/CodexWorkbenchCore/AccountRuntimePolicy.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/AutomaticResetCoordinator.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/AccountPresentationTests.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/AccountDetailPresentationTests.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/AccountRuntimePolicyTests.swift`

**Step 1：写失败的模式解码与展示测试**

增加 `local_default` fixture：desktop `managed=false`、Codex 可关闭、profiles 只有 `local-default`。断言：

```swift
runner.expect(payload?.accountMode == .localDefault, "Local default mode must decode")
runner.expect(
    AccountPresentationBuilder.confirmedCurrentProfileName(payload: payload) == "local-default",
    "The default home account is confirmed by its explicit mode"
)
runner.expect(
    AccountPresentationBuilder.menu(payload: payload).profileDisplayName == "本机当前账号",
    "Synthetic internal keys must not leak into UI"
)
runner.expect(
    AccountPresentationBuilder.details(payload: payload).otherProfiles.isEmpty,
    "Local mode must not expose a switch target"
)
```

增加策略断言：`.localDefault` 的自动重置 availability 为只读禁用，`.managedProfiles` 保持现状。

**Step 2：运行 Core 测试确认失败**

```bash
cd codex-workbench
./test.sh
```

Expected：FAIL，缺少 `AccountMode`。

**Step 3：实现可向后兼容的模式模型**

```swift
public enum AccountMode: String, Codable, Equatable, Sendable {
    case managedProfiles = "managed_profiles"
    case localDefault = "local_default"
    case unavailable

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .unavailable
    }
}
```

`AccountDashboardPayload.accountMode` 为可选解码并对旧 payload 推导 `.managedProfiles`；不得破坏旧 fixture。

**Step 4：实现当前账号选择和 UI 名称**

- `managedProfiles` 继续要求 running + managed + active 一致。
- `localDefault` 要求 `activeProfile == "local-default"` 且存在对应 account profile；不要求 desktop managed / running。
- `profileDisplayName("local-default")` 返回“本机当前账号”。
- `otherProfiles` 永远过滤 synthetic local key。

**Step 5：阻止单账号自动消费**

在 Core policy 返回 `.readOnlyLocalAccount`，Coordinator 在调用 backend 前再次 guard。Profiles 现有 policy 与 tests 不改语义。

**Step 6：运行测试并提交**

```bash
cd codex-workbench
./test.sh
swift build
git add Sources Tests
git commit -m "feat: support local and managed account modes"
```

Expected：Core tests 和 Swift build PASS。

### Task 4：自包含 arm64 账号后端

**Files:**
- Create: `codex-workbench/requirements-build.txt`
- Create: `codex-workbench/scripts/bootstrap-release-tools.sh`
- Create: `codex-workbench/scripts/build-account-backend.sh`
- Create: `codex-workbench/Tests/Scripts/test-account-backend-bundle.sh`
- Create: `codex-workbench/THIRD_PARTY_NOTICES.md`
- Modify: `codex-workbench/Sources/CodexWorkbenchCore/AccountGateway.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/AccountGatewayTests.swift`
- Modify: `codex-workbench/build-app.sh`
- Modify: `codex-workbench/verify-install.sh`

**Step 1：写失败的 Gateway 路径测试**

把 `AccountCommandBuilder` 改测为“可执行文件 + 固定参数前缀”：

```swift
let frozen = AccountCommandBuilder(
    executableURL: URL(fileURLWithPath: "/App/Contents/Helpers/CodexAccountBackend/CodexAccountBackend"),
    argumentPrefix: []
)
runner.expect(frozen.statusCommand(refreshResetCredits: false).arguments == ["status", "--json"])

let development = AccountCommandBuilder(
    executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
    argumentPrefix: ["/repo/codex_profile.py"]
)
runner.expect(development.statusCommand(refreshResetCredits: false).arguments.first == "/repo/codex_profile.py")
```

`AccountBackendLocator.bundled` 必须只接受包内 executable，不调用 `resolvePython()`。

**Step 2：运行 Core 测试确认失败**

```bash
cd codex-workbench && ./test.sh
```

Expected：FAIL，现有 builder 仍需要 pythonURL / helperURL。

**Step 3：实现通用命令 builder**

移除 Release 对 Python 的查找；保留 `development(repositoryRoot:)` 的 Python 候选，仅用于源码运行。`run` 只验证 command executable 和明确传入的 required resource。

**Step 4：写失败的 bundle smoke**

`test-account-backend-bundle.sh` 要求：

```bash
[[ -x "$BACKEND/CodexAccountBackend" ]]
file "$BACKEND/CodexAccountBackend" | grep -q 'arm64'
! file "$BACKEND/CodexAccountBackend" | grep -q 'x86_64'
env -i HOME="$fixture_home" PATH=/usr/bin:/bin \
  "$BACKEND/CodexAccountBackend" --help >/dev/null
```

Expected：构建脚本存在前 FAIL。

**Step 5：实现 pinned PyInstaller onedir 构建**

`requirements-build.txt`：

```text
pyinstaller==6.21.0
```

`build-account-backend.sh` 使用受控 venv 和：

```bash
python -m PyInstaller --clean --noconfirm --onedir \
  --target-arch arm64 --noupx \
  --name CodexAccountBackend \
  --paths "$ACCOUNT_SOURCE_DIR" \
  --hidden-import codex_profile_dashboard \
  --distpath "$DIST_DIR" --workpath "$WORK_DIR" --specpath "$SPEC_DIR" \
  "$ACCOUNT_SOURCE_DIR/codex_profile.py"
```

不要使用 onefile。bootstrap 脚本是显式开发动作，不在普通 `build-app.sh` 中静默联网安装依赖。

**Step 6：修改 App 组装和 verifier**

- 复制 onedir 到 `Contents/Helpers/CodexAccountBackend/`。
- 不再把两个 `.py` 当作 Release runtime；源码 fingerprint 仍覆盖源后端。
- verifier 检查主 helper、arm64、无 x86_64、包内 fingerprint 和无外部 Python fallback。

**Step 7：记录第三方 notices**

只写 CPython、PyInstaller 及随 bundle 收集组件的许可证来源；不要擅自给整个仓库选择开源许可证。

**Step 8：运行测试并提交**

```bash
cd codex-workbench
./scripts/bootstrap-release-tools.sh
./scripts/build-account-backend.sh
./Tests/Scripts/test-account-backend-bundle.sh
./test.sh
./build-app.sh
git add requirements-build.txt scripts Tests/Scripts THIRD_PARTY_NOTICES.md \
  Sources/CodexWorkbenchCore/AccountGateway.swift \
  Tests/CodexWorkbenchCoreTests/AccountGatewayTests.swift \
  build-app.sh verify-install.sh
git commit -m "build: bundle the account backend for arm64"
```

Expected：helper smoke、Core、App build PASS；普通 App runtime 不需要外部 Python。

### Task 5：当前账号安全重启

**Files:**
- Modify: `codex-profile-switcher/codex_profile.py`
- Modify: `codex-profile-switcher/tests/test_codex_profile.py`
- Create: `codex-workbench/Sources/CodexWorkbenchCore/AccountRestartPolicy.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchCore/AccountGateway.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchCore/AccountOperationEventFactory.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/AccountRestartPolicyTests.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/AccountGatewayTests.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/main.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/AppModel.swift`

**Step 1：写失败的 Python restart tests**

覆盖：Profiles 当前账号调用现有 `cmd_app` 路径；local default 安全 quit → wait → default home launch → wait；退出 / 启动超时使用现有 stderr 文案，且不写 profile bridge。

**Step 2：运行 Python 测试确认失败**

```bash
cd codex-profile-switcher
python3 -m unittest -v tests.test_codex_profile
```

Expected：FAIL，parser 没有 `restart`。

**Step 3：实现后端 restart**

新增 CLI：

```text
codex-profile restart [--profile <existing-profile>]
```

- 有 profile：复用 `cmd_app(restart=True)`。
- 无 profile：不接触 bridge，安全退出后调用默认 home `codex app` 并验证启动。

**Step 4：写失败的 Core policy / verifier tests**

```swift
runner.expect(AccountRestartPolicy.decision(runtimeState: "idle") == .restartNow)
runner.expect(AccountRestartPolicy.decision(runtimeState: "running") == .confirm(.runningTask))
runner.expect(AccountRestartPolicy.decision(runtimeState: "waiting") == .confirm(.waitingTask))
runner.expect(AccountRestartPolicy.decision(runtimeState: "unknown") == .confirm(.unknownState))
```

增加 command args、Profiles 原账号验证、local mode 验证和日志事件脱敏测试。

**Step 5：实现 Core 与 AppModel 状态机**

- 新增 `AccountRestartStage`：preparing / quitting / launching / verifying。
- `requestRestartCurrentCodex()` 设置 confirmation 或立即调用。
- `confirmRestartCurrentCodex()` 执行 gateway，刷新 payload，验证并记录事件。
- 取消只清 confirmation，并写 `restart_cancelled` routine event。
- 账号 switch / restart 互斥。

**Step 6：运行相关测试并提交**

```bash
cd codex-profile-switcher && python3 -m unittest -v
cd ../codex-workbench && ./test.sh && swift build
git add ../codex-profile-switcher/codex_profile.py \
  ../codex-profile-switcher/tests/test_codex_profile.py \
  Sources Tests
git commit -m "feat: safely restart the current Codex account"
```

### Task 6：真实诊断与安全动作

**Files:**
- Create: `codex-workbench/Sources/CodexWorkbenchCore/WorkbenchDiagnostics.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/WorkbenchDiagnosticsTests.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/main.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/AccountRuntimeServices.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/CodexIntegrationService.swift`
- Create: `codex-workbench/Sources/CodexWorkbenchApp/DiagnosticsView.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/AccountsView.swift:588-636`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/AppModel.swift`

**Step 1：写失败的脱敏诊断测试**

fixture 同时包含 `/Applications/ChatGPT.app`、`/Applications/Codex.app`、同 bundle id、不同 Launch Services selected path。断言：

```swift
runner.expect(snapshot.findings.contains { $0.id == "duplicate-codex-apps" && $0.level == .warning })
runner.expect(!snapshot.copyableSummary.contains("auth.json"), "Diagnostic summary must not expose auth file names")
runner.expect(!snapshot.copyableSummary.contains("token"), "Diagnostic summary must remain redacted")
```

覆盖只有一个 App、未安装、backend missing、local / profiles、最近失败。

**Step 2：运行 Core 测试确认失败**

```bash
cd codex-workbench && ./test.sh
```

Expected：FAIL，缺少 diagnostics 类型。

**Step 3：实现 Core builder**

定义 `DiagnosticFinding`、`DiagnosticLevel`、`WorkbenchDiagnosticInput` 和 builder。路径展示只允许 app 名、位置类别（系统 Applications / 用户 Applications / 其他）与脱敏 hash，不复制认证路径。

**Step 4：实现可注入的 App 探测**

- 使用 `NSWorkspace.urlForApplication(withBundleIdentifier:)`、running applications 和常见 Applications 路径交叉收集。
- 用 `Bundle(url:)` 读取 bundle id / version。
- 检查默认 home 类别、profile count、bundled backend executable 和最近错误阶段。
- Finder reveal 和 clipboard 只接受 builder 输出的安全目标 / 摘要。

**Step 5：实现 UI**

- 将旧 `DisclosureGroup("高级诊断")` 改为“账号来源说明”。
- 增加“打开诊断与修复”按钮及 sheet。
- sheet 含刷新、打开 Codex、重启、Finder 显示、复制脱敏摘要。
- 不增加删除 / 修复认证 / 新增账号按钮。

**Step 6：测试、AX smoke 和提交**

```bash
cd codex-workbench
./test.sh
swift build
git add Sources Tests
git commit -m "feat: add actionable workbench diagnostics"
```

Expected：Core / build PASS；后续视觉批次验证真实可点击性。

### Task 7：侧栏合并与真实工作区目录

**Files:**
- Modify: `codex-workbench/Sources/CodexWorkbenchCore/AppContracts.swift:1-27`
- Create: `codex-workbench/Sources/CodexWorkbenchCore/WorkspaceCatalogPresentation.swift`
- Create: `codex-workbench/Tests/CodexWorkbenchCoreTests/WorkspaceCatalogPresentationTests.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/AppContractsTests.swift`
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/main.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/AppModel.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/WorkbenchShell.swift:68-139`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/ProjectsView.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/ToolsSkillsView.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/OverviewView.swift`

**Step 1：写失败的模块和目录 tests**

断言模块标题恰为：概览、操作日志、账号管理、项目与任务、工具与自动化。

用 `CodexMetadataCatalog`、context cards 和 workflow files fixture 断言：

- 最近 threads 按 updatedAt 排序并按 project 分组；
- `sourceThreadID` 标识接续关系；
- 只有实际 context card 才显示“有摘要”；缺少不显示伪健康分数；
- hooks / automations 由 `WorkflowFileKind` 分类，展示真实 name / status / schedule。

**Step 2：运行 Core 测试确认失败**

```bash
cd codex-workbench && ./test.sh
```

Expected：FAIL，旧模块名和 presentation 缺失。

**Step 3：发布最小 evidence snapshot**

`WorkbenchAppModel` 从现有 `LedgerRefreshResult.snapshot` 保存 thread catalog、context cards 和 workflow files 的只读视图；visual fixture 可以注入确定性数据。

**Step 4：删除“即将推出”并重做两页**

- `WorkbenchShell` 删除未来 section。
- `ProjectsView` 标题改“项目与任务”，保留项目统计并增加最近任务 / 对话；点击调用 `openThread`。
- `ToolsSkillsView` 标题改“工具与自动化”，保留 tools / skills 并增加 hooks / automations。
- `OverviewView` 只展示证据读取警告和摘要覆盖事实。

**Step 5：运行测试和 build**

```bash
cd codex-workbench
./test.sh
swift build
```

Expected：PASS；`rg -n '即将推出' Sources` 无结果。

**Step 6：提交**

```bash
git add codex-workbench/Sources codex-workbench/Tests
git commit -m "feat: consolidate workbench modules"
```

### Task 8：重启 UI、账号页和菜单栏

**Files:**
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/AccountsView.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/MenuBarView.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/WorkbenchShell.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/DesignSystem.swift` only if an existing token cannot express the approved layout
- Modify: `codex-workbench/Tests/CodexWorkbenchCoreTests/WorkbenchVisualAcceptanceTests.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchCore/WorkbenchVisualAcceptance.swift`

**Step 1：写失败的视觉 fixture / source behavior tests**

覆盖 local account、managed profiles、restart confirmation、restart progress、diagnostic sheet。断言 single account fixture 没有其他账号；菜单栏和账号页都有重启 action。

**Step 2：运行测试确认失败**

```bash
cd codex-workbench && ./test.sh
```

Expected：FAIL，缺少 restart / local visual states。

**Step 3：按 Design Lock 实现 UI**

- 当前账号卡片右上提供“重启 Codex”。
- 菜单栏在账号详情 / 打开工作台之外增加紧凑的“重启”。
- `.confirmationDialog` 明确运行中 / 待接手 / 未知风险。
- restart stage 显示具体阶段并禁用切换 / 重复重启。
- local mode 隐藏 switcher section；Profiles 保持当前布局。

**Step 4：做基础无障碍检查**

重启、确认、取消、诊断、复制摘要都有 AX label / hint；进度与结果不只靠颜色。

**Step 5：运行测试并提交**

```bash
cd codex-workbench
./test.sh
swift build
git add Sources Tests
git commit -m "feat: expose restart and local account controls"
```

### Task 9：产品命名、原子安装与冷备迁移

**Files:**
- Modify: `codex-workbench/Resources/Info.plist`
- Modify: `codex-workbench/build-app.sh`
- Modify: `codex-workbench/install-app.sh`
- Modify: `codex-workbench/verify-install.sh`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/WorkbenchShell.swift`
- Modify: `codex-workbench/Sources/CodexWorkbenchApp/MenuBarView.swift`
- Create: `codex-workbench/Tests/Scripts/test-install-migration.sh`
- Modify: `codex-workbench/README.md`

**Step 1：写失败的临时 install-root 测试**

fixture 创建旧 `Codex 观测站.app` marker，安装新 `Codex 工作台.app`。断言成功只留下新 App；模拟 move 失败时恢复旧 App；用户 data root 不变。

**Step 2：运行确认失败**

```bash
cd codex-workbench
./Tests/Scripts/test-install-migration.sh
```

Expected：FAIL，当前 APP_NAME 仍为 Codex 观测站。

**Step 3：改名但保持 identity**

- `CFBundleDisplayName` / `CFBundleName`、窗口标题、build / install / verify APP_NAME 改为“Codex 工作台”。
- bundle id 保持不变，设置 / 账本位置不变。
- 安装脚本识别“Codex 观测站”和“Codex 工具台”，只在 stage 中保留一个可恢复 previous app。

**Step 4：运行构建和迁移测试**

```bash
cd codex-workbench
./Tests/Scripts/test-install-migration.sh
./build-app.sh
file "build/Codex 工作台.app/Contents/MacOS/CodexWorkbenchApp"
```

Expected：PASS；主 binary 只有 arm64；bundle id 未变。

**Step 5：提交**

```bash
git add Resources build-app.sh install-app.sh verify-install.sh Sources README.md Tests/Scripts
git commit -m "refactor: rename the observatory to Codex Workbench"
```

### Task 10：Developer ID 签名、DMG 与 fail-closed 发布脚本

**Files:**
- Create: `codex-workbench/Resources/AccountBackend.entitlements`
- Create: `codex-workbench/Resources/CodexWorkbench.entitlements`
- Create: `codex-workbench/scripts/sign-app.sh`
- Create: `codex-workbench/scripts/create-dmg.sh`
- Create: `codex-workbench/scripts/release.sh`
- Create: `codex-workbench/scripts/publish-github-release.sh`
- Create: `codex-workbench/Tests/Scripts/test-release-guardrails.sh`
- Modify: `codex-workbench/verify-install.sh`
- Modify: `codex-workbench/README.md`

**Step 1：写失败的发布门禁测试**

测试以下输入必须失败且不调用 `gh release create`：缺 version、缺 Developer ID、缺 notary profile、binary 含 x86_64、codesign 失败、stapler 失败、SHA 缺失、未传 `--publish`。

**Step 2：运行确认失败**

```bash
cd codex-workbench
./Tests/Scripts/test-release-guardrails.sh
```

Expected：FAIL，发布脚本尚不存在。

**Step 3：实现从内到外签名**

不要用 `codesign --deep` 进行签名。`sign-app.sh`：

1. 找到 helper 内所有 Mach-O / dylib / framework executable 并签名。
2. 签名 frozen helper 主 binary（最小 Apple Events entitlement 仅在真实需求验证后保留）。
3. 签名 login helper App。
4. 签名主 App，全部使用 `--options runtime --timestamp`。
5. 最后只用 `codesign --verify --deep --strict` 验证。

**Step 4：实现 DMG / 公证**

`create-dmg.sh` 构建 staging：`Codex 工作台.app` + `Applications` symlink，输出：

```text
dist/Codex-Workbench-v<version>-arm64.dmg
dist/Codex-Workbench-v<version>-arm64.dmg.sha256
```

`release.sh` 依次执行 build、架构检查、sign、DMG、`notarytool submit --wait`、`stapler staple/validate`、`spctl -a -vv` 和 `hdiutil verify`。

**Step 5：实现显式 GitHub 发布**

`publish-github-release.sh` 默认只打印将发布的 tag / assets；只有 `--publish` 才执行：

```bash
gh release create "v$VERSION" "$DMG" "$SHA_FILE" \
  --title "Codex 工作台 v$VERSION" \
  --notes-file "$NOTES_FILE"
```

禁止覆盖既有 tag / asset；发现存在时退出并请求用户处理。

**Step 6：运行无凭据门禁**

```bash
cd codex-workbench
./Tests/Scripts/test-release-guardrails.sh
./scripts/release.sh --version 0.3.0 --dry-run
```

Expected：测试 PASS；dry-run 明确报告“缺少 Developer ID / notary profile”，不创建 Release。

**Step 7：提交**

```bash
git add Resources scripts Tests/Scripts verify-install.sh README.md
git commit -m "build: add a notarized arm64 DMG pipeline"
```

### Task 11：真实行为、视觉与无障碍验收

**Files:**
- Modify: `codex-workbench/docs/visual-acceptance.md`
- Create: `codex-workbench/docs/productization-live-acceptance.md`
- Create: `codex-workbench/screenshots/productization/`
- Modify: `codex-workbench/specs/productization/tasks.md`

**Step 1：完整自动化门禁**

```bash
cd codex-profile-switcher && python3 -m unittest -v
cd ../codex-workbench
./test.sh
swift build -c release --arch arm64
./Tests/Scripts/test-account-backend-bundle.sh
./Tests/Scripts/test-install-migration.sh
./Tests/Scripts/test-release-guardrails.sh
./build-app.sh
```

Expected：全部 PASS。

**Step 2：记录真实初始账号和进程**

只记录脱敏名称、runtime、App path / PID；确认没有运行中任务后才进入真实重启。

**Step 3：安装并执行现有 Profiles 验收**

- 退出但不删除旧冷备。
- 安装新工作台。
- 完成初始账号 → 另一账号 → 初始账号；两次验证实际账号。
- 在 idle 状态重启当前 Codex 并验证账号不变。
- running / waiting 风险只用 fixture / 可控测试验证，不中断真实任务。

**Step 4：执行诊断验收**

确认当前机器上的重复 `ChatGPT.app` / `Codex.app` 被识别，实际运行路径和 Launch Services 选择可见；复制摘要无敏感信息。

**Step 5：视觉和 AX**

从正式安装产物截图：菜单栏浅 / 深、账号 local / profiles、重启确认 / 进度 / 错误、诊断 sheet、项目与任务、工具与自动化；窗口 900×640、1160×780、1440×900。

使用 `accessibility-basic-check` 进行底线检查，Visual Verdict 目标 ≥ 90。

**Step 6：更新验收文档并提交**

```bash
git add codex-workbench/docs codex-workbench/screenshots/productization \
  codex-workbench/specs/productization/tasks.md
git commit -m "test: accept workbench productization behavior"
```

### Task 12：干净用户、正式 Release 与收敛

**Files:**
- Modify: `codex-workbench/README.md`
- Modify: `codex-workbench/docs/productization-live-acceptance.md`
- Modify: `codex-workbench/specs/productization/tasks.md`
- Modify: `codex-workbench/specs/productization/execution-contract.md` only if a documented prerequisite or approved behavior changed

**Step 1：创建干净测试用户 / 等价隔离环境**

只在明确安全的测试 home 中准备单个默认 `.codex`；不创建 `.codex-profiles`，不安装 Python / Homebrew，不挂载源码目录。

**Step 2：用 DMG 安装**

- 下载 / 复制 DMG。
- 拖入 Applications。
- 通过 Gatekeeper 打开。
- 断言本机当前账号、额度、状态可见；无 profiles / symlink 新增。
- 用新版覆盖安装，断言本地数据保留。

**Step 3：完成签名、公证门禁**

仅当用户已通过 Keychain 提供 Developer ID 和 notary profile：

```bash
./scripts/release.sh --version "$VERSION" \
  --sign-identity "$CODEX_WORKBENCH_SIGN_IDENTITY" \
  --notary-profile "$CODEX_WORKBENCH_NOTARY_PROFILE"
```

Expected：`codesign`、`spctl`、`notarytool`、`stapler`、`hdiutil`、SHA 全部 PASS。不要在输出或文档中记录凭据。

**Step 4：对抗式发布复核**

- Release notes 明示 Apple Silicon / macOS 13+ / 手动升级。
- DMG 和 SHA 匹配；tag 不存在；git 工作树干净。
- App 没有 Sparkle、GitHub API 轮询、analytics 或更新 daemon。
- 冷备、账号目录和初始账号状态已恢复。

**Step 5：显式创建 GitHub Release**

只有门禁全部通过且用户确认当前版本对外发布时运行：

```bash
./scripts/publish-github-release.sh --version "$VERSION" --publish
```

Expected：GitHub Release 包含 DMG、SHA 和发布说明；不 push 未确认代码，不覆盖现有资产。

**Step 6：收敛、文档与提交**

逐项核对 AC-PD-001 至 AC-PD-013，标记满足 / 部分 / 未满足和证据。若仍缺 Developer ID，只能将 AC-PD-009、010、013 标记为外部门禁，不能宣称正式发布完成。

```bash
git add codex-workbench/README.md codex-workbench/docs \
  codex-workbench/specs/productization
git commit -m "docs: close the workbench productization release"
```

## 全量完成门禁

```bash
cd codex-profile-switcher && python3 -m unittest -v
cd ../codex-workbench
./test.sh
swift build -c release --arch arm64
./Tests/Scripts/test-account-backend-bundle.sh
./Tests/Scripts/test-install-migration.sh
./Tests/Scripts/test-release-guardrails.sh
./build-app.sh
./verify-install.sh
git status --short
```

正式 Release 额外要求：

```bash
file "build/Codex 工作台.app/Contents/MacOS/CodexWorkbenchApp"
codesign --verify --deep --strict --verbose=2 "build/Codex 工作台.app"
spctl -a -vv -t execute "build/Codex 工作台.app"
xcrun stapler validate "dist/Codex-Workbench-v${VERSION}-arm64.dmg"
hdiutil verify "dist/Codex-Workbench-v${VERSION}-arm64.dmg"
shasum -a 256 -c "dist/Codex-Workbench-v${VERSION}-arm64.dmg.sha256"
```

Expected：所有自动化、行为、视觉、架构、签名、公证和 SHA 门禁通过；工作树只包含已审查提交；旧 Profile Switcher 冷备仍可恢复且未并行运行。
