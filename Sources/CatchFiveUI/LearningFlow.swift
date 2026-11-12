import CatchFive
import SwiftUI

/// Each entry opens the requested destination directly; the real table remains its owner throughout.
enum LearningStart {
    case archive, practice
    case replay(HandReplay, names: [String], mode: PlayMode)
}

enum LearningRoute: Hashable {
    case replay, setup, practice, rule(String)
}

struct LearningPresentation: Identifiable {
    let id = UUID()
    let start: LearningStart
}

@MainActor final class LearningFlowModel: ObservableObject {
    let real: GameModel
    let start: LearningStart
    @Published var path: [LearningRoute] = []
    @Published var query = ""
    @Published private(set) var selectedReplay: HandReplay?
    @Published private(set) var practiceModel: GameModel?
    @Published private(set) var error: String?
    @Published private(set) var statistics = HandArchiveStatistics()
    @Published private(set) var isLoading = true
    @Published private var allHands = HandArchiveListing()
    @Published private var limit = 50
    private(set) var names: [String]
    private(set) var mode: PlayMode
    private var archivedSelection: ArchivedHand?
    private var seed: HandReplay?
    private var configuration = PracticeConfiguration()
    private var context: GameModel.ArchiveReadContext
    private var loadGeneration = 0
    private var loadTask: Task<HandArchiveListing?, Never>?

    init(real: GameModel, start: LearningStart) {
        self.real = real
        self.start = start
        names = real.seatNames
        mode = real.mode
        context = real.archiveReadContext
        if case let .replay(replay, names, mode) = start {
            selectedReplay = replay
            self.names = names
            self.mode = mode
        }
    }

    var listing: HandArchiveListing {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let entries = text.isEmpty ? allHands.entries : allHands.entries.filter { hand in
            let words = [hand.names.joined(separator: " "), hand.trump.rawValue, "Hand \(hand.handNumber)",
                         hand.isNineAndOut ? "9 and out nine and out" : "Bid \(hand.bid)",
                         hand.recovered ? "recovered" : "saved", hand.mode == .solo ? "solo" : "pass and play"]
            return words.joined(separator: " ").localizedStandardContains(text)
        }
        return HandArchiveListing(entries: text.isEmpty ? Array(entries.prefix(limit)) : entries,
                                  unreadableFiles: allHands.unreadableFiles,
                                  hasMore: text.isEmpty && entries.count > limit)
    }

    var practiceNames: [String] { selectedReplay == nil ? real.seatNames : names }
    var practiceConfiguration: PracticeConfiguration { configuration }
    var replayDescription: String? { seed.map { "Original deal · Hand \($0.number)" } }

    /// Disk validation runs off actor; cached filtering and pagination remain immediate.
    func load(reader: @escaping @Sendable (HandArchiveReadRequest) throws -> HandArchiveListing = { try $0.read() }) async {
        guard !Task.isCancelled else { return }
        refreshContext()
        loadGeneration += 1
        let generation = loadGeneration
        loadTask?.cancel()
        let expected = context
        isLoading = true
        let pending = Task { await real.savedHandsAsync(limit: .max, reader: reader) }
        loadTask = pending
        let result = await withTaskCancellationHandler {
            await pending.value
        } onCancel: {
            pending.cancel()
            Task { @MainActor [weak self] in self?.cancelLoad(generation: generation) }
        }
        guard generation == loadGeneration else { return }
        loadTask = nil
        isLoading = false
        guard !Task.isCancelled, expected == real.archiveReadContext else { refreshContext(); return }
        guard let result else { return }
        allHands = result
        statistics = HandArchiveStatistics(result.entries)
        error = real.archiveError
    }

    func cancelLoad() { cancelLoad(generation: loadGeneration) }

    private func cancelLoad(generation: Int) {
        guard generation == loadGeneration else { return }
        loadGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }

    func loadMore() { limit += 50 }
    func retry() async {
        guard !Task.isCancelled else { return }
        real.retryArchive()
        await load()
    }

