# Types and Functions

One line per public thing, grouped by file, with the test that proves it. Names are exact so you can `grep` for them.

## Class diagram

```mermaid
classDiagram
    class Card {
        +Suit suit
        +Rank rank
    }
    class Auction {
        +Int dealer
        +Int? nextSeat
        +Int? winner
        +Int? highestBid
        +Bool isNineAndOut
        +[AuctionCall] calls
        +act(seat, bid, nineAndOut)
    }
    class AuctionCall {
        +Int seat
        +Bid? bid
    }
    class Hand {
        +HandPhase phase
        +Auction auction
        +[[Card]] hands
        +[Card] stock
        +[Card] discarded
        +[Int] discardCounts
        +Suit? trump
        +Int? nextSeat
        +[Play] currentTrick
        +[CompletedTrick] completedTricks
        +[[Card]] captured
        +HandScore? result
        +bid(seat, amount, nineAndOut)
        +chooseTrump(seat, suit)
        +play(seat, card)
        +legalMoves(seat)
    }
    class Match {
        +Hand hand
        +[Int] scores
        +Int? winner
        +[HandSummary] history
        +Int handNumber
        +bid() bidNineAndOut() chooseTrump() play()
        +startNextHand(deck)
        +apply(PlayerAction, seat)
    }
    class PlayerView {
        +Int seat
        +[Card] cards
        +[Play] trick
        +[AuctionCall] calls
        +[CompletedTrick] completedTricks
        +[Int] scores
        +public facts…
    }
    class ComputerPlayer {
        +decide(PlayerView) PlayerAction?
        +estimate(cards, suit) Double
        +isTrailingBadly(PlayerView) Bool
    }
    class Knowledge {
        +Set~Card~ unseen
        +unbeatable(card, led) Bool
        +pointValue(card) Double
        +controlValue(card) Double
    }
    ComputerPlayer *-- Knowledge
    class MatchSave {
        +encode(Match) Data
        +decode(Data) Match
        +write(Match, to URL)
        +read(from URL) Match
    }
    class GameModel {
        +Match match
        +Int revision
        +String? errorMessage
        +send(PlayerAction)
        +stepComputer()
        +allows(PlayerAction) Bool
        +latestCall(for seat) String?
        +contract String?
        +persist()
    }
    Hand *-- Auction
    Auction *-- AuctionCall
    Match *-- Hand
    Match --> HandSummary
    Hand --> Card
    PlayerView ..> Match : built from
    ComputerPlayer ..> PlayerView
    MatchSave ..> Match
    GameModel *-- Match
    GameModel ..> ComputerPlayer
    GameModel ..> MatchSave
```

## Sources/CatchFive/Cards.swift

| Name | Kind | Purpose | Proven by |
|---|---|---|---|
| `Suit` | enum, `CaseIterable` | clubs, diamonds, hearts, spades | used everywhere |
| `Rank` | enum, `Int` raw values 2…14 | two … ace; `rawValue` orders cards | `highestTrumpWins` |
| `Rank.gameValue` | computed property | 10→10, J→1, Q→2, K→3, A→4, else 0 | `cardValuesForGame` |
| `Card` | struct, `Hashable`, `Codable` | one suit and one rank; `name` spells it out ("queen of hearts") for explanations | everywhere |
| `RuleError` | enum | invalidTrick, invalidSeat, outOfTurn, invalidBid, auctionComplete, invalidScoring, forbiddenNineAndOut | error assertions across suites |

## Sources/CatchFive/Tricks.swift

