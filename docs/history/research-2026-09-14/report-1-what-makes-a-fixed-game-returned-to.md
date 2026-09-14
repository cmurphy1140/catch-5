# What Actually Makes a Fixed Partnership Card Game One People Return To

Your three starting beliefs do not survive intact.

| Belief | Research verdict | What I would do |
|---|---|---|
| **The computer partner is the most important thing.** | **Mostly strengthened, with an important correction.** The strongest directly analogous experiment I found says players can strongly prefer one AI card-game partner over another **even when objective team scores are statistically indistinguishable**. What mattered was whether the partner was understandable, predictable, trustworthy, and free of apparently stupid moves. citeturn25academia29turn17view0turn18view3 | **Make partner quality the top priority.** But optimize “good teammate,” not merely “strong player.” |
| **The app should never count cards for the player.** | **Too absolute.** Offloading memory can improve immediate performance and reduce burden; novice guidance can genuinely help. But offloading information that is itself the target skill can reduce later memory/independent performance, and instructional support that helps novices can become useless or harmful for experts. citeturn23search0turn25search0turn25search1 | Keep automatic perfect counting **off by default**. I would **not put a card tracker in the next six increments**. If you eventually add one, make it optional, temporary, and preferably require the player to participate rather than simply displaying perfect state. |
| **Teaching after the hand is better than assistance during it.** | **Not established, and the blanket version is probably wrong.** Feedback-timing research does not consistently favor delayed feedback; immediate corrective feedback often wins, and results depend heavily on the task. citeturn5search7turn5search16turn25search18 | Preserve the player's **attempt**, not necessarily a whole-hand delay. A stronger rule is: **do not give the strategic answer before the decision; teach after commitment.** Your post-hand review is valuable, but it need not be the only teaching moment. |

My overall confidence that **partner work should come first is moderately high**, not because there is a study of your exact Pitch variant, but because the closest controlled evidence is unusually close to your problem: a human playing a cooperative, imperfect-information card game with an AI teammate. I would not claim science has proved that partner AI outranks every imaginable software characteristic. I would absolutely bet the next major increment on it.

The deeper finding is this:

> **For a frozen game, software cannot manufacture replayability inside the rules. What it can control is whether the player experiences their own decisions as consequential, their partner as trustworthy, their mistakes as learnable, their losses as legitimate, and returning as effortless.**

Those are the levers I would optimize, in roughly that order.

## The partner is probably your highest-leverage feature, but raw playing strength is the wrong metric

**Falsifiable claim:** *For a partnership card game, improving the human compatibility of the computer partner will increase willingness to replay more than an equivalent improvement in opponent strength, tutorial content, statistics, or cosmetic presentation.*

**Confidence: moderately high on prioritizing the partner; only moderate on the comparative “more than everything else” part.**

The most important study I found is Siu and colleagues' human–AI experiment in **Hanabi**, another cooperative card game built around hidden information, inference, and coordination. Twenty-nine participants played with two AI teammates: a hand-engineered rule-based agent called SmartBot and a state-of-the-art reinforcement-learning agent called Other-Play. The researchers measured game score alongside perceived teamwork, trust, understanding, comfort, and partner preference. Humans clearly preferred SmartBot across almost all subjective teamwork measures **despite there being no statistically significant difference in objective game score between the two agents**. citeturn25academia29turn17view0

That distinction is enormously important for your project. Players were not simply asking, “Does this bot produce wins?” They were evaluating, “Can I work with this thing?”

Direct comparisons favored SmartBot on partner preference, trust, perceived understanding, perceived reliability, perceived game understanding, and judgments about which AI was the better player. Several of those effects were around the medium-effect range. Participants described the disliked agent in terms such as breaking trust or making apparently obvious mistakes; strikingly, some participants who achieved extremely good scores with it still strongly preferred the other partner. citeturn18view3turn18view1

The result gets even more relevant to your mixed-skill family: the **experienced Hanabi players were substantially harsher on the unpredictable AI than novices were**. Experienced players had stronger expectations about what a sensible partner should infer and do, and violations of those expectations damaged their assessment of the team. citeturn17view0turn18view3

