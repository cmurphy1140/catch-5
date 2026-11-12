import Foundation
import SwiftUI

/// The engineering explainer, read natively from the docs themselves. `docs/learning-path.md` is the
/// contents page: its reading-order table names the chapters and its glossary the Swift vocabulary.
/// Each chapter is that doc's full Markdown, bundled under `Explainer/docs`, with every Mermaid
/// diagram rendered to `Explainer/diagrams/<file>-<n>.png` by `scripts/export-docs.py --app`.
public enum ExplainerLibrary {
    public static let folder = "Explainer"

    struct Chapter: Equatable, Hashable, Identifiable {
        let number: Int
        /// The doc's file name without `.md`, e.g. "architecture".
        let file: String
        /// "What you will understand afterwards", from the learning path's table.
        let summary: String
        var id: String { file }
    }

    struct GlossaryEntry: Equatable {
        let term: String
        let meaning: String
        let where_: String
    }

    /// The learning path itself, bundled so the contents page is never typed twice.
    static let contentsChapter = Chapter(number: 0, file: "learning-path", summary: "The front door to the living documentation.")

    /// The reading order: the first table of the learning path, one row per chapter.
    static func chapters(from learningPath: MarkdownDocument) -> [Chapter] {
        guard let table = learningPath.blocks.compactMap({ block -> (header: [String], rows: [[String]])? in
            if case let .table(header, rows) = block, header.first == "Step" { return (header, rows) }
            return nil
        }).first else { return [] }
        return table.rows.compactMap { row in
            guard row.count >= 3, let number = Int(row[0]), let file = linkTarget(in: row[1]) else { return nil }
            return Chapter(number: number, file: file.replacingOccurrences(of: ".md", with: ""), summary: row[2])
        }
    }

    /// The Swift vocabulary table: term, meaning, where it appears.
    static func glossary(from learningPath: MarkdownDocument) -> [GlossaryEntry] {
        guard let table = learningPath.blocks.compactMap({ block -> [[String]]? in
            if case let .table(header, rows) = block, header.first == "Term" { return rows }
            return nil
        }).first else { return [] }
        return table.filter { $0.count >= 3 }.map { GlossaryEntry(term: $0[0], meaning: $0[1], where_: $0[2]) }
    }

    /// "[architecture.md](architecture.md)" → "architecture.md".
    static func linkTarget(in cell: String) -> String? {
        guard let open = cell.range(of: "]("), let close = cell.range(of: ")", range: open.upperBound..<cell.endIndex) else { return nil }
        return String(cell[open.upperBound..<close.lowerBound])
    }

