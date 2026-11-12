import Foundation
import CatchFive

/// A searchable index of the canonical house rules, with separate worked examples.
enum HouseRuleGuide {
    struct Entry: Identifiable, Sendable {
        let id: String
        let title: String
        let paragraphs: [String]
        let example: String
        let keywords: [String]
        let rules: [ReplayRule]
    }

    static let entries: [Entry] = {
        let sections = RulesText.sections
        // These fixed scoring fixtures contain unique cards and valid bids.
        let high = try! playedHighExample(), tie = try! tiedGameExample(), set = try! setBidExample()
        let ordinary = try! nineExample(special: false), special = try! nineExample(special: true)
        return [
            Entry(id: "bidding", title: "Bidding and dealer matching", paragraphs: sections[1].paragraphs + [sections[4].paragraphs[1]],
                  example: "Example: a normal 4 may be matched by the dealer. A 9 and out may never be matched, even by the dealer.",
                  keywords: ["dealer match", "auction", "raise", "pass", "minimum"], rules: [.bidding, .dealerMatch]),
            Entry(id: "discard", title: "Discard and replenish", paragraphs: sections[1].paragraphs,
                  example: "Example: keep two trumps, discard four non-trumps, then draw four replacements. Undealt scoring cards stay out of play.",
                  keywords: ["refill", "draw", "undealt", "stock"], rules: [.discardAndRefill]),
            Entry(id: "opening", title: "The opening lead", paragraphs: sections[2].paragraphs,
                  example: "Example: the bidder holding clubs as trump must lead a club on the first trick; later leads are free.",
                  keywords: ["first lead", "opening trump"], rules: [.openingTrump]),
            Entry(id: "follow", title: "Follow suit", paragraphs: sections[2].paragraphs,
                  example: "Example: when hearts are led, a player holding a heart must play one, even when another player has trumped.",
                  keywords: ["legal play", "must follow", "void"], rules: [.followSuit]),
            Entry(id: "trick", title: "Winning a trick", paragraphs: sections[2].paragraphs,
                  example: "Example: with clubs as trump, the two of clubs beats the ace of hearts in a hearts-led trick. The hand's High point is scored separately.",
                  keywords: ["highest trump", "led suit", "trick winner"], rules: [.trumpWins, .ledSuitWins]),
            Entry(id: "high-low", title: "High and Low: highest trump played", paragraphs: [sections[3].paragraphs[0]],
                  example: "Scoring example: only the king and eight of clubs were played as trumps. The king's capturing team (team \(high.highTeam! + 1)) gets High; the eight's team gets Low. An unplayed ace cannot win High.",
                  keywords: ["highest trump played", "lowest trump played", "king", "ace absent"], rules: [.highLowPlayed]),
            Entry(id: "captured", title: "Captured points and missing scoring cards", paragraphs: [sections[3].paragraphs[0], sections[1].paragraphs[0]],
                  example: "Scoring example: with only that king and eight as trumps, Jack and Five award no points. Including Game, this example awards \(high.points.reduce(0, +)) points total. Undealt cards never count.",
                  keywords: ["missing jack", "missing five", "undealt scoring", "capture"], rules: [.capturedScoring]),
            Entry(id: "game", title: "Game and tied card values", paragraphs: [sections[3].paragraphs[1]],
                  example: "Scoring example: team card values tie at \(tie.gameValues[0]) each. Bidding team \(tie.gameTeam + 1) receives Game's one point.",
                  keywords: ["game tie", "ten", "card values"], rules: [.gameTie]),
            Entry(id: "settlement", title: "Making a bid or going set", paragraphs: [sections[3].paragraphs[2]],
                  example: "Scoring example: starting at 10–4, team 1 bids 5 but captures 3; defenders capture 6. The scores become \(set.scores[0])–\(set.scores[1]).",
                  keywords: ["set bid", "subtract", "ordinary settlement", "defenders"], rules: [.ordinarySettlement]),
            Entry(id: "nine-out", title: "9 and out versus a normal nine", paragraphs: sections[4].paragraphs,
                  example: "Scoring example: at 0–0, a normal 9 collecting 8 leaves \(ordinary.scores[0])–\(ordinary.scores[1]) and play continues. The same result on 9 and out immediately gives team \(special.winner! + 1) the match. Below zero, the special bid is forbidden.",
                  keywords: ["nine and out", "9 and out", "negative", "below zero", "special bid"], rules: [.nineAndOut]),
            Entry(id: "target", title: "First to 25", paragraphs: [sections[0].paragraphs[0]],
                  example: "Example: if both teams reach 25 on the same normal hand, the bidding team wins.",
                  keywords: ["target score", "match winner", "both reach"], rules: [.targetScore]),
        ]
    }()

    static func entry(id: String) -> Entry? { entries.first { $0.id == id } }

    static func entry(for rule: ReplayRule) -> Entry {
        let id: String
        switch rule {
        case .bidding, .dealerMatch: id = "bidding"
        case .discardAndRefill: id = "discard"
        case .openingTrump: id = "opening"
        case .followSuit: id = "follow"
        case .trumpWins, .ledSuitWins: id = "trick"
        case .highLowPlayed: id = "high-low"
        case .capturedScoring: id = "captured"
        case .gameTie: id = "game"
        case .ordinarySettlement: id = "settlement"
        case .nineAndOut: id = "nine-out"
        case .targetScore: id = "target"
        }
        return entry(id: id)!
    }

    static func search(_ query: String) -> [Entry] {
        let terms = normalized(query).split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return entries }
        let phrase = terms.joined(separator: " ")
        return entries.enumerated().compactMap { index, entry -> (Int, Int, Entry)? in
            let text = normalized(([entry.title, entry.example] + entry.paragraphs + entry.keywords).joined(separator: " "))
            guard terms.allSatisfy({ text.contains($0) }) else { return nil }
            let priority = normalized(entry.title).contains(phrase) ? 2 : (entry.keywords.contains { normalized($0).contains(phrase) } ? 1 : 0)
            return (priority, index, entry)
        }.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 > $1.0 }.map { $0.2 }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "&", with: " and ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.map { $0 == "nine" ? "9" : $0 }.joined(separator: " ")
    }

    static func playedHighExample() throws -> HandScore {
        try scoreHand(captured: [[Card(.clubs, .king)], [Card(.clubs, .eight)]], trump: .clubs, bidder: 0)
    }
    static func tiedGameExample() throws -> HandScore {
        try scoreHand(captured: [[Card(.clubs, .two)], [Card(.clubs, .three)]], trump: .clubs, bidder: 1)
    }
    static func setBidExample() throws -> Settlement {
        try settle(scores: [10, 4], points: [3, 6], bidder: 0, bid: .points(5))
    }
    static func nineExample(special: Bool, startingScore: Int = 0) throws -> Settlement {
        try settle(scores: [startingScore, 0], points: [8, 1], bidder: 0, bid: special ? .nineAndOut : .points(9))
    }
}
