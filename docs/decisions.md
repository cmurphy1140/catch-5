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

**Chosen:** VoiceOver wording lives in `GameModel` (`spokenDescription`, `accessibilityValue`) where it is unit-tested; views only attach it. Fixed point sizes became text styles and `@ScaledMetric`, and Reduce Motion swaps the slide transitions for fades. The icon is rendered by `scripts/make-icon.swift` into the asset catalog, `App/PrivacyInfo.xcprivacy` declares no tracking and no required-reason APIs, and `project.yml` carries the version, category and icon settings; `build-simulator.py` copies scaled icons and the manifest into the hand-built bundle so the simulator shows the same icon.

**Over:** Ad-hoc labels in views, a hand-drawn icon file, and leaving the store metadata until a Mac with the iOS platform is available.

**Why:** Wording in the view model means the same test that checks legality checks what VoiceOver says. Rendering the icon from code keeps it reproducible and alpha-free (App Review rejects icons with transparency). Preparing the catalog, manifest and project settings now means `xcodegen && xcodebuild archive` is the only remaining step once Xcode's iOS platform is installed; `build-simulator.py` still cannot sign for devices.

Portrait iPhone first, with iPad allowed in the same 640-point column, stays the shipping layout (roadmap M6, "out": landscape and split iPad layouts).

## D31. The tutorial is built from Connor's design, with fixtures checked against the engine (PR #14, 2026-09-04)

**Chosen:** The five-lesson "How to play" flow follows [tutorial-spec.md](tutorial-spec.md) and the Claude Design reference build: fixed hand-authored positions, one exercise per lesson, completion shown on chapter pills. Every answer key is asserted against the rules engine in tests. Two deviations from the spec: completion is stored in `Settings.completedLessons` rather than `UserDefaults`, so the privacy manifest can keep declaring no required-reason APIs (D30), and the scoring fixture was corrected after the engine test showed the reference piles gave Game to the wrong side.

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

