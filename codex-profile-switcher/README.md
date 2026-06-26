# Codex Profile Switcher

A small local CLI for switching Codex accounts while keeping local history shared.

## Goal

Codex official OAuth credentials are stored under `CODEX_HOME`, usually
`~/.codex`. This tool creates named profile directories so different Codex
accounts can keep separate `auth.json` and `config.toml` files while sharing
local chat history and the desktop sidebar project index.

Each profile links these Codex state entries back to the shared Codex home:

```bash
sessions
archived_sessions
history.jsonl
session_index.jsonl
state_5.sqlite
skills
pets
plugins
vendor_imports
computer-use
attachments
generated_images
shell_snapshots
ambient-suggestions
browser
automations
rules
superpowers
worktrees
cache
sqlite/state_5.sqlite
.codex-global-state.json
AGENTS.md
models_cache.json
```

`.codex-global-state.json` is included because Codex Desktop uses it for local
project ordering, saved workspace roots, and thread workspace hints. Without
sharing it, the SQLite history can be shared while the left sidebar still looks
different between accounts.

`skills`, `plugins`, `vendor_imports`, `computer-use`, and `pets` are included
so installed capabilities and custom local UI assets stay visible after
switching accounts. `attachments`, `generated_images`, `shell_snapshots`, and
`session_index.jsonl` keep existing conversations from losing referenced local
resources.

Account identity and runtime-local entries remain profile-specific, including
`auth.json`, `config.toml`, logs, `goals_1.sqlite`, `memories_1.sqlite`,
`installation_id`, `process_manager`, `tmp`, `.tmp`, `*.wal`, `*.shm`, and
`chrome-native-hosts*.json`.

By default the shared Codex home is `~/.codex`. Set `CODEX_SHARED_HOME` to use
another shared history location.

The tool does not read, print, copy, or modify token contents.

## MVP Commands

```bash
python3 codex_profile.py init account-a
python3 codex_profile.py list
python3 codex_profile.py login account-a
python3 codex_profile.py app account-a
python3 codex_profile.py use account-a -- --version
python3 codex_profile.py doctor account-a
```

Profiles are stored in:

```bash
~/.codex-profiles/<profile-name>
```

## Typical Flow

Create two profiles:

```bash
python3 codex_profile.py init account-a
python3 codex_profile.py init account-b
```

Log in to each account once:

```bash
python3 codex_profile.py login account-a
python3 codex_profile.py login account-b
```

Launch Codex with a profile:

```bash
python3 codex_profile.py app account-a
```

`app` quits an already-running Codex Desktop app before opening it again. This
matters because the Desktop app has a long-running `app-server` process; if it
is already running, simply opening a new window can keep the old `CODEX_HOME`
environment and appear to switch back to the previous account.

Use `--no-restart` only when you intentionally want to reuse the existing app
process:

```bash
python3 codex_profile.py app account-a --no-restart
```

To make command-line use shorter, add a shell alias:

```bash
alias codex-profile='python3 /Users/dysania/program/tools/codex-profile-switcher/codex_profile.py'
```

Run a Codex command under a profile:

```bash
python3 codex_profile.py use account-a -- --version
```

## App Shortcuts

Local shortcut scripts can switch Codex Desktop directly:

```bash
codex-hd-master
codex-hd-sarah-blackwell
```

Both shortcuts call `codex_profile.py app <profile>`, so they restart Codex
Desktop and then open it with the selected profile. For CLI commands, keep
using `python3 codex_profile.py use <profile> -- <codex-args>`.

## Future GUI Plan

1. Harden the profile layer: keep the shared-vs-profile-specific manifest in
   code, add a repair command, and make backups/rollback explicit.
2. Add app status detection: show the active Desktop `CODEX_HOME`, running
   app-server PID, and whether the visible app matches the selected profile.
3. Build a small macOS menu-bar app or lightweight desktop UI with one-click
   switch buttons, login status, repair, doctor, and open/restart actions.
4. Add usage display in two tiers: reliable local usage/session summaries first;
   true account quota only after confirming a stable supported source for the
   signed-in Codex account.
5. Package it with a signed app bundle and a simple update path once the CLI
   behavior is stable.

## Verification

Current verification results:

- `python3 -m unittest -v`
- `python3 codex_profile.py --help`
- `CODEX_PROFILE_ROOT=.tmp-smoke python3 codex_profile.py init smoke-test`
- `CODEX_PROFILE_ROOT=.tmp-smoke python3 codex_profile.py use smoke-test -- --version`

## Status

MVP implemented. Future GUI work can reuse the same profile root and commands.
