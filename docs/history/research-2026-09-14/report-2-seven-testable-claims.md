# What the Software Around a Fixed Card Game Controls for Return: Seven Testable Claims

## TL;DR
- **Your strongest belief is broadly correct but needs a sharper reason: a bad AI partner does more damage than a bad AI opponent, and the mechanism is not "it plays weakly" but "it plays *illegibly*."** The highest-leverage single fix is making the partner's play predictable and explainable, not maximally strong. In the closest empirical test (Siu et al., 2021, NeurIPS), humans and a state-of-the-art AI teammate scored no better than humans and a simple rule-based bot, yet players "consistently hated" the sophisticated AI and preferred the predictable one.
- **Your second belief — that the app must never do the game's skill — is only half-right.** The evidence supports a hard line between removing *tedium* (safe, even helpful) and removing *skill-building* (costly). A cards-played counter sits closer to the skill side, so your refusal is defensible for experienced players but likely harms beginners; the resolution is fading, not a blanket ban.
- **Your third belief — post-hand teaching over in-hand assistance — is supported for building durable skill, but skill-building is not the same as return.** Return in a family is driven more by friction-to-start, ritual, and how losses are handled than by how much anyone learned.

## Key Findings
Seven claims follow, each stated so it could be false, each with the evidence, its real strength, and what to do. Claims 1–3 bear directly on your three beliefs and lead.

---

## Details

### CLAIM 1 (sharpens Belief 1): A bad AI *partner* damages the experience more than an equally bad AI *opponent* — but the driver is unpredictability, not weakness. Making the partner *legible* beats making it *strong*.

**Evidence.** This is the best-supported claim in your whole problem, and it comes from convergent empirical sources:

- The strongest single study is Siu et al. (2021, NeurIPS; arXiv:2107.07630), a single-blind human-AI experiment in the cooperative card game Hanabi with **29 participants** (pooled into 10 novices self-rating experience ≤5 and 19 experts self-rating >5). Humans played with a rule-based bot (SmartBot) and a state-of-the-art reinforcement-learning bot (Other-Play). As MIT Lincoln Laboratory summarized the result: **"Not only were the scores no better with the AI teammate than with the rule-based agent, but humans consistently hated playing with their AI teammate. They found it to be unpredictable, unreliable, and untrustworthy, and felt negatively even when the team scored well."** The researchers attribute this to *legibility* and *predictability* — an illegible teammate breaks the human's ability to plan. Co-author Hosea Siu reported: **"There was a lot of commentary about giving up, comments like 'I hate working with this thing.'"** Crucially for you, they found an "Expert Paradox": the more experienced the human, the *more* they disliked the strong-but-unconventional agent, because it violated their mental model of correct play. A larger 2025 follow-up ("In Pursuit of Predictive Models of Human Preferences Toward AI Teammates," arXiv:2503.15516) ran N=241 and replicated the preference for the rule-based teammate.
- A related finding: in one online field experiment (Adachi et al., "Toxic Teammates or Obscene Opponents?"), players reported experiencing *more* negative behavior from teammates than from opponents, particularly when the team was not coordinating. And blame-attribution research shows people ascribe more blame to AI teammates for bad outcomes while crediting themselves for good ones — the self-serving bias applied to AI teammates (Chong et al., 2022, *IJHCI*).
- Your own competitor evidence fits precisely. NeuralPlay Pitch's reviews complain the partner bids "three" with no trump in hand, "throws in the 2 of trump" then "the 10 of trump" on an opponent's opening bid, and "play[s] the queen on our ace, when he has the jack or some other point card." These are all *legibility* failures — moves that violate a Pitch player's model of what a sane partner would do — not merely weak play. The developer's own response ("Levels 4+ use an advanced Monte Carlo Simulation AI … This results in some good plays on the higher levels. And of course a few bad ones too.") confirms the higher-strength AI produces exactly the unpredictable moves that enrage partners.

