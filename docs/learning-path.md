# Learning Path: Reading Catch 5 Without an IDE

This is the front door to the living documentation. Each linked page is kept in step with the code; when a source file changes, the page that explains it changes in the same commit.

## Reading order

| Step | Page | What you will understand afterwards |
|---|---|---|
| 1 | [build-and-run.md](build-and-run.md) | What a Swift package is, what the four commands you actually run do, and how the simulator build works without Xcode's editor |
| 2 | [architecture.md](architecture.md) | The three layers (engine, view model, SwiftUI), why the engine has no UI code, and how MVVM maps onto this repo |
| 3 | [game-flow.md](game-flow.md) | The state machines: one hand, one auction, one trick, one match, and how the screen turns computer players on and off |
| 4 | [types-and-functions.md](types-and-functions.md) | Every type and public function, one line each, with the test that proves it |
| 5 | [testing.md](testing.md) | How Swift Testing works, the test pyramid here, and how each feature was built test-first |
| 6 | [decisions.md](decisions.md) | The decision log: what was chosen, what was rejected, and why |
| 7 | [code-map.md](code-map.md) | Older call-trace walkthroughs (match scoring, save/resume, computer path); still accurate |
| 8 | [roadmap.md](roadmap.md) | The six milestones toward a shippable app, all done, with dependencies, tests written first and risks |
| 9 | [tutorial-spec.md](tutorial-spec.md) | The in-app "How to play" tutorial: five lessons, their fixtures and answer keys, and the tests that check them against the engine |
| 11 | [redesign-plan.md](redesign-plan.md) | The table-first redesign: research findings, the design tokens, what changed in each view, and the risks that shaped it |
| 10 | [device-install.md](device-install.md) | Putting the app on your own iPhone: what this Mac is missing, the one-time setup, and the build-and-install commands |

## Swift vocabulary used in these pages

You will meet these words constantly. Each is defined once here and used without explanation elsewhere.

| Term | Meaning in plain words | Where you see it |
|---|---|---|
| `struct` | A value type. Assigning it makes an independent copy. Changing a copy never changes the original. | `Card`, `Hand`, `Match`, `Auction` |
| `class` | A reference type. Two variables can point at the same object. Used only where SwiftUI needs a shared, observable object. | `GameModel` |
| `enum` | A fixed set of cases. Cases may carry data ("associated values"). | `Suit`, `HandPhase`, `PlayerAction.play(Card)` |
| `mutating func` | A method on a struct that changes the struct it is called on. | `Hand.play`, `Match.bid` |
| `private(set) var` | Anyone can read it, only the owning type can change it. This is how the engine stays a referee. | Most `Hand` and `Match` properties |
| `throws` / `try` | The function can fail with a typed error instead of returning garbage. Callers must write `try`. | Every rule check |
| `guard ... else { throw }` | Validate first, exit early. The rest of the function runs only when the guard passes. | Everywhere in the engine |
| `Sendable` | The compiler checks this value is safe to pass between threads. All engine types are `Sendable`. | Type declarations |
| `Codable` | Can be converted to and from JSON automatically. | `Card`, `SavedAction` |
| `@MainActor` | Runs only on the main thread, which is where UI must be updated. | `GameModel`, view model tests |
| `ObservableObject` / `@Published` | A class SwiftUI watches. When a `@Published` property changes, dependent views re-render. | `GameModel` |
| `@StateObject` | A view owns this observable object for its lifetime. | `TableView` |
| `some View` | "Returns a view; the exact type is the compiler's business." | Every SwiftUI `body` |
| `@Test` / `#expect` | Swift Testing attributes. `@Test` marks a test function; `#expect` records a failure without stopping. | All tests |
| `#require` | Like `#expect` but stops the test if the value is missing. Used to unwrap optionals safely. | Simulation tests |

## How to read a Swift file in a plain editor

1. Skim the type declarations first (`struct`, `enum`, `class`). Note which properties are `private(set)`; those are the state the type protects.
2. Read the `init`. It tells you what the type needs to exist and what it validates on creation.
3. Read each `mutating func` top to bottom: guards first, then the change, then any follow-on effects such as `finishTrick()`.
4. Open the matching test file in [types-and-functions.md](types-and-functions.md). Each test name is a sentence describing a rule.
5. Run just that test:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter playMustFollowSuitAndWinningPlayerLeadsNext
```

## The rules inside the app

`Sources/CatchFiveUI/RulesText.swift` quotes every paragraph of [catch-five-rules.md](catch-five-rules.md) and a test compares the two, so editing the rules document is the only way to change what the app says.

## Keeping these pages live

Rule for every future change: if a commit adds or renames a type, function, phase, or test, the same commit updates the relevant page here. `CLAUDE.md` states this so automated sessions follow it too.

**Reading these pages in the app.** The Claude Design exports of these pages are bundled in the app (`App/Explainer`) and open from Settings under "How Catch 5 is built". They are a snapshot: after changing a page here, re-export it and replace the file in that folder.

**Exporting these pages.** `python3 scripts/export-docs.py`, run from the repo root, renders every page here to PDF and every Mermaid diagram to PNG in the gitignored `work/docs-export/` folder, along with a combined `catch-five-explainer.pdf` and a paste-ready prompt for Claude Design. The reading-order table above drives its page list, so a page added to the table is exported on the next run. [build-and-run.md](build-and-run.md) describes the pipeline.
