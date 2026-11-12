import CatchFive
@testable import CatchFiveUI
import Foundation
import Testing

@MainActor @Test func theTopRowHasHomeLeftAndRulesRightAndNothingThatPauses() {
    // D93: the Table / Clarify bar is gone; Home goes back to the menu (the game is already saved), Rules opens the rulebook.
    #expect(TableTopRow.home == TableTopRow.Button(title: "Home", symbol: "arrow.backward", showsTitle: false))
    #expect(TableTopRow.rules == TableTopRow.Button(title: "Rules", symbol: "book"))
    // No drop-down is left to hold play up.
    #expect(!TablePause().isPaused)
    // The pause card says the game keeps its place.
    #expect(WelcomeCard.keepsPlace == "You can leave the app and come back to this exact spot.")
}

@Test func tappingANameTagRenamesThatSeat() {
    // D93: seats 1 to 3 write their own name; seat 0 goes through the player's name; blank keeps the old one.
    var settings = Settings(playerName: "Connor")
    settings.seatNames[0] = "Connor"
    settings.renameSeat(2, to: "  Grandpa ")
    #expect(settings.seatNames == ["Connor", "Marcus", "Grandpa", "Monica"])
    settings.renameSeat(2, to: "   ")
    #expect(settings.seatNames[2] == "Grandpa")
    settings.renameSeat(0, to: "Mom")
    #expect(settings.playerName == "Mom")
    #expect(settings.seatNames[0] == "Mom")
    settings.renameSeat(0, to: "")
    #expect(settings.playerName == "Mom")
}

@Test func theBidBoxSaysTrumpBesideTheSuit() {
    // D93: the word, not just the glyph, so a new player knows what the suit is.
    #expect(ContractPlaque.trumpWord == "Trump")
}

@MainActor @Test func theRulesPicturesNeverShowTheBidderOpeningWithoutTrump() {
    // D93 after D91: the example tricks are a later lead, not the bidder's opening one.
    #expect(RulesFigures.followedTrick.first?.seat != RulesFigures.bidder)
    #expect(RulesFigures.trumpedTrick.first?.seat != RulesFigures.bidder)
    #expect(RulesFigures.setting.contains("later"))
    // Lesson 4a says West's king is a later lead, after the bidder opened.
    #expect(TutorialModel(completed: [], onCompletionChange: { _ in }).trickPrompt.hasPrefix("Later in the hand"))
}

@MainActor @Test func theBidBoxShowsTheFaceTheBidAndTrumpAndTheSuitKeepsTheTally() throws {
    // N63, N67: who bid (their face), the bid and trump in one box; the tally lives on the suit.
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    model.send(.bid(9))
    for _ in 0..<3 { model.stepComputer() }
    #expect(ContractPlaque.contract(in: model)?.trump == nil)
    model.send(.chooseTrump(.hearts))
    let bidder = try #require(model.match.hand.auction.winner)
    let contract = try #require(ContractPlaque.contract(in: model))
    #expect(contract.portrait == (Cast.opponent(at: bidder)?.portrait ?? model.settings.playerPortrait))
    #expect(contract.number == String(try #require(model.match.hand.auction.highestBid)))
    #expect(contract.trump == .hearts)
    let box = ContractPlaque.onTable(model, contract: contract, width: 120)
    box.onAdd()
    box.onAdd()
    #expect(model.trumpTally == 2)
    box.onTakeBack()
    #expect(model.trumpTally == 1)
    #expect(ContractPlaque.spoken(contract, tally: 1) == "\(model.seatNames[bidder]) bid 9, hearts are trump, 1 trump played")
    // The separate trump tile is gone: the suit is drawn in the box, in its own colour.
    #expect(ContractPlaque.glyphColor(.hearts) == .suitRed && ContractPlaque.glyphColor(.clubs) == .black)
}

