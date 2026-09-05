# Decision Log

Each entry: what was decided, what it was chosen over, and why. Dates are when the decision landed in the repo. Newest last.

## D1. A dependency-free rules engine (PR #1, merged 2026-09-04)

**Chosen:** `Sources/CatchFive` imports only the standard library and Foundation. No SwiftUI, no Combine, no packages.

**Over:** Writing rules inside the view model or views, which is the fastest way to get a first screen up.

**Why:** Rules are the part that must be exactly right and change least. Keeping them UI-free means they compile on macOS in the test runner, run 200 matches in under half a second, and can be reused by a terminal demo, a future server, or a different UI without change.

## D2. Value types everywhere in the engine (PR #1, merged 2026-09-04)

**Chosen:** `Hand`, `Match`, `Auction` are structs with `private(set)` state and `mutating` methods.

**Over:** Classes with mutable properties.

**Why:** Copying is free and explicit. Validation can work on a copy and commit only on success (`var updated = self … self = updated`), giving transaction semantics without any undo code. `allows(_:)` in the UI is a one-line dry run for the same reason. Structs are also trivially `Sendable`, which Swift 6 strict concurrency demands.

## D3. Throwing validation instead of Bool returns (PR #1, merged 2026-09-04)

**Chosen:** Every rule check throws a case of `RuleError`, `HandError`, or `MatchError`.

**Over:** Returning `false` or an optional.

**Why:** A thrown error names the rule that was broken, tests can assert the exact case, and the caller cannot forget to check because `try` is mandatory.

## D4. Match settles automatically, redeals explicitly (PR #1, merged 2026-09-04)

**Chosen:** The sixth trick scores and settles the hand inside `Match.play`. Starting the next hand requires a separate `startNextHand(deck:)`.

**Over:** Auto-dealing the next hand, or requiring a separate "score" call.

**Why:** Scoring twice or forgetting to score are both classic bugs; making it automatic and testing it happens exactly once (`matchScoresOnlyAfterLastCardAndOnlyOnce`) removes them. The explicit redeal exists so the screen can show the hand summary before cards disappear.

## D5. Saves are replay logs, not board snapshots (PR #1, merged 2026-09-04)

**Chosen:** `MatchSave` stores the initial deck, dealer, and every accepted action. Loading replays them through the real rule methods.

**Over:** Encoding every property of `Match` and `Hand`.

**Why:** A snapshot can describe an impossible position; a replay cannot. It also means no separate decoding validation, tiny files, and human-readable JSON. Cost: replay time grows with match length (fine for a local game) and rule changes alter how old saves replay, hence the `version` field.

## D6. Computers see a `PlayerView`, never the `Match` (PR #1, merged 2026-09-04)

**Chosen:** `PlayerView(match:seat:)` copies the seat's own cards and public information only.

**Over:** Passing the whole `Match` to the strategy for convenience.

**Why:** It makes cheating structurally impossible rather than a matter of discipline, and `changingHiddenCardsDoesNotChangeComputerDecision` proves it. The same shape is what a networked opponent would receive.

## D7. Computer actions go through the same `apply` as humans (PR #1, merged 2026-09-04)

**Chosen:** `ComputerPlayer.decide` proposes; `Match.apply` checks.

**Why:** A strategy bug can never corrupt a game; it just throws, and the simulation test would fail loudly.

## D8. A revision counter drives the computer scheduler (PR #1, merged 2026-09-04)

**Chosen:** `GameModel.revision` increments on every accepted action; `TableView` uses `.task(id: model.revision)` with a short sleep.

**Over:** A `Timer`, a Combine pipeline, or a loop that plays all computer moves at once.

**Why:** SwiftUI cancels and restarts an id-keyed task for free. A human tap bumps the revision, which cancels any sleeping computer task, so ordering bugs cannot occur. The pause between plays is what makes the game readable.

## D9. Build the simulator app with `swiftc` directly (PR #1, merged 2026-09-04)

