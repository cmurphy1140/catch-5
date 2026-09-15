# The deck box: design plan and canvas brief

Draft, 2026-09-14. Not authorised for implementation.

This page turns [E.8](ideas.md) into something Claude Design can be pointed at. E.8 agreed the
direction and the pipeline — *explore in Claude Design, implement directly in SwiftUI* — but not the
surfaces, the boundary or the checks. Those are below, read from the current source rather than from
the concept image.

The repository has done this once already. The tutorial was designed in Claude Design on 2026-09-04,
kept as a reference build, written up as [tutorial-spec.md](tutorial-spec.md), and implemented in
PR #14 with the engine correcting the design where the two disagreed. That sequence is the template:

```
canvas  →  docs/export/Deck-Box.dc.html  →  docs/deck-box-spec.md  →  SwiftUI, one surface per PR
```

## 1. The boundary, as the code actually draws it

E.8 splits the app into furniture and table. Every surface below was located by grepping for
`WoodGrainView`, `FeltView` and the felt gradient, so this is the real inventory, not a guess.

### Becomes the box

| Surface | Drawn at | Today |
|---|---|---|
| Header band | `TableView.swift:93–98` | `WoodGrainView(vignette: .linear)` clipped to `HeaderBandShape(dip: 18)`, shadow black 45% r10 y4 |
| Main menu | `MainMenuView.swift:86` | `LinearGradient([.felt, .black], topLeading → bottomTrailing)` |
| How to play | `TutorialView.swift:27` | `WoodGrainView()`, radial vignette |
| Hand review, three screens | `ReviewView.swift:27, 84, 122` | `WoodGrainView()`, radial vignette |
| Hint detail | `TableSurface.swift:586` | `WoodGrainView()`, radial vignette |
| How Catch 5 is built | `ExplainerView.swift:108, 202` | felt → black gradient |

### Stays exactly as it is

| Surface | Drawn at |
|---|---|
| The playing area | `TableView.swift:117`, `FeltView` |
| Cards, ivory faces, green backs | `CardView.swift` |
| Seat tiles, portraits, moods | `TableSurface.swift`, `PortraitView.swift`, `SeatMood.swift` |
| Auction pills | `PillButtonStyle`, `TableSurface.swift:507` |
| Gold's five meanings | D33 |
| The table-first layout and its measurements | `Theme.Table`, `HandLayout` |

### Undecided, and worth one sentence from Connor each

- **The rulebook** (`RulesView.swift:103`) sits on felt *on purpose*: its own header comment says
  "the tutorial is wood, pills and exercises; this is felt, panels and figures, so the two read as
  different rooms." Moving the tutorial to the box preserves that contrast — box versus felt — so the
  recommendation is to leave the rulebook on felt and let the box supply the difference. It also
  shows the table's own pieces, which is the felt side of the split.
- **Login and intro** (`LoginView.swift:68`, `IntroView.swift:68`) are on the felt gradient. They are
  neither frame nor play. They come before the box is opened, so the recommendation is that they
  become the box, matching the main menu they lead into.

## 2. What the box may not disturb

These are approved or decided elsewhere. The canvas explores material, not layout.

| Fixed | Source |
|---|---|
| Three persistent elements across the top: score chip, contract chip, menu | R1, `ScoreBarView` |
| The main-menu hamburger: bare glyph, top-right, 44 pt hit area | R19, R29, approved geometry |
| The header band's frown: `dip = 18`, quad curve control at `(midX, maxY - 2·dip)` | `Theme.Table.headerDip` |
| The main-menu stack: title, player card, Beginner mode, action buttons, `maxWidth 480` | R31 |
| Gold means dealer, trump and contract, the seat to act, the winning card, the one primary button | D33 |
| No card counts anywhere on the box or the table | R20 |
| Text runs large: every style +2 Dynamic Type steps; table caps at AX2, cards at XXXL | `Theme.textBoostSteps` |
| Card geometry: 2:3, radius 6% of width, 58/62 pt in hand | `Theme.Card` |

**The one real risk is gold.** Gold currently carries five meanings and nothing else, and a box with a
gold foil rule adds a sixth use of the same colour. Connor's call on 2026-09-14: do not settle this in
prose, draw both and judge them side by side. The canvas carries two main menus, identical but for the
title, and the comparison decides it.

*Candidate A, gold foil.* Closest to the concept image. It holds only if this rule holds:

> Foil is material, signal is state. The box's foil is static — it never moves, never changes with
> the game, and never crosses onto the felt. Signal gold appears only on felt. A player never sees
> two golds doing different jobs in the same rectangle.