    public static func markdownURL(for file: String, in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: file, withExtension: "md", subdirectory: "\(folder)/docs")
    }

    public static func diagramURL(for file: String, index: Int, in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "\(file)-\(index)", withExtension: "png", subdirectory: "\(folder)/diagrams")
    }

    static func document(for file: String, in bundle: Bundle = .main) -> MarkdownDocument? {
        guard let url = markdownURL(for: file, in: bundle), let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return MarkdownDocument.parse(text)
    }

    /// About 200 words a minute, never under one minute.
    static func readingMinutes(_ document: MarkdownDocument) -> Int {
        readingMinutes(words: document.blocks.reduce(0) { $0 + $1.words })
    }

    static func readingMinutes(words: Int) -> Int {
        max(1, Int((Double(words) / 200).rounded()))
    }

    /// What a chapter's card on the contents shelf says about it (D147).
    struct Facts: Equatable, Identifiable {
        let chapter: Chapter
        let title: String
        let minutes: Int
        let sections: Int
        let diagrams: Int
        var id: String { chapter.id }
    }

    static func facts(for chapter: Chapter, in bundle: Bundle = .main) -> Facts {
        let document = document(for: chapter.file, in: bundle)
        return Facts(chapter: chapter, title: document?.title ?? chapter.file, minutes: document.map(readingMinutes) ?? 0,
                     sections: document?.sections.count ?? 0, diagrams: document?.diagramCount ?? 0)
    }

    /// A count as tally marks: full gates of five, and the strokes left over.
    static func tally(_ count: Int) -> (gates: Int, loose: Int) { (max(0, count) / 5, max(0, count) % 5) }

    /// The largest count a card draws mark by mark; a bigger one is written as a number.
    static let drawnUpTo = 15

    /// One short page of a chapter: a `##` section, or one part of a long one.
    struct Page: Equatable, Hashable, Identifiable {
        let file: String
        /// The section's heading text, or "Overview" for what sits above the first section.
        let title: String
        let part: Int
        let parts: Int
        /// The section's blocks for this part, without its `##` heading.
        let blocks: [MarkdownDocument.Block]
        /// Position in the chapter's page list, from 0.
        let number: Int
        var id: String { "\(file)#\(number)" }
        var words: Int { blocks.reduce(0) { $0 + $1.words } }
        var minutes: Int { ExplainerLibrary.readingMinutes(words: words) }
        var hasDiagram: Bool { blocks.contains { if case .diagram = $0 { true } else { false } } }
    }

    /// One card in a chapter's list: a section, opening on its first page; Next walks through the rest of its parts.
    /// A split section gets one card, not one per part, since its parts are cut by length and have no names of their own.
    struct Card: Equatable, Identifiable {
        let first: Page
        let parts: Int
        let words: Int
        let hasDiagram: Bool
        var id: String { first.id }
        var minutes: Int { ExplainerLibrary.readingMinutes(words: words) }
    }

    /// The chapter's cards: each run of a section's parts folded into one.
    static func cards(for pages: [Page]) -> [Card] {
        var cards: [Card] = []
        for page in pages {
            if page.part > 1, let last = cards.last, last.first.title == page.title {
                cards[cards.count - 1] = Card(first: last.first, parts: last.parts + 1, words: last.words + page.words,
                                              hasDiagram: last.hasDiagram || page.hasDiagram)
            } else {
                cards.append(Card(first: page, parts: 1, words: page.words, hasDiagram: page.hasDiagram))
            }
        }
        return cards
    }

    /// About a minute and a half of reading; a longer section is split into parts.
    static let pageWords = 300

    /// Chapters whose sections read newest first: the decision log appends at the bottom.
    static let newestFirst: Set<String> = ["decisions"]

    /// The chapter as short pages: an Overview of what precedes the first `##`, then one page per
    /// `##` section (reversed for `newestFirst` files). A section over `pageWords` is split at its
    /// `###` headings, then at block boundaries, and a long table by rows, each part repeating the
    /// header. A block that cannot be cut stays whole on its own page.
    static func pages(of document: MarkdownDocument, file: String) -> [Page] {
        var overview: [MarkdownDocument.Block] = []
        var sections: [(title: String, blocks: [MarkdownDocument.Block])] = []
        var titled = false
        for block in document.blocks {
            if case let .heading(2, text) = block {
                sections.append((text, []))
            } else if sections.isEmpty {
                if case .heading(1, _) = block, !titled { titled = true } else { overview.append(block) }
            } else {
                sections[sections.count - 1].blocks.append(block)
            }
        }
        if newestFirst.contains(file) { sections.reverse() }
        if !overview.isEmpty { sections.insert(("Overview", overview), at: 0) }

        var pages: [Page] = []
        for section in sections {
            let parts = split(section.blocks)
            for (offset, blocks) in parts.enumerated() {
                pages.append(Page(file: file, title: section.title, part: offset + 1, parts: parts.count, blocks: blocks, number: pages.count))
            }
        }
        return pages
    }

    /// A section's blocks in parts of at most `pageWords`: its `###` subsections grouped while they
    /// fit, and any group still too long cut between blocks.
    static func split(_ blocks: [MarkdownDocument.Block]) -> [[MarkdownDocument.Block]] {
        let words = { (blocks: [MarkdownDocument.Block]) in blocks.reduce(0) { $0 + $1.words } }
        guard words(blocks) > pageWords else { return [blocks] }
        var subsections: [[MarkdownDocument.Block]] = [[]]
        for block in blocks {
            if case .heading(3, _) = block, !subsections[subsections.count - 1].isEmpty { subsections.append([]) }
            subsections[subsections.count - 1].append(block)
        }
        var groups: [[MarkdownDocument.Block]] = []
        for subsection in subsections where !subsection.isEmpty {
            if let last = groups.last, words(last) + words(subsection) <= pageWords {
                groups[groups.count - 1] += subsection
            } else {
                groups.append(subsection)
            }
        }
        return groups.flatMap { words($0) > pageWords ? splitBetweenBlocks($0) : [$0] }
    }

    /// Cuts between blocks, never leaving a heading at the foot of a part; a long table is cut by rows.
    private static func splitBetweenBlocks(_ blocks: [MarkdownDocument.Block]) -> [[MarkdownDocument.Block]] {
        var parts: [[MarkdownDocument.Block]] = []
        var current: [MarkdownDocument.Block] = []
        var currentWords = 0
        func close() {
            // Headings at the end move on with the text they introduce.
            var carried: [MarkdownDocument.Block] = []
            while case .heading? = current.last { carried.insert(current.removeLast(), at: 0) }
            if !current.isEmpty { parts.append(current) }
            current = carried
            currentWords = 0
        }
        for block in blocks {
            var pieces = [block]
            if block.words > pageWords, case let .table(header, rows) = block {
                pieces = tableParts(header: header, rows: rows)
            }
            for (offset, piece) in pieces.enumerated() {
                if currentWords > 0, currentWords + piece.words > pageWords { close() }
                current.append(piece)
                currentWords += piece.words
                // Every table part but the last fills a page of its own.
                if offset < pieces.count - 1 { close() }
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    /// A table's rows in runs of at most `pageWords`, each run under the same header.
    private static func tableParts(header: [String], rows: [[String]]) -> [MarkdownDocument.Block] {
        var runs: [[[String]]] = []
        var words = 0
        for row in rows {
            let rowWords = MarkdownDocument.Block.table(header: header, rows: [row]).words
            if let last = runs.last, !last.isEmpty, words + rowWords <= pageWords {
                runs[runs.count - 1].append(row)
                words += rowWords
            } else {
                runs.append([row])
                words = rowWords
            }
        }
        return runs.map { .table(header: header, rows: $0) }
    }
}

/// The contents page (D147): a spiral notebook lying on the wood. Its Modules tab is a shelf of index cards that
/// scrolls sideways, one chapter to a card; its Swift vocab tab is the glossary.
struct ExplainerView: View {
    let onDismiss: () -> Void
    @State private var contents: MarkdownDocument?
    @State private var open: ExplainerLibrary.Chapter?
    @State private var tab = Tab.modules
    /// The card the shelf has come to rest on.
    @State private var facing: String?
    private let shelf: [ExplainerLibrary.Facts]

    enum Tab: String, CaseIterable { case modules = "Modules", vocab = "Swift vocab" }

    /// `initial` opens straight into a chapter by file name; nil shows the contents page.
    init(initial: String? = nil, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        let contents = ExplainerLibrary.document(for: ExplainerLibrary.contentsChapter.file)
        let chapters = contents.map(ExplainerLibrary.chapters) ?? []
        _contents = State(initialValue: contents)
        _open = State(initialValue: chapters.first { $0.file == initial })
        shelf = chapters.map { ExplainerLibrary.facts(for: $0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Green cloth, where the pages about playing wear burgundy (D184); the lede rides on it.
                ClothHeader(title: "How Catch 5 is built", onDone: onDismiss, colours: .green) {
                    if case let .paragraph(lede)? = contents?.blocks.dropFirst().first {
                        // Its first sentence only: the page under it says the rest.
                        MarkdownText(lede.components(separatedBy: ". ").first.map { $0.hasSuffix(".") ? $0 : $0 + "." } ?? lede).font(.subheadline).opacity(0.9)
                            .lineLimit(3).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 14)
                    }
                }
                if let contents {
                    notebook(contents)
                } else {
                    Text("The explainer pages are not in this build.").opacity(0.7).padding()
                    Spacer()
                }
            }
            .foregroundStyle(.ivory)
            .background(WoodGrainView().ignoresSafeArea())
            .navigationTitle("How Catch 5 is built")
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(item: $open) { chapter in
                DocumentReaderView(chapter: chapter, chapters: chapters) { open = $0 }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var chapters: [ExplainerLibrary.Chapter] { shelf.map(\.chapter) }

    private func notebook(_ contents: MarkdownDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            tabs
            switch tab {
            case .modules: modules
            case .vocab:
                ScrollView { glossarySection(ExplainerLibrary.glossary(from: contents)).padding(.trailing, 18).padding(.bottom, 30) }
            }
        }
        .padding(.leading, SpiralBinding.margin)
        .foregroundStyle(Theme.Paper.ink)
        .frame(maxWidth: 640, maxHeight: .infinity, alignment: .top)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6).fill(Color.ivory)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        }
        .overlay(alignment: .leading) { SpiralBinding().allowsHitTesting(false) }
        .padding(.leading, 18).padding(.trailing, 10)
        .ignoresSafeArea(edges: .bottom)
    }

    /// Two words on the page; the open one is underlined in green.
    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button { withAnimation(.easeOut(duration: 0.18)) { tab = item } } label: {
                    Text(item.rawValue).font(.system(.subheadline, design: .serif).weight(.bold))
                        .foregroundStyle(tab == item ? Theme.Paper.green : Theme.Paper.ink.opacity(0.6))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .overlay(alignment: .bottom) { Rectangle().fill(tab == item ? Theme.Paper.green : .clear).frame(height: 2) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Paper.rule.opacity(0.5)).frame(height: 0.5) }
        .padding(.trailing, 14)
    }

    /// The shelf: chapter cards side by side, coming to rest one at a time, with the place written under them.
    private var modules: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(shelf) { facts in
                        Button { open = facts.chapter } label: { ModuleCard(facts: facts) }
                            .buttonStyle(.plain)
                            .containerRelativeFrame(.horizontal) { width, _ in min(width * 0.82, 320) }
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 16)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $facing)
            .contentMargins(.trailing, 18, for: .scrollContent)
            .contentMargins(.leading, 4, for: .scrollContent)
            Text("\((shelf.firstIndex { $0.id == facing } ?? 0) + 1) of \(shelf.count)")
                .font(.custom("Noteworthy-Bold", size: 15, relativeTo: .footnote)).opacity(0.6)
                .padding(.bottom, 34).accessibilityHidden(true)
        }
    }

    private func glossarySection(_ entries: [ExplainerLibrary.GlossaryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(entries, id: \.term) { entry in
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.term.replacingOccurrences(of: "`", with: "")).font(.title3.weight(.bold)).foregroundStyle(Theme.Paper.green)
                    MarkdownText(entry.meaning).font(.subheadline).opacity(0.85)
                    MarkdownText(entry.where_).font(.caption).opacity(0.6)
                    PaperRule().padding(.top, 9)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 14)
    }
}

