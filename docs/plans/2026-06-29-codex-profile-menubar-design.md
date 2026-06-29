# Codex Profile Menu Bar Design

## Goal

Replace the browser-first dashboard with a native macOS menu bar companion app. The app should live in the top macOS menu bar, show Codex account quota/status at a glance, and switch Codex Desktop accounts without opening a web page.

## Recommended Approach

Use a small native Swift/AppKit app as the first packaged UI. The existing Python profile switcher remains the source of truth for profile discovery, quota reads, and account switching. Swift shells out to the local `codex_profile.py` script for structured JSON status and switch actions.

This is lighter than Tauri for a menu bar utility and avoids adding a frontend build chain. It is also cleaner than Python GUI wrappers because macOS menu bar behavior is first-class in AppKit.

## User Experience

- A persistent menu bar item shows a compact Codex label and the lowest remaining primary quota percent.
- Clicking it opens a native menu.
- The menu shows each profile with:
  - auth/config state
  - plan type
  - primary remaining percent and reset time
  - secondary remaining percent and reset time
  - reset credits when available
- Each profile has a switch command.
- The menu has refresh, open Codex, and quit commands.

The first version intentionally uses native menus instead of a custom popover. It will feel less flashy but much more reliable, fast, and menu-bar-native.

## Architecture

```text
CodexProfileMenuBar.app
  Swift AppKit status item
    -> python3 codex_profile.py status --json
    -> python3 codex_profile.py app <profile>

codex_profile.py
  status --json
    -> build_profiles_payload(...)
    -> app-server per CODEX_HOME
    -> local rollout token_count fallback
```

## Data Flow

1. Menu bar app launches.
2. It runs `python3 codex_profile.py status --json`.
3. Python returns the same structured payload used by the dashboard API.
4. Swift decodes only the fields needed for the menu.
5. User clicks switch.
6. Swift runs `python3 codex_profile.py app <profile>`.
7. Python restarts Codex Desktop with the selected profile.

## Security

- Swift never reads `auth.json` directly.
- Python status output includes only presence flags and account status returned by app-server.
- No direct `wham` HTTP calls are added.
- No telemetry, analytics, or remote service calls are added by the app itself.

## Build Output

The build script creates:

```text
codex-profile-switcher/build/Codex Profile Switcher.app
```

The app bundle is unsigned for local use in MVP.

## Later Improvements

- Use an SF Symbol-only status item once the first version is validated.
- Add a custom popover with richer layout if the native menu feels too cramped.
- Add launch-at-login support.
- Add signed packaging.
