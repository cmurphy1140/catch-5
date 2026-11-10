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
    /// How many times each figure has been asked to play: set on first arrival, bumped by a tap.
    @State private var plays: [Chapter: Int] = [:]
    /// How far each figure has played in; a part shows once its beat is reached.
    @State private var beats: [Chapter: Int] = [:]
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
        /// The rule you can try under this chapter, judged live by the engine.
        var trial: RuleTrial.Kind? {
            switch self {
            case .deal: .dealerMatch
            case .play: .followSuit
            case .nineAndOut: .nineAndOutBelowZero
            default: nil
            }
        }

        /// The verbatim paragraphs from `RulesText`, found by title so a new or moved section can never
        /// land under the wrong heading; the last chapter is the screen notes.
        var paragraphs: [String] {
            self == .reading ? RulesText.readingTheTable : groups.flatMap(\.steps)
        }
        /// The chapter a `rules-1` … `rules-6` screenshot stage opens the sheet at; nil for any other stage.
        @MainActor static var staged: Chapter? {
            guard let name = ScreenshotStage.name, name.hasPrefix("rules-"), let number = Int(name.dropFirst(6)) else { return nil }
            return Chapter(rawValue: number - 1)
        }

        /// How many beats the figure plays in on arrival, one part per beat (D107).
        var beats: Int {
            switch self {
            case .table: 6                                  // four seats, the partner line, then 25
            case .deal: 6 + RulesFigures.bidLadder.count + 2 // six cards, each bid, dealer may match, 9 and out
            case .play: RulesFigures.followedTrick.count + 1 // each card, then the winner's ring
            case .scoring: RulesFigures.pointTiles.count
            case .nineAndOut: RulesFigures.nineAndOutPoints + 2 // each point, then "all nine" swells and settles
            case .reading: RulesText.readingTheTable.count
            }
        }
        /// The pause between beats; a trick plays slowly enough to follow, a ladder quickly.
        var beatInterval: Duration {
            switch self {
            case .table: .milliseconds(160)
            case .deal: .milliseconds(80)
            case .play: .milliseconds(320)
            case .scoring: .milliseconds(180)
            case .nineAndOut: .milliseconds(110)
            case .reading: .milliseconds(120)
            }
        }

        /// The chapter's labeled runs of steps; the screen notes have none.
        var groups: [RulesText.Group] { RulesText.sections.first { $0.title == title }?.groups ?? [] }
    }

    private var motion: Animation { reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay }
    /// The chapter the rail should light: the one just chosen, else the one under the top edge, else the first.
    private var shownChapter: Chapter { chosen ?? current ?? .table }

    // MARK: Play on arrival (D107)

    private func beat(_ chapter: Chapter) -> Int { beats[chapter] ?? 0 }

    private func replay(_ chapter: Chapter) { plays[chapter, default: 0] += 1 }

    /// Plays a figure in, one part per beat. Reduce Motion fades straight to the whole figure.
    private func play(_ chapter: Chapter) async {
        guard plays[chapter] != nil else { return }
        if reduceMotion {
            withAnimation(Theme.Motion.reduced) { beats[chapter] = chapter.beats }
            return
        }
        beats[chapter] = 0
        for next in 1...chapter.beats {
            try? await Task.sleep(for: chapter.beatInterval)
            if Task.isCancelled { return }
            withAnimation(Theme.Motion.arrival) { beats[chapter] = next }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    // Six panels, all realised, so a jump to any chapter always has a target.
                    VStack(spacing: 20) {
                        // Where the game comes from, before any rule (D66).
                        Text(RulesText.origin)
                            .font(.system(.body, design: .serif).italic())
                            .multilineTextAlignment(.center)
                            .opacity(0.9)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                        ForEach(Chapter.allCases) { chapter in
                            panel(chapter).id(chapter)
                        }
                        signOff
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
                // The jump waits one beat so every panel has laid out and the target exists.
                .task {
                    if ScreenshotStage.name == "signoff" {
                        try? await Task.sleep(for: .milliseconds(900))
                        proxy.scrollTo("signoff", anchor: .bottom)
                        return
                    }
                    guard let initial else { return }
                    chosen = initial
                    try? await Task.sleep(for: .milliseconds(80))
                    proxy.scrollTo(initial, anchor: .top)
                }
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

    /// The family's note after the last chapter, and a link that opens a new mail (N34).
    private var signOff: some View {
        VStack(spacing: 10) {
            Text(RulesText.signOff)
                .font(.system(.body, design: .serif).italic())
                .multilineTextAlignment(.center)
                .opacity(0.9)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: RulesText.contactURL) {
                Text(RulesText.contactEmail).font(.body.weight(.semibold)).underline()
            }
            .foregroundStyle(.ivory)
                .accessibilityHint("Opens a new email")
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .id("signoff")
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
                        .background(active ? Theme.Wood.dark : Theme.Wood.inlay, in: Capsule())
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
        .background(Theme.Wood.inlay)
    }

    // MARK: Panels

    private func panel(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(chapter.numeral).font(.system(.title, design: .serif).weight(.bold)).foregroundStyle(.gold)
                Text(chapter.title).font(.system(.title2, design: .serif).weight(.semibold))
            }
            figure(chapter)
                .contentShape(Rectangle())
                // Taps on the figure's own controls (the trick toggle, the point tiles) go to them first.
                .onTapGesture { replay(chapter) }
                .accessibilityAction(named: "Play again") { replay(chapter) }
                .modifier(OnArrival { if plays[chapter] == nil { plays[chapter] = 1 } })
                .task(id: plays[chapter]) { await play(chapter) }
            // The last chapter is the screen notes themselves, drawn once with icons.
            if chapter != .reading { rule(chapter) }
            if let trial = chapter.trial { RuleTrialView(kind: trial) }
        }
        .padding(18)
        .background(Theme.Wood.inlay.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.ivory.opacity(0.12)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chapter \(chapter.rawValue + 1), \(chapter.title)")
    }

    /// The rule as written, always visible: the letter of the rule under the picture of it, one rule
    /// per line under the document's own labels, so a long paragraph reads as a few short steps.
    private func rule(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("THE RULE AS WRITTEN")
                .font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1).opacity(0.6)
            ForEach(chapter.groups, id: \.label) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.label).font(.system(.subheadline, design: .serif).weight(.semibold)).foregroundStyle(.gold)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(group.steps, id: \.self) { step in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(.ivory.opacity(0.5)).frame(width: 4, height: 4).alignmentGuide(.firstTextBaseline) { $0[.bottom] + 4 }
                                .accessibilityHidden(true)
                            Text(step).font(.subheadline).lineSpacing(2).opacity(0.92)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
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
        let b = beat(.table)
        // Opponent 1 (your partner) across, the other two at the sides, you at the bottom; each drops in from outside.
        let seats: [(portrait: Portrait, name: String, at: CGSize)] = [
            (Cast.opponents[0].portrait, Cast.opponents[0].name, CGSize(width: -96, height: 0)),
            (Cast.opponents[1].portrait, Cast.opponents[1].name, CGSize(width: 0, height: -70)),
            (Cast.opponents[2].portrait, Cast.opponents[2].name, CGSize(width: 96, height: 0)),
            (Cast.defaultPlayerPortrait, "You", CGSize(width: 0, height: 70)),
        ]
        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                Ellipse().stroke(.ivory.opacity(0.25), lineWidth: 1.5).frame(width: 150, height: 90)
                // The partner line draws between you and your partner once all four are seated.
                Rectangle().fill(.gold.opacity(0.5)).frame(width: 1.5, height: 116)
                    .scaleEffect(x: 1, y: b >= 5 || reduceMotion ? 1 : 0)
                    .opacity(b >= 5 ? 1 : 0)
                ForEach(Array(seats.enumerated()), id: \.offset) { index, seat in
                    self.seat(seat.portrait, seat.name)
                        .arrives(b > index, from: CGSize(width: seat.at.width * 0.4, height: seat.at.height * 0.4), scale: 0.3, reduce: reduceMotion)
                        .offset(seat.at)
                }
            }
            .frame(width: 236, height: 186)
            .dynamicTypeSize(...Theme.Card.maximumTypeSize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.seatingLabel)
            VStack(spacing: 0) {
                Text("FIRST TO").font(.system(.caption2, design: .monospaced)).tracking(1).opacity(0.6)
                Text(b >= 6 ? RulesFigures.matchTarget : 0, format: .number)
                    .font(.system(size: 44, weight: .bold, design: .serif)).foregroundStyle(.gold)
                    .contentTransition(.numericText(value: Double(b >= 6 ? RulesFigures.matchTarget : 0)))
                    .monospacedDigit()
                Text("wins").font(.footnote).opacity(0.7)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("First to \(RulesFigures.matchTarget) wins")
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
            PortraitView(portrait: portrait, size: 38)
            Text(name).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    // MARK: II. Deal and bidding

    private var dealFigure: some View {
        let b = beat(.deal)
        let ladder = RulesFigures.bidLadder
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                // Six cards leave the deck one at a time and settle into a fan.
                ZStack {
                    ForEach(0..<6, id: \.self) { index in
                        let dealt = b > index || reduceMotion
                        CardBackView(width: 34)
                            .rotationEffect(.degrees(dealt ? Double(index - 3) * 7 : 0), anchor: .bottom)
                            .offset(x: dealt ? Double(index - 3) * 12 : -40, y: dealt ? 0 : -24)
                            .opacity(b > index ? 1 : 0)
                    }
                }
                .frame(width: 140, height: 62)
                .dynamicTypeSize(...Theme.Card.maximumTypeSize)
                .accessibilityHidden(true)
                Text("Six cards each, three at a time, starting left of the dealer.").font(.subheadline).opacity(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // The bid ladder: 2 at the bottom, 9 at the top, and 9 and out above them all.
            VStack(spacing: 6) {
                Text("9 and out · from a score of 0 or above").font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 10).frame(minHeight: 30)
                    .overlay(Capsule().stroke(.gold, lineWidth: 1.5))
                    .foregroundStyle(.gold)
                    .arrives(b >= 6 + ladder.count + 2, scale: 0.8, reduce: reduceMotion)
                HStack(spacing: 4) {
                    ForEach(Array(ladder.enumerated()), id: \.element) { index, bid in
                        Text(bid, format: .number).font(.headline).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity).frame(minHeight: 38)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .arrives(b > 6 + index, from: CGSize(width: 0, height: 10), scale: 0.8, reduce: reduceMotion)
                    }
                }
                HStack {
                    Text("must beat the last bid").font(.caption2).opacity(b > 6 ? 0.6 : 0)
                    Spacer()
                    Text("dealer may match").font(.caption2).foregroundStyle(.gold)
                        .arrives(b >= 6 + ladder.count + 1, from: CGSize(width: 12, height: 0), scale: 1, reduce: reduceMotion)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bids run from \(HouseRules.bidRange.lowerBound) to \(HouseRules.bidRange.upperBound), each beating the last; the dealer may match instead. 9 and out sits above them all and needs a score of 0 or above.")
        }
    }

    // MARK: III. Play

    /// Where each seat's card flies in from: your partner across the table, the opponents at the sides, you below.
    private static func flightStart(_ seat: Int) -> CGSize {
        switch seat {
        case 1: CGSize(width: -70, height: 0)
        case 2: CGSize(width: 0, height: -60)
        case 3: CGSize(width: 70, height: 0)
        default: CGSize(width: 0, height: 60)
        }
    }

    private var playFigure: some View {
        let b = beat(.play)
        let plays = trumped ? RulesFigures.trumpedTrick : RulesFigures.followedTrick
        let winner = trumped ? RulesFigures.trumpedWinner : RulesFigures.followedWinner
        return VStack(spacing: 12) {
            Picker("Example", selection: $trumped) {
                Text("Following suit").tag(false)
                Text("Trumped").tag(true)
            }
            .pickerStyle(.segmented)
            Text(RulesFigures.setting).font(.caption).opacity(0.75).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                // Played in turn, one card a beat; the ring lands on the winner after the last card.
                ForEach(Array(plays.enumerated()), id: \.element.seat) { index, play in
                    VStack(spacing: 4) {
                        CardView(card: play.card, width: 56, style: .rest, ring: b > plays.count && play.seat == winner ? .gold : nil)
                            .scaleEffect(b > plays.count && play.seat == winner && !reduceMotion ? 1.08 : 1)
                            .arrives(b > index, from: Self.flightStart(play.seat), scale: 0.7, reduce: reduceMotion)
                        Text(Cast.opponent(at: play.seat)?.name ?? "You").font(.caption2).opacity(0.75)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
            .dynamicTypeSize(...Theme.Card.maximumTypeSize)
            Text(RulesFigures.caption(trumped: trumped))
                .font(.subheadline).multilineTextAlignment(.center)
                .opacity(b > plays.count ? 0.9 : 0)
                .fixedSize(horizontal: false, vertical: true)
        }
        // A new example plays from the first card again.
        .onChange(of: trumped) { _, _ in replay(.play) }
        .accessibilityElement(children: .contain)
    }

    // MARK: IV. Scoring

    private var scoringFigure: some View {
        let b = beat(.scoring)
        let tiles = RulesFigures.pointTiles
        let total = tiles.prefix(b).map(\.points).reduce(0, +)
        return VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(Array(tiles.enumerated()), id: \.element.name) { index, tile in
                    let open = openTile == tile.name
                    let shown = b > index
                    Button { withAnimation(motion) { openTile = open ? nil : tile.name } } label: {
                        VStack(spacing: 2) {
                            Text(tile.points, format: .number)
                                .font(.system(tile.points == 5 ? .largeTitle : .title2, design: .serif).weight(.bold))
                                .foregroundStyle(tile.points == 5 ? .gold : .ivory)
                            Text(tile.name).font(.caption2.weight(.semibold))
                        }
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity).frame(minHeight: 72)
                        .background(open ? .white.opacity(0.12) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(open ? .ivory.opacity(0.5) : .clear))
                    }
                    .buttonStyle(.plain)
                    // Each tile turns over in turn; the Five lands big and settles.
                    .rotation3DEffect(.degrees(shown || reduceMotion ? 0 : -90), axis: (x: 0, y: 1, z: 0))
                    .arrives(shown, from: .zero, scale: tile.points == 5 ? 1.6 : 0.9, reduce: reduceMotion)
                    .accessibilityLabel("\(tile.name), \(tile.points) \(tile.points == 1 ? "point" : "points")")
                    .accessibilityHint(tile.meaning)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text("POINTS IN A HAND").font(.system(.caption2, design: .monospaced)).tracking(1).opacity(0.6)
                Spacer()
                Text(total, format: .number).font(.system(.title3, design: .serif).weight(.bold)).foregroundStyle(.gold)
                    .monospacedDigit().contentTransition(.numericText(value: Double(total)))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(RulesFigures.nineAndOutPoints) points in a hand")
            if let openTile, let tile = tiles.first(where: { $0.name == openTile }) {
                Text(tile.meaning).font(.subheadline).multilineTextAlignment(.center).opacity(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            } else {
                Text("Tap a tile to see how it is won.").font(.footnote).opacity(0.6)
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
        let b = beat(.nineAndOut)
        let points = RulesFigures.nineAndOutPoints
        return VStack(spacing: 10) {
            // The meter fills a point a beat; when it is full, "all nine" swells once and settles.
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<points, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(.gold).frame(height: 22)
                        .scaleEffect(x: 1, y: b > index || reduceMotion ? 1 : 0.1, anchor: .bottom)
                        .opacity(b > index ? 1 : 0.15)
                }
            }
            .accessibilityHidden(true)
            HStack(alignment: .top) {
                Text("all nine").font(.subheadline.weight(.bold)).foregroundStyle(.gold)
                    .scaleEffect(b == points + 1 && !reduceMotion ? 1.25 : 1, anchor: .leading)
                Text("or nothing: fewer than nine loses the match, whatever the score. Only a team at 0 or above may bid it.")
                    .font(.subheadline).opacity(0.85)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: VI. Reading the table

    private var readingFigure: some View {
        let b = beat(.reading)
        let symbols = ["number", "person.crop.rectangle.stack", "rectangle.on.rectangle.slash", "lightbulb", "gearshape"]
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(RulesText.readingTheTable.enumerated()), id: \.offset) { index, note in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbols[min(index, symbols.count - 1)]).font(.subheadline).foregroundStyle(.gold).frame(width: 20)
                    Text(note).font(.subheadline).opacity(0.9).fixedSize(horizontal: false, vertical: true)
                }
                .arrives(b > index, from: CGSize(width: -16, height: 0), scale: 1, reduce: reduceMotion)
            }
        }
    }
}

/// Runs once the view is at least a third on screen; before iOS 18 there is no visibility signal, so on appear.
private struct OnArrival: ViewModifier {
    let action: () -> Void
    func body(content: Content) -> some View {
        if #available(iOS 18, macOS 15, *) {
            content.onScrollVisibilityChange(threshold: 0.35) { visible in if visible { action() } }
        } else {
            content.onAppear(perform: action)
        }
    }
}

private extension View {
    /// Hidden until `shown`, then springs in from `offset` and `scale`; Reduce Motion keeps only the fade.
    func arrives(_ shown: Bool, from offset: CGSize = CGSize(width: 0, height: 14), scale: CGFloat = 0.6, reduce: Bool) -> some View {
        opacity(shown ? 1 : 0)
            .scaleEffect(shown || reduce ? 1 : scale)
            .offset(shown || reduce ? .zero : offset)
    }

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
