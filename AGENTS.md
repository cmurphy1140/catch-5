# Catch 5

## The two repositories

Do not confuse these, and do not merge one into the other by hand:

- **catch-5** (this repository, `~/Desktop/Projects/catch-5`) is the single-game subset. Catch 5 UI and gameplay polish happens here first.
- **plug-and-pitch** (`~/Desktop/Projects/plug-and-pitch`, `git@github.com:cmurphy1140/plug-and-pitch.git`) is the multi-preset app, where a versioned rule set makes a variant a preset rather than a rewrite.

Sequence, decided September 13, 2026: finish Catch 5 here first. Finished means the six increments of the [family-first plan](docs/superpowers/plans/2026-09-05-iphone-16-ui-ux-gameplay.md) are implemented, verified and accepted by Connor. Only then is this repository's `main` ingested into plug-and-pitch in one deliberate pass, and new product work moves there. Work flows that way only; plug-and-pitch is not a branch to merge back. It sits on an older Catch 5 base (`c2172db` plus PRs through #38) than this repository's `main`, so check both before assuming a feature is missing.

## Current Status
As of September 13, 2026 the active goal is family enjoyment through bounded native Catch Five UI/UX refinement, before distribution or spending. Use the [current plan](docs/superpowers/plans/2026-09-05-iphone-16-ui-ux-gameplay.md) for order, acceptance checks and progress, and the [requirement spec](catch5-ui-redesign-spec.md) for requirement identifiers. The plan's progress table (section 8) is the one progress record. No increment has started.

