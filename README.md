# Catch 5

A SwiftUI iPhone app for Catch 5 (Pitch with Fives), using the [house rules](docs/catch-five-rules.md): partnerships, first to 25, and a 9-and-out bid.

## Related repositories

This is one of two repositories, and they are deliberately separate.

| Repository | What it is |
|---|---|
| **catch-5** (this one) | The single-game subset: Catch 5 on its own. UI and gameplay polish happens here first. |
| [plug-and-pitch](https://github.com/cmurphy1140/plug-and-pitch) | The multi-preset app, where a match carries a versioned rule set so a variant is a preset rather than a rewrite. Catch 5 and the planned 9–5 are both presets there. |

Catch 5 is finished here first: the six increments of the [family-first plan](docs/superpowers/plans/2026-09-05-iphone-16-ui-ux-gameplay.md). Then this repository's `main` is ingested into plug-and-pitch in one pass and new product work moves there. plug-and-pitch is not a fork to be merged back into this one; it sits on an older base (`c2172db` plus PRs through #38), so check both before assuming a feature is missing. Local checkouts sit side by side at `~/Desktop/Projects/catch-5` and `~/Desktop/Projects/plug-and-pitch`.

## Current Status

**Current focus: make Catch Five enjoyable for Connor's family through small UI/UX improvements.** Start with the [detailed family-first plan](docs/superpowers/plans/2026-09-05-iphone-16-ui-ux-gameplay.md). Customizable Pitch variants, paid services and App Store distribution are deferred.

`main` has the solo game, three computer opponents, Easy/Standard, save/resume, hints, hand review, statistics, settings and optional lessons. Returning players reach the main menu. A September 12 iPhone 16/iOS 18.6 simulator review of `131c941` (the code of PR #41, the current `main`) completed the navigation flow and one hand; broader accessibility, full-match and real-device verification remain separate. Implement from `main`; the `claude/dealer-draw` branch is historical.

The [device installation guide](docs/device-install.md) records an earlier local installation; it does not establish which build is currently on the phone. Current test results come from running the checks below.

## Start here

- To understand the game: [house rules](docs/catch-five-rules.md).
- To understand the code: [documentation index](docs/learning-path.md).
- To run the app: [build and run](docs/build-and-run.md) or [install on a phone](docs/device-install.md).
- For Claude Code session instructions: [AGENTS.md](AGENTS.md). `CLAUDE.md` links to that same file, so edit only `AGENTS.md`.
- For how sessions work together, the copy-ready prompts and the session log: [working together](docs/working-together.md).
- For ideas kept but not scheduled: [ideas](docs/ideas.md).

## Where things live

| Location | Purpose |
|---|---|
| `Sources/CatchFive/` | Game rules, scoring, computer decisions, and saving; independent of the screen code |
| `Sources/CatchFiveUI/` | Screens, cards, animations, settings, and tutorial; `GameModel` connects them to the engine |
| `Sources/CatchFiveDemo/` | Optional terminal demonstration of the engine |
| `App/` | iPhone app entry point, icon, privacy information, and bundled offline reading pages |
| `Tests/` | Automated rules and view-model checks |
| `docs/` | Current explanations and specifications; start with the index |
| `docs/history/` | Earlier briefs and merge notes, retained as historical context |
| `docs/superpowers/` | Dated design specifications and implementation plans; their existence does not mean they are complete |
| `scripts/` | Build, install, icon-generation, and documentation-export helpers |
| `notes/` | Local task notes worth keeping, including the three-task workflow trial; ignored by Git |
| `work/` | Local builds, exports, logs, and reference artifacts; ignored by Git |

You usually need only the relevant source files, their tests, and the matching documentation. There is no need to read every folder before making a bounded change.

### Build and tool files

- `Package.swift` describes the Swift modules and tests. The package has no external dependencies and targets iOS 17+ / macOS 14+.
- `project.yml` describes the iPhone application's Xcode settings; XcodeGen produces `CatchFive.xcodeproj` from it. Keep both; they are used by the device build workflow.
- `.github/` holds automatic test and simulator-build checks.
- `.git/` holds version history; `.gitignore` identifies local files Git should not track. `main` advances by squash merge, so an old topic branch can look "ahead of main" while every line of it is already merged; compare trees with `git diff main <branch>`, not commit counts.
- This folder sits under the iCloud-synced Desktop and carries the `com.apple.fileprovider.ignore#P` extended attribute so iCloud leaves it alone (applied September 13, 2026, after iCloud wrote duplicate files into `.git`). After cloning to a synced location, reapply it: `xattr -w 'com.apple.fileprovider.ignore#P' 1 <repo folder>`.
- `.claude/` holds local Claude settings and any Claude-managed worktrees. A worktree is another working checkout: inspect its branch, changes, and active use before removal.
- `.build/`, `.swiftpm/`, and `.vscode/` hold build or local tool state. They are not application source.

### Documentation copies and local files

Edit the explanatory Markdown under `docs/`. The HTML in `App/Explainer/` is a separate, bundled snapshot used by the app's offline reader. The former identical HTML copies in `docs/export/` were removed; the unique earlier tutorial proposal is preserved in `docs/history/`.

The export script writes PDFs and diagrams to `work/docs-export/`. That process does not automatically refresh the app's HTML snapshot; see [the documentation index](docs/learning-path.md).

Build helpers retain their existing output paths: `work/simulator-build/` for simulator builds and `work/derived/` for phone builds. Logs live in `work/logs/`; older build folders, screenshots, and a design ZIP may also be present. Inspect individual items before cleanup. Do not delete all of `work/` blindly, and preserve `notes/` separately. Ignored files are local, not backed up by Git.

## Verify and run

From the project directory on this Mac:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

For the simulator build:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/build-simulator.py
```

For an optional text match:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run catch-five-demo
```

Add `--computer` to the demo command for computer play, or `--save-roundtrip` for a save/restore demonstration. Installation and launch instructions are in [build and run](docs/build-and-run.md). Device installation uses `scripts/install-phone.sh`; read [the device guide](docs/device-install.md) first.

Tests do not replace simulator/device checks for visual layout, motion, and accessibility. Update the matching living documentation when changing types, functions, phases, or tests. Commits require an explicit request.
