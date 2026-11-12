import CatchFive
import SwiftUI

/// The bid in the table's top-left corner once the auction resolves (D65, D87): Connor's three biggest things,
/// who bid (their own face), the bid large in the display serif under a BID eyebrow (9 and out reads as a 9
/// with "and out"), and trump, the suit big in its own colour once it is named (N63, N67). Since D94 there is no box:
/// the face lies on the table like a chip and the words and the suit are carved into the wood. The suit is also the
/// player's tally of trumps played, chalked beside it: tap adds a mark, press and hold takes one back; the app never
/// counts for the player (spec R4), it only keeps the marks they make.
struct ContractPlaque: View {
    struct Contract: Equatable {
        let bid: Int
        let isNineAndOut: Bool
        let bidder: String
        /// The bidder's face, the same as at their seat.
        let portrait: Portrait
        /// Trump, once the bidder has named it.
        var trump: Suit? = nil
        /// Seat identity survives player renames and selects the current roster's cutout (D171).
        var bidderSeat: Int? = nil

        /// The big figure: the bid, or 9 for 9 and out.
        var number: String { isNineAndOut ? "9" : String(bid) }
        /// The words under a 9 and out's figure; nil for an ordinary bid.
        var qualifier: String? { isNineAndOut ? "and out" : nil }
        var spoken: String { "\(bidder) bid \(isNineAndOut ? "9 and out" : String(bid))" }
    }

    /// The contract once the auction has resolved: the bid, who holds it, and trump when it is named.
    static func contract(in model: GameModel) -> Contract? {
        let auction = model.match.hand.auction
        guard auction.nextSeat == nil, let bidder = auction.winner, let bid = auction.highestBid else { return nil }
        return Contract(bid: bid, isNineAndOut: auction.isNineAndOut, bidder: model.seatNames[bidder],
                        portrait: Cast.opponent(at: bidder)?.portrait ?? model.settings.playerPortrait,
                        trump: model.match.hand.trump, bidderSeat: bidder)
    }

    /// The box as the table shows it: the player's tally on the suit, and the demo's pulse on it (N61).
    static func onTable(_ model: GameModel, contract: Contract, width: Double) -> ContractPlaque {
        ContractPlaque(contract: contract, width: width, tally: model.trumpTally, demo: model.tallyDemo == .trump,
                       figure: contract.bidderSeat.flatMap { SeatArt.image(seat: $0, opponents: model.settings.opponents) },
                       onAdd: model.tallyTrump, onTakeBack: model.untallyTrump)
    }

    let contract: Contract
    /// The corner's width, from `TableLayout.cornerWidth(available:)`; the height is `Theme.Table.cornerHeight`.
    let width: Double
    var tally = 0
    /// The tally demo is pointing at the suit.
    var demo = false
    var figure: Image?
    var onAdd: () -> Void = {}
    var onTakeBack: () -> Void = {}

    /// The bid is cut into the wood (D94).
    static let numberInk = Carving.ink

    /// The word printed beside the suit, so the glyph reads as trump and not as a card (D93).
    nonisolated static let trumpWord = "Trump"

    /// The trump line as it reads in the corner (D95): the suit and the word together, "♠ Trump".
    nonisolated static func trumpLine(_ suit: Suit) -> String { "\(suit.glyph) \(trumpWord)" }

    /// Red for hearts and diamonds, black for spades and clubs: the suit's own colour, never a control's.
    nonisolated static func glyphColor(_ suit: Suit) -> Color { suit.isRed ? .suitRed : .black }