*Candidate B, no gold on the box.* Title and rules embossed in burgundy and shadow alone. D33 stays
untouched by construction, and the box earns its richness from material rather than colour.

The artboard that actually decides this is not either menu on its own — it is the header band over
live felt, where box and table share one screen and a player would see both golds at once.

## 3. The palette as it exists today

Read from `Theme.swift` and `CardView.swift`, converted to hex. The canvas must hold the felt column
exactly and propose only the box column.

| Role | Token | Hex |
|---|---|---|
| Card face, all body text | `.ivory` | `#FAF5E3` |
| Signal gold | `.gold` | `#E8BF6B` |
| Suit red | `.suitRed` | `#DB2E38` |
| Felt, lit centre | `Wood.feltEdge` | `#295742` |
| Felt, base | `Wood.felt` | `#1A4030` |
| Felt, edge | `Wood.feltDark` | `#0A211A` |
| Felt nap flecks | `Wood.feltLight` | `#8CCC9E` |
| Oak light / base / dark — **replaced by the box** | `Wood.light/base/dark` | `#B3824A` / `#8A5E33` / `#614021` |
| Panel inlay, still used inside sheets | `Wood.inlay` | `#1F130A` |
| Darkest edge | `Wood.header` | `#120B06` |

The box needs, at minimum: a burgundy board colour, a lit and a shadowed variant of it, a foil gold
(which may or may not be `#E8BF6B`), and an embossing tone. Naming them is part of the canvas's job.

### The oak's weak spot is the reading sheets, not the header band

Ivory text sits straight on both surfaces, so their background sets the floor for readability. The
rows below marked *drawn* are sampled from rendered frames (iPhone 16 Pro simulator, iOS 26.5, dark,
September 14 2026), not computed from the colour literals. That distinction is the whole point:
`WoodGrainView` lays a three-stop gradient, twenty-eight tonal bands, several hundred grain strokes
and a vignette on top of each other, so no pixel on screen is ever the bare literal. Glyph pixels and
their antialiased edges are excluded from every sample.

| Surface | Contrast with ivory `#FAF5E3` |
|---|---|
| Header band, behind the score and contract text — *drawn* | 6.90:1 median — passes |
| Header band, brightest pixel anywhere: the top-left corner, under the status bar, where no app text sits — *drawn* | 3.43:1 |
| Reading sheet, title and subtitle on bare wood — *drawn* | **4.4:1 median, 3.84:1 floor, half the area below 4.5:1** |
| Reading sheet, body copy on the dark inlay panel — *drawn* | 10.75:1 median — passes |
| A deep burgundy, `#4A1420` to `#7E2A3C` — *computed* | 13.6:1 to 8.4:1 |

The header band is not the problem. The vignette and the grain darken it well past the floor wherever
text actually sits, and `Theme.swift` says as much in the comment above `Wood`: the base stays
mid-dark and the grain carries the lighter look. The reading sheets are the problem. Their headings
sit on bare wood at the lit end of the radial vignette, where about half the area behind the text
falls under 4.5:1 and the brightest background reaches 3.84:1; only the dark inlay panel beneath the
body copy rescues the rest of the page.

So the box direction fixes a real failure on the reading sheets and leaves the header band no worse.
Any burgundy dark enough to read as a deck box clears the floor on both. That range is the canvas's
starting point, not its answer — the board still has to sit beside the felt without either muddying
the other.

## 4. Artboards

One canvas, iPhone 16 at 393 × 852 pt, dark. Ten artboards in three rows.

**Row 1 — the material.** Nothing from the app; just the box.
1. **Board study.** Burgundy cloth-textured board at 1:1 and at 3:1, with the foil rule and one
   embossed suit, so the texture can be judged at the size a phone actually renders it.
2. **Foil and emboss.** The gold foil rule at three weights and the four suits embossed, each shown
   on the lit and the shadowed board. Establishes how deep the deboss reads before it becomes noise.

**Row 2 — the two surfaces that change most, and the gold comparison.**
3. **Main menu, candidate A.** The hero. Closed box seen from above, title in gold foil, hamburger
   top-right unmoved, player card, Beginner mode, Continue game / New match / How to play.
4. **Main menu, candidate B.** Identical in every respect except the title, which is embossed in
   burgundy and shadow with no gold anywhere on the screen. Same copy, same spacing, same everything;
   only then is the comparison honest.
