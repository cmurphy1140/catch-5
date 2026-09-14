# Catch 5 — UI/UX Redesign Spec

## Current working agreement — 2026-09-12

**Source of truth:** this project file supplies requirement IDs; the [family-first UI/UX plan](docs/superpowers/plans/2026-09-05-iphone-16-ui-ux-gameplay.md) supplies current order, acceptance checks and progress. Both are tracked in this repository from September 13, 2026. Earlier Inbox convenience copies are not synchronized; use the Git copies.

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

No current Claude assignment is established by this agreement. Historical ownership and branch details are preserved in [the September 6 agreement](docs/history/2026-09-06-ui-working-agreement.md). Check active sessions before edits. Work sequentially by default; no automatic commit, push, agent launch, or worktree cleanup. Do not restart the completed three-task trial.

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

## Design principles driving these changes

1. **The table is the interface.** Chrome shrinks, cards and players grow.
2. **The app does not count for you.** Card counting is a skill of the game. Any tracking is an
   explicit beginner-mode affordance, never a default HUD element.
3. **Selection and commitment must be unambiguous.** Use one consistent interaction model in
   both modes. The proposed explicit-button-only refinement is deferred under D6.
4. **Progressive disclosure at the end of a hand.** One screen, collapsed by default, expandable
   for anyone who wants the detail.
5. **Protect what already works.** Keep large readable ranks and suits, cream cards against green
   felt, partner-across seating, a bottom-positioned hand, gold action emphasis, and the clear
   main-menu Continue game action with a saved-match summary.
6. **Actions must fit before decoration.** No available action or essential card information may
   be obscured to preserve empty felt, a fixed header, or a decorative stack.

---

## How to use this spec

| Group | Scope | Timing |
|---|---|---|
| A. Navigation and product structure | Three screens, pause menu, developer-learning entry | Core |
| B. Table clarity and layout | Visible actions, readable tricks, simple HUD, accessibility | Core |
| C. Decisions and controls | Card selection, discards, bidding, trump | Core |
| D. Assistance and results | Normal/beginner boundary, complete hints, compact outcomes | Core |
| E. Down the road ideas | Interaction experiments, visual/motion polish, teaching refinements | Deferred |
| F. Delivery and verification | Small implementation passes and practical checks | Working guide |

**Minimalism with pragmatism:** keep information visible when it helps the next decision. Put
supporting detail in an obvious place the player can open. Features can remain rich without all
being on the table at once. These requirements are constraints to satisfy together, not a list
of widgets to display simultaneously.

Deferred does not mean discarded. Preserve features that already work; do not build or expand
Group E merely because it is documented. Clipping, unreadable controls, misleading state, and
lost game state remain core correctness issues even when related polish is deferred.

---

## A. Navigation and product structure

**R31 — Keep three top-level screens; separate navigation from match state. High.**

```swift
enum GameScreen {
    case mainMenu
    case tutorial
    case gameplay
}
```

| Screen | Responsibility |
|---|---|
| `mainMenu` | Name, opponent difficulty, player selection, beginner-mode toggle, New match / Continue game, Settings, How to play, and How Catch 5 is built |
| `tutorial` | Optional five-step practice walkthrough of one hand, with Skip and Finish |
| `gameplay` | The live match and its bidding, trump, discard/draw, trick, and result phases |

These are conceptual destinations, not a mandated enum replacement. Existing onboarding routes
and tutorial sheets may remain. On the main menu, the approved visible layout is the title,
saved-player/match card, Beginner mode row, and game-action stack. Settings, Statistics, and
How Catch 5 is built live in the top-right hamburger dropdown; setup editing may remain in
Settings rather than adding more controls to this screen.

- Main-menu New match uses the selected setup. Offer the tutorial when appropriate; allow the
  player to skip it. Skip and Finish both start a fresh real match using that setup.
- Continue game restores the saved match directly, without tutorial or setup changes.
- If the tutorial is opened from an active match, preserve that match and return to it on Skip
  or Finish. Track the tutorial entry context explicitly; do not accidentally start a new match.
- Use isolated practice state for the tutorial so it cannot overwrite the real match or statistics.
- The tutorial teaches a practice hand; beginner mode supplies ongoing assistance in actual play.
  Neither requires the other to be enabled or completed.
- Keep the gameplay phase in authoritative engine state. Views derive their presentation from
  that state instead of maintaining a second independently mutable phase variable.
- Possible phases include bidding, choosing trump, discarding, drawing, playing a trick, hand
  results, and match results. Match the actual engine lifecycle; these are conceptual labels,
  not instructions to change game rules or force animation-only states into the engine.
