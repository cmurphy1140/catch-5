import CatchFive
import SwiftUI

/// The rulebook as a guided walk: six chapters on the felt, each opening with a figure built from the
/// table's own pieces and closing with the rule as written, always visible. A chapter rail under the
/// title scrolls to a chapter and lights up as the reader passes it. The tutorial is wood, pills and
/// exercises; this is felt, panels and figures, so the two read as different rooms.
struct RulesView: View {
    let onDismiss: () -> Void
    /// Opens the sheet at this chapter; nil leaves the reader at the top.
    let initial: Chapter?
    /// The chapter under the top edge, read from the scroll view; never written, so the column never
    /// shifts sideways (writing a `scrollPosition` inside content margins does).
    @State private var current: Chapter?
    /// The chapter last chosen from the rail or `initial`; lights its chip until the reader scrolls on.
    @State private var chosen: Chapter?

    init(initial: Chapter? = nil, onDismiss: @escaping () -> Void) {
        self.initial = initial
        self.onDismiss = onDismiss
    }
    @State private var trumped = false
    @State private var openTile: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Chapter: Int, CaseIterable, Identifiable {
        case table, deal, play, scoring, nineAndOut, reading
        var id: Int { rawValue }
        var numeral: String {
            switch self {
            case .table: "I"
            case .deal: "II"
            case .play: "III"
            case .scoring: "IV"
            case .nineAndOut: "V"
            case .reading: "VI"
            }
        }
        var title: String {
            switch self {
            case .table: "The table"
            case .deal: "Deal and bidding"
            case .play: "Play"
            case .scoring: "Scoring"
            case .nineAndOut: "9 and out"
            case .reading: "Reading the table"
            }
        }
        /// The verbatim paragraphs from `RulesText`, found by title so a new or moved section can never
        /// land under the wrong heading; the last chapter is the screen notes.
        var paragraphs: [String] {
            self == .reading ? RulesText.readingTheTable
                : RulesText.sections.first { $0.title == title }?.paragraphs ?? []
        }
    }

