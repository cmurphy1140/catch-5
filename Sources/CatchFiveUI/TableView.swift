import CatchFive
import SwiftUI

/// The gameplay screen: a compact score bar, the table with seats and pile, then the hand.
/// Nothing here scrolls; sheets do. Layout and motion values come from docs/redesign-plan.md.
public struct TableView: View {
    @StateObject private var model: GameModel
    @StateObject private var tutorial: TutorialModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The seat whose name tag was tapped, and the name being typed for it (D93).
    @State private var renaming: Int?
    /// The seat whose player card is up (D151).
    @State private var carding: Int?
    /// Where the room table's far edge lies down the screen (D158), once the seats have been measured.
    @State private var tableEdge: Double?
    /// The hand-end card is up, so the rail passes behind it.
    @State private var resultCardUp = false
    /// The hand whose contract card has been read and put down (D157), by its number in the match.
    @State private var contractRead: Int?
    @State private var nameDraft = ""
    /// The rules, opened from the book in the top row (D93); they open like a book (D94).
    @State private var showRules = ScreenshotStage.name == "table-rules" || BookFold.heldProgress(stage: ScreenshotStage.name) != nil
    @State private var confirmNineAndOut = false
    @State private var showSettings = false
    @State private var showTutorial = false
    /// The full score sheet is open over the table (N66).
    @State private var scorePanel = false
    @State private var showStatistics = false
    @State private var support: SupportPresentation?
    /// A local trick request waits until chat's sheet has finished dismissing.
    @State private var supportReplay: (number: Int, revision: Int, viewerSeat: Int?)?
    @State private var learning: LearningPresentation?
    @State private var advice: LiveAdvicePresentation?
    @StateObject private var savedStatistics = SavedHandStatisticsModel()
    /// Completed tricks whose cards have already collapsed toward the winner.
    @State private var collapsedTricks = 0
    @State private var reopenedTrick: Int?
    @State private var shakes: [Card: Int] = [:]
    @State private var shakeCount = 0
    @State private var toast: PlayerAction?
    /// What the last revision changed, reduced to the one cue worth a haptic.
    @State private var cue: (id: Int, cue: TableFeedback.Cue)?
    @State private var seen: TableFeedback.Snapshot
    /// Where the deck beside the dealer rests on the table; the refill deals in from here (T12).
    @State private var dealerDeck: CGPoint?
    /// Counts hands dealt while the table is up; each one riffles once at the dealer's deck (D68).
    @State private var shuffles = 0
    /// What still plays before the match-over card: the 9-and-out screen and the cascade (D69).
    @State private var celebrating: [Celebration] = []
    /// Counts cascades begun, for their success haptic.
    @State private var cascades = 0
    /// The match has just been won; the celebration waits until the last trick has been taken (D97).
    @State private var celebrationDue = false
    /// What is in the air and what has landed (D97). View state only: derived from the match after each accepted
    /// action, never written back, and reset whenever the match moves other than one step forward.
    @State private var flightState: TableMotion
    /// The match as the motion planner last saw it.
    @State private var motionSeen: MotionSnapshot
    /// Where the seats, the pile, the deck and the hand are; read when a flight is planned, never drawn from.
    @State private var measured = TableMeasurements()
    /// The card picked in your hand by a first tap (D97).
    @State private var selected: Card?
    /// Counts taps on your spot on the table, which lay the picked card down (D116).
    @State private var layDown = 0
    /// Counts the tricks that have arrived at each place, so that face nods (D97).
    @State private var bumps: [Int: Int] = [:]
    /// When the deal now under way will have finished; the first bid waits for it.
    @State private var dealEnds: Date?
    /// A finished trick on its way to its winner, named by its collection, so a stale one never clears a newer one; the
    /// hand's result waits until it has arrived (D97).
    @State private var takingTrick: UUID?
    @AccessibilityFocusState private var statusFocused: Bool

    private let onLeave: () -> Void
    /// Home in the top row: back to the main menu, the match kept (D93).
    private let onHome: () -> Void
    /// Something outside this view covers the table (the welcome card); computers wait while it is up.
    private let covered: Bool

    public init(model: GameModel, tutorial: TutorialModel? = nil, covered: Bool = false, onLeave: @escaping () -> Void = {},
                onHome: @escaping () -> Void = {}) {
        _model = StateObject(wrappedValue: model)
        // Share the root's tutorial model when there is one, so lessons finished in the intro show as done here.
        _tutorial = StateObject(wrappedValue: tutorial ?? model.makeTutorial())
        _seen = State(initialValue: TableFeedback.Snapshot(model))
        // A restored table shows everything where it is; only a fresh match still behind its draw for dealer is dealt.
        _collapsedTricks = State(initialValue: model.match.hand.completedTricks.count)
        _flightState = State(initialValue: TableMotion(match: model.match, dealPending: Self.dealPending(model)))
        _motionSeen = State(initialValue: MotionSnapshot(match: model.match))
        self.covered = covered
        self.onLeave = onLeave
        self.onHome = onHome
    }

