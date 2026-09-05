# How to play: in-app tutorial

Designed by Connor in Claude Design on 2026-09-04 (reference build `Tutorial.dc.html`, kept outside the repository); implemented in PR #14 with the corrections noted inline.

A five-lesson "How to play" flow for novices, replacing or sitting alongside the current `RulesView` sheet. The browser build (`Tutorial.dc.html` in the Claude Design project, exported as `export/Tutorial.dc.html`) is the reference for layout, copy and exercise behaviour. This page states what to build and how it maps onto the existing code.

## Scope

- Five lessons: The deal, Bidding, Trump, Tricks, Scoring. Rules plus one basic tactic each. No advanced strategy.
- Every lesson has one exercise (Tricks has two parts). Exercises use fixed, hand-authored positions; no shuffling.
- Completion per lesson is tracked and shown as a check on the chapter pill and a "n / 5 complete" label.
- Presented as a sheet from the existing book icon in `TableView.header`; also shown on first launch in place of `RulesView` when `needsRulesIntroduction` is true.
- Adds no behaviour to the engine. Exercise legality comes from the real `Hand`/`Auction` where a position can be built, otherwise from a fixed answer key.

## Files to add

| File | Contents |
| --- | --- |
| `Sources/CatchFiveUI/Tutorial/TutorialView.swift` | Sheet root: header (CATCH 5 / HOW TO PLAY · LESSON n OF 5), chapter pills, lesson container, Back / Next lesson footer. Same felt gradient, `.ivory` text, `.gold` accents as `TableView`. |
| `Sources/CatchFiveUI/Tutorial/TutorialModel.swift` | `@MainActor final class TutorialModel: ObservableObject`. `@Published var lesson: Int`, `@Published var completed: Set<Int>` (persisted as `Settings.completedLessons` in `settings.json`, not `UserDefaults`, so the privacy manifest stays empty; see D31), per-lesson exercise state. |
| `Sources/CatchFiveUI/Tutorial/Lessons/*.swift` | One view per lesson: `DealLesson`, `BiddingLesson`, `TrumpLesson`, `TricksLesson`, `ScoringLesson`. Each takes the model and reports `onComplete`. |
| `Sources/CatchFiveUI/Tutorial/TutorialFixtures.swift` | The fixed cards and answer keys listed below, as `Card` arrays. |
| `Tests/CatchFiveUITests/TutorialModelTests.swift` | Completion tracking, persistence, and that each exercise's legal set matches the engine (see Tests). |

## Lessons

| Lesson | Exercise | Fixture | Correct answer and check |
| --- | --- | --- | --- |
| 1 · Deal | Tap the seat that receives the first three cards when East (seat 3) deals. | Seats only. Dealer badge on East. | You (seat 0). Fixed key: `(dealer + 1) % 4`. |
| 2 · Bidding | Auction shows West bid 2, Partner bid 3, East dealer waiting. Tap a bid 2…9, Pass, or 9 and out. | Hand `A♠ K♠ 5♠ 9♥ 3♣ 7♦`. West bid 2, Partner bid 3, East (dealer) to follow. Fixed answer key (see note below). | Legal: 4…9, Pass, 9 and out. Preferred: 4. Feedback strings in the reference build. Buttons 2 and 3 render disabled (`allows`-style greying). |
| 3 · Trump | Won the bid at 4; tap a suit. | Same hand. Refill hand after choosing spades: `A♠ K♠ 5♠ 8♠ Q♣ 2♥`. | Spades. On correct: non-spades fade to 35%, "Discard and refill" toggle shows the refilled hand with the three new cards ringed in gold. |
| 4a · Tricks | West led K♦, spades trump. Tap a card you may play. | Hand `9♦ A♠ 7♣ 2♦ Q♥ 8♠`. Verified with `legalCards(in:led:)`, the function `Hand.legalMoves` uses. | 9♦ or 2♦. After a correct tap, advance to 4b after ~2.5 s. |
| 4b · Tricks | Four cards on the table; tap the winner. | `K♦ West · 9♦ Partner · 2♠ East · A♦ You`. | 2♠ (East). Check with `trickWinner(_:trump: .spades)`. |
| 5 · Scoring | Assign High, Low, Jack, Five, Game to Us or Them. | Us: `A♠ 3♠ 10♣ 7♥ 7♦ 9♣ 4♦ 8♠`. Them: `5♠ J♠ 10♥ Q♦ 2♣ K♥ 9♦ 8♣`. They bid 4. Scores before: 10–5. (The reference build had `6♥` for Them, which leaves Game with Us at 14 to 13 because the ace of spades counts 4; the engine test caught it.) | Us: High, Low. Them: Jack, Five, Game. Check with `scoreHand(captured:trump:bidder:)`. On all correct, show settlement 10→12, 5→12 via `settle`. |

Note on lesson 2: the reference build uses a fixed answer key for the auction exercise because the seat order (West, Partner, then You) does not match a real `Auction` from dealer 3, where seat 0 acts first. Either keep the fixed key, or change the fixture so You are seat 2 with dealer 1; the copy in the reference build assumes the former.

### Lesson copy

Rules text and tactic boxes are in the reference build, one lesson per screen. Tactics, in order:

1. Deal: partners sit across from each other; the leftover deck is out of play, scoring cards included.
2. Bidding: count what you can see (the ace of a long suit is High, the five in that suit is five if you can protect it). Bid what you can take; a failed 4 costs more than being outbid.
3. Trump: name the suit where you hold the most cards and the highest ones. Three trumps headed by the ace is a strong start; a lone king is not.
4. Tricks: never lead the five of trump. Lead your highest trump to pull the others out; keep the five for a trick your side is already winning.
5. Scoring: the five is worth more than everything else together. Give it to your partner's winning card; watch for the moment an opponent is forced to play it.

## Visual rules

- Reuse `CardView` unchanged (48×72, ivory, radius 8). Captured piles in lesson 5 may use a 40×60 variant.
- Panels: `.white.opacity(0.06)` radius 16; seat tiles `.white.opacity(0.04)` radius 12; trick area radius 24 with the 8% white stroke, as in `TableView.trick`.
- Feedback text is `.gold`, footnote size, reserved height so the layout does not jump. Tactic box matches `hintRow`: gold 10% fill, 40% gold stroke, radius 12.
- Selection ring: 3pt gold stroke for a correct pick, 3pt `.white.opacity(0.6)` for an incorrect one. Illegal bids greyed to 35% ivory, not hidden.
- All tap targets at least 44pt. Chapter pills are 44pt tall.
- Primary footer button is the one solid gold fill on the screen (`.borderedProminent.tint(.gold)`, black label), matching "Deal next hand".

## Tests

```swift
@MainActor @Test func completingAllLessonsPersistsAcrossLaunch()
@MainActor @Test func biddingExerciseLegalSetIsFourThroughNinePassAndNineAndOut()
@Test func tricksExerciseLegalMovesMatchEngine()      // Hand.legalMoves on the 4a fixture == [9♦, 2♦]
@Test func tricksExerciseWinnerMatchesEngine()        // trickWinner on the 4b fixture == seat 3
@Test func scoringExerciseMatchesScoreHand()          // scoreHand on the lesson 5 piles == [2, 7], settle → [12, 12]
```

The last three tests are the point of the spec: fixtures are checked against the engine so a rules change can never leave the tutorial teaching something false. This page is in the reading-order table in `docs/learning-path.md` so it exports with the rest.
