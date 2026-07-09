#!/usr/bin/env python3
"""Local dashboard for Codex profile status and account limits."""

from __future__ import annotations

import json
import hashlib
import mimetypes
import os
import re
import selectors
import shutil
import sqlite3
import subprocess
import time
import urllib.error
import urllib.request
import webbrowser
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Callable
from zoneinfo import ZoneInfo


DEFAULT_USAGE = {
    "input_tokens": 0,
    "cached_input_tokens": 0,
    "output_tokens": 0,
    "reasoning_output_tokens": 0,
    "total_tokens": 0,
}
PROFILE_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$")
WEB_ROOT = Path(__file__).resolve().parent / "web"
RUNTIME_GREEN_ROLLOUT_MS = 90_000
RUNTIME_RECENT_ACTIVITY_MS = 15 * 60_000
REMOTE_STATUS_CACHE_SECONDS = 10 * 60
RESET_CREDIT_DETAILS_CACHE_SECONDS = 6 * 60 * 60
CODEX_APP_BINARY = Path("/Applications/Codex.app/Contents/Resources/codex")
RESET_CREDITS_ENDPOINT = "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits"
RESET_CREDIT_GRANTED_KEYS = ("granted_at", "grantedAt", "created_at", "createdAt", "issued_at", "issuedAt")
RESET_CREDIT_EXPIRES_KEYS = (
    "expires_at",
    "expiresAt",
    "expiration_time",
    "expirationTime",
    "expired_at",
    "expiredAt",
)
RESET_CREDIT_USED_KEYS = (
    "used",
    "is_used",
    "isUsed",
    "consumed",
    "is_consumed",
    "isConsumed",
    "redeemed",
)


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


def _first_present(value: dict, *keys: str) -> object | None:
    for key in keys:
        if key in value and value[key] is not None:
            return value[key]
    return None


def _optional_int(value: object | None) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _optional_number(value: object | None) -> int | float | None:
    if value is None:
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return int(number) if number.is_integer() else number


def _optional_timestamp(value: object | None) -> int | float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        timestamp = float(value)
        if timestamp > 10_000_000_000:
            timestamp = timestamp / 1000
        return int(timestamp) if timestamp.is_integer() else timestamp
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            return _optional_timestamp(float(text))
        except ValueError:
            pass
        try:
            parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
        except ValueError:
            return None
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        timestamp = parsed.timestamp()
        return int(timestamp) if timestamp.is_integer() else timestamp
    return None


def _mask_identifier(value: object | None) -> str | None:
    if value is None:
        return None
    text = str(value)
    digest = hashlib.sha256(text.encode("utf-8", errors="ignore")).hexdigest()[:10]
    if len(text) <= 8:
        return f"hash:{digest}"
    return f"{text[:4]}...{text[-4:]} hash:{digest}"


def _find_access_token(value: object) -> str | None:
    if isinstance(value, dict):
        for key, child in value.items():
            key_text = str(key).lower()
            if key_text == "access_token" and isinstance(child, str) and child.strip():
                return child.strip()
            found = _find_access_token(child)
            if found:
                return found
    if isinstance(value, list):
        for child in value:
            found = _find_access_token(child)
            if found:
                return found
    return None


def normalize_reset_credits(payload: dict, limits: dict) -> dict:
    candidates = [
        payload.get("rateLimitResetCredits"),
        payload.get("resetCredits"),
        limits.get("rateLimitResetCredits"),
        limits.get("resetCredits"),
        limits.get("credits"),
    ]
    credits = next((item for item in candidates if isinstance(item, dict)), {})
    available = _optional_int(
        _first_present(credits, "availableCount", "available_count", "balance", "count")
    )
    return {
        "available": bool(credits),
        "available_count": available,
        "has_credits": credits.get("hasCredits"),
        "unlimited": credits.get("unlimited"),
        "expires_at": _optional_number(
            _first_present(
                credits,
                "expiresAt",
                "expires_at",
                "expirationTime",
                "expiration_time",
                "resetsAt",
            )
        ),
    }