- Settings, statistics, build explanations, and hand details may be sheets or overlays rather
  than additional top-level `GameScreen` cases. The pause menu is an overlay on gameplay.

**Acceptance:** Tutorial practice cannot mutate the live match. Skip/Finish honor their entry
context; Continue restores the saved match. Navigation and gameplay phases cannot drift apart.

**R32 — Replace “Welcome back” with a simple pause menu. High.**

Remove the Welcome back heading and automatic welcome popup. Show a pause overlay only when
requested during gameplay, using the existing menu control without adding a fourth HUD element.

| Pause action | Behavior |
|---|---|
| Continue | Dismiss the overlay and resume the current match exactly where it paused |
| New match | Ask before ending the current match; on confirmation, start a fresh match with the same setup |
| Main menu | Preserve the current match for Continue game, then return to the setup/main-menu screen |

- Keep exactly these three actions in the pause overlay. Continue is primary. Remove duplicate
  Settings, statistics, tutorial, and build-explanation actions from that overlay; provide those
  destinations through the main menu. Preserve R29's named build-explanation dropdown entry.
- Main menu is non-destructive. Editing setup there configures a future new match; it does not
  silently change the saved match's players or difficulty when Continue game is chosen.
- Starting New match from the main menu also requires confirmation if it replaces an unfinished
  match. Cancel leaves that match untouched; do not delete its save on merely opening setup.
- Pause gameplay progression while the overlay is open or the player visits the main menu or
  tutorial. Ensure pending AI actions or animation callbacks cannot advance or double-apply moves.
- On a fresh launch/relaunch, present the main menu with Continue game when a resumable match
  exists. Do not show the old Welcome back popup. Ordinary foregrounding of an already-open app
  need not reset navigation to the main menu.
- Keep any compact saved-match summary on the main menu; it is not needed in the pause overlay.

**Acceptance:** Continue preserves the match; Main menu followed by Continue game restores it;
New match Cancel preserves it; confirmed New match starts with the intended setup. No automatic
Welcome back popup remains, no AI move runs while paused, and the build explanation is reached
through Main menu → hamburger → How Catch 5 is built in both assistance modes.

### Developer learning

**R29 — Keep “How Catch 5 is built” accessible through the main-menu dropdown. Medium.**

The owner uses this app to improve their software-development skills. Revisiting how its parts
fit together and how features were built is an intentional part of the product's value.
The September 6 approved hamburger placement supersedes the earlier first-level-button
requirement. The destination remains directly named in the dropdown, not nested inside About.

- On the main menu, show “Continue game” as the primary action when a saved match exists, with
  a compact saved-match summary. Without a saved match, New match is primary.
- Keep “How Catch 5 is built” as the third entry in the top-right hamburger dropdown, after
  Settings and Statistics. Opening it takes two taps from the main menu: hamburger, then the
  named entry. Do not add a duplicate button to the main action stack or pause overlay.
- Keep How to play accessible for learning the rules. Use distinct labels for learning the game
  and learning its implementation; both serve a real purpose.
- Make the build explanation available in both normal and beginner mode. Gameplay assistance
  and software-development learning are independent preferences.
- Keep the entry and existing useful content in the core pass. The following content expansions
  are down-the-road refinements (see Group E.3), not prerequisites for the navigation changes.
- Preserve existing useful build content now. The following content improvements belong to the
  deferred R29 expansion in E.3, not the current navigation acceptance checks:
  organize it around a concise big-picture overview,
  with expandable detail so the owner can revisit the process without rereading everything.
- Explain how the actual game engine, state, SwiftUI views, AI decisions, persistence, and tests
  connect, where those components exist. Ground all architecture claims in the current repo.
- Trace one concrete interaction, such as selecting and confirming a card, through validation,
  state change, UI feedback, and saving. Explain why the responsibilities are separated.
- Include relevant design decisions and tradeoffs, plus how behavior is verified. Link to actual
  source files or documentation where practical; never invent implementation history or paths.
- Keep the overview current when the underlying architecture changes. Clearly distinguish
  implemented behavior from planned work. Use consistent action names across menus.

**Current navigation acceptance:** In either mode, hamburger → How Catch 5 is built opens the
existing content and dismissal returns to the preserved main menu. Continue game remains primary
when a saved match exists. The pause overlay contains only R32's three actions.

**Deferred content-expansion acceptance (E.3):** The reader can understand the architecture and
follow a real action through the software; the expanded explanation matches the code. Do not
make this expansion a prerequisite for finishing the approved menu.

---

## B. Table clarity and layout

### HUD and surfaces

