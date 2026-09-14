# Ideas kept, not scheduled

Everything worth remembering that nobody has agreed to build. Split out of the requirements spec on
September 14, 2026: a requirement is something the app must do, an idea is something it might.

**Nothing here is authorised.** An idea earns a requirement identifier when it is chosen, and only
then does it move into [the spec](../catch5-ui-redesign-spec.md).

Add freely. Connor volunteers these as they occur to him and they are captured the same day, with
the open questions attached so the thinking is not lost.

Revisit these after the core flow works comfortably. Implement only the subset chosen for a
later pass. Keep existing useful behavior; do not remove working polish to match this schedule.

### E.1 Interaction refinements

**D1 — Keep the hand steady.**
When hints, bid controls, or status messages appear, avoid unexpected movement of cards under
the player's thumb. Reserve space or use bounded help surfaces. Normal dealing, drawing, and
re-fanning after a card leaves can still move cards intentionally.

Future check: open and close hints during selection; confirm the selected card and its touch
position remain predictable. This extends R21/R25; fixing currently hidden controls remains core.

**D2 — Distinguish selected from recommended.**
Lift the player's selected card; use a separate subtle marker for a beginner recommendation.
Give each state an accessible description and avoid relying only on color. A suggested card
must never look already chosen or auto-commit a move.

Future check: request a hint while a different card is selected; both states remain understandable.

**D3 — Give each decision one obvious next action.**
Use specific confirmation labels such as “Play J♠,” “Discard 3,” and “Deal next hand.” Keep
secondary choices available without competing with the next action. This generalizes the
existing discard and results labels; it does not add another control wherever one already exists.

Future check: each phase can answer “What will this button do?” without additional instructions.

**D6 — Explore a simpler select/deselect/confirm model.**
Proposed replacement for R15's second-tap-to-play behavior:

1. Tap a legal card to select and lift it.
2. Tap the selected card again to deselect it.
3. Tap another card to change selection; in discard, toggle membership in the discard set.
4. Commit only with the labeled Play or Discard button.

This is an interaction experiment for a later pass, not an instruction to implement now. If
adopted, update R15, the shared-mode behavior, and any drag gesture together. A drag must not
silently bypass explicit confirmation. Never support second-tap play and second-tap deselection
at the same time. Validate convenience and accidental-move frequency before choosing the model.

### E.2 Feedback and motion

**D4 — Briefly explain consequences.**
Use short outcome messages such as “Otto won the trick” or “Contract missed · −4,” using the
actual engine result and score change. Reuse the existing status area rather than adding a
permanent HUD label. Keep the factual outcome available in results after the message disappears.

Future check: messages clarify what happened without blocking play or requiring a review screen.

The following earlier motion requirements retain their IDs, but new animation work is deferred.
Build against settled geometry, respect Reduce Motion, and do not delay core usability fixes.

**R18 — Add bidding animations.**

- Bid value change: number rolls/counts rather than hard-cutting.
- Bid committed: a chip flies from the bidding control to the bidder's avatar and settles there,
  staying visible as the bid badge.
- Pass: avatar's badge fades in as a muted "Pass" then dims the avatar slightly.
- Winning bid: brief gold pulse on the winner's avatar before transitioning to trump selection.
- Keep all of these ≤ 350ms. Bidding is a rhythm — don't add drag to it.

**R5 — Dealing and discard animations.**

*Opening deal:*
- Cards fly one at a time from the deck position to each player in seat order.
- ~60–80ms stagger per card, ~250ms per card flight, spring easing.
- Opponent cards land face-down; player's cards flip face-up on arrival, or fan up together at the end.
- Full deal completes in roughly 1.5–2.0s. **Must be skippable** — any tap fast-forwards to the
  final state. Non-negotiable: this animation plays every hand, so it can never feel like a wall.

*Discard:*
- Selected cards fly from the hand to the discard pile position (R3), staggered ~50ms.
- Hand closes the gap and re-fans after the last card leaves.

*Replacement draw:*
- New cards fly from deck to hand, reusing the deal animation timing.

Implementation notes: prefer `matchedGeometryEffect` between hand and pile namespaces over manual
offset math. Respect `@Environment(\.accessibilityReduceMotion)` — when on, cross-fade instead of
fly, keeping the same durations so game logic timing is unaffected.

### E.3 Reading, teaching, and developer-learning refinements

The following earlier refinements are retained for a later pass. Core readable text and complete
hint access remain required under R22/R26; a broader visual or editorial redesign can wait.

