#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Codex 观测站"
INSTALL_ROOT="${CODEX_WORKBENCH_INSTALL_ROOT:-$HOME/Applications}"
APP_DIR="$INSTALL_ROOT/$APP_NAME.app"
PLIST="$APP_DIR/Contents/Info.plist"
BINARY="$APP_DIR/Contents/MacOS/CodexWorkbenchApp"

source_fingerprint() {
    cd "$ROOT_DIR"
    find Sources Resources scripts -type f \
        ! -name 'AppIcon-1024.png' \
        ! -name 'AppIcon.icns' \
        -print0 \
        | sort -z \
        | xargs -0 shasum -a 256 \
        | shasum -a 256 \
        | awk '{print $1}'
}

[[ -d "$APP_DIR" ]] || { echo "FAIL: 未安装 $APP_DIR" >&2; exit 1; }
[[ -x "$BINARY" ]] || { echo "FAIL: 缺少可执行文件" >&2; exit 1; }
[[ -f "$APP_DIR/Contents/Resources/AppIcon.icns" ]] || { echo "FAIL: 缺少应用图标" >&2; exit 1; }
[[ -f "$APP_DIR/Contents/Resources/codex-profile-switcher/codex_profile_dashboard.py" ]] \
    || { echo "FAIL: 缺少账号模块资源" >&2; exit 1; }
[[ -f "$APP_DIR/Contents/Resources/codex-profile-switcher/codex_profile.py" ]] \
    || { echo "FAIL: 缺少账号切换资源" >&2; exit 1; }

plutil -lint "$PLIST" >/dev/null

EXPECTED_FINGERPRINT="$(source_fingerprint)"
INSTALLED_FINGERPRINT="$(defaults read "$PLIST" WorkbenchSourceFingerprint)"
[[ "$EXPECTED_FINGERPRINT" == "$INSTALLED_FINGERPRINT" ]] \
    || { echo "FAIL: 安装包不是当前源码构建" >&2; exit 1; }

ACCOUNT_SOURCE_DIR="$ROOT_DIR/../codex-profile-switcher"
ACCOUNT_RESOURCE_DIR="$APP_DIR/Contents/Resources/codex-profile-switcher"
EXPECTED_ACCOUNT_FINGERPRINT="$(bash "$ROOT_DIR/scripts/account-resource-fingerprint.sh" "$ACCOUNT_SOURCE_DIR")"
PLIST_ACCOUNT_FINGERPRINT="$(defaults read "$PLIST" WorkbenchAccountBackendFingerprint)"
INSTALLED_ACCOUNT_FINGERPRINT="$(bash "$ROOT_DIR/scripts/account-resource-fingerprint.sh" "$ACCOUNT_RESOURCE_DIR")"
[[ "$EXPECTED_ACCOUNT_FINGERPRINT" == "$PLIST_ACCOUNT_FINGERPRINT" \
    && "$EXPECTED_ACCOUNT_FINGERPRINT" == "$INSTALLED_ACCOUNT_FINGERPRINT" ]] \
    || { echo "FAIL: 打包的账号后端不是当前源码" >&2; exit 1; }

codesign --verify --deep --strict "$APP_DIR"

BUNDLE_ID="$(defaults read "$PLIST" CFBundleIdentifier)"
VERSION="$(defaults read "$PLIST" CFBundleShortVersionString)"
COMMIT="$(defaults read "$PLIST" WorkbenchSourceCommit)"
BUILT_AT="$(defaults read "$PLIST" WorkbenchBuildTimestamp)"
BINARY_SHA="$(shasum -a 256 "$BINARY" | awk '{print $1}')"

echo "PASS: $APP_NAME $VERSION"
echo "bundle_id=$BUNDLE_ID"
echo "source_commit=$COMMIT"
echo "source_fingerprint=$INSTALLED_FINGERPRINT"
echo "account_backend_fingerprint=$INSTALLED_ACCOUNT_FINGERPRINT"
echo "binary_sha256=$BINARY_SHA"
echo "built_at=$BUILT_AT"
