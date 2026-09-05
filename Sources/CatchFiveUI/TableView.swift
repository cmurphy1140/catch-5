import CatchFive
import SwiftUI

public struct TableView: View {
    @StateObject private var model: GameModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmNewGame = false

    public init(model: GameModel) { _model = StateObject(wrappedValue: model) }

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                scores
                HStack {
                    opponent(1, name: "West")
                    Spacer()
                    opponent(2, name: "Partner")
                    Spacer()
                    opponent(3, name: "East")
                }
                Text(status).font(.subheadline).multilineTextAlignment(.center).frame(minHeight: 40)
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
            try? await Task.sleep(for: .milliseconds(model.match.hand.currentTrick.isEmpty ? 1200 : 700))
            guard !Task.isCancelled else { return }
            model.stepComputer()
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.persist() } }
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
                Text("CATCH 5").font(.system(size: 34, weight: .bold, design: .serif))
                Text("PARTNERSHIP PITCH · FIRST TO 25").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1)
            }
            Spacer()
            Text("HAND \(model.match.handNumber)").font(.caption.monospaced())
        }
    }

    private var scores: some View {
        HStack {
            score("YOU + PARTNER", value: model.match.scores[0])
            Spacer()
            VStack(spacing: 4) {
                Text(model.match.hand.trump.map { "\($0.glyph) TRUMP" } ?? "— TRUMP")
                    .font(.caption.monospaced())
                if let contract = model.contract {
                    Text(contract).font(.system(size: 9, design: .monospaced)).opacity(0.8)
                }
            }.multilineTextAlignment(.center).foregroundStyle(.gold)
            Spacer()
            score("WEST + EAST", value: model.match.scores[1])
        }.padding(16).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private func score(_ title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.system(size: 9, design: .monospaced))
            Text(value, format: .number).font(.system(size: 32, weight: .semibold, design: .serif))
        }
    }

    private func opponent(_ seat: Int, name: String) -> some View {
        VStack(spacing: 6) {
            Text(name).font(.subheadline.weight(.semibold))
            Text(seatDetail(seat)).font(.caption2).opacity(0.65)
            if model.match.hand.auction.dealer == seat { Text("DEALER").font(.system(size: 8, design: .monospaced)).foregroundStyle(.gold) }
        }.padding(12)
            .background(model.match.hand.nextSeat == seat ? .white.opacity(0.14) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    /// During the auction each seat shows its call; afterwards the bidder is marked and others show card counts.
    private func seatDetail(_ seat: Int) -> String {
        if model.match.hand.phase == .bidding { return model.latestCall(for: seat) ?? "Waiting" }
        if model.match.hand.auction.winner == seat { return "Bidder" }
        return "\(model.match.hand.hands[seat].count) cards"
    }

    private var status: String {
        if let winner = model.match.winner { return winner == 0 ? "Your team wins!" : "West + East win" }
        switch model.match.hand.phase {
        case .bidding:
            let bid = model.match.hand.auction.isNineAndOut ? "9 and out" : model.match.hand.auction.highestBid.map(String.init) ?? "none"
            return "High bid: \(bid)\n\(model.isHumanTurn ? "Your bid" : "Bidding…")"
        case .choosingTrump: return model.isHumanTurn ? "Choose trump" : "Choosing trump…"
        case .playing: return model.isHumanTurn ? "Your turn\nTap a legal card" : "Computer’s turn"
        case .finished: return "Hand complete"
        }
    }

    private var trick: some View {
        let last = model.match.hand.completedTricks.last
        let showingLast = model.match.hand.currentTrick.isEmpty && last != nil
        let plays = showingLast ? last?.plays ?? [] : model.match.hand.currentTrick
        let names = ["You", "West", "Partner", "East"]
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
                    VStack(spacing: 8) {
                        CardView(card: play.card)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(.gold, lineWidth: showingLast && last?.winner == play.seat ? 3 : 0))
                        Text(names[play.seat]).font(.caption2)
                    }
                    .transition(.asymmetric(insertion: .move(edge: Self.edge(for: play.seat)).combined(with: .opacity),
                                            removal: .opacity))
                }
                if plays.isEmpty { Text("Waiting for the first card").font(.footnote).opacity(0.45).frame(height: 96) }
            }.frame(minHeight: 96)
            .animation(.spring(duration: 0.45), value: model.revision)
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
            HandSummaryView(match: model.match)
            Button(model.match.winner == nil ? "Deal next hand" : "Play again") {
                if model.match.winner == nil { model.nextHand() } else { model.newGame() }
            }.buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
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
                            .allowsHitTesting(playable)
                            .opacity(model.match.hand.phase == .playing && !playable ? 0.5 : 1)
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .top).combined(with: .opacity)))
                    }
                }.padding(.bottom, 8)
                .animation(.spring(duration: 0.45), value: model.revision)
            }
        }
    }
}
