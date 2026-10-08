# Verification record — 9 October 2026

Environment: Apple Silicon (arm64), macOS 27.0.1, Apple Command Line Tools Swift compiler. App deployment target: macOS 12.0.

Completed:

- Compiled the final Swift source and app bundle successfully.
- Verified the ad-hoc code signature with `codesign --verify --strict`.
- Validated the generated Info.plist with `plutil -lint`.
- Launch smoke check on an earlier build: Launch Services launched the helper, and its process remained running. It was stopped by default and was terminated after the check. No Roblox input was sent.
- Executed the final source's safety/state checks successfully: stopped defaults and indicator; nonnegative system input-idle query; no attempt while stopped; direct event-send rejection while stopped; both mode changes stop scheduling; next attempt scheduled five minutes later; one-shot stops; lock handler stops; termination invokes and clears a pending key-release callback.
- No Accessibility permission was granted by the agent and no game session was joined or changed.

To reproduce the non-input checks, run `/bin/zsh ./check.command` from this folder. The harness compiles the same implementation with a test entry point in a temporary directory, briefly creates a stopped menu item, and sends no keyboard input. Its temporary files are removed on exit.

Not verified:

- Native visual/menu inspection: the computer-use tool timed out trying to inspect this menu-bar app.
- Accessibility authorization flow, successful global/process-targeted event reception, foreground activation, minimized/full-screen window restoration, focus restoration, actual sleep/lock notifications, or sleep assertion behavior during a running session.
- Roblox's idle timer, 25–30 minute connection survival, individual experience behavior, or Intel/older macOS runtime compatibility.

The checks validate local control logic, not anti-AFK effectiveness. Follow README.md's in-game trial before relying on either mode.

## Version 1.1 follow-up

- Added original multi-resolution app icon, normal Dock presence, native SwiftUI main window, mode selector, permission indicator, Roblox detection, and countdown.
- Rebuilt and reran the safety/state checks successfully.
- Opened the new app and visually inspected its window: icon, text, controls, and footer rendered without clipping.
- The app subsequently reported permission ready after the user's setup interaction; the agent did not grant this permission.
- Ran one background-mode test from the new window with Roblox open in an experience. The UI reported “Space attempted at 12:34:12 AM — unverified (test stopped)” on 9 October 2026 (Asia/Kuala_Lumpur), and returned to stopped/not scheduled.
- This confirms the app reached its event-posting path and stopped after one attempt. It does not establish that Roblox consumed the key or reset its idle counter. No 25–30 minute trial has been completed.
