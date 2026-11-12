import Foundation
import CatchFive

/// A standard-strategy suggestion for one revealed turn; contains no hidden game state.
struct LiveAdvicePresentation: Identifiable {
    let id = UUID()
    let viewerSeat: Int
    let revision: Int
    let advice: Advice
    let rules: [ReplayRule]
    private let source: ObjectIdentifier

    @MainActor fileprivate init(model: GameModel, viewerSeat: Int, advice: Advice, rules: [ReplayRule]) {
        source = ObjectIdentifier(model)
        self.viewerSeat = viewerSeat
        revision = model.revision
        self.advice = advice
        self.rules = rules
    }

    var actionTitle: String {
        switch advice.action {
        case .bid(nil): "Pass"
        case let .bid(amount?): "Bid \(amount)"
        case .nineAndOut: "Bid 9 and out"
        case let .chooseTrump(suit): "Choose \(suit.rawValue)"
        case let .play(card): "Play the \(card.name)"
        }
    }

    @MainActor func isValid(for model: GameModel, covered: Bool = false) -> Bool {
        source == ObjectIdentifier(model) && revision == model.revision && viewerSeat == model.viewerSeat
            && model.isHumanTurn && model.curtainSeat == nil && model.dealerDraw == nil
            && model.match.hand.phase != .finished && model.match.winner == nil && !covered
    }
}

extension GameModel {
    func liveAdvice(covered: Bool = false) -> LiveAdvicePresentation? {
        guard !covered, curtainSeat == nil, dealerDraw == nil, isHumanTurn, match.winner == nil,
              match.hand.phase != .finished, let seat = viewerSeat,
              let view = try? PlayerView(match: match, seat: seat),
              let advice = ComputerPlayer.advise(view) else { return nil }
        var rules: [ReplayRule] = []
        switch view.phase {
        case .bidding:
            rules = [.bidding]
            if view.calls.contains(where: { $0.bid == .nineAndOut }) || advice.action == .nineAndOut { rules.append(.nineAndOut) }
            else if view.seat == view.dealer, view.highestBid != nil { rules.append(.dealerMatch) }
        case .choosingTrump: rules = [.discardAndRefill]
        case .playing:
            if view.trick.isEmpty && view.completedTricks.isEmpty { rules.append(.openingTrump) }
            if let led = view.trick.first?.card.suit, view.cards.contains(where: { $0.suit == led }) { rules.append(.followSuit) }
            let trumpPlayed = view.trick.contains { $0.card.suit == view.trump }
            if case let .play(card) = advice.action, card.suit == view.trump || trumpPlayed { rules.append(.trumpWins) }
            else { rules.append(.ledSuitWins) }
        case .finished: return nil
        }
        return LiveAdvicePresentation(model: self, viewerSeat: seat, advice: advice, rules: rules)
    }
}
