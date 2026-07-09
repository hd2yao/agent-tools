# Codex Thread Bridge

A local CLI for inspecting Codex threads and creating compact continuation
packs for starting cleaner follow-up conversations.

## Goal

Long Codex threads can become hard to scan and expensive to continue. This tool
keeps the old thread intact, reads local Codex metadata and PreCompact context
cards, then produces a small Markdown handoff that can be used as the first
message in a fresh thread.

The MVP is intentionally read-mostly:

- `list` reads local thread metadata.
- `pack` generates a continuation pack.
- `assign-project` only prints a dry-run plan for local metadata changes.

It does not rewrite transcript files or move conversation history.

## Commands

List recent local threads:

```bash
python3 codex_thread_bridge.py list --limit 10
```

Search for one thread:

```bash
python3 codex_thread_bridge.py list --query "对话迁移" --json
```

Generate a continuation pack:

```bash
python3 codex_thread_bridge.py pack <thread-id> --max-events 12
```

Save the pack to a file:

```bash
python3 codex_thread_bridge.py pack <thread-id> --output /tmp/thread-pack.md
```

Preview what would be needed to assign a thread to a project:

```bash
python3 codex_thread_bridge.py assign-project <thread-id> \
  --project /Users/dysania/program/tools \
  --json
```

## Data Sources

The tool reads from the configured Codex home, defaulting to `~/.codex`:

- `state_5.sqlite`
- `.codex-global-state.json`
- `session_index.jsonl`
- `context-cards/*.md`
- rollout JSONL files referenced by `state_5.sqlite`

## Safety Model

`assign-project` is dry-run only in this MVP. It reports the local metadata that
would need to change, including `threads.cwd`, `thread-workspace-root-hints`,
`projectless-thread-ids`, and related projectless output-directory state.

Future versions can add `--apply`, but only with backup, validation, and an
easy rollback path.

## Verification

```bash
python3 -m unittest discover -s tests -v
```