That suggests a correction to your phrase “quality of the computer partner.” There are at least two meanings:

**Playing strength** means maximizing expected points or win probability.

**Teammate quality** means taking actions that are strong *and comprehensible given the shared conventions and information of a human partner*.

The Hanabi evidence says those are not interchangeable. citeturn25academia29

Your competitor reviews are therefore useful corroboration rather than primary evidence. The current Pitch app you identified has thousands of ratings, while its review history includes the unusually memorable “I WANT A NEW PARTNER!” complaint and recurring complaints about partner bidding, leads, and failures that users perceive as nonsensical. Its developer has also repeatedly described AI improvements in release notes. Those reviews are self-selected and cannot establish causation, but they line up unusually well with the controlled Hanabi result: partnership AI errors are salient enough to dominate people's descriptions of an otherwise functional game. citeturn9search1turn9search3turn9search5

### What I would change

Do **not** make “higher win rate against itself” your sole acceptance criterion for partner improvements.

Build a corpus of partnership decisions from your actual family rules and have the strongest family players label actions something like:

| Classification | Meaning |
|---|---|
| Clearly right | A knowledgeable partner expects this |
| Reasonable alternative | Not what I would choose, but defensible |
| Strange but explicable | Needs a clear strategic reason |
| Trust-breaking | A knowledgeable partner thinks “What on earth are you doing?” |

Then optimize **trust-breaking-error rate** before squeezing out the last fraction of a point of theoretical playing strength.

For your specific game, the regression cases should especially cover the decisions that create blame: bidding over the human partner, leading trump or withholding trump, feeding or withholding a five, deciding whether to take a point now versus preserve control, interpreting what the partner's prior plays imply, and changing strategy when the contract is in danger. Those examples come from your rules and therefore do not require changing the game.

Also test **consistency**. A slightly suboptimal partner whose behavior a family member learns can be easier to coordinate with than an opaque maximizer that unpredictably changes what the same signal “means.” That is an inference from the Hanabi work rather than a Pitch-specific experimental result, but it is exactly the distinction the researchers' trust and interpretability measurements expose. citeturn25academia29turn18view1

I found **no clean experiment** that holds agent competence constant and randomly assigns the same bad artificial player to the role of teammate versus opponent in a partnership card game. So your stronger hypothesis—*a bad partner hurts much more than an equally bad opponent*—remains unproven.

But I would still treat it as the leading engineering hypothesis. An opponent's good or bad play changes the challenge. A partner's inexplicable play changes whether the player feels that **their own good decisions can matter**. That latter mechanism potentially attacks competence and agency at the same time.

**Monday-morning decision: improve the partner first.**

## Return is not the same variable as enjoyment, and game research often quietly substitutes one for the other

**Falsifiable claim:** *Once somebody already likes and understands a fixed card game, month-scale recurrence will depend partly on variables that are not captured by “How much did you enjoy that session?”*

**Confidence: high that enjoyment and recurrence are distinct constructs; moderate that context/startup friction will matter materially for this particular family.**

You were right to be suspicious here.

A canonical game-motivation paper, Ryan, Rigby, and Przybylski's 2006 application of self-determination theory, found that autonomy and competence predicted enjoyment and preferences for future play; in its multiplayer survey, autonomy, competence, and relatedness also independently predicted intended future play. One of the laboratory studies included an actual behavioral choice to continue with one game versus another, where competence was predictive. This is better than merely asking “was it fun?” citeturn19search3

But even that literature does **not** answer your success criterion cleanly. “How many months do you plan to keep playing?” and an immediate choice to continue are not the same outcome as noticing that Aunt Jane voluntarily opens the same app six weeks later. Much game-experience research stops at enjoyment, preference, intention, or short-duration play behavior rather than observing long-term household recurrence. citeturn19search3

A different literature—habit formation—does observe repeated behavior longitudinally. In one 2022 investigation, an experimentally manipulated six-week student study and a separate naturalistic habit sample found that repeating behavior in a more stable context was associated with greater automaticity and better goal attainment; the two studies involved 95 students with 2,482 repetitions and 218 users with 2,368 repetitions, respectively. This was **not gaming research**, which matters enormously for how cautiously it should be transferred. citeturn24view1