/// One chapter as an index card on the shelf (D147): its number, its name over a red rule, what it teaches, and at
/// the foot its measures, drawn rather than listed.
private struct ModuleCard: View {
    let facts: ExplainerLibrary.Facts

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%02d", facts.chapter.number)).font(.system(size: 54, weight: .heavy, design: .serif)).foregroundStyle(Color.suitRed)
                Spacer()
                Image(systemName: "arrow.right").font(.body.weight(.semibold)).opacity(0.55)
            }
            // Three cards lifted apart, the top one in the chapter's suit: a stand-in until each chapter has its own
            // painted picture (D184).
            LayeredCards(number: facts.chapter.number).frame(maxWidth: .infinity).frame(height: 150).accessibilityHidden(true)
            Text(facts.title).font(.system(.title2, design: .serif).weight(.bold)).foregroundStyle(Theme.Paper.green)
                .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.leading)
            Rectangle().fill(Color.suitRed.opacity(0.45)).frame(height: 1)
            Text(facts.chapter.summary).font(.callout).multilineTextAlignment(.leading).minimumScaleFactor(0.8)
            Spacer(minLength: 12)
            HStack(alignment: .bottom, spacing: 0) {
                measure("\(facts.minutes) min") { ClockWedge(minutes: facts.minutes).frame(width: 34, height: 34) }
                measure("section\(facts.sections == 1 ? "" : "s")", count: facts.sections) { SectionTally(count: facts.sections) }
                if facts.diagrams > 0 {
                    measure("diagram\(facts.diagrams == 1 ? "" : "s")", count: facts.diagrams) { DiagramDots(count: facts.diagrams) }
                }
            }
            .accessibilityHidden(true)
        }
        .foregroundStyle(Theme.Paper.ink)
        .padding(18)
        .frame(maxHeight: 520, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color(red: 0.995, green: 0.985, blue: 0.955))
                .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(facts.chapter.number). \(facts.title). \(facts.chapter.summary)")
        .accessibilityValue("\(facts.minutes) minutes, \(facts.sections) sections, \(facts.diagrams) diagrams")
        .accessibilityAddTraits(.isButton)
    }

    /// A drawing over its caption. A count too big to draw is written as a number in the same hand.
    private func measure(_ caption: String, count: Int? = nil, @ViewBuilder drawing: () -> some View) -> some View {
        VStack(spacing: 4) {
            if let count, count > ExplainerLibrary.drawnUpTo {
                Text(String(count)).font(.custom("Noteworthy-Bold", fixedSize: 26))
            } else {
                drawing()
            }
            Text(count.map { $0 > ExplainerLibrary.drawnUpTo ? caption : "\($0) \(caption)" } ?? caption)
                .font(.custom("Noteworthy-Bold", fixedSize: 13)).opacity(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .bottom)
    }
}

