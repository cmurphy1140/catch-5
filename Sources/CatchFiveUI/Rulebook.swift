import CatchFive
import SwiftUI

/// The illustrated rulebook (D185): thirteen short pages, one idea to a page, in the book's own plain words. The rules
/// as the family wrote them stay in `RulesText`, checked against the rules document and reached from the contents
/// page; this is the teaching of them. The words are data so the book is tested without a screen.
enum Rulebook {
    struct Page: Identifiable, Sendable {
        let chapter: RulesView.Chapter?
        let title: String
        let lede: String
        /// A git-ignored picture of the build, drawn above the words when it is there.
        var picture: String?
        let blocks: [Block]
        var id: String { title }
    }

    enum Block: Sendable {
        case heading(String)
        case text(String)
        /// Small red capitals over what follows.
        case label(String)
        case rule
        /// A quiet aside in italics.
        case note(String)
        /// A sum or a score written large; `red` for the one that matters.
        case big(String, red: Bool)
        /// A row of cards, the marked ones outlined and underlined.
        case cards([Card], marked: [Card])
        /// A trick under its label: who played what, whose card took it, and why.
        case trick(label: String, plays: [Play], winner: Int, caption: String)
        /// The five points of a hand, as a ledger.
        case points
        /// What each rank counts toward Game.
        case gameValues
        /// The dealer's call, judged by the engine.
        case call
        /// Your hand with a heart led, judged by the engine.
        case hand
        /// The six chapters, each opening its first page.
        case contents
        /// The family's note and the mail link.
        case signOff
    }

    /// The book's own cast, the one painted into its pictures: you, then Hazel, Otto across from you, and Rue.
    static let names = ["You"] + Cast.opponents.map(\.name)

    /// What the contents page says under each chapter.
    static func about(_ chapter: RulesView.Chapter) -> String {
        switch chapter {
        case .table: "Partners and the winning score"
        case .deal: "First dealer, auction, and refill"
        case .play: "Following suit and taking a trick"
        case .scoring: "The nine points and the scorepad"
        case .nineAndOut: "Calling the match on a single hand"
        case .reading: "Scoreboard, replay, and table settings"
        }
    }

    /// How each of a hand's points is won, in the book's words.
    static func how(_ point: String) -> String? {
        ["High": "Capture the highest trump actually played.", "Low": "Capture the lowest trump actually played.",
         "Jack": "Capture the Jack of trump.", "Five": "Capture the Five of trump.",
         "Game": "Collect the higher total card value in your tricks."][point]
    }

    /// The page a chapter opens on.
    static func firstPage(of chapter: RulesView.Chapter) -> Int {
        pages.firstIndex { $0.chapter == chapter } ?? 0
    }

    private static let spades = Suit.spades
    private static let example: [Card] = [Card(.spades, .ace), Card(.spades, .seven), Card(.hearts, .king),
                                          Card(.diamonds, .queen), Card(.clubs, .nine), Card(.hearts, .three)]

