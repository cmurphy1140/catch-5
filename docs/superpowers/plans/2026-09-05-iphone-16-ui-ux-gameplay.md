# Catch Five family-first UI/UX plan

> **For agentic workers:** Use the existing inspect → small change → verify workflow; `superpowers:executing-plans` may guide an authorized implementation session. Work sequentially by default. Checkboxes below are future work, not permission to implement, commit, push, launch Claude, or spend money.

**Updated:** September 13, 2026. This existing path remains the authoritative execution plan; its filename reflects when it was first created. It is tracked in this repository; other checkouts receive it through Git.

**Goal:** Make the current native iPhone Catch Five a game Connor and his family enjoy returning to. Portfolio value comes from a thoughtful, working game and honest evidence of improvement.

**Architecture:** Preserve the dependency-free Swift engine, current rules, replay saves, hidden-card boundary, and SwiftUI presentation. Refine existing screens and components; extract a small view or presentation helper only when the chosen change needs it.

**Tech stack:** Existing Swift 6, SwiftUI, Swift Testing, Xcode and local build scripts. Keep current iOS 17/macOS 14 package floors; the review device is not a new support policy.

**Spec:** [Catch Five UI/UX requirements](../../../catch5-ui-redesign-spec.md), reconciled by the current working agreement there. [House rules](../../catch-five-rules.md) govern gameplay. This plan defines order, deliverables, and checks; the spec retains requirement identifiers.

**Authorization:** Planning and documentation only in this session. No application implementation has begun under this plan.

## 1. The direction and the stopping point

