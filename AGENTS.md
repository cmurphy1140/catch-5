# Catch 5

## Current Status
Greenfield SwiftUI iOS app with a Hint button that explains the computer strategy from the human seat. Rules and complete hand lifecycle implemented: deal/refill, normal auction, legal moves, trick capture, scoring and match settlement. 96 tests pass, including 208 deterministic hands, a five-hand match and a mirrored strength benchmark against a frozen player. Match owns automatic scoring, summaries, dealer rotation and victory enforcement; terminal demo uses it. Versioned replay-based save/resume and atomic disk APIs are implemented; baseline computer players use restricted PlayerView, with 24 shuffled match simulations. SwiftUI table (`Sources/CatchFiveUI`) plays one human against three computers, shows each seat's auction call and the contract, and saves after every accepted action and on backgrounding. Build the simulator bundle with `scripts/build-simulator.py`.

## Architecture
Use Swift Testing and a dependency-free Swift package for rules. SwiftUI and a thin view model will consume it. Team 0 seats are 0/2, team 1 seats are 1/3; turns advance in ascending seat order modulo four.

## Aesthetic North Star
A readable, welcoming card table with large cards and understated controls. Final visual design awaits the playable engine.

## Living documentation
`docs/learning-path.md` indexes explainer pages (architecture, game-flow, types-and-functions, testing, decisions, build-and-run) with Mermaid diagrams. Any commit that adds, renames or removes a type, function, phase or test must update the matching page in the same commit, and new design choices get a numbered entry in `docs/decisions.md`. `scripts/export-docs.py` renders those pages to PDF and PNG in `work/docs-export/` for Claude Design.

## Verification
Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.

## Rules
The user's house rules in `docs/catch-five-rules.md` take precedence over published Pitch rules.