    /// Every reason the scheduler must wait, gathered in one place. Any sheet, dialog, cover or the
    /// reopened trick pauses play; closing one of several keeps it paused.
    private var pause: TablePause {
        TablePause(sceneActive: scenePhase == .active,
                   welcomeShown: covered,
                   sheetShown: showSettings || showTutorial || showRules || scorePanel || showStatistics || support != nil || supportReplay != nil || learning != nil || advice != nil,
                   dialogShown: renaming != nil || carding != nil || contractSummary != nil || confirmNineAndOut || model.tallyDemo != nil || model.errorMessage != nil || model.saveError != nil,
                   inspectingTrick: reopenedTrick != nil,
                   drawShown: drawShown)
    }

    /// A different cover invalidates advice; its own sheet remains a reason to pause, not a reason to dismiss.
    private var adviceBlocked: Bool {
        covered || showSettings || showTutorial || showRules || scorePanel || showStatistics || support != nil || learning != nil
            || renaming != nil || carding != nil || contractSummary != nil || confirmNineAndOut
            || model.tallyDemo != nil || model.errorMessage != nil || model.saveError != nil || reopenedTrick != nil
            || scenePhase != .active
    }

    private func openAdvice() {
        guard !pause.isPaused else { return }
        advice = model.liveAdvice()
    }

    private func validateAdvice() {
        if let advice, !advice.isValid(for: model, covered: adviceBlocked) { self.advice = nil }
    }

    private func openReplay() { openReplay(trick: nil) }

    private func openReplay(trick number: Int?) {
        guard let replay = model.handReplay(), !covered else { return }
        let initialStepID: Int?
        if let number {
            guard let stepID = ReplayTrickPresentation.firstPlayStepID(number: number, in: replay) else { return }
            initialStepID = stepID
        } else {
            initialStepID = nil
        }
        learning = LearningPresentation(start: .replay(replay, names: model.seatNames, mode: model.mode,
                                                       initialStepID: initialStepID, bottomSeat: model.bottomSeat))
    }

    /// The draw for dealer is showing: a fresh match, not yet covered, with its draw still on the table.
    private var drawShown: Bool { model.dealerDraw != nil && model.match.actionCount == 0 && !covered }

    /// The tally demo is looked for when trump is named and when the table is uncovered again.
    private struct DemoKey: Hashable {
        let trumpNamed: Bool
        let paused: Bool
    }

    /// The scheduler restarts whenever an action lands or the pause lifts, and cancels when a pause begins.
    private struct SchedulerKey: Hashable {
        let revision: Int
        let paused: Bool
    }

    public var body: some View {
        withSheets
            // Pass and play: nothing of the table shows, to the eye or to VoiceOver, until the next player is ready; and
            // VoiceOver meets only the rules while the book is open (D94).
            .accessibilityHidden(model.curtainSeat != nil || showRules)
            .overlay {
                if let seat = model.curtainSeat {
                    PassCurtainView(name: model.seatNames[seat], portrait: portraits[seat], figure: figures[seat]) {
                        withAnimation(motion(Theme.Motion.overlay)) { model.ready() }
                    }
                    .transition(.opacity)
                }
            }
            .overlay {
                if drawShown, let draw = model.dealerDraw {
                    DealerDrawView(draw: draw, names: model.seatNames, portraits: portraits, figures: figures, saysYou: model.mode == .solo) {
                        withAnimation(motion(Theme.Motion.overlay)) { model.dismissDealerDraw() }
                    }
                    .transition(.opacity)
                }
            }
            // The one bid that can end the match on its own: the partner asks, then the engine judges it at that moment (D70).
            .overlay {
                if confirmNineAndOut {
                    NineAndOutConfirm(name: NineAndOutConfirm.partnerName(model), portrait: portraits[model.partnerSeat], figure: figures[model.partnerSeat],
                                      onSure: { confirmNineAndOut = false; model.send(.nineAndOut) },
                                      onCancel: { withAnimation(motion(Theme.Motion.overlay)) { confirmNineAndOut = false } })
                        .transition(.opacity)
                }
            }
            .overlay { teamPanel }
            .overlay { rulesBook }
            .overlay { celebration }
            .transformEnvironment(\.dynamicTypeSize) { $0 = $0.boosted(by: Theme.textBoostSteps) }
            .onAppear {
                // The screenshot stages open on a match already won, so nothing announced the win.
                if ["won", "ninewin", "ninelose"].contains(ScreenshotStage.name ?? "") { celebrating = model.celebrations }
                if ScreenshotStage.name == "confirm9" { confirmNineAndOut = true }
                if ScreenshotStage.name == "panel" { scorePanel = true }
            }
    }

