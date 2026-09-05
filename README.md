# CardGame.io

A SwiftUI iOS card-game app in development, starting with Catch 5 (Pitch with Fives) using custom partnership rules and a winning score of 25.

## Current Status

The pure Swift engine runs complete matches, and a SwiftUI table lets one human play against three computer players with automatic save and restore. A repeatable text demonstration also runs a normal-bid match to completion.

- Normal four-seat bidding with dealer matching and forced opening bid.
- Follow-suit validation and trick winner calculation.
- Captured High, Low, Jack, Five, and all-suit Game scoring.
- Normal bid settlement, 25-point wins, and 9-and-out settlement.
- Full deal, discard/refill, bidding-to-play transitions, turn enforcement and six-trick completion.
- Match coordinator with automatic scoring, hand history, dealer rotation and victory enforcement.
- Versioned save/resume with validated action replay and atomic file writes.
- Computer bidding from an expected-points estimate; card play scores every legal card from trick memory (unseen cards, unbeatable trumps, certain High/Low, control kept) using only a restricted PlayerView.
- Auction call history per seat, shown on the table during bidding and summarised as the contract afterwards.
- SwiftUI table with bidding, trump choice, legal-card play, last-trick recap, hand summary and save on every accepted action.
- 61 Swift Testing tests, including 208 deterministic hands, 24 shuffled computer matches and a 600-match strength benchmark against a frozen earlier player.

`Auction` accepts normal bids and 9-and-out, treating 9-and-out as outranking a normal 9 with dealer matching allowed. Both are confirmed house rules.

## Run Tests

From this repository on this Mac:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

With Xcode selected as the default developer directory, `swift test` is sufficient. The package has no external dependencies and targets iOS 17+ / macOS 14+.

## Watch a Text Match

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run catch-five-demo
```

This prints a deterministic five-hand match, ending Team 0: 26, Team 1: 16. It uses deliberately simple legal moves and ordered deck rotations for inspection, not a production shuffle or strategic opponents. No Xcode editor is needed.

Add `--save-roundtrip` to the demo command to see it save and restore mid-trick. Engine APIs support disk saves; automatic saving when the app closes will be connected with the UI.

Add `--computer` to watch four baseline computer players complete a match with fresh shuffled decks. This mode is separate from the fixed save-roundtrip demo. The strategy is a simple heuristic, not a trained or expert player.

Initial dealing uses two packets of three starting left of dealer. Refill gives each player their replacements clockwise, starting left of dealer. These are provisional packet-order defaults.

## Structure

- `Sources/CatchFive`: pure Swift rules; no UI dependencies.
- `Tests/CatchFiveTests`: repeatable rule tests with explicit card fixtures.
- `docs/learning-path.md`: start here to read the code without an IDE; links the architecture, game-flow, types, testing, decision-log and build pages, all with diagrams.
- `docs/catch-five-rules.md`: confirmed house rules.
- `docs/engine-plan.md`: initial implementation milestone.
- `docs/code-map.md`: plain-language architecture and source-to-test connections.

Team-indexed inputs use `[team0, team1]`. Team 0 seats are 0/2, team 1 seats are 1/3. The Hand coordinator enforces turn order, card ownership and six-trick completion before scoring. Its read-only state includes all hands for diagnostics; PlayerView restricts computer strategy to its own cards and public auction/trick information; the future UI must similarly keep opponents’ cards hidden. Captured-card scoring can also be used independently on supplied card collections.

## Next

Refine computer strategy through playtesting. Build the simulator app with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/build-simulator.py` when Xcode's iOS platform is unavailable.

Use tested milestone commits on short-lived branches off `main` to track progress.