**Strength of evidence.** Moderate-to-strong. The Hanabi study is a controlled, peer-reviewed experiment but with a modest sample (29) in a different game; its core preference finding has now been replicated at N=241. The convergence with your competitor's multi-year review pattern and with the broader teammate-blame literature makes the direction reliable. The exact magnitude in Pitch is not measured.

**Confidence: High** on the direction and on the legibility mechanism. Medium on magnitude.

**What to do.** 
- Reframe the partner work from "make it play better" to "make it play *predictably and explainably*." A partner that plays a slightly sub-optimal but human-conventional Pitch game (leads trump when short, saves the off-Jack, throws the 3 on a partner's sure winner to bank Game points, does not overtake its partner's winning trick) will be *preferred* to a Monte-Carlo partner that is stronger on average but occasionally alien.
- This makes partner improvement genuinely your highest-leverage work — **but the target is legibility, not raw strength.** Building a stronger search-based AI could actively backfire, exactly as it did for your competitor and for Other-Play in the Hanabi study.
- Cheapest high-value addition: let the partner briefly *explain* its non-obvious plays ("led low trump to protect my Jack"). Legibility can be delivered by explanation, not just by behavior.

---

### CLAIM 2 (partially contradicts Belief 2): There is a real, documented line between removing *tedium* and removing *skill* — and a cards-played counter is closer to the skill side. Your blanket refusal protects experts and likely frustrates beginners; the fix is fading, not prohibition.

**Evidence.** Your instinct that automating card-counting could "hollow out" mastery has genuine empirical grounding — but the literature also shows where the line falls:

- The cognitive-offloading literature establishes the trade-off cleanly. Risko & Gilbert (2016, *Trends in Cognitive Sciences*, 20(9):676–688) define offloading as using external action to reduce cognitive demand, and document that it reliably boosts immediate performance while risking internalization of the offloaded content. Grinschgl, Papenmeier & Meyerhoff (2021, *Quarterly Journal of Experimental Psychology*, 74(9):1477–1496, "Consequences of cognitive offloading: Boosting performance but diminishing memory"; preregistered, three experiments, Experiment 1 N=172) found more offloading produced faster performance but **worse later memory** for the offloaded material, with individual-difference correlations between offloading and memory ranging up to |r|≈.85. Sparrow, Liu & Wegner (2011, *Science*, 333:776–778) — the "Google effect" — found that expecting future access to information lowers recall of that information (though this specific finding has had mixed replication and should be cited as foundational-but-contested).
- **The critical nuance that resolves your dilemma:** Grinschgl et al.'s Experiment 3 showed the memory cost of offloading *almost completely disappears when the person is motivated to retain the information.* Offloading only hollows out skill you would otherwise have been building incidentally and cared about building. If a player doesn't want to internalize the count, automating it is a clean win; the harm arises only when the tracking was the channel through which valued mastery developed.
- The one direct game study: Wallace et al. (2012, CSCW poster) had groups play Pandemic at varying automation levels and found that automating setup/upkeep/bookkeeping "can also negatively impact enjoyment, game state awareness, and flexibility in game play"; players preferred the less-automated physical version. This is a small poster study (multiplayer, cooperative) but it is the only direct test, and it points toward "automating bookkeeping can reduce awareness and enjoyment."
- Board-game design practice has independently codified the exact distinction you need: maximize "decision making," minimize "decision resolution / record keeping" (Delta Vector); eliminate "null decisions" but protect "meaningful decisions" (BoardGameGeek design threads); reduce the "mental load of bookkeeping" as a usability win *provided you do not remove agency* (Nielsen Norman Group, "Usability Heuristics Applied to Board Games").

Where does card-counting in Pitch fall? Counting which points (the 5, the off-5, Jacks, the 2, the 10s for Game) have been played is not arithmetic tedium — it is the informational substrate of skilled decisions. That places it on the *skill* side. By contrast, tallying the running Game-point score, or summing the hand total, is *resolution/tedium* — automating it is safe and probably beneficial.

**Strength of evidence.** Medium. The offloading mechanism is strongly established but was measured on memory tasks, not on felt mastery or enjoyment in games. The one direct game study is a small poster. No peer-reviewed experiment directly measures "in-game card-counting aid → perceived mastery." Your specific claim is a well-supported *inference*, not a documented finding — I want to be explicit about that.

