#!/usr/bin/env python3
"""Local dashboard for Codex profile status and account limits."""

from __future__ import annotations

import json
import mimetypes
import os
import re
import selectors
import shutil
import sqlite3
import subprocess
import time
import webbrowser
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Callable


DEFAULT_USAGE = {
    "input_tokens": 0,
    "cached_input_tokens": 0,
    "output_tokens": 0,
    "reasoning_output_tokens": 0,
    "total_tokens": 0,
}
PROFILE_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$")
WEB_ROOT = Path(__file__).resolve().parent / "web"


def normalize_window(value: dict | None) -> dict | None:
    if not value:
        return None
    used = int(value.get("usedPercent") or 0)
    return {
        "used_percent": used,
        "remaining_percent": max(0, 100 - used),
        "window_minutes": value.get("windowDurationMins"),
        "resets_at": value.get("resetsAt"),
    }


def normalize_rate_limits(payload: dict | None) -> dict:
    value = payload or {}
    limits = value.get("rateLimits") or {}
    credits = limits.get("credits") or {}
    return {
        "available": bool(limits),
        "limit_id": limits.get("limitId"),
        "limit_name": limits.get("limitName"),
        "plan_type": limits.get("planType"),
        "credits_available": credits.get("availableCount"),
        "primary": normalize_window(limits.get("primary")),
        "secondary": normalize_window(limits.get("secondary")),
        "rate_limit_reached_type": limits.get("rateLimitReachedType"),
    }


def _usage_value(usage: dict, key: str) -> int:
    return int(usage.get(key) or 0)


def _extract_token_count(row: dict) -> tuple[dict, dict | None] | None:
    payload = row.get("payload") or {}
    message = payload.get("message") or {}
    if payload.get("type") == "token_count":
        message = payload
    if row.get("type") == "token_count":
        message = row
    if message.get("type") != "token_count":
        return None
    info = message.get("info") or {}
    usage = info.get("total_token_usage") or {}
    rate_limits = info.get("rate_limits") or info.get("rateLimits")
    normalized_usage = {key: _usage_value(usage, key) for key in DEFAULT_USAGE}
    return normalized_usage, rate_limits


def read_local_token_snapshot(shared_home: Path) -> dict:
    event_count = 0
    bad_line_count = 0
    latest_timestamp = None
    latest_usage = dict(DEFAULT_USAGE)
    latest_rate_limits = None
    search_roots = (shared_home / "sessions", shared_home / "archived_sessions")

    for root in search_roots:
        if not root.exists():
            continue
        for path in sorted(root.rglob("rollout-*.jsonl")):
            with path.open(encoding="utf-8") as handle:
                for line in handle:
                    try:
                        row = json.loads(line)
                    except json.JSONDecodeError:
                        bad_line_count += 1
                        continue
                    extracted = _extract_token_count(row)
                    if extracted is None:
                        continue
                    usage, rate_limits = extracted
                    timestamp = row.get("timestamp")
                    if latest_timestamp is None or (timestamp or "") >= latest_timestamp:
                        latest_timestamp = timestamp
                        latest_usage = usage
                        latest_rate_limits = rate_limits
                    event_count += 1

    return {
        "event_count": event_count,
        "bad_line_count": bad_line_count,
        "latest_timestamp": latest_timestamp,
        "total": latest_usage,
        "rate_limits": normalize_rate_limits({"rateLimits": latest_rate_limits})
        if latest_rate_limits
        else normalize_rate_limits(None),
    }


def read_sqlite_history_summary(shared_home: Path) -> dict:
    path = shared_home / "state_5.sqlite"
    if not path.exists():
        return {"available": False, "thread_count": 0, "tokens_used": 0, "error": None}
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=5)
        try:
            row = conn.execute(
                "select count(*), coalesce(sum(tokens_used), 0) from threads"
            ).fetchone()
        finally:
            conn.close()
    except sqlite3.Error:
        return {
            "available": False,
            "thread_count": 0,
            "tokens_used": 0,
            "error": "sqlite unavailable",
        }
    return {
        "available": True,
        "thread_count": int(row[0] or 0),
        "tokens_used": int(row[1] or 0),
        "error": None,
    }


def build_rpc_request(request_id: int, method: str, params: dict | None = None) -> dict:
    request = {"jsonrpc": "2.0", "id": request_id, "method": method}
    if params is not None:
        request["params"] = params
    return request


def _stop_process(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=2)


