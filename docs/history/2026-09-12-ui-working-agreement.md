# UI working agreement, September 12, 2026

Preserved September 14 when the requirements spec was split into a spec, an ideas file and this
record. Its evidence and delivery order are of its date. Current order and progress live in the
[family-first plan](../superpowers/plans/2026-09-05-iphone-16-ui-ux-gameplay.md); the requirements it
refers to are in [the spec](../../catch5-ui-redesign-spec.md).

## Current working agreement — 2026-09-12

**Source of truth:** this project file supplies requirement IDs; the [family-first UI/UX plan](../superpowers/plans/2026-09-05-iphone-16-ui-ux-gameplay.md) supplies current order, acceptance checks and progress. Both are tracked in this repository from September 13, 2026. Earlier Inbox convenience copies are not synchronized; use the Git copies.

**Accepted product direction:** concentrate on the native Catch Five UI/UX and family enjoyment. Preserve the current identity and single-player game. Plug & Pitch's configurable-game ambition remains future work; its existing two-preset plan is not implemented or active here. Defer paid developer membership, distribution, App Store work, hosting and new spending. This session authorizes planning only.

### Preserve the approved foundation

- Keep the approved main-menu title, saved-match card, Beginner row and action stack. Keep the bare hamburger top-right with its accessible Menu label, Settings, Statistics and How Catch 5 is built. No visible Menu label or replacement header by default.
- Continue is primary for a saved match. Preserve partner-across seating, the modest existing portrait scale, felt, oak, ivory cards, restrained gold and large readable text.
- Preserve engine rules, automatic Catch Five non-trump replacement, replay saves, Easy/Standard, and hidden-card boundaries. No manual-discard phase, rule builder, new counting tray or architecture rewrite in this pass.

### Evidence and remaining work

September 12 review used main `131c941b4301069574abe87a5196044d12ca1343` in an isolated iPhone 16/iOS 18.6 simulator. Profile/intro, tutorial navigation, menu destinations, pause/resume, Beginner preference persistence, New match Cancel, 9-and-out Cancel, and one full hand/result/review worked. A build and four final UI probes passed. Full rules tests, all interruption cases, full match outcomes, complete accessibility and real-device feedback were not certified by that review.

Main contains later pause/layout/outcome/validation work absent from old diagnoses. Inspect before repairing. First-lesson reading load, cramped beginner trump captions and table-menu icon meaning remain observed UX opportunities. Main already hides visible keep counts in normal mode. An animation-time result screenshot was rechecked after settling and is not a persistent layout bug.

### Current delivery order and decision boundaries

Use the execution plan: reconcile the dirty checkout → ordinary-turn clarity → compact factual results → optional hands-on learning → deliberate touch/continuity → accessibility/feedback → family observation. Any reproduced data-loss or action-correctness defect moves ahead of polish. First proposed visible change is beginner trump-caption readability only; the whole backlog is not assigned for implementation.

R15/F.1's selection-only Undo target conflicts with main's one-tap play and replay Undo and with the older plan. Preserve current behavior during unrelated UI work. Resolve this once with Connor using concrete tap sequences when that task is selected; do not silently remove working Undo. Manual-discard requirements apply only where the game's actual rules support them and do not activate Plug & Pitch features.

R27 teaching and D5 lightweight observation are selected candidates for this roadmap; other Group E ideas remain deferred. R7–R11 compact results remain a target, not a claim that current scoring is broken. Normal-mode shared facts stay available; assistance/difficulty remain independent. The uncommitted spec's detailed targets are not proof of implementation.

No current Claude assignment is established by this agreement. Historical ownership and branch details are preserved in [the September 6 agreement](2026-09-06-ui-working-agreement.md). Check active sessions before edits. Work sequentially by default; no automatic commit, push, agent launch, or worktree cleanup. Do not restart the completed three-task trial.

---

<!-- Future reference only — not implementation requirements:
Replayability: Ask what makes someone want another round. Prioritize satisfying decisions, meaningful variation, and visible improvement before adding rewards or features.
Framework choice: SwiftUI for interface work, SpriteKit for 2D simulation, RealityKit for 3D/AR. They can coexist through shared app state, but keep separate scenes/physics. Combine only when each has a clear purpose; no framework migration is proposed for Catch 5.
-->

Scope: SwiftUI iOS app. This document is written to be handed to Claude Code as a working spec.
Existing requirements keep their `R1`–`R32` identifiers. Future ideas use `D1`–`D6`.
This is one grouped working document, not a request to implement everything at once.
Use the current working agreement above for today's scope; F.2 retains the remaining delivery
order. Keep deferred ideas out of the current pass.

Visual identity is **unchanged**: dark green table, cream/ivory cards, muted gold accents, serif
titles. This is a layout, interaction, and motion pass — not a re-skin.

Revision: September 6 working agreement reconciles the approved menu, avatar direction, current
branch scope, and verification status. Earlier screenshot review remains below. R1–R20 retain their
identifiers; R21–R30 add usability fixes and acceptance criteria. R31–R32 define the
three-screen navigation and simplified pause menu. Latest explicit decisions supersede older
directions; preserve bidding structure, remove default card counts, retain the agreed seating
and modest avatar increase, and preserve the card-room identity.

Evidence boundary: clipping, overlapping cards, and wording are visible in the screenshots.
Touch accuracy, animation quality, responsiveness, VoiceOver, and measured contrast still need
on-device or simulator verification; this document does not claim those checks have passed.

---
