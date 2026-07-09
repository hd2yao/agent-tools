# Codex Thread Bridge MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a local MVP for finding Codex threads, generating continuation context packs, and dry-running thread-to-project assignment.

**Architecture:** Add a standalone Python CLI under `codex-thread-bridge/`. It reads local Codex state files in a read-mostly way, composes concise Markdown context packs from SQLite thread metadata, rollout paths, and PreCompact context cards, and only reports assignment changes in dry-run mode for MVP.

**Tech Stack:** Python standard library, `unittest`, SQLite, JSON/JSONL, Markdown output.

---

### Task 1: Thread Inventory And Context Pack Tests

**Files:**
- Create: `codex-thread-bridge/tests/test_thread_bridge.py`
- Create: `codex-thread-bridge/__init__.py`
- Create: `codex-thread-bridge/thread_bridge.py`

**Steps:**
1. Write failing tests for loading thread metadata from `state_5.sqlite`, `.codex-global-state.json`, `session_index.jsonl`, and context-card files.
2. Run `python3 -m unittest -v` from `codex-thread-bridge/`; expect import or missing function failures.
3. Implement the minimum code needed to pass.
4. Run tests again and confirm they pass.

### Task 2: CLI Commands

**Files:**
- Modify: `codex-thread-bridge/thread_bridge.py`
- Create: `codex-thread-bridge/codex_thread_bridge.py`

**Steps:**
1. Write failing tests for `list`, `pack`, and `assign-project --dry-run` behavior.
2. Implement an argparse CLI with JSON and Markdown-friendly text output.
3. Keep `assign-project` read-only unless a future explicit `--apply` is added.
4. Run focused tests.

### Task 3: Documentation

**Files:**
- Create: `codex-thread-bridge/README.md`
- Modify: `README.md`

**Steps:**
1. Document the MVP commands and safety model.
2. Register `codex-thread-bridge` in the top-level tool list.
3. Run smoke commands against the local Codex home.

### Task 4: Verification And Commit

**Commands:**
- `python3 -m unittest -v`
- `python3 codex_thread_bridge.py list --limit 3`
- `python3 codex_thread_bridge.py pack <known-thread-id> --max-events 8`
- `python3 codex_thread_bridge.py assign-project <known-thread-id> --project /Users/dysania/program/tools --json`

**Expected Result:** Tests pass, smoke commands produce no secrets, no tracked changes outside the new tool, top-level README, and this plan.
