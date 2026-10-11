import CatchFive
@testable import CatchFiveUI
import Foundation
import Testing

private let docsFolder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("App/Explainer/docs")

@Test func markdownParserCoversEveryConstructTheDocsUse() {
    let source = """
    # Title here

    A paragraph that
    wraps onto two lines with **bold**, `code` and a [link](architecture.md).

    ## Section

    - first bullet
    - second bullet

    1. step one
    2. step two

    | Name | Purpose |
    |---|---|
    | `Match` | owns the game |
    | `Hand` | one deal |

    ```bash
    swift test
    ```

    ```mermaid
    flowchart LR
        A --> B
    ```

    ### Deeper

    Last words.
    """
    let document = MarkdownDocument.parse(source)
    #expect(document.title == "Title here")
    #expect(document.blocks == [
        .heading(level: 1, text: "Title here"),
        .paragraph("A paragraph that wraps onto two lines with **bold**, `code` and a [link](architecture.md)."),
        .heading(level: 2, text: "Section"),
        .bullets(["first bullet", "second bullet"]),
        .numbered(["step one", "step two"]),
        .table(header: ["Name", "Purpose"], rows: [["`Match`", "owns the game"], ["`Hand`", "one deal"]]),
        .code(language: "bash", text: "swift test"),
        .diagram(index: 1),
        .heading(level: 3, text: "Deeper"),
        .paragraph("Last words."),
    ])
    #expect(document.diagramCount == 1)
    #expect(document.sections.map(\.text) == ["Section", "Deeper"])
}

@Test func everyChapterParsesAndItsDiagramsAreCounted() throws {
    let path = try String(contentsOf: docsFolder.appendingPathComponent("learning-path.md"), encoding: .utf8)
    let chapters = ExplainerLibrary.chapters(from: MarkdownDocument.parse(path))
    #expect(chapters.count == 12)   // screen-flow joined the reading order
    #expect(chapters.first?.file == "build-and-run" && chapters.last?.file == "redesign-plan")
    #expect(chapters.allSatisfy { !$0.summary.isEmpty })
    for chapter in chapters {
        let markdown = try String(contentsOf: docsFolder.appendingPathComponent("\(chapter.file).md"), encoding: .utf8)
        let document = MarkdownDocument.parse(markdown)
        #expect(!document.title.isEmpty, Comment(rawValue: chapter.file))
        #expect(document.blocks.count > 5, Comment(rawValue: chapter.file))
        #expect(document.diagramCount == markdown.components(separatedBy: "```mermaid").count - 1, Comment(rawValue: chapter.file))
    }
    // The glossary is the learning path's second table.
    let glossary = ExplainerLibrary.glossary(from: MarkdownDocument.parse(path))
    #expect(glossary.count > 10 && glossary.first?.term == "`struct`")
}

@Test func explainerBundleHasAPNGForEveryDiagram() throws {
    // The app bundles one PNG per Mermaid fence of each chapter (rendered by scripts/export-docs.py --app);
    // a fence without its picture would show the reader an empty diagram.
    let bundle = docsFolder.deletingLastPathComponent()
    let path = try String(contentsOf: docsFolder.appendingPathComponent("learning-path.md"), encoding: .utf8)
    for chapter in ExplainerLibrary.chapters(from: MarkdownDocument.parse(path)) + [ExplainerLibrary.contentsChapter] {
        let source = try String(contentsOf: docsFolder.appendingPathComponent("\(chapter.file).md"), encoding: .utf8)
        let diagrams = MarkdownDocument.parse(source).diagramCount
        for index in stride(from: 1, through: diagrams, by: 1) {
            let png = bundle.appendingPathComponent("diagrams/\(chapter.file)-\(index).png")
            #expect(FileManager.default.fileExists(atPath: png.path), Comment(rawValue: "missing \(png.lastPathComponent)"))
        }
    }
}

/// `count` words of filler, for sizing synthetic sections.
private func words(_ count: Int) -> String {
    (1...count).map { "w\($0)" }.joined(separator: " ")
}

@Test func chaptersSplitIntoSectionPagesAndLongSectionsIntoParts() {
    let rows = (1...80).map { "| row\($0) | \(words(9)) |" }.joined(separator: "\n")
    let source = """
    # Synthetic

    An opening paragraph.

    ## Short

    Just a few words here.

    ```mermaid
    flowchart LR
        A --> B
    ```

    ## Long

    Intro words.

    ### One

    \(words(200))

    ### Two

    \(words(200))

    ### Three

    \(words(50))

    ## Table

    | Key | Value |
    |---|---|
    \(rows)

    ## Picture

    Words around it.

    ```mermaid
    flowchart LR
        C --> D
    ```
    """
    let pages = ExplainerLibrary.pages(of: MarkdownDocument.parse(source), file: "synthetic")
    #expect(pages.map(\.title) == ["Overview", "Short", "Long", "Long", "Table", "Table", "Table", "Picture"])
    #expect(pages.map(\.part) == [1, 1, 1, 2, 1, 2, 3, 1])
    #expect(pages.map(\.parts) == [1, 1, 2, 2, 3, 3, 3, 1])
    #expect(pages.allSatisfy { $0.file == "synthetic" })
    #expect(Set(pages.map(\.id)).count == pages.count)
    #expect(pages[0].blocks == [.paragraph("An opening paragraph.")])
    // The `##` heading is the page's title, not one of its blocks; diagrams keep their document index.
    #expect(pages[1].blocks == [.paragraph("Just a few words here."), .diagram(index: 1)])
    #expect(pages[7].blocks == [.paragraph("Words around it."), .diagram(index: 2)])
    #expect(pages[1].hasDiagram && !pages[0].hasDiagram)
    // Long splits at its `###` headings, grouped while they fit: intro + One, then Two + Three.
    #expect(pages[2].blocks.first == .paragraph("Intro words.") && pages[2].blocks.contains(.heading(level: 3, text: "One")))
    #expect(pages[3].blocks == [.heading(level: 3, text: "Two"), .paragraph(words(200)), .heading(level: 3, text: "Three"), .paragraph(words(50))])
    // The long table splits by rows, every part repeating the header, every row present once.
    var tableRows: [[String]] = []
    for page in pages[4...6] {
        guard page.blocks.count == 1, case let .table(header, rows) = page.blocks[0] else {
            Issue.record("table page holds \(page.blocks)"); continue
        }
        #expect(header == ["Key", "Value"])
        #expect(page.words <= ExplainerLibrary.pageWords)
        tableRows += rows
    }
    #expect(tableRows.map { $0[0] } == (1...80).map { "row\($0)" })
}

