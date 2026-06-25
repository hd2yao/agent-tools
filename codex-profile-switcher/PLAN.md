# Plan

## MVP Scope

- Create a dependency-free Python CLI.
- Manage profile directories under `~/.codex-profiles`.
- Start Codex with `CODEX_HOME` set to the selected profile directory.
- Provide `init`, `list`, `use`, `login`, and `doctor` commands.
- Add focused unit tests for path validation and command construction behavior.

## Non-Goals

- No GUI in the first version.
- No automatic account rotation.
- No parsing, printing, copying, or editing OAuth token contents.
- No analytics, telemetry, or network calls beyond the Codex command the user runs.
- No dependency installation or lockfile.

## Acceptance Criteria

- [x] `init <name>` creates `~/.codex-profiles/<name>` with user-only permissions.
- [x] `list` shows profiles and whether `auth.json` exists without printing secrets.
- [x] `use <name>` runs `codex` with `CODEX_HOME` pointed at that profile.
- [x] `login <name>` runs `codex login` with `CODEX_HOME` pointed at that profile.
- [x] `doctor <name>` runs `codex doctor` with `CODEX_HOME` pointed at that profile.
- [x] Invalid profile names are rejected before touching the filesystem.
- [x] Unit tests pass with `python3 -m unittest`.

## Likely Files

- `codex_profile.py`
- `tests/test_codex_profile.py`
- `README.md`
- `PLAN.md`
- `REVIEW.md`
- `docs/plans/2026-06-25-codex-profile-switcher-design.md`
- `docs/plans/2026-06-25-codex-profile-switcher.md`