    /// The next celebration step over the table, each moving on by itself or at a tap (D69).
    @ViewBuilder private var celebration: some View {
        switch celebrating.first {
        case .cascade:
            CardCascade()
                .transition(.opacity)
                .task {
                    cascades += 1
                    try? await Task.sleep(for: .seconds(Celebration.cascadeSeconds))
                    guard !Task.isCancelled else { return }
                    nextCelebration()
                }
        case let .nineAndOut(result):
            NineAndOutScreen(result: result, bidderName: model.seatNames[result.bidder], onDone: nextCelebration)
                .transition(.opacity)
                .task {
                    try? await Task.sleep(for: .seconds(Celebration.nineSeconds))
                    guard !Task.isCancelled else { return }
                    nextCelebration()
                }
        case nil:
            EmptyView()
        }
    }

    /// The full score sheet, opened from the scorecard (N66).
    @ViewBuilder private var teamPanel: some View {
        if scorePanel {
            let them = 1 - model.ourTeam
            ScorePanel(us: ScorePanel.content(team: model.ourTeam, history: model.match.history, seatNames: model.seatNames),
                       them: ScorePanel.content(team: them, history: model.match.history, seatNames: model.seatNames),
                       usLabel: teamLabel(model.ourTeam), themLabel: teamLabel(them),
                       onClose: { withAnimation(motion(Theme.Motion.overlay)) { scorePanel = false } })
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// The rules, swinging onto the screen like a book's page about its left edge and back when closed (D94).
    @ViewBuilder private var rulesBook: some View {
        if showRules {
            RulebookView { closeRules() }
                // The table's type is two steps larger (N-boost); the book is set in its own sizes, as from the menu.
                .transformEnvironment(\.dynamicTypeSize) { $0 = $0.boosted(by: -Theme.textBoostSteps) }
                .modifier(BookFold(progress: BookFold.heldProgress(stage: ScreenshotStage.name) ?? 1))
                .transition(BookFold.transition(reduceMotion: reduceMotion))
                .zIndex(1)
        }
    }

    private func openRules() {
        withAnimation(reduceMotion ? Theme.Motion.reduced : .easeInOut(duration: BookFold.seconds)) { showRules = true }
    }

    private func closeSupport() {
        supportReplay = nil
        support?.invalidate()
        support = nil
    }

    private func supportDidDismiss() {
        let pending = supportReplay
        supportReplay = nil
        guard let pending, pending.revision == model.revision,
              pending.viewerSeat == model.viewerSeat else { return }
        openReplay(trick: pending.number)
    }

    private func closeRules() {
        withAnimation(reduceMotion ? Theme.Motion.reduced : .easeInOut(duration: BookFold.seconds)) { showRules = false }
        model.markRulesSeen()
    }

    private func nextCelebration() {
        guard !celebrating.isEmpty else { return }
        withAnimation(motion(Theme.Motion.overlay)) { _ = celebrating.removeFirst() }
    }

    /// The four seats' cut-out figures for the chosen cast, nil where the build has none (D170).
    private var figures: [Image?] { (0..<4).map { SeatArt.image(seat: $0, opponents: model.settings.opponents) } }

    private var portraits: [Portrait] {
        [model.settings.playerPortrait] + Cast.opponents.map(\.portrait)
    }

    /// Support opens over the table with what the player can see, from the top row or from their own face (D115).
    private func openSupport() {
        guard !covered, let context = SupportContext.visible(in: model) else { return }
        let presentation = SupportPresentation(context: context)
        if let replay = model.handReplay() {
            presentation.completedTrickNumbers = replay.steps.compactMap { step in
                if case let .trick(number, _, _) = step.event { return number }
                return nil
            }
            let revision = model.revision
            let viewerSeat = model.viewerSeat
            let presentationID = presentation.id
            presentation.onReplayTrick = { number in
                guard support?.id == presentationID, model.revision == revision,
                      model.viewerSeat == viewerSeat, !covered else { return }
                supportReplay = (number, revision, viewerSeat)
                support?.invalidate()
                support = nil
            }
        }
        support = presentation
    }

    /// Score bar, table and hand in one non-scrolling column.
    private var layout: some View {
        VStack(spacing: 6) {
            // Home on the left, the rules on the right (D93).
            TableTopRow(onHome: onHome, onRules: openRules, onSupport: openSupport, score: model.settings.tableArrangement == .classic ? nil : (model.match.scores[model.ourTeam], model.match.scores[1 - model.ourTeam]),
               onScore: { withAnimation(motion(Theme.Motion.overlay)) { scorePanel = true } })
                .padding(.horizontal, 4).padding(.top, 2).padding(.bottom, 4)
                // A solid header band: runs up behind the status bar and ends in a frown, the corners
                // hanging lower than the middle, so the bar sits on one colour and the wood starts beneath.
                .background {
                    WoodGrainView(vignette: .linear).modifier(WoodTone(colours: model.settings.tableColours))
                        .clipShape(HeaderBandShape(dip: Theme.Table.headerDip))
                        .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
                        .ignoresSafeArea(edges: .top)
                }
            TableSurface(model: model, collapsedTricks: collapsedTricks, motion: reduceMotion ? nil : flightState, selected: selected,
                         bumps: bumps, resultReady: collapsedTricks >= model.match.hand.completedTricks.count && takingTrick == nil,
                         onAnchor: { place, point in measured.geometry.seats[place] = point },
                         onPileCentre: { centre, scale in
                             measured.geometry.pileCentre = centre
                             measured.geometry.pileScale = scale
                             measured.geometry.pileRise = model.settings.tableArrangement == .classic ? Theme.Table.trickRise : TableLayout.tightRise
                         },
                         reopenedTrick: reopenedTrick, toast: toast,
                         onReopenTrick: { withAnimation(motion(Theme.Motion.collapse)) { reopenedTrick = model.match.hand.completedTricks.count } },
                         onCloseTrick: { withAnimation(motion(Theme.Motion.collapse)) { reopenedTrick = nil } },
                         onNineAndOut: { withAnimation(motion(Theme.Motion.overlay)) { confirmNineAndOut = true } },
                         onScorecard: { withAnimation(motion(Theme.Motion.overlay)) { scorePanel = true } },
                         onLayDown: { layDown += 1 },
                         onSettings: { showSettings = true },
                         onDeck: { dealerDeck = $0 },
                         onRename: rename,
                         onTableEdge: { tableEdge = $0 },
                         onResultCard: { resultCardUp = $0 },
                         holdsResult: !celebrating.isEmpty || celebrationDue,
                         onReplay: openReplay, onReplayTrick: { openReplay(trick: $0) }, onAdvice: openAdvice,
                         statusFocus: $statusFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Theme.Table.horizontalInset)
                // The hand-end card runs down over the rows below it, so the table comes forward for it.
                .zIndex(model.match.hand.phase == .finished ? 1 : 0)
            // Cards stop growing at XXXL so the fan keeps six cards on screen; the cap must sit above the
            // fan's own scaled metrics, which read it from the environment.
            HandFanView(model: model, onIllegal: shake, shakes: $shakes, selected: $selected, dealing: dealing,
                        deck: dealerDeck, onDeck: { dealerDeck = $0 }, onRename: rename, onSupport: openSupport, layDown: layDown,
                        onGeometry: { measured.geometry.hand = $0 },
                        onAnchor: { measured.geometry.seats[0] = $0 },
                        onLaunch: { card, pose in measured.launch = (card, pose) })
                .dynamicTypeSize(...Theme.Card.maximumTypeSize)
                .padding(.horizontal, Theme.Table.horizontalInset)
        }
        // The shuffle sits over the dealer's deck, in the same space the deck reports its place in.
        .overlay(alignment: .topLeading) {
            if shuffles > 0, let dealerDeck {
                RiffleShuffle().id(shuffles).position(dealerDeck)
            }
        }
        // Every card in the air, above everything on the table (D97).
        .overlay { FlightLayer(flights: flightState.flights) }
        .coordinateSpace(.named(TableLayout.space))
        .dynamicTypeSize(...Theme.maximumTableTypeSize)
        .padding(.bottom, Theme.Table.footInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The row under the hand (your name tag, and the deal when it is yours) sits down beside the home indicator,
        // which only takes the middle of the bottom edge, so the table gets that height back (N64).
        // Ivory on the oak; dark ink on the two paler woods (D118).
        .foregroundStyle(model.settings.tableColours.woodIsLight ? Theme.Wood.header : .ivory)
        // The room table (D158): the players sit behind the rail, and the felt runs from it to the bottom of the screen.
        .overlay {
            if model.settings.tableArrangement == .rail, let tableEdge {
                GeometryReader { geometry in RoomRail(top: tableEdge - geometry.frame(in: .global).minY) }.ignoresSafeArea().allowsHitTesting(false)
                    // The hand-end card stands in front of the rail: the rail shows only in the margins beside it.
                    .mask {
                        let side = Theme.Table.horizontalInset + Theme.Table.overlayInset
                        HStack(spacing: 0) {
                            Rectangle().frame(width: side)
                            Rectangle().opacity(resultCardUp ? 0 : 1)
                            Rectangle().frame(width: side)
                        }
                        .ignoresSafeArea()
                    }
                    .animation(Theme.Motion.overlay, value: resultCardUp)
            }
        }
        .background {
            ZStack {
                WoodGrainView().modifier(WoodTone(colours: model.settings.tableColours))
                if model.settings.tableArrangement == .rail, let tableEdge {
                    // The wall behind the players, in shadow, then the cloth.
                    Color.black.opacity(0.28)
                    GeometryReader { geometry in RoomFelt(top: tableEdge - geometry.frame(in: .global).minY, colours: model.settings.tableColours) }
                }
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }

    /// A tapped name tag flips up that player's card (D151); the pencil on the card asks for the seat's new name,
    /// starting from the one it wears (D93).
    private func rename(_ seat: Int) {
        withAnimation(motion(.spring(duration: 0.45, bounce: 0.25))) { carding = seat }
    }

    /// The auction to read back (D157): once trump is named and before the first card, until the player taps Play.
    private var contractSummary: ContractCard.Summary? {
        let hand = model.match.hand
        // It holds through the whole first trick, so it cannot be missed if a lead lands before the table pauses.
        guard hand.phase == .playing, hand.completedTricks.isEmpty, contractRead != model.match.handNumber, !covered else { return nil }
        return ContractCard.Summary(auction: hand.auction, trump: hand.trump, names: model.seatNames, scores: model.match.scores, ourTeam: model.ourTeam)
    }

    @ViewBuilder private var contractCard: some View {
        if let summary = contractSummary {
            ContractCard(summary: summary, portrait: portraits[summary.bidderSeat], figure: figures[summary.bidderSeat]) {
                withAnimation(motion(Theme.Motion.overlay)) { contractRead = model.match.handNumber }
            }
                .transition(.opacity)
        }
    }

    @ViewBuilder private var playerCard: some View {
        if let seat = carding {
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture { withAnimation(motion(Theme.Motion.overlay)) { carding = nil } }
                    .accessibilityLabel("Close the card").accessibilityAddTraits(.isButton)
                PlayerCard(name: model.seatNames[seat], figure: SeatArt.image(seat: seat, opponents: model.settings.opponents), item: SeatArt.named("GuestItem\(seat)"),
                           sheet: PlayerSheet(seat: seat, match: model.match)) {
                    nameDraft = model.seatNames[seat]
                    carding = nil
                    renaming = seat
                }
                .transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity).combined(with: .offset(y: 120)),
                                        removal: .opacity))
            }
            .accessibilityAddTraits(.isModal)
        }
    }

    /// US or THEM in solo, the pair's names in pass and play.
    private func teamLabel(_ team: Int) -> String {
        Scorecard.label(us: team == model.ourTeam, mode: model.mode, teamNames: model.teamNames(team))
    }

    /// One animation for the whole table per accepted action, so cards fly between hand and pile in one
    /// transaction; the scheduler task holds finished tricks and lets computers act.
    private var withScheduling: some View {
        layout
            .animation(motion(Theme.Motion.flight), value: model.revision)
            .task(id: SchedulerKey(revision: model.revision, paused: pause.isPaused)) { await advance() }
            .onChange(of: pause) { _, now in TableTrace.log("pause \(now)") }
            // Every touch on the table, whether or not a control took it (D142).
            .simultaneousGesture(SpatialTapGesture(coordinateSpace: .global).onEnded { tap in
                TableTrace.log("touch \(Int(tap.location.x)),\(Int(tap.location.y)) \(traceState)")
            })
            .onChange(of: model.match.handNumber) { _, _ in collapsedTricks = 0; reopenedTrick = nil }
            .onChange(of: model.revision) { _, revision in
                withAnimation(motion(Theme.Motion.collapse)) { reopenedTrick = nil }
                if RiffleShuffle.startsHand(model.match.hand) { shuffles += 1 }
                selected = nil
                planMotion()
                noteChanges(revision)
            }
            .onChange(of: model.lastHumanAction) { _, action in toast = action }
            .onChange(of: takingTrick) { _, _ in startCelebrationIfDue() }
    }

    /// VoiceOver hears what the screen no longer prints, and its focus follows the game.
    /// Split from `withScheduling` so older compilers type-check each chain in reasonable time.
    private var withAnnouncements: some View {
        withScheduling
            // The discards and the "bidding bolder" note are no longer printed (D98); VoiceOver hears them as they happen.
            .onChange(of: model.notice) { _, notice in if let notice { AccessibilityNotification.Announcement(notice).post() } }
            .onChange(of: model.boldNote) { _, note in if let note { AccessibilityNotification.Announcement(note).post() } }
            .onChange(of: collapsedTricks) { _, _ in startCelebrationIfDue() }
            // Focus follows the game: a lifted cover or a new turn puts VoiceOver on the status line.
            .onChange(of: covered) { _, now in if !now { statusFocused = true } }
            .onChange(of: pause.sheetShown) { _, now in if !now { statusFocused = true } }
            .onChange(of: pause.dialogShown) { _, now in if !now { statusFocused = true } }
            .onChange(of: model.isHumanTurn) { _, now in if now { statusFocused = true } }
    }

    /// The timed overlays: the toast, the bold note and the tally demo each fade on their own clock.
    private var withTimers: some View {
        withAnnouncements
            .task(id: toast) {
                guard toast != nil else { return }
                try? await Task.sleep(for: .seconds(Theme.Motion.toastSeconds))
                guard !Task.isCancelled else { return }
                withAnimation(motion(Theme.Motion.overlay)) { toast = nil }
            }
            // The bold note says its piece once and fades; the `bold` screenshot stage holds it.
            .task(id: model.boldNote) {
                guard model.boldNote != nil, ScreenshotStage.name != "bold" else { return }
                try? await Task.sleep(for: .seconds(Theme.Motion.boldNoteSeconds))
                guard !Task.isCancelled else { return }
                withAnimation(motion(Theme.Motion.overlay)) { model.clearBoldNote() }
            }
            .onChange(of: scenePhase) { _, phase in if phase != .active { model.persist() } }
            // The first time trump is named on this install, once nothing covers the table, it shows its two taps (N61).
            // Screenshot stages leave it out, except `demo`, which holds its first caption.
            .task(id: DemoKey(trumpNamed: model.match.hand.trump != nil, paused: pause.isPaused || model.curtainSeat != nil)) {
                guard ScreenshotStage.name == nil || ScreenshotStage.name == "demo", !pause.isPaused, model.curtainSeat == nil else { return }
                withAnimation(motion(Theme.Motion.overlay)) { model.beginTallyDemoIfDue() }
            }
            .task(id: model.tallyDemo) {
                guard model.tallyDemo != nil, ScreenshotStage.name != "demo" else { return }
                try? await Task.sleep(for: .seconds(TallyDemo.stepSeconds))
                guard !Task.isCancelled else { return }
                withAnimation(motion(Theme.Motion.overlay)) { model.advanceTallyDemo() }
            }
    }

    /// Two haptics only: the refusal buzz, and one outcome cue per accepted action (`TableFeedback`).
    private var withHaptics: some View {
        withTimers
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.4), trigger: shakeCount) { _, _ in model.settings.haptics }
            .sensoryFeedback(cue?.cue.feedback ?? .selection, trigger: cue?.id ?? 0) { _, _ in model.settings.haptics && cue != nil }
            .sensoryFeedback(.success, trigger: cascades) { _, _ in model.settings.haptics }
    }

    /// After each accepted action, work out what it did and pick the one cue and announcement for it.
    private func noteChanges(_ revision: Int) {
        let now = TableFeedback.Snapshot(model)
        if let picked = TableFeedback.cue(from: seen, to: now, mode: model.mode) { cue = (revision, picked) }
        // The celebration waits for the last trick to be taken (D97); `advance` starts it.
        if now.winner != nil, seen.winner == nil { celebrationDue = true }
        let handEnded = now.hands > seen.hands
        if now.tricks > seen.tricks, !handEnded, let winner = now.lastTrickWinner {
            AccessibilityNotification.Announcement("\(model.seatNames[winner]) took the hand").post()
        } else if handEnded, let outcome = model.lastHandOutcome {
            AccessibilityNotification.Announcement("\(outcome.headline). \(outcome.bidderLine)").post()
        }
        seen = now
    }

    private var withSheets: some View {
        withHaptics
            .sheet(item: $learning) { presentation in
                LearningFlowView(model: model, start: presentation.start) { learning = nil }.id(presentation.id)
            }
            .sheet(item: $advice) { presentation in
                LearningAdviceView(presentation: presentation) { advice = nil }.id(presentation.id)
            }
            .onChange(of: model.revision) { _, _ in validateAdvice() }
            .onChange(of: model.viewerSeat) { _, _ in validateAdvice() }
            .onChange(of: model.curtainSeat) { _, _ in validateAdvice() }
            .onChange(of: adviceBlocked) { _, _ in validateAdvice() }
            .sheet(item: $support, onDismiss: supportDidDismiss) { presentation in
                SupportView(presentation: presentation).id(presentation.id)
            }
            .onChange(of: model.revision) { _, _ in closeSupport() }
            .onChange(of: model.curtainSeat) { _, _ in closeSupport() }
            .onChange(of: model.viewerSeat) { _, _ in closeSupport() }
            .onChange(of: covered) { _, covered in if covered { closeSupport() } }
            .sheet(isPresented: $showSettings) { SettingsView(settings: $model.settings) }
            .sheet(isPresented: $showTutorial, onDismiss: { model.markRulesSeen() }) { TutorialView(model: tutorial) { showTutorial = false } }
            .sheet(isPresented: $showStatistics) {
                StatisticsView(stats: model.statistics, records: model.records, saved: savedStatistics.statistics,
                               savedError: savedStatistics.error, isSavedLoading: savedStatistics.isLoading) { showStatistics = false }
                    .task(id: model.archiveReadContext) { await savedStatistics.load(model) }
                    .onDisappear { savedStatistics.prepareLoading() }
            }
            .alert("Game notice", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
            // The buttons clear the error themselves; dismissal must not, or a failed Retry would go quiet.
            .alert("Could not save", isPresented: Binding(get: { model.saveError != nil }, set: { _ in })) {
                Button("Retry") { model.retrySave() }
                Button("Not now", role: .cancel) { model.saveError = nil }
            } message: { Text(model.saveError ?? "") }
            .overlay { contractCard }
            .overlay { playerCard }
            // Renaming a seat from its tag (D93); blank keeps the old name (`Settings.renameSeat`).
            .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $nameDraft)
                Button("Save") {
                    if let seat = renaming { model.settings.renameSeat(seat, to: nameDraft, passAndPlay: model.mode == .passAndPlay) }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            } message: { Text("What should this seat be called?") }
    }

    private func motion(_ animation: Animation) -> Animation { reduceMotion ? Theme.Motion.reduced : animation }

    /// What the table knows right now, for the step log (D142).
    private var traceState: String {
        let hand = model.match.hand, number = model.match.handNumber
        let landed = TableSurface.handLanded(model.humanCards, motion: flightState, handNumber: number)
        return "rev \(model.revision) hand \(number) \(hand.phase) next \(hand.nextSeat.map(String.init) ?? "-") human \(model.isHumanTurn)"
            + " paused \(pause.isPaused) landed \(landed) dealt \(flightState.dealtHand) started \(flightState.dealStarted)"
            + " flights \(flightState.flights.count) tricks \(hand.completedTricks.count) collapsed \(collapsedTricks) covered \(covered)"
    }



    /// A finished trick is worth a medium tap when our side took it, a light one otherwise.

    private func shake(_ card: Card) {
        shakes[card, default: 0] += 1
        shakeCount += 1
        model.refuse(.play(card))
        // VoiceOver hears why, as a sighted player reads it over the hand (D97).
        if let reason = model.refusal { AccessibilityNotification.Announcement(reason).post() }
    }

    /// After every accepted action: deal a fresh hand, hold a finished trick and take it to its winner, then let the
    /// next computer act. Everything here waits on the table's own pace; none of it changes the match except
    /// `stepComputer`, the one place a computer acts.
    private func advance() async {
        TableTrace.log("advance \(traceState)")
        guard !pause.isPaused else { TableTrace.log("advance stop: paused \(pause)"); return }
        let hand = model.match.hand
        if collapsedTricks > hand.completedTricks.count { collapsedTricks = hand.completedTricks.count }
        // A fresh hand is dealt round the table before anyone bids (D97); one that can no longer be dealt shows at once.
        let number = model.match.handNumber
        switch flightState.dealStep(for: hand, handNumber: number, canAnimate: !reduceMotion && model.curtainSeat == nil) {
        case .animate:
            // One beat so the new dealer's deck has said where it rests. If a bid lands meanwhile, the next run skips it.
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled else { TableTrace.log("advance cancelled before deal"); return }
            deal()
            TableTrace.log("deal started hand \(number) flights \(flightState.flights.count) ends in \(dealEnds?.timeIntervalSinceNow ?? 0)")
        case .skip:
            TableTrace.log("deal skipped hand \(number)")
            flightState.skipDeal(handNumber: number)
        case .none:
            break
        }
        if let dealEnds, dealEnds > Date() {
            try? await Task.sleep(for: .seconds(dealEnds.timeIntervalSinceNow))
            guard !Task.isCancelled else { return }
        }
        let step = TableScheduler.plan(hand: hand, collapsedTricks: collapsedTricks)
        if step.hold {
            try? await Task.sleep(for: model.settings.trickHold)
            guard !Task.isCancelled else { return }
            collect(trick: hand.completedTricks.count - 1)
            if !reduceMotion {
                try? await Task.sleep(for: .seconds(Theme.Motion.collectSeconds))
                guard !Task.isCancelled else { return }
            }
        }
        startCelebrationIfDue()
        if step.dealing {
            try? await Task.sleep(for: Theme.Motion.dealHold)
            guard !Task.isCancelled else { return }
        }
        guard !model.isHumanTurn, hand.nextSeat != nil, model.match.winner == nil else {
            TableTrace.log("advance rests: \(traceState)")
            return
        }
        try? await Task.sleep(for: model.settings.delay(leadingTrick: step.leading))
        guard !Task.isCancelled else { TableTrace.log("advance cancelled before computer"); return }
        model.stepComputer()
    }

    // MARK: Motion (D97)

    /// A won match celebrates once its last trick has reached the winner. Called whenever that could have become true,
    /// so a pause or a cancelled scheduler run can never leave the celebration, and the result behind it, waiting.
    private func startCelebrationIfDue() {
        guard celebrationDue, collapsedTricks >= model.match.hand.completedTricks.count, takingTrick == nil else { return }
        celebrationDue = false
        celebrating = model.celebrations
    }

    /// A fresh match still behind its draw for dealer is dealt once the draw is put away.
    private static func dealPending(_ model: GameModel) -> Bool {
        model.match.actionCount == 0 && model.dealerDraw != nil && RiffleShuffle.startsHand(model.match.hand)
    }

    /// The cards of your hand that are still being dealt.
    private var dealing: Set<Card> {
        guard !reduceMotion else { return [] }
        let hand = model.match.handNumber
        return Set(model.humanCards.filter { !flightState.isInHand($0, handNumber: hand) })
    }

    /// After each accepted action, decide what flies: a played card from its player to the field, or nothing; anything
    /// that is not one step forward puts every card where the match says it is.
    private func planMotion() {
        let now = MotionSnapshot(match: model.match)
        let change = MotionSnapshot.change(from: motionSeen, to: now)
        motionSeen = now
        let launch = measured.launch
        measured.launch = nil
        guard !reduceMotion else {
            flightState.reset(to: model.match)
            return
        }
        flightState.apply(change, to: model.match, dealPending: Self.dealPending(model))
        switch change {
        case let .played(play, index):
            // A trick still lying on the field when the next card is led is swept up first.
            let hand = model.match.hand
            if hand.currentTrick.count == 1, hand.completedTricks.count > collapsedTricks {
                collect(trick: hand.completedTricks.count - 1)
            }
            let from = launch?.card == play.card ? launch?.pose : nil
            if let flight = FlightPlan.play(play, index: index, place: model.place(of: play.seat), handNumber: now.handNumber,
                                            geometry: measured.geometry, launch: from) {
                fly([flight])
            } else {
                flightState.landedPlays = max(flightState.landedPlays, index + 1)
            }
        case .dealt, .quiet:
            break
        case .reset:
            collapsedTricks = model.match.hand.completedTricks.count
            dealEnds = nil
            takingTrick = nil
        }
    }

    /// Deals the current hand from the dealer's deck (D97).
    private func deal() {
        let number = model.match.handNumber
        var geometry = measured.geometry
        geometry.deck = dealerDeck
        let flights = FlightPlan.deal(dealerPlace: model.place(of: model.match.hand.auction.dealer), yourCards: model.humanCards,
                                      geometry: geometry)
        flightState.dealStarted = number
        guard !flights.isEmpty else {
            flightState.dealtHand = number
            return
        }
        fly(flights)
        dealEnds = Date().addingTimeInterval(flights.map(\.lands).max() ?? 0)
    }

    /// Takes finished trick `index` off the field: the flights carry its cards to the winner, whose face nods as they
    /// arrive. Under Reduce Motion the trick fades instead.
    private func collect(trick index: Int) {
        let hand = model.match.hand
        guard hand.completedTricks.indices.contains(index) else { return }
        if !reduceMotion {
            let trick = hand.completedTricks[index]
            let places = (0..<4).map { model.place(of: $0) }
            fly(FlightPlan.collect(trick, trickIndex: index, handNumber: model.match.handNumber, places: { places[$0] },
                                   geometry: measured.geometry))
            let winner = places[trick.winner], epoch = flightState.epoch, token = UUID()
            takingTrick = token
            Task {
                try? await Task.sleep(for: .seconds(Theme.Motion.collectSeconds))
                if takingTrick == token { takingTrick = nil }
                guard flightState.epoch == epoch else { return }
                bumps[winner, default: 0] += 1
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { collapsedTricks = hand.completedTricks.count }
        } else {
            withAnimation(Theme.Motion.reduced) { collapsedTricks = hand.completedTricks.count }
        }
    }

    /// Puts flights in the air and lands each one when its time is up. A reset in between cancels the landing.
    private func fly(_ planned: [Flight]) {
        let launched = flightState.launch(planned)
        let epoch = flightState.epoch
        for flight in launched {
            Task {
                try? await Task.sleep(for: .seconds(flight.lands))
                guard flightState.epoch == epoch else { return }
                land(flight)
            }
        }
    }

    /// A flight's end: the card it carried shows where it landed, in the same frame the flight stops being drawn.
    /// A dealt card turns face up in your hand as it lands.
    private func land(_ flight: Flight) {
        let number = model.match.handNumber
        if case .hand = flight.arrival {
            withAnimation(.easeOut(duration: 0.18)) { flightState.land(flight, handNumber: number) }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { flightState.land(flight, handNumber: number) }
        }
    }

}

