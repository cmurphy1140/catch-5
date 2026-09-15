# Working together: sessions, worktrees, prompts, and the log

This file is meant to be edited. Every section says when to change it. `AGENTS.md` holds the rules that rarely change; this holds the ones that do. Pinned product ideas live in the spec's section E, not here.

## 1. Roles

*Change this when a role is added, retired, or handed to a different kind of session.*

- **Coordinator.** Connor's planning chat, on whatever device he is holding. Owns the family plan, the spec, `AGENTS.md`, and this file's structure. Decides what the next bounded task is and who takes it. Writes the prompts below. Never edits Swift.
- **UI writer.** A Claude Code session in the main checkout, `~/Desktop/Projects/catch-5`. Owns `Sources/CatchFiveUI/`, `App/` and `Tests/CatchFiveUITests/`. Works the family plan's increments in order, one slice at a time, with the simulator open so Connor can watch.
- **Engine writer.** A Claude Code session in a worktree (section 3). Owns `Sources/CatchFive/`, `Sources/CatchFiveDemo/` and `Tests/CatchFiveTests/`. First job: the bot bank (D58).

One session may hold both writer roles, one after the other, never both at once on the same files. Today (September 13, 2026) that is the arrangement: one session, the coordinator on another device.

## 2. Start of a session

*Change this when a check proves useless or a new one saves a session from a bad start.*

1. Confirm you are on this Mac, not a cloud checkout: `hostname` and `pwd` say so.
2. `git status --short` is empty, or every line is explained by the last log entry below.
3. You are on a short-lived branch off `main`, named for the task (`ui/trump-captions`, `engine/bot-bank-01`). Never on `main` itself, never on a historical branch.
4. Read your row in the family plan's progress table (section 8) and the last two entries of the log below.
5. Claim a simulator by name and say so in your first message. Current devices: `Catch 5 Wood`, `Catch 5 iPhone`, `Catch 5 UX Review`, `Catch 5 SE`. Shut it down when you stop.

## 3. Adding or removing the engine worktree

*Change this when the worktree location or naming changes.*

Desktop is iCloud-synced, so worktrees live under `~/Developer/active/`, which is not. Create one from `main` in one line:

```bash
cd ~/Desktop/Projects/catch-5 && git worktree add ~/Developer/active/catch-5-worktrees/engine -b engine/<task> main
```

Remove it when the branch has merged:

```bash
cd ~/Desktop/Projects/catch-5 && git worktree remove ~/Developer/active/catch-5-worktrees/engine && git branch -d engine/<task>
```

A worktree isolates files only. It shares the simulator, the Mac's CPU, and the saved game inside any simulator device. Two writers never point at the same simulator.

## 4. The verification turn

*Change this when a lighter check becomes enough or a heavier one becomes necessary.*

One heavy operation on the Mac at a time: `swift test`, `swift build`, the simulator build, a simulator launch, a phone install. Before starting one, check nobody else is mid-flight:

```bash
pgrep -fl "swift-build|xcodebuild|build-simulator"
```

If something is running, wait or ask in chat. When you finish a heavy run, say so in your handoff so the other session knows the Mac is free. The standard checks, from the repo root:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/build-simulator.py
```

After editing any page listed in `docs/learning-path.md`, refresh the in-app copies before testing: `python3 scripts/export-docs.py --app`, then `swift test --filter Explainer`.

## 5. Merge protocol

*Change this when the branch or PR habits change.*

- One task, one branch, one PR. Commits, pushes and PRs happen only when Connor asks.
- CI (`Tests` workflow: `swift-test` and `simulator-build`) must be green before merge. Squash-merge, delete the branch.
- One PR at a time. Squash merging means an old branch still looks "ahead of main" after it has landed; compare trees (`git diff main <branch>`), never commit counts.
- When a change needs both sides, the engine side lands first. The interface between them (a type or a function signature) is agreed through the coordinator before either writer starts.
- Docs pages are shared. A writer edits only the section that describes its own module (`types-and-functions.md`, `testing.md`, `decisions.md` entries it adds). The coordinator resolves anything else.

## 6. Copy-ready prompts

*Change these every time one is used and something was missing. They are templates, not scripts.*

### Start the UI writer on the next increment

```
You are the UI writer for Catch 5, in ~/Desktop/Projects/catch-5 on this Mac. Read AGENTS.md,
then docs/working-together.md, then section 8 of
docs/superpowers/plans/2026-09-05-iphone-16-ui-ux-gameplay.md. Confirm git status is clean and
create branch ui/<slice> off main.

