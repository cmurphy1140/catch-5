# Game Flow

Seats are 0 (You), 1 (West), 2 (Partner), 3 (East). Team 0 is seats 0 and 2; team 1 is seats 1 and 3. Play moves in ascending seat order, wrapping at 4.

## A match

```mermaid
stateDiagram-v2
    [*] --> Hand1: Match(deck:dealer:)
    Hand1 --> Settled: sixth trick scored once
    Settled --> NextHand: startNextHand(deck:)<br/>dealer rotates +1
    NextHand --> Settled: sixth trick scored
    Settled --> [*]: a team reaches 25<br/>or 9-and-out resolves
```

`Match.winner` becomes non-nil exactly once. After that every action throws `MatchError.matchFinished`. The screen asks for an explicit "Deal next hand" tap so the scoring breakdown can be read first.

## One hand: the four phases

```mermaid
stateDiagram-v2
    [*] --> bidding: deal 6 each,<br/>two packets of 3,<br/>left of dealer first
    bidding --> choosingTrump: dealer has acted<br/>(auction.nextSeat == nil)
    choosingTrump --> playing: bid winner names trump,<br/>everyone discards non-trumps<br/>and refills to 6
    playing --> playing: card played,<br/>4th card resolves the trick,<br/>winner leads
    playing --> finished: 6th trick →<br/>scoreHand → Match.recordHand
    finished --> [*]
```

`HandPhase` is the enum with these four cases. Every `Hand` method starts with a guard on `phase`, so calling `play` during `bidding` throws `HandError.wrongPhase` rather than doing something odd.

## The auction, turn by turn

```mermaid
flowchart TD
    A["nextSeat = dealer + 1"] --> B{"Is this seat the dealer?"}
    B -- no --> C{"Pass?"}
    C -- yes --> D["record AuctionCall(seat, nil)"]
    C -- no --> E{"bid ≥ highest + 1<br/>and 2…9?"}
    E -- no --> X["throw invalidBid<br/>turn is NOT consumed"]
    E -- yes --> F["highestBid = bid, winner = seat<br/>record AuctionCall"]
    D --> G["nextSeat += 1"]
    F --> G
    G --> B
    B -- yes --> H{"Anyone bid?"}
    H -- no --> I["dealer must bid 2<br/>(pass throws)"]
    H -- yes --> J["dealer may match highest,<br/>raise, or pass"]
    I --> K["nextSeat = nil<br/>phase → choosingTrump"]
    J --> K
```

Special bid: `nineAndOut` sets `highestBid = 9` and `isNineAndOut = true`. It outranks a normal 9. Only the dealer may bid against it, and only by matching with their own 9-and-out; that override was confirmed as a house rule on 2026-09-04. Normal bids after a 9-and-out throw.

`Auction.calls` is the ordered list of accepted calls. The table reads it to show "Bid 3" or "Pass" under each seat; computers receive it in `PlayerView.calls`.

## One trick

```mermaid
sequenceDiagram
    participant L as Leader
    participant H as Hand
    participant N as Next three seats
    L->>H: play(card) — any card is legal on a lead
    loop three more plays
        N->>H: play(card)
        H->>H: legalMoves: must follow led suit if able,<br/>otherwise anything (trumping allowed)
    end
    H->>H: trickWinner: highest trump if any trump was played,<br/>else highest card of the led suit
    H->>H: captured[winner % 2] += all four cards
    H->>H: nextSeat = winner
    Note over H: on the 6th trick: scoreHand, phase = finished
```

The screen keeps the last completed trick visible, ringed in gold on the winning card, until the winner leads the next card. Then the old trick fades and the new lead slides in from that seat's edge of the table.

## Scoring at the end of a hand

```mermaid
flowchart LR
    C["captured cards<br/>per team"] --> HI["High: highest trump played → 1"]
    C --> LO["Low: lowest trump played → 1"]
    C --> J["Jack of trump, if played → 1"]
    C --> F["Five of trump, if played → 5"]
    C --> G["Game: 10=10 J=1 Q=2 K=3 A=4<br/>across all suits → 1<br/>tie → bidding team"]
    HI & LO & J & F & G --> P["HandScore.points [team0, team1]"]
    P --> S["settle(scores, points, bidder, bid)"]
    S --> R{"bidder made bid?"}
    R -- yes --> Y["bidder += its points"]
    R -- no --> N["bidder −= bid amount"]
    Y & N --> DEF["defenders += their points"]
    DEF --> W{"≥ 25?"}
```

High and Low are relative to cards actually played. Undealt cards stay in the stock and never count, which is why "Out of play" can appear for Jack or Five in the hand summary.

## Who acts when: the screen's scheduler

```mermaid
flowchart TD
    R["model.revision changed"] --> T[".task(id: revision) starts"]
    T --> Q{"human's turn,<br/>or hand/match over?"}
    Q -- yes --> STOP["do nothing; wait for a tap"]
    Q -- no --> S["sleep 1.2 s if leading a trick,<br/>0.7 s otherwise"]
    S --> C{"task cancelled?<br/>(revision changed again)"}
    C -- yes --> STOP
    C -- no --> D["stepComputer():<br/>PlayerView → ComputerPlayer.decide → match.apply"]
    D --> R
```

Because `stepComputer()` increments `revision`, the next task starts automatically. The human's tap also increments it, which cancels any pending computer sleep, so nothing acts out of turn.

## How a computer chooses a card

```mermaid
flowchart TD
    V["PlayerView: my cards, trick, completed tricks"] --> K["Knowledge<br/>unseen = deck − mine − played"]
    K --> L{"Am I leading?"}
    L -- yes --> B{"Hold an unbeatable trump?"}
    B -- yes --> LB["lead it: pulls trumps,<br/>may force out the five"]
    B -- no --> NT{"No trumps left<br/>against us?"}
    NT -- yes --> LS["lead best side card"]
    NT -- no --> LX["cheapest exit,<br/>never the five"]
    L -- no --> S["for each legal card:<br/>p = chance our side wins the trick<br/>score = p·(table + stake) − (1−p)·stake − control"]
    S --> P["play the best score;<br/>ties → least control, lowest rank"]
```

The Hint button runs exactly this from your seat and shows the branch it took in words, ringing the suggested card. `stake` is the card's own point value if the other side captures it (a five is 5, a certain Low is 1, a ten is 0.6). `control` is what a trump is worth for later tricks, highest for an unbeatable one and zero on the last trick. `p` is 1 for an unbeatable card, otherwise 0.8 or 0.6 depending on how many seats still play, and when partner is winning it is the chance partner's card holds.

## Saving

Every accepted action calls `persist()`, and `TableView` also calls it whenever the app leaves the foreground (`scenePhase` change). The write is atomic: the old file is replaced only when the new one is complete. `loadDefault()` reads it at launch; on failure the user sees an explanation and a fresh game.
