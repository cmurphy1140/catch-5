# Project status — Catch 5 and Plug & Pitch

**Snapshot date:** September 13, 2026. Written for a planning session starting
fresh. Everything below was verified by inspecting the repositories on this Mac
on that date, except where marked *unverified*. Treat unverified claims as
things to check, not as facts to build on.

## The two repositories

They are deliberately separate. Work flows one way: catch-5 is **later ingested
into plug-and-pitch**. plug-and-pitch is not a fork to be merged back.

| | catch-5 | plug-and-pitch |
|---|---|---|
| Checkout | `~/Desktop/Projects/catch-5` | `~/Desktop/Projects/plug-and-pitch` |
| Remote | `git@github.com:cmurphy1140/catch-5.git` | `git@github.com:cmurphy1140/plug-and-pitch.git` |
| `main` tip | `2befd92` | `0e99835` |
| Checked-out branch | `claude/dealer-draw` | `main` |
| Working tree | clean | clean |
| Unpushed commits | none | none |
| What it is | The single-game subset: Catch 5 alone. UI and gameplay polish happens here first. | The multi-preset app. A match carries a versioned rule set, so a variant is a preset rather than a rewrite. |

Both have `README.md` and `AGENTS.md` sections naming this relationship.
`CLAUDE.md` is a symlink to `AGENTS.md` in both; maintain one file, not two.

plug-and-pitch sits on an **older Catch 5 base (`c2172db`)** than catch-5's
`main`. A feature missing from one may exist in the other. Check both before
concluding something is unimplemented.

## catch-5

`main` (`2befd92`) has the solo game: pure Swift rules engine, three computer
opponents (Hazel, Otto, Rue) at Easy and Standard, replay-log save/resume, and a
SwiftUI table with hints, tap-to-explain, hand review, undo, scoreboard, match
history, settings, a five-lesson tutorial and in-app documentation. Returning
players land on a main menu. Layout is tuned for the iPhone 16 family (393 pt);
other sizes get a scroll fallback.

*Unverified:* `AGENTS.md` states 149 tests pass and records a September 12
simulator review covering the navigation flow and one hand. No test or build run
was performed on September 13. Broader accessibility, full-match and real-device
verification were already outstanding before that date.

### Branches

| Branch | Ahead of main | Behind main | Notes |
|---|---|---|---|
| `claude/dealer-draw` | 19 | 21 | Checked out. Real unmerged work. Pushed. |
| `fix/bigger-seats-and-header` | 3 | 3 | Subjects match squash-merged PR #40; likely redundant, unconfirmed. |
| `fix/labelled-home-button` | 2 | 4 | Home pill / bare chevron. Unconfirmed whether it landed. |

No open pull requests. Seventeen merged `claude/*` branches were deleted from
the remote on September 13; their content is in `main`.

`main` advances by **squash merge**, so a topic branch whose work is fully in
`main` still reports as unmerged. Compare trees (`git diff main..<branch>`), not
commit lists.

### The open problem: reconciling `claude/dealer-draw`

The branch holds roughly 11 commits of genuine work not in `main` — pause under
any cover, launch and restoration behavior, trump captions and suit-pill
previews, opponent moods, an Xcode dark-style regeneration — plus a documentation
reorganization committed on September 13 (`3d7ba57`).

Both a rebase and a merge onto `main` were attempted and **aborted**:

- Rebase: conflicted on the second of 19 commits, 10+ files.
- Merge: **16 conflicted files**, 78 clean. Conflicts are `AGENTS.md`,
  `CatchFive.xcodeproj/project.pbxproj`, `Sources/CatchFiveUI/` `HandFanView`,
  `RootView`, `ScoreBarView`, `Settings`, `TableSurface`, `TableView`, `Theme`,
  `Tests/CatchFiveUITests/GameModelTests.swift`, and five docs files.

This is not a mechanical merge. `main`'s UI redesign (PRs #39–#41) and the
branch's layout work rewrote the same views, so resolving `TableView.swift` and
`Theme.swift` means **deciding which design wins**. That is a product decision
and should be made deliberately, view by view.

`backup/dealer-draw-pre-rebase` (`3d7ba57`, local only) marks the pre-attempt
state. The branch is pushed, so the work is safe on GitHub either way.

## plug-and-pitch

The goal is an app offering Catch 5 and Connor's **9–5** variation as two fixed
presets. Full confirmed rule table and sequencing:
`docs/superpowers/plans/2026-09-05-plug-and-pitch.md`.

Seven commits were pushed on September 13, moving `origin/main` from `c2172db`
to `0e99835`. Before that the remote was a verbatim copy of catch-5 and all this
work existed only as uncommitted local files.

**Implemented and committed:**

- `Sources/CatchFive/RuleSet.swift` — versioned presets. `catchFiveV1` vs the
  9–5 set differ on `initialHandSize` (6 / 9), `minimumBid` (2 / 4),
  `maximumPoints` (9 / 18), `targetScore` (25 / 50) and `specialBidName`
  ("9 and out" / "Hotshot"). Threaded through bidding, scoring, hand and the
  computer player. `HouseRules` aliases the Catch 5 definition.
- Rule trials — self-contained teaching hands (`RuleTrial.swift`,
  `RuleTrialView.swift`, `RulesFigures.swift`, `MarkdownDocument.swift`).
- Explainer rebuilt on markdown plus generated PNG diagrams, replacing the
  exported `.dc.html` pages.
- Launch screen and app icon.
- `docs/nine-five-rules.md`.

**Not implemented:** the visible **Plug & Pitch** rename (the app still displays
"Catch 5") and the selectable 9–5 preset. Per `AGENTS.md`, only Catch 5 can
start a game; 9–5 hand and match construction **throws**. Standalone 9–5
auctions and scoring exist. Do not describe a planned capability as available.

*Unverified:* no test or build run was performed against this tree before or
after the September 13 commits. Run `scripts/build-simulator.py` before building
on it.

## Environment

- `~/Desktop` is **iCloud-synced** (Desktop & Documents; `brctl status` reports
  `current=YES`). Both repositories live under it.
- Gitignored build output is excluded from sync with
  `xattr -w 'com.apple.fileprovider.ignore#P' 1 <dir>` — applied to catch-5
  `work/` (868 MB) and plug-and-pitch `work/` and `notes/` (82 MB). Apply the
  same to any new large generated directory.
- Xcode 26.6 (build 17F113). Swift 6 package, Swift Testing, iOS 17+ / macOS 14+.
- `~/.claude/CLAUDE.md` was updated on September 13: code projects now live under
  `~/Desktop/Projects/`, named to match the GitHub repository.

## What a new plan needs to decide

1. **Which design wins** where `claude/dealer-draw` and `main` collide — the
   blocker on 16 files, and the reason both merge attempts were abandoned.
2. Whether `fix/bigger-seats-and-header` and `fix/labelled-home-button` carry
   anything not already squash-merged, or can be deleted.
3. Sequencing of the visible rename and the 9–5 preset in plug-and-pitch.
4. When catch-5's UI work gets ingested into plug-and-pitch, and by what
   mechanism — the two have diverged by 21 commits of UI redesign.

## Do not assume

- That an unmerged-looking branch is unmerged. Squash merges hide it.
- That plug-and-pitch has catch-5's recent UI. It does not; it predates it.
- That tests pass. Nothing was run on September 13.
- That the `~/Developer/active/` copies still exist. Placeholder stubs for
  catch-5, band-charter-outreach and macos-audit were removed on September 13
  after verifying they held nothing unique. Only `job-hunt`, `notes` and
  `scratch` remain there.
