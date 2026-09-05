# CardGame.io

A SwiftUI iOS card-game app in development, starting with Catch 5 (Pitch with Fives) using custom partnership rules and a winning score of 25.

## Current Status

The pure Swift engine now runs complete hands and a repeatable text demonstration runs a normal-bid match to completion. There is no playable iOS app yet.

- Normal four-seat bidding with dealer matching and forced opening bid.
- Follow-suit validation and trick winner calculation.
- Captured High, Low, Jack, Five, and all-suit Game scoring.
- Normal bid settlement, 25-point wins, and 9-and-out settlement.
- Full deal, discard/refill, bidding-to-play transitions, turn enforcement and six-trick completion.
- Match coordinator with automatic scoring, hand history, dealer rotation and victory enforcement.
- 30 Swift Testing tests, including 208 deterministic hands and a complete five-hand match.

`Auction` currently accepts normal integer bids only. Special bid precedence awaits a house-rule clarification; 9-and-out win/loss settlement is already tested separately.

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

Initial dealing uses two packets of three starting left of dealer. Refill gives each player their replacements clockwise, starting left of dealer. These are provisional packet-order defaults.

## Structure

- `Sources/CatchFive`: pure Swift rules; no UI dependencies.
- `Tests/CatchFiveTests`: repeatable rule tests with explicit card fixtures.
- `docs/catch-five-rules.md`: confirmed house rules and unresolved cases.
- `docs/engine-plan.md`: initial implementation milestone.
- `docs/code-map.md`: plain-language architecture and source-to-test connections.

Team-indexed inputs use `[team0, team1]`. Team 0 seats are 0/2, team 1 seats are 1/3. The Hand coordinator enforces turn order, card ownership and six-trick completion before scoring. Its read-only state includes all hands for diagnostics; a future UI/player observation layer must restrict opponents to public information. Captured-card scoring can also be used independently on supplied card collections.

## Next

Add computer-player strategy, save/resume, and a SwiftUI interface with a thin view model. Special-bid auction precedence remains unresolved.

Development branch: `feature/catch-five-engine`. Use tested milestone commits to track progress.
