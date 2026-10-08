import AppKit
import SwiftUI
import ApplicationServices
import IOKit.pwr_mgt

final class DashboardState: ObservableObject {
    @Published var status = "Stopped"
    @Published var running = false
    @Published var foreground = true
    @Published var trusted = false
    @Published var robloxOpen = false
    @Published var next = "Not scheduled"
    @Published var busy = false
}

struct Dashboard: View {
    @ObservedObject var state: DashboardState
    let toggle: () -> Void
    let test: () -> Void
    let permission: () -> Void
    let setMode: (Bool) -> Void
    let about: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Roblox Idle Helper").font(.system(size: 26, weight: .bold))
                    Text("A little help while you step away.").foregroundColor(.secondary)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Circle().fill(state.running ? Color.green : Color.secondary).frame(width: 9, height: 9)
                    Text(state.running ? "Helper running" : "Helper stopped").font(.headline)
                    Spacer()
                    Text("EVERY 5 MIN").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.secondary)
                }
                Text(state.status).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                Divider()
                HStack {
                    Label(state.robloxOpen ? "Roblox open" : "Open Roblox to begin", systemImage: "gamecontroller")
                    Spacer()
                    Text(state.next).monospacedDigit()
                }.font(.system(size: 12)).foregroundColor(.secondary)
            }.padding(18).background(Color(NSColor.controlBackgroundColor)).cornerRadius(14)

            VStack(alignment: .leading, spacing: 10) {
                Text("HOW TO SEND INPUT").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                Picker("Mode", selection: Binding(get: { state.foreground }, set: setMode)) {
                    Text("Briefly focus Roblox").tag(true)
                    Text("Background · experimental").tag(false)
                }.pickerStyle(.segmented).labelsHidden().disabled(state.busy)
                Text(state.foreground
                    ? "Briefly restores Roblox, presses Space, then tries to return you to your previous app. Waits while you use the Mac."
                    : "Sends Space directly to Roblox without bringing it forward. Roblox may ignore this, especially when minimized.")
                    .font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                Image(systemName: state.trusted ? "checkmark.shield.fill" : "lock.shield")
                    .font(.system(size: 22)).foregroundColor(state.trusted ? .green : .orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.trusted ? "Permission ready" : "Permission needed").font(.system(size: 13, weight: .semibold))
                    Text("Accessibility / Device Control access").font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
                Button(state.trusted ? "Settings…" : "Set up…", action: permission)
            }.padding(14).background(Color(NSColor.controlBackgroundColor)).cornerRadius(12)
            HStack(spacing: 12) {
                Button(state.running ? "Stop helper" : "Start helper", action: toggle)
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(state.busy && !state.running)
                Button("Test once", action: test).controlSize(.large).disabled(state.busy)
                Spacer()
                Button(action: about) { Image(systemName: "questionmark.circle").font(.system(size: 19)) }.buttonStyle(.plain).help("How this works")
            }
            Text("Close chat and menus first: Space may jump or type. Input attempts do not confirm that Roblox’s idle timer reset.")
                .font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack {
                Label("Local only · No account required", systemImage: "network.slash")
                Spacer()
                Text("Unofficial utility · v1.1")
            }.font(.system(size: 10)).foregroundColor(.secondary)
        }.padding(28).frame(width: 616, height: 716).background(Color(NSColor.windowBackgroundColor))
    }
}