    /// "Diane bid 4, hearts are trump, 3 trump played".
    static func spoken(_ contract: Contract, tally: Int) -> String {
        guard let trump = contract.trump else { return contract.spoken }
        return "\(contract.spoken), \(trump.rawValue) are trump, \(tally) trump played"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 4) {
                // The bidder's face lies on the table like a chip, its shadow on the wood.
                SeatFace(portrait: contract.portrait, figure: figure, size: Theme.Table.plaquePortraitSize)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 1, y: 3)
                    .padding(.top, Theme.Table.plaquePortraitSize * Theme.Table.portraitHeadroom)
                VStack(spacing: -6) {
                    Text("BID").font(.system(size: Theme.Table.bidEyebrowSize, weight: .heavy, design: .serif)).tracking(1.5)
                        .carved()
                    Text(contract.number).font(.system(size: Theme.Table.plaqueNumberSize, weight: .bold, design: .serif))
                        .carved(Self.numberInk)
                    if let qualifier = contract.qualifier {
                        Text(qualifier).font(.system(size: Theme.Table.bidEyebrowSize, weight: .heavy, design: .serif)).carved()
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(contract.spoken)
            suit
        }
        .lineLimit(1).minimumScaleFactor(0.6)
        .padding(.horizontal, 2).padding(.vertical, 4)
        .frame(width: width, height: Theme.Table.cornerHeight)
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
        .accessibilityElement(children: .contain)
    }

    /// Trump carved under the bid with its word, and the player's tally chalked under them, the tap target; an empty line of the same
    /// height until trump is named.
    @ViewBuilder private var suit: some View {
        if let trump = contract.trump {
            // "♠ Trump" on one line (D95), the tally chalked under it.
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    CarvedSuit(suit: trump, size: Theme.Table.trumpLineSuitSize)
                        .modifier(DemoTap(active: demo))
                    Text(Self.trumpWord).font(.system(size: Theme.Table.trumpWordSize, weight: .heavy, design: .serif))
                        .carved()
                }
                TallyMarks(count: tally).frame(maxWidth: .infinity).frame(height: Theme.Table.tallyHeight)
            }
            .frame(height: Theme.Table.bidBoxSuitSize * 1.15)
            .contentShape(Rectangle())
            .onTapGesture(perform: onAdd)
            .onLongPressGesture(perform: onTakeBack)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.spoken(contract, tally: tally))
            .accessibilityHint("Tap when a trump is played; swipe up or down to change the count")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onAdd() }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onAdd()
                case .decrement: onTakeBack()
                @unknown default: break
                }
            }
        } else {
            Color.clear.frame(height: Theme.Table.bidBoxSuitSize * 1.15)
        }
    }
}

/// A corner's arrival (N53): the first time it fills it grows in with a light glow that fades, so players know
/// where to look; under Reduce Motion it fades in instead.
struct CornerArrival: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: .ivory.opacity(glowing ? 0.9 : 0), radius: 14)
            .scaleEffect(arrived || reduceMotion ? 1 : Theme.Table.cornerArrivalScale)
            .opacity(arrived ? 1 : 0)
            .onAppear {
                guard !reduceMotion else {
                    withAnimation(Theme.Motion.reduced) { arrived = true }
                    return
                }
                glowing = true
                withAnimation(.spring(duration: 0.45, bounce: 0.35)) { arrived = true }
                withAnimation(.easeOut(duration: Theme.Table.cornerGlowSeconds).delay(0.3)) { glowing = false }
            }
    }
}

/// Tally strokes chalked straight onto the wood (D94), in groups of five with the fifth across the four, as on paper.
struct TallyMarks: View {
    let count: Int

    /// The strokes in each group, left to right: 13 is [5, 5, 3].
    nonisolated static func groups(_ count: Int) -> [Int] {
        stride(from: 0, to: max(count, 0), by: 5).map { min(5, count - $0) }
    }

