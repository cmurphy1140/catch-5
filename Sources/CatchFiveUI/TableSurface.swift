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
    /// The human's latest action while its undo toast is showing.
    let toast: PlayerAction?
    let onReopenTrick: () -> Void
    let onCloseTrick: () -> Void
    let onReview: () -> Void
    /// The 9-and-out pill asks the table to confirm before the bid is sent.
    let onNineAndOut: () -> Void
    /// VoiceOver focus lands on the status line when a cover lifts or the turn changes.
    let statusFocus: AccessibilityFocusState<Bool>.Binding
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

    private var inAuction: Bool { hand.phase == .bidding || hand.phase == .choosingTrump }

    var body: some View {
        GeometryReader { geometry in
            let reach = CGSize(width: geometry.size.width / 2 + 40, height: geometry.size.height / 2 + 40)
            // Scrolls only when the content cannot fit, which happens at accessibility text sizes.
            ScrollView(.vertical, showsIndicators: false) {
                // Three groups spread over the full height: the contract under the header, the seats and
                // pile in the middle, and the status line with its controls down by the hand.
                VStack(spacing: 6) {
                    HStack { contractPill.accessibilitySortPriority(25); Spacer(minLength: 0) }
                    Spacer(minLength: 4)
                    SeatView(model: model, seat: 2).accessibilitySortPriority(20)
                    // The side tiles give way before the pile can touch them (`TableLayout`).
                    let sideWidth = TableLayout.sideSeatWidth(available: geometry.size.width)
                    HStack(alignment: .center) {
                        SeatView(model: model, seat: 1, width: sideWidth).accessibilitySortPriority(30)
                        Spacer(minLength: TableLayout.seatGap)
                        if !inAuction { centre(reach: reach) }
                        Spacer(minLength: TableLayout.seatGap)
                        SeatView(model: model, seat: 3, width: sideWidth).accessibilitySortPriority(10)
                    }
                    Spacer(minLength: 4)
                    statusLine.accessibilitySortPriority(4)
                    if model.isHumanTurn, hand.phase == .bidding { bidding }
                    if model.isHumanTurn, hand.phase == .choosingTrump { trumpChoice }
                    commentary
                }
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: geometry.size.width, height: geometry.size.height)
            // The stock sits in the top-right corner of the table; refills deal in from here.
            .overlay(alignment: .topTrailing) { DeckView(remaining: hand.stock.count).padding(.top, 6) }
            // The finished hand's card takes over the table; what is underneath fades back and leaves the
            // accessibility tree, so VoiceOver meets the card and nothing behind it.
            .opacity(hand.phase == .finished ? 0.12 : 1)
            .accessibilityHidden(hand.phase == .finished)
            .overlay { if hand.phase == .finished { finishedCard } }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Pile

    @ViewBuilder private func centre(reach: CGSize) -> some View {
        let pile = pile
        ZStack {
            // Reserve the pile's footprint so the layout does not jump between phases.
            Color.clear.frame(width: TableLayout.pileReservation, height: Theme.Card.pileWidth * Theme.Card.ratio + 48)
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
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
    }

    /// Where each seat's card rests on the pile: nudged toward the seat that played it.
    static func pileOffset(for seat: Int) -> CGSize {
        switch seat {
        case 1: CGSize(width: -Theme.Table.sideNudge, height: 4)
        case 2: CGSize(width: 0, height: -Theme.Table.partnerNudge)
        case 3: CGSize(width: Theme.Table.sideNudge, height: 4)
        default: CGSize(width: 0, height: Theme.Table.ownNudge)
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

    // MARK: Contract

    /// Trump and the contract, in gold (rule 2), as plain text at the table's top-left once trump is
    /// named: no pill, so it sits in the felt like a scorer's note.
    @ViewBuilder private var contractPill: some View {
        if let trump = hand.trump {
            HStack(spacing: 8) {
                Text(trump.glyph).font(.title2).foregroundStyle(trump.isRed ? Color.suitRed : .ivory)
                Text("Trump")
                if let contract = model.contract {
                    Text("·").opacity(0.5)
                    Text(contract)
                }
            }
            .font(.system(.body, design: .serif).weight(.semibold))
            .foregroundStyle(.gold)
            .lineLimit(1).minimumScaleFactor(0.8)
            .padding(.leading, 4).padding(.top, 10)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Status, hints, explanations

    private var statusLine: some View {
        HStack(spacing: 8) {
            // Left: reopen the last trick when the pile is clear. Right: the hint on your turn.
            if pile.plays.isEmpty, hand.completedTricks.last != nil, hand.phase == .playing, reopenedTrick == nil {
                smallButton("rectangle.stack", label: "Show the last trick", action: onReopenTrick)
            } else if reopenedTrick != nil {
                // Play waits while the trick is open, so there must be a way to put it down again.
                smallButton("xmark", label: "Hide the last trick", action: onCloseTrick)
            } else {
                Spacer().frame(width: Theme.Table.statusButtonHitSize, height: Theme.Table.statusButtonHitSize)
            }
            statusText.font(.title3.weight(.medium)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                .accessibilityFocused(statusFocus)
            if model.isHumanTurn, hand.phase != .finished {
                smallButton("lightbulb", label: "Hint") { model.showHint() }
            } else {
                Spacer().frame(width: Theme.Table.statusButtonHitSize, height: Theme.Table.statusButtonHitSize)
            }
        }
    }

    /// A tertiary control: a 28pt circle inside a 44pt hit area.
    private func smallButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body)
                .frame(width: Theme.Table.statusButtonSize, height: Theme.Table.statusButtonSize)
                .background(.ivory.opacity(0.1), in: Circle())
                .overlay(Circle().stroke(.ivory.opacity(0.35)))
                .frame(width: Theme.Table.statusButtonHitSize, height: Theme.Table.statusButtonHitSize)
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
            return model.isHumanTurn ? Text("Your turn").foregroundStyle(.gold) : Text("\(actor) is thinking")
        case .finished:
            return Text("Hand complete")
        }
    }

    /// One line under the status: the undo toast after your action (with any discard notice), else a
    /// hint reason or explanation, else the notice, else your standing call in the auction, else a
    /// placeholder in play. Reserves no space in the auction while the controls need it.
    @ViewBuilder private var commentary: some View {
        ZStack {
            if let toast, model.canUndo {
                HStack(spacing: 12) {
                    Text([model.describe(toast), model.notice].compactMap { $0 }.joined(separator: " · ")).font(.footnote).lineLimit(1)
                    Button("Undo") { model.undo() }.font(.footnote.weight(.semibold)).tint(.ivory)
                        .accessibilityHint("Takes back your last action and the replies after it")
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Theme.Wood.inlay.opacity(0.85), in: Capsule())
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            } else if let refusal = model.refusal {
                Text(refusal).font(.footnote).multilineTextAlignment(.center).foregroundStyle(.ivory.opacity(0.9))
                    .padding(.horizontal, 8)
            } else if let text = model.hint?.reason ?? model.explanation {
                Text(text)
                    .font(.footnote).multilineTextAlignment(.center)
                    .foregroundStyle(.ivory.opacity(0.85))
                    .padding(.horizontal, 8)
                    .accessibilityLabel(model.hint != nil ? "Hint: \(text)" : text)
            } else if let notice = model.notice {
                Text(notice).font(.footnote).opacity(0.85)
            } else if hand.phase == .bidding, !model.isHumanTurn, let call = model.latestCall(for: 0) {
                Text("You: \(call)").font(.footnote).opacity(0.85)
            } else if !inAuction {
                Text(pile.plays.isEmpty ? " " : "Tap a card to see why it was played")
                    .font(.footnote).foregroundStyle(.ivory.opacity(0.5))
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: inAuction && model.isHumanTurn ? 0 : 36, alignment: .top)
        .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay, value: toast)
    }

    // MARK: Phase controls

    private var bidding: some View {
        VStack(spacing: Theme.Table.auctionButtonSpacing) {
            if let context = model.auctionContext {
                Text(context).font(.footnote).opacity(0.85).multilineTextAlignment(.center).padding(.bottom, 2)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Table.auctionButtonSpacing), count: 4),
                      spacing: Theme.Table.auctionButtonSpacing) {
                ForEach(2...9, id: \.self) { bid in actionButton(String(bid), action: .bid(bid)) }
            }
            HStack(spacing: Theme.Table.auctionButtonSpacing) {
                actionButton("Pass", action: .bid(nil), font: .body.weight(.semibold))
                Button { onNineAndOut() } label: { Text("9 and out").font(.body.weight(.semibold)) }
                    .buttonStyle(PillButtonStyle(fill: Theme.Wood.inlay))
                    .disabled(!model.allows(.nineAndOut))
                    .accessibilityHint(model.allows(.nineAndOut) ? "Take all nine points or lose the match; asks you to confirm"
                                       : model.validationMessage(for: .nineAndOut) ?? "")
            }
        }
    }

    /// Four suit pills, each named for newcomers and captioned with what choosing it keeps and draws.
    private var trumpChoice: some View {
        HStack(alignment: .top, spacing: Theme.Table.auctionButtonSpacing) {
            ForEach(Suit.allCases, id: \.self) { suit in
                VStack(spacing: 2) {
                    actionButton(suit.glyph, action: .chooseTrump(suit), fill: suit.pillFill, font: .largeTitle.weight(.bold))
                        .accessibilityLabel("\(suit.rawValue), \(model.trumpPreview(for: suit) ?? "")")
                    // One caption line so the auction still fits without scrolling (D34).
                    Text(suit.rawValue).font(.caption2.weight(.semibold)).opacity(0.8)
                    if let preview = model.trumpPreview(for: suit) {
                        Text(preview).font(.caption2).opacity(0.6)
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityElement(children: .contain)
            }
        }
    }

    /// Pills fill their column so neighbours almost touch: solid, tall, with a large label.
    private func actionButton(_ label: String, action: PlayerAction, fill: Color = Theme.Wood.inlay,
                              font: Font = .title3.weight(.semibold)) -> some View {
        let allowed = model.allows(action)
        return Button { model.send(action) } label: { Text(label).font(font) }
            .buttonStyle(PillButtonStyle(fill: fill))
            .disabled(!allowed)
            // A greyed pill still says why it is greyed to assistive technology.
            .accessibilityHint(allowed ? "" : model.validationMessage(for: action) ?? "")
    }

    // MARK: Hand end

    private var finishedCard: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                if let winner = model.match.winner { matchOver(winner) }
                HandSummaryView(match: model.match, names: model.seatNames)
                // Side by side when they fit, stacked at accessibility text sizes.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { reviewButton; dealButton }
                    VStack(spacing: 8) { dealButton; reviewButton }
                }
            }
            .padding(12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.Wood.inlay, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.ivory.opacity(0.15)))
        .padding(8)
        .transition(reduceMotion ? .opacity : .offset(y: 12).combined(with: .opacity))
        .accessibilitySortPriority(40)
    }

    private var reviewButton: some View {
        Button(action: onReview) { Label("Review", systemImage: "list.bullet.rectangle") }
            .buttonStyle(.bordered).tint(.ivory.opacity(0.8)).lineLimit(1)
    }

    private var dealButton: some View {
        Button(model.match.winner == nil ? "Deal next hand" : "Play again") {
            if model.match.winner == nil { model.nextHand() } else { model.newGame() }
        }.buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black).lineLimit(1)
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
    /// Side tiles take the width the row can spare; the partner's tile keeps the full width.
    var width: Double = Theme.Table.seatTileWidth

    private var hand: Hand { model.match.hand }
    private var active: Bool { hand.nextSeat == seat && model.match.winner == nil }

    /// One fixed size in every phase: name on top, the call or the card-back stack in the middle, and a
    /// badge line that is always reserved, so tiles never grow or shrink as the hand moves on.
    var body: some View {
        VStack(spacing: 4) {
            PortraitView(portrait: portrait, size: Theme.Table.portraitSize)
            Text(model.seatNames[seat]).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            ZStack {
                if hand.phase == .bidding {
                    Text(model.latestCall(for: seat) ?? "Waiting").font(.caption).opacity(0.75).lineLimit(1)
                } else {
                    ForEach(0..<min(3, max(1, hand.hands[seat].count)), id: \.self) { index in
                        CardBackView(width: Theme.Table.seatBackWidth)
                            .offset(x: Double(index) * 4 - 4)
                    }
                    Text(hand.hands[seat].count, format: .number).font(.caption.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.black.opacity(0.55), in: Capsule())
                        .offset(x: Theme.Table.seatBackWidth * 0.65, y: Theme.Table.seatBackWidth * 0.55)
                }
            }
            .frame(height: Theme.Table.seatBackWidth * Theme.Card.ratio + 4)
            .dynamicTypeSize(...Theme.Card.maximumTypeSize)
            HStack(spacing: 6) {
                if hand.auction.dealer == seat { Text("DEALER").foregroundStyle(.gold) }
                if hand.auction.winner == seat, hand.phase != .bidding { Text("BIDDER").opacity(0.7) }
            }
            .font(.system(.caption2, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.7)
            .frame(height: 15)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(width: width)
        // No fill: the name, backs and badges sit straight on the felt; only the seat to act gets a ring.
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.gold, lineWidth: active ? 2 : 0))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.seatSummary(for: seat))
    }

    private var portrait: Portrait { Cast.opponent(at: seat)?.portrait ?? model.settings.playerPortrait }
}