    static let pages: [Page] = [
        Page(chapter: nil, title: "Catch 5", lede: "A New England variant of Pitch, passed down through generations.", blocks: [
            .heading("Four players. Two partnerships."),
            .text("Play a hand, or look up a house rule."),
            .contents,
        ]),
        Page(chapter: .table, title: "Take a seat", lede: "Your partner sits across from you.", picture: "GuestBookTable", blocks: [
            .heading("Four seats, two teams"),
            .text("You and \(names[2]) play against \(names[1]) and \(names[3]). Use a standard 52-card deck."),
            .rule,
            .heading("First to \(RulesFigures.matchTarget) wins"),
            .text("If both teams reach \(RulesFigures.matchTarget) on the same hand, the bidding team wins."),
        ]),
        Page(chapter: .deal, title: "Draw for dealer", lede: "Before the first hand, everyone draws one card.", picture: "GuestBookDraw", blocks: [
            .heading("Highest card deals"),
            .text("If ranks tie, compare suits. Clubs are lowest and spades are highest."),
            .rule,
            .heading("Six cards apiece"),
            .text("Start with the player to the dealer’s left. Deal three at a time, twice around the table."),
            .note("After each hand, the deal passes to the left."),
        ]),
        Page(chapter: .deal, title: "Match the bid", lede: "The high bid is 3. You are the dealer.", picture: "GuestBookBid", blocks: [
            .label("The auction"),
            .text("A bid promises points for your team. Starting left of the dealer, bid 2 to 9 or pass. Each player gets one call. Non-dealers must raise."),
            .heading("What’s your call?"),
            .call,
            .rule,
            .note("If everyone else passes, the dealer must bid 2."),
        ]),
        Page(chapter: .deal, title: "Choose trump", lede: "The player who wins the bid names a suit.", blocks: [
            .label("Example / Spades are trump"),
            .cards(example, marked: example.filter { $0.suit == .spades }),
            .heading("Keep the two spades."),
            .text("Every player keeps their trump cards and discards all cards of the other suits."),
            .rule,
            .label("Refill to six"),
            .big("2 kept  +  4 drawn  =  6", red: false),
            .text("In this example, draw four replacement cards. Keep those cards, even if some are off-suit."),
            .rule,
            .heading("Leave the rest out"),
            .text("Undealt cards stay out of play, even if the trump Jack or Five is among them."),
        ]),
        Page(chapter: .play, title: "Follow suit", lede: "A heart was led. Spades are trump.", picture: "GuestBookFollow", blocks: [
            .heading("Which card can you play?"),
            .label("Your hand"),
            .hand,
            .text("Follow the led suit whenever you can. If you have none, any card is legal, including trump."),
            .rule,
            .note("Each of the six tricks has one card from each player."),
        ]),
        Page(chapter: .play, title: "Who wins the trick?", lede: "Compare two later tricks. Spades are trump.", blocks: [
            .text("On the first trick, the bid winner leads trump if they have one. With no trump, they may lead any suit. Later leads may be any suit."),
            .trick(label: "No trump played", plays: RulesFigures.followedTrick, winner: RulesFigures.followedWinner,
                   caption: "\(names[RulesFigures.followedWinner]) wins with the highest heart."),
            .trick(label: "A trump is played", plays: RulesFigures.trumpedTrick, winner: RulesFigures.trumpedWinner,
                   caption: "\(names[RulesFigures.trumpedWinner]) has no hearts. The trump beats \(names[RulesFigures.followedWinner])’s king."),
            .rule,
            .text("Highest trump wins. With no trump, highest of the led suit wins. The winner leads the next trick."),
        ]),
        Page(chapter: .scoring, title: "Count your points", lede: "A hand has up to nine points to capture.", blocks: [
            .points,
            .heading("Unplayed cards score nothing"),
            .text("If the trump Jack or Five never enters play, its points cannot be collected."),
        ]),
        Page(chapter: .scoring, title: "The Game point", lede: "One point goes to the team with the higher card-value total.", blocks: [
            .label("Count captured cards in every suit"),
            .gameValues,
            .text("All other ranks count as zero toward Game."),
            .rule,
            .heading("A close count"),
            .text("Suppose your captured cards total 18 in Game value. Your opponents have 17."),
            .big("18 to 17", red: true),
            .text("Your team earns the one Game point. On a tie, the bidding team gets it."),
            .rule,
            .note("The trump Five is worth five hand points. Its rank contributes zero to the Game count."),
        ]),
        Page(chapter: .scoring, title: "Make your bid", lede: "Your team bid 6 and collected 7.", picture: "GuestBookScore", blocks: [
            .label("Points your team took"),
            .big("High 1  +  Jack 1  +  Five 5  =  7", red: false),
            .rule,
            .heading("You made your bid"),
            .text("Add all 7 points. Your score moves from 18 to 25."),
            .rule,
            .text("With only 5 points, you would miss your bid of 6. Subtract 6 from 18 to finish at 12."),
            .note("Defenders always add the points they collect."),
        ]),
        Page(chapter: .nineAndOut, title: "Nine and out", lede: "One call can decide the match.", picture: "GuestBookNine", blocks: [
            .heading("Who can call it?"),
            .text("Your team’s score must be 0 or higher. At −9, the call is unavailable."),
            .rule,
            .heading("Take all nine. Win the match."),
            .big("Take fewer. Lose the match.", red: true),
            .text("The result holds whatever the score. Nine and out outranks a normal 9. Nobody, including the dealer, can match or overcall it."),
            .note("House rule confirmed October 7, 2026."),
        ]),
        Page(chapter: .reading, title: "Read the table", lede: "The scores, the bid, and the cards still in play.", picture: "GuestBookRead", blocks: [
            .heading("Across the top"),
            .text("The team scores are 18 and 12. The club symbol names trump. Bid 6 is the winning bid."),
            .rule,
            .heading("At each seat"),
            .text("During the auction, seats show bids or passes. Once trump is named, the bidder is marked. “3 left” means that player holds three cards."),
            .rule,
            .text("Illegal cards are dimmed. The last trick stays on the table with its winning card ringed until the next lead."),
        ]),
        Page(chapter: .reading, title: "After the hand", lede: "Look back at the cards that changed the score.", picture: "GuestBookAfter", blocks: [
            .heading("Replay hand"),
            .text("Review every bid, discard, trick and score change. Once the hand ends, you can reveal all four hands."),
            .rule,
            .text("Why this move? suggests a standard-strategy play using your hand and public play."),
            .text("The gear opens difficulty, play speed, seat names and haptics."),
            .rule,
            .signOff,
        ]),
    ]