    var body: some View {
        Canvas { context, size in
            let step = Theme.Table.tallyStep, gap = Theme.Table.tallyGroupGap
            let groupWidth = 3 * step
            var x = 2.0
            for strokes in Self.groups(count) {
                var path = Path()
                for index in 0..<min(strokes, 4) {
                    // A hand-drawn lean, alternating, so the chalk does not look ruled.
                    let stroke = x + Double(index) * step, lean = index.isMultiple(of: 2) ? 0.8 : -0.6
                    path.move(to: CGPoint(x: stroke + lean, y: 2))
                    path.addLine(to: CGPoint(x: stroke - lean, y: size.height - 2))
                }
                if strokes == 5 {
                    path.move(to: CGPoint(x: x - 2, y: size.height - 4))
                    path.addLine(to: CGPoint(x: x + groupWidth + 2, y: 4))
                }
                context.stroke(path, with: .color(.ivory.opacity(0.9)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                x += groupWidth + gap
            }
        }
        .accessibilityHidden(true)
    }
}

/// The player's mark on a seat they have seen run out of trump: the suit on an ivory disc, crossed out.
struct OutOfTrumpBadge: View {
    let trump: Suit

    var body: some View {
        Text(trump.glyph).font(.system(size: Theme.Table.outOfTrumpBadgeSize * 0.6))
            .foregroundStyle(trump.isRed ? Color.suitRed : .black)
            .frame(width: Theme.Table.outOfTrumpBadgeSize, height: Theme.Table.outOfTrumpBadgeSize)
            .background(.ivory, in: Circle())
            .overlay {
                Rectangle().fill(.black).frame(width: 2, height: Theme.Table.outOfTrumpBadgeSize * 0.8)
                    .rotationEffect(.degrees(45))
            }
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            .accessibilityHidden(true)
    }
}

/// The contract as one line on the field's corner (D113), for the rail layout, which has no corner beside the partner:
/// who bid, how many, and trump once named, with the player's tally after it. A tap adds to the tally, a long press
/// takes one back, as on the plaque.
struct ContractChip: View {
    let contract: ContractPlaque.Contract
    var tally = 0
    var onAdd: () -> Void = {}
    var onTakeBack: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            Text("\(contract.bidder) bid \(contract.number)\(contract.qualifier.map { " " + $0 } ?? "")")
            if let trump = contract.trump {
                Text(trump.glyph).foregroundStyle(TrumpInlay.wood(for: trump))
                if tally > 0 { Text("\(tally) seen").opacity(0.8) }
            }
        }
        .font(.system(.subheadline, design: .serif).weight(.bold)).lineLimit(1)
        .foregroundStyle(Theme.Field.maple)
        .padding(.horizontal, 10).frame(minHeight: 30)
        .background(.black.opacity(0.35), in: Capsule())
        .frame(minHeight: 44).contentShape(Rectangle())
        .onTapGesture { if contract.trump != nil { onAdd() } }
        .onLongPressGesture { onTakeBack() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ContractPlaque.spoken(contract, tally: tally))
        .accessibilityHint(contract.trump == nil ? "" : "Tap to count a trump played")
    }
}

/// The contract as one line across the oak above the cloth table (D117), as large as the line allows (D143): who bid
/// and how many, the trump suit once it is chosen, and the player's own count of trump seen. A tap adds to the count,
/// a long press takes one back. Empty during the auction, keeping its height so the table does not jump.
struct ContractStrip: View {
    let contract: ContractPlaque.Contract?
    var tally = 0
    var onAdd: () -> Void = {}
    var onTakeBack: () -> Void = {}

    var body: some View {
        // One Text, so the whole line shrinks together and no part of it is cut short.
        line
        .font(.system(.title2, design: .serif).weight(.bold)).lineLimit(1).minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, minHeight: 38)
        .overlay(alignment: .top) { rule }
        .overlay(alignment: .bottom) { rule }
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture { if contract?.trump != nil { onAdd() } }
        .onLongPressGesture { onTakeBack() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(contract.map { ContractPlaque.spoken($0, tally: tally) } ?? "")
        .accessibilityHint(contract?.trump == nil ? "" : "Tap to count a trump played")
        .accessibilityHidden(contract == nil)
    }

    private var line: Text {
        guard let contract else { return Text(" ") }
        let bar = Text("  |  ").foregroundColor(Theme.Paper.rule)
        var text = Text("\(contract.bidder) bid \(contract.number)\(contract.qualifier.map { " " + $0 } ?? "")")
        if let trump = contract.trump {
            // The suit itself lies on the cloth below, so the line names it without the word "trump" and has room to be larger.
            text = text + bar + Text(trump.glyph).foregroundColor(trump.isRed ? .suitRed : nil) + Text(" \(trump.rawValue.capitalized)")
                + bar + Text("\(tally) seen").italic()
        }
        return text
    }

    private var divider: some View { Rectangle().fill(Theme.Paper.rule.opacity(0.8)).frame(width: 1, height: 16).accessibilityHidden(true) }
    private var rule: some View { Rectangle().fill(Theme.Paper.rule.opacity(contract == nil ? 0 : 0.55)).frame(height: 1).accessibilityHidden(true) }
}
