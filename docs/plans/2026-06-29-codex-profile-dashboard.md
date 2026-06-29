# Codex Profile Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a local dashboard for Codex Profile Switcher that shows per-account login status, rate limits, usage, local token history, and one-click Desktop profile switching.

**Architecture:** Keep `codex_profile.py` as the CLI entrypoint and add a separate dashboard module for app-server probing, local usage parsing, and the localhost UI server. Serve static HTML/CSS/JS from a small `web/` directory with no build step, and call the existing profile switch logic for Desktop launches.

**Tech Stack:** Python 3 standard library (`subprocess`, `json`, `http.server`, `sqlite3`, `pathlib`, `unittest`), Codex app-server JSON-RPC over stdio, static HTML/CSS/JS.

---

### Task 1: Add Dashboard Data Normalization Tests

**Files:**
- Create: `codex-profile-switcher/tests/test_dashboard.py`
- Create: `codex-profile-switcher/codex_profile_dashboard.py`

**Step 1: Write failing tests for rate limit normalization**

Create `codex-profile-switcher/tests/test_dashboard.py`:

```python
import unittest


class DashboardNormalizationTests(unittest.TestCase):
    def test_normalize_rate_limits_adds_remaining_percent(self):
        from codex_profile_dashboard import normalize_rate_limits

        payload = {
            "rateLimits": {
                "limitId": "codex",
                "planType": "plus",
                "primary": {
                    "usedPercent": 25,
                    "windowDurationMins": 300,
                    "resetsAt": 1782700000,
                },
                "secondary": None,
                "credits": {"availableCount": 2},
            }
        }

        result = normalize_rate_limits(payload)

        self.assertEqual(result["limit_id"], "codex")
        self.assertEqual(result["plan_type"], "plus")
        self.assertEqual(result["credits_available"], 2)
        self.assertEqual(result["primary"]["used_percent"], 25)
        self.assertEqual(result["primary"]["remaining_percent"], 75)
        self.assertEqual(result["primary"]["window_minutes"], 300)
        self.assertEqual(result["primary"]["resets_at"], 1782700000)
        self.assertIsNone(result["secondary"])
```

**Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 -m unittest tests/test_dashboard.py
```

Expected: fails because `codex_profile_dashboard` does not exist.

**Step 3: Implement minimal normalization module**

Create `codex-profile-switcher/codex_profile_dashboard.py` with:

```python
from __future__ import annotations


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


def normalize_rate_limits(payload: dict) -> dict:
    limits = payload.get("rateLimits") or {}
    credits = limits.get("credits") or {}
    return {
        "limit_id": limits.get("limitId"),
        "plan_type": limits.get("planType"),
        "credits_available": credits.get("availableCount"),
        "primary": normalize_window(limits.get("primary")),
        "secondary": normalize_window(limits.get("secondary")),
        "raw_available": bool(limits),
    }
```

**Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 -m unittest tests/test_dashboard.py
```

Expected: PASS.

**Step 5: Commit**

```bash
git add codex-profile-switcher/codex_profile_dashboard.py codex-profile-switcher/tests/test_dashboard.py
git commit -m "Add dashboard rate limit normalization"
```

### Task 2: Add Local Token Count Snapshot Parser

**Files:**
- Modify: `codex-profile-switcher/codex_profile_dashboard.py`
- Modify: `codex-profile-switcher/tests/test_dashboard.py`

**Step 1: Write failing tests for rollout parsing**

Append tests:

```python
import json
import tempfile
from pathlib import Path


class LocalTokenSnapshotTests(unittest.TestCase):
    def test_read_latest_token_count_snapshot(self):
        from codex_profile_dashboard import read_local_token_snapshot

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rollout = root / "sessions" / "2026" / "06" / "29" / "rollout-test.jsonl"
            rollout.parent.mkdir(parents=True)
            rollout.write_text(
                json.dumps(
                    {
                        "timestamp": "2026-06-29T01:00:00Z",
                        "payload": {
                            "type": "event_msg",
                            "message": {
                                "type": "token_count",
                                "info": {
                                    "total_token_usage": {
                                        "input_tokens": 10,
                                        "cached_input_tokens": 4,
                                        "output_tokens": 3,
                                        "reasoning_output_tokens": 2,
                                        "total_tokens": 15,
                                    }
                                },
                            },
                        },
                    }
                )
                + "\n"
                + "{bad-json\n",
                encoding="utf-8",
            )

            result = read_local_token_snapshot(root)

            self.assertEqual(result["event_count"], 1)
            self.assertEqual(result["bad_line_count"], 1)
            self.assertEqual(result["total"]["input_tokens"], 10)
            self.assertEqual(result["total"]["cached_input_tokens"], 4)
            self.assertEqual(result["latest_timestamp"], "2026-06-29T01:00:00Z")
```

**Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 -m unittest tests/test_dashboard.py
```

Expected: fails because `read_local_token_snapshot` does not exist.

**Step 3: Implement parser**

Add:

```python
import json
from pathlib import Path


EMPTY_USAGE = {
    "input_tokens": 0,
    "cached_input_tokens": 0,
    "output_tokens": 0,
    "reasoning_output_tokens": 0,
    "total_tokens": 0,
}


def read_local_token_snapshot(shared_home: Path) -> dict:
    latest_timestamp = None
    latest_usage = dict(EMPTY_USAGE)
    event_count = 0
    bad_line_count = 0
    roots = [shared_home / "sessions", shared_home / "archived_sessions"]
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("rollout-*.jsonl"):
            with path.open(encoding="utf-8") as handle:
                for line in handle:
                    try:
                        row = json.loads(line)
                    except json.JSONDecodeError:
                        bad_line_count += 1
                        continue
                    message = ((row.get("payload") or {}).get("message") or {})
                    if message.get("type") != "token_count":
                        continue
                    usage = ((message.get("info") or {}).get("total_token_usage") or {})
                    latest_timestamp = row.get("timestamp") or latest_timestamp
                    latest_usage = {key: int(usage.get(key) or 0) for key in EMPTY_USAGE}
                    event_count += 1
    return {
        "event_count": event_count,
        "bad_line_count": bad_line_count,
        "latest_timestamp": latest_timestamp,
        "total": latest_usage,
    }
```

**Step 4: Run tests**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 -m unittest tests/test_dashboard.py
```

Expected: PASS.

**Step 5: Commit**

```bash
git add codex-profile-switcher/codex_profile_dashboard.py codex-profile-switcher/tests/test_dashboard.py
git commit -m "Add local token usage snapshot parser"
```

### Task 3: Add Codex App-Server JSON-RPC Client

**Files:**
- Modify: `codex-profile-switcher/codex_profile_dashboard.py`
- Modify: `codex-profile-switcher/tests/test_dashboard.py`

**Step 1: Write tests for request framing and error sanitization**

Add tests for building JSON-RPC requests and for converting subprocess failures into non-secret error payloads:

```python
class AppServerClientTests(unittest.TestCase):
    def test_build_rpc_request(self):
        from codex_profile_dashboard import build_rpc_request

        self.assertEqual(
            build_rpc_request(3, "account/rateLimits/read"),
            {"jsonrpc": "2.0", "id": 3, "method": "account/rateLimits/read"},
        )
```

**Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 -m unittest tests/test_dashboard.py
```

Expected: fails because `build_rpc_request` does not exist.

**Step 3: Implement app-server client helpers**

Add:

```python
import subprocess
import time


def build_rpc_request(request_id: int, method: str, params: dict | None = None) -> dict:
    request = {"jsonrpc": "2.0", "id": request_id, "method": method}
    if params is not None:
        request["params"] = params
    return request


