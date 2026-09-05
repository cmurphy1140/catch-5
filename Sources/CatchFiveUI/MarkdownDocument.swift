import Foundation

/// The subset of Markdown the docs use, parsed into blocks the reader can draw natively: headings,
/// paragraphs, bullet and numbered lists, pipe tables, fenced code, and Mermaid fences, which become
/// numbered diagrams rendered to images at export time. Inline styling stays as Markdown for
/// `AttributedString(markdown:)` to render.
struct MarkdownDocument: Equatable {
    enum Block: Equatable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullets([String])
        case numbered([String])
        case table(header: [String], rows: [[String]])
        case code(language: String, text: String)
        /// The n-th Mermaid fence in the document, 1-based; the reader shows `diagrams/<file>-<n>.png`.
        case diagram(index: Int)
    }

    struct Section: Equatable {
        let level: Int
        let text: String
    }

    let title: String
    let blocks: [Block]

    var diagramCount: Int { blocks.filter { if case .diagram = $0 { return true } else { return false } }.count }

    /// Every heading below the title, for a jump list.
    var sections: [Section] {
        blocks.compactMap { block in
            if case let .heading(level, text) = block, level > 1 { return Section(level: level, text: text) }
            return nil
        }
    }

    static func parse(_ markdown: String) -> MarkdownDocument {
        var blocks: [Block] = []
        var title = ""
        var diagrams = 0
        var paragraph: [String] = []
        var bullets: [String] = []
        var numbered: [String] = []
        var tableLines: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
        }
        func flushLists() {
            if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
            if !numbered.isEmpty { blocks.append(.numbered(numbered)); numbered = [] }
        }
        func flushTable() {
            guard !tableLines.isEmpty else { return }
            let rows = tableLines.map(cells).filter { !$0.isEmpty }
            tableLines = []
            guard let header = rows.first else { return }
            // The second row is the |---| separator; anything after it is data.
            let body = rows.dropFirst().filter { row in !row.allSatisfy { $0.allSatisfy { "-: ".contains($0) } } }
            blocks.append(.table(header: header, rows: Array(body)))
        }
        func flushAll() { flushParagraph(); flushLists(); flushTable() }

        let lines = markdown.components(separatedBy: "\n")
        var index = 0
        while index < lines.count {
            let raw = lines[index]
            let line = raw.trimmingCharacters(in: .whitespaces)
            index += 1

            if line.hasPrefix("```") {
                flushAll()
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    body.append(lines[index])
                    index += 1
                }
                index += 1   // the closing fence
                if language == "mermaid" {
                    diagrams += 1
                    blocks.append(.diagram(index: diagrams))
                } else {
                    blocks.append(.code(language: language, text: dedented(body)))
                }
                continue
            }
            if line.isEmpty { flushAll(); continue }
            if line.hasPrefix("#") {
                flushAll()
                let level = line.prefix { $0 == "#" }.count
                let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
                if level == 1, title.isEmpty { title = text }
                blocks.append(.heading(level: level, text: text))
                continue
            }
            if line.hasPrefix("|") {
                flushParagraph(); flushLists()
                tableLines.append(line)
                continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph(); flushTable()
                if !numbered.isEmpty { blocks.append(.numbered(numbered)); numbered = [] }
                bullets.append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                continue
            }
            if let dot = line.firstIndex(of: "."), line[..<dot].allSatisfy(\.isNumber), !line[..<dot].isEmpty,
               line[line.index(after: dot)...].hasPrefix(" ") {
                flushParagraph(); flushTable()
                if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
                numbered.append(line[line.index(after: dot)...].trimmingCharacters(in: .whitespaces))
                continue
            }
            // A continuation line of the current list item, or ordinary prose.
            if !bullets.isEmpty, raw.hasPrefix("  ") { bullets[bullets.count - 1] += " " + line; continue }
            if !numbered.isEmpty, raw.hasPrefix("  ") { numbered[numbered.count - 1] += " " + line; continue }
            flushLists(); flushTable()
            paragraph.append(line)
        }
        flushAll()
        return MarkdownDocument(title: title, blocks: blocks)
    }

    /// Splits a pipe-table line into trimmed cells, ignoring the outer pipes.
    private static func cells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Removes the common leading indentation of a code block.
    private static func dedented(_ lines: [String]) -> String {
        let indents = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.prefix { $0 == " " }.count }
        let common = indents.min() ?? 0
        return lines.map { String($0.dropFirst(min(common, $0.prefix { $0 == " " }.count))) }
            .joined(separator: "\n").trimmingCharacters(in: .newlines)
    }
}