Task: Increment <N>, slice "<slice name>", exactly as the plan describes it. Files you may edit:
Sources/CatchFiveUI/, App/, Tests/CatchFiveUITests/, and the docs sections for what you change.
Do not touch Sources/CatchFive/ or Tests/CatchFiveTests/; if you need an engine change, stop and
say what interface you need.

Rhythm: capture the current screen on simulator "<device>" first, make the one change, show me
before and after, run the relevant tests, then stop. Do not extend the pattern to other screens
until I have seen the first one. Do not commit or push. End with a log entry per section 7 of
working-together.md.
```

### Start the engine writer on the bot bank

```
You are the engine writer for Catch 5. Create the worktree per section 3 of
docs/working-together.md (branch engine/bot-bank-<NN>) and work only there. Read AGENTS.md and
docs/decisions.md entries D17, D18, D22 and D58.

Task: the flagged hand below. Rebuild it as a deterministic fixture in Tests/CatchFiveTests/ from
the replay log (initial deck, dealer, and the action list), write one test that names the bad
decision in plain words, and confirm the test fails against the current ComputerPlayer. Then
change ComputerPlayer only enough to pass it. Run the mirrored benchmark
(swift test --filter Benchmark) before and after; if the win rate drops, stop and report instead
of shipping. Files you may edit: Sources/CatchFive/, Tests/CatchFiveTests/, and the docs rows
for what you add. Do not touch the UI module. Do not commit or push.

