# HUNCH — Game Design Document

**A rule-induction puzzle game for iPhone. Offline, wordless, procedurally generated.**

Version 1.0 · 27 July 2026 · derived from `hunch-claude-code-prompt.md`

---

## 0. Front matter

### 0.1 What this document is

This is the **design of the game** — what HUNCH is, how it plays, what is in it, and what every system does. It is written to be built from: an engineer should be able to open any section and implement it without asking a question, and every number in it is a number some other section agrees with.

It is deliberately **not** a build plan, a schedule, an architecture document, or code. The build brief owns the architecture, the tech constraints and the phase gates; §14.3 maps this design onto those phases and stops there.

Where the brief was silent, this document **decides** and says why. Those calls are marked `> **Decision:**` throughout — there are 60-odd of them, and they are the audit trail. Where the brief was wrong for the game, the document says so explicitly and overrules it; there are four such places (§3.5 sequence semantics, §4.5 two strikes, §11.9 Induction as a mean, §11.5 no export), each with its reasoning attached.

### 0.2 The game in one page

The player has found **the Loom** — a machine left behind by people who are gone. It accepts one **glyph** at a time and answers with exactly one bit: **admit** or **reject**. Behind that bit sits a **law**, a hidden predicate over the 256-glyph deck, that the Loom will never state.

The player **probes** the Loom, reads the **ribbon** of accumulated verdicts, and when they think they know the law, they **assemble it on the Bench** out of rule-tiles and press **the Seal** — stating the machine's own logic back to it in the machine's own notation. Correct, and the law is inscribed as a page in **the Codex**. Wrong, and the Loom answers with exactly one **counterexample** and nothing else.

**Nothing is ever explained in words, because there are no words.** The play surface contains zero text in every one of the twelve shipped languages — verdicts are ring geometry, budgets are tick marks, the law itself is a diagram. This is what makes twelve languages nearly free, and it is a hard constraint, not an aspiration.

| | |
|---|---|
| **Deck** | 256 glyphs — 4 attributes × 4 values (fill, shape, pips, hue), every one readable without colour |
| **Law space** | **27,015 distinct laws**, enumerated exhaustively over the real deck, not estimated |
| **Bands** | 8, one law family each — each band demands a *conceptual move* the previous one did not |
| **Modes** | PROBE (the core), DRIFT, ECHO, SIEVE |
| **Difficulty** | adaptive, Rasch-style, targeting an 80 % success rate, never shown as a number |
| **Meta** | the Codex (archive), the Anomaly (one law a day, the same law worldwide, zero server), the Profile (a shape, not a score) |
| **Business model** | paid once. No IAP, no ads, no lives, no timers, no accounts, no network of any kind |

### 0.3 The eight bands, at a glance

Difficulty is **structural** — it is the *family* of the law, not the number of clauses in it. This is the single largest bet in the design, and §5.1 argues it.

| Band | Family | The conceptual move it demands | Laws | par |
|---|---|---|---|---|
| 1 | LITERAL | "one thing matters" | 40 | 7 |
| 2 | PAIR | "two things matter at once" | 1,272 | 13 |
| 3 | EXCLUSIVE | "truth is not monotone in any attribute" | 108 | 16 |
| 4 | RELATIONAL | "the law names no value" | 2,322 | 20 |
| 5 | CONTEXTUAL | "a glyph has no verdict by itself" | 6,934 | 23 |
| 6 | GUARDED | "the law is piecewise; your theory has a region" | 5,688 | 23 |
| 7 | COMPOSITE | "hold two of the above at once" | 10,314 | 26 |
| 8 | SYSTEMIC | "no attribute is privileged" | 337 | 29 |

Band 8 has the *smallest* hypothesis space in the game and is the hardest band in it, because the human prior does not contain attribute-symmetric hypotheses at all. A difficulty function based on entropy or term count would rank it easier than band 2. That single fact is why difficulty here reads the family.

### 0.4 How to read it

Read **§1 → §6** for the game. Read §7–§9 for the other three modes, §10–§11 for the systems around the round, §12–§13 for the surface, §14 for the checklist.

The document cross-references heavily and by design: **every quantity has exactly one normative home**, and every other section that uses it cites rather than restates. When two sections disagree, the owner below wins.

| Quantity | Owner |
|---|---|
| Glyph model, terminology, enum value names | §2 |
| The grammar, sequence semantics, equivalence | §3 |
| The declaration interface and its gestures | §4 |
| `difficulty(of:)`, the band table, par/cap, locked constants | §5 |
| PROBE's round, scoring and persistence | §6 |
| Each mode's own rules, budgets and transcript quantities | §7, §8, §9 |
| **Mode unlock gates** | §9.10, once, for all four modes |
| Ability estimation and the serving policy | §10 |
| The Anomaly's derivation | §11.6, once |
| **All five Profile axis formulas** | §11.9, once |
| The on-disk file tree and the reset map | §11.13 |
| Screens, navigation, Settings, the localization surface | §12 |
| **Every audio cue, every haptic pattern, the palette** | §13 |
| The feature checklist, scope and risks | §14 |

### 0.5 Status

Everything needed to build the game is decided. **Eight questions remain genuinely open** (§14.5) — price tier, the name, suspended-round slot count, when the band index is built, CI cadence, translation process, app icon, and one accessibility question — and each carries a recommended default, so none of them blocks a phase.

The three things most likely to be wrong, in order, are: that the loop stays interesting past twenty minutes; that the wordless declaration interface is learnable; and that `difficulty(of:)` predicts real failure rates. All three have falsifiable early signals and named gates in §14.6, and the second one is a hard gate on phase 3 — five people who have never seen the game must each state `shape ∈ {triangle}` unaided, on video, before PROBE is called done.

---

## Contents

| § | Section |
|---|---|
| **1** | **The Game** — premise, pillars, core loop, ancestry, copy and claims policy |
| **2** | **The Glyph Vocabulary** — the four attributes, redundant encoding, locked terminology |
| **3** | **The Rule Grammar** — BNF, predicate inventory, sequence semantics, equivalence |
| **4** | **Declaring a Law** — the Dial, the Bench, the Assay, expressiveness parity, the counterexample |
| **5** | **Difficulty and the Law Generator** — `difficulty(of:)`, the band table, guardrails, par, worked rounds |
| **6** | **PROBE — the core mode** — state machine, layout, verdicts, declaring, scoring, persistence |
| **7** | **DRIFT** — the hinge, the two laws, cling, the reveal |
| **8** | **ECHO** — the pool, the primer, the cast, why it is not a memory task |
| **9** | **SIEVE** — the gate, the speed curve, fouls, and the four modes side by side |
| **10** | **Adaptive Difficulty, Pacing and Progression** — the Rasch model, the serving policy, the harness |
| **11** | **The Meta Layer** — the Codex, the Anomaly, the Profile, statistics, persistence |
| **12** | **Screens, Navigation, Onboarding and Settings** — 18 screens, onboarding by doing, the localization surface |
| **13** | **Art Direction, Motion, Audio, Haptics and Accessibility** — the palette, the money shot, the cue table, VoiceOver |
| **14** | **Feature Inventory, Scope and Open Decisions** — the build checklist, the MPP, risks |

---
## 1. The Game

### 1.1 The pitch

> A machine left behind by people who are gone admits some glyphs and rejects others according to a law it will never state; you probe it until you can say the law back in its own language.

### 1.2 Premise and player fantasy

The player has found **the Loom**: powered, idle, no manual, no labels, no language, no interest in being understood. Its **throat** accepts one **glyph** at a time and answers with exactly one bit — **admit** or **reject**. Behind that bit sits a **law**, a predicate over the 256-glyph **deck**, that the Loom will never articulate.

The fantasy is **archaeology, not combat**. There is no adversary. The Loom is not withholding the law out of malice; it has no faculty for saying it. It is indifferent, consistent and infinitely patient — it will answer the same question a thousand times and never tire, never taunt, never help. The player is the only agent in the room, and every fact on screen is a fact the player went and got.

The room is dark and the machine is the only lit object in it. Work is quiet: compose a glyph on the **Dial**, feed it, watch the verdict land in the **ribbon** — a dig site, an accumulating transcript that never lies and never forgets. When the player finally understands, they do not type an answer or pick from a list. They **assemble the law on the Bench** from **rule-tiles** and press **the Seal**, stating the machine's own logic back to it in the machine's own notation. Correct: a **page** in **the Codex**. Wrong: one **counterexample** and nothing else. That last move is the fantasy's spine — the player is not guessing a secret, the player is writing down a law and signing it.

### 1.3 The core loop — five steps

| # | Step | What happens | Player verb |
|---|---|---|---|
| 1 | **PRIME** | The round opens with a **seed glyph** already in the throat, drawn deterministically from the round seed. It carries no verdict and is not scored. It is `prev` for probe 1. | read |
| 2 | **PROBE** | Compose a glyph on the Dial (four single-select **ramps**), feed it. The Loom answers **admit** or **reject**. The tile enters the ribbon with a link arc to its predecessor. | experiment |
| 3 | **READ** | Read the ribbon. Form a hypothesis. Optionally open the Bench and watch the **Assay** — a 16×16 micro-grid of the whole deck — light up under the current draft. | infer |
| 4 | **DECLARE** | Assemble the law on the Bench from Ramp / Bridge / Fork / Tally tiles and one **coupler**. The **Seal** is physically barred while the draft is inert, unbound, or constant. | commit |
| 5 | **SEAL** | Correct → the law is inscribed as a Codex page with its mark count. Wrong → one counterexample, one **strike**, the round continues. Wrong twice, or reaching **cap** → the round ends and the law is revealed. | face it |

Steps 2 and 3 interleave freely and are the bulk of the round. Steps 4 and 5 happen once, or twice at most.

### 1.4 Design pillars

Five. Each states what it forbids and what observation would falsify it. A pillar you cannot violate is decoration.

**P1 — The play surface is language-free by construction.** No text, no numerals, no letterforms in the throat, ribbon, Dial, Bench, Assay or instrument bar, in any locale.
*Forbids* tooltips, hint text, numeric probe counters, difficulty labels, tutorial overlays, "Level 4", "Nice!", a text log, a legend. Par renders as tick marks; verdicts as ring state, tone and haptic. *Falsified by* any writing-system glyph in a screenshot of a play screen in any of the 12 languages — enforced by screenshot review in English, German and Arabic, plus the rule that no play-surface view may reference `LocalizedStringResource`.

**P2 — Evidence, never explanation.** The Loom's entire vocabulary is `admit`, `reject`, one counterexample when a declaration is wrong, and the full law when the round is already lost.
*Forbids* hints, nudges, "you're close", partial credit, graded feedback (Mastermind's key pegs are exactly this), highlighting the relevant attribute, narrowing the palette to the current family, a solver, a skip, any pity reveal mid-round. *Falsified by* any code path surfacing information about the hidden law other than (a) a verdict on a probe the player built, (b) the deterministic counterexample of §4.5, (c) the reveal on a lost round.

**P3 — The transcript is the truth.** Every verdict is a pure function of the visible probe sequence; a player can replay their own ribbon and re-derive every answer.
*Forbids* hidden state deeper than `prev`, randomness in verdicts, laws referencing off-screen history, counters, run lengths — anything the ribbon does not show. DRIFT's law-swap is disclosed after declaration and the swap point is marked in the ribbon on the results screen. *Falsified by* the determinism test: the same `(seed, mode, difficulty)` producing a different transcript across runs or processes.

**P4 — Difficulty is conceptual, never perceptual or manual.** The only thing that makes a round hard is the idea it demands; bands are separated by conceptual moves, not by more clauses.
*Forbids* time pressure, precision targets, reaction windows, reading speed, cross-session memorisation, small hit areas (minimum shipped target 56×44 pt), any load scaling with eyesight or hand steadiness. **SIEVE is the one quarantined exception** — a change of texture, never on the Codex's critical path, never the only route to anything. *Falsified by* any mode other than SIEVE having a clock, or any round outcome changing because the player was slower.

**P5 — Nothing is sold, timed, gated or withheld.** The whole game is on device at first launch, forever, offline.
*Forbids* IAP, subscriptions, ads, energy, lives, cooldowns, "watch to continue", daily play limits, login-streak rewards, push notifications, accounts, leaderboards, network calls of any kind. The Anomaly is one law a day because it is one law a day, not to manufacture a return obligation. *Falsified by* the no-network grep build phase failing, or any content reachable only after a wait or a payment.

> **Decision:** the only two business models P5 permits are free and paid-once; ship **paid-once, no free tier, no IAP** — because a free build with no monetisation surface has no honest funding story, and a single up-front price is the only structure that never asks the player for anything mid-round. Price tier is section 7's call.
>
> **Decision:** the Seal has **no confirmation dialog** — because the nerve of committing is the emotional payload of the round, and an "are you sure?" modal launders exactly the feeling we are selling. The bar across a barred Seal is a machine state, not a warning.

### 1.5 Why this concept specifically

- **Language-free by construction, not by translation.** The play surface has nothing to translate; 12 languages cost only menus, Settings, Codex chrome and the listing. A structural property, not a localisation effort.
- **Infinite by grammar, not by content pipeline.** 27,015 distinct laws fall out of a closed grammar over a 256-glyph deck, generated on device from a seed. No level designer, no downloads, no patch cadence, no "solved" state.
- **Cannot be brute-forced or looked up.** Laws are procedurally sampled and the novelty guard rejects the player's last 50. There is no walkthrough to write, and the daily **Anomaly** derives from `hash(UTC date)` — identical worldwide, zero server.
- **Hard in the interesting direction.** The gradient runs through *concepts* — "one thing matters" → "truth is not monotone in any attribute" → "a glyph has no verdict by itself" → "no attribute is privileged" — not through speed, precision or volume.
- **It works at 25 and at 70.** Nothing rewards fast hands or fast eyes. A 70-year-old who thinks carefully outperforms a 25-year-old who probes impulsively; the adaptive engine serves both at the same ~80 % success rate. Reference device: an iPhone SE, held one-handed.
- **It fits the box.** Vector glyphs, procedural audio, JSON persistence — no image assets, no audio assets, no dependencies, comfortably under 15 MB.

### 1.6 Who it is for, and who it is not for

**For:** people who enjoy interrogating a system — cryptic crossword solvers, Zendo and Set players, debuggers, people who read a board game's rules for pleasure. People who want a game with no social surface, and who will replay a round in their head on the walk home. Age is not a segment here; patience is.
**Not for:** players who want narrative, characters or world-building (there is a room and a machine and nothing else); visible numeric progression, XP, leaderboards or PvP; a sub-60-second filler (nothing here is one — a band-1 round runs about a minute and a SIEVE run about 45 seconds, and those are the two shortest things in the game); to be told they are improving — the Profile is a record of how you played, never an assessment of you; or to be taught before playing, because the tutorial is round 1 of band 1 and there is no other one.

### 1.7 The emotional arc of a single round

| Phase | Where | What it feels like | What the machine does |
|---|---|---|---|
| **Confusion** | probes 1 → ~0.2·par | "There is no pattern here." Verdicts arrive with no structure. | Nothing. It answers and waits. |
| **Pattern** | ~0.2 → 0.4·par | Two admits share something. The ribbon starts to look sorted rather than random. | Nothing. |
| **Hypothesis** | ~0.4 → 0.7·par | A theory forms and immediately wants to be confirmed. This is the trap. | Nothing. |
| **Nerve** | ~0.7 → 1.0·par | The draft is on the Bench, the Assay constellation matches every ribbon tile, the bar lifts off the Seal. The third Seal mark went at `0.6·par` and is not coming back; what is still on the table is the *second* mark and the flat-score region, and both end on one specific tick that the player can see approaching but cannot count to. The question is no longer "what is it" but "am I sure, and am I sure before that tick". | Fills one tick per probe. At the last par tick the row inverts and the dim row below begins emptying the other way — **the par crossing** (§6.9), the only direction reversal in the instrument bar and the only thing the machine ever marks that is not a verdict. |
| **Commitment** | one tap | Irreversible, unconfirmed, silent. | Nothing for 640 ms, identical whether you are right or wrong. The pause is designed. |
| **Reveal** | 1.6–2.5 s | Correct: the two readings of the law — the player's and the Loom's — register onto each other, the sweep passes, and the Bench becomes a Codex page. The one orchestrated motion in the app. Wrong: one glyph walks to centre wearing two contradictory rings. | Speaks, once, and stops. |

The reveal is the money shot and the only place motion is permitted to be theatrical. Everything else is instrument-panel calm.

### 1.8 Good play versus bad play

The distinction is **probing to confirm** versus **probing to falsify**, and the game rewards falsification without ever saying so. A probe returns exactly one bit; its information value is `H(p)`, where `p` is the player's own predicted probability of admit. Probing where you are confident is nearly free of information; probing where you cannot predict is worth a full bit. (The table is idealised — it ignores the family friction coefficient `k`, which only widens the gap.)

| Style | Predicted `p(admit)` | Bits/probe | Probes to cover band 5's 12.76 bits, + `d` = 5 | Outcome vs par 23 / cap 37 |
|---|---|---|---|---|
| Confirm-only, confident | 0.95 | 0.286 | ≈ 50 | **exceeds cap — loss** |
| Confirm-leaning | 0.90 | 0.469 | ≈ 32 | over par, 1 mark |
| Balanced / falsifying | 0.50 | 1.000 | ≈ 18 | under par, 2 marks |

**Good play:** hold three attributes fixed and move one; use the **twin** to test for statefulness at all; construct the glyph your hypothesis *rejects* and see whether the Loom agrees; sweep an attribute exhaustively when a subset may be scattered; **ribbon-load** a tile to vary it by one step.
**Bad play:** generating instances your theory already predicts will admit (the human default, and the reason the admit-rate ceiling is 0.60 rather than 0.85); moving several attributes at once *late*, when the answer hinges on one; declaring early to farm a counterexample.

Four mechanisms enforce this, none ever explained to the player. (1) **`par` is an information budget**, `ceil(k·log₂|H| + d)`, and it is priced at both ends: a third Seal mark below `0.6·par`, a flat score up to `par`, continuous score decay past it, and the round ending at `cap = 1.6·par`. Confirming play does not merely miss par — the top row of the table above runs to ~50 probes against a cap of 37, so it is a **loss**, arithmetically, not a poor score. (2) **The counterexample prefers false negatives** — cases the hidden law admits and the declaration rejects — which targets the over-narrow hypothesis, precisely what confirmation-only probing produces. (3) **A strike costs 40 % of score** and marks the page with a **fracture**, pricing "declare to learn" above "probe to learn". (4) **The twin is never blocked or penalised**, because under previous-probed semantics it is the single most informative probe in the game.

> **Decision:** the game never labels a probe good or bad — no "efficient!" toast, no post-round probe-quality breakdown, no efficiency star. Reason: naming the strategy converts an insight the player owns into an instruction they follow, and P2 forbids the machine having an opinion about the player's reasoning.

### 1.9 A worked round — band 1, the first minute of the game

Hidden law `fill ∈ {striped}` (`|H|` = 40, 5.32 bits, `p` = .250, δ = .023, **par 7, cap 12**). Seed glyph primed in the throat: **dotted square, two pips, teal**.

| # | Probe | Verdict | Purpose |
|---|---|---|---|
| 1 | hollow circle, one pip, amber | reject | baseline |
| 2 | **striped** circle, one pip, amber | **admit** | fill varied alone → fill is pivotal here. ~1 bit |
| 3 | **solid** circle, one pip, amber | reject | so it is not "anything but hollow" |
| 4 | **dotted** circle, one pip, amber | reject | fill sweep complete: only `striped` admits on this row |
| 5 | striped **hexagon, four pips, rose** | **admit** | hold striped, move all three others → they are jointly free |
| 6 | striped **triangle, three pips, frost** | **admit** | second joint check |
| 7 | **hollow** hexagon, four pips, rose | reject | **the falsifier.** If the law were "hexagon OR striped", this admits. It rejects |

Declaration: one **Ramp** tile, header `fill`, cell `striped` lit — three taps (palette stamp, header, cell). 7 probes = par → **2 Seal marks**, page inscribed, no fracture. Probe 7 is the whole lesson: a confirming player declares at probe 6 with an untested disjunction and eats a strike. On screen it is equally short — ticks fill in the instrument bar (y 20–64), the live glyph sits in the throat (64–176), tiles accrete in the ribbon (176–228), all seven probes are built on the four Dial ramps (236–508) with probes 3, 4 and 7 costing one tap each because the Dial retains the last probe; then the Bench handle at y 516 pulls up, the Assay lights 64 of 256 cells, the bar lifts off the Seal, and the round ends. Total elapsed: about 65 seconds, and the player has been taught the ramp, the Dial, the ribbon, the Bench and the Seal without reading a word.

### 1.10 Session shape

| Band | par | Median probe interval | Typical round, incl. declaration + reveal |
|---|---|---|---|
| 1 LITERAL | 7 | 6 s | **≈ 1:05** |
| 2 PAIR | 13 | 7 s | ≈ 2:05 |
| 3 EXCLUSIVE | 16 | 10 s | ≈ 3:15 |
| 4 RELATIONAL | 20 | 11 s | ≈ 4:25 |
| 5 CONTEXTUAL | 23 | 14 s | ≈ 6:25 |
| 6 GUARDED | 23 | 15 s | ≈ 6:55 |
| 7 COMPOSITE | 26 | 18 s | ≈ 9:00 |
| 8 SYSTEMIC | 29 | 20 s | ≈ 11:00 |

A **round** is one law start to verdict; a **run** is consecutive rounds in one sitting.

> **Decision:** the target sit-down is **8–15 minutes** — one top-band round, or three to six low-band rounds, or the Anomaly plus one. Reason: it is a single commute, and the longest span for which suspend-and-resume is a safety net rather than the primary flow.
>
> **Decision:** there is no session structure of any kind — no daily quota, no "3 rounds then rest", no end-of-run summary that must be dismissed. Reason: P5. A run ends when the player stops. Mid-round state persists after every probe, so quitting mid-round is free and lossless, including mid-Anomaly.

### 1.11 Failure states and edge cases

| Situation | Behaviour |
|---|---|
| First wrong declaration | **Strike.** One counterexample, two rings, law-broken haptic. Round continues, probe count keeps running, player may declare again. |
| Second wrong declaration | Round ends as a loss. True law animates in full rule-tiles. Nothing inscribed. |
| **Cap** reached | Round ends as a loss. Law revealed. The adaptive engine needs a failure signal that is not solely "declared wrong". |
| Seal pressed while barred | The offending rail pulses. No text, no modal, no error state. The machine is simply not ready. |
| App killed mid-round | Resumes at the exact probe, with the ribbon, Dial state and Bench draft intact. Not a loss. |
| Saved round fails its integrity check on resume | The round is **voided**: no page, no score, no ability update, and the round card opens on a broken-seal state. Never silently altered — the machine does not hand back a round it cannot vouch for. |
| **Abandon** (instrument bar) | Ends the round, no page, and **is recorded as a loss** for the ability estimate — because otherwise a player dodges every hard law and the estimate becomes unidentifiable. Requires a second tap on the same control; that is the one place a confirmation is correct, because the input is destructive and not the round's dramatic beat. |
| Anomaly, second attempt same day | Not offered. One attempt per UTC date, win or lose. |
| Device clock moved forward | Future Anomalies are playable (it is offline; this is unenforceable), but the streak counts only distinct UTC dates in non-decreasing order, so clock-rolling cannot inflate it. |
| Strike taken on the Anomaly | Streak forfeited even if the second declaration is correct. Page is inscribed with a fracture. |

### 1.12 Tone and voice rules

1. The Loom **never addresses the player** and **has no personality** — no second person anywhere except Settings labels, where it is unavoidable; no mood, no jokes, no lore dumps, no ghost-of-the-builders narration. Ambient, not characterful.
2. **No exclamation marks.** Anywhere. In any of the 12 languages.
3. **No praise and no commiseration.** No "Great!", "Nice try", "So close". The Codex page is the congratulation; the counterexample is the condolence.
4. **Numerals live outside the play surface only** — Codex, Profile, Settings. Never in the instrument bar, never on the Bench.
5. **Nouns over verbs, ≤ 8 words per string.** Register is instrument labelling: `probes`, `laws found`, `sound`, `language`. If a string needs a sentence, ask whether the screen needs the string.
6. **Never name a mechanic in text where a drawing works** — no glossary, no "what is a contextual law" page. The band, the family, the difficulty and the Rasch estimate are **never surfaced numerically or by name**.
7. The Profile is described only as *a record of how you played*. Never a measurement, a score, a level, an assessment, or a profile *of the player*.

### 1.13 Copy and claims policy

The FTC fined Lumosity **$2,000,000** in 2016 for cognitive-benefit claims. This is a compliance boundary, not a style preference, and it binds the App Store listing, screenshots, keywords, onboarding, Settings, the Codex, the Profile, release notes and every localisation. **Absolute rule:** no statement in or about this product may assert or imply an effect on memory, attention, focus, intelligence, IQ, reasoning ability, work or academic performance, ageing, cognitive decline, dementia, stress, anxiety, sleep, or any other health or cognitive outcome — not as a benefit, not as a hedge, not as a joke, not in a review reply.

| # | BANNED | APPROVED replacement | Why |
|---|---|---|---|
| 1 | "Train your brain" / "brain training" / "brain game" | "A rule-induction puzzle." | Category term carries an implied benefit. |
| 2 | "Improves memory / focus / concentration" | "ECHO: hold a rule in mind while you do something else." | Describes the *task*; promises nothing. |
| 3 | "Keeps your mind sharp" | "A machine with a hidden law." | Cognitive-maintenance claim. |
| 4 | "Boost your IQ" / "IQ test" / "measure your intelligence" | "How few probes can you do it in?" | Ability claim. |
| 5 | "Scientifically designed", "research-backed", "built on cognitive science" | "Eight families of law. 27,015 in total. All generated on your device." | Efficacy-by-authority. |
| 6 | "Reduces cognitive decline / protects against dementia" | *No replacement. Never say anything in this area.* | Disease claim. |
| 7 | "Your cognitive profile" / "brain age" / "mental fitness score" | "The Profile: a record of how you played, not a score." | Assessment claim. |
| 8 | "Get smarter every day" / "daily brain workout" | "The Anomaly: one law a day, the same law for every player." | Improvement + obligation. |
| 9 | "Sharpen your problem-solving skills" | "Probe the Loom. Work out the law. Say it back." | Skill-transfer claim. |
| 10 | "Relaxing", "reduces stress", "mindful", "therapeutic" | "Silent, patient, offline." | Health-adjacent wellness claim. |
| 11 | "Great for seniors / keeps ageing minds active" | "No reflexes required. Only SIEVE is timed." | Age-targeted health claim. |
| 12 | "Levels", "beat your high score", "compete with friends" | "Laws found. Probes used. Nothing is sent anywhere." | Not a claims issue — a design-integrity one (P5). |
| 13 | "Unlimited puzzles!" | "Every law is generated from a seed, so there is no list to finish." | Superlative + exclamation. |
| 14 | "Free", "try before you buy", "premium" | "Pay once. No ads, no purchases, no accounts." | Must match the shipped model exactly. |

**Enforcement is an engineering artifact, not a review checklist.** A test over `Localizable.xcstrings` (all 12 languages) plus the App Store metadata files fails the build on any match against a per-locale banned-token list, case- and diacritic-insensitive. The list is per language because the risk is highest in translation, where a well-meaning translator reaches for the local category term:

`en` brain, cognitive, memory, focus, IQ, mental, dementia, Alzheimer, smarter, sharper, train/training, workout, therapy, mindful · `de` Gehirn, Gehirnjogging, Denksport, Gedächtnis, Konzentration, geistig · `fr` cerveau, gymnastique cérébrale, mémoire, concentration, mental · `es`/`pt-BR` cerebro/cérebro, mente, memoria/memória, concentración/concentração, agilidad mental · `it` cervello, mente, memoria, concentrazione · `tr` beyin, zihin, hafıza, zeka · `ru` мозг, память, внимание, интеллект · `ja` 脳, 脳トレ, 記憶力, 集中力, 認知 · `ko` 두뇌, 뇌, 기억력, 집중력, 인지 · `zh-Hans` 大脑, 脑力, 记忆力, 专注力, 智力 · `ar` دماغ, ذاكرة, تركيز, ذهني

Exclamation marks are on the same list. A token clears only by a written exception in `DECISIONS.md`; the default is deletion.

### 1.14 What this game is not

- **Not a trivia game.** There is no knowledge to have. The entire universe — 256 glyphs, four attributes, four values each — is visible on screen at all times in the Assay. Nothing is recalled; everything is derived.
- **Not a reflex game.** Seven of the eight bands and three of the four modes have no clock. SIEVE is a deliberate quarantined change of texture, not the game's centre.
- **Not a memorisation game.** The novelty guard blocks the last 50 laws; with 27,015 laws and procedural sampling, a remembered answer is worth nothing.
- **Not social.** No accounts, no friends, no leaderboards, no sharing. The Anomaly is shared only in the sense that everyone gets the same law.

**The three real ancestors, stated accurately.**

| | **Zendo** (Kory Heath, 2001) | **Mastermind** (Meirowitz, 1970) | **Wason 2-4-6** (Wason, 1960) |
|---|---|---|---|
| What is hidden | A rule about koans, invented and phrased in natural language by a human Master | One specific code: 4 pegs from 6 colours, 1,296 possibilities | One rule generating number triples; in the classic run, "any ascending sequence" |
| Feedback per attempt | A white or black stone: the koan does or does not have the Buddha-nature | **Graded**: key pegs counting exact and misplaced matches | "Conforms" / "does not conform" |
| Who adjudicates | A human Master, who must also refute a wrong guess with a counterexample | Mechanical, exhaustive | The experimenter |
| The winning move | Spend a guessing stone and state the rule aloud | Name the code | State the rule when certain |
| Known result | — | Solvable in ≤ 5 guesses (Knuth, 1977); trivially brute-forced by software | Subjects overwhelmingly generate *confirming* instances and announce over-specific rules |

**What HUNCH takes.** From Zendo: the hidden-rule structure and the refute-a-wrong-guess-with-a-counterexample response — a direct, acknowledged inheritance. From Wason: that people probe positively by default, which is why the admit-rate window is skewed low (`p ∈ [0.15, 0.60]`, mode 0.30) so positive probing is *productive* rather than merely punished.

**What HUNCH changes.**
*Against Zendo* — the Master is a generator over a formal grammar, so every rule is guaranteed satisfiable, falsifiable, non-degenerate, band-consistent and constructible on the Bench; no human authors or adjudicates, no rule is unfairly phrased, and with no natural language anywhere the declaration is a machine-checkable extension comparison rather than an argument about wording. Zendo needs three to five people and a Master with taste; HUNCH needs a phone in a dark room.
*Against Mastermind* — the hidden object is a **predicate over the whole deck**, not an instance; feedback is one bit rather than a graded score, which removes the hill-climbing that makes Mastermind mechanically solvable; and Mastermind has no declaration step at all, because guessing the code *is* winning. Here, collecting admitting glyphs is worthless on its own — the round is won by *stating the law*, a different act with a different failure mode.
*Against Wason 2-4-6* — that is a psychology task, not a game: one rule, no scoring, no budget, no notation for the answer, success judged by a human reading a sentence. HUNCH gives it a grammar to answer in, an information budget (`par`), 27,015 rules across eight escalating conceptual families, a machine that never disputes an equivalent phrasing, and — critically — a **contextual** family with no counterpart in the original task, where a glyph has no verdict by itself at all. HUNCH is a game built on the structure of that task. It is not a measurement of anything, and it does not claim to change anyone who plays it.
## 2. The Glyph Vocabulary

A glyph is one reading of four independent attributes. Four attributes × four values = **256 glyphs**. That deck never grows.

Every attribute occupies a **spatially disjoint register** of the drawing. No two channels can overlap, so no two channels can ever be confused, and every channel can be read with the others removed.

| Attribute | Register | Values (rank 1 → 4) | Non-colour encoding | Rank is perceptible because |
|---|---|---|---|---|
| `fill` | interior of the body | `hollow, dotted, striped, solid` | interior texture | monotone ink density |
| `shape` | outer silhouette | `circle, triangle, square, hexagon` | the silhouette | corner count 0 → 3 → 4 → 6 |
| `pips` | nodes **on** the contour | `one, two, three, four` | count of contour nodes | cardinality |
| `hue` | index register below the body | `amber, teal, frost, rose` | **index stroke** rotating 0° → 45° → 90° → 135° | a 135° sweep, not a cycle |

> **Decision:** every attribute carries a visible total order, including hue. Reason: it makes the relational family symmetric (6 attribute pairs, not pips-only) and it costs one line segment we were already drawing for colourblind redundancy.

**Hue is drawn twice.** The Okabe–Ito subset is used verbatim — no re-lighting, no OKLab normalisation.

| Name | Okabe–Ito | Hex | Rel. luminance | Contrast on ground `#0B0A08` | Index stroke |
|---|---|---|---|---|---|
| `amber` | orange | `#E69F00` | 0.416 | 8.79 : 1 | 0° |
| `teal` | bluish green | `#009E73` | 0.257 | 5.78 : 1 | 45° |
| `frost` | sky blue | `#56B4E9` | 0.405 | 8.6 : 1 | 90° |
| `rose` | reddish purple | `#CC79A7` | 0.293 | 6.5 : 1 | 135° |

`teal` (0.257) and `rose` (0.293) are luminance-adjacent: in 8-bit greyscale they land on levels 139 and 147 — **8 levels apart out of 255**, a 1.12 : 1 ratio. That is far below reliable discrimination for two marks of different hue at different points on screen, so hue is not recoverable from luminance and the index stroke is not decoration, it **is** the hue channel; colour is the redundant copy.

> **Measured, not asserted.** Every ratio in this document is recomputed from the hex by WCAG 2.1 relative luminance, and the arithmetic is a shipped test (`check-tokens.swift`), because an earlier draft of this table carried four cells that had been stated rather than measured — `amber` as 9.5 : 1 and `teal` as 6.4 : 1 against their true 8.79 and 5.78, and this pair as "identical" against a real 8-level gap. No design consequence followed from any of them, which is exactly why nobody would have caught them by eye. High-contrast theme drops all four hues to the foreground stroke colour and doubles the index stroke from 12 pt to 18 pt — the game remains fully playable with hue rendered in one colour.

**Pips render as contour nodes, filled progressively N → E → S → W.** `one` = {N}; `two` = {N,E}; `three` = {N,E,S}; `four` = {N,E,S,W}. Node radius `0.11 × glyphRadius`, floored at 3 pt; below a 48 pt glyph the body stroke thins to 1.5 pt so nodes stay distinct.

> **Decision:** pips sit on the contour, not inside the body. Reason: it eliminates the pips-versus-fill collision outright (three interior discs inside a `dotted` fill is unreadable and needs knockout hacks), the four states have distinct silhouettes so count is pre-attentive rather than counted, and progressive accretion makes the ordinality visible instead of asserted.

**Canonical ordering — `fill → shape → pips → hue`**, everywhere and forever: VoiceOver label order, deck sort order, ramp row order on the Dial and the Bench, Codex page layout, AST commutative-operand sorting, serialisation.

```
glyphID = fill*64 + shape*16 + pips*4 + hue        // 0…255, stable forever
```

VoiceOver reads one localized format string with four interpolations, never concatenated fragments: *"hollow triangle, three pips, teal."* Accessibility labels are audio; the no-text rule constrains rendered pixels only.

**RTL:** layout mirrors, glyphs never do. The index stroke's 45° and 135° states are game state; mirroring them would swap `teal` and `rose` in Arabic. Ramps, the Assay and the ribbon are instrument scales and render leading-to-trailing in source order in every locale.

**Dynamic Type:** the play surface has no text, so type scaling drives *art* scaling. Glyph and tile geometry scale with the type multiplier up to 1.35×. At AX2 and above the Bench switches to a single-rail pager (one tile on screen, paged) rather than shrinking targets.

### Locked terminology

Seven authors write against this table. These are the only permitted names.

| Concept | Canonical name | Notes |
|---|---|---|
| the machine | **the Loom** | never "the game", "the engine" |
| where the live glyph sits | **the throat** | |
| visible probe log | **the ribbon** | tiles + link arcs, horizontally scrolling |
| one of the 256 | **glyph** | |
| all 256 | **the deck** | |
| feeding one glyph | **probe** (noun and verb) | never "guess", "try" |
| re-probing the identical glyph | **twin** | |
| the two verdicts | **admit** / **reject** | never "pass/fail", "yes/no" |
| the pre-primed glyph at position 0 | **the seed glyph** | |
| the hidden predicate | **the law** | |
| the shape-class a law belongs to | **family** | eight of them |
| difficulty tier 1–8 | **band** | one family per band |
| probe-construction control | **the Dial** | four ramps, single-select |
| four-cell attribute widget | **the ramp** | the atom of both UIs |
| declaration surface | **the Bench** | |
| one horizontal slot on the Bench | **rail** | |
| any term rendered on the Bench | **rule-tile** | generic |
| tile classes | **Ramp**, **Bridge**, **Fork**, **Tally** | |
| the AND/OR/XOR node between two tiles | **coupler** | |
| comparator control on a Bridge | **wedge** | |
| `prev` framing of a Bridge socket | **ghost** | |
| live 16×16 extension grid | **the Assay** | |
| the assembled law the player commits | **declaration** | |
| the commit control | **the Seal** | |
| a wrong declaration that does not end the round | **strike** | one per round |
| glyph (or pair) proving a declaration wrong | **counterexample** | |
| expected probe count | **par** | |
| hard probe limit | **cap** | |
| one law, start to verdict | **round** | |
| consecutive rounds in one sitting | **run** | |
| the archive | **the Codex**; one entry is a **page** | |
| mark on a page won after a strike | **fracture** | |
| the daily law | **the Anomaly** | |
| five-axis self-portrait | **the Profile** | axes: Induction, Retention, Flexibility, Restraint, Tempo |
| the four modes | **PROBE, DRIFT, ECHO, SIEVE** | uppercase in copy |
| a law's truth table | **extension** | `table` in code |

Enum-style value names, verbatim:

```swift
enum Shape:  circle, triangle, square, hexagon        // rank 1…4
enum Fill:   hollow, dotted, striped, solid           // rank 1…4
enum Pips:   one, two, three, four                    // rank 1…4
enum Hue:    amber, teal, frost, rose                 // rank 1…4
enum Attribute: fill, shape, pips, hue                // canonical order
enum Verdict: admit, reject
enum Coupler: and, or, xor
enum Comparator: eq, neq, lt, lte, gt, gte
enum Family: literal, pair, exclusive, relational, contextual, guarded, composite, systemic
enum Mode: probe, drift, echo, sieve
```

---

## 3. The Rule Grammar

### 3.1 The collapse

Every attribute has exactly four values. Therefore *every comparator against a constant collapses to a subset*: `pips >= 3` **is** `pips ∈ {three, four}`; `shape != circle` **is** `shape ∈ {triangle, square, hexagon}`. There are `2⁴ − 2 = 14` non-trivial subsets per attribute.

> **Decision:** there is exactly one atomic form — `attribute ∈ subset` — and therefore **no operator dimension at the atom level at all**. Reason: threshold and inequality operators add zero expressive power over a 4-valued domain, and each one added would be a second symbol the player must learn for the same truth function. Ordinal comparators survive only on cross-attribute bridges, where they cannot collapse.

This answers the ordinal-versus-nominal operator question outright: **at the atom level, no attribute takes operators, ordinal or nominal.** Comparators (`eq neq lt lte gt gte`) appear only in relational and contextual predicates, and there they apply to **all four attributes**, because all four carry a rank the ramp visibly teaches.

> **Decision:** there is no `NOT` node in the AST or the UI. Reason: the grammar is closed under complement at every production, so negation is always expressible as a different spelling of the same shape — and a negation operator is the single hardest thing to render unambiguously without text.

Proof of complement-closure, production by production: `¬(a ∈ S) = a ∈ S̄` (14 subsets closed under complement); `¬(RANK a ⋈ RANK b) = RANK a ⋈̄ RANK b` (the six comparators are closed under complement); contextual likewise; `¬(x AND y) = x̄ OR ȳ` and `¬(x OR y) = x̄ AND ȳ` (De Morgan, and both AND and OR live in the same family); `¬(x XOR y) = x̄ XOR y`; `¬(IF g THEN A ELSE B) = IF g THEN Ā ELSE B̄`; `¬COUNT(A,S,C) = COUNT(A,S,C̄)`; `¬PARITY(A,b) = PARITY(A, 1−b)`. Every case lands inside the grammar and inside the same family.

### 3.2 BNF

```bnf
<law>        ::= <term> | <term> <coupler> <term> | <guard> | <aggregate>

<coupler>    ::= "AND" | "OR" | "XOR"
<term>       ::= <atom> | <rel> | <ctx>

<atom>       ::= <attr> "IN" <subset4>
<rel>        ::= "RANK" <attr> <cmp> "RANK" <attr>                ; attrs distinct, canonical order
<ctx>        ::= "RANK" <attr> <cmp> "PREV" "RANK" <attr>         ; attrs may be equal

<guard>      ::= "IF" <attr> "IS" <value> "THEN" <attr> "IN" <subset4>
                                          "ELSE" <attr> "IN" <subset4>
                 ; gate attr ≠ branch attr; both branches on the same branch attr; branches differ

<aggregate>  ::= "COUNT" <attrSet> "RANKIN" <subset4> "IN" <countSet>
               | "PARITY" <attrSet> "IS" <bit>

<attr>       ::= "fill" | "shape" | "pips" | "hue"
<cmp>        ::= "==" | "!=" | "<" | "<=" | ">" | ">="
<subset4>    ::= bitmask 0001…1110                                ; 14 values; ∅ and full forbidden
<attrSet>    ::= subset of <attr> with |set| ≥ 3                  ; 5 values
<countSet>   ::= non-empty proper subset of {0…|attrSet|}
<value>      ::= one of the four values of <attr>
<bit>        ::= 0 | 1
```

### 3.3 Exhaustive predicate inventory

| Class | Form | Count | In admit window, bare |
|---|---|---|---|
| **Atomic** | `attr IN subset` | 4 × 14 = **56** | 40 |
| **Relational** | `RANK a ⋈ RANK b`, a ≠ b | 6 pairs × 6 cmp = **36** | 18 |
| **Contextual** | `RANK a(cur) ⋈ RANK b(prev)` | 4 × 4 × 6 = **96** | 48 |
| **Guard** | `IF a IS v THEN b IN S₁ ELSE b IN S₂` | 12 × 4 × 14 × 13 = **8,736** | — |
| **Aggregate** | `COUNT` / `PARITY` | 1,204 + 10 = **1,214** | 337 |

The final column counts **distinct extensions** in the admit window, not syntactic forms. Where two forms of a class share a table they are counted once — this matters only for the aggregates, where a `COUNT` form can coincide with a `PARITY` form or with another `COUNT` form. Two of these numbers are therefore reused verbatim as `|H|` in §5.2: the atomic **40** is band 1 and the aggregate **337** is band 8, because those two families are exactly their bare class. The relational 18 and contextual 48 are not, since bands 4, 5 and 7 admit composites over those terms.

Contextual is the only class where the two attribute slots may be equal — `RANK pips(cur) > RANK pips(prev)` is the entry-level contextual law and must exist. Relational forbids it because `RANK a ⋈ RANK a` is constant.

**Deliberately excluded, with reasons.** Cross-attribute rank *parity* pairs (`PAR a == PAR b`): parity of a single rank is invisible on a glyph; parity survives only in the aggregate family where it is the point. Arithmetic beyond comparison (`pips + shapeRank ≥ 6`): unrenderable without a numeral. n-ary XOR (n > 2): odd parity, which no one reads correctly and which the coupler would misrepresent as associative-and-obvious. Depth-2 statefulness: see §3.4.

### 3.4 Combinators, depth, and normal form

**`MAX_DEPTH = 2`. `MAX_LEAVES = 4`.** One coupler over two terms, or one guard over three atoms, or one aggregate.

> **Decision:** there is no grouping bracket, no nesting gesture, and no operator precedence — because there is nothing to nest. Reason: the only genuinely nested formulas worth having are piecewise ones, and the `<guard>` production expresses them *flat*. `IF hue IS amber THEN pips ∈ {3,4} ELSE pips ∈ {1}` is a depth-3 Boolean formula rendered as one tile with three docks. We get the expressive power of nesting without the pinch-to-group gesture, the bracket-stroke luminance ladder, or the precedence problem. This is the load-bearing simplification of the whole design.

Additional structural caps, enforced by the generator and by the Bench: at most one relational term, at most two contextual terms, at most two leaves per attribute, and no two leaves sharing an identical `(attr, cmp, operand)` triple.

**Normal form: RNF (Rendered Normal Form), for storage and display only — never for equivalence.**

1. Complement-fold: any negation introduced during editing is pushed into the operand (§3.1) and the `NOT` disappears.
2. Sort commutative operands by `(kindOrdinal, attrOrdinal, cmpOrdinal, subsetBitmask)`.
3. Relational operands ordered by canonical attribute order, comparator flipped to compensate. Contextual always renders **`cur` on the leading side and `prev` on the trailing side** — the orientation the BNF already fixes (`RANK a ⋈ PREV RANK b`). The converse reading is reached by flipping the comparator, never by moving `prev` to the leading side. This is why the Bridge's ghost toggle sits on the **trailing** socket (§4.2).
4. Merge same-attribute atoms under a coupler by set algebra (`AND`→∩, `OR`→∪, `XOR`→△). This is what unmasks a two-term law as a one-term law before it can be emitted.
5. Constant-fold any subtree whose extension is all-0 or all-1. The generator never emits these; the player can build them, and the Seal is barred when they exist.

RNF guarantees *one law, one tile layout, forever*. It is explicitly **not** the equivalence test.

### 3.5 Sequence semantics

> **Decision:** `previous` means the **previously probed glyph, regardless of verdict** — overruling the brief, which says "previously admitted."

Three reasons, in order of weight.

1. **Observability.** The previous probed glyph is always one slot back in the ribbon, on screen, next to the current one. Under *previously admitted*, after nine rejections the referent is nine slots back and the player must maintain an invisible filtered pointer. That converts a reasoning game into a bookkeeping game and adds difficulty with no conceptual payoff.
2. **Reproducibility of the evidence.** Under *previously probed* the Loom is a pure function of the visible probe sequence: the player can replay their own ribbon and re-derive every verdict. Under *previously admitted* the same probe yields different verdicts at different moments for reasons not visible in the record. Reproducible evidence is a precondition for induction, not a nicety.
3. **It draws.** The ribbon becomes a chain and the relation between adjacent tiles renders as a literal link arc. A skipping referent is unrenderable at 44 pt in a scroller.

**Cost, stated plainly:** every exploratory probe perturbs the context for the next one, so some probes are pure setup, and probe economy is scored. Mitigated by the **twin** (one tap re-probes the identical glyph, holding the context fixed) and by ribbon-load (§4.1). Not eliminated. This is a real skill and I am content for it to be one.

**The first probe.** The Loom is **always primed**: at round start a seed glyph is drawn deterministically from the round seed and shown in the throat. It is `prev` for probe 1. It is not a probe, carries no verdict, and is not scored.

> **Decision:** the seed glyph appears in **every band**, contextual or not. Reason: priming only in contextual bands would leak the family before the first probe.

**Statefulness beyond depth 1: none.** No "two glyphs ago", no counters, no run lengths, no aggregate history. Depth-2 predicates range over 16.7 M ordered triples; a human cannot separate a depth-2 law from noise inside any offerable budget, and the pair table would grow from 8 KiB to 2 MiB. Cost: we lose streak and alternation laws, which are genuinely appealing. DRIFT supplies the higher-order temporal texture instead, as a **round schedule outside the AST** — the law swaps to a different law of the same band after N admissions, `N ~ U[3,6]` from the seed. The AST, evaluator, canonicaliser and Bench are unchanged across all four modes.

### 3.6 Canonicalisation and equivalence

**The extension is the canonical form. Syntax is never compared.**

| | Representation | Build | Compare |
|---|---|---|---|
| stateless law | `Bitboard256` = 4 × `UInt64` (32 B) | 4 word-ops from precomputed masks, ≈ **20 ns** | 4 word compares, ≈ **5 ns** |
| contextual law | `Bitboard65536` = 1024 × `UInt64` (8 KiB), index `prev*256 + cur` | 1024-word scatter + ≤ 3 word-array ops, ≈ **2 µs** | `memcmp` 8 KiB, ≈ **0.4 µs** |

**Never walk the AST per glyph.** Precompute once at launch and keep resident:

| Table | Entries | Size |
|---|---|---|
| atom masks `attr IN subset` | 56 × 256 bit | 1.8 KB |
| relational masks | 36 × 256 bit | 1.2 KB |
| contextual **row** masks — `ctx(a,b,cmp)` row for `prev` depends only on `prev`'s value of `b`, so store 4 rows per form | 96 × 4 × 256 bit | 12 KB |
| aggregate masks — all 1,214 forms, not only the 337 in-window ones, because the player may build any of them on the Tally | 1,214 × 256 bit | 39 KB |
| **total resident** | | **≈ 54 KB** |

A contextual pair table is materialised on demand by tiling its four row masks — 1024 word writes, ≈ 2 µs. Never stored in the Codex; a Codex page stores the AST and rebuilds.

**Cross-class comparison — lifting.** A stateless table `T` lifts to pair space by tiling: `lift(T) = TILE * T`, where `TILE` has bit `i*256` set for all `i` (no carries, since `T < 2^256`). Comparison always happens at the larger of the two arities. This is how a player's stateless declaration is judged against a contextual hidden law, and how "is this contextual law secretly stateless?" is answered (`P == lift(P & FULL256)`).

**Two laws are the same law iff their extensions are bit-identical in the common space.** `RANK pips == RANK shape` and `RANK shape == RANK pips` are the same law. `shape ∈ {triangle,square,hexagon}` and the complement spelling of `shape ∈ {circle}` are the same law.

**Dead-term detection falls out of the same machinery.** For each leaf `t`: substitute ⊤, rebuild; substitute ⊥, rebuild. If either rebuild equals the original extension, `t` is dead and the law is rejected. Both substitutions are required: `AND(shape∈{circle}, shape∈{circle,triangle})` is caught by removal, and `XOR(a,b)` has no meaningful removal so it needs the pivotal test. Cost for a 4-leaf contextual law: 8 rebuilds ≈ 16 µs, at generation only, never in a hot loop.

**Attribute liveness.** Attribute `a` is live iff `T != permute_a(T)` for at least one of the three non-identity value permutations of `a` — three table permutes, microseconds.

**Dedup key.** 64-bit hash of the word array; full compare only on collision. At 300 stored Codex pages the birthday probability is ≈ 2⁻⁴⁵.

**The lower-band index.** The stateless law space of bands 1, 2, 3, 4, 6, 8 is enumerated once at first launch — **9,767 tables, 305 KB** — and cached to Application Support as `lowerBandIndex.bin`. It is **band-partitioned**: six sorted runs of **40 / 1,272 / 108 / 2,322 / 5,688 / 337**, concatenated behind a six-entry header of per-band offsets, so any prefix union is a contiguous range.

A candidate at band `b` is rejected as *secretly easier* iff its table (lifted where needed) appears in `⋃{index[b′] : b′ < b}` — the bands **strictly below** its own, **never its own band**. The distinction is not pedantic: the index is by construction the complete enumeration of exactly those six bands, so comparing a band against itself would reject 100 % of candidates at five of the eight bands and drive the fallback rate (§5.3) to 1.00.

Contextual bands 5 and 7 are stored separately and are likewise band-partitioned: 17,248 pair tables (138 MB if materialised), indexed by 64-bit hash only — **138 KB**, as two runs of **6,934 / 10,314** — with collisions resolved by rebuild-and-compare. They contribute nothing to any *stateless* candidate's exclusion set, because G7 guarantees no band-5 or band-7 table is the lift of a stateless one. In the other direction that same guarantee makes G4 **vacuous at band 5** (all four bands below it are stateless), and at band 7 it reduces to the single test "not already a band-5 table," run against the band-5 hash run.

This is what makes the bands disjoint in meaning rather than merely in syntax. The enumeration is a shipped test that asserts the exact **per-band** counts against the band table of §5 — six assertions plus two, not one assertion on a 9,767-table blob.

**Total law space: 27,015 distinct laws.**

---

## 4. Declaring a Law

### 4.1 The ramp, and why probing teaches declaring

The atom of both interfaces is **the ramp**: an attribute header followed by that attribute's four values, drawn exactly as they appear inside a glyph — four silhouettes, four fill swatches, four contour-node counts, four index strokes. There is no attribute emblem to learn. *The ramp is a picture of its own attribute.*

The ramp has two modes, and that is the whole interface:

- **Single-select** — used on the **Dial**, where the player composes the glyph to probe.
- **Multi-select** — used on the **Bench**, where the player states which values the law admits.

> **Decision:** the probe control and the atomic rule-tile are the *same widget*. Reason: the player learns the multi-select rule-tile by accident on probe 1 of round 1, having read nothing. This is the brief's "onboarding by doing" delivered for free, and it removes the largest single legibility risk in a text-free declaration UI.

**Probe construction: free construction via the Dial.** Not a dealt hand, not a 256-glyph grid.

- A **dealt hand** destroys the epistemics. Controlled variation — change exactly one attribute, hold three fixed — is *the* inductive move and the only way to establish pivotality. A hand cannot guarantee the neighbour you need.
- A **256-glyph grid** is a mirage. Choosing from 256 is 8 bits either way, but the Dial *factors* those 8 bits into four independent 2-bit choices that map exactly onto the hypothesis structure. Hick's law applies to the flat set, not the factored one. And 256 targets at 44 pt needs ~5,000 pt of scrolling on the reference device; finding a glyph becomes a scavenger hunt, which is visual search, not reasoning.

**Reference device: iPhone SE (2nd/3rd gen), 375 × 667 pt, safe area ≈ 375 × 647.** The 1st-gen SE (320 × 568) cannot run iOS 18 and is not a target.

| Region | y | Detail |
|---|---|---|
| instrument bar | 20–64 | probe tally as tick marks, mode sigil. No text, no numerals. |
| the Loom — throat | 64–176 | 96 pt live glyph, centred |
| the ribbon | 176–228 | 44 pt tiles, horizontal scroll, link arcs between adjacent tiles |
| Dial: 4 ramps | 236–508 | 4 rows × 60 pt, 8 pt gutters. Header 44 pt + 4 cells of 70 × 48 pt + 6 pt gutters = 342 pt in 375. |
| the Bench handle | 516–560 | pull-up to declare |
| commit bar | 604–667 | **PROBE** (leading) · **twin** (centre) · **Bench** (trailing), 44 pt each |

Every target is ≥ 70 × 48 pt. Right-thumb comfort arc from a bottom-trailing pivot covers y > 240 — the Dial and both keys sit inside it; the Loom is view-only and lives in the unreachable top third by design.

**Three mitigations reduce the modal probe to one or two taps**, which is the honest answer to choice paralysis:

1. **The Dial retains the last probe.** The default action is a minimal edit, not a fresh construction. The single most valuable experiment costs exactly one tap.
2. **Ribbon-load.** Tap any ribbon tile to load it into the Dial. "Go back and vary that one" is two taps.
3. **The twin key.** One tap re-probes the identical glyph. Under previous-probed semantics this is the experiment that *detects statefulness at all* — same glyph, different verdict — and it is how a player buys the contextual family for two probes.

A horizontal swipe on the throat glyph steps the last-touched attribute by ±1, so controlled variation is one flick without reaching the Dial.

> **Decision:** no repeat guard. Re-probing an already-probed glyph is not blocked or refunded. Reason: under previous-probed semantics the twin is the most informative probe in the game; a guard against it would be a bug. Repeats are marked in the ribbon with a doubled ring so the transcript shows the twin pair as a unit.

### 4.2 The Bench

Four tile classes, distinguished at silhouette level, and one coupler. No text anywhere.

```
 20– 64  instrument bar
 64–176  the Loom throat (the seed / last glyph stays visible)
176–228  the ribbon
228–560  THE BENCH   rails, 291 pt wide  |  THE ASSAY, 64 pt trailing column
560–604  the palette — 4 tile stamps, 68 × 44 pt
604–667  commit bar:  Dial (leading)  ·  THE SEAL (trailing)
```

**1. RAMP (atom).** Attribute header 44 pt + four 56 × 44 pt cells. Tap a cell to admit it. Lit = admitted; unlit drops to 25 % opacity **and** gains a diagonal cancel hatch, so the state is readable with no colour and no brightness discrimination. 14 usable states per ramp; 0 lit and 4 lit are inert.

**2. BRIDGE (relational and contextual).** Two attribute sockets with a **wedge** between them. Tap an empty socket → the four attribute headers appear inside it → tap one. Tap the wedge to cycle the comparator, drawn pictorially and never as ASCII: `eq` two parallel bars; `neq` two bars with a slash; `lt`/`gt` a wedge whose wide end physically opens toward the larger side; `lte`/`gte` the same wedge with an underbar. The **trailing** socket carries a **ghost toggle**: tapping it re-frames that socket as the *previous* glyph, drawn with the dashed hollow frame and backward chevron already used to mark `prev` in the ribbon ten probes earlier. That one toggle is the entire contextual grammar, and its symbol was introduced diegetically.

The leading socket is always `cur` and carries no toggle. That is RNF rule 3 made physical (§3.4), and it costs nothing: every one of the 96 contextual forms is `RANK a(cur) ⋈ PREV RANK b`, so `cur`-leading is not a restriction, it is the grammar's own orientation — all 96 are reachable as *leading attribute × trailing attribute × wedge* = 4 × 4 × 6. A player who wants the converse reading flips the wedge. Putting the toggle on the leading socket instead would make the only expressible contextual family the transposed one, and the tile would render a law RNF forbids.

**3. FORK (guard).** A railway switch: one incoming line splits into an upper **lit** track and a lower **dim** track. The **gate dock** at the top holds a ramp restricted to one lit cell. The lit dock and the dim dock each hold a full ramp, both on the same attribute. Lit = "then", dim = "else", and the mapping is taught by the tile's own drawing — the gate cell that is lit routes to the lit track.

**4. TALLY (aggregate).** The four attribute headers in a column, each toggleable in or out of the counted set (minimum three), sharing one 4-stop **rank ramp**; below it a **counter dial**, a 5-stop track with the same tap-a-cell verb, meaning "the number of counted attributes whose rank is in the ramp lies in this set." A two-tooth comb toggle switches the tile to **parity mode**, where the dial collapses to two cells: even / odd.

**COUPLER.** The junction between the two rails is a circular node. Tap to cycle: **AND** = a solid welded bar; **OR** = a forked bar, two strands that split and rejoin; **XOR** = a forked bar whose two strands cross and terminate — you may take one path but not both. Diagrams, not symbols, and all three are commutative, matching the semantics. A Fork or a Tally occupies the whole Bench and has no coupler.

**Gesture inventory — exhaustive.**

| Gesture | Effect |
|---|---|
| tap a palette stamp | add that tile class to the next empty rail |
| tap a cell / dock / dial stop | toggle it in or out |
| tap a coupler | cycle AND → OR → XOR |
| tap a wedge | cycle comparator |
| tap the ghost toggle | switch the **trailing** socket between `cur` and `prev` |
| tap an empty socket, then an attribute header | bind an attribute |
| swipe a rail toward the trailing edge | clear that rail |
| tap the Seal | declare |

> **Decision:** there is no drag, no pinch, no long-press and no double-tap anywhere in the declaration UI. Every action is a tap or a trailing swipe. Reason: drag and pinch are precisely the gestures VoiceOver cannot perform and that no textless affordance can teach. Every control is a standard accessibility element with a state; the whole Bench is navigable with rotor and single-finger double-tap.

### 4.3 How a half-built law reads: the Assay

Beside the Bench sits a **16 × 16 micro-grid of the entire deck** at 4 pt cells (64 × 64 pt), laid out in canonical `glyphID` order so its geometry becomes memorable. Cells the **current draft** admits are lit. As the player builds, the constellation morphs live. This gives, with no text:

- the draft's admit rate, as density;
- unsatisfiability (all dark) and tautology (all lit), instantly and unmistakably;
- in contextual drafts, the extension **conditioned on the pinned `prev`** — scrubbing the ghost thumbnail morphs the constellation, which is the clearest possible non-verbal statement of what "contextual" means.

**The pin defaults to the seed glyph** and is scrubbable to any of the 256. The live Assay is therefore always a *slice* of the pair table, never a projection of it: for a draft admitting `p` of the 65,536 pairs, the lit count is the row count for the pinned `prev`, which in general differs from `p × 256`. The unconditional marginal projection is a different picture with a different job — it is what a Codex page thumbnail renders — and the two must not be quoted for each other.

Tap the Assay to expand it to a full-screen read-only inspector at 23 pt cells.

> **Decision:** the Assay's *evidence overlay* — ringing probed glyphs and flashing any cell the draft gets wrong against the ribbon — unlocks at band 4, not band 1. Reason: a free consistency check trivialises the low bands, where the reasoning is the game; from band 4 up nobody can hold a 65,536-entry pair table in their head and the tool is load-bearing.

An empty rail draws as a dashed outline with a pulsing hairline. A ramp with 0 or 4 cells lit draws at 30 % with a hairline slash — **one inert state, not two**, because nobody should have to learn the difference between "empty" and "vacuous". **The Seal is physically barred** by a machined bar across it while any rail is inert, any socket unbound, or the draft's extension is constant. Pressing a barred Seal pulses the offending rail and nothing else. No error text, no error state, no modal: the machine simply is not ready.

### 4.4 Expressiveness parity

| Grammar production | Constructible as | Reachable |
|---|---|---|
| `attr IN subset` — 56 | one RAMP, any of 14 cell states × 4 attributes | exhaustive |
| `RANK a ⋈ RANK b` — 36 | one BRIDGE, both sockets `cur` | exhaustive |
| `RANK a(cur) ⋈ RANK b(prev)` — 96 | one BRIDGE, **trailing** socket ghosted (leading is always `cur`, RNF rule 3) | exhaustive — 4 leading × 4 trailing × 6 wedge |
| `AND` / `OR` / `XOR` | the coupler, 3 states | exhaustive |
| `<guard>` — 8,736 | FORK: gate dock + lit dock + dim dock | exhaustive |
| `<aggregate>` — 1,214 | TALLY, count mode and parity mode | exhaustive |
| complement of anything | a different cell / comparator / count-set selection | exhaustive (§3.1) |
| depth ≤ 2, leaves ≤ 4 | two rails, one coupler; or one Fork; or one Tally | exact ceiling |

**Nothing much beyond it.** The Bench's structural ceiling *is* `MAX_DEPTH = 2`, `MAX_LEAVES = 4`; the Fork's docks accept ramps only, so there is no fork-inside-fork; the Tally is a whole-Bench tile. The one genuine over-reach is that the player can build a draft whose extension is constant, and the Seal is barred for exactly those. **The Bench and the grammar are the same language.**

Two tests enforce it. Forward: for all 10,000 generated laws per band, `Bench.layout(for: law)` returns non-nil and `parse(layout)` is **node-identical to `RNF(law)`** — an AST round-trip, not an extension match (see G10, §5.3). Backward: a fuzzer over 200,000 random Bench configurations asserts every one parses to a grammar-valid AST or is barred at the Seal.

> **Decision:** the palette unlocks tile classes at the player's **lifetime maximum band + 1**, never at the current round's band. Reason: a veteran always sees the full palette regardless of what they are being served and cannot read the family off the toolbox; a beginner literally cannot express a band-5 law, which is fine, because they will never be served one.

### 4.5 Verdict on declaration

**Correct iff `extension(declared) == extension(hidden)`**, compared in the common space with lifting. Purely semantic. Tile arrangement, spelling, coupler choice and complement direction are all irrelevant. A player who lights `{triangle, square, hexagon}` matches a hidden law whose canonical spelling excludes `circle`; a player who lights the pips ramp `{three, four}` matches a hidden "pips ≥ 3". Rejecting an equivalent phrasing would punish the player for the grammar rather than for the induction.

All 65,536 ordered pairs are reachable — any glyph may follow any glyph — so there is no "correct on reachable states but judged wrong" failure mode.

**When wrong, the Loom reveals exactly one counterexample — and never the law.** Selection is fully deterministic:

1. Restrict to glyphs (or, in contextual bands, ordered pairs) where `declared` and `hidden` disagree.
2. **Prefer false negatives** — cases the hidden law admits and the declaration rejects.
3. Minimise attribute-space Hamming distance to the nearest glyph already in the ribbon.
4. Tie-break by lowest `glyphID`.

Rendering, textless: the ribbon stays on screen, the counterexample animates to centre and takes **two rings at once** — the declaration's ring says one verdict, the Loom's outer ring says the other. Two rings, one glyph, opposite states, and the distinct law-broken haptic. In contextual bands it is two glyphs joined by the link arc.

Why a counterexample and not the law: revealing the law converts failure into a lookup and trains waiting instead of reasoning, which is the single largest risk to the core loop. Revealing nothing is uninformative and makes the machine feel arbitrary rather than legible-in-principle. One counterexample is the *minimum honest response*: it is evidence, the same currency the whole game trades in, it proves the declaration false, and it does not identify the law. Preferring a false negative targets the most common human error — the over-narrow hypothesis. Minimising Hamming distance to the ribbon makes it land as "oh, *that* one" rather than as a random glyph.

> **Decision:** two strikes, not one — overruling the brief. On the **first** incorrect declaration the counterexample is revealed and the round continues; the probe count keeps running and the player may declare again. On the **second**, the round ends, the true law animates in full rule-tiles, and nothing is inscribed. Reason: a counterexample is pedagogically worthless if you cannot act on it, and the 80 % success target is far easier to hold with a two-strike structure than by softening the laws themselves.

Anti-farming: a garbage declaration disagrees nearly everywhere, so the minimum-Hamming rule returns a glyph the player has effectively already probed. A strike also costs 40 % of score, marks the Codex page with a **fracture**, and forfeits the Anomaly streak. Buying information with a strike is priced above the cost of simply probing.

**Reaching the cap** (§5) ends the round as a loss and **does** reveal the law in rule-tiles. Reason: the reveal is priced at more probes than solving costs, so it is never an exploit, and withholding it after `1.6 × par` probes is punitive rather than instructive.

---

## 5. Difficulty and the Law Generator

### 5.1 Difficulty is structural

> **Decision:** difficulty is determined by the law's **family**, with bounded within-family modifiers — not inferred from term counts on a flat grammar. Reason: a flat grammar's hour 20 is hour 1 with more clauses. Eight families, each demanding a conceptual move the previous one did not, is what makes hour 20 ask a different question.

```swift
func difficulty(of law: Law) -> Double {          // → [0.000, 1.000)
    let base = Double(law.family.index) * 0.125                                  // 0.000 … 0.875
    let m1 = 0.030 * Double(min(2, law.leafCount - law.family.minLeaves)) / 2     // ≤ 0.030
    let m2 = 0.040 * law.marginalDeficit                                         // ≤ 0.040
    let m3 = 0.020 * Double(law.freeAttributeCount) / 3                          // ≤ 0.020
    let m4 = 0.020 * abs(law.admitRate - 0.30) / 0.30                            // ≤ 0.020
    let m5 = 0.014 * Double(min(2, law.scatteredSubsetCount)) / 2                 // ≤ 0.014
    return base + m1 + m2 + m3 + m4 + m5                                         // ≤ base + 0.124
}
```

| Term | Definition | Max | Why |
|---|---|---|---|
| `base` | family index × 0.125 | 0.875 | the conceptual move dominates everything |
| `m1` leaves | leaves above the family minimum | 0.030 | more terms inside the same idea |
| `m2` **marginal deficit** | `1 − min(1, maxᵩ\|P(admit\|φ) − p\| / 0.35)` over the 16 (attribute, value) conditions φ | 0.040 | **the key modifier.** It asks: does *any single value* predict the verdict? That is exactly the power of the strategy every real player uses — vary one attribute, watch the lamp. An atom scores 0; a flat XOR, a relational law and a parity law all score 1. |
| `m3` free attributes | attributes named by no term | 0.020 | unreferenced attributes must be ruled out |
| `m4` rate skew | distance of `p` from the 0.30 mode | 0.020 | evidence starvation in either direction |
| `m5` scatter | leaves whose subset is not a contiguous run of ranks (5 of the 14 subsets are scattered) | 0.014 | `pips ∈ {1,3}` is far harder to conjecture than `pips ∈ {1,2}` |

The five modifier maxima sum to **exactly 0.124**, one tick short of the band width. A law can never escape its band, and *the family determines the band while the modifiers determine the position within it.* Because the modifier span (0.124 → 0.99 logits) equals the band step, the adaptive engine's serving range is effectively continuous: it picks a target difficulty and the generator rejection-samples within the family until `|difficulty − target| ≤ 0.02`.

**Rasch coupling:** `δ_logit = 8 · difficulty − 4`, working range ≈ [−4.0, +3.99]. To hold 80 % success, serve `δ_logit = θ − 1.386`. Never surfaced numerically.

### 5.2 The band table

`|H|(b)` is the count of **distinct extensions** in band `b`'s family that survive G1–G3, G5–G7, G10 and the band-membership clause of G8, plus G4's exclusion by the **strictly lower** bands only — **enumerated exhaustively over the real 256-glyph deck**, not estimated.

It deliberately does *not* close over three of the ten guardrails. G4-against-its-own-band would be circular, since G4's index is built *from* these counts (§3.6); enumeration therefore runs in ascending band order, so band `b`'s exclusion set is complete and frozen before band `b` is counted. G8's `targetδ` proximity clause is per-request, not a property of the law. G9 is per-player and per-day. With those three excluded the definition is well-founded and the shipped assertion is a fixed number rather than a moving one. Verified constants, asserted by test, **per band**.

| # | Family | δ range | The conceptual move it demands | \|H\| | log₂\|H\| | Example law | p | δ |
|---|---|---|---|---|---|---|---|---|
| 1 | **LITERAL** | .000–.124 | "one thing matters" | 40 | 5.32 | `fill ∈ {striped}` | .250 | **.023** |
| 2 | **PAIR** | .125–.249 | "two things matter at once" | 1,272 | 10.31 | `shape ∈ {triangle,hexagon} AND pips ∈ {three,four}` | .250 | **.160** |
| 3 | **EXCLUSIVE** | .250–.374 | "truth is not monotone in any attribute" | 108 | 6.75 | `shape ∈ {circle,triangle} XOR fill ∈ {hollow,dotted}` | .500 | **.317** |
| 4 | **RELATIONAL** | .375–.499 | "the law names no value" | 2,322 | 11.18 | `RANK shape == RANK pips` | .250 | **.432** |
| 5 | **CONTEXTUAL** | .500–.624 | "a glyph has no verdict by itself" | 6,934 | 12.76 | `RANK pips(cur) > PREV RANK pips` | .375 | **.525** |
| 6 | **GUARDED** | .625–.749 | "the law is piecewise; your theory has a region" | 5,688 | 12.47 | `IF hue IS amber THEN pips ∈ {three,four} ELSE pips ∈ {one}` | .313 | **.639** |
| 7 | **COMPOSITE** | .750–.874 | "hold two of the above at once" | 10,314 | 13.33 | `RANK hue(cur) == PREV RANK hue XOR RANK shape < RANK pips` | .438 | **.785** |
| 8 | **SYSTEMIC** | .875–.999 | "no attribute is privileged" | 337 | 8.40 | `PARITY {fill,shape,pips,hue} IS even` | .500 | **.928** |

Three of these jumps are *enforced*, not asserted:

- **Band 3** is exactly the XOR of two 2-element subsets on distinct attributes. That is not a guardrail, it is a theorem: an XOR's marginals are `{p_T, 1 − p_T}`, so all sixteen (attribute, value) marginals equal `p` **iff** both subsets have size 2. Exactly 108 laws, tolerance-free. A player still varying one attribute at a time sees 50 % admits on every attribute and concludes the machine is random.
- **Band 4** is enforceable the same way: for every value of every attribute, admitted and rejected glyphs both exist. `RANK shape == RANK pips` has marginal deficit 1.0 — no value predicts anything.
- **Band 8** is enforced by **symmetry, not flatness** — and this is a theorem too. Every aggregate names an *attribute set*, never an attribute: its extension is invariant under any permutation of the counted attributes, so all counted attributes have *identical* marginals and the question "which attribute matters?" answers "all of them, equally, and none of them alone." That is the answer the human prior does not carry, and it is why band 8 costs `d = 8`.

  Flat marginals are a property of the **parity sub-family only** (deficit 1.0). A COUNT law is a legitimate band-8 law with a marginal that is not flat: `COUNT {fill,shape,pips} RANKIN {three,four} IN {2,3}` — "at least two of three ranks ≥ 3" — has `p = 0.500`, `P(admit | fill ∈ {three,four}) = 0.750` against `0.250` for the complement, marginal deficit **0.286**, δ = **0.906**. It is one of the 337. Marginal deficit therefore *positions* a law inside band 8 through `m2`; it does not gate entry to it. Requiring flatness would collapse `|H|(8)` to roughly the ten parity forms and take `log₂|H|`, par, cap, the index and the total down with it, in exchange for a band with almost no content. Not done.

### 5.3 The generator

```
generate(seed: UInt64, band: Int, targetδ: Double, mode: Mode,
         avoid: Set<UInt64> = []) -> Law        // pure over these five arguments, and nothing else
```

> **Decision:** the generator is a **pure function of its explicit arguments**. Player history never reaches inside it. Novelty is expressed as `avoid`, a set of 64-bit extension hashes assembled by the **serving layer** and passed down. Reason: the brief makes determinism a hard requirement — "the same `(seed, mode, difficulty)` must produce a byte-identical puzzle across runs and across processes" — and that is not merely untested but *unstateable* for a function that reads mutable state. The determinism test asserts `generate(s, b, δ, m, avoid: [])` is byte-identical across runs and across processes. Seed choice, `avoid` assembly (the player's last 50 solved extensions, their found set for that band, today's Anomaly) and retry-with-a-fresh-seed all live in the serving layer, are tested separately, and are explicitly *not* stable across sessions — which is the point of them.

1. `rng = SplitMix64(seed ^ (UInt64(band) << 32) ^ mode.salt)`.
2. `family = Family(band)` — **strictly one family per band, no reprises.** A band-2 law served at band 5 would be scored at band 2 and would poison the Rasch estimate.
3. Sample a skeleton from the family's skeleton list, weighted by inverse cardinality so rare skeletons surface.
4. Fill leaves: attributes drawn without replacement within a leaf; subsets and comparators uniform, subject to family constraints. `hue` is down-weighted 0.5 in relational and contextual slots and is never the sole ordinal operand below band 5 — its rank is the weakest of the four.
5. Canonicalise to RNF.
6. Run guardrails cheap → expensive; on failure resample, bounded at **200 attempts**, then fall back to the family's deterministic anchor law. Generation must never block or fail. The anchor satisfies G1–G7, G8's band-membership clause and G10 by construction; it is exempt from G8's `targetδ` proximity clause and from G9, because a last resort that can itself be vetoed is not a last resort. The fallback rate is itself a monitored test statistic and must stay under 2 % per band.

| # | Guardrail | Test |
|---|---|---|
| G1 | satisfiable | `popcount(T) ≥ 1` |
| G2 | falsifiable | `popcount(T) ≤ N − 1` |
| G3 | admit-rate window | `p = popcount(T)/N ∈ [0.15, 0.60]` |
| G4 | not secretly easier | `T ∉ ⋃{index[b′] : b′ < band}` (lifted where needed) — **strictly lower bands, never its own**. Vacuous at band 5, and at band 7 reduces to the band-5 hash run (§3.6) |
| G5 | no dead terms | leaf-by-leaf ⊤/⊥ substitution (§3.6) — **both** substitutions, always |
| G6 | attribute liveness | every named attribute is pivotal |
| G7 | genuinely contextual | bands 5, 7: `P != lift(P & FULL256)` |
| G8 | band fidelity | `difficulty(canonical form) ∈ [lo, hi)` and within 0.02 of `targetδ` |
| G9 | novelty | `hash(T) ∉ avoid` — the caller-supplied set, nothing else. The serving layer fills it with the player's last **50** solved extensions, their found set for this band, and today's Anomaly |
| G10 | constructible | `parse(Bench.layout(for: L))` is **node-identical to `RNF(L)`** — an AST round-trip, not an extension match. **Any law the generator emits is provably buildable, or it is never emitted.** |

**G10 compares ASTs, not extensions,** because the extension test has a blind spot exactly where the Bridge is most fragile. A rendering convention that transposes `cur` and `prev` produces the converse law — a different extension for the 64 asymmetric contextual forms, but *the same* extension for the 8 symmetric ones (`==`, `!=` with both sockets on one attribute). An extension round-trip would pass those eight, and the bug would ship as "sometimes the tile lies." RNF gives one law exactly one layout (§3.4), so demanding node identity costs nothing and closes the hole at generation time.

**The admit-rate window is `[0.15, 0.60]`, and it is deliberately asymmetric.**

- **Floor 0.15.** At `p = 0.05` a uniformly probing player sees one admit in twenty. The positive class carries nearly all the discriminating information — it is what pins down *which* subset — and it becomes unreachable by exploration; the round degenerates into random search. At 0.15 the first admit arrives within ~7 probes of blind probing, comfortably inside the smallest par.
- **Ceiling 0.60, not 0.85.** This is the most opinionated number in the document. Wason's result is that humans probe *positively* by default: they generate instances they expect to be admitted. A law admitting 25 % of the deck **rewards** that instinct — each admit sharply narrows the space. A law admitting 80 % **punishes** it: the natural strategy returns "yes" almost every time, the player learns nothing, and the machine reads as broken. Skewing low aligns the game with the strategy people actually bring. Target mode `p ≈ 0.30`.
- Contextual laws use the same window computed over all 65,536 ordered pairs.

> **Decision:** the window is asymmetric even though the grammar is closed under complement. Reason: this costs the *generator* the "everything except this narrow exclusion" class — roughly 30 % of otherwise-valid tables — but it costs the *player* nothing, because the Bench remains complement-closed. A player who thinks "it's everything except triangles" can always say so. Unlearnable laws are worse than absent laws.

### 5.4 Information budget

Each probe returns exactly one bit, so an ideal reasoner needs at least `log₂|H|` probes. A real reasoner falls short of that bound by a **friction coefficient** `k` — hypothesis spaces are not perfectly splittable and human priors are wrong — and pays a fixed **discovery cost** `d`: probes spent working out *what kind* of law this is before the search proper begins.

```
par(band)  = ceil( k · log₂|H| + d )
cap(band)  = ceil( 1.6 × par )
```

| Band | log₂\|H\| | k | why k | d | why d | **par** | **cap** |
|---|---|---|---|---|---|---|---|
| 1 LITERAL | 5.32 | 1.15 | near-perfectly splittable | 0 | — | **7** | 12 |
| 2 PAIR | 10.31 | 1.15 | AND/OR/XOR ambiguity resists splitting | 1 | one attribute or two? | **13** | 21 |
| 3 EXCLUSIVE | 6.75 | 1.80 | flat posterior; single-attribute probes are worth **zero** bits | 3 | discovering non-monotonicity | **16** | 26 |
| 4 RELATIONAL | 11.18 | 1.40 | relational tables overlap heavily; many agree on 80 % of the deck | 4 | abandoning "which value?" | **20** | 32 |
| 5 CONTEXTUAL | 12.76 | 1.35 | large but well-structured once the family is known | 5 | twin-probes to detect statefulness at all | **23** | 37 |
| 6 GUARDED | 12.47 | 1.40 | probes inside one region say nothing about the other | 5 | noticing a region boundary exists | **23** | 37 |
| 7 COMPOSITE | 13.33 | 1.55 | two conceptual layers interfere | 5 | identifying both layers | **26** | 42 |
| 8 SYSTEMIC | 8.40 | 2.40 | **entropy is not difficulty** — see below | 8 | ruling out bands 1–7 first | **29** | 47 |

**Band 8 is the argument for the whole ladder.** Its hypothesis space is *smaller than band 2's* — 337 laws, 8.40 bits against band 2's 1,272 and 10.31. An ideal Bayesian with the correct prior solves it in nine probes. A human needs about 29, because the human prior does not contain attribute-symmetric hypotheses at all; almost the entire budget goes on falsifying band 1–7 theories before the right *shape* of idea is considered. **A difficulty function based on entropy, term count, or hypothesis-space size would rank band 8 easier than band 2.** This one ranks it hardest, because it reads the family.

`k` and `d` are design-time priors. The simulated-player harness runs a greedy max-entropy reasoner over each band's materialised hypothesis set (sampled at 20,000 for bands 5 and 7, corrected by `log₂(|H| / 20000)`) and must reproduce this table within ±20 %, or the par column is regenerated empirically.

**Par is soft; the cap is hard.** Par renders as a row of unlit tick marks that fill as you probe; past par a second, dimmer row begins emptying. No numerals, no countdown. Reaching the cap ends the round as a loss with the law revealed (§4.5) — the adaptive engine needs a failure signal that is not solely "declared wrong", or a grinding player makes the Rasch model unidentifiable.

**Scoring:** `score = round(1000 · min(1, par / probesUsed))`, × 0.6 if a strike was taken. Seal marks: 3 at `≤ 0.6 · par`, 2 at `≤ par`, 1 at `≤ cap`. A correct declaration is always inscribed in the Codex regardless of mark. Profile axes read off directly: **Tempo** = probes/par, **Restraint** = strike rate, **Induction** = highest band cleared, **Flexibility** = DRIFT re-declaration latency, **Retention** = ECHO accuracy.

**Mid-round state is persisted after every probe.** At par 23–29 a top-band round is a six-to-twelve minute commitment, which is longer than a mobile session. Suspend-and-resume is load-bearing, not a nicety.

A suspended round stores the **resolved law itself** — the RNF `LawNode`, ~40 B — never `(seed, band, targetδ, mode)` to be re-generated on resume. Reason: `avoid` is serving-layer state and it moves while the round is suspended. Suspend a PROBE round, play a SIEVE round that inscribes a page, resume: re-generation from the same seed can now legitimately resolve to a *different* law, and the round is destroyed by its own consistency check. Store the law; keep `lawHash` alongside it as a corruption check only, never as the source of truth.

### 5.5 A worked round — band 5, CONTEXTUAL

Hidden law: `RANK pips(cur) > PREV RANK pips  AND  shape ∈ {triangle, hexagon}`. `p = 0.188`, marginal deficit 0.464, δ = **0.562**, par 23, cap 37. Seed glyph primed in the throat: **hollow triangle, two pips, teal**. Every verdict below is machine-verified.

| # | Probe | `prev` pips | Verdict | Inference |
|---|---|---|---|---|
| 1 | hollow triangle, **three** pips, amber | 2 | **admit** | a positive. Could be anything |
| 2 | *twin of #1* | 3 | reject | **the same glyph just gave two different answers.** It is contextual. Two probes bought the family. |
| 3 | hollow triangle, **four** pips, amber | 3 | **admit** | pips went up, it admitted |
| 4 | *twin of #3* | 4 | reject | strict increase, not `>=` |
| 5 | hollow triangle, **one** pip, amber | 4 | reject | 1 > 4 false. Consistent. Also resets the context low |
| 6 | hollow triangle, **two** pips, amber | 1 | **admit** | 2 > 1. `pips(cur) > pips(prev)` is holding |
| 7 | hollow **square**, three pips, amber | 2 | reject | delta is still +1 but it rejected — **shape participates** |
| 8 | hollow **triangle**, four pips, amber | 3 | **admit** | same +1 delta, triangle back → it was the square |
| 9 | hollow triangle, one pip, amber | 4 | reject | deliberate reset, expected |
| 10 | hollow **circle**, two pips, amber | 1 | reject | +1 delta, circle → circle is out |
| 11 | hollow **hexagon**, three pips, amber | 2 | **admit** | +1 delta, hexagon → hexagon is **in** |
| 12 | hollow triangle, one pip, amber | 3 | reject | reset |
| 13 | hollow **square**, two pips, amber | 1 | reject | square confirmed out. Shape = {triangle, hexagon} |
| 14 | **solid** hexagon, three pips, **rose** | 2 | **admit** | fill and hue moved together and it still admitted |
| 15 | **striped** triangle, four pips, **frost** | 3 | **admit** | fill and hue are free. Declare |

Note probes 7→8: the informative move is not "change one attribute of the glyph" but **"hold the pip delta at +1 and change the shape."** Under contextual semantics the controlled variable is a *relation between two probes*, not an attribute of one. That is the skill band 5 is teaching, and it is why `d = 5` in the par table.

Shape is `{triangle, hexagon}` — ranks 2 and 4, a **scattered** subset, which is why probes 9–13 were needed at all: a contiguous shape set would have fallen out of probes 7–8.

**15 probes against par 23 → 2 marks** (3 marks needs ≤ 13; the two pure reset probes at #9 and #12 are the difference, and a sharper player sequences the shape sweep so each reset does double duty).

Declaration, nine taps: palette → Bridge stamp; leading socket → `pips` (this is `cur`); trailing socket → `pips`; **ghost toggle on the trailing socket**; wedge cycled to wide-end-leading, which reads *leading is the larger side* → `RANK pips(cur) > PREV RANK pips`; coupler left at AND; palette → Ramp stamp; header → `shape`; cells `triangle`, `hexagon`.

The Assay is conditioned on the pinned ghost, which defaults to the seed glyph — **hollow triangle, two pips, teal**, so `prev` pips rank = 2. The Bridge alone lights the 128 glyphs with pips ∈ {three, four}; the shape ramp halves that, and the finished draft **lights 64 cells**. Every ribbon admit is lit, every ribbon reject dark; the bar lifts off the Seal. (48 cells would be `p × 256` = 0.188 × 256, the *unconditional* marginal projection — the Codex thumbnail, not the live Assay. §4.3.) A player who instead reasoned "the shape rank is even" and lit the same two cells is inscribed as correct — same extension, same law (§4.5).

### 5.6 A worked round — band 3, EXCLUSIVE

Hidden: `shape ∈ {circle,triangle} XOR fill ∈ {hollow,dotted}`, `p = 0.500`, every marginal exactly 0.500.

hollow circle → reject (T⊕T). hollow triangle → reject. hollow square → **admit** (F⊕T). solid circle → **admit** (T⊕F). solid square → reject. dotted hexagon → **admit**.

The player still varying one attribute at a time sees 50 % admits on every attribute and concludes the machine is random. The player who notices that *shape and fill agreeing* predicts rejection has made band 3's move. Declaration: two Ramps — shape lit on `circle, triangle`, fill lit on `hollow, dotted` — coupler cycled to the crossed fork.

### 5.7 Locked constants

Every number the rest of this document must agree with.

| Constant | Value |
|---|---|
| Attributes / values each / **deck size** | 4 / 4 / **256** |
| Ordered pairs (contextual universe) | 65,536 |
| Non-trivial subsets per attribute / total atoms | 14 / **56** |
| Relational forms / contextual forms | 36 / 96 |
| Guard forms / aggregate forms | 8,736 / 1,214 |
| **MAX_DEPTH / MAX_LEAVES** | **2 / 4** (guard = exactly 3 leaves) |
| Max relational terms / contextual terms / leaves per attribute | 1 / 2 / 2 |
| `NOT` nodes in the grammar | **0** (complement-closed) |
| **Bands** | **8**, one family each, width 0.125 |
| Difficulty range / modifier ceiling | `[0.000, 1.000)` / 0.124 |
| Band populations \|H\| (1→8) | 40, 1,272, 108, 2,322, 6,934, 5,688, 10,314, 337 |
| **Total distinct laws** | **27,015** |
| **Admit-rate window** | **`p ∈ [0.15, 0.60]`**, target mode 0.30 |
| **Par** (1→8) | **7, 13, 16, 20, 23, 23, 26, 29** |
| **Cap** (1→8) = ceil(1.6 × par) | **12, 21, 26, 32, 37, 37, 42, 47** |
| Strikes per round | 2 (first continues the round, second ends it) |
| **Target round success rate** | **0.80** (first-declaration target 0.62) |
| Rasch coupling | `δ_logit = 8·difficulty − 4`; serve `θ − 1.386` |
| Novelty guard / generator attempt bound | last 50 solved extensions, passed in as `avoid` / 200 attempts |
| Generator purity | `generate(seed:band:targetδ:mode:avoid:)` — pure over those five arguments; determinism asserted at `avoid: []` |
| Equivalence check — stateless | 4 × `UInt64`; build ≈ 20 ns, compare ≈ 5 ns |
| Equivalence check — contextual | 1024 × `UInt64` (8 KiB); build ≈ 2 µs, compare ≈ 0.4 µs |
| Resident precomputed masks | ≈ 54 KB |
| Lower-band index (stateless, cached) | 9,767 tables, 305 KB — **band-partitioned** 40 / 1,272 / 108 / 2,322 / 5,688 / 337 |
| G4 scope | bands **strictly below** the candidate's own band |
| Contextual dedup index (hashes only) | 17,248 × 8 B = 138 KB — band-partitioned 6,934 / 10,314 |
| 10,000-law suite, all 8 bands | ≈ 1.2 s (budget: `swift test` < 10 s) |
| Reference device | iPhone SE 2/3 — 375 × 667 pt, safe 375 × 647 |
| Minimum hit target | 44 × 44 pt (smallest shipped: 56 × 44 pt) |
| Art scaling ceiling before Bench pager | 1.35× type multiplier (AX2) |

**Known limitations, locked and acknowledged.** Bands 3 and 8 are thin — 108 and 337 laws. Both exceed twice the novelty guard, so no near-term repeats, but a player who lives at band 8 will eventually shift from induction to recognition; that is the content ceiling of a 256-glyph deck and enlarging the deck would break the Assay, the Dial and the reference layout. The ladder also leaks: a player who knows roughly where they sit can pre-load the family and collapse `d`. Palette camouflage hides the current band but not the player's self-knowledge; the within-family search (11–13 bits at bands 4–7) still dominates the budget, and the daily Anomaly samples bands 4–7 uniformly, off-ladder, to deny the pre-load once a day.
## 6. PROBE — The Core Mode

PROBE is the whole game with nothing added. One hidden law, a Dial to build glyphs with, a ribbon that remembers, a Bench to state your answer on, and two chances to be right. Every other mode is this loop with one variable changed.

### 6.1 The round as a state machine

```swift
enum RoundPhase: Sendable, Equatable {
    case arming                      // law generated OR snapshot restored; first frame not yet shown
    case probing                     // Dial live, input open — the only open-input phase
    case adjudicating(Verdict)       // 420 ms (320 ms Reduce Motion), input locked, model committed
    case declaring                   // Bench up, Dial down, input open
    case sealing                     // 640 ms, input locked, verdict already computed, verdict-blind
    case counterexample              //   960 ms, input locked, first strike only
    case revealing(Outcome)          // 1,840 / 1,020 / 1,620 ms — see §6.8
    case settled(Outcome)            // the round card (chrome; text permitted here)
}

enum Outcome: Sendable, Equatable {
    case inscribed(marks: Int, fracture: Bool)   // correct declaration
    case broken                                  // second strike
    case exhausted                               // cap reached
    case abandoned                               // player left after ≥ 1 probe
    case voided                                  // stored law failed its integrity hash on resume
}
```

**Every duration in the table below is the duration of the destination phase, measured inside that phase.** §6.8's beat sheets are the other convention — they are measured from the Seal press, because a player experiences one continuous event there, not two. Where both appear, `absolute = 640 + local`.

| From | Trigger | To | What ends the state |
|---|---|---|---|
| *(entry)* | new round generated | `arming` | — |
| *(entry)* | cold launch with a live snapshot | `arming` | the snapshot is rehydrated and its law integrity-checked before any frame |
| `arming` | fresh round, first frame committed | `probing` | one frame; never visible as a wait |
| `arming` | resumed round, stored law passes its integrity hash | `probing` | the 900 ms re-entry beat (§6.10); input locked throughout, phase is `probing` from its first frame |
| `arming` | resumed round, stored law **fails** its integrity hash | `settled(.voided)` | no beat sheet; the round card opens directly on a broken-seal state |
| `probing` | PROBE key, twin key, or throat-swipe-then-PROBE | `adjudicating` | the 420 ms beat sheet completes (320 ms Reduce Motion) |
| `probing` | Bench handle tap / upward drag, or Bench key | `declaring` | the 380 ms transition completes |
| `probing` | probe index reaches `cap` | `adjudicating` → `revealing(.exhausted)` | the cap-th verdict is still delivered in full |
| `probing` | abandon from the run frame, ≥ 1 probe | `settled(.abandoned)` | — |
| `probing` | abandon from the run frame, 0 probes | *(exit)* | the round is discarded outright; no record, no `Outcome` (§6.10) |
| `adjudicating` | 420 ms elapsed (320 ms under Reduce Motion) | `probing` | — |
| `declaring` | Dial key | `probing` | draft preserved verbatim |
| `declaring` | Seal (unbarred) | `sealing` | 640 ms hold, identical for both verdicts |
| `declaring` | abandon from the run frame, ≥ 1 probe | `settled(.abandoned)` | the Bench collapses first, 380 ms |
| `sealing` | correct | `revealing(.inscribed)` | **1,840 ms** (sec-13 §13.7.1), skippable from t = 400 ms of the reveal |
| `sealing` | wrong, `strikes == 0` | `counterexample` | **960 ms**, then auto-collapse to `probing` |
| `sealing` | wrong, `strikes == 1` | `revealing(.broken)` | **1,020 ms** (sec-13 §13.7.1, lost skeleton) |
| `counterexample` | beat sheet completes | `probing` | strikes := 1; Bench collapses; draft preserved |
| `revealing(_)` | beat sheet completes or tap-to-skip | `settled(_)` | — |
| `settled(_)` | NEXT / run frame | new `arming` or exit | — |

`settled(.voided)` is reachable **only** from `arming`, and only on a resume. Nothing inside a live round can produce it, which is the point: a voided round is a round the machine declines to vouch for, not a round the player lost.

Two invariants hold everywhere and remove an entire class of bugs:

- **The model never waits on an animation.** Every verdict — probe or declaration — is computed and committed to `RoundState` at t = 0 ms of its beat sheet and merely *displayed* later. Killing the app mid-animation loses nothing.
- **No wall-clock quantity affects score, marks, or the Rasch update in PROBE.** `Tempo` is `probes / par` (canon §5.4), not seconds. A round can be paused for a week without consequence. Elapsed time is recorded for the round card only.

### 6.2 The play surface, portrait, two devices

SE geometry is canon §4.1 verbatim. Pro Max geometry is derived by one rule.

> **Decision:** surplus height goes to the **throat and the ribbon**; the Dial, handle and commit bar keep their heights and are laid out **upward from the bottom safe edge** — because the evidence display benefits from every point it gets, while the controls must stay inside the thumb arc, which is anchored to the bottom edge, not to the screen height. Growing the Dial on a big phone would push its top row out of reach.

| Region | iPhone SE 2/3 — 375 × 667, safe 375 × 647 | iPhone 16 Pro Max — 440 × 956, safe y 62…922 |
|---|---|---|
| instrument bar | y 20–64 · mode sigil (leading) + par tick row, 288 pt wide | y 62–106 · same, 348 pt wide |
| the throat | y 64–176 · 96 pt live glyph, centred | y 106–306 · 128 pt live glyph |
| the ribbon | y 176–228 · one lane, 44 pt tiles, 50 pt pitch | y 306–420 · **two lanes**, 50 pt pitch, chain wraps with a return elbow |
| bezel gap | — | y 420–470 · machined dead band, no controls |
| the Dial | y 236–508 · 4 ramps × 60 pt, 8 pt gutters; header 44 + 4 cells 70 × 48 | y 470–812 · 4 ramps × 78 pt, 10 pt gutters; header 52 + 4 cells 82 × 62 |
| Bench handle | y 516–560 | y 820–864 |
| commit bar | y 604–667 · **PROBE** (leading) · **twin** (centre) · **Bench** (trailing) | y 868–922 · same three keys, 60 pt tall |

**The par tick row is length-proportional, not pitch-fixed.** Canon §5.4 makes the row's *length* the only difficulty signal the player gets (sec-10 §10.5: 7 ticks at band 1, 29 at band 8, uncountable at a glance past ~7), so pitch is held constant and length varies:

```
nominalPitch = 9 pt (SE) | 10 pt (Pro Max)
rowWidth     = 288 pt (SE) | 348 pt (Pro Max)
tickPitch    = min(nominalPitch, rowWidth / N)          // N = the mode's par for this band
```

At PROBE's longest par, `N = 29`, that is a fixed 9 pt pitch and a 261 pt row on SE — always inside the 288 pt the bar allows, so within PROBE the row's length is exactly proportional to par and sec-10 §10.5's signal is intact. The clamp only engages in DRIFT, where `par_DRIFT` reaches **40** at band 8 (sec-07 §7.7): 40 × 9 = 360 > 288, so the pitch compresses to 288/40 = **7.2 pt** on SE and 348/40 = 8.7 pt on Pro Max. The tick itself stays 2 pt wide, leaving ≥ 5.2 pt of gap, and DRIFT's tick count already identifies the mode by design (sec-07 §7.5), so compressing its row costs no signal that was not already given away.

**Thumb reach.** Measured from the **bottom safe edge**, the Dial's top edge sits 431 pt up on SE (667 − 236) and 452 pt up on Pro Max (922 − 470) — a 21 pt difference across a 289 pt difference in screen height. Every interactive target in PROBE lives within 460 pt of the bottom safe edge on both devices. The throat (603 pt up on SE) and the ribbon (491 pt at its top edge) sit above that band on both, deliberately: they are read, not touched, except for two low-frequency gestures (throat swipe, ribbon-load tap) which are convenience paths with a Dial equivalent.

**Visible history before scroll.** SE: 7 whole ribbon tiles plus a 25 pt peek of the eighth. Pro Max: 16 (8 per lane). The ribbon is pinned to its trailing edge and re-pins after every verdict; scrolling back is a standard horizontal scroll, so VoiceOver's three-finger swipe works with no custom gesture.

**Beyond that, the sheet.** Seven tiles is a viewport, not a ledger. Tapping the **spool** — the 24 pt rail-cap at the ribbon's leading edge — expands the ribbon to a full-screen read-only **sheet**: a **7 × 10 grid of 70 cells**, 45 pt cells with 40 pt glyphs on SE, 51 pt cells with 46 pt glyphs on Pro Max.

**The sheet is sized against the largest cap in *any* mode, not PROBE's.** PROBE's cap tops out at 47 (canon §5.7), but the sheet is a shared surface: sec-07 §7.5 gives DRIFT PROBE's layout region for region, and §7.7 locks `cap_DRIFT` to 52 at bands 5–6, 60 at band 7 and **64** at band 8. The worst case the grid must hold is therefore `max(cap, cap_DRIFT) + 1 = 65` — the seed glyph plus 64 probes — and DRIFT is precisely the mode that needs it, because its whole reveal (§7.9's seam and split) is a re-reading of the entire transcript on both sides of the hinge. **70 ≥ 65 with five cells spare, so the longest possible round in any mode is on one screen with no scrolling.** This is asserted by the same test that asserts the pitch invariant: `sheetCells ≥ 1 + max over modes and bands of cap`.

Geometry, both devices: SE `7 × 45 + 6 × 6 + 2 × 12 = 375` across and `10 × 45 + 9 × 6 = 504` down, placed at y 72–576 under a 20–64 header carrying the spool cap and the sort toggle. Pro Max `7 × 51 + 6 × 8 + 2 × 16 = 437` across and `10 × 51 + 9 × 8 = 582` down, at y 114–696. Seven columns rather than eight because eight would force a 38 pt cell on SE, below canon's 44 pt minimum hit target — and every cell is tappable.

- **Chain order** (default): reading leading→trailing, top→bottom, mirrored under RTL, with link arcs and a return elbow at each row end so adjacency survives the wrap.
- **Verdict sort** (one tap on the spool again): admits block first, rejects second, chain order preserved within each block. Link arcs are dropped; twin pairs keep their doubled ring.
- Tap any cell to ribbon-load it into the Dial and dismiss. Tap the spool a third time to close.

The sheet costs nothing, consumes no probe, and is available from probe 0.

### 6.3 Composing a probe

The Dial is four single-select ramps in canonical order `fill → shape → pips → hue`. The throat *is* the draft: the glyph in the throat is what the PROBE key will feed to the Loom.

| Action | Cost | Effect |
|---|---|---|
| tap a Dial cell | free | that ramp's selection moves; the throat redraws in 80 ms |
| swipe the throat glyph horizontally | free | steps the last-touched attribute by ±1, wrapping off |
| tap a ribbon tile (or a sheet cell) | free | ribbon-load: the Dial and throat adopt that glyph wholesale |
| **PROBE** key | 1 probe | feeds the throat glyph |
| **twin** key | 1 probe | re-feeds the glyph currently in the throat, unchanged |

**Only the changed register animates.** When a Dial cell changes the fill, the fill texture crossfades and the silhouette, contour nodes and index stroke hold perfectly still. This is not polish: it is what makes controlled variation *visible* as an act, and it is why the register-disjointness of canon §2 is load-bearing here.

**At probe 0 the Dial is pre-loaded with the seed glyph**, so the throat matches what the Loom was primed with and probe 1 is one tap.

> **Decision:** probe 1 defaults to a twin-of-seed — because it costs one tap, it establishes the seed glyph's own verdict (a baseline every band wants), and it is family-neutral: the same default in band 1 and band 8 leaks nothing.

**Probes are free within the cap.** There is no probe currency, no refill, no consumable, no cooldown, no wait, and no timer. Two budgets exist and neither is a resource:

- **par** (7, 13, 16, 20, 23, 23, 26, 29) — soft. Renders as an unlit tick row that fills as you probe. Costs nothing until exceeded, then costs score continuously.
- **cap** (12, 21, 26, 32, 37, 37, 42, 47) — hard. A second, dimmer tick row below par's begins *emptying* past par; when it empties the round ends as a loss. No numerals, no countdown. The handover between the two rows is the **par crossing** (§6.9), the round's one non-verdict event.

> **Decision:** probes are never a spendable resource — because a resource economy converts an induction game into a rationing game, makes the correct move "probe less than you need to," and manufactures exactly the refill slot the brief forbids. Probe economy is a *score* dimension only.

### 6.4 ADMIT / REJECT semantics

The Loom is a total, deterministic, pure function.

```
verdict(cur) = law.evaluate(cur, prev)
prev(1)      = seedGlyph                    // primed, not a probe, no verdict, not scored
prev(n)      = glyph(n − 1)                 // previously *probed*, regardless of verdict (canon §3.5)
```

Every one of the 256 glyphs receives exactly one of `admit` / `reject` under every one of the 256 possible `prev` values. There is no third state, no "invalid", no "unknown", no partial credit, no "close". A verdict once frozen onto a ribbon tile never changes. Replaying an identical probe sequence **under the same law** reproduces an identical verdict sequence — asserted by test, and re-asserted on every resume, where the stored law re-derives every ribbon verdict from glyph IDs alone (§6.10).

**Encoding, in three independent channels. Any one alone is sufficient.** Audio and haptic values are sec-13 §13.8 and §13.9 verbatim; this table is the mapping, not a second definition of the cues.

| Channel | admit | reject |
|---|---|---|
| geometry (primary) | the ring around the glyph **completes** — a continuous 3 pt circle with a 6 pt outward bloom | the ring **collapses** inward to a 1.5 pt hairline crossed by one diagonal cancel stroke |
| colour (redundant) | signal amber `#E69F00` | cold frost-grey, desaturated |
| audio (procedural) | `admit` — just perfect fifth, 220.25 + 330.37 Hz (+ 660.75 at −18 dB), 4 ms attack, 260 ms decay. Beat-free: it *locks* | `reject` — just tritone, 146.83 + 206.48 Hz (+ 73.42 sub at −12 dB), 2 ms attack, 190 ms decay. Down and unresolved |
| haptic | `admit` — **one** transient, I 0.55, Sh 0.30. Soft, round, low | `reject` — **two** transients at 0 and 75 ms, I 0.45 / 0.30, Sh 0.90. Hard, bright, doubled |
| VoiceOver | one localized utterance, announced at the verdict beat | same |

The haptic contrast is *count and sharpness together* — one soft event against two sharp ones — so the two verdicts are separable with the screen face-down. Do not "improve" admit by making it crisper; a sharp admit and a soft reject are the same event to a thumb.

Open versus closed aperture is a **shape** difference, so the verdict survives silent switch + haptics off + monochrome high-contrast theme simultaneously.

### 6.5 Submit: the 420 ms verdict beat

| t (ms) | Beat |
|---|---|
| 0 | Key depresses 2 pt. Input locks. **Verdict computed and appended to `RoundState.probes`.** Snapshot scheduled. Throat glyph contracts to 0.92 over 90 ms, ease-in. `probe.submit` cue — 195.77 Hz triangle, 1 ms / 55 ms, −26 dBFS — and `probe.submit` haptic, one transient I 0.28 Sh 0.65, quieter than either verdict. |
| 90–260 | **The adjudication hold.** Nothing moves but a hairline aperture rotating in the throat ring. |
| 260 | Verdict lands: aperture opens or closes per §6.4. Audio and haptic fire on the same frame. VoiceOver utterance posted. **This is where sec-13 §13.7.2's micro-response begins** — its local t = 0 is our t = 260. |
| 260–420 | The tile buds off the throat, travels to the ribbon's trailing edge, the link arc draws over 120 ms, the ribbon re-pins, one par tick fills. On the probe that fills the **last** par tick, the par crossing fires here (§6.9). |
| 420 | Input unlocks. |
| 420–520 | The admit ring finishes expanding (sec-13's 200 ms ring, 260 → 460) or the reject ring finishes breaking (260 → 510). **Non-blocking**: it outlives the lock by design, so the next probe can start while the last one is still fading. |

> **Decision:** the adjudication hold is a **constant 260 ms regardless of verdict, band, or whether the law is contextual** — because variable latency is a side channel. A Loom that "thinks harder" about hard glyphs would leak the family before probe 3, and the real evaluation cost is 5 ns to 0.4 µs (canon §3.6), which is invisible either way.

**Fast probing.** Input is locked 0–420 ms, capping the rate at ~2.4 probes/s. The PROBE and twin keys hold a **single-slot queue**: one tap during the lock is honoured at t = 420 ms and compresses the following ribbon travel to 180 ms. A second tap during the lock is dropped. The Seal has **no queue** and is edge-triggered — a queued second declaration would be catastrophic.

> **The input lock and the ring animation are different clocks, and only one of them gates input.** sec-13 §13.7.2 describes the admit and reject micro-responses as "never blocking", which is true of the *rings*: they are decoration over a verdict already committed, and they run past the unlock. It is not true of the beat: **the next probe cannot be issued before t = 420 ms** (320 ms under Reduce Motion), because the throat must return to a stable draft state before it can be re-fed and because a 260 ms hold the player can outrun is not a hold. Read §13.7.2's timings as offsets into the 260–520 ms window of this table, never as an input policy.

**Reduce Motion:** the input lock shortens to **320 ms** — the 260 ms hold unchanged, then a 60 ms crossfade in place of the contraction, travel and arc draw. The ring's own substitution (sec-13 §13.7.4: a static closed or broken ring crossfading in and out over 160 ms) runs 260–420 ms and, as above, never blocks. Same audio, same haptic, same beat positions; the queued tap is honoured at t = 320 ms.

**Recording.** `ProbeRecord { index: UInt8, glyphID: UInt8, verdict: Verdict, isTwin: Bool }` in memory for rendering; the persisted snapshot stores glyph IDs only and recomputes verdicts from the stored law (§6.10).

### 6.6 Making contextuality discoverable without words

A player must be able to *find out* that a law can depend on the previous glyph. Six layers do it, all present in **every band** so that none of them leaks the family, and all of them shapes rather than words.

1. **The seed glyph.** At round start something is already in the throat that the player did not put there, wearing a dashed hollow frame and a backward chevron. Before probe 1, in every band, the machine visibly is not empty.
2. **The ghost mark.** The trailing-most ribbon tile always carries that same dashed frame and backward chevron. The Loom's memory has a permanent, visible, one-slot address on screen at all times.
3. **The twin key.** A third of the commit bar, from round 1 of band 1. In bands 1–4 it *always* agrees with itself — four bands of teaching that the Loom is consistent. At band 5 it disagrees for the first time, and the contradiction lands precisely because the expectation was built for free.
4. **The split doubled ring.** A twin pair draws in the ribbon as one unit under a doubled ring. When the two verdicts differ, the ring draws **split** — one half open, one half closed, on a single drawing of a single glyph. A rendered contradiction; no colour required, no text possible.
5. **The sheet's verdict sort** (§6.2). One tap re-sorts the round into an admit block and a reject block, and asks the only question that matters: *can the same glyph appear on both sides?* In a stateless round it cannot. In a contextual round it does. The interface lets the player ask, and the answer is the family.
6. **The ghost toggle on the Bench** (canon §4.2) is drawn in the identical dashed-frame-and-chevron idiom as layers 1, 2 and 4, and the **Assay conditioned on a pinned ghost** (canon §4.3) morphs as the ghost is scrubbed. Symbol identity does the naming that words are forbidden from doing.

> **Decision — the breath.** If `probesUsed > 0.6 · par` and the twin key has never been pressed this round, the twin key breathes: a 1.2 s hairline pulse every 8 s, no arrow, no badge, no modal, no text. It fires on the **same rule in every band**, so it cannot leak contextuality — at bands 1–4 it costs one mildly wasted probe, which is itself the lesson of layer 3. It stops permanently on first use. Under Reduce Motion it is a static 30 % opacity lift instead of a pulse.

### 6.7 Declaring

**Entering.** Tap the Bench handle, drag it upward, or tap the Bench key in the commit bar. All three are equivalent; the handle is exposed to VoiceOver as a button so the drag is never required. 380 ms: the Dial's ramps slide down and out, the rails rise, the palette appears at y 560–604, the Assay slides in from the trailing edge, the commit bar crossfades from three keys to two (Dial leading, Seal trailing).

**The throat and the ribbon do not move.** Canon's two layouts place both at y 64–176 and 176–228 in Dial mode *and* Bench mode. The evidence never leaves the screen while the player states their theory. This is the single most important layout constraint in the mode.

**Availability.** The Bench opens at any time, including probe 0. No gate, no minimum, no unlock. A gate would be a rule taught by refusal, which is the one teaching method a wordless game cannot use.

**Backing out.** Tap the Dial key. 380 ms reverse. **The draft is preserved verbatim** — cells, sockets, wedges, ghosts, coupler. Returning finds it exactly as left. A player probes specifically to test a specific draft; discarding it would make the round trip pointless.

**Cost.** Opening, editing, expanding the Assay, and closing the Bench all cost zero probes and advance no counter.

**Worked declaration** — the band 5 law of canon §5.5, `RANK pips(cur) > PREV RANK pips AND shape ∈ {triangle, hexagon}`, nine taps:

The Assay counts below are conditioned on the pinned ghost, which defaults to the seed glyph — **hollow triangle, two pips, teal**, so `prev` pips rank = 2 (canon §4.3, §5.5).

| # | Tap | Result |
|---|---|---|
| 1 | palette → Bridge stamp | Bridge lands on rail 1; both sockets dashed and empty; Seal barred |
| 2 | leading socket → `pips` header | leading socket binds. It is always `cur` and carries no toggle (canon §4.2). Assay dark — the trailing socket is unbound |
| 3 | trailing socket → `pips` header | Bridge complete at the default `eq`, both sockets `cur` → a tautology. All 256 cells lit, Seal barred on a constant extension |
| 4 | **ghost toggle on the trailing socket** | trailing socket re-frames as `prev` — dashed frame, backward chevron. `RANK pips(cur) == PREV RANK pips` → **64 cells** (pips = two) |
| 5 | wedge, cycled to wide-end-leading | comparator `>` → `RANK pips(cur) > PREV RANK pips` → **128 cells** (pips ∈ {three, four}) |
| — | coupler left at AND | welded bar, default |
| 6 | palette → Ramp stamp | Ramp lands on rail 2, 0 cells lit → inert, hairline slash, Seal still barred |
| 7 | Ramp header → `shape` | attribute bound; still 0 cells lit, still inert |
| 8 | cell `triangle` | 1 cell lit; Assay narrows to **32** |
| 9 | cell `hexagon` | 2 cells lit; Assay settles on **64**; **the machined bar lifts off the Seal** |

The ghost toggle is on the **trailing** socket and only ever there. That is not a UI preference, it is RNF rule 3 made physical (canon §3.4, §4.2): every one of the 96 contextual forms is `RANK a(cur) ⋈ PREV RANK b`, so `cur`-leading is the grammar's own orientation and all 96 are reachable as leading attribute × trailing attribute × wedge. Putting the toggle on the leading socket would make the transposed family the only expressible one and render a law RNF forbids.

Note step 3: binding the second socket transiently produces a tautology, and the Seal is barred on it exactly as canon §4.3 requires — the machined bar is doing real work mid-build, not only at the end. Note also that 64 is the *conditioned* count, the live Assay's slice through the pair table at the pinned ghost; 48 would be `p × 256` = 0.188 × 256, the unconditional marginal projection, which is the Codex thumbnail and a different picture with a different job (canon §4.3). The two are never quoted for each other.

Every ribbon admit is lit in the Assay, every ribbon reject dark. The bar lifts the instant no rail is inert, no socket unbound, and the extension is non-constant — canon §4.3. Pressing a barred Seal pulses the offending rail and does nothing else: no error text, no error state, no modal.

### 6.8 Resolution

**All times below are absolute, measured from the Seal press.** sec-13 §13.7.1 specifies the reveal in its own local time, starting at its beat 0; the two are the same sheet with `absolute = 640 + local`, and the beat numbers are given so they cannot drift apart. There is exactly one reveal sheet in this document and it lives in sec-13.

**The seal beat, both outcomes identical for 640 ms.** t = 0: Seal depresses 3 pt, `declare` cue (146.83 → 293.66 Hz glide over 180 ms), input locks, **comparison performed and committed — and with it the Codex page, the θ update, the Profile accumulators and the novelty ring entry** (§6.1's invariant: the model never waits on an animation). t = 0–240: a hairline circuit lights from each rule-tile through the coupler to the Seal, 80 ms apart. t = 240–640: a slow ring rotation in the Seal and nothing else. **This hold is the reason the reveal can be honest about its own length:** it is verdict-blind, identical in content and duration for a correct and an incorrect declaration, so the answer is not readable off the clock. It is also unchanged under Reduce Motion — shortening it for some players would hand them a different game.

**Correct — 640 ms seal hold + sec-13's 1,840 ms reveal = 2,480 ms.** Skippable from **t = 1,040 ms** (t = 400 ms of the reveal, sec-13's threshold, expressed absolutely). That is the one skip threshold; there is no other.

| t (ms) | sec-13 beat | Beat |
|---|---|---|
| 640 | 0 | The Seal **releases** its 3 pt depression over 90 ms and the ring completes; the machined bar, if any, retracts off the trailing edge. `law.declared.correctly` opens: continuous 640–820, I 0.15 → 0.55, Sh 0.10. |
| 730 | 1 | All unlit Bench chrome → 0 opacity; the ribbon → 20 %. **The Assay holds at full** — for 140 ms it is the only thing at full brightness on the screen, which is the beat that says *meaning, not syntax*. |
| 870 | 2 | The player's rule-tiles leave their rails and gather into one centred stack, 8 pt overshoot. |
| 1,130 | 3 | The Loom's own tiles fade in **behind** the player's at 14 pt offset and converge to zero — two readings of one law registering onto each other. |
| 1,450 | 4 | **Registration.** The brass hairline sweeps leading→trailing at 1,900 pt/s; each tile's stroke steps to `accent.brass`. Transient I 0.75 Sh 0.85 — the pawl dropping — then continuous 1,450–1,690, I 0.60 → 0.10, Sh 0.40. The `correct` cue's four voices enter one per 90 ms, onsets aligned to this beat and beat 6. |
| 1,630 | 5 | The Assay's lit constellation contracts into the 64 pt page thumbnail and docks below the stack. `codex.inscribe` — 264.29 + 396.44 Hz, 700 ms decay, soft and long underneath everything else. |
| 1,850 | 6 | Seal marks strike in, one per 80 ms: N transients at 1,850 / 1,930 / 2,010, I 0.50 / 0.60 / 0.70, Sh 0.70, where N is the marks earned. A fracture, if present, draws as a hairline crack across the page. |
| 2,090 | 7 | The Codex page frame draws itself, hairline, from the top-leading corner, clockwise. Continuous 2,090–2,350, I 0.30 → 0.05, Sh 0.15 — the frame being drawn, felt. |
| 2,350–2,480 | 8 | The 3 pt global drift resolves to 0; the continue affordance fades in → `settled(.inscribed)`. |

Beat 0 is the one place the two documents needed reconciling rather than adding: sec-13 §13.7.1 writes it as the Seal *depressing*, because its sheet starts at the press. Here the press already happened at t = 0 and spent that 3 pt, so beat 0 is the release. Same 90 ms, same phase, opposite sign — the `phaseAnimator`'s phase count is unchanged. Separately, sec-13 §13.9 annotates its opening continuous haptic *(beat 3, convergence)*; by its own offsets (t 0.00–0.18) that event lands on beat 0, and it is placed there above. The label is what wants correcting, not the timing — every other offset in the haptic table agrees with §13.7.1's beats exactly.

**Reduce Motion** (sec-13 §13.7.4): the 640 ms hold runs unchanged, then one 260 ms crossfade to the settled composition with the marks already struck — 900 ms total. Every audio and haptic onset keeps its absolute position; the ones that fall past 900 ms are dropped rather than rescheduled, because a haptic arriving after the screen has settled is a second event, not the same one.

**VoiceOver** posts three announcements — at **640** (the verdict), **1,450** (beat 4, the law lands) and **1,850** (beat 6, the page and its marks) — and disables tap-to-skip, which collides with tap-to-focus; VO users skip with the magic tap.

**Incorrect, first strike — 640 ms seal hold + 960 ms counterexample = 1,600 ms, round continues:**

| t (ms) | Beat |
|---|---|
| 640 | The Seal ring **breaks**: it splits at two points and the arcs slide 6 pt apart. `law.broken` haptic — transient I 0.85 Sh 1.00, then continuous 660–1,060 ms I 0.55 → 0.00 Sh 0.75, then a settling transient I 0.35 Sh 0.20 at 1,060 ms. `incorrect` cue: 146.83 + 206.48 Hz held, dropping to 138.59 Hz at t = 1,060 — a semitone fall, the machine settling. |
| 640–1,000 | Bench dims to 30 %. The counterexample rises from its cell in the Assay and travels to centre at 96 pt. In contextual bands, **two** glyphs joined by the link arc, the leading one wearing the ghost frame. |
| 1,000–1,300 | It takes **two rings at once** — inner ring the declaration's verdict, outer ring the Loom's, in the same open/closed aperture idiom as every probe verdict. The contradiction is legible with no colour. |
| 1,300–1,600 | The counterexample docks **below** the ribbon's trailing end as a marginal island with a doubled outline and stays there for the rest of the round. The Bench auto-collapses to the Dial. |

Counterexample selection is canon §4.5 verbatim: restrict to disagreements, prefer false negatives, minimise attribute-space Hamming distance to the nearest ribbon glyph, tie-break on lowest `glyphID`. The law is never revealed.

> **Decision:** the counterexample is **not** a probe. It does not increment `probesUsed`, it does not become `prev`, and it draws below the chain with no link arc into it — because a player's carefully arranged context should not be destroyed by their own failure, which has nothing to do with the law.

> **Decision:** the Bench auto-collapses to the Dial after a strike, and there is **no forced probe** before re-declaring — because evidence is acted on by probing (so return the player to the Dial), but a player who reads their error straight off the counterexample has done the reasoning, and a mandatory-probe gate would be another rule taught by refusal.

**Second strike — 640 ms seal hold + sec-13's 1,020 ms lost skeleton = 1,660 ms, round over.** Same break at 640 ms. The lost skeleton is the correct sheet with beats 0–2 unchanged (absolute 640 / 730 / 870); at beat 3 (1,130) the Loom's tiles fade in **alone** while the player's stack falls 24 pt and fades out over 180 ms; beat 4's sweep is `accent.cold` rather than brass; beats 5–7 are skipped, because there is no thumbnail, no mark and no page to file; beat 8 runs at 1,530 and settles at 1,660. No Codex page, no score, `Outcome.broken`. Reduce Motion: the 640 ms hold plus one 260 ms crossfade, 900 ms total.

**Cap reached — the exhausted end, 2,040 ms from the cap-th verdict.** There is no `sealing` phase here, because there was no Seal press: the path is `probing → adjudicating → revealing(.exhausted)`. The cap-th probe's verdict resolves in full first — 420 ms, a paid-for bit is never withheld. Then `revealing(.exhausted)` runs **1,620 ms**: for 600 ms the Dial's ramps go dark and inert, the dim tick row empties completely, and **the Bench opens itself with the Loom's law already assembled on the rails**; from +600 ms the lost skeleton runs its 1,020 ms exactly as above, with the player's stack empty, so beat 3 is the law arriving on an unclaimed Bench. Score 0, no page, `Outcome.exhausted`. Canon §4.5: the reveal is priced at `1.6 × par` probes, more than solving costs, so it is never an exploit.

**Two declarations per round, hard.** No third.

### 6.9 Scoring

```swift
let probesUsed = max(1, probeCount)                        // guards a 0-probe declaration
let economy    = min(1.0, Double(par) / Double(probesUsed))
let penalty    = (strikes == 1) ? 0.6 : 1.0
let score      = Int((1000.0 * economy * penalty).rounded(.toNearestOrAwayFromZero))
let marks      = probesUsed <= 0.6 * Double(par) ? 3
               : probesUsed <= Double(par)       ? 2 : 1
```

Evaluation order is **multiply then round once**, so a strike never produces a fractional intermediate. Only `Outcome.inscribed` scores; `broken`, `exhausted`, `abandoned` and `voided` all score exactly 0.

> **Decision:** losses score 0, with no consolation points — because score is the Codex's currency and a loss inscribes no page; a consolation score would make the page count and the score total disagree. The Profile axes still update from behaviour, so a lost round is not lost data.

> **Decision:** marks and the fracture are **independent** records. A 3-mark fractured page exists and is drawn with three marks and a crack — because conflating them destroys information about a round that was solved efficiently *after* a wrong turn.

**The gradient is flat below par, and that is the point.** `min(1, par/probesUsed)` pays a full 1000 for any probe count at or under par. A careful player who uses their whole budget is not taxed for it; extreme economy is recognised categorically, by the third Seal mark, not continuously. This is exactly "probe economy rewarded without punishing careful play": the cost curve begins only where the budget ends.

**The flat region, stated honestly, and why the thresholds do not move.** Between `0.6·par` and `par` the marginal probe costs nothing in score and nothing in marks. That is a real property of the design and it is deliberate, not an oversight, but it has to survive the obvious objection: *why not simply probe to par every time?* Three answers, in order of weight.

1. **`par` is the budget, not a bonus.** `par = ceil(k·log₂|H| + d)` is calibrated so that a player at the 80 % success target *needs* roughly par probes (canon §5.4). The third mark at `0.6·par` is a distinction, not the modal outcome. So "burn the rest of the budget" is a strategy that presupposes the player has already finished — and a player who has finished has nothing left to do but declare, because declaring is the only other verb in the round. The line the objection describes is not a dominant strategy, it is an *indifference*, and it is broken by the only currency the game does not model and the player does: their own time. At band 8 that is four more minutes of tapping for zero reward.
2. **The boundary is legible but not countable.** Par renders as tick marks with no numerals and no countdown (canon §5.4, P1). The row is proportional and uncountable at a glance past ~7 (sec-10 §10.5). A player can see that par is *near*; they cannot see that it is four probes away. "Probe to exactly par" is not an executable instruction on this instrument, which is why the crossing had to be made an event rather than an arithmetic fact — see below.
3. **The flat region is not free of record.** `Tempo` is `probes / par` and is a permanent Profile axis (canon §5.4); the Codex page carries `probesUsed` forever (§6.10). A 15-probe page and a 23-probe page at band 5 are different objects in the archive even though both carry two marks and both score 1000.

> **Decision:** the mark thresholds stay at canon's `3 ≤ 0.6·par`, `2 ≤ par`, `1 ≤ cap`, and specifically **the middle threshold does not move in to `0.85·par`**. Reason: pulling it in re-taxes exactly the careful play the flat gradient exists to protect, and it does so worst at the bands where the budget is most genuinely needed — at band 8 it would put the 2-mark boundary at probe 24 against a budget of 29, so a player who spends the budget they were given loses a mark for spending it. The problem the proposal was aiming at is real; it is a *drama* problem, not a scoring problem, and it is solved by making the end of the flat region a witnessed moment rather than by charging for the middle of it. Canon §5.4 and §5.7 also lock these three numbers, and the rest of the document is built on them.

**The par crossing.** On the probe that fills the last par tick, at t = 260–420 ms of the verdict beat (§6.5), the par row completes and **inverts** — filling ticks become one solid rule — and on the same frame the dim cap row below it lights fully and begins emptying from the **trailing** end with the next probe. The instrument bar's only animated element reverses direction, once, permanently, at the exact probe where score begins to decay and the page drops to one mark. That reversal is what §1.7's Nerve phase is watching for.

> **Decision:** the par crossing has **no audio and no haptic**, unlike every other structural event in the round. Reason: it lands on the same frame as a verdict, which owns the audio and haptic channels absolutely (§6.4), and a second cue there would either mask the verdict or be misread as part of it — a player would learn "sometimes the admit tone is different", which is a lie about the law. The crossing is geometry only; VoiceOver already carries it, since the probe tally is `.updatesFrequently` and speaks par and cap as numbers (sec-13 §13.10, where numerals are permitted because labels are audio).

**Three worked rounds.**

| | **A — great** | **B — average** | **C — bad** |
|---|---|---|---|
| Band / family | 5 CONTEXTUAL | 4 RELATIONAL | 6 GUARDED |
| par / cap | 23 / 37 | 20 / 32 | 23 / 37 |
| Declarations | one, at probe 13, correct | probe 17 wrong → probe 24 correct | probe 19 wrong → probe 30 wrong |
| Par crossing | never reached | at probe 20, between the strike and the second declaration — the four taxed probes are exactly the ones that cost the mark | at probe 23, and the player kept going |
| `probesUsed` | 13 | 24 | 30 |
| `economy` | `min(1, 23/13) = min(1, 1.769) = 1.000` | `min(1, 20/24) = 0.8333` | — |
| `penalty` | 1.0 | 0.6 | — |
| Raw | `1000 × 1.000 × 1.0 = 1000.0` | `1000 × 0.8333 × 0.6 = 500.0` | — |
| **Score** | **1000** | **500** | **0** |
| Marks | `0.6 × 23 = 13.8`, `13 ≤ 13.8` → **3** | `24 > 20`, `24 ≤ 32` → **1** | none |
| Outcome | `inscribed(3, fracture: false)` | `inscribed(1, fracture: true)` | `broken` |
| Codex | clean page | page with a fracture | nothing |
| Rasch | success at δ .525 | success at δ .432 | failure at δ .639 |

Variant **C′**, the other loss shape: the same band 6 round with no declaration at all. The player probes to 37, the cap empties, `Outcome.exhausted`, score 0, law revealed in rule-tiles, recorded as a failure at δ .639 — canon §5.4 requires a failure signal that is not solely "declared wrong", or a grinding player makes the Rasch model unidentifiable.

**Why declaring early and often loses.** Structurally, the maximum number of declarations per round is **two**, so "often" tops out at two. Economically, using canon's targets — first-declaration success 0.62, round success 0.80, hence second-declaration success given a strike = `(0.80 − 0.62)/0.38 = 0.474`:

- *Patient* (probe to par, declare once): `0.62 × 1000 + 0.38 × 0.474 × 600` = **728** expected.
- *Spam* (declare a near-random draft at probe 4, then play the round out normally): a garbage draft disagrees with the hidden law nearly everywhere, so the minimum-Hamming rule (canon §4.5) hands back a glyph the player has effectively already probed — near-zero information. Their eventual declaration succeeds at roughly their normal first-declaration rate. `0.03 × 1000 + 0.97 × 0.62 × 600` = **391** expected.

Spamming forfeits 46 % of expected score, and additionally: the fracture is permanent on the Codex page, and the Anomaly streak is forfeit. The counterexample is priced above the cost of simply probing, exactly as canon §4.5 requires.

**Run total** is the plain sum of round scores. No combo, no streak multiplier — a multiplier would reward speed and tax the careful band-8 round, inverting the game's values. A **run** ends on returning to the run frame's root or after 30 minutes in the background.

### 6.10 Persistence, interruption, abandonment

**End of round, persisted:** the `RoundRecord` (seed, band, δ, probe list, strikes, outcome, score, marks, elapsed) appended to the run log; the **Codex page** on `inscribed` only (AST, band, probesUsed, marks, fracture, date, seed — never the materialised pair table, canon §3.6); the θ update; the five Profile accumulators; the novelty ring buffer (last 50 solved extensions, canon G9). The mid-round snapshot slot is cleared last, after every other write succeeds.

> **Decision:** a *lost* law additionally enters an 8-entry **cooldown ring** and is not re-served for 8 rounds, on top of canon's 50-entry novelty guard over solved laws — because re-serving a law the player just failed reads as the machine taunting them, and canon's guard covers solved laws only.

**Mid-round snapshot** — written atomically after every committed verdict, after every strike resolution, and on `scenePhase → .inactive`. Bench draft is included on the `.inactive` write only; writing 2 KB on every ramp-cell tap is 40 writes a round for state the player can re-tap in two seconds.

```swift
struct ProbeSnapshot: Codable {          // schema v1
    let schema: Int
    let law: LawNode                      // THE RESOLVED LAW ITSELF, in RNF, ~40 B (canon §5.4)
    let lawHash: UInt64                   // extension hash — a corruption check, never the source of truth
    let seed: UInt64, band: Int, targetDelta: Double, mode: Mode   // round metadata: δ for the θ update,
                                          // band for par/cap, seed for the round card. NOT a law recipe.
    let seedGlyph: UInt8
    let probes: [UInt8]                   // glyph IDs only; verdicts are RECOMPUTED from `law`
    let strikes: Int
    let counterexample: CounterexampleRef?
    let benchDraft: BenchLayout?
    let startedAt: Date, elapsedActive: TimeInterval

    struct CounterexampleRef: Codable {   // a tuple cannot conform to Codable and cannot be
        let cur: UInt8                    // extended to; synthesis would simply fail to compile
        let prev: UInt8?                  // nil in stateless bands
    }
}
```

`BenchLayout` — the rail-by-rail description of a draft, the same type canon §4.4's `Bench.layout(for:)` returns and `parse(_:)` consumes — is declared `Codable` at its own definition, with a `UInt8`-backed raw value on every tile-class, comparator and coupler enum. `Mode` likewise carries a stable `UInt8` raw value rather than a `String`: a `String`-backed `Mode` is the exact case the localization catalogue silently fails to extract, and persistence must not be the reason a raw enum value ends up in a `Text`.

**The law is stored, not regenerated — canon §5.4, and the reason is not paranoia.** `avoid` is serving-layer state and it moves while a round is suspended: suspend a PROBE round, play a SIEVE run that inscribes a page, resume, and regeneration from the same `(seed, band, targetδ, mode)` can now legitimately resolve to a *different* law, destroying the round by its own consistency check. So the snapshot carries the `LawNode` and `lawHash` is only ever asked "is this the law I wrote down", never "which law was this".

Verdicts are still recomputed rather than stored: the payload is ≈ 160 bytes plus the draft, tampering with the probe list achieves nothing because the law re-derives every verdict, and every resume is a live evaluator check over the whole transcript. If `hash(extension(law)) != lawHash` — with the law stored, the only realistic cause is on-disk corruption, not a generator change — the round is **voided**, never silently altered: score 0, no page, no θ update, and the round card shows a broken-seal state.

**Relaunch.** A cold launch with a live snapshot opens **directly into the round**, mid-state, in `probing` with the Bench collapsed and the draft preserved for whenever the player pulls it up. The 900 ms re-entry beat: par ticks re-fill leading→trailing (and the crossing inversion is restored, not replayed, if the round was already past par), the ribbon scrolls from its leading edge to its trailing edge, a docked counterexample re-appears in its margin, the throat lights last. Input is locked for the beat's duration. No dialog and no "Resume?" button — the player already made that decision.

**Abandonment** is reached from the run frame, opened by tapping the mode sigil in the instrument bar.

- **Before probe 1:** the round is discarded outright. No record, no θ update, the seed returns to the pool. No evidence was produced.
- **After probe 1:** `Outcome.abandoned`, score 0, **no θ update** — an abandon is an interruption signal, not a failure signal, and scoring it as failure would let a player farm the adaptive engine downward by abandoning hard rounds. The anti-farm is that **the target δ is sticky across an abandon**: the next round is generated at the same target, from a different seed.

### 6.11 Edge cases

| # | Case | Defined behaviour |
|---|---|---|
| 1 | Declare at probe 0 | Legal if the Seal is unbarred. `probesUsed = max(1, 0) = 1` → no division by zero; correct scores 1000 / 3 marks. Not an exploit: 1-in-40 at band 1, 1-in-6,934 at band 5, and a miss costs a strike. |
| 2 | Twin pressed at probe 0 | Legal — it probes the seed glyph, establishing its verdict. The seed glyph itself never gains a verdict ring. |
| 3 | Same glyph probed twice, non-adjacently | Allowed, drawn normally, no doubled ring. **A twin is an *adjacent* re-probe only** — only adjacency holds the context fixed, which is the twin's entire purpose. |
| 4 | Cap reached on an admit | The verdict is delivered in full, then `exhausted`. A paid-for bit is never withheld. |
| 5 | Backgrounded during the 420 ms verdict beat | Verdict was committed at t = 0. On resume the animation is skipped and the tile is already in the ribbon. |
| 6 | Backgrounded during the 2,480 ms reveal | The page was written at **t = 0**, on the Seal press, along with the θ update and the novelty entry. Resume lands on the round card; the reveal is replayable from the Codex page. |
| 7 | Force-quit from the app switcher | The app was already `.background`, so the `.inactive` snapshot exists. Nothing is lost, draft included. |
| 8 | Crash or battery death mid-round | Last committed verdict survives (snapshot is post-verdict, so zero probes are lost). Bench draft since the last `.inactive` is lost. |
| 9 | Phone call mid-round | `.inactive` → snapshot. `AVAudioEngine` suspends and resumes with `.shouldResume`. Nothing is timed, so nothing needs pausing. |
| 10 | Double-tap on PROBE inside the lock | One queued tap honoured at t = 420 ms (320 ms under Reduce Motion) with a 180 ms compressed travel; further taps dropped. |
| 11 | Double-tap on the Seal | Seal is edge-triggered with no queue; the second tap is discarded. |
| 12 | Barred Seal pressed | The offending rail pulses once. No text, no modal, no error state. |
| 13 | Draft's extension is constant | Seal stays barred (canon §4.3). Inert and vacuous ramps share one 30 %-plus-slash drawing. |
| 14 | Correct declaration that is spelled differently from the hidden law | Correct. Comparison is extension-identity in the common space with lifting (canon §4.5). |
| 15 | Stateless declaration against a contextual law | Judged by lifting the stateless table to pair space. Wrong unless genuinely equivalent. |
| 16 | Silent switch on | No audio. Geometry + haptics carry the verdict. |
| 17 | System haptics off | Geometry + audio. |
| 18 | Both off | Geometry alone — which is why the aperture is a shape change, not a colour change. |
| 19 | Reduce Motion | Every beat sheet becomes crossfades; audio and haptic beat positions unchanged; the breath becomes a static opacity lift. |
| 20 | Dynamic Type ≥ AX2 | Bench becomes a single-rail pager (canon §2); the Assay leaves the trailing column and becomes a 44 pt chip in the instrument bar that expands full-screen on tap. |
| 21 | Low Power Mode | Durations unchanged. The grain/bloom `colorEffect` shader disables after 2 s below 30 fps and re-enables on the next round boundary. |
| 22 | Storage full — atomic write fails | The round continues in memory. A hairline warning strip appears in the **chrome**, never in the play surface. Completed-round writes are queued and retried at the next round boundary and on `.background`. |
| 23 | Stored law fails its `lawHash` integrity check on resume | `Outcome.voided`, reached from `arming` and from nowhere else (§6.1). Score 0, no page, no θ update, broken-seal round card. |
| 24 | Device rotated | Portrait locked; no layout exists for landscape. |
| 25 | UTC date rolls over mid-round | PROBE is unaffected — only the Anomaly is date-derived, and its seed is bound at round start. |
| 26 | VoiceOver on during a reveal | Tap-to-skip is disabled (it collides with tap-to-focus); three announcements at **640 / 1,450 / 1,850 ms**, on the verdict, the registration and the page; magic tap skips. |
| 27 | Player exits to the run frame and returns without abandoning | Round resumes in `probing` with the draft, ribbon and probe count intact. Costs nothing. |
| 28 | Backgrounded with the Bench up, then cold-launched | The `.inactive` write captured the draft. Resume enters `probing` with the Bench collapsed and the draft intact — restoring *into* `declaring` would put a player back on a commit surface they did not just choose to be on. |
| 29 | Snapshot's probe count already equals `cap` | Unreachable by construction: the cap-th verdict transitions straight to `revealing(.exhausted)` and the snapshot slot is cleared at round end. A snapshot at `cap` therefore fails validation and is treated as corruption → `Outcome.voided`. |
## 7. DRIFT

### 7.1 What DRIFT asks, and why it is not PROBE repainted

PROBE has a property its player never notices: **evidence never expires.** Every verdict in the ribbon is true forever, so the optimal strategy is monotone accumulation — narrow, never widen. DRIFT removes exactly that property and nothing else. Partway through, the Loom's law is replaced; from that instant part of the ribbon is testimony about a law that no longer exists, and the player's best-supported theory is the *most* misleading object on screen — it explains almost everything and predicts the wrong thing. The task is **change detection followed by re-induction against a strong wrong prior**, which is not induction against no prior. The behaviour it produces — probes spent gathering confirmations equally consistent with the dead law and the live one — has no analogue in PROBE, because in PROBE such probes do not exist.

> **Decision:** DRIFT adds **no controls, no chrome, no timer** to PROBE's surface. Reason: if any interface element changed at the hinge, the interface would be announcing the change, and the mode would measure reading rather than noticing.

Feeds **Flexibility** (primary), **Induction**, **Restraint**.

### 7.2 The two laws

A DRIFT round holds `L₁` and `L₂`, both of band `b` and `Family(b)`, generated by canon §5.3 from `seed ^ Mode.drift.salt`.

> **Decision:** `L₂` is a **one-leaf edit of `L₁`** — same family, same skeleton, differing in exactly one leaf parameter (one subset bitmask, one comparator, one bound attribute, one gate value, one count-set, or one parity bit). Reason: a randomly re-rolled second law is indistinguishable from "the round silently restarted", and clinging only exists as a failure when the dead theory still explains most of what the player sees. A one-leaf edit also makes the reveal a single moving part (§7.9), which is what makes it land.

Pair guardrails, applied after both laws individually clear canon's G1–G10:

| # | Guardrail | Test |
|---|---|---|
| D1 | distinct | `T₁ != T₂` in the common space (lifted where needed) |
| D2 | detectable, not a restart | disagreement rate `\|D\|/N ∈ [0.10, 0.30]`, `D = T₁ △ T₂`, `N` = 256 or 65,536 |
| D3 | both legal | `L₂` passes G1–G10 including the admit window `p ∈ [0.15, 0.60]` |
| D4 | the edit bites | `\|{g : L₁(g)=admit, L₂(g)=reject}\| ≥ 8` — the drift must be able to break a positive, not only a negative |
| D5 | novel | neither extension among the last 50 solved laws, nor today's Anomaly |
| D6 | hinge lands mid-theory | `N_admits / (p(L₁) · par(b)) ∈ [0.25, 0.80]` |
| D7 | cheaply exposable | at least one single-attribute edit of the **seed glyph** lies in `D`, so one flick can expose the change |

Resampling bounded at 200 attempts (canon §5.3), then the family's deterministic anchor pair. **DRIFT serves bands 3–8 only**, and D6 is why: with the hinge fixed at 3–6 admissions (canon §3.5), bands 1 and 2 cannot fire it inside `0.80 · par` for any admit rate in the legal window — at band 1, `par = 7` and three admits need ≈ 12 probes, past the cap. A mode whose central event fires after the round should have ended is not a mode.

### 7.3 The hinge — exactly when the law changes

`N_admits ~ U[3, 6]`, drawn deterministically from the round seed (canon §3.5). The **hinge** is the moment `L₂` takes force. It fires at the earliest of:

| Trigger | Condition | Notes |
|---|---|---|
| **(a) satiation** | the probe delivering the `N_admits`-th admit under `L₁` | that probe's verdict is `L₁`'s; probe `t+1` onward is `L₂`'s |
| **(b) capture** | the player's first declaration whose extension equals `L₁`'s | the declaration is **accepted**, then the floor moves |
| **(c) forced** | probe index `ceil(0.80 · par(b))` reached with fewer than `N_admits` admits | an unlucky run still gets the mode |

> **Decision:** trigger (b) exists, and a pre-hinge correct declaration does **not** end the round. Reason: without it, a fast player solves `L₁` before the hinge and never experiences DRIFT — the mode's presence would be a function of how good you are at PROBE. Under (b) the player gets the full correct-declaration ring and the inscribe haptic, the Bench slides away, and the round continues. Being told *"yes, that was the law"* and then finding that it is not, is the mode stated in one gesture.

Trigger (b) writes a **seam marker** into the ribbon at that index — a vertical hairline carrying a 20 pt silhouette of the accepted tile layout. It is the only visible trace of a hinge before the reveal, and it appears only for (b), where the player already knows something happened.

**The hinge never resets context.** In bands 5 and 7 the next probe is evaluated by `L₂` against the pre-hinge `prev`. The chain is unbroken; only the predicate changed.

### 7.4 Round lifecycle

```swift
enum DriftPhase { case arming, priming, runningPre, runningPost,
                       declaring, adjudicating, struck, hinge, settled }
```

| From | Event | To | Side effects |
|---|---|---|---|
| `arming` | round generated | `priming` | seed glyph drawn into the throat |
| `priming` | first Dial commit | `runningPre` | — |
| `runningPre` | trigger (a) or (c) | `runningPost` | `t_hinge` recorded; **no visible change** |
| `runningPre` | Seal, ext == `L₁` | `runningPost` | trigger (b): accept ring, inscribe haptic, seam marker |
| `runningPre` | Seal, ext != `L₁` | `struck` | ordinary counterexample (canon §4.5) |
| `runningPost` | Seal, ext == `L₂` | `hinge` | **win**; adjudication commits before any animation |
| `runningPost` | Seal, ext == `L₁` | `struck` | **dead-law strike**, special counterexample (§7.6) |
| `runningPost` | Seal, anything else | `struck` | ordinary counterexample |
| `struck` | strikes == 2 | `hinge` | **loss**; both laws revealed |
| either running | probes == `cap_DRIFT(b)` | `hinge` | **loss**; both laws revealed |
| `hinge` | complete or skipped | `settled` | Codex page written (or not, on a loss) |

### 7.5 Play surface, win, loss, strikes

The surface is PROBE's, region for region (canon §4.1): instrument bar 20–64, throat 64–176, ribbon 176–228, Dial 236–508, Bench handle 516–560, commit bar 604–667. The only differences are the **mode sigil** — which identifies DRIFT, never the hinge — and the seam marker. The par tick row counts against `par_DRIFT`, so a veteran can read the mode off the tick count; that is fine and intended.

- **Win:** a declaration whose extension equals `L₂`'s, at any point after the hinge.
- **Loss:** second strike, or reaching `cap_DRIFT(b)`.
- **Strikes:** two, as canon §4.5 — the first continues the round, the second ends it.

### 7.6 The dead-law counterexample

When a post-hinge declaration's extension equals `L₁`'s, a step 0 is inserted before canon §4.5's selection:

> Prefer a glyph (or ordered pair) already in the ribbon whose verdict under `L₁` differs from its verdict under `L₂`. Tie-break by most recent ribbon index, then lowest `glyphID`.

It renders as the **twin ring**: the ribbon tile and the centred counterexample carry the identical glyph, one ringed admit, one ringed reject. The player has already seen this exact visual in PROBE when a twin exposed a contextual law, so the meaning *"the same thing gave two answers"* is already learned. If `D` contains no ribbon member, fall through to canon's ordinary rule. If both strikes are spent before the hinge fires, the loss reveal still plays the full hinge with the un-fired `L₂` at 40 % opacity, so a fast loss still teaches the mode's shape.

### 7.7 Budget and scoring

The second induction costs less than the first: the family is known (`d = 0`) and the search collapses to the one-leaf edit-neighbourhood of `L₁`. Recovery allowance `rec(b) = ceil(k(b) · log₂|Nbhd|)` over real neighbourhood sizes, locked:

| band | `par` | `rec` | **`par_DRIFT`** | **`cap_DRIFT`** = ceil(1.6·par_DRIFT) | forced hinge at |
|---|---|---|---|---|---|
| 3 EXCLUSIVE | 16 | 9 | **25** | **40** | 13 |
| 4 RELATIONAL | 20 | 9 | **29** | **47** | 16 |
| 5 CONTEXTUAL | 23 | 9 | **32** | **52** | 19 |
| 6 GUARDED | 23 | 9 | **32** | **52** | 19 |
| 7 COMPOSITE | 26 | 11 | **37** | **60** | 21 |
| 8 SYSTEMIC | 29 | 11 | **40** | **64** | 24 |

Canon's formula is unchanged; only `par` is substituted:

```
score_DRIFT = round( 1000 · min(1, par_DRIFT(b) / probesUsed) · (anyStrike ? 0.6 : 1.0) )
```

Seal marks carry the flexibility signal instead of adding a second score term. **3 marks:** `probesUsed ≤ 0.6·par_DRIFT` **and** `R ≤ rec(b)`. **2:** `probesUsed ≤ par_DRIFT`. **1:** `probesUsed ≤ cap_DRIFT`. A strike still fractures the Codex page and forfeits the Anomaly streak.

**Worked round — band 5, CONTEXTUAL.**
`L₁ = RANK pips(cur) > PREV RANK pips AND shape ∈ {circle, triangle, hexagon}` — `p = 0.281`, δ = **0.544**.
`L₂ = ` the same with `shape ∈ {circle, triangle, square}` — one leaf edited (hexagon out, square in), `p = 0.281`, δ = **0.538**. `|D|/65536 = 0.1875` ✓ D2. `N_admits = 4`; D6 = `4/(0.281·23) = 0.62` ✓. `par_DRIFT = 32`, `cap_DRIFT = 52`. Seed glyph: hollow triangle, two pips, teal.

| # | probe | `prev` pips | verdict | in force | player's read |
|---|---|---|---|---|---|
| 1 | hexagon, 3 pips | 2 | **admit** | L₁ | positive #1 |
| 3 | hexagon, 4 pips | 4 | reject | L₁ | `>` is strict |
| 5 | triangle, 3 pips | 2 | **admit** | L₁ | positive #2 |
| 7 | hexagon, 4 pips | 3 | **admit** | L₁ | positive #3 — hexagon is in |
| 9 | square, 2 pips | 1 | reject | L₁ | square is out |
| 10 | hexagon, 3 pips | 2 | **admit** | L₁ | positive #4 → **hinge fires (a)** |
| 11 | hexagon, 4 pips | 3 | **reject** | L₂ | identical form to #7. `t_evidence = 11` |
| 12 | *twin of #11* | 4 | reject | L₂ | consistent — but this pair is **not** in `D` |
| 13 | hexagon, 2 pips | 1 | reject | L₂ | in `D` → `t_recover = 13`, cling `C = 2` |
| 18 | *declares `L₁`* | — | — | — | **strike 1**; twin-ring counterexample on probe 7's pair |
| 19–26 | shape sweep holding pip delta at +1 | | | L₂ | square admits, hexagon rejects |
| 27 | *declares `L₂`* | — | — | — | **correct**. `t_seal = 27` |

`probesUsed = 27`; `min(1, 32/27) = 1`; one strike → `score = round(1000 · 1 · 0.6) = **600**`. Marks: 3 needs `≤ 19` probes and `R ≤ 9` — no; 2 needs `≤ 32` — yes → **2 marks, fractured**. `R = 27 − 11 = 16` against `rec(5) = 9`. DRIFT hands the Profile the pair `(R, rec(b))` and the flag `deadDeclaration`; the mapping onto the Flexibility axis and the update rule are **§11.9's, not this section's** (§7.8). Under §11.9's latency form with `L* = rec(b)` this round yields **0.148**.

### 7.8 What is measured, and why no number is ever shown

Derived from the transcript at `settled`. None is rendered, spoken, or stored as a displayable value.

| Symbol | Definition |
|---|---|
| `t_hinge` | probe index at which `L₂` took force |
| `t_evidence` | first probe `> t_hinge` whose verdict is inconsistent with `L₁` — the first moment the change is *observable*. Often well after `t_hinge`, since most glyphs agree under both laws |
| `t_recover` | first probe `> t_evidence` lying inside `D` |
| **`C = t_recover − t_evidence`** | **cling** — probes spent inside the agreement set after the first contradiction. Their verdicts are equally consistent with the dead law and the live one: pure confirmation, zero bits |
| **`R = t_seal − t_evidence`** | **re-declaration latency** — canon's Flexibility quantity |
| `deadDeclaration` | whether any post-hinge declaration's extension equalled `L₁`'s |

**This section defines the quantities; it does not define the axis.** DRIFT emits `(R, rec(b), deadDeclaration)` at `settled`. The sample formula that turns them into a Flexibility increment, and the step size that applies it, are **§11.9's single normative table** — there is no second definition here, no EWMA constant here, and no per-mode α. `C` and `wasteRate` are retained for the simulated-player harness only and feed no axis.

> **Decision:** none of these is surfaced as a number, percentage, rank, streak, or comparison against other players. The only outward expression is the Profile's Flexibility vertex — a distance on a morphing shape with no axis labels and no scale. Reason: a number attached to *how long you were wrong* is the one piece of feedback in this game that would read as a verdict on the player rather than on the declaration.

### 7.9 The reveal — the hinge

Adjudication commits to disk **before** the animation starts, so the reveal is decoration over settled state and can be skipped, interrupted, or replayed from the Codex without changing anything.

1. **The seam**, 500 ms — a hairline sweeps the ribbon leading→trailing and stops at `t_hinge`, docking to the trigger-(b) seam marker if one exists.
2. **The split** — every ribbon tile is re-evaluated under both laws. Tiles `L₁` explains rise 18 pt; tiles `L₂` explains fall 18 pt; tiles both explain hold. The ribbon becomes two lanes forking at the seam: a picture of *your evidence was about two different machines*.
3. **The dead stretch** — tiles probed after `t_evidence` that lie in the agreement set drop to 25 % and take the diagonal cancel hatch already used for unlit Bench cells. No count, no label; the player simply sees how long the useless run was.
4. **The morph**, 900 ms eased — `L₁` assembles in rule-tiles above the seam over 700 ms, staggered; `L₂` assembles below, except the shared leaves do not redraw, they *slide down*. Only the edited leaf animates: one ramp cell extinguishing while another ignites, one wedge rotating 30°, or one gate cell moving.
5. **The hold** — two laws, one moving part, three seconds of silence, then the Codex page.

Reduce Motion replaces steps 1–4 with four crossfades of the same total duration; the two-lane geometry and the single changed leaf remain, because they are information, not motion. Audio: the seam is a filtered noise sweep; the morph plays the admit interval detuned a semitone and then resolved — the only place in the game where dissonance resolves rather than closes.

### 7.10 Failure and interruption

Mid-round state persists after every probe (canon §5.4). The DRIFT record adds `L₁`, `L₂`, `N_admits`, `hingeFired`, `t_hinge`, `t_evidence`, `t_recover`, `seamMarkerIndex`, `strikes`. Nothing is re-randomised on resume; the hinge neither re-fires nor un-fires. **Backgrounding:** state is already on disk, resume enters the same phase at the same probe index. **Termination during `hinge`:** already adjudicated, so resume lands in `settled` with the Codex page present and the reveal replays from the page. **Mode switch:** the round suspends; one suspended round per mode, and starting a second DRIFT round discards the older one after a confirmation — the only modal in the game, and it lives outside the play surface. DRIFT reads no clock, so date manipulation affects the Anomaly and nothing here.

### 7.11 Edge cases

| Name | Situation | Defined behaviour |
|---|---|---|
| **EARLY-SEAL** | declaration matches `L₁` pre-hinge | trigger (b): accepted, accept ring + inscribe haptic, seam marker written, **no strike, no score change**, round continues under `L₂` |
| **STARVED-HINGE** | fewer than `N_admits` admits by probe `ceil(0.80·par(b))` | trigger (c): hinge fires on that probe's boundary regardless of admit count |
| **DEAD-HINGE** | player never probes inside `D` and declares `L₁` | strike, and the counterexample is guaranteed to come from `D` (§7.6) — the mode delivers its lesson at least once per round |
| **CONTEXT-CARRY** | contextual band, hinge fires between probes | `prev` untouched; probe `t_hinge+1` is evaluated by `L₂` against the pre-hinge `prev`; the ribbon chain stays continuous |
| **BLIND-EDIT** | the edited leaf is unreachable from anything probed | prevented at generation by D7: one single-attribute edit of the seed glyph lies in `D`, so a throat flick exposes it |
| **DOUBLE-STRIKE-PRE-HINGE** | two wrong declarations before the hinge | loss; reveal plays in full with `L₂` at 40 % opacity and the un-fired seam dashed |
| **TWIN-OF-THE-HINGE** | the probe that fires trigger (a) is immediately twinned | legal and highly informative — the twin is evaluated under `L₂`. In contextual bands this is the cheapest hinge detector, and the mode rewards it |

---

## 8. ECHO

### 8.1 What ECHO asks, and why it earns its place

PROBE, DRIFT and SIEVE all ask the player to *find* a law. ECHO is the only mode that asks them to **use** one — hold a predicate steady and apply it, repeatedly and correctly, to material they did not choose, with no verdict feedback while they work. That is not decorative: the characteristic failure in rule-induction is declaring a law you cannot actually apply, because the Seal accepts an extension match and a player can reach the right table by elimination without ever internalising the rule as a procedure. ECHO is the only place that gap becomes visible, because it switches off the Loom's lamp. There is no admit ring during a cast. The player is the evaluator.

Feeds **Retention** (primary), **Induction**.

### 8.2 Which law is in force

> **Decision:** ECHO never generates a law. It selects from the **echo pool** — the last **8** laws inscribed in the Codex, in any mode — and identifies which one via a primer. Reason: the brief's "the law you learned last round" is right in spirit but gives the adaptive engine no control and is brittle (one hard round and the pool is a law the player barely holds). Eight is chosen because it is exactly three bits, and three bits is exactly what a three-glyph primer carries.

ECHO therefore bypasses canon's G9 novelty guard by construction: it selects, it does not generate.

**The pool is rendered, not remembered.** Above the primer sits the **pool strip**: the whole echo pool, one **40 pt extension thumbnail** per member — the Codex page's own unconditional marginal projection of the Assay (canon §4.3), the picture the player has already seen on every page they own — in Codex order, oldest leading. It is read-only, textless, carries no numeral and is not a hit target.

> **Decision:** the primer *eliminates* on screen. As each primer glyph resolves its verdict ring, every pool member inconsistent with the verdict vector so far **extinguishes** — dropping to 25 % with the diagonal cancel hatch already used for an unlit Bench cell (canon §4.2). When the primer ends exactly one thumbnail is still lit, and it stays lit for the whole round. Reason: three to five ringed glyphs cannot pin a law out of 27,015; they can only separate members of a candidate set, and if that set is not on screen the deduction is unaided recall of up to eight laws spanning eight rounds, any mode, any band. That is a memory task, and §8.8 exists to say this mode is not one. Rendering the pool preserves the 3-bit deduction exactly — the player who reads ahead predicts which thumbnail survives — and destroys the recall requirement. It also makes Retention measure application of the rule rather than recall of the pool.

**The primer.** Each round opens with a seed glyph followed by `m` glyphs presented **with their true verdict rings**, chosen so the verdict vector is **unique across the pool** — it identifies which member is in force, and no other member could have produced it. `m` is the smallest value in `{3, 4, 5}` for which a separating chain exists (200 seeded attempts per `m`); for contextual members the chain's adjacent pairs supply `prev`, with the seed glyph priming position 0 (canon §3.5). No separating chain at `m = 5` → drop the two oldest pool members and retry; pool below **3** → ECHO unavailable this session. The primer and the pool strip both stay on screen for the whole round (§8.4). Neither is a memory item.

Uniqueness of the verdict vector is what guarantees the strip resolves: `m = 3` separates at most 8 members, `m = 4` at most 16, `m = 5` at most 32, and the pool is 8 — so a separating chain, when one exists, always extinguishes exactly seven thumbnails.

| Situation | Behaviour |
|---|---|
| Codex under the §9.10 unlock threshold (**5 pages**) | ECHO is locked — absent from the mode rack (§12.4), not greyed with an explanation |
| a round was just lost | pool unchanged; a loss inscribes nothing, so ECHO still holds the last **successful** laws |
| player switches modes | pool does not move. It is a function of the Codex, not of the session |
| a DRIFT round was won | **`L₂` only** enters the pool. `L₁` is on the page but is not the law the player finished holding |
| a SIEVE run sieved at `ratio ≥ 0.92` | its law enters the pool (§9.6). It was never declared on the Bench, but it **was** stated: a sieved run's reveal renders the law in rule-tiles (§9.5), and sieving at 0.92 is a demonstration of applying the law as a filter — which is precisely ECHO's task, and a stronger warrant than a declaration, which only proves the extension was *found* |

### 8.3 The cast and the recall

The Loom emits a **cast** of `L` glyphs into the throat, one at a time, at fixed cadence, with no verdicts. **The ribbon stays dark** — a cast is not probing and the Loom does not log it. That is diegetic, and it is the entire reason the mode has an ordering component.

- Each glyph: 120 ms draw-in, `cadence − 240 ms` hold, 120 ms withdraw, with a link arc to its predecessor so the chain reads as a chain (contextual members need it). Reduce Motion: hard crossfades at the identical cadence — the cadence is the game, the animation is not.
- **Cast glyphs are pairwise distinct**, so the tray is a set and no duplicate-identity ambiguity can arise. Exactly `A` of the `L` are lawful, by construction; `A` is **never displayed**, anywhere, at any point.
- **One replay.** The **twin key** — already meaning *do that again* in PROBE — replays the cast exactly once per round at a score cost of ×0.6. It stays live during recall and never clears the rail.

When the last glyph withdraws, the throat clears and two surfaces appear. **The tray** holds all `L` cast glyphs re-presented as tiles in canonical `glyphID` order (canon §2) — the Assay's order, therefore already spatially familiar; not cast order, not shuffled, a deterministic neutral index. **The rail** holds the player's answer, initially empty. The player taps tray tiles that were **lawful**, in the order they appeared in the cast; a tap lifts the tile to the trailing end of the rail, tapping a rail tile returns it. The Seal commits. Every cast glyph is re-shown, so **nothing must be recalled as an image**; what must be produced is *which* and *in what order*.

### 8.4 Play surface — recall phase, iPhone SE reference

| Region | y | Detail |
|---|---|---|
| instrument bar | 20–64 | cast ticks (one per position, all filled), mode sigil. No numerals |
| **the pool strip** | 68–108 | up to 8 extension thumbnails at **40 × 40 pt**, 6 pt gutters (8·40 + 7·6 = 362 in 375), Codex order, oldest leading. Read-only, not a hit target. Eliminated members at 25 % + cancel hatch; exactly one lit after the primer |
| **primer strip** | 116–164 | `m` glyphs at 44 pt with verdict rings, read-only, leading-aligned; seed glyph at 36 pt in a dashed frame |
| **the rail** | 172–252 | 44 pt tiles + link arcs, horizontal scroll, leading→trailing in every locale |
| **the tray** | 260–572 | 4-column grid of **84 × 72 pt** cells (4·84 + 3·8 = 360 in 375), rows filled leading→trailing, glyph at 52 pt. `L ≤ 14`, so at most 4 rows (4·72 + 3·8 = 312) and at maximum load the final row is short by two |
| negative space | 572–604 | deliberate; the mode is quiet |
| commit bar | 604–667 | **twin/replay** (leading, 44 pt) · **Seal** (trailing, 44 pt) |

During primer and cast the layout is PROBE's: 96 pt live glyph in the throat at 64–176, ribbon dark, Dial absent — with the pool strip pinned at 68–108 throughout, since its whole purpose is to be readable at the moment the primer resolves. Every *target* is ≥ 44 × 44 pt; the smallest is the tray cell at 84 × 72. The pool strip and the primer strip are read-only and therefore exempt from the hit-target floor, exactly as the ribbon's link arcs are; both are exposed to VoiceOver as static grouped elements with the canonical `fill → shape → pips → hue` labelling and a lit/extinguished state. At AX2 and above the tray becomes a two-column pager and the pool strip wraps to two rows of four, matching the Bench's rule (canon §2).

### 8.5 Round lifecycle

```swift
enum EchoPhase { case arming, priming, primer, casting, recalling,
                      adjudicating, reveal, settled }
```

| From | Event | To | Notes |
|---|---|---|---|
| `arming` | pool resolved, law selected, cast built | `priming` | pool strip drawn, all members lit; seed glyph in the throat, 1.2 s |
| `priming` | — | `primer` | `m` glyphs at 900 ms each, verdict rings; each ring extinguishes every strip member it eliminates, on the same frame as the ring resolves |
| `primer` | — | `casting` | 600 ms gap, ribbon goes dark. **Invariant, asserted:** exactly one strip member is lit at this transition |
| `casting` | `L`-th glyph withdrawn | `recalling` | tray + rail appear |
| `recalling` | twin key, first use | `casting` | replay; rail preserved; `replayed = true` |
| `recalling` | Seal | `adjudicating` | commits to disk before animating |
| `adjudicating` | — | `reveal` | §8.7 |
| `reveal` | complete or skipped | `settled` | Codex burnish at 3 marks |

**There is no strike mechanic in ECHO.** A commit is final. The Bench's strike exists so a counterexample can be acted on; ECHO's answer is a transcript, not a hypothesis, and a second attempt at the same transcript is a memory retry, not a reasoning retry.

### 8.6 Load and difficulty

Because the law is the player's own, ECHO's difficulty knob is the **load index** `ℓ ∈ 1…8`, not the law.

| `ℓ` | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| `L` (cast length) | 6 | 8 | 9 | 10 | 11 | 12 | 13 | 14 |
| `A` (lawful) | 2 | 3 | 3 | 4 | 4 | 5 | 5 | 6 |
| cadence (ms) | 1400 | 1300 | 1200 | 1100 | 1000 | 950 | 900 | 850 |
| cast duration (s) | 8.4 | 10.4 | 10.8 | 11.0 | 11.0 | 11.4 | 11.7 | 11.9 |

```
δ_ECHO     = clamp01( 0.60 · difficulty(law) + 0.40 · (ℓ − 1) / 7 )
band_ECHO  = floor(δ_ECHO / 0.125) + 1        // for the canon band table and the Rasch update
```

**Serving.** §10.3 hands ECHO a `targetδ` in **difficulty units** `[0.000, 1.000)` — never a logit. `selectFromPool(targetδ)` then:

```
law = pool member minimising |difficulty(law) − targetδ|      // tie-break: most recently inscribed
ℓ   = clamp( 1 + round( 7 · (targetδ − 0.60 · difficulty(law)) / 0.40 ), 1, 8 )
```

`ℓ` is the *only* thing ECHO adapts; the law is chosen, never generated, so canon's G9 novelty guard and the 200-attempt bound do not apply. `δ_ECHO` spans `[0.014, 0.999]` over a full pool, so ECHO's served band range is 1…8. Round length: primer + cast + untimed recall ≈ 45–75 s.

Cast construction (deterministic from `seed ^ Mode.echo.salt`): sample `A` lawful and `L − A` unlawful glyphs, all distinct, then order them subject to (i) for contextual laws the realised sequence must actually produce the intended verdicts, checked by evaluation rather than assumed, and (ii) no more than three consecutive positions share a verdict, so the answer is never a contiguous block.

### 8.7 Scoring

```
truth   = ordered list of lawful cast indices, |truth| = A
answer  = ordered list of cast indices on the rail
hit     = |answer ∩ truth|
prec    = hit / max(1, |answer|)          rec = hit / A
setF1   = 2·prec·rec / (prec + rec)                       // 0 if hit == 0
order   = LIS(answer ∩ truth, by cast index) / max(1, hit)
replayF = replayed ? 0.6 : 1.0

score_ECHO = round( 1000 · setF1² · (0.70 + 0.30 · order) · replayF )
```

**Success**, for the Rasch update, iff `setF1 == 1.0` — the right set, regardless of order. Order is never a pass/fail condition; it is a bounded 30 % of score. Marks: **3** if `setF1 == 1`, `order == 1`, not replayed; **2** if `setF1 == 1`; **1** if `setF1 ≥ 0.70`.

ECHO emits `(hit, falseIncludes = |answer \ truth|, A, order, replayed)` to the Profile at `settled`. The sample formula that turns them into a Retention increment, and the step size that applies it, are **§11.9's single normative table** — not defined here, and there is no per-mode EWMA constant in this section.

**Worked round.** `ℓ = 5` → `L = 11`, `A = 4`, cadence 1000 ms. Pool law `RANK shape == RANK pips` (band 4, δ = 0.432). `δ_ECHO = 0.60·0.432 + 0.40·(4/7) = 0.259 + 0.229 = **0.488**` → band 4. Primer separated the pool at `m = 3`; seven of the eight thumbnails were dark before the cast began.

Lawful positions `truth = [2, 5, 6, 10]`. The rail, in placement order, `answer = [2, 6, 5, 9]`.

- `hit = |{2,5,6}| = 3`; `prec = rec = 0.75`; `setF1 = 0.75`
- intersection in answer order `[2, 6, 5]`; longest increasing subsequence by cast index `[2, 6]`, length 2 → `order = 0.667`
- no replay → `score = round(1000 · 0.5625 · 0.900) = **506**`
- `setF1 ≠ 1` → **not a success** for the ability update; `setF1 ≥ 0.70` → **1 mark**
- to the Profile: `hit = 3`, `falseIncludes = |{9}| = 1`, `A = 4`, `order = 0.667`. Under §11.9's Retention form that is `(3 − 1)/4 = **0.50**`

**Reveal.** The cast replays at 400 ms per glyph with each true verdict ring resolving as it lands, the player's rail beneath with its own rings. Correct placements pulse once; intrusions take the two-ring conflict of canon §4.5; misses draw as an empty slot opening in the rail at the right index. The law then renders in rule-tiles — it is the player's own law, so there is nothing to protect.

### 8.8 Why this is not a memory task

Stated explicitly, because the mode fails if this drifts. (1) **Every cast glyph is re-presented in the tray** — no glyph is reconstructed from recall. (2) **The pool strip and the primer are both on screen for the entire round**, and the strip ends the primer with exactly one member lit, so which law is in force is *pointed at*, not remembered — the deduction is still the player's, but its candidate set is drawn rather than held. Without the strip this clause would be false, and the mode would be measuring recall of the last eight Codex pages. (3) **The dominant term is `setF1²`**, and for stateless pool laws (bands 1–4) the correct set is fully recomputable from the tray and the primer with zero memory involvement. (4) **Order contributes at most 30 %** and is never a success condition. (5) At contextual pool laws (bands 5, 7) the tray cannot be evaluated tile-by-tile, so adjacency must be reconstructed — but the reconstruction is *implied by the law* ("find the ascending runs"), and the dependency is depth 1, the same ceiling the grammar itself enforces (canon §3.5). (6) `A ≤ 6` and `L ≤ 14`, both capped so that length alone is never the obstacle.

If players succeed on set and fail on order, the mode is working. The reverse means `ℓ` is too high and the cadence, not the filter, is binding.

### 8.9 Failure and interruption

> **Decision:** backgrounding during `casting` **voids the cast and restarts it from position 1 on resume, at no cost, once.** A second interruption in the same round **abandons** it: no score, no Codex effect, and **no ability update in either direction**. Reason: a partially-seen cast is unanswerable, and both scoring it and failing it would inject noise into the Retention estimate. Abandonment is the only outcome that is neither punishment nor exploit — and since the replay is already free once, an interruption cannot buy a second viewing.

Persisted per round: pool snapshot, law id, primer chain, cast, `ℓ`, phase, rail contents, `replayed`, `interruptions`. The pool strip's lit/extinguished state is a pure function of `(pool snapshot, primer chain, primer position)` and is recomputed on resume, never stored. During `recalling` the round resumes exactly, since recall is untimed.

### 8.10 Edge cases

| Name | Situation | Defined behaviour |
|---|---|---|
| **BLIND-PRIMER** | no chain of `m ≤ 5` separates the pool | drop the two oldest members, retry from `m = 3`. The unlock threshold is 5 pages (§9.10) against a functional floor of 3, so at least one drop cycle always exists. If a 3-member pool still cannot be separated, ECHO is **unavailable**: its key is *absent* from the mode rack (§12.4), exactly as when locked, and the engine's rotation skips it. It is never a lit key that silently serves PROBE — availability is re-evaluated whenever the rack is drawn, and the Codex only changes between rounds |
| **STALE-POOL** | every pool law sits far below the engine's target δ | serve the highest-δ member and raise `ℓ` to 8. If `δ_ECHO` is still more than 0.125 under target, skip ECHO in the rotation. **Never generate an unseen law for ECHO** — the mode's premise is that you already own the law |
| **EMPTY-RAIL** | Seal pressed with an empty rail | legal. `hit = 0` → `setF1 = 0` → score 0, 0 marks, counted as a failure. No confirmation prompt: an empty answer is a real answer |
| **RAIL-OVERFILL** | player places all `L` tiles | legal; no cap below `L`. `setF1 = 2A/(L+A)` — 0.53 at `ℓ = 5`, below the 1-mark threshold. Flooding is dominated |
| **DUPLICATE-SUPPRESSION** | the sampler would draw a glyph twice | forbidden at construction. The "same glyph, two verdicts" lesson belongs to PROBE's twin, not here |
| **REPLAY-MID-PLACEMENT** | twin key with tiles already on the rail | replay runs, rail preserved, `replayF` drops to 0.6. Only one replay exists, so it cannot be pressed twice |
| **POOL-CHURN-MID-ROUND** | a Codex write lands while an ECHO round is suspended | impossible to affect it: the pool is snapshotted at `arming` and persisted with the round |

---

## 9. SIEVE

### 9.1 What SIEVE asks, and the crux

> **Decision:** the law in SIEVE is **learned live from the stream** — not carried in from the Codex, not stated in advance. Reason: a known law makes SIEVE into ECHO with a clock, which is exactly the PROBE-repainted mode that ought to be cut. Learned live, SIEVE is **induction without experiment design**: the machine chooses the glyphs, and the player cannot construct a controlled variation, cannot twin, cannot go back. Passive observation and active experimentation are genuinely different epistemic situations, and PROBE only covers one of them.

For that to be possible rather than cruel, feedback is per-glyph and unconditional:

> **Every glyph resolves its true verdict as it leaves the gate, whether the player acted on it or not.** The stream is a forced-march probe sequence delivering one bit per glyph at 1.0–2.9 bits per second. The player pays for early ignorance in errors and converts late knowledge into hits.

It is also, deliberately, the only mode with real time pressure and the only one that ends in under a minute — a 42-second run between two six-minute PROBE rounds is a different kind of object in a session. Feeds **Tempo** (primary), **Induction**, **Restraint**.

### 9.2 Geometry — the gate, not the glyph

Glyphs travel top to bottom on a fixed vertical conveyor. **The tap target is not the moving glyph.**

| Region | y | Detail |
|---|---|---|
| instrument bar | 20–64 | three foul ticks, stream progress arc, mode sigil. No numerals |
| the lip | 64–96 | spawn; 32 pt of fade-in |
| the lane | 96–420 | 324 pt of travel; glyph drawn at 72 pt |
| **the gate** | **420–508** | **88 pt tall, full 375 pt width — the entire actionable target.** Two brass hairlines with edge ticks |
| the sump | 508–556 | exit; the ring resolves here, then the glyph dissolves over 300 ms |
| **the tail** | 560–604 | the last 6 resolved glyphs at 36 pt with their rings, leading→trailing. The ribbon's role in SIEVE: recent evidence, reviewable at a glance |
| commit bar | 604–667 | **pause** (trailing, 44 pt). Nothing else during `streaming`. In `paused` the same slot gains a **chevron** (leading, 44 pt) that abandons the run on a second, confirming tap — deliberately two taps, and reachable only from a stopped stream |

- A glyph is **actionable** exactly while its centre is within ±44 pt of the gate centre line (y = 464).
- Glyph pitch is fixed at **`P = 132 pt`** centre-to-centre at every speed. Since `P > 88 pt`, **at most one glyph is ever actionable** — a hard invariant, asserted by test.
- A tap **anywhere inside the gate band** means *admit this one*; not tapping means *reject*. The target is 375 × 88 pt — 8.5× the 44 pt minimum in its short axis — and it sits inside the right-thumb comfort arc (canon §4.1: y > 240).
- Taps outside the gate are discarded silently: no foul, no sound, no haptic. A fumble costs nothing.

### 9.3 Speed curve

Rate ramps linearly in **glyph index**, not wall-clock, so a run is reproducible from its seed and unaffected by a dropped frame.

```
r(n) = r₀ + (r₁ − r₀) · n / N        glyphs per second, n = 0 … N−1
v(n) = r(n) · 132                    pt per second
window(n)  = 88 / v(n) = 0.667 / r(n)    seconds actionable
preview(n) = 340 / v(n)                  seconds visible above the gate
```

| law band | `r₀` | `r₁` | window @ `r₀` | window @ `r₁` | preview @ `r₁` | `N` | **tell / body / run-out** | duration |
|---|---|---|---|---|---|---|---|---|
| 1 LITERAL | 1.00 | 1.60 | 667 ms | 417 ms | 1.61 s | 60 | **12 / 33 / 15** | ≈ 46 s |
| 2 PAIR | 1.10 | 1.75 | 606 ms | 381 ms | 1.47 s | 64 | **12 / 36 / 16** | ≈ 45 s |
| 3 EXCLUSIVE | 1.20 | 1.90 | 556 ms | 351 ms | 1.36 s | 68 | **12 / 39 / 17** | ≈ 44 s |
| 4 RELATIONAL | 1.30 | 2.05 | 513 ms | 325 ms | 1.26 s | 72 | **12 / 42 / 18** | ≈ 43 s |
| 5 CONTEXTUAL | 1.40 | 2.20 | 476 ms | 303 ms | 1.17 s | 76 | **12 / 45 / 19** | ≈ 42 s |
| 6 GUARDED | 1.45 | 2.35 | 460 ms | 284 ms | 1.10 s | 80 | **12 / 48 / 20** | ≈ 42 s |

**Tempo step** `s ∈ {0,1,2,3}` adds `0.20·s` to both `r₀` and `r₁`. At band 6 with `s = 3`, `r₁ = 2.95 g/s` → window **226 ms**, preview 0.87 s, total decision time **1.10 s** from first sight to last chance.

**SIEVE serves law bands 1–6 only.** Band 7 demands holding two conceptual layers, band 8 demands ruling out every simpler family first; neither is learnable from a passive stream in 45 seconds, and serving them would teach the player only that SIEVE is arbitrary. Ability above band 6 is absorbed by the tempo step, not by the law.

### 9.4 Stream composition

The stream is constructed, not sampled uniformly. Three **reaches**, defined **by subtraction so that they partition the stream exactly**, in this order:

```
tell   = 12
runOut = round(0.25 · N)
body   = N − 12 − runOut          // the remainder, never a percentage
```

| Reach | Extent | Lawful fraction | Construction | Weight |
|---|---|---|---|---|
| **the tell** | first `12` glyphs | exactly 0.50 | the law's pivotal attributes vary maximally; consecutive glyphs differ in ≥ 2 attributes | **0.5** |
| **the body** | the next `N − 12 − runOut` | the law's own `p` | uniform over the deck subject to `p` | 1.0 |
| **the run-out** | the final `round(0.25·N)` | the law's own `p` | each glyph differs from its predecessor in **exactly one attribute**, and ≥ 40 % of adjacent pairs straddle the law's boundary | 1.0 |

> **Decision:** the body is the remainder, not a fraction. Reason: a fixed 12-glyph tell plus 60 % plus 25 % totals `12 + 0.85·N`, which equals `N` only at `N = 80` — every band but 6 was over-subscribed, band 1 by three glyphs. Since the tell is weighted 0.5 and the run-out carries the fine-discrimination guarantee, the split is load-bearing for the score and for S1–S3, so it is fixed by construction rather than by rounding at build time. The resulting integer triples are in §9.3's band table.

The tell makes evidence arrive fast and keeps the unlearnable prefix off full weight; the run-out makes the last quarter compound speed with fine discrimination rather than merely getting faster. Contextual laws (band 5) take `prev` from the stream's own adjacency, with a **seed glyph** held inert in the gate for 1.5 s before the stream starts, priming position 0 (canon §3.5). Guardrails on top of canon G1–G10: **S1** — over the first 12 glyphs, every attribute the law names takes ≥ 3 of its 4 values. **S2** — no run of 5 consecutive glyphs shares a verdict, anywhere. **S3** — in contextual bands, ≥ 4 adjacent pairs in the tell straddle the law's boundary. **S4** — the pitch invariant `P > gate height` at every `r`. **S5** — `tell + body + runOut == N`, and `body ≥ 20`, for every band and every tempo step.

### 9.5 Round lifecycle, fouls, and how a run ends

```swift
enum SievePhase { case arming, priming, streaming(Reach), paused,
                       fouling, reveal, settled }        // Reach = tell | body | runOut
```

| From | Event | To | Side effects |
|---|---|---|---|
| `arming` | stream built | `priming` | seed glyph inert in the gate, 1.5 s |
| `priming` | — | `streaming(.tell)` | — |
| `streaming` | reach boundary crossed | `streaming(next)` | no visible cue |
| `streaming` | pause key, or backgrounded | `paused` | freeze at the next glyph boundary |
| `paused` | resume | `streaming` | **run-up**: last 3 resolved glyphs replay at `r₀`, then continue |
| `paused` | chevron, then confirm tap | `reveal` | **abandoned** — scored as a foul-out at the last resolved glyph (§9.8) |
| `streaming` | third foul | `fouling` | stream halts mid-lane, 400 ms freeze |
| `fouling` | — | `reveal` | **loss**; law revealed in rule-tiles |
| `streaming` | `N`-th glyph resolved | `reveal` | **sieved**; the law is likewise revealed in rule-tiles — it is the law the player just demonstrated, so there is nothing to protect, and a page that may enter ECHO's pool must have been stated at least once (§8.2) |
| `reveal` | complete or skipped | `settled` | Codex page if sieved and `ratio ≥ 0.92` |

| Event | Definition | Consequence |
|---|---|---|
| **hit** | lawful, tapped in window | score, admit haptic |
| **correct pass** | unlawful, not tapped | score, no haptic — silence is the reward |
| **miss** | lawful, not tapped | no score. The sump shows the Loom's admit ring with the player's ring **absent**: a hollow result |
| **foul** | unlawful, tapped | score penalty **and one of three fouls**. Two-ring conflict (canon §4.5) + law-broken haptic |

> **Decision:** misses never end a run; three fouls do. Reason: the instruction is "tap only the lawful ones". A miss is caution, a foul is a false claim, and punishing claims while tolerating caution is what stops the mode degenerating into mashing. Tap-everything fouls out inside the first three body glyphs (`p ≤ 0.60`); tap-nothing survives the full run and scores ≈ 41 %, below the 1-mark threshold. Both degenerate strategies are strictly dominated.

**Fouls do not accrue during the tell.** A false positive in the first 12 glyphs still resolves visibly — that is how the player learns — but costs no foul and is weighted 0.5. Punishing an unlearnable prefix would be dishonest. A run ends **sieved** (all `N` resolved), **fouled** (third foul), or **abandoned** (§9.8).

### 9.6 Scoring

```
per glyph i, weight wᵢ = 0.5 in the tell, else 1.0
  hit → + wᵢ·10     correct pass → + wᵢ·3     miss → 0     foul → − wᵢ·8

raw           = Σ over resolved glyphs
idealResolved = Σ over resolved i of wᵢ · (lawful(i) ? 10 : 3)
ratio         = max(0, raw) / idealResolved        // accuracy, over what was actually seen
completion    = resolvedGlyphs / N                 // reach
yield         = ratio · completion

score_SIEVE = round( 1000 · yield )
```

> **Decision:** `ratio` is normalised over **resolved** glyphs, not over all `N`. Reason: with `ideal` summed over all `N`, the unresolved glyphs sit in the denominator contributing nothing to the numerator, so completion is already inside `ratio` — multiplying by `completion` again squares the penalty. A flawless player fouling out at glyph 20 of 76 scored `1000 · 0.26 · 0.26 ≈ 69`, roughly 7 % of a completed run and about four times harsher than the mode's own edge-case table claims. At band 6 with `s = 3` the window is 226 ms and three fouls are cheap to accumulate, so the mode's most common bad outcome was its most mispriced one. Split cleanly: `ratio` measures accuracy, `completion` measures reach, each is charged exactly once.

Marks are read off `yield`, not `ratio`, so that reach is charged to the mark as well as to the score: **3** if `yield ≥ 0.92` and zero fouls outside the tell; **2** if `yield ≥ 0.80`; **1** if `yield ≥ 0.60`. On a sieved run `completion = 1` and `yield == ratio`, so the thresholds are exactly the completed-run thresholds they were calibrated as. Success, for the Rasch update, iff **sieved and `ratio ≥ 0.80`**. A run sieved at `ratio ≥ 0.92` **inscribes the law as a Codex page** marked with the SIEVE sigil — a page won by demonstration rather than declaration — which then enters ECHO's pool.

SIEVE emits `(median gate-entry-to-tap latency over hits, mean window over the same glyphs, ratio, completion)` to the Profile at `settled`. The sample formula and the step size are **§11.9's single normative table**; no axis formula and no EWMA constant live in this section. SIEVE has no quantity ranging 0–12 and no notion of a "tier" — any axis definition that reads one is reading a field that does not exist.

**Worked run — law band 5, tempo step 0.** Law `RANK pips(cur) > PREV RANK pips`, `p = 0.375`, δ = 0.525. `N = 76`, `r₀ = 1.40`, `r₁ = 2.20`, ≈ 42 s. Reaches by §9.4: tell 12 (6 lawful / 6 unlawful, w = 0.5), run-out `round(19) = 19`, body `76 − 12 − 19 = 45` → the 64 non-tell glyphs are 24 lawful / 40 unlawful.

```
idealResolved = tell   6·0.5·10 + 6·0.5·3    =  30 +   9 =  39     // all 76 resolved,
              + rest  24·10     + 40·3       = 240 + 120 = 360     // so this is the full ideal
                                                              → 399
```

Player: in the tell, 4 hits of 6, 5 correct passes of 6, 1 false positive (no foul). After the tell: 21 hits of 24, 38 correct passes of 40, 2 fouls — the run survives at 2 of 3.

```
raw = tell   4·0.5·10 + 5·0.5·3 − 1·0.5·8    =  20 + 7.5 − 4   =  23.5
    + rest  21·10     + 38·3   − 2·8         = 210 + 114 − 16  = 308.0   → 331.5

ratio = 331.5 / 399 = 0.831 ;  completion = 1.0 ;  yield = 0.831 ;  score = 831
```

**2 marks** — `yield ≥ 0.80`, but fouls occurred outside the tell. Sieved and `ratio ≥ 0.80` → **success**. Below 0.92 → no Codex page.

### 9.7 Difficulty mapping

```
δ_SIEVE    = clamp( difficulty(law) + 0.125 · s / 3, 0.0, 0.999 )      s ∈ {0,1,2,3}
band_SIEVE = floor(δ_SIEVE / 0.125) + 1
```

§10.3 hands SIEVE a `targetδ` in **difficulty units** `[0.000, 1.000)` — never a logit; feeding this mapping a logit would return a negative band. Given `targetδ`:

```
lawBand = min(6, floor(targetδ / 0.125) + 1)          // the law's band — capped at 6, §9.3
law     = generate(seed, lawBand, min(targetδ, 0.749), .sieve, avoid)      // canon §5.3
s       = clamp( round( 3 · (targetδ − difficulty(law)) / 0.125 ), 0, 3 )  // the remainder, as speed
```

With `lawBand = 6, s = 3`, `δ_SIEVE` reaches 0.874 — the top of band 7's range — so SIEVE spans the ability ladder to an **effective** `band_SIEVE` of 7 while never serving a band-7 or band-8 *law*. The two quantities are distinct and both are needed: `lawBand ≤ 6` gates the generator, `band_SIEVE ≤ 7` is what the Rasch update and §10.3's per-mode clamp see. Canon's two-consecutive-failures rule applies unchanged: drop a full band, which in SIEVE means dropping `s` to 0 first and only then reducing `lawBand`. **Speed is reduced before the idea is.**

### 9.8 Fairness on a small screen, accessibility, interruption

- The target is 375 × 88 pt, fixed and stationary; nothing that moves is ever tapped, and at most one glyph is actionable at any instant. Worst-case total decision time (band 6, `s = 3`, final glyph) is 0.87 s preview + 0.226 s window = **1.10 s**.
- **Reduce Motion:** the conveyor becomes a step — glyphs crossfade lip → lane → gate → sump at the identical cadence, and the gate dwell is byte-identical, so the hit window is unchanged. Motion is removed; timing is not.
- **VoiceOver:** step mode with `r` fixed at 0.75 g/s (window 889 ms) and no ramp. The gate is one accessibility element with an "admit" custom action; each glyph is announced on gate entry using the canonical `fill → shape → pips → hue` label and its resolution announced in the sump. Scoring is identical; the **Tempo axis is not updated**, because the timing is not comparable.
- **Settings → steady stream:** fixes `r` at `r₀` with no ramp, at a 0.85 score multiplier. Available to anyone, not gated behind an accessibility flag, and it does not disable Codex inscription.
- Every verdict is readable with audio off, haptics off and colour off: the ring is a **solid** 3 pt stroke for admit and a **broken** 3 pt stroke for reject, independent of hue.

> **Decision:** a SIEVE run that is **terminated** (swipe-kill, OOM, crash — not merely backgrounded) is **void**: no score, no Codex effect, no ability update, no foul carried forward. Reason: a timed run cannot be honestly resumed across a cold launch. Canon §5.4's after-every-probe persistence has no analogue here because SIEVE has no probes; the run record is still written, marked `void`, carrying `resolvedGlyphs`, `raw` and `idealResolved` at the last resolved glyph boundary, so the attempt log stays truthful and the frozen `ratio`/`completion` remain recoverable. **A terminated run is never banked at its frozen score** — banking on force-quit is precisely the exploit voiding exists to close.

**Voiding is sticky, and bounded.** Voiding alone does not close the exploit: a player who force-quits every run that opens badly records only wins, so `θ_sieve` is estimated from a censored sample and drifts upward — the same failure canon guards against by demanding a failure signal that is not solely "declared wrong". PROBE already solved the analogous case by making the abandoned target sticky, and SIEVE takes the same rule:

1. A voided run leaves `δ_served`, `lawBand` and the tempo step `s` **unchanged** for the next SIEVE run, which is generated at the same target from a different seed. Quitting buys a re-roll of the law, never an easier one.
2. After **two consecutive voids**, the third run is not voidable: it is scored at its frozen `ratio` and `completion` at the moment of termination and counted as a normal outcome for the ability update. Two escapes is generous; three is a strategy.

**Abandoning is not voiding.** From `paused`, a chevron with a second confirming tap ends the run deliberately. An abandoned run is **scored exactly as a foul-out at the last resolved glyph**: `completion = resolvedGlyphs / N`, `ratio` as it stands, `yield = ratio · completion`, marks by `yield`, a Codex page only at `yield ≥ 0.92` (which needs a run that was almost complete anyway), and the ability update runs normally. Reason: the exit is deliberate and confirmed, so it is a choice about this run rather than an accident of the operating system, and treating a chosen exit as a non-event is the same censoring problem in a nicer costume. This is the third of the three ways a run ends in §9.5 — sieved, fouled, abandoned — and the only one the player controls.

Backgrounding is neither: the stream freezes at the next glyph boundary and, on resume, the last 3 resolved glyphs replay at `r₀` before it continues. The run-up costs nothing and is not re-scored — those glyphs keep their original results. A run may be paused any number of times; each pause costs a 3-glyph run-up, which is its own soft disincentive. Because `r` ramps in glyph index rather than wall-clock, a frame drop delays a glyph but never shortens its window; if the frame budget is missed by more than 100 ms the run auto-pauses.

### 9.9 Edge cases

| Name | Situation | Defined behaviour |
|---|---|---|
| **GATE-STRADDLE** | a tap lands as a glyph crosses the gate edge | the tap binds to the glyph whose centre is nearest y = 464 at the tap timestamp, iff that centre is within ±44 pt. The pitch invariant guarantees at most one candidate; no candidate → discarded silently |
| **DOUBLE-TAP** | second tap while the same glyph is in the gate | ignored. Admit is idempotent; one glyph can produce at most one foul |
| **THUMB-PARK** | the player rests a thumb inside the gate | only touch-**down** events register, and a touch begun before the glyph entered does not carry over. A parked thumb admits nothing |
| **TELL-FOUL** | false positives in the first 12 glyphs | resolve visibly, weighted 0.5, **no foul accrued**. The unlearnable prefix is never punishable |
| **FOUL-OUT-EARLY** | third foul at glyph 20 of 76 | run ends; `completion = 0.263`, so `yield ≤ 0.263` and `score ≤ 263` regardless of accuracy. A player who was otherwise flawless to that point holds `ratio ≈ 0.90` and scores **≈ 237** — not the ≈ 69 the pre-§9.6 double count produced. An early foul-out is still strictly worse than the cautious full run (`yield ≈ 0.41`, score ≈ 410), which is the intended ordering, and it is now worse by the right margin rather than by four times it |
| **BLIND-STREAM** | a contextual law whose stream rarely crosses its own boundary | prevented by S3: the tell guarantees ≥ 4 boundary-straddling adjacent pairs |
| **ZERO-ACTION RUN** | the player taps nothing for the whole stream | legal, sieved, `completion = 1` so `yield = ratio ≈ 0.41` at `p = 0.30` → 0 marks, counted as a failure. No page, no penalty beyond the ability update |
| **SERIAL-VOID** | the player force-quits two opening-badly runs in succession | each void leaves `δ_served`, `lawBand` and `s` unchanged, so run 2 and run 3 are served at the identical target from fresh seeds. The **third** consecutive termination is scored at its frozen `ratio` and `completion` and updates the ability (§9.8) |

---

### 9.10 The four modes, side by side

| | **PROBE** | **DRIFT** | **ECHO** | **SIEVE** |
|---|---|---|---|---|
| **Cognitive task** | active hypothesis search with self-designed experiments | change detection, then re-induction against a strong wrong prior | applying a law you already own as a filter, with the lamp switched off | inducing a law from a stream you do not control, at pace |
| **What it removes from PROBE** | — | the permanence of evidence | the ability to test | the choice of the next glyph, and time |
| **Player chooses the next glyph** | yes (Dial) | yes (Dial) | no | no |
| **Feedback during play** | per probe | per probe | **none** during the cast | per glyph, unconditional |
| **Round length** | ≈ 1 min (band 1) → 6–12 min (band 8) | ≈ 1.3 × PROBE at the same band | 45–75 s | **41–46 s, fixed** |
| **Time pressure** | none | none | cadence during the cast only; recall untimed | continuous and ramping — the only mode with real time pressure |
| **Uses the Bench** | yes | yes | no | no (read-only at the reveal) |
| **Law source** | generated, bands 1–8 | generated pair `L₁ → L₂`, bands 3–8 | **selected** from the Codex pool (last 8) | generated, bands 1–6 |
| **Difficulty knobs** | band + within-band δ | band + within-band δ | pool law + load index `ℓ` 1–8 | law band 1–6 + tempo step `s` 0–3 |
| **δ ceiling** | 0.999 | 0.999 | 0.999 | 0.874 |
| **Profile axes fed** | **Induction**, Tempo, Restraint | **Flexibility**, Induction, Restraint | **Retention**, Induction | **Tempo**, Induction, Restraint |
| **Inscribes a Codex page** | any correct declaration | correct `L₂` declaration; the page carries both laws and the hinge | no — burnishes an existing page at 3 marks | only when sieved at `ratio ≥ 0.92` |
| **Strikes** | 2 | 2 | none — a commit is final | none — 3 fouls instead |
| **Interruption policy** | persisted per probe, resumes exactly | persisted per probe, resumes exactly | one free cast restart; a second interruption abandons with no ability update | backgrounding pauses with a 3-glyph run-up; the chevron abandons and is scored as a foul-out; termination voids the run, sticks the target, and stops being voidable on the third consecutive void |
| **Unlocks when** | first launch, ungated | the Codex holds a **page at band ≥ 3** | the Codex holds **≥ 5 pages** | the Codex holds **≥ 8 pages** |

**This row is the single source for mode unlocks.** No other section states a threshold; every other section that mentions one cross-references here, and canon §5.7 carries the triple as a locked constant. The three numbers are not arbitrary:

- **DRIFT — a page at band ≥ 3.** DRIFT's lowest servable band is 3 (§7.2), so the gate is the mode's own floor: you have met a law whose family DRIFT can actually edit.
- **ECHO — 5 pages.** ECHO's pool has a functional floor of 3 members (§8.2), and BLIND-PRIMER can drop two. Unlocking at exactly 3 would hand the player a lit key over an unusable pool. The rule is `unlockThreshold(.echo) ≥ minimumPoolSize + 2`, shipped as an assertion, and 5 is the smallest number satisfying it.
- **SIEVE — 8 pages.** One full echo pool. SIEVE is the texture change and the only timed mode; it arrives once the archive is an archive rather than a handful.
## 10. Adaptive Difficulty, Pacing and Progression

### 10.1 The model, in one screen

One latent ability per mode, in logits, on the same scale as `δ_logit = 8 · difficulty − 4` (§5.1). Band width `0.125` in difficulty is therefore **exactly 1.000 logit** — the single most useful fact in this section. "Drop a full band" and "subtract 1.0" are the same instruction.

```swift
struct Ability: Codable, Equatable, Sendable {          // pure value type, no clock, no store
    var core:  Double                                   // PROBE-anchored, the only absolute
    var drift = 0.0, echo = 0.0, sieve = 0.0            // offsets, logits
    var n: [Mode: Int] = [:]                            // scored rounds, per mode
    var lastPlayed: [Mode: Date] = [:]
}
struct ServingState: Codable, Sendable {
    var reach = 0.0, relief = 0.0                       // 0…1.0, 0…2.0
    var winStreak = 0, consecutiveLosses = 0
    var lastFamily: Family? = nil                       // family actually served; Family(lawBand) in SIEVE
    var calibrationRound: Int? = 1                      // nil once calibrated
    var ceilingClampRun = 0                             // consecutive rounds clamped at maxBand — §10.3 step 10
    var maxBandEverServed = 1                           // drives the palette ceiling — §10.4, never decreases
    var sieveVoidRun = 0                                // consecutive terminated SIEVE runs — §9.8
    var stickyTarget: [Mode: StickyTarget] = [:]        // frozen by a void or abandon; cleared by any scored round
}
struct StickyTarget: Codable, Sendable {                // §6.10 for PROBE, §9.8 for SIEVE
    var band: Int, targetδ: Double, tempoStep: Int
}
```

**Success probability.** `P(win) = σ(θ_mode − δ_logit) = 1 / (1 + e^(δ − θ))`. Nothing else. No guessing parameter, no discrimination parameter — a wrong declaration is not a lucky guess over 27,015 laws, and the family structure already carries the discrimination.

**The 80 % target is one constant.** `σ(ln 4) = 4/5` exactly, so serving `δ = θ − ln 4 = θ − 1.3863` hits 0.800 by construction. That is the whole target mechanism; everything below is correction and safety — and the correction is load-bearing, because the pacing terms §10.3 adds on top of this target have a non-zero mean and would otherwise move the realised rate to 0.75. The identity above holds *in expectation over rounds*, not round by round, and `π₀` is what makes that true.

> **Decision:** the Rasch response variable is the **round outcome** (inscribed / not inscribed), not the first declaration. Because canon locks both `0.80` round success and `0.62` first-declaration, and two strikes sit between them: `0.62 + (1 − 0.62)·r = 0.80 ⟹ r = 0.474`. The counterexample-conditional recovery rate `r ≈ 0.47` is therefore a **derived constant**, and the harness asserts it (H5). Modelling the first declaration instead would make the served band 0.5 logit too easy.

**A round is a loss** if the second strike lands, or the cap is reached (§5.4), or a timed mode's threshold is missed. A round is **not scored at all** if it is suspended, if it is the Anomaly (§10.6), if an ECHO cast was interrupted a second time (§8.9), or if a SIEVE run was terminated and the void is still within its two-run allowance (§9.8).

**Abandoning is scored.** A deliberately abandoned SIEVE run is scored as a foul-out at the last resolved glyph and updates `θ` normally (§9.8), and an abandoned PROBE or DRIFT round leaves its target sticky rather than free. The distinction is not fussiness: every unscored outcome is a censored observation, and an estimator fed only the rounds a player chose not to quit drifts upward for the same reason that a survey of finishers overstates the pass rate.

### 10.2 The update rule — symmetric, pure, unbiased

```
θ_mode ← θ_mode + K(n) · (x − P) ,    x ∈ {0,1} ,  P = σ(θ_mode − δ_served)
K(n)   = max(0.18, 0.90 / (1 + n/8))  ,  n = scored rounds in that mode after calibration
```

`K` at `n = 0, 4, 8, 16, 24, ≥32` = `0.900, 0.600, 0.450, 0.300, 0.225, 0.180`. At the floor, a win at `P = 0.8` moves `+0.036` and a loss moves `−0.144`: four wins to undo one loss, which is the correct ratio at an 80 % target and needs no asymmetry to produce it.

> **Decision:** the estimator is **strictly symmetric**. All "up fast / down gently" asymmetry lives in the *serving policy*, never in the estimator. Because `θ += K(x − P)` has a fixed point at `E[x] = P` for any `K`; multiplying `K` by a direction-dependent factor destroys that fixed point and biases `θ̂` upward by ~0.4 logit at equilibrium, which silently moves the true success rate to ~0.74. The brief's asymmetry requirement is a *pacing* requirement and is satisfied exactly by `reach` and `relief` below, with no cost to the estimate.

The estimator is a pure function of `(Ability, Mode, δ_served, Bool)` with no wall-clock, RNG or store dependency — the unit under test in `AbilityEstimatorTests`. `θ` is hard-clamped to `[−6, +6]` at write; `n` caps at 4,096. Mode offsets update on the same rule with `K_Δ(n) = 0.6 · K(n)` plus shrinkage `Δ ← 0.985 · Δ` after each update in that mode, which bounds `|Δ| ≤ 3.0` in practice and means an unplayed mode never drifts.

### 10.3 The serving policy — where the asymmetry lives

Executed in this exact order, once per round, before generation:

| # | Step | Formula |
|---|---|---|
| 1 | mode ability | `θ = core + offset(mode)` |
| 2 | target | `δ = θ − 1.3863` |
| 3 | mode bias | `δ += modeBias(mode)` — probe `0`, drift `−0.50`, echo `0`, sieve `0` |
| 4 | **pressure** | `δ += reach − relief − π₀`, with **`π₀ = 0.44` locked** (see below) |
| 5 | jitter | `δ += U[−0.35, +0.35]`, drawn from `roundSeed`, deterministic |
| 6 | clamp | `δ = clamp(δ, −4.00, 3.99)`; SIEVE additionally `δ ≤ 2.99` — the effective ceiling `δ_SIEVE ≤ 0.874` of §9.7, in logits |
| 7 | quantise | `band = clamp(Int(floor(δ + 4)) + 1, 1, 8)` |
| 8 | **mode band clamp** | `band = clamp(band, minBand(mode), maxBand(mode))` — probe `1…8`, drift `3…8`, echo `1…8`, sieve `1…7` |
| 9 | family repeat guard | if the last round was a loss and `Family(band) == lastFamily`, move `band` down 1 — up 1 if already at `minBand(mode)` |
| 10 | ceiling rotation | if `band` was clamped at `maxBand(mode)` on each of the 3 preceding rounds, `band −= 1` |
| 11 | within-band | if steps 8–10 all left `band` untouched, `targetδ = clamp((δ + 4)/8, 0.125·(band−1), 0.125·band − 0.001)`; if a clamp or the repeat guard moved it, `targetδ =` the new band's **centre**, `0.125·band − 0.0625`; if the ceiling rotation moved it, the new band's **upper near edge**, `0.125·band − 0.020` |
| 12 | **record** | `δ_served = 8·targetδ − 4`. **This**, not step 6's `δ`, is what §10.2's estimator consumes |
| 13 | dispatch | PROBE / DRIFT → `generate(seed, band, targetδ, mode)` (§5.3, ±0.02 tolerance, 200 attempts) · ECHO → `selectFromPool(targetδ)` (§8.6) · SIEVE → `generate` at `lawBand`, then solve the tempo step `s` (§9.7) |

**Steps 7–12 hand each mode a `band` in `1…8` and a `targetδ` in difficulty units `[0.000, 1.000)`. §8.6 and §9.7 consume `targetδ`; neither ever sees a logit** — `floor(logit/0.125)+1` on a logit of −2 returns band −15, which is the shape of bug this sentence exists to prevent.

> **Decision:** step 11 re-derives `targetδ` *after* every step that can move the band. Reason: computing the within-band position against the pre-guard band and then moving the band leaves `targetδ` clamped into a range the new band does not contain. G8 requires `difficulty ∈ [lo, hi)` **and** within 0.02 of `targetδ`; for a 5 → 4 shift with `targetδ = 0.56` those two windows do not intersect, all 200 attempts fail, and the generator falls back to the family anchor — silently degrading the family-repeat guard, one of the two named anti-frustration mechanisms, into "serve the same fixed anchor law every time you lose twice to the same family". H19 watches the fallback rate for exactly this class of failure.

**DRIFT carries a −0.50 mode bias** because the mid-round law swap is a schedule *outside* the AST (§3.5) and therefore invisible to `difficulty(of:)`. Empirically (H12) it costs about half a band of effective difficulty; the bias pays for it rather than corrupting the difficulty function. Its floor of band 3 is not decorative: §7.2 restricts DRIFT to bands 3–8 because the hinge cannot fire inside `0.80 · par` at bands 1–2, and §7.7's `par_DRIFT` / `cap_DRIFT` table has no rows below band 3. A calibrated beginner sits at `core = −2.114` and `relief` can subtract a further 2.00, so without step 8 the generator would routinely be called with an undefined par.

**When a step-8 clamp binds, the pressure term stops accumulating in that direction** — `reach` is frozen at its current value while `band == maxBand(mode)`, `relief` while `band == minBand(mode)` — so the ladder never builds up unspendable pressure that has to be discharged before the next real move can be felt.

```
reach:   on win  → winStreak += 1 ; reach = min(1.00, 0.25 · (winStreak - 1))
         on loss → winStreak  = 0 ; reach = 0
relief:  on loss → consecutiveLosses += 1
                   if consecutiveLosses >= 2 { relief = min(2.00, relief + 1.00) }
         on win  → consecutiveLosses  = 0 ; relief = max(0.00, relief - 0.50)
```

**`π₀` — why the escalation has to be centred.** `reach` is not an occasional excursion, it is a standing offset. At an 80 % win rate the streak length seen at serving time is distributed `P(k) = (1−q)·q^k`, so streaks of ≥ 5 — which carry the full `+1.00` — occupy `0.8⁵ ≈ 33 %` of rounds and `E[reach] = 0.413` measured. `relief` answers with only `E[relief] = 0.035`, because two consecutive losses is a 4 % event by the model's own arithmetic. Left uncentred the policy therefore serves about `+0.37` logit hard, and the fixed point `q = E[σ(1.3863 − reach + relief)]` lands at **0.75**, not 0.80. That is not a rounding error against H3's `0.80 ± 0.03`; it is a different game.

`π₀` is the constant that makes the pressure term a **reallocation of difficulty across rounds rather than a net shift**. It is defined operationally — the unique offset for which the Level-A harness realises 0.800 at equilibrium — and solved once, offline, over the whole policy including jitter, band quantisation and the harness's day-to-day `ε`:

```
π₀ = E[reach − relief]  +  curvature
   =        0.375       +    0.065      =  0.44        // locked; H18 asserts it
```

The curvature term is not a fudge: `σ` is concave at `x = ln 4` (`σ'' = −0.096`), so a zero-mean spread in the served `δ` depresses the mean win rate by `≈ σ''·Var/2` — about 0.006 from jitter and ε together. Measured at `π₀ = 0.44`, the realised rate is **0.797–0.799** for every `θ_true` from −1 to +3, against 0.749 uncentred. If the jitter width, the relief ladder or the reach schedule ever changes, `π₀` is re-solved; H18 fails the build if it is not.

**reach — up fast on a win streak.** Streak 1 → 0, 2 → 0.25, 3 → 0.50, 4 → 0.75, ≥5 → 1.00. Against the centred baseline that is the difference between `σ(1.83) = 0.86` on the round after a loss and `σ(0.83) = 0.70` deep in a streak — a full band of felt escalation with the *average* still at 0.80. When the reach round is lost, `reach` collapses to 0 and the player lands back where `θ` says they belong. Reach never touches `θ`, so a probing escalation cannot inflate the estimate.

**relief — down gently, then decisively.**

Trace: `L` → 0.00 (θ has already dropped ~0.14, nothing else moves) · `LL` → 1.00, **one full band down** · `LLL` → 2.00, two bands · `LLLL` → 2.00, capped · then `W` → 0.50 · `WW` → 0.00.

One loss moves nothing but the estimate — a single loss is normal at an 80 % target and reacting to it would make the ladder twitch. Two consecutive losses is a 4 % event under the model, so it is evidence, and it buys a full band. Recovery takes two wins, not one, so a rescued player gets a confirmed win before being asked again.

Guaranteed floor behaviour: at `band 1` with `relief = 2.0` the clamp at `−4.00` holds and the served law is band 1's minimum-difficulty law. There is nowhere lower. §10.7 takes over.

**What actually rotates the family — and what does not.** Jitter cannot do it, and an earlier draft of this section claimed it could. A band is exactly 1.000 logit wide (§10.1); `U[−0.35, +0.35]` cannot cross a boundary from band centre *at all*, and averaged over a uniform position inside the band it crosses only 17.5 % of the time. Jitter's real jobs are within-band variation and blurring the par-tick signal (§10.5), and that is all it is claimed for here.

The rotation comes from the pressure term, which spans 3 logits — three whole bands. Measured over 10⁶ stationary rounds at `π₀ = 0.44`:

| `θ_true` | band distribution | modal share | mean consecutive rounds in one family | `P(family run ≥ 5)` |
|---|---|---|---|---|
| 0.0 | 2 : .19 · **3 : .58** · 4 : .22 | 0.58 | 1.95 | 0.047 |
| +0.35 (mid-band) | 2 : .09 · 3 : .49 · **4 : .42** | 0.49 | 2.32 | 0.074 |
| +2.0 | 4 : .19 · **5 : .58** · 6 : .22 | 0.58 | 1.94 | 0.047 |

Three families in regular rotation, the modal one under 60 % of rounds, and a same-family run of five or more on 5–7 % of runs. That is the mechanism, stated where it is true.

It fails in exactly one place: **when the band clamp binds, the pressure has nowhere to push.** At `θ_true = +6` the served band is 8 on 89 % of rounds with a mean family run of 4.7, because `reach` is pinned and only `relief` can move anything. Step 10's ceiling rotation exists for that regime alone — three consecutive clamped rounds force one round a band down, at that band's upper near edge so it reads as a change of question rather than a demotion. The floor needs no equivalent: a player pinned at band 1 is losing, and §10.7's floor rescue already owns that case.

### 10.4 Cold start and calibration

> **Decision:** a brand-new player has **no prior at all** — `core` is undefined, not `0`. A fixed prior of 0 would serve band 4 (RELATIONAL) as round 1 to everyone, which is unplayable before the Dial and the Bench have been learned. Instead, rounds 1–5 run a **galloping ladder**: bands **1, 2, 4, 6, 8**, ascending only while the player is winning, terminating on the first loss or at round 5.

Round 1 is band 1 unconditionally; each win advances to the next rung. On the first loss at band `b`, with `marks` = Seal marks earned on the previous (winning) round:

```
b_est   = (marks >= 2) ? b - 1 : max(1, b - 2)          // probe economy breaks the tie
core   := (Double(b_est) - 4.5) + 1.3863                // = b_est − 3.114 ; band centre + ln4
n[mode] = 0                                             // K restarts at 0.900
```

| First loss at | b_est | seeded `core` |
|---|---|---|
| band 1 (r1) or band 2 (r2) | 1 | −2.114 |
| band 4 (r3) | 3 or 2 | −0.114 / −1.114 |
| band 6 (r4) | 5 or 4 | 1.886 / 0.886 |
| band 8 (r5) | 7 or 6 | 3.886 / 2.886 |
| never — won all 5 | 8 | 4.886 (band 8 permanently) |

Worst-case seeding error is ±1 band; `K = 0.900` for the next 4 rounds removes it in ~3 rounds (H2 asserts ≤ 12 median). Calibration costs at most 5 rounds and is over in one sitting.

> **Decision:** **calibration rounds 1–5 unlock the full palette**, exactly as the Anomaly round does (§10.6), reverting when calibration ends. Reason: canon §4.4 gates tile classes at lifetime maximum band + 1 and justifies it with "a beginner literally cannot express a band-5 law, which is fine, because they will never be served one." The gallop is the one thing that makes that sentence false. A player who wins bands 1 and 2 has lifetime max 2, hence a ceiling of band 3 — two Ramps and a coupler, **no Bridge** — and round 3 is band 4 RELATIONAL, which cannot be stated without one. Round 4 is band 6 GUARDED and needs the Fork; round 5 is band 8 SYSTEMIC and needs the Tally. Every new player who wins their first two rounds was being handed a round that is unwinnable by construction, would probe to the cap, and would lose — and that loss is what seeds `core`.

**The palette ceiling is derived from the highest band ever *served*, not the highest ever cleared,** persisted alongside it. Clearing is the wrong predicate: `reach` can add a full band and jitter another third, so a player whose lifetime maximum *cleared* band is 6 can be served band 8 and still have no Tally. And the guarantee is enforced **at serve time, not at generation time** — canon's G10 proves every emitted law is buildable in principle, on the full palette, and says nothing about the palette this player is holding:

```
assert paletteTileClasses(player) ⊇ tileClasses(Family(servedBand))     // before the round arms
```

If the assertion would fail, the palette is raised to satisfy it and the round proceeds. A player is never shown a law they cannot state.

**Resetting the ladder** — the destructive Settings action — is defined here, and only here, so that no other section has to guess what it clears. It sets `core` back to **undefined** (not to `0`), `calibrationRound = 1`, `n[mode] = 0` for all four modes, and zeroes `reach`, `relief`, `winStreak` and `consecutiveLosses` and the last-50 novelty ring. The next round is therefore round 1 of the galloping ladder. Zeroing `core` to `0.0` instead would serve band 3 immediately and skip calibration entirely, which is the precise cold-start failure the first Decision in this section exists to prevent. The Codex, the Profile and the Anomaly ledger — tally and streak both — are untouched; the reset is for a shared device, not a wipe. The **palette ceiling is not** untouched: `maxBandEverServed` is `ServingState`, so it zeroes with the rest and the palette returns to its band-2 opening state, which is correct, because a re-calibrating player is about to be served band 1 again.

**Why it does not feel like a test.** There is no assessment screen, no progress bar, no "finding your level" copy — there is no copy at all inside the play surface. Every calibration round is a real round: a win is inscribed in the Codex with its marks, a loss reveals a counterexample exactly as any other loss does. The ladder only ever ascends, so the felt experience while winning is *"the machine keeps getting stranger"*, and the round that ends calibration is an ordinary defeat. Calibration rounds are exempt from `consecutiveLosses`, `reach` and `relief` — the ladder already stops — and a calibration loss fractures nothing, because nothing was inscribed.

**Modes 2–4 never re-calibrate.** A player opening DRIFT for the first time is served at `core + 0 + modeBias`, i.e. their PROBE ability. That is the entire point of the offset decomposition: three of the four modes get a free, accurate cold start.

### 10.5 Per-axis abilities, and what the player perceives

Four serving parameters; five Profile axes; they are not the same list and must never be confused.

| Serving parameter | Mode | Profile axis it surfaces as | Second difficulty dimension driven by it |
|---|---|---|---|
| `core` | PROBE | **Induction** — sample and update rule per §11.9 | — |
| `core + drift` | DRIFT | **Flexibility** — §11.9 | swap point `N ~ U[3,6]` — fixed by canon, not adapted |
| `core + echo` | ECHO | **Retention** — §11.9 | load index `ℓ ∈ 1…8`, solved from `targetδ` by **§8.6's table**. Not defined here |
| `core + sieve` | SIEVE | **Tempo** — §11.9 | law band `1…6` plus tempo step `s ∈ {0,1,2,3}`, solved from `targetδ` by **§9.7's mapping**. Not defined here |
| — | — | **Restraint** — §11.9 | **no serving role at all** — descriptive only |

> **Decision:** this section names the second dimension and points at it. It does not define it. Reason: an earlier draft carried its own `L` and `r` formulas here, and they did not merely differ from §8.6 and §9.3 — their ranges did not overlap (`r` capped at 1.65 g/s here against 2.95 there) and both read `θ_echo` / `θ_sieve`, which §10.1 defines as **offsets defaulting to 0.0**, not absolute abilities, so `L` evaluated to the same constant for every player forever. One definition per quantity, in the section that owns the mode.

**SIEVE's cap is on the law, not on the ability.** The *law* band is capped at 6 (§9.3): a band-7 COMPOSITE law asks the player to hold two conceptual layers and a band-8 SYSTEMIC law asks them to rule out every simpler family first, and neither is learnable from a passive 45-second stream. Ability above that is absorbed by the tempo step, so the **effective** `band_SIEVE` reaches 7 at `δ_SIEVE = 0.874` — which is why step 8's clamp for SIEVE is `1…7` and step 6's is `δ ≤ 2.99`. `lastFamily` for a SIEVE round records `Family(lawBand)`, the family actually served, not the family of the effective band.

**Difficulty is never a number, and the reason is mechanical, not cosmetic.** A visible band label would name the **family** (§5.2 is a bijection band ↔ family), which hands the player the entire discovery cost `d` — 3 to 8 probes, up to a third of par (§5.4). Publishing the band would make the game measurably easier and the Rasch estimate unidentifiable. Secondly, a visible demotion after two losses is a second punishment stacked on the first. Thirdly, a number becomes the goal.

**The three signals the player actually gets — exactly three.**

1. **The length of the par tick row** (§5.4): 7 unlit ticks at band 1, 29 at band 8. Proportional, uncountable at a glance past ~7, reads as *"this is a long law"*. Par is deliberately **non-injective** — bands 5 and 6 both have par 23 and cap 37, so the most common relief move (6 → 5) is invisible in the instrument bar. And the tick row is not a stable read of ability in any case: the pressure term moves the served band on roughly half of all rounds (§10.3), so a shorter row this round is far more likely to be the ladder breathing than a verdict.
2. **The palette's ceiling**, locked by §4.4 to *lifetime maximum band + 1*, never the current round's band. It reads as capability acquired, not as an assignment received, and a veteran served an easy round sees no change in their toolbox.
3. **The Codex shelves** — eight, by family. The ladder is learned *retrospectively, from your own archive*, which is the only place difficulty is legible, and by then it is history rather than a verdict.

One ambient signal, sub-numeric by design: the Loom's procedural drone drops one scale degree every two bands (four steps across the ladder). Nobody derives "band 6" from a pitch, but the room does get lower as the laws get stranger. **Forbidden explicitly:** no band number, no percentage, no star rating tied to difficulty, no colour-coded difficulty, no "hard mode" toggle, no level-up moment, no post-round "difficulty adjusted" acknowledgement of any kind.

### 10.6 The daily Anomaly — global, therefore unadaptable

**The Anomaly's derivation lives in §11.6 and nowhere else.** That section owns the frozen `ANOMALY_SALT`, the `utcDayIndex` function, the no-`Calendar`/no-`Locale` rule, the SplitMix64 finaliser and the exact draw order — day index → `anomalySeed` → band draw → jitter draw → `generate`. This section deliberately states **no** band formula and **no** `targetδ` formula, because two derivations of a value whose entire justification is "identical for every player on Earth" cannot both be right, and the two that existed disagreed twice over: different bit-slices of the same seed give different bands, and one added a ±0.05 jitter the other forbade. The band is drawn from bands 4–7 and the round is otherwise an ordinary round of that band. It cannot be adapted, so **everything around it adapts instead.**

| Problem | Mechanism |
|---|---|
| Corrupts the estimate | **Anomaly rounds never update `θ`, `reach`, `relief`, `winStreak` or `consecutiveLosses`.** A band-6 loss by a band-2 player would drive `core` down two bands and take a week to recover. They do feed the Codex and the Profile. Asserted by H14. |
| Unbuildable for a beginner | The Anomaly **temporarily unlocks the full palette** for the duration of that round only, then reverts. Without this a band-2 player literally cannot express a band-6 law and the Anomaly is not merely hard but impossible. |
| Unreadable for a beginner | The Anomaly always grants the **Assay evidence overlay** (canon §4.3 unlocks it at band 4; the Anomaly is always band ≥ 4, so this is consistent, not an exception). |
| Demoralising to lose | Two independent records, **defined in §11.8 and named there**: the **tally**, a lifetime count of days sealed, monotone and un-loseable, drawn as the large numeral; and the **streak**, consecutive days sealed clean, forfeited by a strike (canon §4.5). The tally is the headline; the streak is a connoisseur's mark. A lost day costs the streak and takes nothing away. |
| Nothing to show for a loss | Hitting the cap reveals the true law in rule-tiles (§4.5). A band-2 player who spends 37 probes and then watches a band-6 GUARDED law assemble itself has had the single most instructive four minutes available in the game. |
| Trivial for a veteran | The mark is the global one (3 marks at ≤ 0.6·par), but the Anomaly page records **probes used** and the Anomaly shelf sorts by it. For a band-8 player the Anomaly is a probe-economy problem, which is the brief's own framing — *how few probes*. One strike breaks a 40-day clean streak; that is pressure enough. |

Determinism edge cases, decided: the date is **UTC**, read from the system clock, with no network authority available by construction. A clock moved *backwards* onto an already-played date renders that Anomaly read-only — it is in the Codex and cannot be re-marked. A clock moved *forward* skips days; the streak resets and is not restored. **Every past Anomaly remains playable forever** from the Codex, inscribed normally, but cannot retroactively extend the streak.

### 10.7 Anti-frustration — exact triggers

| Trigger | Response |
|---|---|
| 2 consecutive losses (any mode) | `relief = 1.00` — one full band. §10.3. |
| 3 consecutive losses | `relief = 2.00` — two full bands. Capped there. |
| Loss, and next round's band has the same `Family` | Band shifted down 1 (up 1 only if already at `minBand(mode)`), and `targetδ` re-derived to the new band's centre — §10.3 step 9 then step 11, in that order. No player gets three XORs in a row after failing one. |
| 3 consecutive losses **at band 1** (the floor — relief has nowhere to go) | **Floor rescue**: serve the family's deterministic anchor law (§5.3) — `freeAttributeCount = 3`, contiguous subset, `p ≈ 0.25`, minimum difficulty in the band — and unlock the Assay evidence overlay permanently for that player. At the floor, the *tooling* opens because the difficulty cannot close further. |
| 2 consecutive SIEVE losses | The tempo step `s` drops one notch (`−0.20` g/s on both `r₀` and `r₁`) and only if `s` is already `0` does `lawBand` drop — §9.7's rule, **speed is reduced before the idea is**. For that one round the ramp is also flattened to `r₁ ← r₀ + (r₁ − r₀)/2`, at no score cost. |
| Round **suspended** | Never scored, never updates `θ`, persists indefinitely (§5.4). Absence is never converted into a loss. |
| Round **abandoned** | The target is sticky: the next round in that mode is generated at the same `(band, targetδ)` from a different seed, so quitting buys a re-roll and never an easier law. In SIEVE the abandon is additionally scored as a foul-out at the last resolved glyph (§9.8), because there the exit is a confirmed two-tap choice rather than an interruption. |
| Cap reached | The law is revealed in rule-tiles. This is the designed relief valve and it is priced at more probes than solving costs, so it is never an exploit. |

**No cap relief, ever, and no par relief, ever.** Par feeds Tempo and cap feeds the failure signal the estimator needs; softening either silently would make the model unidentifiable and the Profile a lie.

### 10.8 Anti-boredom — exact triggers

| Trigger | Response |
|---|---|
| ≥ 8 wins in the last 10 rounds at band 8 with `δ` clamped at 3.99 | **Ceiling variation.** A third, tighter tick row appears: 3 marks now require `≤ 0.45·par` instead of `≤ 0.6·par`. The law does not change; the *scoring* does. Reverts after 3 losses of the tightened standard. |
| Same, plus band-8 lifetime solves > 150 (band 8 holds 337 laws — canon flags this honestly) | Within the generator's 200 attempts, the first 100 additionally reject any extension already in the Codex; attempts 101–200 fall back to the locked last-50 guard. Soft preference only — the locked constant is untouched. |
| Any converged player | The **pressure term** keeps three families in rotation with the modal one under 60 % of rounds and a same-family run of ≥ 5 on only 5–7 % of runs — measured, §10.3. Jitter is *not* the mechanism and is not claimed as one: it cannot cross a 1.000-logit band from centre. The daily Anomaly adds one off-ladder law from bands 4–7, denying the family pre-load once a day (§5.7). |
| Band clamped at `maxBand(mode)` for 3 consecutive rounds | **Ceiling rotation** (§10.3 step 10). At the top of the ladder `reach` is pinned and the pressure term stops rotating anything — measured at `θ_true = +6`, band 8 takes 89 % of rounds and the mean family run stretches to 4.7. One round a band down, at that band's upper near edge. |
| `min(drift, echo, sieve)` more than 1.0 logit below `core` | The mode sigil for the weakest mode renders at full luminance in the mode selector while the others sit at 60 %. A textless nudge toward the mode that still has slope in it. |
| Band 7/8 generation | Skeletons weighted toward high marginal deficit (`m2`, §5.1), keeping "vary one attribute and watch the lamp" dead where it is supposed to be dead. |

**What keeps hour 20 interesting** is not a difficulty number that keeps climbing — it cannot, there are eight bands. It is that at the ceiling the game silently changes question. Bands 1–6 ask *what is the law*; band 8 plus the tightened par asks *in how few probes*, which has no ceiling. The four modes multiply that by four different failure surfaces, and the Anomaly supplies one off-ladder law a day that nobody's estimate protects them from.

### 10.9 Absence and return

> **Decision:** **`θ` never decays. Confidence does.** Decaying ability would demote a returning player on their first round back — the most reliable way to lose them — and it would be false: a player who solved a band-6 GUARDED law in March has not forgotten how a guard works. What has decayed is the *evidence* that the estimate is still right, so what decays is `n`, which raises `K` and lets 2–3 rounds re-measure them.

On session start, per mode, with `gap` = whole days since the last scored round in that mode:

```
if gap > 7 {
    n[mode] = max(6, Int(Double(n[mode]) * exp(-Double(gap - 7) / 90)))
    relief  = max(relief, 0.5 * min(3.0, Double(gap) / 30.0))     // cleared on first win, or after 2 rounds
}
```

**Worked: a player returns after 92 days.** They left with `core = 1.20`, `n = 40`, sitting at band 4–5. `n → max(6, 40·e^(−85/90)) = 15`, so `K` rises 0.180 → 0.297. Re-entry relief `= 0.5 · min(3, 3.07) = 1.50`. Each row below is §10.3 steps 1–7 at zero jitter, including `π₀` and the `reach` the preceding wins have earned.

| Round back | `reach` | `relief` | δ | band |
|---|---|---|---|---|
| 1 | 0.00 | 1.50 | `1.20 − 1.386 + 0 − 1.50 − 0.44` = −2.13 | **2** — a comfortable, familiar win |
| 2 | 0.00 | 1.00 | −1.63 | 3 |
| 3 | 0.25 | 0.50 | −0.88 | 4 |
| 4 | 0.50 | 0.00 | −0.13 | 4 — full strength, four rounds |

The Codex is untouched, the palette is untouched, the Profile is untouched. Nothing was taken away while they were gone, and the ramp back is invisible — it reads as a short round, not as a demotion. Asserted by H15 (≤ 6 rounds to re-converge).

### 10.10 The simulated player harness

Two harnesses, because two different things need proving and they have runtimes three orders of magnitude apart.

**Level A — `ResponseHarness`.** Does not play. Given a served `δ`, draws `x ~ Bernoulli(σ(θ_true + ε − δ))` with `ε ~ N(0, 0.35²)` (day-to-day variance). Tests the estimator and the serving policy in isolation. **10⁶ rounds in < 0.4 s**; runs in the fast suite.

**Level B — `ReasonerHarness`.** Actually plays a generated law. Per round:

1. Receives `(band, par, cap, seedGlyph)` and the Loom. Never sees the law.
2. Prior `H` = union of the law sets of bands 1…`band`, weighted by a deliberately **mis-specified human family prior** `[0.34, 0.24, 0.06, 0.14, 0.10, 0.08, 0.03, 0.01]` (bands 5 and 7 sampled at 20,000 per §5.4). The mis-specification is the point: it is what *produces* the discovery cost `d` and what makes band 8 hardest despite having the smallest `|H|`. The harness must reproduce §5.4's par table, not be told it.
3. Probe: greedy maximum-expected-entropy-reduction over a random candidate set of size `m = clamp(round(4 + 28·σ(θ)), 4, 32)` — **ability enters as search breadth**, the honest model of what ability means here. With probability `(1 − σ(θ))·0.30`, substitute a Wason positive-test probe instead; ability reduces the bias.
4. Declare when posterior max mass `> τ = 0.55 + 0.35·σ(θ)`, or at `par + Poisson(2)` probes, or forced at cap. Declare the MAP hypothesis — but with probability `(1 − σ(θ))·0.25` the second-mass one (premature commitment). Verdict by extension comparison (§4.5).
5. On strike 1: ingest the counterexample as a hard constraint, filter `H`, probe up to `0.3·par` more, declare again. On strike 2 or cap: loss. Emit `(band, δ, probes, strikes, firstDeclCorrect, won)`.

**Runtime split, to protect `swift test` < 10 s:** Level B's full matrix (8 bands × 400 laws × 200 rounds = 640 k reasoning rounds, ~9 min) runs behind `HUNCH_CALIBRATION=1` in CI; the fast suite runs the 8 × 20 × 20 smoke subset (3,200 rounds, ≈ 0.8 s) plus all of Level A. **Every invariant below is a shipped assertion.**

| # | Invariant | Measurement | Pass |
|---|---|---|---|
| H1 | Convergence | `θ_true ∈ {−3,−2,−1,0,1,2,3,4}`, 400 rounds, 64 seeds each; \|θ̂₄₀₀ − θ_true\| | ≤ 0.35 all seeds; median ≤ 0.15 |
| H2 | Convergence speed | rounds until \|θ̂ − θ_true\| ≤ 0.5 and stays | ≤ 25 worst case, ≤ 12 median |
| H3 | **Target hold** | round success rate, rounds 26–400, over `θ_true ∈ {−1, 0, +1, +2, +3}` — the range in which an eight-band ladder can actually serve the target | **0.80 ± 0.03**. Excluded by construction, not by convenience: below `θ ≈ −2.2` the clamp at `δ = −4.00` cannot serve an easy enough law (H8 covers it) and above `θ ≈ +4` the clamp at 3.99 cannot serve a hard enough one (H9) |
| H4 | First-declaration rate | same window | 0.62 ± 0.05 |
| H5 | Counterexample recovery | `P(2nd declaration correct \| 1st wrong)` | 0.47 ± 0.06 |
| H6 | **No loss loop** | max consecutive losses over 10⁶ Level-A rounds | ≤ 6, and `P(run ≥ 4) < 0.004` |
| H7 | Relief efficacy | `P(win \| exactly 2 preceding losses)` | ≥ 0.86 |
| H8 | No trap at the floor | `θ_true = −5` (below band 1); win rate after floor rescue | ≥ 0.55 |
| H9 | No trap at the ceiling | `θ_true = +6`; win rate, modal band share, and *unforced* band changes | ≥ 0.88; band 8 modal with share ≥ 0.65; **zero** band changes on rounds where `reach`, `relief` and the ceiling rotation are all inert. The old form of this row asserted "band changes < 5 % of rounds", which measured relief and the ceiling rotation doing their jobs and would have failed on correct behaviour — at the ceiling `relief` alone moves the band on ~20 % of rounds. The oscillation it meant to catch is the *unforced* change, and that is what is asserted |
| H10 | **Difficulty calibration** | Spearman ρ between `difficulty(of:)` and Level-B per-law failure rate, θ fixed at 8 values, 400 laws/band × 200 rounds | ρ ≥ 0.75 overall; ≥ 0.45 *within* every band |
| H11 | Band monotonicity | mean failure rate across bands 1→8 at fixed θ | strictly increasing, no inversion; **band 8 > band 7** |
| H12 | Par fidelity | Level-B median probes vs. §5.4 par | within ±20 % per band |
| H13 | Purity / determinism | `(seed, θ_true)` → θ trajectory, across runs and processes | byte-identical |
| H14 | Anomaly isolation | 400 Anomaly rounds injected mid-run | `θ̂` bit-identical to the run without them |
| H15 | Absence | 90-day gap injected at round 200; rounds to re-converge | ≤ 6 |
| H16 | Boundedness | θ̂ range; NaN/Inf check | `[−6, +6]`, never non-finite |
| H17 | Mode independence | strong PROBE / weak SIEVE player, 120 SIEVE rounds | \|Δ̂_sieve − Δ_true\| ≤ 0.45 |
| H18 | **Pressure is centred** | `E[reach − relief]` over 10⁶ Level-A rounds at `θ_true ∈ {0, +2}`, and the realised success rate at `π₀ = 0.44` | `E[reach − relief] = 0.375 ± 0.02`; success `0.80 ± 0.01`. **Fails the build if `π₀` is stale** — this is the row that catches any future change to jitter width, the relief ladder or the reach schedule |
| H19 | Generator fallback rate | share of rounds falling back to the family anchor law (§5.3), per band, across the H1 convergence run | **< 2 % per band**. This is what catches a `targetδ` derived against the wrong band (§10.3 step 11) — the failure is silent in every other metric |
| H20 | **Palette sufficiency** | for every served round in the Level-B matrix *and* every calibration round: `paletteTileClasses ⊇ tileClasses(Family(servedBand))` | holds, 100 % — asserted at serve time, not at generation time |
| H21 | Family rotation | over 10⁶ stationary rounds at `θ_true ∈ {0, +0.35, +2}`: modal family share, and `P(same family ≥ 5 rounds running)` | modal share ≤ 0.62; `P(run ≥ 5) ≤ 0.10`. At `θ_true = +6` the same statistics are asserted **with** the ceiling rotation active |

H10 is the one that can fail honestly: if ρ drops below 0.75, **`difficulty(of:)` is wrong and the §5.1 modifier weights are regenerated from the harness** — the test is never weakened. H11's band-8 clause is the specific assertion that the family-based difficulty function beats an entropy-based one, since an entropy ranking puts band 8 below band 2.

**A passing run, numerically** (Level A, 400 rounds, 64 seeds, median across seeds, `π₀ = 0.44`). The 1st-decl column is not measured — it is the identity `firstDecl = (success − r)/(1 − r)` with the derived `r = 0.474` of §10.1, which is what makes H4 and H5 a single claim rather than two.

| θ_true | θ̂ @400 | rounds → ±0.5 | success | 1st-decl | max loss run | modal band |
|---|---|---|---|---|---|---|
| −3.0 | −2.98 | 7 | 0.636 | — | 6 | 1 |
| −1.0 | −1.12 | 7 | 0.796 | 0.612 | 3 | 2 |
| 0.0 | −0.07 | 12 | 0.800 | 0.620 | 2 | 3 |
| +1.0 | +0.89 | 10 | 0.800 | 0.620 | 2 | 4 |
| +2.0 | +1.92 | 11 | 0.800 | 0.620 | 2 | 5 |
| +3.0 | +2.86 | 7 | 0.800 | 0.620 | 2 | 6 |
| +4.0 | +3.93 | 10 | 0.803 | 0.626 | 2 | 7 |

**This table was regenerated after §10.3's `π₀` correction, and the correction is why it can exist.** Under the uncentred policy the success column read 0.749 flat and H3 could not pass at any `θ`; the table that used to sit here showed 0.783–0.831, which was not achievable by the policy printed beside it. The two edge rows are artefacts and are asserted rather than corrected: at `θ_true = −3.0` the served `δ` clamps at −4.00 and the ladder has no easier law, so the rate falls to 0.64 and H8's floor rescue is the mechanism that owns it (the 1st-decl identity does not apply below target and is left blank); at `θ_true = +4.0` the clamp at 3.99 binds in the other direction and `θ̂` under-estimates. Max loss run of 2 is not a bug — after two losses `relief` buys a full band and `P(win) ≈ 0.95`, which is H7 doing its job (measured 0.952 at mid-ladder, 0.870 near the floor).

### 10.11 The long arc

| Horizon | Rounds | What the player has |
|---|---|---|
| **1 session** (~12 min) | 4–6 | Calibration done. Median new player ends at band 3. 3–5 Codex pages on 2–3 shelves, probably one fracture. Palette shows Ramp plus one further stamp. They have met the Loom, the ribbon, the Dial, the Bench and the Seal without reading a word. |
| **1 week** (~7 sessions) | 35 | `θ` converged at 1–2; served band 3–6, modal 4–5. 25–30 pages. All three gated modes unlocked, in the order §9.10 fixes: DRIFT first, then ECHO, then SIEVE — this section quotes that row and states no threshold of its own. 7 Anomalies attempted, tally ≈ 5. |
| **3 months** (~200 rounds) | 200 | 150–190 pages across all 8 shelves. `θ` at 2–4, served band 4–8 with the mode around 6. Profile shape stable enough that its silhouette is recognisably *theirs*. A best clean Anomaly streak in the 4–12 range and a much larger tally. All four modes in rotation. |
| **Hour 20** (~600 rounds) | 600 | Band 8 fluent. The tightened par row is live. The game has become probe economy — which has no ceiling — plus one off-ladder Anomaly a day and three modes with different failure surfaces. Canon §5.7 states the honest limit: a player living at band 8 will eventually recognise rather than induce among 337 laws. The answer is the other seven shelves and the other three modes, not a ninth band. |

### 10.12 Retention mechanics: what is forbidden

Stated as a build constraint, not a preference. Each of these is a grep-able absence.

- **No lives, hearts, energy, stamina or cooldowns**, and **no timers as pressure or monetisation** — SIEVE's stream rate is a rule inside one mode, not a gate on play. A round is available whenever the app is open.
- **No daily-login reward, no login calendar, no "come back tomorrow" bonus. No FOMO** — every past Anomaly is playable forever from the Codex.
- **No streak-as-punishment.** Breaking the Anomaly streak costs that one counter and nothing else — no lost progress, no lost pages, no lost ability, no streak-freeze to buy (there is no IAP), no red badge. The tally, which is the headline, does not move at all. Both are records of what happened, not debts.
- **No notifications, at all.** Zero `UNUserNotificationCenter` usage. There is no server to notify from and no guilt to deliver.
- **No leaderboards, Game Center, social, sharing prompt or rating prompt. No XP, levels, numeric rank or visible difficulty** (§10.5). **No loot, gacha, cosmetic carrot or season.**
- **No cognitive, memory, focus, intelligence, performance or health framing anywhere** — not in copy, not in the Profile, not in the Codex, not in App Store metadata, not as a joke. The Profile is a self-portrait of how you play, and it says so by being a shape rather than a score.

**What is used instead**, and it is a short list: the **Codex**, an archive that only ever grows and is never taken away; the **Profile**, a slowly morphing shape rather than a chart; the **Anomaly**, a shared object rather than a competition; and the adaptive engine itself. An 80 % success rate held across 600 rounds *is* the retention mechanic. Everything above exists to make that number true without the player ever seeing it.
## 11. The Meta Layer — Codex, Anomaly, Profile

Three systems sit outside the round: **the Codex** (what you have found), **the Anomaly** (the one law everybody gets today), **the Profile** (the shape your play makes). All three are pure functions of locally persisted round records. None of them touches the network, none of them can be bought, and none of them gates content.

**Where the no-text rule ends.** Canon §2 fixes it for pixels inside the play surface. Extending it: the Codex *browse* hierarchy — root, shelf, thumbnail, facet bar, scrubber — is **textless by construction**, because that is where hundreds of items must be discriminated at a glance. Numerals and one localized date are permitted in exactly three places: the **instrument strip** at the foot of a single page view, the **statistics screen**, and the **Anomaly tally** (§11.8 draws it as the large numeral, and a count of days is the one fact the ribbon's 28 cells cannot carry). No glyph, rule-tile, Assay, shelf or Profile contour ever carries a word or a numeral.

> **Decision:** the app posts **zero local notifications** — no Anomaly reminder, no streak warning, no "come back". `UNUserNotificationCenter` never appears in the binary. Reason: every meta system here is a record of what you did, not a lever to make you do it, and a streak reminder is the exact mechanism that turns a collection into an obligation.

---

### 11.1 The Codex — what a page is

A **page** is one law, identified by its extension (canon §3.6: the extension *is* the canonical form). One law, one page, forever.

```swift
struct CodexPage: Codable {
    let lawKey: UInt64        // 64-bit hash of the extension — canon §3.6 dedup key
    let law: LawNode          // RNF AST. The table is never stored; it is rebuilt on open.
    let band: UInt8           // 1…8
    let skeleton: UInt16      // index into the family's skeleton list (canon §5.3 step 3)
    var firstFoundAt: Date
    var lastFoundAt: Date
    var firstFoundMode: Mode
    var modesSeen: UInt8      // bitset over Mode
    var timesFound: UInt16    // rendered as re-strike rings, capped at 5+
    var bestProbes: UInt16    // minimum over all finds
    var bestMarks: UInt8      // 1…3, Seal marks (canon §5.4)
    var unfractured: Bool     // ever declared correct on the first declaration, zero strikes
    var burnished: Bool       // latches true on an ECHO 3-mark round held on this law (§11.3)
    var driftPartner: LawNode?// DRIFT's L₁, from the first DRIFT find; never overwritten
    var driftHinge: UInt16?   // that find's t_hinge (§7.8). The pair is payload, never identity
    var anomalyDay: Int64?    // UTC day index, if ever found as the Anomaly
}
```

**A DRIFT page is keyed on `L₂` and carries `L₁` as payload.** §9.10 says a DRIFT page "carries both laws and the hinge" and §7.10 replays the reveal "from the page"; `driftPartner` and `driftHinge` are exactly what that replay needs. They are deliberately *not* part of `lawKey`: identity is `L₂`'s extension and nothing else, or the same law found twice behind two different dead laws would mint two pages and break §11.2's premise. They are written on the **first** DRIFT find and never overwritten, so the reveal a page replays is stable forever — the same rule that governs `firstFoundMode`.

**What a page stores, against what a round stores.** The page holds the resolved law and the bests; the `RoundRecord` (§6.10) holds `seed`, `targetδ`, the probe list and the outcome. `seed` is therefore **not** a page field — canon §3.6 and §5.4 both make the *law* the stored object and the seed a serving-layer input that does not survive a change in `avoid`. `skeleton` is a page field and not a round field, because §11.2 browses by it and recomputing it from the AST on every shelf open is 2,000 walks per scroll.

Storing the AST and not the table is canon (§3.6) and is what keeps the Codex small: a contextual table is 8 KiB, an AST is ~40 B. A page renders in three registers, all vector, all textless except the strip:

1. **The law**, in the Bench's own rule-tile grammar (Ramp / Bridge / Fork / Tally, coupler, ghost toggle, wedge), laid out by the same `Bench.layout(for:)` that G10 already guarantees round-trips. Read-only: no cell responds to touch, no Seal, no palette. At 0.78× the live Bench (291 pt rails → 227 pt). A **burnished** page draws those strokes in `accent.brass` rather than `stroke.primary` — the same brass the reveal's registration beat steps them to (§13.7.1 beat 4), so the state is already learned.
2. **The Assay**, the law's full extension at 9.5 pt cells (152 × 152 pt). For a contextual law it shows the marginal projection with a draggable ghost thumbnail; dragging pins `prev` and the constellation morphs. Same widget the player used to declare, so nothing new is learned.
3. **The instrument strip** — `bestProbes` as a tick row against that band's `par` (canon: 7/13/16/20/23/23/26/29) with the mono numeral beside it; Seal marks as 1–3 pips; the **fracture** hairline across the rim if `unfractured == false`; the mode sigil; a band notch; the **anomaly seal** (a doubled rim arc) if `anomalyDay != nil`; the find date via `Date.FormatStyle(.dateTime.year().month().day())`.

> **Decision:** re-finding a fractured page **clean** heals the fracture (`unfractured` latches true and the crack is not drawn). Reason: every other field on a page improves; a permanent scar for one bad first encounter contradicts the improvement loop and makes early rounds feel like they damage the archive.

### 11.2 Taxonomy and browsing

Three levels, all derived from structures canon already defines, all textless: **band → skeleton → canonical key.** Date is **not** a browsing axis; it is one field on a page and one facet.

- **Band** is the primary shelf, because canon locks exactly one family per band, so a shelf is a family and a family is a conceptual move. Eight shelves, no more, ever.
- **Skeleton** sub-sections a shelf. The generator already samples a skeleton per law (§5.3); the skeleton is the tile *silhouette* — "Bridge with a ghosted leading socket", "Fork on a hue gate", "two Ramps under a crossed coupler". A sub-section header is that silhouette drawn at 24 pt in the leading margin with a hairline divider. Large shelves get 10–40 sections; band 1 gets four (one per attribute).
- **Canonical key** orders within a section: `(attrOrdinal, cmpOrdinal, subsetBitmask)` in canonical `fill → shape → pips → hue` order. Deterministic, so a law's slot never moves.

**The thumbnail is the extension, not the syntax.** A 60 × 60 pt cell drawn as the 16 × 16 deck grid at 3.5 pt cells, in `glyphID` order — the Assay signature. Two consequences: no two thumbnails can collide (extension is identity), and a filling shelf becomes a wall of constellations whose texture is genuinely readable. Contextual laws (bands 5, 7) project: cell *i* carries the fraction of the 256 `prev` values under which glyph *i* is admitted, quantised to four levels drawn as **hollow / dotted / striped / solid** — the fill ink-density ladder from canon §2, reused, monotone, colour-free. Overlays on the cell: a 2 pt corner notch for a fracture, a doubled rim for an anomaly page, an unlit cell (dashed socket) for an empty slot.

**Screens.** Reference device 375 × 667, safe 375 × 647.

| `CodexRootView` | y | Detail |
|---|---|---|
| instrument bar | 20–64 | Codex sigil, active facet stamps |
| 8 shelf plates | 64–624 | 64 pt each + 6 pt gutter. Leading 44 pt family sigil · 3 pt fill arc · trailing 4 most-recent thumbnails at 40 pt · doubled rim when sealed |
| facet bar | 624–667 | 5 stamps at 44 pt: mode (cycles through 4 sigils + off), unfractured-only, anomaly-only, attribute-participation (four ramp headers), 3-marks-only |

| `CodexShelfView` | y | Detail |
|---|---|---|
| instrument bar | 20–64 | family sigil, fill arc, facet state |
| grid | 64–620 | 5 columns × 60 pt, 10 pt gutters (5·60 + 4·10 = 340 in 375), vertical scroll, ~45 pages per screen, skeleton dividers |
| rail scrubber | 64–620, trailing 12 pt | snaps to **skeleton sections**, not to pixels — the only way a 2,063-row shelf is navigable |
| back / facets | 620–667 | |

`CodexPageView`: 20–64 bar · 64–316 rule-tiles · 316–472 Assay · 472–540 instrument strip · 540–620 find log (up to 5 re-strike rings, each tappable for its date) · 620–667 prev/next. Horizontal swipe steps to the adjacent slot in canonical order, including empty slots on slot-map shelves — walking past the holes is the point.

**No global meter anywhere.** A "0.3 % of 27,015" bar would be both true and useless. Only per-shelf arcs exist.

### 11.3 Duplicates

The generator's G9 novelty guard is *last 50 laws* (canon §5.3). Band 1 holds 40 laws. Duplicates are therefore not an edge case, they are the steady state.

> **Decision:** a duplicate **never** creates a second page and is **never** refused as a round. It re-inscribes the existing page in place, improving `bestProbes`, `bestMarks`, `unfractured`, `modesSeen`, `timesFound`, `lastFoundAt`, and — on a first DRIFT find — writing `driftPartner` and `driftHinge`. Reason: refusing the round would require the serving layer to fail closed on small bands, and a second page would make the extension stop being the identity, which breaks the shelf's whole premise.

**Burnish, defined once.** A **burnish** is what a mode that cannot mint pages records on a page that already exists. Exactly one mode does it: an ECHO round settled at **3 marks** burnishes the pool law it was holding (§8.5, §9.10). Exhaustively, a burnish sets `burnished = true` and sets ECHO's bit in `modesSeen`. It does **not** touch `timesFound`, `bestProbes`, `bestMarks`, `unfractured` or `lastFoundAt` — those are properties of *finding* a law, and ECHO does not find one, it applies one. It is therefore not a re-find and draws no re-strike ring; the render is the brass rule-tile stroke of §11.1. `burnished` latches: there is no un-burnishing.

**Serving-layer soft-avoid, above G9.** For bands whose `|H| ≤ 512` — exactly bands 1 (40), 3 (108), 8 (337) — the avoid-set is the player's **entire found set for that band**; the generator's 200-attempt bound then falls through to a duplicate only when the shelf is complete. For bands 2, 4, 5, 6, 7 the avoid-set is the **512 most recent** found lawKeys for that band. The threshold is the same `|H| ≤ 512` that §11.4 uses to decide which shelves get a slot map, and deliberately so: the shelves you can see the holes in are exactly the shelves the server tries to fill. This turns collection from coupon-collector into near-sampling-without-replacement: band 8 completes in ~337 solves rather than the ~2,157 that 337·H₃₃₇ would demand.

**Round-end presentation of a duplicate.** The existing page flies in already inscribed and takes one additional **re-strike ring** on its rim (5 rings, then a single filled ring meaning 5+). If `probes < bestProbes` the tick strip re-flows to the new count with the law-declared-correctly haptic; if not, the page settles with no improvement mark and no negative signal. There is no "already collected" state, no dust, no converting duplicates into anything.

### 11.4 Why it is a collection and not a log, and what completion means

**The law space, computed from canon's grammar.** Syntactic upper bound before guardrails: 188 single terms (56 atomic + 36 relational + 96 contextual), plus 3 · C(188,2) = 52,734 coupled pairs, plus 8,736 guards and 1,214 aggregates ≈ **63k syntactic forms**. After RNF collapse, G1–G8 and cross-band de-duplication, canon §5.2 enumerates exhaustively:

`40 + 1,272 + 108 + 2,322 + 6,934 + 5,688 + 10,314 + 337 = ` **27,015 distinct laws.** That is the exact and permanent ceiling on Codex size.

So the space is *finite and modest*, not combinatorially unbounded — and the design must be honest about that rather than pretend to infinity.

> **Decision:** three shelves are **exhaustible and sealable** — bands 1 (40), 3 (108), 8 (337), total **485 pages** — and five are not. Reason: `|H| ≤ 512` is precisely the set of shelves where a full **slot map** (every law drawn as a permanent socket, empty ones dashed) is renderable and where a real terminal state is reachable in tens of hours rather than thousands. Bands 2, 4, 5, 6, 7 get **accretion shelves**: found pages only, log-scaled fill arc `log₂(1+n)/log₂(1+|H|)` with inscribed notches at n ∈ {8, 32, 128, 512, 2048, 8192}.

Cost of sealing all three, at par-rate play: 40 · ~1.5 min + 108 · ~4 min + 337 · ~8 min ≈ **53 hours**. That is the completion state, and it is the only one. There is no global 100 %, no prestige, no reset-for-a-star.

Five properties make this a collection rather than a log file: **permanent identity** (the extension — a page cannot be duplicated, renamed, or lost to a re-roll); **visible absence** (on slot-map shelves the holes are drawn — a log shows what happened, a map shows what is missing); **pages improve** (`bestProbes`, `bestMarks`, healing a fracture, `modesSeen` — a held page is never finished); **intrinsic rarity** (band 3 has 108 laws because XOR-of-two-pairs is a theorem, not because a designer assigned a tier — no drops, no rarity colours, no currency); and **the shelf is a picture of the law space** (canonical-key adjacency puts near-neighbours in extension space side by side, so a filling shelf develops readable texture).

### 11.5 Export and sharing

> **Decision:** there is **no share sheet, no share card, no image composer, no `UIActivityViewController`, no deep link.** Reason: the constraint is 100 % offline, and beyond that, a share affordance implies an audience, and an audience reintroduces exactly the comparison the Profile is designed to make impossible. The system screenshot already exists; `CodexPageView` is therefore composed to be screenshot-clean — full-bleed, no floating chrome, no modal, no transient overlay.

> **Decision:** there is **no export either** — no *write archive* row, no `hunch-codex-v1.json`, nothing in `Documents/`, and neither `UIFileSharingEnabled` nor `LSSupportsOpeningDocumentsInPlace` in `Info.plist` (§12.9 asserts the plist stays empty of both). Reason: "your data is yours" already has an answer that costs nothing and commits to nothing — `Application Support/Hunch/` is included in the device backup (§12.6), so a restored or migrated phone keeps its Codex intact. An exported file is a *published format*: the moment one exists, every future schema change owes it compatibility, for a v1 nicety with no reader on the other end. The app therefore never appears in Files, which is also the honest rendering of "no data leaves this device."

---

### 11.6 The Anomaly — derivation

One law per UTC day, identical for every player on Earth, with zero server.

```swift
// Days since 1970-01-01T00:00:00Z, floor semantics. No Calendar, no Locale, no TimeZone.
func utcDayIndex(_ t: TimeInterval) -> Int64 {
    let s = Int64(t.rounded(.down))
    return s >= 0 ? s / 86_400 : (s - 86_399) / 86_400
}
let ANOMALY_SALT: UInt64 = 0x48_55_4E_43_48_41_4E_4F   // "HUNCHANO" — frozen forever

func anomalySeed(day: Int64) -> UInt64 {              // SplitMix64 finalizer
    var z = UInt64(bitPattern: day) &+ ANOMALY_SALT
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    return z ^ (z >> 31)
}
```

**Date normalisation is the day index, never a formatted string.** Formatting drags in `Calendar` and `Locale`, which vary by device (Buddhist calendar, Islamic calendar, `ar-SA` defaults) and would silently give two players different Anomalies. Unix time has no leap seconds, so the arithmetic is total. Proleptic, monotone, one integer.

**Parameters, all derived from `seed`.** These three lines are the **single normative derivation of the Anomaly**; §10.6 states the same constants and must cite this block rather than restate it, because a globally shared law with two derivations is a coin flip at implementation time.

```swift
let band     = 4 + Int(seed % 4)                       // 4…7 uniformly, canon §5.7's off-ladder rule
let jitter   = Double(next() % 1001) / 10_000.0 - 0.05 // [−0.050, +0.050], next SplitMix64 draw
let targetδ  = 0.125 * Double(band - 1) + 0.0625 + jitter
```

`band = 4 + Int(seed % 4)` uses the **low** bits because it sits next to the `anomalySeed` finaliser, whose last step is `z ^ (z >> 31)` — the finaliser has already avalanched the low word, so no shift is needed and any variant spelling (`(seed >> 32) % 4`) selects a different band from the same day and is therefore wrong, not merely different.

The law is then `generate(seed: seed, band: band, targetδ: targetδ, mode: .probe, avoid: [])` — canon's five-argument pure generator with the novelty set **empty**, which is exactly how G9 is disabled: the Anomaly must not depend on the player's history, and canon §5.3 already routes all history through `avoid`, so nothing special is needed to switch it off. G1–G8 and G10 are active and unchanged.

> **Decision:** the Anomaly is always **PROBE**. Reason: ECHO's law is defined as "the law you learned last round", which has no referent for a standalone daily; SIEVE is the timed mode and would make a shared law a reflex contest; DRIFT's swap point is seed-derived and would work, but it makes the day's *par* incomparable between players. PROBE is the only mode where "how few probes" means the same thing to everyone.

> **Decision:** the Anomaly does **not** feed the Rasch ability estimate θ. Reason: it is served off-ladder at a band up to 3 above the player's, and canon §5.3 is explicit that off-band results poison the estimate. It **does** inscribe Codex pages, and it feeds Profile axes at 0.5 weight, never emitting an Induction loss-sample.

### 11.7 Attempts, the clock, and cheating

> **Decision:** **one attempt per UTC day.** The attempt is a full round with the standard two-strike structure, at the band's own par and cap from canon §5.7's locked row — **32, 37, 37 or 42** for bands 4–7 respectively, never a single number, since §11.6 draws band 4 as often as any other. Reason: the two strikes already are the second chance; unlimited retries make the shared law and the streak meaningless.

**The high-water rule** is the entire anti-cheat, and it is honest about what it can and cannot do.

```swift
struct AnomalyLedger: Codable {
    var v: Int
    var highWaterDay: Int64        // monotone. Never decreases. Never cleared by any user-facing reset.
    var entries: [DayEntry]        // last 400 only
    var streak: Int, longestStreak: Int, tally: Int
    var clockJumpCount: Int
    var anchor: MonotonicAnchor    // bootID + uptimeAtStamp + wallAtStamp
}
enum AnomalyOutcome: Int, Codable { case solvedClean, solvedFractured, failed, abandoned }
struct DayEntry: Codable { let day: Int64; let outcome: AnomalyOutcome; let probes: UInt16; let band: UInt8; let settledAt: Date }
```

On every launch and every foreground: `observed = utcDayIndex(now)`; `highWaterDay = max(highWaterDay, observed)`.

- **Today's Anomaly is playable iff `observed == highWaterDay` and no settled entry exists for that day.** Nothing else is ever playable.
- **Clock forward.** `highWaterDay` jumps with it, permanently. Every skipped day is recorded as `missed` on the next reconciliation and the streak resets to 0. You burn future days; you gain nothing, because there is only ever one playable day.
- **Clock back.** `observed < highWaterDay` puts the app in **`.clockBehind`**: the Anomaly tile locks, rendered textlessly as a full, static rollover ring with no pulse. It unlocks only when true wall-clock reaches `highWaterDay + 1`. Setting the clock back is therefore strictly worse than doing nothing — which is the only durable defence available without a server.
- **Jump detection.** `ContinuousClock` + `ProcessInfo.systemUptime` + a boot-session UUID give a monotonic anchor. If wall-clock advances by more than 120 s beyond monotonic elapsed within a session, `clockJumpCount += 1`. It is used only to refuse to *shorten* a lock. It never punishes, never wipes, never bans.
- **Reset immunity.** **No reset path of any kind touches `anomaly.json` or its `anomaly.hw` sidecar** — not the three content resets, not "Reset the ladder", and not "Reset everything", which deletes every other file in the tree (§12.6's DATA table, §11.13's file map). Otherwise reset *is* the clock exploit: wipe the ledger, and `highWaterDay` goes with it. Only deleting the app clears it, which also clears everything else — a fair floor. The migration fixture test asserts this directly: run every reset against the `Fixtures/v1/` tree and assert `anomaly.json` is byte-identical afterwards.
- **Timezone travel changes nothing.** The Anomaly is a function of the UTC day, so a flight from Auckland to Los Angeles alters only the local wall-time at which the day rolls over. A 24-segment rollover arc on the tile shows how far into the UTC day you are. This is the direct payoff of normalising on UTC rather than local midnight, and it is why local midnight was rejected: the UTC−12…UTC+14 span is 26 hours, so local-midnight rollover puts up to **three distinct dailies live simultaneously** and makes "the same law for everyone on Earth" simply false.
- **Day rollover mid-round.** The in-progress round runs to completion and is credited to the day it *started*. Today's Anomaly becomes available the moment it settles. An Anomaly round left unsettled when its day is no longer `highWaterDay` is recorded `abandoned`.

### 11.8 Streak, missed days, presentation

**Streak** increments only on `solvedClean` — correct on the first declaration, zero strikes. Canon §4.5 is explicit that a strike forfeits the Anomaly streak, and that is honoured exactly. Streak resets to 0 on any of: `solvedFractured`, `failed` (second strike or cap), `missed`, `abandoned`.

> **Decision:** the streak is **not** the headline. Two counters exist: **the tally** (lifetime `solvedClean` + `solvedFractured` days, never resets, drawn as the large numeral) and the **streak** (a secondary ring). Reason: canon's clean-only rule is severe, and a single harsh counter as the headline converts the daily into a loss-aversion device. The tally is monotone and un-loseable; the streak is the sharp edge for players who want one. No freezes, no repairs, no restores — there is nothing to sell and nothing to earn back.

**The Anomaly ribbon** is the whole history UI: 28 cells of the last 28 UTC days, one per cell, 11 pt each, textless and colour-free —

| State | Render |
|---|---|
| `solvedClean` | solid ring |
| `solvedFractured` | solid ring with a fracture notch |
| `failed` | hollow ring with cross-hatch |
| `missed` / `abandoned` | dashed empty ring |
| today, unplayed | pulsing hairline ring (static dash under Reduce Motion) |
| today, `.clockBehind` | full static ring, no pulse |

**Tapping a past cell reveals that day's law in rule-tiles, always** — including days you missed and days you failed. It costs nothing (regenerate from `anomalySeed(day:)`) and it makes a missed day interesting rather than a hole. Future days are not addressable; the ribbon has no cells beyond `highWaterDay`.

**The Anomaly ribbon lives on `AnomalyView`** (§12.2 screen 12), reached from the Frame's Anomaly key. Tapping today's cell starts the round; tapping a past cell opens its law in rule-tiles in place.

**Result, no leaderboard, no network — and no separate screen.** An Anomaly round settles onto the ordinary `InscriptionView` (§12.2 screen 8) with one appended strip, so win and loss keep the single round-end layout §12.1 decided on: the day's law animates in full rule-tiles; your probe count as a tick strip against the day's par with the par silhouette drawn beneath, so "how few probes" has a reference that is not another person; the 28-cell ribbon with today's cell newly inscribed; the tally numeral incrementing. No percentile, no distribution, no "you beat X %", no rank. None of those are withheld — they are unavailable, because the device knows about exactly one player and never will know about another.

---

### 11.9 The Profile — five axes, operationally

**This table is the single normative definition of all five axes.** Canon §5.4 names the *quantity* each axis reads — Tempo reads probe economy, Restraint the strike rate, Induction the band ladder, Flexibility DRIFT's re-declaration latency, Retention ECHO accuracy — and that naming stands. It does not fix a normalisation, a direction, a weight or an update rule, and this section does. The per-mode sections own the **transcript quantities** and nothing else: `R` and `t_evidence` (§7.8), `setF1`, `order`, `hit`, `A` (§8.7), gate-entry-to-tap latency (§9.6). Where any of those sections also states a sample formula or an EWMA, this table supersedes it — five axes with three spellings is the same defect as one law with two extensions.

**Direction is fixed by the geometry, not by taste.** §11.10 grows a vertex radius with its axis value, so every sample must be oriented *more is more of the thing the vertex is named for*. Tempo therefore samples `par/probes`, not canon's `probes/par`: the efficient player must be pulled **toward** the Tempo vertex, and §11.10's worked month-3 silhouette is drawn on exactly that convention. A test asserts monotonicity per axis: for each axis, a strictly better transcript never produces a smaller sample.

All five hold `value ∈ [0,1]` and a confidence count `n ∈ [0,60]`. All five are fed by per-round samples in [0,1] with a weight `w`.

| Axis | What it measures, precisely | Per-round sample | Feeds | w |
|---|---|---|---|---|
| **Induction** | how deep in the family ladder your settled rounds sit | solved: `(band−1)/7`; lost: `clamp((band−2)/7, 0, 1)` | PROBE, DRIFT, Anomaly | 1.0 / 0.5 |
| **Retention** | whether a law once established survives being carried | ECHO: `max(0, (hit − (\|answer\| − hit)) / A)` in §8.7's own symbols — credit for each lawful index placed, debited one-for-one by each intrusion, over the `A` that were there · PROBE: `1 − duplicatePairProbes/probes`, where a probe is a *duplicate pair* if its exact `(prev, cur)` ordered pair already appears in the ribbon | ECHO 1.0, PROBE 0.35 | |
| **Flexibility** | how fast a hypothesis that stopped working is abandoned | `clamp((2L* − L)/(1.5L*), 0, 1)`, where `L` is §7.8's `R` — probes from the first *contradicting* verdict to the sealing declaration — and `L* = 0.45·par(b)` (DRIFT hinge) or `0.30·par(b)` (first strike in any mode), on canon's `par(b)`, never `par_DRIFT` | DRIFT 1.0, strike-recovery 0.5 | |
| **Restraint** | declaring only once the evidence closes | `0.6·d + 0.4·m`. Discrete `d`: 1.00 solved clean, 0.60 cap-loss with zero strikes, 0.35 solved after one strike, 0.00 lost on the second strike. Margin `m = clamp(1 − log₂(H_live)/log₂(\|H_band\|), 0, 1)`, `H_live` = laws in the band's set still consistent with the whole ribbon at the moment of declaration | all settled rounds | 1.0 |
| **Tempo** | probe economy — probes spent against par | solved: `min(1, par/probes)`; lost: `0.5·min(1, par/probes)`; SIEVE: `clamp01(1 − median(gate-entry-to-tap latency) / mean window)` over hits only, §9.6's quantity verbatim | PROBE/DRIFT/Anomaly 1.0, SIEVE 0.7 | |

`par` always means the mode's own par: canon §5.7's `par(b)` in PROBE and the Anomaly, §7.7's `par_DRIFT(b)` in DRIFT. **SIEVE emits no Tempo sample at all** when the run used §9.8's VoiceOver step mode or the *steady stream* setting — both fix `r`, so the latency is not comparable and a sample would be a measurement of the setting rather than of the player. It still emits Induction and Restraint.

`H_live` is only computable where a materialised stateless hypothesis set exists — canon's lower-band index covers bands 1, 2, 3, 4, 6, 8. For bands **5 and 7** the margin term is skipped and Restraint uses `d` alone. Cost at band 4: 2,322 tables × a 4-word compare ≈ 50 µs, once per declaration.

> **Decision:** **Induction is a mean of settled rounds, not a running maximum**, overruling the plainest reading of canon §5.4's "highest band cleared". Reason: §11.10 normalises radii against the player's own five-axis mean, so an axis that can only ratchet upward eventually dominates the silhouette for reasons that have nothing to do with how the player plays; and one lucky band-8 clear would permanently redraw the portrait, which is the definition of a trophy. The mean of `(band−1)/7` over settled rounds says *where you live*, which is what a self-portrait is for. Highest-band-cleared survives as a fact — it is legible from the Codex shelves (§10.5's third signal), where it is history rather than a level.

**Update rule.** `value += α · (sample − value)` with `α = w · max(0.06, 1/(n+1))`, then `n = min(60, n + w)`. Robbins–Monro, and it is the **only** update rule for any axis: it subsumes a fixed-α EWMA (which is its `n → ∞` tail), it is fast while the portrait is unformed and slow once it is, and the 0.06 floor means it never freezes. `lastSampleAt` is stamped.

**Worked, against §7.7's DRIFT transcript.** Band 5, `par(b) = 23`, `R = 27 − 11 = 16`. `L* = 0.45 · 23 = 10.35`; sample `= clamp((20.70 − 16) / 15.525, 0, 1) = **0.303**`. With `n = 12` and `w = 1.0`, `α = 0.077`.

**Idle handling.** No decay of `value` toward anything. Instead confidence decays: `n = max(4, n · pow(0.5, daysIdle/60))`. Coming back after a long gap makes the portrait *more responsive*, not *lower*. A decay toward the mean would read as punishment for not playing, which is the same lever as a streak reminder.

### 11.10 The Profile — geometry

Five vertices at `θ_i = −90° + i·72°`, locked order clockwise from the top: **Induction (−90°), Retention (−18°), Flexibility (54°), Restraint (126°), Tempo (198°)**. Card 375 × 280 pt, centre (187.5, 140), `R0 = 96 pt`.

**The load-bearing rule: radii are normalised against the player's own five-axis mean, so the portrait cannot grow.**

```
v̄  = mean(v₀…v₄)
rᵢ = R0 · clamp(0.55 + 0.45 · vᵢ / max(0.15, v̄), 0.35, 1.55)
```

A uniform rise across all five axes leaves the shape **pixel-identical**. Only asymmetry is visible. You cannot inflate the portrait; you can only bend it. This makes "not a grade" a property of the geometry rather than a rule about copy.

- The five points are joined by a **closed Catmull–Rom spline** (tension 0.5, converted to cubic Bézier). A smooth closed curve, not a polygon — a polygon with vertices reads as a radar chart, and a radar chart reads as a score.
- **No gridlines, no concentric rings, no ticks, no axis labels, no numerals.** Five hairline spokes at 12 % opacity, nothing else. Gridlines are precisely what make a radar chart measurable.
- Ink: 2 pt brass contour; interior fill 6 %; a 1.5 pt inner offset contour at 20 % opacity for depth. High-contrast theme: contour to foreground, fill to 0 %, spokes to 25 %.
- **Confidence renders as tremble, not as size.** Each vertex radius carries `+A·noise(t, i)` with `A = R0 · 0.05 · (1 − min(1, nᵢ/24))` and a 0.6 Hz value-noise. Under Reduce Motion, tremble becomes a static dash pattern whose gap length scales with `A`, and all motion below becomes a 0.35 s crossfade.
- **Between-session morph.** The portrait never animates during play. On entering the Profile screen a `phaseAnimator` runs 2.4 s: the previous session's contour holds 0.4 s → each vertex springs to its new radius on a staggered delay of `i · 0.06 s` (response 0.9, damping 0.85) → the contour settles and tremble amplitude updates.
- **The ghost.** The portrait as it stood 90 days ago, drawn behind at 12 % opacity, 1 pt, dashed. Unlabelled. It is the only temporal comparison in the app, it is self-to-self, and because radii are mean-normalised it can only show *change of shape*, never growth.

**Day 1 vs month 3.**

| | Geometry |
|---|---|
| **Day 1**, 0 rounds | all `vᵢ = 0`, `v̄` guarded to 0.15 → all `rᵢ = 52.8 pt`. A small regular pentagon-spline, trembling at 4.8 pt amplitude. Reads as *unformed*, not as *zero*. No ghost. |
| **Week 1**, ~25 PROBE rounds | Induction/Restraint/Tempo at n≈25, tremble ~1 pt; Retention and Flexibility still starved at n≈2, tremble at full 4.8 pt. Radii spread ±15 %. A wobbling, lopsided blob. |
| **Month 3**, ~400 rounds, all modes | every n at the 60 cap, tremble 0, contour crisp and still. A player who probes exhaustively and never strikes reads as pulled toward Restraint (`r ≈ 148 pt`) and away from Tempo (`r ≈ 62 pt`) — an unmistakable silhouette, held steady across sessions, with the 90-day ghost showing the rounder earlier form. |

### 11.11 The Profile — why it cannot read as a grade

Eight rules, all enforceable:

- **P1** Radii are mean-normalised (§11.10). Uniform improvement is invisible. There is no "bigger".
- **P2** No gridlines, rings, ticks, or numerals anywhere on the portrait.
- **P3** **The axis names never appear in the app.** *Induction, Retention, Flexibility, Restraint, Tempo* are internal identifiers used in code and in this document only. Each vertex carries a small vector sigil drawn from the game's existing vocabulary: Induction = a ramp silhouette, Retention = a link arc, Flexibility = the Fork's railway switch, Restraint = the Seal's bar, Tempo = a tick strip.
- **P4** No other person's data exists on the device. Comparison is not suppressed; it is unavailable.
- **P5** No time series of any axis. The 90-day ghost contour is the only history, and it shows shape, not level.
- **P6** The portrait is **never shown at round end**. It lives only on the Profile screen, entered deliberately. A per-round readout is a grade by any other name.
- **P7** No notifications reference the Profile, or anything else (§11).
- **P8** A shipped test greps every value in `Localizable.xcstrings` across all 12 languages against a per-language banned-lexeme list and fails the build on a hit.

**VoiceOver, the only place the axes are described in words.** Five approved, localized, behavioural strings — descriptions of what you did, never of what you are. **The sentence *is* the vertex's accessibility label**; the identifier is not spoken, not a fallback, and never enters `Localizable.xcstrings`, so the five words below appear nowhere a translator or a player can reach them. That is what makes P8's banned-lexeme grep survivable: *Retention* and *Flexibility* land on "memory" and "ability" in several of the twelve languages, which are two of the words P8 fails the build on.

| Vertex | Approved VoiceOver string |
|---|---|
| Induction | "How deep in the machine's law families your finished rounds sit." |
| Retention | "How often you re-ask a question the ribbon already answered." |
| Flexibility | "How many probes you spend after a verdict contradicts your theory." |
| Restraint | "How often you declare before the evidence closes." |
| Tempo | "Your probes against par." |

**Approved framings, anywhere in the app, the App Store listing, or metadata:** "a machine with a hidden law"; "how few probes can you do it in"; "the shape your play makes"; "your Codex"; "probe economy"; "the archive of laws you have found"; "a self-portrait, not a score".

**Banned outright, in all 12 languages, including in jest:** brain, mind, mental, cognitive, cognition, IQ, intelligence, smart, memory, recall, focus, attention, concentration, sharpen, boost, train, training, workout, exercise, improve, improvement, decline, age-related, health, therapy, performance, productivity, skill, skill level, ability, aptitude, talent, rank, ranking, grade, level, score (of the Profile), percentile, benchmark, "get better", "stay sharp", "keep your mind". The FTC's 2016 Lumosity order is the reason this list is a build-failing test and not a style guide.

---

### 11.12 The statistics screen

`StatisticsView` (§12.2 screen 13), reached from the Profile's instrument bar — the numeric counterpart sits one tap from the wordless one, and nowhere else. Chrome, so localized labels and numerals are permitted; every number is formatted with `Date.FormatStyle` / `NumberFormatter` / `Measurement`, never string arithmetic. Instrument-panel layout, mono numerals, thin rules. Five sections — MODES · ROUNDS · BANDS · CODEX · ANOMALY — 19 labelled rows and column heads, budgeted in §12.9.

**Tracked and shown:** rounds played per mode (4); rounds settled solved / lost on second strike / lost at cap; total probes; twins used; duplicate-pair probes; strikes taken; fractures currently standing; per band (8 rows) rounds served, solve rate, best probes against par; Codex pages held and per-shelf fill with sealed shelves marked; Anomaly tally, current streak, longest streak, 28-day ribbon; longest and current run (consecutive solved rounds in one sitting; Anomaly rounds do not count toward a run). **Not tracked at all:** session duration, time of day, days-opened heatmap, launch count. No `θ`, no `difficulty`, no band number framed as a level (canon: never surface a numeric difficulty), no percentile.

> **Decision:** no usage-time or usage-calendar statistic exists. Reason: a days-played heatmap is an engagement-pressure device and is the closest this app could come to a habit-manipulation surface. Only facts about *play* are counted, never facts about *attendance*.

**This screen is read-only.** Every destructive action lives in one place, Settings → DATA (§12.6), so that the reset set can be enumerated, alerted and tested once. Three of the five are the content resets this section's data belongs to — **Clear statistics** (`stats.json`), **Clear Codex** (`codex-b1…b8.json` + `codex-index.json`), **Reset Profile** (`profile.json`) — and each is independent of the other two: clearing the Codex does not clear the counters that say what you found, and resetting the Profile does not touch a page. None of the five touches `anomaly.json` or `anomaly.hw` (§11.7).

Two consequences worth stating rather than discovering. **Clear Codex empties ECHO's pool**, so ECHO and SIEVE re-lock at §9.10's page gates — ≥ 5 and ≥ 8 — which are honoured in both directions. And **Clear Codex does *not* touch the palette ceiling**: §10.4 derives that from `maxBandEverServed`, which lives in `ServingState` in `ladder.json`, not from the archive. Only **Reset the ladder** (or **Reset everything**) drops the palette back to its band-2 opening state. The two are deliberately separable — a player clearing a shared device's Codex keeps the toolbox they earned, and a player resetting the ladder to re-calibrate keeps their pages.

### 11.13 Persistence, versioning, failure

`Application Support/Hunch/` — `Codable` JSON, atomic writes, behind the `PersistenceStore` protocol, injected. **This tree is the only on-disk layout in the document.** There is no `state.v1.json`: a single monolith would have to parse the whole worst-case 3.8 MB Codex at every launch to read a 40-byte suspended round, and deleting it would take the Anomaly ledger with it (§11.7). Ten kinds of file — seventeen on disk once the eight shelves and the `anomaly.hw` sidecar are counted — each with one owner and one reset.

| File | Contents | Notes |
|---|---|---|
| `manifest.json` | `{ schema: Int, createdAt, lastWriteAt }` | single global `schema`; every other file echoes `v` for validation |
| `codex-index.json` | `[UInt64]` lawKeys + per-band counts | 27,015 × 8 B = 216 KB worst case. Loaded at launch; the dedup authority. |
| `codex-b1.json` … `codex-b8.json` | `[CodexPage]` | **loaded lazily**, only when a shelf opens. Worst case 27,015 × ~140 B ≈ 3.8 MB across all eight — never parsed at once. |
| `anomaly.json` | `AnomalyLedger` | `entries` capped at 400 (~16 KB); aggregates kept forever. Reset-immune. |
| `profile.json` | 5 × `Axis` + `ghost: [Double]` + `ghostTakenAt` + `lastRenderedRadii` | < 1 KB |
| `ladder.json` | `Ability` (θ core + three mode offsets, `n`, `lastPlayed`), `ServingState` (reach, relief, streaks, `lastFamily`, `calibrationRound`), the 50-entry novelty ring of solved extension hashes (canon G9), the 8-entry lost-law cooldown ring (§6.10), `OnboardingLedger` | < 2 KB. Everything the serving layer needs and nothing the player can see |
| `stats.json` | the counters §11.12 renders, plus a 200-entry `recentRounds` ring of `RoundRecord`s | < 40 KB. The counters are authoritative and monotone; the ring is for the statistics screen's run figures and the harness, and is never the source of an aggregate |
| `round.json` | the one suspended round: canon §5.4's **resolved `LawNode`** (plus `lawHash` as a corruption check only, never as the source of truth), the probe list, strikes, the Bench draft, and the mode's own extra state (§7.10's DRIFT fields, §8.9's ECHO snapshot) | written after every probe; smallest file, written first |
| `lowerBandIndex.bin` | 9,767 tables, 305 KB, plus the 138 KB contextual hash index | derived; `isExcludedFromBackupKey = true`, set **here and nowhere else**; regenerated if absent or corrupt |

**The reset map — five actions, one row each, all in Settings → DATA (§12.6).**

| Action | Effect on the tree |
|---|---|
| Clear statistics | `stats.json` rewritten to zeros |
| Clear Codex | `codex-b1…b8.json` deleted, `codex-index.json` rewritten empty |
| Reset Profile | `profile.json` rewritten to day-1 defaults (all `v = 0`, `n = 0`, no ghost) |
| Reset the ladder | `ladder.json` rewritten: ability undefined (`calibrationRound = 1`), serving state zeroed — `maxBandEverServed` included, so the palette returns to its band-2 opening state — both rings emptied. **The Codex is kept** |
| Reset everything | every file **except `anomaly.json` and `anomaly.hw`** deleted, including `lowerBandIndex.bin`; `hunch.settings.*` cleared except `languageTag` and `theme`; onboarding re-arms from beat 0 |

No path deletes the directory itself, and no path writes to `Documents/` — there is nothing there (§11.5).

**Migration.** `schema` starts at 1. Additive fields decode with `decodeIfPresent` and a default; removed fields are tolerated; any semantic change bumps `schema` and gets an explicit `migrate_vN_to_vN+1(directory:)`. Migration is transactional: write the whole new tree into `Hunch.staging/`, `fsync`, then atomically replace the directory. A checked-in `Fixtures/v1/` tree must load green under every future build — this is the brief's persistence-migration test and it never gets regenerated to make a build pass. The same fixture carries the reset assertions: run each of the five actions above against a copy and assert the exact file set that survives, with `anomaly.json` and `anomaly.hw` byte-identical in all five.

**Failure states.**

| Failure | Behaviour |
|---|---|
| A shelf file fails to decode | quarantined to `corrupt/`, rebuilt empty. `codex-index.json` still holds the lawKeys, so *page detail* is lost but "already found" is not — the shelf meter and dedup survive. |
| `codex-index.json` fails to decode | rebuilt by scanning the eight shelf files. Cost ≈ 200 ms worst case, once. |
| `profile.json` fails to decode | reset to day-1 defaults (all `v=0`, `n=0`). The portrait re-forms; nothing else is affected. |
| `ladder.json` fails to decode | rewritten to the cold-start state: ability undefined, `calibrationRound = 1`, rings empty. §10.4's five-round gallop re-runs, which is the correct recovery — the Codex proves what the player can do, so calibration converges in one sitting. |
| `anomaly.json` fails to decode | `highWaterDay` is recovered from a 16-byte sidecar `anomaly.hw` written on every mutation; entries reset. Never recovered as a *lower* value. |
| Disk full on an atomic write | in-memory state is retained, one non-modal instrument warning is shown, the write is retried at the next round end. `round.json` is written first and is the smallest file, so an in-progress round is the last thing to be lost. |
| App killed mid-round | resume from `round.json`, including mid-Anomaly (canon §5.4). |
| Two devices | nothing to reconcile. No iCloud, no CloudKit, no sync — by constraint. |
| Clock set forward by years | `highWaterDay` jumps; intervening days are reconciled as `missed` **without** allocating an entry per missing day (the ribbon derives `missed` from absence, not from a stored record); streak = 0. Not recoverable, and stated plainly rather than papered over. |
## 12. Screens, Navigation, Onboarding and Settings

### 12.1 Naming the shell

The Loom, the Bench, the Codex, the Profile and the Anomaly are locked (§2). The container that holds them is not, so:

> **Decision:** the home screen is **the Frame** — because a loom's frame is the thing every other part is mounted on, it extends the machine metaphor instead of importing a menu metaphor, and it is the only word in this section that needs inventing.

> **Decision:** the round-end screen is **the Inscription**, in both outcomes — because §5.4 already says a correct declaration "is inscribed", and giving win and loss the same screen (differing only in whether a page is minted) removes a whole failure-state layout and makes losing feel like a reading rather than a punishment. "Verdict" is reserved for `admit`/`reject` and is never used for a round result.

### 12.2 Screen inventory

Eighteen screens. Every one is portrait-only, dark-first, and none of the play surfaces render a single character.

| # | Type | Purpose | Contents | Entry | Exit | **Primary action** |
|---|---|---|---|---|---|---|
| 1 | `LaunchSurface` | cover the cold-start hitch | wordmark HUNCH, one brass hairline, dark ground. Storyboard, no code | process launch | auto, ≤ 400 ms | none |
| 2 | `FrameView` | choose a mode; reach everything | mode rack (4 keys), shelf (Codex, Profile), Settings key, Anomaly key, the idle Loom | launch (returning player), any Frame key | a mode key, or any shelf key | **tap a mode key → round starts** |
| 3 | `RoundView` | the PROBE / DRIFT play surface | instrument bar, throat, ribbon, Dial (4 ramps), Bench handle, commit bar (§4.1 layout) | Frame mode key, Inscription *again* key, cold launch with a suspended round | Seal (via Bench), cap reached, leading chevron | **tap PROBE** |
| 4 | `EchoRoundView` | the ECHO play surface | §8.4 verbatim: primer strip (`m` glyphs with verdict rings, on screen all round), the rail, the 4 × 4 tray of 84 × 72 pt cells, commit bar = twin/replay (leading) + Seal (trailing). **No Dial, no PROBE key, no Bench.** During the cast: the throat at 64–176 and a **dark ribbon** — a cast is not probing and the Loom does not log it | Frame ECHO key | Seal, or chevron | **tap a tray tile → it lifts to the trailing end of the rail** |
| 5 | `SieveRoundView` | the SIEVE play surface | §9.2 verbatim: lip (64–96) · lane (96–420) · **gate (420–508, the only actionable region)** · sump (508–556) · tail (560–604, last 6 resolved glyphs) · commit bar = pause (trailing), which gains the abandon chevron **only while paused**. Instrument bar carries three foul ticks and the stream progress arc — **no lawful count anywhere**, it would leak the law's admit rate `p` | Frame SIEVE key | stream exhausted, third foul, or the paused chevron (**abandons**, scored as a foul-out — §9.8) | **tap the gate band** (375 × 88 pt) |
| 6 | `BenchView` | assemble and commit a declaration | rails, palette, coupler, Assay column, the Seal (§4.2 layout) | Bench handle pull-up, or the Bench key in the commit bar | the Seal, or pull-down | **tap the Seal** |
| 7 | `AssayInspectorView` | read the draft's extension at size | full-screen 16×16 grid at 23 pt cells, read-only, ghost scrubber for contextual drafts | tap the Assay | tap anywhere, or pull-down | none (read-only); dismiss |
| 8 | `InscriptionView` | deliver the law-reveal and the score | staggered rule-tile reveal of the true law, its Assay with the ribbon overlaid, Seal marks, probes-vs-par ticks, fracture mark. On an Anomaly round, the 28-cell ribbon and the tally strip append below (§11.8). **No Profile readout of any kind** — §11.11 P6 | Seal (correct), second strike, cap reached | *again*, Frame key, or minted-page key | **tap *again* → next round, same mode** |
| 9 | `CodexRootView` | choose a shelf | 8 shelf plates (family sigil, fill arc, 4 recent thumbnails), facet bar of 5 stamps (§11.2) | Frame shelf, Inscription minted-page key | tap a shelf, back, or play key | **tap a shelf plate** |
| 10 | `CodexShelfView` | browse one band | 5-column thumbnail grid, skeleton dividers, rail scrubber snapping to skeleton sections (§11.2) | tap a shelf plate | tap a thumbnail, back, or play key | **tap a thumbnail** |
| 11 | `CodexPageView` | inspect one law | full-scale rule-tiles, that law's Assay, the instrument strip (probes vs par, marks, fracture, mode sigils, band notch, date), find log | tap a thumbnail | back, swipe to the adjacent slot, or play key | none; dismiss |
| 12 | `AnomalyView` | today's law, and the last 28 days | 28-cell ribbon, tally numeral, streak ring, 24-segment rollover arc, `.clockBehind` lock state (§11.8). Textless but for the title | Frame Anomaly key | tap today's cell → the round; back, or play key | **tap today's cell → the Anomaly round starts** |
| 13 | `StatisticsView` | the numbers, in one place | 5 sections, 19 labelled rows and column heads (§11.12). Read-only — every reset lives in Settings | Profile instrument bar | back, or play key | none; dismiss |
| 14 | `ProfileView` | show the five-axis self-portrait | morphing spline, **five vector vertex sigils** (§11.11 P3 — never the axis names), stat block (5 rows), the 90-day ghost | Frame shelf | back, statistics key, or play key | none; dismiss |
| 15 | `SettingsView` | every preference | 7 sections, 19 rows (§12.6) | Frame Settings key | back, or play key | none |
| 16 | `AboutView` | version, privacy, licences | version, build, "no data is collected", copyright, storage-status indicator | Settings row | back | none |
| 17 | `ResetConfirmAlert` | guard the five destructive actions | title, body, destructive verb, shared cancel. **Five variants**, one per DATA row (§12.6) | Settings row | either button | **cancel** (default focus) |
| 18 | `SievePauseOverlay` | freeze a timed run safely | 70 % scrim, frozen lane, three retracting arcs on resume. The commit bar gains the abandon chevron here **and only here** (§9.2) | `scenePhase != .active` during SIEVE, or the pause key | tap the gate, or chevron ×2 | **tap the gate to resume** |

Not screens, deliberately: no tutorial, no tooltip, no coach mark, no difficulty picker, no leaderboard, no store, no account, no share sheet, no "rate us", no onboarding carousel, no empty-state copy. The Codex with zero pages draws one dashed plate and nothing else.

### 12.3 Navigation map

```
                              ┌──────────────────┐
   cold launch ──────────────▶│  LaunchSurface   │
                              └────────┬─────────┘
                     suspended round?  │
              ┌── yes ─────────────────┴──── no ──┐
              ▼                                   ▼
   ┌─────────────────────┐  chevron ┌───────────────────────────────┐
   │  RoundView (resume) │◀─────────│           FrameView           │
   │  EchoRoundView      │─────────▶│  ▸ PROBE  ▸ DRIFT             │
   │  SieveRoundView     │  chevron  │  ▸ ECHO   ▸ SIEVE   ▸ Anomaly │
   └──┬──────────────┬───┘           │  ▸ Codex  ▸ Profile ▸ Settings│
      │ handle       │ cap / 2nd     └─┬───────┬───────┬────────┬───┘
      ▼              │ strike          │       │       │        │
 ┌──────────┐        │                 ▼       ▼       ▼        ▼
 │BenchView │        │        ┌─────────────┐ ┌─────┐ ┌────────┐ ┌────────┐
 │  ▸ Assay │        │        │CodexRootView│ │Anom.│ │Profile │ │Settings│
 └──┬───┬───┘        │        └──────┬──────┘ └──┬──┘ └───┬────┘ └───┬────┘
    │   │ Seal       │               │           │        │          │
    │   ▼            ▼               ▼           │        ▼          ▼
    │ ┌──────────────────┐   ┌──────────────┐    │  ┌──────────┐ ┌────────┐
    │ │  InscriptionView │──▶│CodexShelfView│    │  │Statistics│ │ About  │
    │ └───┬─────────┬────┘   └──────┬───────┘    │  └────┬─────┘ └───┬────┘
    │     │ again   │ Frame         ▼            │       │           │
    │     │         │        ┌─────────────┐     │       │           │
    │     │         │        │CodexPageView│     │       │           │
    │     │         │        └──────┬──────┘     │       │           │
    │     └────┐    └───────────────┴────────────┴───────┴───────────┴──▶ Frame
    ▼          ▼
 AssayInspector  (new round, same mode)
```

**Every non-play screen carries a play key** — a 44 × 44 throat sigil in the trailing corner of its instrument bar (screens 9–15; not on 16, 17, 18). Tapping it resumes the suspended round if one exists, otherwise starts a new round in the last-played mode.

**Tap-distance audit (the ≤ 2 rule):**

| From | Taps to a live probe surface |
|---|---|
| Cold launch, suspended round | **0** — the app opens in the round |
| Cold launch, no suspended round | 1 (mode key) |
| Frame | 1 |
| Inscription | 1 (*again*), 2 for a different mode (Frame → mode key) |
| Codex root, Codex shelf, Codex page, Anomaly, Statistics, Profile, Settings | 1 (play key), 2 for a different mode |
| About, Assay inspector, Reset alert | dismiss, then play key → **2** worst case |
| SievePause | 1 |

Worst case in the entire app is two taps. Enforced by `NavigationDepthTests`: a graph walk over the route table asserts `distanceToPlay(screen) ≤ 2` for every reachable screen, and fails CI if a new screen is added without one — which is why the Codex's three levels cost nothing: every one of them carries the play key.

**Exactly one path is three deep, and it is the Codex** — root → shelf → page (§11.2). That is a drill-down through a spatial hierarchy the player can see the whole of (8 shelves, then a grid, then one law), not a menu tree, and the alternative — a flat 27,015-slot grid — is the thing §11.2 exists to avoid. Everywhere else is at most two: `NavigationStack` is used twice, in the Codex and in Settings (→ About), and Profile → Statistics is a push with the same play key on both ends. Everything else is a full-surface transition or a sheet. Reason for the rule at all: a back-stack you can get lost in is the failure mode of menu-driven design, and this app has nine destinations.

### 12.4 The Frame

Reference device, iPhone SE 2/3, 375 × 667 pt, safe 375 × 647 (§5.7).

| Region | y | Contents |
|---|---|---|
| instrument bar | 20–64 | Settings key (leading, 44 × 44) · run-notch stack (centre) · Anomaly key (trailing, 44 × 44, 24-segment rollover arc outside a streak ring, no numeral — the tally lives on `AnomalyView`; full static ring when `.clockBehind`, §11.7) → `AnomalyView` |
| the idle Loom | 72–288 | a 128 pt throat ring with one glyph drifting through it, crossfading every 8 s from a seed derived from the launch time. Non-interactive by design — it sits above the thumb arc and is scenery, not a control |
| the mode rack | 300–528 | 2 × 2 grid, keys **168 × 108 pt**, 12 pt gutters, 13.5 pt side margins. Order PROBE · DRIFT / ECHO · SIEVE |
| the shelf | 540–592 | Codex (leading, 168 × 52) · Profile (trailing, 168 × 52); 592–647 is home-indicator clearance |

Every interactive target sits at y ≥ 300, inside the right-thumb comfort arc (y > 240, §4.1). The Settings and Anomaly keys at y 20–64 are the two exceptions and are both non-urgent.

**A mode is chosen with zero text.** Each rack key draws a sigil built only from idioms the player has already met:

| Mode | Sigil | Built from |
|---|---|---|
| PROBE | one stroke entering a ring | the throat |
| DRIFT | two offset law-plates, the trailing one in the dashed hollow ghost frame | the `prev` ghost marker (§4.2) |
| ECHO | a ring trailing three decaying concentric arcs | the ribbon's link arc |
| SIEVE | three strokes falling through a slotted grate, one caught | new, but self-evident |

Key state, all readable without colour:

- **Barred** — a machined bar across the key, the identical drawing used for the barred Seal (§4.3). **The gates are §9.10's and are stated there, not here: DRIFT on the first inscribed page at band ≥ 3, ECHO at ≥ 5 pages, SIEVE at ≥ 8 pages.** This section renders them; it does not set them.
- **Idle** — sigil at 100 %, hairline border 1 pt.
- **Suspended round** — the key's border becomes an arc filled to `probesUsed / par`, and the sigil lights. Tapping **resumes**. To discard and start fresh, **swipe the key toward the trailing edge** — the same gesture that clears a rail on the Bench (§4.2). Reuse over invention.

> **Decision:** modes unlock on **archive evidence**, not on a round count — because DRIFT is only legible to someone who already believes laws are stable, ECHO only to someone who has held a law in mind once, and SIEVE only to someone who can recognise a lawful glyph at a glance. The bar idiom carries the whole message; there is no text explaining it.

> **Decision:** DRIFT's gate is a **band-3 page**, not a page count, because DRIFT cannot generate a band-1 or band-2 law at all (§7.2: at band 1, `par = 7` and three admits need ≈ 12 probes, past the cap). A page-count gate lets a player who is still parked near θ ≈ −2 unbar a mode whose serving path would then have to clamp them up two bands on their first round — an unlocked key that lies about what it will hand you. The band-3 page is the cheapest honest proof that the player is already being served where DRIFT can live. The serving layer holds the other end of the same guarantee: DRIFT's served band clamps to **3–8** and SIEVE's to **1–6** (§9.3) after §10.3's quantisation, so no unlocked mode can ever be asked for a law it cannot produce.

> **Decision:** first launch never shows the Frame (§12.5). The Frame is revealed only when round 1 ends — because a menu is a text-shaped object and the first thing a new player must meet is the machine.

### 12.5 Onboarding by doing

No tutorial screen, no tooltip, no instructional text, no arrow-with-caption, ever. The entire mechanic is taught by revealing exactly one affordance at a time and letting the player press it.

**The opening round is fixed, not generated.** Mode `probe`, band 1 (LITERAL), seed `0x48554E4348` ("HUNCH"), generator bypassed.

- **The Opening Law:** `shape ∈ {triangle}`. `p = 0.250`; marginal deficit 0; free attributes 3; `δ = 0.023` — exactly the band-1 exemplar of §5.2. **par 7, cap 12.**
- **The seed glyph** in the throat is forced to `hollow triangle, two pips, frost` — `glyphID = 0·64 + 1·16 + 1·4 + 2 = 22`.
- The Dial is preset to the seed glyph, per the normal "Dial retains the last probe" rule (§4.1); at round start there is no last probe, so the seed is the preset.

**Beat by beat.**

| Beat | Trigger | What the player sees | What it teaches |
|---|---|---|---|
| 0 | first launch, no state file | Frame skipped. Dark surface; the throat ring strikes and the seed glyph fades up over 700 ms. Everything else — ribbon, Dial, handle, commit bar — is at 0 % | there is a machine and it has one thing in it |
| 1 | +1.2 s | the **PROBE key** alone fades to 100 % and begins a 0.5 Hz breath (opacity 0.55 ↔ 1.0). It is the only lit pixel below the throat | one control exists; press it |
| 2 | tap PROBE | **the exact first probe: the seed glyph itself, un-edited.** It is admitted. Consonant tone, admit haptic, the tile drops into the ribbon lit. The breath stops | pressing does something, and the machine has a *positive* state |
| 3 | +400 ms | the **shape ramp** alone fades in, staggered cell by cell at 60 ms. The other three ramps stay dark | the ramp is a picture of its own attribute (§4.1) |
| 4 | tap any shape cell | the glyph **in the throat** morphs to the new shape in 180 ms. The PROBE key resumes its breath | this widget edits that glyph |
| 5 | tap PROBE (probe 2) | if a non-triangle: rejected — dissonant tone, reject haptic, dark tile with cancel hatch. If triangle again: admitted, doubled ring (a **twin**) | verdicts differ; something about the glyph decides |
| 6 | first admit **and** first reject both recorded | the remaining **three ramps** fade in, staggered 120 ms apart, leading to trailing | the Dial is four of the thing you already understand |
| 7 | probe 4, or 25 s after beat 6, whichever first | the **Bench handle** appears at y 516–560 and performs one tug: up 20 pt, settle, 520 ms, once | there is something under here |
| 8 | pull up | the Bench. The palette holds **exactly one stamp** (Ramp) — the palette unlocks to lifetime max band + 1 = band 2, which needs only Ramp + coupler (§4.4). The stamp breathes | one tool, press it |
| 9 | tap the stamp | a Ramp lands on rail 1, unbound: its header dock shows the four attribute headers stacked. The Seal wears its machined bar | pick what the law is about |
| 10 | tap the `shape` header | the ramp binds and shows four silhouette cells, all unlit → the ramp is inert, the Seal stays barred, the rail draws at 30 % with a hairline slash | inert is one state, not two |
| 11 | tap `triangle` | one cell lights; the other three drop to 25 % with the diagonal cancel hatch. The **Assay** beside the rail lights 64 of 256 cells. **The machined bar retracts off the Seal** with a mechanical thunk | *this is the moment.* The machine is now ready, and nobody said a word |
| 12 | tap the Seal | correct. Staggered law-reveal on the Inscription; 3 Seal marks if ≤ 4 probes (`0.6 × 7 = 4.2`); score `1000 · min(1, 7/probes)`; the first Codex page mints | declaring is the point |
| 13 | Inscription | *again* key is primary. The Frame key (trailing) is now lit for the first time | there is more than this |

**How the declaration interface is discovered without being told:** it is not a new interface. §4.1 makes the probe control and the atomic rule-tile the *same widget* in two modes — single-select on the Dial, multi-select on the Bench. By beat 8 the player has tapped that widget between four and twelve times. The Bench introduces exactly one novelty (you may light more than one cell), and the Assay + the retracting Seal bar confirm it within one tap. The only genuinely new object in the whole of onboarding is the handle, and the handle is taught by a tug.

**Onboarding success criterion — measurable, recorded in `OnboardingLedger`:**

```swift
struct OnboardingLedger: Codable {          // in ladder.json (§11.13)
    var selfConstructedProbes: Int          // probes where the Dial differed from the previous probe
    var unvariedRun: Int                    // consecutive probes with an unchanged Dial — drives nudge 5
    var sawAdmit: Bool, sawReject: Bool
    var openedBench: Bool
    var boundAnAttribute: Bool
    var clearedTheSealBar: Bool
    var declaredCorrectly: Bool
    var nudgesFired: Int
}
```

Onboarding is complete iff **`declaredCorrectly && selfConstructedProbes >= 1 && sawAdmit && sawReject && boundAnAttribute`** within the opening round's cap (12, elastic — see below). In plain terms: at the end of it the player can, unaided, *construct a chosen probe, read the verdict, open the Bench, state a subset of one attribute, and commit it.* Nothing about strategy, nothing about the eight families — those are the game, not the tutorial.

**The passive path, and why the cap bends for it.** There is exactly one way to reach the end of the opening round having learned nothing: press the only lit control twelve times. Under the Opening Law `shape ∈ {triangle}` and a seed glyph that is already a triangle, every one of those probes is an **admit** — twelve twins, twelve positives, `sawReject == false`, beat 6 never fires, the other three ramps never appear, and the round ends at the cap having demonstrated that nothing about a glyph matters. The idle nudge cannot catch it (two controls are lit from beat 3), and §12.5's own success criterion is unmeetable on that path. Two rules close it, and they apply **only in the opening round**:

- **Nudge 5, *Unvaried*** (below). It stops breathing the PROBE key — which has nothing left to teach — and breathes the shape ramp's four cells **as a group**. Never one cell: the hard floor holds, the nudge says *this control exists and is pressable* and nothing about which value is lawful.
- **The cap does not end the round while `sawReject == false`.** The moment a reject lands, the cap re-arms at `max(12, probesUsed + 3)`, so the player always has at least three probes to declare with. The extra probes are scored normally — economy is `min(1, 7/probesUsed)` and marks are `≤ cap_effective → 1`, so a long tutorial round is worth what a long round is worth. Nothing is refunded and nothing is gifted; only the *loss* is deferred. The suspension itself ends at probe 24: a player who has ignored a breathing ramp for twelve probes is better served by the cap reveal (§4.5) and a fresh opening round than by an unbounded one.

**Failure of the opening round.** Two strikes or reaching the cap ends it like any round: the true law animates in full rule-tiles (§4.5), which is itself the most instructive thing that can happen. The next round re-runs the opening configuration with a *different* band-1 law (still `attr ∈ {single value}`, still with the seed glyph forced to an admitted glyph) and the beat script re-arms from beat 6 onward — beats 0–5 never repeat. After three failed opening rounds the ledger stops re-arming and the player is simply in band 1 like anyone else; the adaptive engine's two-consecutive-failure band drop has nowhere lower to go, which is correct.

**The nudge — the wordless fallback for a stuck player.** One visual vocabulary: a *breath* (opacity 0.55 ↔ 1.0, 1.2 s ease-in-out) on the single control that is currently the correct next act, plus one 0.4-amplitude click haptic on the first cycle only.

| Nudge | Trigger threshold | Form | Repeat |
|---|---|---|---|
| Idle | 12 s with zero touches while exactly one control is lit (beats 1, 8, 9) | breath ×3 on that control | every 20 s, max 5, then permanently silent for the session |
| No-Bench | probe count reaches 6 with `openedBench == false` | handle tugs once more; the par tick row flashes once | max 2, at probes 6 and 9 |
| Barred Seal | the barred Seal is pressed **3 times** with no rail edit in between | the offending rail pulses (already spec'd, §4.3), then its four cells sweep-highlight leading → trailing, 80 ms apart, once | max 3 per round |
| Global idle | 90 s with zero touches, any round, any mode except SIEVE | surface dims to 60 %; the most-recently-usable control breathes | until touched |
| **Unvaried** *(opening round only)* | `unvariedRun == 2` — two consecutive probes with an unchanged Dial — while `sawReject == false` | the PROBE key's breath **stops**; the lit ramp's four cells breathe **as a group**, 60 ms apart, leading → trailing. After beat 6 the group is all four ramps' cells | every 2 unvaried probes, no limit while `sawReject == false`; silent forever once it is true |

**Hard floor on nudges:** a nudge may only ever say *"this control exists and is pressable."* It may never indicate which cell, which attribute, which comparator, or anything about the law. No auto-play, no auto-solve, no skip, no hint economy. Under Reduce Motion every nudge becomes a pure opacity crossfade — no scale, no translate, no tug (the handle brightens its hairline instead). Under VoiceOver, nudges are suppressed entirely; the rotor already enumerates every control, so a breath would be noise.

### 12.6 Settings

**Seven sections, nineteen rows.** This table is the single source: where §13 specifies a control's shape, §13 wins and this table has been rebuilt to match. Everything persists to `UserDefaults.standard` under the `hunch.settings.` prefix except the DATA rows, which act on files. **`UserDefaults` holds preferences only** (§ architecture); game state lives in JSON.

| Section | Row | Type | Default | Effect | Key |
|---|---|---|---|---|---|
| DISPLAY | Theme | segmented, 4 (System / Dark / Light / High Contrast) | **System** | swaps the palette (§13.2: Dark below `.light`, Light above). High Contrast is a *theme*, not a toggle: hues → `stroke.primary`, index stroke 12 → 18 pt, all strokes +0.5 pt, shader off. Forced on if `isDarkerSystemColorsEnabled` and the player has not chosen | `theme` |
| | Grain | toggle | On | the Metal `colorEffect` scanline/vignette pass (§13.6). Ignored — held at `amt = 0` — under High Contrast, Reduce Transparency or Low Power | `grain` |
| | Reduce motion | segmented, 2 (System / Always) | System | every animation becomes a crossfade per §13.7.4; the Frame's idle glyph stops drifting | `reduceMotion` |
| | Left-hand keys | toggle | Off | mirrors **only** the commit bar key order and the Bench handle side. Never the play surface | `leftHandKeys` |
| FEEDBACK | Haptics | toggle | On | gates `CHHapticEngine` entirely (§13.9). There is no Light tier: §13.9 specifies eleven patterns and a half-strength spelling of each would be eleven more designs carrying no information the visuals do not already carry | `haptics` |
| | Sound | toggle | On | master gate on `AVAudioEngine`; off means the engine is never instantiated | `sound` |
| | Level | segmented, 2 (Normal / Low) | Normal | Low is −8 dB (§13.8). **Two states, not a slider** — the mix is already ceiling-limited at −6 dBFS and a continuous gain is a control nobody can set correctly by ear | `level` |
| PLAY | Confirm the Seal | toggle | Off | On = the Seal requires a second tap within 2.0 s. For tremor and one-handed play | `confirmSeal` |
| | Steady stream | toggle | Off | SIEVE only: fixes `r` at `r₀` with no ramp, at a 0.85 score multiplier (§9.8). Not gated behind an accessibility flag, and it does not disable Codex inscription | `steadyStream` |
| VOICEOVER | Detail | segmented, 2 (Full / Terse) | Full | Terse omits attributes unchanged from the previous glyph ("three pips" instead of the full four-part label) | `voiceOverDetail` |
| | Announce verdicts | toggle | On | posts an `.announcement` on every `admit`/`reject` | `announceVerdicts` |
| | Announce the Assay | toggle | Off | posts the draft's admit count on every Bench edit. Off by default because it is very chatty | `announceAssay` |
| LANGUAGE | App language | picker, 13 | **System** | see §12.9 | `languageTag` |
| DATA | Clear statistics | destructive + alert | — | rewrites `stats.json` to zeros. Nothing else moves | files |
| | Clear Codex | destructive + alert | — | deletes `codex-b1…b8.json`, empties `codex-index.json`. Re-locks ECHO and SIEVE at §9.10's page gates. **Does not touch the palette ceiling** — that is `ServingState`, not the archive (§11.12) | files |
| | Reset Profile | destructive + alert | — | rewrites `profile.json` to day-1 defaults; the portrait re-forms unformed | files |
| | Reset the ladder | destructive + alert | — | rewrites `ladder.json`: ability undefined, serving state zeroed — including `maxBandEverServed`, so **the palette drops to its band-2 opening state** — novelty and cooldown rings emptied. §10.4's calibration re-runs. **Keeps the Codex.** For a shared device | files |
| | Reset everything | destructive + alert | — | deletes every file in `Application Support/Hunch/` **except `anomaly.json` and `anomaly.hw`**, including the derived index; clears every `hunch.settings.*` key **except** `languageTag` and `theme`; re-arms onboarding from beat 0 | files + defaults |
| ABOUT | About | disclosure → `AboutView` | — | version, build, "no data is collected", copyright, storage-status indicator | — |

**No reset of any kind touches `anomaly.json` or its `anomaly.hw` sidecar** (§11.7). That is not a courtesy to the ledger, it is the whole anti-cheat: `highWaterDay` is the only thing standing between the daily and the clock, and a reset that cleared it would *be* the exploit. Asserted in the migration fixture test (§11.13).

Rows deliberately absent, with reasons: no difficulty selector (§ brief: never surface a numeric level); no notifications or daily reminder (a reminder is a text surface in 12 languages for zero play value, and the app has nothing time-sensitive to say); no iCloud sync (no network, at all); no Codex export and no `Documents/` folder — §11.5 decides against a file format outright, and the device backup already answers "your data is yours"; no "restore purchases" (there are none); no analytics opt-in (there is nothing to opt out of, and `PrivacyInfo.xcprivacy` says so); no separate High Contrast toggle (it is a theme, and two controls for one state is how they get out of sync).

**Persistence map.** The file tree is §11.13's, verbatim and exclusively — there is no `state.v1.json`.

| What | Where | Backed up |
|---|---|---|
| every `hunch.settings.*` preference | `UserDefaults.standard` | yes |
| Codex (`codex-index.json`, `codex-b1…b8.json`), Anomaly ledger (`anomaly.json` + `anomaly.hw`), Profile (`profile.json`), ability + serving state + `OnboardingLedger` (`ladder.json`), counters and the 200-round ring (`stats.json`), the suspended round (`round.json`), `manifest.json` | `Application Support/Hunch/`, atomic writes, one global `schema` from v1 (§11.13) | **yes** — a restored phone keeps its Codex |
| lower-band index (9,767 tables, 305 KB) and contextual hash index (138 KB) | `Application Support/Hunch/lowerBandIndex.bin` — canon §3.6's spelling, one spelling only | **no** — `isExcludedFromBackupKey = true`, set in §11.13 and nowhere else; it is regenerable |
| anything in `Documents/` | nothing, ever | — the app must not appear in Files |

### 12.7 Pause and interruption

There is **no pause control** in PROBE, DRIFT or ECHO, because there is no clock. SIEVE is the only mode with time pressure and therefore the only one that needs a freeze.

| Event | PROBE / DRIFT / ECHO | SIEVE |
|---|---|---|
| `scenePhase → .inactive` (call, banner, control centre, app switcher) | nothing visible; the round is already on disk (§5.4 persists after every probe) | stream freezes on the current frame within one display tick; `SievePauseOverlay` drops a 70 % scrim |
| `scenePhase → .background` | flush + `fsync` `round.json`, then the other dirty files in §11.13's order; stop `AVAudioEngine`; stop `CHHapticEngine` | same, plus the frozen stream position is written |
| `scenePhase → .active` | 600 ms spin-up: the throat ring re-lights, ribbon tiles fade in leading → trailing at 40 ms each, then the Dial | overlay stays; resuming needs **one deliberate tap on the gate** — the same 375 × 88 pt band the run is played with, never a region SIEVE does not have — then §9.8's 3-glyph run-up replays at `r₀` before the stream continues |
| termination (swipe-kill, OOM, crash) | relaunch opens **directly into the round**, ribbon intact, Dial holding the last probe | relaunch opens the Frame; **the run is voided per §9.8** — no score, no Codex effect, no ability update, no foul carried forward. The run record is still written, marked `void`, so the attempt log stays truthful. Banking a force-quit is the one exploit a timed mode has, and this closes it |
| audio interruption began / ended | engine stops; restarts only on `.shouldResume` | same |
| Low Power Mode on | grain shader off; the Frame's idle glyph stops drifting | plus stream frame rate capped at 60 Hz |
| memory warning | drop the on-demand contextual pair table (2 µs to rebuild) and unmap the lower-band index | same |

**Leaving a round.** In PROBE, DRIFT and ECHO a leading chevron sits at the leading end of the instrument bar, and **one tap suspends and returns to the Frame** — no confirmation, because nothing is lost: the mode key on the Frame now draws its partial arc and one tap resumes.

**SIEVE is the exception, and its exit is §9.2's, not this section's.** There is no chevron in SIEVE's instrument bar, which carries the foul ticks and the progress arc and nothing else, and none in its commit bar while the stream runs — the commit bar holds `pause` alone. The exit exists **only from `paused`**, where the commit bar gains a leading chevron that ends the run on a second, confirming tap. Two reasons it is built that way rather than as a one-tap bar control: a timed mode is the one place a stray thumb near the chrome can destroy something, and stopping the stream *first* means the decision to leave is made against a frozen screen rather than a moving one. An abandoned run is scored exactly as a foul-out at the last resolved glyph (§9.8) — it is not a void; voiding is what happens to a *terminated* run, and the difference is the whole anti-censoring argument in §9.8. That confirm-by-repeat and the Seal's optional one (§12.6) are the only two in the app.

### 12.8 Accessibility-driven layout rules

**Targets.** Minimum 44 × 44 pt; the smallest shipped is 56 × 44 (Bench ramp cell, §5.7). The instrument-bar chevron and the play key draw at 24 pt inside a 44 × 44 hit rect. Inter-target spacing ≥ 8 pt everywhere; the Dial's 6 pt gutter is between *cells of one ramp*, which are a single semantic group, not between independent targets.

**Dynamic Type.** The play surface has no text, so the type multiplier drives *art* scale, capped at 1.35× (§2).

| Category | Chrome type | Art scale | Layout change |
|---|---|---|---|
| xSmall … Large | 100 % | 1.00× | reference layout |
| xLarge … xxxLarge | 112–120 % | 1.00–1.20× | Dial cells 70 × 48 → 84 × 58; ribbon pinned at 44 pt |
| accessibility1 | 135 % | 1.35× (ceiling) | Settings rows go label-over-value; Dial gutters 6 → 4 pt |
| accessibility2 … 5 | 135 % (clamped) | 1.35× | **Bench becomes a single-rail pager** (§2); ECHO's tray becomes a two-column pager (§8.4); Codex shelf grid 5 → 2 columns; Profile stat block one item per line; mode rack 2 × 2 → 1 × 4 scrolling |

Chrome text never truncates and never shrinks: `lineLimit(nil)`, `fixedSize(horizontal: false, vertical: true)`, no `minimumScaleFactor`. If a row cannot fit, the row grows.

**One-handed portrait on the SE.** The right-thumb comfort arc from a bottom-trailing pivot covers y > 240 (§4.1). Three tiers, and every shipped surface satisfies them:

1. **Commit controls live in the commit bar, y 604–667, on every surface** — PROBE · twin · Bench (§4.1), Dial · Seal (§4.2), twin/replay · Seal (§8.4), pause (§9.2). The thing that ends a decision is always in the same place under the same thumb.
2. **Composition controls live at y ≥ 220** — the Dial's ramps (236–508), the Bench's rails and palette (228–604), the Frame's mode rack and shelf (300–592), ECHO's tray (260–572, §8.4), SIEVE's gate (420–508). Reach for a multi-cell grid is measured at its **nearest** row, not its farthest: the grid is entered from below, and above AX2 it pages rather than grows (§2).
3. **Everything above y = 220 is read-only** — instrument bars, the throat, the ribbon, ECHO's primer strip, the Frame's idle Loom. The Loom is deliberately unreachable.

Two controls sit above the line and both are **undo-shaped**, so each has a same-effect route inside the arc: the ribbon (176–228) loads a tile into the Dial, which the Dial can always compose directly (canon §4.1 calls ribbon-load a *mitigation*, not the route); and ECHO's rail (172–252, §8.4) returns a placed tile, which **tapping its tray tile a second time also does** — the tray tile carries a placed state and is a toggle, so the whole of ECHO is playable without reaching above y = 220. Nothing else above the line responds to touch.

On a Pro Max the same layout letterboxes vertically — the commit bar stays pinned to the safe-area bottom and the Loom region absorbs the extra height, so reach does not degrade with device size.

**RTL — mirror the chrome, never the glyph.**

| Mirrors in Arabic | Does **not** mirror, in any locale |
|---|---|
| instrument-bar key order; the chevron itself | glyph bodies, silhouettes, fills |
| commit bar order (PROBE · twin · Bench) | the **index stroke** — 45° and 135° are `teal` and `rose`; mirroring swaps two hues (§2) |
| Bench handle side; palette order; rail leading edge | pip node positions (N → E → S → W accretion) |
| Settings rows, disclosure chevrons | the Codex plate's internal rule-tile layout, which is the law's rendering |
| Codex grid reading order; Assay grid horizontal order (cell 0 sits top-*leading*) | — |
| the **wedge** — it mirrors *with* its rail, so its wide end still physically opens toward the larger socket | the wedge's meaning, which is positional and therefore preserved by mirroring |

`leading`/`trailing` only, `left`/`right` never. Ramps, the Assay and the ribbon render **leading-to-trailing in source order** in every locale (§2) — the source order is canonical, the visual direction follows the locale.

**VoiceOver.** Every control is a standard accessibility element with a label, a trait and a value; there is no drag, pinch, long-press or double-tap in the declaration UI (§4.2), so the whole Bench is operable with rotor + single-finger double-tap. The glyph label is **one localized format string with four interpolations, never concatenated fragments** (§2). The four custom rotors are §13.10's and there is no fifth: *Rails* (Bench), *Attributes* (the Dial's four ramps), *Probes* (backward through the ribbon), *Counterexample* (only after a strike); `.headings` carries the Codex, Profile, Statistics and Settings. `accessibilityRespondsToUserInteraction` is set on the barred Seal so it is discoverable while it is refusing.

### 12.9 The localization surface

**The play surface has zero strings.** Not few — zero. `RoundView`, `EchoRoundView`, `SieveRoundView`, `BenchView`, `AssayInspectorView` and the Inscription's reveal region contain no `Text` view rendering any character in any locale. This is enforced, not merely intended: `PlaySurfaceTextTests` fails the build if any type in those files references `Text`, `Label`, or `AttributedString` outside an `.accessibility*` modifier.

**Exhaustive inventory of every place text appears in the app.**

| Location | Visible? | Keys | Notes |
|---|---|---|---|
| Settings: 7 section headers, 19 row labels, 11 option labels | yes | 37 | ≤ 22 chars in English, budgeted for +40 %. Option labels are Theme 4, Reduce motion 2, Level 2, VoiceOver Detail 2, App language "System" 1. Excludes the 12 language endonyms, which are constants, not translation units |
| Reset alerts ×5 (title, body, destructive verb) + shared cancel | yes | 16 | one variant per DATA row; the bodies differ because the consequences do |
| `AboutView` rows | yes | 6 | includes the no-data-collected statement and the storage-status line |
| `StatisticsView`: 5 section headers, 19 row and column labels | yes | 24 | §11.12. The four mode names are **wordmarks**, not translation units — PROBE / DRIFT / ECHO / SIEVE ship untranslated in all 12 locales, exactly like HUNCH |
| `ProfileView`: five stat labels | yes | 5 | rounds, pages, longest run, Anomaly streak, mean probes/par. **No "highest band" row** — §10.5 forbids surfacing a band number, and the Codex shelves already carry that fact retrospectively |
| Screen titles (Codex, Anomaly, Statistics, Profile, Settings, About) | yes | 6 | `CodexShelfView` and `CodexPageView` have none — a shelf is titled by its family sigil and a page by its law |
| **Visible subtotal** | | **94** | the entire readable text of the game |
| VoiceOver: attribute + value names | no | 20 | 4 attributes + 16 values |
| VoiceOver: glyph label format | no | 1 | four interpolations |
| VoiceOver: control labels | no | 77 | Frame 8, PROBE/DRIFT round 10, ECHO 4, SIEVE 3 (§13.10), Bench 22, Assay 3, Inscription 8, Codex root 6, Codex shelf 3, Anomaly 5, Statistics 2, Profile 3 |
| VoiceOver: the five Profile vertex strings | no | 5 | §11.11's approved behavioural sentences. The identifiers *Induction, Retention, Flexibility, Restraint, Tempo* never enter the catalog in any form, visible or spoken |
| VoiceOver: hints | no | 14 | |
| VoiceOver: value formats (probes-of-par, marks, band, streak) | no | 8 | plural-bearing |
| VoiceOver: announcements | no | 9 | admit, reject, strike, counterexample, Seal barred, inscribed, revealed, drift changed, cap reached |
| **Accessibility subtotal** | | **134** | audio only; never rendered as pixels |
| **`Localizable.xcstrings` total** | | **≈ 228** | hard budget **250**, asserted by test |
| App Store Connect: name, subtitle, description, keywords, what's-new | n/a | 5 fields | outside the catalog; 5 × 12 = 60 units |
| `Info.plist` | n/a | **0** | see below |
| `PrivacyInfo.xcprivacy` | n/a | 0 | |
| Screenshots | n/a | **0** | wordless by decision — the game is wordless, the screenshots should prove it |

≈ 228 keys × 12 languages ≈ **2,740 translated units**, plus 60 metadata units. A test asserts `catalog.keyCount <= 250` so the no-text discipline is mechanically enforced rather than remembered. The budget is 250 and not 220 because the statistics screen and its five reset alerts are counted here rather than discovered at translation time; it is set one screen's worth above the count, which is the most headroom a discipline can survive.

**`Info.plist` contains zero localizable strings**, and that is a verifiable privacy claim: the app requests no permissions, so there is no `NS*UsageDescription` of any kind. It also carries **neither `UIFileSharingEnabled` nor `LSSupportsOpeningDocumentsInPlace`** — there is no export and no `Documents/` content (§11.5), and a test asserts both keys are absent so the app cannot silently acquire a Files presence. `CFBundleDisplayName` is **"HUNCH" in all 12 locales including Arabic** — it is a wordmark, not a word.

**Language override, and the two things that do not work by default.** `hunch.settings.languageTag` stores `"system"` or a BCP-47 tag. On change the app re-creates the root view; the `AppleLanguages` write is kept for the **next cold launch only** and is explicitly not the mechanism for the current session.

1. **Layout direction is not derived from `\.locale`.** `EnvironmentValues.layoutDirection` comes from the process's effective localization, fixed at launch, so setting `\.locale` to `ar` mirrors nothing. It is therefore set explicitly on the root:
   `.environment(\.layoutDirection, resolvedLocale.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)`.
2. **`String(localized:)`, `LocalizedStringResource` and bare `Text("literal")` all resolve against `Bundle.main`'s launch-time localization**, not the cached `.lproj` bundle. An override that only reached the `Loc(…)` helper would leave every `Text` literal in English until relaunch — which is most of the app's strings. Every user-facing string therefore goes through **one accessor**, which carries the bundle and the locale:
   `LocalizedStringResource(key, bundle: .atURL(overrideBundle.bundleURL), locale: resolvedLocale)`.

With both in place, selecting Arabic mirrors the chrome and switches every string immediately, with no relaunch. `Date.FormatStyle`, `NumberFormatter` and `Measurement` all read the same resolved locale, so a player in French-on-an-English-phone gets French dates in the Codex. This is a brief requirement and a Definition-of-Done item ("It works in Arabic"), so it is a shipped test: set the override to `ar`, assert `layoutDirection == .rightToLeft` and that a sampled key resolves to its Arabic value, without restarting the process.

**The traps, named.**

1. **Untracked literals, in both spellings.** Raw enum `String` values are not extracted by String Catalogs — `Text(mode.rawValue)` compiles, ships, and is English forever — and a bare `Text("Clear Codex")` *is* extracted but bypasses the override accessor above, so it stays English until relaunch. Every user-facing enum exposes `var label: LocalizedStringResource` implemented as a `switch` over string literals; `rawValue` is for serialisation only. The lint test fails on **both**: any `Text(` whose argument's static type is `String`, and any `Text(` with a bare string literal anywhere outside the accessor.
2. **German, Russian and Turkish run up to 40 % longer.** Every visible string is budgeted at ≤ 22 characters in English and every Settings row is verified at `.accessibility3` under the expanded pseudolocale. Rows grow vertically; nothing truncates, nothing scales down.
3. **Never concatenate translated fragments.** One format string per sentence, interpolations only. This is already law for the glyph label (§2) and applies equally to "3 of 7 probes" and "streak of 4 days".
4. **Plurals are per-language grammar, not an `if`.** Probe counts, page counts, day counts and mark counts use String Catalog plural variations; Russian needs four categories and Arabic six. Any `count == 1 ? … : …` in the codebase is a bug.
5. **Turkish dotless ı.** The instrument-panel look uses small caps. It must come from the font's `smcp` feature, never from `.uppercased()` — and if a locale-aware uppercase is ever unavoidable it is `.uppercased(with: locale)`. `"i".uppercased()` is `"I"`, which is wrong in Turkish.
6. **Small caps and tight tracking do not apply to every script.** Arabic, Japanese, Korean and Simplified Chinese use a per-script typographic profile: no small caps, no negative tracking, taller line height. The instrument-panel aesthetic is carried by rules and spacing in those locales, not by letterforms.
7. **Locale-native numerals are allowed** wherever text appears, because the play surface uses tick marks and notches rather than numerals — so Eastern Arabic digits in the Codex are correct, not a bug.
8. **Pseudolocalization is a gate, not a courtesy.** Every screen is reviewed under accented + expanded pseudo-language and under `-AppleTextDirection YES` before it is called finished, and simulator screenshots are taken in English, German and Arabic (§ verification).
## 13. Art Direction, Motion, Audio, Haptics and Accessibility

### 13.1 The commitment

**A dead machine in a dark room.** The Loom is not a UI; it is an instrument someone else built, powered down for a long time, that still answers when you feed it. Everything below serves one sentence: *the marks glow, the chrome does not.* Three consequences, enforced everywhere: **luminance is the only depth cue** (no shadows, no elevation, no material blur as a primary surface — panels separate by a hairline rule and a 1.06 : 1 ground shift); **glyphs are light, chrome is etched metal**; **the accent is rationed** to at most three elements per screen.

**Forbidden, and a reviewer should reject a PR on sight:** flat purple/indigo gradients; white or near-white grounds outside the light theme; the system blue tint; rounded-rect "cards" with soft shadows; SF Symbols inside the play surface; emoji; gradient or textured fills *inside* a glyph body (the fill register is game state and must be a flat pattern); `.ultraThinMaterial` as a primary surface; bounce or rubber-band easing on a verdict; **rounded corners on a glyph silhouette** — corner count is the shape channel and rounding erodes it.

### 13.2 Palette

Named tokens only; no literal hex in view code. `Theme.token(_:)` resolves against the active theme. Contrast is WCAG 2.1 relative luminance against the theme's `ground`.

| Token | Dark (`ground` L 0.0031) | : 1 | Light (`ground` L 0.866) | : 1 | High Contrast | : 1 | Use |
|---|---|---|---|---|---|---|---|
| `ground` | `#0B0A08` | — | `#F4EFE4` | — | `#000000` | — | the room |
| `ground.raised` | `#15120D` | 1.06 | `#FBF7EE` | 1.06 | `#0A0A0A` | 1.10 | Bench, sheets, Codex rows |
| `ground.sunken` | `#050504` | 1.06 | `#EBE4D5` | 1.07 | `#000000` | 1.00 | Assay well, throat vignette |
| `stroke.primary` | `#EFE3D0` | **15.6** | `#1A1712` | **15.6** | `#FFFFFF` | **21.0** | glyph keyline, rule-tile strokes, body text |
| `stroke.secondary` | `#6B6153` | **3.3** | `#6E6659` | **4.9** | `#B0B0B0` | **9.7** | chrome rules, tick marks, labels |
| `stroke.hairline` | `#3A342B` | 1.6 | `#D6CDBC` | 1.5 | `#5A5A5A` | 3.3 | decorative rules, Assay grid — **never state-bearing** |
| `accent.brass` | `#C9922F` | **7.2** | `#8A5E14` | **5.0** | `#FFC24D` | **13.1** | admit, the Seal, marks, streak |
| `accent.cold` | `#7FD8E0` | **12.1** | `#0E5F72` | **6.3** | `#7FE9FF` | **15.0** | reject, strike, counterexample, barred |
| `hue.amber` | `#E69F00` | 9.5 | `#E69F00` | 1.8 † | `stroke.primary` | 21.0 | glyph hue rank 1 |
| `hue.teal` | `#009E73` | 6.4 | `#009E73` | 2.7 † | `stroke.primary` | 21.0 | glyph hue rank 2 |
| `hue.frost` | `#56B4E9` | 8.6 | `#56B4E9` | 2.0 † | `stroke.primary` | 21.0 | glyph hue rank 3 |
| `hue.rose` | `#CC79A7` | 6.5 | `#CC79A7` | 2.7 † | `stroke.primary` | 21.0 | glyph hue rank 4 |

Okabe–Ito verbatim in both themes, per canon — no re-lighting.

> **Decision:** † in the **light theme only**, every glyph carries a `stroke.primary` **keyline** at `bodyWeight + 1.0 pt` beneath the hue stroke, so the mark's outer edge is 15.6 : 1 and the hue sits *inside* an ink outline. Because canon establishes that the index stroke *is* the hue channel and colour is the redundant copy, raw hue contrast is decorative — but the *silhouette* is state-bearing and must clear 3 : 1 at every size. The keyline is the cheapest way to get both, and it preserves Okabe–Ito verbatim. Dark needs none (worst hue 5.78 : 1, `teal`); High Contrast drops hue to `stroke.primary` outright, per canon.

**Register segregation is a hard rule.** `accent.*` never touches a glyph body, a ramp cell or an index stroke; `hue.*` never touches chrome, a rule-tile frame, a tick mark or the Seal. `hue.amber` and `accent.brass` sit 3° apart in hue and only **1.22 : 1** apart in luminance — closer than an earlier draft claimed, and close enough that luminance carries none of the distinction. Register segregation and ring geometry carry all of it, which is why the registers are separate Swift types rather than a convention: nothing may be built that assumes those two are told apart by brightness. `hue.frost` / `accent.cold` are 17° and 1.41 : 1. Reject is additionally encoded as a *contracting, broken* ring, never colour alone.

**Theme selection.** Settings: System / Dark / Light / High Contrast, default System (Dark below `.light`, Light above). If `UIAccessibility.isDarkerSystemColorsEnabled` and the player has made no explicit choice, force High Contrast.

### 13.3 Strokes, corners, grid, chrome

| Weight | pt | Applied to |
|---|---|---|
| `hairline` | 0.5 | chrome rules, the Assay's 16×16 grid, empty-rail outline |
| `thin` | 1.0 | ramp cell borders, rule-tile frames, pip knockout ring |
| `bodySm` | 1.5 | glyph body below 48 pt (canon), fill hatch at small sizes |
| `body` | 3.0 | glyph body at ≥ 48 pt, index stroke, wedge, coupler strands |
| `heavy` | 4.0 | the machined bar across a barred Seal, the AND welded bar |

**Corners and caps.** Glyph silhouettes use **miter joins, zero radius, always.** Chrome uses a 2 pt continuous radius; nothing exceeds it except the Bench sheet's top corners (12 pt). Caps are `butt` on glyph geometry so a 45° index stroke has an honest length, `round` on chrome.

**Grid and chrome.** 4 pt base; scale `4 / 8 / 12 / 16 / 20 / 24 / 32 / 44 / 64`. Outer margin **16 pt**, content column **343 pt** on canon's 375 pt reference device; the Dial resolves to header 45 + 4 × 70 + 3 × 6 = 343 (canon's 342, with the 1 pt rounding absorbed by the header). A rule is a 0.5 pt `stroke.hairline` line inset 16 pt both sides; a section boundary is a rule with 24 pt of air above and 16 pt below. No screen exceeds 62 % ink-bearing area outside the Dial.

### 13.4 Typography

System faces only — no bundled font, no licence file, no bytes. SF Pro (variable width, iOS 16+) and SF Mono via `design: .monospaced`.

| Role | Size @ Large | Weight | Width | Tracking | Face | Where |
|---|---|---|---|---|---|---|
| `display` | 28 | semibold | condensed | 0.06 em | SF Pro | Codex page title, Profile |
| `title` | 20 | semibold | condensed | 0.08 em | SF Pro | screen titles |
| `section` | 13 | medium | condensed | 0.14 em, UPPERCASE | SF Pro | instrument labels, Settings headers |
| `body` | 17 | regular | standard | 0 | SF Pro | Settings rows, Codex notes |
| `caption` | 13 | regular | standard | 0.01 em | SF Pro | secondary metadata |
| `numeral` | 15 | regular | standard | 0 | **SF Mono**, `monospacedDigit` | every number, always |
| `micro` | 11 | medium | condensed | 0.16 em, UPPERCASE | SF Pro | statistics section heads and column heads, Settings section heads |

**Monospaced numerals are mandatory** wherever a value changes without a layout pass: probe counts, par/cap, Seal marks, the Anomaly tally and streak, the Codex page's instrument strip, the Profile's **stat block** — never the portrait, which carries no numeral at all (§11.11 P2) — the statistics screen, and the Settings version. A proportional digit that shifts a column on every probe is a bug.

**Dynamic Type.** Every role declares `relativeTo:` its nearest style (`display`→`.largeTitle`, `title`→`.title2`, `section`→`.caption`, `body`→`.body`, `caption`→`.footnote`, `numeral`→`.subheadline`, `micro`→`.caption2`). Tracking is stored in **em** and applied as `.tracking(scaledSize * em)` via `@ScaledMetric` — fixed-point tracking collapses at AX5. `minimumScaleFactor` is **1.0 everywhere, no exceptions**: text wraps, containers grow, layouts reflow. Uppercasing uses `String.uppercased(with: locale)`, never a display transform — Turkish dotted-I and Arabic caselessness both break the naive path.

### 13.5 Glyph geometry — four channels as vectors

A glyph is drawn into a square box of side `S`: `bodyCentre = (0, +0.10·S)`, body radius `R = 0.37·S`, index register centred at `y = −0.43·S`.

**A glyph is monochrome in its own hue.** Body stroke, fill texture, pip nodes and index stroke are all drawn in `hue.*` (or `stroke.primary` under High Contrast). One colour per glyph — the oscilloscope truth — which also makes fill density a pure ink-coverage signal, independent of which hue is showing.

**`shape` — the silhouette (outer contour).** Regular polygons inscribed in `R`, conventional orientation.

| Value | Rank | Vertices | Corner count |
|---|---|---|---|
| `circle` | 1 | — | **0** |
| `triangle` | 2 | −90°, +30°, +150° (apex up) | **3** |
| `square` | 3 | ±45°, ±135° (axis-aligned) | **4** |
| `hexagon` | 4 | −90°, −30°, +30°, +90°, +150°, +210° (pointy-top) | **6** |

**`pips` — contour nodes (on the contour).** Node `k` sits **where the ray from `bodyCentre` at angle θ_k meets the silhouette**, θ = {−90° N, 0° E, +90° S, 180° W}, filled progressively N → E → S → W per canon. A node is a filled disc of radius `max(3 pt, 0.11·R)` in the hue, with a 1 pt `ground` knockout ring so it separates from the body stroke and from fill texture reaching the contour. On `triangle` and `hexagon` the N node lands on a vertex; on `square` and `circle`, mid-edge. Both are distinct silhouette bumps.

**`fill` — interior texture** (clipped to the silhouette, inset `1.5 × bodyWeight`). Coverage is size-invariant because every pattern is pinned to one pitch: `pitch = max(5 pt, 0.22·R)`, `dotRadius = 0.25·pitch`, `stripeWeight = 0.386·pitch`.

| Value | Rank | Geometry | Coverage | Texture kind |
|---|---|---|---|---|
| `hollow` | 1 | nothing | **0 %** | none |
| `dotted` | 2 | hex-packed discs at `dotRadius`, `pitch` | **22.7 %** | discrete |
| `striped` | 3 | parallel lines at +45°, `stripeWeight`, `pitch` | **38.6 %** | continuous, linear |
| `solid` | 4 | flat field | **100 %** | continuous, area |

Monotone ink density 0 → 22.7 → 38.6 → 100 %, matching canon's rank order, identically at every size from 24 pt to 220 pt.

**`hue` — the index stroke (below the body).** One straight stroke of weight `body`, centred at `(0, −0.43·S)`, length `0.273·S` (High Contrast `0.409·S`), rotated by rank: `amber` 0°, `teal` 45°, `frost` 90°, `rose` 135°. At S = 44 pt those lengths are exactly canon's **12 pt / 18 pt**; at S = 96 pt, 26.2 / 39.3 pt. The index stroke stays at `body` (3.0 pt) even when the silhouette drops to `bodySm` (1.5 pt) — the hue channel is deliberately the heaviest non-colour mark on the glyph.

**Bloom, and what it actually costs.** Each glyph is stroked twice: once at `3 × weight` and 12 % opacity, then at full weight and opacity. The halo is the **widened low-opacity stroke itself**, with a `round` join — at these sizes that reads as a halo, and it is genuinely two draw calls into the same layer.

The blur is separate and is **not** free: inside a `Canvas` the only way to blur drawn geometry is `GraphicsContext.addFilter(.blur(radius:))` around a `drawLayer { }`, which is an explicit offscreen layer, exactly as `.blur()` is as a view modifier. So the blur is applied **once per glyph-bearing region — the throat, the ribbon, the tail — never once per glyph**, at `radius: 0.062·S` for that region's `S`. Three layers per frame, not up to sixteen.

**The Assay is excluded from bloom entirely**, at every size and in every state. Its cells are 3.5–9.5 pt and carry no stroke to widen; and during the correct-declaration reveal it floods 256 cells at 1.6 ms/cell (§6.8) on top of the throat and ribbon, which is precisely the frame that cannot afford a fourth offscreen layer against the ≤ 0.4 ms/frame shader budget.

Off entirely under Reduce Transparency and High Contrast — both the widened stroke and the layer filter.

#### 13.5.1 Proof of triple encoding

256 = `fill`(4) × `shape`(4) × `pips`(4) × `hue`(4), and **all four channels are fully determined by geometry alone**:

| Channel | Achromatic discriminator | Values |
|---|---|---|
| `fill` | ink coverage {0, 22.7, 38.6, 100} % **and** texture kind {none, discrete, linear, area} | 4 |
| `shape` | silhouette corner count {0, 3, 4, 6} | 4 |
| `pips` | count of contour discs {1, 2, 3, 4} at fixed compass rays | 4 |
| `hue` | index-stroke rotation {0°, 45°, 90°, 135°} | 4 |

Therefore a **greyscale screenshot** preserves all 256 glyphs as distinct rasters; a **monochromat** reads all 256; every dichromacy type is unaffected because no decision depends on chromatic discrimination. Canon's worst case — `teal` L 0.257 and `rose` L 0.293, 8 of 255 greyscale levels apart (1.12 : 1) — is resolved entirely by 45° vs 135°, a 90° angular separation, the maximum available. Two shipped tests make this falsifiable: (1) `render(g, monochrome: true)` and `render(g)` must produce **bit-identical coverage masks** for all 256 — colour may differ, geometry may not; (2) render all 256 at 44 pt @2×, convert to 8-bit luminance, assert pairwise L1 distance ≥ `T`, `T` asserted as a shipped constant.

### 13.6 The shader

One SwiftUI `.colorEffect(ShaderLibrary.loomGrain(...))` over the play surface, below the chrome bar.

```metal
[[ stitchable ]] half4 loomGrain(float2 p, half4 c, float2 size, float t, float amt) {
    float scan  = 1.0 + 0.028 * sin(p.y * 2.0943951);              // 3 px period, ±2.8 %
    float g     = fract(sin(dot(floor(p) + floor(t * 8.0), float2(12.9898, 78.233))) * 43758.5453);
    float grain = 1.0 + 0.032 * (g - 0.5);                         // ±1.6 %, reseeded at 8 Hz
    float2 d    = (p / size) - 0.5;
    float vig   = mix(1.0, 0.88, saturate(dot(d, d) * 2.0));       // 1.00 centre → 0.88 corner
    return half4(c.rgb * half(mix(1.0, scan * grain * vig, amt)), c.a);
}
```

Budget ≤ 0.4 ms/frame at 120 Hz on A15. `amt = 0` under Reduce Transparency, High Contrast, or `isLowPowerModeEnabled`. `t` is frozen at 0 under Reduce Motion (static grain, no shimmer).

### 13.7 Motion

**One orchestrated moment per round beats forty micro-animations.** Budget: at most one animation over 260 ms per screen state; the play surface has exactly two recurring animations (admit, reject), both under 260 ms, neither blocking input.

#### 13.7.1 The law-reveal, correct declaration — the money shot

Fires when the Seal is pressed and `extension(declared) == extension(hidden)`. Total **1,840 ms**, built as one `phaseAnimator` over a `RevealPhase` enum so the beats cannot drift apart.

| Beat | t (ms) | Dur | What happens | Easing |
|---|---|---|---|---|
| 0 | 0 | 90 | Seal depresses 2 pt; the machined bar, if any, retracts off the trailing edge | `easeIn` |
| 1 | 90 | 140 | All unlit Bench chrome → 0 opacity; the ribbon → 20 %; the Assay holds at full | `easeInOut` |
| 2 | 230 | 260 | The player's rule-tiles leave their rails and gather into one centred stack, 8 pt overshoot | `spring(.26, .78)` |
| 3 | 490 | 320 | The hidden law's tiles fade in **behind** the player's at 14 pt offset, 40 % opacity, then converge to zero offset — two readings of the same law registering onto each other | `easeOut` |
| 4 | 810 | 180 | **Registration.** A 4 pt `accent.brass` hairline sweeps leading→trailing at 1,900 pt/s; as it passes, each tile's stroke steps `stroke.primary` → `accent.brass`, staggered 0 / 60 / 120 ms by position | `linear` sweep, `easeOut` per tile |
| 5 | 990 | 220 | The Assay's lit constellation contracts into a 64 pt page thumbnail and docks below the stack | `spring(.30, .85)` |
| 6 | 1210 | 240 | Seal marks strike in, one per 80 ms; each scale 1.25 → 1.00 over 90 ms with a 60 ms brass bloom | `easeOut` |
| 7 | 1450 | 260 | The Codex page frame draws itself — a hairline rectangle stroked from the top-leading corner, clockwise | `easeInOut` |
| 8 | 1710 | 130 | A 3 pt global downward drift resolves to 0; the continue affordance fades in | `easeOut` |

**Why it reads as a mechanism unlocking:** beats 2–3 are *approach and misalignment*, beat 4 is *the pawl dropping*, beats 5–7 are *the result being filed*. No beat eases in and out symmetrically; each either accelerates into a stop or decelerates out of one.

**Interruption.** Taps before t = 400 ms are swallowed, so the moment always starts. A tap at t ≥ 400 ms snaps the phase to `.settled` immediately — no partial states. Backgrounding resumes at `.settled`.

**Round lost** (second strike, or cap reached) — same skeleton, **1,020 ms**: beat 2 unchanged; at beat 3 the hidden law fades in alone while the player's stack falls 24 pt and fades out over 180 ms; beat 4's sweep is `accent.cold`; beats 5–7 skipped; beat 8 runs at t = 890.

#### 13.7.2 Micro-responses

**Admit, 260 ms, never blocking** (the next probe may be issued at t = 0). t 0: throat glyph scale 1.00 → 1.04 over 70 ms `easeOut`, and a ring **expands** R → 1.35 R over 200 ms `easeOut`, opacity 0.9 → 0, weight 3 → 1 pt, `accent.brass`. t 70: scale 1.04 → 1.00 over 120 ms `spring(.18, .90)`. t 140: the new ribbon tile slides in from the trailing edge over 120 ms `easeOut`; the ribbon scrolls to hold it 24 pt off the trailing margin.

**Reject, 250 ms.** t 0: ring **contracts** 1.35 R → R over 160 ms `easeIn`, `accent.cold`; simultaneously a 130 ms shudder — ∓2 pt horizontal, leading → trailing → rest, amplitude 2 pt, **not** a bounce. t 160: the ring breaks into 4 arcs that separate 3 pt over 90 ms and fade. t 140: ribbon tile slides in with a cold hairline and an **open** ring.

> **Decision:** the non-colour encoding of the verdict is **ring direction and closure** — admit expands and stays closed, reject contracts and breaks. Colour, tone and haptic are three redundant copies layered on that. Under `shouldDifferentiateWithoutColor` the broken ring's gap doubles.

**Twin** — the verdict animation at 0.7 × amplitude plus canon's doubled ribbon ring; a twin must not read as a fresh discovery. **DRIFT moment** — 520 ms inserted at t = 230 of the reveal: pre-swap ribbon tiles desaturate to `stroke.secondary` (220 ms), a 2 pt brass rule draws downward through the ribbon at the swap index (180 ms), post-swap tiles brighten (120 ms). **SIEVE** — tap response inside 120 ms: a 90 ms ring only, no scale, no shudder. **Barred Seal** — the offending rail pulses 3 × 90 ms, 0.5 → 1.0 opacity; nothing else moves, no error text, no modal (canon).

#### 13.7.3 Screen transitions

| From → To | Transition | Duration |
|---|---|---|
| Home → mode | chrome bar persists; content pushes up 24 pt + crossfade | 280 ms `easeInOut` |
| Dial ↔ Bench | interactive drag on the Bench handle; the Dial slides down 332 pt; follows the finger, interruptible | ≤ 320 ms `spring(.32, .86)` |
| Assay → expanded inspector | zoom from the 64 pt well, `matchedGeometryEffect` | 300 ms `spring(.30, .88)` |
| Reveal → Codex page | the beat-5 thumbnail is the shared element | 340 ms `spring(.34, .86)` |
| Round end → next round | full crossfade through `ground` | 220 ms |
| Any → Settings | system sheet | system |

#### 13.7.4 Reduce Motion — complete substitution table

Every animation in the app appears here. The substitution is a crossfade unless motion *is* the mechanic.

| Animation | Normal | `isReduceMotionEnabled` |
|---|---|---|
| law reveal, correct | 1,840 ms, 8 beats | one 260 ms crossfade to the settled composition; marks already struck |
| law reveal, lost | 1,020 ms | 260 ms crossfade to the final state |
| admit ring | expands 200 ms | 160 ms crossfade of a **static closed** ring at 1.18 R, in then out |
| reject ring | contracts + breaks, 250 ms | 160 ms crossfade of a **static broken** ring at 1.00 R |
| throat scale 1.04 | 70 + 120 ms | none; opacity 1.0 → 0.72 → 1.0 over 160 ms |
| reject shudder | 130 ms translate | none; cold opacity pulse as above |
| ribbon tile slide-in | 120 ms slide | 140 ms crossfade in place |
| ribbon auto-scroll | animated | instant `scrollTo` |
| Dial ↔ Bench | interactive spring | 220 ms crossfade; the handle becomes a plain button |
| Assay expand | 300 ms zoom | 200 ms crossfade |
| Assay live morph per cell | 180 ms per cell | cells switch instantly; the whole Assay crossfades over 120 ms |
| Codex shared element | 340 ms | 220 ms crossfade |
| screen push | 280 ms | 220 ms crossfade |
| DRIFT moment | 520 ms, 3 parts | 240 ms crossfade to the final marked ribbon |
| Seal marks strike-in | 3 × 90 ms scale | already struck; 180 ms crossfade |
| streak bloom | 600 ms | 180 ms crossfade |
| Profile morph | 2.4 s continuous morph | new shape instantly; 240 ms crossfade |
| barred-Seal rail pulse | 3 × 90 ms | rail crossfades to `accent.cold` @ 0.5 α and back, 200 ms |
| empty-rail hairline pulse | 1.6 s loop | static hairline at 60 % |
| grain / scanline shimmer | reseeds at 8 Hz | frozen at `t = 0` |
| bloom pulse on admit | 120 ms | static bloom |
| **SIEVE glyph travel** | glyphs stream across the screen | **motion is the mechanic, so it is replaced, not removed** — §9.8 verbatim: the lane keeps its four stations and a glyph **crossfades lip → lane → gate → sump** at the identical cadence. Nothing translates; the *information the travel carried* is untouched. The gate dwell is byte-identical, the ±44 pt actionable rule is byte-identical, and the **preview count** — how many glyphs are visible above the gate at once — is unchanged at every band and tempo step. Scoring and difficulty are unchanged. |

**Why the SIEVE row is written that way, and the assertion that keeps it honest.** Collapsing the lane to a single centre slot would delete the *preview*, and the preview is not decoration: §9.3 budgets worst-case decision time as `preview + window` = 0.87 s + 0.226 s = **1.10 s**, and a one-slot substitution leaves roughly one inter-glyph period (≈ 0.34 s at band 6, `s = 3`). That would cut the hardest decision in the game to a third of its length for exactly the players who asked for less motion. The brief's rule is *replace every animation with a crossfade*, not remove what the animation was showing. A shipped test asserts `preview(n) + window(n)` is identical with Reduce Motion on and off, for every band 1–6 × every tempo step 0–3 × every `n`, and that the station a glyph occupies at time `t` is the same in both.

### 13.8 Audio

**Everything is computed per sample.** One `AVAudioEngine`, one `AVAudioSourceNode` into a mixer. No `AVAudioFile`, no buffers from disk, no assets. The render block is allocation-free and lock-free: a fixed 8-slot voice array with an atomic head index, oldest-stolen, polyphony capped at **6** (SIEVE at maximum speed requests ~12 cues/s; the cap holds).

**The scale: five-limit just intonation on D3 = 146.83 Hz.** Ratios in use: 1/1 (146.83), 6/5 (176.20), 4/3 (195.77), 3/2 (220.25), 9/5 (264.29), 2/1 (293.66), plus 45/32 (206.48) reserved exclusively for rejection. Just, not tempered, because a beat-free perfect fifth is *audibly* locked and a tempered one is not — the whole point of `admit` is that it resolves. **Admit is a just fifth; reject is a just tritone a fifth lower.** With no context whatsoever, admit is *up and settled*, reject is *down and unresolved*.

> **The cue table below is the single normative source for every sound in the app** — frequencies, waveforms, envelopes, levels and the interval logic. The mode sections own *beat positions* (which cue fires at which millisecond of which animation) and the channel-independence claim ("any one channel alone is sufficient", §6.4), and nothing else. Where §6.4's channel table or §6.8's beat sheets state a frequency, an interval or a duration — a minor second at 220/233 Hz, a 140 ms decay, a 220 Hz harmonic series — those numbers are superseded here and must be replaced by a citation. A reject built on a minor second is not a near-miss of this design, it is the opposite of it: the whole scheme rests on reject being a **tritone a fifth below** admit, which is a fall, where a minor second above the same root is a rise.

| Cue | Voices (Hz) | Waveform | Attack | Decay | Peak | Notes |
|---|---|---|---|---|---|---|
| `probe.submit` | 195.77 | triangle | 1 ms | 55 ms | −26 dBFS | key travel; a click with a pitch |
| `admit` | 220.25 + 330.37 + 660.75 (−18 dB) | sine ×3 | 4 ms | 260 ms | −16 dBFS | **3/2 just fifth**, beat-free |
| `reject` | 146.83 + 206.48 + 73.42 (−12 dB) | sine ×2 + triangle | 2 ms | 190 ms | −18 dBFS | **45/32 just tritone** + sub octave |
| `twin` | the verdict cue, gain ×0.72, one added partial at 2/1 | — | — | — | — | marks a repeat without new information |
| `declare` | 146.83 → 293.66, 180 ms exponential glide | sine | 8 ms | 340 ms | −14 dBFS | the Seal travelling |
| `bar` | 110.12 | square, LP 700 Hz | 0.5 ms | 45 ms | −28 dBFS | a dead thunk; no pitch movement |
| `strike` | 206.48 | square, LP 1.2 kHz | 1 ms | 120 ms | −20 dBFS | dry, mechanical |
| `correct` | 146.83, 176.20, 220.25, 293.66 — one per 90 ms | sine, 3 partials each | 6 ms | 300 ms (last 520) | −12 dBFS | onsets aligned to reveal beats 4 and 6 |
| `incorrect` | 146.83 + 206.48 held, dropping to 138.59 at t = 420 ms | sine + triangle sub | 8 ms | 900 ms | −16 dBFS | a semitone fall — the machine settling |
| `drift.moment` | 195.77 + a partner sliding 195.77 → 190.00 over 480 ms | sine ×2 | 30 ms | 620 ms | −18 dBFS | beat rate climbs 0 → 5.8 Hz: the pitch *slides off* |
| `sieve.tick` | 293.66 | sine | 0.5 ms | 22 ms | −30 dBFS | one per glyph arrival, metronomic |
| `sieve.hit` | 440.50 | sine | 2 ms | 90 ms | −22 dBFS | |
| `sieve.miss` | 110.12 | triangle | 1 ms | 140 ms | −22 dBFS | |
| `streak` | 146.83 plus one partial per streak step: 3/2, 2/1, 5/2, 3/1, 4/1 | sine | 6 ms | 600 ms | −14 dBFS | the chord *grows*; caps at 5 partials |
| `codex.inscribe` | 264.29 + 396.44 | sine | 10 ms | 700 ms | −20 dBFS | soft, long, under the reveal |

Envelopes are AD only — no sustain, no release stage; decay is exponential to −60 dB over the stated time.

**Mix.** Buses: play cues 0 dB, chrome cues −6 dB, `sieve.tick` −10 dB. Master ceiling −6 dBFS with a soft clipper `tanh(1.2x)/tanh(1.2)`; a 3-pole DC blocker on the source node. No cue peaks above −12 dBFS. Sample rate follows `AVAudioSession.sharedInstance().sampleRate`; the source node is rebuilt on a route change that alters channel count.

**Session policy.** Category `.ambient`, mode `.default`, options `[]` — `.ambient` **honours the hardware silent switch** and **mixes with other audio**, so a podcast keeps playing and Hunch sits over it. Never `.playback`; overriding the silent switch in a puzzle game is a hostile act. When `isOtherAudioPlaying`, drop the master a further **−4 dB**. On `interruptionNotification` `.began` pause the engine; on `.ended` with `.shouldResume` restart, otherwise stay stopped until the next user action. The engine **starts lazily on the first cue** and stops after **20 s of silence**, so a player with sound off never instantiates an audio unit. Settings: `Sound` toggle (default **on**) and `Level` — Normal / Low (−8 dB). Two states, not a slider.

### 13.9 Haptics

**The pattern table below is the single normative source for every haptic in the app** — event kinds, times, intensities and sharpnesses. As with audio, the mode sections own beat positions only; §6.4's "two short transients at 0 ms and 55 ms, sharpness 0.3" for `reject` is superseded by the `reject` row here (t 0.000 at Sh 0.90 and t 0.075 at Sh 0.90), and the difference matters — a soft, low double is admit's texture doubled, where reject must read as *hard and bright*, the opposite corner of the intensity/sharpness square from `bar`.

`CHHapticEngine`; patterns precompiled to `CHHapticPatternPlayer` on first use and cached (11 players, ≈ 2 KB). All calls no-op when `CHHapticEngine.capabilitiesForHardware().supportsHaptics == false`. `isAutoShutdownEnabled = true`; `resetHandler` and `stoppedHandler` recreate and re-prepare. `I` = intensity, `Sh` = sharpness.

| Pattern | Events |
|---|---|
| `probe.submit` | transient t 0.000, I 0.28, Sh 0.65 — a key click, quieter than either verdict |
| `admit` | **one** transient, t 0.000, I 0.55, Sh 0.30 — soft, round, low |
| `reject` | **two** transients, t 0.000 (I 0.45, Sh 0.90) and t 0.075 (I 0.30, Sh 0.90) — hard, bright, doubled |
| `twin` | transient t 0.000 (I 0.20, Sh 0.50), then the verdict pattern offset +0.060 s |
| `bar` | transient t 0.000, I 0.90, Sh 0.15 — the **only** high-intensity low-sharpness event in the game. A dull heavy thud: no give. |
| `strike` | transient t 0.000 (I 0.70, Sh 0.95); continuous t 0.020–0.260, I 0.35 → 0.00, Sh 0.60 |
| `law.declared.correctly` | continuous t 0.00–0.18, I 0.15 → 0.55, Sh 0.10 *(beat 3, convergence)*; transient t 0.810, I 0.75, Sh 0.85 *(beat 4, registration lands)*; continuous t 0.810–1.050, I 0.60 → 0.10, Sh 0.40; **N transients** at t 1.21 / 1.29 / 1.37 where N = marks earned (1–3), I 0.50 / 0.60 / 0.70, Sh 0.70 *(beat 6)*; continuous t 1.45–1.71, I 0.30 → 0.05, Sh 0.15 *(beat 7, the frame drawing)* |
| `law.broken` | transient t 0.000, I 0.85, Sh 1.00 *(the crack)*; continuous t 0.020–0.420, I 0.55 → 0.00, Sh 0.75 *(the ring shattering)*; transient t 0.420, I 0.35, Sh 0.20 *(the settle, on the semitone fall)* |
| `drift.moment` | continuous t 0.00–0.70 with `hapticIntensityControl` I 0.10 → 0.45 → 0.08 at control points 0.00 / 0.40 / 0.70 and `hapticSharpnessControl` ramping Sh 0.20 → 0.80. The sensation *slides*, matching the audio detune. |
| `streak` | N transients at 0.00 / 0.09 / 0.18 / 0.27 / 0.36 (N = streak, capped 5), I = 0.35 + 0.08 k, Sh 0.55 |
| `sieve.hit` / `sieve.miss` | transient I 0.40 Sh 0.75 / transient I 0.65 Sh 0.20 |

**Discriminability by feel alone:** admit is *one soft* event, reject is *two sharp* events, `bar` is *one blunt heavy* event. A player with the screen face-down can tell all three apart; this is a shipped manual-test item.

**Settings and system.** iOS exposes **no public read of the System Haptics switch** for Core Haptics (it gates `UIFeedbackGenerator` only), so our own `Haptics` **toggle** — default **on**, directly above `Sound` in §12.6's FEEDBACK section — is the player's control and is honoured before any engine call. It is a toggle and not a three-way: a "Light" tier would need a defined half-strength spelling of all eleven patterns above, and every one of them already has a visual and an audible twin, so the honest options are *these patterns* or *none*. Patterns longer than 0.4 s are additionally suppressed under `isLowPowerModeEnabled`; transients still fire. Haptics never carry information that is not also visual and audible.

### 13.10 VoiceOver

**Glyph label — canon's format, canon's order (`fill → shape → pips → hue`), one localized format string with four interpolations, never concatenated fragments:**

```
GLYPH_LABEL = "%1$@ %2$@, %3$@, %4$@"     → "hollow triangle, three pips, teal"
```

The `pips` interpolation is itself a plural-aware String Catalog entry ("1 pip" / "3 pips") — a complete grammatical unit, not a glued fragment. Accessibility labels are audio; canon's no-text rule constrains rendered pixels only, so numbers (probe count, par, cap, marks) *are* spoken even though they are never drawn.

| Element | Traits | Label | Value | Custom actions |
|---|---|---|---|---|
| the throat | `.image`, `.updatesFrequently`, `.adjustable` | "Loom throat" | glyph label + last verdict | swipe ↑/↓ steps the last-touched attribute ±1 rank |
| ribbon tile | `.button` | glyph label | "admitted" / "rejected" / "seed glyph" / "twin" | "Load into the Dial" |
| Dial ramp / cell | container / `.button` `.isSelected` | "Fill" / "striped" | current value / "selected" | — |
| PROBE key, twin key | `.button` | "Probe" / "Twin" | the composed / last-probed glyph label | — |
| probe tally | `.staticText`, `.updatesFrequently` | "Probes" | "12 of 23 expected, 37 maximum" | — |
| Bench handle | `.button` | "Bench" | "1 of 2 rails filled" | — |
| palette stamp ×4 / rail | `.button` / container | "Ramp tile", "Bridge tile", "Fork tile", "Tally tile" / "Rail 1" | — / that rail's narration | — / "Clear rail" |
| Ramp tile / cell | container / `.button` `.isSelected` | "Ramp on shape" / "triangle" | "admits triangle, hexagon" / "admitted" | — |
| Bridge socket / ghost toggle | `.button` / `.button` `.isSelected` | "Leading socket", "Trailing socket" / "Previous glyph" | "pips, this glyph", "pips, previous glyph", "empty" / "on", "off" | — |
| wedge / coupler | `.button` | "Comparator" / "Coupler" | "greater than" / "and", "or", "exclusive or" | "Cycle" |
| Fork docks | containers | "Gate" / "Then" / "Else" | "hue is amber" / "pips admits three, four" | — |
| Tally attr toggle / counter dial | `.button` `.isSelected` / `.adjustable` | attribute name / "Count" | "counted" / "admits 0, 2 and 3" | — |
| the Assay | `.image`, `.updatesFrequently` | "Assay" | the **lit count of the slice on screen** — "Admits 64 of 256 glyphs, with this previous glyph" for a contextual draft, "Admits 64 of 256 glyphs" for a stateless one. Never the unconditional marginal: canon §4.3 makes the live Assay a *slice* of the pair table pinned to the ghost, and quoting the projection instead would say 48 where the screen shows 64 | "Inspect", **"Read by attribute"** |
| the Seal | `.button`, `.notEnabled` when barred | "Seal" | "ready" / "barred, rail 2 is empty" | — |
| ECHO primer strip / a primer glyph | container / `.staticText` | "Primer" / glyph label | "3 glyphs" / "admitted" / "rejected" | — |
| ECHO rail / rail tile | container / `.button` | "Rail" / glyph label | "2 of 16 placed" / "position 2" | "Return to the tray" |
| ECHO tray tile | `.button` `.isSelected` when placed | glyph label | "placed, position 2" / "not placed" | — |
| SIEVE gate | `.button`, `.updatesFrequently` | "Gate" | the glyph label of whatever is actionable, announced on gate entry; its resolution announced in the sump (§9.8) | **"Admit"** |
| SIEVE tail | container | "Tail" | the last 6 resolved glyphs, each label + "admitted" / "rejected" | — |

**"Read by attribute"** solves the 256-cell grid: instead of exposing cells, it speaks the sixteen marginals — *"Of glyphs with shape triangle, 12 of 64 admitted"* — as one interruptible announcement. That is the non-visual equivalent of reading a constellation's density, it leaks nothing (the Assay shows the player's own draft), and it takes 20 s versus an impossible 256 swipes.

**The Bench narration — the hard part.** The Bench container exposes an `accessibilityValue` synthesized by a `LawNarrator` in `HunchCore` that walks the draft AST and emits **one localized sentence**: *"Pips of this glyph is greater than pips of the previous glyph, and shape admits triangle or hexagon."* Rules, enforced by test: it describes **only the player's own draft or an already-revealed law**, never a hidden law mid-round; it uses the same String Catalog fragments as the Codex page, so a narrated law and a rendered law are the same law in two media; **parity invariant** — the narrator says nothing a sighted player cannot read off the tiles, asserted by walking 10,000 generated laws and checking that `parse(Bench.layout(for: law))` and `narrate(law)` describe the same extension. This is the only place in the app where a law appears in words, and it is audio-only, so the no-text rule is intact.

**Rotors, Magic Tap, escape.** Custom rotors: **"Rails"** (rail 1, rail 2, coupler, Seal — cuts a full declaration traversal from ~22 gestures to ~16); **"Attributes"** (jumps between the Dial's four ramps); **"Probes"** (steps backward through the ribbon, newest first, announcing glyph + verdict); **"Counterexample"** (exists only after a strike; two stops — the counterexample glyph and the nearest ribbon tile it was chosen against). **Magic Tap** = Probe on the Dial, Seal on the Bench — the single largest VoiceOver win in the app. **Escape** (two-finger scrub) closes the Bench or the expanded Assay. `.headings` rotor on Codex, Profile, Settings.

**Announcements.** Priority `.high` on verdicts so they interrupt. Order is fixed — **verdict → evidence → bookkeeping** — so a fast player can move on after two words.

| Event | Announcement |
|---|---|
| admit / reject | "Admit. Hollow triangle, three pips, amber. Probe 12 of 23." / "Reject. …" |
| twin | the same, prefixed "Twin. " |
| past par / 5 from cap | "Past the expected probe count." / "Five probes remaining." — each once per round |
| cap reached | "Probe limit reached. Round over. The law was: {narration}." |
| barred Seal pressed | "The Seal is barred. Rail 2 is empty." |
| declaration correct | "Correct. {narration}. Inscribed. Three marks. Fifteen probes." |
| first incorrect (strike) | "Incorrect. Strike one of two. Counterexample: solid square, two pips, rose. Your law rejects it; the Loom admits it. The round continues." |
| second incorrect | "Incorrect. Round over. The law was: {narration}." |
| DRIFT swap revealed | "The law changed after probe 9." |
| streak / screen change | "Streak: four." / `.screenChanged` with the screen name |

**Worked walkthrough — declaring canon's band-5 law under VoiceOver** (`RANK pips(cur) > PREV RANK pips AND shape ∈ {triangle, hexagon}`; nine taps sighted, sixteen gestures here):

1. Rotor → "Rails" → Bench. *"Bench. Rail 1 empty, rail 2 empty. Seal barred."*
2. Swipe to "Bridge tile", double tap. *"Bridge added to rail 1. Leading socket empty."*
3. Swipe to the first socket, double tap → the four attribute headers become focusable inside it; swipe to "Pips", double tap. *"pips, this glyph."*
4. Swipe to "Previous glyph", double tap. *"Previous glyph on."* — the entire contextual grammar, one toggle.
5. Swipe to "Comparator", double tap until *"greater than."* Swipe to the other socket, double tap, swipe to "Pips", double tap.
6. Swipe to "Coupler". *"Coupler, and."* Leave it. Swipe to "Ramp tile", double tap; "Attribute", double tap; "Shape", double tap.
7. Swipe to "triangle", double tap. *"triangle, admitted."* Swipe ×2 to "hexagon", double tap.
8. Rotor → "Rails" → Bench reads the full narration. Optionally: Assay → "Read by attribute" to hear the marginals first.
9. Two-finger double tap (Magic Tap) → the Seal fires.

Every step is a single-finger swipe or a double tap. Canon already forbids drag, pinch, long-press and double-tap-to-mean-something-else in the declaration UI, which is exactly why this works: **there is no gesture on the Bench that VoiceOver cannot perform.**

### 13.11 Dynamic Type and the remaining accessibility settings

| Screen | Behaviour at AX3 – AX5 |
|---|---|
| PROBE / Dial | No text on the surface. Art scales with the type multiplier to canon's **1.35× ceiling (AX2)**; above AX2 geometry freezes at 1.35× and the four ramps scroll vertically inside y 236–508. The commit bar is pinned and never scrolls. |
| Bench | Above AX2, canon's **single-rail pager** engages. The Assay moves from the 64 pt trailing column to a full-width 343 pt strip under the rail. The palette becomes a 2×2 grid of 165 × 56 pt stamps. |
| Codex list / page | Rows reflow to two lines; the glyph thumbnail is fixed at 44 pt and never scales (it is a picture, not text) and row height grows. On a page, rule-tiles freeze at 1.35× and metadata scrolls below. |
| Profile | The portrait card holds canon's geometry — 375 × 280 pt, `R0 = 96 pt` (§11.10) — and does **not** scale with type: it is a drawing, not text. The five **vertex sigils** reflow from a ring to a vertical list at AX3, each keeping its 44 × 44 pt hit rect; the stat block goes one item per line. The axis names appear at no size, because they do not exist in the app (§11.11 P3). |
| Anomaly / Statistics / Settings | Dates and counters in monospaced numerals, wrap, never scale down. The Anomaly's 28-cell ribbon holds its cell size and reflows 28 × 1 → 7 × 4. Statistics and Settings are standard `Form`s, `.lineLimit(nil)`, toggles keep 44 × 44 pt. |
| Onboarding-by-doing | Has no text by construction; unaffected. |

Snapshot test: every screen × AX5 × {English, German, Turkish, Russian, Arabic}, asserting zero truncation and zero horizontal overflow.

**Reduce Transparency** — shader `amt = 0`; bloom off; every material becomes opaque `ground.raised`; the Bench scrim goes from a 0.6 α blur to a flat 0.85 α `ground`.

**Bold Text** — every type role steps one weight (regular → medium → semibold → bold), **and glyph and rule-tile stroke weights step ×1.25** (`body` 3.0 → 3.75, `bodySm` 1.5 → 1.875, `hairline` 0.5 → 0.625). The play surface has no text, so Bold Text is the only signal the system gives us that this player wants heavier marks; honouring it there is more useful than ignoring it.

**Differentiate Without Colour** — true by construction. When on, additionally: ribbon admit tiles draw a fully closed ring and reject tiles a broken ring at 2× the normal gap; and the counterexample's two rings take distinct dash patterns (solid = the Loom's verdict, dashed = your declaration's), so the two contradictory readings are separable without either colour or memory.

**High Contrast theme** — canon's rules made concrete: all four `hue.*` render as `stroke.primary`; the index stroke goes `0.273·S` → `0.409·S` (12 → 18 pt at the ribbon tile); shader off; all stroke weights +0.5 pt; unlit ramp cells go 25 % → 40 % opacity and their diagonal cancel hatch 1.0 → 2.0 pt. Every token clears **9.7 : 1**; the primary pair clears **21 : 1**.

### 13.12 Accessibility acceptance checklist

Each line is a gate before any release build and has a matching entry in `tests.json`.

1. All 256 glyphs render as pairwise-distinct greyscale rasters at 44 pt @2× (automated).
2. `render(g, monochrome:)` produces bit-identical coverage masks for all 256 (automated).
3. A complete band-5 round — probe, twin, declare, strike, re-declare, inscribe — is playable end to end with the screen curtain on.
4. Every interactive element has a non-empty, non-duplicated label; the Accessibility Inspector audit is clean on every screen in §12.2's inventory.
5. Magic Tap fires Probe on the Dial and the Seal on the Bench; two-finger scrub closes the Bench and the Assay.
6. All four custom rotors present and correct in context, including "Counterexample" appearing only after a strike.
7. The Bench narration matches the rendered tiles for 10,000 generated laws (automated parity test).
8. AX5 × 5 locales: zero truncation, zero horizontal overflow, all targets ≥ 44 × 44 pt (snapshot).
9. Reduce Motion on: nothing translates, scales or rotates anywhere, including SIEVE; every substitution in §13.7.4 verified by hand. Automated alongside it: `preview(n) + window(n)` and the station occupied at time `t` are identical with Reduce Motion on and off, across bands 1–6 × tempo steps 0–3.
10. High Contrast on: every foreground/background pair ≥ 4.5 : 1, hue is index-stroke-only, all 256 glyphs remain distinguishable.
11. **Audio session, stated as what is checkable.** iOS exposes no public read of the ring/silent switch, so "engine never started" is neither implementable nor verifiable and is not claimed. Instead: (a) automated — the session category is `.ambient`, mode `.default`, options `[]`; (b) manual — with the silent switch on, output is inaudible and every verdict remains readable from geometry and haptics alone; (c) manual — with other audio playing, `isOtherAudioPlaying` drops the master −4 dB and the other audio is never ducked, paused or interrupted. The lazy start and the 20 s-idle stop are asserted separately as an engine-lifecycle test: no `AVAudioUnit` is instantiated before the first cue, and the engine is stopped 20 s after the last.
12. Haptics: admit / reject / `bar` are distinguishable face-down by three testers who were not told which is which.
13. Nothing in the UI, App Store copy or onboarding claims or implies a cognitive, memory, focus, intelligence or health benefit. Re-read every string before submission.
## 14. Feature Inventory, Scope and Open Decisions

### 14.1 The complete feature inventory

This table is the checklist the engineer builds against. **P0** must ship or the game is not the game; **P1** should ship and is individually droppable under schedule pressure; **P2** is nice and is cut first. Anything described anywhere in §1–§13 appears here.

| Feature | What it is | Pri | Spec |
|---|---|---|---|
| **CORE SYSTEMS** | | | |
| Glyph model | 4 attributes × 4 values, `glyphID = fill*64 + shape*16 + pips*4 + hue`; canonical order `fill → shape → pips → hue` everywhere | P0 | §2 |
| Rule AST + BNF | `<atom> <rel> <ctx> <guard> <aggregate>`, one coupler, `MAX_DEPTH 2` / `MAX_LEAVES 4`, no `NOT` | P0 | §3.2, §3.4 |
| Evaluator | `law.evaluate(cur, prev)`; `prev` = previously *probed* glyph, seed glyph primes position 0 | P0 | §3.5 |
| Extension tables + masks | `Bitboard256` / `Bitboard65536` with cross-arity lifting, over ~54 KB of resident precomputed masks | P0 | §3.6 |
| RNF canonicaliser | complement-fold, commutative sort, `cur`-leading contextual, set-algebra merge, constant-fold | P0 | §3.4 |
| Equivalence, dedup, liveness | extension identity is the only comparison; 64-bit hash key; ⊤/⊥ dead-term substitution and attribute pivotality | P0 | §3.6 |
| Lower-band index | 9,767 stateless tables (305 KB) band-partitioned + 17,248 contextual hashes (138 KB) | P0 | §3.6 |
| `difficulty(of:)` | family base × 0.125 plus five bounded modifiers summing to ≤ 0.124 | P0 | §5.1 |
| Band table | 8 bands, one family each, `\|H\|` = 40/1,272/108/2,322/6,934/5,688/10,314/337 | P0 | §5.2 |
| Generator | `generate(seed:band:targetδ:mode:avoid:)`, pure over five args, 200 attempts then family anchor | P0 | §5.3 |
| Guardrails G1–G10 | satisfiable, falsifiable, admit window [0.15,0.60], not-secretly-easier, no dead terms, liveness, genuinely contextual, band fidelity, novelty, constructible | P0 | §5.3 |
| Seeded RNG | SplitMix64 conforming to `RandomNumberGenerator`; every puzzle reproducible | P0 | §5.3 |
| Par / cap / scoring | par 7…29, cap = ceil(1.6·par), `1000·min(1,par/probes)·(strike?0.6:1)`, marks at 0.6·par / par / cap | P0 | §5.4, §6.9 |
| Serving layer | seed choice, `avoid` assembly (50-entry novelty ring + shelf soft-avoid + today's Anomaly), 8-entry lost-law cooldown | P0 | §5.3, §6.10, §11.3 |
| **PROBE** | | | |
| Round state machine | `RoundPhase` 8 states, `Outcome` 5 cases; model never waits on an animation | P0 | §6.1 |
| Play surface layout | SE 375×667 reference + Pro Max derivation; surplus height goes to throat and ribbon | P0 | §6.2 |
| The throat | 96 pt live glyph, is the draft, only the changed register animates | P0 | §6.2, §6.3 |
| The ribbon | 44 pt tiles, link arcs, ghost mark on the trailing tile, doubled/split ring for twins | P0 | §6.2, §6.6 |
| The spool sheet | full-screen 7×10 grid (70 cells ≥ max cap + 1), chain order + verdict sort, tap to ribbon-load | P1 | §6.2 |
| The Dial | four single-select ramps, retains the last probe, preloaded with the seed glyph; throat swipe steps ±1 and a ribbon tap loads wholesale | P0 | §6.3 |
| The twin key | one tap re-probes the identical glyph; never blocked, never refunded | P0 | §4.1, §6.3 |
| Verdict beat | 420 ms (320 ms Reduce Motion), constant 260 ms adjudication hold, single-slot input queue | P0 | §6.5 |
| Admit / reject encoding | ring completes vs contracts-and-breaks; colour, audio and haptic are redundant copies | P0 | §6.4 |
| The breath | twin key pulses past 0.6·par if never pressed; same rule in every band | P2 | §6.6 |
| The Bench | rails, palette, coupler, wedge, ghost toggle, tap and trailing-swipe only; Ramp / Bridge / Fork / Tally = atom / relational-contextual / guard / aggregate, distinct at silhouette level | P0 | §4.2 |
| Palette ceiling | tile classes unlock at lifetime maximum band *served* + 1; raised at serve time if insufficient | P0 | §4.4, §10.4 |
| The Assay | 16×16 live extension grid conditioned on the pinned ghost; expandable read-only inspector | P0 | §4.3 |
| Assay evidence overlay | ribbon rings + wrong-cell flash, unlocked at band 4 (and always on the Anomaly) | P1 | §4.3, §10.6 |
| The Seal + machined bar | barred while any rail is inert, any socket unbound, or the extension constant; pressing pulses the rail | P0 | §4.3 |
| Declaration verdict | extension identity in the common space; spelling, order and complement direction irrelevant | P0 | §4.5 |
| Counterexample | deterministic: disagreements → prefer false negatives → min Hamming to ribbon → lowest `glyphID`; two rings, docks as a marginal island | P0 | §4.5, §6.8 |
| Two strikes | first continues the round, second ends it; cap-loss reveals the law in rule-tiles | P0 | §4.5 |
| Par tick row + par crossing | proportional unlit row fills; at par it inverts and the dim cap row begins emptying. Geometry only, no cue | P0 | §5.4, §6.9 |
| Reveal beat sheets | correct 2,480 ms / broken 1,660 ms / exhausted 2,040 ms, all absolute from the Seal press | P0 | §6.8 |
| Mid-round snapshot | `ProbeSnapshot` after every verdict; stores the resolved `LawNode`, recomputes verdicts; 900 ms re-entry beat | P0 | §6.10 |
| Abandon semantics | 0 probes → discarded; ≥1 probe → `abandoned`, score 0, no θ update, target sticky | P0 | §6.10 |
| **DRIFT** | | | |
| Two-law generation | `L₂` is a one-leaf edit of `L₁`, same family and skeleton; pair guardrails D1–D7 | P0 | §7.2 |
| The hinge | fires at satiation (`N_admits ~ U[3,6]`), capture (a correct pre-hinge declaration, which writes the seam marker), or forced at 0.80·par | P0 | §7.3 |
| Lifecycle + budgets | `DriftPhase`, bands 3–8 only, `par_DRIFT` 25…40 and `cap_DRIFT` 40…64, marks carry `rec(b)` | P0 | §7.4, §7.7 |
| Dead-law counterexample | step 0 prefers a ribbon glyph whose verdict differs under `L₁` and `L₂`; renders as the twin ring | P1 | §7.6 |
| Transcript metrics | `t_hinge`, `t_evidence`, `t_recover`, cling `C`, latency `R`, `deadDeclaration` — never displayed | P1 | §7.8 |
| The hinge reveal | seam → split into two lanes → dead stretch hatched → 900 ms morph of the single edited leaf → hold | P0 | §7.9 |
| **ECHO** | | | |
| The echo pool | last 8 inscribed Codex laws; selected, never generated; G9 bypassed by construction | P0 | §8.2 |
| The pool strip | 8 extension thumbnails; each primer verdict extinguishes every inconsistent member | P0 | §8.2 |
| The primer | `m ∈ {3,4,5}` ringed glyphs whose verdict vector is unique across the pool; on screen all round | P0 | §8.2 |
| The cast | `L` distinct glyphs at fixed cadence, no verdicts, ribbon dark, link arcs between them | P0 | §8.3 |
| Tray and rail | tray in canonical `glyphID` order, rail holds the ordered answer, tap to lift / tap to return | P0 | §8.3 |
| One replay | twin key replays the cast once per round at ×0.6 score; rail preserved | P1 | §8.3 |
| Load index ℓ | 1…8 → `L` 6…14, `A` 2…6, cadence 1400…850 ms; `δ_ECHO` from law difficulty + ℓ | P0 | §8.6 |
| ECHO scoring | `setF1²·(0.70+0.30·order)·replayF`; success iff `setF1 == 1`; order via LIS, never pass/fail | P0 | §8.7 |
| Interruption policy | one free cast restart; a second interruption abandons with no ability update either way | P1 | §8.9 |
| **SIEVE** | | | |
| Conveyor geometry | lip / lane / gate / sump / tail; the 375×88 pt gate is the only actionable region, and 132 pt pitch > 88 pt gate means at most one glyph is ever actionable | P0 | §9.2 |
| Speed curve | `r(n)` linear in **glyph index**, six band rows, tempo step `s ∈ {0..3}` adding 0.20·s | P0 | §9.3 |
| Stream composition | tell 12 (weight 0.5, no fouls) / body = remainder / run-out 25 %, guardrails S1–S5 | P0 | §9.4 |
| Fouls and outcomes | hit / correct pass / miss / foul; three fouls end the run; misses never do | P0 | §9.5 |
| SIEVE scoring | `ratio` over resolved glyphs × `completion`; marks read off `yield`; page at `ratio ≥ 0.92` | P0 | §9.6 |
| Difficulty mapping | law band capped at 6, ability above absorbed by `s`; effective `band_SIEVE ≤ 7` | P0 | §9.7 |
| Pause and run-up | freeze at the next glyph boundary, resume on a deliberate gate tap, 3-glyph run-up at `r₀` | P0 | §9.8, §12.7 |
| Void / sticky / abandon | termination voids and freezes the target, the third consecutive one is scored; a two-tap chevron abandon scores as a foul-out at the last resolved glyph | P0 | §9.8 |
| Steady stream | fixes `r` at `r₀` at ×0.85 score, ungated, does not disable inscription | P1 | §9.8, §12.6 |
| **ADAPTIVE** | | | |
| Ability model | `core` + three mode offsets, `n` per mode, θ clamped [−6,+6]; `P(win) = σ(θ − δ)` | P0 | §10.1 |
| Update rule | `θ += K(n)·(x − P)`, `K = max(0.18, 0.90/(1+n/8))`, strictly symmetric, pure and unit-testable | P0 | §10.2 |
| Serving policy | 13 ordered steps: ability → target → mode bias → pressure → jitter → clamp → quantise → mode clamp → family guard → ceiling rotation → re-derived `targetδ` → record → dispatch | P0 | §10.3 |
| Pressure term | `reach` (up fast on streak) − `relief` (down after 2 losses) − `π₀ = 0.44` centring constant | P0 | §10.3 |
| Cold start | galloping ladder over bands 1,2,4,6,8; `core` seeded from the first loss; full palette during calibration | P0 | §10.4 |
| Palette sufficiency | `paletteTileClasses ⊇ tileClasses(Family(servedBand))` asserted before the round arms | P0 | §10.4 |
| Difficulty is never a number | exactly three signals: par row length, palette ceiling, Codex shelves; plus a sub-numeric drone step | P0 | §10.5 |
| Anti-frustration | relief ladder, family repeat guard, floor rescue at band 1, sticky target on abandon, cap reveal | P0 | §10.7 |
| Anti-boredom | ceiling variation (tightened 0.45·par mark), shelf soft-avoid, ceiling rotation, weak-mode sigil lift | P2 | §10.8 |
| Absence and return | θ never decays; `n` decays past 7 days and re-entry `relief` ramps the player back in ~4 rounds | P1 | §10.9 |
| Simulated player harness | Level A `ResponseHarness` (10⁶ rounds < 0.4 s) and Level B `ReasonerHarness` with a mis-specified human prior | P0 | §10.10 |
| **CODEX** | | | |
| `CodexPage` model | keyed on the extension; AST stored, table rebuilt; bests, modes seen, fracture, burnish, drift partner | P0 | §11.1 |
| Page rendering | rule-tiles at 0.78×, that law's Assay with a draggable ghost, the instrument strip | P0 | §11.1 |
| Duplicates | never mint a second page; re-inscribe in place with a re-strike ring, improve the bests | P0 | §11.3 |
| Fracture and burnish | a strike marks the page and a later clean find heals it; an ECHO 3-mark round latches `burnished` and sets ECHO's `modesSeen` bit and nothing else | P1 | §11.1, §11.3 |
| Taxonomy and browse | band → skeleton → canonical key; 8 shelf plates, 5-column grid, rail scrubber snapping to skeletons | P0 | §11.2 |
| Extension thumbnails | 16×16 constellation; contextual laws project to four ink densities reusing the fill ladder | P0 | §11.2 |
| Slot maps vs accretion | bands 1/3/8 (`\|H\| ≤ 512`) draw every slot and can be sealed; the other five use log-scaled fill arcs | P1 | §11.4 |
| Facet bar | five stamps: mode, unfractured-only, anomaly-only, attribute participation, 3-marks-only | P2 | §11.2 |
| **ANOMALY** | | | |
| Derivation | `utcDayIndex` → frozen `ANOMALY_SALT` → SplitMix64 finaliser → band 4–7 → jitter → `targetδ` | P0 | §11.6 |
| One attempt per UTC day | full PROBE round, two strikes, the band's own par and cap; never re-offered | P0 | §11.7 |
| High-water anti-cheat | monotone `highWaterDay`, `.clockBehind` lock, jump detection, reset immunity for `anomaly.json`/`.hw` | P0 | §11.7 |
| Grants and isolation | full palette and Assay overlay for that round only; never updates θ, reach, relief or streaks; feeds the Codex fully and the Profile at 0.5 weight | P0 | §10.6, §11.6 |
| Tally, streak, ribbon | tally is the headline numeral, streak is the secondary ring, 28-cell ribbon with tap-to-reveal any past law | P1 | §11.8 |
| **PROFILE** | | | |
| Five axes | Induction, Retention, Flexibility, Restraint, Tempo — one normative sample formula each | P0 | §11.9 |
| Update rule | `value += α(sample − value)`, `α = w·max(0.06, 1/(n+1))`, `n` capped at 60, no value decay | P0 | §11.9 |
| Restraint margin | `H_live` consistency count against the band's materialised set; skipped at bands 5 and 7 | P1 | §11.9 |
| Geometry | five vertices, mean-normalised radii, closed Catmull–Rom spline, no gridlines or numerals | P0 | §11.10 |
| Tremble and morph | vertex noise amplitude falls as `n` rises; a 2.4 s staggered spring on entering the screen, never during play and never at round end | P1 | §11.10, §11.11 |
| The 90-day ghost | previous contour at 12 % opacity, self-to-self, shape only | P2 | §11.10 |
| Vertex sigils | five vector marks drawn from the existing vocabulary; the axis names exist nowhere in the app | P0 | §11.11 |
| Statistics screen | 5 sections, 19 labelled rows, read-only; no θ, no band-as-level, no attendance metric | P1 | §11.12 |
| **SCREENS / NAVIGATION** | | | |
| 18 screens | the exact inventory of §12.2, portrait-only, dark-first, no tutorial/store/share/rating screen | P0 | §12.2 |
| The Frame | idle Loom, 2×2 mode rack, Codex/Profile shelf, Settings and Anomaly keys | P0 | §12.4 |
| Mode sigils, key states, gates | barred / idle / suspended-with-arc, textless; modes unlock on archive evidence, not round counts — DRIFT on a band-≥ 3 page, ECHO at ≥ 5 pages, SIEVE at ≥ 8, set once in §9.10 | P0 | §9.10, §12.4 |
| Play key + ≤2-tap rule | every non-play screen carries a 44 pt throat sigil; `NavigationDepthTests` walks the route graph | P0 | §12.3 |
| Leaving a round | leading chevron suspends silently in PROBE/DRIFT/ECHO; SIEVE has no chevron while streaming — the exit exists only from `paused`, needs a confirming second tap, and is scored as a foul-out, not voided | P0 | §9.2, §12.7 |
| `SievePauseOverlay` | 70 % scrim, frozen lane, resume on a gate tap | P0 | §12.2, §12.7 |
| Reset confirm alerts | five variants, one per DATA row, cancel focused | P1 | §12.2 |
| **ONBOARDING** | | | |
| Fixed opening round | seed `0x48554E4348`, law `shape ∈ {triangle}`, seed glyph 22, generator bypassed | P0 | §12.5 |
| 13-beat reveal script | one affordance at a time: PROBE key → shape ramp → three more ramps → handle → palette → Seal | P0 | §12.5 |
| `OnboardingLedger` | success iff declared correctly with ≥1 self-constructed probe, an admit, a reject and a bound attribute | P0 | §12.5 |
| Elastic cap | the cap does not end the opening round while `sawReject == false`; hard stop at probe 24 | P0 | §12.5 |
| Five nudges | idle, no-Bench, barred-Seal, global idle, unvaried — a breath and nothing more, never a hint | P1 | §12.5 |
| Frame withheld | first launch opens on the machine; the Frame is revealed when round 1 ends | P0 | §12.4 |
| **SETTINGS** | | | |
| DISPLAY | Theme (System/Dark/Light/High Contrast), Grain, Reduce motion, Left-hand keys | P0/P2 | §12.6 |
| FEEDBACK | Haptics, Sound, Level (Normal/Low) | P0/P1 | §12.6 |
| PLAY + VOICEOVER | Confirm the Seal, Steady stream; Detail (Full/Terse), Announce verdicts, Announce the Assay | P1 | §12.6 |
| LANGUAGE | 13-option override defaulting to System, applied without relaunch | P0 | §12.6, §12.9 |
| DATA | five destructive actions with distinct alert bodies; none touches the Anomaly ledger | P0 | §12.6 |
| ABOUT | version, build, no-data-collected statement, storage status | P1 | §12.2 |
| **ART / MOTION** | | | |
| Palette tokens | three themes, WCAG-checked, `Theme.token(_:)`, no literal hex in view code | P0 | §13.2 |
| Register segregation | `accent.*` never on a glyph, `hue.*` never on chrome; light-theme keyline under every hue | P0 | §13.2 |
| Strokes, corners, grid | five weights, miter joins with zero radius on silhouettes, 4 pt grid, 16 pt margins | P0 | §13.3 |
| Typography | seven roles, condensed small caps for instrument labels, SF Mono for every numeral | P0 | §13.4 |
| Glyph geometry | silhouette / contour nodes / fill texture at fixed pitch / index stroke at four rotations | P0 | §13.5 |
| Bloom | double stroke per glyph plus one blur layer per glyph-bearing region; Assay excluded entirely | P1 | §13.5 |
| `loomGrain` shader | one `colorEffect`: scanline, 8 Hz grain, vignette; ≤ 0.4 ms/frame; `amt = 0` on three conditions | P1 | §13.6 |
| The law-reveal | 8-beat `phaseAnimator`, brass registration sweep, skippable from t = 400 ms of the reveal | P0 | §13.7.1 |
| Micro-responses + transitions | admit, reject, twin, DRIFT moment, SIEVE tap, barred-Seal pulse, all under 260 ms and non-blocking; six screen transitions including the interactive Dial↔Bench drag | P0/P1 | §13.7.2, §13.7.3 |
| Reduce Motion table | every animation in the app has a named substitution; SIEVE is replaced, not removed | P0 | §13.7.4 |
| **AUDIO** | | | |
| Procedural engine | one `AVAudioEngine` + `AVAudioSourceNode`, allocation-free render, 6-voice polyphony, no assets | P0 | §13.8 |
| Cue table | 15 cues on five-limit just intonation; admit = just fifth, reject = just tritone a fifth below | P0 | §13.8 |
| Mix and session policy | three buses, −6 dBFS ceiling with soft clipper and DC blocker; `.ambient` honouring the silent switch, mixing with other audio at −4 dB, lazy start and 20 s idle stop | P0 | §13.8 |
| **HAPTICS** | | | |
| Core Haptics patterns | 11 precompiled players; admit one soft, reject two sharp, `bar` one blunt heavy | P0 | §13.9 |
| Engine lifecycle and toggle | capability no-ops, `resetHandler`/`stoppedHandler`, auto-shutdown; our own Haptics switch is the control (iOS exposes no public read); Low Power drops patterns over 0.4 s | P0 | §13.9 |
| **ACCESSIBILITY** | | | |
| VoiceOver element map | every control labelled, valued and traited across all 18 screens | P0 | §13.10 |
| Glyph label | one localized format string, four interpolations, plural-aware pips, never concatenated | P0 | §2, §13.10 |
| `LawNarrator` | one sentence per draft or revealed law, sharing the Codex's catalog fragments, parity-tested | P0 | §13.10 |
| "Read by attribute" | speaks the sixteen Assay marginals instead of exposing 256 cells | P1 | §13.10 |
| Rotors, Magic Tap, announcements | four custom rotors, Magic Tap = Probe/Seal, two-finger scrub escapes; announcements in fixed order verdict → evidence → bookkeeping at `.high` priority | P0 | §13.10 |
| Dynamic Type | art scales to a 1.35× ceiling; Bench single-rail pager, ECHO two-column tray, 5→2 Codex columns at AX2+ | P0 | §12.8, §13.11 |
| Targets and reach | ≥44×44 pt (smallest shipped 56×44), three reach tiers, everything above y=220 read-only or undo-shaped | P0 | §12.8 |
| System settings | Reduce Transparency, Bold Text (steps stroke weights ×1.25), Differentiate Without Colour | P1 | §13.11 |
| High Contrast theme | hue → `stroke.primary`, index stroke 12→18 pt, shader off, +0.5 pt strokes | P0 | §13.11 |
| Triple-encoding proof | greyscale distinctness and monochrome-mask identity for all 256 glyphs | P0 | §13.5.1 |
| **LOCALIZATION** | | | |
| String Catalog | `Localizable.xcstrings`, ~228 keys, hard budget 250 asserted by test | P0 | §12.9 |
| Twelve languages | en, de, fr, es, pt-BR, it, tr, ru, ja, ko, zh-Hans, ar | P0 | brief, §12.9 |
| Zero play-surface strings | `PlaySurfaceTextTests` fails the build on any `Text`/`Label` outside `.accessibility*` in six view files | P0 | §12.9 |
| Override accessor | one accessor carrying bundle + locale, plus an explicit `layoutDirection` on the root; no relaunch | P0 | §12.9 |
| RTL | chrome mirrors, glyphs never do; the index stroke and pip accretion are game state | P0 | §12.8 |
| Plurals, formats, scripts | catalog plural variations and `Date.FormatStyle`/`NumberFormatter`/`Measurement`, never concatenation; no small caps or negative tracking in ar/ja/ko/zh-Hans; `uppercased(with:)` for Turkish | P0 | §12.9 |
| Banned-lexeme test | per-locale token list plus exclamation marks, case- and diacritic-insensitive, fails the build | P0 | §1.13, §11.11 |
| Pseudolocalization gate | accented + expanded pseudo-language and `-AppleTextDirection YES` on every screen before it is finished | P0 | §12.9 |
| **PERSISTENCE** | | | |
| File tree | `Application Support/Hunch/`, ten kinds of file, one owner and one reset each | P0 | §11.13 |
| `PersistenceStore` | protocol-backed, injected, atomic writes, no singletons for game state | P0 | brief, §11.13 |
| Schema and migration | single global `schema` from v1, `decodeIfPresent` defaults, transactional staging-directory replace | P0 | §11.13 |
| Lazy loading and recovery | shelf files loaded only when a shelf opens, `codex-index.json` as the launch-time dedup authority; per-file corruption behaviour incl. the `anomaly.hw` sidecar and index rebuild-by-scan | P1 | §11.13 |
| Reset map | five actions with an exact surviving file set; `anomaly.json`/`.hw` byte-identical after all five | P0 | §11.13, §12.6 |
| Backup policy | the whole tree backs up except `lowerBandIndex.bin`; nothing is ever written to `Documents/` | P0 | §11.5, §12.6 |
| **VERIFICATION** | | | |
| Fast loop | `swift test` on `HunchCore` under 10 s, Swift Testing, no simulator | P0 | brief |
| 10,000-law suite | per band: satisfiable, falsifiable, non-degenerate, structurally distinct, constructible | P0 | brief, §5.3 |
| Per-band `\|H\|` enumeration | eight exact counts plus the two contextual runs asserted against §5.2 | P0 | §3.6, §5.2 |
| G10 round-trip + fuzzer | `parse(Bench.layout(for: L))` node-identical to `RNF(L)`; 200,000 random Bench configs parse or bar | P0 | §4.4, §5.3 |
| Determinism | `(seed, mode, band, targetδ)` byte-identical across runs and processes at `avoid: []` | P0 | brief, §5.3 |
| Harness invariants H1–H21 | convergence, 0.80 ± 0.03 hold, no loss loop, difficulty calibration ρ ≥ 0.75, `π₀` staleness, fallback < 2 % | P0 | §10.10 |
| Localization tests | no untranslated/stale/duplicate keys in 12 languages, key count ≤ 250, banned tokens | P0 | §12.9 |
| Persistence tests | save→kill→relaunch identity, `Fixtures/v1/` loads green, reset assertions | P0 | brief, §11.13 |
| No-network build phase | grep for `URLSession`, `Network`, CloudKit, `UNUserNotificationCenter`; fails the build | P0 | brief, §10.12 |
| Mode invariants | SIEVE pitch invariant, sheet capacity ≥ max cap + 1, Reduce-Motion preview+window parity, ECHO primer resolves to one lit member | P0 | §6.2, §8.5, §9.2, §13.7.4 |
| Accessibility checklist | the 13 gates of §13.12, each with a `tests.json` entry | P0 | §13.12 |
| `tests.json` | structured pass/fail list of every invariant; entries are never removed or weakened | P0 | brief |

---

### 14.2 The Minimum Playable Product

**MPP = PROBE, complete, across all eight bands, plus the Codex.** Concretely: the glyph vocabulary and renderer; the full grammar, generator, guardrails and difficulty function; the Dial, ribbon, twin, Bench with all four tile classes, the Assay and the Seal; counterexample and two strikes; par/cap/marks/scoring; the adaptive engine with cold-start calibration; onboarding-by-doing; the Codex with eight shelves and page detail; mid-round persistence; the law-reveal, admit/reject audio and haptics; the dark theme; full VoiceOver, Dynamic Type and RTL; twelve languages.

That is a genuinely good game and not a demo. It has 27,015 laws, eight conceptual moves that each ask something the previous one did not, an archive that only grows, and a difficulty engine holding an 80 % success rate. A player can spend twenty hours in it.

**Deliberately cut from the MPP, and why the game survives without each:** DRIFT, ECHO and SIEVE (they are all gated behind Codex pages, so their absence is invisible on day one, and each is a variation on a loop that already works); the daily Anomaly (a return hook, not a play mechanic); the Profile and the statistics screen (records of play, never inputs to it); the spool sheet, the Codex facet bar and slot maps, the 90-day ghost, the grain shader, the light theme, left-hand keys, and the anti-boredom ceiling variation. Nothing cut here is load-bearing for a first session, and nothing cut here is cheap to fake later — each is added whole or not at all.

### 14.3 Build order against the brief's eight phases

| Phase | Features landed | Verification gate |
|---|---|---|
| **1 Foundations** | repo, `HunchCore` package, app target, SplitMix64, `CLAUDE.md`/`SPEC.md`/`DECISIONS.md`/`PROGRESS.md`, `tests.json`, no-network build phase | `swift test` runs and passes; the grep phase fails a deliberately planted `URLSession` reference |
| **2 Grammar and generator** | glyph model, AST, evaluator, bitboards + masks, RNF, equivalence, lower-band index, `difficulty(of:)`, generator, G1–G10, par/cap constants | the 10,000-law-per-band suite passes; the eight `\|H\|` counts match §5.2 exactly; determinism is byte-identical across two processes; suite runs in ≈ 1.2 s |
| **3 PROBE end-to-end** | the whole PROBE column above, plus Bench/Assay/Seal, reveal motion, snapshot persistence, onboarding round, and the localized chrome that exists | a real round is playable in the simulator, quit, relaunched and resumed at the exact probe; G10 round-trip + 200 k Bench fuzzer green; subagent diff review against `SPEC.md` |
| **4 Adaptive engine** | Ability, estimator, 13-step serving policy, `π₀`, reach/relief, calibration ladder, palette sufficiency, both harnesses | H1–H21 pass at the fast-suite subset; H3 holds 0.80 ± 0.03; H10 ρ ≥ 0.75 overall and ≥ 0.45 within band; H19 fallback < 2 %; full Level-B matrix green behind `HUNCH_CALIBRATION=1` |
| **5 Remaining modes** | DRIFT complete, then ECHO complete, then SIEVE complete — one at a time, each with its own generation, surface, scoring, reveal and interruption policy | per mode: its guardrail suite (D1–D7 / primer separation / S1–S5), its scoring worked example reproduced numerically, and a played round resumed or voided per its own policy. SIEVE additionally: pitch invariant and the Reduce-Motion preview parity test. Subagent diff review at the end of the phase |
| **6 Meta layer** | Codex root/shelf/page, duplicates and burnish, Anomaly derivation and ledger, Profile axes and geometry, statistics, Settings, the Frame, navigation | `Fixtures/v1/` loads green; all five resets leave `anomaly.json` byte-identical; `NavigationDepthTests` ≤ 2 for every screen; two devices set to the same UTC date produce the identical Anomaly law |
| **7 Localization and accessibility** | all 12 languages, override accessor, RTL, plurals, script profiles; VoiceOver map, narrator, rotors, Dynamic Type, High Contrast | localization completeness + key-count + banned-lexeme tests pass; AX5 × 5 locales snapshot with zero truncation; the §13.12 checklist is green; screenshots reviewed in English, German and Arabic |
| **8 Polish and ship prep** | shader, bloom, full palette and type application, procedural audio, haptics, app icon, launch screen, App Store metadata ×12, `PrivacyInfo.xcprivacy` | archive builds with zero warnings; binary under 15 MB; airplane-mode playthrough; face-down haptic discrimination by three testers; every string re-read against §1.13 |

### 14.4 Explicitly out of scope

- **iPad, landscape, macOS, visionOS, watchOS** — one device class, one orientation; the layout is tuned to a 375 pt thumb arc.
- **Multiplayer, asynchronous or otherwise** — there is no adversary in this fantasy and no network to carry one.
- **Accounts, sign-in, profiles, save slots** — the device knows about one player and never will know about another.
- **iCloud, CloudKit, any sync** — a hard constraint; the device backup already answers "your data is yours".
- **Leaderboards, Game Center, percentiles, rankings** — comparison is not suppressed, it is unavailable by construction.
- **IAP, subscriptions, ads, paywalls, lives, energy, cooldowns** — paid once, everything on device at first launch.
- **Any network code at all** — no `URLSession`, no `Network`, no analytics, no crash SDK; enforced by a build phase.
- **Push or local notifications** — nothing to notify from and no guilt to deliver; `UNUserNotificationCenter` never appears.
- **A level editor, custom laws, or user-generated content** — the grammar is the content pipeline.
- **Share sheet, share cards, export, Files presence** — an audience reintroduces the comparison the Profile exists to prevent.
- **Third-party dependencies, image assets, audio assets, bundled fonts** — vector and procedural throughout, under 15 MB.
- **Tutorial screens, tooltips, coach marks, hints, a solver, a skip** — the tutorial is round 1 of band 1, and P2 forbids the machine having an opinion.
- **A difficulty picker or any visible band number** — publishing the band hands the player the discovery cost `d`.
- **Widgets, App Intents, Shortcuts, Siri, Live Activities, Handoff, external keyboard or controller support** — surface area with no play value.
- **A ninth band or a larger deck** — 256 glyphs is what the Assay, the Dial and the reference layout are built on.
- **A rating prompt, a "what's new" modal, or any onboarding carousel** — the app asks the player for nothing.

### 14.5 Open decisions

Only genuinely unresolved questions. Each has a recommended default so nothing blocks.

Two questions that appeared here in draft have since been closed in the text and are recorded for audit rather than decision. **Mode unlock thresholds:** §9.10 is the single source — DRIFT on a band-≥ 3 page, ECHO at ≥ 5 pages, SIEVE at ≥ 8 — and §11.12 and §12.4 now cite it instead of restating their own numbers. **What "Clear Codex" clears:** the palette ceiling reads `maxBandEverServed` from `ServingState`, not the archive, so Clear Codex re-locks the page-gated modes and leaves the palette alone; **Reset the ladder** is what returns the palette to its band-2 opening state.

1. **Price.** §1.4 fixes paid-once and defers the tier to a section that never sets one. Options: Tier 3 ($3.99) buys volume; Tier 5 ($5.99) matches the ambition and the absence of IAP; Tier 8 ($8.99) is a statement that costs reach. Trade-off is reach against signalling. **Default: $5.99, no launch discount, no sale in the first year** — a game with no monetisation surface should not train its buyers to wait.
2. **The name.** The brief invites a rename. HUNCH is short, wordmark-safe in all 12 locales, and already carries the induction idea; nothing better has surfaced. **Default: keep HUNCH, and log the search in `DECISIONS.md`.**
3. **How many suspended rounds exist.** §11.13 specifies one `round.json`; §7.10 and §12.4 both assume one per mode (the Frame draws a per-key progress arc, and DRIFT's "starting a second DRIFT round discards the older one" is a per-mode rule). Trade-off: four slots cost ~8 KB and one extra resume path; one slot costs the Frame's arc semantics and silently destroys a suspended PROBE round when a player tries DRIFT. **Default: four slots, `round-{mode}.json`, SIEVE excluded (it voids rather than suspends), so three files in practice.**
4. **When `lowerBandIndex.bin` is built.** §3.6 says "enumerated once at first launch". Unmeasured, and first launch is the onboarding round. Options: build eagerly at first launch (risks a visible hitch); build on a background task (band 1 needs no G4 exclusion set, so the opening round is safe); ship it precomputed in the bundle (+443 KB against a 15 MB budget, but it must then be version-locked to the generator). **Default: background build, gated so no band ≥ 2 round arms until it completes; measure in phase 2 and switch to a bundled resource only if the build exceeds 3 s on an A15.**
5. **Level-B harness cadence in CI.** The full matrix is ~9 minutes. Options: every commit (slow, honest), nightly (fast, with a lag), pre-release only (risky). **Default: fast subset on every commit, full matrix nightly and as a hard gate before any archive.**
6. **How the other eleven languages are produced.** The document specifies the tests but not the process. Options: machine draft only (fails the register — instrument labelling, ≤ 8 words, no exclamation marks); machine draft plus native review of the 94 visible strings; full vendor translation of all ~228. Trade-off: cost against the fact that the banned-lexeme risk is *highest* in translation, where a translator reaches for the local category term. **Default: write the English as a copywriter, machine-draft the rest, then native review of all 94 visible strings and of the 5 Profile sentences; the 134 accessibility strings get native review in de, tr, ru, ja, ar at minimum.**
7. **App icon.** Options: a single glyph (hollow triangle with its index stroke); the empty throat ring; the wordmark. Trade-off: the glyph is the game's own language but is illegible at 29 pt; the ring is legible and abstract but generic. **Default: the throat ring in brass on near-black with one glyph half-entering it, tested at 29, 60 and 1024 pt before anything else is drawn.**
8. **An ECHO cadence accommodation.** Cadence is ECHO's difficulty knob, so a "slow cast" setting would be a difficulty selector by another name — but SIEVE got *steady stream* for the same reason. Trade-off: consistency of accommodation against integrity of the `ℓ` ladder. **Default: none — the free replay is the accommodation, and VoiceOver already gets step mode; revisit only if playtesting shows set accuracy failing for motor rather than reasoning reasons.**

### 14.6 Risk register

| # | Risk | Likelihood | Impact | Early signal | Mitigation |
|---|---|---|---|---|---|
| 1 | **The loop is fascinating for 20 minutes and dull thereafter.** Once "vary one attribute, watch the lamp" is learned, every round is the same act with more clauses | Medium–High | Fatal | Sessions 3–6 shorter than sessions 1–2; players stop opening the Codex; band distribution stuck in one family; in Level B, per-round probe counts converge across bands | Difficulty is *family*, not term count — eight conceptual moves, each demanding something the last did not (this is the single largest bet in the design). Four modes with four different failure surfaces. The pressure term keeps three families in rotation (H21). At the ceiling the question silently changes from *what is the law* to *in how few probes*. Falsify it early: run a 10-session diary with five testers before phase 5 commits to three more modes |
| 2 | **The declaration interface is unusable without text.** A player can probe happily and never work out that the Bench states a *predicate*, or cannot express the theory they hold | Medium–High | Fatal | `OnboardingLedger.clearedTheSealBar` false for >20 % of first rounds; the barred-Seal nudge firing at its cap in round 1; testers who solve the law aloud but cannot build it | The ramp is the *same widget* as the Dial in a second mode, tapped 4–12 times before the Bench opens. The Assay gives live semantics with no words. The machined bar makes "not ready" a machine state rather than an error. The ghost toggle reuses a symbol introduced diegetically. Hard gate: five testers who have never seen the game must each state `shape ∈ {triangle}` unaided in the opening round, recorded, before phase 3 is called done |
| 3 | **`difficulty(of:)` does not predict failure.** The five modifiers are design-time priors and H10 fails | Medium | High — the adaptive engine becomes noise and the 80 % target is unreachable | Within-band Spearman ρ < 0.45 at phase 4; H12 par fidelity outside ±20 % for two or more bands | Regenerate the §5.1 modifier weights from the Level-B harness rather than weakening the test; the par column is explicitly regenerable empirically. Band-level ordering is enforced by theorem for bands 3, 4 and 8, so a modifier failure degrades within-band position, not the ladder |
| 4 | **Contextual bands are unlearnable in practice.** Bands 5 and 7 are 17,248 of the 27,015 laws and all of DRIFT's best material; if players cannot hold a pair table, a third of the game is dead | Medium | High | Band-5 win rate below 0.65 even after relief; the twin key unpressed in >50 % of band-5 rounds; `d = 5` proving optimistic in H12 | Six discoverability layers, all present in every band so none leaks the family: seed glyph, permanent ghost mark, the twin key from round 1, the split doubled ring, the sheet's verdict sort, the Bench's ghost toggle. The breath fires past 0.6·par. If it still fails, raise `d` for bands 5 and 7 in the par table — an already-documented empirical path |
| 5 | **Content exhaustion at the thin shelves.** Bands 3 (108) and 8 (337) shift from induction to recognition for a heavy player | Medium (only past ~150 band-8 solves) | Medium | Duplicate rate at band 8 above 30 % over the last 50 rounds; time-to-declare at band 8 falling while probe count stays flat | Serving-layer soft-avoid uses the *entire found set* for `\|H\| ≤ 512` shelves, turning collection into near-sampling-without-replacement. Ceiling variation tightens the mark instead of the law. The Anomaly supplies one off-ladder law a day. Stated honestly in §5.7 rather than hidden |
| 6 | **Performance and battery.** `Canvas` + shader + bloom + 256-cell Assay morphs, and a SIEVE stream that must not drop a frame at 2.95 glyphs/s | Medium | Medium | Shader over 0.4 ms/frame on an A15; any dropped frame in SIEVE at `r₁`; thermal throttling in a 12-minute band-8 round | Blur is one layer per glyph-bearing *region*, never per glyph; the Assay is excluded from bloom entirely; the shader auto-disables below 30 fps for 2 s and re-enables at a round boundary; SIEVE ramps in glyph index so a dropped frame delays a glyph and never shortens its window, and auto-pauses past a 100 ms budget miss |
| 7 | **Scope: the project does not finish.** Four modes, 18 screens, 21 harness invariants, 12 languages and ~228 keys, built by one engineer across many context windows | High | High | Phase 3 not gated by the end of the third context window; any phase-5 work starting while the PROBE slice has a known gap; `PROGRESS.md` describing intentions rather than passing output | §14.2's MPP is the declared fallback ship, and §14.1's P1/P2 column is the drop order. Vertical slices only — one mode finished end to end before the next begins. Commit constantly; `PROGRESS.md` and `tests.json` updated at every gate; subagent diff reviews at phases 3, 5 and 8 |
| 8 | **Localization ships a claims violation or an unreadable register.** Eleven machine-drafted languages, and the highest banned-lexeme risk is exactly where a translator reaches for the local category term for "brain game" | Medium | High — FTC exposure, App Review rejection, and the one thing §1.13 calls a compliance boundary | Banned-token test hits during phase 7; a native reviewer flagging more than 10 % of the 94 visible strings; German or Russian Settings rows wrapping to three lines at AX3 | Per-locale banned-lexeme test that fails the build, exclamation marks on the same list, exceptions only by written entry in `DECISIONS.md`. ≤ 22 characters per visible string, budgeted at +40 %. Mode names and HUNCH ship as untranslated wordmarks. Native review of all 94 visible strings before submission, and every screen reviewed under the expanded pseudolocale before it is called finished |
