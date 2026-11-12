#!/bin/sh
# Build Catch 5 for the simulator, boot a simulator, install the app, launch it and stream its output.
# Usage: scripts/run-simulator.sh [device-name-or-udid]
# IntelliJ runs this from the "Catch 5 Simulator" configuration in .run/.
# CATCH5_HEADLESS=1 boots without opening the Simulator window and returns once the app launches,
# for checks run from a script.
set -e
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

device="${1:-Catch 5 iPhone}"
# A list line reads "    Catch 5 iPhone (UDID) (Shutdown)": match the whole name or the UDID.
udid=$(xcrun simctl list devices available | grep -F -e "$device (" -e "($device)" \
  | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
if [ -z "$udid" ]; then
  echo "No available simulator is named \"$device\". Pick one from: xcrun simctl list devices available" >&2
  exit 1
fi

echo "Building"
python3 scripts/build-simulator.py
echo "Booting $device ($udid)"
xcrun simctl bootstatus "$udid" -b >/dev/null
if [ -z "${CATCH5_HEADLESS:-}" ]; then
  open "$DEVELOPER_DIR/Applications/Simulator.app"
fi
echo "Installing"
xcrun simctl install "$udid" work/simulator-build/CatchFive.app
echo "Launching"
if [ -n "${CATCH5_HEADLESS:-}" ]; then
  xcrun simctl launch --terminate-running-process "$udid" com.cardgame.catchfive >/dev/null
  echo "Catch 5 is running on $device."
  exit 0
fi
# Stay attached, so the app's print() output streams into IntelliJ's Run window.
echo "Catch 5 is running on $device. Its print() output follows."
exec xcrun simctl launch --console-pty --terminate-running-process "$udid" com.cardgame.catchfive