/// Three cards seen from above and to one side, lifted apart like layers: a back, a tan card and a face whose suit
/// turns with the chapter's number.
struct LayeredCards: View {
    let number: Int

    nonisolated static let suits = ["♥", "♣", "♦", "♠"]
    /// The suit on the top card: hearts for chapter 1, then clubs, diamonds, spades, and round again.
    nonisolated static func suit(for number: Int) -> String { suits[((number - 1) % 4 + 4) % 4] }

    var body: some View {
        let suit = Self.suit(for: number), red = suit == "♥" || suit == "♦"
        ZStack {
            layer(fill: Color.suitRed, ink: Color.gold, mark: nil).offset(y: 38)
            layer(fill: Color(red: 0.90, green: 0.78, blue: 0.52), ink: Theme.Paper.green, mark: "♣").offset(y: 6)
            layer(fill: .ivory, ink: red ? Color.suitRed : Theme.Paper.ink, mark: suit).offset(y: -26)
        }
        .dynamicTypeSize(.large)
    }

    private func layer(fill: Color, ink: Color, mark: String?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return shape.fill(fill)
            .overlay(shape.stroke(ink.opacity(0.6), lineWidth: 1).padding(6))
            .overlay { if let mark { Text(mark).font(.system(size: 54)).foregroundStyle(ink) } }
            .frame(width: 124, height: 176)
            .rotationEffect(.degrees(-58))
            .scaleEffect(x: 1, y: 0.5)
            .shadow(color: .black.opacity(0.3), radius: 4, y: 5)
    }
}

