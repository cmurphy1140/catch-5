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
    /// The hint's full reason, opened from its Why? control (spec R22).
    @State private var showHintDetail = false

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
                    Spacer(minLength: 4)
                    SeatView(model: model, seat: 2).accessibilitySortPriority(20)
                    // The side tiles give way before the pile can touch them (`TableLayout`); in the auction
                    // there is no pile, so they keep their full width.
                    let sideWidth = inAuction ? Theme.Table.seatTileWidth : TableLayout.sideSeatWidth(available: geometry.size.width)
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
            // The stock sits in the top-right corner of the table; refills deal in from here. The discards
            // mirror it in the top-left, clear of the hand (spec R3), and discards fly there.
            .overlay(alignment: .topTrailing) { DeckView(remaining: hand.stock.count).padding(.top, 6) }
            .overlay(alignment: .topLeading) {
                if !hand.discarded.isEmpty {
                    DiscardPileView(count: hand.discarded.count).padding(.top, 6).transition(.opacity)
                }
            }
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
            Color.clear.frame(width: TableLayout.pileReservation,
                              height: Theme.Card.pileWidth * Theme.Card.ratio + Theme.Table.partnerNudge + Theme.Table.ownNudge + 8)
            ForEach(pile.plays, id: \.card) { play in
                Button { model.explain(play, inLastTrick: pile.isLast) } label: {
                    CardView(card: play.card, width: Theme.Card.pileWidth, style: .pile)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Card.radius(width: Theme.Card.pileWidth), style: .continuous)
                            .stroke(.gold, lineWidth: pile.winner == play.seat ? 3 : 0))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.spokenDescription(of: play, winner: pile.winner))
                .accessibilityHint("Explains why this card was played")
                .rotationEffect(.degrees(toss(for: play).rotation))
                .offset(Self.pileOffset(for: play.seat) + toss(for: play).offset)
                .matchedGeometryEffect(id: play.card, in: namespace)
                .transition(transition(for: play, winner: pile.winner, reach: reach))
                .zIndex(Double(pile.plays.firstIndex(where: { $0.card == play.card }) ?? 0))
            }
            if pile.plays.isEmpty, hand.phase == .playing, !model.isHumanTurn || hand.completedTricks.isEmpty {
                Text(hand.completedTricks.isEmpty ? "First lead" : "").font(.caption2).opacity(0.7)
            }
        }
        .accessibilitySortPriority(5)
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
    }

    /// The card's own turn and drift on the pile, fixed for as long as this trick lies there.
    private func toss(for play: Play) -> CardToss.Pose {
        CardToss.pose(for: play.card, hand: model.match.handNumber, trick: hand.completedTricks.count)
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

    // MARK: Status, hints, explanations

    private var statusLine: some View {
        HStack(spacing: 8) {
            if reopenedTrick != nil {
                // Reviewing the last trick is its own state (spec R24): say so, and name the way back.
                // Play waits while the trick is open; no hint is offered, since nothing is being decided.
                Button(action: onCloseTrick) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.subheadline.weight(.bold))
                        Text("Back to play").font(.subheadline.weight(.semibold))
                    }
                    .frame(minHeight: Theme.Table.statusButtonHitSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to play")
                Text("Reviewing last trick").font(.title3.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .accessibilityFocused(statusFocus)
                Spacer().frame(width: Theme.Table.statusButtonHitSize, height: Theme.Table.statusButtonHitSize)
            } else {
                // Left: reopen the last trick when the pile is clear. Right: the hint on your turn.
                if pile.plays.isEmpty, hand.completedTricks.last != nil, hand.phase == .playing {
                    smallButton("rectangle.stack", label: "Show the last trick", action: onReopenTrick)
                } else {
                    Spacer().frame(width: Theme.Table.statusButtonHitSize, height: Theme.Table.statusButtonHitSize)
                }
                statusText.font(.title3.weight(.medium)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityFocused(statusFocus)
                if model.isHumanTurn, hand.phase != .finished {
                    smallButton("lightbulb", label: "Hint") { model.showHint() }
                } else {
                    Spacer().frame(width: Theme.Table.statusButtonHitSize, height: Theme.Table.statusButtonHitSize)
                }
            }
        }
    }

    /// A tertiary control: a 28pt circle inside a 44pt hit area.
    /// A bare glyph with a soft shadow for contrast, no plate (spec R19); the hit area stays 48 pt.
    private func smallButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3.weight(.medium))
                .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
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
            if model.isHumanTurn, let suit = model.suitToFollow {
                // The shaded cards are the ones that cannot follow; say why in the same breath.
                return Text("Your turn").foregroundStyle(.gold) + Text(" · follow \(suit.rawValue)")
            }
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
            if let refusal = model.refusal {
                // A refused tap answers first: it is the freshest thing the player did.
                Text(refusal).font(.footnote).multilineTextAlignment(.center).foregroundStyle(.ivory.opacity(0.9))
                    .padding(.horizontal, 8)
            } else if let toast, model.canUndo {
                HStack(spacing: 12) {
                    Text([model.describe(toast), model.notice].compactMap { $0 }.joined(separator: " · ")).font(.footnote).lineLimit(1)
                    Button("Undo") { model.undo() }.font(.footnote.weight(.semibold)).tint(.ivory)
                        .accessibilityHint("Takes back your last action and the replies after it")
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Theme.Wood.inlay.opacity(0.85), in: Capsule())
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            } else if let hint = model.hint {
                // One complete recommendation on one line; the reason waits behind Why?, so a long hint
                // can never push the controls above it off the screen (spec R22).
                let parts = Self.hintParts(hint.reason)
                HStack(spacing: 10) {
                    Text(parts.recommendation).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    if !parts.detail.isEmpty {
                        Button("Why?") { showHintDetail = true }
                            .font(.footnote.weight(.semibold)).tint(.ivory).underline()
                            .accessibilityHint("Opens the reason for this hint")
                    }
                }
                .foregroundStyle(.ivory)
                .padding(.horizontal, 8)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Hint: \(parts.recommendation)")
            } else if let text = model.explanation {
                Text(text)
                    .font(.footnote).multilineTextAlignment(.center)
                    .foregroundStyle(.ivory.opacity(0.85))
                    .padding(.horizontal, 8)
            } else if let notice = model.notice {
                Text(notice).font(.footnote).opacity(0.85)
            } else if hand.phase == .bidding, !model.isHumanTurn, let call = model.latestCall(for: 0) {
                Text("You: \(call)").font(.footnote).opacity(0.85)
            } else if !inAuction {
                Text(pile.plays.isEmpty ? " " : (reopenedTrick != nil ? "Tap a card to see why it was played" : "Tap a card on the table to see why it was played"))
                    .font(.footnote).foregroundStyle(.ivory.opacity(0.7))
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: inAuction && model.isHumanTurn ? 0 : 36, alignment: .top)
        .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay, value: toast)
        .sheet(isPresented: $showHintDetail) {
            if let hint = model.hint {
                HintDetailView(parts: Self.hintParts(hint.reason))
            }
        }
    }

    /// Advice reads "Play the six of clubs: partner's queen holds the trick, so…". The part before the
    /// colon is the recommendation; the rest, with a capital, is the reason. No colon: all recommendation.
    nonisolated static func hintParts(_ reason: String) -> (recommendation: String, detail: String) {
        guard let colon = reason.firstIndex(of: ":") else { return (reason, "") }
        let recommendation = String(reason[..<colon]).trimmingCharacters(in: .whitespaces)
        let rest = reason[reason.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard let first = rest.first else { return (recommendation, "") }
        return (recommendation, first.uppercased() + rest.dropFirst())
    }

    // MARK: Phase controls

    private var bidding: some View {
        VStack(spacing: Theme.Table.auctionButtonSpacing) {
            if let context = model.auctionContext {
                Text(context).font(.footnote).opacity(0.85).multilineTextAlignment(.center).padding(.bottom, 2)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Table.auctionButtonSpacing), count: 4),
                      spacing: Theme.Table.auctionButtonSpacing) {
                ForEach(HouseRules.bidRange, id: \.self) { bid in actionButton(String(bid), action: .bid(bid)) }
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
    /// Suits alternate red and black, ♥ ♠ ♦ ♣, so the two red suits never sit side by side (spec R13).
    static let trumpOrder: [Suit] = [.hearts, .spades, .diamonds, .clubs]

    private var trumpChoice: some View {
        HStack(alignment: .top, spacing: Theme.Table.auctionButtonSpacing) {
            ForEach(Self.trumpOrder, id: \.self) { suit in
                VStack(spacing: 2) {
                    // The glyph carries the suit's colour on the same dark pill as every other choice; a red
                    // fill only hid the glyph (spec R13).
                    actionButton(suit.glyph, action: .chooseTrump(suit), font: .largeTitle.weight(.bold),
                                 labelColor: suit.isRed ? Color.suitRed : .ivory)
                        .accessibilityLabel("\(suit.rawValue), \(model.trumpPreview(for: suit) ?? "")")
                    // One short caption line so the auction still fits without scrolling (D34): the suit and
                    // what it keeps; the draw count is implied and VoiceOver reads the full preview.
                    Text(model.trumpPreview(for: suit).flatMap { $0.split(separator: " · ").first }.map { "\(suit.rawValue) · \($0)" } ?? suit.rawValue)
                        .font(.caption2.weight(.semibold)).opacity(0.8)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    /// Pills fill their column so neighbours almost touch: solid, tall, with a large label.
    private func actionButton(_ label: String, action: PlayerAction, fill: Color = Theme.Wood.inlay,
                              font: Font = .title3.weight(.semibold), labelColor: Color = .ivory) -> some View {
        // One dry run per pill: the reason, when there is one, is also why the pill is greyed.
        let reason = model.validationMessage(for: action)
        return Button { model.send(action) } label: { Text(label).font(font).foregroundStyle(labelColor) }
            .buttonStyle(PillButtonStyle(fill: fill))
            .disabled(reason != nil)
            // A greyed pill still says why it is greyed to assistive technology.
            .accessibilityHint(reason ?? "")
    }

    // MARK: Hand end

    private var finishedCard: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                if let winner = model.match.winner { matchOver(winner) }
                HandSummaryView(match: model.match, names: model.seatNames, outcome: model.lastHandOutcome)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The halo's breathing, driven by a repeating animation while this seat is deciding.
    @State private var pulsing = false
    @ScaledMetric(relativeTo: .title2) private var backWidth = Theme.Table.seatBackWidth

    private var hand: Hand { model.match.hand }
    private var active: Bool { hand.nextSeat == seat && model.match.winner == nil }

    /// A face over a name over one line of badges: the call in the auction, a hint of a hand in play, and
    /// DEALER or BIDDER when they apply. Everything a seat says sits under its own portrait, so nothing
    /// about a player floats elsewhere on the table (spec R2). The seat to act wears a gold halo that
    /// breathes; that halo is the table's only turn indicator.
    var body: some View {
        VStack(spacing: 2) {
            PortraitView(portrait: portrait, size: Theme.Table.portraitSize, expression: SeatMood.expression(for: seat, in: model.match))
                .overlay {
                    Circle().stroke(.gold, lineWidth: Theme.Table.activeRingWidth)
                        .padding(-Theme.Table.activeRingGap)
                        .opacity(active ? 1 : 0)
                }
                .scaleEffect(pulsing ? Theme.Table.activePulseScale : 1)
                .onChange(of: active, initial: true) { _, isActive in
                    if isActive, !reduceMotion {
                        withAnimation(Theme.Motion.pulse) { pulsing = true }
                    } else {
                        withAnimation(Theme.Motion.overlay) { pulsing = false }
                    }
                }
                .padding(.vertical, Theme.Table.activeRingGap)
            Text(model.seatNames[seat]).font(.headline).lineLimit(1).minimumScaleFactor(0.6)
            badges
        }
        .padding(.horizontal, 4).padding(.vertical, 2)
        .frame(width: width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.seatSummary(for: seat))
    }

    /// One line, always the same height, so the tiles do not jump when a call lands or the phase turns.
    private var badges: some View {
        HStack(spacing: 6) {
            if hand.phase == .bidding {
                // The call as a badge on the same dark pill as the auction's own buttons; a pass is muted
                // so the bids stand out. No badge until the seat has spoken: the halo says who is deciding.
                if let call = hand.auction.calls.last(where: { $0.seat == seat }), let label = model.latestCall(for: seat) {
                    Text(label).font(.caption.weight(.semibold)).foregroundStyle(.ivory)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Theme.Wood.inlay, in: Capsule())
                        .opacity(call.bid == nil ? 0.7 : 1)
                }
            } else {
                // The stack's thickness says roughly how many cards are left; there is no number (spec R20).
                ZStack(alignment: .leading) {
                    ForEach(0..<min(3, max(1, hand.hands[seat].count)), id: \.self) { index in
                        CardBackView(width: Theme.Table.seatBackWidth).offset(x: Double(index) * 3)
                    }
                }
                .padding(.trailing, 6)
                .dynamicTypeSize(...Theme.Card.maximumTypeSize)
            }
            if hand.auction.dealer == seat { Text("DEALER").foregroundStyle(.gold) }
            if hand.auction.winner == seat, hand.phase != .bidding { Text("BIDDER").opacity(0.7) }
        }
        .font(.system(.caption2, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.6)
        .frame(height: backWidth * Theme.Card.ratio + 2)
    }

    private var portrait: Portrait { Cast.opponent(at: seat)?.portrait ?? model.settings.playerPortrait }
}

extension Suit {
    var isRed: Bool { self == .hearts || self == .diamonds }
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

/// The undealt stock in the table's top-right corner. Its thickness says roughly how much is left;
/// there is no number, because counting is the player's skill, not the app's (spec R20).
struct DeckView: View {
    let remaining: Int

    /// One back per six cards or part of one, so a full stock reads as five and a near-empty one as one.
    nonisolated static func thickness(_ count: Int) -> Int { max(1, min(5, (count + 5) / 6)) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ForEach(0..<Self.thickness(remaining), id: \.self) { index in
                CardBackView(width: Theme.Table.deckWidth)
                    .offset(x: Double(index) * -2, y: Double(index) * -2)
            }
        }
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Deck")
    }
}

/// The discards, face down in the top-left corner: nothing about them is a secret worth keeping (the rules put
/// them out of play), but nothing about them needs showing either, so no number here (spec R20).
struct DiscardPileView: View {
    let count: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(0..<min(3, DeckView.thickness(count)), id: \.self) { index in
                CardBackView(width: Theme.Table.deckWidth * 0.85)
                    .rotationEffect(.degrees(5 - Double(index) * 5))
                    .offset(x: Double(index) * 1.5, y: Double(index) * -1.5)
            }
        }
        .opacity(0.8)
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Discard pile")
    }
}

private func + (lhs: CGSize, rhs: CGSize) -> CGSize {
    CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
}

/// The hint's reason, in a short sheet over the table: bounded, scrollable, never in the way of a control.
struct HintDetailView: View {
    let parts: (recommendation: String, detail: String)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("HINT").font(.system(.caption, design: .monospaced)).tracking(1).opacity(0.7)
                Text(parts.recommendation).font(.system(.title3, design: .serif).weight(.bold))
                Text(parts.detail).font(.body).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .foregroundStyle(.ivory)
        .background(WoodGrainView().ignoresSafeArea())
        .presentationDetents([.fraction(0.35), .medium])
        .presentationDragIndicator(.visible)
    }
}