5. **Header band over live felt.** The band in box material, frown intact, with the real felt table
   beneath it mid-trick, showing signal gold on the felt at the same time. This artboard is the proof
   the split works and the one that decides the gold question; spend the most time here. Draw it twice
   if the band itself carries foil under candidate A.
6. **Header band, before and after.** The same state twice, oak and box, side by side at the same
   scale.

**Row 3 — the reading rooms.**
7. **How to play.** Lesson 3, Trump: chapter pills, lesson body, Back / Next.
8. **Hand review.** A long scroll, dense text, the state where a wood background currently does the
   least work.
9. **How Catch 5 is built.** The densest text in the app.
10. **Do not touch.** The felt table at default state, labelled as reference. Present so the canvas
    carries its own boundary and nobody redesigns a card by accident.

## 5. The prompt

Copy this into Claude Design.

```text
Design the frame for Catch 5, an iPhone card game for one family. The game itself is finished and
stays exactly as it is; you are designing the box it sits in.

THE IDEA
The app should feel like a deck of cards someone has owned for thirty years, kept in a good deck box.
Deep burgundy boards, cloth-textured, with a gold foil rule and embossed card suits. Inside the box
is green felt, and that is where the game is played. Not a casino app: no neon, no gradients that
glow, no plastic. A readable, welcoming card table sitting inside a good box.

THE SPLIT, WHICH IS THE WHOLE POINT
The BOX is everything around the play area: the header band across the top of the table screen, the
screen edge, the main menu, and the reading screens (how to play, hand review, how the app is built,
hint detail). These currently look like drawn golden oak or a green gradient. They become the box.

The TABLE is the play area and everything a player reads while deciding: green felt, ivory card faces,
green card backs, seat portraits, auction pills, and the layout. These do not change. Draw them as
described below and leave them alone.

If a change would alter what a player looks at while choosing a card, it is out of scope.

PALETTE YOU MUST HOLD EXACTLY (the table side)
  ivory, all text and card faces  #FAF5E3
  signal gold                     #E8BF6B
  suit red                        #DB2E38
  felt, lit centre                #295742
  felt, base                      #1A4030
  felt, edge                      #0A211A
  felt nap flecks                 #8CCC9E
The felt is a radial gradient, lighter at centre (0.5, 0.45), falling to the edge colour, with a fine
seeded stipple of light and dark flecks on a 4 pt grid so it reads as fibre rather than paint.

PALETTE YOU ARE DESIGNING (the box side)
Propose and name: a burgundy board, a lit and a shadowed variant, a foil gold, an embossing tone.
The burgundy must sit against the felt without either one muddying the other, and must hold ivory
text at 4.5:1 or better. On the reading screens the title and subtitle sit directly on the board with
no panel behind them, while body copy sits on a dark inset panel; the bare-board heading is the case
to prove, because that is exactly where the oak it replaces currently fails.

THE GOLD QUESTION, WHICH IS THE HARDEST CONSTRAINT
In the game, gold has exactly five meanings and no decorative use at all: the dealer badge, the trump
suit and contract, the seat whose turn it is, the winning card of a trick, and the single primary
button on a screen. A gold foil box risks becoming a sixth gold.

Do not settle this for me. Draw both and let me choose:

  Candidate A — gold foil on the box. It works only under this rule, so build it into the drawing:
  foil is material, signal is state. The box's foil never moves, never changes with the game, and
  never crosses onto the felt. Signal gold appears only on felt. A player must never see two golds
  doing different jobs inside one rectangle.

  Candidate B — no gold anywhere on the box. Title and rules embossed in burgundy and shadow only.

Artboards 3 and 4 are the same main menu under A and under B, identical but for the title treatment.
Artboard 5 is where it is really decided: the box header sits directly above felt carrying live signal
gold, so both golds are on screen at once. If the band carries foil under A, draw that artboard twice.

GEOMETRY THAT IS APPROVED AND MUST NOT MOVE
- The top of the table screen holds exactly three things: a score chip on the left ("Us 21 · Them 14",
  serif numerals), a contract chip in the centre (only after bidding resolves, e.g. "♥ 4 — You"), and
  a menu glyph on the right. Nothing else.
- The header band's bottom edge is a frown: the corners hang 18 pt lower than the middle, drawn as a
  quadratic curve whose control point is 36 pt below the band's bottom.
- The main menu's hamburger is a bare glyph with no plate, top right, 44 x 44 pt hit area.
- The main menu stacks: "CATCH 5" in large serif bold, "MAIN MENU" small monospaced with letter
  spacing beneath it, a player card (portrait plus name plus difficulty plus where the saved match
  stands), a Beginner mode toggle with a one-line explanation, then Continue game / New match / How
  to play. Maximum content width 480 pt.
- Cards are 2:3 with a corner radius of 6% of width, 58-62 pt wide in hand, overlapped so each still
  shows a 44 pt strip.
- Auction pills are full width, 64 pt tall, 14 pt radius, solid dark with ivory labels.
- Text runs large throughout: assume every size is two Dynamic Type steps above the system default,
  and that a player may raise it further. Nothing may clip or become unreachable when they do.
- Never show a count of cards anywhere. Deck and discard show volume by stack thickness only.

ARTBOARDS, iPhone 16 at 393 x 852, dark
1.  Board study: the burgundy board at 1:1 and 3:1, with the foil rule and one embossed suit, so the
    texture can be judged at the size a phone renders it.
2.  Foil and emboss: the foil rule at three weights, all four suits embossed, each on the lit board
    and the shadowed board.
3.  Main menu as the closed box, candidate A: title in gold foil. This is the hero.
4.  Main menu as the closed box, candidate B: title embossed in burgundy, no gold on the screen at
    all. Identical to artboard 3 in copy, spacing and layout; only the title treatment differs.
5.  The header band in box material sitting over the real felt table, mid-trick, four cards down,
    with signal gold visible on the felt (the seat to act ringed, the contract chip). This artboard
    proves the split and decides the gold question; spend the most time here.
6.  The same header state twice at the same scale, drawn oak on the left, box on the right.
7.  How to play, lesson 3 of 5 (Trump): chapter pills, lesson body, Back / Next footer.
8.  Hand review: a long scroll of dense text.
9.  How Catch 5 is built: the densest text in the app.
10. Labelled "Do not touch": the felt table in its default state, as a boundary reference.

WHAT I NEED BACK
For each artboard, the colours as hex, the corner radii, the stroke weights of the foil, and how the
emboss is built (fill, inner shadow, highlight), specific enough to rebuild in SwiftUI without an
image asset. The app draws its textures in code from a fixed seed, so any texture must be describable
as a procedure — flecks, bands, strokes, opacities — not supplied as a bitmap.

WHAT NOT TO DO
Do not redesign a card, a seat, a portrait, an auction pill or the felt. Do not add a count of
anything. Do not move the hamburger. Do not let box gold and signal gold appear in one rectangle doing
different jobs. Do not add a screen the app does not have.
```

