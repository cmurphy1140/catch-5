# Catch 5 handoff for Codex

Written 2026-09-05 by the Claude Code session that merged PRs #24–#38. Untracked on purpose: not committed, not part of any branch.

## 1. Repository and location

- **Remote:** `git@github.com:cmurphy1140/catch-5.git` (GitHub `cmurphy1140/catch-5`)
- **Session checkout:** `/Users/connormurphy/Desktop/Projects/catch-5/.claude/worktrees/modest-chebyshev-d173ce`, a git worktree on branch `main` at `32619de`, equal to `origin/main`, working tree clean.
- **Main checkout:** `/Users/connormurphy/Desktop/Projects/catch-5` (this folder), on branch `claude/dealer-draw` at `c2172db`, with uncommitted changes described in section 3.
- **Associated PRs:** none open. Merged today: #21 and #23 (this session's own work), #22 (another Claude session), and #24–#38 (merged by this session on request). The repository has no open pull requests.

## 2. Completed work

**By this session earlier today (on main):**

- PR #21 (`845b940`): felt playing area under an oak header band with a frown-shaped bottom edge, oak behind the tutorial and reading sheets, larger text app-wide (`Theme.textBoostSteps` = 2 Dynamic Type steps, applied at `TableView`'s root so sheets inherit it), solid full-width 64 pt auction pills, trump and contract at the table's top-left, a deck at the top-right, unfilled seat tiles, and the discard-and-redeal animation with a scheduler pause (`TableScheduler.plan` returns `dealing`). Decisions D35, D37.
- PR #23 (`283918a`): trump line as plain gold text, shorter tutorial copy, one-line tutorial seat tiles.
- `2e9a4d5`: deleted `changes.md` (a merge note for the other session) directly on main at Connor's request.
- `32619de`: regenerated `CatchFive.xcodeproj` with `xcodegen generate` because PR #33 deleted the `App/Explainer/*.dc.html` files the checked-in project still referenced, which broke the device build (CI's simulator job does not use the Xcode project, so it did not catch this). Pushed directly to main.

**Merged today on Connor's instruction ("merge PR 24 through 38"), all authored by another Claude session:**