**Chosen:** `scripts/build-simulator.py` compiles the modules and assembles the `.app` bundle by hand.

**Over:** `xcodebuild`, which is the normal route.

**Why:** The installed Xcode requires an iOS platform download that is not present, so `xcodebuild` cannot resolve a destination. The script uses the same compiler and SDK and produces a bundle the simulator runs. `project.yml` remains so Xcode can be used when the platform is installed.

## D10. 9-and-out precedence (PR #2, 2026-09-04)

**Chosen:** A 9-and-out declaration outranks a normal 9. The dealer may match it with their own 9-and-out and thereby takes the bid.

**History:** PR #1 implemented this behaviour provisionally and the docs flagged it as unconfirmed. Connor confirmed the dealer-match rule on 2026-09-04.

## D11. Auction calls are recorded in the engine, not the view (PR #2, 2026-09-04)

**Chosen:** `Auction.calls` stores each accepted `AuctionCall`; `PlayerView` exposes it; `GameModel` turns it into words.

**Over:** Having `TableView` remember what it saw as bids went by.

**Why:** The engine is the only place that knows which calls were accepted. Storing it there means saves replay it, computers can use it, and the view is stateless. Rejected calls are deliberately not recorded.

## D12. Cards stay readable during bidding (PR #2, 2026-09-04)

**Chosen:** Hand cards use `allowsHitTesting(playable)` rather than `.disabled(!playable)`.

**Why:** SwiftUI's plain button style dims disabled buttons, which greyed the whole hand while bidding, when reading it matters most. Hit testing switches interaction off without touching appearance; opacity is applied only in the playing phase for illegal cards.

## D13. Bid from an expected-points estimate with a half-point margin (PR #2, 2026-09-04)

**Chosen:** `ComputerPlayer.estimate` sums heuristic weights (High, Low, Jack, Five, control, trump count, refill chance). The bid cap is `floor(estimate − 0.5)`; the computer bids the minimum needed up to that cap.

**Over:** The previous flat "2 per trump, +2 for honours" count capped at 5, and an alternative of bidding the full estimate.

**Why:** Measured over 200 seeded matches, the old bidder let two thirds of hands fall to a forced dealer 2. The estimate is calibrated (estimate 5 → 5.6 points made on average). Bidding the full estimate was rejected on economics: in Pitch, being outbid costs about one point relative, while failing a 4 costs roughly nine, so a margin is worth more than aggression. The regression test guards both the competitiveness and the contract rate.

## D14. Keep the trump five off leads (PR #2, 2026-09-04)

**Chosen:** When leading, the computer excludes the trump five unless it is the only legal card.

**Why:** The five is worth more than every other point combined. Leading it hands opponents a free capture with any higher trump. Leading the ace instead draws trumps out while the five stays protected.

## D15. Trick animation keyed by card, not seat (PR #2, 2026-09-04)

**Chosen:** `ForEach(plays, id: \.card)` with per-seat entry edges and `.animation(value: model.revision)`.

**Over:** Keying by seat.

**Why:** Seat ids repeat every trick, so SwiftUI would treat a new trick as the old views changing content and skip the transition. Cards are unique within a hand, so keying by card makes the old trick leave and the new lead arrive as distinct animations.

## D16. Living documentation in `docs/` (PR #2, 2026-09-04)

**Chosen:** Flat Markdown pages with Mermaid diagrams, linked from [learning-path.md](learning-path.md), updated in the same commit as the code they describe.

**Over:** Relying on an IDE's navigation, or generated API docs.

**Why:** Connor reads the code without an IDE. Diagrams render on GitHub, plain Markdown reads anywhere, and the "same commit" rule keeps pages from rotting.

## D17. Strategy changes are judged by a mirrored benchmark against a frozen player (2026-09-04)

**Chosen:** `Tests/CatchFiveTests/BaselinePlayer.swift` freezes the PR #2 player. `mirroredBenchmark` plays each seed twice with the teams swapped and reports win rate and score margin. A test requires the shipped player to beat the frozen one.

