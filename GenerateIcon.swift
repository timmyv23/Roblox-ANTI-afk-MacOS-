import AppKit

// Original geometric icon: a crescent and an activity pulse. No Roblox branding.
let destination = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 198, yRadius: 198)
NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.36, alpha: 1),
           ending: NSColor(calibratedRed: 0.39, green: 0.30, blue: 0.82, alpha: 1))!.draw(in: tile, angle: 55)
let moon = NSBezierPath()
moon.move(to: NSPoint(x: 603, y: 789))
moon.curve(to: NSPoint(x: 603, y: 259), controlPoint1: NSPoint(x: 223, y: 892), controlPoint2: NSPoint(x: 152, y: 266))
moon.curve(to: NSPoint(x: 603, y: 789), controlPoint1: NSPoint(x: 385, y: 364), controlPoint2: NSPoint(x: 386, y: 646))
moon.close()
NSColor(calibratedRed: 0.94, green: 0.96, blue: 1, alpha: 1).setFill()
moon.fill()
let pulse = NSBezierPath()
pulse.move(to: NSPoint(x: 444, y: 435))
pulse.line(to: NSPoint(x: 551, y: 435))
pulse.line(to: NSPoint(x: 610, y: 570))
pulse.line(to: NSPoint(x: 684, y: 328))
pulse.line(to: NSPoint(x: 747, y: 461))
pulse.line(to: NSPoint(x: 824, y: 461))
pulse.lineWidth = 42
pulse.lineCapStyle = .round
pulse.lineJoinStyle = .round
NSColor(calibratedRed: 0.42, green: 1, blue: 0.77, alpha: 1).setStroke()
pulse.stroke()
NSColor(calibratedWhite: 1, alpha: 0.75).setFill()
NSBezierPath(ovalIn: NSRect(x: 731, y: 699, width: 25, height: 25)).fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
