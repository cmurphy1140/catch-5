import CatchFive
import SwiftUI

/// The playing surface: partner across the top, West and East at the sides, the pile in the middle,
/// the status line and explanations under it, and the phase controls where the pile sits during the auction.
struct TableSurface: View {
    @ObservedObject var model: GameModel
    /// Completed tricks that have already collapsed toward their winner.
    let collapsedTricks: Int
    /// What is in the air (D97): a play still flying is not drawn on the field until it lands.
    var motion: TableMotion? = nil
    /// The card you have picked in your hand, waiting for the second tap (D97).
    var selected: Card? = nil
    /// Counts the tricks each place has taken this session, so its face can nod as a trick arrives (D97).
    var bumps: [Int: Int] = [:]
    /// The finished hand's last trick has been taken, so its result may come up (D97).
    var resultReady = true
    /// Each seat's face says where it is, by place round the table, so flights can start and end there.
    var onAnchor: (Int, CGPoint) -> Void = { _, _ in }
    /// The pile says where its middle is, and how much its cards are scaled by the reader's text size.
    var onPileCentre: (CGPoint, Double) -> Void = { _, _ in }
    /// A completed trick the player asked to see again.
    let reopenedTrick: Int?
    /// The human's latest action while its undo toast is showing.
    let toast: PlayerAction?
    let onReopenTrick: () -> Void
    let onCloseTrick: () -> Void
    /// The 9-and-out pill asks the table to confirm before the bid is sent.
    let onNineAndOut: () -> Void
    /// The score pad on the table was tapped: open the score sheet (N66).
    var onScorecard: () -> Void = {}
    /// Your spot on the field was tapped while a card is picked: lay that card down (D116).
    var onLayDown: () -> Void = {}
    /// The gear by the status line was tapped: open Settings over the table (D118).
    var onSettings: () -> Void = {}
    /// The deck beside the dealer's tile says where it rests, so the deal can start there.
    var onDeck: (CGPoint) -> Void = { _ in }
    /// A seat's name tag was tapped: rename that seat (D93).
    var onRename: (Int) -> Void = { _ in }
    /// A match-win celebration is playing; the hand-end card waits until it has finished (D69).
    var holdsResult = false
    /// VoiceOver focus lands on the status line when a cover lifts or the turn changes.
    let statusFocus: AccessibilityFocusState<Bool>.Binding
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The hint's full reason, opened from its Why? control (spec R22).
    @State private var showHintDetail = false
    /// The column's own height, measured so the table can tell whether it fits the surface (spec R25).
    @State private var contentHeight = 0.0
    @State private var padWidth = 0.0
    /// The height of the status line and what sits with it, so the trick knows the room it has (D112).
    @State private var lowerHeight = 0.0
    /// The floating notice's height, so it sits wholly above "Your turn" in play.
    @State private var floatHeight = 0.0
    /// What the field is laid out between (D97), in the column's own space: the partner's row, the side seats and the
    /// status line.
    @State private var fieldEdges = FieldEdges()
    /// Where the rows under the field begin, so the trial layouts can run the field down to them (D113).
    @State private var lowerTop = 0.0
    /// The foot of the partner's seat on the Around table, where it sits inside the field (D117).
    @State private var partnerBottom = 0.0

    private var hand: Hand { model.match.hand }
    private var arrangement: Settings.TableArrangement { model.settings.tableArrangement }
    /// The trial layouts (D113): the field fills the table, the dealer button rides the dealer's face, and the score
    /// is a plate on the top row instead of a pad on the table.
    private var reworked: Bool { arrangement != .classic }
    /// The field's edges as drawn: today's table ends it under the side seats, the trial layouts above the status line.
    private var drawnEdges: FieldEdges {
        var edges = fieldEdges
        if reworked, lowerTop > 0 { edges.bottom = lowerTop + Theme.Field.verticalGap - 4 }
        return edges
    }

    /// Which plays the pile shows, the winner if they are a finished trick, and which trick of the hand they are.
    private var pile: (plays: [Play], winner: Int?, isLast: Bool, trick: Int) {
        if !hand.currentTrick.isEmpty { return (hand.currentTrick, nil, false, hand.completedTricks.count) }
        guard let last = hand.completedTricks.last else { return ([], nil, false, 0) }
        let count = hand.completedTricks.count
        if count > collapsedTricks || reopenedTrick == count { return (last.plays, last.winner, true, count - 1) }
        return ([], nil, false, count)
    }

    /// The finished hand's card is up: the last trick has been taken (D97), and no celebration is playing.
    private var showsResult: Bool { hand.phase == .finished && resultReady }

    /// The edges the field is fitted between.
    struct FieldEdges: Equatable {
        var top = 0.0
        var bottom = 0.0
        var left = 0.0
        var right = 0.0
        var availableWidth = 0.0

        /// The field's frame: between the side seats, tucked a little under each, from under the partner's row to above
        /// the status line. Nil until the seats have been measured.
        var rect: CGRect? {
            let gap = Theme.Field.verticalGap
            let x = availableWidth > 0 ? 2 : left - Theme.Field.sideTuck
            let width = availableWidth > 0 ? availableWidth - 4 : right - left + 2 * Theme.Field.sideTuck
            let rect = CGRect(x: x, y: top + gap, width: width, height: bottom - top - 2 * gap)
            return rect.width > 80 && rect.height > 80 ? rect : nil
        }
    }

    /// The column's own coordinate space, which the field is drawn in.
    nonisolated static let column = "column"

    private var inAuction: Bool { hand.phase == .bidding || hand.phase == .choosingTrump }
    /// Beginner mode is set aside for this milestone (H01, T03): the live table carries no coaching, and the
    /// teaching lives in How to Play. `Settings.beginnerMode` stays in the file so saves keep loading.
    private let coaching = false

