import CatchFive
import SwiftUI

/// The replay's actual cursor: no rebuilding, wraparound or movement beyond the recorded hand.
struct ReplayPlayback {
    let replay: HandReplay
    private(set) var index = 0
    var current: ReplayStep { replay.steps[index] }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index + 1 < replay.steps.count }

    mutating func next() { if canGoForward { index += 1 } }
    mutating func previous() { if canGoBack { index -= 1 } }
    mutating func select(id: Int) {
        if let position = replay.steps.firstIndex(where: { $0.id == id }) { index = position }
    }
}

/// Seat numbers keep two people with the same display name distinct throughout the history.
struct LearningSeatLabels {
    let names: [String]
    let mode: PlayMode

    func name(_ seat: Int) -> String {
        let name = names.indices.contains(seat) ? names[seat] : "Player"
        return "\(name) · seat \(seat + 1)"
    }

    func team(_ team: Int) -> String {
        if mode == .solo { return team == 0 ? "Us" : "Them" }
        return "Team \(team + 1) · seats \(team + 1) & \(team + 3)"
    }

    func teamSubject(_ team: Int) -> String {
        if mode == .solo { return team == 0 ? "Our team" : "The other team" }
        return self.team(team)
    }
}

enum ReplayWording {
    static func bid(_ bid: Bid?) -> String {
        switch bid {
        case nil: "passes"
        case let .points(amount)?: "bids \(amount)"
        case .nineAndOut?: "bids 9 and out"
        }
    }

    static func title(_ event: ReplayEvent, labels: LearningSeatLabels) -> String {
        switch event {
        case let .deal(dealer): "\(labels.name(dealer)) deals"
        case let .bid(seat, amount): "\(labels.name(seat)) \(bid(amount))"
        case let .trump(seat, suit): "\(labels.name(seat)) names \(suit.rawValue)"
        case let .discard(seat, _, _): "\(labels.name(seat)) discards and draws"
        case let .play(play): "\(labels.name(play.seat)) plays the \(play.card.name)"
        case let .trick(number, _, winner): "Trick \(number) goes to \(labels.name(winner))"
        case let .score(_, _, _, winner, nineAndOut):
            if nineAndOut, let winner { "9 and out · \(labels.teamSubject(winner)) wins the match" }
            else if let winner { "Scores settled · \(labels.teamSubject(winner)) wins the match" }
            else { "Scores settled" }
        }
    }

    static func contract(_ replay: HandReplay) -> String {
        "\(replay.isNineAndOut ? "9 and out" : "Bid \(replay.bid)") · \(replay.trump.rawValue.capitalized) trump"
    }

    static func scoreLine(team: Int, before: [Int], after: [Int], labels: LearningSeatLabels) -> String {
        "\(labels.team(team)): \(before[team]) → \(after[team])"
    }

    static func settlement(_ replay: HandReplay, result: HandScore, labels: LearningSeatLabels) -> String {
        if replay.isNineAndOut, let winner = replay.winner {
            return "\(labels.teamSubject(winner)) wins the match. On 9 and out the numeric scores stay as they were."
        }
        return result.points[replay.bidder % 2] >= replay.bid
            ? "The bidding team made its contract."
            : "The bidding team went set and loses its bid."
    }
}

struct HandReplayView: View {
    let replay: HandReplay
    let names: [String]
    let mode: PlayMode
    let onClose: () -> Void
    let onPractice: (HandReplay) -> Void
    let onRule: (ReplayRule) -> Void
    @State private var playback: ReplayPlayback
    @State private var showsHands: Bool

    init(replay: HandReplay, names: [String], mode: PlayMode,
         initialStepID: Int? = nil, initiallyShowsHands: Bool = false, onClose: @escaping () -> Void,
         onPractice: @escaping (HandReplay) -> Void, onRule: @escaping (ReplayRule) -> Void) {
        self.replay = replay
        self.names = names
        self.mode = mode
        self.onClose = onClose
        self.onPractice = onPractice
        self.onRule = onRule
        var playback = ReplayPlayback(replay: replay)
        if let initialStepID { playback.select(id: initialStepID) }
        _playback = State(initialValue: playback)
        _showsHands = State(initialValue: initiallyShowsHands)
    }