    /// What the dealer hears back for a call the engine took (the book's words; a refusal is the engine's own).
    static func verdict(forCall action: PlayerAction) -> String {
        switch action {
        case .bid(nil): "You pass. \(names[1]) keeps the bid at 3 and names trump."
        case .bid(3): "Your 3 takes the bid. The dealer may match the highest normal bid."
        case let .bid(amount?): "Your \(amount) takes the bid. It beats the 3."
        default: "Accepted."
        }
    }
}

/// The rulebook on plain paper: a page at a time, with Previous and the next page's name at the foot.
struct RulebookView: View {
    let onDismiss: () -> Void
    @State private var index: Int
    @State private var showRules = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The pictures' own paper, so each one melts into the page.
    static let paper = Color(red: 0.988, green: 0.965, blue: 0.91)
    static let red = Theme.Team.theirRim

    init(initial: RulesView.Chapter? = nil, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        // `-rulebookPage 6` at launch opens the book at that page, counted from 1, for screenshots.
        let asked = UserDefaults.standard.integer(forKey: "rulebookPage")
        let start = Rulebook.pages.indices.contains(asked - 1) ? asked - 1
            : ScreenshotStage.name == "signoff" ? Rulebook.pages.count - 1 : initial.map(Rulebook.firstPage) ?? 0
        _index = State(initialValue: start)
    }

    private var page: Rulebook.Page { Rulebook.pages[index] }
    private var count: Int { Rulebook.pages.count }