/// Reading time as a clock face: the green wedge is the share of an hour the chapter takes.
private struct ClockWedge: View {
    let minutes: Int

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2), radius = min(size.width, size.height) / 2 - 1.5
            var wedge = Path()
            wedge.move(to: centre)
            wedge.addArc(center: centre, radius: radius, startAngle: .degrees(-90),
                         endAngle: .degrees(-90 + 360 * min(1, Double(minutes) / 60)), clockwise: false)
            wedge.closeSubpath()
            context.fill(wedge, with: .color(Theme.Paper.green.opacity(0.8)))
            context.stroke(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(Theme.Paper.ink.opacity(0.8)), lineWidth: 1.4)
            var hand = Path()
            hand.move(to: centre); hand.addLine(to: CGPoint(x: centre.x, y: centre.y - radius))
            context.stroke(hand, with: .color(Theme.Paper.ink.opacity(0.8)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }
}

/// Sections kept as a card player keeps score: pencil strokes, every fifth one struck across the four before it.
private struct SectionTally: View {
    let count: Int
    private static let step = 5.0, gap = 7.0, height = 26.0

    var body: some View {
        let tally = ExplainerLibrary.tally(count)
        let width = Double(tally.gates) * (Self.step * 4 + Self.gap) + Double(tally.loose) * Self.step + 2
        Canvas { context, _ in
            let pencil = GraphicsContext.Shading.color(Theme.Paper.ink.opacity(0.8))
            let style = StrokeStyle(lineWidth: 1.6, lineCap: .round)
            var x = 2.0
            func stroke(lean: Double) {
                var line = Path()
                line.move(to: CGPoint(x: x + lean, y: 3)); line.addLine(to: CGPoint(x: x - lean, y: Self.height - 3))
                context.stroke(line, with: pencil, style: style)
                x += Self.step
            }
            for _ in 0..<tally.gates {
                let start = x
                for mark in 0..<4 { stroke(lean: mark % 2 == 0 ? 0.6 : -0.4) }
                var strike = Path()
                strike.move(to: CGPoint(x: start - 2, y: Self.height - 7)); strike.addLine(to: CGPoint(x: x - 2, y: 7))
                context.stroke(strike, with: pencil, style: style)
                x += Self.gap - Self.step + Self.step
            }
            for mark in 0..<tally.loose { stroke(lean: mark % 2 == 0 ? 0.6 : -0.4) }
        }
        .frame(width: max(width, 6), height: Self.height)
    }
}

/// Diagrams as a little diagram: one dot for each, joined in a zigzag.
private struct DiagramDots: View {
    let count: Int

    var body: some View {
        let step = count > 1 ? min(11, 60 / Double(count - 1)) : 0
        Canvas { context, _ in
            let points = (0..<count).map { CGPoint(x: 4 + Double($0) * step, y: $0 % 2 == 0 ? 20 : 6) }
            var line = Path()
            line.addLines(points)
            context.stroke(line, with: .color(Theme.Paper.ink.opacity(0.6)), lineWidth: 1.2)
            for point in points {
                context.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)), with: .color(Color.suitRed))
            }
        }
        .frame(width: 8 + Double(max(0, count - 1)) * step, height: 26)
    }
}