    private var labels: LearningSeatLabels { LearningSeatLabels(names: names, mode: mode) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    contract
                    Divider().overlay(Theme.Paper.rule)
                    selectedEvent.id("selected-event")
                    LearningRuleLinks(rules: playback.current.rules, onRule: onRule)
                    allHands
                    timeline
                    Button("Practice this deal") { onPractice(replay) }.buttonStyle(PaperButtonStyle())
                }
                .font(.system(.body, design: .serif)).foregroundStyle(Theme.Paper.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20).paperCard().padding(12)
            }
            .onChange(of: playback.index) { _, _ in proxy.scrollTo("selected-event", anchor: .top) }
        }
        .background(WoodGrainView().ignoresSafeArea())
        .navigationTitle("Hand \(replay.number) replay")
        .toolbar {
            Button("Done", action: onClose).frame(minWidth: 44, minHeight: 44).foregroundStyle(.ivory)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { playbackControls }
    }

    private var contract: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ReplayWording.contract(replay)).font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(replay.trump.isRed ? Color.suitRed : Theme.Paper.green)
            Text("\(labels.name(replay.bidder)) won the bid").font(.subheadline)
            Text("Completed hand · all four hands may be revealed below.")
                .font(.footnote).foregroundStyle(Theme.Paper.ink.opacity(0.75))
        }
    }

    private var selectedEvent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step \(playback.index + 1) of \(replay.steps.count)").font(.subheadline)
                .foregroundStyle(Theme.Paper.ink.opacity(0.7))
            Text(ReplayWording.title(playback.current.event, labels: labels))
                .font(.system(.title2, design: .serif).weight(.bold))
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            eventDetails
            VStack(alignment: .leading, spacing: 4) {
                Text("Score at this step").font(.caption.weight(.semibold))
                ForEach(0..<2, id: \.self) { team in
                    Text("\(labels.team(team)): \(playback.current.scores[team])").font(.subheadline)
                }
            }
        }
    }

    @ViewBuilder private var eventDetails: some View {
        switch playback.current.event {
        case .deal:
            Text("Six cards are dealt to each seat. Open All hands to see this moment's cards.")
        case .bid:
            Text("This is the accepted call, in speaking order.")
        case .trump:
            Text("Trump is named before the automatic discard and refill.")
        case let .discard(_, thrown, drawn):
            Text("The house rule automatically keeps trumps and discards every non-trump.")
            cardRow("Discarded", cards: thrown)
            cardRow("Drawn", cards: drawn)
        case .play:
            trickCards(playback.current.currentTrick)
        case let .trick(_, plays, _):
            trickCards(plays)
            Text("The winning seat takes these four cards. The hand's High and Low points are settled after play.")
                .font(.subheadline)
        case let .score(before, after, result, _, _):
            ForEach(0..<2, id: \.self) { team in
                VStack(alignment: .leading, spacing: 4) {
                    Text(ReplayWording.scoreLine(team: team, before: before, after: after, labels: labels)).font(.headline)
                    Text("Captured \(result.points[team]) points · Game card value \(result.gameValues[team])").font(.subheadline)
                }
            }
            Text(ReplayWording.settlement(replay, result: result, labels: labels))
            scoringPoints(result)
        }
    }

    private func cardRow(_ title: String, cards: [Card]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) · \(cards.count)").font(.headline)
            if cards.isEmpty { Text("None").font(.subheadline) }
            else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) { ForEach(cards, id: \.self) { CardView(card: $0, width: 48) } }
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private func trickCards(_ plays: [Play]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(plays.enumerated()), id: \.offset) { _, play in
                HStack(alignment: .center, spacing: 12) {
                    CardView(card: play.card, width: 48)
                    Text(labels.name(play.seat)).font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func scoringPoints(_ result: HandScore) -> some View {
        let points: [(String, Int?)] = [("High", result.highTeam), ("Low", result.lowTeam),
                                      ("Jack", result.jackTeam), ("Five", result.fiveTeam), ("Game", result.gameTeam)]
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(points, id: \.0) { point in
                Text("\(point.0): \(point.1.map(labels.team) ?? "not in play")").font(.subheadline)
            }
        }
    }

    private var allHands: some View {
        DisclosureGroup("All hands at this step", isExpanded: $showsHands) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<4, id: \.self) { seat in
                    cardRow(labels.name(seat), cards: playback.current.hands[seat])
                }
            }.padding(.top, 12)
        }
        .font(.headline).tint(Theme.Paper.green)
        .frame(minHeight: 44)
    }

    private var timeline: some View {
        DisclosureGroup("Every bid, discard and trick") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(replay.steps) { step in
                    Button { playback.select(id: step.id) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(step.id + 1)").monospacedDigit().foregroundStyle(Theme.Paper.ink.opacity(0.6))
                            Text(ReplayWording.title(step.event, labels: labels)).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            if step.id == playback.current.id { Image(systemName: "checkmark").accessibilityHidden(true) }
                        }
                        .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.vertical, 4).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.Paper.green)
                    .accessibilityAddTraits(step.id == playback.current.id ? .isSelected : [])
                    Divider().overlay(Theme.Paper.rule.opacity(0.5))
                }
            }.padding(.top, 8)
        }
        .font(.headline).tint(Theme.Paper.green).frame(minHeight: 44)
    }

    private var playbackControls: some View {
        ViewThatFits(in: .horizontal) {
            controlRow(compact: false)
            controlRow(compact: true)
        }
        .buttonStyle(.plain).font(.headline).foregroundStyle(Theme.Paper.green)
        .frame(minHeight: 56).padding(.horizontal, 16).padding(.vertical, 4)
        .background(Color.ivory)
    }

    private func controlRow(compact: Bool) -> some View {
        HStack(spacing: 8) {
            Button { playback.previous() } label: {
                Group {
                    if compact { Image(systemName: "chevron.left") }
                    else { Label("Previous", systemImage: "chevron.left").fixedSize() }
                }.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .disabled(!playback.canGoBack).accessibilityLabel("Previous replay step")
            Spacer(minLength: 0)
            Text("\(playback.index + 1) / \(replay.steps.count)").font(.caption).monospacedDigit()
                .accessibilityLabel("Step \(playback.index + 1) of \(replay.steps.count)")
            Spacer(minLength: 0)
            Button { playback.next() } label: {
                Group {
                    if compact { Image(systemName: "chevron.right") }
                    else { Label("Next", systemImage: "chevron.right").fixedSize() }
                }.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .disabled(!playback.canGoForward).accessibilityLabel("Next replay step")
        }
    }
}
