import CatchFive
@testable import CatchFiveUI
import Foundation
import SwiftUI
import Testing
#if canImport(AppKit)
import AppKit
#endif

/// Where a trace is written: `work/trace/` beside `Package.swift` (ignored by Git), found from this file's path.
enum TraceFolder {
    static let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("work/trace")

    static func prepare() throws -> URL {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

/// One tap's trail, written down as it happens: the hops a test names, every announcement a listener hears,
/// the numbers read before and after, how many times the hosted view's body ran, and the frames rendered.
/// `report()` writes `work/trace/<name>.md` with a Mermaid sequence diagram drawn from the entries.
@MainActor final class TapTrace {
    enum Entry: Equatable {
        /// A call or hand-off in the trail ("send(.play(queen of hearts))", "send returned").
        case hop(String)
        /// One @Published announcement: the field and the value the listener was handed.
        case announcement(field: String, value: String)
    }

    let name: String
    private(set) var entries: [Entry] = []
    private(set) var before: [(label: String, value: String)] = []
    private(set) var after: [(label: String, value: String)] = []
    private(set) var frames: [(label: String, file: String)] = []

    init(name: String) { self.name = name }

    func hop(_ text: String) { entries.append(.hop(text)) }
    func announced(_ field: String, _ value: Any) { entries.append(.announcement(field: field, value: "\(value)")) }
    func before(_ label: String, _ value: Any) { before.append((label, "\(value)")) }
    func after(_ label: String, _ value: Any) { after.append((label, "\(value)")) }
    func framed(_ label: String, file: String) { frames.append((label, file)) }

    var announcements: [Entry] { entries.filter { if case .announcement = $0 { true } else { false } } }

    /// The Markdown report: values, the trail, the diagram and the frames. Returns the file written.
    @discardableResult
    func report() throws -> URL {
        let folder = try TraceFolder.prepare()
        let file = folder.appendingPathComponent("\(name).md")
        try markdown.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    var markdown: String {
        var lines = ["# One tap: \(name)", "", "## Values", "", "| Number | Before | After |", "|---|---|---|"]
        for (label, value) in before {
            let later = after.first { $0.label == label }?.value ?? "–"
            lines.append("| \(label) | \(value) | \(later) |")
        }
        lines += ["", "## Trail", ""]
        for entry in entries {
            switch entry {
            case let .hop(text): lines.append("- \(text)")
            case let .announcement(field, value): lines.append("  - `\(field)` → \(value)")
            }
        }
        lines += ["", "## Diagram", "", "```mermaid", mermaid, "```", ""]
        if !frames.isEmpty {
            lines += ["## Frames", ""]
            for (label, file) in frames { lines.append("![\(label)](\(file))") }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    /// A sequence diagram: the test stands in for the tap, the announcements sit in one box, values ride on notes.
    var mermaid: String {
        var out = ["sequenceDiagram",
                   "    participant T as Test (stands in for the tap)",
                   "    participant G as GameModel",
                   "    participant P as @Published",
                   "    participant V as HandFanView body"]
        let beforeNote = before.map { "\($0.label) \($0.value)" }.joined(separator: ", ")
        if !beforeNote.isEmpty { out.append("    Note over T: before: \(clean(beforeNote))") }
        var inBox = false
        for entry in entries {
            switch entry {
            case let .hop(text):
                if inBox { out.append("    end"); inBox = false }
                out.append("    T->>G: \(clean(text))")
            case let .announcement(field, value):
                if !inBox {
                    out.append("    rect rgb(245, 240, 225)")
                    out.append("    Note over G,P: \(announcements.count) announcements during send, each before its value changes")
                    inBox = true
                }
                out.append("    G-)P: \(clean(field))")
                out.append("    Note over P: \(clean(field)) → \(clean(value))")
            }
        }
        if inBox { out.append("    end") }
        let afterNote = after.map { "\($0.label) \($0.value)" }.joined(separator: ", ")
        out.append("    P-)V: objectWillChange → body runs again")
        if !afterNote.isEmpty { out.append("    Note over V: after: \(clean(afterNote))") }
        return out.joined(separator: "\n")
    }

    /// Mermaid reads `;` and `#` specially inside a line; keep the text plain.
    private func clean(_ text: String) -> String {
        text.replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: "#", with: "no.")
    }
}

#if canImport(AppKit)
/// Hosts the real `HandFanView` in an unshown Mac window so SwiftUI evaluates its body, counts those runs,
/// and renders the hosted view to a PNG on request. Nothing in `Sources/` knows it exists.
@MainActor final class TraceStage {
    /// The wrapper SwiftUI re-evaluates; its body counts itself.
    private struct Probe: View {
        @ObservedObject var model: GameModel
        let counter: Counter
        @State private var shakes: [Card: Int] = [:]
        @State private var selected: Card?
        var body: some View {
            let _ = counter.runs += 1
            HandFanView(model: model, onIllegal: { _ in }, shakes: $shakes, selected: $selected)
                .frame(width: 390, height: 320)
        }
    }
    @MainActor final class Counter { var runs = 0 }

    private let counter = Counter()
    private let host: NSHostingView<Probe>
    private let window: NSWindow
    private let trace: TapTrace

    /// Hosts the hand for `model` and settles once, so the first body run is counted before the test acts.
    init(model: GameModel, trace: TapTrace) {
        self.trace = trace
        host = NSHostingView(rootView: Probe(model: model, counter: counter))
        host.frame = NSRect(x: 0, y: 0, width: 390, height: 320)
        window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        settle()
    }

    /// How many times the hosted body has run so far.
    var bodyRuns: Int { counter.runs }

    /// Lets the main run loop turn, which is when SwiftUI re-runs a body it was told about: in slices of a
    /// twentieth of a second until the body has run again, or `upTo` seconds have passed.
    func settle(upTo seconds: TimeInterval = 1) {
        host.layoutSubtreeIfNeeded()
        let start = counter.runs
        let deadline = Date().addingTimeInterval(seconds)
        repeat {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        } while counter.runs == start && Date() < deadline
    }

    /// Renders the hosted view as it stands to `work/trace/<trace name>-<label>.png` and records it on the trace.
    @discardableResult
    func frame(_ label: String) throws -> URL {
        host.displayIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw TraceError.noBitmap }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw TraceError.noPNG }
        let name = "\(trace.name)-\(label).png"
        let file = try TraceFolder.prepare().appendingPathComponent(name)
        try png.write(to: file)
        trace.framed(label, file: name)
        return file
    }

    enum TraceError: Error { case noBitmap, noPNG }
}
#endif

// MARK: - Self-tests

@MainActor @Test func traceReportHoldsTheBoxAndTheNotes() throws {
    let trace = TapTrace(name: "self-test")
    trace.before("hand", 6)
    trace.hop("send(.play(five of hearts))")
    trace.announced("objectWillChange", "revision still 1")
    trace.announced("$revision", 2)
    trace.hop("send returned; #2")
    trace.after("hand", 5)
    let md = trace.markdown
    #expect(md.contains("| hand | 6 | 5 |"))
    #expect(md.contains("rect rgb("))
    #expect(md.contains("Note over G,P: 2 announcements during send, each before its value changes"))
    #expect(md.contains("Note over P: $revision → 2"))
    #expect(md.contains("end\n    T->>G: send returned, no.2"))
    #expect(trace.announcements.count == 2)
    // No announcements, no box: a refused card leaves the diagram honest.
    let quiet = TapTrace(name: "quiet")
    quiet.hop("send(.play(x))")
    #expect(!quiet.mermaid.contains("rect"))
}

#if canImport(AppKit)
@MainActor @Test func traceStageHostsTheHandAndRendersAFrame() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    model.send(.bid(9))
    for _ in 0..<3 { model.stepComputer() }
    model.send(.chooseTrump(.hearts))
    let trace = TapTrace(name: "self-test")
    let stage = TraceStage(model: model, trace: trace)
    #expect(stage.bodyRuns == 1)
    let file = try stage.frame("hand")
    let size = try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int ?? 0
    #expect(size > 10_000)
    #expect(trace.frames.map(\.label) == ["hand"])
    #expect(file.lastPathComponent == "self-test-hand.png")
    // Nothing changed: settle waits out its deadline and the count stays put.
    let started = Date()
    stage.settle(upTo: 0.2)
    #expect(Date().timeIntervalSince(started) < 1)
    #expect(stage.bodyRuns == 1)
}
#endif
