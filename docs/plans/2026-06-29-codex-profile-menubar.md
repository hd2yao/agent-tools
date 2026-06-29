# Codex Profile Menu Bar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native macOS menu bar companion app for Codex Profile Switcher that shows account quota/status and switches Codex Desktop profiles without opening a browser.

**Architecture:** Add a JSON status command to the existing Python CLI, then create a small Swift/AppKit menu bar app that shells out to that CLI. Use a build script to compile Swift and assemble a local unsigned `.app` bundle.

**Tech Stack:** Python 3 standard library, Swift 6, AppKit, macOS `.app` bundle layout, `unittest`.

---

### Task 1: Add CLI JSON Status

**Files:**
- Modify: `codex-profile-switcher/codex_profile.py`
- Modify: `codex-profile-switcher/tests/test_codex_profile.py`

**Steps:**
1. Add a `status` subcommand with `--json`.
2. Implement `cmd_status()` using `build_profiles_payload(get_profile_root(), get_shared_home())`.
3. Print compact JSON to stdout with `ensure_ascii=False`.
4. Add a test that stubs `build_status_payload()` and verifies `main(["status", "--json"])`.
5. Run `python3 -m unittest tests/test_codex_profile.py`.
6. Commit as `Add profile status JSON command`.

### Task 2: Add Swift Menu Bar App

**Files:**
- Create: `codex-profile-switcher/macos/CodexProfileMenuBar.swift`

**Steps:**
1. Create an AppKit app with `NSApplicationDelegate`.
2. Add an `NSStatusItem` with title `Codex`.
3. Resolve the adjacent `codex_profile.py` path from the app bundle first, with a development fallback.
4. Run `python3 codex_profile.py status --json` on refresh.
5. Decode profile names, auth/config state, rate limit windows, credits, and generated time.
6. Rebuild `NSMenu` with account status and switch actions.
7. Run `python3 codex_profile.py app <profile>` when a switch item is clicked.
8. Add Refresh and Quit menu items.

### Task 3: Add App Build Script

**Files:**
- Create: `codex-profile-switcher/build-menubar-app.sh`

**Steps:**
1. Compile Swift with `swiftc`.
2. Create `build/Codex Profile Switcher.app/Contents/MacOS`.
3. Write `Info.plist` with `LSUIElement=true`.
4. Copy the compiled binary into the bundle.
5. Copy `codex_profile.py` and `codex_profile_dashboard.py` into `Contents/Resources/codex-profile-switcher`.
6. Make the script executable.
7. Run `sh -n build-menubar-app.sh`.

### Task 4: Document and Verify

**Files:**
- Modify: `codex-profile-switcher/README.md`

**Steps:**
1. Add menu bar app build/run instructions.
2. Run:
   - `python3 -m py_compile codex_profile.py codex_profile_dashboard.py`
   - `python3 -m unittest tests/test_codex_profile.py tests/test_dashboard.py`
   - `sh -n codex-hd-master codex-hd-sarah-blackwell build-menubar-app.sh`
   - `./build-menubar-app.sh`
   - `open "build/Codex Profile Switcher.app"`
3. Check `git status --short`.
4. Commit as `Add macOS menu bar app`.
5. Push `main`.