The useful implication is not “gamify a habit.” It is almost the opposite.

A game that becomes a small household ritual benefits when its invocation has a stable shape:

**open → recognize where I am → play.**

Not:

**open → remember what this app wants → dismiss something → choose something → reconfigure something → reconstruct what I was doing → play.**

Your resumable saved game is therefore more important than it may look. It does not make a hand more entertaining. It preserves the possibility that a half-finished game remains an easy activity to re-enter.

I would treat these as separate variables:

\[
\text{Return likelihood} \neq \text{session enjoyment}
\]

A more useful working model for this app is:

\[
\text{Return} \approx
f(\text{desire to play},
\text{trust},
\text{anticipated competence},
\text{availability cue},
\text{cost of restarting})
\]

That equation is a design model, not a validated statistical model.

There is an especially important asymmetry here. **Start friction can matter without ever appearing in a post-game satisfaction questionnaire**, because the person who encounters the friction may never start the session whose enjoyment you would have measured.

### What this means for your backlog

I would **not** launch into a broad polish pass. You already possess the important structural feature: resumability.

Instead, audit only the transition from intention to first meaningful card decision:

**cold launch → playable hand**

**saved game → next decision**

**finished match → another match**

Count taps and interruptions. Do not put a statistics screen, tutorial reminder, recap, modal, difficulty question, or feature announcement in that path unless the player asks for it.

This is one of the few places where the hundredth play should dominate the first. A tutorial needs to be discoverable once. The core path needs to disappear cognitively forever.

And measure the outcome you actually care about. An entirely local, private log can store session date, whether a game was resumed or started, whether a match was completed, and time from launch to first decision. No account or telemetry service is necessary. With one small family you will not get publishable statistical power, but at least you will stop mistaking “everyone said it was nice at Christmas” for recurrence.

## The AI partner need not satisfy human relatedness to create a real teammate relationship

**Falsifiable claim:** *An artificial partner can generate trust, coordination, obligation, and betrayal-like reactions that materially affect the game experience even if it does not satisfy SDT relatedness in the same sense as another human.*

**Confidence: moderately high. Confidence that an AI teammate fully satisfies the SDT need for relatedness: low.**

Here I would resist both extremes.

Your statement that the game “structurally cannot offer relatedness” is **too strong** if by relatedness you mean any psychologically social relationship with the partner. But saying “the AI partner satisfies the player's SDT relatedness need” would go beyond the evidence.

The original game-SDT work operationalized relatedness largely through connection with other players and found it independently related to enjoyment and intended future play in online multiplayer contexts. That does not establish that a bot is interchangeable with a person. citeturn19search3

Human–AI-team research, however, makes it difficult to treat an artificial teammate as merely another mechanical subsystem. In the Hanabi experiment, people made sharply differentiated judgments about whether the agent understood them, whether they understood it, whether it was reliable, whether they trusted it, and whether they wanted it as their partner. Those judgments diverged from objective team score. citeturn25academia29turn18view3

A separate survey study of AI teammates in online-game contexts found perceived rapport associated with trust in AI teammates and trust associated with intention to cooperate with them. That study was cross-sectional, so it cannot establish that increasing rapport *causes* continued cooperation, and its context is not an offline family card game. citeturn25search19

The broader human-autonomy literature likewise treats interdependence, predictability, communication, benevolence, and coordination as central to whether an artificial system is experienced as a teammate rather than simply a tool. Much of that literature comes from military, robotics, or laboratory teaming contexts, so transfer to Pitch should be cautious. citeturn11view2

This resolves an apparent paradox in your competitor evidence.

A player does not need to believe:

> “This is a conscious being I am emotionally attached to.”

to sincerely experience:

> “My partner screwed me.”

The second reaction requires much less psychology than the first.

A partnership establishes a shared goal. The computer occupies the seat that, in the family's original game, belongs to a person whose decisions interact with yours. The user therefore has to construct a model of what that seat will do. When the partner violates that model, the player can experience the equivalent of coordination failure whether or not genuine interpersonal relatedness is being satisfied.

### Do not spend this insight on fake personality

I would **not** respond by adding conversational banter, a cute avatar, simulated affection, or a “relationship” system.

