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

## D28. Undo rewinds the replay log rather than mutating state (PR #11, 2026-09-04)

**Chosen:** `Match.rewound(toActionCount:)` rebuilds the match from the first deal by replaying a prefix of the accepted actions, using the same helper the save loader uses. `undoPoint(forSeat:)` finds the human's latest action in the current hand; undo drops it and every computer reply after it. Nothing after a hand is scored, and nothing across a hand boundary.

**Over:** Storing snapshots, or writing inverse operations for each action.

**Why:** The replay log (D5) already proves any prefix is a legal position, so undo cannot corrupt a game and needs no new persistence: the shortened log is simply saved. Because the computers are deterministic, replaying the unchanged prefix reproduces exactly the position the human saw. The human has seen the replies that get dropped; that is accepted as the price of a one-tap undo.

## D29. Match records are derived from the action log at the finish (PR #12, 2026-09-04)

**Chosen:** When a winner is decided, `GameModel` computes the human's record for the match by replaying it (`Match.performance(forSeat:)`, which reviews each finished hand with `HandReview`) and appends one `MatchRecord` to `history.json`. Nothing is tallied during play; the hand review itself is rebuilt from public information the same way tap-to-explain is.

**Over:** Counting agreements as the hand is played, or storing reviews with the save.

**Why:** The action log already holds everything needed (D5), so a match restored from disk at any point still produces the same record, and the review code has one implementation. Records are written once, guarded by a flag that is set when a finished match is restored, so a relaunch cannot duplicate an entry. A history file that cannot be decoded is renamed `history-corrupt.json` before anything is written, so a bad file never blocks play and is never overwritten. Records decode with defaults for fields added later, the same rule as `Settings` (D25); dates are stored to the second and `difficulty` is the value in effect when the match ended. The human's record is computed once at the finish (`finalPerformance`), not on every render, and the review always compares plays to the standard strategy whatever the difficulty, saying so for Easy seats. (Amended after code review, PR #13.)

## D30. Accessibility through the view model, and App Store scaffolding in `App/` (PR #13, 2026-09-04)

**Chosen:** VoiceOver wording lives in `GameModel` (`spokenDescription`, `accessibilityValue`) where it is unit-tested; views only attach it. Fixed point sizes became text styles and `@ScaledMetric`, and Reduce Motion swaps the slide transitions for fades. The icon is rendered by `scripts/make-icon.swift` into the asset catalog, `App/PrivacyInfo.xcprivacy` declares no tracking and one required-reason API (UserDefaults, reason CA92.1, for the `-stage` launch argument), and `project.yml` carries the version, category and icon settings; `build-simulator.py` copies scaled icons and the manifest into the hand-built bundle so the simulator shows the same icon.

**Over:** Ad-hoc labels in views, a hand-drawn icon file, and leaving the store metadata until a Mac with the iOS platform is available.

**Why:** Wording in the view model means the same test that checks legality checks what VoiceOver says. Rendering the icon from code keeps it reproducible and alpha-free (App Review rejects icons with transparency). Preparing the catalog, manifest and project settings now means `xcodegen && xcodebuild archive` is the only remaining step once Xcode's iOS platform is installed; `build-simulator.py` still cannot sign for devices.

Portrait iPhone first, with iPad allowed in the same 640-point column, stays the shipping layout (roadmap M6, "out": landscape and split iPad layouts).

## D31. The tutorial is built from Connor's design, with fixtures checked against the engine (PR #14, 2026-09-04)

**Chosen:** The five-lesson "How to play" flow follows [tutorial-spec.md](tutorial-spec.md) and the Claude Design reference build: fixed hand-authored positions, one exercise per lesson, completion shown on chapter pills. Every answer key is asserted against the rules engine in tests. Two deviations from the spec: completion is stored in `Settings.completedLessons` rather than `UserDefaults`, so the lessons add no use of it (the manifest declares the UserDefaults category, reason CA92.1, for the `-stage` launch argument that `App/CatchFiveApp.swift` reads), and the scoring fixture was corrected after the engine test showed the reference piles gave Game to the wrong side.

**Over:** Hand-written explanations without engine checks, or a scripted live hand.

**Why:** A tutorial that can drift from the rules is worse than none; checking the fixtures against `legalCards`, `trickWinner`, `scoreHand` and `settle` means a rules change fails a test before it teaches something false, and it already caught one mistake. The tutorial replaces the rules sheet on first launch; the rules stay one tap away inside it.

## D32. The explainer pages ship inside the app as bundled HTML (PR #16, 2026-09-05)

**Chosen:** The ten Claude Design pages (`App/Explainer/*.dc.html`, about 5 MB) are bundled as a folder and shown in a `WKWebView` loaded from the file URL with read access to the folder, so their relative links work offline. Navigation is allowed only inside the folder; web links open in Safari. Entry points: Settings ("How Catch 5 is built") and the tutorial's More menu. A test checks that every page the library lists is present and that no page's head references the network.

**Over:** Rendering the Markdown in-app, or linking out to GitHub.

**Why:** The exported pages are self-contained (blob: assets only, verified in a browser with the network log open) and already carry the diagrams and the interactive decisions table, so bundling them is the shortest path to reading the documentation on the phone. The cost is that they are a snapshot: re-export from Claude Design after the docs change, then copy the files into `App/Explainer`. The hand-built simulator bundle copies the folder too.

## D33. A table-first screen with a five-rule use of gold (PR #20, 2026-09-05)

**Chosen:** `TableView` is a fixed column: `ScoreBarView`, a `TableSurface` with partner across the top, West and East at the sides and the pile in the middle, then a fanned `HandFanView` that is the largest thing on screen. Cards move: a computer's card arrives from its seat, yours flies from the hand by `matchedGeometryEffect`, a finished trick holds 900 ms and collapses toward the winner. Hint is a tertiary control on the status line; Undo is a toast after your play. Gold is used only for the dealer, trump and contract, the seat to act, the winning card, key results and the one prominent button. Numbers and sources are in [redesign-plan.md](redesign-plan.md).

**Over:** The previous dashboard order (scores, tiles, text, buttons, an often-empty trick panel, small cards in a horizontal scroll view) and gold on every accent.

**Why:** Research on one-handed use puts primary actions at the bottom; the hand and the auction controls now live there. Fanned cards at 60 pt keep a 44 pt strip each, so six fit without scrolling on a 375 pt screen. Reserving gold makes the seat to act and the winning card readable at a glance. Collapsing tricks conflicts with tap-to-explain (D24), so a reopen control keeps that feature. One animation per accepted action, keyed on `revision` (D8), is what lets a card fly from the hand to the pile in a single transaction.

## D34. The table scrolls only when it must, and cards stop growing at XXXL (PR #20, 2026-09-05)

**Chosen:** `TableSurface` sits in a `ScrollView` with `.scrollBounceBehavior(.basedOnSize)` and a minimum height equal to the space it is given, so on every phone at the default text size nothing scrolls, and at accessibility sizes the table scrolls instead of clipping. During the auction the bid grid or the suit buttons take the pile's place rather than stacking under a reserved footprint, which is what lets the auction fit a 375 × 667 pt screen. Card widths follow Dynamic Type up to XXXL and stop; table text follows it up to AX2 and stops; sheets stay uncapped. Undo lives in the gear menu as well as in the four-second toast, and the toast carries the discard notice so the two never hide each other.

**Over:** A strictly non-scrolling surface (clipped the Pass row on the SE and became unusable at AX sizes); shrinking cards below 44 pt strips; letting the hand fan grow past the screen at AX5; a toast-only Undo that vanished after four seconds.

**Why:** The one-handed-use research behind D33 is about the default case, and a scroll view that engages only when content cannot fit costs that case nothing. Apple's guidance for games allows bounding the size of game pieces where growth would break play; a fan of six cards is that case, and the corner index stays legible at XXXL. The caps sit above the views whose `@ScaledMetric` values read them, because a cap applied inside a view does not reach the view's own scaled metrics (the first attempt piled the cards up at AX5 for exactly that reason).

## D35. Oak and felt, larger text everywhere, and the iPhone 16 as the only verified device (PR #21, 2026-09-05)

**Chosen:** The playing area is felt again, a lighter felt green lit in the middle and darker at the edges (`FeltView`), and the oak lives where the eye rests between hands: `WoodGrainView` draws it in a `Canvas` from a fixed seed (gradient, tonal bands, a few hundred wavy grain lines at uneven spacing running across the screen, a vignette) and fills the header band, which runs up behind the status bar and ends in a frown, its corners hanging lower than its middle (`HeaderBandShape`); the same oak backs the tutorial, rules, review, scoreboard and statistics sheets. The header carries the title, the hand number and the scores only. Trump and the contract are plain gold text at the top-left of the table with the suit in its own colour (a filled pill was tried and Connor asked for it to blend into the felt); the stock is a small deck of card backs with its count at the top-right; the dealer badge joins the "YOUR HAND" label. Seat tiles have no fill: name, backs and badges sit on the felt and only the seat to act gets a gold ring. The auction's pills are solid, full-width and 64 pt tall. The status line is larger and no longer repeats the trump. One message line under it carries, in order of priority, the undo toast (with the discard notice), a hint or explanation, the notice, your standing call, or the tap-to-explain placeholder. Every text style renders two Dynamic Type steps above the system setting (`Theme.textBoostSteps`, applied at the root of `TableView` so sheets inherit it), hand cards start at 64 pt and pile cards at 74. Connor directed each of these from screenshots, and asked for the layout to be judged on the iPhone 16 alone.

**Over:** The felt-only gradient of D33 (Connor: too generic) and a wood-only table (the first cut of this pull request, which Connor liked less once the header and tiles were tried in green); a wood image asset, which would need a resource pipeline the hand-built simulator bundle does not have; bumping each font style by hand across forty views; filled seat tiles in dark brown, dark green and wood (each tried, none kept); a separate toast row between the table and the hand, which cost the auction its Pass row once the pills grew; keeping the SE and accessibility-size matrix as a gate.

**Why:** A procedural texture costs one file and no build changes, is identical on every launch, and stays crisp at any size; clipping the same view to the header shape and the sheets keeps one drawing. Felt in play and wood around it is how a real card table looks. Boosting the environment's `dynamicTypeSize` is one line, testable, and composes with the existing caps (cards still stop at XXXL, table text at AX2). Full-width pills put the whole column under the thumb, which is the point of having the auction in the thumb zone. Folding the toast into the message line removed a 28 pt row that was empty most of the time. The scroll fallback from D34 stays in the code so nothing clips on other phones, but it is no longer verified per release.

## D36. A fixed cast, a one-time name prompt and a menu-first launch (PR #22, 2026-09-05)

**Chosen:** Three named opponents, Hazel, Otto and Rue, always fill West, Partner and East, drawn in SwiftUI from a `Portrait` recipe rather than image assets. The human types a name once on a login screen and picks one of four faces; the name becomes seat 0's name in `Settings.seatNames`, so the rest of the app is unchanged. The app opens on a main menu with Continue, New match, Tutorial, Rules, Match history and Settings; the table gains a back chevron and no longer opens the tutorial by itself. Old settings files that still carry West, Partner and East migrate to the cast's names; custom names are kept.

**Over:** A roster with random seating (the player never learns who is who); choosing opponents at login (more screens for no gameplay gain); image assets (an art pipeline the hand-built simulator bundle does not have); a NavigationStack that creates the model on demand (the menu needs settings and history before a match exists).

**Why:** Names and faces make turn order readable at a glance and give the score bar's team labels a person to point at. Keeping names in `Settings.seatNames` means the contract line, explanations, review and scoreboard needed no changes. The recipe approach keeps portraits crisp at 28 pt and 72 pt, tints nothing gold (D33), and compiles on macOS for `swift test`. Menu-first gives the tutorial, rules and history a home that does not compete with the table.

## D37. Discards rise and the refill deals in from the deck (PR #21, 2026-09-05)

D36 is taken by the cast, login and menu work on the parallel branch.

