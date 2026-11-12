import Foundation

/// The house rules as shown in the app. Every paragraph is copied verbatim from
/// `docs/catch-five-rules.md`; a test reads that file and fails if the two drift apart.
public enum RulesText {
    /// Where the game comes from: the first line of the rules sheet and the first face of the tip card (D66, D67).
    /// Not a rule, so it lives outside `sections` and the verbatim check against the rules document.
    public static let origin = "A New England variant of Pitch, passed down through generations. We hope you enjoy it as much as we do."
    /// The family's sign-off at the end of the rules sheet, above a mail link (N34). Not a rule either.
    public static let signOff = "We're honored you took a seat at our table. This game has been part of my family for generations. Always will be. The rules stay as they are, but if you have ideas for the app, email me. I'd love to hear them."
    public static let contactEmail = "cmurphy1140@gmail.com"
    /// A new mail to `contactEmail` with the subject "Catch 5".
    public static let contactURL = URL(string: "mailto:\(contactEmail)?subject=Catch%205")!

    public struct Section: Sendable {
        public let title: String
        public let paragraphs: [String]
    }

    public static let sections: [Section] = [
        Section(title: "The table", paragraphs: [
            "Four players, two partnerships seated opposite; standard 52-card deck. First team to 25 wins. If both reach 25 on the same hand, the bidding team wins.",
            "Before the first hand each player draws a card and the highest deals; equal ranks go by suit, clubs lowest and spades highest. After that the deal passes to the left.",
        ]),
        Section(title: "Deal and bidding", paragraphs: [
            "Deal six cards each. Bidding starts left of dealer and ends with dealer. Minimum 2, maximum normal bid 9. Non-dealers must raise; dealer may match the highest bid and must bid 2 if everyone passes. Bid winner chooses trump. Discard all non-trumps and replenish each hand to six. Undealt cards remain out of play, including scoring cards.",
        ]),
        Section(title: "Play", paragraphs: [
            "Bid winner leads the first trick and must lead a trump if holding one; with no trump, any card may lead. Later leads are free. Players must follow suit if able; otherwise any card is legal. Highest trump wins, otherwise highest card of the led suit. Trick winner leads next.",
        ]),
        Section(title: "Scoring", paragraphs: [
            "Points are awarded to capturing teams: highest trump played (1), lowest trump played (1), trump Jack (1), trump Five (5). High/Low are relative to cards actually played, not necessarily Ace/2. Missing Jack/Five contribute no points.",
            "Game (1) goes to the team with the greatest captured-card value across all suits: 10=10, J=1, Q=2, K=3, A=4; all others=0. Ties go to the bidding team.",
            "Successful normal bidders add every point collected; unsuccessful bidders subtract their bid. Defenders always add their points.",
        ]),
        Section(title: "9 and out", paragraphs: [
            "A special 9 and out bid is forbidden below zero. At zero or above, collecting all nine points wins the match; collecting fewer loses the match regardless of normal scores.",
            "A 9 and out declaration outranks a normal 9. Nobody, the dealer included, may match or overcall a 9 and out declaration: it stands, and its bidder keeps the bid (house rule, confirmed 2026-10-07).",
        ]),
    ]

    /// How the screen presents the rules; not part of the rules document.
    public static let readingTheTable: [String] = [
        "Scores for both partnerships sit at the top, with the trump suit and the current bid between them.",
        "During the auction each seat's tile shows its bid or pass. After trump is named, the bidder's tile says so and the others show cards left.",
        "Cards you cannot legally play are dimmed. The last hand stays on the table, with the winning card ringed, until the next lead.",
        "Choose Why this move? on your turn for a standard-strategy suggestion using only your hand and public play. After a hand ends, Replay hand shows every bid, discard, trick and score change; all four completed hands can be revealed.",
        "The gear opens settings: difficulty, play speed, seat names and haptics.",
    ]

    public static var allText: String {
        sections.flatMap(\.paragraphs).joined(separator: "\n")
    }
}