**R1 — Reduce elements at the top of the screen.**
Target: no more than **three** persistent elements across the top safe area.

- Left: score chip (`Us 21 – Them 14`), tappable to open full scoring sheet.
- Center: current contract chip (`♠ 4 — You`), only present after bidding resolves.
- Right: settings / menu button.

Everything else currently pinned up top moves, collapses, or dies:

| Currently top-of-screen | Disposition |
|---|---|
| Trick counter | Fold into the contract chip, or show as pip row near the trick area |
| Turn indicator | Move to the table — highlight the active player's avatar instead |
| Round/hand label | Into the settings sheet or the score sheet, not the HUD |
| Deck / discard counts | **Delete** (see R20) |

**R20 — Remove all card-count displays.** No "cards left" badge on the deck, the discard pile, or
under any player avatar. Deck and discard communicate volume through the *visual thickness of the
stack* only.

**R4 — No automatic number tracking.** Remove any running tally of played suits, points taken per
suit, trump remaining, or "cards you've seen." If it exists in a view model, gate it behind the
beginner-mode flag (R14) rather than deleting the logic.

**R19 — No translucent borders/plates on icons.** The lightbulb (hint), settings gear, help, and any
other glyph render as the bare icon with a subtle shadow for contrast. Remove
`.background(.ultraThinMaterial)` / circle-fill-with-opacity wrappers. Keep the 44×44pt hit area —
just make it invisible.

**R16 — De-bubble the settings UI and back button.**
- Back button: chevron + label, no pill, no circle backing.
- Settings rows: flat list on a single grouped surface. No per-row capsule, no card-inside-a-card.
- One divider style, one row height, consistent left inset for icons.

**Acceptance:** Screenshot the table mid-hand. Count top-edge elements — must be ≤ 3. Search the
codebase for any label rendering a `count` of cards; zero results outside beginner mode.

### Seating and piles

**R2 — Readable player avatars within the established seating.**

- The latest direction is a modest increase while preserving partner-across seating. The current
  branch uses 68pt portraits (up from its 60pt baseline); verify that implementation for fit and
  readability. This supersedes the original 1.6–1.8× target and the later abandoned single-row
  enlargement experiment. Do not rearrange seats solely to satisfy those older size targets.
- Include name and, when relevant, bid badge attached to the avatar — not floating separately.
- Active-player state: gold ring + gentle scale-to-1.05 pulse. This replaces the deleted turn
  indicator from R1.
- Avatars must not collide with the trick area at the smallest supported device width. Lay out with
  a `GeometryReader`-driven proportional frame rather than fixed points if that's tight.

**R3 — Discard pile moves to the left.**

- Discard pile: leading edge, vertically centered-ish, clear of the player's hand.
- Deck (if visible): trailing edge, mirrored, or removed entirely if it carries no information.
- Both render as a small fanned/offset stack. No counts (R20). No labels if the shape reads clearly.
- Discarded cards animate *into* this position (R5), so its coordinates need to be resolvable via
  `matchedGeometryEffect` or an anchor preference.

**Acceptance:** On the smallest supported device, avatars, trick pile, discard stack, and a 6-card
hand all fit with no overlap and no clipping.

### Visibility, state clarity, and accessibility

**R21 — Keep every bidding and phase action visible. Critical.**

- The screenshots show the second bidding row almost entirely clipped above the hand. Repair the
  layout without changing the bidding structure or match-a-bid behavior (R12).
- Reserve space for the complete action area, selected-card lift, hand, and bottom safe area.
  Reclaim surplus table spacing before reducing card readability or action hit areas.
- Apply this rule to bidding, trump selection, discard confirmation, and card-play confirmation.
- Do not let a hand overlay intercept taps intended for an action above it.

**Acceptance:** On the smallest supported screen and supported text sizes, every bid, Pass, and
phase confirmation is readable and tappable. No row is hidden beneath the hand.

**R23 — Make every played card identifiable. High.**

- Give each seat a distinct position in the central trick. Preserve the four-player spatial mapping.
- Every played card's rank and suit must remain exposed. Overlap is acceptable only if it does not
  hide that information or make a card's owner ambiguous.
- Use a gold outline for the winner once determined. Keep review interactions reachable without
  obstructing the player's hand or the enlarged avatars (R2).

**Acceptance:** A screenshot of a full trick lets a reader identify all four cards and their owners
without opening a detail view. Validate with six cards still in the player's hand.

**R24 — Distinguish live play from reviewing a trick. High.**

- The screenshots combine a full trick, “Your turn,” and “Tap a card to see why it was played.”
  Use explicit state wording: “Reviewing last trick” with “Back to play” during review.
