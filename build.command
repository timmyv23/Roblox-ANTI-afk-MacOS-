#!/bin/zsh
set -eu
cd -- "${0:A:h}"
if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
  print 'Install Apple Command Line Tools with: xcode-select --install'
  exit 1
fi
APP="$PWD/Roblox Idle Helper.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
/bin/cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
/usr/bin/xcrun swiftc -O -swift-version 5 -target "$(uname -m)-apple-macosx12.0" RobloxIdleHelper.swift -o "$APP/Contents/MacOS/RobloxIdleHelper"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>RobloxIdleHelper</string>
<key>CFBundleIdentifier</key><string>local.roblox-idle-helper</string>
<key>CFBundleName</key><string>Roblox Idle Helper</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Ad-hoc local signing: no Apple account, certificate, payment, or notarization.
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/codesign --verify --strict "$APP"
print "Built: $APP"
print 'Move the app to a stable location before granting Accessibility, then double-click it.'
