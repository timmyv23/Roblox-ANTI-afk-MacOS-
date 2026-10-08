# Roblox Idle Helper for macOS

A local macOS app with a main window, Dock icon, and menu-bar shortcut that **attempts** to keep Roblox active. It cannot guarantee prevention of the 20-minute idle kick, and cannot prevent server resets, network disconnections, or game-specific AFK rules.

## Start here

1. Move **Roblox Idle Helper.app** to a stable location, such as your Applications folder, before granting permissions. The included build is for Apple Silicon, targeting macOS 12 or later; it was compiled on macOS 27.0.1. Older macOS versions have not been tested. Intel users should build from source below.
2. Double-click the app. Its main window shows mode, permission status, and Start/Test controls. A custom moon-and-pulse icon appears in Finder and the Dock. **R ○** in the menu bar is a shortcut. It starts **stopped** every launch. Closing the window keeps the helper available; click its Dock icon to reopen it. Use Quit to exit.
3. Choose **Grant Accessibility…**. In System Settings → Privacy & Security → Accessibility (called **Device Control and Data Access** on this Mac), add/enable **Roblox Idle Helper**. Restart the helper if the permission does not take effect. It does not need Screen Recording, Full Disk Access, or Roblox credentials.
4. Join an experience, close chat/text fields/menus, and put your character somewhere a Space press/jump is harmless. The helper cannot tell whether you are playing, chatting, or at the Roblox home screen.
5. Leave the default **Briefly focus Roblox — best effort** selected. Choose **Test once (after 5 seconds)**, then stop touching the keyboard/mouse for at least 10 seconds. The timer checks every two seconds; active input defers it in 15-second increments. It should restore Roblox if minimized, attempt a Space press, and attempt to return you to the previous app and minimized state.
6. Choose **Start (every 5 minutes)**. **R ◉** means scheduling is enabled, not that idle protection is working. The first attempt is after about five seconds, subject to the same idle checks. **Stop** or **Quit** ends scheduling. No login item or background service is installed.

### Two modes

| Mode | What happens | Limit |
|---|---|---|
| Briefly focus Roblox (default) | Unminimizes one Roblox window, activates Roblox, checks focus, posts a Space down/up pair through macOS's input stream, then tries to restore the prior app/window state. | Interrupts your screen for about a second. Defers while the Mac is in use. Full-screen Spaces, activation restrictions, and inaccessible windows can prevent it working. |
| Stay in background (experimental) | Posts the same key pair directly to Roblox's process ID, without changing focus, visibility, or mouse position. | Roblox may ignore it when unfocused/minimized. There is no acknowledgment or idle-reset verification. Never silently switches to foreground mode. |

Switching modes stops scheduling; press Start again. Exactly one Roblox player must be running. It targets the official player's bundle identifier `com.roblox.RobloxPlayer`, rather than matching arbitrary process names. Roblox Studio is not targeted.

## Verify on your own setup

Use an experience where automation is permitted and jumping is harmless. First verify a visible jump using a one-shot foreground test. A visible jump proves an input was handled, **not** that the idle counter reset.

Then test each desired mode separately for **at least 25–30 minutes** without manually interacting with Roblox. Test unfocused and minimized states separately. Start with a fresh connection for each trial. Record mode, state, duration, and whether an idle disconnect occurred. Staying connected once is useful evidence for that configuration, not a guarantee; some experiences have their own idle behavior. Recheck after Roblox/macOS updates.

The status line records only an attempted event time. It does not inspect game memory, server state, the disconnect screen, or the idle timer. A one-shot test only checks the event-attempt path; no 25–30 minute in-game idle-prevention trial has been completed as part of this delivery.

If background mode fails, use the foreground mode and allow focus interruptions. If foreground mode fails despite a visible jump, this utility is not a reliable solution for that experience/client. It has no executor/injection fallback. If uninterrupted use of another app and permanently minimized Roblox are both mandatory, this implementation cannot promise your requirement is achievable.

## Build locally (no developer account or notarization)

The included app is **ad-hoc signed**, not Developer ID signed or notarized. Ad-hoc signing is a local code signature; it does not identify a trusted publisher or bypass Gatekeeper. The most transparent option is to review the source and compile it on your Mac.

1. Install Apple's Command Line Tools if needed:

   ```sh
   xcode-select --install
   ```

2. In Terminal, enter `cd `, drag this folder onto the Terminal window, and press Return. Then run:

   ```sh
   /bin/zsh ./build.command
   ```

3. Open the resulting **Roblox Idle Helper.app**. The build uses only Apple's SDK and Swift compiler; no downloaded packages, administrator access, certificates, or Apple developer membership are needed. It builds for the current Mac's architecture.

