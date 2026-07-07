"""Local helpers for bridging Codex threads."""

from __future__ import annotations

import json
import re
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


DEFAULT_CODEX_HOME = Path("~/.codex").expanduser()
MAX_CARD_CHARS = 3000
MAX_TEXT_CHARS = 360
SECRET_PATTERNS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"sk-(?:proj-)?[A-Za-z0-9_-]{20,}"), "[REDACTED]"),
    (re.compile(r"gh[pousr]_[A-Za-z0-9_]{20,}"), "[REDACTED]"),
    (
        re.compile(
            r"(?i)\b((?:AWS_)?(?:SECRET_ACCESS_KEY|ACCESS_KEY_ID)|"
            r"(?:OPENAI|ANTHROPIC|GITHUB|GITLAB|NPM|HF|HUGGINGFACE)_API_KEY|"
            r"(?:API[_-]?KEY|TOKEN|SECRET|PASSWORD))\s*=\s*[^ \n\r\t`'\"\]]+"
        ),
        r"\1=[REDACTED]",
    ),
    (
        re.compile(
            r"(?i)\b(api[_-]?key|token|secret|password)\s*[:=]\s*[^ \n\r\t`'\"\]]{8,}"
        ),
        r"\1=[REDACTED]",
    ),
)


@dataclass(frozen=True)
class ThreadRecord:
    id: str
    title: str
    cwd: str
    rollout_path: Path
    created_at: int
    updated_at: int
    tokens_used: int
    preview: str
    projectless: bool
    workspace_hint: str
    projectless_output_dir: str
    context_card_paths: list[Path]


def _read_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return default


def _global_state(codex_home: Path) -> dict[str, Any]:
    data = _read_json(codex_home / ".codex-global-state.json", {})
    return data if isinstance(data, dict) else {}


def _session_titles(codex_home: Path) -> dict[str, str]:
    path = codex_home / "session_index.jsonl"
    titles: dict[str, str] = {}
    if not path.exists():
        return titles
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return titles
    for line in lines:
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        thread_id = str(item.get("id") or "")
        title = str(item.get("thread_name") or "").strip()
        if thread_id and title:
            titles[thread_id] = title
    return titles


def _sqlite_columns(conn: sqlite3.Connection, table: str) -> set[str]:
    return {str(row[1]) for row in conn.execute(f"pragma table_info({table})")}


def _thread_rows(codex_home: Path) -> list[dict[str, Any]]:
    db_path = codex_home / "state_5.sqlite"
    if not db_path.exists():
        return []
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    try:
        columns = _sqlite_columns(conn, "threads")
        wanted = [
            "id",
            "rollout_path",
            "created_at",
            "updated_at",
            "cwd",
            "title",
            "tokens_used",
            "preview",
        ]
        selected = [name for name in wanted if name in columns]
        if "id" not in selected:
            return []
        rows = conn.execute(
            f"select {', '.join(selected)} from threads order by updated_at desc"
        ).fetchall()
        return [dict(row) for row in rows]
    finally:
        conn.close()


def _context_card_paths(codex_home: Path) -> dict[str, list[Path]]:
    card_dir = codex_home / "context-cards"
    cards: dict[str, list[Path]] = {}
    if not card_dir.exists():
        return cards
    for path in sorted(card_dir.glob("*.md")):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for match in re.finditer(r"会话 ID:\s*`([^`]+)`", text):
            cards.setdefault(match.group(1), []).append(path)
    return cards


def _as_path(value: str, codex_home: Path) -> Path:
    path = Path(value).expanduser()
    if path.is_absolute():
        return path
    return codex_home / path


def list_threads(
    codex_home: str | Path = DEFAULT_CODEX_HOME,
    *,
    limit: int | None = None,
    query: str = "",
) -> list[ThreadRecord]:
    home = Path(codex_home).expanduser()
    state = _global_state(home)
    projectless_ids = set(state.get("projectless-thread-ids") or [])
    hints = state.get("thread-workspace-root-hints") or {}
    output_dirs = state.get("thread-projectless-output-directories") or {}
    titles = _session_titles(home)
    cards = _context_card_paths(home)
    query_lower = query.lower()

    records: list[ThreadRecord] = []
    for row in _thread_rows(home):
        thread_id = str(row.get("id") or "")
        title = titles.get(thread_id) or str(row.get("title") or "").strip() or thread_id
        cwd = str(row.get("cwd") or "")
        preview = str(row.get("preview") or "")
        if query_lower:
            haystack = f"{thread_id} {title} {cwd} {preview}".lower()
            if query_lower not in haystack:
                continue
        records.append(
            ThreadRecord(
                id=thread_id,
                title=title,
                cwd=cwd,
                rollout_path=_as_path(str(row.get("rollout_path") or ""), home),
                created_at=int(row.get("created_at") or 0),
                updated_at=int(row.get("updated_at") or 0),
                tokens_used=int(row.get("tokens_used") or 0),
                preview=preview,
                projectless=thread_id in projectless_ids,
                workspace_hint=str(hints.get(thread_id) or ""),
                projectless_output_dir=str(output_dirs.get(thread_id) or ""),
                context_card_paths=cards.get(thread_id, []),
            )
        )

    records.sort(key=lambda item: (item.updated_at, item.id), reverse=True)
    if limit is not None:
        return records[:limit]
    return records