    var body: some View {
        GeometryReader { geometry in
            // Space goes by priority (spec R25): the seats and the pile hold the top of the table, the
            // status line with its controls and commentary sits down by the hand, and whatever the phase
            // leaves over opens up between them. The column is stretched to the surface whenever its
            // content fits; when it cannot, at accessibility text sizes, it keeps its own height and scrolls.
            let fits = contentHeight <= geometry.size.height + 0.5
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    // The phone holder sits at the bottom; in pass and play the table turns with the phone.
                    // The bid box in the top-left corner: who bid, the bid and trump with the player's tally on
                    // the suit (D65, N63), beside the partner and no taller than the partner's tile. It pops in the
                    // first time it fills (N53).
                    let cornerWidth = TableLayout.cornerWidth(available: geometry.size.width)
                    if arrangement == .rail {
                        railRow(available: geometry.size.width)
                            .onGeometryChange(for: Double.self) { $0.frame(in: .named(Self.column)).maxY } action: { fieldEdges.top = $0 }
                        // The contract lies on the field's corner, since the rail has no room beside the partner.
                        Color.clear.frame(height: 0).overlay(alignment: .topLeading) {
                            if let contract = ContractPlaque.contract(in: model) {
                                ContractChip(contract: contract, tally: model.trumpTally, onAdd: model.tallyTrump, onTakeBack: model.untallyTrump)
                                    .padding(.leading, 14).padding(.top, 12)
                            }
                        }
                        .opacity(dim).zIndex(2)
                    } else if arrangement == .around {
                        // The contract as one line on the oak (D117); the field starts under it, the partner inside.
                        ContractStrip(contract: ContractPlaque.contract(in: model), tally: model.trumpTally,
                                      onAdd: model.tallyTrump, onTakeBack: model.untallyTrump)
                            // The Rules book hangs over this corner; the line stops short of it.
                            .padding(.trailing, Theme.Table.rulesBookWidth + 28)
                            .opacity(dim).accessibilitySortPriority(25)
                            .onGeometryChange(for: Double.self) { $0.frame(in: .named(Self.column)).maxY } action: { fieldEdges.top = $0 - 4 }
                        SeatView(model: model, seat: model.seat(at: 2), isPartner: true, puckOnRim: true, onField: true, onDeck: onDeck, onRename: onRename,
                                 onAnchor: { onAnchor(2, $0) }, bump: bumps[2, default: 0]).accessibilitySortPriority(20)
                            .overlay(alignment: .topLeading) {
                                if hand.phase == .bidding {
                                    bidBox(at: 2, from: CGSize(width: Theme.Table.bidBoxWidth, height: 0))
                                        .offset(x: -Theme.Table.bidBoxWidth - 4, y: Theme.Table.portraitSize * Theme.Table.portraitHeadroom)
                                }
                            }
                            .padding(.top, 4)
                            .onGeometryChange(for: Double.self) { $0.frame(in: .named(Self.column)).maxY } action: { partnerBottom = $0 }
                            .opacity(dim)
                    } else {
                    HStack(alignment: .top, spacing: 0) {
                        corner(width: cornerWidth) {
                            if let contract = ContractPlaque.contract(in: model) {
                                ContractPlaque.onTable(model, contract: contract, width: cornerWidth).modifier(CornerArrival())
                            }
                        }
                        .opacity(dim)
                        .accessibilitySortPriority(25)
                        Spacer(minLength: 0)
                        SeatView(model: model, seat: model.seat(at: 2), isPartner: true, puckOnRim: reworked, onDeck: onDeck, onRename: onRename,
                                 onAnchor: { onAnchor(2, $0) }, bump: bumps[2, default: 0]).accessibilitySortPriority(20)
                            // The partner's box sits beside them on the left, in the corner the bid box will take (N55),
                            // since the scorecard holds the right (N66). Level with the top of the face.
                            .overlay(alignment: .topLeading) {
                                if hand.phase == .bidding {
                                    bidBox(at: 2, from: CGSize(width: Theme.Table.bidBoxWidth, height: 0))
                                        .offset(x: -Theme.Table.bidBoxWidth - 4, y: Theme.Table.portraitSize * Theme.Table.portraitHeadroom)
                                }
                            }
                            .opacity(dim)
                        Spacer(minLength: 0)
                        // The right corner stays empty, matching the bid corner's width so the partner sits in the middle;
                        // the portrait book occupies the safe trailing corner above it.
                        corner(width: cornerWidth) {
                            if hand.auction.dealer == model.seat(at: 2), !reworked { DealerMark(onPlaced: onDeck) }
                        }
                        .padding(.top, TableLayout.topCornerClearance)
                    }
                    .onGeometryChange(for: Double.self) { $0.frame(in: .named(Self.column)).maxY } action: { fieldEdges.top = $0 }
                    }
                    // The side tiles give way before the pile can touch them (`TableLayout`); in the auction
                    // there is no pile, so they keep their full width. Faces sit level with the pile's centre,
                    // each beside the card its seat played.
                    // The side tiles keep their play width through the auction too, so the field between them never changes
                    // shape (D97); the auction's boxes are chalked, so they read where they tuck over it.
                    let sideWidth = TableLayout.sideSeatWidth(available: geometry.size.width)
                    // Half the room the phase leaves goes above the side row, half below, so the trick sits in the
                    // middle of the field (D97).
                    Spacer(minLength: 0)
                    HStack(alignment: .center) {
                        // Each side seat's box sits low beside it, toward the empty middle, clear of the partner's name (N55).
                        if arrangement != .rail {
                        SeatView(model: model, seat: model.seat(at: 1), width: sideWidth, puckOnRim: reworked, onField: reworked, onDeck: onDeck, onRename: onRename,
                                 onAnchor: { onAnchor(1, $0) }, bump: bumps[1, default: 0]).accessibilitySortPriority(30)
                            .onGeometryChange(for: Double.self) { $0.frame(in: .named(Self.column)).maxX } action: { fieldEdges.left = $0 }
                            .modifier(DemoTap(active: model.tallyDemo == .face(seat: model.seat(at: 1))))
                            .overlay(alignment: .bottomTrailing) {
                                if hand.phase == .bidding {
                                    bidBox(at: 1, from: CGSize(width: -Theme.Table.bidBoxWidth, height: -Theme.Table.bidBoxHeight))
                                        .offset(x: Theme.Table.bidBoxWidth - Theme.Table.bidBoxTuck)
                                }
                            }
                        }
                        Spacer(minLength: TableLayout.seatGap)
                        // What the partner's row, the status line and the gaps between leave is the trick's to fill (D112).
                        let room = geometry.size.height - Theme.Table.seatInset - (arrangement == .around ? partnerBottom : fieldEdges.top) - lowerHeight - 30
                        if !inAuction { centre(available: geometry.size.width, room: room).zIndex(1) }
                        Spacer(minLength: TableLayout.seatGap)
                        if arrangement != .rail {
                        SeatView(model: model, seat: model.seat(at: 3), width: sideWidth, puckOnRim: reworked, onField: reworked, onDeck: onDeck, onRename: onRename,
                                 onAnchor: { onAnchor(3, $0) }, bump: bumps[3, default: 0]).accessibilitySortPriority(10)
                            .onGeometryChange(for: Double.self) { $0.frame(in: .named(Self.column)).minX } action: { fieldEdges.right = $0 }
                            .overlay(alignment: .bottomLeading) {
                                if hand.phase == .bidding {
                                    bidBox(at: 3, from: CGSize(width: Theme.Table.bidBoxWidth, height: -Theme.Table.bidBoxHeight))
                                        .offset(x: Theme.Table.bidBoxTuck - Theme.Table.bidBoxWidth)
                                }
                            }
                        }
                    }
                    // While bidding there is no pile between them, so the side seats rise toward the partner, and the
                    // bigger faces leave the bid pills their room (N48).
                    .padding(.top, inAuction && !reworked ? -Theme.Table.biddingSideRise : 0)
                    // The field ends just under the side row, so it keeps its size whoever's turn it is (D97).
                    .onGeometryChange(for: Double.self) { $0.frame(in: .named(Self.column)).maxY } action: { fieldEdges.bottom = $0 }
                    .opacity(dim)
                    Spacer(minLength: 4)
                    VStack(spacing: 6) { ForEach(Self.lowerRows(inAuction: inAuction), id: \.self) { row in
                        switch row {
                        case .commentary: commentary
                        case .status:
                            // On your turn in the auction the status line heads the panel instead (D110).
                            if !showsAuctionPanel { statusLine.accessibilitySortPriority(4)
                                .overlay(alignment: .top) {
                                    if Self.commentaryFloats(inAuction: inAuction) {
                                        commentary.padding(.bottom, 4)
                                            .padding(.leading, padOnTable ? padWidth : 0)
                                            .onGeometryChange(for: Double.self) { $0.size.height } action: { floatHeight = $0 }
                                            .offset(y: -floatHeight)
                                    }
                                } }
                        case .controls:
                            // The auction's controls come up in `auctionPanel`, over the table, so they never need room here.
                            EmptyView()
                        }
                    } }
                    .onGeometryChange(for: Double.self) { $0.size.height } action: { lowerHeight = $0 }
                    .onGeometryChange(for: Double.self) { $0.frame(in: .named(Self.column)).minY } action: { lowerTop = $0 }
                    .opacity(dim)
                }
                .coordinateSpace(.named(Self.column))
                .background(alignment: .topLeading) {
                    if let rect = drawnEdges.rect {
                        TableField(rect: rect, trump: arrangement == .around ? nil : hand.trump, lamp: lampPlace, cloth: reworked, colours: model.settings.tableColours).opacity(dim)
                    }
                }
                .padding(.top, Theme.Table.seatInset)
                .onGeometryChange(for: Double.self) { $0.size.height } action: { contentHeight = $0 }
                .frame(width: geometry.size.width)
                .frame(height: fits ? geometry.size.height : nil)
            }
            .scrollBounceBehavior(.basedOnSize)
            // A side face at its big-moment size reaches a little past the column; the screen's margin holds it,
            // so the column clips top and bottom only.
            .scrollClipDisabled()
            .frame(width: geometry.size.width, height: geometry.size.height)
            .mask { Rectangle().padding(.horizontal, -Theme.Table.seatInset) }
            // The score pad lies in the bottom-left corner by the hand while cards are played (D100, D112), at its first
            // size; the words above "Your turn" move over to clear it.
            .overlay(alignment: .bottomLeading) {
                if padOnTable {
                    Scorecard(us: Scorecard.lines(team: model.ourTeam, history: model.match.history),
                              them: Scorecard.lines(team: 1 - model.ourTeam, history: model.match.history),
                              width: TableLayout.cornerWidth(available: geometry.size.width), onOpen: onScorecard)
                        // Drawn at four fifths (the pad's height is fixed), so it lies under the side seat's name (D112).
                        .scaleEffect(TableLayout.padScale, anchor: .bottomLeading)
                        .padding(.bottom, 4)
                        .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
                        .accessibilitySortPriority(3)
                }
            }
            .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay, value: padOnTable)
            .onGeometryChange(for: Double.self) { TableLayout.padWidth(available: $0.size.width) } action: { padWidth = $0 }
            .onGeometryChange(for: Double.self) { $0.size.width } action: { fieldEdges.availableWidth = $0 }
            // No corner deck or discard pile (T12): the deck sits beside the dealer's tile instead.
            // The finished hand's card takes over the table; what is underneath fades back and leaves the
            // accessibility tree, so VoiceOver meets the card and nothing behind it.
            .accessibilityHidden(showsResult)
            // The card takes the whole table and runs down over the bottom row and the empty hand, so the result and
            // its one button fit without scrolling; it starts clear of the Rules book and stops above the name under the hand.
            .overlay { if showsResult, !holdsResult { finishedCard.padding(.top, Theme.Table.resultDrop).padding(.bottom, -Theme.Table.resultSpill) } }
            .overlay(alignment: .bottom) {
                if showsAuctionPanel {
                    auctionPanel.transition(reduceMotion ? .opacity : .offset(y: 12).combined(with: .opacity))
                }
            }
            // The one-time demo of the two taps says what each pulse means, in the middle of the table (N61).
            .overlay {
                if let demo = model.tallyDemo {
                    TallyDemoCaption(text: demo.caption)
                        .padding(.horizontal, Theme.Table.overlayInset)
                        .onTapGesture { withAnimation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay) { model.advanceTallyDemo() } }
                        .transition(.opacity)
                        .id(demo.caption)
                }
            }
        }
        .coordinateSpace(.named(Self.space))
        .accessibilityElement(children: .contain)
    }

    /// The surface's own space, for the top row's lower edge.
    nonisolated static let space = "surface"

    /// The table fades back under the hand-end card, which carries both new totals.
    /// Whether your own cards have all landed; the auction takes no taps while they are still being dealt and hidden.
    private var handLanded: Bool { Self.handLanded(model.humanCards, motion: motion, handNumber: model.match.handNumber) }

    nonisolated static func handLanded(_ cards: [Card], motion: TableMotion?, handNumber: Int) -> Bool {
        guard let motion else { return true }
        return cards.allSatisfy { motion.isInHand($0, handNumber: handNumber) }
    }

    private var dim: Double { showsResult ? 0.12 : 1 }


    /// The place of the seat to act, where the field's lamp sits; nil once the hand or the match is over.
    private var lampPlace: Int? {
        guard model.match.winner == nil, hand.phase != .finished, let seat = hand.nextSeat else { return nil }
        return model.place(of: seat)
    }

    /// The box of the seat at `place` round the table (N55), its call arriving from `from`.
    private func bidBox(at place: Int, from: CGSize) -> some View {
        BidBox(label: BidBox.label(for: model.seat(at: place), in: hand.auction), from: from)
    }

    /// A top corner of the table: a fixed width, top-aligned, empty until it has something to show.
    private func corner(width: Double, @ViewBuilder _ content: () -> some View) -> some View {
        // The clear strut holds the width while the corner is empty, so the partner stays centred.
        ZStack(alignment: .top) {
            Color.clear.frame(width: width, height: 0)
            content()
        }
    }

    // MARK: Pile

    private var padOnTable: Bool { !reworked && Scorecard.liesOnTable(phase: hand.phase, reviewing: reopenedTrick != nil) }

    /// The rail (D113): the three other seats in a row on the oak, left, across, right, as they sit round the table.
    /// In the auction each seat's box hangs under it, over the top of the field.
    private func railRow(available: Double) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach([1, 2, 3], id: \.self) { place in
                SeatView(model: model, seat: model.seat(at: place), width: available / 3, puckOnRim: true, onDeck: onDeck, onRename: onRename,
                         onAnchor: { onAnchor(place, $0) }, bump: bumps[place, default: 0])
                    .accessibilitySortPriority(place == 1 ? 30 : place == 2 ? 20 : 10)
                    .overlay(alignment: .bottom) {
                        if hand.phase == .bidding {
                            bidBox(at: place, from: CGSize(width: 0, height: -Theme.Table.bidBoxHeight))
                                .offset(y: Theme.Table.bidBoxHeight + 4)
                        }
                    }
            }
        }
        // The right-hand seat sits under the Rules book, which hangs below the top row; the row starts clear of it.
        .padding(.top, max(0, TableLayout.topCornerClearance - 60))
        .opacity(dim)
    }

    private var rise: Double { reworked ? TableLayout.tightRise : Theme.Table.trickRise }

    @ViewBuilder private func centre(available: Double, room: Double) -> some View {
        let pile = pile
        PileScale(available: reworked ? available + 2 * TableLayout.minimumSeatWidth : available, room: room,
                  boost: reworked ? TableLayout.trickBoost : 1, rise: rise) { scale in
            ZStack {
                // Reserve the pile's footprint so the layout does not jump between phases. Its height follows the cards'
                // own scale, so the field between the seats always holds the whole trick (D97).
                Color.clear.frame(width: TableLayout.pileReservation(scale: scale), height: TableLayout.pileHeight(scale: scale, rise: rise))
                ForEach(Array(pile.plays.enumerated()), id: \.element.card) { position, play in
                    pileCard(play, position: position, winner: pile.winner, isLast: pile.isLast, trick: pile.trick, scale: scale)
                }
                // Your turn and nothing picked yet: your spot waits, empty (D117).
                if reworked, selected == nil, model.isHumanTurn, hand.phase == .playing, model.match.winner == nil {
                    RoundedRectangle(cornerRadius: Theme.Card.radius(width: Theme.Card.pileWidth * scale), style: .continuous)
                        .strokeBorder(.ivory.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .frame(width: Theme.Card.pileWidth * scale, height: Theme.Card.pileWidth * scale * Theme.Card.ratio)
                        .offset(Self.pileOffset(for: 0, scale: scale, rise: rise))
                        .accessibilityHidden(true)
                }
                // The card you picked, shown faintly where it will land (D116): tap your spot to lay it down.
                if let selected, model.isHumanTurn, hand.phase == .playing, model.allows(.play(selected)) {
                    LayDownSpot(card: selected, width: Theme.Card.pileWidth * scale, action: onLayDown)
                        .offset(Self.pileOffset(for: 0, scale: scale, rise: rise))
                        .zIndex(10)
                        .transition(.opacity)
                }
            }
            .onGeometryChange(for: CGPoint.self) { proxy in
                let frame = proxy.frame(in: .named(TableLayout.space))
                return CGPoint(x: frame.midX, y: frame.midY)
            } action: { onPileCentre($0, scale) }
        }
        .accessibilitySortPriority(5)
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
    }

    /// One card on the field. A play still in the air is drawn by the flight layer and appears here the moment it
    /// lands (D97); the winner of a finished trick is ringed in gold.
    private func pileCard(_ play: Play, position: Int, winner: Int?, isLast: Bool, trick: Int, scale: Double) -> some View {
        let toss = toss(for: play, trick: trick)
        let landed = motion?.hasLanded(playIndex: trick * 4 + position) ?? true
        let offset = Self.pileOffset(for: model.place(of: play.seat), scale: scale, rise: rise) + toss.offset
        let radius = Theme.Card.radius(width: Theme.Card.pileWidth * scale)
        return Button { model.explain(play, inLastTrick: isLast) } label: {
            CardView(card: play.card, width: Theme.Card.pileWidth * scale, style: .pile)
                .dynamicTypeSize(.large)
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.gold, lineWidth: winner == play.seat ? 3 : 0))
        }
        .buttonStyle(.plain)
        .allowsHitTesting(coaching)
        .accessibilityLabel(model.spokenDescription(of: play, winner: winner))
        .accessibilityHint(coaching ? "Explains why this card was played" : "")
        .rotationEffect(.degrees(toss.rotation))
        .offset(offset)
        .opacity(landed ? 1 : 0)
        .transition(reduceMotion ? .opacity : .identity)
        .zIndex(Double(position))
    }

    /// The card's own turn and drift on the pile, fixed for as long as this trick lies there: keyed to the trick's own
    /// number, so a trick does not shift when it completes.
    private func toss(for play: Play, trick: Int) -> CardToss.Pose {
        CardToss.pose(for: play.card, hand: model.match.handNumber, trick: trick)
    }

    /// Where each card rests on the pile: nudged toward the place (0 bottom, 1 left, 2 across, 3 right) of the
    /// seat that played it. `scale` is the cards' own growth with the reader's text size: the top and bottom nudges
    /// grow with it, so cards drawn larger still clear one another; the side ones keep the room the row gives them.
    nonisolated static func pileOffset(for place: Int, scale: Double = 1, rise: Double = Theme.Table.trickRise) -> CGSize {
        switch place {
        case 1: CGSize(width: -Theme.Table.sideNudge * scale, height: 0)
        case 2: CGSize(width: 0, height: -TableLayout.pileRise(scale: scale, rise: rise))
        case 3: CGSize(width: Theme.Table.sideNudge * scale, height: 0)
        default: CGSize(width: 0, height: TableLayout.pileRise(scale: scale, rise: rise))
        }
    }

    /// Unit direction from the pile toward a place round the table.
    static func direction(for place: Int) -> CGSize {
        switch place {
        case 1: CGSize(width: -1, height: 0)
        case 2: CGSize(width: 0, height: -1)
        case 3: CGSize(width: 1, height: 0)
        default: CGSize(width: 0, height: 1)
        }
    }

    // MARK: Status, hints, explanations

    enum LowerRow: Hashable { case commentary, status, controls }

    /// The rows under the pile, top to bottom. In play the column has no height to spare above the hand, so
    /// the notice line ("Discarded: …") takes no row: it floats above "Your turn" in the space the pile
    /// leaves. The auction keeps its call under the controls.
    nonisolated static func lowerRows(inAuction: Bool) -> [LowerRow] {
        inAuction ? [.status, .controls, .commentary] : [.controls, .status]
    }

    nonisolated static func commentaryFloats(inAuction: Bool) -> Bool { !inAuction }

    /// Height the commentary holds even when empty: none in play (it floats), none while your bid controls
    /// need the space.
    nonisolated static func commentaryMinHeight(inAuction: Bool, humanTurn: Bool) -> Double {
        inAuction && !humanTurn ? 36 : 0
    }

    /// The status line while the last trick is reopened: it is the last trick of the hand in play (N42).
    nonisolated static let reviewLabel = "Reviewing last trick"

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
                Text(Self.reviewLabel).font(.title3.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .accessibilityFocused(statusFocus)
                Spacer().frame(width: Theme.Table.statusButtonHitSize, height: Theme.Table.statusButtonHitSize)
            } else {
                // Left: your own box in the auction, its call rising from the bid row (N55). Right: the hint on your
                // turn; in play, reopen the last trick when the pile is clear, on the right since the score pad lies on
                // the left (D100).
                if hand.phase == .bidding {
                    bidBox(at: 0, from: CGSize(width: 0, height: Theme.Table.auctionButtonHeight + Theme.Table.bidBoxHeight))
                } else if hand.phase == .playing {
                    smallButton("gearshape", label: "Settings", action: onSettings)
                } else {
                    Spacer().frame(width: Theme.Table.statusButtonHitSize, height: Theme.Table.statusButtonHitSize)
                }
                // Your turn is the loudest line on the table (T05); everything else stays at a calm weight.
                turnWords.frame(maxWidth: .infinity)
                    // The table no longer prints who is deciding or what was thrown (D98); VoiceOver still hears it here.
                    .accessibilityLabel(Self.spokenStatus(prompt: promptWords, actor: actorWords, notice: model.notice ?? model.boldNote))
                    .accessibilityFocused(statusFocus)
                if model.isHumanTurn, hand.phase != .finished, coaching {
                    smallButton("lightbulb", label: "Hint") { model.showHint() }
                } else if pile.plays.isEmpty, hand.completedTricks.last != nil, hand.phase == .playing {
                    smallButton("rectangle.stack", label: "Show the last hand", action: onReopenTrick)
                } else if model.canUndo {
                    // Undo was built, tested and documented (D28, M4) but the D97 redesign dropped both its homes
                    // (gear menu and toast) without re-homing it; this gives the take-back a reachable control again.
                    smallButton("arrow.uturn.backward", label: "Undo") { model.undo() }
                } else if hand.phase == .bidding {
                    Spacer().frame(width: Theme.Table.bidBoxWidth, height: Theme.Table.bidBoxHeight)
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

    /// Your prompt: gold words on the oak, or, in play on the cloth tables, an ivory plaque that also says how (D117).
    @ViewBuilder private var turnWords: some View {
        if reworked, hand.phase == .playing, let prompt = promptWords {
            VStack(spacing: 0) {
                Text(prompt).font(.system(.title2, design: .serif).weight(.bold))
                Text(selected == nil ? "Tap a card" : "Now tap your spot").font(.footnote.weight(.medium)).opacity(0.75)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            .foregroundStyle(Theme.Paper.ink)
            .padding(.horizontal, 26).padding(.vertical, 4)
            .background(.ivory, in: Capsule())
            .overlay(Capsule().stroke(Theme.Paper.rule, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
        } else {
            statusText.font(model.isHumanTurn ? .title2.weight(.bold) : .title3.weight(.medium))
                .multilineTextAlignment(.center).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    /// The line by the hand speaks only to you (D98): your prompt in gold when it is your move, and nothing otherwise.
    /// Who is bidding, choosing or playing shows on the table itself, by the halo and the lamp.
    private var statusText: Text {
        guard let prompt = promptWords else { return Text(" ") }
        return Text(prompt).foregroundStyle(.gold)
    }

    /// Your prompt, when the next move is yours.
    private var promptWords: String? {
        guard model.match.winner == nil, model.isHumanTurn else { return nil }
        switch hand.phase {
        case .bidding: return "Your bid"
        case .choosingTrump: return "Choose trump"
        case .playing: return "Your turn"
        case .finished: return nil
        }
    }

    /// What the table no longer prints but VoiceOver still reads from the status line (D98).
    private var actorWords: String? {
        if let winner = model.match.winner { return model.winnerHeadline(winner) }
        let actor = hand.nextSeat.map { model.seatNames[$0] } ?? ""
        switch hand.phase {
        case .bidding: return "\(actor) is bidding"
        case .choosingTrump: return "\(actor) is choosing trump"
        case .playing: return nil
        case .finished: return "Hand complete"
        }
    }

    /// The status line's VoiceOver words: your prompt, or who is deciding, then any table notice such as the discards.
    nonisolated static func spokenStatus(prompt: String?, actor: String?, notice: String?) -> String {
        [prompt ?? actor, notice].compactMap { $0 }.joined(separator: ". ")
    }
    /// One line under the status: a refusal, else a hint reason or explanation, else the notice (no undo
    /// toast on the play surface, T07), else the note that a team down 10 is bidding bolder (D71), else your standing call in the auction, else a
    /// placeholder in play. Reserves no space in the auction while the controls need it.
    @ViewBuilder private var commentary: some View {
        ZStack {
            if let refusal = model.refusal {
                // A refused tap answers first: it is the freshest thing the player did.
                // It may take two lines; it grows upward from the status line rather than being cut off (D97).
                Text(refusal).font(.body.weight(.medium)).multilineTextAlignment(.center).foregroundStyle(.ivory)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            } else if let selected, model.isHumanTurn, hand.phase == .playing, !model.allows(.play(selected)) {
                // The first tap picked a card (D97): say how to play it, by name.
                Text(Self.selectedCaption(selected)).font(.body.weight(.semibold)).multilineTextAlignment(.center)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            } else if let hint = model.hint {
                // One complete recommendation on one line; the reason waits behind Why?, so a long hint
                // can never push the controls above it off the screen (spec R22).
                let parts = Self.hintParts(hint.reason)
                HStack(spacing: 10) {
                    Text(parts.recommendation).font(.body.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    if !parts.detail.isEmpty {
                        Button("Why?") { showHintDetail = true }
                            .font(.body.weight(.semibold)).tint(.ivory).underline()
                            .accessibilityHint("Opens the reason for this hint")
                    }
                }
                .foregroundStyle(.ivory)
                .padding(.horizontal, 8)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Hint: \(parts.recommendation)")
            } else if let text = model.explanation {
                Text(text)
                    .font(.body.weight(.medium)).multilineTextAlignment(.center)
                    .foregroundStyle(.ivory)
                    .padding(.horizontal, 8)
            // The discard counts, the "bidding bolder" note and your standing call are no longer printed (D98): the
            // discards are spoken through the status line, and your call is chalked by your own seat.
            } else if !inAuction {
                Text(pile.plays.isEmpty || !coaching ? " " : (reopenedTrick != nil ? "Tap a card to see why it was played" : "Tap a card on the table to see why it was played"))
                    .font(.body.weight(.medium)).foregroundStyle(.ivory)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.commentaryMinHeight(inAuction: inAuction, humanTurn: model.isHumanTurn), alignment: .top)
        // A soft shadow under the words, so the field's edge never runs through them where they rise over it (D97).
        .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
        .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay, value: toast)
        .sheet(isPresented: $showHintDetail) {
            if let hint = model.hint {
                HintDetailView(parts: Self.hintParts(hint.reason))
            }
        }
    }

    /// What the table says while a card waits for its second tap (D97).
    nonisolated static func selectedCaption(_ card: Card) -> String {
        "Tap your spot on the table to play the \(card.label)\(card.suit.glyph)"
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

    /// One pill of the bid row: its number, and whether the seat to act may still bid it.
    struct BidPill: Equatable {
        let bid: Int
        let enabled: Bool
    }

    /// Every bid from 2 to 9, lowest first; the ones the auction has passed stay in place, greyed (N55, over B03).
    nonisolated static func bidRow(allows: (Int) -> Bool) -> [BidPill] {
        HouseRules.bidRange.map { BidPill(bid: $0, enabled: allows($0)) }
    }

    enum AuctionRow: Hashable { case numbers, pass, passWithNineAndOut }

    /// The auction's rows, top to bottom: the numbers, then Pass; when 9 and out may be bid its pill sits at the right
    /// end of the Pass row, under the 9, covering no number (D85), so the auction fits above the hand (D97).
    nonisolated static func auctionRows(nineAndOut: Bool) -> [AuctionRow] {
        nineAndOut ? [.numbers, .passWithNineAndOut] : [.numbers, .pass]
    }

    /// Your turn to bid or to name trump, and the hand's result is not up.
    private var showsAuctionPanel: Bool { model.isHumanTurn && inAuction && !showsResult }

    /// Your call, or your choice of trump, as one dark panel over the lower table (D110): the status line, the calls
    /// so far in words, since the panel lies over the side seats and their boxes, then the controls. It needs no room
    /// in the column, so the auction fits whatever the phone.
    private var auctionPanel: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return VStack(spacing: Theme.Table.auctionButtonSpacing) {
            statusLine.accessibilitySortPriority(4)
            if hand.phase == .bidding {
                Text(Self.callsSoFar(model)).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7).opacity(0.85)
                bidding.allowsHitTesting(handLanded)
            } else {
                trumpChoice
            }
        }
        .padding(8)
        .background(shape.fill(Theme.Wood.header.opacity(0.95)).shadow(color: .black.opacity(0.5), radius: 10, y: 4))
        .overlay(shape.stroke(.ivory.opacity(0.18), lineWidth: 1))
        .accessibilitySortPriority(35)
    }

    /// "JC: Bid 5 · Connor: Pass · Diane: to bid", the other three seats in the order round the table.
    static func callsSoFar(_ model: GameModel) -> String {
        (1...3).map { place in
            let seat = model.seat(at: place)
            return "\(model.seatNames[seat]): \(model.latestCall(for: seat) ?? "to bid")"
        }.joined(separator: " · ")
    }

    /// The auction's controls (B05, N55, D107): green numerals on ivory tiles, in one row when targets fit, otherwise two rows,
    /// the lowest you may bid turned over to ivory on green; under them Pass, and 9 and out beside it in oxblood when
    /// it may be bid. The seats' boxes carry who bid what, so there are no High and Lowest chips.
    private var bidding: some View {
        let row = Self.bidRow { model.allows(.bid($0)) }
        let lowest = row.first(where: \.enabled)?.bid
        return VStack(spacing: Theme.Table.auctionButtonSpacing) {
            if let context = model.auctionContext {
                // A size down from body, never under 15 pt, two lines at most (D97): the dealer's note is the auction's
                // only sentence, and the room it takes is room Pass needs.
                Text(context).font(.footnote.weight(.semibold)).multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.9).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Self.auctionRows(nineAndOut: model.allows(.nineAndOut)), id: \.self) { line in
                switch line {
                case .numbers:
                    // Keep all choices stable; wrap before targets become narrower than 44 pt.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Theme.Table.auctionButtonSpacing) {
                            bidChoices(row, lowest: lowest)
                        }
                        .frame(minWidth: 8 * 44 + 7 * Theme.Table.auctionButtonSpacing)
                        // Two rows sit a little shorter, so the auction still fits above the hand (D97).
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: Theme.Table.auctionButtonSpacing), count: 4), spacing: Theme.Table.auctionButtonSpacing) {
                            bidChoices(row, lowest: lowest, height: Theme.Table.auctionButtonCompactHeight)
                        }
                    }
                    .dynamicTypeSize(...Theme.Card.maximumTypeSize)
                case .pass:
                    passButton
                case .passWithNineAndOut:
                    HStack(spacing: Theme.Table.auctionButtonSpacing) {
                        passButton
                        nineAndOutButton
                    }
                }
            }
        }
        .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay, value: row)
    }

    private var passButton: some View {
        actionButton("Pass", action: .bid(nil), fill: .ivory,
                     font: .system(.title3, design: .serif).weight(.bold), labelColor: Theme.Paper.green, height: Theme.Table.auctionButtonCompactHeight)
    }

    /// Shared controls keep bid order, validation and the lowest-bid outline identical in both layouts.
    private func bidChoices(_ row: [BidPill], lowest: Int?, height: Double = Theme.Table.auctionButtonHeight) -> some View {
        ForEach(row, id: \.bid) { pill in
            // Green numerals on ivory tiles; the lowest bid you may make is the tile turned over, ivory on green.
            actionButton(String(pill.bid), action: .bid(pill.bid), fill: pill.bid == lowest ? Theme.Paper.green : .ivory,
                         font: .system(.title, design: .serif).weight(.bold),
                         labelColor: pill.bid == lowest ? .ivory : Theme.Paper.green, height: height)
                .frame(minWidth: 44)
        }
    }

    /// The rare bid sits beside Pass at the same size, in oxblood so it is never taken for a number.
    private var nineAndOutButton: some View {
        Button { onNineAndOut() } label: {
            Text("9 and out").font(.system(.title3, design: .serif).weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .buttonStyle(PillButtonStyle(fill: Theme.Team.theirRim, height: Theme.Table.auctionButtonCompactHeight))
        .accessibilityHint("Take all nine points or lose the match; asks you to confirm")
    }

    /// Four suit pills, each named for newcomers and captioned with what choosing it keeps and draws.
    /// Suits alternate red and black, ♥ ♠ ♦ ♣, so the two red suits never sit side by side (spec R13).
    nonisolated static let trumpOrder: [Suit] = [.hearts, .spades, .diamonds, .clubs]

    private var trumpChoice: some View {
        HStack(alignment: .top, spacing: Theme.Table.auctionButtonSpacing) {
            ForEach(Self.trumpOrder, id: \.self) { suit in
                VStack(spacing: 2) {
                    // The glyph carries the suit's colour on the same dark pill as every other choice; a red
                    // fill only hid the glyph (spec R13).
                    actionButton(suit.glyph, action: .chooseTrump(suit), fill: .ivory,
                                 font: .largeTitle.weight(.bold),
                                 labelColor: suit.isRed ? Color.suitRed : .black)
                        .accessibilityLabel("\(suit.rawValue), \(model.trumpPreview(for: suit) ?? "")")
                    // The suit on one line and, in beginner mode, what it keeps on a second (spec R30), so no
                    // caption is ever shrunk to fit its column; the draw count is implied and VoiceOver reads it all.
                    // A single row of pills leaves room for two short lines even on the smallest phone (D34).
                    VStack(spacing: 1) {
                        Text(suit.rawValue)
                        if coaching, let keeps = model.trumpPreview(for: suit)?.split(separator: " · ").first {
                            Text(keeps)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    /// Pills fill their column so neighbours almost touch: solid, tall, with a large label.
    private func actionButton(_ label: String, action: PlayerAction, fill: Color = Theme.Wood.inlay,
                              font: Font = .title3.weight(.semibold), labelColor: Color = .ivory,
                              height: Double = Theme.Table.auctionButtonHeight) -> some View {
        // One dry run per pill: the reason, when there is one, is also why the pill is greyed.
        let reason = model.validationMessage(for: action)
        return Button { model.send(action) } label: { Text(label).font(font) }
            .buttonStyle(PillButtonStyle(fill: fill, labelColor: labelColor, height: height))
            .disabled(reason != nil)
            // A greyed pill still says why it is greyed to assistive technology.
            .accessibilityHint(reason ?? "")
    }

    // MARK: Hand end

    private var finishedCard: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    if let winner = model.match.winner { matchOver(winner) }
                    HandSummaryView(match: model.match, names: model.seatNames, outcome: model.lastHandOutcome, review: model.handReview(), difficulty: model.settings.difficulty, describe: model.describe, coaching: coaching)
                    if let line = model.handEndLine { handEndWords(line) }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            // R21: the next phase stays reachable while the result's optional detail scrolls.
            dealButton.padding(.horizontal, 16).padding(.bottom, 16).padding(.top, 6)
        }
        .paperCard()
        .padding(.vertical, 8).padding(.horizontal, Theme.Table.overlayInset)
        .transition(reduceMotion ? .opacity : .offset(y: 12).combined(with: .opacity))
        .accessibilitySortPriority(40)
    }

    /// One seat's line about the hand, under its portrait and name (N36).
    private func handEndWords(_ line: HandEndLine) -> some View {
        HStack(spacing: 10) {
            PortraitView(portrait: Cast.opponent(at: line.seat)?.portrait ?? model.settings.playerPortrait, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.seatNames[line.seat]).font(.caption.weight(.semibold)).foregroundStyle(Theme.Wood.dark)
                Text("\u{201C}\(line.text)\u{201D}").font(.system(.title3, design: .serif).italic()).foregroundStyle(Theme.Wood.header)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private var dealButton: some View {
        Button {
            if model.match.winner == nil { model.nextHand() } else { model.newGame() }
        } label: {
            HStack(spacing: 12) {
                Text(model.match.winner == nil ? "Deal next hand" : "Play again")
                Image(systemName: "arrow.right").accessibilityHidden(true)
            }
        }
        .buttonStyle(PaperButtonStyle())
    }

    /// The card shown once a team reaches 25 or a 9-and-out resolves.
    private func matchOver(_ winner: Int) -> some View {
        VStack(spacing: 3) {
            Text(model.mode == .solo && winner == 0 ? "YOU WIN THE MATCH" : "\(model.teamNames(winner)) WIN")
                .font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(2)
            Text("\(model.match.scores[0]) – \(model.match.scores[1]) after \(model.match.history.count) hands").font(.title3.weight(.semibold))
            if let performance = model.finalPerformance {
                Text("You made \(performance.bidsMade) of \(performance.bids) bids and played the strategy's card \(performance.playsAgreed) of \(performance.plays) times.")
                    .font(.footnote).multilineTextAlignment(.center).opacity(0.8)
            }
        }.foregroundStyle(.black)
    }
}

/// Reads how much cards on the field are scaled by the reader's text size, under the cards' own cap, and hands it to
/// its content (D97).
private struct PileScale<Content: View>: View {
    @ScaledMetric(relativeTo: .title2) private var scale = 1.0
    let available: Double
    /// The height the trick may take; the cards shrink to it before the table has to scroll (D112).
    let room: Double
    /// How much larger than the reader's own scale the cards may be drawn, where the field has the room (D113).
    var boost = 1.0
    var rise = Theme.Table.trickRise
    @ViewBuilder let content: (Double) -> Content
    var body: some View {
        content(TableLayout.pileScale(room: room, preferred: TableLayout.pileScale(available: available, preferred: scale * boost), rise: rise))
    }
}

/// One opponent: a face with its name carved into the wood under it, and the dealer button. A gold ring marks the seat whose
/// turn it is.
struct SeatView: View {
    @ObservedObject var model: GameModel
    let seat: Int
    /// Side tiles take the width the row can spare; the partner's tile keeps the full width.
    var width: Double = Theme.Table.seatTileWidth
    /// The partner across the top: no badge band, so the row stays short, and the dealer's mark set out beside the tile
    /// (`DealerMark.placement(forPlace:)`).
    var isPartner = false
    /// The trial layouts (D113): the dealer button always rides the dealer's face, and there is no deck or badge band.
    var puckOnRim = false
    /// This seat sits on the walnut field, so its name is inlaid light.
    var onField = false
    /// Where the face last was, so the deal can start from the dealer's face when no deck is drawn.
    @State private var faceAt: CGPoint?
    /// The dealer's deck says where it rests.
    var onDeck: (CGPoint) -> Void = { _ in }
    /// The name tag was tapped: rename this seat (D93).
    var onRename: (Int) -> Void = { _ in }
    /// Where the face sits in the table's space, so a card can fly from it and a trick can fly to it (D97).
    var onAnchor: (CGPoint) -> Void = { _ in }
    /// Goes up each time a trick this seat took arrives at its face, which nods once (D97).
    var bump = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The halo's breathing, driven by a repeating animation while this seat is deciding.
    @State private var pulsing = false
    @ScaledMetric(relativeTo: .title2) private var backWidth = Theme.Table.seatBackWidth

    private var hand: Hand { model.match.hand }
    private var active: Bool { hand.nextSeat == seat && model.match.winner == nil }
    private var thinking: Bool { active && !model.isHuman(seat) && hand.phase != .finished }
    /// This seat won the auction, once the auction is over.
    private var isBidder: Bool { hand.auction.nextSeat == nil && hand.auction.winner == seat }
    /// This seat deals the hand and wears the dealer's mark (N65).
    private var deals: Bool { Self.marks(seat: seat, dealer: hand.auction.dealer, bidder: hand.auction.winner).contains(DealerMark.label) }
    /// The player has marked this seat as out of trump (D65).
    private var markedOut: Bool { hand.trump != nil && model.outOfTrump.contains(seat) }

    /// A face over its carved name (D94) over one line of badges: the dealer's mark beside the face
    /// (N65), no stack of backs (D93) and no BIDDER, since the bid box shows who bid. Everything a seat says sits on or under its own portrait, so nothing
    /// about a player floats elsewhere on the table (spec R2). The seat to act wears a gold halo that
    /// breathes; that halo is the table's only turn indicator.
    var body: some View {
        VStack(spacing: 2) {
            ThinkingDots()
                .frame(width: Self.thinkingFrame(width: width).width, height: Self.thinkingFrame(width: width).height)
                .frame(height: Theme.Table.thinkingHeight)
                .opacity(thinking ? 1 : 0)
            // The rim says the side: your team's light, the opponents' oxblood (D97).
            PortraitView(portrait: portrait, size: Theme.Table.portraitSize, expression: expression, popsOut: true,
                         rim: Self.rim(seat: seat, ourTeam: model.ourTeam), rimWidth: Theme.Team.rimWidth)
                .onGeometryChange(for: CGPoint.self) { proxy in
                    let frame = proxy.frame(in: .named(TableLayout.space))
                    return CGPoint(x: frame.midX, y: frame.midY)
                } action: { onAnchor($0); faceAt = $0; if deals, puckOnRim { onDeck($0) } }
                .onChange(of: deals) { _, now in if now, puckOnRim, let faceAt { onDeck(faceAt) } }
                // Big public moments show larger on the face, until the next lead (N36).
                .scaleEffect(bigMomentScale, anchor: .bottom)
                .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay, value: SeatMood.isBigMoment(for: seat, in: model.match))
                // The bidder's ring: dashed, light brown, on the portrait's own edge, never the gold halo (D65).
                .overlay {
                    Circle().strokeBorder(Theme.Wood.streakLight,
                                          style: StrokeStyle(lineWidth: Theme.Table.bidderRingWidth, dash: Theme.Table.bidderRingDash))
                        .opacity(isBidder ? 1 : 0)
                }
                // While the score pad lies in the corner under the left seat, that seat's dealer button rides its face (D112).
                .overlay(alignment: .bottomTrailing) {
                    if puckOnFace { DealerButton().scaleEffect(0.8).offset(x: 12, y: 6).transition(.opacity) }
                }
                .overlay(alignment: .bottomLeading) {
                    if markedOut, let trump = hand.trump { OutOfTrumpBadge(trump: trump).offset(x: -8, y: 2) }
                }
                // Tapping a face marks that seat out of trump, or clears the mark; the player's note, not the game's.
                .contentShape(Circle())
                .onTapGesture { model.toggleOutOfTrump(seat) }
                .overlay {
                    Circle().stroke(.gold, lineWidth: Theme.Table.activeRingWidth)
                        .padding(-Theme.Table.activeRingGap)
                        .opacity(active ? 1 : 0)
                }
                // The popped head goes over the rings as well, so it stays in front of its circle (N49).
                .overlay {
                    PortraitView(portrait: portrait, size: Theme.Table.portraitSize, expression: expression, popsOut: true, headOnly: true)
                        .scaleEffect(bigMomentScale, anchor: .bottom)
                }
                .scaleEffect(pulsing ? Theme.Table.activePulseScale : 1)
                // A trick taken lands in the face, which nods (D97); Reduce Motion keeps it still.
                .keyframeAnimator(initialValue: 1.0, trigger: bump) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        SpringKeyframe(reduceMotion ? 1 : 1.12, duration: 0.14, spring: .snappy)
                        SpringKeyframe(1, duration: 0.32, spring: .bouncy)
                    }
                }
                .onChange(of: active, initial: true) { _, isActive in
                    if isActive, !reduceMotion {
                        withAnimation(Theme.Motion.pulse) { pulsing = true }
                    } else {
                        withAnimation(Theme.Motion.overlay) { pulsing = false }
                    }
                }
                .padding(.vertical, Theme.Table.activeRingGap)
                .padding(.top, Self.portraitTopInset)
            // The name carved into the wood under the face, trump carved beside it for the bidder (D94); a tap renames
            // the seat (D93). Its thumb-tall hit area reaches a little into the face above.
            // A side seat on the field has no width for the suit beside its name; the field's own inlay shows trump there.
            NameTag(name: model.seatNames[seat], trump: puckOnRim ? nil : Self.carvedTrump(seat: seat, bidder: hand.auction.winner, trump: hand.trump), inlaid: onField)
                .renames { onRename(seat) }
                .padding(.top, -8)
            // The partner's tile ends at the name, so the row stays short.
            if placement == .underFace, !puckOnRim { badges }
        }
        .padding(.horizontal, Self.tilePadding).padding(.vertical, 1)
        .frame(width: width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.seatSummary(for: seat) + (markedOut ? ", out of trump" : ""))
        .accessibilityActions {
            Button("Rename \(model.seatNames[seat])") { onRename(seat) }
            if hand.trump != nil {
                Button(markedOut ? "Clear out of trump" : "Mark out of trump") { model.toggleOutOfTrump(seat) }
            }
        }
    }

    /// Room the tile keeps on each side.
    nonisolated static let tilePadding = 4.0
    /// Room above the portrait for everything that rises out of it: the hat's headroom, grown with the face at a
    /// big moment (which scales from the bottom, so all of that growth goes up), half the turn pulse, and the ring.
    nonisolated static var portraitTopInset: Double {
        Theme.Table.portraitSize * (Theme.Table.portraitHeadroom * Theme.Table.bigMomentScale + Theme.Table.bigMomentScale - 1
                                    + (Theme.Table.activePulseScale - 1) / 2)
            + Theme.Table.activeRingGap + Theme.Table.activeRingWidth / 2
    }
    nonisolated static func thinkingFrame(width: Double) -> CGRect {
        CGRect(x: (width - 42) / 2, y: 4, width: 42, height: 14)
    }

    /// The portrait's rim (D97): light for the phone holder's team, oxblood for the other.
    nonisolated static func rim(seat: Int, ourTeam: Int) -> Color {
        seat % 2 == ourTeam ? Theme.Team.ourRim : Theme.Team.theirRim
    }

    /// Where this seat's dealer button rests when it deals (D94).
    private var placement: DealerMark.Placement { DealerMark.placement(forPlace: model.place(of: seat)) }

    /// The suit carved beside a seat's name (D94): trump, for the seat that won the bid, once it is named.
    nonisolated static func carvedTrump(seat: Int, bidder: Int?, trump: Suit?) -> Suit? {
        bidder == seat ? trump : nil
    }

    /// The words a seat wears beside its face: DEALER for the dealer, and nothing for the bidder, whom the bid box
    /// shows (N65).
    nonisolated static func marks(seat: Int, dealer: Int, bidder: Int?) -> [String] {
        dealer == seat ? [DealerMark.label] : []
    }

    /// One band, the same height through a hand, so the tiles do not jump when a call lands or the phase turns: the
    /// dealer's mark when this seat deals (N65). The stack of backs that sat beside it is gone (D93).
    private var badges: some View {
        HStack(spacing: 6) {
            // Deck and button side by side (D97), so the dealer's tile is barely taller and the auction still fits.
            if deals, !puckOnFace { DealerMark(onPlaced: onDeck, sideways: true) }
        }
        .frame(height: deals && !puckOnFace ? nil : backWidth * Theme.Card.ratio + 2)
    }

    private var puckOnFace: Bool { deals && (puckOnRim || Self.puckRidesTheFace(place: model.place(of: seat), phase: hand.phase)) }
    /// The score pad lies in the bottom-left corner while cards are played, over where the left seat's deck would rest;
    /// for that seat, for that phase, the deck is put away and the dealer button sits on the face's rim (D112).
    nonisolated static func puckRidesTheFace(place: Int, phase: HandPhase) -> Bool {
        place == 1 && Scorecard.liesOnTable(phase: phase, reviewing: false)
    }

    private var portrait: Portrait { Cast.opponent(at: seat)?.portrait ?? model.settings.playerPortrait }
    private var expression: Portrait.Expression { SeatMood.expression(for: seat, in: model.match) }
    private var bigMomentScale: Double { SeatMood.isBigMoment(for: seat, in: model.match) ? Theme.Table.bigMomentScale : 1 }
}

/// Whoever deals (N65): a proper deck, much larger than the small stack it replaces, with a dealer button, a round
/// puck with a "D" engraved in it, resting at its foot (D94). Nothing about it is a control.
struct DealerMark: View {
    nonisolated static let label = "DEALER"
    nonisolated static let engraving = "D"

    /// Where the mark rests in front of the dealer's seat: beside the phone holder's name under the hand, under a side
    /// seat's face, or out beside the partner's tile across the top.
    enum Placement: Equatable { case besideYourName, underFace, besideTile }

    nonisolated static func placement(forPlace place: Int) -> Placement {
        switch place {
        case 0: .besideYourName
        case 2: .besideTile
        default: .underFace
        }
    }

    /// Told the deck's centre in the table's coordinate space whenever it moves; the deal starts there.
    var onPlaced: (CGPoint) -> Void = { _ in }
    /// The label beside the deck rather than across its foot, for the short row under the hand.
    var sideways = false

    var body: some View {
        Group {
            if sideways {
                HStack(spacing: 6) { DealerDeck(onPlaced: onPlaced); DealerButton() }
            } else {
                VStack(spacing: -12) { DealerDeck(onPlaced: onPlaced); DealerButton() }.frame(width: Theme.Table.dealerMarkWidth)
            }
        }
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The dealer's deck: a squared stack of backs with no plate, edge or tap, so it reads as a thing on the table and
/// not a button (T13).
struct DealerDeck: View {
    /// Told the deck's centre in the table's coordinate space whenever it moves; the deal starts there.
    var onPlaced: (CGPoint) -> Void = { _ in }

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                CardBackView(width: Theme.Table.dealerMarkDeckWidth).offset(x: Double(index) * -1.5, y: Double(index) * -1.5)
            }
        }
        .onGeometryChange(for: CGPoint.self) { proxy in
            let frame = proxy.frame(in: .named(TableLayout.space))
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: { onPlaced($0) }
        .rotationEffect(.degrees(-8))
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Three dots that brighten in turn: a seat is deciding. Still under Reduce Motion.
struct ThinkingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                if reduceMotion {
                    dot.opacity(0.8)
                } else {
                    dot.phaseAnimator([0, 1, 2]) { view, phase in
                        view.opacity(phase == index ? 1 : 0.35)
                    } animation: { _ in .easeInOut(duration: 0.4) }
                }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Theme.Wood.inlay.opacity(0.85), in: Capsule())
        .accessibilityHidden(true)
    }

    private var dot: some View { Circle().fill(.ivory).frame(width: 6, height: 6) }
}

extension Suit {
    var isRed: Bool { self == .hearts || self == .diamonds }
}

extension Color {
    /// Catch 5 red: the five, hearts/diamonds, and the one primary action on non-felt surfaces.
    static var suitRed: Color { Color(red: 0.698, green: 0.122, blue: 0.180) } // #B21F2E
}

/// The auction's pills: a solid fill, ivory label, a faint edge, dimmed when the rule disallows the
/// action, and a small press. Fills the column it is given.
struct PillButtonStyle: ButtonStyle {
    var fill: Color
    var labelColor: Color = .ivory
    var height = Theme.Table.auctionButtonHeight
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity, minHeight: height)
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

/// Where your picked card will land (D116): the card itself, faint, inside a gold dashed outline that breathes, on
/// your side of the trick. A tap lays the card down. Gold because it is your move, as "Your turn" is.
struct LayDownSpot: View {
    let card: Card
    let width: Double
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Card.radius(width: width), style: .continuous)
        Button(action: action) {
            CardView(card: card, width: width, style: .pile).dynamicTypeSize(.large)
                .opacity(0.45)
                .overlay(shape.strokeBorder(.gold, style: StrokeStyle(lineWidth: 3, dash: [7, 5])))
                .overlay(alignment: .bottom) {
                    Text("Play").font(.system(.headline, design: .serif).weight(.bold)).foregroundStyle(.black)
                        .lineLimit(1).fixedSize()
                        .padding(.horizontal, 12).padding(.vertical, 3)
                        .background(.gold, in: Capsule()).offset(y: 12)
                }
                .scaleEffect(breathing ? 1.04 : 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { breathing = true } } }
        .accessibilityLabel("Play the \(card.spoken)")
    }
}
