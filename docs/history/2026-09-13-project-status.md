# Project status — Catch 5 and Plug & Pitch

> Dated snapshot, moved to history on September 13, 2026. Current status lives in `AGENTS.md` and the family plan's progress table. The iCloud exclusion described under Environment was applied to both repository folders the same day.

**Snapshot date:** September 13, 2026. Written for a planning session starting
fresh. Everything below was verified by inspecting the repositories on this Mac
on that date, except where marked *unverified*. Treat unverified claims as
things to check, not as facts to build on.

**Corrected September 13, 2026, later the same day.** The original snapshot named
reconciling `claude/dealer-draw` as this project's open blocker. That was wrong,
and two sessions disproved it independently. The branch is already in `main`. The
branch table, the section that was headed "The open problem", the decisions list
and the test-status note below have all been rewritten from evidence; the rest of
the file stands as first written.

## The two repositories

They are deliberately separate. Work flows one way: catch-5 is **later ingested
into plug-and-pitch**. plug-and-pitch is not a fork to be merged back.

| | catch-5 | plug-and-pitch |
|---|---|---|
| Checkout | `~/Desktop/Projects/catch-5` | `~/Desktop/Projects/plug-and-pitch` |
| Remote | `git@github.com:cmurphy1140/catch-5.git` | `git@github.com:cmurphy1140/plug-and-pitch.git` |
| `main` tip | `2befd92` | `0e99835` |
| Checked-out branch | `docs/family-first-plan` | `main` |
| Working tree | uncommitted docs work | uncommitted docs work |
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

*Verified September 13, 2026:* `swift build` succeeds and `swift test` reports
**149 tests passed** against the working tree (`main` plus the uncommitted docs
work, which changes no Swift source). The build was briefly broken earlier that
day by an iCloud conflict copy inside a compiled target; see *iCloud duplicates*
below. `AGENTS.md` also records a September 12 simulator review covering the
navigation flow and one hand.

*Still unverified:* broader accessibility, a full match end to end, and
real-device behavior. Those were outstanding before September 13 and remain so.

### Branches

| Branch | Ahead of main | Behind main | Notes |
|---|---|---|---|
| `claude/dealer-draw` | 19 | 21 | **Historical. Do not merge.** Its code is all in `main` via PRs #24–#38. Pushed. |
| `fix/bigger-seats-and-header` | 3 | 3 | Pre-squash source of PR #40. Nothing unique; a merge would revert `main`. |
| `fix/labelled-home-button` | 2 | 4 | Pre-squash source of PR #41. Nothing unique; a merge would revert `main`. |

The "ahead of main" counts are an artifact of squash merging and do **not** mean
unmerged work. All three branches are safe to delete once Connor says so.

No open pull requests. Seventeen merged `claude/*` branches were deleted from
the remote on September 13; their content is in `main`.

`main` advances by **squash merge**, so a topic branch whose work is fully in
`main` still reports as unmerged. Compare trees (`git diff main..<branch>`), not
commit lists.

### Settled: `claude/dealer-draw` is already in `main`

**This was previously recorded here as the project's open blocker. It is not one.**
Two sessions checked it independently on September 13 and agreed.

Every code commit on the branch is in `main` already, squash-merged as
PRs #24–#38. The evidence:

- `git log --cherry-mark --left-right main...claude/dealer-draw` marks nine of the
  branch's commits byte-identical to commits on `main`.
- The remaining commits match merged PRs by subject, rung by rung: pause gate,
  hand targets, auction clarity, outcome clarity, accessibility, launch polish,
  trump preview, stack review, moods, card toss, dimmed cards, discard pile,
  dealer draw.
- The four commits that could plausibly have carried something unique were each
  chased to ground in `main`: the hand-card sizing (`Theme.swift`, `handWidth`
  58.0 / `handWidthWide` 62.0 / `handOverlap` -8.0), the one-line trump caption
  (`TableSurface.swift`, same D34 comment), the `nonisolated` routing helpers in
  `RootView.swift`, and the Xcode dark-style regeneration (superseded by
  `32619de`).
- `git grep` on `main` finds Mood, TablePause, DealerDraw, the discard pile, the
  card toss and the trump preview in `Sources/`; `main`'s `project.yml` already
  carries `UIUserInterfaceStyle: Dark`.

**The conflicts were the danger sign, not the work.** A merge of this branch
would *delete* `MainMenuView.swift`, `RuleTrial.swift`, `RuleTrialView.swift`,
`RulesFigures.swift`, `MarkdownDocument.swift` and `ExplainerTests.swift`, and
revert `ExplainerView.swift` and `RulesView.swift` by roughly 800 lines — the
work of PRs #30, #33 and #39–#41. The 16 "conflicted files" were the squash
merges colliding with their own originals. Git was refusing to let an older tree
overwrite a newer one. There was never a which-design-wins decision to make.

The branch's only unique content was the documentation reorganization
(`3d7ba57`), which has since been carried onto `docs/family-first-plan`
separately.

**Do not merge or rebase it.** `AGENTS.md` says the same. It and
`backup/dealer-draw-pre-rebase` (`3d7ba57`, local only) can both be deleted.

### iCloud duplicates in the catch-5 checkout

`~/Desktop` is iCloud-synced, and branch switching produced **34 untracked
conflict copies** with `" 2"` / `" 3"` suffixes — 20 in `App/Explainer/`, a shadow
`docs/history 2/` directory, two plan copies, and four at the repository root.

One of them broke the build. `Sources/CatchFiveUI/RulesFigures 2.swift` sat
inside a compiled target declaring a second `enum RulesFigures`, so `swift build`
failed with `invalid redeclaration of 'RulesFigures'`. It was deleted on
September 13 and the build and full suite pass again.

The remaining 33 were each checked with `git hash-object` and are byte-identical
to content git already stores; the one exception, `codex-handoff 2.md`, differs
from `codex-handoff 3.md` only in two paths and holds nothing unique. All are
safe to delete. List them with
`git status --short --untracked-files=all | grep '??'`.

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

1. ~~Which design wins where `claude/dealer-draw` and `main` collide.~~
   **Settled September 13: there is no collision.** The branch is already in
   `main`; see the section above. Nothing to decide.
2. ~~Whether the two `fix/` branches carry anything unmerged.~~ **Settled
   September 13:** both are pre-squash sources of PRs #40 and #41 and carry
   nothing unique. Deleting them needs only Connor's word.
3. Sequencing of the visible rename and the 9–5 preset in plug-and-pitch.
4. When catch-5's UI work gets ingested into plug-and-pitch, and by what
   mechanism — the two have diverged by 21 commits of UI redesign.

## Do not assume

- That an unmerged-looking branch is unmerged. Squash merges hide it.
- That plug-and-pitch has catch-5's recent UI. It does not; it predates it.
- That tests pass *at any given moment*. They did pass on September 13 (149 of
  149), but an iCloud conflict copy had broken the build hours earlier. Run the
  suite; do not quote a remembered number.
- That the `~/Developer/active/` copies still exist. Placeholder stubs for
  catch-5, band-charter-outreach and macos-audit were removed on September 13
  after verifying they held nothing unique. `job-hunt`, `notes` and `scratch`
  remain, and so does `catch-5-worktrees/game-logic` — a real registered git
  worktree on `logic/baseline` at `2befd92`, created for a session that was
  never started. `git worktree list` confirms it. Remove it with
  `git worktree remove` if the two-track split is not taken up.