## 6. Back from the canvas

1. Export the canvas to `docs/export/Deck-Box.dc.html`, beside the tutorial's reference build.
2. Write `docs/deck-box-spec.md` on the model of `tutorial-spec.md`: what to build, which file each
   artboard maps onto, and the corrections found while reading it against the code.
3. Add the box colours to `Theme.swift` as `Theme.Box`, leaving `Theme.Wood.felt*` untouched. The oak
   values stay until nothing references them, then go in the same commit that removes the last use.
4. Implement one surface per pull request, in this order, because it runs from most-seen to least:
   header band → main menu → reading sheets. Each is independently revertible.
5. `docs/decisions.md` gets D62 for the box direction and the foil-versus-signal rule. Per the living
   documentation rule, whichever pages describe the changed types are updated in the same commit.

## 7. Checks

The north star requires capturing the current screen and comparing the same states afterwards, so
every surface below is shot twice, before and after, on the same device and the same saved match.

| Check | How |
|---|---|
| Same states, before and after | Simulator screenshots of: main menu with a saved match, header band mid-trick, header band during the auction with no contract chip, how to play lesson 3, hand review, the build explainer |
| Ivory on burgundy is readable | Contrast ratio of `#FAF5E3` on the board colour, 4.5:1 or better |
| Gold still means five things | Every signal gold on the felt is still visible against the new frame; no foil inside the play area |
| Nothing clips when text grows | Each screen at default, XXXL and AX2 |
| Increase Contrast and Reduce Motion | Both on; the box has no motion of its own, so this should be a no-op, which is the point of checking |
| The engine is untouched | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` |

## 8. Settled, and still open

**Settled 2026-09-14.** Connor drives Claude Design himself with the section 5 prompt, as he did for
the tutorial on 2026-09-04. Gold is not decided in prose: the canvas draws both title treatments and
the header-over-felt artboard settles it.

**Still open, and answerable on the canvas rather than before it:**

1. The rulebook: stay on felt, as recommended in section 1, or join the box?
2. Login and intro: box, as recommended in section 1, or leave them on the felt gradient?
3. Whether the header band carries foil at all, or only the main menu does.
