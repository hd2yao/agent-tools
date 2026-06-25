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
state_5.sqlite
skills
sqlite/state_5.sqlite
.codex-global-state.json
```

`.codex-global-state.json` is included because Codex Desktop uses it for local
project ordering, saved workspace roots, and thread workspace hints. Without
sharing it, the SQLite history can be shared while the left sidebar still looks
different between accounts.

`skills` is included so installed skills stay visible after switching accounts.

By default the shared Codex home is `~/.codex`. Set `CODEX_SHARED_HOME` to use
another shared history location.

The tool does not read, print, copy, or modify token contents.

## MVP Commands

```bash
python3 codex_profile.py init account-a
python3 codex_profile.py list
python3 codex_profile.py login account-a
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
python3 codex_profile.py use account-a
```

To make it shorter, add a shell alias:

```bash
alias codex-profile='python3 /Users/dysania/program/tools/codex-profile-switcher/codex_profile.py'
```

Run a Codex command under a profile:

```bash
python3 codex_profile.py use account-a -- --version
```

## Verification

Current verification results:

- `python3 -m unittest -v`
- `python3 codex_profile.py --help`
- `CODEX_PROFILE_ROOT=.tmp-smoke python3 codex_profile.py init smoke-test`
- `CODEX_PROFILE_ROOT=.tmp-smoke python3 codex_profile.py use smoke-test -- --version`

## Status

MVP implemented. Future GUI work can reuse the same profile root and commands.