def read_app_server_account_snapshot(
    profile_home: Path,
    timeout_seconds: float = 8.0,
) -> dict:
    codex = shutil.which("codex")
    if not codex:
        return {"ok": False, "rate_limits": None, "usage": None, "error": "codex not found"}

    env = dict(os.environ)
    env["CODEX_HOME"] = str(profile_home)
    try:
        process = subprocess.Popen(
            [codex, "app-server"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            env=env,
        )
    except OSError:
        return {"ok": False, "rate_limits": None, "usage": None, "error": "spawn failed"}

    responses: dict[int, dict] = {}
    try:
        requests = [
            build_rpc_request(
                1,
                "initialize",
                {
                    "clientInfo": {"name": "codex-profile-switcher", "version": "0"},
                    "capabilities": {"experimentalApi": True},
                },
            ),
            {"jsonrpc": "2.0", "method": "initialized", "params": {}},
            build_rpc_request(2, "account/rateLimits/read"),
            build_rpc_request(3, "account/usage/read"),
        ]
        if process.stdin is None or process.stdout is None:
            return {
                "ok": False,
                "rate_limits": None,
                "usage": None,
                "error": "app-server pipe unavailable",
            }
        for request in requests:
            process.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
        process.stdin.flush()

        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)
        deadline = time.monotonic() + timeout_seconds
        while time.monotonic() < deadline and (2 not in responses or 3 not in responses):
            wait = max(0.0, deadline - time.monotonic())
            events = selector.select(timeout=min(0.25, wait))
            if not events:
                if process.poll() is not None:
                    break
                continue
            line = process.stdout.readline()
            if not line:
                break
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(row.get("id"), int):
                responses[row["id"]] = row
        selector.close()
    finally:
        _stop_process(process)

    rate_limits = responses.get(2) or {}
    usage = responses.get(3) or {}
    error = None
    if "error" in rate_limits:
        error = "rate limits unavailable"
    elif "result" not in rate_limits:
        error = "app-server timeout"
    return {
        "ok": error is None,
        "rate_limits": rate_limits.get("result"),
        "usage": usage.get("result"),
        "error": error,
    }


def build_profiles_payload(
    profile_root: Path,
    shared_home: Path,
    read_remote: bool = True,
) -> dict:
    local_snapshot = read_local_token_snapshot(shared_home)
    profiles = []
    if profile_root.exists():
        for profile in sorted(path for path in profile_root.iterdir() if path.is_dir()):
            remote = read_app_server_account_snapshot(profile) if read_remote else None
            profiles.append(
                {
                    "name": profile.name,
                    "path": str(profile),
                    "auth": "present" if (profile / "auth.json").is_file() else "missing",
                    "config": "present" if (profile / "config.toml").is_file() else "missing",
                    "rate_limits": normalize_rate_limits(
                        (remote or {}).get("rate_limits") or {}
                    ),
                    "usage": (remote or {}).get("usage"),
                    "remote_error": (remote or {}).get("error") if remote else None,
                }
            )
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "profile_root": str(profile_root),
        "shared_home": str(shared_home),
        "local_snapshot": local_snapshot,
        "history": read_sqlite_history_summary(shared_home),
        "profiles": profiles,
    }


def _json_response(handler: BaseHTTPRequestHandler, status: int, payload: dict) -> None:
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def _static_response(handler: BaseHTTPRequestHandler, path: Path) -> None:
    if not path.is_file():
        handler.send_error(HTTPStatus.NOT_FOUND)
        return
    body = path.read_bytes()
    content_type = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
    handler.send_response(HTTPStatus.OK)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def _read_json_body(handler: BaseHTTPRequestHandler) -> dict:
    length = int(handler.headers.get("Content-Length") or "0")
    if length <= 0:
        return {}
    data = handler.rfile.read(length)
    return json.loads(data.decode("utf-8"))


def make_handler(
    profile_root: Path,
    shared_home: Path,
    switch_profile: Callable[[str], int] | None = None,
) -> type[BaseHTTPRequestHandler]:
    class DashboardHandler(BaseHTTPRequestHandler):
        def log_message(self, format: str, *args: object) -> None:
            return

        def do_GET(self) -> None:
            if self.path == "/" or self.path == "/index.html":
                _static_response(self, WEB_ROOT / "index.html")
                return
            if self.path == "/api/profiles":
                _json_response(
                    self,
                    HTTPStatus.OK,
                    build_profiles_payload(profile_root, shared_home),
                )
                return
            if self.path in {"/app.js", "/styles.css"}:
                _static_response(self, WEB_ROOT / self.path.lstrip("/"))
                return
            self.send_error(HTTPStatus.NOT_FOUND)

        def do_POST(self) -> None:
            if self.path != "/api/switch":
                self.send_error(HTTPStatus.NOT_FOUND)
                return
            try:
                payload = _read_json_body(self)
            except (json.JSONDecodeError, UnicodeDecodeError):
                _json_response(self, HTTPStatus.BAD_REQUEST, {"ok": False, "error": "bad json"})
                return
            name = str(payload.get("name") or "")
            if not PROFILE_NAME_RE.fullmatch(name):
                _json_response(
                    self,
                    HTTPStatus.BAD_REQUEST,
                    {"ok": False, "error": "invalid profile"},
                )
                return
            if switch_profile is None:
                _json_response(
                    self,
                    HTTPStatus.NOT_IMPLEMENTED,
                    {"ok": False, "error": "switch unavailable"},
                )
                return
            code = switch_profile(name)
            _json_response(self, HTTPStatus.OK, {"ok": code == 0, "returncode": code})

    return DashboardHandler


def serve_dashboard(
    profile_root: Path,
    shared_home: Path,
    host: str,
    port: int,
    open_browser: bool,
    switch_profile: Callable[[str], int] | None = None,
) -> int:
    handler = make_handler(profile_root, shared_home, switch_profile=switch_profile)
    server = ThreadingHTTPServer((host, port), handler)
    url = f"http://{host}:{server.server_port}"
    print(f"Codex Profile Dashboard: {url}")
    if open_browser:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        return 130
    finally:
        server.server_close()
    return 0