**Chosen:** When trump is named, the cards leaving the hand rise toward the table, shrink and fade one after another (`Theme.Motion.discardRise`, `discardStagger`), and after a short delay the replacements deal in from the deck in the table's top-right corner, small and faint at first, one card at a time (`dealDelay`, `dealStagger`), each flight starting from that card's own place in the fan (`HandFanView.dealOrigin`). A played card still leaves by `matchedGeometryEffect`; the difference is decided by phase: a card leaving while trump is being chosen is a discard, a card arriving at the start of play is a refill. `TableScheduler.plan` reports `dealing` for the start of play, and the scheduler waits `dealHold` before the first computer lead so nothing plays over the deal. Reduce Motion crossfades instead.

**Over:** Animating the engine's refill through a new model event; dealing from the dealer's seat (Connor asked for a visible deck instead); a fixed extra delay on every lead.

**Why:** The engine already discards and refills in one action, so the hand's diff is exactly the animation's cast list; SwiftUI's asymmetric transitions carry their own timing, so the stagger needs no extra state. Choosing the transition by phase avoids tracking "why did this card leave", and the only insertion during early play is the refill. The deck gives the deal a source the eye can follow and shows the stock count for free.

## D38. The header is lit as one board, seats grow, the pile card shrinks, and the felt gets a nap (PR #22, 2026-09-05)

**Chosen:** `WoodGrainView` takes a `vignette`: the header band uses a linear top-to-bottom shade (a little dark at the very top, clear through the middle, darker along the frown edge), while the reading sheets keep the radial pool of light. Seat tiles grow (36 pt portraits, 30 pt card backs, headline names, 116 pt tiles) and the pile card drops from 74 to 62 pt so the people at the table outweigh the card in play. `FeltView` draws a seeded stipple of faint light and dark flecks on a 4 pt jittered grid over the felt gradient.

**Over:** Keeping the radial vignette everywhere (on a short strip it reads as a spotlight around the Dynamic Island, which Connor flagged from a screenshot); an image texture for the felt.

**Why:** A vignette sized for a full screen has nowhere to fall away on a 180 pt band, so its centre becomes a bright disc; a linear shade keeps the grain and gives the band one light. With named, drawn opponents the seats carry more meaning than before, and a 62 pt pile card still shows rank and suit at a glance. The stipple costs one `Canvas` pass with the same seeded generator as the grain, so it is identical on every launch and needs no asset.

## D39. No menu page: a one-page intro for new players, a welcome card for returning ones (PR #22, 2026-09-05)

**Chosen:** Amends D36. The full-page main menu is gone. After login the only button is New match; it opens `IntroView`, one page that says how a hand goes in five steps with Learn the game (the tutorial, full screen, Skip in the toolbar and Deal me in at the end) and Deal me in. A returning player launches straight onto the table with a small `WelcomeCard` over it: Continue game until the match is won (a dealt hand counts, Connor asked for it from a screenshot), New match (confirming only when bids or plays would be lost), Settings. The table's chevron reopens the card. Match history and the tutorial stay in the table's gear menu.

**Over:** A menu with Continue, New match, Tutorial, Rules, Match history and Settings for everyone (Connor: Continue makes no sense for someone who just signed in, and a returning player should not pass a menu to reach their game); forcing the five-lesson tutorial on new players.

**Why:** Standard game onboarding is a short, skippable intro with a clear door to the full lessons, and returning players expect to be at the table one launch away. A card over the table keeps the two things a returning player actually wants in reach without a page between them.

## D40. Play pauses under any cover, and a failed save is not a refused move (PR #24, 2026-09-05)

**Chosen:** `TablePause` gathers every reason the computers must wait: the scene is not active, the welcome card is up, any sheet is open, a confirmation or alert is showing, or the player has reopened the last trick. `TableView` keys its scheduler task on the revision and that one flag, so a cover cancels the task and lifting the last cover starts one fresh task that applies at most one computer action. Because the reopened trick now pauses play, the status line gains a Hide control beside Show. In `GameModel`, `perform` returns whether the engine accepted the action; the human's toast and haptic follow that answer, not the absence of an error message. Write failures for the game, settings and history land in `saveError`, shown as a "Could not save" alert with Retry, and `retrySave()` writes the state already in memory, never replaying a move.

**Over:** Checking each overlay flag inside `advance()` (misses the cancellation, so a sleep started before the cover could still act after it); folding save failures into `errorMessage` (a successful bid then looked refused and lost its toast); retrying by re-sending the action.

**Why:** The roadmap's first task. Task ids are how SwiftUI cancels work, so the pause belongs in the id. Stacked covers stay paused because the flag is computed from all of them at once. Separating acceptance from persistence keeps the replay log the only record of what happened; a save is a copy of it, and a retry copies again.

## D41. The hand and the seat row are laid out from measurements, with a two-row fallback (PR #25, 2026-09-05)

**Chosen:** `HandFanView` measures the width it is given and asks `HandLayout.arrange` how to use it. The fan keeps its overlap while every card's exposed strip is at least 44 pt; when scaled cards or a narrow width would push a strip under that, the hand becomes two flat rows, each still meeting the bound, and the hand's height follows. The seat row does the same through `TableLayout`: the pile reserves a nudged card plus air, and the side tiles take what is left down to an 84 pt floor, so a played card never sits on a seat tile.

**Over:** Trusting the theme constants (the old metric test checked 60 and 64 pt cards against a 375 pt phone and nothing else, while the runtime fitting could shrink a strip below 44 with no fallback); hard-coding a 126 pt pile footprint that was narrower than two nudged cards.

**Why:** Task 2 of the roadmap. A touch target the user cannot see is a mis-tap waiting to happen, and Apple's 44 pt minimum applies to every essential control. Deciding from a measurement makes the invariant true on every width and text size rather than on the ones somebody screenshotted, and a pure function is the only way to test that without a device matrix.

## D42. Refusals say why, the dealer is told their rights, and 9 and out asks first (PR #26, 2026-09-05)

**Chosen:** `GameModel.validationMessage(for:)` runs an action on a copy of the match and turns the engine's refusal into the player's words, with the two common cases spelled out: "Follow hearts; you still have hearts." and "Wait for Hazel." A refused card tap still shakes and buzzes, and now also records that sentence in `refusal`, which the message line shows until the next accepted action. Greyed auction pills carry the same sentence as their accessibility hint. When the human bids as dealer, a line above the grid says what the dealer may do: match the high bid, match 9 and out, or bid the forced 2. The 9-and-out pill opens a confirmation ("Take all nine points to win the match. Take fewer and you lose it, whatever the score."); confirming sends the bid through the engine at that moment, cancelling changes nothing, and the dialog counts as a cover for `TablePause`.

**Over:** A second set of rules in the views to explain refusals (the engine is the referee, so the copy-and-try keeps one source of truth); a modal alert per refusal; confirming ordinary bids (their consequence does not justify a second tap).

**Why:** Task 3 of the roadmap. A shake without a reason teaches nothing; the reason costs one dry run. The dealer's rights are the one part of the auction a newcomer cannot guess from the pills alone. Nine and out is the only bid that can end the match by itself, which is what earns it a confirmation.

## D43. The hand-end card leads with the verdict and the arithmetic (PR #27, 2026-09-05)

**Chosen:** `HandOutcome` turns the engine's `HandSummary` and the previous scores into the order a player wants: "Contract made" or "Contract set" (or "9 and out made" / "failed") in gold, then "Connor + Otto bid 4 · captured 6 · score 2 → 8" and the defenders' line, then the point-by-point rows, then notes only when a rule decided something: a Game tie going to the bidder, a Five or Jack that was never dealt, both teams reaching 25 on one hand. The review sheet says that Standard's choice is a recommendation, not proof that another legal play was wrong.

**Over:** Leading with the five category rows and leaving the reader to work out whether the bid made and why the score moved; a permanent list of every rule on the card.

**Why:** Task 4 of the roadmap. The first question after a hand is "did we make it and what did it cost", and the scores in the header only show the result of the arithmetic. Building the wording from numbers the engine already computed keeps the card honest and lets the edge cases be tested without playing a hand to reach them.

## D44. Covers hide the table from VoiceOver, focus follows the game, motion and contrast settings are honoured, and one haptic speaks per action (PR #28, 2026-09-05)

**Chosen:** The table is `accessibilityHidden` while the welcome card covers it (the card is marked modal) and while the finished-hand card is up, so VoiceOver meets the cover and nothing behind it. An `AccessibilityFocusState` on the status line receives focus when a cover lifts, a sheet closes or the human's turn comes, and `AccessibilityNotification.Announcement` reads out the trick winner and the hand outcome. Under Reduce Motion the card press no longer lifts or scales (it dims) and a refused tap no longer shakes (the reason on the message line carries it); deal, discard, flight and collection were already crossfades. Under Increase Contrast a dimmed card keeps 80% opacity and gains a dashed edge, and the welcome dim layer is darker. `TableFeedback` reduces each accepted action to one haptic, the most consequential outcome first: match won (success) or lost (error), hand ended, trick won or lost, play, call. The refusal buzz stays separate because it never coincides with an action.

**Over:** Six stacked `sensoryFeedback` modifiers that could all fire on one tap; `.success` on every hand end, which made a lost hand feel like a win; lowering opacity as the only "not legal now" signal.

**Why:** Task 5 of the roadmap. A modal cover that leaves the table in the accessibility tree lets VoiceOver users play under the card. Focus and announcements are what turn a visual table into a narrated one. The motion and contrast settings are promises the system makes on the user's behalf; the table has to keep them in its own effects, not just its transitions. Haptics are a language: one word per event, and different words for winning and losing.

## D45. Restore is measured, not staged; a corrupt save is kept; the welcome card says where you were (PR #29, 2026-09-05)

**Chosen:** A test replays a whole match from its save and asserts it takes under 300 ms, the roadmap's threshold for showing a spinner; it does, by a wide margin, so there is no bootstrap state and no progress indicator. A game file that cannot be decoded is moved to `game-corrupt.json` (as history already was) and the fresh game's notice says so, so nothing is overwritten and the player chooses to continue the fresh deal or start a new match. The welcome card gains one line of `resumeContext`: hand number, both scores and the phase. The launch screen is declared dark (`UIUserInterfaceStyle`) in both build paths, so the first frame is dark like the felt rather than a white flash. The sign-in screen is headed "Set up your player" to say it is a local profile, not an account.

**Over:** A "Restoring your game…" state on principle (the measurement says it would never be seen); replacing an unreadable save silently; a launch storyboard or image asset for the launch colour (the hand-built simulator bundle compiles no asset catalog, and a dark interface style needs none).

**Why:** Task 6 of the roadmap, which asked for measurement before machinery. Keeping the corrupt file costs nothing and leaves a path to recovery. The card's context line answers "where was I" before the player commits to Continue.

## D46. The rules sheet shows each rule before it states it (PR #30, 2026-09-05)

**Chosen:** `RulesView` is six chapters on the felt, each an inlay panel with a gold numeral: a figure first, built from the table's own pieces (portraits, card backs, `CardView`, the cast's names), then the rule as written from `RulesText`, always visible under a thin gold rule. A chapter rail of chips under the title scrolls to a chapter (`scrollPosition`) and lights the chapter at the top. Interaction is spent only where it adds understanding: a Following suit / Trumped toggle on the example trick, tappable point tiles that explain how each point is won. `RulesFigures` holds every number a figure draws and a test checks them against the engine, including the two example tricks through `trickWinner`. Reduce Motion drops the springs.

**Over:** The previous list of headings and paragraphs on wood; showing the player's own name and face on the seating figure (the sheet is reachable without a model, and the fixed cast is the point of the picture); hiding the verbatim text behind disclosures (the standard for a rules screen is summary first, exact text visible beneath, so a dispute mid-game is settled in one glance and VoiceOver reads it in one pass); numbers typed into the figures by hand.

**Why:** Connor asked for a much better layout with an interactive flow and its own colour scheme, distinct from the tutorial. The tutorial is wood, pills and exercises; the rules are felt, panels and figures, so the two read as different rooms. Building figures from the real components keeps them in the app's language, and checking their numbers against the engine keeps them true. A review of the first cut moved the house numbers into `HouseRules` so the ladder and the target quote the engine rather than repeat it, built the trick captions and VoiceOver labels from the same data as the figures, capped the card-sized parts at XXXL, and gave the rail chips 44 pt targets.

