import CatchFive
import SwiftUI

public struct TableView: View {
    @StateObject private var model: GameModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmNewGame = false
    @State private var showSettings = false
    @State private var showTutorial = false
    @StateObject private var tutorial: TutorialModel
    @State private var showReview = false
    @State private var showScoreboard = false
    @State private var showStatistics = false

    public init(model: GameModel) {
        _model = StateObject(wrappedValue: model)
        _tutorial = StateObject(wrappedValue: model.makeTutorial())
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                scores
                HStack {
                    opponent(1)
                    Spacer()
                    opponent(2)
                    Spacer()
                    opponent(3)
                }
                Text(status).font(.subheadline).multilineTextAlignment(.center).frame(minHeight: 40)
                if let notice = model.notice { Text(notice).font(.caption).foregroundStyle(.gold.opacity(0.85)) }
                if model.isHumanTurn || model.canUndo { hintRow }
                if model.match.hand.phase == .playing || model.match.hand.phase == .finished { trick }
                if !model.humanCards.isEmpty { hand }
                controls
                Button("Start a new game") { confirmNewGame = true }
                    .font(.footnote).tint(.ivory.opacity(0.65))
            }
            .padding(20).frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.ivory)
        .background(LinearGradient(colors: [.felt, .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task(id: model.revision) {
            guard !model.isHumanTurn, model.match.hand.nextSeat != nil, model.match.winner == nil else { return }
            try? await Task.sleep(for: model.settings.delay(leadingTrick: model.match.hand.currentTrick.isEmpty))
            guard !Task.isCancelled else { return }
            model.stepComputer()
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.persist() } }
        .sensoryFeedback(.impact(weight: .light), trigger: model.match.hand.completedTricks.count) { _, _ in model.settings.haptics }
        .sensoryFeedback(.success, trigger: model.match.history.count) { _, _ in model.settings.haptics }
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

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CATCH 5").font(.system(.largeTitle, design: .serif).weight(.bold))
                Text("PARTNERSHIP PITCH · FIRST TO 25").font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("HAND \(model.match.handNumber)").font(.caption.monospaced())
                HStack(spacing: 14) {
                    Button { showStatistics = true } label: { Image(systemName: "chart.bar") }
                        .accessibilityLabel("Statistics")
                    Button { showTutorial = true } label: { Image(systemName: "book") }
                        .accessibilityLabel("How to play")
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }.tint(.ivory.opacity(0.7))
            }
        }
    }

    private var scores: some View {
        Button { showScoreboard = true } label: { scorePanel }
            .buttonStyle(.plain)
            .accessibilityHint("Shows every hand of this match")
    }

    private var scorePanel: some View {
        HStack {
            score(team(0), value: model.match.scores[0])
            Spacer()
            VStack(spacing: 4) {
                Text(model.match.hand.trump.map { "\($0.glyph) TRUMP" } ?? "— TRUMP")
                    .font(.caption.monospaced())
                if let contract = model.contract {
                    Text(contract).font(.system(.caption2, design: .monospaced)).opacity(0.8)
                }
            }.multilineTextAlignment(.center).foregroundStyle(.gold)
            Spacer()
            score(team(1), value: model.match.scores[1])
        }.padding(16).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
    }

    private func team(_ index: Int) -> String {
        "\(model.seatNames[index]) + \(model.seatNames[index + 2])".uppercased()
    }

    private func score(_ title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.system(.caption2, design: .monospaced))
            Text(value, format: .number).font(.system(.title, design: .serif).weight(.semibold))
        }.accessibilityElement(children: .combine)
    }

    private func opponent(_ seat: Int) -> some View {
        VStack(spacing: 6) {
            Text(model.seatNames[seat]).font(.subheadline.weight(.semibold))
            Text(seatDetail(seat)).font(.caption2).opacity(0.65)
            if model.match.hand.auction.dealer == seat { Text("DEALER").font(.system(.caption2, design: .monospaced)).foregroundStyle(.gold) }
        }.padding(12)
            .background(model.match.hand.nextSeat == seat ? .white.opacity(0.14) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(seatSummary(seat))
    }

    /// One VoiceOver sentence per seat tile: name, detail, dealer and whose turn it is.
    private func seatSummary(_ seat: Int) -> String {
        var parts = [model.seatNames[seat], seatDetail(seat)]
        if model.match.hand.auction.dealer == seat { parts.append("dealer") }
        if model.match.hand.nextSeat == seat { parts.append("to act") }
        return parts.joined(separator: ", ")
    }

    /// During the auction each seat shows its call; afterwards the bidder is marked and others show card counts.
    private func seatDetail(_ seat: Int) -> String {
        if model.match.hand.phase == .bidding { return model.latestCall(for: seat) ?? "Waiting" }
        if model.match.hand.auction.winner == seat { return "Bidder" }
        return "\(model.match.hand.hands[seat].count) cards"
    }

    /// One tap shows what the computer strategy would do from your seat and why.
    @ViewBuilder private var hintRow: some View {
        if let hint = model.hint {
            Text(hint.reason)
                .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.gold)
                .padding(12).frame(maxWidth: .infinity)
                .background(.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gold.opacity(0.4)))
                .accessibilityLabel("Hint: \(hint.reason)")
        } else {
            HStack(spacing: 12) {
                if model.isHumanTurn {
                    Button { model.showHint() } label: { Label("Hint", systemImage: "lightbulb") }
                }
                if model.canUndo {
                    // Rewinds the replay log to just before your last action, dropping the replies after it.
                    Button { model.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                }
            }.font(.footnote).tint(.gold).buttonStyle(.bordered)
        }
    }

    private var status: String {
        if let winner = model.match.winner { return winner == 0 ? "Your team wins!" : "\(model.seatNames[1]) + \(model.seatNames[3]) win" }
        let actor = model.match.hand.nextSeat.map { model.seatNames[$0] } ?? ""
        switch model.match.hand.phase {
        case .bidding:
            let bid = model.match.hand.auction.isNineAndOut ? "9 and out" : model.match.hand.auction.highestBid.map(String.init) ?? "none"
            return "High bid: \(bid)\n\(model.isHumanTurn ? "Your bid" : "\(actor) is bidding")"
        case .choosingTrump: return model.isHumanTurn ? "Choose trump" : "\(actor) is choosing trump"
        case .playing: return model.isHumanTurn ? "Your turn\nTap a legal card" : "\(actor) is thinking"
        case .finished: return "Hand complete"
        }
    }

    private var trick: some View {
        let last = model.match.hand.completedTricks.last
        let showingLast = model.match.hand.currentTrick.isEmpty && last != nil
        let plays = showingLast ? last?.plays ?? [] : model.match.hand.currentTrick
        let names = model.seatNames
        return VStack(spacing: 12) {
            Text(showingLast ? "LAST TRICK" : "ON THE TABLE")
                .font(.caption2.monospaced()).tracking(2).opacity(0.6)
            if showingLast, let winner = last?.winner {
                let leads = model.match.hand.phase == .playing ? " and lead\(winner == 0 ? "" : "s") next" : ""
                Text("\(names[winner]) took it\(leads)")
                    .font(.footnote).foregroundStyle(.gold)
            }
            HStack(spacing: 12) {
                // Cards are unique within a hand, so keying by card lets a new trick replace the last one.
                ForEach(plays, id: \.card) { play in
                    // Tap a played card to hear why that seat played it.
                    Button { model.explain(play, inLastTrick: showingLast) } label: {
                        VStack(spacing: 8) {
                            CardView(card: play.card)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(.gold, lineWidth: showingLast && last?.winner == play.seat ? 3 : 0))
                            Text(names[play.seat]).font(.caption2)
                        }
                    }.buttonStyle(.plain).foregroundStyle(.ivory)
                    .accessibilityLabel(model.spokenDescription(of: play, winner: showingLast ? last?.winner : nil))
                    .accessibilityHint("Explains why this card was played")
                    .transition(reduceMotion ? .opacity
                                : .asymmetric(insertion: .move(edge: Self.edge(for: play.seat)).combined(with: .opacity), removal: .opacity))
                }
                if plays.isEmpty { Text("Waiting for the first card").font(.footnote).opacity(0.45).frame(height: 96) }
            }.frame(minHeight: 96)
            .animation(.spring(duration: 0.45), value: model.revision)
            if let explanation = model.explanation {
                Text(explanation).font(.footnote).multilineTextAlignment(.center).foregroundStyle(.gold)
                    .padding(.horizontal, 16)
            } else if !plays.isEmpty {
                Text("Tap a card to see why it was played").font(.caption2).opacity(0.4)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 20)
            .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.08)))
    }

    /// Played cards enter from the side of the table their seat occupies.
    private static func edge(for seat: Int) -> Edge {
        switch seat {
        case 1: .leading
        case 2: .top
        case 3: .trailing
        default: .bottom
        }
    }

    @ViewBuilder private var controls: some View {
        if model.match.hand.phase == .finished {
            if let winner = model.match.winner { matchOver(winner) }
            HandSummaryView(match: model.match, names: model.seatNames)
            HStack(spacing: 12) {
                Button { showReview = true } label: { Label("Review hand", systemImage: "list.bullet.rectangle") }
                    .buttonStyle(.bordered).tint(.gold)
                Button(model.match.winner == nil ? "Deal next hand" : "Play again") {
                    if model.match.winner == nil { model.nextHand() } else { model.newGame() }
                }.buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
            }
        } else if model.isHumanTurn && model.match.hand.phase == .bidding {
            VStack(spacing: 12) {
                Text("How many points can your team take?").font(.footnote)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(2...9, id: \.self) { bid in actionButton(String(bid), action: .bid(bid)) }
                }
                HStack { actionButton("Pass", action: .bid(nil)); actionButton("9 and out", action: .nineAndOut) }
                Text("9 and out: take all nine or lose the game.").font(.caption2).opacity(0.6)
            }
        } else if model.isHumanTurn && model.match.hand.phase == .choosingTrump {
            HStack { ForEach(Suit.allCases, id: \.self) { suit in actionButton(suit.glyph, action: .chooseTrump(suit)) } }
        }
    }

    /// The card shown once a team reaches 25 or a 9-and-out resolves.
    private func matchOver(_ winner: Int) -> some View {
        let performance = model.finalPerformance
        return VStack(spacing: 8) {
            Text(winner == 0 ? "YOU WIN THE MATCH" : "\(model.seatNames[1]) + \(model.seatNames[3]) WIN").font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(2)
            Text("\(model.match.scores[0]) – \(model.match.scores[1]) after \(model.match.history.count) hands").font(.title3.weight(.semibold))
            if let performance {
                Text("You made \(performance.bidsMade) of \(performance.bids) contracts and played the strategy's card \(performance.playsAgreed) of \(performance.plays) times.")
                    .font(.footnote).multilineTextAlignment(.center).opacity(0.8)
            }
        }.padding(16).frame(maxWidth: .infinity).foregroundStyle(.gold)
            .background(.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.gold.opacity(0.4)))
    }

    private func actionButton(_ label: String, action: PlayerAction) -> some View {
        Button(label) { model.send(action) }.buttonStyle(.bordered).tint(.gold)
            .disabled(!model.allows(action)).frame(minHeight: 44)
    }

    private var hand: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YOUR HAND").font(.caption.monospaced()).tracking(1)
                Spacer()
                if model.match.hand.phase == .bidding, let call = model.latestCall(for: 0) {
                    Text(call.uppercased()).font(.caption2.monospaced()).opacity(0.65)
                }
                if model.match.hand.auction.dealer == 0 { Text("DEALER").font(.caption2.monospaced()).foregroundStyle(.gold) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.humanCards, id: \.self) { card in
                        // Hit testing rather than .disabled keeps the hand readable while bidding.
                        let playable = model.allows(.play(card))
                        Button { model.send(.play(card)) } label: { CardView(card: card) }
                            .buttonStyle(.plain)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(.gold, lineWidth: model.hint?.action == .play(card) ? 3 : 0))
                            .allowsHitTesting(playable)
                            .opacity(model.match.hand.phase == .playing && !playable ? 0.5 : 1)
                            .accessibilityValue(model.accessibilityValue(for: card))
                            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity, removal: .move(edge: .top).combined(with: .opacity)))
                    }
                }.padding(.bottom, 8)
                .animation(.spring(duration: 0.45), value: model.revision)
            }
        }
    }
}
