# Catch 5

## Current Status
Single-player Catch 5 is feature complete: pure Swift rules engine, three computer opponents (Easy and Standard), replay-log save/resume, and a SwiftUI table with hints, tap-to-explain, hand review, undo, scoreboard, match history, settings, a five-lesson tutorial, the documentation pages bundled for offline reading, Dynamic Type and VoiceOver. A new player signs in once (name, face, difficulty) and gets a one-page skippable intro; a returning player lands on the table under a small welcome card (Continue game, New match, Settings). The three computer seats are a fixed cast (Hazel, Otto, Rue) with drawn portraits. 137 tests pass. The gameplay screen is a table-first layout on felt under an oak header (seats around the pile, fanned hand, cards that travel, gold reserved for five meanings), with every text style two Dynamic Type steps above the system setting. The layout is tuned and verified for the iPhone 16 family (393 pt wide); other sizes get a scroll fallback but are not verified. The app runs in the simulator via `scripts/build-simulator.py` and on Connor's iPhone via `xcodebuild` plus `devicectl` (`docs/device-install.md`).

## Architecture
Swift Testing and a dependency-free Swift package for rules (`Sources/CatchFive`); `GameModel` and SwiftUI views consume it (`Sources/CatchFiveUI`). Team 0 seats are 0/2, team 1 seats are 1/3; turns advance in ascending seat order modulo four. Computers and hints see only a `PlayerView`.

## Aesthetic North Star
A readable, welcoming card table: felt in play, drawn oak (grain running across the screen, no image) for the frown-shaped header band and the reading sheets, ivory cards, green card backs, gold accents, seats with no fill, solid dark pills for the auction, one solid gold button per screen. Text runs large.

## Living documentation
`docs/learning-path.md` indexes the explainer pages (build-and-run, architecture, game-flow, types-and-functions, testing, decisions, code-map, roadmap, tutorial-spec, device-install) with Mermaid diagrams. Any commit that adds, renames or removes a type, function, phase or test must update the matching page in the same commit, and new design choices get a numbered entry in `docs/decisions.md`. `scripts/export-docs.py` renders the pages to PDF and PNG in `work/docs-export/` for Claude Design.

## Verification
Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.

## Rules
The user's house rules in `docs/catch-five-rules.md` take precedence over published Pitch rules.