    var body: some View {
        VStack(spacing: 0) {
            band.zIndex(1)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        RulebookPageView(page: page, open: turn, openRules: { showRules = true })
                    }
                    .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 20)
                    .frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity)
                    .id("top")
                }
                .onChange(of: index) { _, _ in proxy.scrollTo("top", anchor: .top) }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { foot }
            .background(Self.paper.ignoresSafeArea())
            // A flick sideways turns the page, as a book's does.
            .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { drag in
                guard abs(drag.translation.width) > abs(drag.translation.height) * 2 else { return }
                if drag.translation.width < 0, index < count - 1 { turn(index + 1) }
                if drag.translation.width > 0, index > 0 { turn(index - 1) }
            })
        }
        .foregroundStyle(Theme.Paper.ink)
        .background(Self.paper.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showRules) { RulesView { showRules = false } }
    }

    private func turn(_ to: Int) {
        guard Rulebook.pages.indices.contains(to) else { return }
        withAnimation(reduceMotion ? Theme.Motion.reduced : .easeInOut(duration: 0.22)) { index = to }
    }

    /// A slim strip of the other pages' cloth (D181) as the running head: back to the chapters, where you are in
    /// the book, and Done. Slim, so the page under it holds what the mockup's page holds.
    private var band: some View {
        HStack(spacing: 12) {
            if index == 0 {
                Text("Rulebook").font(.system(.headline, design: .serif)).accessibilityAddTraits(.isHeader)
            } else {
                Button { turn(0) } label: {
                    Text("‹  Chapters").font(.system(.headline, design: .serif)).frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            Text(String(format: "%02d / %02d", index + 1, count)).font(.footnote.monospacedDigit()).opacity(0.8)
                .accessibilityLabel("Page \(index + 1) of \(count)")
            Button(action: onDismiss) {
                Text("Done").font(.system(.subheadline, design: .serif).weight(.bold))
                    .padding(.horizontal, 14).frame(minHeight: 34)
                    .background(Theme.Wood.header, in: Capsule())
                    .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).keyboardShortcut(.cancelAction)
        }
        .foregroundStyle(.ivory)
        .padding(.horizontal, 22).padding(.vertical, 2)
        .background {
            LinearGradient(colors: [ClothColours.burgundy.cloth, ClothColours.burgundy.deep], startPoint: .top, endPoint: .bottom)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                .ignoresSafeArea(edges: .top)
        }
    }

    /// Previous on the left; on the right the name of the page to come, which is the way on.
    private var foot: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.Paper.ink.opacity(0.15)).frame(height: 1).accessibilityHidden(true)
            HStack {
                if index == 0 {
                    Button("House rules") { showRules = true }.font(.subheadline).opacity(0.7)
                        .accessibilityHint("The rules as the family wrote them, with a search")
                } else {
                    Button { turn(index - 1) } label: { Text("‹  Previous") }.font(.subheadline).opacity(0.7)
                }
                Spacer()
                Button { turn(index == count - 1 ? 0 : index + 1) } label: {
                    Text("\(index == count - 1 ? "Chapters" : Rulebook.pages[index + 1].title)  ›").font(.headline)
                }
                .keyboardShortcut(.defaultAction)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 52)
        }
        .padding(.horizontal, 22)
        .background(Self.paper)
    }
}

