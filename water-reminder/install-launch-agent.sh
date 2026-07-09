#!/usr/bin/env bash
set -euo pipefail

label="com.dysania.water-reminder"
tool_dir="$(cd "$(dirname "$0")" && pwd)"
binary_path="$tool_dir/water-reminder"
plist_path="$HOME/Library/LaunchAgents/$label.plist"
log_dir="$HOME/Library/Logs"
uid="$(id -u)"

swiftc "$tool_dir/water_reminder.swift" -o "$binary_path"
mkdir -p "$HOME/Library/LaunchAgents" "$log_dir"

launchctl bootout "gui/$uid/$label" >/dev/null 2>&1 || true

cat > "$plist_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$binary_path</string>
    <string>--once</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>900</integer>
  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>StandardOutPath</key>
  <string>$log_dir/water-reminder.out.log</string>
  <key>StandardErrorPath</key>
  <string>$log_dir/water-reminder.err.log</string>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$uid" "$plist_path"
launchctl enable "gui/$uid/$label"
launchctl kickstart -k "gui/$uid/$label"

echo "Installed $label"
echo "Plist: $plist_path"
echo "Binary: $binary_path"
