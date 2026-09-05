# Hand Lifecycle Implementation Plan

**Goal:** Run Catch 5 hands from an ordered deck through the final score without a screen.
**Architecture:** A value-type Hand owns the auction, card locations, turn and completed tricks. Its methods validate before mutation. Tests supply ordered decks and legal automatic moves.
**Spec:** `catch-five-rules.md`.

- [x] Add `Sources/CatchFive/Hand.swift`: checked 52-card initialization, normal bidding, bidder-only trump selection, discard/refill, checked card play and final scoring.
- [x] Add `Tests/CatchFiveTests/HandTests.swift`: initial dealing/card conservation, illegal-phase and ownership errors, refill, follow-suit enforcement, completed trick leader and final scoring. Write tests against empty operations, observe failure, implement and verify.
- [x] Run repeatable simulations across all dealer seats and trump suits, checking 52 unique cards across all locations after every move and termination after 24 plays.
- [x] Add a terminal demonstration to narrate one hand, then verify tests and the demonstration. Document actual status.

Implementation defaults: initial deal in two rounds of three, clockwise starting left of dealer; refill clockwise starting left of dealer, one player's replacement batch at a time. These packet-order details were not explicitly specified and are recorded as defaults, not confirmed house rules. Only non-trumps from the initial hand are discarded; replacement cards remain regardless of suit. Normal auction only until special-bid precedence is clarified.

## Verification and Handoff
24 tests pass, including 208 deterministic complete hands. Text demo completes in five hands with final scores 26–16. Files touched: Package.swift, Hand.swift, HandTests.swift, CatchFiveDemo/main.swift, README.md, AGENTS.md and this plan. No commits or pushes. Next: computer-player observations/strategy and persistent match lifecycle. Special-auction precedence remains the only outstanding rule question.
