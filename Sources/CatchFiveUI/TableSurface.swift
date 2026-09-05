import CatchFive
import SwiftUI

/// The playing surface: partner across the top, West and East at the sides, the pile in the middle,
/// the status line and explanations under it, and the phase controls where the pile sits during the auction.
struct TableSurface: View {
    @ObservedObject var model: GameModel
    let namespace: Namespace.ID
    /// Completed tricks that have already collapsed toward their winner.
    let collapsedTricks: Int
    /// A completed trick the player asked to see again.
    let reopenedTrick: Int?
    let onReopenTrick: () -> Void
    let onReview: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hand: Hand { model.match.hand }

    /// Which plays the pile shows, and the winner if they are a finished trick.
    private var pile: (plays: [Play], winner: Int?, isLast: Bool) {
        if !hand.currentTrick.isEmpty { return (hand.currentTrick, nil, false) }
        guard let last = hand.completedTricks.last else { return ([], nil, false) }
        let count = hand.completedTricks.count
        if count > collapsedTricks || reopenedTrick == count { return (last.plays, last.winner, true) }
        return ([], nil, false)
    }

    var body: some View {
        GeometryReader { geometry in
            let reach = CGSize(width: geometry.size.width / 2 + 40, height: geometry.size.height / 2 + 40)
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                SeatView(model: model, seat: 2).accessibilitySortPriority(20)
                HStack(alignment: .center) {
                    SeatView(model: model, seat: 1).accessibilitySortPriority(30)
                    Spacer(minLength: 4)
                    centre(reach: reach)
                    Spacer(minLength: 4)
                    SeatView(model: model, seat: 3).accessibilitySortPriority(10)
                }
                statusLine.accessibilitySortPriority(4)
                commentary
                if model.isHumanTurn, hand.phase == .bidding { bidding }
                if model.isHumanTurn, hand.phase == .choosingTrump { trumpChoice }
                Spacer(minLength: 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay { if hand.phase == .finished { finishedCard } }
        }
    }

    // MARK: Pile

    @ViewBuilder private func centre(reach: CGSize) -> some View {
        let pile = pile
        ZStack {
            // Reserve the pile's footprint so the layout does not jump between phases.
            Color.clear.frame(width: Theme.Card.pileWidth + 64, height: Theme.Card.pileWidth * Theme.Card.ratio + 48)
            ForEach(pile.plays, id: \.card) { play in
                Button { model.explain(play, inLastTrick: pile.isLast) } label: {
                    CardView(card: play.card, width: Theme.Card.pileWidth, style: .pile)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Card.radius(width: Theme.Card.pileWidth), style: .continuous)
                            .stroke(.gold, lineWidth: pile.winner == play.seat ? 3 : 0))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.spokenDescription(of: play, winner: pile.winner))
                .accessibilityHint("Explains why this card was played")
                .offset(Self.pileOffset(for: play.seat))
                .matchedGeometryEffect(id: play.card, in: namespace)
                .transition(transition(for: play, winner: pile.winner, reach: reach))
                .zIndex(Double(pile.plays.firstIndex(where: { $0.card == play.card }) ?? 0))
            }
            if pile.plays.isEmpty, hand.phase == .playing, !model.isHumanTurn || hand.completedTricks.isEmpty {
                Text(hand.completedTricks.isEmpty ? "First lead" : "").font(.caption2).opacity(0.35)
            }
        }
        .accessibilitySortPriority(5)
    }

    /// Where each seat's card rests on the pile: nudged toward the seat that played it.
    static func pileOffset(for seat: Int) -> CGSize {
        switch seat {
        case 1: CGSize(width: -30, height: 4)
        case 2: CGSize(width: 0, height: -22)
        case 3: CGSize(width: 30, height: 4)
        default: CGSize(width: 0, height: 24)
        }
    }

    /// Unit direction from the pile toward a seat.
    static func direction(for seat: Int) -> CGSize {
        switch seat {
        case 1: CGSize(width: -1, height: 0)
        case 2: CGSize(width: 0, height: -1)
        case 3: CGSize(width: 1, height: 0)
        default: CGSize(width: 0, height: 1)
        }
    }

    /// A computer's card arrives from its seat; a finished trick leaves toward the winner's seat.
    /// The human's own card is moved by `matchedGeometryEffect` from the hand instead.
    private func transition(for play: Play, winner: Int?, reach: CGSize) -> AnyTransition {
        if reduceMotion { return .opacity }
        let from = Self.direction(for: play.seat)
        let to = Self.direction(for: winner ?? play.seat)
        let insertion: AnyTransition = play.seat == 0 ? .identity
            : .offset(x: from.width * reach.width, y: from.height * reach.height).combined(with: .opacity)
        let removal: AnyTransition = .offset(x: to.width * reach.width, y: to.height * reach.height)
            .combined(with: .scale(scale: 0.5)).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }

    // MARK: Status, hints, explanations

    private var statusLine: some View {
        HStack(spacing: 8) {
            // Left: reopen the last trick when the pile is clear. Right: the hint on your turn.
            if pile.plays.isEmpty, hand.completedTricks.last != nil, hand.phase == .playing, reopenedTrick == nil {
                smallButton("rectangle.stack", label: "Show the last trick", action: onReopenTrick)
            } else {
                Spacer().frame(width: 44, height: 44)
            }
            statusText.font(.subheadline).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            if model.isHumanTurn, hand.phase != .finished {
                smallButton("lightbulb", label: "Hint") { model.showHint() }
            } else {
                Spacer().frame(width: 44, height: 44)
            }
        }
    }

    /// A tertiary control: a 28pt circle inside a 44pt hit area.
    private func smallButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.caption)
                .frame(width: 28, height: 28)
                .background(.ivory.opacity(0.1), in: Circle())
                .overlay(Circle().stroke(.ivory.opacity(0.35)))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var statusText: Text {
        if let winner = model.match.winner {
            return Text(winner == 0 ? "Your team wins the match" : "\(model.seatNames[1]) + \(model.seatNames[3]) win the match")
        }
        let actor = hand.nextSeat.map { model.seatNames[$0] } ?? ""
        switch hand.phase {
        case .bidding:
            let bid = hand.auction.isNineAndOut ? "9 and out" : hand.auction.highestBid.map(String.init) ?? "none"
            return model.isHumanTurn ? Text("Your bid").foregroundStyle(.gold) + Text(" · high bid \(bid)")
                : Text("\(actor) is bidding · high bid \(bid)")
        case .choosingTrump:
            return model.isHumanTurn ? Text("Choose trump").foregroundStyle(.gold) : Text("\(actor) is choosing trump")
        case .playing:
            let trump = hand.trump.map { " · \($0.glyph) trump" } ?? ""
            return model.isHumanTurn ? Text("Your turn").foregroundStyle(.gold) + Text(trump) : Text("\(actor) is thinking\(trump)")
        case .finished:
            return Text("Hand complete")
        }
    }

    @ViewBuilder private var commentary: some View {
        let text = model.hint?.reason ?? model.explanation
        Text(text ?? (pile.plays.isEmpty ? " " : "Tap a card to see why it was played"))
            .font(.footnote).multilineTextAlignment(.center)
            .foregroundStyle(.ivory.opacity(text == nil ? 0.35 : 0.85))
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .top)
            .padding(.horizontal, 8)
            .accessibilityLabel(text.map { model.hint != nil ? "Hint: \($0)" : $0 } ?? "")
    }

    // MARK: Phase controls

    private var bidding: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(2...9, id: \.self) { bid in actionButton(String(bid), action: .bid(bid)) }
            }
            HStack { actionButton("Pass", action: .bid(nil)); actionButton("9 and out", action: .nineAndOut) }
            Text("9 and out: take all nine or lose the game.").font(.caption2).opacity(0.5)
        }
    }

    private var trumpChoice: some View {
        HStack { ForEach(Suit.allCases, id: \.self) { suit in actionButton(suit.glyph, action: .chooseTrump(suit)) } }
    }

    private func actionButton(_ label: String, action: PlayerAction) -> some View {
        Button(label) { model.send(action) }.buttonStyle(.bordered).tint(.ivory.opacity(0.8))
            .disabled(!model.allows(action)).frame(minHeight: 44)
    }

    // MARK: Hand end

    private var finishedCard: some View {
        VStack(spacing: 12) {
            if let winner = model.match.winner { matchOver(winner) }
            HandSummaryView(match: model.match, names: model.seatNames)
            HStack(spacing: 12) {
                Button(action: onReview) { Label("Review hand", systemImage: "list.bullet.rectangle") }
                    .buttonStyle(.bordered).tint(.ivory.opacity(0.8))
                Button(model.match.winner == nil ? "Deal next hand" : "Play again") {
                    if model.match.winner == nil { model.nextHand() } else { model.newGame() }
                }.buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
            }
        }
        .padding(16)
        .background(Color.felt.opacity(0.94), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.ivory.opacity(0.15)))
        .padding(12)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilitySortPriority(40)
    }

    /// The card shown once a team reaches 25 or a 9-and-out resolves.
    private func matchOver(_ winner: Int) -> some View {
        VStack(spacing: 6) {
            Text(winner == 0 ? "YOU WIN THE MATCH" : "\(model.seatNames[1]) + \(model.seatNames[3]) WIN")
                .font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(2)
            Text("\(model.match.scores[0]) – \(model.match.scores[1]) after \(model.match.history.count) hands").font(.title3.weight(.semibold))
            if let performance = model.finalPerformance {
                Text("You made \(performance.bidsMade) of \(performance.bids) contracts and played the strategy's card \(performance.playsAgreed) of \(performance.plays) times.")
                    .font(.footnote).multilineTextAlignment(.center).opacity(0.8)
            }
        }.foregroundStyle(.gold)
    }
}

