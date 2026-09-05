import CatchFive
@testable import CatchFiveUI
import Foundation
import Testing

private let docsFolder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs")

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
    #expect(chapters.count == 11)
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

@Test func explainerBundleMatchesTheDocsAndTheirDiagrams() throws {
    // The app bundles a copy of each chapter and one PNG per Mermaid fence; both must match the docs
    // in the same commit, or the reader drifts from the pages it explains.
    let bundle = docsFolder.deletingLastPathComponent().appendingPathComponent("App/Explainer")
    let path = try String(contentsOf: docsFolder.appendingPathComponent("learning-path.md"), encoding: .utf8)
    for chapter in ExplainerLibrary.chapters(from: MarkdownDocument.parse(path)) + [ExplainerLibrary.contentsChapter] {
        let source = try String(contentsOf: docsFolder.appendingPathComponent("\(chapter.file).md"), encoding: .utf8)
        let bundled = try String(contentsOf: bundle.appendingPathComponent("docs/\(chapter.file).md"), encoding: .utf8)
        #expect(bundled == source, Comment(rawValue: "\(chapter.file).md is stale in App/Explainer; run scripts/export-docs.py --app"))
        let diagrams = MarkdownDocument.parse(source).diagramCount
        for index in stride(from: 1, through: diagrams, by: 1) {
            let png = bundle.appendingPathComponent("diagrams/\(chapter.file)-\(index).png")
            #expect(FileManager.default.fileExists(atPath: png.path), Comment(rawValue: "missing \(png.lastPathComponent)"))
        }
    }
}
