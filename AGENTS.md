# Catch 5

## Current Status
Single-player Catch 5 is feature complete: pure Swift rules engine, three computer opponents (Easy and Standard), replay-log save/resume, and a SwiftUI table with hints, tap-to-explain, hand review, undo, scoreboard, match history, settings, a five-lesson tutorial, the documentation pages bundled for offline reading, Dynamic Type and VoiceOver. 99 tests pass. The app runs in the simulator via `scripts/build-simulator.py` and on Connor's iPhone via `xcodebuild` plus `devicectl` (`docs/device-install.md`).

## Architecture
Swift Testing and a dependency-free Swift package for rules (`Sources/CatchFive`); `GameModel` and SwiftUI views consume it (`Sources/CatchFiveUI`). Team 0 seats are 0/2, team 1 seats are 1/3; turns advance in ascending seat order modulo four. Computers and hints see only a `PlayerView`.

## Aesthetic North Star
A readable, welcoming card table: felt gradient, ivory cards, gold accents, understated controls, one solid gold button per screen.

## Living documentation
`docs/learning-path.md` indexes the explainer pages (build-and-run, architecture, game-flow, types-and-functions, testing, decisions, code-map, roadmap, tutorial-spec, device-install) with Mermaid diagrams. Any commit that adds, renames or removes a type, function, phase or test must update the matching page in the same commit, and new design choices get a numbered entry in `docs/decisions.md`. `scripts/export-docs.py` renders the pages to PDF and PNG in `work/docs-export/` for Claude Design.

## Verification
Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.

## Rules
The user's house rules in `docs/catch-five-rules.md` take precedence over published Pitch rules.
