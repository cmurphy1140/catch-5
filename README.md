# Catch 5

[![Tests](https://github.com/cmurphy1140/catch-5/actions/workflows/tests.yml/badge.svg)](https://github.com/cmurphy1140/catch-5/actions/workflows/tests.yml)

A SwiftUI iPhone card game, built for a new family member who is learning Catch 5 (Pitch with Fives). It plays the family's house rules (partnerships, first to 25, a 9-and-out bid) against three computer opponents, and teaches the game as you play.

<p>
  <img src=".github/screenshots/home.png" width="23%" alt="Home screen">
  <img src=".github/screenshots/bidding.png" width="23%" alt="Bidding">
  <img src=".github/screenshots/table.png" width="23%" alt="Playing a trick">
  <img src=".github/screenshots/result.png" width="23%" alt="Hand result">
</p>

## Features

- Solo play against three computer opponents (Easy and Standard), or pass-and-play on one phone.
- Hints, hand review with an explanation of every play, undo, and match statistics.
- Optional lessons and rule trials that use the same engine as the game.
- Save and resume from a replay log, so a match restores in any phase.
- Computer bidding tuned against a mirrored benchmark: win rate rose from 64.7% to 67.5%.

## Architecture

MVVM, in a Swift package with no external dependencies (iOS 17+ / macOS 14+).

- `Sources/CatchFive/` is the rules engine: dealing, bidding, tricks, scoring, computer players and saving. It has no UI code.
- `Sources/CatchFiveUI/` holds the SwiftUI views; `GameModel` is the view model that connects them to the engine.
- `App/` is the iPhone app entry point; `Sources/CatchFiveDemo/` is a terminal demo of the engine.

## Build and test

```bash
swift test                            # 264 tests: 93 engine, 171 view model
python3 scripts/build-simulator.py    # builds work/simulator-build/CatchFive.app
```

The same tests run in GitHub Actions on pushes to `main` and on pull requests.

## Docs

[House rules](docs/catch-five-rules.md) · [Contributor notes](AGENTS.md)
