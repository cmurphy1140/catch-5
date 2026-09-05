# Catch Five Engine Implementation Plan

> Execute inline task-by-task using test-driven development. No commits without user instruction.

**Goal:** Deliver independently tested rule primitives before implementing the full hand lifecycle.

**Architecture:** Pure Swift value types and throwing validation functions. No SwiftUI, network, or external packages. A later match coordinator will use these same functions for human and computer actions.

**Tech Stack:** Swift 6, Swift Testing, iOS 17+/macOS 14+ package deployment targets.

**Spec:** `docs/catch-five-rules.md`

## Global Constraints
- User house rules override standard Pitch.
- Keep special bid auction precedence unresolved until confirmed.
- No commits or remote writes.

## Tasks
- [x] Create `Cards.swift` with Card/Suit/Rank and `Tricks.swift` with `legalCards(in:led:)` and `trickWinner(_:trump:)`. Tests reject empty/malformed tricks and distinguish following suit from trumping. Example: `#expect(legalCards(in: hand, led: .clubs) == [club])`.
- [x] Create `Bidding.swift` with a four-turn `Auction`, `Bid`, and checked `act(seat:bid:)`. Tests exercise minimum/maximum bids, forced dealer, matching, completion and out-of-turn actions. Example: `#expect(auction.winner == 3)` after the dealer matches 4.
- [x] Create `Scoring.swift` with `scoreHand(captured:trump:bidder:)` and `settle(scores:points:bidder:bid:)`. Test relative High/Low, absent scoring cards, all-suit Game ties, negative set scores, target ties and 9-and-out results. Example: `#expect(result.winner == 1)` when team 0 misses 9 and out.
- [x] For each unit: write tests, run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` and observe failure, implement, rerun to green.
- [x] Correct README, run complete suite and release build, inspect Git diff, report the tested milestone and remaining work.

## Next Milestone
Deal/refill and turn state machine; then deterministic complete-hand simulations, computer strategy, persistence, and SwiftUI integration. The present rules package is not a playable app.