**R27 — Shorten teaching and use consistent player names. Medium.**

- Present one immediate lesson instruction or decision at a time. Put supporting rules and tactics
  behind an expansion control instead of requiring a long read before the first interaction.
- Use the same player names as the table: “Rue is dealing. Tap the player who receives cards first.”
  If compass directions matter to the lesson, introduce “Rue (East)” explicitly before using East.
- Keep lesson progress and navigation discoverable; long lesson tabs must scroll without trapping
  the reader or concealing the current lesson.
- In results, follow R7–R10's collapsed structure. Within an expanded trick, show cards and outcome
  first, then a concise explanation. Avoid a third disclosure level.

**Acceptance:** The learner can identify the next action and referenced player without translating
between unexplained names/directions or reading a long introductory block.

**R28 — Unify reading surfaces and typography. Medium.**

- Preserve green felt, ivory cards, muted gold, and serif titles. Keep wood as table framing;
  reduce its visual prominence behind tutorials, statistics, and results using quiet opaque surfaces.
- Define shared typography roles, panel colors, spacing, dividers, and control styles. Serif titles
  and sans-serif body text can coexist deliberately; avoid unrelated screen-by-screen treatments.
- Apply R16's flat grouped rows instead of adding nested cards or capsule backings. This is a
  readability refinement within the existing identity, not a new visual theme.

**Acceptance:** Compare table, tutorial, statistics, and results side by side. Shared roles look
consistent and wood texture does not compete with body text.

**R29 expansion — revisit the build process.** Keep the main-menu entry and existing content
now. Later, expand its architecture overview, a real card-action walkthrough, design tradeoffs,
verification examples, and source references as described in R29. Keep details collapsible and
repo-grounded so learning stays useful without adding clutter to gameplay.

### E.4 Lightweight usability observation

**D5 — Watch a new player use it without coaching.**
Ask someone unfamiliar with the app to start a match, make a bid, play a card, leave, and resume
the saved match. Observe before explaining. Note hesitation, wrong taps, missed controls, and
places where they misunderstand the next action; choose the next refinement from those findings.

A short session is enough to identify candidates. Do not present a single person's experience
as proof that the design works for everyone. Any discovered blocking usability bug moves back
to core fixes; optional polish stays in this group.

---

### E.5 Pinned by Connor, September 13, 2026

Ideas Connor wants kept, not scheduled. No requirement IDs; they earn one when chosen.

- **Opponent personalities.** Hazel, Otto and Rue each get a bidding temperament and a line or two of table talk, drawn only from public events the way the existing moods are (D-numbered mood decision). No hidden-card knowledge, no new rules.
- **Moments worth a small fuss.** Making 9-and-out; catching the Five off the bidder; setting the bidder; winning Game by one card value. A single restrained cue each, within the one-haptic policy, never a modal.

### E.6 Pinned by Connor, September 14, 2026

- **A loading screen.** The app currently has a native launch screen showing the icon. This is the
  idea of a proper one with something to look at while the table is set: cards being shuffled, the
  box opening, the felt unrolling. It must not add a wait that is not already there; an artificial
  delay to show off an animation is the opposite of the point.
- **Talking strategy with your partner.** A way, between hands, to tell your partner how you want
  them to play: lead trumps early, save the Five for me, bid more boldly, stop overtaking me.
  Standing instructions, not table talk during a hand, which at a real table is cheating. Each
  instruction would become a modifier on that seat's scoring in `ComputerPlayer`, applied to the
  partner only. It teaches the game's strategy vocabulary by letting a player use it, gives Otto a
  character you can argue with, and reuses the same terms the bot bank (D58) is already tuning.
  Open questions: whether instructions persist across matches, whether opponents may be instructed
  (they may not), and whether the partner may refuse.
- **A different view from the table** was raised and dropped the same day as overkill. Recorded so
  it is not proposed again without a reason.

### E.7 Counting at the table, pinned September 14, 2026

Two ideas from Connor about the information a real Catch 5 table shares out loud. They belong
together: the first supplies the numbers, the second gives the player somewhere to keep them.

- **Every seat announces how many cards it discards.** Once trump is named each player discards
  their non-trumps and draws back to six, so the count they announce says how many trumps they
  held. At a real table this is said aloud and everyone uses it: whether the bidder is strong or
  bluffing, whether leading trumps helps your partner or the other side, and whether the Five can
  be sneaked. The app currently shows only the human's own count, and the engine pools every
  discard into one pile with no record of who threw what, so the computer plays blind to
  information every person at the table has. Engine side first: record the counts, carry them in
  `PlayerView`, teach the strategy to read them. Then the table announces each one.
