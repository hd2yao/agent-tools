# Codex Profile Switcher Design

## Problem

Codex official OAuth credentials are cached locally under `CODEX_HOME`.
Switching accounts by copying or restoring `auth.json` snapshots is fragile,
and a Codex skill is not a good first solution because it depends on the
currently usable Codex account.

## MVP

Build a local command-line tool that manages named Codex home directories and
launches Codex with `CODEX_HOME` set to the selected profile.

## Architecture

The CLI is a single Python file using only the standard library. Profiles live
under `~/.codex-profiles/<name>`. Commands create directories, inspect whether
expected files exist, and delegate execution to the installed `codex` binary
with a modified environment.

## Components

- `init`: validate a profile name and create the profile directory.
- `list`: print known profiles and whether `auth.json` exists.
- `use`: run `codex` under a profile, forwarding optional arguments.
- `login`: run `codex login` under a profile.
- `doctor`: run `codex doctor` under a profile.

## Data Flow

The tool never reads token contents. It only checks for the existence of
`auth.json` and `config.toml`, then passes a profile path through the
`CODEX_HOME` environment variable when launching Codex.

## Error Handling

Invalid profile names are rejected before filesystem access. Missing profiles
produce a clear error with the suggested `init` command. Missing `codex` binary
is reported before command execution when possible.

## Testing

Unit tests cover profile name validation, path resolution, profile creation
metadata, status detection, and command construction. A smoke check verifies
CLI help output and a real `codex --version` invocation under a test profile.
