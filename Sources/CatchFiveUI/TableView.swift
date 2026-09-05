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

    public init(model: GameModel) {
        _model = StateObject(wrappedValue: model)
        _tutorial = StateObject(wrappedValue: model.makeTutorial())
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
                         onNewGame: { confirmNewGame = true })
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12)
                // A solid header band: runs up behind the status bar and curves off at the bottom, so the
                // scores sit on one colour and the wood starts beneath it.
                .background {
                    UnevenRoundedRectangle(bottomLeadingRadius: Theme.Table.headerCornerRadius,
                                           bottomTrailingRadius: Theme.Table.headerCornerRadius, style: .continuous)
                        .fill(Theme.Wood.inlay)
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                        .ignoresSafeArea(edges: .top)
                }
            TableSurface(model: model, namespace: cards, collapsedTricks: collapsedTricks, reopenedTrick: reopenedTrick,
                         onReopenTrick: { withAnimation(motion(Theme.Motion.collapse)) { reopenedTrick = model.match.hand.completedTricks.count } },
                         onReview: { showReview = true })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
            toastSlot
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
        .background(WoodGrainView())
        .preferredColorScheme(.dark)
    }

    /// One animation for the whole table per accepted action, so cards fly between hand and pile in one
    /// transaction; the scheduler task holds finished tricks and lets computers act.
    private var withScheduling: some View {
        layout
            .animation(motion(Theme.Motion.flight), value: model.revision)
            .task(id: model.revision) { await advance() }
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
            .onAppear { if model.needsRulesIntroduction { showTutorial = true } }
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
        let hand = model.match.hand
        if collapsedTricks > hand.completedTricks.count { collapsedTricks = hand.completedTricks.count }
        let step = TableScheduler.plan(hand: hand, collapsedTricks: collapsedTricks)
        if step.hold {
            try? await Task.sleep(for: Theme.Motion.trickHold)
            guard !Task.isCancelled else { return }
            withAnimation(motion(Theme.Motion.collapse)) { collapsedTricks = hand.completedTricks.count }
        }
        guard !model.isHumanTurn, hand.nextSeat != nil, model.match.winner == nil else { return }
        try? await Task.sleep(for: model.settings.delay(leadingTrick: step.leading))
        guard !Task.isCancelled else { return }
        model.stepComputer()
    }

    /// Between the table and the hand: the undo toast after your play (with any notice), a notice on its
    /// own, or your standing call during the auction.
    @ViewBuilder private var toastSlot: some View {
        ZStack {
            if let toast, model.canUndo {
                HStack(spacing: 12) {
                    Text([model.describe(toast), model.notice].compactMap { $0 }.joined(separator: " · ")).font(.footnote).lineLimit(1)
                    Button("Undo") { model.undo() }.font(.footnote.weight(.semibold)).tint(.ivory)
                        .accessibilityHint("Takes back your last action and the replies after it")
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(.ivory.opacity(0.12), in: Capsule())
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            } else if let notice = model.notice {
                Text(notice).font(.caption).opacity(0.8)
            } else if model.match.hand.phase == .bidding, let call = model.latestCall(for: 0) {
                Text("You: \(call)").font(.caption).opacity(0.8)
            }
        }
        .frame(height: 28)
        .animation(motion(Theme.Motion.overlay), value: toast)
    }
}

/// The scheduler's decisions, kept pure so they can be tested without a view.
enum TableScheduler {
    /// Whether a finished trick still needs its hold before collapsing, and whether the coming
    /// computer play is a lead (which gets the longer pause) rather than a follow.
    static func plan(hand: Hand, collapsedTricks: Int) -> (hold: Bool, leading: Bool) {
        let hold = hand.phase == .playing && hand.currentTrick.isEmpty && hand.completedTricks.count > collapsedTricks
        return (hold, hand.currentTrick.isEmpty && !hold)
    }
}
