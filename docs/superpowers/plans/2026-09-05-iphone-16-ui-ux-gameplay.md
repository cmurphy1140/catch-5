# Catch 5: iPhone 16 and newer UI/UX and gameplay improvement plan

**Date:** September 5, 2026  
**Status:** Proposed design and implementation roadmap; no application implementation authorized.  
**Audience:** Product owner and SwiftUI implementer.  
**Goal:** Make every bid, card play, trick result, and return to a saved match clear, comfortable, and satisfying on iPhone 16 and newer.

**Architecture:** Preserve the dependency-free Swift rules package and its house rules. Improve the SwiftUI presentation around the existing `GameModel`, adding narrowly scoped layout, pause, and feedback responsibilities where required. Keep presentation state separate from match actions and saved rule state.

**Tech stack:** Swift 6, SwiftUI, Combine/ObservableObject, Swift Testing, Xcode app target; current deployment floor iOS 17. Hardware focus does not require changing that floor.

**Design specification:** Sections 3–10 of this document. Roadmap: section 11. This is a review-ready product plan, not permission to execute it. Future implementers should use Superpowers executing-plans task by task after approval; do not interpret unchecked tasks as authorization.

## 1. Evidence and scope

Inspected local repository `cardgame-io`, connected to [cmurphy1140/catch-5](https://github.com/cmurphy1140/catch-5). Local branch `claude/cast-and-menu` at `06b0ca4b6c727ce9a10b3b4ff39a731da030ee82`; fetched remote main at `5da6d9d4b97643d92df778886fd9c0f44593d7e1`. The two tracked trees were identical at inspection, despite different commit histories. Recommendations therefore apply to that remote snapshot too.

Read the supplied screenshot, the existing redesign brief and plan, project instructions, house rules, app/package configuration, core UI/model files, and relevant tests. Computer Use inspection confirmed the current simulator welcome overlay and auction interface. The simulator was running iOS 18.6; its installed build revision was not independently verified. The post-dismissal screenshot was partly clipped by capture, so it is not evidence of a complete layout pass. No bids, cards, or new matches were submitted.

**Verification performed:** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` passed all **111 tests**, September 5, 2026. This verifies the existing baseline, not proposed changes or physical-device accessibility. No release build, full simulator matrix, performance trace, or physical haptic test was performed.

**Screenshot versus current app:** The original screenshot has a large title, boxed scoreboard, three seats in a horizontal row, persistent Hint/Undo buttons, a large empty trick box, small unoverlapped cards, and a new-game link below the hand. Current source already replaces much of this with spatial seating, a compact header, fanned indexed cards, traveling cards, contextual Undo, cast portraits, tutorial, and welcome overlay. Do not repeat that first redesign or restore obsolete Westin/East naming. Seat 0 is the player, 1 Hazel at left, 2 Otto opposite/partner, 3 Rue at right.

**Asset inventory:** Verified tracked image: `App/Assets.xcassets/AppIcon.appiconset/icon-1024.png`; accompanying catalog files: `App/Assets.xcassets/Contents.json` and `App/Assets.xcassets/AppIcon.appiconset/Contents.json`. The table, wood, portraits, cards, and backs are drawn in SwiftUI through `WoodGrainView.swift`, `PortraitView.swift`, and `CardView.swift`; no separate raster card-face or felt asset was found. Preserve these assets. No image conversion, new asset, or visual code change is part of this document.

## 2. Current implementation and concrete gaps

| Area | Existing implementation | Remaining opportunity / confidence |
|---|---|---|
| Rules | `Sources/CatchFive/`: bidding, hand, tricks, scoring, match, replay saves, strategies | Preserve. House rules in `docs/catch-five-rules.md` outrank generic Pitch rules. High confidence. |
| App entry | `App/CatchFiveApp.swift` constructs `GameModel.loadDefault()`; `RootView.swift` owns the model, login, intro, table, welcome overlay | Clarify local profile language; measure restoration; explicitly gate play behind overlays. High confidence in structure. |
| Table | `TableView.swift` owns scheduling, sheets, transient state, feedback; `TableSurface.swift` renders seats, pile, auction, commentary, results | Separate phase controls and scheduling only where needed; reduce dense horizontal width demand. High confidence in source, layout risk requires device verification. |
| Fan | `HandFanView.swift` fits scaled cards by reducing exposed strip width | `minimumTouchStrip` exists but the runtime fitting equation does not enforce it. Existing metric test checks token values, not all actual layouts. High confidence. |
| Invalid action | Non-playable card calls `shake`; legal moves go through `GameModel.send` | Rejected tap produces motion/haptic but no rule explanation through this path. High confidence. |
| Pause | Scheduler depends on `revision`; inactive scene triggers persistence | No explicit scheduler gate for welcome, sheets, background, or review. In-flight task can outlive a visible pause context; exact observed behavior needs a regression fixture. High confidence in missing gate. |
| Accessibility | Spoken card/seat labels, sorting priorities, Dynamic Type, reduced transitions | Table capped at accessibility2; fan capped at xxxLarge; text boosted two steps; shake and press style do not read Reduce Motion. Welcome AX tree exposed underlying table controls during observation. High confidence. |
| Results | `HandSummaryView.swift` lists category winners and bid | Promote contract made/set and score arithmetic above detailed breakdown. High confidence. |
| Persistence | Match write errors surfaced; history/settings use some `try?` writes | Distinguish accepted action from save failure; surface retryable settings/history failure without losing current state. High confidence. |

A notable fitting risk is the side-seat row: two 116-point seats plus a 126-point pile reservation total 358 points before spacers/default gaps. At a 393-point viewport with 32 points of horizontal padding, only 361 points remain. Scaled cards can extend beyond their reservation. This is a sizing inference, not a measured clipping claim.

## 3. Recommended direction and alternatives

**Recommend: refine the welcoming physical table.** Keep felt, oak, ivory, restrained gold, serif identity, familiar cast, and direct tap-to-play. Make the current table reliably adapt to phase, type size, and available space. The product should answer: whose turn, what can I do, what is trump, who took the trick, and what changed in the score?

Alternative A: a flatter score-and-cards interface would reduce visual complexity but discard the current approved identity. Alternative B: a cinematic casino treatment with a large splash, 3D effects, and elaborate dealing would add production and accessibility cost without addressing the actual gaps. Neither is recommended.

**Priority order:** correctness and continuity; readable controls; understandable outcomes; visual refinement; optional gameplay enrichment. Do not add multiplayer, accounts/cloud sync, monetization, new rule variants, or a web rewrite in this scope.

## 4. iPhone 16-and-newer layout specification

Treat the device requirement as a validation scope, not a fixed pixel canvas or a model-name conditional. Use available width, safe areas, and Dynamic Type. Include iPhone 16, Plus, Pro, Pro Max, and 16e if considered part of the supported family; verify newer models available at implementation time. Do not assume every device has a Dynamic Island, the same logical width, or the same refresh rate. Preserve portrait as the current orientation policy; define landscape explicitly before expanding it.

Proposed screen regions, top to bottom:

1. **Compact score header:** small brand, hand number, both scores, one menu. The score remains tappable for history. In compact space use “You + Otto” and “Hazel + Rue” or “Your team / Their team,” with full names in accessibility labels. Keep negative and two-digit scores aligned with monospaced digits.
2. **Contract context:** “Hearts are trump · Otto bid 4.” During bidding show current high bid and actor instead. No redundant instructions or decorative panels.
3. **Table:** Otto opposite, Hazel left, Rue right; seat positions stay consistent. Show active-player treatment plus text, not gold alone. Keep the center footprint stable across empty/one/four-card states.
4. **Decision area near the hand:** status and phase-specific controls. Playing: “Your turn · Follow hearts” when applicable. Bidding: legal choices and Pass. Trump: four labeled suits. Results: contract outcome and next-hand action.
5. **Hand:** anchored above bottom safe area; stable while hint text or transient notices expand. Six card identities must remain distinct and selectable.

Use 16-point outer insets as the initial baseline and an 8-point spacing rhythm with 4-point optical exceptions. Use flexible vertical allocation; reduce decorative gaps before shrinking cards or core text. Do not use one global scale to make a failing screen fit.

At ordinary type sizes, keep essential play controls and the hand visible without scrolling. At accessibility sizes, switch to a deliberate linear reading layout with a stable hand/action area and scrollable supporting details. Existing `TableSurface` scrolling is useful but does not solve a horizontally overflowing seat row. A custom SwiftUI `Layout` or a small adaptive arrangement is preferable to accumulating hard-coded offsets.

**Acceptance:** no safe-area collisions; no essential truncated action copy; all six cards accessible; no seat/card overlap obscuring a rank; full auction reachable; summary and restart confirmation usable at largest supported text sizes. Apple recommends controls at least 44×44 points; use this as the minimum for every essential control. [Apple UI Design Tips](https://developer.apple.com/design/tips/)

## 5. Card interaction and turn clarity

Retain one-tap play as the default. Adding mandatory select-then-confirm would double routine taps. Offer an optional “Confirm card plays” accessibility/comfort setting only after testing identifies a need. In that mode tap selects/lifts, a labeled “Play [card]” control commits, tapping another card changes selection, and phase/undo/new-hand transitions clear stale selection. Drag-to-play is optional later, never the only interaction.

For normal play:

- Display rank/suit corner indices unobscured by overlap. Preserve suit shapes and spoken names; red/black cannot be the sole distinction.
- Maintain a real, nonambiguous 44-point exposed touch region. If the fan cannot fit scaled cards at that bound, switch to an accessible two-row/grid or horizontal list with intentional scrolling. Do not make overlapping invisible hit rectangles compete.
- Define separate resting, playable, pressed, hint, waiting, and unavailable states. Do not communicate “unavailable” only through low opacity, and do not dim card information below comfortable reading contrast.
- Rejected tap leaves match/action count unchanged and shows a short inline reason: “Follow hearts; you still have hearts.” During a computer turn: “Wait for Hazel.” A small haptic accompanies the message if enabled; avoid repeated modal alerts.
- Show “Otto took the trick” with the winning card before collection. Last trick remains inspectable until the next completed trick replaces it.
- Keep Undo reachable from the menu after its four-second toast disappears. Current Undo rewinds the human action and computer replies: explain that honestly; do not describe it as merely moving one card back.

Legal options must continue to derive from engine validation, not a second set of rules in views. A proposed `GameModel.validationMessage(for:) -> String?` can validate on a match copy, returning nil for legal actions and player-facing wording otherwise. Future tests must cover out-of-turn, must-follow-suit, finished hand, and unchanged action count.

## 6. Bidding, trump, scoring, and gameplay ideas

**Bidding:** Keep the visible range consistent, disabling unavailable choices with an understandable explanation available to assistive technology. Add concise context for dealer matching and forced bid 2. Never apply the generic “must always raise” rule to the dealer. Give “9 and out” more separation from Pass; add a focused confirmation explaining “Take all nine points to win; otherwise lose this match.” This confirmation is justified by that action’s exceptional consequence, not by routine bids.

**Trump:** Label suit symbols for sighted beginners as space permits, retaining VoiceOver names. Before selection, an optional factual preview can say how many cards would be kept/replaced. After selection announce the actual replacement count. Do not reveal undealt cards, other hands, or future draws. Match rules already discard non-trumps automatically; do not introduce a manual discard phase.

**Scoring:** The result’s first line should read “Contract made” or “Contract set,” followed by arithmetic: “Bid 4 · Captured 3 · Score 6 → 2.” Defenders add captured points normally. Then show High, Low, Jack, Five (5 points), and Game. High/Low refer to trumps actually played. Mark absent scoring cards “Out of play”; never imply that all nine points must be available. Explain Game ties favor the bidder and simultaneous arrival at 25 favors the bidder. Special 9-and-out results need explicit match win/loss language.

**Learning:** Build on the five existing tutorial lessons and engine-backed review. Add first-occurrence, dismissible explanations near the relevant bid/card/result. Offer “Review this hand” after scoring and “Practice this lesson” from review. Avoid auto-opening a full tutorial mid-match. Describe Standard advice as a strategy recommendation, not proof that a different play was wrong. The existing agreement metric is not a complete skill rating.

**Optional later gameplay value:** replay a completed deal in a clearly labeled practice session with original match history isolated; quick/normal/relaxed pacing tuned across dealing and collection, not just computer delays; a short post-match summary emphasizing bids made and key scoring captures; optional subtle card sounds with a persisted mute setting. Keep Easy/Standard and improve explanation quality before adding a speculative Hard level.

## 7. Loading, onboarding, and save continuity

**Yes to a coherent launch; no to an artificial loading ritual.** This app uses local rules and replay files, not a network-backed game table. Measure cold restoration first. Make the static launch screen visually consistent with the first rendered background. Keep logos modest and avoid timed splash screens. Apple distinguishes launch from onboarding and recommends a launch screen resembling the initial UI. [Launching](https://developer.apple.com/design/human-interface-guidelines/launching), [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)

If measured restoration becomes noticeably slow, introduce a bootstrap state: restoring → ready or recovery-needed. Render a stable background with “Restoring your game…” and an indeterminate progress indicator while real work occurs. Do not show fake percentages, invented card backs representing an unknown hand, or a playable fresh game that is suddenly replaced by a restored one. A proposed 300 ms threshold for revealing a status indicator is a product tuning value, not an Apple rule; never delay completion to meet it.

On restore failure, preserve the unreadable save for recovery, explain that it could not be restored, and let the player explicitly start a new match. Keep the live game usable if a subsequent save fails; offer Retry and do not imply that an accepted move was rejected. Settings/history write failures should also be observable.

Call the existing name/portrait screen “Your player” or “Set up your player,” not an online account login. Keep the skippable intro. The welcome card should add brief saved-match context, such as “Hand 4 · Your team 6, their team 12,” and remain dismissible through Continue. Hide underlying table elements from VoiceOver and pause scheduling while the overlay is present. Apple encourages optional, brief onboarding; this supports the existing skippable approach. [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)

## 8. Typography, materials, motion, and haptics

Keep system serif for brand/selected result emphasis, system body text for gameplay, and monospaced digits for scores. Restrict uppercase tracking to brief metadata. Avoid a font replacement project. Current two-step text boosting is an intentional choice: retain it initially, then tune component hierarchy against real layouts. Do not silently undo that preference to make screenshots fit. Apple text styles and system font designs support scaling without embedding font files. [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)

Measure contrast on the rendered grain/felt, including low-opacity labels, unavailable cards, pressed controls, and the welcome dimming layer. Aim for 4.5:1 for ordinary text and 3:1 for large text and essential graphical distinctions. Add an Increase Contrast response with more opaque materials and clearer boundaries. Keep the existing aesthetic; no new stock imagery or ornamental layers. [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/)

Current timings include 200 ms press, 450 ms flight, 500 ms collapse, 350 ms overlay, 900 ms trick hold, and 1400 ms deal hold. Use them as a baseline, not a reason to add more animations. Measure whether the sum of hold, collection, and computer delay feels sluggish, especially on Quick. Prefer one presentation sequence per accepted action. Replace the fixed 520-point deal origin with measured deck/hand anchors if the flight misses on different sizes.

Reduce Motion must cover `CardPressStyle`, `ShakeEffect`, matched geometry, deal/discard, and collection—not only transitions. Use a small opacity change and a visible reason for rejection; no shaking or traveling cards in reduced mode. [SwiftUI Reduce Motion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)

Retain `.sensoryFeedback` and the saved haptics toggle. One light card-play response, a subtle rejected-action cue, and restrained outcome feedback are sufficient. Audit overlapping triggers: a final action can currently also finish a hand and match. Prefer one prioritized outcome cue; use distinct semantics for a win versus a loss instead of success on every hand completion. Verify on a physical iPhone; simulator observation cannot validate the tactile result. [SensoryFeedback](https://developer.apple.com/documentation/swiftui/sensoryfeedback)

## 9. SwiftUI state and accessibility architecture

Keep `RootView` as the owner of the single game model; child views observe it. There is no demonstrated need to migrate the whole app from ObservableObject to Observation or add an architecture framework.

Introduce a presentation pause policy. Proposed inputs: scene active, welcome presented, sheet presented, confirmation presented, last-trick inspection active. Proposed output: `canAdvance`. A scheduler task should depend on revision and eligibility, cancel when eligibility becomes false, re-check after each suspension, and apply at most one next action. A nested/stacked pause must not resume play when only one overlay closes. Pause state is UI state, not an action in the replay log.

`GameModel.perform` currently applies a rule action, persists, records results, and increments revision, while `send` sets feedback only if `errorMessage` is nil. Because persistence can set that message after the move was accepted, separate action acceptance from persistence outcome. This prevents save failure from suppressing accepted-action feedback or confusing retry behavior. Never reapply a move as a save retry.

For VoiceOver, keep full card names, seat direction/role, dealer, contract, and playable state. Add focused announcements for turn change and trick result without announcing every decorative state change. After a welcome/sheet closes, restore focus to a useful control. After playing, move to the next meaningful status rather than a removed card. Use `AccessibilityFocusState` selectively and avoid repeatedly stealing focus. [AccessibilityFocusState](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate)

The welcome overlay and finished-hand overlay must hide underlying actionable content from accessibility, not merely lower opacity. Provide an accessible hand layout beyond the current type caps. Validate Voice Control labels, Switch Control traversal, Bold Text, Increase Contrast, and Reduce Motion. No essential information may rely solely on suit color, gold, motion, haptics, or timed toast visibility.

## 10. Validation matrix and success criteria

| Dimension | Required cases |
|---|---|
| Hardware/layout | Smallest supported iPhone 16-family logical width; base, Plus, Pro, Pro Max; 16e decision documented; newest available supported standard/largest model; actual safe areas and Display Zoom |
| Text | Default, boosted default, xxxLarge, accessibility2, largest accessibility size; long names, negative scores, hand numbers beyond one digit |
| Phases | Fresh auction; dealer must bid; dealer matches; trump choice; six-card hand; must-follow-suit; one legal card; four-card trick; last trick; hand result; normal win/loss; 9-and-out win/loss |
| Continuity | Welcome open during a computer turn; settings/review/confirmation open; background and return; process relaunch; undo during a pending delay; corrupt save; disk-write failure |
| Accessibility | VoiceOver full match, larger-text full match, reduced-motion full match, haptics off, Increase Contrast, Voice Control and Switch Control critical controls |
| Performance | Cold/warm launch and long-history restoration; rapid taps; deal/collect; long-session memory; UI responsiveness on lowest supported hardware |

Proposed product targets, to validate rather than claim as measured: launch-to-usable under one second for normal local saves on the baseline device; no artificial waiting; immediate press feedback; no noticeable stalls during play; stable frame pacing at the device’s active refresh rate. Correctness gates are strict: one action per deliberate activation, no hidden-turn advancement while paused, all essential hit regions at least 44×44 points, no obscured card identity, accessible core flow at largest text, and baseline rules/save tests remain green.

Run a small formative study with 3–5 players of mixed familiarity: ask them to identify trump, explain a legal move, make a bid, identify a trick winner, explain score changes, and resume a saved game. Record confusion, mis-taps, and requests for help; this is qualitative validation, not statistical proof.

## 11. Practical implementation roadmap

The following are independently reviewable work packages. Estimates are planning ranges for one SwiftUI developer, not commitments; physical-device validation and accessibility work can expand them. Do not execute without user approval. Do not commit application changes without explicit authorization.

### P0 — Task 1: Pause and accepted-action correctness (1–2 days)

**Modify:** `Sources/CatchFiveUI/RootView.swift`, `TableView.swift`, `GameModel.swift`. **Tests:** extend `Tests/CatchFiveUITests/GameModelTests.swift`; add `Tests/CatchFiveUITests/PresentationTests.swift` for a proposed small scheduling policy if extracted.

- [ ] Create deterministic computer-turn and pending-trick fixtures; demonstrate the missing pause gate and save-error/accepted-move distinction.
- [ ] Implement one pause eligibility path owned by the table/root, cancel and revalidate scheduler work after awaits.
- [ ] Separate accepted move, persistence error, and user feedback; make save retry persist the same state only.
- [ ] Verify nested overlays, background/foreground, rapid dismiss/reopen, and undo during delay. Expected: zero actions while paused; exactly one eligible next computer action on resume; no duplicate score/history recording.

### P0 — Task 2: Adaptive table and reliable hand targets (2–3 days)

**Modify:** `Theme.swift`, `TableView.swift`, `TableSurface.swift`, `HandFanView.swift`, `CardView.swift` under `Sources/CatchFiveUI`. **Create if needed:** `Sources/CatchFiveUI/HandLayout.swift` for measured fan/grid decisions. **Tests:** `Tests/CatchFiveUITests/HandLayoutTests.swift` plus simulator interaction checks.

- [ ] Capture baseline auction, play, and result screens at minimum supported width and large text.
- [ ] Test actual available-width/scaled-card combinations, not just nominal theme constants. Required invariant: use fan only when every exposed strip is at least 44 points; otherwise select fallback.
- [ ] Reflow seat/table allocation and large-text hand; reserve bottom safe area and prevent commentary from shifting the hand.
- [ ] Tap all six cards at edges/overlaps in a controlled fixture. Verify no neighboring card activates and no card rank is hidden. Check ordinary layout without scrolling and accessible layout with deliberate scrolling.

### P1 — Task 3: Clear actions, auction, and safe special bid (1–2 days)

**Modify:** `GameModel.swift`, `HandFanView.swift`, `TableSurface.swift`; optionally extract `Sources/CatchFiveUI/AuctionControls.swift`. **Tests:** extend `GameModelTests.swift` and existing rule fixtures in `Tests/CatchFiveTests/BiddingTests.swift` only if coverage gaps exist.

- [ ] Add copied-match validation wording; verify a refused move never changes action count.
- [ ] Present concise rule reasons and waiting states; retain persistent Undo access.
- [ ] Add explanatory dealer bid context and special-bid confirmation. Canceling confirmation must leave match unchanged; confirming must use engine validation at that moment.
- [ ] Verify all-pass dealer, dealer match including 9-and-out, below-zero prohibition, and changed state while a control is presented.

### P1 — Task 4: Outcome and learning clarity (1–2 days)

**Modify:** `HandSummaryView.swift`, `TableSurface.swift`, `ReviewView.swift`, `GameModel.swift`, `RulesText.swift` as needed. **Tests:** extend `GameModelTests.swift` and use existing scoring/review fixtures.

- [ ] Add contract outcome and before/after score wording derived from existing hand history.
- [ ] Verify made/set, defenders’ points, absent Five/Jack, Game tie, simultaneous 25, and special match outcomes.
- [ ] Keep review optional; distinguish strategy advice from rule legality and guaranteed optimal play.
- [ ] Test last-trick inspection with scheduling paused and useful focus restored on close.

### P1 — Task 5: Complete accessibility and feedback (2–3 days)

**Modify:** `RootView.swift`, `WelcomeCard.swift`, `TableSurface.swift`, `TableView.swift`, `HandFanView.swift`, `CardView.swift`, `Theme.swift`, `Settings.swift`, `SettingsView.swift`. **Tests:** presentation/model tests plus Accessibility Inspector and physical-device sessions.

- [ ] Hide background accessibility elements under overlays; establish/restore focus and announce meaningful outcomes.
- [ ] Remove shake, press movement, and card travel under Reduce Motion; retain textual feedback.
- [ ] Add semantic contrast responses and verify rendered colors rather than token colors alone.
- [ ] Prioritize haptic events to avoid stacking; verify toggle off, normal finish, match win/loss, and rejected move on device.
- [ ] Complete a match at maximum text size and with VoiceOver. Automated string tests alone do not satisfy this task.

### P2 — Task 6: Launch and restoration polish (1–2 days, conditional complexity)

**Modify:** `App/CatchFiveApp.swift`, `RootView.swift`, `WelcomeCard.swift`, `LoginView.swift`, `GameModel.swift`, `project.yml`; regenerate `CatchFive.xcodeproj/project.pbxproj` only through the established project workflow if configuration changes. **Create only if measurements justify it:** `Sources/CatchFiveUI/BootstrapModel.swift`. **Tests:** restore fixtures in `GameModelTests.swift` and `Tests/CatchFiveTests/SaveTests.swift`.

- [ ] Measure restore time on normal and long replay histories; inspect static launch appearance.
- [ ] Align launch background and first frame; clarify local profile copy; add resume context.
- [ ] If needed, use one bootstrap-owned restoration operation and real progress state, preserving Swift concurrency isolation. Do not move non-Sendable model instances through detached tasks.
- [ ] Validate corrupt save preservation, retry, new-game consent, no flash of a false fresh match, and no extra delay on fast launch.

### P2 — Task 7: Optional gameplay enhancements (2–4 days per selected slice)

**Potential files:** `Settings.swift`, `SettingsView.swift`, `ReviewView.swift`, `MatchHistory.swift`, and a new isolated practice coordinator only if replay practice is selected. Core `Match` replay APIs should be reused rather than reimplemented.

- [ ] Select one enhancement using formative feedback: confirm-play option, practice replay, pacing refinement, or sound.
- [ ] Define settings migration and isolation from real match records before implementation.
- [ ] For practice replay, prove saved active match/history are unchanged. For confirm-play, prove stale selection cannot commit after undo/phase change. For sound, prove mute persists and interruptions behave correctly.
- [ ] Ship and evaluate the selected slice before choosing another.

**Recommended sequence:** Tasks 1–2 first; 3–5 next; 6 after launch measurement; 7 only after core validation. Core work is roughly 8–13 developer days plus release/device verification; optional work is separate. Establish first milestone as a paused, readable, fully tappable table—not a splash screen.

Every implemented task should update the matching living docs in `docs/architecture.md`, `docs/game-flow.md`, `docs/testing.md`, `docs/code-map.md`, `docs/types-and-functions.md`, and `docs/decisions.md` when those facts change, following project instructions. Update `AGENTS.md` Current Status only to verified implemented behavior. This planning document does not change current feature claims.

## 12. Sources, limits, and handoff

Research used the current repository as primary implementation evidence and current Apple documentation as platform guidance. Searches covered launch/onboarding, game design, typography, control sizing, accessibility, reduced motion, feedback, and accessibility focus. No competitor popularity claim or third-party thumb-zone statistic is needed to justify this plan. Research stopped when each requested area had repository evidence plus applicable first-party guidance; device behavior remains a testing obligation.

Additional platform reference: [Apple Designing for Games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games/) supports adapting interface/control choices and accessibility preferences to the player and device. All linked Apple pages accessed September 5, 2026; stable publication dates were not provided by every page.

**Evidence confidence:** high for inspected code structure, test count, asset inventory, and local/remote tree equivalence; medium for interaction risks inferred from lifecycle/layout code; limited for untested physical-device feel, frame pacing, and all-size visual quality. The earlier screenshot is historical context, not the current baseline.

**Current state:** design and roadmap complete; application code unchanged. **Files added by this task:** this plan only in the repository; a delivery copy outside the repo. Existing untracked `catch5-redesign-brief.md` remains untouched. **Blockers to future implementation:** none for initial pause/layout work; physical iPhone validation is needed before claiming tactile/accessibility quality. **Open product choices:** confirm-play default remains off; include 16e explicitly when finalizing device matrix; select optional gameplay work only after testing. **Recommendation:** approve Tasks 1–2 as the first implementation slice, then reassess screenshots and real-device play before cosmetic expansion.