    private var motion: Animation { reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay }
    /// The chapter the rail should light: the one just chosen, else the one under the top edge, else the first.
    private var shownChapter: Chapter { chosen ?? current ?? .table }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    // Six panels, all realised, so a jump to any chapter always has a target.
                    VStack(spacing: 20) {
                        ForEach(Chapter.allCases) { chapter in
                            panel(chapter).id(chapter)
                        }
                    }
                    .scrollTargetLayout()
                    .frame(maxWidth: 640).frame(maxWidth: .infinity)
                }
                // Margins rather than padding, so scroll targets are measured where they are drawn.
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .contentMargins(.top, 12, for: .scrollContent)
                // Enough room below the last chapter for it to reach the top edge like the others.
                .contentMargins(.bottom, 240, for: .scrollContent)
                .scrollPosition(id: $current, anchor: .top)
                .safeAreaInset(edge: .top, spacing: 0) { rail(proxy) }
                .onAppear { if let initial { chosen = initial; proxy.scrollTo(initial, anchor: .top) } }
                // A tap's choice stays lit until the page arrives there; a drag hands control back to the scroll.
                .onChange(of: current) { _, now in if now == chosen { chosen = nil } }
                .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { _ in chosen = nil })
            }
            .foregroundStyle(.ivory)
            .background(LinearGradient(colors: [.felt, .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
            .navigationTitle("How to play Catch 5")
            .toolbar { Button("Done", action: onDismiss) }
            .compactOpaqueBar()
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Rail

    /// One chip per chapter. Tapping scrolls there; the chip for the chapter under the top edge glows,
    /// and the rail slides to keep that chip in view.
    private func rail(_ proxy: ScrollViewProxy) -> some View {
        ScrollViewReader { railProxy in
            railChips(proxy)
                .onChange(of: shownChapter) { _, chapter in
                    withAnimation(motion) { railProxy.scrollTo("chip-\(chapter.rawValue)", anchor: .center) }
                }
        }
    }

    private func railChips(_ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Chapter.allCases) { chapter in
                    let active = shownChapter == chapter
                    Button { chosen = chapter; withAnimation(motion) { proxy.scrollTo(chapter, anchor: .top) } } label: {
                        HStack(spacing: 6) {
                            Text(chapter.numeral).font(.system(.caption, design: .serif).weight(.bold))
                            Text(chapter.title).font(.footnote.weight(.semibold))
                        }
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, 12).frame(minHeight: 44)
                        .background(active ? .gold.opacity(0.18) : Theme.Wood.inlay.opacity(0.6), in: Capsule())
                        .overlay(Capsule().stroke(active ? .gold : .ivory.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(active ? .gold : .ivory)
                    .accessibilityLabel("Chapter \(chapter.rawValue + 1), \(chapter.title)")
                    .accessibilityAddTraits(active ? .isSelected : [])
                    // Chips carry their own ids so the page's reader never mistakes a chip for a panel.
                    .id("chip-\(chapter.rawValue)")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: Panels

    private func panel(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(chapter.numeral).font(.system(.title, design: .serif).weight(.bold)).foregroundStyle(.gold)
                Text(chapter.title).font(.system(.title2, design: .serif).weight(.semibold))
            }
            figure(chapter)
            // The last chapter is the screen notes themselves, drawn once with icons.
            if chapter != .reading { rule(chapter) }
        }
        .padding(18)
        .background(Theme.Wood.inlay.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.ivory.opacity(0.12)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chapter \(chapter.rawValue + 1), \(chapter.title)")
    }

    /// The rule as written, always visible: the letter of the rule under the picture of it.
    private func rule(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE RULE AS WRITTEN")
                .font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1).opacity(0.6)
            ForEach(chapter.paragraphs, id: \.self) { paragraph in
                Text(paragraph).font(.footnote).lineSpacing(2).opacity(0.92)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 12)
        .overlay(alignment: .leading) { Rectangle().fill(.gold.opacity(0.6)).frame(width: 2) }
    }

    @ViewBuilder private func figure(_ chapter: Chapter) -> some View {
        switch chapter {
        case .table: tableFigure
        case .deal: dealFigure
        case .play: playFigure
        case .scoring: scoringFigure
        case .nineAndOut: nineAndOutFigure
        case .reading: readingFigure
        }
    }

    // MARK: I. The table

    private var tableFigure: some View {
        HStack(alignment: .center, spacing: 16) {
            // Four seats around a small oval; partners face each other.
            ZStack {
                Ellipse().stroke(.ivory.opacity(0.25), lineWidth: 1.5).frame(width: 120, height: 72)
                Rectangle().fill(.gold.opacity(0.35)).frame(width: 1, height: 96)
                seat(Cast.opponents[1].portrait, Cast.opponents[1].name).offset(y: -58)
                seat(Cast.opponents[0].portrait, Cast.opponents[0].name).offset(x: -78)
                seat(Cast.opponents[2].portrait, Cast.opponents[2].name).offset(x: 78)
                seat(Cast.defaultPlayerPortrait, "You").offset(y: 58)
            }
            .frame(width: 200, height: 150)
            .dynamicTypeSize(...Theme.Card.maximumTypeSize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.seatingLabel)
            VStack(spacing: 0) {
                Text("FIRST TO").font(.system(.caption2, design: .monospaced)).tracking(1).opacity(0.6)
                Text(RulesFigures.matchTarget, format: .number)
                    .font(.system(.largeTitle, design: .serif).weight(.bold)).foregroundStyle(.gold)
                Text("wins").font(.footnote).opacity(0.7)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
    }

    /// Composed from the cast so a renamed or reordered cast reads the same to VoiceOver as to the eye.
    static var seatingLabel: String {
        let names = Cast.opponents.map(\.name)
        return "Four seats around the table. You and \(names[1]) are partners, facing each other; \(names[0]) and \(names[2]) are the other team. First to \(RulesFigures.matchTarget) wins."
    }

    private func seat(_ portrait: Portrait, _ name: String) -> some View {
        VStack(spacing: 2) {
            PortraitView(portrait: portrait, size: 30)
            Text(name).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    // MARK: II. Deal and bidding

    private var dealFigure: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    ForEach(0..<6, id: \.self) { index in
                        CardBackView(width: 26)
                            .rotationEffect(.degrees(Double(index - 3) * 6), anchor: .bottom)
                            .offset(x: Double(index - 3) * 9)
                    }
                }
                .frame(width: 110, height: 48)
                .dynamicTypeSize(...Theme.Card.maximumTypeSize)
                .accessibilityHidden(true)
                Text("Six cards each, three at a time, starting left of the dealer.").font(.footnote).opacity(0.85)
            }
            // The bid ladder: 2 at the bottom, 9 at the top, and 9 and out above them all.
            VStack(spacing: 4) {
                Text("9 and out · from a score of 0 or above").font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 10).frame(minHeight: 28)
                    .overlay(Capsule().stroke(.gold, lineWidth: 1.5))
                    .foregroundStyle(.gold)
                HStack(spacing: 4) {
                    ForEach(RulesFigures.bidLadder, id: \.self) { bid in
                        Text(bid, format: .number).font(.subheadline.weight(.semibold)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity).frame(minHeight: 32)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                HStack {
                    Text("must beat the last bid").font(.caption2).opacity(0.6)
                    Spacer()
                    Text("dealer may match").font(.caption2).foregroundStyle(.gold)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bids run from \(HouseRules.bidRange.lowerBound) to \(HouseRules.bidRange.upperBound), each beating the last; the dealer may match instead. 9 and out sits above them all and needs a score of 0 or above.")
        }
    }

    // MARK: III. Play

    private var playFigure: some View {
        VStack(spacing: 10) {
            Picker("Example", selection: $trumped) {
                Text("Following suit").tag(false)
                Text("Trumped").tag(true)
            }
            .pickerStyle(.segmented)
            let plays = trumped ? RulesFigures.trumpedTrick : RulesFigures.followedTrick
            let winner = trumped ? RulesFigures.trumpedWinner : RulesFigures.followedWinner
            HStack(spacing: 10) {
                // Keyed by seat, so the one card that changes between the two tricks animates in place.
                ForEach(plays, id: \.seat) { play in
                    VStack(spacing: 4) {
                        CardView(card: play.card, width: 44, style: .rest, ring: play.seat == winner ? .gold : nil)
                        Text(Cast.opponent(at: play.seat)?.name ?? "You").font(.caption2).opacity(0.75)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
            .dynamicTypeSize(...Theme.Card.maximumTypeSize)
            .animation(motion, value: trumped)
            Text(RulesFigures.caption(trumped: trumped))
                .font(.footnote).multilineTextAlignment(.center).opacity(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: IV. Scoring

    private var scoringFigure: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(RulesFigures.pointTiles, id: \.name) { tile in
                    let open = openTile == tile.name
                    Button { withAnimation(motion) { openTile = open ? nil : tile.name } } label: {
                        VStack(spacing: 2) {
                            Text(tile.points, format: .number)
                                .font(.system(tile.points == 5 ? .largeTitle : .title2, design: .serif).weight(.bold))
                                .foregroundStyle(tile.points == 5 ? .gold : .ivory)
                            Text(tile.name).font(.caption2.weight(.semibold))
                        }
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity).frame(minHeight: 64)
                        .background(open ? .white.opacity(0.12) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(open ? .ivory.opacity(0.5) : .clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tile.name), \(tile.points) \(tile.points == 1 ? "point" : "points")")
                    .accessibilityHint(tile.meaning)
                }
            }
            if let openTile, let tile = RulesFigures.pointTiles.first(where: { $0.name == openTile }) {
                Text(tile.meaning).font(.footnote).multilineTextAlignment(.center).opacity(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            } else {
                Text("Nine points in a hand. Tap one to see how it is won.").font(.footnote).opacity(0.6)
            }
            // The Game ledger: what each captured card counts toward the Game point.
            HStack(spacing: 0) {
                Text("GAME VALUES").font(.system(.caption2, design: .monospaced)).tracking(1).opacity(0.6)
                Spacer()
                ForEach(RulesFigures.gameValues, id: \.rank) { entry in
                    HStack(spacing: 2) {
                        Text(entry.rank.label).font(.caption.weight(.semibold))
                        Text("=\(entry.value)").font(.caption.monospacedDigit()).opacity(0.75)
                    }
                    .padding(.leading, 10)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Game values: " + RulesFigures.gameValues.map { "\($0.rank.label) counts \($0.value)" }.joined(separator: ", ") + "; other cards nothing.")
        }
    }

    // MARK: V. 9 and out

    private var nineAndOutFigure: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<RulesFigures.nineAndOutPoints, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(.gold).frame(height: 14)
                }
            }
            .accessibilityHidden(true)
            HStack(alignment: .top) {
                Text("all nine").font(.footnote.weight(.semibold)).foregroundStyle(.gold)
                Text("or nothing: fewer than nine loses the match, whatever the score. Only a team at 0 or above may bid it.")
                    .font(.footnote).opacity(0.85)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: VI. Reading the table

    private var readingFigure: some View {
        let symbols = ["number", "person.crop.rectangle.stack", "rectangle.on.rectangle.slash", "lightbulb", "gearshape"]
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(RulesText.readingTheTable.enumerated()), id: \.offset) { index, note in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbols[min(index, symbols.count - 1)]).font(.footnote).foregroundStyle(.gold).frame(width: 18)
                    Text(note).font(.footnote).opacity(0.9).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private extension View {
    /// A compact, opaque title bar so the chapters scroll under a solid edge; the modifiers are iOS-only.
    func compactOpaqueBar() -> some View {
        #if os(iOS)
        return navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.felt, for: .navigationBar)
        #else
        return self
        #endif
    }
}
