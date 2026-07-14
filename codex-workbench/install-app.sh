#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Codex 工具台"
SOURCE_APP="$ROOT_DIR/build/$APP_NAME.app"
INSTALL_ROOT="${CODEX_WORKBENCH_INSTALL_ROOT:-$HOME/Applications}"
DEST_APP="$INSTALL_ROOT/$APP_NAME.app"
mkdir -p "$INSTALL_ROOT"
STAGE_DIR="$(mktemp -d "$INSTALL_ROOT/.codex-workbench-install.XXXXXX")"

cleanup() {
    rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/build-app.sh"
ditto "$SOURCE_APP" "$STAGE_DIR/$APP_NAME.app"

if [[ -e "$DEST_APP" ]]; then
    mv "$DEST_APP" "$STAGE_DIR/previous.app"
fi
if ! mv "$STAGE_DIR/$APP_NAME.app" "$DEST_APP"; then
    if [[ -e "$STAGE_DIR/previous.app" ]]; then
        mv "$STAGE_DIR/previous.app" "$DEST_APP"
    fi
    echo "安装失败，已恢复原有 App。" >&2
    exit 1
fi

echo "已安装：$DEST_APP"
echo "可直接从 Finder、Spotlight 或菜单栏打开。"