- **A trump counter the player increments themselves.** A place to keep a tally of trumps played,
  which the app never advances on its own. This does not conflict with R4 (no automatic number
  tracking) or R20 (no card-count displays): counting stays the player's skill, and the app only
  offers somewhere to write it down, the way a notepad differs from a calculator. Open questions:
  whether it resets each hand automatically, whether it can be corrected downward, and whether it
  appears at all outside beginner mode.

### E.8 The deck-box direction, agreed September 14, 2026

Connor found a concept treating the app as a premium deck box: deep burgundy boards, gold foil rules,
embossed card suits, cloth texture, with green felt visible inside the frame. Agreed scope, after
his correction that it is neither a full re-skin nor pure refinement:

**The frame becomes the box.** Header band (currently drawn oak), screen edge, reading sheets, and
the main menu, which becomes the closed box with its title in gold foil.

**The game stays on felt.** Playing surface, ivory cards, green backs, seat tiles and portraits,
auction pills, gold's five meanings, large text, and the table-first layout.

Why this split holds: it changes what surrounds the game without touching what a player reads while
deciding. The two surfaces it touches, the header and the main menu, are the two already under
active work, and the felt is the part Connor said he liked.

The aesthetic north star in `AGENTS.md` was amended the same day; it previously named drawn oak for
the header and reading sheets, which is precisely what changes.

Pipeline agreed: explore in Claude Design, implement directly in SwiftUI. The Figma MCP is installed
but unused for now — it reads designs back and only earns its place if a Figma file is going to be
maintained, which is a decision for later.

### E.9 The phone as the control surface, pinned September 14, 2026

From a setup document Connor brought on September 14. Its useful half is a working shape: the Mac is
the engine room, the iPhone is both the control surface and the real test device. Connor plays a hand
on the phone, notices something, describes it from the phone, a writer session on the Mac traces it
and changes the code, the Mac builds and installs, and he plays the same hand again. The loop closes
on the device the game is actually played on, which is where the friction the family feels lives.

**Most of the setup it describes is already done and better recorded.** See
[device install](device-install.md): the Apple ID Personal Team, Developer Mode, the trust prompt and
the seven-day expiry are all there, with Connor's team id in `project.yml`, his phone's identifier,
and commands verified on the Mac on September 5. Two limits that document has and the source does not:
a free team may keep only three apps installed at once, and the iOS platform download is the thing
that actually blocks a device build. `scripts/install-phone.sh` already does the whole build, sign,
install and launch in one command, in about fifteen seconds.

**Corrections, so the source document is not followed into a mistake.** It names `Catch-5.xcodeproj`
and a `Catch-5` target and says to set signing in Xcode's interface. The project is
`CatchFive.xcodeproj`, the scheme is `CatchFiveApp`, and the project is generated by `xcodegen` from
`project.yml` — signing set through the interface is overwritten by the next `xcodegen generate`,
which is why `DEVELOPMENT_TEAM` is recorded in `project.yml` instead.

**What is actually new, and worth keeping:**

- **The loop itself, written down.** Play, notice, describe, change, rebuild, play the same hand
  again. Nothing in the repository states this as the way a UI change gets judged, and every
  increment of the family plan ends in a judgement only the phone can make.
- **A discipline for describing what was seen.** The source ends with a prompt template whose good
  part is its order: investigate before changing, name the files and state involved, say the likely
  cause, make the smallest fix, then say what to test on the phone afterwards. That matches the
  repository's existing sketch, inspect, small change, play, verify workflow and could be written as
  a short section in [working together](working-together.md) rather than a separate document.
- **Remote access to the Mac** as the step that makes the loop work when Connor is not sitting at it.
  Untested; the Mac must stay awake, online and signed in, and a cloud checkout is not the same
  machine, which is a distinction the repository already has to make.

**Out of scope, and noted so it is not mistaken for a plan.** The source's later stages are
TestFlight, the Apple Developer Program at ninety-nine dollars a year, and a build pipeline that
uploads to it. Project scope in `AGENTS.md` excludes App Store and TestFlight work, hosting, paid
services and new spending from the family UI effort, and the finish line is a game the family enjoys
on Connor's phone. [Device install](device-install.md) already records what an archive would take if
that ever changes. Nothing here argues for paying yet.

**Open questions.** Whether the seven-day resign is actually annoying enough in practice to matter;
whether the loop needs anything written down beyond the working-together page; and whether the
remote-Mac step is worth setting up before the increments that would use it exist.