    @discardableResult func select(_ entry: ArchivedHand) -> Bool {
        refreshContext()
        guard let current = allHands.entries.first(where: { $0.id == entry.id }), !isActiveDeal(current.dealID),
              let replay = try? current.replay() else {
            error = "This hand is unavailable. A deal still in play cannot be revealed."
            return false
        }
        archivedSelection = current
        selectedReplay = replay
        names = current.names
        mode = current.mode
        path.append(.replay)
        return true
    }

    func beginPractice() {
        seed = selectedReplay
        path.append(.setup)
    }

    func startPractice(_ configuration: PracticeConfiguration) {
        do {
            let model = try practice(configuration: configuration, replay: seed)
            self.configuration = configuration
            practiceModel = model
            error = nil
            path.append(.practice)
        } catch { self.error = "This practice deal could not be opened. Your game is still safe." }
    }

    func newPracticeDeal() {
        seed = nil
        do {
            practiceModel = try practice(configuration: configuration)
            error = nil
        } catch { self.error = "A new practice deal could not be opened. Try again." }
    }

    private func practice(configuration: PracticeConfiguration, replay: HandReplay? = nil) throws -> GameModel {
        let model = try real.makePractice(configuration: configuration, replay: replay)
        if let archivedSelection {
            model.settings.seatNames = archivedSelection.names
            model.settings.opponents = archivedSelection.opponents
        }
        return model
    }

    /// True asks the container to close; a replay-origin practice returns to that replay instead.
    @discardableResult func leavePractice() -> Bool {
        practiceModel = nil
        seed = nil
        if selectedReplay != nil {
            if let replay = path.firstIndex(of: .replay) { path = Array(path.prefix(through: replay)) }
            else { path = [] }
            return false
        }
        path = []
        return true
    }

    func showRule(_ rule: ReplayRule) { path.append(.rule(HouseRuleGuide.entry(for: rule).id)) }
    func back() { if !path.isEmpty { path.removeLast() } }

    @discardableResult func closeReplay() -> Bool {
        guard case .archive = start else { return true }
        path = []
        selectedReplay = nil
        archivedSelection = nil
        return false
    }

    /// Scope/deal changes clear old cards and counts before awaiting another disk read.
    func validateSelection(reader: @escaping @Sendable (HandArchiveReadRequest) throws -> HandArchiveListing = { try $0.read() }) async {
        guard !Task.isCancelled else { return }
        refreshContext()
        await load(reader: reader)
        if let selected = archivedSelection, !allHands.entries.contains(where: { $0.id == selected.id }) {
            clearSelection()
        }
    }

    private func refreshContext() {
        let current = real.archiveReadContext
        guard current != context else { return }
        cancelLoad()
        context = current
        allHands = HandArchiveListing()
        statistics = HandArchiveStatistics()
        limit = 50
        error = nil
        clearSelection()
    }

    private func clearSelection() {
        selectedReplay = nil
        archivedSelection = nil
        seed = nil
        practiceModel = nil
        path = []
    }

    private func isActiveDeal(_ id: String) -> Bool {
        real.match.hand.phase != .finished && (try? HandArchiveStore.dealIdentity(for: real.match)) == id
    }

    @discardableResult static func resetPlayer(_ model: GameModel, onSuccess: () -> Void) -> Bool {
        guard model.resetPlayer() else { return false }
        onSuccess()
        return true
    }
}

/// The two Statistics openings share the same loading/cancellation contract as Saved hands.
@MainActor final class SavedHandStatisticsModel: ObservableObject {
    @Published private(set) var statistics = HandArchiveStatistics()
    @Published private(set) var error: String?
    @Published private(set) var isLoading = true
    private var generation = 0
    private var loadTask: Task<HandArchiveListing?, Never>?

    func prepareLoading() {
        cancelLoad()
        statistics = HandArchiveStatistics()
        error = nil
        isLoading = true
    }