The empirical signal points much more strongly toward **contingent competence**:

*It noticed what I did.*

*Its next play made sense in light of what I did.*

*It did not sabotage the implication of its own earlier play.*

*When it made an unusual choice, there was a defensible reason.*

That is the form of “relationship” your software actually needs.

One particularly promising extension of your existing hand review would therefore be **partner legibility**. When a family member asks “Why did my partner do that?”, the review should be capable of answering using only information the partner possessed at the time.

For example:

> “At this point your partner had seen X, Y, and Z. Given those cards, it expected ____. That is why it played ____.”

And, critically, sometimes:

> “That was a partner error. Playing ____ was better.”

A system that rationalizes every move after the fact will eventually destroy trust. A system capable of admitting its own error can distinguish **bad luck**, **reasonable disagreement**, and **actual AI failure**.

That feature serves teaching and partner quality simultaneously.

## Your ban on card-counting aids is too absolute, but an automatic perfect tracker is still the wrong default

**Falsifiable claim:** *An always-visible perfect card-history/counting aid would improve novice in-session performance but would, for at least some players, reduce acquisition or exercise of the counting skill that contributes to long-term mastery.*

**Confidence: moderate. The general cognitive evidence is good; the transfer to this card game has not been directly tested.**

This is where I would most carefully separate three things people casually call “assistance”:

**Removing clerical work.**

**Scaffolding a skill.**

**Performing the skill instead of the player.**

They are not psychologically equivalent.

Research on cognitive offloading—the use of an external aid instead of internal memory—shows why. Offloading can improve immediate task performance because information no longer has to be maintained internally. But experimental work also documents poorer memory for information that has been externally offloaded under some conditions. Later studies emphasize that the size and persistence of this cost depend on the task, the person's intentions, and whether the person continues actively encoding the information. citeturn25search0

The concern is important enough that recent work on AI and automation explicitly warns that assistance can conceal weaker underlying independent skill: aided performance can look excellent while unaided ability develops less or decays. That 2024 paper is a **theoretical perspective synthesizing existing automation and cognitive research, not a new experiment**, so it should not be treated as direct evidence that an iPhone card tracker will degrade your family's card-counting ability. citeturn23search0

There is also a counterweight: external aids can free limited cognitive capacity for higher-level reasoning. A beginner who cannot simultaneously remember previous cards, understand trump, evaluate partnership implications, and choose a play may learn more about strategy if part of that burden is temporarily reduced. The literature therefore does **not** establish a universal boundary where “helpful tedium removal” ends and “skill destruction” begins. That boundary depends partly on what performance you regard as constitutive of expertise.

For your inherited game, you have already supplied that missing normative fact:

**remembering what has been played is part of being good at this game.**

That matters.

If arithmetic on the final score is not a valued family skill, automate it freely.

If detecting illegal moves is not a valued skill, prevent them.

If shuffling, dealing, sorting the hand, persisting state, and calculating nine points are administrative machinery, let the phone do them.

But if noticing that the important fives/trumps have or have not appeared is part of how one becomes an expert family player, a perfect always-on ledger is not merely UI convenience. It substitutes for part of the play.

### Novices complicate the answer

There is a well-replicated instructional phenomenon called the **expertise reversal effect**: instructional supports that help people with little prior knowledge can become redundant or reduce learning efficiency for people who already possess the relevant schemas. A 2025 meta-analysis found evidence for the effect across the instructional literature, strengthening the case against one fixed level of guidance for everybody. citeturn25search1

That makes your existing **assistance mode** conceptually better than a universal counting feature.

If counting really is a beginner bottleneck, I would test progressively weaker scaffolds:

> “Would you like help practicing what has already appeared?”

is better than silently maintaining an omniscient display.

A stronger design would make the player **externalize their own count**. For instance, in assistance mode the player could tap which critical cards they believe have already been played, and the software could check that model after the trick or hand. The software is then supporting deliberate practice rather than substituting perfect memory.

Another possibility is retrospective reconstruction:

> “At trick four, which fives did you already know were gone?”

Let the player answer first. Then show the record.