For a downloaded copy, macOS may block the unnotarized app. Prefer rebuilding locally; alternatively, after reviewing the source, use the per-app **Open Anyway** option in System Settings → Privacy & Security if available. Do not disable Gatekeeper globally. Rebuilding or moving the app can invalidate its Accessibility authorization; remove/re-add its entry if necessary. Quit it before rebuilding.

## Privacy, safety, and practical limits

- No network requests, analytics, accounts, persistent logs, event taps, screen capture, or game-file changes. Status stays in memory. The app queries the current app, Roblox window attributes, input-idle duration, modifier/Space/button states, and session state. It does not collect typed text.
- Accessibility is a powerful permission. Review the short source before granting it; revoke it when no longer needed. The code does not use AppleScript/System Events or request Automation permission.
- Space can jump, type into chat, or activate a selected control. Close text fields and menus yourself. The helper cannot determine a safe in-game context.
- Foreground mode uses global macOS events only after checking that Roblox is frontmost. That check and event delivery are **not atomic**: a focus switch at exactly the wrong moment can send Space to another app. Idle/held-key checks reduce this risk; they do not eliminate it. It does not restore focus if another app is already frontmost when the pulse finishes. Avoid sensitive input workflows while using it.
- Background mode targets only the Roblox process. Targeting does not guarantee that Roblox consumes the events. No fallback to global input occurs in this mode.
- While running, it requests prevention of ordinary idle display/system sleep. This increases battery use and may keep your display visible. It releases the request on Stop/Quit. It does not prevent lid-close sleep, manual sleep, power loss, or every OS sleep decision.
- Observed sleep, display sleep, session switching, lock, and screensaver events stop scheduling. Resuming requires Start. Some lock indicators are undocumented and best-effort; this is **not** a security boundary. Stop before manually locking/leaving the machine. It does not unlock the Mac or change lock preferences.
- Frequent input on your Mac defers foreground attempts indefinitely, so the idle kick may still occur. It never forces input merely to meet a deadline. Background mode skips when modifiers, Space, or left/right mouse buttons are held.
- Focus/minimized restoration is best-effort, especially with multiple windows and full-screen Spaces. It restores one window, not an entire desktop arrangement. If Roblox exposes no accessible window, foreground mode skips the attempt.
- No reconnection, crash recovery, anti-cheat evasion, or guarantee against account enforcement. Use only where permitted. Roblox prohibits cheating/exploiting; external key automation should not be assumed approved merely because this app doesn't modify the client.

To uninstall: Quit, delete the app/folder, and remove its Accessibility entry. No launch agents, privileged helpers, or settings files are created.

## Research and implementation rationale

Research checked 9 October 2026:

- [Roblox Player.Idled documentation](https://create.roblox.com/docs/reference/engine/classes/Player#Idled) describes client-side idle notifications and automatic disconnection after at least 20 idle minutes. It does not specify acceptance of macOS synthetic events or promise that an external keypress resets the timer.
- [Apple CGEvent](https://developer.apple.com/documentation/coregraphics/cgevent) exposes both global event posting and process-targeted posting. Those APIs support delivery attempts; they do not guarantee that a particular game's input system processes them while unfocused/minimized.
- [Apple NSRunningApplication](https://developer.apple.com/documentation/appkit/nsrunningapplication) provides activation/unhide methods. Activation is an attempt and is checked before foreground input. Restoring an AX window is necessary when minimized; merely preventing Mac sleep is not game activity.
- [Apple accessibility trust check](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions) reports whether the app is a trusted Accessibility client. Permission prompts are asynchronous; granting permission must be followed by another check.
- [Apple power assertions](https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridlesystemsleep) concern OS sleep, not Roblox idle state. The helper uses the display-idle assertion while running; this also prevents ordinary idle system sleep.
- [Roblox VirtualUser documentation](https://create.roblox.com/docs/reference/engine/classes/VirtualUser) describes limited playback and says the service has not been maintained in years. It is not an external macOS automation solution. This app does not execute Luau in other people's games.
- [Roblox cheating and exploiting guidance](https://en.help.roblox.com/hc/en-us/articles/203312450-Cheating-and-Exploiting) prohibits cheating/exploiting; this source does not certify this utility as permitted.

**Engineering inference:** foreground input is the more promising external approach because it reduces dependence on a game's background event handling. Fully background/minimized reliability is unverified; no official source above establishes it. A script that only jiggles the system mouse or runs `caffeinate` cannot be assumed to reset Roblox's idle counter.

## Delivery verification

See VALIDATION.md for the build and smoke checks actually performed. The code is intended as a transparent, best-effort utility, not a claim that minimized anti-AFK has been solved.