def normalize_reset_credit_details(payload: dict | None) -> dict:
    value = payload or {}
    credits = value.get("credits") if isinstance(value.get("credits"), list) else []
    normalized_credits = []
    for item in credits:
        if not isinstance(item, dict):
            continue
        status = _first_present(item, "status", "state", "type") or "unknown"
        used = _first_present(item, *RESET_CREDIT_USED_KEYS)
        if used is None:
            used = str(status).lower() not in {"available", "active", "unused"}
        granted_at = _optional_timestamp(_first_present(item, *RESET_CREDIT_GRANTED_KEYS))
        expires_at = _optional_timestamp(_first_present(item, *RESET_CREDIT_EXPIRES_KEYS))
        card = {
            "id": _mask_identifier(
                _first_present(
                    item,
                    "id",
                    "uuid",
                    "credit_id",
                    "creditId",
                    "reset_credit_id",
                    "resetCreditId",
                )
            ),
            "status": status,
            "used": bool(used),
            "granted_at": granted_at,
            "expires_at": expires_at,
        }
        normalized_credits.append(card)

    available_count = _optional_int(
        _first_present(value, "available_count", "availableCount", "count", "balance")
    )
    if available_count is None:
        available_count = sum(
            1
            for card in normalized_credits
            if not card["used"] and str(card["status"]).lower() in {"available", "active", "unused"}
        )
    total_earned_count = _optional_int(
        _first_present(value, "total_earned_count", "totalEarnedCount", "total")
    )
    available_expirations = [
        card["expires_at"]
        for card in normalized_credits
        if card["expires_at"] is not None and not card["used"]
    ]
    return {
        "available": bool(value),
        "available_count": available_count,
        "total_earned_count": total_earned_count,
        "credits": normalized_credits,
        "earliest_expires_at": min(available_expirations) if available_expirations else None,
    }


def normalize_rate_limits(payload: dict | None) -> dict:
    value = payload or {}
    limits = value.get("rateLimits") or {}
    reset_credits = normalize_reset_credits(value, limits)
    return {
        "available": bool(limits),
        "limit_id": limits.get("limitId"),
        "limit_name": limits.get("limitName"),
        "plan_type": limits.get("planType"),
        "credits_available": reset_credits["available_count"],
        "reset_credits": reset_credits,
        "primary": normalize_window(limits.get("primary")),
        "secondary": normalize_window(limits.get("secondary")),
        "rate_limit_reached_type": limits.get("rateLimitReachedType"),
    }


def _usage_value(usage: dict, key: str) -> int:
    return int(usage.get(key) or 0)


def _empty_usage() -> dict:
    return dict(DEFAULT_USAGE)


def _add_usage(target: dict, usage: dict) -> None:
    for key in DEFAULT_USAGE:
        target[key] = _usage_value(target, key) + _usage_value(usage, key)


def _date_key(timestamp: str | None) -> str | None:
    if isinstance(timestamp, str) and len(timestamp) >= 10:
        return timestamp[:10]
    return None


def summarize_account_usage(usage: dict | None, now: datetime | None = None) -> dict:
    now_value = now or datetime.now(timezone.utc)
    today_key = now_value.astimezone(ZoneInfo("Asia/Shanghai")).date().isoformat()
    raw_buckets = (usage or {}).get("dailyUsageBuckets") or []
    buckets = []
    for item in raw_buckets:
        if not isinstance(item, dict):
            continue
        date = item.get("startDate")
        if not isinstance(date, str):
            continue
        buckets.append({"date": date, "tokens": int(item.get("tokens") or 0)})
    buckets.sort(key=lambda item: item["date"])

    latest_date = buckets[-1]["date"] if buckets else None
    today_bucket = next((item for item in reversed(buckets) if item["date"] == today_key), None)
    last_7 = buckets[-7:]
    last_14 = buckets[-14:]
    return {
        "today_tokens": today_bucket["tokens"] if today_bucket else None,
        "today_available": today_bucket is not None,
        "last_7_tokens": sum(item["tokens"] for item in last_7) if last_7 else None,
        "last_14_tokens": sum(item["tokens"] for item in last_14) if last_14 else None,
        "latest_date": latest_date,
        "source": "account_usage",
    }


