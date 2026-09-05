# CardGame.io

## Current Status
Greenfield SwiftUI iOS app. Rules and complete hand lifecycle implemented: deal/refill, normal auction, legal moves, trick capture, scoring and match settlement. 55 tests pass, including 208 deterministic hands and a five-hand match. Match owns automatic scoring, summaries, dealer rotation and victory enforcement; terminal demo uses it. Versioned replay-based save/resume and atomic disk APIs are implemented; baseline computer players use restricted PlayerView, with 24 shuffled match simulations. SwiftUI table (`Sources/CatchFiveUI`) plays one human against three computers, shows each seat's auction call and the contract, and saves after every accepted action and on backgrounding. Build the simulator bundle with `scripts/build-simulator.py`.

## Architecture
Use Swift Testing and a dependency-free Swift package for rules. SwiftUI and a thin view model will consume it. Team 0 seats are 0/2, team 1 seats are 1/3; turns advance in ascending seat order modulo four.

## Aesthetic North Star
A readable, welcoming card table with large cards and understated controls. Final visual design awaits the playable engine.

## Verification
Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.

## Rules
The user's house rules in `docs/catch-five-rules.md` take precedence over published Pitch rules.