**Over:** Judging strategy edits by reading them, or by the contract rate alone.

**Why:** Card-play heuristics that look right often are not. Mirroring cancels seat and dealer luck, 600 to 1200 matches put the noise floor near two percentage points, and a frozen opponent means the number is comparable across commits. It also caught two of my own "obvious" improvements that measured worse.

## D18. Card play maximises expected points net of control, using trick memory (2026-09-04)

**Chosen:** `PlayerView` carries `completedTricks`. `Knowledge` derives the unseen cards, whether a card is unbeatable, each card's certain point value and the value of keeping a trump. `chooseCard` scores every legal card by the chance our side wins the trick, the points on the table, the card's own stake if lost, and the control given up.

**Over:** The rule list (cheapest winner, feed when last, dump the least valuable).

**Why:** One scoring function covers the cases the rules handled separately and the ones they missed: securing a five with the ace, refusing to trump a worthless trick, feeding a certain Low to a safe partner, and knowing when a king has become the boss. Measured 66% wins and +5.5 points per match against the frozen player.

## D19. Bid to the whole-point estimate with no margin (2026-09-04)

**Chosen:** The bid cap is `floor(estimate)`.

**Over:** The half-point margin of D13.

**Why:** With the stronger card play, a grid over bid margins showed zero margin winning more matches than 0.5 or 1.0 while keeping the contract rate at 81%. A negative margin scored similarly but with a 72% contract rate, which felt reckless for a human opponent to face.

## D20. No "probable" High or Low credit (2026-09-04)

**Chosen:** `pointValue` counts High and Low only when certain from the unseen set.

**Over:** Partial credit for a queen-or-better or a four-or-lower when higher or lower trumps were still unseen.

**Why:** The partial credit measured worse in every variant tried, because it made the player cling to cards it should have spent and dump cards it should have kept.

## D21. Export by rendering, never by hand-maintained copies (PR #4, 2026-09-04)

**Chosen:** `scripts/export-docs.py` generates PDF and PNG into the gitignored `work/docs-export/` folder from the Markdown source: one PDF per page, a combined `catch-five-explainer.pdf`, and one PNG per Mermaid block.

**Over:** Committing rendered images to the repo; pasting Markdown into Claude Design; adding a Node project with `package.json`.

**Why:** Claude Design imports documents, images and repos but not Markdown with Mermaid. Rendering from the source keeps one source of truth, so a diagram edit needs no second update. The toolchain (Node, mermaid-cli, headless Chrome) is already on the Mac, so a stdlib Python script that shells out matches how the simulator build already works.
## D22. Six strategy ideas measured and not adopted (2026-09-04)

**Method:** the current player was frozen as a reference opponent in the test target, each idea was implemented behind temporary knobs, and every variant played 1200 mirrored matches against the reference (noise floor about two percentage points). A control run with the knobs off scored exactly 50% each time, confirming the harness.

| Idea | Best variant | Win rate vs current | Margin per match |
|---|---|---|---|
| Void tracking (seats that failed to follow a suit) | hold chance still indexed by seats to play | 50.0% | 0.0 |
| Game point valued by the state of the race | flat weight, zero once decided (never triggered) | 50.0% | 0.0 |
| Monte Carlo sampling of hidden hands, 12 deals, heuristic rollouts | as inherited from the cancelled experiment | 45.9% | −1.5, and ten times slower |
| Hypergeometric hold chance from the unseen cards | quarter blend with the fixed table | 51.7% | +0.4 |
| Bidding context: dealer bonus, save bid, closing bid, respecting high bids | dealer +1 | 51.1% | +0.1 |
| Lead policy: low trump when holding the five, short-suit exits, opening top trump, low trump when long | short-suit exits | 50.5% | +0.1 |