**Confidence: Medium.** The tedium/skill distinction is real and defensible. The exact placement of "card counting" on the skill side is a judgment call backed by the design literature, not by direct measurement.

**What to do.**
- **Keep score-keeping and hand-total arithmetic automated** (this is tedium; the app almost certainly already does it). Do not agonize about that.
- **Do not build a permanent, always-on card-counting display.** For an experienced player it removes the core skill; the offloading and design-practice evidence both warn against it, and it will make the app feel like it plays itself.
- **Do build a *fadeable* counting aid for beginners**, framed as a training wheel that is on by default in assistance mode and off by default otherwise. This directly serves the beginner without permanently hollowing out the expert — and Grinschgl Exp. 3 suggests that if the beginner *knows* the aim is to learn to count, even using the aid does less damage. The manual counting aid you were unsure about building **is worth building — but as a fading beginner scaffold, not a standing feature.** A blanket refusal over-serves the expert at the beginner's expense.

---

### CLAIM 3 (supports Belief 3 with a caveat): Post-hand teaching builds durable skill better than in-hand assistance — but do not confuse skill-building with return.

**Evidence.** The learning science is on your side on the narrow question:

- The expertise-reversal effect (Kalyuga, Ayres, Chandler & Sweller, 2003, *Educational Psychologist*, 38(1):23–31) is directly on point: heavy instructional guidance that helps novices becomes useless or *harmful* for more advanced learners, who learn better with reduced guidance. This is your strongest theoretical basis for treating beginners and experts differently in one app.
- The assistance dilemma (Koedinger & Aleven, 2007, *Educational Psychology Review*, 19(3):239–264) frames it precisely: withholding help causes frustration; giving too much produces "shallow learning and a lack of motivation to learn by oneself." Highly-assisted learners look good *during* practice but may not build capability that transfers — a "measurement trap."
- Desirable difficulties (Bjork) and the delayed-feedback literature support your specific timing preference. Delaying feedback (as post-hand review does, versus in-hand hints) tends to improve *transfer* and long-term retention. Rowland's (2014, *Psychological Bulletin*, 140(6):1432–1463) meta-analysis of 61 experimental studies found testing produced an overall mean effect of about 0.50 standard deviations over restudy, and — directly relevant to you — intermediate testing that *included feedback* yielded d=0.73 versus d=0.39 without feedback, with delayed feedback often outperforming immediate. Butler and others also document a metacognitive disconnect: learners *believe* immediate feedback helps them most even when delayed feedback produces better transfer. So your users may *ask* for in-hand hints while post-hand review serves their skill better.

The caveat: the feedback-timing literature is genuinely contested. Several studies and meta-analyses (including the classic Kulik & Kulik, 1988) found *immediate* feedback superior in applied classroom settings; recent work finds them roughly equal. The honest reading is: post-hand teaching is *at least as good as* in-hand assistance for durable learning and better for transfer, but "delayed always wins" is not established.

**Strength of evidence.** Medium-strong for the beginner/expert differentiation (expertise reversal is robust). Medium and contested for the specific "delayed beats immediate" timing claim. All of it is from education, not card games — transfer to your context is an inference.

**Confidence: Medium-high** that post-hand teaching earns its place; **Medium** that it is strictly superior to in-hand help.

**What to do.**
- **Post-hand teaching earns its place — keep and invest in the hand-by-hand review, and make its teaching content richer** ("at trick four, the 5 and off-5 were still out; leading your Jack was into a likely finesse"). This is your best skill-builder.
- **Do not remove in-hand hints; make them fade.** Both serve different players: in-hand hints for the true novice (expertise reversal says they need guidance), post-hand review for the improving player. Default the assistance to fade as the player's competence rises.
- **But rank this below Claims 1 and 5 for *return*.** Teaching builds the competence that SDT says feeds enjoyment — but a family member does not come back next month because they learned; they come back because it was easy to start and did not feel unfair. See Claims 4 and 5.

---

