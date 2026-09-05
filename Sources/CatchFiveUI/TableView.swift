import CatchFive
import SwiftUI

/// The gameplay screen: a compact score bar, the table with seats and pile, then the hand.
/// Nothing here scrolls; sheets do. Layout and motion values come from docs/redesign-plan.md.
public struct TableView: View {
    @StateObject private var model: GameModel
    @StateObject private var tutorial: TutorialModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var cards
    @State private var confirmNewGame = false
    @State private var showSettings = false
    @State private var showTutorial = false
    @State private var showReview = false
    @State private var showScoreboard = false
    @State private var showStatistics = false
    /// Completed tricks whose cards have already collapsed toward the winner.
    @State private var collapsedTricks = 0
    @State private var reopenedTrick: Int?
    @State private var shakes: [Card: Int] = [:]
    @State private var shakeCount = 0
    @State private var toast: PlayerAction?

    private let onLeave: () -> Void
    /// Something outside this view covers the table (the welcome card); computers wait while it is up.
    private let covered: Bool

    public init(model: GameModel, covered: Bool = false, onLeave: @escaping () -> Void = {}) {
        _model = StateObject(wrappedValue: model)
        _tutorial = StateObject(wrappedValue: model.makeTutorial())
        self.covered = covered
        self.onLeave = onLeave
    }

    /// Every reason the scheduler must wait, gathered in one place. Any sheet, dialog, cover or the
    /// reopened trick pauses play; closing one of several keeps it paused.
    private var pause: TablePause {
        TablePause(sceneActive: scenePhase == .active,
                   welcomeShown: covered,
                   sheetShown: showSettings || showTutorial || showReview || showScoreboard || showStatistics,
                   dialogShown: confirmNewGame || model.errorMessage != nil || model.saveError != nil,
                   inspectingTrick: reopenedTrick != nil)
    }

    /// The scheduler restarts whenever an action lands or the pause lifts, and cancels when a pause begins.
    private struct SchedulerKey: Hashable {
        let revision: Int
        let paused: Bool
    }

    public var body: some View {
        withSheets.transformEnvironment(\.dynamicTypeSize) { $0 = $0.boosted(by: Theme.textBoostSteps) }
    }