That turns the capability your software trivially possesses into a **test of memory**, rather than replacement for memory.

This specific interface has not, to my knowledge, been experimentally tested in a Pitch-like game; it is an application of retrieval-practice and offloading principles, not a research finding about card apps.

### My decision on the feature

**Do not build an automatic card tracker now.**

I would move it outside your next six increments unless actual observation shows that novice family members are abandoning the game specifically because remembering prior play overwhelms everything else.

If that happens, build a **fadeable training aid**, not a permanent perfect ledger.

Your original instinct was directionally right. The part I would discard is the word **never**.

## Beginner-friendly software should disappear as expertise rises

**Falsifiable claim:** *Some help that improves the first five games will reduce the quality of the fiftieth game if it cannot be silenced or faded.*

**Confidence: high for the general learning principle; moderately high for this implementation.**

This is one of the strongest general findings that transfers to your situation.

Novices lack organized domain knowledge. Explicit examples, prompts, explanations, and guidance can reduce pointless cognitive load and show them what information matters. Once that knowledge becomes internalized, the same explanation has to be processed alongside information the expert already possesses; assistance becomes redundant and can interfere rather than help. That pattern is the expertise reversal effect, now supported by a substantial experimental literature and meta-analytic evidence. citeturn25search1turn25search10

Your direct card-game evidence points the same way from another direction. Experienced Hanabi players were **more bothered**, not less bothered, by an AI teammate whose choices violated their expectations. Expertise gave them a better model of how partnership play ought to work, which made incoherence more visible. citeturn17view0turn18view3

This has a fairly severe consequence for one-family-one-app design:

**Do not design the experienced interface as “beginner mode plus things the expert has learned to ignore.”**

The hundredth game should be nearly devoid of instruction unless the player asks for it.

That means your assistance architecture should satisfy three properties:

**Optionality.** Strategic assistance should not appear merely because the software knows something helpful.

**Persistence.** Once a person says “I don't need this,” do not make them dismiss it every game.

**Fading.** Help can become less explicit as performance or preference demonstrates that it is no longer necessary.

You do not need an account to do this. A small set of local player preferences or a remembered assistance level is enough.

There is also a useful distinction between **mechanical transparency** and **strategic coaching**.

Showing whose turn it is, what the bid currently stands at, the score, who took the previous trick, or why a tap was illegal does not meaningfully perform the player's strategy.

Telling the player “lead the five because only one trump is likely outstanding” does.

The first category can remain indefinitely. The second should be pull-based or fade.

This suggests a good test for every aid:

> **After the player has mastered the game, does removing this aid make them worse at the actual family game played with physical cards?**

If yes, the aid was probably substituting for a transferable skill.

If no, it was probably removing interface friction or bookkeeping.

That test is a design heuristic, not an established psychometric boundary. But it maps your actual product goal much better than asking whether a feature makes the phone version easier.

## “After the hand” is not the evidence-based dividing line; “after the decision” is

**Falsifiable claim:** *For strategic learning, preserving an unaided attempt before revealing advice matters more than whether feedback arrives immediately after that attempt or several minutes later at the end of the hand.*

**Confidence: moderate. Confidence that end-of-hand feedback is universally superior: low.**

This is the belief I would most directly revise.

The research literature on **feedback timing** is messy. Experiments have found immediate feedback advantageous in some learning tasks; other studies find delayed feedback equivalent or superior under particular conditions, and reviews repeatedly conclude that the outcome depends on what is being learned, what feedback contains, the delay interval, and what later test is used. citeturn5search7turn5search16turn25search18

So there is no defensible general rule:

> delayed = better learning.

What *is* much easier to defend is the distinction between **feedback** and **preemption**.

These sequences are fundamentally different:

**A**

> Situation → software says what to do → player does it.

**B**

> Situation → player decides → software explains outcome.

B preserves the cognitive act you hope the person will learn to perform independently. A may produce better game performance while giving you very little evidence that the player could have made the decision.

Your existing post-hand feature is therefore pointed in a good direction, but not because “after hand” possesses some special educational property.

Its advantage is that it can preserve **epistemic honesty**.

You can reconstruct:

> “Here is what had happened by trick four.”

rather than:

