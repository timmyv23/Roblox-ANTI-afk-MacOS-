#!/bin/zsh
set -eu
cd -- "${0:A:h}"
CHECK_DIR=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp/}roblox-helper-check.XXXXXX")
trap '/bin/rm -rf -- "$CHECK_DIR"' EXIT
/usr/bin/awk '/^let app = NSApplication.shared/ {exit} {print}' RobloxIdleHelper.swift > "$CHECK_DIR/main.swift"
/bin/cat Checks.swift >> "$CHECK_DIR/main.swift"
/usr/bin/xcrun swiftc -swift-version 5 "$CHECK_DIR/main.swift" -o "$CHECK_DIR/checks"
HELPER_CHECKS=1 "$CHECK_DIR/checks"
