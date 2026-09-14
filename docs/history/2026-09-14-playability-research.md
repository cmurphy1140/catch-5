# What three deep-research runs say about returning to a fixed game, September 14, 2026

Connor ran three independent deep-research sessions on one question: *given a card game whose rules
cannot change, what does the software around it control that decides whether people come back?*
This is the synthesis. It is a dated snapshot, kept because it disputes two things this repository
has already decided.

**Nothing here is a decision.** Where the research conflicts with an existing decision, both sides are
stated and the conflict is left open for Connor. Where the three reports disagree with each other,
that is said rather than averaged away.

**Read the agreement carefully.** Three sessions over the same literature are not three independent
experiments. Their convergence shows the literature is consistent, not that the finding is more
likely true. The citations below are relayed from the reports and have not been independently
verified against the papers.

The three reports are not in the repository; they were working files.

## 1. What all three agree on

| Finding | Confidence they assign |
|---|---|
| The computer **partner** is the highest-leverage part of the app | High |
| But the lever is **legibility**, not playing strength — a stronger partner can be a worse one | High |
| **Return is not enjoyment.** Enjoyment predicts a good session; friction and stable cues predict a habit | High |
| The **resumable saved game** is the most valuable feature already built | High |
| Assistance must **fade** as a player improves; one fixed level cannot serve a family | High |
| A **blanket** ban on counting aids is too absolute | Moderate |
| How the app handles **losing** is a top-tier lever, through attribution rather than difficulty | Moderate |

The shared evidence is Siu et al. (2021, NeurIPS), a human–AI experiment in Hanabi, a cooperative
hidden-information card game. Twenty-nine participants played with a hand-written rule-based bot and
a state-of-the-art reinforcement-learning agent. Players strongly preferred the rule-based bot on
trust, understanding and partner preference **while the objective team scores did not separate the
two**. Experienced players disliked the sophisticated agent *more* than novices did, because they had
a stronger model of what a sensible partner does. One report cites a 2025 replication at 241
participants.

That result is why all three re-aim the partner work. There are two different targets:

- **Playing strength** — maximise expected points or win rate.
- **Teammate quality** — play strongly *and* comprehensibly, given what a human partner can infer.

The Hanabi evidence says these are not the same thing, and that optimising the first can lose the
second.

## 2. Two places the research disputes a decision already made

### The bot bank flags for legibility but accepts on strength (D58, D59, D61)

D58 built exactly the mechanism the research recommends. A hand is flagged when Connor sees a seat
bid wrong, waste a trick, ignore its partner or give away the Five or Jack — a human judging whether
the play was *comprehensible*. D59 and D60 then added counterfactual detectors so only decisions that
could never have worked are counted.

The gate is the problem. D58 accepts a change only if the mirrored benchmark against the frozen
player does not get worse, and that benchmark is win rate and margin. All three reports say that
metric is the wrong target, and D61 already recorded the trade honestly: badly-missed contracts rose
71 → 88 and surrendered counters 14 → 19, because winning more auctions means playing more contracts.
A partner that wins more while occasionally doing something inexplicable is, on this evidence, worse
to play with.

**The open question:** should the flagged-hand corpus become the primary acceptance criterion, with
the benchmark demoted to a guard against collapse, rather than the other way round? This does not
require abandoning the benchmark. It requires deciding which one can veto.

### Zero-friction resume against the main menu on launch (D39, R31, R32, D56)

The third report puts friction-to-start **first** in its work order, ahead of the partner, on a
habit-formation argument: motivation fluctuates over months, so the ability to start must stay near
zero effort, and any menu between the cue and the play breaks automaticity. It asks for the app to
open directly into the live hand.

The approved design does not do that. `RootView` sends a returning player with a saved match to the
main menu, where Continue game is the primary action — one deliberate tap, chosen so that the match
is never resumed or replaced by accident (R32) and so the menu can carry the saved-match summary
(R29, R31).

**The open question:** is one tap friction worth what it buys? This is measurable rather than
arguable — count taps and seconds from cold launch to the first card decision, for a resumed match
and a new one, and decide with the number in hand.