> “Knowing all four hands, here is the move that happened to work.”

That distinction is especially important in a luck-and-hidden-information game. Retrospective engines easily commit hindsight fraud: once the software knows every card, an action can appear obviously right even though it was not justified from the player's information set.

### I would redesign review around decisions, not hands

A review is unlikely to become better merely by becoming more exhaustive.

For each hand, select perhaps one or two decisions where the alternatives actually mattered. Then use this structure:

**What could you know?**

Ask the player—or at least make them mentally reconstruct—which important cards had already appeared and what the bidding/play had revealed.

**What did you choose?**

Keep the original decision visible.

**What was reasonable at that moment?**

Evaluate alternatives using only the information available then.

**What happened afterward?**

Only now distinguish outcome from decision quality.

This lets you explicitly teach the crucial lesson:

> “This lost, but it was a good decision.”

or:

> “This won, but it was risky for reasons you could already have known.”

That separation is particularly valuable in a game containing both skill and deal luck.

### Keep your live hints

I would not remove hints.

Make them **requested assistance**, particularly for beginners. A player who is stuck enough to ask “What am I missing?” is in a different state from a player whom the software interrupts with the correct answer before they have tried.

Where immediate teaching is useful, a good compromise is **feedback immediately after commitment**, not before it. Depending on how sacred the physical-game rhythm feels, that could mean after a card is played, after the trick resolves, or after the hand. I would avoid popping instructional prose into every trick; not because delayed feedback has proved superior, but because unsolicited interruption damages the actual act of playing.

So your belief becomes:

> **Let players play unaided by default; teach from completed decisions.**

That is stronger than “always wait until the hand is over.”

And yes: **post-hand teaching earns its place**. I would invest in it, particularly because your software already possesses the complete history necessary to answer the unusually valuable question you posed: *“What could you have known at trick four?”*

## Loss should be made legitimate and intelligible, not softened

**Falsifiable claim:** *In a fixed luck-bearing partnership game, truthful explanations of why a loss occurred will protect replay better than interventions that merely make losing rarer.*

**Confidence: moderate on the underlying mechanisms; moderate-low on the specific retention effect, because I found no Pitch-like randomized trial of loss explanations.**

The direct retention evidence says something subtler than “people quit because they lose.”

A 2024 study used **42 days of actual server logs covering roughly six million matches and more than 262,000 players** in a commercial competitive game. Players facing substantially stronger opponents had greater churn, while higher win rate and winning streaks were associated with lower churn. But losing streaks did **not** have one simple universal relationship with churn: the effect changed with the player's phase/experience. This is observational multiplayer evidence from a very different game, so it cannot tell you how many lost Pitch matches your uncle will tolerate. It does show why “loss = quit” is too crude a model. citeturn21search0

Experimental game research more generally links successful performance and perceived competence to more positive player experience, consistent with self-determination accounts in which competence satisfaction contributes to enjoyment and motivation. citeturn19search3turn6search4

Your app, however, cannot legitimately manipulate the central cause of losses. The deal is the deal. Nor should it: secretly giving a returning player favorable cards would damage the very family game you are trying to preserve.

That leaves **attribution** as the software lever.

There are at least four psychologically different losses:

> **“I played well and the cards didn't break.”**

> **“I now see the mistake I made.”**

> **“My partner made a reasonable decision that happened not to work.”**

> **“This stupid computer threw the game.”**

All four produce the same final score.

They are not the same product outcome.

The fourth is uniquely dangerous because it tells the player that improving their own skill may not fix the source of frustration. This is one reason the partner work and the loss problem are really the same work.

### Your review should adjudicate blame honestly

For consequential losing hands, let review make three distinctions explicit where it can do so reliably:

**Unavoidable uncertainty.**  
“You could not know East held the remaining trump.”

**Player decision.**  
“Given what had already been played, holding the five gave up the safer line.”

**Partner decision.**  
“Your partner chose X because of Y.”

And occasionally:

**Partner error.**  
“Your partner's play was a mistake; Z was the stronger choice.”

That final category is important. The purpose is not to make the AI apologize theatrically. It is to prevent the system from gaslighting the player.