- In live play, retain the active-avatar treatment from R2. For the local player, use a clear
  highlight near their hand if there is no local avatar; do not add another persistent HUD item.
- Review taps inspect cards; play taps select cards. Never let an inspection commit a move.
- Leaving review restores the current live position. If review is available only in beginner mode,
  keep that gate; this requirement does not create a new review feature in normal mode.

**Acceptance:** In each state, the visible instruction accurately describes what tapping a card
will do. No live-turn prompt is displayed as the instruction for review.

**R25 — Allocate table space by phase. High.**

- The screenshots leave substantial open felt while bottom controls are crowded. Give the table,
  hand, and action area explicit space priorities for bidding, trump, discard, play, and review.
- Maintain stable seating and the larger avatar targets. Reclaim decorative/header space and
  surplus gaps first; do not shrink avatars as the default fix.
- A visible deck or discard stack should be identifiable through placement and animation (R3).
  If its meaning remains unclear, provide an accessible name and a short beginner explainer.
  Do not restore default numerical badges or add permanent labels when the shape reads clearly.

**Acceptance:** Each phase fits independently and transitions without collisions. Explainable
pile identity does not introduce automatic counting outside R14's allowed tray.

**R26 — Improve secondary text and unavailable-card feedback. Medium.**

- Increase contrast for muted text on felt and explanations on dark panels. Measure actual theme
  colors against the project's accessibility target rather than judging screenshot contrast alone.
- Preserve suit glyphs and ranks on unavailable cards. R15's 40% opacity is a starting treatment;
  adjust it if it makes the hand unreadable. Never use color alone to convey availability.
- Clarify R15: an illegal card is unavailable for selection or play, but remains tappable for a
  brief reason such as “Must follow suit.” Its feedback must never dispatch a game move.
- Bare icons retain R19's invisible 44×44pt hit area and meaningful accessibility labels. Verify
  VoiceOver identifies card, selection, availability, and the active player.
- With Reduce Motion enabled, replace the avatar pulse and error shake with static emphasis or a
  brief fade; keep the existing reduced-motion deal treatment.

**Acceptance:** Required text remains readable at supported text sizes, icon controls are named,
and an illegal-card tap explains the rule without selecting or playing it.

---

## C. Decisions and controls

### Selection and discard

**R15 — Tap-a-card in both normal and beginner mode.**
Single interaction model everywhere:

1. Tap a card → it lifts (~12–16pt translate up, slight scale, soft shadow) and is *selected*.
2. Tap again, or tap a confirm control → *played*.
3. Tap a different card → selection moves. Clear selection through the shared uncommitted-selection
   undo control (R14). Do not assign both play and deselect to the same second-tap gesture.

**Deferred alternative:** D6 proposes second tap to deselect and a labeled button as the only
commit path. Do not introduce that behavior change as part of this document reorganization.

Drag-to-play may remain as an alternative if it already exists, but tap must be a complete path
through every card decision in the game. Illegal cards: start with 40% opacity (subject to R26
readability), unavailable for play but tappable for rule feedback such as “Must follow suit.”

**R6 — Discard selection must not auto-select trump.**
Current behavior auto-includes trump in the discard set. Remove that entirely.

- The player taps exactly the cards they want to discard. Trump cards are selectable like any other.
- In beginner mode, if the player selects a trump card, show a **non-blocking** warning near the confirm button
  ("You're discarding 1 trump") — inform, don't prevent.
- Confirm button is disabled until the required count is selected, and reads
  `Discard 3` (live count), not a generic "Confirm."
- **R14 shared selection undo** applies in both modes: an undo control clears the last selection
  before commit.

**Acceptance:** Entering the discard phase with trump in hand produces **zero** pre-selected cards.

### Bidding and trump

**R12 — Keep the bidding UI structurally as-is**, including the ability to match a bid. Do not
redesign the control layout. Changes are additive polish only. Fixing the clipped second row is
required under R21: preserve the controls, order, and matching behavior while repairing their
container sizing and available space.



**R13 — Rearrange Choose Trump so the two red suits aren't adjacent in the middle.**
Order left-to-right: **♥ ♠ ♦ ♣** (red, black, red, black). This alternates colors and prevents the
♥/♦ confusion of a red-red center pair. Each option gets suit glyph + name label; selection state is
a gold ring, not a fill that obscures the glyph.

---

## D. Assistance and results

### Normal and beginner modes

**R14 — Same game, two levels of assistance.** A single setting controls guidance:
**“Beginner mode — hints and guided play.”** Off means normal playing mode. Keep opponent
difficulty as a separate setting; neither setting changes the other.

