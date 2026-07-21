#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

swift run --quiet CodexWorkbenchCoreTests
"$ROOT_DIR/scripts/test-app-model.sh"
