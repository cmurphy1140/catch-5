import CatchFive
import SwiftUI

/// Owns the one `GameModel`. A new player sees login, then the tutorial as an intro they may skip, then the
/// table. A returning player with a match in progress lands back on the table, curtain down in pass and play;
/// with no match, or a finished one, they land on the main menu, Back to the table or New game one tap away
/// (override of spec R31/R32 and this comment, decision D64). Going from the menu to the table shows the tip
/// card first (D67); a launch that resumes onto the table does not. The table's menu opens a pause card whose Main
/// menu comes back here with the match preserved (spec R31, R32).
public struct RootView: View {
    enum Screen { case login, intro, menu, table }

    @StateObject private var model: GameModel
    @StateObject private var tutorial: TutorialModel
    @State private var screen: Screen
    /// The pause card over the table, opened from the table's menu.
    @State private var showWelcome = false
    /// The tip card over the table, on the way in from the main menu (D67).
    @State private var showTips = false
    /// The `home-tips` stage keeps the tip card up for its screenshot.
    private let holdTips: Bool
    /// The menu opens with the Solo or Pass and play question up (the `picker` launch stage).
    private let choosingMode: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    /// `stage` opens a named state directly, for headless screenshots: `picker` (the New match question),
    /// `curtain` (a fresh pass-and-play match waiting for its first player) or `seat` (that player's table);
    /// `pass-table` (pass and play mid-hand, a player other than the first holding the phone);
    /// solo `draw` (the draw for dealer), `bidding` (your bid, a bid and a pass already in the boxes), `trump` (your trump choice), `table` (your play,
    /// cards on the pile), `dealer-bidder` (the same, a side seat having dealt and won the bid), `pause` (the
    /// pause card over it), `result` (the second hand's result), `review` (with Review hand open) or `over` (the match
    /// won); `stats`, `settings` or `howto` (the menu with that sheet open); `table-rules` (the `table` state with the rules opened
    /// from its book), `table-rules-fold` (the same, held halfway through the book-opening fold); `home` (the menu with a match in
    /// progress) or `home-tips` (the tip card over the table, held), `home-whywe` (the same, turning to why we play); `ninewin`, `ninelose` (a 9 and out made or missed,
    /// its screen up), `won` (a solo match won, the cascade falling) or `confirm9` (your bid, the partner asking about 9 and out); `rules`
    /// (How to play with the full rules sheet open over it), `rules-1` … `rules-6` (the same, opened at that chapter), `signoff` (the same, scrolled to the family's note); `dealer-forced`
    /// (everyone passed and you deal, so you must bid); `bold` (a computer team down 10 or more, its note held on the table); `five` (your team has just taken the five
    /// of trump, the big faces up, your lead), `handline` (a hand's result with a seat's line on it), `panel` (three hands
    /// in, your team's score panel open) or `demo` (the `table` state with the one-time tally demo's first caption held).
    public init(model: GameModel, stage: String? = nil) {
        ScreenshotStage.name = stage
        var model = model
        switch stage {
        case "curtain", "seat":
            model.newGame(mode: .passAndPlay)
            model.dismissDealerDraw()
            if stage == "seat" { model.ready() }
        case "pass-table":
            model.newGame(mode: .passAndPlay)
            model.dismissDealerDraw()
            Self.passAndPlay(model) { hand in hand.phase == .playing && !hand.currentTrick.isEmpty && hand.nextSeat != 0 }
        case "draw":
            model.newGame(mode: .solo)
        case "bidding", "table", "table-rules", "table-rules-fold", "demo", "pause", "result", "review", "home", "home-tips", "home-whywe", "confirm9":
            // The `bidding` stage deals until a bid and a pass are both in the seats' boxes before your turn (N55).
            for _ in 0..<200 {
                model.newGame(mode: .solo)
                model.dismissDealerDraw()
                Self.play(model) { hand, humanTurn in
                    switch stage {
                    case "bidding", "home", "home-tips", "home-whywe", "confirm9": humanTurn && hand.phase == .bidding
                    case "table", "table-rules", "table-rules-fold", "demo", "pause": humanTurn && hand.phase == .playing && !hand.currentTrick.isEmpty
                    default: hand.phase == .finished
                    }
                }
                let calls = model.match.hand.auction.calls
                if stage != "bidding" || calls.contains(where: { $0.bid == nil }) && calls.contains(where: { $0.bid != nil }) { break }
            }
            // The `result` stage plays a second hand, so the scorecard shows a new total under a struck one (N66).
            if stage == "result", model.match.winner == nil {
                model.nextHand()
                Self.play(model) { hand, _ in hand.phase == .finished }
            }
        case "trump", "dealer-bidder":
            // Deal until the hand reaches the wanted auction: you naming trump, or a side seat that dealt and won the bid.
            for _ in 0..<200 {
                model.newGame(mode: .solo)
                model.dismissDealerDraw()
                Self.play(model) { hand, humanTurn in hand.phase != .bidding || (stage == "trump" && humanTurn && hand.phase == .choosingTrump) }
                let auction = model.match.hand.auction
                if stage == "trump" ? model.isHumanTurn && model.match.hand.phase == .choosingTrump
                    : auction.winner == auction.dealer && auction.dealer != 0 { break }
            }
            if stage == "dealer-bidder" {
                Self.play(model) { hand, humanTurn in humanTurn && hand.phase == .playing && !hand.currentTrick.isEmpty }
            }
        case "ninewin", "ninelose":
            // A 9 and out bid from the first seat, on a deck that makes it or one that does not; nothing is saved.
            let deck = stage == "ninewin" ? Self.nineAndOutDeck() : Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
            model = GameModel(match: try! Match(deck: deck, dealer: 3), settings: model.settings)
            model.send(.nineAndOut)
            Self.play(model) { hand, _ in hand.phase == .finished }
        case "won":
            for _ in 0..<20 where model.match.winner != 0 {
                model.newGame(mode: .solo)
                model.dismissDealerDraw()
                for _ in 0..<60 where model.match.winner == nil {
                    Self.play(model) { hand, _ in hand.phase == .finished }
                    if model.match.winner == nil { model.nextHand() }
                }
            }
        case "bold":
            // Play whole matches until a computer team down 10 calls in the auction and the table says so.
            for _ in 0..<40 where model.boldNote == nil {
                model.newGame(mode: .solo)
                model.dismissDealerDraw()
                for _ in 0..<60 where model.match.winner == nil && model.boldNote == nil {
                    Self.play(model) { hand, _ in model.boldNote != nil || hand.phase == .finished }
                    if model.boldNote == nil, model.match.winner == nil { model.nextHand() }
                }
            }
        case "dealer-forced":
            // You deal and the other three pass, so you must bid: the auction's tallest state, with its longest note (D97).
            // The computers rarely all pass, so the passes are made directly; nothing is saved.
            var match = try! Match(deck: GameModel.deck(), dealer: 0)
            for seat in 1...3 { try! match.bid(seat: seat, amount: nil) }
            model = GameModel(match: match, settings: model.settings)
        case "five":
            // Deal until your team takes the five of trump and it is your lead, so the big faces hold on the table.
            for _ in 0..<80 {
                model.newGame(mode: .solo)
                model.dismissDealerDraw()
                Self.play(model) { hand, humanTurn in humanTurn && hand.phase == .playing && SeatMood.isBigMoment(for: 0, in: model.match) }
                if model.isHumanTurn, model.match.hand.phase == .playing, SeatMood.isBigMoment(for: 0, in: model.match) { break }
            }
        case "handline":
            // Play solo hands until one ends with a seat's line on the hand-end card.
            for _ in 0..<40 {
                model.newGame(mode: .solo)
                model.dismissDealerDraw()
                Self.play(model) { hand, _ in hand.phase == .finished }
                if model.handEndLine != nil { break }
            }
        case "panel":
            // Three hands scored, then your turn in the fourth, with your team's score panel open (N62).
            model.newGame(mode: .solo)
            model.dismissDealerDraw()
            for _ in 0..<3 where model.match.winner == nil {
                Self.play(model) { hand, _ in hand.phase == .finished }
                if model.match.winner == nil { model.nextHand() }
            }
            Self.play(model) { hand, humanTurn in humanTurn && hand.phase == .playing }
        case "over":
            model.newGame(mode: .solo)
            model.dismissDealerDraw()
            for _ in 0..<60 where model.match.winner == nil {
                Self.play(model) { hand, _ in hand.phase == .finished }
                if model.match.winner == nil { model.nextHand() }
            }
        default: break
        }
        if stage == "home-whywe" { model.settings.nextTip = TipDeck.tips.count }
        if stage == "demo" { model.settings.hasSeenTallyDemo = false }
        _model = StateObject(wrappedValue: model)
        _tutorial = StateObject(wrappedValue: model.makeTutorial())
        let screen: Screen = switch stage {
        case "picker", "stats", "settings", "howto", "rules", "rules-1", "rules-2", "rules-3", "rules-4", "rules-5", "rules-6", "signoff", "home": .menu
        case "curtain", "seat", "pass-table", "draw", "bidding", "dealer-forced", "trump", "table", "table-rules", "table-rules-fold", "dealer-bidder", "pause", "result", "review", "over",
             "home-tips", "home-whywe", "ninewin", "ninelose", "won", "confirm9", "bold", "five", "handline", "panel", "demo": .table
        default: Self.initialScreen(for: model.settings, matchInProgress: model.matchInProgress)
        }
        _screen = State(initialValue: screen)
        _showWelcome = State(initialValue: stage == "pause")
        _showTips = State(initialValue: stage == "home-tips" || stage == "home-whywe")
        holdTips = stage == "home-tips" || stage == "home-whywe"
        choosingMode = stage == "picker"
    }