def read_app_server_account_snapshot(profile_home: Path, timeout_seconds: float = 8.0) -> dict:
    env = dict(os.environ)
    env["CODEX_HOME"] = str(profile_home)
    process = subprocess.Popen(
        ["codex", "app-server"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
    )
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
        assert process.stdin is not None
        for request in requests:
            process.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
        process.stdin.flush()

        deadline = time.monotonic() + timeout_seconds
        responses = {}
        assert process.stdout is not None
        while time.monotonic() < deadline and (2 not in responses or 3 not in responses):
            line = process.stdout.readline()
            if not line:
                break
            row = json.loads(line)
            if "id" in row:
                responses[row["id"]] = row
        return {
            "ok": 2 in responses,
            "rate_limits": (responses.get(2) or {}).get("result"),
            "usage": (responses.get(3) or {}).get("result"),
            "error": None if 2 in responses else "app-server unavailable",
        }
    finally:
        process.terminate()
```

Also import `os`.

**Step 4: Run tests**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 -m unittest tests/test_dashboard.py
```

Expected: PASS.

**Step 5: Commit**

```bash
git add codex-profile-switcher/codex_profile_dashboard.py codex-profile-switcher/tests/test_dashboard.py
git commit -m "Add Codex app-server account snapshot client"
```

### Task 4: Add Dashboard Profile API

**Files:**
- Modify: `codex-profile-switcher/codex_profile_dashboard.py`
- Modify: `codex-profile-switcher/tests/test_dashboard.py`

**Step 1: Write failing test for profile JSON**

Add:

```python
class ProfileApiTests(unittest.TestCase):
    def test_build_profiles_payload_does_not_include_secret_contents(self):
        from codex_profile_dashboard import build_profiles_payload

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "profiles"
            shared = Path(tmp) / "shared"
            profile = root / "account-a"
            profile.mkdir(parents=True)
            shared.mkdir()
            (profile / "auth.json").write_text("secret-token", encoding="utf-8")

            result = build_profiles_payload(root, shared, read_remote=False)

            text = json.dumps(result)
            self.assertIn("account-a", text)
            self.assertNotIn("secret-token", text)
            self.assertEqual(result["profiles"][0]["auth"], "present")
```

**Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 -m unittest tests/test_dashboard.py
```

Expected: fails because `build_profiles_payload` does not exist.

**Step 3: Implement profile payload builder**

Add:

```python
from datetime import datetime, timezone


def build_profiles_payload(profile_root: Path, shared_home: Path, read_remote: bool = True) -> dict:
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
                    "rate_limits": normalize_rate_limits((remote or {}).get("rate_limits") or {}),
                    "usage": (remote or {}).get("usage"),
                    "remote_error": (remote or {}).get("error") if remote else None,
                }
            )
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "local_snapshot": read_local_token_snapshot(shared_home),
        "profiles": profiles,
    }
```

**Step 4: Run tests**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 -m unittest tests/test_dashboard.py
```

Expected: PASS.

**Step 5: Commit**

```bash
git add codex-profile-switcher/codex_profile_dashboard.py codex-profile-switcher/tests/test_dashboard.py
git commit -m "Add dashboard profile status payload"
```

### Task 5: Add Local HTTP Server and CLI Command

**Files:**
- Modify: `codex-profile-switcher/codex_profile.py`
- Modify: `codex-profile-switcher/codex_profile_dashboard.py`
- Modify: `codex-profile-switcher/tests/test_codex_profile.py`

**Step 1: Write failing CLI test**

Add to `test_codex_profile.py`:

```python
    def test_ui_command_starts_dashboard(self):
        import codex_profile
        from codex_profile import main

        calls = []
        old_run = codex_profile.run_dashboard
        try:
            codex_profile.run_dashboard = lambda host, port, open_browser: calls.append((host, port, open_browser)) or 0

            code = main(["ui", "--port", "9000", "--no-open"])
        finally:
            codex_profile.run_dashboard = old_run

        self.assertEqual(code, 0)
        self.assertEqual(calls, [("127.0.0.1", 9000, False)])
```

**Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 -m unittest tests/test_codex_profile.py
```

Expected: fails because `run_dashboard` and `ui` command do not exist.

**Step 3: Implement CLI hook**

In `codex_profile.py`, add:

```python
def run_dashboard(host: str, port: int, open_browser: bool) -> int:
    from codex_profile_dashboard import serve_dashboard

    return serve_dashboard(
        profile_root=get_profile_root(),
        shared_home=get_shared_home(),
        host=host,
        port=port,
        open_browser=open_browser,
    )


def cmd_ui(args: argparse.Namespace) -> int:
    return run_dashboard(args.host, args.port, args.open_browser)
```

Add parser:

```python
    ui_parser = subparsers.add_parser("ui", help="open the local profile dashboard")
    ui_parser.add_argument("--host", default="127.0.0.1")
    ui_parser.add_argument("--port", type=int, default=8765)
    ui_parser.add_argument("--no-open", dest="open_browser", action="store_false", default=True)
    ui_parser.set_defaults(func=cmd_ui)
```

**Step 4: Implement minimal server**

In `codex_profile_dashboard.py`, add `serve_dashboard()` with `ThreadingHTTPServer` and routes:

- `GET /` returns static `index.html`.
- `GET /api/profiles` returns `build_profiles_payload(...)`.
- `POST /api/switch` accepts `{"name":"..."}` and calls a callback in a later task.

**Step 5: Run tests**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 -m unittest tests/test_codex_profile.py tests/test_dashboard.py
```