`main` contains the solo game, cast, Easy/Standard, local save/resume, hints, review, tutorial, returning-player main menu, pause overlay and start-over alert (PRs through #41). The September 12 iPhone 16/iOS 18.6 simulator review of `131c941` (the code of PR #41) exercised navigation and one full hand; its build and four final UI probes passed. Full current rules-suite, accessibility, all-size and physical-device claims require their own checks. Use actual test output rather than a repeated historic count.

Implement from `main` or a short-lived branch off it. The `claude/dealer-draw` branch is historical: its source predates PRs #39–#41 and must not be merged; its documents were carried onto this branch on September 13.

## Architecture
Swift Testing and a dependency-free Swift package for rules (`Sources/CatchFive`); `GameModel` and SwiftUI views consume it (`Sources/CatchFiveUI`). Team 0 seats are 0/2, team 1 seats are 1/3; turns advance in ascending seat order modulo four. Computers and hints see only a `PlayerView`.

## Project scope
Catch Five takes UI/UX refinement and bounded reliability fixes needed for its existing player journey. Preserve house rules, engine/save boundaries, approved main-menu geometry and current artwork. Plug & Pitch remains the longer-term customizable-Pitch direction; its preset, discard, branding and architecture work is deferred. No App Store/TestFlight work, hosting, membership, paid services, new spending or multiplayer in the family UI plan.

Connor is the player, designer and engineering collaborator. Use sketch → inspect together → small change → play → verify. Offer one meaningful decision when needed; routine authorized work does not need repeated permission. Observe family use informally, without surveys or scorecards. Keep future ideas in the existing backlog. State observed behavior, proposed design and unverified checks separately.

Check the actual host and available files when Connor is on his phone; controlling this Mac is different from a cloud checkout. These local instructions do not automatically synchronize to other checkouts or apps. Commits require explicit Catch Five authorization. No push or new-session launch unless requested.

## Session coordination

Codex is no longer used; mentions of it in historical documents describe their own time. Connor runs a separate planning chat as the **coordinator** and Claude Code sessions as **writers**: one writer session by default, and a second on the engine side whenever Connor opens one. The working rules, the copy-ready prompts and the session log live in [docs/working-together.md](docs/working-together.md); edit that file freely, this one rarely.

1. **The coordinator owns the plans and these instructions.** Writers implement one bounded task each. A writer edits the plan only to record its own task's status in the progress table, and does not rewrite `AGENTS.md`.
2. **Two tracks, split by module, used when a second session exists.** The **UI writer** owns `Sources/CatchFiveUI/`, `App/` and `Tests/CatchFiveUITests/`. The **game-logic writer** owns `Sources/CatchFive/`, `Sources/CatchFiveDemo/` and `Tests/CatchFiveTests/`. Neither edits the other's files. A change that needs both sides is split into two tasks, the engine side lands first, and the interface between them (a type or function signature) is agreed through the coordinator before either starts. The UI writer uses the main checkout `~/Desktop/Projects/catch-5`; the game-logic writer uses a worktree under `~/Developer/active/catch-5-worktrees/<track>/` (Desktop is iCloud-synced, verified September 13, so worktrees stay out of it). Each works on its own branch off `main`. Shared files (`docs/`, `Package.swift`, `project.yml`, the plan, this file) are coordinator-owned; a writer touches a docs page only in the section that describes its own module, and PRs merge one at a time. Worktrees do not isolate the simulator, saves or the Mac's CPU.
3. **Inspect before changing Git state.** Read the plan's progress table and the working-tree status. Never blindly pull, reset or switch branches with uncommitted work. The `claude/dealer-draw` branch is historical and must not be merged.
4. **One verification turn on the Mac at a time.** Run exports, tests, builds and simulator checks sequentially. The two writers agree who verifies when, and hand the turn over when finished. Do not stop another session's jobs to make room.
5. **Own simulator per writer.** Existing devices: `Catch 5 Wood` (`AF208C60-6B4E-47A9-9AD5-5D6CAE18F5C7`), `Catch 5 iPhone` (`02419047-584C-4D69-A0F1-6F33C2C5F0F2`), `Catch 5 UX Review` (`F6996C6A-3025-4CFD-86BA-447A178DBD32`), `Catch 5 SE` (`3C3E458E-165F-400E-8FC6-90B1753FE1D2`). Take one, name it in your handoff, shut it down when idle. Physical-device installs need task authorization.
6. **Finish locally; publish deliberately.** Verify, report what passed and what was skipped, and leave the work reviewable. Commits require explicit authorization; push and PR actions need it too. One independent PR at a time.
7. **Handoffs are small and current.** A writer ends by stating base commit, branch, changed files, checks run, unresolved issues and the next concrete action, and updates its row in the plan's progress table. The coordinator folds that into the shared plan.

## Aesthetic North Star
A readable, welcoming card table: felt in play, drawn oak (grain running across the screen, no image) for the frown-shaped header band and the reading sheets, ivory cards, green card backs, gold accents, seats with no fill, solid dark pills for the auction, one solid gold button per screen. Text runs large.

## Living documentation
`docs/learning-path.md` indexes the explainer pages (build-and-run, architecture, game-flow, types-and-functions, testing, decisions, code-map, roadmap, tutorial-spec, device-install) with Mermaid diagrams. Any commit that adds, renames or removes a type, function, phase or test must update the matching page in the same commit, and new design choices get a numbered entry in `docs/decisions.md`. `scripts/export-docs.py` renders the pages to PDF and PNG in `work/docs-export/` for Claude Design.

## Verification
Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.

## Local resource coordination
Before running builds, tests, simulator launches, screenshots, or Xcode previews, check whether the other writer is already performing a resource-heavy operation, and take the verification turn described above. Pause Xcode previews when they are not needed, and stop simulator or build processes started for the task when they are no longer required.

## Execution default
Within the authorization rules above (commits, pushes and PRs still need an explicit request), when the user proposes or requests a concrete task that can be completed safely and reversibly, perform it instead of stopping at a plan or asking whether to proceed. If an action genuinely requires user approval, complete all safe preparation first and then use the app's native approval or option prompt when available. Ask in ordinary chat only when the required approval cannot be presented through the app.

## Rules
The user's house rules in `docs/catch-five-rules.md` take precedence over published Pitch rules.

## Completed workflow trial
The three-task trial is complete (3/3) in the ignored local `notes/claude-workflow-trial.md`; do not restart it or add entries. Reusable lesson: verify changing facts against current source and evidence before repeating them. Maintain the current plan/spec at meaningful checkpoints; record checks actually run and limitations. The ignored trial/review notes do not automatically transfer to another checkout.