Catch Five is the immediate game. Plug & Pitch is the longer-term idea: a family of Pitch games that can eventually accommodate personal house rules. The [existing Plug & Pitch plan](https://github.com/cmurphy1140/plug-and-pitch/blob/main/docs/superpowers/plans/2026-09-05-plug-and-pitch.md) lives in that repository, starts with two fixed presets, and is not an implemented, arbitrary rule builder. Keep its rules, naming, discard/refill work, and architecture separate and deferred.

**Finish line, decided September 13, 2026:** Catch 5 is complete when Increments 1–6 below are implemented, verified and accepted by Connor. At that point this repository's `main` is ingested into plug-and-pitch in one deliberate pass and new product work moves there. Until then plug-and-pitch takes no new product work.

**Two writer tracks, split by module** (rules in `AGENTS.md`, working details in [working together](../../working-together.md)): one session by default; a second joins on the engine side whenever Connor opens one. The increments below are UI-track work. The engine track's first real job is the **"the bot did WHAT?" bank**: Connor flags a hand where a bot bid wrong, wasted a trick, ignored its partner or gave away the Five or Jack; each flagged hand becomes a deterministic test fixture from the replay log; a fix is accepted only if the mirrored benchmark (`Tests/CatchFiveTests/StrategyBenchmark.swift`, D17) does not get worse. This supersedes D22's "strategy is parked": strategy now moves on evidence from real hands. The engine track also owns the baseline package suite in Increment 0, the save/undo/corrupt-fixture regressions in Increment 4, the full-match fixtures in section 6, and any reproduced engine defect.

Our first finish line is a comfortable offline solo game against the existing opponents. Family members can try it on Connor's phone without a new subscription. This does not promise everyone can install it remotely for free, and it does not mean human family multiplayer exists. Distribution can be revisited after the game is worth sharing.

**Success looks like this:** a family member can start or resume, recognize their partner and turn, bid and choose trump, deliberately play cards, understand the result, and choose another hand without Connor repeatedly explaining the interface. An unfamiliar player can get help without blocking an experienced player. Family enjoyment remains something to observe, not something a passing test can establish.

**Not in this effort:** developer membership, App Store/TestFlight submission, hosting, paid services/assets, account login, cloud sync, multiplayer, new rule variants, arbitrary rule editing, stronger AI, a new framework, rebranding, analytics services, or a portfolio website. Preserve useful engine/UI boundaries for the future without building abstractions for hypothetical games.

## 2. What the latest review establishes

Reviewed main: `131c941b4301069574abe87a5196044d12ca1343`, verified against GitHub main during the September 12 review. The build came from an isolated archive, not the older dirty checkout. Device: iPhone 16 simulator, iOS 18.6, 393 × 852 points, default system text with existing app scaling.

| Evidence level | Finding | Consequence for the plan |
|---|---|---|
| Interaction verified | Profile, skippable introduction, tutorial navigation/exit, menu destinations, pause, resume, bidding, trump selection, six plays, hand result and review worked | Preserve these flows; do not rebuild them as missing features |
| Interaction verified, bounded | Beginner preference survived relaunch; Continue restored the game; New match Cancel and 9-and-out Cancel worked | Extend coverage around interruptions and setup changes rather than claiming every continuity edge passed |
| Appearance verified | Felt, wood, ivory cards, cast, large cards, score arithmetic, and highlighted hints are present | Retain the identity; this is refinement, not a reskin |
| Observed UX friction | First lesson puts paragraphs ahead of a partly off-screen exercise; beginner trump captions are crowded; table gear means general controls while main menu uses hamburger | Address through small comparisons, respecting the approved main-menu icon and location |
| Existing code, not freshly certified | `TablePause`, `HandLayout`, `HandOutcome`, validation messages, save-retry separation, Reduce Motion hooks, and targeted tests now exist on main | Old claims that these are absent are stale; inspect and reproduce before repairing |
| Not yet verified | Full-match outcomes, all tutorial exercises, all modes/difficulties, rapid tapping, interrupted computer turns, maximum text, full VoiceOver play, real-device motion/haptics | Acceptance work remains; absence of testing is not a reproduced defect |

Four final UI probes passed and the simulator build succeeded. An earlier probe used an alert selector for a sheet and failed; the corrected probe passed. An overlapping hand-end screenshot was taken during animation; the settled screen was checked and was legible. Neither is recorded as a persistent app defect. The full engine suite was not rerun in that review; historic counts are not current results.

Detailed local evidence: [review note](../../../notes/ux-review-2026-09-12.md), screenshots/logs in `work/ux-review-2026-09-12/`. These are ignored local artifacts and do not travel through Git automatically. This section preserves the essential findings for another checkout. The [prior plan snapshot](../../history/2026-09-05-iphone-ui-plan-before-family-focus.md) preserves older research and proposals as history.

## 3. Resolve inherited conflicts before implementing their behavior

The September 6 spec is a target, not proof that main implements it. The September 5 plan is historical. Latest user decisions take precedence over both.

- **Card commitment and Undo:** main currently plays a legal card with one tap and supports replay-based Undo. Spec R15/F.1 describe selection/commit and undoing only uncommitted selection; the old plan preferred one-tap play. Do not silently pick a new interaction model or remove working Undo during spacing work. Keep current behavior for the first increment. When this becomes the chosen task, show Connor two concrete tap sequences and resolve the scope once, then update the matching requirement. Engine rewind remains intact even if its presentation changes.
- **Discarding:** current Catch Five automatically replaces non-trumps. Manual discard/tray passages in the broad spec are not authorization to add Plug & Pitch's discard phase to this game. No new game action or save format in this UI pass.
- **Trump captions:** main already hides visible keep counts in normal mode. Improve beginner caption fit selectively; retain plain suit labels in normal mode. Inspect accessible labels too before declaring the assistance boundary complete. Do not add a live counting tray to solve cramped captions.
- **Menu:** the approved bare main-menu hamburger stays top-right. Investigate only the table's gear/general-menu mismatch; no visible Menu label or menu redesign by default.
- **Results:** main has a result plus a separate review; R7–R11 target compact facts with optional detail. That is a planned presentation change, not a broken scoring claim.
- **Teaching:** R27 was deferred in the old pass. It is now a selected candidate within the family-focused roadmap, after core play clarity; this does not activate all of Group E.

No question here blocks writing the plan. A narrow implementation should raise only the decision it actually depends on; family members do not need to complete a questionnaire first.

## 4. The player journey we are shaping

```text
RETURNING PLAYER
Main menu → Continue game → My turn → Result → Deal next hand
                  ↕             ↕          ↕
             Pause/resume    Help if wanted   Details if wanted

NEW PLAYER
Your player → Play now OR optional practice → Same real table
```

Suggested result composition, for discussion rather than a final mockup:

```text
Contract set
You + Otto bid 9 and captured 4
Your score: 0 → −9

▸ Points and scoring
▸ What happened in the tricks
▸ A suggestion for next time       [beginner guidance only]

[ Deal next hand ]
```

This example uses the reviewed hand's facts. The final wording must derive from existing outcome data and preserve defenders' scores and special-win rules. Ordinary facts remain available in both modes. No mandatory advice modal, accuracy grade, or fabricated optimal-play judgment.

## 5. Ordered implementation increments

### Increment 0 — Establish the writable baseline

**Outcome:** subsequent screenshots, tests, and edits all refer to one known version. This is prerequisite preparation, not another redesign.

Implementation base: `main` at or after the September 13 documentation merge (code `131c941`, PR #41). This plan and the spec are tracked on `main`; the `claude/dealer-draw` branch is historical and must not be merged. The coordinator/writer rules are in `AGENTS.md`.

- [x] Carry this plan and the authoritative spec onto `main` (September 13, 2026, docs-only branch from `2befd92`).
- [ ] Check host, branch, status, worktrees, other sessions, and simulator/build use immediately before implementation.
- [x] Writer checkouts: the UI writer uses the main checkout `~/Desktop/Projects/catch-5`; the game-logic writer uses the worktree `~/Developer/active/catch-5-worktrees/game-logic` (branch `logic/baseline` off `main` at `2befd92`, created September 13). Desktop is iCloud-synced, so worktrees live under Developer. No migration of the main repo.
- [ ] One heavy test/build/simulator operation at a time across both writers.
- [ ] Game-logic writer: run the existing package suite on that baseline and record failures as baseline failures before changing code. UI writer: inventory exact assets before visual work; preserve existing drawn artwork and icon.

**Accept:** known build/branch, preserved local changes, relevant instructions available, baseline checks recorded. No commit/push without authorization. This plan grants neither.

### Increment 1 — Make an ordinary turn easy to read

**Outcome:** recognizable current table with clear actions and comfortable labels. This is the recommended first visible change for the family-first goal.

**Files to inspect/modify only as needed:** `Sources/CatchFiveUI/TableSurface.swift`, `ScoreBarView.swift`, `Theme.swift`; `HandFanView.swift` and `HandLayout.swift` only for reproduced card-fit issues. Use existing `GameModel` validation and `TablePause`; do not alter engine rules.

- [ ] Capture auction, trump choice and trick play in both modes before edits; compare the same states afterward.
- [ ] Start with one small visual slice: give beginner trump captions a compact two-line layout or sufficient width without shrinking essential text. Keep suit order, red/black alternation, glyph visibility and normal-mode suit labels. Show Connor the comparison before extending the pattern.
- [ ] Second slice, pace (Connor, September 13: "too fast, things happen before I see them"): make `relaxed` the default play speed in `Settings.swift` (today `normal`, 0.7 s before a play and 1.2 s before a lead; relaxed is 1.0 and 1.8) and add a short beat after a trick completes before it collects, so the winner can be seen. Keep the setting user-adjustable; existing saved settings keep their chosen speed.
- [ ] Verify whose turn, partner, high bid, trump, and the required next action can be found without opening help. Change only misleading/missing presentation revealed by that check.
- [ ] Inspect table menu meaning; propose the smallest consistent table affordance while leaving the approved main menu intact. Preserve access to pause and its existing three actions.
- [ ] Check six-card hit regions, unavailable-card explanations, and readable four-card tricks. Fix a reproduced defect in its own bounded slice; do not assume old clipping reports still reproduce.

**Acceptance:** all bidding options reachable; no caption collisions at baseline size; large text reflows rather than hiding an action; normal mode stays free of visible coaching counts; six intended card targets can be distinguished; refused actions do not advance the game. Navigation changes must preserve Cancel/resume. Existing `handLayoutFansOnlyWhenEveryStripIsThumbSized`, `validationMessagesExplainRefusalsWithoutChangingTheMatch`, and `trumpChoicesAlternateRedAndBlack` are relevant checks; simulator interaction is still required.

**Stop:** one before/after set that feels clearer without looking like a different game. Do not add controls to fill space.

### Increment 2 — Make the end of a hand understandable

**Outcome:** outcome and score change first, next hand easy to reach, optional explanation available without an imposed reading session.

**Files:** `HandSummaryView.swift`, `ReviewView.swift`, result presentation in `TableSurface.swift`, existing `HandOutcome.swift`; only read `Sources/CatchFive/HandReview.swift` and scoring unless a separate reproduced defect requires repair. Reuse data rather than calculate scores in views.

- [ ] Mock the compact result using the real hand above; compare with the existing result.
- [ ] Keep contract outcome, both teams' score changes, and Deal next hand visible. Expose scoring facts and trick details through bounded disclosure, following R7–R11 with at most two disclosure levels.
- [ ] Show the Game count out loud in the result ("Game 34 to 31, bidder takes the point"), because ties to the bidder are the rule this table argues about (Connor, September 13). Derive it from existing outcome data.
- [ ] Retain access to all existing factual review data; beginner coaching may add one concise suggestion, without a new recommendation engine or skill rating.
- [ ] Explain missing scoring cards and special 9-and-out outcomes using existing outcome facts. Distinguish captured hand points from the score penalty.
- [ ] Verify opening/closing details never resumes a finished hand, adds history again, or hides the next-hand action at larger text sizes.

**Acceptance:** made and set, defenders' points, missing Five/Jack, negative score, match win/loss, and 9-and-out cases all display faithful facts. Reuse `handOutcomeLeadsWithTheContractAndTheArithmetic`, `handOutcomeExplainsTheEdgeCases`, `lastHandOutcomeIsBuiltFromTheMatchHistory`, and `finishedMatchIsRecordedExactlyOnce`. Check settled rendering and animation separately.

### Increment 3 — Help only where the player needs it

**Outcome:** optional practice teaches by doing; experienced players proceed directly to the game.

**First slice files:** `Tutorial/Lessons/DealLesson.swift` and shared `Tutorial/TutorialView.swift` under `Sources/CatchFiveUI`; `TutorialModel.swift` only if behavior changes. Then individually consider `BiddingLesson.swift`, `TrumpLesson.swift`, `TricksLesson.swift`, `ScoringLesson.swift`, `IntroView.swift`, and `LoginView.swift`.

- [ ] Move the first lesson's short prompt and seat exercise ahead of supporting paragraphs; put optional explanation under a clear disclosure. Start with the existing fixture and feedback.
- [ ] Use the table's familiar names; introduce a compass direction explicitly when it matters. Avoid requiring players to map unnamed East/West seats to characters themselves.
- [ ] Make Skip/Done, lesson progress, feedback, and next action discoverable. Retain the ability to browse lessons; do not add compulsory completion gates.
- [ ] Inspect both entry routes: starting from the intro and opening help during a saved match. Practice must not replace that match or inflate statistics.
- [ ] Only after the first lesson works, apply the same pattern to remaining exercises that need it. Keep rules available offline and preserve meaningful detail.
- [ ] Clarify that player setup is local; do not imply online registration. No new account or onboarding questionnaire.

**Acceptance:** first exercise and its choices visible at the baseline size with no preliminary reading required; larger text can scroll deliberately; wrong answer gives a useful explanation and permits retry; Skip/Finish return to the correct context; live save/history unchanged. Reuse `TutorialModelTests.swift` fixtures for legal moves, winners and scoring. Add an isolation regression if a navigation/model change exposes a gap; UI tests, not model tests alone, must verify the actual entry/exit routes.

### Increment 4 — Deliberate card choices and trustworthy interruptions

**Outcome:** touch behavior feels predictable and a interruption does not cost the player their game.

**Files:** `HandFanView.swift`, `GameModel.swift`, `TableView.swift`, `TablePause.swift`, `RootView.swift`, `MainMenuView.swift`, `WelcomeCard.swift`. Existing tests: `Tests/CatchFiveUITests/GameModelTests.swift`, `Tests/CatchFiveTests/SaveTests.swift` and `UndoTests.swift`.

- [ ] Before changing commitment, show current one-tap plus replay-Undo beside select/change/confirm plus uncommitted-selection undo. Resolve the R15 conflict with Connor using a concrete hand; no silent global change or new settings branch.
- [ ] If a different interaction is selected, first add a regression for stale selections after phase change/new hand/resume, then implement only that selected behavior. Use one interaction model across assistance modes.
- [ ] Pause during a pending computer move, open a nested sheet, dismiss one cover, and background the app. Verify no hidden move while paused and exactly one eligible action after resuming.
- [ ] Change future-match setup, then Continue: current cards, scores, players and difficulty must remain those of the saved match. New match Cancel preserves it; confirm uses the selected setup.
- [ ] Verify accepted-action/save-failure behavior with isolated temporary storage. Retry persistence must not play the move again. Corrupt fixtures must not touch Connor's real save.

**Acceptance:** exact action counts and saved-state assertions for these cases, plus visible interaction checks. Existing `tablePauseHoldsWhileAnyCoverRemains`, `saveFailureKeepsTheAcceptedMoveAndRetryWritesTheSameState`, `undoneMatchSavesAndReloads`, and `corruptGameIsSetAsideAndTheFreshGameSaysSo` are starting coverage, not proof that every UI route is correct. Repairs arise from reproduced failures. Any actual data-loss defect found earlier takes priority immediately.

### Increment 5 — Comfortable reading and satisfying feedback

**Outcome:** the existing table remains readable and responsive with larger text, accessibility settings, and real thumb use. This is finishing work, not a visual effects project.

**Files:** `Theme.swift`, `CardView.swift`, `HandFanView.swift`, `TableView.swift`, `TableFeedback.swift`, `Settings.swift`, `SettingsView.swift`; relevant reading views only when their text needs attention.

- [ ] Test one larger text setting during every earlier increment. Here complete the supported extremes and critical accessibility flow; reduce gaps or use deliberate reflow before shrinking ranks or instructions.
- [ ] Verify VoiceOver can identify cards, legal status, partner, trump, turn, result, and primary actions. Overlays must not expose underlying playable controls; closing one restores useful focus.
- [ ] Reduce Motion removes unnecessary travel/shake while textual feedback remains. Check suits and states without relying on color alone; inspect contrast on rendered textures.
- [ ] Tune existing pace only where real-device play shows lag or premature collection. Retain user-controlled pace and haptics; no artificial splash/loading wait.
- [ ] Test haptics on Connor's phone when available, including mute/off behavior and stacked end-of-hand/end-of-match events. Simulator results cannot establish tactile quality.

**Acceptance:** complete a match at default and large text, and exercise the core loop with VoiceOver and Reduce Motion; record exact configurations. No essential control hidden by text or the home indicator. One accepted action produces appropriate feedback without duplicated events. Existing `oneFeedbackCuePerActionWithTheOutcomeThatMattersMost` protects feedback selection; physical testing establishes feel. Optional sound remains deferred until players request it and a small free, appropriately licensed solution is useful.

### Increment 6 — A family play session and a small finish

**Outcome:** evidence from actual use determines the final corrections.

- [ ] Let a willing family member play on the available phone. Start with someone familiar with the house rules; if practical, later try someone less familiar. Neither recruitment nor a particular sample size blocks development.
- [ ] Offer one natural goal: “Play a hand, then show me what happened.” Observe without narrating every control; help if they are stuck.
- [ ] Record only moments affecting understanding or use: location, what happened, likely impact, and smallest correction. Separate observation from their preference and our interpretation. No recording, analytics, timed scorecard or survey required.
- [ ] Ask what felt awkward and whether they would choose another hand. Do not interpret politeness or a single session as retention evidence.
- [ ] Pick at most three useful corrections, verify each, and stop. Keep remaining ideas in the existing spec rather than creating another project.

**Acceptance:** the family loop works without repeated assistance, or the remaining specific obstacle is recorded honestly. Lack of an available tester is “family validation pending,” not a software failure or a reason to spend money.

## 6. Verification without making the hobby feel like work

For a styling-only change, compare screenshots and interact with the affected controls. Do not add tests that merely mirror padding values. For state changes, add a targeted regression using existing fixtures and temporary stores, prove the failure, then repair it. Do not create a second test framework or permanent UI-test project unless repeated needs justify one; the September 12 probe was temporary and is not a repository test target.

Commands from the implementation checkout:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TutorialModelTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter tablePauseHoldsWhileAnyCoverRemains
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/build-simulator.py
```

Choose the relevant focused test, then run the required suite and simulator build once at an app-code milestone. Confirm filter output actually ran the intended tests. Do not rerun expensive checks for a documentation-only planning update. Use the existing device-install guide when local phone testing is requested; never overwrite an existing phone save blindly.

Minimum practical matrix: baseline 393-point portrait; one larger supported phone size; default plus larger and maximum supported text; beginner on/off with Easy/Standard; Reduce Motion; first-run and returning-player routes. Include other actual family phones when known, without raising minimum OS or claiming untested coverage. Full-match fixtures include normal and special win/loss; after the first targeted pass, repeat only affected cases unless a failure requires broader investigation.

## 7. Keeping it fun and keeping the record useful

Use **sketch → inspect together → change one thing → play → verify**. Connor is the player, designer and engineering collaborator, not a requirements clerk. Offer one meaningful choice when the next change depends on it; do routine work without repeated permission requests once implementation is authorized. No imposed schedule: each increment may take multiple small sessions, and the older 8–13-day estimate is not a commitment for this revised scope.

After each accepted increment, update this plan's status table, the matching spec requirements, and affected living docs. Record implemented, verified, and user-approved separately. Do not restart the completed workflow trial. A branch/worktree is not a saved Git checkpoint; commits still require explicit permission for Catch Five. No push, archive upload, App Store work, or other agent launch is authorized by this plan.

When useful, capture one before/after and a short explanation of why the change helped. At the finish, update the existing README and keep a brief gameplay recording plus test evidence for the portfolio. No separate résumé project, performance claims, or invented user metrics; distinguish Connor's decisions, tool assistance, and verified engineering work.

## 8. Current progress and next action

| Increment | Status on September 13 | Next check |
|---|---|---|
| Baseline reconciliation | Done September 13: plan, spec and rules on `main`; `swift build` and `swift test` 149 of 149 verified on that tree; iCloud excluded; stale branches removed | Increment 1, first slice |
| Ordinary turn clarity | Proposed first visible slice | Beginner trump captions, same-state before/after |
| Hand result clarity | Proposed | Compact real-data sketch; preserve factual detail |
| Optional learning | Proposed | One lesson first, verify entry/exit isolation |
| Touch/continuity | Partially covered by existing behavior; remaining verification pending | Resolve commitment mismatch only when this task starts |
| Accessibility/feedback | Existing facilities; full current validation pending | Larger text, VoiceOver, actual phone feedback |
| Family observation | Not performed | A willing player and available phone, when convenient |

**Active sessions, September 13, 2026:** one Claude Code session in the main checkout, holding both writer roles in turn; the coordinator is Connor's planning chat. A second session joins on the engine side when Connor opens one. Sessions leave word in the log at the end of [working together](../../working-together.md); the coordinator updates this table.

**Next recommended implementation request (UI writer):** “Start Increment 1 of the Catch Five family UI plan from `main` in your own worktree. Improve only beginner trump-caption readability. Keep normal mode, suit order, rules, saves, and the approved main menu unchanged. Show before/after and verify relevant checks. Leave changes uncommitted; don't push.” Within the UI track, run increments in order: 1 and 2 both touch `TableSurface.swift`.

**Next recommended implementation request (engine writer, when opened):** “Start the bot bank. Take the first hand Connor flagged, rebuild it from the replay log as a deterministic fixture in `Tests/CatchFiveTests/`, write the test that names the bad decision, then improve `ComputerPlayer` only enough to pass it without lowering the mirrored benchmark. Engine files only. Leave changes uncommitted; don't push.”

## 9. Source and maintenance boundaries

Project evidence: reviewed main files and named tests above; September 12 review; current spec; house rules; earlier plan snapshot; Plug & Pitch plan. No new external product, pricing, or platform recommendation was required for this planning update. Earlier Apple links remain in the historical plan as dated references, not newly reverified research. Before adopting a specific new platform API, check the installed SDK and official documentation then.

This plan and the spec are tracked in this repository from September 13, 2026. App-bundled explanatory content was regenerated for the indexed pages this documentation change touched (roadmap, learning path); preserve that source/build convention when future implementation changes indexed content.

**Planning verification, September 12:** local document links and Markdown fences checked; historical missing Inbox links in the deferred plan labeled unavailable. `git diff --check` passed. Content hashes verified all pre-existing files outside the six intended documentation edits unchanged; `CLAUDE.md` remains the symlink to `AGENTS.md`. Older plan/agreement snapshots were preserved under `docs/history/`. No application tests/builds were run for this planning-only update. No app code, global instructions, simulator state, commit or remote state changed.