- Stack, in order: #24 pause under covers and save-failure handling; #25 measured hand and seat layouts with a two-row fallback; #26 refusal reasons and 9-and-out confirmation; #27 hand-end verdict and arithmetic; #28 accessibility and a one-haptic policy; #29 launch and restoration polish; #31 named suit pills with trump preview; #32 stack code-review fixes; #34 opponent moods; #35 tossed card landings; #36 dimmed unavailable cards and suit-to-follow status; #37 discard pile under the deck; #38 first dealer drawn for.
- Standalone: #30 rules sheet as a guided walk with engine-judged trials; #33 the docs read natively in-app (`MarkdownDocument`, `ExplainerLibrary`, bundled copies under `App/Explainer/docs` and `App/Explainer/diagrams`).
- Because the stack was squash-merged rung by rung, each later PR conflicted on lines its predecessor introduced. Resolution: merge `origin/main` into each branch and take the branch side (verified safe: main held nothing the stack lacked, PR #23 included). For #30 and #33, keep-both merges: decision entries interleaved by number (D40–D55, with D46 and D50 from #30 and D49 from #33), test blocks concatenated, doc rows combined. The merge commits are in the merged history.

**Effect on the app:** the table pauses under covers, refuses moves with reasons, confirms 9-and-out, explains hand outcomes, honours motion and contrast settings, previews trump choices, animates tosses and discards, draws for the first dealer, has a walk-through rules sheet, and reads the living docs natively. Test count went from 111 to 144.

## 3. Uncommitted work

- **Session worktree (`modest-chebyshev-d173ce`):** nothing staged, unstaged, or untracked. Fourteen local-only helper branches named `stack/<name>` (for example `stack/hand-targets`) are merged leftovers, safe to delete, left in place because deleting was not authorized.
- **Main checkout (this folder), not touched by this session and not inspected:** on `claude/dealer-draw` at `c2172db` with modified `.gitignore`, `AGENTS.md`, `README.md`, `docs/build-and-run.md`, `docs/device-install.md`; deleted `changes.md`; untracked `catch5-redesign-brief.md` and this file. Presumably Connor's local documentation cleanup. The remote branch `claude/dealer-draw` was deleted by the merge loop after #38 landed (the intention was to keep it; the script deleted it). The local branch is intact and its content is on main via #38.

## 4. Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` on main at `e0e9303`: **144 tests pass**. Also run on every intermediate branch before pushing (115, 117, 120, 121, 124, 125, 130, 131, 132, 133, 134, 137, 142, 144; all passing).
- GitHub Actions on main at `e0e9303`: **success** (jobs `swift-test` and `simulator-build`). Every merged PR had both jobs green on its final head.
- PR #33's test `explainerBundleMatchesTheDocsAndTheirDiagrams` requires `python3 scripts/export-docs.py --app` after any change under `docs/`; run as part of that merge.
- Device build of main at `32619de` succeeded, installed and launched on the iPhone.
- **Not checked:** no simulator run of the post-stack build; no hands-on pass of the merged UI on the phone or simulator; the interleaved decision entries were sorted by number but not proofread; conflict resolution in `Sources/` took the branch side wholesale without line-by-line review; the Reduce Motion and VoiceOver passes that PR #22's own test plan left unchecked.

## 5. Remaining work

- **Phone:** the iPhone now runs main at `32619de` (installed and launched after the stack merge). Settings, save and history survive upgrades (the decoder uses defaults for missing keys). Reinstall with `scripts/install-phone.sh` from a checkout on main.
- **Docs numbering:** confirm `docs/decisions.md` reads correctly around D40–D55 after the interleave, and that the per-layer counts in `docs/testing.md` still add to 144 (the total and the L6 line were updated; other layers were not recounted).
- **Housekeeping:** delete the `stack/*` local branches in the session worktree; optionally re-push `claude/dealer-draw` if its remote is wanted back.
- **Known judgment calls:** the iPhone 16 family (393 pt) is the only verified layout target (D35); other sizes fall back to scrolling. The app-wide text boost is one constant.
- **Next planned direction per Connor:** "Plug & Pitch", keeping Catch 5 and adding a separate 9–5 rules preset. Not started, no branch created, repository not renamed.

## 6. Active resources

- **Worktrees:** the main checkout (this folder, on `claude/dealer-draw`, dirty) and the session worktree (`modest-chebyshev-d173ce`, on `main`, clean). An earlier worktree `catch-5-app-2985e8` no longer exists.
- **Simulators:** two custom devices exist, "Catch 5 iPhone" (`02419047-584C-4D69-A0F1-6F33C2C5F0F2`, shared with the other session) and "Catch 5 Wood" (`AF208C60-6B4E-47A9-9AD5-5D6CAE18F5C7`, created to avoid the two sessions overwriting each other's settings and saves). Neither was booted at handoff time; no app process was running.
- **Background tasks:** none running. The stack-merge jobs completed.
- **Build outputs:** `work/simulator-build/` and `work/derived/` in the worktrees are gitignored scratch.

## 7. Important context

- **Project instructions:** `CLAUDE.md` is a symlink to `AGENTS.md`; edit `AGENTS.md`. Rule: any commit that adds, renames or removes a type, function, phase or test must update `docs/types-and-functions.md` (and related pages) in the same commit, and design choices get a numbered entry in `docs/decisions.md`. The next free decision number is D56. Verification command is in section 4.
- **Xcode project:** `CatchFive.xcodeproj` is generated from `project.yml` by `xcodegen generate`; regenerate and commit it after adding or removing any file under `App/`, since only the device build uses it and CI does not.
- **Docs bundle:** `App/Explainer/docs/*.md` and `App/Explainer/diagrams/*.png` are generated copies; regenerate with `python3 scripts/export-docs.py --app` whenever `docs/` changes, or the test in section 4 fails.
- **Interfaces changed today:** `ScoreBarView` no longer takes `trump`, `contract`, `youDeal`; `TableSurface` takes `toast:` and hosts the message line; `TableScheduler.plan` returns a three-element tuple `(hold, leading, dealing)`; `HandFanView.dealOrigin` is `nonisolated static` (CI's Swift 6.1 treats view statics as main-actor isolated; the local Xcode does not). The stack added many more; see `docs/types-and-functions.md`.
- **Saved-game behaviour:** replay-log saves keep format version 1; PR #29 keeps a corrupt save aside rather than discarding it; settings decode with per-field defaults, so older files load and pre-cast seat names migrate to the cast.
- **House rules:** `docs/catch-five-rules.md` is authoritative and now includes how the first dealer is drawn (#38); `RulesText` is tested against it.
- **CI:** `.github/workflows/tests.yml` runs `swift test` and the simulator bundle build on every PR and push to main, with a `.build` cache and cancel-in-progress.

## Status at handoff

The authorized task, merging PRs #24 through #38, is finished and verified. Nothing is still running: no background jobs, no builds, no simulators booted. The only items awaiting action are the housekeeping listed in section 5.

## Working agreement (also proposed for AGENTS.md, uncommitted on Claude's side) for multiple agents

Claude Code and Codex both work on this codebase, often on the same day. These rules exist because sharing a machine and a repository without them produced overwritten simulator saves, a checkout pinned to another agent's branch, a fifteen-PR stack that conflicted at every rung, and a Mac at a load average of 200.

**Lanes.**
- Each agent works in its own worktree and branch. Never share a checkout, and never check out `main` in a folder another agent is using. Pull `main` fresh at the start of every task.
- Each agent uses its own simulator, named after itself ("Catch 5 Wood" is Claude's), and shuts it down when idle. Never the same device UDID.
- Catch 5 (this repository) takes UI refinement and reusable presentation components only. New product features, rule presets, save-format changes, branding and architectural work go to Plug & Pitch. If a request crosses that line, say so and propose a Plug & Pitch backlog item instead.

**One heavy step at a time.** Only one `swift test`, `xcodebuild`, `scripts/build-simulator.py` or `scripts/export-docs.py` runs on the machine at once. The agent whose turn it is verifies, opens a pull request, and stops; the other agent starts its heavy steps only after that PR's CI is green. Editing in parallel is fine; building in parallel is not. Quit Chrome-based tools and keep Xcode closed while building. `~/Developer` must not sit inside iCloud Drive.

**Pull requests.** One independent PR per change, based on `main`, squash-merged after CI. No stacked PRs: if work needs several PRs, land the first, rebase the next onto `main`, and repeat. Never delete a branch that another open PR uses as its base.

**Shared files.** Every design choice takes the next free number in `docs/decisions.md`; reserve numbers in the PR body so two agents do not reuse one. Any commit touching `docs/` reruns `python3 scripts/export-docs.py --app`, and any commit adding or removing files under `App/` reruns `xcodegen generate` and commits the project. Every task ends with a handoff note (repository, branch, commits, verification, what is unverified, what is still running) written for the other agent.

