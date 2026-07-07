#!/usr/bin/env bash
set -euo pipefail

label="com.dysania.water-reminder"
tool_dir="$(cd "$(dirname "$0")" && pwd)"
plist_path="$HOME/Library/LaunchAgents/$label.plist"
uid="$(id -u)"

launchctl bootout "gui/$uid/$label" >/dev/null 2>&1 || true
rm -f "$plist_path"
pkill -f "$tool_dir/water-reminder --once" >/dev/null 2>&1 || true

echo "Uninstalled $label"
