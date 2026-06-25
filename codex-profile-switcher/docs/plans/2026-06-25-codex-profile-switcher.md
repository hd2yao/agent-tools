# Codex Profile Switcher Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a dependency-free CLI that launches Codex with named `CODEX_HOME` profile directories.

**Architecture:** The tool is a single Python module with pure helper functions and a small argparse CLI. Profile directories live under `~/.codex-profiles`, and Codex is launched by passing a modified environment to `subprocess.run`.

**Tech Stack:** Python 3 standard library, `unittest`, local Codex CLI.

---

### Task 1: Core Helpers and Tests

**Files:**
- Create: `codex_profile.py`
- Create: `tests/test_codex_profile.py`
- Modify: `REVIEW.md`

**Step 1: Write the failing tests**

Add tests for:

- accepting profile names like `account-a`, `work_2`, and `personal.2026`
- rejecting empty names, path traversal, slashes, spaces, and shell metacharacters
- resolving profile paths under a configurable root
- detecting `auth.json` and `config.toml` existence without reading contents
- building the Codex command environment with `CODEX_HOME`

**Step 2: Run test to verify it fails**

Run: `python3 -m unittest -v`

Expected: FAIL because `codex_profile.py` does not exist yet.

**Step 3: Write minimal implementation**

Create helper functions:

- `validate_profile_name(name: str) -> str`
- `profile_path(root: Path, name: str) -> Path`
- `ensure_profile(root: Path, name: str) -> Path`
- `profile_status(path: Path) -> dict[str, bool]`
- `build_codex_env(base_env: Mapping[str, str], home: Path) -> dict[str, str]`

**Step 4: Run test to verify it passes**

Run: `python3 -m unittest -v`

Expected: PASS.

### Task 2: CLI Commands

**Files:**
- Modify: `codex_profile.py`
- Modify: `tests/test_codex_profile.py`
- Modify: `README.md`
- Modify: `REVIEW.md`

**Step 1: Write command tests**

Add tests for parser behavior and non-secret list output using a temporary
profile root.

**Step 2: Run test to verify it fails**

Run: `python3 -m unittest -v`

Expected: FAIL until CLI command handlers exist.

**Step 3: Implement CLI**

Add argparse subcommands:

- `init <name>`
- `list`
- `use <name> [-- <codex args...>]`
- `login <name>`
- `doctor <name>`

`use`, `login`, and `doctor` must run the installed `codex` binary with
`CODEX_HOME` set to the selected profile directory.

**Step 4: Verify**

Run:

```bash
python3 -m unittest -v
python3 codex_profile.py --help
python3 codex_profile.py init smoke-test
python3 codex_profile.py use smoke-test -- --version
```

Expected: tests pass, help renders, profile is created, and Codex prints a version.

### Task 3: Documentation and Review

**Files:**
- Modify: `README.md`
- Modify: `PLAN.md`
- Modify: `REVIEW.md`

**Step 1: Update docs**

Record run instructions, verification results, and current status.

**Step 2: Run focused review**

Review the diff for:

- secret exposure
- unsafe profile path handling
- accidental network or telemetry behavior
- missing verification notes

**Step 3: Final status**

Run: `git status --short` in both the independent project and the original workspace.

Expected: independent project is not a git repository unless initialized later;
original workspace has no tracked edits from this task.
