# Screen flow

Where the app's screens are, and every way to get between them. Read from `RootView.swift`,
`MainMenuView.swift`, `TableView.swift` and `TableSurface.swift`, so it describes what the code does
rather than what a design intends. [game-flow.md](game-flow.md) covers the *game's* state machines;
this covers the *screens*.

Three kinds of surface, and the difference matters:

| Kind | Behaviour | Examples |
|---|---|---|
| **Screen** | Replaces everything. `RootView` owns exactly four. | login, intro, menu, table |
| **Sheet** | Slides over, dismissed by the player, the screen beneath continues to exist | settings, statistics, how to play, hand review, scoreboard, hint detail |
| **Cover** | Blocks play. The table underneath is neither tappable nor reachable by VoiceOver, and the scheduler holds | pause card, tip card, 9-and-out screen, hand result, match over, pass-and-play curtain |

## The four screens

```mermaid
stateDiagram-v2
    [*] --> login: no name saved
    [*] --> intro: name saved, rules unseen
    [*] --> menu: name saved, rules seen
    [*] --> table: left the table under thirty minutes ago, match in progress

    login --> menu: sign in with a match already in progress
    login --> intro: sign in, no match, rules unseen
    login --> table: sign in, no match, rules seen

    intro --> table: finished or skipped

    menu --> table: Back to the table, tip card first
    menu --> table: New game (confirmed), tip card first

    table --> menu: pause card, Main menu
    table --> menu: Home, top left
    note right of table
        The match is preserved.
        Nothing is discarded without asking.
    end note
```

`RootView.initialScreen(for:matchInProgress:)` decides the first of these, and
`RootView.destinationAfterSignIn(matchInProgress:hasSeenRules:)` decides where signing in leads. Both
are `nonisolated` and tested directly, so the routing can be checked without building a view. A launch
opens the main menu whether or not a match is in progress (decision D141, replacing D64): the match
waits behind Back to the table, and in pass and play the curtain still comes down for whoever is next,
since a restored match never carries a revealed seat. The exception is a short absence (decision D144):
a launch within thirty minutes of leaving the app from the table goes straight back to it, without the opening.

## What opens from the main menu

```mermaid
flowchart TD
    M[Main menu]
    M -->|Back to the table| TC[Tip card, cover]
    M -->|New game, alert confirms| TC
    TC -->|tap, or after its second face| T[Table]
    M -->|How to play| TU[How to play, sheet]
    M -->|hamburger| S[Settings, sheet]
    M -->|hamburger| ST[Statistics, sheet]
    M -->|hamburger| EX[How Catch 5 is built, full-screen]
    TU --> M
    S --> M
    ST --> M
    EX --> M
```

Back to the table is the primary action whenever a match is in progress, with New game beside it;
New game stands alone when there is none (D67). Replacing a match in progress always asks first (spec R32).
Either way the tip card comes up over the table first: where the game comes from, then one tip, then the
deal. A launch that resumes onto the table skips it.

## What opens from the table

```mermaid
flowchart TD
    T[Table]
    T -->|Home, top left, game saved| M
    T -->|Rules book, top right| RU[Rules, sheet]
    T -->|tap a name tag| RN[Rename alert, play waits]
    T -->|scorecard| SB[Score sheet, cover]
    T -->|hint| H[Hint detail, sheet]
    T -->|hand ends| R[Hand result, cover]

    P -->|Continue game| T
    P -->|Main menu| M[Main menu]
    P -->|New match, alert confirms| T
    R -->|Deal next hand| T
    R -->|Review| RV[Hand review, sheet]
    T -->|match won| CE[9 and out screen, cascade, cover]
    CE --> MO[Match over]
    R -->|match won| MO
    RV --> R
    U --> T
    SB --> T
    H --> T
    S --> T
    ST --> T
    TU --> T
```

## Rules the flow obeys

- **A cover holds the game.** While the pause card or a hand result is up, the scheduler does not let
  a computer act, so no move happens behind it. `tablePauseHoldsWhileAnyCoverRemains` checks this.
- **Nothing is thrown away without a question.** Every route that would replace a match in progress
  goes through an alert with a named way to say no (spec R32, decision D57).
- **Leaving the table keeps the match.** Main menu from the pause card preserves everything; Continue
  game returns to the same trick.
- **A sheet never resumes a finished hand** and never adds a second entry to history.
- **Practice is separate from play.** How to play opens the tutorial over whichever screen launched
  it; it never replaces the live match, and its hands never reach statistics.
- **Pass and play passes the phone.** New match asks Solo or Pass and play. In pass and play, before any seat
  acts after another seat, a full-screen curtain says Pass the phone to <name>; only Ready shows that seat's hand.
  Hand results are shared and show without a curtain; hands never do.
- **Covers hide what is beneath.** The table is `accessibilityHidden` under a cover, so VoiceOver
  cannot reach controls the eye cannot see either.
