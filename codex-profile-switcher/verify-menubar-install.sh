#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Codex Profile Switcher"
APP_DIR="${1:-$HOME/Applications/$APP_NAME.app}"
SOURCE="$ROOT_DIR/macos/CodexProfileMenuBar.swift"
BINARY="$APP_DIR/Contents/MacOS/$APP_NAME"

if [[ ! -x "$BINARY" ]]; then
  echo "missing installed executable: $BINARY" >&2
  exit 1
fi

if [[ "$SOURCE" -nt "$BINARY" ]]; then
  echo "installed executable is older than CodexProfileMenuBar.swift" >&2
  exit 1
fi

for copy in "5小时剩余" "7日剩余" "今日 token"; do
  if ! LC_ALL=C grep -aFq "$copy" "$BINARY"; then
    echo "installed executable is missing runtime copy: $copy" >&2
    exit 1
  fi
done

echo "fresh install verified: $APP_DIR"