**Decision:** keep the D18 player unchanged. Nothing cleared the two-point noise floor, and the two ideas with real complexity (voids, Monte Carlo) measured neutral or worse. The fixed hold-chance table appears to encode useful pessimism that the "more accurate" hypergeometric estimate loses, probably because opponents choose when to trump rather than trumping at random.

**What might still work:** a proper search would need a better rollout model than the heuristic and an honest model of the stock, and a much larger time budget than the test suite can afford. Any future attempt should start by reproducing the 50% control run described above.

## D23. Hints come from the same code that plays (2026-09-04)

**Chosen:** `ComputerPlayer.advise(_:)` returns an `Advice` (action plus reason) and `decide(_:)` is just its action. The Hint button builds a `PlayerView` for seat 0 and shows the advice; the suggested card is ringed in the hand.

**Over:** A separate explanation generator, or hints written as rules of thumb.

**Why:** One path cannot drift from the other: a test plays a whole match and checks that advice and decision agree at every turn. The reasons are derived from the same facts the score uses (what is on the table, whether a card can be beaten, whether the five is being kept back), so they explain the computers' own play as much as they advise the human. Hints use only the human's `PlayerView`, so they never reveal hidden cards.

## D24. Past plays are explained by rebuilding the view, not by logging reasons (2026-09-04)

**Chosen:** `PlayerView.init(match:replaying:inCompletedTrick:)` reconstructs what a seat could see before an earlier play (its cards then, the tricks before, the cards already on the table) and `advise` runs on that. Card choice was made order-independent so the rebuilt hand decides identically; a test replays a whole match and checks every explanation matches the play that happened.

**Over:** Storing each computer's reason alongside the action log.

**Why:** Nothing new needs saving, old saves gain the feature for free, and the explanation can never disagree with the code that played. For the human's own card the same view says what the strategy would have done instead, which is the "why did the computer do that" question turned into a coaching moment.

## D25. Settings live in the UI module and are saved beside the game (PR #8, 2026-09-04)

**Chosen:** `Settings` (play speed, seat names, haptics) is a Codable struct in `CatchFiveUI`, written to `settings.json` next to `game.json` whenever it changes, with defaults for any missing key so older files keep loading. `GameModel` owns it and derives seat names, the sorted hand and the computer pause from it.

**Over:** `UserDefaults`, or threading preferences into the engine.

**Why:** The engine stays free of preferences, so nothing in the rules changes with a name or a speed. A JSON file next to the save is easy to inspect, matches how the game is stored, and needs no privacy-manifest reason. Keeping one `seatNames` source in the view model ended the three duplicated name lists the roadmap found.

## D26. The frozen benchmark player is the Easy difficulty (PR #9, 2026-09-04)

**Chosen:** `BaselinePlayer` moved from the test target into the package as `EasyPlayer`. `Difficulty` (easy, standard) lives in `Settings`; `ComputerPlayer.decide(_:difficulty:)` routes to it. Hints and explanations always use the standard strategy, and explanations for Easy seats say so and show what Standard would have played.

**Over:** Writing a deliberately weakened player, or dropping the benchmark.

**Why:** The frozen player already exists, is deterministic, and measured about one match in three against the current player, which is a real on-ramp for newcomers. One copy serves both jobs, and the "never improve it" contract now protects the difficulty setting as well as the benchmark's yardstick.

## D27. The rules sheet quotes the rules document and a test keeps them equal (PR #10, 2026-09-04)

**Chosen:** `RulesText` holds the house rules as paragraphs copied verbatim from `docs/catch-five-rules.md`, grouped under short headings. A test reads the document at test time and fails if any rule paragraph is missing from the sheet or the counts differ. The sheet opens by itself until dismissed once (`Settings.hasSeenRules`), and from a book button afterwards.

**Over:** Loading the Markdown file into the app bundle, or rewriting the rules in friendlier prose.

**Why:** The hand-built simulator bundle has no resource pipeline, so the text has to live in code; the test makes the copy safe. Quoting the document verbatim keeps one wording of the rules everywhere, which matters because the document is what Connor confirmed.