/// The document's opening blocks (titled "Overview") and `##` sections, in document order.
private func sections(of document: MarkdownDocument) -> [(title: String, blocks: [MarkdownDocument.Block])] {
    var sections: [(title: String, blocks: [MarkdownDocument.Block])] = [("Overview", [])]
    var titled = false
    for block in document.blocks {
        if case let .heading(2, text) = block {
            sections.append((text, []))
        } else if case .heading(1, _) = block, sections.count == 1, !titled {
            titled = true   // the chapter's own title, shown by the reader
        } else {
            sections[sections.count - 1].blocks.append(block)
        }
    }
    if sections[0].blocks.isEmpty { sections.removeFirst() }
    return sections
}

/// One section's parts back together, rejoining a table that was split across pages.
private func joined(_ pages: [ExplainerLibrary.Page]) -> [MarkdownDocument.Block] {
    var blocks: [MarkdownDocument.Block] = []
    for page in pages {
        var rest = page.blocks[...]
        if case let .table(header, rows)? = blocks.last, case let .table(nextHeader, nextRows)? = rest.first, header == nextHeader {
            blocks[blocks.count - 1] = .table(header: header, rows: rows + nextRows)
            rest = rest.dropFirst()
        }
        blocks += rest
    }
    return blocks
}

@Test func everyRealChapterReadsInShortPagesThatCoverItOnce() throws {
    let path = try String(contentsOf: docsFolder.appendingPathComponent("learning-path.md"), encoding: .utf8)
    let chapters = ExplainerLibrary.chapters(from: MarkdownDocument.parse(path))
    #expect(!chapters.isEmpty)
    for chapter in chapters {
        let markdown = try String(contentsOf: docsFolder.appendingPathComponent("\(chapter.file).md"), encoding: .utf8)
        let document = MarkdownDocument.parse(markdown)
        let pages = ExplainerLibrary.pages(of: document, file: chapter.file)
        let label = Comment(rawValue: chapter.file)
        #expect(!pages.isEmpty, label)
        // Short pages, unless a page is one block that cannot be cut (a heading above it carries no words).
        for page in pages where page.words > ExplainerLibrary.pageWords {
            #expect(page.blocks.filter { $0.words > 0 }.count == 1, Comment(rawValue: "\(chapter.file): \(page.title) part \(page.part) has \(page.words) words"))
        }
        // Group the pages back into sections (a section starts at part 1) and compare with the document.
        var groups: [[ExplainerLibrary.Page]] = []
        for page in pages {
            if page.part == 1 { groups.append([page]) } else { groups[groups.count - 1].append(page) }
        }
        #expect(groups.allSatisfy { group in group.enumerated().allSatisfy { $1.part == $0 + 1 && $1.parts == group.count && $1.title == group[0].title } }, label)
        var expected = sections(of: document)
        if ExplainerLibrary.newestFirst.contains(chapter.file) {
            let overview = expected.first?.title == "Overview" ? [expected.removeFirst()] : []
            expected = overview + expected.reversed()
        }
        #expect(groups.map { $0[0].title } == expected.map(\.title), label)
        for (group, section) in zip(groups, expected) {
            #expect(joined(group) == section.blocks, Comment(rawValue: "\(chapter.file): \(section.title)"))
        }
    }
    // The decision log opens on its newest entry, the last `##` of the file.
    let decisions = MarkdownDocument.parse(try String(contentsOf: docsFolder.appendingPathComponent("decisions.md"), encoding: .utf8))
    let first = ExplainerLibrary.pages(of: decisions, file: "decisions").first { $0.title != "Overview" }
    #expect(first?.title == decisions.sections.last { $0.level == 2 }?.text)
}

@Test func aSplitSectionIsOneCardThatOpensOnItsFirstPart() throws {
    // D101: parts are cut by length and have no names, so the chapter's list shows one card per section.
    let path = try String(contentsOf: docsFolder.appendingPathComponent("learning-path.md"), encoding: .utf8)
    for chapter in ExplainerLibrary.chapters(from: MarkdownDocument.parse(path)) {
        let markdown = try String(contentsOf: docsFolder.appendingPathComponent("\(chapter.file).md"), encoding: .utf8)
        let pages = ExplainerLibrary.pages(of: MarkdownDocument.parse(markdown), file: chapter.file)
        let cards = ExplainerLibrary.cards(for: pages)
        let label = Comment(rawValue: chapter.file)
        #expect(cards.count == pages.filter { $0.part == 1 }.count, label)
        #expect(cards.allSatisfy { $0.first.part == 1 && $0.parts == $0.first.parts }, label)
        #expect(cards.reduce(0) { $0 + $1.words } == pages.reduce(0) { $0 + $1.words }, label)
        #expect(cards.map(\.first.title) == pages.filter { $0.part == 1 }.map(\.title), label)
    }
}