/// The wire down the notebook's left edge: a punched hole in the paper for each coil, and the coil itself coming
/// out past the edge.
private struct SpiralBinding: View {
    /// How far the page's writing is kept clear of the holes.
    static let margin = 30.0
    private static let overhang = 12.0

    var body: some View {
        Canvas { context, size in
            var y = 20.0
            while y < size.height {
                context.fill(Path(ellipseIn: CGRect(x: Self.overhang + 9, y: y - 4.5, width: 9, height: 9)),
                             with: .color(Color(red: 0.24, green: 0.15, blue: 0.09)))
                let coil = Path(roundedRect: CGRect(x: 0, y: y - 2.5, width: Self.overhang + 15, height: 5), cornerRadius: 2.5)
                context.fill(coil, with: .color(Color(white: 0.42)))
                context.fill(Path(roundedRect: CGRect(x: 1, y: y - 2.5, width: Self.overhang + 13, height: 1.6), cornerRadius: 0.8),
                             with: .color(.white.opacity(0.45)))
                y += 26
            }
        }
        .frame(width: Self.overhang + Self.margin)
        .offset(x: -Self.overhang)
    }
}

/// One chapter as a list of short pages; tapping a card opens that page on top.
struct DocumentReaderView: View {
    let chapter: ExplainerLibrary.Chapter
    let chapters: [ExplainerLibrary.Chapter]
    /// A link to another doc, or the Previous and Next buttons, opens that chapter in place.
    let openChapter: (ExplainerLibrary.Chapter) -> Void
    @State private var document: MarkdownDocument?
    @State private var pages: [ExplainerLibrary.Page] = []
    @State private var reading: ExplainerLibrary.Page?

    var body: some View {
        ScrollView {
            if let document {
                VStack(alignment: .leading, spacing: 14) {
                    MarkdownText(document.title).font(.system(size: 40, weight: .semibold, design: .serif))
                        .minimumScaleFactor(0.6).accessibilityAddTraits(.isHeader)
                    Text("\(ExplainerLibrary.readingMinutes(document)) min · \(document.sections.count) sections\(document.diagramCount > 0 ? " · \(document.diagramCount) diagram\(document.diagramCount == 1 ? "" : "s")" : "")")
                        .font(.subheadline).opacity(0.65)
                    PaperRule()
                    Text(chapter.summary).font(.title3).opacity(0.8).fixedSize(horizontal: false, vertical: true)
                    Text("In this chapter").font(.subheadline.weight(.bold)).foregroundStyle(Theme.Paper.green).padding(.top, 12)
                    VStack(spacing: 0) {
                        ForEach(ExplainerLibrary.cards(for: pages)) { card in
                            PaperRule()
                            Button { reading = card.first } label: { pageCard(card) }.buttonStyle(.plain)
                        }
                        PaperRule()
                    }
                    neighbours
                }
                .padding(.horizontal, 22).padding(.vertical, 16).frame(maxWidth: 640).frame(maxWidth: .infinity)
            } else {
                Text("This chapter is not in this build.").foregroundStyle(.secondary).padding()
            }
        }
        .modifier(PaperPage())
        .toolbar {
            if let position = chapters.firstIndex(of: chapter) {
                Text("Chapter \(position + 1) of \(chapters.count)").font(.subheadline.weight(.semibold)).foregroundStyle(.ivory.opacity(0.9))
            }
        }
        .environment(\.openURL, chapterLinks)
        .navigationDestination(item: $reading) { page in
            PageReaderView(pages: pages, start: page.number, next: nextChapter, close: { reading = nil }, open: open)
                .environment(\.openURL, chapterLinks)
        }
        .task(id: chapter.file) {
            reading = nil
            document = ExplainerLibrary.document(for: chapter.file)
            pages = document.map { ExplainerLibrary.pages(of: $0, file: chapter.file) } ?? []
        }
    }

    /// Leaves any open page, then shows the other chapter's page list.
    private func open(_ other: ExplainerLibrary.Chapter) {
        reading = nil
        openChapter(other)
    }

    /// A relative link to a sibling doc opens that chapter; anything else goes to the system.
    private var chapterLinks: OpenURLAction {
        OpenURLAction { url in
            let target = url.lastPathComponent.replacingOccurrences(of: ".md", with: "")
            if url.scheme == nil || url.isFileURL, let chapter = chapters.first(where: { $0.file == target }) {
                open(chapter)
                return .handled
            }
            return .systemAction
        }
    }

