# Catch 5 — UI/UX Redesign Brief

You have access to the `catch-5` SwiftUI codebase in this repo. Before proposing anything, research the relevant UI/UX ground truth and inspect the actual views, models, and state management currently driving the game screen(s) — don't design in the abstract, and don't write any code yet. This brief is asking for a **plan**, not an implementation.

## Context

The current gameplay screen has a strong **visual identity** already: dark green table background, cream/ivory cards, muted gold accents, serif title treatment. Keep that language — this is not a "make it colorful and generic" redesign. The problem is **information architecture**, not taste.

Right now the screen reads top-to-bottom like a dashboard:
`scoreboard → player boxes → instructions → buttons → large empty table → hand of cards`

It should read like a physical card table:
`table first → players seated around it → cards moving through the center → game info supporting the table, not competing with it`

## The core layout shift

Compact score/status bar pinned to the top:

```
CATCH 5                          ⚙︎

YOU + PARTNER                 THEM
     6                          12

♥ TRUMP · BID 3              HAND 4
```

Then a spatial table below it — opponents placed where they'd actually sit, played cards animating from each seat toward the center pile:

```
        WESTIN
          6

 PARTNER              EAST
   6                    6

        ┌─────────┐
        │ played  │
        │  cards  │
        └─────────┘

      Your turn
       ♥ Trump

 ╲ A♥ ╲ 5♥ ╲ 9♣ ╲ 5♣ ╲ K♠ ╲ 9♠
             YOUR HAND
```

The player's hand should be the most tactile, visually dominant element on screen — not competing for space with a mostly-empty table.

## Priorities, in order

1. **Enlarge and dramatize the hand.** Cards are currently too small relative to the empty table space. Increase size ~20–35%, overlap slightly, use a subtle fan/arc rather than a flat row.

2. **Seat opponents spatially, not as list items.** Westin left, partner top, East right (adjust naming/seats to match actual game state model). Played cards should visually travel from each seat into the center pile rather than just appearing in a static log. The goal: the player understands turn order and game state spatially, without reading labels.

3. **Remove persistent Hint and Undo buttons from the main chrome.** They currently compete with "play a card" for attention, which should be the single dominant action.
   - Undo → contextual toast after a play: `9♣ played · Undo`, auto-dismissing.
   - Hint → demoted to a small, secondary/tertiary control, not a primary button.

4. **Make gold mean something specific.** It should be reserved for: current dealer, trump suit, active player indicator, winning card in a trick, key result states. Audit every current gold usage and cut any that isn't one of these — if everything is gold, nothing reads as significant.

5. **Add tactile/motion feedback layer:**
   - Tap a card → rises 8–12pt before confirming play
   - When it's the player's turn, legal cards subtly lift/highlight vs. illegal ones
   - Illegal card tapped → small resistance/shake, no play
   - Playing a card → animates from hand into the center pile
   - Winning card in a trick gets a restrained highlight (not full gold-flash)
   - Trick completion → cards collapse/animate toward the winning seat
   - Haptics: `UIImpactFeedbackGenerator` (or SwiftUI `.sensoryFeedback`) on card play, a stronger haptic on taking a trick

## Research to ground the plan

Before finalizing anything above, research current iOS card-game UI/UX conventions via web search and use it to validate, refine, or correct the priorities above. Specifically look into:

- Touch ergonomics and thumb-zone placement for primary actions (play a card, end a turn, bid) on iPhone
- Contrast/elevation techniques for separating cards from a game-table background (shadows, borders, fills)
- Card aspect ratios and sizing conventions for mobile vs. desktop card UIs
- Typography legibility standards for suit/rank readability at a glance
- Natural/physical animation patterns for card flipping, sliding, and dragging
- Haptic feedback patterns via Core Haptics / `UIImpactFeedbackGenerator` for draw/play/shuffle actions
- Apple's Human Interface Guidelines for iOS, specifically around card-based and game UI

Where the research suggests something more specific or different than what's written above — a concrete aspect ratio, a thumb-zone constraint that changes where the hand should sit, a more precise haptic pattern — note the refinement and its source/rationale rather than silently overriding the brief.

## What I need from you

Work screen-by-screen through the actual SwiftUI views in this repo (not a rebuild from scratch) and produce:

1. **A short design system reference** — spacing/sizing scale for cards at rest vs. active, the specific rule for when gold is used vs. not, motion/timing values for the animations above, and how the compact score bar should be structured as a reusable component. Ground this in both the brief and the research above; flag any non-obvious choice with its rationale.

2. **A screen-by-screen breakdown** of the current gameplay view(s): what stays, what's being restructured, and which existing SwiftUI views/components get repositioned vs. rebuilt vs. deleted. Reference actual file/type names from the codebase.

3. **A concrete, ordered implementation roadmap** — the sequence you'd tackle this in (e.g., layout restructure → seat positioning → hand sizing/fan → remove/relocate buttons → gold audit → motion/haptics pass), with each step scoped to something independently shippable/testable, not one giant rewrite.

Flag anywhere the current state model or navigation structure would make part of this harder than it looks from the UI alone — I'd rather know that up front than discover it mid-implementation.

Write the plan to a markdown file in this repo rather than just answering in chat.