/// Plays out the hand in progress: the first seat to speak bids 5, the rest pass, hearts are trump, then every
/// seat plays its first legal card.
private func playHand(_ match: inout Match) throws {
    while match.hand.phase == .bidding {
        let seat = try #require(match.hand.nextSeat)
        if (try? match.bid(seat: seat, amount: 5)) == nil { try match.bid(seat: seat, amount: nil) }
    }
    try match.chooseTrump(seat: try #require(match.hand.auction.winner), suit: .hearts)
    while match.hand.phase != .finished {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
}

@Test func theScorecardWritesEachNewTotalAndStrikesThePriorOne() throws {
    // N66: a notebook page, US and THEM; each hand's new total on the next line, the one before scratched out.
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var match = try Match(deck: deck, dealer: 3)
    #expect(Scorecard.lines(team: 0, history: match.history).isEmpty)
    #expect(Scorecard.columns == ["US", "THEM"])
    try playHand(&match)
    let first = match.scores
    for team in 0...1 {
        #expect(Scorecard.lines(team: team, history: match.history) == [.init(total: first[team], struck: false)])
    }
    try match.startNextHand(deck: deck)
    // Nothing moves while a hand is being played.
    #expect(Scorecard.lines(team: 0, history: match.history).count == 1)
    try playHand(&match)
    for team in 0...1 {
        #expect(Scorecard.lines(team: team, history: match.history)
            == [.init(total: first[team], struck: true), .init(total: match.scores[team], struck: false)])
    }
    #expect(Scorecard.handwriting == "Marker Felt")
    #expect(Scorecard.label(us: false, mode: .passAndPlay, teamNames: "Marcus + Monica") == "MARCUS + MONICA")
    #expect(Scorecard.label(us: true, mode: .solo, teamNames: "Cheryl + Meg") == "US")
}

@MainActor @Test func everySeatWearsANameTagWithItsName() throws {
    // N64, D93, D94: every seat's name carved into the wood under it, no sticker; the phone holder's too.
    let solo = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3))
    #expect(NameTag.names(solo) == solo.seatNames)
    // Pass and play turns the table with the phone, and the tags turn with it.
    let pass = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3))
    pass.newGame(mode: .passAndPlay)
    pass.dismissDealerDraw()
    pass.ready()
    let holder = try #require(pass.viewerSeat)
    #expect(NameTag.names(pass) == (0..<4).map { pass.seatNames[(holder + $0) % 4] })
}

@Test func onlyTheDealerIsMarkedAndNoSeatSaysBidder() {
    // N65, D94: a dealer button beside whoever deals; the bid box says who bid, so BIDDER goes.
    #expect(DealerMark.label == "DEALER")
    #expect(SeatView.marks(seat: 1, dealer: 1, bidder: 1) == ["DEALER"])
    #expect(SeatView.marks(seat: 2, dealer: 1, bidder: 2).isEmpty)
    #expect(SeatView.marks(seat: 3, dealer: 1, bidder: 2).isEmpty)
    for seat in 0..<4 {
        #expect(!SeatView.marks(seat: seat, dealer: 0, bidder: seat).contains("BIDDER"))
    }
    // Much larger than the 24 pt deck it replaces.
    #expect(Theme.Table.dealerMarkDeckWidth >= 1.25 * 24)
}

@Test func theNewCastReplacesTheFamilyAndTheFamilyStaysAChoice() throws {
    #expect(Settings().opponents == .friends && Settings().seatNames == ["Cheryl", "Marcus", "Meg", "Monica"])
    // A save from before the choice existed, still seating the family as dealt, takes the new three.
    let old = Data(#"{"playerName":"Emma","seatNames":["Emma","JC","Doug","Diane"]}"#.utf8)
    #expect(try JSONDecoder().decode(Settings.self, from: old).seatNames == ["Emma", "Marcus", "Meg", "Monica"])
    // A name typed by hand is a choice and stays.
    let typed = Data(#"{"playerName":"Emma","seatNames":["Emma","JC","Grandpa","Diane"]}"#.utf8)
    #expect(try JSONDecoder().decode(Settings.self, from: typed).seatNames == ["Emma", "JC", "Grandpa", "Diane"])
    // Choosing the family in Settings seats them, keeps the player's seat, and survives a save.
    var settings = try JSONDecoder().decode(Settings.self, from: old)
    settings.seat(.family)
    #expect(settings.seatNames == ["Emma", "JC", "Doug", "Diane"])
    let again = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
    #expect(again.opponents == .family && again.seatNames == ["Emma", "JC", "Doug", "Diane"])
}