**Current scope:** the September 12 review verified the toggle and preference persistence on main. Full mode/difficulty and coaching-boundary verification remains pending. The table below retains broader targets; discard/tracking additions are outside the current Catch Five pass and adding a toggle does not complete R14.

| Normal mode | Beginner mode adds |
|---|---|
| Clean table, scores, contract, active player | Short explanations for each phase |
| Select a card, then confirm | Optional recommended card with “Why?” |
| Manual discard selection | Non-blocking warnings before discarding trump |
| No automatic card tracking | Your discard/draw history in a collapsible tray |
| Compact hand results and factual trick breakdowns | Optional strategy explanations and trick walkthroughs |

#### Shared behavior in both modes

- Use the same rules, seating, card controls, selection/confirmation flow, and scoring. Turning
  assistance off must not require learning a different interaction model.
- Readable cards, accessible controls, legal-move feedback, and explanations such as “Must follow
  suit” are basic usability and remain available in both modes.
- Players can change or clear an **uncommitted** selection in either mode. The explicit Undo
  selection control also works in both modes and is disabled when there is nothing to undo.
  It never reverts a played card, completed trick, placed bid, or committed discard.
- Keep factual results and expandable trick cards available in normal mode (R7–R10). Beginner
  mode adds coaching, not access to the basic record of the hand.
- Rules / How to play remain accessible from the menu in both modes.

#### Beginner-only assistance

- **Discarded & drawn cards panel:** a collapsed-by-default tray near the discard pile showing
  the player's own discards and replacement draws this hand. This is the only sanctioned live
  card-tracking surface under R4/R20. Do not expose opponents' hidden cards or discards.
- **Phase help:** a bare question-mark glyph opens a short explanation for bidding, trump
  selection, discard, or trick play. Follow R19's no-plate styling and accessible hit area.
- **Optional hints:** the lightbulb belongs to this same assistance system. On request, show a
  short suggested play with “Why?” for its complete explanation (R22). Do not auto-select or
  commit the suggested card.
- **Discard coaching:** show the non-blocking trump warning from R6 near the confirm control;
  the player can still choose any legal discard.
- **Strategy review:** add concise explanations and optional walkthroughs to the existing result
  structure. Keep recommendations distinct from rules and avoid treating strategy agreement as
  proof of correct play (R30). Coaching metrics appear only with assistance enabled.

Extra help appears when relevant or on request. Keep trays and detailed explanations collapsed
by default; beginner mode must not crowd the action area or hide cards.

#### Mode and difficulty behavior

- Persist the assistance preference independently from opponent difficulty.
- Support strong opponents with guidance and easy opponents with a clean normal-mode table.
- Switching assistance changes presentation only: preserve the current hand, scores, contract,
  opponent difficulty, and uncommitted selection. Close any beginner-only panel when disabling it.
- When beginner mode is off, remove its hints, tracking tray, coaching warnings, and strategy
  explanations from the view tree. Shared selection controls and factual results stay available.

**Acceptance:** Verify both modes with each supported opponent difficulty. The same legal move
uses the same selection/confirmation steps in both. Normal mode has no coaching or automatic
tracking; beginner panels never clip required actions. Switching modes preserves game state.

### Complete hints

**R22 — Give hints a complete, bounded presentation. High.**

- The visible hint ends mid-sentence. Show one complete short recommendation inline; open the full
  explanation using an explicit expansion control or help sheet.
- The expanded explanation scrolls if needed and never pushes required actions off-screen.
- Gate coaching hints behind beginner mode (R14). A rule explanation for an unavailable action is
  basic interaction feedback and remains available in normal mode.

**Acceptance:** Long explanations remain fully accessible without clipped sentences; the player
can dismiss help and return to the same uncommitted selection.

### End-of-hand results

**R9 — One screen.** The hand review and the "contract made" screen merge into a single
`HandResultView`. There is no longer a two-step sequence.

**R7 — The hand review shortens and becomes a dropdown**, not a full-screen list of every trick.

**R10 — Structured as collapsible rows.** Default state: everything collapsed. Summary line always
visible at the top:

```
CONTRACT MADE  ·  Us  4♠ bid 4, made 5

▸ Us — 5 points
▸ Them — 1 point
▸ Bid — 4 ♠ by You
▸ Hand points — 6 total
▸ Tricks (6)
```

- Rows expand in place with a spring, chevron rotates.
- Team names use actual team labels, never "Team 1 / Team 2" placeholders.
- **R8 — Each trick is its own expandable row** inside the Tricks section: collapsed shows
  `Trick 3 — Won by Sarah (+2)`; expanded shows the four cards played in order with the winning
  card ringed in gold.