/// One page of the book.
private struct RulebookPageView: View {
    let page: Rulebook.Page
    let open: (Int) -> Void
    let openRules: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(page.chapter.map { "\($0.numeral)  /  \($0.title.uppercased())" } ?? "A FAMILY GAME OF PITCH")
                .font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(RulebookView.red)
            Text(page.title).font(.system(size: 40, weight: .heavy, design: .serif)).minimumScaleFactor(0.7).lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Text(page.lede).font(.system(.body, design: .serif)).fixedSize(horizontal: false, vertical: true)
            if let picture = page.picture.flatMap(SeatArt.named) {
                picture.resizable().scaledToFit().frame(maxWidth: .infinity).accessibilityHidden(true)
            }
            ForEach(Array(page.blocks.enumerated()), id: \.offset) { _, block in view(block) }
        }
        .id(page.id)
        .transition(.opacity)
    }

    private var hairline: some View {
        Rectangle().fill(Theme.Paper.ink.opacity(0.15)).frame(height: 1).accessibilityHidden(true)
    }

    @ViewBuilder private func view(_ block: Rulebook.Block) -> some View {
        switch block {
        case let .heading(words):
            Text(words).font(.system(.title2, design: .serif).weight(.bold)).padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
        case let .text(words):
            Text(words).font(.callout).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        case let .label(words):
            Text(words.uppercased()).font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(RulebookView.red).padding(.top, 6)
        case .rule:
            hairline.padding(.vertical, 6)
        case let .note(words):
            Text(words).font(.system(.callout, design: .serif).italic()).opacity(0.75).fixedSize(horizontal: false, vertical: true)
        case let .big(words, red):
            Text(words).font(.system(.title, design: .serif).weight(.bold)).foregroundStyle(red ? RulebookView.red : Theme.Paper.ink)
                .lineLimit(1).minimumScaleFactor(0.5)
        case let .cards(cards, marked):
            HStack(spacing: 8) { ForEach(cards, id: \.self) { BookCard(card: $0, marked: marked.contains($0)) } }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Six cards; the marked ones are " + marked.map(\.name).joined(separator: " and "))
        case let .trick(label, plays, winner, caption):
            VStack(alignment: .leading, spacing: 8) {
                Text(label.uppercased()).font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(RulebookView.red)
                HStack(alignment: .top, spacing: 10) {
                    ForEach(plays, id: \.seat) { play in
                        VStack(spacing: 6) {
                            BookCard(card: play.card, marked: play.seat == winner)
                            Text(Rulebook.names[play.seat]).font(.caption).opacity(0.7)
                        }
                    }
                }
                Text(caption).font(.system(.callout, design: .serif))
            }
            .padding(.top, 6)
            .accessibilityElement(children: .combine)
        case .points:
            VStack(spacing: 0) {
                ForEach(RulesFigures.pointTiles, id: \.name) { tile in
                    hairline
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(tile.name); Spacer(); Text(tile.points, format: .number)
                        }
                        .font(.system(.title2, design: .serif).weight(.bold))
                        .foregroundStyle(tile.points == 5 ? RulebookView.red : Theme.Paper.ink)
                        Text(Rulebook.how(tile.name) ?? tile.meaning).font(.footnote).opacity(0.7).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                }
                hairline
            }
        case .gameValues:
            HStack(spacing: 8) {
                ForEach(RulesFigures.gameValues, id: \.rank) { entry in
                    VStack(spacing: 6) {
                        Text(entry.rank.label).font(.system(.title2, design: .serif).weight(.bold))
                        Text("\(entry.value) pt\(entry.value == 1 ? "" : "s")").font(.caption).opacity(0.7)
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(BookCard.face, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(BookCard.edge, lineWidth: 1))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(RulesFigures.gameValues.map { "\($0.rank.label) counts \($0.value)" }.joined(separator: ", "))
        case .call: BookCall()
        case .hand: BookHand()
        case .contents:
            VStack(spacing: 0) {
                ForEach(RulesView.Chapter.allCases) { chapter in
                    hairline
                    Button { open(Rulebook.firstPage(of: chapter)) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(chapter.numeral).font(.system(.subheadline, design: .serif).weight(.bold))
                                .foregroundStyle(RulebookView.red).frame(width: 44, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chapter == .nineAndOut ? "Nine and out" : chapter.short)
                                    .font(.system(.title2, design: .serif).weight(.bold))
                                Text(Rulebook.about(chapter)).font(.footnote).opacity(0.7)
                            }
                            Spacer(minLength: 8)
                            Text("›").font(.title3).foregroundStyle(RulebookView.red)
                        }
                        .padding(.vertical, 8).frame(minHeight: 56).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Chapter \(chapter.rawValue + 1), \(chapter.title). \(Rulebook.about(chapter))")
                }
                hairline
            }
            .padding(.top, 10)
        case .signOff:
            VStack(alignment: .leading, spacing: 14) {
                Text("“\(RulesText.signOff)”").font(.system(.callout, design: .serif).italic())
                    .fixedSize(horizontal: false, vertical: true)
                Link(RulesText.contactEmail, destination: RulesText.contactURL).font(.callout)
                    .foregroundStyle(RulebookView.red).accessibilityHint("Opens a new email")
            }
            .id("signoff")
        }
    }
}

