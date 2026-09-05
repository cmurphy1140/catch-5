# Catch 5 table redesign: plan

Approved on 2026-09-05; implemented step by step on branch `claude/redesign`.

## Context

The gameplay screen has a visual identity worth keeping (felt gradient, ivory cards, gold accents, serif title) but reads as a dashboard: `TableView.body` is a `ScrollView` stacking header, score panel, three opponent tiles in a row, status text, Hint/Undo row, trick panel, hand, then phase controls (`Sources/CatchFiveUI/TableView.swift` lines 21–44). The brief asks for a physical table: compact score bar on top, opponents seated around a centre pile, cards moving between seats and pile, and the hand as the dominant, tactile element. Research below confirms the direction and sharpens several numbers.

## Research findings that refine the brief

| Topic | Finding | Effect on the brief |
|---|---|---|
| Thumb zone | 49% of people use one thumb; 75% of touches are thumb; bottom-centre is the "natural" zone, top corners the hard one ([Hoober summary](https://parachutedesign.ca/blog/thumb-zone-ux/), [Elaris](https://elaris.software/blog/mobile-ux-thumb-zones-2025/)). | Hand at the bottom is right. Bids and trump choice, the other primary actions, must also sit in the bottom third; today they render below the hand, off-screen until scrolled. Rare actions (settings, stats, tutorial) may stay top-right. |
| Touch targets | HIG: 44×44 pt default, 28 pt only for non-critical controls; keep controls out of the home-indicator and Dynamic Island areas ([WWDC24 game design](https://developer.apple.com/videos/play/wwdc2024/10085/), [HIG games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games)). | Overlapped fan cards must expose at least a 44 pt tappable strip each; this bounds the overlap (see metrics). The Hint tertiary control may be 28 pt visually but keeps a 44 pt hit area. |
| Card ratio | Poker 2.5×3.5 in (5:7 = 1:1.4), bridge 2.25×3.5 (1:1.56); comfortable band 1:1.3 to 1:1.7; corner radius 3–4 mm on a 63 mm card, about 6% of width ([PrintNinja](https://printninja.com/card-dimensions/), [Pure Solitaire](https://www.puresolitaire.games/blog/playing-card-dimensions-deck-size/)). | Keep the current 2:3 (1:1.5). Refinement: corner radius 6% of width, so 4 pt at 60 pt wide rather than today's 8 pt at 48 pt, which reads as a chip, not a card. |
| Fan legibility | In fanned hands the readable strip is the top-left corner; values placed there with higher contrast survive overlap ([designing a card game](https://medium.com/@acbassettone/5-ux-ui-lessons-from-designing-a-card-game-b689d3f3187), [GDKeys](https://gdkeys.com/the-card-games-ui-design-of-fairtravel-battle/)). | Refinement: `CardView` gains a top-left corner index (rank over suit) in addition to the centre pips; the overlap direction leaves each card's left edge visible. |
| Typography | HIG minimum 11 pt; body 17, footnote 13, caption 12/11; SF Text under 20 pt ([Median](https://median.co/blog/apples-ui-dos-and-donts-typography), [Design+Code](https://designcode.io/ios-design-handbook-typography-and-dynamic-type/)). | Corner index no smaller than 13 pt at default size; seat labels 13 pt; score digits title-size. All via text styles so Dynamic Type keeps working (M6 already did this). |
| Contrast and elevation | 4.5:1 text, 3:1 non-text components; in dark UIs shadows read weakly and elevation comes from lighter surfaces ([WebAIM](https://webaim.org/articles/contrast/), [Muzli dark elevation](https://medium.muz.li/mastering-elevation-for-dark-ui-a-comprehensive-guide-04cc770dd0d6)). | Ivory on felt is already about 14:1. Refinement: express "lifted" primarily by a lighter card face and a larger, softer shadow, not shadow alone; illegal cards dim to 55% (still above 3:1), not 50%. |
| Motion | HIG: motion must convey meaning, be optional, respect Reduce Motion; system animations 250–400 ms; WWDC23 springs: bounce 0 is the versatile default, about 0.15 feels brisk, 0.3 noticeably bouncy, above 0.4 is too much for UI ([WWDC23 Animate with springs](https://developer.apple.com/videos/play/wwdc2023/10158/), [Use Your Loaf](https://useyourloaf.com/blog/reducing-motion-of-animations/)). | Concrete timings below. Every flight has a Reduce Motion fallback (crossfade), extending the existing `reduceMotion` branches. |
| Haptics | Impact styles map to visual weight (light/medium/heavy, soft/rigid); `.sensoryFeedback` offers `.impact(weight:intensity:)`, `.impact(flexibility:intensity:)`, `.selection`, `.success`, `.warning`, `.error`; Apple's guidance is to use haptics sparingly, consistently, and always paired with a visual ([Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-haptic-effects-using-sensory-feedback), [Swift with Majid](https://swiftwithmajid.com/2023/10/10/sensory-feedback-in-swiftui/), [Apple UIImpactFeedbackGenerator](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator)). Core Haptics transients (sharpness, intensity 0–1) allow custom "card" taps ([Lofelt](https://medium.com/lofelt/10-things-you-should-know-about-designing-for-apple-core-haptics-9219fdebdcaa)). | Refinement: stay on `.sensoryFeedback` (already used, honours the settings toggle) rather than Core Haptics; a rejected tap uses a rigid low-intensity impact, not `.error`, which is a two-pulse alarm too strong for a wrong card. Vocabulary below. |

## 1. Design system reference

All values go in one new file, `Sources/CatchFiveUI/Theme.swift`, as `enum Theme { enum Card, Motion, Gold }` with `@ScaledMetric`-friendly base values, so views stop carrying magic numbers.

**Card metrics** (width × height, 2:3; corner radius 6% of width)

| Role | Size | Notes |
|---|---|---|
| Hand at rest | 60×90 pt (+25% over today's 48×72) | On widths ≥ 402 pt use 64×96 (+33%). Both fit six overlapped cards on a 375 pt screen. |
| Hand, playable on your turn | same size, lifted 6 pt, face `.ivory` at 100%, shadow y 4 blur 8 | Illegal cards: not lifted, 55% opacity, no shadow. |
| Hand, pressed (about to play) | lifted 12 pt, scale 1.04, shadow y 8 blur 14 | Matches "rises 8–12 pt before confirming". |
| Hand overlap | each card shows a 44 pt strip: spacing −16 pt at 60 pt width | Six cards span 60 + 5×44 = 280 pt. Fan: rotation from −8° to +8° across the hand, anchor bottom-centre, y offset following a shallow arc (outer cards 6 pt lower). Keep flat when Reduce Motion is on (rotation is fine, but no arc animation). |
| Centre pile | 56×84 pt | Four cards at their seat offsets (see layout), winner ringed. |
| Opponent card back | 40×60 pt | A single back per seat with the count; not one back per card. |
| Corner index | rank 13 pt serif bold over suit 12 pt, top-left, 6 pt inset | Centre pips stay (rank 22 pt, suit 26 pt scaled). |

**When gold is used** (and nowhere else)

1. Current dealer badge.
2. Trump suit glyph and the contract line in the score bar.
3. Active seat indicator (the seat whose turn it is): a 2 pt gold ring on the seat tile, and the "Your turn" status word.
4. Winning card of a completed trick: 3 pt ring, and the winner's seat flash during the collapse.
5. Key results: match-over card, and the one primary button on screen ("Deal next hand" / "Play again").

Everything else that is gold today becomes ivory at reduced opacity: hint panel and hint ring (ivory dashed ring, 70%), explanation text (ivory 85%), notices, "took it" line, bordered action buttons (bid grid, suits, Review hand: `.tint(.ivory.opacity(0.8))`), the score-panel trump text stays gold (rule 2). Grep today finds about 40 `gold` uses in `Sources/CatchFiveUI`; the audit table in step 6 lists each.

**Motion and timing** (all springs; Reduce Motion replaces flights with 200 ms crossfades)

| Event | Animation | Values |
|---|---|---|
| Legal cards lift when it becomes your turn | offset + shadow | `.spring(duration: 0.3, bounce: 0.15)` |
| Press a card | offset 12 pt, scale 1.04 | `.spring(duration: 0.2, bounce: 0.2)`, driven by a `ButtonStyle` `isPressed` |
| Play a card: hand → pile | `matchedGeometryEffect` on the card id across hand and pile | `.spring(duration: 0.45, bounce: 0)` |
| Computer plays: seat → pile | insertion transition offset from that seat's anchor to the pile | `.spring(duration: 0.4, bounce: 0)` |
| Illegal card tapped | horizontal shake ±6 pt, 3 cycles | keyframe 0.3 s total; no play |
| Trick complete | hold 900 ms with the winner ringed, then the four cards collapse toward the winner's seat (offset to seat anchor, scale 0.5, opacity 0) | `.spring(duration: 0.5, bounce: 0)`; the hold reuses the existing lead delay in `.task(id: revision)` so nothing plays during it |
| Hand end / match end | summary card fades and slides up 12 pt over the table | `.spring(duration: 0.35, bounce: 0)` |

**Haptic vocabulary** (`.sensoryFeedback`, gated by `settings.haptics` as today)

| Event | Feedback |
|---|---|
| Card played (human) | `.impact(flexibility: .soft, intensity: 0.6)` |
| Illegal card tapped | `.impact(flexibility: .rigid, intensity: 0.4)` |
| Trick taken by our side | `.impact(weight: .medium, intensity: 0.9)`; by them `.impact(weight: .light)` |
| Bid or trump chosen | `.selection` |
| Hand end | `.success` (existing); match end `.success` then a 150 ms later `.impact(weight: .heavy)` |

**Compact score bar** as a reusable component: `ScoreBarView(us: Int, them: Int, usLabel: String, themLabel: String, trump: Suit?, contract: String?, handNumber: Int, onTap:)`, pure of `GameModel`, two rows: team labels over digits (title style, serif), then `♥ TRUMP · BID 3` left and `HAND 4` right in caption monospaced. It replaces `header` + `scorePanel` (lines 77–130) and keeps the scoreboard tap. The three sheet buttons move into a single `Menu` behind the gear (Settings, Statistics, How to play) so the bar has one control.

## 2. Screen-by-screen breakdown (`Sources/CatchFiveUI`)

The gameplay screen is one view, `TableView`, with sheets. Sheets (`SettingsView`, `TutorialView`, `RulesView`, `ReviewView`, `ScoreboardView`, `StatisticsView`, `ExplainerView`) are untouched except for gold consistency.

| Region today | Code | Decision |
|---|---|---|
| Header (title, hand number, three icons) | `header`, lines 77–96 | **Rebuilt** into `ScoreBarView`; title shrinks to the bar's first line; icons collapse into one gear `Menu`. |
| Score panel (button → scoreboard) | `scores`, `scorePanel`, `team`, `score`, lines 98–130 | **Rebuilt** into `ScoreBarView`; the tap-to-scoreboard and `accessibilityHint` carry over. |
| Opponent tiles in an `HStack` | `opponent(_:)`, `seatSummary`, `seatDetail`, lines 132–156 | **Repositioned** into a new `TableSurface` `ZStack`: seat 2 (partner, across) top-centre, seat 1 (West) left, seat 3 (East) right, per `Self.edge(for:)` and the engine's seating (team 0 = seats 0/2). The brief's sketch puts "Westin" top; the model says partner is across, so the tile positions follow the model and the names follow `settings.seatNames`. Tile content stays (name, detail, dealer badge, VoiceOver summary); active-seat styling changes from white 14% fill to the gold ring rule. Each tile becomes a card-back stack with a count outside the auction. |
| Status text + notice | line 33–34, `status` 180–191 | **Repositioned** into the table centre under the pile ("Your turn ♥ Trump"), one line, ivory; notice text becomes the toast slot (see Undo). |
| Hint / Undo row | `hintRow`, lines 158–178, condition line 35 | **Deleted** as a row. Hint becomes a 28 pt tertiary `lightbulb` button at the right end of the status line (44 pt hit area), shown only on your turn; its panel reuses the explanation slot under the pile. Undo becomes a toast. |
| Trick panel ("ON THE TABLE" / "LAST TRICK") | `trick`, `edge(for:)`, lines 193–245 | **Rebuilt** as `PileView`: four cards offset toward their seats around the centre, ringed winner, tap-to-explain preserved (`model.explain`), explanation text below the pile. The "last trick stays until the next lead" behaviour is replaced by hold-then-collapse; a small stacked-cards glyph beside the winner's seat reopens the last trick for tap-to-explain. |
| Phase controls (bid grid, suit buttons, hand summary, match-over, Review/Deal buttons) | `controls`, `matchOver`, `actionButton`, lines 247–290 | **Repositioned**: bid grid and suit buttons render inside the table surface (the pile area is empty during the auction and trump choice), which puts them in the thumb zone above the hand. `HandSummaryView` and `matchOver` become an overlay card centred on the table surface when `phase == .finished`, with Review hand and Deal next hand beneath it. `actionButton` loses `.tint(.gold)` (gold rule 5 applies to the one prominent button only). |
| Hand | `hand`, lines 292–320 | **Rebuilt** as `HandFanView`: no horizontal `ScrollView` (six cards fit), overlap and fan per the metrics, press-lift `ButtonStyle`, legal-lift on your turn, shake on illegal tap, `matchedGeometryEffect` id = card into `PileView`, `allowsHitTesting(playable)` and accessibility values kept. "YOUR HAND" label drops below the fan in caption monospaced; DEALER badge moves to the score bar's contract line when you deal. |
| Root `ScrollView` | lines 22–44 | **Rebuilt** as a fixed `VStack`: `ScoreBarView`, `TableSurface` (`.frame(maxHeight: .infinity)`), `HandFanView`, with `.padding(.bottom)` respecting the safe area. Nothing on the gameplay screen scrolls; sheets do. The 640 pt max width stays for iPad portrait. |
| `CardView` | `CardView.swift` | **Extended**: corner index, radius 6% of width, `CardStyle` (rest / lifted / pressed / dimmed / pile / back) driving face brightness, shadow and offset. |
| `HandSummaryView` | `HandSummaryView.swift` | **Kept**, hosted in the overlay card. |

## 3. Implementation roadmap (each step ships on its own, tests green, docs updated)

1. **Theme and card faces.** Add `Theme.swift`; extend `CardView` (corner index, radius, styles, back). No layout change. Tests: `Theme` metrics (overlap leaves ≥ 44 pt), `CardView` accessibility label unchanged. Manual: hand still readable at largest Dynamic Type.
2. **Score bar.** `ScoreBarView` replaces header and score panel; gear `Menu`. Tests: existing `GameModelTests` untouched; manual screenshot.
3. **Fixed layout.** Root `VStack`; `TableSurface` placeholder holding the current trick panel and controls; hand summary and match-over move to the overlay card; bid/suit controls move into the surface. Manual: every phase fits without scrolling on the iPhone SE simulator width (375 pt) and the Catch 5 iPhone.
4. **Seats around the table.** `SeatView` placement in the `ZStack`, anchors captured with `PreferenceKey` for later flights, active-seat gold ring, card-back stacks. Manual: VoiceOver reads seats in West, Partner, East order (`accessibilitySortPriority`).
5. **Pile and flights.** `PileView` with seat offsets; computer plays enter from their seat anchor; human play flies via `matchedGeometryEffect`; hold-then-collapse to the winner; last-trick reopen glyph. Model change: none required, but the hold must be coordinated with `.task(id: revision)` (see risks). Reduce Motion path.
6. **Hand fan and press-lift.** `HandFanView`, `CardPressStyle`, legal lift on turn, shake on illegal tap (a view-local `shakeToken` per card; the model already refuses the play). Tests: none new at the model level; manual on device (this is the step to install on the phone with `scripts/install-phone.sh` and feel).
7. **Hint and Undo.** Tertiary hint button; undo toast: `GameModel` gains `lastHumanAction: PlayerAction?` set in `send`, cleared in `perform` for non-human steps; `TableView` shows `9♣ played · Undo` in the notice slot for 4 s with a `Task` timer, tapping calls `undo()`. Tests: `lastHumanActionDescribesThePlayAndClearsOnUndo`.
8. **Gold audit.** Apply the five-rule list; table of every `gold` use with keep/cut. Includes tutorial and sheets for consistency (tactic boxes and pills keep gold as "key state"? No: pills use gold only for the current lesson, which is an active indicator, rule 3; tactic boxes go ivory).
9. **Haptics pass.** Map the vocabulary onto `.sensoryFeedback` triggers on `TableView`: play (trigger `model.lastHumanAction`), illegal (`shakeToken`), trick (`completedTricks.count`, with weight by winner team), bid/trump (`revision` when phase is bidding), hand and match end (existing). Tests: model triggers only; manual on device.
10. **Docs.** `docs/architecture.md` view-layer diagram (new components), `docs/types-and-functions.md` rows, `docs/decisions.md` D33 (table-first layout and the gold rule), `docs/roadmap.md` M8.

## Where the current code makes this harder than it looks

- **Animations are keyed on `model.revision`** (`.animation(.spring, value: model.revision)`, D8). Every accepted action bumps it, including computer plays that arrive 0.3–1.8 s apart depending on `Settings.delay`. Flight durations (0.4–0.5 s) must stay shorter than the quick play speed's 300 ms follow delay or two flights overlap. Decision: the quick speed's follow delay rises to 450 ms, or flights shorten to 0.3 s at quick speed via `Theme.Motion.scale(for: playSpeed)`.
- **Hold-then-collapse needs a "trick just completed" moment the model does not expose.** `currentTrick` empties and `completedTricks.count` increments in the same `revision`. The view can derive it (count changed and current trick empty) and run the 900 ms hold inside the existing `.task(id: revision)` before `stepComputer()`; when the human won the trick, the hold ends on their first tap. No engine change.
- **`matchedGeometryEffect` requires both endpoints in one hierarchy and the source to leave in the same transaction.** The human's card leaves `humanCards` and appears in `currentTrick` in one `revision`, which is exactly that. It will not work through the current horizontal `ScrollView` clipping, which is another reason the fan drops the scroll view.
- **Undo semantics.** `undo()` rewinds to before your last action and drops computer replies (D28). With the toast auto-dismissing after 4 s and computers replying within 0.3–1.8 s, the toast will usually be shown while replies land; the collapse animation must not fight a rewind (bump `revision` cancels pending tasks, which already covers it).
- **Two "last trick" affordances collide.** Tap-to-explain (D24) relies on the last trick staying visible; the brief's collapse removes it. The reopen glyph keeps the feature; `ReviewView` remains the full record.
- **Bidding controls in the table area** depend on `TableSurface` being tall enough on small phones: bar (~88 pt) + surface + hand (~110 pt with fan) on a 667 pt-tall iPhone SE leaves about 400 pt, enough for seats plus a 4×2 bid grid at 44 pt rows, but the 9-and-out explainer line becomes a footnote inside the grid.
- **Spatial layout and VoiceOver.** The `ZStack` order is not reading order; `accessibilitySortPriority` on seats and the pile is required or M6's VoiceOver work regresses.
- **Tutorial reuses `CardView`, `SeatTile` and the felt panel styles.** Steps 1 and 8 touch it; lesson fixtures and tests are unaffected.

## Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` after every step (97 tests today plus the ones named above).
- Simulator screenshots per step on the Catch 5 iPhone and an iPhone SE-width device for each phase: auction, trump, lead, mid-trick, trick complete, hand end, match end; at default and largest Dynamic Type; with Reduce Motion on.
- On the phone via `scripts/install-phone.sh` for steps 6 and 9: feel the lift, flight, collapse and haptics; confirm legal-card lift is visible in daylight.

Sources: [Parachute thumb zone](https://parachutedesign.ca/blog/thumb-zone-ux/), [Elaris thumb zones](https://elaris.software/blog/mobile-ux-thumb-zones-2025/), [WWDC24 Design advanced games](https://developer.apple.com/videos/play/wwdc2024/10085/), [HIG Designing for games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games), [PrintNinja card dimensions](https://printninja.com/card-dimensions/), [Pure Solitaire dimensions](https://www.puresolitaire.games/blog/playing-card-dimensions-deck-size/), [5 UX lessons from a card game](https://medium.com/@acbassettone/5-ux-ui-lessons-from-designing-a-card-game-b689d3f3187), [GDKeys card UI](https://gdkeys.com/the-card-games-ui-design-of-fairtravel-battle/), [Median typography](https://median.co/blog/apples-ui-dos-and-donts-typography), [Design+Code Dynamic Type](https://designcode.io/ios-design-handbook-typography-and-dynamic-type/), [WebAIM contrast](https://webaim.org/articles/contrast/), [Muzli dark elevation](https://medium.muz.li/mastering-elevation-for-dark-ui-a-comprehensive-guide-04cc770dd0d6), [WWDC23 Animate with springs](https://developer.apple.com/videos/play/wwdc2023/10158/), [Use Your Loaf Reduce Motion](https://useyourloaf.com/blog/reducing-motion-of-animations/), [Hacking with Swift sensory feedback](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-haptic-effects-using-sensory-feedback), [Swift with Majid sensory feedback](https://swiftwithmajid.com/2023/10/10/sensory-feedback-in-swiftui/), [UIImpactFeedbackGenerator](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator), [Lofelt Core Haptics](https://medium.com/lofelt/10-things-you-should-know-about-designing-for-apple-core-haptics-9219fdebdcaa).
