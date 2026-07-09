#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Codex Profile Switcher"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
HELPER_DIR="$RESOURCES_DIR/codex-profile-switcher"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$HELPER_DIR"

swiftc \
  "$ROOT_DIR/macos/CodexProfileMenuBar.swift" \
  -framework AppKit \
  -o "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Codex Profile Switcher</string>
  <key>CFBundleIdentifier</key>
  <string>com.hd2yao.codex-profile-switcher</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Codex Profile Switcher</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.8.2</string>
  <key>CFBundleVersion</key>
  <string>15</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

cp "$ROOT_DIR/codex_profile.py" "$HELPER_DIR/"
cp "$ROOT_DIR/codex_profile_dashboard.py" "$HELPER_DIR/"
chmod +x "$MACOS_DIR/$APP_NAME"

echo "$APP_DIR"