/// A card as the book prints it: flat, its rank in the corner and its suit large; a marked one is outlined in red
/// and underlined.
struct BookCard: View {
    let card: Card
    var marked = false
    var dimmed = false

    static let face = Color(red: 1, green: 0.985, blue: 0.95)
    static let edge = Color(red: 0.78, green: 0.72, blue: 0.62)

    var body: some View {
        let red = card.suit == .hearts || card.suit == .diamonds
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        VStack(spacing: 5) {
            VStack(spacing: -2) {
                Text(card.rank.label).font(.system(.headline, design: .serif).weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
                Text(card.suit.glyph).font(.system(size: 30))
            }
            .foregroundStyle(red ? RulebookView.red : Theme.Paper.ink)
            .lineLimit(1).minimumScaleFactor(0.5)
            .padding(.top, 6).padding(.bottom, 10)
            .frame(maxWidth: 96)
            .background(Self.face, in: shape)
            .overlay(shape.stroke(marked ? RulebookView.red : Self.edge, lineWidth: marked ? 2 : 1))
            .opacity(dimmed ? 0.45 : 1)
            Rectangle().fill(marked ? RulebookView.red : .clear).frame(height: 2).padding(.horizontal, 4)
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.name)
    }
}

/// "What's your call?": the dealer's choices as outlined buttons, each judged by the engine.
private struct BookCall: View {
    @State private var trial = RuleTrial.make(.dealerMatch)
    @State private var chosen: PlayerAction?
    @State private var words: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Array(trial.offeredActions.enumerated()), id: \.offset) { _, action in
                    let picked = chosen == action
                    VStack(spacing: 5) {
                        Button { call(action) } label: {
                            Text(label(action)).font(.system(.body, design: .serif)).lineLimit(1).minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(BookCard.face, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(picked ? RulebookView.red : BookCard.edge, lineWidth: picked ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(picked ? .isSelected : [])
                        Rectangle().fill(picked ? RulebookView.red : .clear).frame(height: 2).padding(.horizontal, 4)
                    }
                }
            }
            Text(words ?? "Try any of them. The game itself will answer.")
                .font(.callout).opacity(words == nil ? 0.6 : 1).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Each call is tried from the same position, so every button can be pressed in turn.
    private func call(_ action: PlayerAction) {
        trial.reset()
        chosen = action
        switch trial.attempt(action) {
        case let .refused(reason): words = reason
        case .accepted: words = Rulebook.verdict(forCall: action)
        }
    }

    private func label(_ action: PlayerAction) -> String {
        if case let .bid(amount?) = action { return "Bid \(amount)" }
        return "Pass"
    }
}

/// "Which card can you play?": your hand with a heart led; the engine allows a card or says why not.
private struct BookHand: View {
    @State private var trial = RuleTrial.make(.followSuit)
    private let cards = RuleTrial.make(.followSuit).offeredCards
    @State private var tried: Card?
    @State private var legal = false
    @State private var words: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 6) {
                ForEach(cards, id: \.self) { card in
                    Button { play(card) } label: {
                        BookCard(card: card, marked: tried == card && legal, dimmed: tried == card && !legal)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Try playing this card")
                }
            }
            Text(words ?? "Tap a card to try it.").font(.system(.title3, design: .serif).weight(.bold))
                .opacity(words == nil ? 0.55 : 1).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func play(_ card: Card) {
        trial.reset()
        tried = card
        switch trial.attempt(.play(card)) {
        case let .refused(reason): legal = false; words = reason
        case .accepted: legal = true; words = "Yes. Play either heart."
        }
    }
}
