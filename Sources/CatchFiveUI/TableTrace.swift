import Foundation

/// A temporary step log for the freeze hunt (D142): each thing the table decides, one line, written to
/// `trace.log` beside the saved game. Debug builds only; a release build compiles every call to nothing. It comes
/// out again once the freeze is found.
enum TableTrace {
    #if DEBUG && os(iOS)
    private static let queue = DispatchQueue(label: "catchfive.trace")
    private static let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("CatchFive", isDirectory: true).appendingPathComponent("trace.log")
    private static let started = Date()
    /// The log starts again when it passes this size, so it never grows without end.
    private static let cap = 2_000_000
    #endif

    /// One line: seconds since launch, then the words. The words are built only in a debug build.
    static func log(_ words: @autoclosure () -> String) {
        #if DEBUG && os(iOS)
        let line = String(format: "%9.3f ", Date().timeIntervalSince(started)) + words() + "\n"
        queue.async {
            let manager = FileManager.default
            try? manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let size = (try? manager.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            if size > cap { try? manager.removeItem(at: url) }
            if !manager.fileExists(atPath: url.path) {
                manager.createFile(atPath: url.path, contents: Data("log started \(Date())\n".utf8))
            }
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        }
        #endif
    }
}