    /// A deck that deals you, with seat 3 dealing, the ace, king, queen, jack, five and two of hearts, and leaves
    /// every other heart undealt at the bottom of the stock: bid 9 and out, name hearts and lead them, and all
    /// nine points are yours. For the `ninewin` stage and its test.
    static func nineAndOutDeck() -> [Card] {
        let yours: [Card] = [.init(.hearts, .ace), .init(.hearts, .king), .init(.hearts, .queen),
                             .init(.hearts, .jack), .init(.hearts, .five), .init(.hearts, .two)]
        let otherHearts = Rank.allCases.map { Card(.hearts, $0) }.filter { !yours.contains($0) }
        var rest = Suit.allCases.filter { $0 != .hearts }.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
        var deck = Array(yours[0..<3])
        deck += rest.prefix(9); rest.removeFirst(9)
        deck += yours[3..<6]
        deck += rest + otherHearts
        return deck
    }

    /// Plays every seat of a pass-and-play match, each through its curtain, until `stop` holds; screenshots only.
    private static func passAndPlay(_ model: GameModel, until stop: (Hand) -> Bool) {
        for _ in 0..<200 where !stop(model.match.hand) && model.match.hand.phase != .finished {
            if model.curtainSeat != nil { model.ready() }
            guard let seat = model.viewerSeat, let view = try? PlayerView(match: model.match, seat: seat),
                  let action = ComputerPlayer.decide(view, difficulty: .standard) else { return }
            model.send(action)
        }
        if model.curtainSeat != nil { model.ready() }
    }