## D47. Suit pills are named and say what they keep (PR #31, 2026-09-05)

**Chosen:** While the human chooses trump, each suit pill carries the suit's name beneath its glyph and a preview from `GameModel.trumpPreview(for:)`: "keep 4 · draw 2", counted from the human's own hand only. The VoiceOver label carries the same words. Nothing about the stock or other hands is revealed; the engine still does the discarding.

**Over:** Glyphs alone (a beginner does not always know ♣ from ♠ at a glance, and the choice is the one that shapes the whole hand); a manual discard phase.

**Why:** The roadmap's trump section asked for labelled suits and an optional factual preview. The preview costs a count over six cards and turns the least explained decision in the auction into an informed one.

## D48. The roadmap stack after review: nothing is thrown away without a choice (PR #32, 2026-09-05)

**Chosen:** A code review of Tasks 1 to 6 found ten defects; all are fixed here. Sign-in no longer discards an older install's match in progress: `destinationAfterSignIn` keeps it behind the welcome card, and a signed-in player who never finished the intro is routed back to it (`initialScreen`). Settings decoding tolerates values this build does not recognise, migrates the old direction names only for files written before sign-in existed, and an unreadable settings file is set aside as `settings-corrupt.json` with a notice shown on whichever screen opens; the corrupt-game notice now says only what actually happened. One writer, `Settings.setPlayerName`, serves sign-in and the Settings sheet, whose name field is a draft so spaces and clearing work. `TableFeedback.Snapshot` is seeded from the restored match, so resuming fires no phantom hand-end cue or announcement. A refused tap's reason comes first on the message line and yields to a hint or explanation. The save alert's dismissal no longer clears the error, so a failed Retry stays visible. The hand keeps its natural fan until its width is measured. Dialog dismissal restores VoiceOver focus. The root's tutorial model is shared with the table, and the felt is `Equatable` so the table's updates never redraw its stipple.

**Over:** Merging the stack and fixing forward; leaving the review's cleanup items (duplicate gold-button and portrait-picker code, the docs export swept into main) for later, which they are.

**Why:** Two of the ten would have cost real players their saved match on the first launch after updating. The rest are the difference between a feature that works in the fixture and one that works on a phone.

## D49. The explainer is the docs, read natively (PR #33, 2026-09-05)

**Chosen:** "How Catch 5 is built" no longer shows condensed web pages. `learning-path.md` is its contents page: the reading-order table names the chapters and the vocabulary table is the glossary, so the app lists exactly what the docs index. Each chapter is that doc's full Markdown, bundled verbatim under `App/Explainer/docs` and parsed by `MarkdownDocument` into blocks the reader draws in SwiftUI (headings, paragraphs, lists, tables as stacked rows, code that scrolls sideways, and each Mermaid fence as a PNG rendered by `scripts/export-docs.py --app` into `App/Explainer/diagrams`). A test compares the bundle to the docs byte for byte and counts the diagrams, so the reader cannot drift. A chapter opens with its section list, links between docs open the target chapter, and Previous and Next sit at the bottom. The welcome card gets a dedicated button, and the reader opens full screen.

**Over:** The ten Claude Design pages in a web view (a screen each, no Dynamic Type, five megabytes); a Markdown-to-HTML pipeline in the app; a hand-typed chapter list.

**Why:** Connor asked for the full piece, explorable, with a dedicated button; the material already existed as 25,000 words of living documentation that the app was not showing. Reading it natively brings Dynamic Type, VoiceOver headings and the table's own look, and deriving the contents from the learning path keeps one index.

## D50. Rules you can try, judged by the engine (PR #30, 2026-09-05)

**Chosen:** Three chapters of the rules sheet end with a "Try it" panel: follow suit (hearts led, spades trump, six cards in your hand), the dealer's right to match (you are dealer facing a bid of 3), and 9 and out below zero (a failed 9 last hand left you at −9). Each `RuleTrial` is a real `Match` built through the engine from a crafted deck, so the position is exactly what the game would deal, and `attempt(_:)` hands whatever the reader tries to the engine on a copy: a refusal comes back in the words the table uses, an acceptance is played out with the standard strategy and described. Reset restores the position. A test drives all three through the engine.

