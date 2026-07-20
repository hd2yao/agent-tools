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
import time
import tomllib
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
    "config.toml",
    "state_5.sqlite",
    ".codex-global-state.json",
)
SHARED_STATE_ENTRIES = (*SHARED_DIRECTORY_ENTRIES, *SHARED_FILE_ENTRIES)
SHARED_STATE_LINKS = {"sqlite/state_5.sqlite": "state_5.sqlite"}
PROFILE_LOCAL_ENTRY_NAMES = {
    ".DS_Store",
    ".app-server-state-reconciled-v1",
    ".codex-profile-switcher-active.json",
    ".personality_migration",
    ".tmp",
    "auth.json",
    "goals_1.sqlite",
    "installation_id",
    "log",
    "logs_2.sqlite",
    "memories_1.sqlite",
    "process_manager",
    "tmp",
    "version.json",
}
PROFILE_LOCAL_PREFIXES = ("auth.json", "chrome-native-hosts", "config.toml")
PROFILE_LOCAL_SUFFIXES = ("-shm", "-wal")
PROFILE_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$")
ACTIVE_PROFILE_FILE = ".codex-profile-switcher-active.json"
PROFILE_ACCOUNT_FILES = ("auth.json",)
BRIDGE_BACKUP_DIR = ".codex-profile-switcher-backups"
CODEX_DESKTOP_BUNDLE_ID = "com.openai.codex"


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


