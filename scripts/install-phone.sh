#!/bin/sh
# Build Catch 5 signed for a connected, paired iPhone, install it and launch it.
# Usage: scripts/install-phone.sh [device-name-or-id]
# With a free personal team the install stops opening after seven days; run this again.
set -e
cd "$(dirname "$0")/.."

# The phone may be running a newer iOS than the default Xcode can build for, so pick the newest
# Xcode installed rather than assuming /Applications. Set DEVELOPER_DIR yourself to override.
if [ -z "${DEVELOPER_DIR:-}" ]; then
  best=""; best_version=""
  for candidate in /Applications/Xcode.app "$HOME/Desktop/Xcode.app" /Applications/Xcode-beta.app; do
    [ -d "$candidate/Contents/Developer" ] || continue
    version=$(defaults read "$candidate/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null) || continue
    # Highest version wins; sort -V puts it last.
    if [ -z "$best_version" ] || [ "$(printf '%s\n%s\n' "$best_version" "$version" | sort -V | tail -1)" = "$version" ]; then
      best="$candidate"; best_version="$version"
    fi
  done
  [ -n "$best" ] || { echo "No Xcode found." >&2; exit 1; }
  export DEVELOPER_DIR="$best/Contents/Developer"
  echo "Using Xcode $best_version at $best"
fi

device="${1:-}"
if [ -z "$device" ]; then
  # Only a real iPhone: the Reality column separates physical hardware from simulators, and without
  # that filter a booted simulator is picked first and the build silently never reaches the phone.
  # An Apple Watch is physical too, so the model column has to say iPhone as well. Hardware UDIDs
  # are 8-16 hex, unlike the 8-4-4-4-12 UUID a simulator carries.
  listing=$(xcrun devicectl list devices 2>/dev/null | grep 'physical' | grep 'iPhone' || true)
  device=$(printf '%s\n' "$listing" | grep -E ' (connected|available)' \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}|[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
    | head -1)
  # The summary column above lags behind reality and reports a live phone as merely "available",
  # so ask the device itself rather than warning on the listing and crying wolf.
  if [ -n "$device" ] && ! xcrun devicectl device info details --device "$device" 2>/dev/null \
      | grep -q 'Device State: connected'; then
    echo "Warning: the iPhone is paired but not reachable. Plug it in and unlock it, or this will fail." >&2
  fi
fi
if [ -z "$device" ]; then
  echo "No paired iPhone found. Plug it in, unlock it, then: xcrun devicectl manage pair --device <name>" >&2
  exit 1
fi

# App/Explainer is bundled as a folder reference, so everything inside it is copied into the app
# verbatim. A .DS_Store that Finder leaves there travels with it and fails code signing with
# "resource fork, Finder information, or similar detritus not allowed", which names the bundle
# rather than the file, so it is worth removing before every build rather than debugging again.
find App/Explainer -name '.DS_Store' -delete 2>/dev/null || true

echo "Building for $device"
xcodebuild -project CatchFive.xcodeproj -scheme CatchFiveApp -destination "id=$device" \
  -derivedDataPath work/derived -allowProvisioningUpdates build -quiet
app=work/derived/Build/Products/Debug-iphoneos/CatchFiveApp.app
echo "Installing $app"
xcrun devicectl device install app --device "$device" "$app" >/dev/null
echo "Launching"
xcrun devicectl device process launch --device "$device" com.cardgame.catchfive >/dev/null
echo "Catch 5 is running on the phone."
