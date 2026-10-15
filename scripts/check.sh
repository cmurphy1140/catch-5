#!/usr/bin/env bash
# The one check. Runs the package tests (engine and view model), prints the
# counts, and exits non-zero on any failure. CI runs this same file.
#
#   swift test   the engine suite (93) and the view-model suite (171); no simulator needed
set -uo pipefail
cd "$(dirname "$0")/.."

fail() { echo "check: $*" >&2; exit 2; }
command -v swift >/dev/null 2>&1 || fail "swift is missing. Install Xcode 16 or newer."

log=$(mktemp)
trap 'rm -f "$log"' EXIT

echo "== swift test"
swift test 2>&1 | tee "$log"
swift_status=${PIPESTATUS[0]}

# Swift Testing prints one "Test run with N tests ... passed|failed" line per
# test target; XCTest prints "Executed N tests, with M failures". Sum both.
sum_of() { grep -aoE "$1" "$log" | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}'; }
st_total=$(sum_of 'Test run with [0-9]+ tests?'); st_total=${st_total:-0}
xc_total=$(grep -aoE 'Executed [0-9]+ tests?' "$log" | tail -1 | grep -oE '[0-9]+' || echo 0)
xc_failed=$(grep -aoE 'with [0-9]+ failures?' "$log" | tail -1 | grep -oE '[0-9]+' || echo 0)
st_failed=$(grep -ac '^✘ Test run with' "$log" || true)
total=$((st_total + xc_total))
failed=$((st_failed + xc_failed))
passed=$((total - failed))

echo
echo "Checked $(date -u +%Y-%m-%d): swift test $passed passed, $failed failed."
if [ "$swift_status" -eq 0 ] && [ "$failed" = 0 ] && [ "$total" -gt 0 ]; then
  echo "check: passed"
else
  echo "check: FAILED" >&2
  exit 1
fi
