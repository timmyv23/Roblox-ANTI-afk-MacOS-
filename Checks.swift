let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let helper = Helper()
helper.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
assert(!helper.running && helper.foreground && helper.assertion == 0)
assert(helper.item.button?.title == "R ○")
assert(helper.idleSeconds() >= 0)
helper.attempt()
assert(!helper.busy)
var rejected = false
helper.sendSpace(NSRunningApplication.current, global: true) { message in
    rejected = message.contains("skipped")
}
assert(rejected, "Stopped helper must reject even a direct sendSpace call")
helper.selectBackground()
assert(!helper.foreground && !helper.running)
helper.selectForeground()
assert(helper.foreground && !helper.running)
helper.running = true
helper.finishAttempt("test attempt")
assert(helper.nextAttempt.timeIntervalSinceNow > 298)
helper.oneShot = true
helper.finishAttempt("one shot")
assert(!helper.running && !helper.oneShot && helper.assertion == 0)
helper.running = true
helper.lockStop()
assert(!helper.running && helper.nextAttempt == Date.distantFuture)
var released = 0
helper.releaseKey = { released += 1 }
helper.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
assert(released == 1 && helper.releaseKey == nil)
print("PASS: stopped defaults, indicator, stopped attempt, stopped event guard, both mode changes, five-minute schedule, one-shot stop, lock stop, pending key release on termination")