### CLAIM 4: Return in a household is a different variable from in-session enjoyment, and it is dominated by friction-to-start and ritual, not by how good the last session felt.

**Evidence.**
- The games research community explicitly separates "enjoyment" researchers from "retention/churn" researchers, and notes they rarely talk to each other (Vaudour, "Challenge and Retention in Games" dissertation, UC eScholarship). Enjoyment and return are measured separately and do not map one-to-one.
- The intention-behavior gap literature is directly relevant: intention (including "I enjoyed that, I intend to play again") is a weak predictor of actual behavior. Measures of intention "rarely predict all or even the majority of the variance in behavior" (Sheeran & Webb review of intention strength).
- Habit formation research locates the "active ingredient" of a recurring behavior in *cued automaticity* — a behavior triggered by a stable context cue, with low friction. Lally, van Jaarsveld, Potts & Wardle (2010, *European Journal of Social Psychology*, 40:998–1009; N=96) found automaticity plateaued after an average of **66 days** of consistent repetition (range 18–254 days), establishing that consistent repetition in a stable context — not the "21-day" myth — drives habit formation. Gardner et al. found *instigation* automaticity (the cue that starts the behavior) predicts frequency better than *execution* automaticity; context stability increases automaticity, and friction at the point of instigation is what kills recurrence. The popular "the most important thing is to start" has empirical support.
- Return-behavior research even shows people delay returning to experiences they *want* to return to and enjoyed (O'Brien & Kassirer, "Lost time undermines return behavior," PNAS) — enjoyment is not sufficient for return.
- The household/ritual literature (practitioner, but consistent) emphasizes that games become durable family fixtures through ritual: fixed time, fixed place, associated cues. One striking observation: physical game night worked as ritual partly *because* of the constraint that everyone had to show up and stay — the coordination cost was the binding agent. Your app removes that coordination cost entirely (one player, three bots, resumable), which is double-edged: it removes the friction that could stop a session, but also removes the social obligation that pulls people back.

**Strength of evidence.** Strong for the general dissociation of enjoyment and return; strong for friction and context cues in habit formation; the household-ritual specifics are practitioner consensus, not controlled study, and I label them as such.

**Confidence: High** that enjoyment ≠ return and that friction-to-start dominates. Medium on the specific ritual prescriptions.

**What to do.**
- **Treat friction-to-start as a first-class feature.** The single most return-relevant thing the software controls is how few taps and seconds separate "I have a spare few minutes" from "I am playing the next hand." Your resumable saved game is exactly the right instinct — protect it fiercely. One tap from app-open to resumed hand.
- **Support ritual and cueing without any dark patterns.** You have (correctly) ruled out streaks and daily-reward hooks; those would actively damage a family relationship with the game by converting intrinsic play into obligation. But a *gentle, optional, user-controlled* cue is different from a manipulative streak. Consider making "resume where you left off" the default screen, and letting the family attach the app to their existing ritual (e.g., a shareable end-of-game summary they can text each other) rather than manufacturing a new one.
- **Do not invest in engagement mechanics.** For a one-family, no-market audience, the ROI of polish-for-retention is low; the ROI of "instant to resume, never frustrating" is high.

---

### CLAIM 5: How the app handles *losing* is a top-tier return lever — and the specific risk is the partner-blame spiral, which you can design against without changing a single rule.

**Evidence.**
- Loss and loss-streaks drive churn. In a large competitive-game study (Kim et al., "Match experiences affect interest," *Heliyon*), higher win rate reduced churn and losing streaks increased it; match experience directly affected continued interest. The player-frustration literature distinguishes *earned* difficulty (motivating) from difficulty that "feels imposed, not earned" (breeds resentment and abandonment).
- Attribution theory is the key to your specific situation. The self-serving bias means players credit wins to themselves and blame losses on external factors — and the most available external factor in your game is *the computer partner.* Blame-attribution research on AI teammates confirms people over-blame the AI teammate for joint failures. In a partnership game with real luck, every lost match offers the player a choice of scapegoat: bad cards (luck), their own play (self), or the partner (AI). Two of those three preserve motivation to return; blaming the partner corrodes the relationship with the app (your competitor's "I WANT A NEW PARTNER!").
- There is a bright spot: attributing loss to *luck* is protective of persistence in a way that self-blame is not, and in a game with genuine card-luck, that attribution is often *true.* The software can legitimately help players correctly attribute a loss to the deal rather than to the partner or themselves.

**Strength of evidence.** Strong that loss handling affects churn; strong that self-serving/AI-blame biases operate; the application to Pitch return specifically is inference from robust general findings.

**Confidence: High** on the mechanism, Medium on specific interventions.

**What to do.**
- **Attack the blame spiral directly — this is where Claims 1 and 5 converge.** The single most damaging loss is one the player attributes to a partner who made an *inexplicable* play. A legible partner (Claim 1) is also the best loss-handling investment, because a loss with a *comprehensible* partner reads as "we got bad cards" (protective luck attribution) rather than "my idiot partner threw the game" (corrosive).
- **Use the post-hand review to support accurate, non-corrosive attribution.** When the partner's play was forced or reasonable, the review can quietly show it ("partner had no trump to lead"). When the deal was simply bad, the review can note it. Do *not* have the app blame the human — self-blame after failure depresses persistence.
- **Do not add loss-aversion hooks or "revenge" prompts.** They would manufacture exactly the resentment you want to avoid.

---

### CLAIM 6: What helps the beginner actively harms the expert — so any assistance you build must fade, and this is the central design constraint of serving one family with one app.

**Evidence.** This is the expertise-reversal effect (Claim 3) generalized. Guidance, worked examples, and redundant on-screen information that help a novice become "unnecessary or even detrimental" for the experienced player (Kalyuga et al.). The same applies to a card-counting display (Claim 2): a scaffold for the beginner, a mastery-remover for the expert. The offloading literature reinforces this — the expert has already internalized the count, so an external counter offers them nothing and removes the exercise of a skill they value. Note the Hanabi "Expert Paradox" again cuts the same way: the more expert the player, the more an intervention that violates their internalized model grates.

**Strength of evidence.** Strong (expertise reversal is one of the more robust findings in instructional psychology), though drawn from education rather than card games.

**Confidence: High.**

**What to do.**
- **Make every assistance feature fade by competence, not by calendar.** Tie hint availability, the counting aid, and in-hand suggestions to a per-player skill signal (assistance mode, or observed play quality), not to a global setting. Your existing per-beginner assistance mode is the right architecture; extend it so it *recedes* automatically.
- Because your audience is one family of "varying ages and varying interest," you will have a genuine novice and a genuine expert in the same install. **Per-player profiles with independent assistance levels are worth building** — this is the mechanism that lets one app serve both without the expert being condescended to or the beginner being lost.

---

### CLAIM 7: An AI teammate can carry *some* relatedness, but a bad one destroys enjoyment in a way a bad opponent does not — so relatedness is a real design surface even with no humans.

**Evidence.**
- SDT's relatedness is usually assumed to require other humans (the PENS scale operationalizes it via multiplayer). But Tyack & Wyeth (2017, "Exploring relatedness in single-player video game play") identify additional sources of relatedness in single-player games: relationships with NPCs/characters, with the game world, and with the game as an object. Research on NPC companions and social presence finds players form real parasocial relationships with agent companions and that well-designed companions create "social presence and companionship." So an AI partner *can* carry some relatedness satisfaction.
- But the asymmetry is the actionable finding: the AI-teammate literature (Siu et al.; the teammate-blame studies; the "commitment deficit" work showing people underperform and disengage more with AI teammates than human ones, Sciencedirect S245195882500243X, N=1988) shows a *bad* teammate produces strong negative affect — frustration, distrust, "I hate working with this thing" — that a bad opponent does not generate. A bad opponent is just an easy win; a bad partner is a betrayal. This is precisely why your competitor's sustained multi-year complaint is about the *partner*, not the opponents.

**Strength of evidence.** Medium. That agents can carry *some* relatedness is established but the effect is modest and mostly studied in narrative/companion contexts, not card partners. The negative asymmetry (bad partner worse than bad opponent) is well-supported and convergent with Claim 1.

**Confidence: Medium-high** on the asymmetry; Medium on the positive relatedness potential of a card partner.

**What to do.**
- **You cannot manufacture full relatedness, and you should not try to fake a "personality" for the partner** — for a discerning family audience, a chatty fake teammate would likely grate. But you *can* invest in the partner as a *reliable, legible presence*, which is the version of relatedness a card partner can plausibly deliver.
- The negative asymmetry means **your defensive priority is clear: never let the partner feel like a saboteur.** This again points all roads back to Claim 1 — legibility of the partner is simultaneously your relatedness lever, your loss-handling lever, and your single highest-leverage build.

---

## Recommendations

**Order your next six increments like this:**

1. **Make the computer partner legible and conventional (highest leverage).** Rewrite partner logic to play human-conventional Pitch — never overtake its own winning trick, save the off-Jack, bank Game points on a partner's sure winner, lead sanely for the auction. Prefer predictable-and-slightly-suboptimal over strong-and-alien. *Benchmark that would change this:* if playtesters in the family cannot predict the partner's plays or still describe them as "dumb," keep iterating before doing anything else. This one item addresses Claims 1, 5, and 7 simultaneously.
2. **Add brief partner-play explanations** ("led low trump to protect my Jack"). Cheap, and converts legibility into felt trust.
3. **Harden friction-to-start.** Guarantee one-tap resume into the exact mid-hand state. Make "resume" the default launch screen. This is your top *return* lever (Claim 4).
4. **Upgrade post-hand review into real teaching** with what-could-you-have-known content, and use it to support accurate, non-corrosive loss attribution (Claims 3, 5).
5. **Build per-player profiles with fading assistance** — independent assistance levels, and a *beginner-only, fadeable* card-counting training wheel (not a permanent display). Serves the novice without hollowing out the expert (Claims 2, 6).
6. **Only then** consider a stronger search-based AI *opponent* (not partner) for the expert who wants a harder game — strength is safe on the opponent side, dangerous on the partner side.

**What to stop / not build:**
- Do not build a standing, always-on card-counting display. Do not build a stronger Monte-Carlo *partner*. Do not add streaks, dailies, loss-aversion hooks, or a fake partner "personality." Each would damage this specific audience.

**On your three beliefs, plainly:**
- Belief 1 (partner matters most): **Confirmed, but re-aimed** — the lever is legibility, not strength. Building a stronger partner could backfire, as it did for Other-Play in the Hanabi study and for your competitor's Level 4+ AI.
- Belief 2 (never do the game's skill): **Half-wrong.** Right for experts and for the counting *display*; wrong as a blanket rule — a fadeable beginner counting aid is worth building.
- Belief 3 (post-hand teaching beats in-hand assistance): **Supported for skill, not decisive for return** — keep both, fade both, and don't expect teaching to be the thing that brings the family back.

## Caveats
- Almost none of this evidence is from single-player card-game apps specifically. The AI-teammate findings (Hanabi) are the closest and most transferable; the learning findings are from education; the habit findings are from health behavior. I have flagged each transfer as an inference.
- The Hanabi study has a modest sample (29 participants), though its central preference finding was replicated at N=241 in a 2025 follow-up. The one direct game-automation study (Wallace et al.) is a small poster. No peer-reviewed study directly measures "card-counting aid → perceived mastery," so Claim 2's specific placement of counting on the skill side is reasoned inference, not a measured finding.
- The feedback-timing literature (Claim 3) is genuinely contested; do not treat "delayed beats immediate" as settled. The Sparrow et al. (2011) "Google effect" has had mixed replication and is cited as foundational-but-contested.
- Household-ritual specifics (Claim 4) are practitioner consensus, not controlled research.
- Your audience is one family, not a market. Standard retention benchmarks (D1/D30 churn) are irrelevant; your only metric is "did they choose to play again this month," which no external dataset measures for you. Treat these claims as priors to test against your own family, not as guarantees.