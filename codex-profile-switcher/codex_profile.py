#!/usr/bin/env python3
"""Launch Codex with per-account profiles and shared local history."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Mapping, Sequence


DEFAULT_PROFILE_ROOT = Path("~/.codex-profiles").expanduser()
DEFAULT_SHARED_HOME = Path("~/.codex").expanduser()
SHARED_DIRECTORY_ENTRIES = (
    "sessions",
    "archived_sessions",
    "skills",
    "pets",
    "plugins",
    "vendor_imports",
    "computer-use",
    "attachments",
    "generated_images",
    "shell_snapshots",
    "ambient-suggestions",
    "browser",
    "automations",
    "rules",
    "superpowers",
    "worktrees",
    "cache",
)
SHARED_FILE_ENTRIES = (
    "history.jsonl",
    "session_index.jsonl",
    "models_cache.json",
    "AGENTS.md",
    "state_5.sqlite",
    ".codex-global-state.json",
)
SHARED_STATE_ENTRIES = (*SHARED_DIRECTORY_ENTRIES, *SHARED_FILE_ENTRIES)
SHARED_STATE_LINKS = {"sqlite/state_5.sqlite": "state_5.sqlite"}
PROFILE_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$")


def validate_profile_name(name: str) -> str:
    if not PROFILE_NAME_RE.fullmatch(name):
        raise ValueError(
            "profile name must be 1-64 chars: letters, numbers, dot, underscore, hyphen"
        )
    if name in {".", ".."}:
        raise ValueError("profile name cannot be '.' or '..'")
    return name


def get_profile_root() -> Path:
    configured = os.environ.get("CODEX_PROFILE_ROOT")
    if configured:
        return Path(configured).expanduser()
    return DEFAULT_PROFILE_ROOT


def get_shared_home() -> Path:
    configured = os.environ.get("CODEX_SHARED_HOME")
    if configured:
        return Path(configured).expanduser()
    return DEFAULT_SHARED_HOME


def profile_path(root: Path, name: str) -> Path:
    safe_name = validate_profile_name(name)
    return root.expanduser() / safe_name


def _ensure_shared_target(shared_home: Path, name: str) -> Path:
    target = shared_home.expanduser() / name
    if name in SHARED_DIRECTORY_ENTRIES:
        target.mkdir(parents=True, exist_ok=True, mode=0o700)
    elif name.endswith(".jsonl") or name.endswith(".md"):
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        target.touch(mode=0o600, exist_ok=True)
    elif name.endswith(".json"):
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        if not target.exists():
            target.write_text("{}\n", encoding="utf-8")
            target.chmod(0o600)
    elif name.endswith(".sqlite"):
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    else:
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        target.touch(mode=0o600, exist_ok=True)
    return target


def _merge_sqlite_entry(source: Path, target: Path) -> None:
    if not target.exists():
        shutil.move(str(source), str(target))
        return

    conn = sqlite3.connect(target, timeout=30)
    try:
        conn.execute("pragma busy_timeout=30000")
        conn.execute(f"attach database 'file:{source}?mode=ro&immutable=1' as src")
        tables = [
            row[0]
            for row in conn.execute(
                """
                select d.name
                from main.sqlite_master d
                join src.sqlite_master s on s.name = d.name
                where d.type = 'table'
                  and s.type = 'table'
                  and d.name not like 'sqlite_%'
                  and d.name not in ('_sqlx_migrations')
                order by d.name
                """
            )
        ]
        for table in tables:
            dst_cols = [row[1] for row in conn.execute(f"pragma main.table_info({table})")]
            src_cols = [row[1] for row in conn.execute(f"pragma src.table_info({table})")]
            cols = [col for col in dst_cols if col in src_cols]
            quoted = ", ".join(f'"{col}"' for col in cols)
            conn.execute(
                f'insert or ignore into main."{table}" ({quoted}) '
                f'select {quoted} from src."{table}"'
            )
        conn.commit()
        conn.execute("detach database src")
    finally:
        conn.close()
    source.unlink()


def _merge_json_values(shared_value: object, profile_value: object) -> object:
    if isinstance(shared_value, dict) and isinstance(profile_value, dict):
        merged = dict(shared_value)
        for key, value in profile_value.items():
            merged[key] = (
                _merge_json_values(merged[key], value) if key in merged else value
            )
        return merged
    if isinstance(shared_value, list) and isinstance(profile_value, list):
        merged = list(shared_value)
        seen = {json.dumps(item, sort_keys=True, ensure_ascii=False) for item in merged}
        for item in profile_value:
            marker = json.dumps(item, sort_keys=True, ensure_ascii=False)
            if marker not in seen:
                merged.append(item)
                seen.add(marker)
        return merged
    return profile_value


def _read_json_file(path: Path) -> object:
    text = path.read_text(encoding="utf-8")
    if not text.strip():
        return {}
    return json.loads(text)


def _merge_json_entry(source: Path, target: Path) -> None:
    if not target.exists():
        shutil.move(str(source), str(target))
        return
    merged = _merge_json_values(_read_json_file(target), _read_json_file(source))
    target.write_text(
        json.dumps(merged, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    source.unlink()


def _merge_existing_entry(source: Path, target: Path) -> None:
    if source.is_dir() and target.is_dir():
        shutil.copytree(source, target, dirs_exist_ok=True)
        shutil.rmtree(source)
        return
    if source.suffix == ".sqlite":
        _merge_sqlite_entry(source, target)
        return
    if source.suffix == ".json":
        _merge_json_entry(source, target)
        return
    if source.is_file() and target.is_file():
        existing = source.read_bytes()
        if existing:
            with target.open("ab") as shared_file:
                shared_file.write(existing)
        source.unlink()
        return
    raise RuntimeError(f"cannot share incompatible Codex state entry: {source}")


def prepare_profile_home(profile: Path, shared_home: Path) -> Path:
    profile.mkdir(parents=True, exist_ok=True, mode=0o700)
    profile.chmod(0o700)
    for name in SHARED_STATE_ENTRIES:
        link = profile / name
        target = _ensure_shared_target(shared_home, name)
        if link.is_symlink():
            if link.resolve() != target.resolve():
                link.unlink()
                link.symlink_to(target, target_is_directory=target.is_dir())
            continue
        if link.exists():
            _merge_existing_entry(link, target)
        link.symlink_to(target, target_is_directory=target.is_dir())
    for link_name, target_name in SHARED_STATE_LINKS.items():
        link = profile / link_name
        target = _ensure_shared_target(shared_home, target_name)
        link.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        if link.is_symlink():
            if link.resolve() != target.resolve():
                link.unlink()
                link.symlink_to(target, target_is_directory=target.is_dir())
            continue
        if link.exists():
            _merge_existing_entry(link, target)
        link.symlink_to(target, target_is_directory=target.is_dir())
    return profile


def ensure_profile(root: Path, name: str) -> Path:
    path = profile_path(root, name)
    return prepare_profile_home(path, get_shared_home())


def profile_status(path: Path) -> dict[str, bool]:
    return {
        "exists": path.is_dir(),
        "has_auth": (path / "auth.json").is_file(),
        "has_config": (path / "config.toml").is_file(),
    }


def build_codex_env(base_env: Mapping[str, str], home: Path) -> dict[str, str]:
    env = dict(base_env)
    env["CODEX_HOME"] = str(home)
    return env


def strip_separator(args: Sequence[str]) -> list[str]:
    values = list(args)
    if values and values[0] == "--":
        return values[1:]
    return values


def require_codex() -> str:
    codex = shutil.which("codex")
    if not codex:
        raise RuntimeError("codex command not found in PATH")
    return codex


def run_codex(home: Path, args: Sequence[str]) -> int:
    codex = require_codex()
    env = build_codex_env(os.environ, home)
    command = [codex, *strip_separator(args)]
    try:
        return subprocess.run(command, env=env, check=False).returncode
    except KeyboardInterrupt:
        return 130


def quit_codex_desktop() -> None:
    subprocess.run(
        ["osascript", "-e", 'tell application "Codex" to quit'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )


def cmd_init(args: argparse.Namespace) -> int:
    path = ensure_profile(get_profile_root(), args.name)
    print(f"created: {path}")
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    root = get_profile_root()
    if not root.exists():
        print(f"no profiles found: {root}")
        return 0

    profiles = sorted(path for path in root.iterdir() if path.is_dir())
    if not profiles:
        print(f"no profiles found: {root}")
        return 0

    for path in profiles:
        status = profile_status(path)
        auth = "yes" if status["has_auth"] else "no"
        config = "yes" if status["has_config"] else "no"
        print(f"{path.name}\tauth: {auth}\tconfig: {config}\tpath: {path}")
    return 0


def existing_profile(root: Path, name: str) -> Path:
    path = profile_path(root, name)
    if not path.is_dir():
        raise FileNotFoundError(f"profile not found: {name}. Run: codex-profile init {name}")
    return prepare_profile_home(path, get_shared_home())


def cmd_use(args: argparse.Namespace) -> int:
    path = existing_profile(get_profile_root(), args.name)
    codex_args = strip_separator(args.codex_args)
    return run_codex(path, codex_args)


def cmd_app(args: argparse.Namespace) -> int:
    path = existing_profile(get_profile_root(), args.name)
    if args.restart:
        quit_codex_desktop()
    return run_codex(path, ["app"])


def cmd_login(args: argparse.Namespace) -> int:
    path = ensure_profile(get_profile_root(), args.name)
    return run_codex(path, ["login"])


def cmd_doctor(args: argparse.Namespace) -> int:
    path = existing_profile(get_profile_root(), args.name)
    return run_codex(path, ["doctor"])


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="codex-profile",
        description="Launch Codex with per-account auth/config and shared local history.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init", help="create a Codex profile directory")
    init_parser.add_argument("name")
    init_parser.set_defaults(func=cmd_init)

    list_parser = subparsers.add_parser("list", help="list Codex profiles")
    list_parser.set_defaults(func=cmd_list)

    use_parser = subparsers.add_parser("use", help="run Codex with a profile")
    use_parser.add_argument("name")
    use_parser.add_argument("codex_args", nargs=argparse.REMAINDER)
    use_parser.set_defaults(func=cmd_use)

    app_parser = subparsers.add_parser(
        "app",
        help="open Codex Desktop with a profile",
        description=(
            "Open Codex Desktop with a profile. By default this first quits an "
            "already-running Desktop app so its app-server inherits the selected CODEX_HOME."
        ),
    )
    app_parser.add_argument("name")
    app_parser.add_argument(
        "--no-restart",
        dest="restart",
        action="store_false",
        default=True,
        help="do not quit an already-running Codex Desktop app before opening it",
    )
    app_parser.set_defaults(func=cmd_app)

    login_parser = subparsers.add_parser("login", help="run codex login with a profile")
    login_parser.add_argument("name")
    login_parser.set_defaults(func=cmd_login)

    doctor_parser = subparsers.add_parser("doctor", help="run codex doctor with a profile")
    doctor_parser.add_argument("name")
    doctor_parser.set_defaults(func=cmd_doctor)

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except (ValueError, FileNotFoundError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