/// One opponent: name, what they have shown (their call, or a stack of card backs with a count), dealer badge.
/// A gold ring marks the seat whose turn it is.
struct SeatView: View {
    @ObservedObject var model: GameModel
    let seat: Int

    private var hand: Hand { model.match.hand }
    private var active: Bool { hand.nextSeat == seat && model.match.winner == nil }

    var body: some View {
        VStack(spacing: 4) {
            Text(model.seatNames[seat]).font(.subheadline.weight(.semibold)).lineLimit(1)
            if hand.phase == .bidding {
                Text(model.latestCall(for: seat) ?? "Waiting").font(.caption).opacity(0.75).frame(height: 30)
            } else {
                ZStack {
                    ForEach(0..<min(3, max(1, hand.hands[seat].count)), id: \.self) { index in
                        CardBackView(width: Theme.Card.backWidth * 0.55)
                            .offset(x: Double(index) * 4 - 4)
                    }
                    if hand.hands[seat].isEmpty { Color.clear.frame(width: 22, height: 33) }
                    Text(hand.hands[seat].count, format: .number).font(.caption2.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.black.opacity(0.55), in: Capsule())
                        .offset(x: 14, y: 12)
                }.frame(height: 36)
            }
            HStack(spacing: 4) {
                if hand.auction.dealer == seat { Text("DEALER").font(.system(.caption2, design: .monospaced)).foregroundStyle(.gold) }
                if hand.auction.winner == seat, hand.phase != .bidding { Text("BIDDER").font(.system(.caption2, design: .monospaced)).opacity(0.7) }
            }.frame(height: 14)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(minWidth: 84)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.gold, lineWidth: active ? 2 : 0))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    private var summary: String {
        var parts = [model.seatNames[seat]]
        if hand.phase == .bidding { parts.append(model.latestCall(for: seat) ?? "waiting") }
        else if hand.auction.winner == seat { parts.append("bidder, \(hand.hands[seat].count) cards") }
        else { parts.append("\(hand.hands[seat].count) cards") }
        if hand.auction.dealer == seat { parts.append("dealer") }
        if active { parts.append("to act") }
        return parts.joined(separator: ", ")
    }
}
