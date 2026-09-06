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
        let words = document.blocks.reduce(0) { count, block in
            switch block {
            case let .paragraph(text): count + text.split(separator: " ").count
            case let .bullets(items), let .numbered(items): count + items.reduce(0) { $0 + $1.split(separator: " ").count }
            case let .table(_, rows): count + rows.reduce(0) { $0 + $1.joined(separator: " ").split(separator: " ").count }
            case let .code(_, text): count + text.split(separator: " ").count / 2
            default: count
            }
        }
        return max(1, Int((Double(words) / 200).rounded()))
    }
}

/// The contents page: the chapters in reading order, then the Swift vocabulary.
struct ExplainerView: View {
    let onDismiss: () -> Void
    @State private var contents: MarkdownDocument?
    @State private var open: ExplainerLibrary.Chapter?

    /// `initial` opens straight into a chapter by file name; nil shows the contents page.
    init(initial: String? = nil, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        let contents = ExplainerLibrary.document(for: ExplainerLibrary.contentsChapter.file)
        _contents = State(initialValue: contents)
        _open = State(initialValue: contents.flatMap { ExplainerLibrary.chapters(from: $0).first { $0.file == initial } })
    }

    var body: some View {
        NavigationStack {
            Group {
                if let contents {
                    contentsPage(contents)
                } else {
                    Text("The explainer pages are not in this build.").foregroundStyle(.secondary).padding()
                }
            }
            .foregroundStyle(.ivory)
            .background(LinearGradient(colors: [.felt, .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
            .navigationTitle("How Catch 5 is built")
            .toolbar { Button("Done", action: onDismiss) }
            .navigationDestination(item: $open) { chapter in
                DocumentReaderView(chapter: chapter, chapters: chapters) { open = $0 }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var chapters: [ExplainerLibrary.Chapter] { contents.map(ExplainerLibrary.chapters) ?? [] }

    private func contentsPage(_ contents: MarkdownDocument) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if case let .paragraph(lede)? = contents.blocks.dropFirst().first {
                    MarkdownText(lede).font(.body).opacity(0.85)
                }
                VStack(spacing: 10) {
                    ForEach(chapters) { chapter in
                        Button { open = chapter } label: { chapterCard(chapter) }.buttonStyle(.plain)
                    }
                }
                glossarySection(ExplainerLibrary.glossary(from: contents))
            }
            .padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
    }

    private func chapterCard(_ chapter: ExplainerLibrary.Chapter) -> some View {
        let document = ExplainerLibrary.document(for: chapter.file)
        return HStack(alignment: .top, spacing: 14) {
            Text(String(chapter.number)).font(.system(.title2, design: .serif).weight(.bold)).foregroundStyle(.gold)
                .frame(width: 28, alignment: .trailing)
            VStack(alignment: .leading, spacing: 4) {
                Text(document?.title ?? chapter.file).font(.headline)
                Text(chapter.summary).font(.footnote).opacity(0.8).fixedSize(horizontal: false, vertical: true)
                if let document {
                    Text("\(ExplainerLibrary.readingMinutes(document)) min · \(document.sections.count) sections\(document.diagramCount > 0 ? " · \(document.diagramCount) diagram\(document.diagramCount == 1 ? "" : "s")" : "")")
                        .font(.caption2.monospaced()).opacity(0.55)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote).opacity(0.4)
        }
        .padding(14)
        .background(Theme.Wood.inlay.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.ivory.opacity(0.12)))
        .accessibilityElement(children: .combine)
    }

    private func glossarySection(_ entries: [ExplainerLibrary.GlossaryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SWIFT VOCABULARY").font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1).opacity(0.6)
            ForEach(entries, id: \.term) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    MarkdownText(entry.term).font(.subheadline.weight(.semibold))
                    MarkdownText(entry.meaning).font(.footnote).opacity(0.85)
                    MarkdownText(entry.where_).font(.caption2).opacity(0.55)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 8)
    }
}

/// One chapter, rendered block by block, with a section list at the top and neighbours at the bottom.
struct DocumentReaderView: View {
    let chapter: ExplainerLibrary.Chapter
    let chapters: [ExplainerLibrary.Chapter]
    /// A link to another doc, or the Previous and Next buttons, opens that chapter in place.
    let openChapter: (ExplainerLibrary.Chapter) -> Void
    @State private var document: MarkdownDocument?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let document {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionList(document, proxy: proxy)
                        ForEach(Array(document.blocks.enumerated()), id: \.offset) { index, block in
                            blockView(block).id(index)
                        }
                        neighbours
                    }
                    .padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
                } else {
                    Text("This chapter is not in this build.").foregroundStyle(.secondary).padding()
                }
            }
        }
        .foregroundStyle(.ivory)
        .background(LinearGradient(colors: [.felt, .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .navigationTitle(document?.title ?? "")
        .environment(\.openURL, OpenURLAction { url in
            // A relative link to a sibling doc opens that chapter; anything else goes to the system.
            let target = url.lastPathComponent.replacingOccurrences(of: ".md", with: "")
            if url.scheme == nil || url.isFileURL, let chapter = chapters.first(where: { $0.file == target }) {
                openChapter(chapter)
                return .handled
            }
            return .systemAction
        })
        .task(id: chapter.file) { document = ExplainerLibrary.document(for: chapter.file) }
    }

    @ViewBuilder private func sectionList(_ document: MarkdownDocument, proxy: ScrollViewProxy) -> some View {
        let sections = document.sections.filter { $0.level == 2 }
        if sections.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                Text("IN THIS CHAPTER").font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1).opacity(0.6)
                ForEach(sections, id: \.text) { section in
                    Button {
                        if let index = document.blocks.firstIndex(of: .heading(level: 2, text: section.text)) {
                            withAnimation { proxy.scrollTo(index, anchor: .top) }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Rectangle().fill(.gold.opacity(0.6)).frame(width: 2, height: 14)
                            MarkdownText(section.text).font(.footnote).multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Theme.Wood.inlay.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder private func blockView(_ block: MarkdownDocument.Block) -> some View {
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
                        Text("•").foregroundStyle(.gold)
                        MarkdownText(item).font(.body).opacity(0.92)
                    }
                }
            }
        case let .numbered(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).").font(.body.monospacedDigit()).foregroundStyle(.gold).frame(width: 24, alignment: .trailing)
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
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
        case let .code(language, text):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                    .padding(12)
            }
            .background(Theme.Wood.inlay.opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if !language.isEmpty { Text(language).font(.system(.caption2, design: .monospaced)).opacity(0.4).padding(6) }
            }
            .accessibilityLabel("\(language.isEmpty ? "Code" : language) block")
            .accessibilityValue(text)
        case let .diagram(index):
            DiagramView(file: chapter.file, index: index)
        }
    }

    private var neighbours: some View {
        let position = chapters.firstIndex(of: chapter)
        let previous = position.flatMap { $0 > 0 ? chapters[$0 - 1] : nil }
        let next = position.flatMap { $0 + 1 < chapters.count ? chapters[$0 + 1] : nil }
        return HStack {
            if let previous {
                Button { openChapter(previous) } label: { Label("Previous", systemImage: "chevron.left") }
                    .buttonStyle(.bordered).tint(.ivory.opacity(0.8))
            }
            Spacer()
            if let next {
                Button { openChapter(next) } label: { Label("Next: \(ExplainerLibrary.document(for: next.file)?.title ?? next.file)", systemImage: "chevron.right") }
                    .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black).lineLimit(1)
            }
        }
        .padding(.top, 20)
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
        Text(Self.styled(source)).tint(.gold)
    }

    /// Inline Markdown as an attributed string; code spans get their font here, explicitly, so only
    /// they turn monospaced. Unparseable text is shown as it is.
    static func styled(_ source: String) -> AttributedString {
        guard var attributed = try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) else {
            return AttributedString(source)
        }
        for run in attributed.runs where run.inlinePresentationIntent?.contains(.code) == true {
            attributed[run.range].font = .system(.body, design: .monospaced).weight(.medium)
            attributed[run.range].foregroundColor = .gold
        }
        return attributed
    }
}

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