Expected: PASS.

**Step 6: Commit**

```bash
git add codex-profile-switcher/codex_profile.py codex-profile-switcher/codex_profile_dashboard.py codex-profile-switcher/tests/test_codex_profile.py
git commit -m "Add local dashboard server command"
```

### Task 6: Add Static Dashboard UI

**Files:**
- Create: `codex-profile-switcher/web/index.html`
- Create: `codex-profile-switcher/web/styles.css`
- Create: `codex-profile-switcher/web/app.js`
- Modify: `codex-profile-switcher/codex_profile_dashboard.py`

**Step 1: Add static files**

Create a compact operational dashboard:

- Header with active status and refresh button.
- Account cards with profile name, auth/config badges, plan, quota, reset time.
- Token usage table from local snapshot.
- Buttons for refresh and switch.

**Step 2: Wire server to serve static assets**

Resolve assets relative to `Path(__file__).parent / "web"` and set correct content types for `.html`, `.css`, `.js`.

**Step 3: Manual smoke test**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 codex_profile.py ui --port 8765 --no-open
```

Open:

```text
http://127.0.0.1:8765
```

Expected: dashboard loads, `/api/profiles` returns JSON, no auth token contents are visible.

**Step 4: Commit**

```bash
git add codex-profile-switcher/web codex-profile-switcher/codex_profile_dashboard.py
git commit -m "Add static profile dashboard UI"
```

### Task 7: Add One-Click Switch Endpoint

**Files:**
- Modify: `codex-profile-switcher/codex_profile_dashboard.py`
- Modify: `codex-profile-switcher/codex_profile.py`
- Modify: `codex-profile-switcher/tests/test_dashboard.py`

**Step 1: Write failing test for switch callback**

Test that `POST /api/switch` validates the profile name and calls a callback with the selected profile.

**Step 2: Implement switch callback injection**

Pass a callback from `codex_profile.py`:

```python
def switch_profile_from_dashboard(name: str) -> int:
    args = argparse.Namespace(name=name, restart=True)
    return cmd_app(args)
```

`serve_dashboard()` receives `switch_profile` and the HTTP handler calls it.

**Step 3: Run tests**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 -m unittest tests/test_codex_profile.py tests/test_dashboard.py
```

Expected: PASS.

**Step 4: Commit**

```bash
git add codex-profile-switcher/codex_profile.py codex-profile-switcher/codex_profile_dashboard.py codex-profile-switcher/tests/test_dashboard.py
git commit -m "Add dashboard profile switch action"
```

### Task 8: Update Documentation and Verify

**Files:**
- Modify: `codex-profile-switcher/README.md`

**Step 1: Update README**

Document:

- `python3 codex_profile.py ui`
- Data source order: app-server, local token_count, SQLite summary.
- Security: no token printing, localhost only.
- Known limitations.

**Step 2: Run verification**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools/codex-profile-switcher
python3 -m py_compile codex_profile.py codex_profile_dashboard.py
python3 -m unittest tests/test_codex_profile.py tests/test_dashboard.py
sh -n codex-hd-master codex-hd-sarah-blackwell
```

Then from repo root:

```bash
cd /Users/dysania/program/tools/agent-tools
git diff --check
git status --short
```

Expected: all checks pass, no tracked edits remain after final commit.

**Step 3: Focused code review**

Review:

- No secret contents in logs, tests, exceptions, or JSON payloads.
- HTTP server binds to `127.0.0.1` by default.
- app-server child process is terminated on timeout/errors.
- No direct `wham` HTTP endpoint is called.
- Switch action reuses existing profile preparation logic.

**Step 4: Commit**

```bash
git add codex-profile-switcher/README.md
git commit -m "Document Codex profile dashboard"
```

### Task 9: Push and Integration

**Files:**
- No file changes.

**Step 1: Inspect commit history**

Run:

```bash
cd /Users/dysania/program/tools/agent-tools
git log --oneline -8
```

**Step 2: Push**

Run:

```bash
git push origin main
```

**Step 3: Report integration state**

Report:

- Commit SHA list.
- Push status.
- PR status or blocker.
- Merge status or blocker.
