#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Codex Profile Switcher"
INSTALL_DIR="${1:-$HOME/Applications}"
BUILD_APP="$ROOT_DIR/build/$APP_NAME.app"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"

"$ROOT_DIR/build-menubar-app.sh" >/dev/null
mkdir -p "$INSTALL_DIR"
rm -rf "$TARGET_APP"
ditto "$BUILD_APP" "$TARGET_APP"
"$ROOT_DIR/verify-menubar-install.sh" "$TARGET_APP" >/dev/null

echo "$TARGET_APP"
