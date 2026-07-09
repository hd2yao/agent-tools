#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

require_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "Expected output to contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

output="$(swift water_reminder.swift \
  --dry-run \
  --once \
  --interval 15 \
  --display-seconds 4 \
  --exit-seconds 2 \
  --confirm-text '知道了' \
  --auto-confirm-seconds 1 \
  --message '太辛苦了！快去喝水！')"

require_contains "$output" "message=太辛苦了！快去喝水！"
require_contains "$output" "interval_minutes=15"
require_contains "$output" "entry_seconds=4"
require_contains "$output" "exit_seconds=2"
require_contains "$output" "mode=once"
require_contains "$output" "start_now=false"
require_contains "$output" "confirmation=click"
require_contains "$output" "confirm_text=知道了"
require_contains "$output" "auto_confirm_seconds=1"
require_contains "$output" "window_scope=compact"
require_contains "$output" "click_blocking=confirm_button"
require_contains "$output" "confirm_control=nsbutton"
require_contains "$output" "accepts_first_mouse=true"
require_contains "$output" "visual_style=macos_compact_toast"
require_contains "$output" "icon_style=folded_paper_airplane"
require_contains "$output" "visual_hierarchy=message_button_airplane"
require_contains "$output" "motion=slow_enter_wait_confirm_exit"
require_contains "$output" "icon_semantics=airplane_leads_banner_trails"
require_contains "$output" "decorations=minimal"
require_contains "$output" "ui=appkit_compact_reminder"

repeat_output="$(swift water_reminder.swift --dry-run)"

require_contains "$repeat_output" "message=太辛苦了！快去喝水！"
require_contains "$repeat_output" "interval_minutes=15"
require_contains "$repeat_output" "entry_seconds=4"
require_contains "$repeat_output" "exit_seconds=1.5"
require_contains "$repeat_output" "mode=repeat"
require_contains "$repeat_output" "start_now=false"
require_contains "$repeat_output" "confirmation=click"
require_contains "$repeat_output" "confirm_text=知道了"
require_contains "$repeat_output" "auto_confirm_seconds=none"
require_contains "$repeat_output" "window_scope=compact"
require_contains "$repeat_output" "click_blocking=confirm_button"
require_contains "$repeat_output" "confirm_control=nsbutton"
require_contains "$repeat_output" "accepts_first_mouse=true"
require_contains "$repeat_output" "visual_style=macos_compact_toast"
require_contains "$repeat_output" "icon_style=folded_paper_airplane"
require_contains "$repeat_output" "visual_hierarchy=message_button_airplane"
require_contains "$repeat_output" "motion=slow_enter_wait_confirm_exit"
require_contains "$repeat_output" "icon_semantics=airplane_leads_banner_trails"
require_contains "$repeat_output" "decorations=minimal"
require_contains "$repeat_output" "ui=appkit_compact_reminder"

[[ -x install-launch-agent.sh ]]
[[ -x uninstall-launch-agent.sh ]]
bash -n install-launch-agent.sh
bash -n uninstall-launch-agent.sh