    func load(_ real: GameModel,
              reader: @escaping @Sendable (HandArchiveReadRequest) throws -> HandArchiveListing = { try $0.read() }) async {
        guard !Task.isCancelled else { return }
        generation += 1
        let current = generation
        loadTask?.cancel()
        let context = real.archiveReadContext
        statistics = HandArchiveStatistics()
        error = nil
        isLoading = true
        let pending = Task { await real.savedHandsAsync(limit: .max, reader: reader) }
        loadTask = pending
        let result = await withTaskCancellationHandler {
            await pending.value
        } onCancel: {
            pending.cancel()
            Task { @MainActor [weak self] in self?.cancelLoad(generation: current) }
        }
        guard current == generation else { return }
        loadTask = nil
        isLoading = false
        guard !Task.isCancelled, context == real.archiveReadContext, let result else { return }
        statistics = HandArchiveStatistics(result.entries)
        error = real.archiveError
    }

    func cancelLoad() { cancelLoad(generation: generation) }
    private func cancelLoad(generation current: Int) {
        guard current == generation else { return }
        generation += 1
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
}

struct LearningFlowView: View {
    @StateObject private var flow: LearningFlowModel
    @ObservedObject private var real: GameModel
    let onClose: () -> Void

    init(model: GameModel, start: LearningStart, onClose: @escaping () -> Void) {
        _flow = StateObject(wrappedValue: LearningFlowModel(real: model, start: start))
        _real = ObservedObject(wrappedValue: model)
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack(path: $flow.path) {
            initial
                .navigationDestination(for: LearningRoute.self) { route in
                    switch route {
                    case .replay: replay
                    case .setup: setup
                    case .practice:
                        if let model = flow.practiceModel {
                            PracticeTableView(model: model, onNewDeal: flow.newPracticeDeal,
                                              onClose: { if flow.leavePractice() { onClose() } })
                                .id(ObjectIdentifier(model))
                        }
                    case let .rule(id):
                        if let entry = HouseRuleGuide.entry(id: id) { HouseRuleEntryView(entry: entry, onClose: flow.back) }
                    }
                }
        }
        .task(id: real.archiveReadContext) { await flow.validateSelection() }
        .onDisappear { flow.cancelLoad() }
    }

    @ViewBuilder private var initial: some View {
        switch flow.start {
        case .archive:
            HandArchiveView(listing: flow.listing, error: flow.error, query: $flow.query, isLoading: flow.isLoading,
                            onSelect: { flow.select($0) }, onLoadMore: flow.loadMore,
                            onRetry: { Task { await flow.retry() } }, onClose: { flow.cancelLoad(); onClose() })
        case .practice: setup
        case .replay: replay
        }
    }

    @ViewBuilder private var replay: some View {
        if let replay = flow.selectedReplay {
            HandReplayView(replay: replay, names: flow.names, mode: flow.mode,
                           onClose: { if flow.closeReplay() { onClose() } },
                           onPractice: { _ in flow.beginPractice() }, onRule: flow.showRule)
        } else {
            VStack(spacing: 20) {
                Text(flow.error ?? "This completed hand is no longer available.")
                Button("Done", action: onClose).frame(minHeight: 44)
            }.padding()
        }
    }

    private var setup: some View {
        PracticeSetupView(names: flow.practiceNames, configuration: flow.practiceConfiguration,
                          replayDescription: flow.replayDescription, onStart: flow.startPractice,
                          onClose: { if flow.path.isEmpty { onClose() } else { flow.back() } })
            .overlay(alignment: .bottom) {
                if let error = flow.error { Text(error).font(.footnote).padding().background(.regularMaterial) }
            }
    }
}

/// The advice and its rule stay in one sheet, so the table stays paused while either is being read.
struct LearningAdviceView: View {
    let presentation: LiveAdvicePresentation
    let onClose: () -> Void
    @State private var path: [LearningRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            LiveAdviceView(presentation: presentation,
                           onRule: { path.append(.rule(HouseRuleGuide.entry(for: $0).id)) }, onClose: onClose)
                .navigationDestination(for: LearningRoute.self) { route in
                    if case let .rule(id) = route, let entry = HouseRuleGuide.entry(id: id) {
                        HouseRuleEntryView(entry: entry, onClose: { path.removeLast() })
                    }
                }
        }
    }
}
