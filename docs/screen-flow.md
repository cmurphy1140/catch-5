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
| **Cover** | Blocks play. The table underneath is neither tappable nor reachable by VoiceOver, and the scheduler holds | pause card, hand result, match over |

## The four screens

```mermaid
stateDiagram-v2
    [*] --> login: no name saved
    [*] --> intro: name saved, rules unseen
    [*] --> menu: name saved, rules seen

    login --> menu: sign in with a match already in progress
    login --> intro: sign in, no match, rules unseen
    login --> table: sign in, no match, rules seen

    intro --> table: finished or skipped

    menu --> table: Continue game
    menu --> table: New match (confirmed)

    table --> menu: pause card, Main menu
    note right of table
        The match is preserved.
        Nothing is discarded without asking.
    end note
```

`RootView.initialScreen(for:)` decides the first of these, and
`RootView.destinationAfterSignIn(matchInProgress:hasSeenRules:)` decides where signing in leads. Both
are `nonisolated` and tested directly, so the routing can be checked without building a view.

## What opens from the main menu

```mermaid
flowchart TD
    M[Main menu]
    M -->|Continue game| T[Table]
    M -->|New match, alert confirms| T
    M -->|How to play| TU[How to play, sheet]
    M -->|hamburger| S[Settings, sheet]
    M -->|hamburger| ST[Statistics, sheet]
    M -->|hamburger| EX[How Catch 5 is built, full-screen]
    TU --> M
    S --> M
    ST --> M
    EX --> M
```

Continue game is the primary action whenever a saved match exists; New match takes its place when one
does not. Replacing a match in progress always asks first (spec R32).

## What opens from the table

```mermaid
flowchart TD
    T[Table]
    T -->|gear menu| P[Pause card, cover]
    T -->|gear menu| U[Undo last action]
    T -->|gear menu| S[Settings, sheet]
    T -->|gear menu| ST[Statistics, sheet]
    T -->|gear menu| TU[How to play, sheet]
    T -->|gear menu, alert confirms| NEW[New match]
    T -->|score bar| SB[Scoreboard, sheet]
    T -->|hint| H[Hint detail, sheet]
    T -->|hand ends| R[Hand result, cover]

    P -->|Continue game| T
    P -->|Main menu| M[Main menu]
    P -->|New match, alert confirms| T
    R -->|Deal next hand| T
    R -->|Review| RV[Hand review, sheet]
    R -->|match won| MO[Match over]
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
- **Covers hide what is beneath.** The table is `accessibilityHidden` under a cover, so VoiceOver
  cannot reach controls the eye cannot see either.
