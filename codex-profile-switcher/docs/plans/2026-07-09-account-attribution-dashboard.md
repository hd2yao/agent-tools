# Account Attribution Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add account-attributed realtime token estimates and a codexU-inspired glass main dashboard while keeping the menu bar popover compact.

**Architecture:** Python remains the data adapter for Codex app-server, local rollout logs, SQLite history, reset-credit details, and the new attribution ledger. Swift/AppKit consumes the enriched JSON payload, keeps the existing menu bar popover, and adds a separate main dashboard window for detailed analysis.

**Tech Stack:** Python 3 standard library, AppKit Swift, existing unittest suite, existing shell build scripts.

---

### Task 1: Token Attribution Ledger

**Files:**
- Modify: `codex_profile_dashboard.py`
- Modify: `codex_profile.py`
- Test: `tests/test_dashboard.py`
- Test: `tests/test_codex_profile.py`

**Step 1: Write failing tests**

Add tests that prove:

- A switch baseline creates a profile ledger entry with the active profile and local token total.
- A later local snapshot produces a positive `today_estimated_tokens` delta for the active profile.
- Official account daily usage overrides prior-day attribution and returns an accuracy comparison.
- Manual or unknown launches do not silently attribute token deltas.

**Step 2: Run tests and verify failure**

Run:

```bash
python3 -m unittest discover -s codex-profile-switcher/tests
```

Expected: new attribution tests fail because helpers and payload fields do not exist.

**Step 3: Implement minimal backend**

Add:

- `read_attribution_ledger(shared_home)`
- `record_attribution_baseline(shared_home, profile_name, local_snapshot, managed)`
- `summarize_profile_attribution(shared_home, profile_name, local_snapshot, account_usage, now)`
- payload field `token_attribution` per profile
- dashboard-level `attribution_summary`

Store ledger JSON under:

```text
~/.codex/cache/codex-profile-switcher/token-attribution/ledger.json
```

No tokens or auth data are stored.

**Step 4: Run tests and verify pass**

Run the same unittest command.

**Step 5: Commit**

Commit message:

```text
feat: add account token attribution ledger
```

### Task 2: Project and Tool/Skill Local Analytics

**Files:**
- Modify: `codex_profile_dashboard.py`
- Test: `tests/test_dashboard.py`

**Step 1: Write failing tests**

Add tests for:

- SQLite project ranking by `cwd`, `tokens_used`, thread count, latest activity.
- Tool ranking from `thread_dynamic_tools` joined to `threads`.
- Safe empty fallback when SQLite tables are absent.

**Step 2: Run tests and verify failure**

Expected: analytics helpers do not exist.

**Step 3: Implement minimal backend**

Add:

- `read_project_rankings(shared_home)`
- `read_tool_rankings(shared_home)`
- optional `skill_usage` placeholder based on rollout Skill load events when present, otherwise installed-skill counts.

**Step 4: Run tests**

Run dashboard tests and full unittest suite.

**Step 5: Commit**

Commit message:

```text
feat: add local project and tool analytics
```

### Task 3: Compact Menu Bar Popover

**Files:**
- Modify: `macos/CodexProfileMenuBar.swift`

**Step 1: Compile existing Swift**

Run:

```bash
swiftc codex-profile-switcher/macos/CodexProfileMenuBar.swift -framework AppKit -o /tmp/codex-profile-switcher-check
```

Expected: compiles before UI edits.

**Step 2: Implement compact popover**

Keep the popover focused on:

- current account
- runtime status
- 5h/7d quota
- today attribution token
- reset cards
- switch buttons
- open main dashboard action

**Step 3: Compile Swift**

Run the same `swiftc` command.

**Step 4: Commit**

Commit message:

```text
feat: compact menu bar account summary
```

### Task 4: Glass Main Dashboard Window

**Files:**
- Modify: `macos/CodexProfileMenuBar.swift`

**Step 1: Add window controller**

Add `DashboardWindowController` owned by `CodexProfileMenuBarApp`, opened from the popover action.

**Step 2: Add layout views**

Add:

- `MainDashboardViewController`
- top overview section
- tab selector: 今日活动 / 用量趋势 / 项目排行 / 工具&Skill
- reusable glass card views

**Step 3: Wire payload refresh**

When status refreshes, update both popover and main window if open.

**Step 4: Compile Swift**

Run:

```bash
swiftc codex-profile-switcher/macos/CodexProfileMenuBar.swift -framework AppKit -o /tmp/codex-profile-switcher-check
```

**Step 5: Commit**

Commit message:

```text
feat: add glass dashboard window
```

### Task 5: Build, Install, Screenshot Verify, Release Bump

**Files:**
- Modify: `README.md`
- Modify: `build-menubar-app.sh` if version metadata is hardcoded there

**Step 1: Run full validation**

Run:

```bash
python3 -m unittest discover -s codex-profile-switcher/tests
python3 -m py_compile codex-profile-switcher/codex_profile.py codex-profile-switcher/codex_profile_dashboard.py
swiftc codex-profile-switcher/macos/CodexProfileMenuBar.swift -framework AppKit -o /tmp/codex-profile-switcher-check
```

**Step 2: Build and install local app**

Run existing build/install scripts.

**Step 3: Visual QA**

Launch app, capture screenshots for:

- menu bar popover
- main dashboard overview
- each dashboard tab where practical

Check no clipped text, no oversized vertical popover, and transparent glass style is visible.

**Step 4: Commit and tag**

Use version `v0.8.0` if validation passes.