def get_thread(codex_home: str | Path, thread_id: str) -> ThreadRecord:
    for record in list_threads(codex_home):
        if record.id == thread_id:
            return record
    raise KeyError(f"thread not found: {thread_id}")


def _text_from_content(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(filter(None, (_text_from_content(item) for item in content)))
    if isinstance(content, dict):
        for key in ("text", "message", "content", "input", "output"):
            if key in content:
                text = _text_from_content(content[key])
                if text:
                    return text
    return ""


def _redact_text(value: str) -> str:
    for pattern, replacement in SECRET_PATTERNS:
        value = pattern.sub(replacement, value)
    return value


def _clean_text(value: str, limit: int = MAX_TEXT_CHARS) -> str:
    value = _redact_text(value)
    value = re.sub(r"\s+", " ", value).strip()
    if len(value) > limit:
        return value[: limit - 1].rstrip() + "..."
    return value


def _message_from_record(record: dict[str, Any]) -> tuple[str, str] | None:
    payload = record.get("payload") if isinstance(record.get("payload"), dict) else {}
    payload_type = payload.get("type")
    if payload_type == "user_message":
        text = _text_from_content(payload.get("message"))
        return ("用户", _clean_text(text)) if text else None
    if payload_type in {"agent_message", "assistant_message"}:
        text = _text_from_content(payload.get("message"))
        return ("助手", _clean_text(text)) if text else None
    if record.get("type") == "response_item" and payload_type == "message":
        role = "用户" if payload.get("role") == "user" else "助手"
        text = _text_from_content(payload.get("content"))
        return (role, _clean_text(text)) if text else None
    return None


def recent_rollout_messages(path: Path, max_events: int = 12) -> list[tuple[str, str]]:
    if not path.exists():
        return []
    messages: list[tuple[str, str]] = []
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return messages
    for line in lines:
        if not line.strip():
            continue
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        message = _message_from_record(record)
        if message and message[1]:
            if not messages or messages[-1] != message:
                messages.append(message)
    return messages[-max_events:]


def _latest_card_excerpt(paths: Iterable[Path]) -> str:
    paths = list(paths)
    if not paths:
        return ""
    latest = paths[-1]
    try:
        text = latest.read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return ""
    text = _redact_text(text)
    if len(text) > MAX_CARD_CHARS:
        return text[: MAX_CARD_CHARS - 1].rstrip() + "..."
    return text


def build_context_pack(
    codex_home: str | Path,
    thread_id: str,
    *,
    max_events: int = 12,
) -> str:
    record = get_thread(codex_home, thread_id)
    card_excerpt = _latest_card_excerpt(record.context_card_paths)
    messages = recent_rollout_messages(record.rollout_path, max_events=max_events)

    lines = [
        "# Codex Thread Continuation Pack",
        "",
        f"- Source Thread ID: `{record.id}`",
        f"- Title: {record.title}",
        f"- Source CWD: `{record.cwd or 'unknown'}`",
        f"- Workspace Hint: `{record.workspace_hint or 'none'}`",
        f"- Projectless: `{str(record.projectless).lower()}`",
        f"- Rollout: `{record.rollout_path}`",
    ]
    if record.context_card_paths:
        lines.append(f"- Latest Context Card: `{record.context_card_paths[-1]}`")

    lines.extend(
        [
            "",
            "## How To Continue",
            "",
            "Use this as a compact handoff. Continue the source thread's goal, but do not assume the full transcript is in context. If a detail matters, read the rollout or context card paths listed above before acting.",
            "",
        ]
    )

    if record.preview:
        lines.extend(["## Thread Preview", "", _clean_text(record.preview, 1200), ""])

    if card_excerpt:
        lines.extend(["## Latest Context Card Excerpt", "", card_excerpt, ""])

    lines.extend(["## Recent Conversation", ""])
    if messages:
        lines.extend(f"- {role}: {text}" for role, text in messages)
    else:
        lines.append("- No recent rollout messages found.")

    lines.extend(
        [
            "",
            "## Suggested First User Prompt",
            "",
            "请基于上面的 continuation pack 继续推进这个线程。先确认你理解的当前目标、已有进展和下一步，然后再执行。",
            "",
        ]
    )
    return "\n".join(lines)


def build_assignment_plan(
    codex_home: str | Path,
    thread_id: str,
    project_path: str | Path,
) -> dict[str, Any]:
    record = get_thread(codex_home, thread_id)
    target = str(Path(project_path).expanduser())
    changes = []
    if record.cwd != target:
        changes.append("state_5.sqlite: update threads.cwd")
    if record.projectless:
        changes.append(".codex-global-state.json: remove from projectless-thread-ids")
    if record.workspace_hint != target:
        changes.append(".codex-global-state.json: set thread-workspace-root-hints")
    if record.projectless_output_dir:
        changes.append(".codex-global-state.json: remove thread-projectless-output-directories entry")
    if target not in (_global_state(Path(codex_home).expanduser()).get("project-order") or []):
        changes.append(".codex-global-state.json: add project-order entry")

    return {
        "dry_run": True,
        "thread_id": record.id,
        "title": record.title,
        "current_cwd": record.cwd,
        "current_workspace_hint": record.workspace_hint,
        "currently_projectless": record.projectless,
        "target_project": target,
        "changes": changes,
    }