**The document's own framing is stale in one respect.** It is written around Codex, which
`AGENTS.md` records as no longer used. The shape survives the tool; the idea above is written for
whichever session is doing the work.

### E.10 Counting tools you operate yourself, pinned September 14, 2026

E.7 pinned a trump counter the player increments themselves. Talking it through on September 14
turned that one idea into a family, and produced the test that decides whether any of them belongs:

> The app may hold a number you computed. It may never compute a number you would have to hold.

Notepad, not calculator. The corollary is the useful half: **inference is the skill, arithmetic under
memory pressure is the tedium**, and the tedium crowds out the skill. A player loses track of Game
because they are busy adding, not because they cannot tell who is ahead.

**A Game pad, kept as a differential.** Game is one point, to whichever side captured the greater
card value (10 = 10, ace 4, king 3, queen 2, jack 1, everything else nothing). The rule that decides
the design is that **the pool cannot be known**: undealt cards stay out of play, every player
discards non-trumps and draws back to six, so the Game value actually in play varies each hand and
no one at the table can total it. A full deck holds eighty; a hand holds an unknowable fraction of
that. Absolute counting is therefore meaningless and only one question is answerable — *are we
ahead?* So the pad is one signed number. Take a ten, tap plus ten; they take an ace, tap minus four;
`+7` means seven up on Game with tricks still to play. One number, one tap per counter, and every
input stays the player's: noticing that the card fell and to whom is exactly the part that is skill.
The hand-end card already names the Game count and its winner every hand, so this is about the part
of the hand where nothing is shown, not about the result.

**Void marks.** When a seat fails to follow suit, everyone at a real table clocks it. Tap the seat,
mark the suit. This is the purest case of the test: public information the player saw, held by the
app so it need not be carried in the head. The app deriving voids would break R4; the player
recording them does not.

**After the hand, what you could have known.** The one worth building first, and it is not live at
all. At hand end, say what the hand made knowable: *"By trick four Rue had shown void in hearts and
clubs, so the Five was safe to lead."* It reads the replay log the bot bank (D58) already needs,
never touches a live decision, so it sits outside R4 and R20 rather than in tension with them, and it
makes a player better instead of making bookkeeping easier. It is also the version that gets a family
member learning without Connor at their shoulder.

**The boundary that is easy to cross by accident.** A private mark is bookkeeping. Anything that
*tells the partner* during a hand is a rules change wearing a feature's clothes, and E.6 already
draws that line at table talk. Discard counts are announceable because the house rules make them
public; "the last trump is gone" is not.

**How it is reached, which is the open question.** Connor's first instinct was a toggle for advanced
players, which is a direct answer to E.7's question of whether the counter appears outside beginner
mode. Two readings, and they disagree:

- **An affordance, not a mode.** A pencil glyph on the status line beside last trick and hint, which
  already sit there at a 44 pt hit area, opening the pad on demand. Zero footprint until reached for,
  so the clutter objection needs no switch to answer. It leaves D56's single guidance setting intact,
  and it does not hide the notepad from the people learning to count — the spec calls counting a
  skill of the game, and a skill needs practice. A real table has no modes; anyone may pick up a
  pencil.
- **A setting for advanced players.** Right if the pad has to be *visible* to be useful — a
  differential glanced at mid-trick without opening anything. Persistent screen space is furniture,
  and furniture does need a switch. The cost is that the guidance toggle stops meaning one thing,
  since beginner mode off currently means a cleaner table, not a fuller one.

Which is correct depends on whether the pad works when it is closed, and that is settled by drawing
or prototyping it, not by arguing it.

**What none of these become.** No display of cards remaining or seen (R20), no tally the app advances
on its own (R4), no derived voids, and no hint delivered to a partner mid-hand. Every number here is
entered by the player or it does not exist.

**Open questions**, in addition to E.7's three. Whether the Game pad and the trump counter are one
pad or two. Whether a differential needs an undo for a mis-tap, given that a wrong number is worse
than no number. Whether the after-the-hand coach belongs in the existing hand review or beside it.

**What the September 14 research says about this.** Three deep-research runs judged an *automatic*
card tracker, which is not what this is; one of them proposed a player-entered count checked by the
software as the better design, which is this pad plus a verification step. They still disagree on
whether to build it at all soon: one says keep it outside the next six increments until a real novice
is seen abandoning the game over memory load, another says build it as a beginner-only fading
scaffold. See the [playability research](history/2026-09-14-playability-research.md).