def _read_toml_file(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if not text.strip():
        return {}
    return tomllib.loads(text)


def _toml_quote(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _toml_key(key: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9_-]+", key):
        return key
    return _toml_quote(key)


def _toml_value(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, str):
        return _toml_quote(value)
    if isinstance(value, list):
        return "[" + ", ".join(_toml_value(item) for item in value) + "]"
    raise TypeError(f"unsupported TOML value type: {type(value).__name__}")


def _toml_lines(data: Mapping[str, object], prefix: tuple[str, ...] = ()) -> list[str]:
    lines: list[str] = []
    scalar_items = [(key, value) for key, value in data.items() if not isinstance(value, dict)]
    table_items = [(key, value) for key, value in data.items() if isinstance(value, dict)]
    if prefix:
        lines.append("[" + ".".join(_toml_key(part) for part in prefix) + "]")
    for key, value in scalar_items:
        lines.append(f"{_toml_key(key)} = {_toml_value(value)}")
    for key, value in table_items:
        if lines:
            lines.append("")
        lines.extend(_toml_lines(value, (*prefix, key)))
    return lines


def _write_toml_file(path: Path, data: Mapping[str, object]) -> None:
    text = "\n".join(_toml_lines(data)).rstrip() + "\n"
    path.write_text(text, encoding="utf-8")
    path.chmod(0o600)


def _merge_toml_values(shared_value: object, profile_value: object) -> object:
    if isinstance(shared_value, dict) and isinstance(profile_value, dict):
        merged = dict(shared_value)
        for key, value in profile_value.items():
            merged[key] = (
                _merge_toml_values(merged[key], value) if key in merged else value
            )
        return merged
    return profile_value


def _merge_toml_entry(source: Path, target: Path) -> None:
    if not target.exists():
        shutil.move(str(source), str(target))
        target.chmod(0o600)
        return
    merged = _merge_toml_values(_read_toml_file(target), _read_toml_file(source))
    if not isinstance(merged, dict):
        raise RuntimeError(f"cannot merge TOML root value from {source}")
    _write_toml_file(target, merged)
    source.unlink()


def _sync_hook_state_aliases(config_path: Path, shared_home: Path, profile: Path) -> None:
    if not config_path.exists():
        return
    config = _read_toml_file(config_path)
    hooks = config.get("hooks")
    if not isinstance(hooks, dict):
        return
    state = hooks.get("state")
    if not isinstance(state, dict):
        return

    alias_paths = [shared_home.expanduser() / "hooks.json", profile.expanduser() / "hooks.json"]
    aliases = []
    for path in alias_paths:
        for value in (str(path), str(path.resolve(strict=False))):
            if value not in aliases:
                aliases.append(value)
    additions: dict[str, object] = {}
    for key, value in list(state.items()):
        if not isinstance(key, str):
            continue
        for alias in aliases:
            prefix = alias + ":"
            if key.startswith(prefix):
                suffix = key[len(alias) :]
                for other_alias in aliases:
                    alias_key = other_alias + suffix
                    if alias_key not in state:
                        additions[alias_key] = value
                break
    if additions:
        state.update(additions)
        _write_toml_file(config_path, config)


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
    if source.suffix == ".toml":
        _merge_toml_entry(source, target)
        return
    if source.is_file() and target.is_file():
        existing = source.read_bytes()
        if existing:
            with target.open("ab") as shared_file:
                shared_file.write(existing)
        source.unlink()
        return
    raise RuntimeError(f"cannot share incompatible Codex state entry: {source}")


def _is_profile_local_entry(name: str) -> bool:
    if name in PROFILE_LOCAL_ENTRY_NAMES:
        return True
    if name.startswith(PROFILE_LOCAL_PREFIXES):
        return True
    return name.endswith(PROFILE_LOCAL_SUFFIXES)


def _handled_shared_link_roots() -> set[str]:
    return {link_name.split("/", 1)[0] for link_name in SHARED_STATE_LINKS}


def _existing_dynamic_shared_entry_names(shared_home: Path) -> list[str]:
    if not shared_home.exists():
        return []
    handled = set(SHARED_STATE_ENTRIES) | _handled_shared_link_roots()
    names = []
    for path in sorted(shared_home.iterdir(), key=lambda item: item.name):
        name = path.name
        if name in handled or _is_profile_local_entry(name):
            continue
        names.append(name)
    return names


def _link_shared_entry(link: Path, target: Path) -> None:
    if link.is_symlink():
        if link.resolve() != target.resolve():
            link.unlink()
            link.symlink_to(target, target_is_directory=target.is_dir())
        return
    if link.exists():
        _merge_existing_entry(link, target)
    link.symlink_to(target, target_is_directory=target.is_dir())


def _ensure_shared_config_target(shared_home: Path) -> Path:
    target = shared_home.expanduser() / "config.toml"
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if target.is_symlink():
        data = target.read_bytes() if target.exists() else b""
        target.unlink()
        target.write_bytes(data)
        target.chmod(0o600)
    elif not target.exists():
        target.touch(mode=0o600)
    return target


def prepare_profile_home(profile: Path, shared_home: Path) -> Path:
    profile.mkdir(parents=True, exist_ok=True, mode=0o700)
    profile.chmod(0o700)
    for name in SHARED_STATE_ENTRIES:
        link = profile / name
        target = (
            _ensure_shared_config_target(shared_home)
            if name == "config.toml"
            else _ensure_shared_target(shared_home, name)
        )
        _link_shared_entry(link, target)
        if name == "config.toml":
            _sync_hook_state_aliases(target, shared_home, profile)
    for link_name, target_name in SHARED_STATE_LINKS.items():
        link = profile / link_name
        target = _ensure_shared_target(shared_home, target_name)
        link.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        _link_shared_entry(link, target)
    for name in _existing_dynamic_shared_entry_names(shared_home):
        _link_shared_entry(profile / name, shared_home / name)
    return profile


def ensure_profile(root: Path, name: str) -> Path:
    path = profile_path(root, name)
    return prepare_profile_home(path, get_shared_home())


def sync_profile_homes(root: Path | None = None, shared_home: Path | None = None) -> list[str]:
    profile_root = root or get_profile_root()
    shared = shared_home or get_shared_home()
    if not profile_root.exists():
        return []
    synced = []
    for path in sorted(item for item in profile_root.iterdir() if item.is_dir()):
        if path.resolve() == shared.resolve():
            continue
        prepare_profile_home(path, shared)
        synced.append(path.name)
    return synced


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
    from codex_profile_dashboard import resolve_codex_binary

    codex = resolve_codex_binary()
    if not codex:
        raise RuntimeError("codex command not found in ChatGPT/Codex app or PATH")
    return codex


def run_codex(home: Path, args: Sequence[str]) -> int:
    codex = require_codex()
    env = build_codex_env(os.environ, home)
    command = [codex, *strip_separator(args)]
    try:
        return subprocess.run(command, env=env, check=False).returncode
    except KeyboardInterrupt:
        return 130


def run_codex_default_home(args: Sequence[str]) -> int:
    codex = require_codex()
    env = dict(os.environ)
    env.pop("CODEX_HOME", None)
    command = [codex, *strip_separator(args)]
    try:
        return subprocess.run(command, env=env, check=False).returncode
    except KeyboardInterrupt:
        return 130


def _same_resolved_path(left: Path, right: Path) -> bool:
    return left.expanduser().resolve(strict=False) == right.expanduser().resolve(strict=False)


def _next_bridge_backup_dir(shared_home: Path) -> Path:
    root = shared_home.expanduser() / BRIDGE_BACKUP_DIR
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    candidate = root / f"account-files-{stamp}"
    suffix = 1
    while candidate.exists():
        suffix += 1
        candidate = root / f"account-files-{stamp}-{suffix}"
    candidate.mkdir(mode=0o700)
    return candidate


def _backup_default_account_file(path: Path, backup_dir: Path) -> None:
    if not path.exists() and not path.is_symlink():
        return
    backup = backup_dir / path.name
    shutil.move(str(path), str(backup))
    if backup.is_file() and not backup.is_symlink():
        backup.chmod(0o600)


def _bridge_account_file(
    shared_home: Path,
    profile_home: Path,
    name: str,
    backup_dir: Path | None,
) -> str:
    shared_file = shared_home / name
    profile_file = profile_home / name
    shared_file.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    profile_file.parent.mkdir(parents=True, exist_ok=True, mode=0o700)

    if shared_file.is_symlink():
        if _same_resolved_path(shared_file, profile_file):
            return "linked"
        shared_file.unlink()

    if shared_file.exists():
        if profile_file.exists():
            if backup_dir is None:
                backup_dir = _next_bridge_backup_dir(shared_home)
            _backup_default_account_file(shared_file, backup_dir)
        else:
            shutil.move(str(shared_file), str(profile_file))
            if profile_file.is_file():
                profile_file.chmod(0o600)

    if not profile_file.exists():
        return "missing"

    shared_file.symlink_to(profile_file)
    return "linked"


def _auth_account_id(path: Path) -> str | None:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(payload, dict):
        return None
    tokens = payload.get("tokens")
    if not isinstance(tokens, dict):
        return None
    account_id = tokens.get("account_id")
    return account_id if isinstance(account_id, str) and account_id else None


def reconcile_default_home_auth(shared_home: Path, profile_home: Path) -> dict[str, str]:
    shared_file = shared_home.expanduser() / "auth.json"
    profile_file = profile_home.expanduser() / "auth.json"
    shared_file.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    profile_file.parent.mkdir(parents=True, exist_ok=True, mode=0o700)

    if shared_file.is_symlink():
        state = "linked" if _same_resolved_path(shared_file, profile_file) else "linked_elsewhere"
        return {"state": state}
    if not shared_file.exists():
        if not profile_file.exists():
            return {"state": "missing"}
        shared_file.symlink_to(profile_file)
        return {"state": "linked"}
    if not profile_file.exists():
        os.replace(shared_file, profile_file)
        profile_file.chmod(0o600)
        shared_file.symlink_to(profile_file)
        return {"state": "adopted"}

    same_contents = shared_file.read_bytes() == profile_file.read_bytes()
    shared_account = _auth_account_id(shared_file)
    profile_account = _auth_account_id(profile_file)
    if not same_contents and (
        shared_account is None
        or profile_account is None
        or shared_account != profile_account
    ):
        return {"state": "account_conflict"}

    os.replace(shared_file, profile_file)
    profile_file.chmod(0o600)
    shared_file.symlink_to(profile_file)
    return {"state": "synced" if not same_contents else "linked"}


def activate_default_home_profile(
    profile_home: Path,
    profile_name: str,
    *,
    shared_home: Path | None = None,
) -> dict:
    shared = (shared_home or get_shared_home()).expanduser()
    profile = profile_home.expanduser()
    shared.mkdir(parents=True, exist_ok=True, mode=0o700)
    profile.mkdir(parents=True, exist_ok=True, mode=0o700)
    backup_dir: Path | None = None
    files: dict[str, str] = {}
    for name in PROFILE_ACCOUNT_FILES:
        before = shared / name
        if before.exists() and not before.is_symlink() and (profile / name).exists():
            backup_dir = backup_dir or _next_bridge_backup_dir(shared)
        files[name] = _bridge_account_file(shared, profile, name, backup_dir)
    return {
        "managed": _bridge_files_are_managed(shared, profile),
        "active_profile": profile_name,
        "shared_home": str(shared),
        "profile_home": str(profile),
        "files": files,
        "backup_dir": str(backup_dir) if backup_dir is not None else None,
    }


def _account_file_bridge_state(shared_home: Path, profile_home: Path, name: str) -> str:
    shared_file = shared_home / name
    profile_file = profile_home / name
    if shared_file.is_symlink():
        return "linked" if _same_resolved_path(shared_file, profile_file) else "linked_elsewhere"
    if shared_file.exists():
        return "unmanaged"
    return "missing" if not profile_file.exists() else "unlinked"


def _bridge_files_are_managed(shared_home: Path, profile_home: Path) -> bool:
    linked_existing = []
    for name in PROFILE_ACCOUNT_FILES:
        profile_file = profile_home / name
        if not profile_file.exists():
            continue
        linked_existing.append(_account_file_bridge_state(shared_home, profile_home, name) == "linked")
    return bool(linked_existing) and all(linked_existing)


def default_home_bridge_status(
    shared_home: Path | None = None,
    profile_root: Path | None = None,
    active_profile: str | None = None,
) -> dict:
    shared = (shared_home or get_shared_home()).expanduser()
    root = (profile_root or get_profile_root()).expanduser()
    active = active_profile or read_active_profile()
    if not active:
        return {
            "managed": False,
            "state": "no_active_profile",
            "active_profile": None,
            "shared_home": str(shared),
            "profile_home": None,
            "files": {},
        }
    try:
        profile = profile_path(root, active)
    except ValueError:
        return {
            "managed": False,
            "state": "invalid_active_profile",
            "active_profile": active,
            "shared_home": str(shared),
            "profile_home": None,
            "files": {},
        }
    if not profile.is_dir():
        return {
            "managed": False,
            "state": "profile_missing",
            "active_profile": active,
            "shared_home": str(shared),
            "profile_home": str(profile),
            "files": {},
        }
    files = {
        name: _account_file_bridge_state(shared, profile, name)
        for name in PROFILE_ACCOUNT_FILES
    }
    managed = _bridge_files_are_managed(shared, profile)
    return {
        "managed": managed,
        "state": "managed" if managed else "needs_repair",
        "active_profile": active,
        "shared_home": str(shared),
        "profile_home": str(profile),
        "files": files,
    }


def repair_default_home_bridge_for_active_profile() -> dict:
    active = read_active_profile()
    if not active:
        return default_home_bridge_status()
    root = get_profile_root()
    profile = profile_path(root, active)
    if not profile.is_dir():
        return default_home_bridge_status(active_profile=active)
    reconcile_default_home_auth(get_shared_home(), profile)
    return default_home_bridge_status(active_profile=active)


def reconcile_default_home_auth_for_active_profile() -> dict[str, str]:
    active = read_active_profile()
    if not active:
        return {"state": "no_active_profile"}
    profile = profile_path(get_profile_root(), active)
    if not profile.is_dir():
        return {"state": "missing_profile"}
    return reconcile_default_home_auth(get_shared_home(), profile)


def record_active_profile(
    name: str,
    *,
    profile_home: Path | None = None,
    codex_pid: int | None = None,
) -> None:
    target = get_shared_home() / ACTIVE_PROFILE_FILE
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    payload: dict[str, object] = {"active_profile": name}
    if profile_home is not None:
        payload["profile_home"] = str(profile_home)
    if codex_pid is not None:
        payload["codex_pid"] = codex_pid
        payload["managed_launch_at"] = int(time.time())
        payload["shared_home"] = str(get_shared_home())
    target.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    target.chmod(0o600)
    try:
        from codex_profile_dashboard import (
            read_local_token_snapshot,
            record_attribution_baseline,
        )

        shared_home = get_shared_home()
        record_attribution_baseline(
            shared_home,
            name,
            read_local_token_snapshot(shared_home),
            managed=codex_pid is not None,
        )
    except Exception:
        pass


def read_active_profile_record() -> dict:
    target = get_shared_home() / ACTIVE_PROFILE_FILE
    if not target.is_file():
        return {}
    try:
        value = json.loads(target.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def read_active_profile() -> str | None:
    value = read_active_profile_record()
    name = value.get("active_profile")
    if isinstance(name, str) and PROFILE_NAME_RE.fullmatch(name):
        return name
    return None


def quit_codex_desktop() -> None:
    subprocess.run(
        [
            "osascript",
            "-e",
            f'tell application id "{CODEX_DESKTOP_BUNDLE_ID}" to quit',
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )


def codex_desktop_pid() -> int | None:
    result = subprocess.run(
        [
            "osascript",
            "-e",
            "tell application \"System Events\" to get unix id of first "
            "application process whose bundle identifier is "
            f'\"{CODEX_DESKTOP_BUNDLE_ID}\"',
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return None
    try:
        return int(result.stdout.strip())
    except ValueError:
        return None


def codex_desktop_is_running() -> bool:
    return codex_desktop_pid() is not None


def build_desktop_status() -> dict:
    record = read_active_profile_record()
    current_pid = codex_desktop_pid()
    active_profile = read_active_profile()
    recorded_pid = record.get("codex_pid")
    bridge = default_home_bridge_status(active_profile=active_profile)
    pid_matches = (
        current_pid is not None
        and isinstance(recorded_pid, int)
        and current_pid == recorded_pid
    )
    bridge_managed = bool(bridge.get("managed"))
    managed = current_pid is not None and (bridge_managed or pid_matches)
    if current_pid is None:
        state = "not_running"
        message = "Codex 未运行"
    elif bridge_managed:
        state = "managed_default_home"
        message = f"默认路径已接管 · {active_profile}" if active_profile else "默认路径已接管"
    elif pid_matches:
        state = "managed_legacy"
        message = f"旧版托管启动 · {active_profile}" if active_profile else "旧版托管启动"
    else:
        state = "manual_or_unknown"
        message = "默认路径未接管 · 建议用账号管家重启"
    return {
        "running": current_pid is not None,
        "managed": managed,
        "state": state,
        "message": message,
        "codex_pid": current_pid,
        "recorded_pid": recorded_pid if isinstance(recorded_pid, int) else None,
        "active_profile": active_profile,
        "profile_home": record.get("profile_home") if isinstance(record.get("profile_home"), str) else None,
        "managed_launch_at": record.get("managed_launch_at") if isinstance(record.get("managed_launch_at"), int) else None,
        "default_home_bridge": bridge,
    }


def wait_for_codex_desktop_exit(timeout_seconds: float = 12.0) -> bool:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        if not codex_desktop_is_running():
            return True
        time.sleep(0.25)
    return not codex_desktop_is_running()


def wait_for_codex_desktop_launch(timeout_seconds: float = 12.0) -> bool:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        if codex_desktop_is_running():
            return True
        time.sleep(0.25)
    return codex_desktop_is_running()


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
        if not wait_for_codex_desktop_exit():
            print(
                "Codex Desktop did not quit within 12 seconds; switch aborted.",
                file=sys.stderr,
            )
            return 1
        reconciliation = reconcile_default_home_auth_for_active_profile()
        if reconciliation.get("state") == "account_conflict":
            print(
                "Codex auth account changed unexpectedly; switch aborted to preserve both accounts.",
                file=sys.stderr,
            )
            return 1
    activate_default_home_profile(path, args.name, shared_home=get_shared_home())
    # The authentication bridge is already authoritative at this point. Record
    # that selected route before launching so a later manual launch cannot be
    # attributed to the previously active account when `codex app` times out.
    record_active_profile(args.name, profile_home=path)
    code = run_codex_default_home(["app"])
    if code != 0:
        return code
    if not wait_for_codex_desktop_launch():
        print(
            "Codex Desktop did not launch within 12 seconds after `codex app`.",
            file=sys.stderr,
        )
        return 1
    record_active_profile(args.name, profile_home=path, codex_pid=codex_desktop_pid())
    return 0


def cmd_login(args: argparse.Namespace) -> int:
    path = ensure_profile(get_profile_root(), args.name)
    return run_codex(path, ["login"])


def cmd_doctor(args: argparse.Namespace) -> int:
    path = existing_profile(get_profile_root(), args.name)
    return run_codex(path, ["doctor"])


def cmd_sync(args: argparse.Namespace) -> int:
    synced = sync_profile_homes()
    if synced:
        print("synced: " + ", ".join(synced))
    else:
        print(f"no profiles found: {get_profile_root()}")
    return 0


def switch_profile_from_dashboard(name: str) -> int:
    args = argparse.Namespace(name=name, restart=True)
    return cmd_app(args)


def run_dashboard(host: str, port: int, open_browser: bool) -> int:
    from codex_profile_dashboard import serve_dashboard

    return serve_dashboard(
        profile_root=get_profile_root(),
        shared_home=get_shared_home(),
        host=host,
        port=port,
        open_browser=open_browser,
        switch_profile=switch_profile_from_dashboard,
    )


def cmd_ui(args: argparse.Namespace) -> int:
    return run_dashboard(args.host, args.port, args.open_browser)


def build_status_payload(force_reset_credit_refresh: bool = False) -> dict:
    from codex_profile_dashboard import build_profiles_payload, read_runtime_status

    profile_root = get_profile_root()
    shared_home = get_shared_home()
    managed_profiles = (
        any(path.is_dir() for path in profile_root.iterdir())
        if profile_root.exists()
        else False
    )
    if managed_profiles:
        sync_profile_homes()
        repair_default_home_bridge_for_active_profile()
        active_profile = read_active_profile()
    else:
        active_profile = None
    payload = build_profiles_payload(
        profile_root,
        shared_home,
        force_reset_credit_refresh=force_reset_credit_refresh,
        active_profile=active_profile,
    )
    payload["runtime_status"] = read_runtime_status(shared_home, profile_root)
    desktop_status = build_desktop_status()
    if payload["account_mode"] == "local_default":
        payload["active_profile"] = "local-default"
        desktop_status = {
            **desktop_status,
            "active_profile": "local-default",
            "state": "local_default",
            "message": "使用本机默认 Codex 账号",
        }
    else:
        payload["active_profile"] = active_profile
    payload["desktop_status"] = desktop_status
    payload["default_home_bridge"] = payload["desktop_status"].get("default_home_bridge")
    return payload


def cmd_status(args: argparse.Namespace) -> int:
    payload = (
        build_status_payload(force_reset_credit_refresh=True)
        if args.refresh_reset_credits
        else build_status_payload()
    )
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
        return 0
    for profile in payload.get("profiles", []):
        limits = profile.get("rate_limits") or {}
        primary = limits.get("primary") or {}
        remaining = primary.get("remaining_percent")
        remaining_text = "-" if remaining is None else f"{remaining}%"
        print(f"{profile.get('name')}\t{profile.get('auth')}\t{remaining_text}")
    return 0


def cmd_consume_reset_credit(args: argparse.Namespace) -> int:
    from codex_profile_dashboard import consume_next_expiring_reset_credit

    profile = profile_path(get_profile_root(), args.name)
    if not profile.is_dir():
        raise FileNotFoundError(f"profile does not exist: {args.name}")
    result = consume_next_expiring_reset_credit(profile, args.idempotency_key)
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0 if result.get("ok") else 2


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
            "Open Codex Desktop with a profile. This first points the default "
            "Codex home account files at the selected profile, then restarts "
            "Desktop so app-server state lines up with that account."
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

    sync_parser = subparsers.add_parser(
        "sync",
        help="sync shared Codex home entries into all profile homes",
    )
    sync_parser.set_defaults(func=cmd_sync)

    ui_parser = subparsers.add_parser("ui", help="open the local profile dashboard")
    ui_parser.add_argument("--host", default="127.0.0.1")
    ui_parser.add_argument("--port", type=int, default=8765)
    ui_parser.add_argument(
        "--no-open",
        dest="open_browser",
        action="store_false",
        default=True,
        help="do not open the dashboard in the default browser",
    )
    ui_parser.set_defaults(func=cmd_ui)

    status_parser = subparsers.add_parser(
        "status",
        help="print profile account status for local integrations",
    )
    status_parser.add_argument(
        "--json",
        action="store_true",
        help="print compact JSON status",
    )
    status_parser.add_argument(
        "--refresh-reset-credits",
        action="store_true",
        help="force a fresh read of reset credit card details",
    )
    status_parser.set_defaults(func=cmd_status)

    consume_parser = subparsers.add_parser(
        "consume-reset-credit",
        help="consume the earliest expiring reset credit for an exhausted profile",
    )
    consume_parser.add_argument("name")
    consume_parser.add_argument("--idempotency-key", required=True)
    consume_parser.set_defaults(func=cmd_consume_reset_credit)

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
