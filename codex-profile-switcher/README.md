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

The tool also links new top-level entries that already exist in the shared
Codex home, such as `hooks` and `hooks.json`, unless they are known
account-specific or runtime-local files. This keeps future local Codex features
visible after switching profiles without requiring a code change for every new
directory name.

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
python3 codex_profile.py ui
python3 codex_profile.py status --json
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

## Local Dashboard

Start the browser dashboard:

```bash
python3 codex_profile.py ui
```

By default it serves a local-only UI at:

```text
http://127.0.0.1:8765
```

Use a custom port or keep the browser closed:

```bash
python3 codex_profile.py ui --port 9000 --no-open
```

The dashboard shows:

- profile login/config status
- Codex plan type and limit id
- primary and secondary rate limit windows
- reset time for each limit window
- available reset credits when app-server provides them
- Codex usage summary from `account/usage/read`
- latest local token snapshot from shared rollout logs
- shared SQLite history thread count and token total

The data source priority is:

1. Codex app-server JSON-RPC with each profile's `CODEX_HOME`.
2. Local `sessions` and `archived_sessions` rollout `token_count` events.
3. Shared `state_5.sqlite` history totals.

The dashboard does not read or print token contents from `auth.json`. It checks
whether auth/config files exist, then asks Codex app-server for account status.
The HTTP server binds to `127.0.0.1` by default and does not call direct
`chatgpt.com/backend-api/wham/*` endpoints.

The account switch button calls the same Desktop launch path as:

```bash
python3 codex_profile.py app <profile>
```

That means Codex Desktop is restarted before opening with the selected profile,
so the app-server does not keep a stale `CODEX_HOME`.

## macOS Menu Bar App

Build the local menu bar app:

```bash
./build-menubar-app.sh
```

Open it:

```bash
open "build/Codex Profile Switcher.app"
```

Install it as a local user app:

```bash
./install-menubar-app.sh
open "$HOME/Applications/Codex Profile Switcher.app"
```

The app runs as a menu bar accessory. It does not show a Dock icon. The status
item displays the active profile's 5-hour remaining quota percent and a runtime
state light:

- green: a Codex conversation process is running, or Codex produced output in
  the last 90 seconds
- yellow: no live process was found, but there was Codex activity in the last 15
  minutes
- red: no live process or recent Codex activity was found

The popover closes when clicking elsewhere, matching normal menu bar behavior.
It shows each profile with plan, auth/config state, 5-hour and 7-day reset
windows, and switch actions.

The app refreshes status on launch, after a profile switch, and every 60
seconds while it is running. Background refresh updates the status item without
showing a temporary loading state. Manual refresh is still available for
immediate checks.

The quit row exits only the menu bar account manager. It does not quit Codex
Desktop. Start it again by opening the installed app.

### Launch ownership

Codex Desktop reads `CODEX_HOME` when its process starts. For profile switching,
the reliable entry point is therefore the account manager, not double-clicking
`/Applications/Codex.app` directly.

When the account manager opens Codex, it records the selected profile and the
Codex Desktop process id. The menu bar UI reports whether the current Desktop
process is still managed by the switcher. If Codex was opened manually, the UI
shows that state and offers a one-click repair action: open/restart Codex with
the current profile.

Directly opening Codex.app still works, but it uses the default `~/.codex`
route. That path is not profile-aware, so it should be treated as outside the
switcher's account isolation model.

### Another Mac

Do not copy `auth.json` or other credential files between machines. On a new
Mac:

1. Clone this repo.
2. Run `./install-menubar-app.sh`.
3. Create the same profile names.
4. Log in to each profile locally with `python3 codex_profile.py login <name>`.
5. Start Codex through the installed account manager.

The tool recreates the profile structure and shared local-state links on each
machine. Secrets remain local to the machine where the account was logged in.

The app is a thin native Swift/AppKit wrapper around the existing CLI:

```bash
python3 codex_profile.py status --json
python3 codex_profile.py app <profile>
```

The generated `.app` is local build output and is not committed to git.

## Future GUI Plan

1. Show reset credit count and reset-credit expiration time when Codex app-server
   exposes them.
2. Add token usage charts by account and model, including input, output,
   reasoning, and cached input tokens.
3. Add login and doctor buttons to the menu bar app.
4. Add launch-at-login support.
5. Add signing and a simple update path once the UI behavior is stable.

## Verification

Current verification results:

- `python3 -m unittest -v`
- `python3 codex_profile.py --help`
- `CODEX_PROFILE_ROOT=.tmp-smoke python3 codex_profile.py init smoke-test`
- `CODEX_PROFILE_ROOT=.tmp-smoke python3 codex_profile.py use smoke-test -- --version`
- `python3 -m py_compile codex_profile.py codex_profile_dashboard.py`
- `python3 -m unittest tests/test_codex_profile.py tests/test_dashboard.py`
- `sh -n codex-hd-master codex-hd-sarah-blackwell build-menubar-app.sh`
- `./build-menubar-app.sh`
- `/usr/bin/env python3 "build/Codex Profile Switcher.app/Contents/Resources/codex-profile-switcher/codex_profile.py" status --json`

## Status

CLI, local dashboard, and native macOS menu bar MVP implemented.
