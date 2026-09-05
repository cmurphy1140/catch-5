# Catch 5

A SwiftUI iPhone app for Catch 5 (Pitch with Fives) under the house rules in `docs/catch-five-rules.md`: partnerships, first to 25, and a 9-and-out bid.

## Current Status

Feature complete for single-player: a pure Swift rules engine, three computer opponents, and a SwiftUI table with coaching built in. It runs in the iOS simulator on this Mac; installing on a phone is the next step (`docs/device-install.md`).

- Normal four-seat bidding with dealer matching and forced opening bid.
- Follow-suit validation and trick winner calculation.
- Captured High, Low, Jack, Five, and all-suit Game scoring.
- Normal bid settlement, 25-point wins, and 9-and-out settlement.
- Full deal, discard/refill, bidding-to-play transitions, turn enforcement and six-trick completion.
- Match coordinator with automatic scoring, hand history, dealer rotation and victory enforcement.
- Versioned save/resume with validated action replay and atomic file writes.
- Computer bidding from an expected-points estimate; card play scores every legal card from trick memory (unseen cards, unbeatable trumps, certain High/Low, control kept) using only a restricted PlayerView.
- Auction call history per seat, shown on the table during bidding and summarised as the contract afterwards.
- SwiftUI table with bidding, trump choice, legal-card play, last-trick recap, hand summary, a Hint button that explains what the computer strategy would do from your seat, tap-to-explain on every played card, a settings sheet (difficulty, play speed, seat names, haptics), a five-lesson tutorial with engine-checked exercises shown on first launch (rules sheet inside it), undo of your last action, a hand review against the strategy, a scoreboard, match history with statistics, Dynamic Type and VoiceOver support, a trump-first sorted hand, plain-word rule errors, and save on every accepted action.
- 96 Swift Testing tests, including 208 deterministic hands, 24 shuffled computer matches and a 600-match strength benchmark against a frozen earlier player.


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

This prints a deterministic five-hand match, ending Team 0: 26, Team 1: 16, using simple legal moves and ordered decks so every trick can be checked by hand. Add `--save-roundtrip` to see it save and restore mid-trick, or `--computer` to watch four standard computer players finish a shuffled match.

Initial dealing uses two packets of three starting left of dealer; refill goes clockwise from the dealer's left. These packet orders are defaults, not confirmed house rules.

## Structure

- `Sources/CatchFive`: pure Swift rules, computer players, save format. No UI imports.
- `Sources/CatchFiveUI`: `GameModel` view model, the table, sheets, settings and the tutorial.
- `Sources/CatchFiveDemo`: the terminal demo.
- `App/`: the nine-line app entry point, icon catalog and privacy manifest.
- `Tests/`: 96 Swift Testing tests across engine and view model.
- `scripts/`: `build-simulator.py` (hand-built simulator bundle), `make-icon.swift`, `export-docs.py` (PDF and PNG export for Claude Design).
- `docs/learning-path.md`: start here to read the code without an IDE; every page has diagrams.
- `docs/catch-five-rules.md`: the house rules, which the in-app rules sheet quotes verbatim.
- `docs/roadmap.md`: the six milestones, all done, and `docs/device-install.md`: putting the app on a phone.

Team-indexed values use `[team0, team1]`. Team 0 seats are 0/2, team 1 seats are 1/3. `Hand` enforces turn order, card ownership and six-trick completion before scoring; `PlayerView` limits computers and hints to a seat's own cards plus public information, and the table keeps opponents' cards hidden.

## Next

Install on a phone: follow `docs/device-install.md`. Work happens on short-lived branches off `main`, merged by pull request with the tests green and the docs updated in the same commit.
