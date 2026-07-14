#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Codex 工具台"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ACCOUNT_SOURCE_DIR="$ROOT_DIR/../codex-profile-switcher"
ACCOUNT_RESOURCE_DIR="$RESOURCES_DIR/codex-profile-switcher"

source_fingerprint() {
    find Sources Resources -type f -print0 \
        | sort -z \
        | xargs -0 shasum -a 256 \
        | shasum -a 256 \
        | awk '{print $1}'
}

cd "$ROOT_DIR"
swift build -c release --product CodexWorkbenchApp
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$ACCOUNT_RESOURCE_DIR"
cp "$BIN_DIR/CodexWorkbenchApp" "$MACOS_DIR/CodexWorkbenchApp"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ACCOUNT_SOURCE_DIR/codex_profile.py" "$ACCOUNT_RESOURCE_DIR/codex_profile.py"
cp "$ACCOUNT_SOURCE_DIR/codex_profile_dashboard.py" "$ACCOUNT_RESOURCE_DIR/codex_profile_dashboard.py"
chmod +x "$MACOS_DIR/CodexWorkbenchApp"
/usr/libexec/PlistBuddy -c "Add :WorkbenchSourceCommit string $(git rev-parse --short HEAD 2>/dev/null || echo unknown)" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :WorkbenchSourceFingerprint string $(source_fingerprint)" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :WorkbenchBuildTimestamp string $(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign - "$APP_DIR"
touch "$APP_DIR"

echo "$APP_DIR"