The hand: <paste the replay log or describe the deal, the bids, and the play that was wrong>.
What Connor expected instead: <one sentence>.
```

### Coordinator: fold two handoffs into the plan

```
You are the coordinator for Catch 5. Read the last two entries in the log at the end of
docs/working-together.md and the progress table in section 8 of the family plan. Update the
table so each row states what is implemented, what is verified, and what Connor has approved,
as three separate facts. Then write the next prompt for each writer using the templates in
section 6, naming the exact slice, files and simulator. Do not edit Swift. Do not commit.
```

### Re-orient me

```
I opened a Catch 5 session and do not know where things stand. Before touching anything: read
AGENTS.md, section 8 of the family plan, the last three log entries in
docs/working-together.md, and run git status, git branch --show-current and git log --oneline -3.
Report in five lines: where we are, what is uncommitted, what the next slice is, which simulator
is free, and anything that looks wrong. Then wait.
```

## 7. When things drift

*Change this when a new kind of drift bites.*

- **A branch looks unmerged but is not.** `git diff main <branch> --stat`. If the diff is mostly deletions of files main has, the branch is older than main and already squash-merged. Do not merge it. Ask before deleting.
- **Files named `something 2.md` appear.** iCloud wrote a conflict copy. Both repo folders carry the exclusion attribute; check it with `xattr -p 'com.apple.fileprovider.ignore#P' .` (expect `1`). Verify a duplicate is byte-identical to what git has (`git hash-object <file>` then `git cat-file -e <hash>`) before deleting it. A duplicate `.swift` inside a target breaks the build.
- **Two sessions edited the same file.** Whoever has the smaller change re-applies it on top of the other's branch. The coordinator picks if it is unclear.
- **Someone wants to edit `AGENTS.md`.** Only the coordinator does. Writers propose wording in their log entry.
- **Something needs a decision Connor should make.** Ask once, in chat, with a recommendation first. Do not stop the whole task for it; finish what does not depend on it.

## 8. Session log

*Append, never rewrite. Newest at the bottom. Five lines: base commit, branch, files changed, checks run and skipped, next action. Keep each entry short; the plan's progress table is the summary.*

Local notes from before this log existed sit in the gitignored `notes/` folder on Connor's Mac (`handoff-2026-09-13-plan-reconciliation.md`, `handoff-2026-09-13-build-fix-and-status-correction.md`). They do not travel; everything that mattered from them is in the plan, the spec, or the history folder.

### 2026-09-13, plan reconciliation and repo cleanup (Claude Code, app session, main checkout)

- Base: `main` at `2befd92`; branch `docs/family-first-plan`.
- Changed: `AGENTS.md`, `README.md`, the family plan, the spec (new on main), `docs/history/` (new), `docs/catch-five-rules.md` attribution line, `docs/decisions.md` D58, `docs/build-and-run.md` iCloud note, `docs/roadmap.md`, `docs/learning-path.md`, this file. Both repo folders excluded from iCloud; 32 duplicate files and 5 stray files in `.git` removed.
- Checks: `git fsck` clean of bad refs; link check over changed pages; `git diff --check`; `swift test --filter Explainer`; rules parity test. Full `swift test` 149 of 149 was verified earlier the same day on this tree by the previous session; not rerun here.
- Skipped: no Swift changed, so no simulator build for this commit.
- Next: PR, CI, squash-merge; delete stale branches; current build to the simulator and Connor's phone; then Increment 1, first slice (beginner trump captions).

### 2026-09-13, evening: cleanup landed, game on the phone (same session)

- Base: `main` at `2a43bb8` (PR #42 squash-merged, CI green); working tree clean apart from this entry and the plan's progress row.
- Changed: origin now has only `main` (seven stale branches deleted); local stale branches and the unused engine worktree removed; GitHub description corrected; plug-and-pitch paused at `20334a4`. No Swift changed.
- Checks: simulator build installed and played to the first trick on `Catch 5 Wood` (three screenshots in `~/Desktop/Screenshots/`); signed device build with Xcode 27 RC installed and launched on Connor's iPhone 16 Pro after he trusted the developer profile.
- Skipped: full `swift test` not rerun (149 of 149 verified on this code earlier today).
- Next: Increment 1, first slice (beginner trump captions), from `main` on a `ui/` branch. Environment notes for whoever goes next: Xcode 27 RC lives at `~/Desktop/Personal/Xcode.app` (should move to `/Applications`); `/Applications/Xcode.app` is 26.6 and its app cannot open on macOS 27; the new `devicectl` prints hardware UDIDs, so `scripts/install-phone.sh` auto-detection needs its pattern updated and `DEVELOPER_DIR` pointed at Xcode 27.


### 2026-09-14, contrast measured and the phone install unbroken (Claude Code, app session, main checkout)

- Base: `main` at `fb5206a` (PRs #82, #83 and #84 squash-merged earlier today by a cloud session; that session left no entry here, and the plan's progress table still reads 149 tests and September 13 dates). Two branches off it, both committed and unpushed: `docs/deck-box-contrast-correction` at `b9778c4` and `fix/install-phone-device-detection` at `ed709bf`.
- Changed: the deck-box plan's contrast section, rewritten from sampled frames and moved off the header band onto the reading sheets, where the failure actually is; its section 5 prompt now names the bare-board heading as the case to prove, and the artboard count reads ten; new `scripts/contrast-sample.swift`; `docs/build-and-run.md` gained the sampler and lost four stale claims (a baked test count, the "no iOS platform so no destination" justification, the project file existing "for the day" device builds work, and the assertion that this Mac cannot sign for devices); `App/Explainer/docs/build-and-run.md` refreshed to match; `scripts/install-phone.sh` fixed on its own branch. No Swift in any target changed.
- Checks: `swift test` 159 of 159, three times. The header band measures 6.90:1 behind its text and the reading-sheet headings 4.40:1 median with a 3.84:1 floor, so the plan's old 3.10:1 was a colour literal that `WoodGrainView` never actually draws. `xcodebuild -showdestinations` lists iOS 26.5 and 27.0 destinations. Built, signed, installed and launched on the iPhone 16 Pro (iOS 27.0) with Xcode 27.0, confirmed running by `devicectl`.
- Skipped: the reading sheets were measured on the tutorial only, not `ReviewView` or the rules pages; no accessibility, all-size or Dynamic Type pass; the install script's disconnected-phone warning path is unexercised; nothing pushed and no PR opened.
- Next: take section 5 of the deck-box plan into Claude Design (Connor's action), then `docs/export/Deck-Box.dc.html` and `docs/deck-box-spec.md` when a reference build returns. Environment corrections to the entry above: Xcode 27.0 is at `~/Desktop/Xcode.app`, not `~/Desktop/Personal/`, and is still not excluded from iCloud despite being 3.6 GB; `/Applications/Xcode.app` is 26.6 and runs the whole command-line pipeline fine, so only device builds need 27; `install-phone.sh` now picks the newest Xcode and filters `devicectl` on the physical-iPhone row itself. A `.DS_Store` inside `App/Explainer` fails code signing, because the folder is bundled as a folder reference and git cannot see the file; the script now deletes it before each build.

### 2026-09-14, the records catch up with the repository (Claude Code, app session, main checkout)

- Base: `main` at `fb5206a`; branch `docs/status-reconciliation`. Asked to sort out the current state; the git state turned out to be healthy and the status documents did not.
- Changed: the plan's section 8 table, which said "No increment has started" while PR #43 had merged — Increment 1 now reads done, Increment 2 started and open as issue #53, with a line for the engine track and both "next request" prompts rewritten; `AGENTS.md` and `README.md` Current Status, re-anchored from `131c941`/PR #41 to `fb5206a`/PR #84; `docs/architecture.md` 149 to 159 tests; `docs/device-install.md`, which still claimed this Mac had no code-signing identity; the two `App/Explainer/docs/` mirrors of those pages, hand-edited to stay byte-identical; this file. No Swift changed.
- Checks: `swift test` 159 of 159 passed, which is also the number the corrected pages now carry (counted independently as 159 `@Test` annotations under `Tests/`). `swift test --filter Explainer` 3 of 3, confirming the bundle mirror. Read-back greps found no surviving "149 tests", "No increment has started" or `131c941` claim. Branch and worktree state read from `gh` and `git`, not from the documents being corrected.
- Skipped: no Swift changed, so no simulator build, no simulator run and no phone re-install for this commit. Editing the two mirrored pages by hand rather than running `scripts/export-docs.py --app` deliberately avoided regenerating all 25 diagram PNGs for a text-only change; the fence counts are unchanged, so the existing PNGs stay valid and the bundle test proves it.
- Next: four things stay open and were not touched here. Two finished branches off this same commit have never been PR'd, so CI has never run on them (`tests.yml` fires only on pull requests and pushes to `main`): `docs/deck-box-contrast-correction` and `fix/install-phone-device-detection`. Both carry their own 2026-09-14 entry for this log, so entries will land out of date order once they do; expect a conflict at the foot of this section and keep both, in order. The merged `engine/five-discount` worktree is still mounted at `~/Developer/active/catch-5-worktrees/engine` and is safe to remove — `git diff origin/main engine/five-discount -- Sources Tests` is empty. And `.build` is 439 MB on the iCloud-synced Desktop with no ignore xattr, while `work/` has one; Xcode 27.0 is still 3.6 GB on the Desktop, unexcluded.