    private var nextChapter: ExplainerLibrary.Chapter? {
        chapters.firstIndex(of: chapter).flatMap { $0 + 1 < chapters.count ? chapters[$0 + 1] : nil }
    }

    private func pageCard(_ card: ExplainerLibrary.Card) -> some View {
        // A ruled line of the page, not a box (D147).
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                MarkdownText(card.first.title).font(.headline).multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text(card.parts > 1 ? "\(card.parts) parts · \(card.minutes) min" : "\(card.minutes) min")
                    if card.hasDiagram {
                        Image(systemName: "point.3.connected.trianglepath.dotted").accessibilityLabel("with a diagram")
                    }
                }
                .font(.subheadline).opacity(0.6)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundStyle(Theme.Paper.green)
        }
        .padding(.vertical, 12).frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var neighbours: some View {
        let position = chapters.firstIndex(of: chapter)
        let previous = position.flatMap { $0 > 0 ? chapters[$0 - 1] : nil }
        let next = position.flatMap { $0 + 1 < chapters.count ? chapters[$0 + 1] : nil }
        return HStack {
            if let previous {
                Button { open(previous) } label: { Text("‹ Previous") }.modifier(PaperTurn())
            }
            Spacer()
            if let next {
                Button { open(next) } label: { Text("\(ExplainerLibrary.document(for: next.file)?.title ?? next.file) ›") }.modifier(PaperTurn())
            }
        }
        .padding(.top, 20)
    }
}


/// One page of a chapter. Previous and Next swap the page in place; before the first page lies the
/// page list, after the last the next chapter.
struct PageReaderView: View {
    let pages: [ExplainerLibrary.Page]
    let next: ExplainerLibrary.Chapter?
    let close: () -> Void
    let open: (ExplainerLibrary.Chapter) -> Void
    @State private var number: Int

    init(pages: [ExplainerLibrary.Page], start: Int, next: ExplainerLibrary.Chapter?, close: @escaping () -> Void,
         open: @escaping (ExplainerLibrary.Chapter) -> Void) {
        self.pages = pages
        self.next = next
        self.close = close
        self.open = open
        _number = State(initialValue: start)
    }

    var body: some View {
        ScrollView {
            if pages.indices.contains(number) {
                let page = pages[number]
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        MarkdownText(page.title).font(.system(.largeTitle, design: .serif).weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        if page.parts > 1 {
                            Text("Part \(page.part) of \(page.parts)").font(.footnote).opacity(0.7)
                        }
                    }
                    ForEach(Array(page.blocks.enumerated()), id: \.offset) { _, block in
                        BlockView(file: page.file, block: block)
                    }
                    turns
                }
                .padding(.horizontal, 22).padding(.vertical, 16).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
        }
        // A fresh scroll view for each page, so a turned page opens at its top: scrolling the old one to the top in
        // the same update as the turn reached the outgoing page, and the new one kept its offset.
        .id(number)
        .modifier(PaperPage())
        .toolbar { Text(ExplainerLibrary.document(for: pages.first?.file ?? "")?.title ?? "").font(.subheadline.weight(.semibold)).foregroundStyle(.ivory.opacity(0.9)).lineLimit(1) }
    }

    private var turns: some View {
        HStack {
            Button {
                if number > 0 { number -= 1 } else { close() }
            } label: { Text("‹ Previous") }
                .modifier(PaperTurn())
                .accessibilityHint(number > 0 ? "The page before" : "Back to the list of pages")
            Spacer()
            if number + 1 < pages.count {
                Button { number += 1 } label: { Text("Next ›") }.modifier(PaperTurn())
            } else if let next {
                Button { open(next) } label: { Text("\(ExplainerLibrary.document(for: next.file)?.title ?? next.file) ›") }.modifier(PaperTurn())
            }
        }
        .padding(.top, 20)
    }

}

/// A chapter or page as flat ivory paper (D147): ink text, green for what can be tapped, the wood's bar over it.
private struct PaperPage: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Theme.Paper.ink)
            .background(Color.ivory.ignoresSafeArea())
            .tint(Theme.Paper.green)
            .navigationTitle("")
            #if os(iOS)
            // The bar over the paper is the wood it lies on, so the clock and the way back read in ivory.
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Wood.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
    }
}

/// Previous and Next as green words at the foot of the page.
private struct PaperTurn: ViewModifier {
    func body(content: Content) -> some View {
        content.buttonStyle(.plain).font(.title3.weight(.bold)).foregroundStyle(Theme.Paper.green).lineLimit(1)
            .frame(minHeight: 44).contentShape(Rectangle())
    }
}

