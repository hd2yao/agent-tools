#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON_BIN="${CODEX_WORKBENCH_BUILD_PYTHON:-python3}"
VENV_DIR="$ROOT_DIR/.build/release-tools/venv"

[[ "$(uname -m)" == "arm64" ]] || {
    echo "FAIL: release tools must be bootstrapped on Apple Silicon" >&2
    exit 1
}
command -v "$PYTHON_BIN" >/dev/null 2>&1 || {
    echo "FAIL: build Python not found: $PYTHON_BIN" >&2
    exit 1
}

"$PYTHON_BIN" -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --requirement "$ROOT_DIR/requirements-build.txt"

echo "PASS: release tools installed in $VENV_DIR"
