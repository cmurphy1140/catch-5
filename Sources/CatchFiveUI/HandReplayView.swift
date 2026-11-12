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

    /// The hand review keeps familiar names, adding the seat only when names repeat.
    static func reviewName(_ seat: Int, in names: [String]) -> String {
        let name = names.indices.contains(seat) ? names[seat] : "Player"
        return names.filter { $0 == name }.count > 1 ? "\(name) · seat \(seat + 1)" : name
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
    let onStepChange: (Int) -> Void
    let bottomSeat: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var playback: ReplayPlayback
    @State private var showsHands: Bool

    init(replay: HandReplay, names: [String], mode: PlayMode,
         initialStepID: Int? = nil, initiallyShowsHands: Bool = false, bottomSeat: Int = 0,
         onClose: @escaping () -> Void, onPractice: @escaping (HandReplay) -> Void,
         onRule: @escaping (ReplayRule) -> Void, onStepChange: @escaping (Int) -> Void = { _ in }) {
        self.replay = replay
        self.names = names
        self.mode = mode
        self.onClose = onClose
        self.onPractice = onPractice
        self.onRule = onRule
        self.onStepChange = onStepChange
        self.bottomSeat = ReplayTrickPresentation.seat(at: 0, bottomSeat: bottomSeat)
        var playback = ReplayPlayback(replay: replay)
        if let initialStepID { playback.select(id: initialStepID) }
        _playback = State(initialValue: playback)
        _showsHands = State(initialValue: initiallyShowsHands)
    }

    private var labels: LearningSeatLabels { LearningSeatLabels(names: names, mode: mode) }
    private var trickExplanation: ReplayTrickPresentation? {
        ReplayTrickPresentation.forStep(playback.current, in: replay)
    }
    private var remainingRules: [ReplayRule] {
        playback.current.rules.filter {
            trickExplanation == nil || ($0 != .trumpWins && $0 != .ledSuitWins)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    contract
                    Divider().overlay(Theme.Paper.rule)
                    selectedEvent.id("selected-event")
                    LearningRuleLinks(rules: remainingRules, onRule: onRule)
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
        VStack(alignment: .leading, spacing: 16) {
            if let lead = plays.first {
                Text("\(lead.card.suit.rawValue.capitalized) led · \(replay.trump.rawValue.capitalized) trump")
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if dynamicTypeSize.isAccessibilitySize {
                orderedTrickCards(plays)
            } else {
                tableTrickCards(plays)
            }
            if let explanation = trickExplanation {
                DisclosureGroup("Why did that win?") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(explanation.explanation)
                            .font(.body).fixedSize(horizontal: false, vertical: true)
                        Button { onRule(explanation.rule) } label: {
                            Label("Read the house rule", systemImage: "book.closed")
                                .font(.subheadline.weight(.semibold))
                                .frame(minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).foregroundStyle(Theme.Paper.green)
                        .accessibilityHint("Returns to these same four cards when you go back")
                    }
                    .padding(.top, 10)
                }
                .font(.headline).tint(Theme.Paper.green)
                .frame(minHeight: 44)
            }
        }
    }

    /// A completed hand keeps the live table's seat orientation; order labels still tell
    /// who led and who followed. Larger type uses the same four plays as a reading list.
    private func tableTrickCards(_ plays: [Play]) -> some View {
        VStack(spacing: 12) {
            tableSeat(2, plays: plays)
            HStack(alignment: .center, spacing: 12) {
                tableSeat(1, plays: plays)
                Spacer(minLength: 20)
                tableSeat(3, plays: plays)
            }
            tableSeat(0, plays: plays)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plays.enumerated().map { index, play in
            spokenPlay(play, order: index + 1)
        }.joined(separator: ". "))
    }

    private func tableSeat(_ place: Int, plays: [Play]) -> some View {
        let seat = ReplayTrickPresentation.seat(at: place, bottomSeat: bottomSeat)
        let position = plays.firstIndex(where: { $0.seat == seat })
        return VStack(spacing: 5) {
            Text(labels.name(seat)).font(.caption.weight(.medium))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let position {
                let play = plays[position]
                let won = trickExplanation?.winningPlay.seat == play.seat
                CardView(card: play.card, width: 52, ring: won ? Theme.Paper.green : nil)
                Text(position == 0 ? "1 · Led" : "\(position + 1) · Played")
                    .font(.caption).foregroundStyle(Theme.Paper.ink.opacity(0.75))
                if won { tookTrick }
            } else {
                Text("Waiting").font(.caption)
                    .foregroundStyle(Theme.Paper.ink.opacity(0.55))
                    .frame(width: 52, height: 73)
            }
        }
        .frame(maxWidth: 124)
    }

    private func orderedTrickCards(_ plays: [Play]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(plays.enumerated()), id: \.offset) { index, play in
                HStack(alignment: .top, spacing: 12) {
                    let won = trickExplanation?.winningPlay.seat == play.seat
                    CardView(card: play.card, width: 48, ring: won ? Theme.Paper.green : nil)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(index + 1) · \(labels.name(play.seat))").font(.subheadline.weight(.medium))
                        Text(play.card.name.capitalized).font(.subheadline)
                        if won { tookTrick }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenPlay(play, order: index + 1))
            }
        }
    }

    private var tookTrick: some View {
        Text("Took trick").font(.caption.weight(.semibold))
            .foregroundStyle(Theme.Paper.green)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func spokenPlay(_ play: Play, order: Int) -> String {
        let result = trickExplanation?.winningPlay.seat == play.seat ? ", took the trick" : ""
        return "\(order). \(labels.name(play.seat)), \(play.card.name)\(result)"
    }

    private func selectStep(id: Int) {
        playback.select(id: id)
        onStepChange(playback.current.id)
    }

    private func previousStep() {
        playback.previous()
        onStepChange(playback.current.id)
    }

    private func nextStep() {
        playback.next()
        onStepChange(playback.current.id)
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
                    Button { selectStep(id: step.id) } label: {
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
            Button(action: previousStep) {
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
            Button(action: nextStep) {
                Group {
                    if compact { Image(systemName: "chevron.right") }
                    else { Label("Next", systemImage: "chevron.right").fixedSize() }
                }.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .disabled(!playback.canGoForward).accessibilityLabel("Next replay step")
        }
    }
}