## 3. Where the three disagree with each other

| Question | Report 1 | Report 2 | Report 3 |
|---|---|---|---|
| What comes first | Partner | Partner | **Friction-to-start** |
| Where friction ranks | Sixth | Third | First |
| A counting aid | Do not build it in the next six increments | Build it, beginner-only and fading | Context-dependent, must fade |
| In-hand hints for a true novice | Requested only; preserve the attempt | Keep them, fade them | **Immediate help is required** for a beginner, or the post-hand review is incomprehensible |

The novice disagreement has a real mechanism behind it. The third report argues that delayed feedback
only helps a learner who already holds enough of a model to have formed a hypothesis; an absolute
beginner will have forgotten the context of an auction decision by the end of the hand, so the review
lands on nothing. The first report argues the opposite risk — that help given before the attempt
teaches the player to follow prompts rather than to play.

They reconcile if assistance is tied to the player rather than to the app: immediate for someone who
has no model yet, receding to post-hand as one forms. That is what a fading assistance mode is for,
and it is the strongest argument yet for per-player assistance levels rather than one setting.

## 4. One warning worth keeping, from the first report only

The third report recommends exposing the partner's reasoning after a hand, including probabilities.
The first report warns where that goes wrong:

> A system that rationalises every move after the fact will eventually destroy trust. A player who
> correctly identifies a ridiculous partner play and is then shown an elaborate explanation of why
> the machine was brilliant has suffered two failures: the original play, and an untrustworthy
> explanation.

This family contains people who will spot a bad play. Any partner-rationale feature must be able to
say **"that was a partner error, and this was the better card."** A feature that can only justify is
worse than no feature.

## 5. What they were judging that we are not building

All three assessed an **automatic** card tracker — a display that counts for you. E.10's pad is
manual: the player enters every number and the app only holds it. The first report independently
proposes, as a *better* design than a tracker, that the player externalise their own count and have
the software check it afterwards. That is E.10's pad with a verification step added.

So the reports do not contradict E.10. They contradict a feature the spec rejected years of decisions
ago (R4, R20). The first report's position — that even the manual version should wait until a real
novice is observed abandoning the game over memory load — still stands against building it soon.

## 6. What none of them knew

They were given the game, the audience and the three beliefs, deliberately without the deck-box work,
the current screens or the code. So they could not know that the hand-end card already names the Game
count and its winner, that tap-to-explain already exists, that beginner mode already gates coaching,
or that the bot bank is already under way. Treat their feature suggestions as directions, and check
each against the code before believing anything is missing — the September 12 review found several
"missing" features already present.

They also had no view on whether visual work matters. Their silence on it is not evidence against it;
they were never asked.

## 7. What would settle the open questions

| Question | What settles it |
|---|---|
| Which gate the bot bank accepts on | Take flagged hands and ask whether a fix that raises trust-breaking errors but wins more is acceptable to Connor. It is his call, not a measurement |
| Whether the launch tap costs anything | Count taps and seconds, cold launch to first decision, resumed and new |
| Whether a counting aid earns a place | Observe a real novice. The trigger is someone who understands the game, wants to keep playing, and stops because holding played cards is overwhelming |
| Whether immediate help is needed for beginners | One family member who has never played, given the app with coaching on, watched once |

## Sources, as cited by the reports

Siu et al., *Evaluation of Human-AI Teams for Learned and Rule-Based Agents in Hanabi* (NeurIPS 2021,
arXiv:2107.07630), with a 2025 follow-up at arXiv:2503.15516. Ryan, Rigby & Przybylski, *The
Motivational Pull of Video Games* (2006). Kalyuga, Ayres, Chandler & Sweller on the expertise
reversal effect (2003). Kluger & DeNisi's Feedback Intervention Theory, reporting that over a third
of feedback interventions decreased performance. Grinschgl, Papenmeier & Meyerhoff on cognitive
offloading (2021), including the finding that the memory cost largely disappears when the person
intends to retain the information. Lally et al. (2010) on habit formation, median 66 days. The Fogg
Behavior Model. Nielsen Norman Group, *Usability Heuristics Applied to Board Games*.