    /// Plays every seat with the computer strategy until `stop` holds, for the screenshot stages only.
    private static func play(_ model: GameModel, until stop: (Hand, Bool) -> Bool) {
        for _ in 0..<200 where !stop(model.match.hand, model.isHumanTurn) && model.match.hand.phase != .finished {
            if model.isHumanTurn, let view = try? PlayerView(match: model.match, seat: 0),
               let action = ComputerPlayer.decide(view, difficulty: .standard) {
                model.send(action)
            } else {
                model.stepComputer()
            }
        }
    }

    /// Login until a name is saved; the intro until it has been seen or skipped; then straight onto the table
    /// if a match is in progress, otherwise the main menu (decision D64). A match with no winner counts as in
    /// progress; a finished or absent match falls back to the menu, never a popup over the table (spec R32).
    nonisolated static func initialScreen(for settings: Settings, matchInProgress: Bool) -> Screen {
        if !settings.hasSignedIn { return .login }
        if !settings.hasSeenRules { return .intro }
        return matchInProgress ? .table : .menu
    }

    enum Destination: Equatable { case menu, intro, table }

    /// Where New match on the sign-in screen leads. An older install that already has a match in progress
    /// keeps it and gets the main menu, so nothing is thrown away without a choice.
    nonisolated static func destinationAfterSignIn(matchInProgress: Bool, hasSeenRules: Bool) -> Destination {
        if matchInProgress { return .menu }
        return hasSeenRules ? .table : .intro
    }

