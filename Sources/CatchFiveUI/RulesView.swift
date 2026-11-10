import CatchFive
import SwiftUI

/// The rulebook as a guided walk: six chapters, each an ivory card on dark wood that opens with a figure built
/// from the table's own pieces, gives the rule as written, and ends with a button to the next chapter. A chapter
/// rail under the title scrolls to a chapter and lights up as the reader passes it.
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
        /// The name on the rail and the Next button, where the ampersand saves a line.
        var short: String { self == .deal ? "Deal & bidding" : title }
        /// The chapter's paragraphs under their headings. The first chapter's are split into the three things it
        /// says; the words stay the rules document's own.
        var sections: [(heading: String?, text: String)] {
            guard self == .table, paragraphs.count == 2, let stop = paragraphs[0].range(of: ". ") else {
                return paragraphs.map { (nil, $0) }
            }
            return [("Players & teams", String(paragraphs[0][..<stop.lowerBound]) + "."),
                    ("Winning the game", String(paragraphs[0][stop.upperBound...])),
                    ("The first dealer", paragraphs[1])]
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
                        // Where the game comes from, before any rule (D66).
                        Text(RulesText.origin)
                            .font(.system(.body, design: .serif).italic())
                            .multilineTextAlignment(.center)
                            .opacity(0.9)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                        ForEach(Chapter.allCases) { chapter in
                            panel(chapter, proxy).id(chapter)
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
            .background(WoodGrainView().overlay(.black.opacity(0.5)).ignoresSafeArea())
            .navigationTitle("How to play")
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
                            Text(chapter.short).font(.system(.footnote, design: .serif).weight(.semibold))
                        }
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(active ? .ivory : .clear, in: Capsule())
                        .overlay(Capsule().stroke(.gold.opacity(active ? 1 : 0.55), lineWidth: active ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(active ? Theme.Paper.green : .ivory)
                    .accessibilityLabel("Chapter \(chapter.rawValue + 1), \(chapter.title)")
                    .accessibilityAddTraits(active ? .isSelected : [])
                    // Chips carry their own ids so the page's reader never mistakes a chip for a panel.
                    .id("chip-\(chapter.rawValue)")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .background(Theme.Wood.header)
    }

    // MARK: Panels

    private func panel(_ chapter: Chapter, _ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(chapter.numeral).font(.system(.headline, design: .serif).weight(.bold)).foregroundStyle(.ivory)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: 38, height: 38)
                    .background(Theme.Paper.green, in: Circle())
                    .overlay(Circle().stroke(Theme.Paper.rule, lineWidth: 1.5))
                Text(chapter.title).font(.system(.title, design: .serif).weight(.bold))
            }
            figure(chapter)
            // The last chapter is the screen notes themselves, drawn once with icons.
            if chapter != .reading { rule(chapter) }
            if let trial = chapter.trial { RuleTrialView(kind: trial) }
            if let next = Chapter(rawValue: chapter.rawValue + 1) {
                Button { chosen = next; withAnimation(motion) { proxy.scrollTo(next, anchor: .top) } } label: {
                    HStack(spacing: 12) {
                        Text("Next: \(next.short)")
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                    }
                }
                .buttonStyle(PaperButtonStyle())
            }
        }
        .padding(18)
        .foregroundStyle(Theme.Paper.ink)
        .paperCard()
        // The card is paper whatever the sheet around it is, so its system controls draw for light.
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chapter \(chapter.rawValue + 1), \(chapter.title)")
    }

    /// The rule as written, always visible: the letter of the rule under the picture of it.
    private func rule(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(chapter.sections, id: \.text) { section in
                Rectangle().fill(Theme.Paper.rule).frame(height: 1).accessibilityHidden(true)
                if let heading = section.heading {
                    Text(heading).font(.system(.title3, design: .serif).weight(.bold)).foregroundStyle(Theme.Paper.green)
                        .accessibilityAddTraits(.isHeader)
                }
                Text(section.text).font(.body).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
                Ellipse().fill(Theme.Paper.green).overlay(Ellipse().stroke(Theme.Paper.rule, lineWidth: 2)).frame(width: 120, height: 72)
                Rectangle().fill(Theme.Paper.rule).frame(width: 1, height: 72)
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
                Text("FIRST TO").font(.caption.weight(.medium)).tracking(2)
                Text(RulesFigures.matchTarget, format: .number)
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                Text("wins").font(.subheadline)
            }
            .foregroundStyle(.ivory)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.Paper.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.Paper.rule, lineWidth: 1.5))
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
                    .overlay(Capsule().stroke(Theme.Paper.rule, lineWidth: 1.5))
                    .foregroundStyle(Theme.Paper.green)
                HStack(spacing: 4) {
                    ForEach(RulesFigures.bidLadder, id: \.self) { bid in
                        Text(bid, format: .number).font(.subheadline.weight(.semibold)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity).frame(minHeight: 32)
                            .background(Theme.Paper.tan, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                HStack {
                    Text("must beat the last bid").font(.caption2).opacity(0.6)
                    Spacer()
                    Text("dealer may match").font(.caption2.weight(.semibold)).foregroundStyle(Theme.Paper.green)
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
            Text(RulesFigures.setting).font(.caption).opacity(0.75).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            let plays = trumped ? RulesFigures.trumpedTrick : RulesFigures.followedTrick
            let winner = trumped ? RulesFigures.trumpedWinner : RulesFigures.followedWinner
            HStack(spacing: 10) {
                // Keyed by seat, so the one card that changes between the two tricks animates in place.
                ForEach(plays, id: \.seat) { play in
                    VStack(spacing: 4) {
                        CardView(card: play.card, width: 44, style: .rest, ring: play.seat == winner ? Theme.Paper.green : nil)
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
                                .foregroundStyle(tile.points == 5 ? Theme.Paper.green : Theme.Paper.ink)
                            Text(tile.name).font(.caption2.weight(.semibold))
                        }
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity).frame(minHeight: 64)
                        .background(open ? Theme.Paper.wash : Theme.Paper.tan, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(open ? Theme.Paper.green : .clear, lineWidth: 1.5))
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
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Theme.Paper.green).frame(height: 14)
                }
            }
            .accessibilityHidden(true)
            HStack(alignment: .top) {
                Text("all nine").font(.footnote.weight(.semibold)).foregroundStyle(Theme.Paper.green)
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
                    Image(systemName: symbols[min(index, symbols.count - 1)]).font(.footnote).foregroundStyle(Theme.Paper.green).frame(width: 18)
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
            .toolbarBackground(Theme.Wood.header, for: .navigationBar)
        #else
        return self
        #endif
    }
}