    /// Score bar, table and hand in one non-scrolling column.
    private var layout: some View {
        VStack(spacing: 6) {
            ScoreBarView(us: model.match.scores[0], them: model.match.scores[1],
                         usLabel: teamLabel(0), themLabel: teamLabel(1),
                         handNumber: model.match.handNumber,
                         canUndo: model.canUndo, onUndo: { model.undo() },
                         onScores: { showScoreboard = true }, onSettings: { showSettings = true },
                         onStatistics: { showStatistics = true }, onTutorial: { showTutorial = true },
                         onNewGame: { confirmNewGame = true }, onLeave: onLeave)
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 14)
                // A solid header band: runs up behind the status bar and ends in a frown, the corners
                // hanging lower than the middle, so the scores sit on one colour and the wood starts beneath.
                .background {
                    WoodGrainView(vignette: .linear)
                        .clipShape(HeaderBandShape(dip: Theme.Table.headerDip))
                        .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
                        .ignoresSafeArea(edges: .top)
                }
            TableSurface(model: model, namespace: cards, collapsedTricks: collapsedTricks, reopenedTrick: reopenedTrick, toast: toast,
                         onReopenTrick: { withAnimation(motion(Theme.Motion.collapse)) { reopenedTrick = model.match.hand.completedTricks.count } },
                         onCloseTrick: { withAnimation(motion(Theme.Motion.collapse)) { reopenedTrick = nil } },
                         onReview: { showReview = true })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
            // Cards stop growing at XXXL so the fan keeps six cards on screen; the cap must sit above the
            // fan's own scaled metrics, which read it from the environment.
            HandFanView(model: model, namespace: cards, onIllegal: shake, shakes: $shakes)
                .dynamicTypeSize(...Theme.Card.maximumTypeSize)
                .padding(.horizontal, 16)
        }
        .dynamicTypeSize(...Theme.maximumTableTypeSize)
        .padding(.bottom, 6)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.ivory)
        .background(FeltView().ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    /// One animation for the whole table per accepted action, so cards fly between hand and pile in one
    /// transaction; the scheduler task holds finished tricks and lets computers act.
    private var withScheduling: some View {
        layout
            .animation(motion(Theme.Motion.flight), value: model.revision)
            .task(id: SchedulerKey(revision: model.revision, paused: pause.isPaused)) { await advance() }
            .onChange(of: model.match.handNumber) { _, _ in collapsedTricks = 0; reopenedTrick = nil }
            .onChange(of: model.revision) { _, _ in withAnimation(motion(Theme.Motion.collapse)) { reopenedTrick = nil } }
            .onChange(of: model.lastHumanAction) { _, action in toast = action }
            .task(id: toast) {
                guard toast != nil else { return }
                try? await Task.sleep(for: .seconds(Theme.Motion.toastSeconds))
                guard !Task.isCancelled else { return }
                withAnimation(motion(Theme.Motion.overlay)) { toast = nil }
            }
            .onChange(of: scenePhase) { _, phase in if phase != .active { model.persist() } }
    }

    /// The haptic vocabulary from the plan, all gated by the settings toggle.
    private var withHaptics: some View {
        withScheduling
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: model.lastHumanAction) { _, new in playHaptic(new) }
            .sensoryFeedback(.selection, trigger: model.lastHumanAction) { _, new in callHaptic(new) }
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.4), trigger: shakeCount) { _, _ in model.settings.haptics }
            .sensoryFeedback(trickFeedback, trigger: model.match.hand.completedTricks.count) { old, new in model.settings.haptics && new > old }
            .sensoryFeedback(.success, trigger: model.match.history.count) { _, new in model.settings.haptics && new > 0 }
            .sensoryFeedback(.impact(weight: .heavy), trigger: model.match.winner) { _, new in model.settings.haptics && new != nil }
    }

    private var withSheets: some View {
        withHaptics
            .sheet(isPresented: $showSettings) { SettingsView(settings: $model.settings) }
            .sheet(isPresented: $showTutorial, onDismiss: { model.markRulesSeen() }) { TutorialView(model: tutorial) { showTutorial = false } }
            .sheet(isPresented: $showReview) {
                if let review = model.handReview() {
                    ReviewView(review: review, names: model.seatNames, difficulty: model.settings.difficulty, describe: model.describe) { showReview = false }
                } else {
                    ReviewUnavailableView { showReview = false }
                }
            }
            .sheet(isPresented: $showScoreboard) { ScoreboardView(history: model.match.history, names: model.seatNames) { showScoreboard = false } }
            .sheet(isPresented: $showStatistics) { StatisticsView(stats: model.statistics, records: model.records) { showStatistics = false } }
            .alert("Game notice", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
            .alert("Could not save", isPresented: Binding(get: { model.saveError != nil }, set: { if !$0 { model.saveError = nil } })) {
                Button("Retry") { model.retrySave() }
                Button("Not now", role: .cancel) { model.saveError = nil }
            } message: { Text(model.saveError ?? "") }
            .confirmationDialog("Start over? This replaces your saved game.", isPresented: $confirmNewGame) {
                Button("Start new game", role: .destructive) { model.newGame() }
            }
    }

    private func teamLabel(_ team: Int) -> String {
        "\(model.seatNames[team]) + \(model.seatNames[team + 2])".uppercased()
    }

    private func motion(_ animation: Animation) -> Animation { reduceMotion ? Theme.Motion.reduced : animation }

    private func playHaptic(_ action: PlayerAction?) -> Bool {
        guard model.settings.haptics, let action else { return false }
        if case .play = action { return true }
        return false
    }

    private func callHaptic(_ action: PlayerAction?) -> Bool {
        guard model.settings.haptics, let action else { return false }
        if case .play = action { return false }
        return true
    }

    /// A finished trick is worth a medium tap when our side took it, a light one otherwise.
    private var trickFeedback: SensoryFeedback {
        (model.match.hand.completedTricks.last?.winner ?? 1) % 2 == 0
            ? .impact(weight: .medium, intensity: 0.9) : .impact(weight: .light, intensity: 0.7)
    }

    private func shake(_ card: Card) {
        shakes[card, default: 0] += 1
        shakeCount += 1
    }

    /// After every accepted action: hold a finished trick, collapse it, then let the next computer act.
    private func advance() async {
        guard !pause.isPaused else { return }
        let hand = model.match.hand
        if collapsedTricks > hand.completedTricks.count { collapsedTricks = hand.completedTricks.count }
        let step = TableScheduler.plan(hand: hand, collapsedTricks: collapsedTricks)
        if step.hold {
            try? await Task.sleep(for: Theme.Motion.trickHold)
            guard !Task.isCancelled else { return }
            withAnimation(motion(Theme.Motion.collapse)) { collapsedTricks = hand.completedTricks.count }
        }
        if step.dealing {
            try? await Task.sleep(for: Theme.Motion.dealHold)
            guard !Task.isCancelled else { return }
        }
        guard !model.isHumanTurn, hand.nextSeat != nil, model.match.winner == nil else { return }
        try? await Task.sleep(for: model.settings.delay(leadingTrick: step.leading))
        guard !Task.isCancelled else { return }
        model.stepComputer()
    }

}

enum TableScheduler {
    /// Whether a finished trick still needs its hold before collapsing, whether the coming computer
    /// play is a lead (which gets the longer pause) rather than a follow, and whether the hand has
    /// just been refilled after trump (so the deal animation gets its own pause first).
    static func plan(hand: Hand, collapsedTricks: Int) -> (hold: Bool, leading: Bool, dealing: Bool) {
        let hold = hand.phase == .playing && hand.currentTrick.isEmpty && hand.completedTricks.count > collapsedTricks
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
