#!/bin/sh
# Build Catch 5 signed for a connected, paired iPhone, install it and launch it.
# Usage: scripts/install-phone.sh [device-name-or-id]
# With a free personal team the install stops opening after seven days; run this again.
set -e
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

device="${1:-}"
if [ -z "$device" ]; then
  # The first phone that is connected or available; the identifier is the UUID column.
  device=$(xcrun devicectl list devices 2>/dev/null | grep -E ' (connected|available)' \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
fi
if [ -z "$device" ]; then
  echo "No paired iPhone is connected. Plug it in, unlock it, then: xcrun devicectl manage pair --device <name>" >&2
  exit 1
fi

echo "Building for $device"
xcodebuild -project CatchFive.xcodeproj -scheme CatchFiveApp -destination "id=$device" \
  -derivedDataPath work/derived -allowProvisioningUpdates build -quiet
app=work/derived/Build/Products/Debug-iphoneos/CatchFiveApp.app
echo "Installing $app"
xcrun devicectl device install app --device "$device" "$app" >/dev/null
echo "Launching"
xcrun devicectl device process launch --device "$device" com.cardgame.catchfive >/dev/null
echo "Catch 5 is running on the phone."