| Name | Purpose | Proven by |
|---|---|---|
| `Play` | one seat's card in a trick | trick tests |
| `legalCards(in:led:openingTrump:)` | if you hold the led suit you must play it; otherwise anything. On a lead with `openingTrump` set (the bidder's opening lead of the hand) only trumps are legal when any are held (D91); every other lead is free. `Hand.legalMoves` and both computer players pass it | `mustFollowSuitEvenWithTrump`, `openingLeadMustBeTrumpWhenTheLeaderHoldsOne` |
| `trickWinner(_:trump:)` | highest trump, else highest of led suit; rejects malformed tricks | `trumpBeatsLedAce`, `highestTrumpWins`, `malformedTricksAreRejected` |

## Sources/CatchFive/Bidding.swift

| Name | Purpose | Proven by |
|---|---|---|
| `Bid` | `.points(Int)` or `.nineAndOut` | settlement tests |
| `AuctionCall` | one seat's accepted call; `bid == nil` is a pass | `auctionRecordsEverySeatCallInOrder` |
| `Auction` | four-turn bidding round starting left of dealer | all `BiddingTests` |
| `Auction.act(seat:bid:nineAndOut:)` | validates turn, minimum raise, dealer match of ordinary bids, forced 2, 9-and-out precedence (nobody, the dealer included, may match a standing 9 and out, D103); records the call | `dealerCanMatchPartnerOrOpponent`, `nonDealerMustRaiseAndInvalidActionDoesNotConsumeTurn`, `dealerMustTakeTwoAfterPasses`, `bidRangeAndTurnOrder`, `nineAndOutOvercallsNineAndDealerCannotMatch` |

## Sources/CatchFive/Scoring.swift

| Name | Purpose | Proven by |
|---|---|---|
| `HouseRules` | the house numbers named once: `matchTarget` 25, `bidRange` 2...9, `handPoints` 9; `settle`, the auction, the bid grid and the rules sheet all quote them | `houseRuleNumbersAreTheOnesTheEngineEnforces` |
| `HandScore` | points per team plus which team took High, Low, Jack, Five, Game and the Game values | scoring tests |
| `scoreHand(captured:trump:bidder:)` | pure function from captured cards to `HandScore`; rejects duplicate cards | `relativeHighAndLowBelongToCapturingTeams`, `missingJackAndFiveDoNotScoreAndGameTieGoesToBidder`, `offSuitScoringCardsOnlyCountTowardGame`, `invalidCapturedCardsAreRejected` |
| `Settlement` | new scores and optional winner | |
| `settle(scores:points:bidder:bid:)` | bidder adds points or subtracts bid; defenders add; 25 wins; 9-and-out ends the match either way | `successfulBidScoresAllPointsAndSetLosesBidAmount`, `twentyFiveAndSimultaneousFinish`, `nineAndOutWinsOrLosesImmediately`, `invalidSettlementRejected` |

## Sources/CatchFive/Hand.swift

| Name | Purpose | Proven by |
|---|---|---|
| `HandPhase` | bidding, choosingTrump, playing, finished | phase guards in every test |
| `CompletedTrick` | four plays and the winning seat | `playMustFollowSuitAndWinningPlayerLeadsNext` |
| `HandError` | invalidDeck, wrongPhase, notBidWinner, cardNotHeld, mustFollowSuit, mustLeadTrump (a non-trump opening lead while holding trump, D91) | `bidderHoldingTrumpMustOpenWithTrump` |
| `Hand.init(deck:dealer:)` | requires 52 unique cards; deals two packets of three | `dealSixEachInTwoPacketsStartingLeftOfDealer`, `rejectInvalidDecks` |
| `Hand.bid` | forwards to `Auction`; moves to `choosingTrump` when the dealer has acted | `trumpSelectionRequiresFinishedAuctionAndWinningSeat` |
| `Hand.chooseTrump` | bid winner only; discards non-trumps, refills to six from stock, and records how many each seat threw | `refillKeepsTrumpsAndDiscardsOnlyInitialNonTrumps`, `everySeatsDiscardCountIsRecordedAndPublicWithoutRevealingTheCards` |
| `Hand.discardCounts` | how many cards each seat threw when trump was named, which every player says aloud at a real table; a seat that discarded n kept 6 − n trumps. Derived from the deal, so a replayed save recomputes it and no archive version changes | `everySeatsDiscardCountIsRecordedAndPublicWithoutRevealingTheCards`, `discardCountsComeBackFromAReplayedSaveWithoutAnArchiveChange` |
| `Hand.play` | full validation, copy-mutate-commit; fourth card resolves the trick, sixth trick scores | `illegalPlayLeavesStateUnchanged`, `completeHandsConserveCardsAndFinishAfterSixTricks` (208 hands) |
| `Hand.legalMoves(seat:)` | empty unless it is that seat's turn in `playing`; before any card of the hand is played, passes trump as `openingTrump` | UI greying relies on this through `allows`; `bidderWithoutTrumpMayOpenWithAnyCard`, `leadsAfterTheFirstTrickAreFree` |

## Sources/CatchFive/Match.swift

| Name | Purpose | Proven by |
|---|---|---|
| `MatchError` | handInProgress, matchFinished | `matchRejectsPrematureRedeal` |
| `HandSummary` | number, dealer, bidder, bid, isNineAndOut, result, running scores; `contractMade` says whether the bidders collected what they promised | `nextHandRotatesDealerAndRetainsScores`, `handSummaryKnowsWhetherTheContractWasMade` |
| `Match.init(deck:dealer:)` | starts hand 1 and remembers the deck for saves | |
| `Match.bid` / `bidNineAndOut` / `chooseTrump` / `play` | wrap `Hand`, refuse after a winner, append to the action log; `play` settles the hand exactly once | `matchScoresOnlyAfterLastCardAndOnlyOnce`, `failedBidMakesNegativeMatchScore`, `negativeTeamCannotDeclareNineAndOut` |
| `Match.startNextHand(deck:)` | only after `finished`; dealer + 1 | `nextHandRotatesDealerAndRetainsScores` |
| `Match.apply(_:seat:)` | one entry point for `PlayerAction` from humans and computers | `computersCompleteShuffledMatchesThroughRealRules` |
| `Match.actionCount`, `rewound(toActionCount:)`, `undoPoint(forSeat:)` | rebuild the match from the same deal with only the first n accepted actions; the action count to rewind to so a seat's latest action this hand is taken back (nil once scored or across a hand boundary). `MatchSave.decode` uses the same `replaying` helper | `rewoundMatchEqualsFreshReplay`, `undoDropsHumanActionAndComputerReplies`, `undoUnavailableAcrossHandBoundaryAndAfterScoring`, `undoAfterAResumeTakesBackOneHumanTurnAndTheMatchSavesAndReloadsIdentically` |

## Sources/CatchFive/ComputerPlayer.swift

| Name | Purpose | Proven by |
|---|---|---|
| `PlayerView` | own cards plus public facts, including every auction call, every completed trick and every seat's discard count; `init(match:seat:)` copies only what the seat may know — the counts cross the boundary, the discarded cards never do | `changingHiddenCardsDoesNotChangeComputerDecision`, `computerSeesPublicAuctionCalls`, `computerSeesCompletedTricksButNotHiddenHands` |
| `PlayerView.scores`, `Match.scoresBeforeHand` | the match score, team 0 then team 1, as it stood when the current hand was dealt; public at a real table, so it crosses the boundary (D6, D71). Once a hand is scored `Match.scores` already includes it, so `scoresBeforeHand` takes the one before from the history | `playerViewCarriesTheScoreTheHandWasDealtAt` |
| `PlayerView.init(match:replaying:inCompletedTrick:)` | rebuilds the view a seat had just before an earlier play, from public information and that seat's remaining cards | `replayedViewExplainsEveryComputerPlayExactly` |
| `PlayerAction` | nineAndOut, bid(Int?), chooseTrump(Suit), play(Card) | |
| `Advice` | an action plus its reasoning in plain words | `adviceNamesTheActionAndExplainsIt` |
| `ComputerPlayer.advise(_:)` | the single source of truth: the action this strategy takes from a seat and why; nil unless it is that seat's turn | `adviceExplainsCardPlay` (also checks it agrees with `decide` through a whole match) |
| `ComputerPlayer.decide(_:)` | `advise(_:)?.action` | `computerDoesNotActOutsideItsTurn` |
| `Difficulty`, `ComputerPlayer.decide(_:difficulty:)` | `easy` routes to `EasyPlayer`, `standard` to `decide(_:)`; hints and explanations always use standard | `easyDifficultyPlaysTheFrozenPlayerAndStandardTheCurrentOne` |
| `ComputerPlayer.facesNineAndOut(_:)` | true while a 9 and out stands in the auction; then both strategies answer only with a pass, never a plain 9 and never a match, since nobody, the dealer included, may match a 9 and out (D102, D103). Easy's pass is given in `decide(_:difficulty:)`, since `EasyPlayer` is frozen | `aComputerDealerAnswersANineAndOutWithALegalCall`, `aStandingNineAndOutIsOnlyEverPassed`, `easyPassesAStandingNineAndOut` |
| `EasyPlayer` (`Sources/CatchFive/EasyPlayer.swift`) | the "Easy" computer: a frozen copy of the PR #2 player, also the benchmark's fixed opponent, never to be improved | `computerPlayerBeatsFrozenBaseline` |
| `ComputerPlayer.estimate(_:suit:)` | expected hand points if that suit were trump | `estimateRanksControlAndTheFiveAboveScatteredCards` |
| bidding (private `bidAdvice`) | bid the minimum needed if it is at most the whole-point estimate; never outbid partner; dealer takes forced 2 | `computerPassesWeakHandButDealerTakesForcedTwo`, `computerRaisesWithStrongSuitAndChoosesIt`, `computerBiddingIsCompetitiveAndUsuallyMakesContract` |
| `ComputerPlayer.isTrailingBadly(_:)`, `deficit(_:)`, `boldDeficit` | true when the seat's team is `boldDeficit` (10) or more match points behind; `bidAdvice` then lets the most it will bid rise by one, never past 9 and never to a 9 and out, and says so in the advice. The table's note asks the same function (D71). Easy never sees it | `trailingBadlyStartsAtExactlyTenBehind`, `trailingBadlyRaisesTheBidCeilingByOne`, `trailingBadlyNeverBidsAboveNineOrNineAndOut`, `easyIgnoresTheMatchScore`, `boldWhenTrailingIsMeasuredAgainstTheSameStrategyWithoutIt` |
| `ComputerPlayer.Knowledge` | built from a `PlayerView`: the set of unseen cards (other hands or stock), `unbeatable(_:led:)` (no unseen card can beat it), `pointValue(_:)` (five 5, jack 1, certain High 1, certain Low 1, plus 0.06 per Game point) and `controlValue(_:)` (what holding a trump is worth for later tricks; 0.8 extra when unbeatable, 0 on the last trick) | `computerSpendsTheAceToCaptureTheFive`, `computerDumpsTheTrickWhenItIsWorthlessAndNoTrumpIsFree` |
| card play (private `chooseCard`) | scores every legal card: chance our side wins the trick × (points on the table + this card's stake) − chance we lose × this card's stake − control given up; picks the best, ties to least control then lowest rank | `computerFollowsSuitInsteadOfTrumping`, `computerUsesLowestWinningCardAgainstOpponentWhenNothingIsAtStake`, `computerFeedsFiveToPartnerWhenLastToPlay`, `computerPreservesFiveWhenItCannotWin` |
| leads (private `chooseLead`) | an unbeatable trump if held; the best side card when no trumps can be against us; otherwise the cheapest exit, never the five. On the bidder's opening lead only trumps are legal (D91) and the reason says the bidder opens with trump | `computerLeadsHighestTrumpButKeepsTheFiveBack`, `bothBotsOpenTheHandWithTrump` |

### Test-only strategy fixtures

| Name | Purpose |
|---|---|
| `playSeededMatch`, `mirroredBenchmark`, `BenchmarkResult` (`Tests/CatchFiveTests/StrategyBenchmark.swift`) | play seeded matches between two strategies, each seed twice with teams swapped; `computerPlayerBeatsFrozenBaseline` guards the shipped player's strength against `EasyPlayer` |

## Sources/CatchFive/HandReview.swift

| Name | Purpose | Proven by |
|---|---|---|
| `ReviewError` | `unexplainedPlay`, thrown only if the strategy had no advice for a legal play | |
| `PlayReview`, `TrickReview`, `HandReview(match:)` | every play of the finished hand's tricks next to the standard strategy's advice from the same rebuilt view (D24); `agreement(forSeat:)` counts matches | `reviewReconstructsEveryPlayWithAdvice` |
| `SeatPerformance`, `Match.performance(forSeat:)` | plays agreed and contracts made over the whole match, rebuilt by replaying to each hand boundary; nothing extra is saved | `performanceCountsHumanPlaysAndContractsAcrossHands` |

## Tests/CatchFiveTests/BotSins.swift

The sin hunt (D58): a sweep that finds the computer's bad decisions so each one can become a fixture.

| Type or function | What it does | Test |
|---|---|---|
| `BotSin`, `BotSin.Kind` | one bad decision, with the seed, hand and seat that produced it; the kinds are the ones Connor named at the table | `theDetectorNamesAnOvertakenPartnerAndASurrenderedCounterAndForgivesTheForced` |
| `leaderSoFar(_:trump:)` | who holds a part-played trick; `trickWinner` answers only once all four cards are down | `theDetectorNamesAnOvertakenPartnerAndASurrenderedCounterAndForgivesTheForced` |
| `trickSins(_:context:trump:seed:hand:)` | a counter surrendered, or a partner overtaken, judged only where the seat had a choice | `theDetectorNamesAnOvertakenPartnerAndASurrenderedCounterAndForgivesTheForced` |
| `huntBotSins(seeds:)` | plays seeded matches with the standard player in all four seats and reports every sin | `botSinsAcrossManySeededMatchesAreCountedAndReported` |

## Sources/CatchFive/MatchSave.swift

| Name | Purpose | Proven by |
|---|---|---|
| `SaveError` | invalidData, unsupportedVersion | `rejectsBrokenOrUnsupportedSave` |
| `SavedAction` (internal) | Codable mirror of the five actions, each replays through the real `Match` method | `replayRejectsIllegalActionsAndInvalidInitialDeck` |
| `MatchSave.encode` / `decode` | version 2 JSON: initial deck, dealer, actions. `decode` accepts versions 1 and 2 and replays both under the current rules, so a version 1 game that opened without trump is refused (D91) | `versionOneSaveThatOpensWithTrumpStillLoads`, `versionOneSaveThatOpensWithoutTrumpIsRefused`, `saveRestoresEveryPhaseAndContinuesIdentically`, `saveRestoresHistoryAndNextDealer`, `rejectedActionsNeverEnterSaveAndResavingDoesNotDuplicateActions`, `corruptSavesSurviveTheFailedReadSoTheyCanBeSetAside` |
| `MatchSave.write` / `read` | atomic file replacement; errors surface | `saveRoundTripOnDiskReplacesPreviousSave`, `diskFailuresAreReported`, `failedSaveKeepsThePreviousFileAndOneRetryWritesTheAcceptedMoveOnce` |

## Sources/CatchFiveUI/GameModel.swift

| Name | Purpose | Proven by |
|---|---|---|
| `GameModel` | `@MainActor ObservableObject` owning one `Match`, a `revision` counter, an optional `errorMessage`, and an optional save URL | |
| `PlayMode`, `mode`, `isHuman(_:)`, `viewerSeat`, `curtainSeat`, `ready()`, `bottomSeat`, `seat(at:)`, `place(of:)`, `teamNames(_:)`, `ourTeam`, `winnerHeadline(_:)` (on `GameModel`) | pass and play names players and teams where solo says "you" (score bar led by the phone holder's team, the menu line, the match's winner, the draw for dealer); solo (seat 0 against three computers) or pass and play (all four seats human, no computer moves); in pass and play only the seat that pressed Ready is shown, the curtain comes down whenever the turn passes to another seat, and the table turns so the phone holder sits at the bottom with the others in their true places (D62); the mode is saved beside the game in `game-mode.json` (missing means solo); undo and tap-to-explain are solo only | `passAndPlayNeverGeneratesAComputerMove`, `passAndPlayShowsOnlyTheSeatThatPressedReady`, `passAndPlayModeIsSavedWithTheGame`, `passAndPlayTurnsTheTableToThePhoneHolder`, `passAndPlayNamesTeamsInsteadOfYou` |
| `isHumanTurn`, `humanCards` | convenience for seat 0 | `humanActionAdvancesComputersAndStopsForHuman` |
| `send(_:)` | human action through `Match.apply`, then persist and bump revision | `acceptedHumanMoveSavesAndInvalidMoveShowsError` |
| `stepComputer()` | one computer action for whichever non-human seat is due | `humanActionAdvancesComputersAndStopsForHuman` |
| `allows(_:)` | dry run on a copy of the match | drives button enabling |
| `validationMessage(for:)`, `refuse(_:)`, `refusal`, `clearRefusal()` | the reason the engine would refuse an action right now, in the player's words ("Follow hearts; you still have hearts.", "Wait for Hazel."), or nil when it would accept; validated on a copy so the action count never moves; `refuse` records it for the table's message line and the next accepted action clears it, as does picking a card (`clearRefusal`, D97) | `validationMessagesExplainRefusalsWithoutChangingTheMatch` |
| `setPlayerName(_:)` (on `Settings`) | the one writer for the player's name: trimmed, mirrored into seat 0, blank input ignored; `signIn` and the Settings sheet both use it, and `signIn` writes settings once | `settingsToleratesValuesItDoesNotRecogniseAndMigratesOnlyPreCastFiles` |
| `renameSeat(_:to:)` (on `Settings`) | a name typed on a seat's tag at the table (D93): seat 0 through `setPlayerName`, seats 1 to 3 trimmed and written; blank input keeps the old name | `tappingANameTagRenamesThatSeat` |
| `resumeContext` | one line for the main menu's saved-match card while a match is in progress: hand number, both scores and the phase ("Hand 4 · Your team 6, their team 12 · trick 3"); nil when there is nothing to resume | `resumeContextDescribesTheSavedMatch` |
| `lastHandOutcome` | the finished hand as a `HandOutcome`, with the scores as they stood before it taken from the previous history entry | `lastHandOutcomeIsBuiltFromTheMatchHistory` |
| `HandEndLine`, `handEndLine` (on `GameModel`) | `HandEndLine.swift` (D73): one short line from one seat on the hand-end card, picked by `pick(bidder:made:fiveTeam:)` from the hand's public result through four lines in one table (your team set, partner: "We'll get it back."; the other team set, its bidder: "Ouch."; your team caught the five, partner: "Nice catch on the five."; your team made its bid, partner: "That's how it's done."); `handEndLine` is nil unless the hand is finished and the match is solo | `handEndWordsFollowThePublicResult`, `noWordsWhileAHandIsInPlayAndNoneInPassAndPlay` |
| `trumpPreview(for:)` | what naming a suit would do to your hand ("keep 4 · draw 2"), only while you are choosing trump; counts your own cards and never the stock's | `trumpPreviewCountsWhatEachSuitKeepsAndDraws` |
| `suitToFollow` | the suit you are obliged to follow right now: the suit led while it is your turn and you still hold it; nil when you lead, cannot follow, or it is not your turn | `statusSaysWhichSuitYouMustFollow` |
| `auctionContext` | the dealer's rights, only when it is the human's turn to bid as dealer: match the high bid, the forced 2 after three passes, or pass when a 9 and out stands, since the dealer may not match it (D103) | `dealerGetsBidContextAndNineAndOutStaysEngineChecked`, `aDealerFacingNineAndOutIsToldToPassAndCannotMatch` |
| `latestCall(for:)`, `contract`, `seatNames` | wording for the auction display | `modelDescribesAuctionCallsAndContract` |
| `settings`, `seatNames` | player preferences (play speed, seat names, haptics, difficulty, `beginnerMode`), saved to `settings.json` whenever they change; names flow into the contract, explanations, tiles and summary | `seatNamesFlowIntoContractAndExplanations`, `settingsRoundTripThroughDiskAndTolerateMissingKeys` |
| `humanCards` | the hand as shown: trumps first, highest to lowest, then the other suits in a fixed order | `humanCardsSortTrumpFirstThenBySuitAndRank` |
| `notice` | one-line note about something that happened without a tap, such as "You discarded 2 and drew 2."; cleared by the next action | `trumpChoiceReportsDiscards` |
| `message(for:)` | rule errors in a player's words ("You must follow suit…") | `illegalPlayExplainsFollowSuitInPlainWords` |
| `records`, `statistics`, `handReview()`, `finalPerformance` | finished matches from `history.json`, totals over them, the finished hand's review, and the human's record computed once when a match is recorded or restored finished | `finishedMatchIsRecordedExactlyOnce`, `corruptHistoryDoesNotBlockPlay` |
| `describe(_:)` | one sentence for a reviewed play, shared by tap-to-explain and the hand review, labelling Easy seats | `reviewRowsShareExplanationWordingAndLabelEasySeats` |
| `loadDefault(in:)` | loads game, settings and history from a directory; a game, settings or history file that cannot be decoded is set aside as `game-corrupt.json`, `settings-corrupt.json` or `history-corrupt.json` rather than overwritten, and the notice says exactly what happened (including when a file could not be moved and will be replaced); the notice is shown on whichever screen opens; a full match replays in well under 300 ms, so there is no loading state | `corruptHistoryIsSetAsideByLoadDefault`, `corruptGameIsSetAsideAndTheFreshGameSaysSo`, `restoringALongReplayIsFastEnoughToNeedNoLoadingState` |
| `spokenDescription(of:winner:)`, `accessibilityValue(for:)` | VoiceOver wording for a played card ("West played the ten of hearts and took the trick") and for a hand card (playable, not legal now, waiting for your turn) | `spokenDescriptionOfPlayNamesSeatAndCard`, `accessibilityValueReflectsLegality` |
| `matchInProgress` | true once the match has an action and no winner; the menu shows Continue | `matchInProgressIsFalseForFreshAndFinishedMatches` |
| `signIn(name:portrait:difficulty:)` | the login screen's one write: trimmed name into `playerName` and seat 0, plus face and difficulty | `signInTrimsNameAndSetsSeatZero` |
| `seatSummary(for:)` | the VoiceOver sentence for a seat tile: name, direction word, call or card count, dealer, to act | `seatSummaryIncludesSeatWord` |
| `canUndo`, `undo()` | take back the human's latest action this hand and every computer reply after it; saves and bumps `revision` | `undoneMatchSavesAndReloads` |
| `lastHumanAction`, `describe(_ action:)` | the human's latest accepted action and its toast wording ("9♣ played", "Bid 3", "Bid 9 and out"); cleared by undo and new hands; also the trigger for the play and selection haptics | `lastHumanActionDescribesThePlayAndClearsOnUndo` |
| `notice` | the discard-and-draw line after trump is named; it survives the computers' replies and clears when the human next acts, undoes, or a new hand starts | `noticeSurvivesComputerRepliesUntilTheHumanActs` |
| `boldNote`, `boldNote(for:)`, `clearBoldNote()`, `boldNoteText(team:deficit:names:solo:)` | the table's note when a Standard computer seat calls in the auction while its team is down 10 or more: "JC and Diane are down 12, bidding bolder." (in solo, "You and Connor are down 11; Connor is bidding bolder."). Set by `stepComputer()` once per hand, shown in the commentary line under the status, faded by `TableView` after `Theme.Motion.boldNoteSeconds` (3 s); decided by `ComputerPlayer.isTrailingBadly` (D71) | `aComputerTeamDownTenSaysItIsBiddingBolderOncePerHand`, `theBoldNoteNamesYouWhenYourPartnerIsTheComputerBiddingBolder` |
| `hint`, `showHint()` | the strategy's advice for seat 0 on request; cleared by the next accepted action | `hintMatchesTheComputerStrategyAndClearsAfterActing` |
| `explanation(for:inLastTrick:)`, `explain(_:inLastTrick:)`, `explanation` | why a card on the table or in the last trick was played; for the human's own card it compares with what the strategy preferred | `explanationsNameTheSeatAndCompareTheHumanToTheStrategy` |
| `nextHand()`, `newGame()`, `dealerDraw`, `dismissDealerDraw()`, `freshMatch()` | fresh shuffled deck via `deck()`; a new game and a fresh install both draw for dealer first and keep the draw until the first action | `newGameDrawsForDealerAndTheMatchUsesIt` |
| `persist()`, `retrySave()`, `saveError`, `loadDefault()` | Application Support/CatchFive/game.json, settings.json and history.json; a failed write lands in `saveError` (separate from the rule error in `errorMessage`) and the accepted move stands; `retrySave()` writes the same in-memory state again and never replays a move; `perform` returns whether the engine accepted the action so feedback does not depend on the save | `saveFailureKeepsTheAcceptedMoveAndRetryWritesTheSameState` |

## Sources/CatchFiveUI views

| Name | Purpose |
|---|---|
| `Settings`, `SettingsStore` | `Settings.swift`: Codable preferences (including `difficulty`, `hasSeenRules`, `playerName`, `playerPortrait`, `hasSignedIn`, `beginnerMode`, on by default and for files from before it existed, `nextTip`, the tip card's place, 0 when missing, and `hasSeenTallyDemo`, false when missing, D84) with defaults for missing or unrecognised values (a newer build's enum case never signs the player out), a migration of the old West/Partner/East defaults to the cast's names only for files from before sign-in existed, and `delay(leadingTrick:)` for the computer pause per play speed; the store reads and writes JSON atomically | `delayDependsOnPlaySpeedAndLeadPosition`, `settingsRoundTripThroughDiskAndTolerateMissingKeys`, `settingsRoundTripKeepsPlayerNameAndPortrait`, `settingsWithoutPlayerFieldsLoadsSignedOut`, `oldSettingsFileMigratesDefaultSeatNamesToCast`, `beginnerModeIsOnByDefaultAndForOlderSettingsFiles` |
| `Portrait`, `Character`, `Cast` | `Cast.swift`: a face recipe (skin, hair, hair colour, feature, hat, shirt), a named player, and the fixed trio Hazel (West), Otto (Partner), Rue (East) plus four faces for the human, all dressed as scholars (D92: `spectacles`, `mortarboard`, and the `tweed`, `oxford` and `burgundy` shirts); `Cast.seatWords` keeps the direction words for accessibility | `castHasThreeDistinctNamesAndPortraits`, `castDressesAsScholarsAndOldFacesStillDecode` |
| `PortraitView` | `PortraitView.swift`: draws a `Portrait` at any size from shapes, colours from `Theme.Portrait`, with eyes, brows and a mouth that follow an `expression` (animated unless Reduce Motion); no gold inside a face. The scholars' shirts show at the neck (`neckline`: an ivory V for tweed and burgundy, collar points for oxford), above where a name sticker sits. `popsOut` (the table's seats, D77) draws the character `Theme.Portrait.popScale` larger and `popRise` higher, the body clipped to the disc and the head rising over its top edge; `headOnly` draws just that head so a seat can lay it over its rings; `popOverflow(top:)`, `headTop`, `tallestTop` say how far it rises | `tableFacesAreAFifthSmallerAndTheirHeadsPopOutOfTheirDiscs`; otherwise manual |
| `LoginView` | first launch, headed "Set up your player" (a local profile, not an account): name, face, Easy/Standard, one gold New match button and nothing else to tap; calls `signIn` | manual |
| `IntroView` | the new player's one page after login: how a hand goes in five steps (deal, bid, trump, tricks, score), Learn the game opens the tutorial full screen, New game goes to the table | manual |
| `WelcomeCard` | the pause card, dropping down over the dimmed table from the Table box's Pause (D86), with one big line that the game keeps its place (`keepsPlace`): Paused, then exactly three actions (spec R32): Continue game in gold (until the match is won), New match (an alert with Cancel if it would throw away bids or plays) and Main menu, which keeps the match and returns to `MainMenuView`; no greeting or summary, those live on the main menu; `MenuButtons` holds the two button styles it shares with the menu | manual |
| `MainMenuView`, `MainMenuView.homeButtons(matchInProgress:)` | the main menu (spec R31): the title, the tilted five of hearts that sways and turns to its back about every 9 s (still under Reduce Motion), with two drawn hands (`ReachingHand`, D78) reaching for it from above and below and drifting in with the sway, a card with the player's portrait, name, difficulty and `resumeContext`, the Beginner mode toggle bound to `Settings.beginnerMode`, then Back to the table (prominent) and New game while a match is in progress, else New game alone, prominent (D67, D93; New game asks Solo or Pass and play and confirms if it would replace a match), and How to play; a bare hamburger at the top right (accessible label Menu, 44 pt hit area) drops down Settings, Statistics and How Catch 5 is built, in that order (spec R29) | `homeOffersBackToTheTableOnlyWithAMatchInProgress` |
| `RootView` | the app's root: owns the model and the tutorial model (shared with the table so intro lessons count), opens on login, on the intro for a signed-in player who never saw it, or on the main menu, never a popup over the table (`initialScreen(for:)`, spec R32); after sign-in an older install's match in progress is kept and the main menu shows it (`destinationAfterSignIn`); Pause game on the table shows the pause card over the dimmed, accessibility-hidden table, and the card's Main menu returns to the menu with the match preserved; going from the menu to the table covers it with `TipCardView` until it deals, never on a launch that resumes onto the table (D67); shows restore notices off the table ( the covered table hidden from VoiceOver and the card marked modal, the dim layer darker under Increase Contrast), crossfades between login, intro and table; a `-stage` launch argument (recorded in `ScreenshotStage.name`) opens a named state for headless screenshots | `rootOpensOnLoginUntilSignedInThenOnTheTable` |
| `TutorialFixtures`, `TutorialBid`, `ScoreCategory` | `Tutorial/TutorialFixtures.swift`: the fixed cards and answer keys for the five lessons | `tricksExerciseLegalMovesMatchEngine`, `tricksExerciseWinnerMatchesEngine`, `scoringExerciseMatchesScoreHand`, `biddingExerciseLegalSetIsFourThroughNinePassAndNineAndOut` |
| `TutorialModel` | `Tutorial/TutorialModel.swift`: current lesson, completed set (handed back for persistence in `Settings.completedLessons`), each exercise's picks and feedback | `completingAllLessonsPersistsAcrossLaunch` |
| `TutorialView`, `SeatTile`, `DealLesson`, `BiddingLesson`, `TrumpLesson`, `TricksLesson`, `ScoringLesson` | the "How to play" sheet from the gear menu, and full screen from the intro (`isIntro`: Skip in the toolbar, New game on the last lesson; seat tiles carry the cast's portraits): header, chapter pills, one lesson at a time, Back / Next, a Full rules button that opens `RulesView` | manual |
| `trumpTally`, `tallyTrump()`, `untallyTrump()`, `trumpTallyCap`, `outOfTrump`, `toggleOutOfTrump(_:)` (on `GameModel`) | the player's own trump tally (0 to 13) and out-of-trump marks, kept by hand from the table's corner tile and the seat portraits once trump is named; view state only, never in the engine, `PlayerView` or the save, cleared by `nextHand()`, `newGame(mode:)` and an undo that takes back the trump call (D65) | `trumpTallyAddsCapsAtThirteenTakesBackToZeroAndResetsNextHand`, `outOfTrumpBadgeTogglesAndResetsNextHand` |
| `TallyDemo`, `tallyDemo`, `beginTallyDemoIfDue()`, `advanceTallyDemo()` (on `GameModel`), `DemoTap`, `TallyDemoCaption` | `TallyDemo.swift` (D84): the one-time show of the two taps the first time trump is named on an install: the suit in the bid box pulses under "Count trump as it falls", then the left opponent's face under "Mark who's out of trump"; `Settings.hasSeenTallyDemo` is saved as it starts; each step holds `TallyDemo.stepSeconds` or until the caption is tapped; play waits meanwhile; no tally mark or badge is made; Reduce Motion keeps the captions and drops the pulse | `theTallyDemoShowsOnceAndTheFlagPersists`, `theTallyDemoLeavesTheTallyAndBadgesAlone` |
| `TipDeck`, `TipDeck.Face`, `TipCardView`, `takeNextTip()` (on `GameModel`) | `TipCard.swift` (D67): the origin line and the eleven tips in order, `tip(_:)` labelling one "TIP n OF 11" and wrapping any index; `whyWePlay`, an unnumbered "WHY WE PLAY" face that closes each `cycle` of twelve after the eleventh tip, and `face(_:)` reading any index round that cycle (D74); the card over the table on the way in from the home screen, turning over every 3.2 s and dealing after its second face or at a tap, four card backs flying to the seats over 0.5 s (crossfades under Reduce Motion); `takeNextTip()` returns the face at `Settings.nextTip` and saves the next index | `tipCardOpensWithTheOriginThenElevenTipsInOrder`, `tipsContinueFromTheLastVisitAcrossLaunchesAndWrap`, `whyWePlayClosesEachCycleAfterTheEleventhTip` |
| `makeTutorial()` (on `GameModel`) | a `TutorialModel` wired to the settings | |
| `RulesText` | the house rules as sections of verbatim paragraphs from `docs/catch-five-rules.md` (including how the first dealer is drawn), plus "Reading the table" notes about the screen, and `origin`, the line about where the game comes from that opens the rules sheet and the tip card (D66); `signOff`, the family's note that closes the sheet, with `contactEmail` and `contactURL`, a mailto link with the subject "Catch 5" (D72) | `rulesSheetContainsEveryHouseRuleParagraph` (reads the doc and fails on any drift), `rulesSheetOpensWithWhereTheGameComesFrom`, `rulesSheetEndsWithTheFamilysNoteAndAMailLink` |
| `RulesView` | the rules sheet as a guided walk on the felt, opening with `RulesText.origin` in italic serif above the first chapter (D66): six chapters (The table, Deal and bidding, Play, Scoring, 9 and out, Reading the table) in inlay panels with gold numerals, a chapter rail of 44 pt chips that scrolls to a chapter and lights the one chosen or at the top, chapters matched to `RulesText` sections by title, and a figure per chapter built from the table's pieces (four portraits round an oval with "first to 25", six card backs and the bid ladder, a four-card trick with a Following suit / Trumped toggle and the winner ringed, five tappable point tiles with the Game ledger, a nine-segment gold meter, the screen notes with icons); the verbatim rule text stays visible under every figure, and Deal and bidding, Play and 9 and out each end with a `RuleTrialView`; after the last chapter, `RulesText.signOff` in italic serif and the address as an underlined ivory link that opens a new mail (D72); reached from the tutorial's Full rules button | manual |
| `RuleTrial`, `RuleTrialView` | `RuleTrial.swift`, `RuleTrialView.swift`: "Try it" under three rules. Each trial is a small real position built through the engine with a crafted deck (hearts led and you must follow; you are dealer facing a bid of 3; a failed 9 left you at −9), the choices on offer, and `attempt(_:)`, which lets the engine judge the action on a copy: a refusal in the table's own words, an acceptance played out with the standard strategy and described ("You take the trick with the king of hearts"). Reset restores the position. The panel shows the position, the tappable cards or bid pills, and the verdict; a trial is its own `Match`, so the live game, its save and its scores are untouched | `ruleTrialsAreJudgedByTheEngine`, `ruleTrialsLeaveTheOngoingMatchAndItsSaveAlone` |
| `RulesFigures` | `RulesFigures.swift`: the numbers the rules sheet draws (point tiles and their meanings, the Game ledger from `Rank.gameValue`, the bid ladder and match target from `HouseRules`, two example tricks judged by `trickWinner`, set later in the hand so the bidder (`bidder`) has already opened with trump, said by `setting`, D93) and `caption(trumped:)`, built from the drawn cards | `rulesFiguresMatchTheEngine`, `theRulesPicturesNeverShowTheBidderOpeningWithoutTrump`, `rulesChaptersMatchTheRuleSectionsByTitle` |
| `needsRulesIntroduction`, `markRulesSeen()` (on `GameModel`) | first-run flag backed by `Settings.hasSeenRules` | `firstLaunchShowsRulesOnce` |
| `MatchRecord`, `Statistics`, `MatchHistoryStore` | `MatchHistory.swift`: one finished solo match (pass and play is never recorded, D63; id, date to the second, scores, hands, difficulty in effect at the finish, human contracts and agreement) decoded with defaults for fields added later; totals; JSON store with ISO 8601 dates and `readSettingAsideCorruption(at:)` | `statisticsAggregateAcrossRecords`, `matchRecordDecodesOlderFilesAndRejectsBadScores`, `passAndPlayMatchesStayOutOfStatistics` |
| `ReviewView`, `StatisticsView` | `ReviewView.swift`: the finished hand play by play with disagreements marked by a branch icon and a note that Standard's choice is advice, not proof another play was wrong; totals and recent matches (chart button) | manual |
| `MarkdownDocument` | `MarkdownDocument.swift`: the docs' Markdown parsed into blocks the reader draws natively (headings, paragraphs, bullet and numbered lists, pipe tables, fenced code, Mermaid fences as numbered diagrams), with the title, the section list and the diagram count; `Block.words` counts a block's words for reading time and page size (D101) | `markdownParserCoversEveryConstructTheDocsUse`, `everyChapterParsesAndItsDiagramsAreCounted` |
| `ExplainerLibrary`, `ExplainerLibrary.Page`, `ExplainerLibrary.Card`, `ExplainerView`, `DocumentReaderView`, `PageReaderView`, `BlockView`, `DiagramView`, `MarkdownText` | `ExplainerView.swift`: "How Catch 5 is built", read from the docs themselves. The library takes the chapters and the Swift vocabulary from `learning-path.md`'s two tables and loads each chapter's Markdown from `App/Explainer/docs` with its diagrams from `App/Explainer/diagrams` (the copies the app ships and, since 2026-10-11, what the explainer tests read; refreshed from the record by `scripts/export-docs.py --app`). Since D101 a chapter reads in short pages: `pages(of:file:)` gives an Overview, then one page per `##` section, a section over `pageWords` (300) words split into parts at its `###` headings, then between blocks, a long table by rows with its header repeated; the decision log (`newestFirst`) lists its newest section first. The contents page lists the chapters in reading order with a summary, reading time, section and diagram counts, then the glossary; a chapter (`DocumentReaderView`) shows its title, summary and one card per section (`cards(for:)`: title, parts, minutes, a diagram mark), opening on the section's first part; a page (`PageReaderView`) renders its blocks with `BlockView`, Previous and Next swapping pages in place and the last page leading to the next chapter; links between docs open in place. Reached from the welcome card, Settings and the tutorial's More menu | `explainerBundleHasAPNGForEveryDiagram`, `chaptersSplitIntoSectionPagesAndLongSectionsIntoParts`, `everyRealChapterReadsInShortPagesThatCoverItOnce`, `aSplitSectionIsOneCardThatOpensOnItsFirstPart` |
| `SettingsView` | sheet from the main menu's hamburger and the table's menu: difficulty, an Assistance section with the Beginner mode toggle, play speed, your name and face, the three opponents' names beside their portraits, haptics toggle, and the "How Catch 5 is built" explainer | manual |
| `WoodGrainView`, `GrainRandom`, `FeltView` | `WoodGrainView.swift`: the oak surface drawn in a `Canvas`, grain running across the screen from a fixed seed (gradient, bands, grain lines, and a `vignette`: radial for full-screen wood on the reading sheets and the tutorial, linear top-to-bottom shade for the header band); the felt gradient of the playing area with a seeded stipple of light and dark flecks for the cloth's nap, `Equatable` so the table's updates never redraw it; no image asset | manual |
| `HeaderBandShape` | the header band's outline: square top, a frown along the bottom whose corners hang `dip` lower than the middle; the oak is clipped to it | `dealtCardsComeFromTheDeckInTheCornerAndTheBandFrowns` |
| `DeckView`, `DiscardPileView`, `PillButtonStyle` | the stock as a stack of card backs with its count in the table's top-right corner, and beneath it the discards face down with their count once trump is named; the auction's solid full-width pill style (dimmed when the rule disallows the action) | manual |
| `HandFanView.cardCentre(slot:count:strip:cardWidth:in:)`, `dealOrigin(slot:count:strip:cardWidth:in:deck:)`, `discardTarget(index:count:width:)` | where a hand card comes to rest; where a refill card's flight starts (the deck beside the dealer, measured in the `TableLayout.space` coordinate space that `DealerDeck` reports through `onPlaced`); where a discard goes | `dealtCardsStartAtTheDealersDeckAndTheBandFrowns`, `discardsFlyToThePileOnTheLeft` |
| `DynamicTypeSize.boosted(by:)`, `Theme.textBoostSteps` | the size a given number of steps above a Dynamic Type size, stopping at the ends; `TableView` applies two steps to the whole app | `textBoostRaisesTheDefaultTwoStepsAndStopsAtTheLargest` |
| `Theme` | `Theme.swift`: `Theme.Wood` colours, grain direction and parameters, the auction pill height and spacing, card metrics (2:3 ratio, six-percent corner radius, hand 58/62 pt, pile 62 pt, overlap −8 pt leaving a 50 pt strip, the 402 pt width that earns wide cards, the XXXL cap on card scaling), `Theme.Table` seat nudges, the toss limits and the pile footprint, the AX2 cap on table text, the top-corner, bidder-ring, out-of-trump badge and watermark tokens (D65), motion springs, the trick hold, toast and shake values | `fannedHandCardsKeepAThumbSizedStrip` |
| `TableTopRow`, `TableTopRow.Button`, `BookPressStyle` | `TableTopRow.swift` (D93, replacing the Table and Clarify bar of D86; D98's score pad left the row again in D100; the book, 156 by 50 pt since D100, overhangs the row and lifts a little when pressed): a slim row on the solid header band, Home on the left (`home`: a carved back arrow with no word, D95, `Button.showsTitle` false so "Home" is VoiceOver's label only, back to the main menu with the match saved) and Rules on the right (`rules`: a closed book lying on the table, `RulesBook`, D94, that opens `RulesView` like a book); no pills, each a full thumb tall (`Theme.Table.topRowHeight`); nothing drops down and nothing pauses | `theTopRowHasHomeLeftAndRulesRightAndNothingThatPauses`, `homeIsACarvedBackArrowWithNoWord` |
| `DealerMark`, `DealerMark.placement(forPlace:)`, `DealerDeck` | `TableSurface.swift` (D90, D94): the dealer's mark, a four-card deck (`Theme.Table.dealerMarkDeckWidth`, 30 pt) with a dealer button at its foot (`DealerButton`, a round ivory puck with a "D" engraved, `engraving`), or beside it under the hand (`sideways`); `placement(forPlace:)` says where it rests: under a side seat's face, out beside the partner's tile under the score pad, beside the phone holder's carved name; `label` (DEALER) is the seat's mark in `SeatView.marks`; `DealerDeck` reports where the deal starts; never a control | `onlyTheDealerIsMarkedAndNoSeatSaysBidder` |
| `NameTag`, `NameTag.renames(_:)` | `NameTag.swift` (D89, D93, D94): the seat's name carved into the wood under its face in a heavy serif (`Theme.Table.carvedNameSize`, 22 pt), with trump carved beside it for the bidder (`trump`, from `SeatView.carvedTrump(seat:bidder:trump:)`); the phone holder's under the hand; no sticker; `renames(_:)` makes the name a button, at least 44 pt tall (`hitHeight`), that opens the rename alert (`renameHint`); `names(_:)` gives the names by place round the table, turning with the phone in pass and play | `everySeatWearsANameTagWithItsName` |
| `Scorecard`, `Scorecard.Line` | `Scorecard.swift` (D88, D94; at its first size again in the table's bottom-left corner since D100): a score pad lying on the table by the hand, light tan paper turned 2° with its shadow, ruled like a notebook page with a US and a THEM column; `lines(team:history:)` writes each hand's total in Marker Felt on the next line and strikes the one before, the last `Theme.Table.scorecardLines` showing; `liesOnTable(phase:reviewing:)` keeps it on the table only while cards are played and no trick is reopened; `label(us:mode:teamNames:)` names the full sheet's columns; a tap opens `ScorePanel` | `theScorecardWritesEachNewTotalAndStrikesThePriorOne`, `theScorePadLiesBottomLeftOnlyWhileCardsArePlayed` |
| `ScorePanel` | `ScorePanel.swift` (D83, D88): the full score sheet over the table, opened from the scorecard: both teams side by side with their totals and 25 dots filled in green (`dots(_:)`), and every hand as a card paging sideways, newest first, each with the bidder, made or set, and both teams' change and running total (`content(team:history:seatNames:)`, `HandCard`, `Content`); never scrolls down; a tap outside or a swipe closes it; opened by `TableView.teamPanel` | `eachTeamsPanelShowsItsTotalDotsAndHands` |
| `ContractPlaque`, `ContractPlaque.Contract`, `TallyMarks`, `OutOfTrumpBadge`, `CornerArrival`, `TableLayout.cornerWidth(available:)` | `TableCorners.swift` (D65, D87, D94): the bid in the top-left corner once the auction resolves (`contract(in:)`), with no box since D94: the bidder's own face lying like a chip (`Contract.portrait`) beside a carved BID eyebrow and the bid large in the display serif, 9 and out as a 9 with "and out" (`Contract.number`, `qualifier`, `spoken`), and under them trump carved into the wood once named (`Contract.trump`, `CarvedSuit`), the suit and the word Trump on one line (`trumpWord`, D93; `trumpLine(_:)`, D95) over the player's tally strokes chalked on the wood; the suit is the tally's tap target, tap to add, press and hold to take back, VoiceOver adjustable (`onTable(_:contract:width:)`, `spoken(_:tally:)`), and the tally demo pulses it; carved in `Carving.ink` (`numberInk`); tally strokes in groups of five (`TallyMarks.groups(_:)`); the crossed-out suit on a seat marked out of trump; `TableLayout.cornerWidth(available:)` by `Theme.Table.cornerHeight`, growing in with a fading glow the first time it fills, a fade under Reduce Motion (`CornerArrival`, D80) | `contractPlaqueShowsTheBidLargeAndNineAndOutAsNine`, `tableCornersSitOnLightTanWithDarkBrownInkAndSuitColouredTrump`, `tableCornersMatchAndNearlyFillTheTopRowBesideThePartner`, `trumpTallyAddsCapsAtThirteenTakesBackToZeroAndResetsNextHand`, `theBidBoxShowsTheFaceTheBidAndTrumpAndTheSuitKeepsTheTally`, `theBidBoxSaysTrumpBesideTheSuit`, `theBidCornerSetsTheSuitAndTrumpOnOneLine` |
| `Carving`, `Carved`, `CarvedSuit`, `DealerButton`, `RulesBook`, `BookFold` | `TableInlay.swift` (D94; since D98 the rules book is larger (156 by 50 pt since D100), with a cream ribbon hanging from its pages, a tooled border, and a soft sheen across the cover every 9 s, still under Reduce Motion): information carved into or lying on the table instead of panels on it. `Carving` holds the recess ink (the darkest wood brown, an oxblood for red suits, `ink(for:)`), the lit lower edge, a big cut's lighter floor (`floor(for:)`) and depth by size (`depth(size:)`, D95), and the WCAG `luminance(_:over:)` and `contrast(_:on:)` the tests hold it to; `Carved` (`.carved(_:)`) cuts text in with an inner shadow along its upper edge and a lit lower edge; `CarvedSuit` is a suit cut the same way, concave: shaded from ink to floor, its shadow and lip as deep as its size (D95); `DealerButton` the ivory puck; `RulesBook` the closed burgundy book of the top row; `BookFold` swings a help screen onto the screen about its left edge (`angle(progress:)`, `seconds`, a fade under Reduce Motion, held halfway for the `table-rules-fold` stage by `heldProgress(stage:)`) | `carvingsReadOnTheWood`, `nothingAPlayerMustReadIsSmallerThanFifteenPoints`, `trumpIsCarvedBesideTheBiddersNameAndBesideTheBid`, `theDealerButtonRestsInFrontOfTheDealersSeat`, `theCarvedNameStillRenamesItsSeat`, `theScorePadLiesOnTheTableAtASlightTurn`, `theRulesOpenLikeABook`, `theRulesBookIsBiggerAndOverhangsTheRow`, `carvedSuitsAreCutConcaveLikeTheLetters` |
| `BidBox` | `BidBox.swift` (D81, D94): one seat's place in the auction, empty until the seat speaks, then its bid large, PASS or 9 OUT (`BidBox.label(for:in:)`), carved into the wood with no box, the call growing in from the bid row or the seat, a fade under Reduce Motion | `everySeatsBidBoxShowsItsCallBigPassOrNineOut` |
| `TableSurface`, `SeatView`, `Suit.buttonTint` | the table (the hint bulb, tap-to-explain on the pile with its prompt line, and the keep captions under the trump pills appear only while `Settings.beginnerMode` is on; rule refusals and the record of play stay in both modes): partner across the top, West and East at the sides (tiles sized by `TableLayout` so they never collide with the pile; portrait wearing its `SeatMood`, gold ring on the seat to act, VoiceOver label from `seatSummary(for:)`, the name carved into the wood under the face, trump beside it for the bidder, that renames the seat when tapped (`onRename`, D93, D94), no stack of backs (D93), the dealer's mark under the face and no BIDDER word (`SeatView.marks(seat:dealer:bidder:)`, D90)), the bid box with trump (D87) in the top-left corner beside the partner, the faint trump watermark behind the play area, the bidder's dashed light-brown ring and the out-of-trump badge toggled by tapping a portrait (D65), the pile in the middle with each card nudged toward its seat, tossed with its own turn and drift (`CardToss`), and the winner ringed, status line ("Your turn · follow diamonds" while you must follow) with the hint and the show or hide last-trick controls ("Reviewing last trick" while it is reopened, `TableSurface.reviewLabel`, D79), commentary; during the auction every seat's bid box (`bidBox(at:from:)`, D81), the dealer context line and one row of every bid from 2 to 9, the passed ones greyed (`bidRow(allows:)`, `BidPill`), 9 and out on its own line under it (`auctionRows(nineAndOut:)`, `AuctionRow`, D85; the row takes no taps until your dealt hand has landed, `handLanded(_:motion:handNumber:)`), or the suit pills (full-width, red suits tinted red, each named beneath its glyph with its keep count ("clubs · keep 2"; VoiceOver hears the full keep-and-draw preview), greyed pills carrying their reason as an accessibility hint, 9 and out handing off to the confirmation) stand where the pile will be; one message line under the status (the reason a tap was refused first, then the undo toast, hint or explanation, notice, your call, placeholder; asking for a hint or an explanation clears a standing refusal), the hand-end card as a scrollable overlay whose buttons stack when they do not fit; the whole surface scrolls only when its content cannot fit (accessibility text sizes, the SE at XXXL), reads as one VoiceOver container, leaves the accessibility tree under the finished-hand card, and carries the status line's focus target (D77, D93: 68 pt faces popping out of their discs, `Theme.Table.portraitHeadroom` kept above each, the side seats rising `biddingSideRise` beside the partner while bidding) | `onlyTheDealerIsMarkedAndNoSeatSaysBidder`, `reviewBarSaysItIsTheLastTrick`, `theBidRowKeepsEveryNumberAndGreysTheOnesPassed`, `theAuctionTakesNoTapsUntilYourDealtHandHasLanded`, `seatTilesHoldTheLargerFaceAndItsHaloOnEveryVerifiedWidth`; otherwise manual (see the verification record in [redesign-plan.md](redesign-plan.md)) |
| `HandFanView`, `HandFanView.Geometry`, `ShakeEffect` | the hand, measured with `onGeometryChange` and arranged by `HandLayout` (a fan, or two flat rows when the fan could not keep 44 pt strips; flat with no fan allowance in the auction), with your name tag under it (D89) and, when you deal, the dealer's mark beside it (D90): discards fly to the pile under the deck, shrinking to card backs, and refills deal in from the deck when trump is named, overlap that tightens to fit the width, wide cards on screens of 402 pt and up, ±8° rotation and a shallow arc, legal cards standing up and illegal ones sunk on your turn, a press-lift, shake on an illegal tap; one gesture per card (D97): a tap picks a legal card (raised 30 pt, warm edge, `selected` shared with the table), a second tap or a drag of 70 pt up plays it, a shorter drag springs back, and the card's pose at that moment is handed to the table (`onLaunch`) so its flight starts there; cards of a hand still being dealt are kept in place but not drawn and turn face up as they land; `Geometry.pose(slot:count:flat:lift:)` places any card of a hand of any size in the table's space, for the deal and the launch | `theHandsLayoutPlacesEveryCardOfAFlatOrFannedRow`, `aPickedCardSaysHowToPlayIt` |
| `CardBackView` | a face-down card for opponents' seats | manual |
| `TableView` | the gameplay screen (shown by `RootView`, which passes `covered` while the pause card is up; `onHome` goes to the main menu from the top row's Home; `showRules` is the rules sheet from its book; `renaming` and `nameDraft` hold the rename alert opened by a name tag, written through `Settings.renameSeat(_:to:)`, D93): the top row, table surface, toast slot and hand in a column; one animation per accepted action; the scheduler task, keyed on the revision and `TablePause.isPaused`, that holds a finished trick, collapses it toward the winner and then lets the next computer act, and that stops whenever a sheet, dialog, cover or the reopened trick is showing; the Retry alert for a failed save; after each revision `noteChanges` picks the one haptic through `TableFeedback` and announces the trick winner or the hand outcome to VoiceOver; focus moves to the status line when a cover lifts, a sheet closes or your turn comes; the partner's 9-and-out card (`NineAndOutConfirm`, D70), which sends the bid to the engine only when confirmed; refused card taps recorded through `refuse`; the undo toast state (rendered by the surface's message line); the haptic vocabulary; the riffle over the dealer's deck when a hand is freshly dealt (D68); the celebrations played before the match-over card, holding the hand-end card back until they finish, with a success haptic as the cascade starts (D69); the sheets, the rename alert, the error alert and the background save; text styles throughout, boosted two steps app-wide, with cards capped at XXXL and table text at AX2; the felt background with the oak frown band behind the score bar | manual |
| `PassCurtainView` | pass and play's full-screen curtain over the table: Pass the phone to <name>, one Ready button; the table beneath is hidden from VoiceOver while it is up | manual |
| `HandOutcome` | `HandOutcome.swift`: the finished hand in the player's order, built from the engine's numbers: a headline (Contract made or set, 9 and out made or failed), the bidding team's line (bid, captured, score before → after), the defenders' line, and notes for the rules that decided a close case (a Game tie, a Five or Jack out of play, both teams at 25) | `handOutcomeLeadsWithTheContractAndTheArithmetic`, `handOutcomeExplainsTheEdgeCases` |
| `HandLayout`, `TableLayout` | `HandLayout.swift`: `HandLayout.arrange(count:cardWidth:available:)` decides from the measured width whether the hand fans (every exposed strip at least 44 pt) or falls back to two flat rows, and `height(of:cardWidth:)` gives the room each needs; `TableLayout.sideSeatWidth(available:)` shrinks the side seat tiles (down to 84 pt) before the pile's reservation (`pileReservation`: a nudged card plus air) could touch them | `handLayoutFansOnlyWhenEveryStripIsThumbSized`, `seatRowLeavesRoomForThePileOnEveryVerifiedWidth` |
| `DealerDraw`, `DealerDrawView` | `DealerDraw.swift`, `DealerDrawView.swift`: how the first dealer is chosen. Each seat draws one card from a shuffled deck and the highest deals, equal ranks going by suit (clubs lowest, spades highest); the match then starts from a fresh shuffle with that dealer. The view lays the four cards beside their portraits over the table with the dealer's ringed, one sentence ("Rue draws the king of spades and deals."), and a Deal button; it puts itself away after `Theme.Motion.dealerDrawHold` or at the first action, and pauses play while it shows | `dealerDrawPicksTheHighestCardWithSuitsBreakingTies`, `newGameDrawsForDealerAndTheMatchUsesIt` |
| `CardToss` | `CardToss.swift`: how a played card lands on the pile, a small turn and drift of its own on top of its seat's nudge, as if tossed in by hand; a pure function of the card, the hand and the trick, so it holds still while the trick lies there and differs next time, within `Theme.Table.tossRotationDegrees` and `tossDrift` | `tossedCardsLandDifferentlyButStayPut` |
| `SeatMood`, `Portrait.Expression` | `SeatMood.swift`: a seat's expression from public events only (whose turn, who took the last trick while it still lies on the table, who won the match): thinking, pleased or rueful, triumphant or dismayed, else neutral; ahead of the turn, the big moments (D73): the trick that caught the five of trump (takers triumphant, the others dismayed) and a 9-and-out declaration (the declarer's partner `surprised`) until the next lead, when `isBigMoment(for:in:)` also draws the face `Theme.Table.bigMomentScale` larger; never reads a hand | `seatMoodsFollowPublicEventsOnly`, `theFiveOfTrumpTrickGetsTheBigFacesUntilTheNextLead`, `aNineAndOutDeclarationSurprisesTheDeclarersPartnerUntilTheFirstLead` |
| `TableFeedback` | `TableFeedback.swift`: one haptic per accepted action; `Snapshot` records what a revision left (seeded from the restored match, so resuming fires nothing), `cue(from:to:)` reads the change between two snapshots and `cue(action:trickWinner:handEnded:matchWinner:)` picks the most consequential outcome (match won or lost, hand ended, trick won or lost, play, call) and each cue maps to its `SensoryFeedback`, with a win and a loss feeling different | `oneFeedbackCuePerActionWithTheOutcomeThatMattersMost` |
| `RiffleShuffle`, `startsHand(_:)` | `RiffleShuffle.swift` (D68): the 0.6 s riffle of card backs over the dealer's deck when a hand has just been dealt (bidding, no call yet); decoration only, never a pause reason, a still fade under Reduce Motion | `theShuffleRunsOnceAtTheStartOfEachHandAndHoldsNothingUp` |
| `NineAndOutResult`, `Celebration`, `CardCascade`, `NineAndOutScreen`, `lastNineAndOut`, `celebrations` (on `GameModel`) | `Celebration.swift` (D69): a 9-and-out hand's bidder and the points missed (High, Low, Jack, Five, Game; an undealt one counts as missed), read from `HandSummary`; the steps before the match-over card (`steps(winner:mode:nineAndOut:)`: the 9-and-out screen when the last hand was one, then the cascade for your team's win in solo or any win in pass and play); the 2 s card cascade (a still spread under Reduce Motion) and the full-screen made or missed screen | `nineAndOutIsMadeOnlyWithAllFivePointsAndNamesWhatWasMissed`, `aRealNineAndOutIsClassifiedFromTheHandResult`, `onlyAWinForThePhoneOrAnyPassAndPlayWinCascades` |
| `NineAndOutConfirm`, `partnerSeat` (on `GameModel`) | `NineAndOutConfirm.swift` (D70): the 9-and-out check as a card in the partner's voice, the partner being the seat across from the phone holder: portrait, name, `line`, a gold I'm sure that sends the bid and Not this time; replaces the system dialog | `thePartnerAsksBeforeNineAndOutInTheirOwnName` |
| `TablePause` | `TablePause.swift`: the reasons play must wait (scene inactive, pause card, any sheet, any dialog or alert, the reopened last trick, the draw for dealer) and one `isPaused` answer; UI state only, never an action | `tablePauseHoldsWhileAnyCoverRemains` |
| `TableScheduler.plan(hand:collapsedTricks:)` | the scheduler's three decisions as a pure function: hold a trick that has finished but not yet been taken (the hand's last trick too, before its result, D97), treat the coming computer play as a lead (longer pause) only when nothing was held, and wait for the deal animation at the start of play | `schedulerHoldsAFinishedTrickOnceThenTreatsTheNextPlayAsALead`, `theLastTrickIsTakenBeforeTheResultComesUp` |
| `TableMotion`, `MotionSnapshot`, `Flight`, `CardPose`, `TableGeometry`, `FlightPlan`, `FlightLayer`, `TableMeasurements` | `TableMotion.swift` and `TableView.swift` (D97): the table's animation state, view state only. `MotionSnapshot.change(from:to:)` reads one accepted action as a play (one card onto the field), a deal (the next hand), quiet (bids, trump) or a reset (undo, new game, restore); `FlightPlan` builds flights from the measured `TableGeometry` (the pile's centre and the cards' scale, each seat's face, the dealer's deck, the hand's layout): `play` from the player's face or your finger to its resting pose (`rest`), `collect` gathering a finished trick onto the winning card and taking it to the winner, `deal` two rounds of three from the dealer's left; `Flight.pose(at:)` runs a flight through its eased legs; `TableMotion` counts plays landed and the hand dealt, so a card in the air is not drawn twice; `apply` zeroes the count for a new hand and `reset` lands everything at once; `dealStep(for:handNumber:canAnimate:)` flies a fresh hand's deal or, once the auction has moved or motion is reduced, skips it (`skipDeal`) so no card stays hidden; `FlightLayer` draws the cards in the air above the table and takes no touches; `TableMeasurements` keeps the measurements by reference so measuring never redraws | `onePlayForwardIsAFlightAndAnythingElseIsAReset`, `theNextHandIsDealt`, `aFlightRunsFromItsStartThroughEachLegAndStopsAtTheEnd`, `aComputersCardFliesFromItsFaceToItsRestingPlace`, `aFinishedTrickGathersOnTheWinnerAndIsTakenToThem`, `theDealGoesRoundTheTableFromTheDealersLeftTwoRoundsOfThree`, `landingShowsWhatAFlightCarriedAndAResetPutsEverythingBack`, `aDealtHandIsHiddenUntilEachCardLands`, `aNewHandStartsWithNothingOfItOnTheField`, `aDealThatCanNoLongerRunIsSkippedSoTheHandShows` |
| `TableField`, `TrumpInlay`, `WalnutGrain`, `TableSurface.FieldEdges`, `SeatView.rim(seat:ourTeam:)` | `TableField.swift` and `TableSurface.swift` (D97): the walnut field inlaid between the seats, from under the partner's row to just under the side row, with its maple stringing, recess and lit lip; trump inlaid at its centre; the lamp that slides toward the seat to act (`lampOffset(place:size:)`); the portrait rim that says the side | `theFieldSitsBetweenTheSeatsAndReadsUnderTheCards`, `theSidesWearTheirOwnRim` |
| `CardView`, `CardFace` | a card at a given width (48 in the tutorial, 64 in the hand, 66 on the field) that scales with Dynamic Type, poker-proportioned (1:1.4, D97), with an optional `ring` drawn at its own scaled radius; `CardFace` prints rank and suit in two opposite corners, the pips as a deck lays them (`pipLayout(_:)`), one large pip for an ace and a framed letter for a court card (`isCourt(_:)`); rest / playable / dimmed / pile styles (a playable card stands up, a dimmed one sinks and stays solid: a dark veil and drained colour, never see-through; under Increase Contrast the veil lightens and a dashed edge carries the state); `Suit.glyph`, `Suit.ink`, `Card.label` helpers | `cardsArePokerSizedWithRealPipLayouts` |
| `HandSummaryView` | the hand-end card: the `HandOutcome` headline in gold, the two score lines, then who took High, Low, Jack, Five, Game, then the deciding-rule notes, using the configured seat names |
| colour extensions | `.ivory`, `.felt`, `.gold` |

## Tests/CatchFiveUITests/TraceHarness.swift

The system-at-work trace (D104): test-only, nothing in `Sources/` knows it exists.

| Type or function | What it does | Test |
|---|---|---|
| `TraceFolder` | `work/trace/` beside `Package.swift`, found from `#filePath`; `prepare()` creates it | `traceStageHostsTheHandAndRendersAFrame` |
| `TapTrace`, `TapTrace.Entry` | one tap's trail: `hop` for a call, `announced` for a @Published announcement and the value the sink was handed, `before`/`after` for a number read on each side of the send; `markdown` and `mermaid` draw the report, the announcements of one send in one box and the values on notes; `report()` writes `work/trace/<name>.md` | `traceReportHoldsTheBoxAndTheNotes` |
| `TraceStage` | hosts the real `HandFanView` in an unshown `NSWindow`; `bodyRuns` counts the wrapper's body evaluations; `settle(upTo:)` turns the run loop until the body runs again or the deadline passes; `frame(_:)` renders the view to `work/trace/<name>-<label>.png` | `traceStageHostsTheHandAndRendersAFrame` |

## Sources/CatchFiveDemo

`main.swift` plays a fixed, deterministic match (`swift run catch-five-demo`) and `ComputerDemo.swift` a shuffled computer match (`--computer`). Both call the real `Match`; they contain no rules of their own.
