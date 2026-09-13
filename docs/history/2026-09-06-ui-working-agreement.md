# Historical UI working agreement

Preserved September 12 before replacing the current agreement. Ownership, branches and verification status below are historical; use the [current spec](../../catch5-ui-redesign-spec.md).

## Current working agreement — 2026-09-06

**Source of truth:** `/Users/connormurphy/Desktop/Projects/catch-5/catch5-ui-redesign-spec.md`.
`/Users/connormurphy/Desktop/Inbox/catch5-ui-redesign-spec.md` is a convenience copy, synchronized
with this revision. Edit the project file first and explicitly refresh the convenience copy;
there is no automatic synchronization. This file is currently uncommitted and absent from
Claude's linked worktree. Read it at the absolute source path; a branch switch does not carry it.

**Decision order:** Connor's latest explicit decisions take precedence over older requirements.
Reconcile the matching requirement when a decision changes. The requirements below describe
the intended product; only the bounded current pass is assigned now. A proposed enum or layout
technique is illustrative, not a requirement to rewrite working architecture.

### Approved direction

- Keep the main-menu layout Connor approved in the September 6, 10:46–10:47 screenshots:
  centered Catch 5 title, saved-player/match card, Beginner mode row, and the existing action stack.
- Keep the bare hamburger in its current top-right position. Its dropdown contains Settings,
  Statistics, and How Catch 5 is built, in that order. Do not add a visible Menu label or move
  the title into a new header row. Keep the accessible Menu label and invisible hit area.
- Continue game is the gold primary action for a resumable match; New match and How to play
  remain below it. Keep the current green, ivory, and gold identity.
- Retain partner-across seating. Follow the latest modest avatar enlargement rather than
  restarting the abandoned large, single-row seating experiment to meet an old multiplier.
- Returning-player launch to the main menu and the three-action pause overlay are already
  decided under R32. They do not need to be reopened as product decisions.

### Current pass and evidence

Snapshot: Claude's `fix/bigger-seats-and-header` branch at `440adb7`, following `54c7530`,
based on merged PR #39 (`f63b63d`). This is a dated snapshot, not a live branch monitor.

| Area | Status | Evidence / remaining check |
|---|---|---|
| Main-menu composition and hamburger location | Visually approved by Connor | Supplied screenshots; dropdown destinations still need interaction verification |
| Earlier layout and menu work | Merged baseline | PR #39; merge status does not establish every acceptance criterion for passes 1–2 |
| Three-element gameplay header, modest avatars, pause and returning-player launch | Implemented; awaiting acceptance verification | Commit `54c7530`; preserve the current geometry while checking fit and navigation |
| Beginner toggle and initial coaching visibility | Partially implemented; awaiting acceptance verification | Commit `440adb7`; this is a first cut of R14, not completion of its tracking tray, warnings, or all mode behavior |
| Other core requirements | Backlog; implementation status not fully audited | Keep the detailed requirements below; do not assume they are missing or complete |

**Finish this pass:** verify the three dropdown destinations; toggle beginner mode both ways
and check persistence, unchanged difficulty and match state; check bidding/trump/play fit and
basic legal-move feedback in both modes; exercise pause Continue, Main menu → Continue game,
New match cancel/confirm, and returning-player relaunch. Preserve existing first-run onboarding;
check its regression behavior without redesigning it. Use the existing automated checks and
record the build/commit, device/text setting, result, and any checks not run. Screenshots establish
appearance only. Coordinate simulator/build use between sessions.

Claude owns the current app-code edits; Codex owns this spec reconciliation. Fix observed
regressions within this pass, then review the result with Connor. Do not expand into the full
R14 tray/coaching system, results redesign, new selection behavior, or Group E during this pass.
Document existing implementation changes as required by the project; docs work does not open
another feature pass. Existing commit, push, and merge authorization rules still apply.

### Next and deferred

- **Next:** review this pass, record verified outcomes, then choose one bounded item from the
  remaining core backlog in F.2. Inspect existing behavior before deciding what needs work.
- **Deferred:** Group E, including D1–D6, new motion work, reading-surface redesign, and build
  explanation expansion. Preserve useful existing behavior; do not automatically implement these.
- **Completion:** “implemented” means code exists; “verified” requires named checks and results;
  “approved” records Connor's design decision. Keep these separate when updating this summary.

**Handoff to Claude:** Read this current working agreement and the reconciled R2, R29, R31,
R32, and F.2 at the source path above before continuing. Keep the approved menu and current
branch ownership. Finish the listed checks and any resulting fixes, report remaining gaps,
and stop before starting another redesign pass. This handoff does not request a new branch,
architecture rewrite, commit, push, or merge.

