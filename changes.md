# Changes on `claude/wood-table` (PR #21), for merging with `claude/cast-and-menu`

Written 2026-09-05 so the cast-and-menu branch can merge this one cleanly. Both branches edit
`TableView`, `TableSurface`, `ScoreBarView`, `Theme`, `TutorialView`, `GameModelTests` and the docs.
Decision numbers: this branch owns **D35** and **D37**; cast-and-menu owns **D36**. Keep all three.

## What this branch does, in one screen

Felt playing area under an oak header band shaped like a frown; oak also behind the tutorial, rules,
review, scoreboard and statistics sheets. Header carries only the title, hand number and scores.
Trump and contract in a gold pill at the table's top-left; the deck (stock count) at the top-right.
Seat tiles have no fill. Auction pills are solid, full-width, 64 pt. Status line is larger and no longer
repeats the trump. One message line under it holds the undo toast, hints, explanations, the discard
notice and your standing call. Text renders two Dynamic Type steps larger app-wide. Cards are 64/74 pt.
After trump is named, discards rise and fade and the refill deals in from the deck, and the scheduler
waits for that before the first computer lead. Only the iPhone 16 family is verified.

## Files and what changed

| File | Change | Merge note |
|---|---|---|
| `Sources/CatchFiveUI/WoodGrainView.swift` (new) | `WoodGrainView` (Canvas oak, seeded, `Theme.Wood.grainRunsHorizontally`), `GrainRandom`, `FeltView` | No overlap |
| `Sources/CatchFiveUI/Theme.swift` | `Theme.textBoostSteps`, `Theme.Wood` (colours, grain, felt, inlay), `Theme.Table` gains `auctionButtonHeight/Spacing/Radius`, `headerDip`, `seatTileWidth`, `statusButtonSize/HitSize`, `deckWidth`, `deckRise`; `Theme.Motion` gains `discardRise`, `discardStagger`, `dealDelay`, `dealStagger`, `dealHold`; `DynamicTypeSize.boosted(by:)`; `pileWidth` 74, `handWidth` 64/68, `seatBackWidth` 24 | Your `Theme.Table.portraitSize` and `Theme.Portrait` slot in alongside; take both sides of any hunk |
| `Sources/CatchFiveUI/ScoreBarView.swift` | Parameters `trump`, `contract`, `youDeal` **removed**; `handNumber` shown beside the title; the trump line and its helpers are gone | Add your `onLeave` parameter and chevron to this version. Do not restore the trump line: it lives in `TableSurface.contractPill` now |
| `Sources/CatchFiveUI/TableView.swift` | `body` wraps `withSheets` in `transformEnvironment(\.dynamicTypeSize)`; header band = `WoodGrainView().clipShape(HeaderBandShape(dip:))` behind the bar, ignoring the top safe area; `FeltView` background; `TableSurface` takes `toast:`; the `toastSlot` view is gone; `advance()` waits `Theme.Motion.dealHold` when `step.dealing`; `TableScheduler.plan` returns `(hold, leading, dealing)`; `HeaderBandShape` defined at the bottom | Keep your `onLeave` init parameter and pass it to `ScoreBarView`; keep your removal of the `onAppear` tutorial auto-open |
| `Sources/CatchFiveUI/TableSurface.swift` | `toast` parameter; VStack spacing 6 with `Spacer`s so groups spread over the height; `contractPill` (top-left, suit glyph in `Color.suitRed` or ivory); `DeckView` overlay top-right (`hand.stock.count`); status text `.title3`, no trump text, `smallButton` 38/48 pt; `commentary` is now the message line (toast → hint/explanation → notice → "You: <call>" → placeholder); `actionButton` uses `PillButtonStyle` with `fill:`/`font:`; `Suit.isRed`, `Suit.pillFill`, `Color.suitRed`; `SeatView` rewritten: fixed width `Theme.Table.seatTileWidth`, no fill, name / (call or backs+count) / badge row, gold ring only when active | Your `PortraitView` goes inside the new `SeatView` body: put it above the name in the VStack (tiles are 110 pt wide, so side by side will not fit at the boosted text size). Use your `model.seatSummary(for:)` in place of the private `summary` |
| `Sources/CatchFiveUI/HandFanView.swift` | `handTransition(index:width:)` (discard removal while choosing trump, deal-in insertion at the start of play), `dealOrigin(index:count:width:)`, `MatchedCard`, `ShakeEffect` uses `Theme.Motion.shakeAmplitude`; label reads "YOUR HAND · DEALER" when you deal; frame height uses the standard card | No overlap expected |
| `Sources/CatchFiveUI/Tutorial/TutorialView.swift` | Background `WoodGrainView().ignoresSafeArea()`; panels and pills use `Theme.Wood.inlay` fills | Your `SeatTile` portrait parameter is in a different hunk; keep both |
| `Sources/CatchFiveUI/Tutorial/Lessons/TrumpLesson.swift` | Refill ring ivory; copy says "ringed" not "ringed in gold" | Main already has the wording fix from PR #19; this keeps it |
| `Sources/CatchFiveUI/RulesView.swift`, `ReviewView.swift` | `.background(WoodGrainView().ignoresSafeArea())`, lists use `.scrollContentBackground(.hidden)` | No overlap |
| `Tests/CatchFiveUITests/GameModelTests.swift` | `import SwiftUI`; scheduler test compares three-element tuples; new `textBoostRaisesTheDefaultTwoStepsAndStopsAtTheLargest`, `dealtCardsComeFromTheDeckInTheCornerAndTheBandFrowns` | Both branches append at the end of the file; keep both blocks |
| `.github/workflows/tests.yml` | Unchanged on this branch (concurrency, cache and simulator-build job landed in PR #20) | |
| `docs/decisions.md` | D35 rewritten for the final look; D37 added (deal animation) | Insert your D36 between them |
| `docs/types-and-functions.md` | Rows for `WoodGrainView`/`FeltView`, `HeaderBandShape`, `DeckView`/`PillButtonStyle`, `dealOrigin`, `TableScheduler` (three decisions), `ScoreBarView`, `TableSurface`, `HandFanView`, `TableView`, `Theme` | Add your rows; on a row both sides edit, merge the sentences |
| `docs/testing.md`, `README.md`, `AGENTS.md` (`CLAUDE.md`) | Test count 103; aesthetic and status lines describe felt under an oak header | Add your tests to the count |
| `docs/game-flow.md`, `docs/redesign-plan.md`, `docs/learning-path.md`, `docs/tutorial-spec.md`, `docs/roadmap.md` | Small wording updates for the redesign | Take both |

## Things to know when testing the merged result

- Verify on the iPhone 16 Pro simulator only. This branch used a private simulator named "Catch 5 Wood"
  (`xcrun simctl list devices | grep Wood`) so two sessions do not overwrite each other's `settings.json`
  and `game.json` on "Catch 5 iPhone". A fresh simulator shows a white screen for up to 10 s on first
  launch while Metal compiles the gradient pipelines; wait before judging.
- The auction must show the Pass row without scrolling at the default text size. The message line
  reserves no height while it is your turn in the auction; the seat tiles size to their content.
- The deal animation is verified by loading a save where a computer is about to name trump (a match
  where seat 0 passed and the auction has ended) and screenshotting every 0.3 s after launch.
- `swift test` must stay green: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.

Delete this file once both branches are on `main`.