extension Suit {
    var isRed: Bool { self == .hearts || self == .diamonds }
    /// Pill fill for a suit choice: the red suits get a deep red, the black suits the inlay.
    var pillFill: Color { isRed ? Color(red: 0.56, green: 0.13, blue: 0.15) : Theme.Wood.inlay }
}

extension Color {
    /// A playing-card red for suit glyphs on dark panels.
    static var suitRed: Color { Color(red: 0.86, green: 0.18, blue: 0.22) }
}

/// The auction's pills: a solid fill, ivory label, a faint edge, dimmed when the rule disallows the
/// action, and a small press. Fills the column it is given.
struct PillButtonStyle: ButtonStyle {
    var fill: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.ivory)
            .frame(maxWidth: .infinity, minHeight: Theme.Table.auctionButtonHeight)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.Table.auctionButtonRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Table.auctionButtonRadius, style: .continuous)
                .stroke(.ivory.opacity(0.18), lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

/// The undealt stock: a small stack of card backs with the count, in the table's top-right corner.
struct DeckView: View {
    let remaining: Int

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ForEach(0..<3, id: \.self) { index in
                CardBackView(width: Theme.Table.deckWidth)
                    .offset(x: Double(index) * -2, y: Double(index) * -2)
            }
            Text(remaining, format: .number).font(.caption2.weight(.bold).monospacedDigit())
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(.black.opacity(0.6), in: Capsule())
                .offset(x: 6, y: 6)
        }
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(remaining) cards in the deck")
    }
}
