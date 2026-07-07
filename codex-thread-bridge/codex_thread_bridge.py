#!/usr/bin/env python3
"""Command-line entrypoint for Codex Thread Bridge."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import thread_bridge


def _thread_to_dict(record: thread_bridge.ThreadRecord) -> dict[str, object]:
    return {
        "id": record.id,
        "title": record.title,
        "cwd": record.cwd,
        "workspace_hint": record.workspace_hint,
        "projectless": record.projectless,
        "rollout_path": str(record.rollout_path),
        "context_cards": [str(path) for path in record.context_card_paths],
        "tokens_used": record.tokens_used,
        "updated_at": record.updated_at,
    }


def _print_json(value: object) -> None:
    print(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True))


def command_list(args: argparse.Namespace) -> int:
    records = thread_bridge.list_threads(
        args.codex_home,
        limit=args.limit,
        query=args.query,
    )
    if args.json:
        _print_json({"threads": [_thread_to_dict(record) for record in records]})
        return 0
    for record in records:
        marker = "projectless" if record.projectless else "project"
        hint = record.workspace_hint or record.cwd or "unknown"
        print(f"{record.id} [{marker}] {record.title} :: {hint}")
    return 0


def command_pack(args: argparse.Namespace) -> int:
    pack = thread_bridge.build_context_pack(
        args.codex_home,
        args.thread_id,
        max_events=args.max_events,
    )
    if args.output:
        output = Path(args.output).expanduser()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(pack, encoding="utf-8")
        print(str(output))
    else:
        print(pack)
    return 0


def command_assign_project(args: argparse.Namespace) -> int:
    plan = thread_bridge.build_assignment_plan(
        args.codex_home,
        args.thread_id,
        args.project,
    )
    if args.json:
        _print_json(plan)
        return 0
    print(f"Dry-run assignment plan for {plan['thread_id']}")
    print(f"Current CWD: {plan['current_cwd']}")
    print(f"Target project: {plan['target_project']}")
    print("Changes:")
    if plan["changes"]:
        for change in plan["changes"]:
            print(f"- {change}")
    else:
        print("- No local metadata changes needed.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Inspect Codex threads and generate continuation context packs."
    )
    parser.add_argument(
        "--codex-home",
        default=str(thread_bridge.DEFAULT_CODEX_HOME),
        help="Codex home directory. Defaults to ~/.codex.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_cmd = subparsers.add_parser("list", help="List local Codex threads.")
    list_cmd.add_argument("--limit", type=int, default=20)
    list_cmd.add_argument("--query", default="")
    list_cmd.add_argument("--json", action="store_true")
    list_cmd.set_defaults(func=command_list)

    pack_cmd = subparsers.add_parser("pack", help="Generate a continuation context pack.")
    pack_cmd.add_argument("thread_id")
    pack_cmd.add_argument("--max-events", type=int, default=12)
    pack_cmd.add_argument("--output", default="")
    pack_cmd.set_defaults(func=command_pack)

    assign_cmd = subparsers.add_parser(
        "assign-project",
        help="Dry-run local metadata changes for assigning a thread to a project.",
    )
    assign_cmd.add_argument("thread_id")
    assign_cmd.add_argument("--project", required=True)
    assign_cmd.add_argument("--json", action="store_true")
    assign_cmd.set_defaults(func=command_assign_project)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