**Over:** A scripted quiz with authored right answers (that is the tutorial's job); a second rules implementation inside the sheet; a "Try it" that only animates.

**Why:** From the research brief's "rulebook you can demonstrate": a rule is learned by being refused once, safely. Building the positions with the engine and judging with the engine means the sheet can never teach a move the game rejects, which is the brief's one hard requirement.

## D51. Opponents wear a mood, drawn from public events only (PR #34, 2026-09-05)

**Chosen:** `SeatMood.expression(for:in:)` gives each opponent's portrait one of six looks from things everyone at the table can see: thinking when it is their turn, pleased or rueful while the last trick still lies on the table (the takers and the losers), triumphant or dismayed when the match is decided, neutral otherwise. `PortraitView` draws the look with two eyes, two brows and a mouth whose bend animates between a frown and a grin; Reduce Motion drops the animation. The function takes the match and the seat and never reads a hand, so no expression can hint at a card.

**Over:** Reactions to hidden information (a seat wincing at its own hand would be a side channel, which the research brief and the house rules both forbid); a Rive or Lottie runtime for animated avatars (six looks are within reach of the shapes the portraits are already made of).

**Why:** The cast is the table's personality, and a face that reacts to the trick just taken makes turn order and outcomes legible without reading a label. Keeping the input to public events keeps it honest.

## D52. Played cards land as if tossed (PR #35, 2026-09-05)

**Chosen:** Each card on the pile keeps its seat's nudge and adds a turn of up to eleven degrees and a drift of up to nine points of its own, from `CardToss.pose(for:hand:trick:)`. The pose is a pure function of the card, the hand number and the trick number, seeded through the same generator as the wood grain, so a re-render never moves a card, the same trick looks the same after a relaunch, and the next trick and the next hand come out differently. The flight in and the collapse toward the winner are unchanged; the card simply arrives at its own angle.

**Over:** Random poses drawn at render time (they would jitter on every update and differ after a restore); one fixed layout (Connor: the pile should look like a player threw the cards in, not always the same).

**Why:** A hand-thrown pile reads as a table with people at it. Determinism is what keeps that from becoming noise.

## D53. Unavailable cards sit in shadow, and the status line names the suit to follow (PR #36, 2026-09-05)

**Chosen:** A card you cannot play right now stays solid ivory with a dark veil over its face and most of its colour drained, like a card in shadow; nothing shows through it. Under Increase Contrast the veil lightens and the dashed edge from D44 carries the state. While you must follow suit, the status line reads "Your turn · follow diamonds" (`GameModel.suitToFollow`), so the shaded cards come with their reason.

**Over:** Lowering the card's opacity (Connor: the see-through cards over the felt looked wrong, and they did, a ghost of a card rather than a card); saying only "Your turn" and leaving the player to work out why four cards are shaded.

**Why:** A card is an opaque object; showing felt through it breaks the table. Shade and desaturation say "not now" while keeping every index readable, and the status line turns the shading from a puzzle into a rule.

## D54. Discards go to a pile under the deck (PR #37, 2026-09-05)

**Chosen:** When trump is named, the cards leaving your hand no longer rise and fade; each flies to the top-right corner and shrinks to a card back, landing on a discard pile drawn beneath the deck (`DiscardPileView`: up to three fanned backs and the count of every seat's discards). The flight reuses the deal-in geometry with a lower landing point (`discardTarget`, `Theme.Table.discardDrop`). Reduce Motion crossfades, as before.

**Over:** Cards that vanish upward (Connor asked to see them go somewhere); animating the computers' discards from their seats (their cards were never visible, so there is nothing to carry).

**Why:** A discard pile gives the refill a source and a sink at the same corner: cards leave to the pile, replacements come from the deck above it. The count also answers a question the rules raise, since undealt and discarded cards are out of play, scoring cards included.

## D55. The first dealer is drawn for (PR #38, 2026-09-05)

**Chosen:** A new match, and a fresh install's first match, begin with a draw: each seat takes one card from a shuffled deck, the highest deals, and equal ranks go by suit with clubs lowest and spades highest, so one draw always settles it. The draw is shown over the table (`DealerDrawView`) with the dealer's card ringed and a sentence, puts itself away after four seconds or at the first action, and pauses play while it shows. The match itself starts from a fresh shuffle with that dealer; the draw is not in the replay log, so a restored game shows no draw. The house rules gain the sentence, in `docs/catch-five-rules.md` and `RulesText` together. After the first hand the deal passes to the left, as before.

**Over:** Dealer 3 every time (Connor asked for a draw); redrawing ties (a suit order makes the draw a single step and matches how the cards rank elsewhere in the game); recording the draw as an action (it decides the dealer and nothing else, and the engine already takes the dealer as an input).

**Why:** Drawing for the deal is how a table starts, and it puts the cast's faces to work before the first bid. The draw stays a presentation of a decision the engine receives, not a rule the engine has to learn.



## D56. Three elements up top, a pause card, the main menu on launch, one setting for guidance (PR #40, 2026-09-06)

**Chosen:** The header is back to the spec's three elements (R1): the score chip, the contract chip once bidding resolves, and the menu. The Home control leaves it; Pause game is the menu's first item and opens `WelcomeCard` as a pause card with exactly Continue game, New match and Main menu (R32). Its greeting and saved-match summary move to the main menu, where a returning player now lands on every launch (`RootView.initialScreen` returns `.menu`), never a popup over the table; Main menu on the card keeps the match for Continue game. Faces grow from 60 to 68 pt (R2), with the halo gap, tile padding and status-glyph hit size trimmed so every bidding row still fits. `Settings.beginnerMode`, on by default and for settings files from before it existed, is one switch (on the main menu and in Settings) for hints and guided play: off hides the hint bulb, tap-to-explain on the pile with its prompt line, and the keep captions under the trump pills (R14 first cut, R30); rule refusals, the undo toast and the record of play stay in both modes. The three Start over dialogs show their title and carry an explicit Cancel.

**Over:** Keeping Home as a fourth header element (the spec caps the top at three); a Settings action on the pause card (the main menu's hamburger owns Settings, Statistics and the explainer, so the card stays at three actions); the larger single-row seating experiment (abandoned: a modest 68 pt keeps partner-across seating); a switch per coaching surface (one switch is what a beginner can find).

**Why:** The table is the interface, the menu is where the destinations live, and guidance is a mode rather than a scattering of toggles.

**Verified 2026-09-06** on the "Catch 5 Wood" simulator (iPhone 16 Pro, iOS 26.5, simctl content size medium) against `783fa80`, the branch tip that PR #40 squashed: the three dropdown destinations open and return to the menu; the beginner toggle persists both ways to `settings.json` with difficulty and the saved match untouched; bidding, trump and play fit in both modes with every pill hittable above the hand; an illegal card is refused with "Follow clubs; you still have clubs." in both modes and stays in the hand; pause Continue, Main menu → Continue game, New match cancel and confirm, relaunch to the main menu and first-run onboarding all behave. One platform note: on iOS 26 the confirmation dialogs present as popovers anchored to their button and drop the Cancel button; tapping outside cancels and the match is preserved.

## D57. Start over asks with an alert, not a confirmation dialog (2026-09-06)

**Chosen:** The three Start over prompts (main menu, pause card, table menu) are `alert`s: the title "Start over?", the message "This replaces your saved game.", a destructive Start new match and a Cancel.

**Over:** `confirmationDialog` with `titleVisibility: .visible` and an explicit Cancel (PR #40). Verified on the iOS 26.5 simulator: the dialog presents as a popover anchored to its button and the system drops the Cancel button, leaving a tap outside as the only way out; on iOS 18 it is a bottom sheet with Cancel. An alert shows both buttons on every system.

**Why:** Throwing away a saved match deserves a named way to say no, wherever the app runs (spec R32: Cancel leaves the match untouched).

## D58. Strategy moves on evidence from real hands: the bot bank (2026-09-13)

**Chosen:** When Connor sees a computer seat bid wrong, waste a trick, ignore its partner or give away the Five or Jack, that hand is flagged and rebuilt from the replay log as a deterministic test fixture in `Tests/CatchFiveTests/`. The test names the bad decision. A change to `ComputerPlayer` is accepted only if it passes the new fixture and the mirrored benchmark against the frozen player (D17) does not get worse.

**Over:** Leaving strategy parked (D22), or tuning heuristics against the benchmark alone. D22's six ideas were measured against a computer opponent; the family plays against people, and the decisions that annoy a person are the ones worth fixing first.

**Why:** Connor named bad bot decisions as the app's biggest miss versus the real table. Each flagged hand is a small, reproducible, human-judged case, which is the cheapest evidence there is.

## D59. The computer is measured against Connor's table, not against Pitch (2026-09-14)

**Chosen:** The sin hunt judges the computer by the house rules and Connor's own bidding table, recorded here because they are unwritten rules at a real table:

| Holding in one suit | The table bids |
|---|---|
| three or more, including that suit's five | 5 |
| ace and king | 3 |
| ace and queen | 2 |
| ace and jack | 2 |

These are floors, not ceilings: bidding higher to keep the auction away from the other side is a legitimate move, so only underbidding counts. Alongside them: the trump Five is sacred and is never risked into a trick the other side takes; a low trump is a surrendered point only when nothing lower can still appear; a ten counts because Game is scored on captured card value, where a ten is worth more than an ace.

**Over:** Judging it by general Pitch strategy. The first detectors watched only the Five and Jack, which is the Pitch reflex, and missed High, Low and Game entirely — all three of which this variant awards to the capturing team.

**Why:** Connor is the rules authority (`docs/catch-five-rules.md`), and the goal is a computer that plays like his family, not one that plays textbook Pitch. A test written from general domain knowledge can be wrong about the specific game while the implementation is right.

## D60. Bad decisions are counted only when they could never have worked (2026-09-14)

**Chosen:** Every sin detector asks a counterfactual before counting: was the seat forced, was a cheaper card available, could anyone still to play have beaten the partner, could this card ever have taken the trick. A test may ask these with all four hands in view; the strategy may not.

**Over:** Counting outcomes. The first sweep reported 523 findings; after the counterfactuals, 96 survived. Overtaking a partner fell from 373 to zero, because taking a trick from a partner who might still lose it is ordinary good play and `chooseCard` already penalises the rest.

**Why:** A bet that lost is not a mistake, and a detector that cannot tell the difference measures nothing. The numbers only became actionable once they stopped counting bad luck.

## D61. The computer bids the table's number for a shape, not the cheapest raise (2026-09-14)

**Chosen:** `ComputerPlayer.houseBid(for:)` encodes Connor's bidding floors, read per suit and bid on the best:

| Holding in one suit | Floor |
|---|---|
| ace and queen, or ace and jack | 2 |
| ace and king | 3 |
| ace, king and queen | 4 |
| five or more with two controls, no five | 4 |
| three or more including that suit's five | 5 |

`bidAdvice` bids `max(smallest legal raise, floor)` rather than the smallest legal raise. The dealer is the exception: bidding last and able to match, a dealer who can take the contract at the minimum gains nothing by naming a bigger number.

**Over:** Correcting the point estimate. Three attempts at better arithmetic — a Five discount, a refill draw credit, a trump-floor ruff penalty — moved the benchmark by noise or not at all.

**Why:** The bots' valuations were never the problem. They bid the cheapest raise that cleared the auction, so ace-king opened at 2 and handed the hand to anyone willing to say 3. A floor is a statement about the *shape*, independent of what the auction currently costs, and no per-hand point estimate contains that.

**Measured, two independent seed ranges.** Win rate 0.647 → 0.675 and 0.625 → 0.653; margin 5.050 → 5.727 and 4.785 → 5.357. Underbids against the table's floors fell 481 → 84. The cost is real and recorded in the ratchets: badly-missed contracts 71 → 88, surrendered counters 14 → 19, because winning more auctions means playing more contracts.

## D62. In pass and play the table turns to the phone holder (2026-09-26)

**Chosen:** The seat holding the phone is drawn at the bottom, with the next seat in turn on the left, their partner across and the seat before them on the right (`GameModel.bottomSeat`, `seat(at:)`, `place(of:)`). While the curtain is up the table has already turned to the next holder; between hands it stays with the last one. Cards on the pile, their flights and the VoiceOver direction words follow the place, not the seat number. Solo is unchanged: seat 0 is always at the bottom.

**Over:** Fixed seats with only the hand changing (the first pass-and-play build), which put a player's own tile across the table from them.

**Why:** Each player should see the table as they would sit at it: their partner opposite, and play passing to their left.

## D63. Pass-and-play matches stay out of Statistics (2026-09-26)

**Chosen:** Only solo matches are recorded in the match history, so Statistics stay the phone owner's own record. A finished pass-and-play match writes nothing to `history.json` and shows no personal line on the match-over card (`finalPerformance` stays nil).

**Over:** Recording every match with seat 0's performance, which credited the phone owner with a match four people played.

**Why:** In pass and play seat 0 is whoever sat there, not the owner.

## D64. A launch with a match in progress opens onto the table, and "How Catch 5 is built" keeps one entry (2026-09-27)

**Chosen:** `RootView.initialScreen(for:matchInProgress:)` sends a signed-in player who has seen the rules straight to `.table` when the saved match has no winner yet, instead of the main menu; a finished match or no match falls back to the menu as before (spec R31/R32 and the `RootView` doc comment, overridden by Connor for this case). In pass and play the curtain stays down: a restored `GameModel` never carries a revealed seat, so the resumed table shows nobody's hand until Ready is pressed. Separately, "How Catch 5 is built" now opens only from the main menu's hamburger (spec R29); the entries in `SettingsView` and the tutorial's "More" menu are gone, and the tutorial's toolbar carries a single "Full rules" button in their place.

**Over:** Leaving the returning-player rule as it stood, which put Connor back at the menu every time iOS suspended and ended the app mid-hand, one extra tap from the game he was already in.

**Why:** The main menu is for starting or resuming a choice, not for a match that is already running; a background-killed app should feel like nothing happened. The explainer only needs to live where a player goes looking for it, and duplicating it in Settings and the tutorial added menu weight without adding a use.

## D65. Who bid, the bid and trump sit in the table's top corners, and the player keeps a trump tally by hand (2026-09-27)

**Chosen:** The header keeps only the score and the pause control; the contract chip is gone. Once the auction resolves, the table's top-left corner shows a plaque (`ContractPlaque`): a small BID eyebrow, the bid large in the display serif (9 and out reads as a 9 with "and out" beneath) and the bidder's name. Once trump is named, the top-right corner shows it large on an ivory tile (`TrumpTile`), hearts and diamonds red, spades and clubs black, and a very large, faint trump watermark sits behind the play area, never hit-testable. Both corners flank the partner's tile and stay within its height (`Theme.Table.cornerWidth` and the tokens beside it). The bidder's portrait wears a dashed light-brown ring on its own edge, which cannot be mistaken for the solid gold halo outside the portrait of the seat to act. Tapping the trump tile adds a tally stroke (drawn in groups of five by `TallyMarks`, capped at 13); press and hold takes one back, down to 0; VoiceOver reads "Hearts are trump, 4 trump played" and adjusts with swipe up and down. Tapping a seat's portrait toggles an out-of-trump badge (the suit crossed out, `OutOfTrumpBadge`). The tally and the badges are `GameModel` view state (`trumpTally`, `outOfTrump`), cleared when the next hand or a new match starts, or when an undo takes back the trump call; the engine, `PlayerView`, the computers and the save never see them.

**Over:** The contract chip in the header, which put the three things a player most needs to remember (who bid, the bid, trump) in a small line at the top of the screen.

**Why:** Connor: "The three biggest things to remember are who bid, what the bid is, and what trump." The tally is consistent with spec R4 (no automatic number tracking) because the app itself never counts: it only keeps the marks the player makes, as a pencil would.


## D66. The rules sheet opens with where the game comes from (2026-09-27)

**Chosen:** "How to play Catch 5" (`RulesView`) shows one line above its first chapter, in the display serif's italic: "A New England variant of Pitch, passed down through generations. We hope you enjoy it as much as we do." The words live once, as `RulesText.origin`, outside the rule sections, so the verbatim check against `docs/catch-five-rules.md` is unchanged and the tip card (D67) quotes the same constant.

**Over:** Leaving the sheet to open straight on the first rule, or adding the line to the rules document as if it were a rule.

**Why:** Connor asked for it: the game is a family's, handed down, and the sheet is where a new player first reads about it. `rulesSheetOpensWithWhereTheGameComesFrom` holds the exact wording.

## D67. Deal me in, and a tip card on the way to the table (2026-09-27)

**Chosen:** The home screen's play buttons are "Back to the table" (prominent) and "Deal me in" (plain) while a match is in progress, and one prominent "Deal me in" otherwise (`MainMenuView.homeButtons(matchInProgress:)`). Deal me in replaces New match and keeps its start-over alert and Solo or Pass and play picker. Going from the home screen to the table through either button shows `TipCardView` over the covered table: a large ivory card that opens on `RulesText.origin` ("WHERE IT COMES FROM"), turns over after 3.2 s (a 3D turn about its vertical axis) to the next of eleven tips ("TIP n OF 11", `TipDeck.tips`), and deals on its own 3.2 s after that; a tap anywhere deals at once. Dealing sends four card backs to the four seats over 0.5 s as the dim lifts. The next tip index is `Settings.nextTip` (decoded with a default of 0, so older files load), advanced and saved by `GameModel.takeNextTip()` when a tip is shown, and wrapping after the eleventh; a visit that deals before the turn uses no tip. A launch that resumes straight onto the table (D64) shows no tip card. The five of hearts on the home screen sways slowly and turns over to its back about every 9 s; it is not a control. Under Reduce Motion the turn and the deal are crossfades and the five holds still. The table counts as covered while the card is up, so no computer acts behind it.

**Over:** Continue game and New match, and going straight to the table.

**Why:** Connor approved the mockup: the walk from the home screen to the table is a moment to teach one thing, the way someone at a real table says a word while they shuffle, and the eleventh tip says the game needs no connection.

## D68. A quick riffle at the dealer's seat as each hand starts (2026-09-27)

**Chosen:** When an accepted action leaves a hand freshly dealt (bidding, no call yet: `RiffleShuffle.startsHand(_:)`), `TableView` plays `RiffleShuffle` over the dealer's deck: six small card backs split into two halves, riffle back together and fade, 0.6 s in all. It takes no taps, is hidden from VoiceOver, and is not a `TablePause` reason, so the scheduler and the computers carry on beneath it and no test waits for it. Under Reduce Motion the stack shows still and fades.

**Over:** No shuffle, or a shuffle the table waits for.

**Why:** A hand at a real table starts with the dealer shuffling; showing it marks the new hand without costing a beat.

## D69. A won match is celebrated, and a 9 and out gets its own moment (2026-09-27)

**Chosen:** When an action wins the match, `TableView` plays `GameModel.celebrations` before the hand-end card shows (`TableSurface.holdsResult`): first, if the deciding hand was bid 9 and out, `NineAndOutScreen`, full screen, "9 and out" large in the display serif and gold with the bidder's name and High, Low, Jack, Five and Game each ticked, or, if it was missed, a quieter ivory "9 and out missed" naming the points missed with those rows crossed and dimmed; then, for a win worth cheering (your team in solo, any team in pass and play), `CardCascade`, sixteen cards tumbling across the table for 2 s with a success haptic when haptics are on. A lost solo match has no cascade. The 9-and-out screen moves on after 3.5 s or at a tap; the cascade takes no taps. Everything is read from the engine's finished hand (`NineAndOutResult(summary:)`, from `HandScore`'s point owners, an undealt Jack or Five counting as missed) and `Match.winner`; the engine is unchanged. Under Reduce Motion the cascade is a still spread of five cards and the steps crossfade.

**Over:** Going straight to the match-over card, as before.

**Why:** Winning a match, and above all making 9 and out, is the moment the family talks about afterwards; the table should mark it. The existing match-won cue (D-series haptics, `TableFeedback`) still fires when the match is won, so a win that cascades straight away feels two success taps close together.

## D70. The partner asks before 9 and out (2026-09-27)

**Chosen:** The 9-and-out pill opens `NineAndOutConfirm`, a card over the dimmed table in the partner's voice: the portrait and name of the phone holder's partner (`GameModel.partnerSeat`, across from the bottom seat, so in pass and play it is that seat's partner), the line "Are you sure? Take all nine and we win the match. Miss one and we lose it.", a gold "I'm sure" that sends the bid, and "Not this time", always present; a tap on the dim also backs out. The card keeps `confirmNineAndOut`, so the table stays paused while it is up, and the engine still judges the bid when it is sent. The label on the gold button is the header's dark brown, not black, under the palette rule. It replaces the system `confirmationDialog` with its red destructive button.

**Over:** The confirmation dialog, which on iOS 26 anchors to its button as a popover and drops its Cancel button (D57), and whose red button put the suit colour on a control.

**Why:** At a real table it is the partner who says "are you sure?"; the card makes that the voice of the check and keeps an explicit way out on every system.

## D71. A team down 10 bids one step bolder (2026-09-27)

**Chosen:** When a Standard computer's team trails the other team by 10 match points or more (`ComputerPlayer.boldDeficit`), the most it will bid rises by one: `bidAdvice` adds one to its whole-point ceiling (estimate or house floor, whichever is higher), capped at 9. Nothing else in the bid changes: the house floors, the dealer's match, never outbidding a partner. The rule never produces a 9 and out and never bids above 9. The advice ends "Your team is down 12, so the table bids one step bolder." when the extra step is what made the bid. One pure function, `ComputerPlayer.isTrailingBadly(_:)`, decides it for the bidding and for the table's note ("JC and Diane are down 12, bidding bolder."), shown once per hand when one of that team's computer seats calls and faded after 3 s. To see the score the computer now receives it: `PlayerView.scores`, the score as it stood when the hand was dealt. Easy (the frozen `EasyPlayer`) is untouched, and so are card play, trump choice, discards, scoring and every rule.

**Over:** Bidding the same whatever the score. At Connor's table a team that is down a lot bids bolder, and he set "a lot" at 10.

**Why:** It is a character rule, the way his family plays, not a strength tune: the computers should feel like that table. The score is written down in front of everyone, so passing it across the `PlayerView` boundary keeps D6.

**Measured** (`boldWhenTrailingIsMeasuredAgainstTheSameStrategyWithoutIt` with `CATCH5_FULL_BENCHMARK=1`: Standard with the rule against Standard with the score hidden, every seed played twice with the teams swapped). Seeds 1..<601: win rate 0.503, margin +0.06 per match; seeds 601..<1201: 0.496, margin −0.14. All 2400 matches: win rate 0.499, margin −0.04, which is no measurable change in strength. Contracts bid by a team down 10 or more were made 682 of 921 times with the rule (0.740) against 693 of 868 without (0.798): the rule takes more contracts from behind and makes a smaller share of them. The sin hunt measures card play, which D71 does not change, so it plays with the score hidden: its seeded matches stay the ones its ceilings were set on. The full measurement runs with `CATCH5_FULL_BENCHMARK=1`; by default a 40-match sample keeps `swift test` quick. The threshold and the step are Connor's and were not tuned to these numbers.

## D72. The rules sheet ends with the family's note and a way to write to us (2026-09-27)

**Chosen:** After the last chapter of "How to play Catch 5" (`RulesView`), a sign-off in the display serif's italic: "We're honored you took a seat at our table. This game has been part of my family for generations. Always will be. The rules stay as they are, but if you have ideas for the app, email me. I'd love to hear them." Below it, cmurphy1140@gmail.com as an underlined ivory `Link` that opens a new mail with the subject "Catch 5". The words and the address live in `RulesText` beside `origin` (`signOff`, `contactEmail`, `contactURL`), outside the rule sections, so the verbatim check against `docs/catch-five-rules.md` is unchanged. The link is ivory, not gold, because gold keeps its established meanings.

**Over:** No way for a player to reach the family from the app, or a contact line inside the rules themselves.

**Why:** Connor asked for it (N34): the rules are the family's and stay as they are, but ideas for the app are welcome. `rulesSheetEndsWithTheFamilysNoteAndAMailLink` holds the wording and the link.

## D73. Bigger faces for big moments, and one line after the hand (2026-09-27)

**Chosen:** Two public moments get louder faces, ahead of the turn face, and the portrait grows to `Theme.Table.bigMomentScale` (1.3) while they last: the trick that caught the five of trump, while it lies on the table (the takers triumphant, the other team dismayed), and a 9-and-out declaration, from the call until the first lead (the declarer's partner `surprised`, a new `Portrait.Expression` drawn in the same style: raised brows, wider eyes, a small round mouth). Both end at the next lead. Seats say nothing while a hand is played. Once it is over, in solo, the hand-end card opens with one line from one seat, its portrait and table name above the result: the first of four lines in `HandEndLine.lines` that fits the public result (your team set: partner, "We'll get it back."; the other team set: its bidder, "Ouch."; your team caught the five: partner, "Nice catch on the five."; your team made its bid: partner, "That's how it's done."), or none. Pass and play shows no line: every seat is a person holding the phone in turn, and nobody should be spoken for. Everything is read from `Hand` in public (the trick's plays, the trump, the auction's calls) and the finished `HandSummary`.

**Over:** The same pleased or rueful face for every trick, no reaction to a 9 and out, and a silent hand-end card.

**Why:** Connor asked for it (N36): the five and a 9 and out are what the table reacts to, and a word from your partner after the hand is how a real table sounds. Words stay off the table during play so they can never read as a signal.

## D74. Why we play closes each round of tips (2026-09-27)

**Chosen:** The tip card's rotation (D67) gains one face after the eleventh tip, labelled "WHY WE PLAY": "52 cards. Endless ways to play. But at the end of the day, it brings people together." It is not numbered, so the tips keep "TIP n OF 11". One full cycle is twelve faces (`TipDeck.cycle`); `TipDeck.face(_:)` reads `Settings.nextTip` round it and `takeNextTip()` wraps at twelve, so the card shows once per cycle, then tip 1 again. A saved index from before (0 to 10) lands on the same tip as it did.

**Over:** Adding it as a twelfth numbered tip, or showing it on every visit.

**Why:** Connor asked for it (N38): it is the reason behind the game, not advice about it, so it sits apart from the tips and comes round once.

## D75. No see-through pills; the home menu is a bare, bigger icon (2026-09-27)

**Chosen:** `MenuButtons.plain` (the pause card's "Main menu" and the home screen's "Deal me in", "How to play") now matches `MenuButtons.prominent`'s solid `Theme.Wood.dark` fill and ivory label, instead of `.buttonStyle(.bordered).tint(.ivory.opacity(0.8))`, which let the wood show through. The same fix applies to the intro's "Learn the game" (`IntroView.swift`) and the build explainer's "Previous" (`ExplainerView.swift`). `MainMenuView`'s hamburger drops `Menu`'s implicit chrome with `.menuStyle(.borderlessButton)` and grows from `.title2` to a 33 pt glyph (about 1.5x), ivory with a shadow, still inside the 44×44 pt hit area and the "Menu" accessibility label. In `RulesView`, the chapter rail's `.ultraThinMaterial` backing becomes a solid `Theme.Wood.inlay`, and its chip fills drop their `.opacity` (solid `Theme.Wood.dark` when active, `Theme.Wood.inlay` otherwise), the gold ring alone marking the active chapter.

**Over:** Translucent bordered buttons and a glass-backed menu icon, both of which let the felt or wood grain show through a control (R19: no translucent borders or plates on icons).

**Why:** Connor marked up a screenshot of the home screen (N39, N40): every button reads as one solid piece of the table's wood, and the menu is a glyph, not a plate floating on glass.

## D76. The table's corners sit on light tan (2026-09-27)

**Chosen:** Both top corners (D65) take one fill, `Theme.Table.cornerFill`, a very light tan (RGB 0.91, 0.84, 0.70): the bid plaque drops its near-black `Theme.Wood.inlay` and the trump tile its ivory. The plaque's words move to the wood's dark browns: "BID" and the bidder's name in `Theme.Wood.dark`, the number (and "and out") in `Theme.Wood.streakDark`. The trump glyph keeps its suit's colour, red for hearts and diamonds and black for spades and clubs (`TrumpTile.glyphColor(_:)`). Size, position, the tally and its gestures are unchanged.

**Over:** A near-black plaque beside an ivory tile, two corners that read as different objects.

**Why:** Connor marked up a screenshot of the table (N41): the two corners are one pair and should look it. `tableCornersSitOnLightTanWithDarkBrownInkAndSuitColouredTrump` holds the fill, the ink and the suit colours.

## D77. Bigger faces that pop out of their circles (2026-09-28)

**Chosen:** Table portraits grow from 68 to 86 pt (`Theme.Table.portraitSize`, about 1.3×). The green disc stays, but the character inside is drawn 1.2× larger and raised a quarter of the face (`Theme.Portrait.popScale`, `popRise`): the shoulders stay clipped to the disc and the head rises over its top edge (`PortraitView(popsOut:)`). The seat draws the head a second time over its rings (`headOnly`), so the bidder's dashed ring and the gold halo pass behind the head, and keeps `Theme.Table.portraitHeadroom` (0.24 of the face) above the disc so the tallest hat never reaches the header. To make room: while bidding, the side seats rise `Theme.Table.biddingSideRise` (100 pt) beside the partner so the bid pills and Pass still sit above the hand; the dealer's deck tucks 10 pt closer to the face; a big moment's face (D73) grows 1.15× from its bottom edge (99 pt, still larger than the old 1.3× of 68) so it neither covers the name nor reaches the pile, and the table column clips only top and bottom so a side face at that size is not cut at the screen's edge. Other portraits (menu, pickers, hand-end card, tutorial) are unchanged.

**Over:** Faces sized to sit wholly inside their discs, or a larger disc, which the side tiles beside the pile cannot hold.

**Why:** Connor asked for bigger faces that pop out of their circles (N48, N49). At rest face and halo fit a side tile on iPhone 16 and 16 Pro, and at full breath or a big moment they stay within the gap beside it, never the pile's reservation; `seatTilesHoldTheLargerFaceAndItsHaloOnEveryVerifiedWidth` and `tableFacesAreBiggerAndTheirHeadsPopOutOfTheirDiscs` hold the sizes.

## D78. Two hands reach for the five on the home screen (2026-09-28)

**Chosen:** The home screen's five of hearts gains two hands, one reaching down from above for its top-right corner and one reaching up from below for its bottom-left, as if two players were going for the same card. Each is a `ReachingHand` (`MainMenuView.swift`): flat shapes in the cast's style, a palm, four fingers and a thumb in a portrait skin tone (tan above, brown below), a sleeve (the olive shirt colour above, `Theme.Wood.dark` below) with an ivory cuff. They drift 5 pt toward the card and back with its sway; under Reduce Motion the card and the hands hold still. The card keeps `HomeFiveCard.handRoom` (44 pt) above and below so the hands clear the title and the player card. They are decoration: no hit testing, hidden from VoiceOver.

**Over:** The card alone, or photographic or emoji hands.

**Why:** Connor asked for it (N47): "like catch five", the game's name in a picture.

## D79. The review bar says "Reviewing last trick" (2026-09-28)

**Chosen:** While the player has the pile reopened, the status line reads "Reviewing last trick" (`TableSurface.reviewLabel`), not "Reviewing last hand". The corners keep showing the bid and trump underneath, as in play.

**Over:** "Reviewing last hand", which promised a finished hand's result the view never showed.

**Why:** What reopens is the last trick of the hand in play (`reopenedTrick`), which has no hand score yet (N42). `reviewBarSaysItIsTheLastTrick` holds the words.

## D80. Bigger matching corners, with the bidder's face (2026-09-28)

**Chosen:** The two light tan corners (D65, D76) take one size: `TableLayout.cornerWidth(available:)` wide (up to `Theme.Table.cornerWidth`, 124 pt, and never so wide that the row overruns: 120 pt on the iPhone 16, 124 on the 16 Pro, 111 on the SE) by `Theme.Table.cornerHeight` (116 pt), so with the partner's tile they fill about 99 percent of the top row. Both have the same fill, edge and shadow. The bid corner shows the bidder's own portrait (`Contract.portrait`, the face at their seat, 50 pt and popping out of its disc as at the table, D77) beside a small BID and the number at 56 pt, with the bidder's name small underneath; the trump corner shows the suit at 80 pt, with the tally strokes still under it and the whole corner still the tap target. The first time a corner fills (the bid resolved, trump named) it grows in from 0.6 with an ivory glow that fades over 0.9 s (`CornerArrival`); under Reduce Motion it fades in.

**Over:** A 92 pt plaque beside a shorter trump tile, the bidder named but not shown, and corners that simply appear.

**Why:** Connor asked for it (N51, N52, N53): the corners are the table's scoreboard for the hand, and people who won't read small text need a big number, a big suit and a face they recognise, and a nudge to look there. `tableCornersMatchAndNearlyFillTheTopRowBesideThePartner` holds the widths, the sizes and the bidder's face.

## D81. Every seat has a bid box, and the bid row keeps every number (2026-09-28)

**Chosen:** While the auction runs, every seat has a small light tan box with a light brown edge beside it (`BidBox`, `Theme.Table.bidBox*`): the partner's to their right, level with the top of their face; each side seat's low beside it, toward the empty middle of the table; the phone holder's at the left of the status line, above the bid row. A box is a faint outline until its seat speaks, then shows the bid large, PASS, or 9 OUT (`BidBox.label(for:in:)`); the call grows in from where it was made, the bid row for your box and the seat for the others, and fades in under Reduce Motion. The boxes go when the auction ends and the bid corner takes over. The "Bid N" pill under a seat is gone, and so are the High and Lowest chips over the row: the boxes say who bid what, and the lowest bid still open keeps its light brown edge. The bid row is one row of every number from 2 to 9 (`TableSurface.bidRow(allows:)`, `BidPill`); a number the auction has passed stays in place, greyed and disabled. 9 and out hangs from the 9's lower edge, flush with the row's end. The `bidding` screenshot stage deals until a bid and a pass are both in the boxes before your turn.

**Over:** Only the legal bids offered in a 4 by 2 grid (B03), with the standing bid in chips and in a pill under the bidder.

**Why:** Connor asked for it (N55): the numbers stayed put so the row reads like a real bidding box, and every seat's call is where that seat sits. Dropping the chips frees a row, which the one-row bid strip needs. `everySeatsBidBoxShowsItsCallBigPassOrNineOut` and `theBidRowKeepsEveryNumberAndGreysTheOnesPassed` hold it.

## D82. Green score rails to 25 down both edges of the table (2026-09-28)

**Chosen:** Two thick green number lines run down the table's edges in the margin beside the hand (`ScoreRail`, drawn by `TableView.scoreRails`): the phone holder's team on the left, from just below the left side seat to the bottom, labelled US; the other team on the right, from below the right side seat, labelled THEM; in pass and play each names its pair (`ScoreRail.label(us:mode:teamNames:)`). Each is a darker green track with a darker edge, a lighter green fill with a mid-green edge, ticks at 5, 10, 15, 20 and 25 (`ScoreRail.ticks`), and the score bold above it. The rails read the last finished hand's scores (`ScoreRail.shown(in:)`), so they hold still through a hand and fill to the new score when it ends, over 0.8 s (`Theme.Motion.railFill`); under Reduce Motion they jump. A score below zero leaves the bar empty and shows the negative number (`ScoreRail.fill(_:)`). The side seats report their lower edge (`TableSurface.onSideSeats`) so a rail starts below them in both the auction and play. The hand-end card stands in `Theme.Table.railClearance` (32 pt) from the table's sides so the rails' labels stay clear while they fill.

**Over:** The score only in the header, or rails that move with every point taken during a hand.

**Why:** Connor asked for it (N59): the race to 25 at a glance, from arm's length. `scoreRailsFillToTwentyFiveAndEmptyBelowZero` and `scoreRailsMoveOnlyWhenTheHandEnds` hold it.

## D83. The score sits at the rails' feet, each opening its team's panel (2026-09-28)

**Chosen:** Each team's score moves from the top of its green rail (D82) to its foot, on a light tan tab with a light brown edge in the table's bottom corner: US bottom-left, THEM bottom-right, the pairs' names in pass and play. The hand keeps a band under it (`Theme.Table.railFootRoom`, 50 pt, the dealer row when you deal) so the tabs sit clear of the cards. Tapping a tab raises that team's `ScorePanel` from the bottom over the table: its label and players, its total, the 25 points as dots filled in green up to it (`ScorePanel.dots(_:)`), and the hands so far as cards that page sideways, newest first, each with the bidder, made or set, the change and the running total (`ScorePanel.content(team:history:seatNames:)`). A tap outside or a swipe up or down closes it; play waits while it is open. The header keeps only the pause button (`ScoreBarView`); the space where the score was stays empty. The full Score page (`ScoreboardView`) is gone.

**Over:** The score in the header opening a scrolling Score page with red dots.

**Why:** Connor asked for it (N62): the score where the rails end, one team at a time, with nothing to scroll. `theHeaderCarriesNoScore` and `eachTeamsPanelShowsItsTotalDotsAndHands` hold it.

## D84. The table shows its two taps once, the first time trump is named (2026-09-28)

**Chosen:** The first time trump is named on an install, once nothing covers the table, the app shows the two hand-kept notes by itself (`TallyDemo`): the trump tile presses and releases as if tapped (`DemoTap`) under the big bold caption "Count trump as it falls", then the opponent on the phone holder's left does, under "Mark who's out of trump" (`TallyDemoCaption`, light tan with a light brown edge, in the middle of the table). Each step holds 2.8 s (`TallyDemo.stepSeconds`) or until the caption is tapped, and play waits meanwhile. It is only a show: no tally mark or badge is made. `Settings.hasSeenTallyDemo` (Codable, false by default and for older files) is saved when it starts, so it never shows again, even if cut short. Under Reduce Motion the captions come without the pulse. Screenshot stages leave it out except `demo`, which holds the first caption.

**Over:** A tip in How to play, or captions that stay until dismissed.

**Why:** Connor asked for it (N61): the tally and the out-of-trump badge are invisible until someone shows them. `theTallyDemoShowsOnceAndTheFlagPersists` and `theTallyDemoLeavesTheTallyAndBadgesAlone` hold it.

## D85. 9 and out takes its own line under the bid row (2026-09-28)

**Chosen:** When 9 and out may be bid, its small dark pill sits on a short line of its own between the numbers and Pass, flush right under the 9 (`TableSurface.auctionRows(nineAndOut:)`). The numbers stay one row across the screen.

**Over:** The pill hanging from the 9's lower edge (D81), where it covered the bottom of the 8 and the 9.

**Why:** Connor asked for it: no pill may cover a number. `nineAndOutTakesItsOwnLineUnderTheBidRow` holds the order.

## D86. Table and Clarify across the top (2026-09-28)

**Chosen:** The lone pause button gives way to one long, skinny bar across the top of the table (`TableBar`): two light tan boxes with a light brown edge and a small gap, "Table" and "Clarify", in big bold type, each opening a drop-down under it on a light tan card (`TableBarMenu`); a tap outside closes it and play waits while it is open (`TablePause.menuShown`). Table holds Pause (the pause card drops down over the table, Continue game and one big line: "You can leave the app and come back to this exact spot.", `WelcomeCard.keepsPlace`), New game (Solo or Pass and play, then the "Start over?" alert, still an alert with Cancel as D57 requires) and Home (the main menu, the match kept). Clarify holds four short answers to "what am I looking at", the bid box, the scorecard, tapping the suit to count trump and tapping a face to mark who's out (`TableBar.answers`), and a How to play button that opens the lessons. The screenshot stages `table-menu` and `clarify` open each drop-down over the `table` state.

**Over:** A bare pause glyph, with New game and Home only on the pause card and the main menu, and the table's taps explained nowhere on the table.

**Why:** Connor asked for it (N68): the controls and the answers should be where the players are looking. `theTableBarHasTableAndClarifyWithTheirDropDowns` holds the boxes, their contents and the pause.

## D87. The bid box holds who bid, the bid and trump (2026-09-28)

**Chosen:** The bid box in the top-left corner (`ContractPlaque`) carries Connor's three biggest things: the bidder's face, the bid, and trump. The face (46 pt) and the bid (52 pt serif under BID) share the top of the box; trump, once named, sits under them at 48 pt in its suit's colour (`Theme.Table.bidBoxSuitSize`), with the player's tally strokes beside it in dark brown. The separate trump tile is gone. The suit is where the tally lives now: tap adds a mark, press and hold takes one back, VoiceOver adjusts it, and the one-time tally demo (D84) pulses the suit. The bidder's name leaves the box; VoiceOver still reads it, and the name tags carry names (D89).

**Over:** A bid plaque in one corner and a trump tile with the tally in the other (D65, D80).

**Why:** Connor asked for it (N63, N67): one place to look for the hand's contract, and the top-right corner freed for the scorecard. `theBidBoxShowsTheFaceTheBidAndTrumpAndTheSuitKeepsTheTally` holds the contents and the tally.

## D88. A notebook scorecard in the top-right corner; the green rails go (2026-09-28)

**Chosen:** The top-right corner, freed by trump moving into the bid box (D87), holds the scorecard (`Scorecard`): the bid box's size and light tan, with faint ruled lines like a notebook page and a line between two columns, US and THEM (the phone holder's team first, also in pass and play). When a hand ends each team's new total is handwritten in Marker Felt, built into iOS, on the next line and the total above it gets a scratch through it (`Scorecard.lines(team:history:)`); nothing changes during a hand. The newest three lines show. A tap opens the full sheet (`ScorePanel`), now both teams side by side, each with its total and 25 green dots, and every hand as a card paging sideways with both teams' change and total, so nothing scrolls down. The green rails and their bottom tabs (D82, D83) are gone, and the hand no longer keeps the 50 pt band they needed. Under the hand-end card everything fades back except the scorecard, and the card starts under the top row, so the new total is in view. The partner's auction box moves to the partner's left, into the empty bid box corner, since the scorecard holds the right; the side seats rise 48 pt while bidding (was 100) so they stay under the scorecard. The `result` screenshot stage plays two hands.

**Over:** Green rails down both edges with tabs at their feet opening one team's panel.

**Why:** Connor asked for it (N66): a score kept the way the family keeps it on paper. `theScorecardWritesEachNewTotalAndStrikesThePriorOne` holds the lines after one and two hands.

## D89. Name tags above every head (2026-09-28)

**Chosen:** Every seat wears a "HI, MY NAME IS" sticker floating above its head, not on the body (`NameTag`): white with a green outline, the words printed on a green band, the name handwritten under it in Marker Felt, 88 pt wide. It replaces the name under the face. The partner's stack of backs rides with the tag, tucked behind its corner, so the partner's tile ends at the face; the side seats keep theirs under the face. The phone holder has no face on the table, so their tag sits under the hand on the left, in the row the deal uses when it is theirs; in pass and play every tag turns with the phone (`NameTag.names(_:)`). To keep "Your turn" on screen with the taller seats, the table's column now runs under the bottom safe area, stopping 16 pt above the screen's edge (`Theme.Table.footInset`), since the home indicator only takes the middle of that edge; and while bidding the side seats rise 36 pt (was 48, D88) so the right-hand tag stays under the scorecard.

**Over:** Names in small type under the faces, and no name for the phone holder.

**Why:** Connor asked for it (N64): names big enough to read from across the table, in the look of a real name sticker. `everySeatWearsANameTagWithItsName` holds the words and the names by place.

## D90. A big dealer mark, and no BIDDER word (2026-09-28)

**Chosen:** Whoever deals wears the dealer's mark (`DealerMark`): a proper four-card deck, 30 pt cards where the old stack was 24, with a big DEALER on a light tan pill with a light brown edge across its foot, in dark brown rather than the old small gold word. It sits off to the right: a side seat's to the right of its stack of backs under the face (its band grows to hold it only while that seat deals, so nothing jumps within a hand), the partner's out beside their tile, right of their card on the pile and under the scorecard, and the phone holder's to the right of their name tag under the hand, the pill beside the deck there so the row stays short. The deal still flies in from the mark's deck (`DealerDeck`). The BIDDER word under a seat is gone: the bid box shows who bid (D87), and the dashed ring on the bidder's face stays. `SeatView.marks(seat:dealer:bidder:)` says what a seat wears. To fit the bidding screen with the bigger mark, the bar's boxes are 36 pt tall (was 40), with 4 pt under the bar and 6 pt above the seats (were 8 and 10).

**Over:** A small deck tucked into the dealer's face, DEALER and BIDDER in small monospaced type under the seat.

**Why:** Connor asked for it (N65): who deals should read from across the table. `onlyTheDealerIsMarkedAndNoSeatSaysBidder` holds the words and the size.

## D91. The bidder opens with trump (2026-09-29)

**Chosen:** A house-rule change decided by Connor after his mom's playtest: the bid winner's opening lead of every hand must be a trump if they hold one. With no trump, any card may lead. Every later lead in the hand is free, and following suit is unchanged. The rule lives in the one legality function, `legalCards(in:led:openingTrump:)`, which `Hand.legalMoves`, the standard computer and the frozen Easy computer all call; a refused opening lead throws `HandError.mustLeadTrump`. Saves move to version 2; `decode` still reads version 1 and replays it under the current rules, so an old game whose opening lead broke the rule fails replay and is set aside by the existing corrupt-save path. The `RuleTrial` follow-suit position now gives the leader no spade, so its heart lead stays legal. The bot-sin ceilings for tens and lows were re-measured on the new seeded games (18 and 21, from 12 and 17).

**Over:** Any card on every lead; a separate check for the bots; a settings toggle.

**Why:** Connor's table plays it this way. One legality function means the human, both bots, hints and saves cannot disagree about it. `bidderHoldingTrumpMustOpenWithTrump`, `bidderWithoutTrumpMayOpenWithAnyCard`, `leadsAfterTheFirstTrickAreFree`, `bothBotsOpenTheHandWithTrump` and the two version 1 save tests hold it.

## D92. The cast dresses as scholars (2026-09-29)

**Chosen:** The game is a gift for an 8th-grade teacher who loves reading, so the faces turn bookish. `Portrait` gains cases only: round reading `spectacles` (smaller, finer and lower than `glasses`, with a lens glint and arms), a `mortarboard` hat (skullcap, flat board, brick-red tassel off the right corner, its top at `tallestTop` so popped heads still fit the seat's headroom) and `tweed`, `oxford` and `burgundy` shirts that show at the neck. Hazel wears spectacles and a burgundy cardigan, Otto keeps his moustache and cap over a tweed jacket, Rue keeps her freckles and wears a mortarboard and an oxford shirt; the four player faces each carry at least one scholarly part. Skin and hair are unchanged, so the cast stays recognisable.

**Over:** Renaming or removing old cases (saved settings decode them); a bow tie or a pencil behind the ear, which do not read at 28 pt; a gold tassel, since gold keeps its table meanings (D33); detail low on the shirt, where the name sticker sits.

**Why:** It fits the person the game is for, without a costume. `castDressesAsScholarsAndOldFacesStillDecode` holds the cast's parts and an old settings file's face.

## D93. The table after the family playtest: Home and Rules, smaller faces, tags on shirts (2026-09-29)

**Chosen:** Eight changes Connor decided after playing with his mom. (a) The Table and Clarify bar (D86) gives way to a slim top row (`TableTopRow`): Home on the left (house glyph and the word) goes back to the main menu, and a book labelled Rules on the right opens `RulesView`. There is no Pause and nothing drops down, so `TablePause.menuShown` is gone; leaving the table already saves the game. The Clarify answers go. (b) Seat faces are 68 pt, a fifth smaller than the 86 of N48; the popped-head headroom stays a fraction of the face, so it shrinks with it. (c) Each seat's "HI, MY NAME IS" tag moves from above the head onto the lower part of the face, over the shirt, sized to fit and tilted a few degrees like a sticker; the phone holder's tag under the hand stays as it was. (d) Tapping a tag, or the seat's VoiceOver Rename action, opens an alert to rename that seat (`Settings.renameSeat(_:to:)`: seat 0 through `setPlayerName`, seats 1 to 3 written directly, blank keeps the old name); play waits while it is up. (e) The small stacks of card backs beside each seat and beside the partner's tag go; the dealer's mark stays. (f) The bid box prints the word Trump beside the suit, over the tally strokes, so the box keeps its size and the suit row stays the tally's tap target. (g) The home screen's Deal me in becomes New game, keeping its Solo or Pass and play question and its warning; the intro and the tutorial's last button say New game too. (h) The rules sheet's example tricks and tutorial lesson 4a are set later in the hand, after the bidder opened with trump (D91), and say so.

**Over:** Keeping the bar with its drop-downs; a Pause button; names above the heads; showing a hint of each hand as card backs.

**Why:** Connor asked for it after the playtest: fewer things on the table, navigation where card apps keep it (out on the top left, help on the top right), names you can fix on the spot, and pictures that obey the new opening-lead rule. `theTopRowHasHomeLeftAndRulesRightAndNothingThatPauses`, `tappingANameTagRenamesThatSeat`, `theBidBoxSaysTrumpBesideTheSuit`, `theRulesPicturesNeverShowTheBidderOpeningWithoutTrump`, `tableFacesAreAFifthSmallerAndTheirHeadsPopOutOfTheirDiscs` and `homeOffersBackToTheTableOnlyWithAMatchInProgress` hold it.

## D94. No boxes on the table: carved, inlaid or lying on it (2026-09-29)

**Chosen:** Connor's direction after the playtest build: no small white lettering and no boxes on the game page, so it looks like a table. Information is part of the table, carved into the wood, chalked on it, or an object lying on it, never a panel on top. (a) Every seat's name is carved into the wood under its face in a large heavy serif (22 pt), the phone holder's under the hand; the "HI, MY NAME IS" sticker goes. Tap-to-rename (D93) keeps its 44 pt target and VoiceOver action. (b) Trump is carved in two places once named: beside the bidder's name and beside the bid. A carving is a dark recess with an inner shadow along its upper edge and a lit lower edge (`Carving`, `Carved`); red suits are cut in an oxblood dark enough to hold 3:1 on the wood. The faint trump watermark stays. (c) The bid corner has no box: the bidder's face lies like a chip, BID and the number are carved, and the tally is chalked on the wood beside the carved suit, still tap to add, press and hold to take back, VoiceOver adjustable. (d) The scorecard is a score pad lying on the table, square-cornered paper turned 2 degrees with a soft shadow, no frame. (e) The DEALER pill becomes a dealer button, an ivory puck with a D engraved, resting at the foot of the dealer's deck in front of the seat (`DealerMark.placement(forPlace:)`). (f) Home is a house and the word carved into the wood; Rules is a small closed burgundy book lying on the table. (g) The rules open from the table like a book: the page swings onto the screen about its left edge with a little perspective in 0.5 s and back when closed, a fade under Reduce Motion (`BookFold`). (h) The discard notice, refusals, hints, the auction context and your call are set at body size in full ivory, the trump pills' names and 9 and out a size up; the "First lead" caption goes, since "Your turn" already says it. The auction's seat boxes (N55) lose their fill too and their calls are carved.

**Over:** Embroidering names on the shirts, which would not read at 15 pt or more on a 68 pt face; suit-coloured red carvings, which reach only about 1.2:1 on the wood; dropping the discard notice, which nothing else on the table shows.

**Why:** Connor: "no more small white lettering, no more boxes in the game page, it should look like a table and the boxes look amature." `carvingsReadOnTheWood`, `nothingAPlayerMustReadIsSmallerThanFifteenPoints`, `trumpIsCarvedBesideTheBiddersNameAndBesideTheBid`, `theDealerButtonRestsInFrontOfTheDealersSeat`, `theCarvedNameStillRenamesItsSeat`, `theScorePadLiesOnTheTableAtASlightTurn` and `theRulesOpenLikeABook` hold it.

## D95. Home is a back arrow; the suits are carved too (2026-09-29)

**Chosen:** Connor's direction on the D94 build. (a) Home is a single carved back arrow, top left above the bid corner, with no house and no word beside it (`TableTopRow.home`, `showsTitle` false); VoiceOver still reads "Home" and the target stays 44 pt. (b) The suits were cut with the letters' 1 pt shadow, which vanishes on a 28 to 48 pt glyph, so they read as flat solid shapes. A carving's shadow and lit lip now grow with its size (`Carving.depth(size:)`, 1 at the name size and below), and a suit's recess is shaded from the ink at its top to a lighter floor at its foot (`Carving.floor(for:)`), both still 3:1 on the wood. This covers the trump in the bid corner and beside the bidder's name. (c) The bid corner sets the suit and the word together on one line, "♠ Trump" (`ContractPlaque.trumpLine(_:)`, the suit at `Theme.Table.trumpLineSuitSize`), with the tally chalked under the line instead of the suit sitting apart bottom-left.

**Over:** A chevron, which reads as a list disclosure as often as a way back; keeping the 48 pt suit apart from the word.

**Why:** Connor: "you dont need yo write home next to a icon of a home", "use and arrow", "above it", and "yes carve the spade too". `homeIsACarvedBackArrowWithNoWord`, `carvedSuitsAreCutConcaveLikeTheLetters` and `theBidCornerSetsTheSuitAndTrumpOnOneLine` hold it.


## D96. UI audit preview: score meaning and bidding targets (2026-09-30)

**Implemented on `codex/ui-audit-preview`; commit and squash merge authorized September 30:** Connor requested a separate branch to see the audit improvements in action. Label running scores “Total” and deltas “This hand”; let team names wrap; call the review’s individual plays “Trick” rather than “Hand”. Present the factual hand summary before the character response. Keep the current artwork and rules. Numeric bids retain their ascending order, disabled states and lowest-legal outline; use one row when eight 44-point targets and spacing fit, otherwise two rows of four. Give the compact 9-and-out pill an explicit 44-point hit region.

**Verification:** Native rendering, compilation, accessibility, and device play are pending on a Mac. Merge authorization is separate from visual acceptance. Inspect the narrowest phone and large text during the next device play check; the extra bid row may require the existing vertical scroll fallback.

## D97. The tactile table: a walnut field, real cards, and cards that travel (2026-10-04)

**Implemented on `ui/tactile-table`, not yet accepted:** Connor asked for the table to feel like a polished, tactile card game while keeping the oak, the cream cards, the dark-red accents and the mid-century character, and for one coherent table-and-trick experience to be shown as a recording before any other screen changes. (a) **A playing field** (`TableField`): a walnut panel inlaid in the oak between the seats, its grain running across the oak's, a maple stringing line just inside its edge, shadowed under its top edge and lit along its lower lip. It ends just under the side row, so it keeps its size whoever's turn it is, and the side tiles keep their play width through the auction so it never changes shape until play opens it out. Trump is inlaid at its centre once named, maple for black suits and a red wood for red ones, replacing the faint watermark. (b) **Turn:** a pool of lamplight on the field slides toward the seat to act, beside the gold halo (D33's third meaning, unchanged). (c) **Sides:** each portrait's rim says its team, light for the phone holder's side and oxblood for the other (`SeatView.rim`). (d) **Cards** (`CardFace`): poker proportions (1:1.4), rank and suit in two opposite corners, the pips laid out as a deck prints them, a single large pip for an ace and a framed letter for a court card; hand cards 64 pt (70 on wide phones) with a 12 pt overlap. A legal card on your turn stands up 10 pt, an illegal one sinks 4 pt under its shade, and the picked card rises 30 pt with a warm edge while the table says "Tap the Q♥ again to play it, or drag it up". Dragging a card up 70 pt plays it; a shorter drag springs back. (e) **Motion** (`TableMotion`, `FlightPlan`, `FlightLayer`): a fresh hand is dealt from the dealer's deck, two rounds of three from the dealer's left, your cards landing edge-on and turning face up; a deal that can no longer run (a call made before it began, the pass-and-play curtain, Reduce Motion) is skipped so the hand shows at once; a played card flies from its player's face, or from where your finger let it go, to its spot; a finished trick is held, gathers onto the winning card and is pulled to the winner, whose face nods; the hand's result comes up only after its last trick has been taken, and a match-win celebration waits for it too. Flights only draw: they are view state planned from the match after each accepted action (`MotionSnapshot.change`), a play in the air is hidden on the field until it lands, and undo, a new game or a restore resets them at once. Reduce Motion replaces every flight with a fade. (f) **The trick fits the field:** its top and bottom nudges grow with the cards' own text-size scale, so the field always holds the whole trick, and each card's toss is keyed to its own trick so nothing shifts when the fourth card lands. (g) **The auction fits above the hand** on an iPhone 16, which it did not since D96's two rows: the pills sit 54 pt tall when they wrap, Pass too; 9 and out moves from its own line (D85) to the right end of the Pass row, still under the 9 and covering no number; a side dealer's deck and button lie side by side; the hand lies flat with no fan allowance; the dealer's note is one line; the status line while a computer bids says only who is bidding, since every call is chalked. (h) The auction's seat boxes are chalked rather than carved (over D94's carving), so they read on the oak and on the walnut where the side boxes tuck over it.

**Over:** An oxblood leather field, which made the dark red the table's main colour rather than an accent; green baize, which D33 already set aside; a full-width field with the side seats sitting on it, which would have put carved names on dark wood; a heads-up score rail, which D94 rules out; matched geometry for the played card, which cannot start from a dragged card or draw above the hand.

**Why:** The audit in [tactile-table.md](tactile-table.md): one flat plane, invisible teams, a turn that was hard to follow, cards that read as tiles, and motion that stopped at the moments that matter. A headless XCUITest probe found that Pass and 9 and out sat under the hand on an iPhone 16, reachable only by scrolling. `onePlayForwardIsAFlightAndAnythingElseIsAReset`, `aFinishedTrickGathersOnTheWinnerAndIsTakenToThem`, `theDealGoesRoundTheTableFromTheDealersLeftTwoRoundsOfThree`, `landingShowsWhatAFlightCarriedAndAResetPutsEverythingBack`, `aNewHandStartsWithNothingOfItOnTheField`, `aDealThatCanNoLongerRunIsSkippedSoTheHandShows`, `theLastTrickIsTakenBeforeTheResultComesUp`, `cardsArePokerSizedWithRealPipLayouts`, `theFieldSitsBetweenTheSeatsAndReadsUnderTheCards`, `theSidesWearTheirOwnRim` and `nineAndOutSitsOnThePassRowUnderTheNine` hold it.

## D98. The score pad moves to the top row, the book grows, and the table stops announcing (2026-10-04)

**Implemented on `ui/tactile-table`, not yet accepted:** Connor's notes after watching the D97 recording. (a) The scorecard leaves the table's top-right corner for the top row, a slip of score pad centred between the back arrow and the rules book, each team's name over its running total (`Scorecard.shortLabel`, `Scorecard.total`); the struck history of earlier totals stays on the full sheet, which a tap still opens. The corner it left stays empty, matching the bid corner, so the partner sits in the middle. (b) The rules book is larger (118 pt) and says it can be picked up without calling out: a cream ribbon hangs from its pages, a tooled border runs inside the cover, a soft sheen crosses it every 9 s (still under Reduce Motion), and it lifts a little when pressed (`BookPressStyle`). (c) The white lines announcing each hand and play are gone: "Connor is bidding", "Connor is choosing trump", "Hand complete", the winner's line, the discard counts ("Discarded: …", spec R4 and R20), the "bidding bolder" note (D71) and "You: Pass". The line by the hand now speaks only to you, in gold. VoiceOver still hears all of it: the status line's label carries who is deciding and the latest notice (`TableSurface.spokenStatus`), and the discards and the bolder note are announced as they happen. Refusals and the "Tap again" caption stay, since they answer something you did.

**Over:** A tall pad down the side of the table, which costs the side seats their room; dropping the scores from view and leaving them to the sheet.

**Why:** Connor: "can you move the score card else, and make the rulebook larger, while indicating that it's clearly clickable while being sublet about it. and the white text announcing each hand and play can be removed." `theScorePadSitsInTheTopRowWithShortNames` and `theTableSpeaksOnlyToYouButVoiceOverHearsEverything` hold it.

## D99. Keep the next phase below the scrolling result details (2026-10-04)

**Implemented on `ui/tactile-table`, not yet accepted on the phone:** the result's existing Deal next hand / Play again button now sits in a fixed footer below the scrolling score, review and optional seat dialogue. Rules, scoring, result text and save behavior are unchanged.

**Why:** the release smoke test completed a real hand on iPhone 16 / iOS 18.6, but its screenshot and interaction log showed that Deal next hand was not hittable until an upward swipe. A player should see how to continue when the hand ends. The bounded result-screen check now requires both Deal next hand and Play again to be hittable without scrolling, then taps each to verify progression. This is a release-flow fix, not a result redesign.

## D100. The score pad returns at its first size to the bottom-left corner, and the book grows again (2026-10-04)

**Implemented on `ui/tactile-table`, not yet accepted:** Connor's notes after playing the D98 build on his iPhone 16 Pro. (a) The score pad leaves the top row and comes back at its first size (D94: the corner's width, `Theme.Table.cornerHeight` tall, three ruled lines with the earlier totals struck), now lying in the table's bottom-left corner by the hand. It lies there while cards are played (`Scorecard.liesOnTable(phase:reviewing:)`) and slides away for the auction, whose buttons need that corner, and while the last trick is reopened, whose way back sits there; the hand's result card carries both totals. The words that float above "Your turn" (a refusal, the "Tap again" caption) move over to clear it, and the button that reopens the last trick moves from the status line's left to its right. The D98 slip and its short names (`shortLabel`, `total`) are gone. (b) The rules book grows again, to 156 by 50 pt with a larger title, now that it has the top row to itself. It is taller than the row and overhangs it a little above and below, so the table keeps its height and the auction still fits above the hand.

**Over:** The pad in the bottom-left in every phase, which would cover the 2, the 6 and Pass in the auction; a pad that shrinks for the auction; moving it back to the top-right corner while bidding, so it would jump corners every hand.

**Why:** Connor: "can you make the rules book bigger, and the scoring pad should return to its OG size, but it in the bottom left corner." `theScorePadLiesBottomLeftOnlyWhileCardsArePlayed` and `theRulesBookIsBiggerAndOverhangsTheRow` hold it. Connor chose to keep it put away during the auction.

## D101. "How Catch 5 is built" reads in short pages, and the tactile table is drawn (2026-10-04)

**Implemented on `ui/tactile-table`, not yet accepted:** the in-app explainer no longer shows a chapter as one long scroll. A chapter opens to its title, summary and one card per section; each `##` section is its own page with Previous and Next, and a section over 300 words is split into parts ("Part 2 of 4") at its `###` headings, then between blocks, a long table by rows with its header repeated (`ExplainerLibrary.pages(of:file:)`). A split section still gets one card ("3 parts · 4 min", `ExplainerLibrary.cards(for:)`), since its parts are cut by length and have no names worth choosing between; Next walks through them. The decision log lists its newest decision first. The Markdown files are unchanged: the reader does the cutting, so each topic keeps one source. Four Mermaid diagrams now draw the tactile table: where the match ends and the animation begins (`architecture.md`), and in `game-flow.md` your touch from finger to accepted play, the motion lane and the scheduler lane after every accepted action; each links to its Lucid version for a big screen. `scripts/export-docs.py` pins mermaid-cli 11.17.0, since 12.0 dropped the `-w` option it uses, and `--app` renders into a staging folder and swaps it in only after its self-check, so a failed run no longer empties `App/Explainer`.

**Over:** Splitting the docs themselves into many small files, which would scatter each topic across pages and break the links and the one-page-per-topic rule; embedding the Lucid images, which drift from the code and need a second image path in the reader.

**Why:** Connor: "break it up into bite sized pieces, some of the pages are wayyy to long", and he asked for the Lucid diagrams in the game's explainer; drawing them as Mermaid keeps them in the same commit as the code they describe. Before: the decision log was 20,010 words on one page and the types page 8,464. After: no page over 300 words unless a single block cannot be cut (the largest, one paragraph of D97, is 635). `chaptersSplitIntoSectionPagesAndLongSectionsIntoParts`, `everyRealChapterReadsInShortPagesThatCoverItOnce` and `aSplitSectionIsOneCardThatOpensOnItsFirstPart` hold it.

## D102. A computer answers a standing 9 and out with a pass or a match, never a plain 9 (2026-10-07)

**Implemented on `fix/closeout-polish`:** the closeout audit's blocker. A computer dealer with a big hand answered a 9 and out with a plain 9; the engine refused it, and the game asked the same seat again forever. While a 9 and out stands (`ComputerPlayer.facesNineAndOut`), the only legal answers are a pass or, for the dealer whose team is at zero or above, a matching 9 and out. Easy stays frozen (D17, D26), so its answer is given in `ComputerPlayer.decide(_:difficulty:)`: it passes. Standard asked a matching hook when matching was legal; it returned false, so Standard passed a standing 9 and out too (the hook is removed in D103).

**Over:** Teaching Standard when to match (a threshold on its hand estimate), which closes with the dev phase still open; editing `EasyPlayer`, which D17 and D26 freeze.

**Why:** a hand that can never end is the one bug a player cannot get around. `aComputerDealerAnswersANineAndOutWithALegalCall`, `aStandingNineAndOutIsOnlyEverPassedOrMatched` and `easyPassesAStandingNineAndOut` hold it.

## D103. Nobody, the dealer included, may match a 9 and out (2026-10-07)

**Chosen:** a house-rule correction from Connor. A 9 and out outranks a normal 9, and once one stands nobody may match or overcall it, the dealer included; its bidder keeps the bid. This replaces the dealer-match line confirmed on 2026-09-04 (D10). `Auction.act(seat:bid:nineAndOut:)` refuses any 9 and out while `isNineAndOut` is set. The dealer still matches ordinary bids. The Standard dealer's matching hook and branch in `ComputerPlayer` are removed, so every computer passes a standing 9 and out (D102's only legal answer now). The rules document, `RulesText`, the human dealer's auction line (`GameModel.auctionContext`) and the docs say the same.

**Over:** keeping the dealer's right to take over a 9 and out (D10), which is not how the family plays.

**Why:** the rules must match the table the game is written for. `nineAndOutOvercallsNineAndDealerCannotMatch`, `aStandingNineAndOutIsOnlyEverPassed` and `aDealerFacingNineAndOutIsToldToPassAndCannotMatch` hold it.

## D104. Tracing is test-only (2026-10-11)

**Chosen:** the "system at work" trace of one tap lives entirely in the test target. `Tests/CatchFiveUITests/TraceHarness.swift` listens to `GameModel`'s `@Published` fields from outside (`TapTrace`), hosts the real `HandFanView` in an unshown Mac window to count body runs and render frames (`TraceStage`), and writes `work/trace/one-tap.md` with a Mermaid sequence diagram: the announcements of one `send` in one box, the values on notes. `SystemAtWorkTests.swift` is the one test that plays the card; the run config "Catch 5 Trace" runs it and copies the report to the vault when `CATCH5_VAULT` is set. No file in `Sources/` or `App/` changes.

**Over:** a `#if DEBUG` probe at the tap site (`HandFanView.swift:208`), which never fires in a test and would ship a trace hook toward family phones; `ImageRenderer`, which draws but never re-runs a body; Instruments, which needs the simulator and shows calls, not values.

**Why:** the spike showed everything the lesson needs is observable from outside: nine announcements per `send`, each before its value changes, and a body that runs again once the run loop turns. `traceReportHoldsTheBoxAndTheNotes` and `traceStageHostsTheHandAndRendersAFrame` hold the harness; the one-tap test holds the trail.
