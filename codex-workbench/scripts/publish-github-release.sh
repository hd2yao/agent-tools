#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=""
NOTES_FILE=""
DIST_DIR="$ROOT_DIR/dist"
PUBLISH=0

usage() {
    echo "Usage: $0 --version <x.y.z> --notes-file <file> [--dist-dir <dir>] --publish" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="${2:-}"; shift 2 ;;
        --notes-file) NOTES_FILE="${2:-}"; shift 2 ;;
        --dist-dir) DIST_DIR="${2:-}"; shift 2 ;;
        --publish) PUBLISH=1; shift ;;
        *) usage; exit 2 ;;
    esac
done

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || { echo "FAIL: 缺少有效 version" >&2; exit 1; }
[[ -f "$NOTES_FILE" ]] || { echo "FAIL: 缺少 release notes" >&2; exit 1; }
DMG_PATH="$DIST_DIR/Codex-Workbench-v$VERSION-arm64.dmg"
SHA_PATH="$DMG_PATH.sha256"
[[ -f "$DMG_PATH" ]] || { echo "FAIL: 缺少 DMG：$DMG_PATH" >&2; exit 1; }
[[ -f "$SHA_PATH" ]] || { echo "FAIL: 缺少 SHA256：$SHA_PATH" >&2; exit 1; }
(cd "$DIST_DIR" && shasum -a 256 -c "$(basename "$SHA_PATH")") >/dev/null \
    || { echo "FAIL: DMG 与 SHA256 不匹配" >&2; exit 1; }

TAG="codex-workbench-v$VERSION"
echo "tag=$TAG"
echo "asset=$DMG_PATH"
echo "asset=$SHA_PATH"
if [[ "$PUBLISH" != "1" ]]; then
    echo "GATE: 未传 --publish；未创建 GitHub Release。" >&2
    exit 2
fi

command -v gh >/dev/null || { echo "FAIL: 缺少 gh" >&2; exit 1; }
if git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "FAIL: 本地 tag 已存在：$TAG" >&2
    exit 1
fi
if gh release view "$TAG" >/dev/null 2>&1; then
    echo "FAIL: GitHub Release 已存在：$TAG" >&2
    exit 1
fi

gh release create "$TAG" "$DMG_PATH" "$SHA_PATH" \
    --title "Codex 工作台 v$VERSION" \
    --notes-file "$NOTES_FILE"

echo "PASS: published $TAG"