    public var body: some View {
        ZStack {
            LinearGradient(colors: [.felt, .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch screen {
            case .login:
                LoginView(model: model) { startFirstMatch() }.transition(.opacity)
            case .intro:
                IntroView(model: model, tutorial: tutorial) { model.markRulesSeen(); show(.table) }.transition(.opacity)
            case .menu:
                MainMenuView(model: model, tutorial: tutorial, onPlay: { showWelcome = false; showTips = true; show(.table) },
                             choosingMode: choosingMode)
                    .transition(.opacity)
            case .table:
                TableView(model: model, tutorial: tutorial, covered: showWelcome || showTips,
                          onLeave: { withAnimation(motion) { showWelcome = true } },
                          onHome: { showWelcome = false; show(.menu) })
                    .transition(.opacity)
                    // Under the card the table is neither tappable nor reachable by VoiceOver.
                    .accessibilityHidden(showWelcome || showTips)
                    .overlay {
                        if showTips {
                            TipCardView(model: model, holds: holdTips) { showTips = false }
                        }
                    }
                    .overlay {
                        if showWelcome {
                            ZStack {
                                Color.black.opacity(contrast == .increased ? 0.75 : 0.55).ignoresSafeArea()
                                WelcomeCard(model: model, onPlay: { withAnimation(motion) { showWelcome = false } },
                                            onMenu: { showWelcome = false; show(.menu) })
                            }
                            // The pause card drops down from the bar's Table box (N68).
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                            .accessibilityAddTraits(.isModal)
                        }
                    }
            }
        }
        .preferredColorScheme(.dark)
        // The table has its own notice alert; the sign-in and intro screens need one for restore notices.
        .alert("Game notice", isPresented: Binding(get: { screen != .table && model.errorMessage != nil },
                                                  set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var motion: Animation { reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay }

    /// After sign-in: a finished leftover match is replaced; one in progress is kept behind the welcome
    /// card; otherwise the intro, or the table if the rules were already seen.
    private func startFirstMatch() {
        if model.match.winner != nil { model.newGame() }
        switch Self.destinationAfterSignIn(matchInProgress: model.matchInProgress, hasSeenRules: model.settings.hasSeenRules) {
        case .menu: showWelcome = false; show(.menu)
        case .intro: showWelcome = false; show(.intro)
        case .table: showWelcome = false; show(.table)
        }
    }

    private func show(_ next: Screen) {
        withAnimation(motion) { screen = next }
    }
}

/// The launch stage for headless screenshots, if any; the screens that open a sheet or a section for it read it.
@MainActor enum ScreenshotStage {
    static var name: String?
}