/// A hairline across the paper.
private struct PaperRule: View {
    var body: some View { Rectangle().fill(Theme.Paper.ink.opacity(0.14)).frame(height: 1) }
}

/// One Markdown block drawn natively; diagrams load from the chapter's rendered PNGs.
struct BlockView: View {
    let file: String
    let block: MarkdownDocument.Block

    var body: some View {
        switch block {
        case let .heading(level, text):
            if level == 1 {
                EmptyView()   // the navigation title carries it
            } else {
                MarkdownText(text)
                    .font(level == 2 ? .system(.title2, design: .serif).weight(.semibold) : .headline)
                    .padding(.top, level == 2 ? 14 : 6)
                    .accessibilityAddTraits(.isHeader)
            }
        case let .paragraph(text):
            MarkdownText(text).font(.body).lineSpacing(3).opacity(0.92)
        case let .bullets(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(Color.suitRed)
                        MarkdownText(item).font(.body).opacity(0.92)
                    }
                }
            }
        case let .numbered(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).").font(.body.monospacedDigit()).foregroundStyle(Color.suitRed).frame(width: 24, alignment: .trailing)
                        MarkdownText(item).font(.body).opacity(0.92)
                    }
                }
            }
        case let .table(header, rows):
            // Tables become stacked rows on the phone: each row a small card of label and value pairs.
            VStack(spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                            if !cell.isEmpty {
                                if column == 0 {
                                    MarkdownText(cell).font(.subheadline.weight(.semibold))
                                } else {
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        if column < header.count, header.count > 2 {
                                            Text(header[column].uppercased()).font(.system(.caption2, design: .monospaced)).opacity(0.5)
                                        }
                                        MarkdownText(cell).font(.footnote).opacity(0.85)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.Paper.tan.opacity(0.55), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
        case let .code(language, text):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                    .padding(12)
            }
            .background(Theme.Paper.wash.opacity(0.8), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if !language.isEmpty { Text(language).font(.system(.caption2, design: .monospaced)).opacity(0.4).padding(6) }
            }
            .accessibilityLabel("\(language.isEmpty ? "Code" : language) block")
            .accessibilityValue(text)
        case let .diagram(index):
            DiagramView(file: file, index: index)
        }
    }
}

/// A rendered Mermaid diagram: fitted to the width, and a tap enlarges it to scroll sideways.
struct DiagramView: View {
    let file: String
    let index: Int
    @State private var enlarged = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let url = ExplainerLibrary.diagramURL(for: file, index: index), let image = platformImage(at: url) {
            Group {
                if enlarged {
                    ScrollView(.horizontal, showsIndicators: true) {
                        image.resizable().scaledToFit().frame(height: 480).padding(10)
                    }
                } else {
                    image.resizable().scaledToFit().padding(10)
                }
            }
            .background(.ivory.opacity(contrast == .increased ? 1 : 0.94), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: enlarged ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.caption).foregroundStyle(.black.opacity(0.55)).padding(8)
            }
            .onTapGesture { withAnimation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay) { enlarged.toggle() } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Diagram \(index)")
            .accessibilityHint(enlarged ? "Double tap to fit the width" : "Double tap to enlarge")
            .accessibilityAddTraits(.isButton)
        } else {
            Text("Diagram \(index) is not in this build.").font(.footnote).opacity(0.6)
        }
    }

    private func platformImage(at url: URL) -> Image? {
        #if canImport(UIKit)
        return UIImage(contentsOfFile: url.path).map(Image.init(uiImage:))
        #else
        return NSImage(contentsOf: url).map(Image.init(nsImage:))
        #endif
    }
}

/// Inline Markdown (bold, italic, code, links) through `AttributedString`; falls back to the raw text.
struct MarkdownText: View {
    let source: String
    init(_ source: String) { self.source = source }
    var body: some View {
        Text(Self.styled(source)).tint(Color.suitRed)
    }

    /// Inline Markdown as an attributed string; code spans get their font here, explicitly, so only
    /// they turn monospaced. Unparseable text is shown as it is.
    static func styled(_ source: String) -> AttributedString {
        guard var attributed = try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) else {
            return AttributedString(source)
        }
        for run in attributed.runs where run.inlinePresentationIntent?.contains(.code) == true {
            attributed[run.range].font = .system(.body, design: .monospaced).weight(.medium)
            attributed[run.range].foregroundColor = Color.suitRed
        }
        return attributed
    }
}

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