- Keep nesting to **two levels max** (section → trick). Do not nest a third dropdown inside a trick.

**R11 — Large "Deal Next Hand" button.**
Pinned to the bottom, full width minus 20pt insets, ~56–60pt tall, gold fill, serif label. Always
visible — it does not scroll away as sections expand. The results content scrolls behind it with
bottom padding equal to the button's height plus the safe area.

**R17 — Scoring totals show team names and scores clearly.**
Two-column layout, team name left / score right, large tabular figures (`.monospacedDigit()` so
numbers don't jitter when they change). Leading team's row is emphasized in gold. Applies to both
the results screen total and the score sheet opened from the HUD chip.

### Clear wording and honest feedback

**R30 — Use clear copy and honest coaching metrics. Medium.**

- Replace “Your bid · high bid none” with “Your bid · No bids yet.” Use short phase instructions
  near the action area, consistent with R1's reduced HUD.
- Follow R13's suit order and suit-name labels. Remove “keep N” from the normal trump selector
  under R4/R20; any beginner explanation of retained cards belongs in R14's sanctioned tray.
- Rename “Played the strategy's card” to “Matched suggested plays.” Explain that agreement with
  the reference strategy is not a measure of optimal play or a verdict that alternatives were wrong.
- Keep this metric secondary to results, and show the comparison denominator when available.
- In hand explanations, distinguish a legal alternative from a prohibited move. Replace internal
  wording such as “the strategy would have” with a direct suggestion and its short reason.

**Acceptance:** No coaching percentage is presented as an accuracy grade. Suit labels, bid status,
and review wording are understandable without knowledge of the implementation.

---

## E. Down the road ideas — deferred, not current-pass requirements

Revisit these after the core flow works comfortably. Implement only the subset chosen for a
later pass. Keep existing useful behavior; do not remove working polish to match this schedule.

### E.1 Interaction refinements

**D1 — Keep the hand steady.**
When hints, bid controls, or status messages appear, avoid unexpected movement of cards under
the player's thumb. Reserve space or use bounded help surfaces. Normal dealing, drawing, and
re-fanning after a card leaves can still move cards intentionally.

Future check: open and close hints during selection; confirm the selected card and its touch
position remain predictable. This extends R21/R25; fixing currently hidden controls remains core.

**D2 — Distinguish selected from recommended.**
Lift the player's selected card; use a separate subtle marker for a beginner recommendation.
Give each state an accessible description and avoid relying only on color. A suggested card
must never look already chosen or auto-commit a move.

Future check: request a hint while a different card is selected; both states remain understandable.

**D3 — Give each decision one obvious next action.**
Use specific confirmation labels such as “Play J♠,” “Discard 3,” and “Deal next hand.” Keep
secondary choices available without competing with the next action. This generalizes the
existing discard and results labels; it does not add another control wherever one already exists.

Future check: each phase can answer “What will this button do?” without additional instructions.

**D6 — Explore a simpler select/deselect/confirm model.**
Proposed replacement for R15's second-tap-to-play behavior:

1. Tap a legal card to select and lift it.
2. Tap the selected card again to deselect it.
3. Tap another card to change selection; in discard, toggle membership in the discard set.
4. Commit only with the labeled Play or Discard button.

This is an interaction experiment for a later pass, not an instruction to implement now. If
adopted, update R15, the shared-mode behavior, and any drag gesture together. A drag must not
silently bypass explicit confirmation. Never support second-tap play and second-tap deselection
at the same time. Validate convenience and accidental-move frequency before choosing the model.

### E.2 Feedback and motion

**D4 — Briefly explain consequences.**
Use short outcome messages such as “Otto won the trick” or “Contract missed · −4,” using the
actual engine result and score change. Reuse the existing status area rather than adding a
permanent HUD label. Keep the factual outcome available in results after the message disappears.

Future check: messages clarify what happened without blocking play or requiring a review screen.

The following earlier motion requirements retain their IDs, but new animation work is deferred.
Build against settled geometry, respect Reduce Motion, and do not delay core usability fixes.

**R18 — Add bidding animations.**

- Bid value change: number rolls/counts rather than hard-cutting.
- Bid committed: a chip flies from the bidding control to the bidder's avatar and settles there,
  staying visible as the bid badge.
- Pass: avatar's badge fades in as a muted "Pass" then dims the avatar slightly.
- Winning bid: brief gold pulse on the winner's avatar before transitioning to trump selection.
- Keep all of these ≤ 350ms. Bidding is a rhythm — don't add drag to it.

**R5 — Dealing and discard animations.**

*Opening deal:*
- Cards fly one at a time from the deck position to each player in seat order.
- ~60–80ms stagger per card, ~250ms per card flight, spring easing.
- Opponent cards land face-down; player's cards flip face-up on arrival, or fan up together at the end.
- Full deal completes in roughly 1.5–2.0s. **Must be skippable** — any tap fast-forwards to the
  final state. Non-negotiable: this animation plays every hand, so it can never feel like a wall.

*Discard:*
- Selected cards fly from the hand to the discard pile position (R3), staggered ~50ms.
- Hand closes the gap and re-fans after the last card leaves.

*Replacement draw:*
- New cards fly from deck to hand, reusing the deal animation timing.

Implementation notes: prefer `matchedGeometryEffect` between hand and pile namespaces over manual
offset math. Respect `@Environment(\.accessibilityReduceMotion)` — when on, cross-fade instead of
fly, keeping the same durations so game logic timing is unaffected.

### E.3 Reading, teaching, and developer-learning refinements

The following earlier refinements are retained for a later pass. Core readable text and complete
hint access remain required under R22/R26; a broader visual or editorial redesign can wait.

**R27 — Shorten teaching and use consistent player names. Medium.**

- Present one immediate lesson instruction or decision at a time. Put supporting rules and tactics
  behind an expansion control instead of requiring a long read before the first interaction.
- Use the same player names as the table: “Rue is dealing. Tap the player who receives cards first.”
  If compass directions matter to the lesson, introduce “Rue (East)” explicitly before using East.
- Keep lesson progress and navigation discoverable; long lesson tabs must scroll without trapping
  the reader or concealing the current lesson.
- In results, follow R7–R10's collapsed structure. Within an expanded trick, show cards and outcome
  first, then a concise explanation. Avoid a third disclosure level.

**Acceptance:** The learner can identify the next action and referenced player without translating
between unexplained names/directions or reading a long introductory block.

**R28 — Unify reading surfaces and typography. Medium.**

- Preserve green felt, ivory cards, muted gold, and serif titles. Keep wood as table framing;
  reduce its visual prominence behind tutorials, statistics, and results using quiet opaque surfaces.
- Define shared typography roles, panel colors, spacing, dividers, and control styles. Serif titles
  and sans-serif body text can coexist deliberately; avoid unrelated screen-by-screen treatments.
- Apply R16's flat grouped rows instead of adding nested cards or capsule backings. This is a
  readability refinement within the existing identity, not a new visual theme.

**Acceptance:** Compare table, tutorial, statistics, and results side by side. Shared roles look
consistent and wood texture does not compete with body text.

**R29 expansion — revisit the build process.** Keep the main-menu entry and existing content
now. Later, expand its architecture overview, a real card-action walkthrough, design tradeoffs,
verification examples, and source references as described in R29. Keep details collapsible and
repo-grounded so learning stays useful without adding clutter to gameplay.

### E.4 Lightweight usability observation

**D5 — Watch a new player use it without coaching.**
Ask someone unfamiliar with the app to start a match, make a bid, play a card, leave, and resume
the saved match. Observe before explaining. Note hesitation, wrong taps, missed controls, and
places where they misunderstand the next action; choose the next refinement from those findings.

A short session is enough to identify candidates. Do not present a single person's experience
as proof that the design works for everyone. Any discovered blocking usability bug moves back
to core fixes; optional polish stays in this group.

---

### E.5 Pinned by Connor, September 13, 2026

Ideas Connor wants kept, not scheduled. No requirement IDs; they earn one when chosen.

- **Opponent personalities.** Hazel, Otto and Rue each get a bidding temperament and a line or two of table talk, drawn only from public events the way the existing moods are (D-numbered mood decision). No hidden-card knowledge, no new rules.
- **Moments worth a small fuss.** Making 9-and-out; catching the Five off the bidder; setting the bidder; winning Game by one card value. A single restrained cue each, within the one-haptic policy, never a modal.

### E.6 Pinned by Connor, September 14, 2026

- **A loading screen.** The app currently has a native launch screen showing the icon. This is the
  idea of a proper one with something to look at while the table is set: cards being shuffled, the
  box opening, the felt unrolling. It must not add a wait that is not already there; an artificial
  delay to show off an animation is the opposite of the point.
- **Talking strategy with your partner.** A way, between hands, to tell your partner how you want
  them to play: lead trumps early, save the Five for me, bid more boldly, stop overtaking me.
  Standing instructions, not table talk during a hand, which at a real table is cheating. Each
  instruction would become a modifier on that seat's scoring in `ComputerPlayer`, applied to the
  partner only. It teaches the game's strategy vocabulary by letting a player use it, gives Otto a
  character you can argue with, and reuses the same terms the bot bank (D58) is already tuning.
  Open questions: whether instructions persist across matches, whether opponents may be instructed
  (they may not), and whether the partner may refuse.
- **A different view from the table** was raised and dropped the same day as overkill. Recorded so
  it is not proposed again without a reason.

### E.7 Counting at the table, pinned September 14, 2026

Two ideas from Connor about the information a real Catch 5 table shares out loud. They belong
together: the first supplies the numbers, the second gives the player somewhere to keep them.

- **Every seat announces how many cards it discards.** Once trump is named each player discards
  their non-trumps and draws back to six, so the count they announce says how many trumps they
  held. At a real table this is said aloud and everyone uses it: whether the bidder is strong or
  bluffing, whether leading trumps helps your partner or the other side, and whether the Five can
  be sneaked. The app currently shows only the human's own count, and the engine pools every
  discard into one pile with no record of who threw what, so the computer plays blind to
  information every person at the table has. Engine side first: record the counts, carry them in
  `PlayerView`, teach the strategy to read them. Then the table announces each one.
- **A trump counter the player increments themselves.** A place to keep a tally of trumps played,
  which the app never advances on its own. This does not conflict with R4 (no automatic number
  tracking) or R20 (no card-count displays): counting stays the player's skill, and the app only
  offers somewhere to write it down, the way a notepad differs from a calculator. Open questions:
  whether it resets each hand automatically, whether it can be corrected downward, and whether it
  appears at all outside beginner mode.

## F. Delivery and verification

### F.1 Agreed boundaries and routine implementation choices

- **Tracking:** R14's beginner tray is the only live automatic card-tracking surface. Factual
  end-of-hand results remain in both modes; hidden opponent information stays hidden.
- **Undo:** the current engine-backed replay Undo and one-tap play differ from the selection-only target. Preserve them during unrelated changes; resolve the interaction choice in the selected touch task under the current agreement.
- **Navigation:** R31/R32 define the destinations and pause actions. R29 remains a named entry
  in the main-menu hamburger dropdown in both modes. Preserve existing working routing.
- **Selection:** R15 is a target, not verified main behavior. Follow the current agreement before changing commitment; D6 is not automatically activated.
- **Deck:** retain it where it communicates dealing/drawing or table state. Remove a purely
  decorative idle stack if needed for fit; do not restore numerical counts.
- **Trick progress:** use the compact contract chip or nearby pips under R1; do not silently
  drop useful progress information or add another top-level HUD element.
- **Animations:** if adding R5 later, include skip and reduced-motion behavior in that same pass.

### F.2 Core delivery order

The numbered passes below preserve the original backlog grouping, not the current execution order or a completion ledger. The September 12 family-first plan linked at the top controls sequencing. Inspect each item against the newer main implementation before choosing changes; do not restart the old passes.

| Pass | Goal | Requirements |
|---|---|---|
| 1 | Repair clipping, unreadable tricks, and ambiguous live/review state | R21, R22, R23, R24, R26 |
| 2 | Simplify the table and fit every phase | R1, R2, R3, R4, R12, R13, R16, R19, R20, R25 |
| 3 | Make navigation and decisions consistent | R6, R15, R31, R32; R29 entry and existing content |
| 4 | Consolidate factual results | R7, R8, R9, R10, R11, R17; R30 copy |
| 5 | Complete normal/beginner separation | R14; integrate R22/R30; verify both modes |

Finish the agreed current pass and verify its behavior before broadening scope. A partial item
from another numbered group does not complete that group. Recheck table fit when beginner panels
are added. Preserve the rules and authoritative engine behavior throughout the UI work.

**Later, selectively:** Group E covers R5, R18, R27, R28, R29 content expansion, and D1–D6.
Do not automatically append all of these to the core implementation task.

### F.3 Core acceptance checks

- Capture bidding with all rows, trump selection, discard selection, a full trick, live play,
  trick review, a long hint, expanded/collapsed results, tutorial, statistics, main menu, and pause.
- Check the smallest supported screen, supported text sizes, beginner mode on/off, and Reduce
  Motion. Use interaction checks for commitment and VoiceOver; screenshots alone cannot prove them.
- Verify tutorial Skip/Finish from setup and from a preserved match; pause Continue; Main menu
  then Continue game; New match confirm/cancel; fresh launch with and without a saved match.
- Check that normal mode has no coaching or live automatic tracking, both modes retain basic
  usability, difficulty remains independent, and the build explainer stays accessible.
- Stop after core acceptance succeeds. Use Group E's future checks only when taking on that
  refinement or resolving an observed problem.