def _extract_token_count(row: dict) -> tuple[dict, dict | None] | None:
    payload = row.get("payload") or {}
    if not isinstance(payload, dict):
        return None
    message = payload.get("message") or {}
    if not isinstance(message, dict):
        return None
    if payload.get("type") == "token_count":
        message = payload
    if row.get("type") == "token_count":
        message = row
    if message.get("type") != "token_count":
        return None
    info = message.get("info") or {}
    usage = info.get("total_token_usage") or {}
    rate_limits = (
        info.get("rate_limits")
        or info.get("rateLimits")
        or message.get("rate_limits")
        or message.get("rateLimits")
    )
    normalized_usage = {key: _usage_value(usage, key) for key in DEFAULT_USAGE}
    return normalized_usage, rate_limits


def read_local_token_snapshot(shared_home: Path) -> dict:
    event_count = 0
    bad_line_count = 0
    latest_timestamp = None
    latest_usage = _empty_usage()
    latest_rate_limits = None
    daily_usage: dict[str, dict] = {}
    model_usage: dict[str, dict] = {}
    search_roots = (shared_home / "sessions", shared_home / "archived_sessions")

    for root in search_roots:
        if not root.exists():
            continue
        for path in sorted(root.rglob("rollout-*.jsonl")):
            file_latest_timestamp = None
            file_latest_usage = None
            file_model = "unknown"
            try:
                handle = path.open(encoding="utf-8")
            except OSError:
                continue
            with handle:
                for line in handle:
                    try:
                        row = json.loads(line)
                    except json.JSONDecodeError:
                        bad_line_count += 1
                        continue
                    payload = row.get("payload") or {}
                    if (
                        isinstance(payload, dict)
                        and row.get("type") == "turn_context"
                        and isinstance(payload.get("model"), str)
                    ):
                        file_model = payload["model"]
                    extracted = _extract_token_count(row)
                    if extracted is None:
                        continue
                    usage, rate_limits = extracted
                    timestamp = row.get("timestamp")
                    if latest_timestamp is None or (timestamp or "") >= latest_timestamp:
                        latest_timestamp = timestamp
                        latest_usage = usage
                        latest_rate_limits = rate_limits
                    if file_latest_timestamp is None or (timestamp or "") >= file_latest_timestamp:
                        file_latest_timestamp = timestamp
                        file_latest_usage = usage
                    event_count += 1
            if file_latest_usage is None:
                continue
            day = _date_key(file_latest_timestamp)
            if day is not None:
                daily_usage.setdefault(day, {"date": day, **_empty_usage()})
                _add_usage(daily_usage[day], file_latest_usage)
            model_usage.setdefault(file_model, {"model": file_model, **_empty_usage()})
            _add_usage(model_usage[file_model], file_latest_usage)

    return {
        "event_count": event_count,
        "bad_line_count": bad_line_count,
        "latest_timestamp": latest_timestamp,
        "total": latest_usage,
        "daily": [daily_usage[key] for key in sorted(daily_usage)[-14:]],
        "by_model": sorted(
            model_usage.values(),
            key=lambda item: item["total_tokens"],
            reverse=True,
        )[:8],
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


def _default_pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def _chat_process_files(shared_home: Path, profile_root: Path) -> list[Path]:
    paths = [shared_home / "process_manager" / "chat_processes.json"]
    if profile_root.exists():
        paths.extend(
            profile / "process_manager" / "chat_processes.json"
            for profile in sorted(path for path in profile_root.iterdir() if path.is_dir())
        )
    return paths


def _read_chat_processes(path: Path) -> list[dict]:
    if not path.is_file():
        return []
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    return [item for item in value if isinstance(item, dict)] if isinstance(value, list) else []


def _latest_rollout_mtime_ms(shared_home: Path) -> int | None:
    latest = None
    for root in (shared_home / "sessions", shared_home / "archived_sessions"):
        if not root.exists():
            continue
        for path in root.rglob("rollout-*.jsonl"):
            try:
                mtime = int(path.stat().st_mtime * 1000)
            except OSError:
                continue
            latest = mtime if latest is None else max(latest, mtime)
    return latest


def read_runtime_status(
    shared_home: Path,
    profile_root: Path,
    *,
    now_ms: int | None = None,
    pid_alive: Callable[[int], bool] = _default_pid_alive,
) -> dict:
    now = now_ms if now_ms is not None else int(time.time() * 1000)
    active_process_count = 0
    recent_process_count = 0
    latest_activity_at_ms = None
    sources_checked = 0

    for path in _chat_process_files(shared_home, profile_root):
        sources_checked += 1
        for item in _read_chat_processes(path):
            updated = item.get("updatedAtMs") or item.get("startedAtMs")
            if isinstance(updated, int):
                latest_activity_at_ms = (
                    updated
                    if latest_activity_at_ms is None
                    else max(latest_activity_at_ms, updated)
                )
                if now - updated <= RUNTIME_RECENT_ACTIVITY_MS:
                    recent_process_count += 1
            pid = item.get("osPid")
            if isinstance(pid, int) and pid_alive(pid):
                active_process_count += 1

    latest_rollout_at_ms = _latest_rollout_mtime_ms(shared_home)
    if latest_rollout_at_ms is not None:
        latest_activity_at_ms = (
            latest_rollout_at_ms
            if latest_activity_at_ms is None
            else max(latest_activity_at_ms, latest_rollout_at_ms)
        )

    latest_age_ms = None if latest_activity_at_ms is None else max(0, now - latest_activity_at_ms)
    if active_process_count > 0 or (
        latest_rollout_at_ms is not None and now - latest_rollout_at_ms <= RUNTIME_GREEN_ROLLOUT_MS
    ):
        state = "running"
        light = "green"
        label = "运行中"
    elif latest_age_ms is not None and latest_age_ms <= RUNTIME_RECENT_ACTIVITY_MS:
        state = "waiting"
        light = "yellow"
        label = "待接手"
    else:
        state = "idle"
        light = "red"
        label = "空闲"

    return {
        "state": state,
        "light": light,
        "label": label,
        "active_process_count": active_process_count,
        "recent_process_count": recent_process_count,
        "latest_activity_at_ms": latest_activity_at_ms,
        "latest_activity_age_ms": latest_age_ms,
        "latest_rollout_at_ms": latest_rollout_at_ms,
        "sources_checked": sources_checked,
    }


def build_rpc_request(request_id: int, method: str, params: dict | None = None) -> dict:
    request = {"jsonrpc": "2.0", "id": request_id, "method": method}
    if params is not None:
        request["params"] = params
    return request


def resolve_codex_binary(
    *,
    app_binary: Path = CODEX_APP_BINARY,
    path_lookup: Callable[[str], str | None] = shutil.which,
) -> str | None:
    override = os.environ.get("CODEX_PROFILE_SWITCHER_CODEX")
    if override:
        return override
    if app_binary.is_file():
        return str(app_binary)
    return path_lookup("codex")


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
    codex = resolve_codex_binary()
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
        for stream in (process.stdin, process.stdout):
            if stream is not None:
                stream.close()

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


def read_reset_credit_details(
    profile_home: Path,
    timeout_seconds: float = 12.0,
) -> dict:
    auth_path = profile_home / "auth.json"
    try:
        auth = json.loads(auth_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"ok": False, "details": None, "error": "auth unavailable"}
    access_token = _find_access_token(auth)
    if not access_token:
        return {"ok": False, "details": None, "error": "access token unavailable"}

    request = urllib.request.Request(
        RESET_CREDITS_ENDPOINT,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
            "User-Agent": "codex-profile-switcher/1.0",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            raw = response.read(1_000_000)
    except urllib.error.HTTPError as error:
        return {
            "ok": False,
            "details": None,
            "error": f"reset credits http {error.code}",
        }
    except OSError:
        return {"ok": False, "details": None, "error": "reset credits unavailable"}
    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return {"ok": False, "details": None, "error": "reset credits bad json"}
    return {
        "ok": True,
        "details": normalize_reset_credit_details(payload),
        "error": None,
    }


def _remote_status_cache_path(shared_home: Path, profile_name: str) -> Path:
    safe_name = re.sub(r"[^A-Za-z0-9_.-]", "_", profile_name)
    return shared_home / "cache" / "codex-profile-switcher" / "remote-status" / f"{safe_name}.json"


def _reset_credit_details_cache_path(shared_home: Path, profile_name: str) -> Path:
    safe_name = re.sub(r"[^A-Za-z0-9_.-]", "_", profile_name)
    return (
        shared_home
        / "cache"
        / "codex-profile-switcher"
        / "reset-credit-details"
        / f"{safe_name}.json"
    )


def _write_remote_status_cache(
    shared_home: Path,
    profile_name: str,
    remote: dict,
    now_seconds: float,
) -> None:
    if not remote.get("ok") or not remote.get("rate_limits"):
        return
    path = _remote_status_cache_path(shared_home, profile_name)
    payload = {
        "cached_at": now_seconds,
        "rate_limits": remote.get("rate_limits"),
        "usage": remote.get("usage"),
    }
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        tmp.replace(path)
    except OSError:
        return


def _read_remote_status_cache(
    shared_home: Path,
    profile_name: str,
    now_seconds: float,
    max_age_seconds: int = REMOTE_STATUS_CACHE_SECONDS,
) -> dict | None:
    path = _remote_status_cache_path(shared_home, profile_name)
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    cached_at = payload.get("cached_at")
    if not isinstance(cached_at, (int, float)):
        return None
    if now_seconds - cached_at > max_age_seconds:
        return None
    return {
        "ok": True,
        "rate_limits": payload.get("rate_limits"),
        "usage": payload.get("usage"),
        "error": None,
        "stale": True,
        "cached_at": cached_at,
    }


def _read_remote_status_with_cache(
    profile: Path,
    shared_home: Path,
    remote_reader: Callable[[Path], dict],
    now_seconds: float,
) -> dict:
    try:
        remote = remote_reader(profile)
    except Exception:
        remote = {
            "ok": False,
            "rate_limits": None,
            "usage": None,
            "error": "status reader failed",
        }
    if remote.get("ok") and remote.get("rate_limits"):
        _write_remote_status_cache(shared_home, profile.name, remote, now_seconds)
        return {**remote, "stale": False, "cached_at": None}

    cached = _read_remote_status_cache(shared_home, profile.name, now_seconds)
    if cached is not None:
        cached["error"] = remote.get("error")
        return cached
    return {**remote, "stale": False, "cached_at": None}


def _write_reset_credit_details_cache(
    shared_home: Path,
    profile_name: str,
    details: dict,
    now_seconds: float,
) -> None:
    if not details.get("available"):
        return
    path = _reset_credit_details_cache_path(shared_home, profile_name)
    payload = {
        "cached_at": now_seconds,
        "details": details,
    }
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        tmp.replace(path)
    except OSError:
        return


def _read_reset_credit_details_cache(
    shared_home: Path,
    profile_name: str,
    now_seconds: float,
    *,
    expected_count: int | None = None,
    max_age_seconds: int | None = RESET_CREDIT_DETAILS_CACHE_SECONDS,
) -> dict | None:
    path = _reset_credit_details_cache_path(shared_home, profile_name)
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    cached_at = payload.get("cached_at")
    details = payload.get("details")
    if not isinstance(cached_at, (int, float)) or not isinstance(details, dict):
        return None
    if max_age_seconds is not None and now_seconds - cached_at > max_age_seconds:
        return None
    if expected_count is not None and details.get("available_count") != expected_count:
        return None
    return {
        "ok": True,
        "details": details,
        "error": None,
        "stale": True,
        "cached_at": cached_at,
    }


def _read_reset_credit_details_with_cache(
    profile: Path,
    shared_home: Path,
    reset_credit_reader: Callable[[Path], dict],
    now_seconds: float,
    *,
    expected_count: int | None = None,
    force_refresh: bool = False,
) -> dict:
    if not force_refresh:
        cached = _read_reset_credit_details_cache(
            shared_home,
            profile.name,
            now_seconds,
            expected_count=expected_count,
        )
        if cached is not None:
            return cached
    try:
        remote = reset_credit_reader(profile)
    except Exception:
        remote = {"ok": False, "details": None, "error": "reset credit reader failed"}
    if remote.get("ok") and remote.get("details"):
        details = remote["details"]
        _write_reset_credit_details_cache(shared_home, profile.name, details, now_seconds)
        return {**remote, "stale": False, "cached_at": None}

    cached = _read_reset_credit_details_cache(
        shared_home,
        profile.name,
        now_seconds,
        expected_count=None,
        max_age_seconds=None,
    )
    if cached is not None:
        cached["error"] = remote.get("error")
        return cached
    return {**remote, "stale": False, "cached_at": None}


def build_profiles_payload(
    profile_root: Path,
    shared_home: Path,
    read_remote: bool = True,
    remote_reader: Callable[[Path], dict] | None = None,
    reset_credit_reader: Callable[[Path], dict] | None = None,
    force_reset_credit_refresh: bool = False,
    now_seconds: float | None = None,
) -> dict:
    now = time.time() if now_seconds is None else now_seconds
    local_snapshot = read_local_token_snapshot(shared_home)
    profile_paths = (
        sorted(path for path in profile_root.iterdir() if path.is_dir())
        if profile_root.exists()
        else []
    )
    remote_by_name: dict[str, dict | None] = {}
    if read_remote and profile_paths:
        reader = remote_reader or read_app_server_account_snapshot
        with ThreadPoolExecutor(max_workers=min(4, len(profile_paths))) as executor:
            futures = {
                executor.submit(
                    _read_remote_status_with_cache,
                    profile,
                    shared_home,
                    reader,
                    now,
                ): profile
                for profile in profile_paths
            }
            for future in as_completed(futures):
                profile = futures[future]
                remote_by_name[profile.name] = future.result()

    reset_details_by_name: dict[str, dict | None] = {}
    if read_remote and profile_paths:
        reader = reset_credit_reader or read_reset_credit_details
        with ThreadPoolExecutor(max_workers=min(4, len(profile_paths))) as executor:
            futures = {}
            for profile in profile_paths:
                remote = remote_by_name.get(profile.name)
                expected_count = normalize_rate_limits(
                    (remote or {}).get("rate_limits") or {}
                )["reset_credits"]["available_count"]
                futures[
                    executor.submit(
                        _read_reset_credit_details_with_cache,
                        profile,
                        shared_home,
                        reader,
                        now,
                        expected_count=expected_count,
                        force_refresh=force_reset_credit_refresh,
                    )
                ] = profile
            for future in as_completed(futures):
                profile = futures[future]
                reset_details_by_name[profile.name] = future.result()

    profiles = []
    for profile in profile_paths:
        remote = remote_by_name.get(profile.name)
        reset_details = reset_details_by_name.get(profile.name) or {}
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
                "usage_metrics": summarize_account_usage(
                    (remote or {}).get("usage"),
                    now=datetime.fromtimestamp(now, timezone.utc),
                ),
                "reset_credit_details": reset_details.get("details"),
                "reset_credit_error": reset_details.get("error") if reset_details else None,
                "reset_credit_stale": bool(reset_details.get("stale")) if reset_details else False,
                "reset_credit_cached_at": reset_details.get("cached_at") if reset_details else None,
                "remote_error": (remote or {}).get("error") if remote else None,
                "remote_stale": bool((remote or {}).get("stale")),
                "remote_cached_at": (remote or {}).get("cached_at") if remote else None,
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

        def do_HEAD(self) -> None:
            if self.path == "/" or self.path == "/index.html":
                path = WEB_ROOT / "index.html"
                if not path.is_file():
                    self.send_error(HTTPStatus.NOT_FOUND)
                    return
                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Type", "text/html")
                self.send_header("Content-Length", str(path.stat().st_size))
                self.end_headers()
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