A knowledgeable family player who correctly identifies a ridiculous partner play and is then shown an elaborate explanation of why the machine was supposedly brilliant has now suffered **two** failures: the original play and an untrustworthy explanation.

The Hanabi findings make this more than aesthetic speculation: perceived reliability, understanding, trust, and avoidance of obvious-seeming mistakes were central to partner preference even when scores did not separate the agents. citeturn25academia29turn18view1

Do not congratulate people after losses. Do not manufacture consolation. Do not turn the review into “you did great!” therapy.

Make the loss **legible**.

Then make “play again” effortless.

# The work order I would actually use

Taking the evidence together, this is how I would spend the next six increments.

| Order | Increment | Why it outranks the alternatives | What I would measure |
|---|---|---|---|
| **First** | **Partner regression suite and elimination of trust-breaking plays** | Closest direct experimental analogue says AI-partner preference can diverge sharply from objective score; obvious and inexplicable teammate behavior damages trust. citeturn25academia29turn18view1 | Curated family-expert scenarios; percentage of decisions classified “unreasonable/trust-breaking”; real complaints after play. |
| **Second** | **Partner predictability and partnership intelligence** | The target is not just stronger AI but an agent humans can form a working model of. Experienced players are particularly sensitive to incoherent teammates. citeturn17view0turn18view3 | Blind paired games against old/new partner; “Which partner would you rather play another match with?” plus specific disagreement cases. |
| **Third** | **Turn hand review into a decision audit, including partner rationale and honest partner errors** | One feature can simultaneously improve trust after losses and teach skill. It also exposes AI defects you otherwise will not notice. The exact retention benefit is inferential, but it follows directly from the trust findings. citeturn25academia29 | Can a knowledgeable player answer “why did partner do that?”; number of review moments where hidden future information contaminates the explanation. |
| **Fourth** | **Teach after commitment rather than automatically before decisions** | Your post-hand intuition is useful, but whole-hand delay itself is not proven superior. Feedback-timing evidence is mixed; preserving the player's attempt is the more defensible target. citeturn5search7turn5search16turn25search18 | Later **unassisted** decisions on analogous situations, not number of hints opened or review screens viewed. |
| **Fifth** | **Make assistance genuinely fadeable and remember the player's preference** | Novice scaffolding and expert play have different requirements; the expertise-reversal literature argues against one fixed guidance level. citeturn25search1 | Experienced players reach play without unwanted coaching; novices can request help; assistance use can decrease without losing core usability. |
| **Sixth** | **Audit return friction and add tiny local measures of actual recurrence** | Your true outcome is next-month return, while much game research measures immediate enjoyment/intention. Stable behavioral contexts matter in longitudinal habit research, although that evidence is not game-specific. citeturn19search3turn24view1 | Launch-to-decision time/taps, resume completion, voluntary rematch, days until next session, 30-/60-day return. |

**The counting aid does not make this list.**

That is not because assistance is inherently corrupting. It is because you already have tutorial, hints, undo, review, statistics, saved games, and an assistance mode, while the directly analogous evidence points at the **partner** as a much more dangerous failure point. Cognitive-offloading research gives you enough reason to be cautious about automating a skill you specifically want players to retain, and not enough evidence that a perfect ledger would solve a retention problem you know you have. citeturn25search0turn23search0

I would revisit counting only after observing a real novice failure pattern such as: *“I understand bidding and trick play, I want to keep playing, but holding played cards in memory is so overwhelming that I stop.”* At that point, the experiment should be a temporary active scaffold, not an always-on answer sheet.

The post-hand teaching feature **does** earn continued investment, with one change in objective. Do not optimize it for “amount of explanation delivered.” Optimize it for **better independent decisions next time**.

And the computer partner should get the largest share of attention. The strongest conclusion of this research is not merely that players dislike stupid AI. It is more specific:

> **In a partnership game, the software partner becomes part of the player's effective ability to act. A partner that is strong but inscrutable can be worse to play with than one that is equally effective but understandable; a partner that makes conspicuously foolish decisions can make the player's own skill feel irrelevant.** citeturn25academia29turn18view3

For a free, offline family game with no extrinsic retention machinery, that is about as high-leverage a defect as software can create.