/// The table's measurements, kept by reference so that measuring never redraws the table (D97).
@MainActor final class TableMeasurements {
    var geometry = TableGeometry()
    /// Where the card you are playing was when you let go of it.
    var launch: (card: Card, pose: CardPose)?
}

enum TableScheduler {
    /// Whether a finished trick still needs its hold before collapsing, whether the coming computer
    /// play is a lead (which gets the longer pause) rather than a follow, and whether the hand has
    /// just been refilled after trump (so the deal animation gets its own pause first).
    static func plan(hand: Hand, collapsedTricks: Int) -> (hold: Bool, leading: Bool, dealing: Bool) {
        // The hand's last trick is held and taken too, before its result comes up (D97).
        let hold = (hand.phase == .playing || hand.phase == .finished) && hand.currentTrick.isEmpty
            && hand.completedTricks.count > collapsedTricks
        let dealing = hand.phase == .playing && hand.currentTrick.isEmpty && hand.completedTricks.isEmpty
        return (hold, hand.currentTrick.isEmpty && !hold, dealing)
    }
}

/// The header band: square at the top, and along the bottom a frown, an arc whose ends hang `dip`
/// points lower than its middle.
struct HeaderBandShape: Shape {
    var dip: Double
    var animatableData: Double { get { dip } set { dip = newValue } }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // A quadratic curve peaks halfway between its ends and its control point.
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                          control: CGPoint(x: rect.midX, y: rect.maxY - 2 * dip))
        path.closeSubpath()
        return path
    }
}

/// The oak as it is, or toned to light tan or birch for the other colour sets (D118): the same grain, paler and less red.
struct WoodTone: ViewModifier {
    let colours: Settings.TableColours
    func body(content: Content) -> some View {
        switch colours {
        case .charcoal, .green: content.saturation(1).brightness(0)
        case .royal: content.saturation(0.7).brightness(0.2)
        case .casino: content.saturation(0.35).brightness(0.36)
        }
    }
}
