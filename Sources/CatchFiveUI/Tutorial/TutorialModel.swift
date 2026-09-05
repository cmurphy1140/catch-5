import CatchFive
import Combine
import Foundation

/// State for the five-lesson "How to play" flow. Completion is handed back through `onCompletionChange`
/// so the caller can persist it in `Settings` alongside the other preferences.
@MainActor
public final class TutorialModel: ObservableObject {
    public static let lessonCount = 5
    public static let titles = ["The deal", "Bidding", "Trump", "Tricks", "Scoring"]

    @Published public var lesson = 0
    @Published public private(set) var completed: Set<Int>
    private let onCompletionChange: (Set<Int>) -> Void

    // Exercise state, one lesson each.
    @Published public private(set) var dealPick: Int?
    @Published public private(set) var dealFeedback = ""
    @Published public private(set) var bidPick: TutorialBid?
    @Published public private(set) var bidFeedback = ""
    @Published public private(set) var trumpPick: Suit?
    @Published public private(set) var trumpFeedback = ""
    @Published public var showRefill = false
    @Published public private(set) var trickPart = 0
    @Published public private(set) var trickPick: Card?
    @Published public private(set) var winnerPick: Int?
    @Published public private(set) var trickFeedback = ""
    @Published public private(set) var scoringPicks: [ScoreCategory: Int] = [:]

    public init(completed: Set<Int>, onCompletionChange: @escaping (Set<Int>) -> Void) {
        self.completed = completed
        self.onCompletionChange = onCompletionChange
    }

    public var isLastLesson: Bool { lesson == Self.lessonCount - 1 }
    public func next() { if !isLastLesson { lesson += 1 } }
    public func back() { if lesson > 0 { lesson -= 1 } }

    public func complete(_ lesson: Int) {
        guard !completed.contains(lesson) else { return }
        completed.insert(lesson)
        onCompletionChange(completed)
    }

    // MARK: Lesson 1

    public func pickSeat(_ seat: Int) {
        dealPick = seat
        if seat == TutorialFixtures.firstDealt {
            dealFeedback = "Right. You sit on East's left, so you get the first three cards, then West, then Partner, then East. Then around again for the second three."
            complete(0)
        } else if seat == TutorialFixtures.dealer {
            dealFeedback = "The dealer deals to themselves last. Try the seat on the dealer's left."
        } else {
            dealFeedback = "Not first. Dealing goes clockwise from the dealer's left, and East is dealing."
        }
    }

    // MARK: Lesson 2

    public func chooseBid(_ bid: TutorialBid) {
        bidPick = bid
        switch bid {
        case .points(let amount) where amount < 4:
            bidFeedback = "Partner already bid 3, so a bid has to raise it. You would need 4 or more."
        case .points(4):
            bidFeedback = "Four is the smallest raise, and you can see it: the ace of spades is High, the five is yours to protect, and the king helps. Bid what you can take."
            complete(1)
        case .points:
            bidFeedback = "Legal, but ambitious. You can see about six points in spades; the rest depend on cards you have not drawn yet."
            complete(1)
        case .pass:
            bidFeedback = "Passing is always allowed, but with the ace and five of spades you are handing a strong hand to Partner's 3."
            complete(1)
        case .nineAndOut:
            bidFeedback = "Legal, but drastic: 9 and out means take all nine points or lose the whole game. Not with this hand."
            complete(1)
        }
    }

    // MARK: Lesson 3

    public func chooseTrump(_ suit: Suit) {
        trumpPick = suit
        if suit == TutorialFixtures.trumpAnswer {
            trumpFeedback = "Spades. Three of them, headed by the ace, and the five is yours to protect. The faded cards are about to be discarded."
            complete(2)
        } else {
            let held = TutorialFixtures.biddingHand.filter { $0.suit == suit }.count
            trumpFeedback = "You hold \(held == 1 ? "one \(suit.rawValue) card" : "\(held) \(suit.rawValue)") and it is low. Naming it throws away your best cards. Look for the suit you hold most of."
        }
    }

    // MARK: Lesson 4

    public var trickPrompt: String {
        trickPart == 0 ? "West led the K♦. Spades are trump. Tap a card you are allowed to play." : "Four cards down. Tap the winner."
    }

    public func pickTrickCard(_ card: Card) {
        trickPick = card
        if TutorialFixtures.trickLegalAnswers.contains(card) {
            trickFeedback = "Yes. You hold diamonds, so a diamond has to go. Keep the ace of spades for a trick that is worth it."
        } else if card.suit == .spades {
            trickFeedback = "Not yet. Trump only comes in when you cannot follow suit, and you still hold diamonds."
        } else {
            trickFeedback = "You must follow suit. You have two diamonds, so one of them has to go."
        }
    }

    public func advanceTrickPart() {
        guard trickPart == 0, let pick = trickPick, TutorialFixtures.trickLegalAnswers.contains(pick) else { return }
        trickPart = 1
        trickFeedback = ""
    }

    public func pickWinner(_ seat: Int) {
        winnerPick = seat
        if seat == TutorialFixtures.trickWinnerAnswer {
            trickFeedback = "East wins with the 2♠. East had no diamonds, so East was free to trump, and any trump beats every non-trump, even your ace. East leads the next trick."
            complete(3)
        } else if seat == 0 {
            trickFeedback = "Your ace is the highest diamond, but a trump was played. Trumps beat everything."
        } else {
            trickFeedback = "Not that one. Is there a trump on the table?"
        }
    }

    // MARK: Lesson 5

    public func assign(_ category: ScoreCategory, to team: Int) {
        scoringPicks[category] = team
        if scoringPicks == TutorialFixtures.scoringAnswers { complete(4) }
    }

    public func scoringIsCorrect(_ category: ScoreCategory) -> Bool? {
        scoringPicks[category].map { $0 == TutorialFixtures.scoringAnswers[category] }
    }

    public var allScoringCorrect: Bool { scoringPicks == TutorialFixtures.scoringAnswers }
}