// Local, unsandboxed app. No networking, event taps, or Roblox modification.
final class Helper: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    let dashboard = DashboardState()
    let bundleID = "com.roblox.RobloxPlayer"
    var item: NSStatusItem!
    var status = "Stopped — idle prevention is unverified"
    var running = false
    var foreground = true
    var busy = false
    var suspended = false
    var nextAttempt = Date.distantFuture
    var assertion: IOPMAssertionID = 0
    var releaseKey: (() -> Void)?
    var timer: Timer?
    var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        rebuild()
        if ProcessInfo.processInfo.environment["HELPER_CHECKS"] != "1" { showWindow() }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.willSleepNotification,
                     NSWorkspace.screensDidSleepNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.suspended = true
                self?.stop("Stopped after session/display sleep — start manually")
            })
        }
        for name in [NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.didWakeNotification,
                     NSWorkspace.screensDidWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.suspended = false
            })
        }
        // These distributed lock notifications are best-effort; they are not a public security boundary.
        for name in ["com.apple.screenIsLocked", "com.apple.screensaver.didstart"] {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(lockStop), name: Notification.Name(name), object: nil)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.refreshDashboard()
            guard self.running, !self.busy, Date() >= self.nextAttempt else { return }
            self.attempt()
        }
    }

    @objc func showWindow() {
        if window == nil {
            let view = Dashboard(state: dashboard,
                toggle: { [weak self] in self?.toggle() },
                test: { [weak self] in self?.test() },
                permission: { [weak self] in self?.permission() },
                setMode: { [weak self] value in
                    if value { self?.selectForeground() } else { self?.selectBackground() }
                }, about: { [weak self] in self?.about() })
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 616, height: 716),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            panel.title = "Roblox Idle Helper"
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: view)
            panel.center()
            window = panel
            let main = NSMenu()
            let appMenu = NSMenu()
            add(appMenu, "About Roblox Idle Helper", #selector(about))
            appMenu.addItem(.separator())
            add(appMenu, "Quit Roblox Idle Helper", #selector(quit), "q")
            let root = NSMenuItem()
            root.submenu = appMenu
            main.addItem(root)
            NSApp.mainMenu = main
        }
        refreshDashboard()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }
    func refreshDashboard() {
        dashboard.status = status
        dashboard.running = running
        dashboard.foreground = foreground
        dashboard.busy = busy
        dashboard.trusted = AXIsProcessTrusted()
        dashboard.robloxOpen = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        if running {
            let seconds = max(0, Int(nextAttempt.timeIntervalSinceNow))
            dashboard.next = busy ? "Attempting input…" : String(format: "Next check %d:%02d", seconds / 60, seconds % 60)
        } else { dashboard.next = "Not scheduled" }
    }
    func rebuild() {
        refreshDashboard()
        item.button?.title = running ? "R ◉" : "R ○"
        let menu = NSMenu()
        let line = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        line.isEnabled = false
        menu.addItem(line)
        add(menu, "Open Roblox Idle Helper", #selector(showWindow))
        menu.addItem(NSMenuItem.separator())
        add(menu, running ? "Stop" : "Start (every 5 minutes)", #selector(toggle))
        add(menu, "Test once (after 5 seconds)", #selector(test))
        menu.addItem(NSMenuItem.separator())
        let fg = add(menu, "Briefly focus Roblox — best effort", #selector(selectForeground))
        fg.state = foreground ? .on : .off
        let bg = add(menu, "Stay in background — experimental", #selector(selectBackground))
        bg.state = foreground ? .off : .on
        menu.addItem(NSMenuItem.separator())
        add(menu, "Grant Accessibility…", #selector(permission))
        add(menu, "How this works…", #selector(about))
        add(menu, "Quit", #selector(quit), "q")
        item.menu = menu
    }
    @discardableResult func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        menu.addItem(entry)
        return entry
    }
    func say(_ value: String) { status = value; rebuild() }
    @objc func permission() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func toggle() {
        if running { stop("Stopped") } else { start() }
    }
    func start() {
        guard !busy else { return }
        oneShot = false
        guard AXIsProcessTrusted() else { say("Accessibility permission required"); permission(); return }
        guard sessionAvailable() else { say("Unlock/wake this session before starting"); return }
        running = true
        // Prevent ordinary idle display/system sleep only while enabled; never disable the user's lock settings.
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), "Roblox Idle Helper is running" as CFString, &assertion)
        if result != kIOReturnSuccess { assertion = 0 }
        nextAttempt = Date().addingTimeInterval(5)
        say(assertion == 0 ? "Starting in 5s; could not prevent idle sleep" : "Starting in 5s — Space may jump or type")
    }
    func stop(_ reason: String) {
        running = false
        nextAttempt = .distantFuture
        if assertion != 0 { IOPMAssertionRelease(assertion); assertion = 0 }
        say(reason)
    }
    @objc func lockStop() { stop("Stopped on lock/screensaver — start manually") }
    @objc func test() {
        guard !busy else { return }
        if !running { start() } else { nextAttempt = Date().addingTimeInterval(5); say("Test scheduled in 5 seconds") }
        // Test is a single attempt, including when Start was used to obtain the sleep assertion.
        oneShot = true
    }
    var oneShot = false
    @objc func selectForeground() { guard !busy else { return }; stop("Mode changed — press Start"); foreground = true; oneShot = false; rebuild() }
    @objc func selectBackground() { guard !busy else { return }; stop("Experimental background mode — press Start"); foreground = false; oneShot = false; rebuild() }
    @objc func quit() { stop("Stopped"); NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        releaseKey?()
        releaseKey = nil
        if assertion != 0 { IOPMAssertionRelease(assertion) }
    }
    @objc func about() {
        let alert = NSAlert()
        alert.messageText = "Roblox Idle Helper"
        alert.informativeText = "Every 5 minutes, attempts one Space press. Foreground mode briefly restores/focuses Roblox, then attempts to return focus and minimized state. It waits while you are using the Mac. Background mode targets Roblox without focusing it and may be ignored. Neither mode can verify the Roblox idle timer or prevent all kicks/resets. Close chat and menus first. Stops on observed sleep/lock; Start resumes manually. No network, accounts, telemetry, or injected game scripts. Read README.md for limits and testing."
        alert.runModal()
    }
    func sessionAvailable() -> Bool {
        guard !suspended, let session = CGSessionCopyCurrentDictionary() as? [String: Any],
              session[kCGSessionOnConsoleKey as String] as? Bool == true else { return false }
        // Supplemental undocumented flag: fail closed when explicitly locked, but absence is not proof of unlock.
        return session["CGSSessionScreenIsLocked"] as? Bool != true
    }
    func idleSeconds() -> Double {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~UInt32(0))!)
    }
    func controlsReleased() -> Bool {
        let flags = CGEventSource.flagsState(.hidSystemState)
        if !flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty { return false }
        return !CGEventSource.keyState(.hidSystemState, key: 49)
            && !CGEventSource.buttonState(.hidSystemState, button: .left)
            && !CGEventSource.buttonState(.hidSystemState, button: .right)
    }
    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }
    func attempt() {
        guard running, !busy else { return }
        guard AXIsProcessTrusted(), sessionAvailable() else { stop("Stopped — permission or active session unavailable"); return }
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter { !$0.isTerminated }
        guard apps.count == 1, let roblox = apps.first else {
            finishAttempt(apps.isEmpty ? "No Roblox player found; waiting" : "Multiple Roblox players — skipped")
            return
        }
        // Defer instead of stealing focus during real keyboard/mouse use. This can allow an idle kick.
        guard controlsReleased(), !foreground || idleSeconds() >= 10 else {
            nextAttempt = Date().addingTimeInterval(15)
            say("Deferred while you use the Mac; retry in 15s")
            return
        }
        busy = true
        if !foreground {
            sendSpace(roblox, global: false) { [weak self] result in
                self?.busy = false
                self?.finishAttempt(result)
            }
            return
        }
        let previous = NSWorkspace.shared.frontmostApplication
        let wasHidden = roblox.isHidden
        let axApp = AXUIElementCreateApplication(roblox.processIdentifier)
        AXUIElementSetMessagingTimeout(axApp, 1)
        let windows = attribute(axApp, kAXWindowsAttribute) as? [AXUIElement] ?? []
        guard let window = windows.first else {
            busy = false
            finishAttempt("No accessible Roblox window — skipped")
            return
        }
        AXUIElementSetMessagingTimeout(window, 1)
        let minimized = attribute(window, kAXMinimizedAttribute) as? Bool == true
        if minimized {
            guard AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success else {
                busy = false; finishAttempt("Could not restore Roblox window — skipped"); return
            }
        }
        roblox.unhide()
        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        activate(roblox)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            self.sendSpace(roblox, global: true) { result in
                // Don't steal focus back if the user has switched elsewhere during the attempt.
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == roblox.processIdentifier {
                    if minimized { _ = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue) }
                    if wasHidden { _ = roblox.hide() }
                    if let previous = previous, previous.processIdentifier != roblox.processIdentifier, !previous.isTerminated {
                        self.activate(previous)
                    }
                }
                self.busy = false
                self.finishAttempt(result)
            }
        }
    }
    func activate(_ target: NSRunningApplication) {
        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(to: target)
            _ = target.activate(options: [])
        } else {
            _ = target.activate(options: [.activateIgnoringOtherApps])
        }
    }
    func sendSpace(_ app: NSRunningApplication, global: Bool, completion: @escaping (String) -> Void) {
        guard running, AXIsProcessTrusted(), sessionAvailable(), !app.isTerminated, controlsReleased(),
              !global || (NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier && idleSeconds() >= 2) else {
            completion("Safety/focus check failed — input skipped"); return
        }
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: false) else {
            completion("Could not create input events"); return
        }
        down.flags = []; up.flags = []
        if global { down.post(tap: .cghidEventTap) } else { down.postToPid(app.processIdentifier) }
        // Always release after a successful down, even if Stop is clicked in the interim.
        releaseKey = {
            if global { up.post(tap: .cghidEventTap) } else if !app.isTerminated { up.postToPid(app.processIdentifier) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.releaseKey?()
            self?.releaseKey = nil
            completion("Space attempted at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) — unverified")
        }
    }
    func finishAttempt(_ message: String) {
        if !running { return }
        if oneShot { oneShot = false; stop(message + " (test stopped)") }
        else { nextAttempt = Date().addingTimeInterval(300); say(message) }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Helper()
app.delegate = delegate
app.run()
