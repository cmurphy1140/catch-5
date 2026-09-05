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

## D17. Export by rendering, never by hand-maintained copies (PR #4, 2026-09-04)

**Chosen:** `scripts/export-docs.py` generates PDF and PNG into the gitignored `work/docs-export/` folder from the Markdown source: one PDF per page, a combined `catch-five-explainer.pdf`, and one PNG per Mermaid block.

**Over:** Committing rendered images to the repo; pasting Markdown into Claude Design; adding a Node project with `package.json`.

**Why:** Claude Design imports documents, images and repos but not Markdown with Mermaid. Rendering from the source keeps one source of truth, so a diagram edit needs no second update. The toolchain (Node, mermaid-cli, headless Chrome) is already on the Mac, so a stdlib Python script that shells out matches how the simulator build already works.
