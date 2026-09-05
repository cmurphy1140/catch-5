# Match Coordinator Plan

Approved direction: continue the pure Swift engine, explaining source-to-test connections.

## Scope
`Match` wraps `Hand` and owns scores, hand number, hand summaries and match winner. It automatically settles the final play exactly once and requires an explicit next-hand action so a future screen can show the scoring breakdown. It reuses `settle` rather than duplicating scoring rules. Normal bidding remains the supported auction path; special-auction precedence is still pending.

## Pipeline
House rule -> `Tests/CatchFiveTests/MatchTests.swift` -> `Sources/CatchFive/Match.swift` -> `Sources/CatchFiveDemo/main.swift`.

- [x] Write failing lifecycle tests: prevent premature redeal; score final card once; preserve state on invalid actions; rotate dealer; reject play after match victory.
- [x] Implement checked actions and hand summaries in Match.swift.
- [x] Test the full five-hand fixture with independently checked scores `[2,7]`, `[10,5]`, `[12,12]`, `[19,14]`, `[26,16]`.
- [x] Connect the terminal demo to Match so demonstration and future UI share the real match coordinator.
- [x] Run suite, demo, release build and iOS Simulator type check. Update project status and source/test map.

No commits or remote writes. Save/resume and computer strategy remain subsequent milestones.

## Handoff
Implemented Match.swift and six MatchTests; connected the demo to Match; added docs/code-map.md and updated README/AGENTS status. 30 tests pass. No commits or pushes. Next: save/resume and computer-player strategy; special-auction precedence remains unresolved.
