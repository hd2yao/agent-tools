# Codex Profile Launch Closure Implementation Plan

> Superseded by `v0.3.0`: Codex Desktop now uses the default-home bridge where
> only `auth.json` is account-specific and `config.toml` is shared local state.
> This older plan is kept as implementation history.

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Codex Profile Switcher the reliable local entry point for account switching while making manual Codex launches visible and recoverable.

**Architecture:** Treat profile switching as a launcher problem: Codex Desktop must inherit the selected `CODEX_HOME` at process start. The switcher records the last managed launch with active profile, profile home, and Codex Desktop pid. The menu bar app compares current Desktop state with that managed launch record, shows whether Codex is managed or manually launched, and offers a one-click launch/restart through the switcher.

**Tech Stack:** Python CLI for profile state and Desktop launch orchestration, Swift/AppKit for menu bar UI, `unittest` for Python behavior checks, `swiftc` for compile verification.

---

### First-Principles Model

Codex account identity lives under `CODEX_HOME`, especially `auth.json` and `config.toml`. Codex Desktop reads `CODEX_HOME` when its long-running process starts. Once Desktop is already running, opening a new window does not reliably change that process environment.

Therefore the switcher cannot make arbitrary manual launches magically correct. It can only:

1. Start Codex Desktop with the chosen profile home.
2. Record that this exact Desktop pid was launched by the switcher.
3. Detect when the current Desktop pid no longer matches the managed launch record.
4. Offer a single repair action: restart/open Codex via the active profile.

This deliberately avoids patching `/Applications/Codex.app`, copying secrets between machines, or pretending the default `~/.codex` path is profile-aware.

### Task 1: Record Managed Desktop Launch Metadata

**Files:**
- Modify: `codex_profile.py`
- Test: `tests/test_codex_profile.py`

**Implementation:**
- Add `codex_desktop_pid()` using System Events to read the Unix pid for process `Codex`.
- Extend `record_active_profile()` with optional `profile_home` and `codex_pid`.
- Store `active_profile`, `profile_home`, `codex_pid`, `managed_launch_at`, and `shared_home`.
- Keep `read_active_profile()` backward compatible with older files containing only `active_profile`.

**Verification:**
- Unit test that launch metadata is stored without exposing auth contents.

### Task 2: Report Desktop Managed Status

**Files:**
- Modify: `codex_profile.py`
- Test: `tests/test_codex_profile.py`

**Implementation:**
- Add `read_active_profile_record()`.
- Add `build_desktop_status()` returning `running`, `managed`, `codex_pid`, `active_profile`, `profile_home`, and `message`.
- Include `desktop_status` in `status --json`.
- `managed` is true only when current Desktop pid matches the recorded managed launch pid.

**Verification:**
- Unit test managed launch when pid matches.
- Unit test manual launch when pid differs.

### Task 3: Add Menu Bar Recovery UI

**Files:**
- Modify: `macos/CodexProfileMenuBar.swift`

**Implementation:**
- Decode `desktop_status`.
- Show a small status line in the header:
  - managed: `托管启动 · <profile>`
  - running but unmanaged: `手动启动 · 建议用账号管家重启`
  - not running: `Codex 未运行 · 可用当前账号打开`
- Add an action row `用当前账号打开 Codex`, calling the same profile launch path as switching.

**Verification:**
- `swiftc macos/CodexProfileMenuBar.swift -framework AppKit`.
- Build and launch the local app.

### Task 4: Fix Account Card Layout

**Files:**
- Modify: `macos/CodexProfileMenuBar.swift`

**Implementation:**
- Increase card and popover height enough to avoid clipping.
- Change footer to a two-line details block plus a fixed-width action button.
- Show `使用：...` on line one and `重置：5小时 ... · 7天 ...` on line two.

**Verification:**
- Compile Swift.
- Launch the app and visually inspect that the footer no longer truncates behind the button.

### Task 5: Document The Closed Loop

**Files:**
- Modify: `README.md`

**Implementation:**
- Document that direct Codex.app launch uses the default `~/.codex` route and is not profile-managed.
- Document the switcher as the reliable entry point.
- Document cross-machine setup: install tool, create profiles, log in locally per machine, share only non-secret code/config workflow.

**Verification:**
- Review README for no secret leakage and no claim that credentials sync across machines.
