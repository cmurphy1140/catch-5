# Catch 5 — UI/UX requirements

The numbered requirements for the app's screens. **R1–R32 are the identifiers**; other documents
refer to them by number, so they do not get renumbered.

| For | Read |
|---|---|
| What to build next, in what order, and what counts as done | [family-first plan](docs/superpowers/plans/2026-09-05-iphone-16-ui-ux-gameplay.md), section 8 |
| Ideas kept but not scheduled | [ideas](docs/ideas.md) |
| How the screens connect | [screen flow](docs/screen-flow.md) |
| What the app should look like | the Aesthetic North Star in `AGENTS.md` |
| The rules of the game | [house rules](docs/catch-five-rules.md) |

This file says *what the screens must do*. It does not track progress, hold unscheduled ideas, or
decide the order of work; those moved out on September 14, 2026 when it had grown to 775 lines and
was three documents wearing one hat.

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
