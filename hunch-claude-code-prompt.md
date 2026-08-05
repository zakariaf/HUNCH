# BUILD BRIEF — "HUNCH": an offline iOS brain game

<role>
You are the sole engineer, game designer, and art director on this project. You own every decision from architecture to typography. Work like a senior iOS engineer who ships: make choices, write them down, verify them, and keep moving.
</role>

<mission>
Build a complete, polished, App Store–submittable iPhone game called **HUNCH** (working title — rename it if you find something better, and log why).

It is a **rule-induction puzzle game**: the machine has a hidden law, and the player's job is to work out what it is. Nothing is explained in words. The player learns by probing and being told yes or no.

Non-negotiables: 100% offline, native Swift + SwiftUI, no third-party dependencies, no network code of any kind, localized into 12 languages from day one.
</mission>

---

<how_to_work>
1. **Start in plan mode.** Read this brief, then produce a written implementation plan before touching code. Show me the plan, then proceed without waiting for approval unless a decision is expensive and irreversible.

2. **Write these files first, in the repo root:**
   - `CLAUDE.md` — build/test commands, code style, architectural rules, gotchas you discover. Keep it under 60 lines and prune it as you go. Only include things that would cause you to make mistakes if removed.
   - `SPEC.md` — the full self-contained spec derived from this brief: named files, named types, what's explicitly out of scope, and an end-to-end verification step per feature.
   - `DECISIONS.md` — every design/tech decision you make on my behalf, one line each, with the reason. This is how I audit your judgment later.
   - `PROGRESS.md` — current phase, what's done, what's next, known issues. Update it at the end of every phase. This is your memory across context windows.

3. **Do not ask me clarifying questions.** Where this brief is silent, pick the option a good designer would pick, implement it, and log it in `DECISIONS.md`. Only stop and ask if a choice is genuinely irreversible or costs real money.

4. **Work in vertical slices, not horizontal layers.** Get one game mode playable end-to-end (generator → engine → UI → persistence → localized strings) before starting the second. Never build "all the models, then all the views."

5. **Context management.** This task spans multiple context windows. Your context will be compacted automatically — do not stop early or wrap up work because you are running low on budget. Before context refreshes, commit your work and update `PROGRESS.md`. When you resume: run `pwd`, read `PROGRESS.md`, `SPEC.md`, and `git log`, then run the full test suite before writing new code.

6. **Commit constantly.** Small, descriptive commits. Use git as your state tracker and your undo button.

7. **Verify, then claim.** Never tell me something works. Show me the command you ran and its output. If a test passes, paste the passing output. It is unacceptable to delete, weaken, or skip a test to get to green.
</how_to_work>

---

<the_game>

### Premise

The player has found a machine — a **Loom** — left behind by people who are gone. It has no manual and no language. It accepts glyphs and either **admits** them or **rejects** them, according to a law it will never state. The player's only tool is the experiment.

Each round: probe the Loom with glyphs, watch what it accepts, form a hypothesis, and then **declare the law** by assembling it from a visual grammar of rule-tiles. Declare it right with few probes and the law is inscribed in your **Codex** — a growing archive of the machine's logic. Declare it wrong and the Loom resets with a different law.

This is the whole hook: **you are never told the rules of the game, and figuring out the rules IS the game.** It is a playable version of the hypothesis-testing loop — probe, observe, form theory, test theory, commit.

### Why this concept, specifically

- **It is language-free by construction.** The core loop uses shapes, colors, and symbols only. This makes 12-language support nearly free: only menus, settings, stats, and onboarding need translating. Do not violate this — no text may appear inside the play surface, ever.
- **It generates infinite content from a small grammar.** No level designer needed, no content pipeline, no downloads. Fits offline perfectly.
- **It cannot be brute-forced or looked up.** Every law is procedurally generated, so no walkthroughs, no memorization, no "solved" state.
- **It is genuinely hard in an interesting way** — the difficulty is conceptual, not reflex-based, so it works for a 25-year-old and a 70-year-old.

### The glyph vocabulary

A glyph has four independent attributes. This is the entire visual language of the game:

| Attribute | Values |
|---|---|
| Shape | circle, triangle, square, hexagon |
| Fill | hollow, solid, striped, dotted |
| Hue | four colorblind-safe hues (Okabe–Ito palette or equivalent) |
| Pips | 1, 2, 3, 4 marks |

256 distinct glyphs. Every attribute must be readable **without color** — fill pattern and shape carry the same information redundantly. This is an accessibility requirement AND a gameplay requirement, since color-only encoding would make some laws undetectable for colorblind players.

### The rule grammar

Laws are predicates over glyphs, built from a small formal grammar. Implement it as a proper AST with an evaluator, not as hardcoded cases.

- **Atomic** — `shape == triangle`, `pips >= 3`, `hue ∈ {amber, teal}`
- **Relational** — `pips == shapeSides`, `hue(current) == hue(previous)`
- **Compositional** — `AND`, `OR`, `NOT`, `XOR`
- **Contextual** — depends on the previously admitted glyph (this is where working memory enters)
- **Meta** — the law changes after N admissions (used only in DRIFT mode)

Difficulty is a computed function of: number of terms, presence of negation or XOR, relational vs atomic, contextual vs stateless, and how many irrelevant attributes vary. You must implement a `difficulty(of: Law) -> Double` function and validate it empirically against a simulated player (see `<verification>`).

### The four modes

All four share the same glyph vocabulary and rule grammar. Variety of challenge type is deliberate — it prevents habituation to a single task, which is what makes repetitive puzzle apps stop being interesting after a week.

1. **PROBE** *(the core mode — build this first, completely, before any other)*
   Feed glyphs to the Loom. It admits or rejects each one. Deduce the law, then declare it with rule-tiles. Scored on correctness first, probe economy second.

2. **DRIFT**
   Same as PROBE, but the law silently changes partway through. Measures how long the player clings to a hypothesis that has stopped working. Give the player a visible "the law has changed" moment *after* they declare, so the reveal lands.

3. **ECHO**
   The Loom emits a sequence of glyphs. Reproduce it — but only the glyphs that obeyed the law you learned last round count. Holding a rule in mind while doing something else.

4. **SIEVE**
   Glyphs stream past at increasing speed. Tap only the lawful ones. Timed, twitchy, and the only mode with real time pressure. Include it as a deliberate change of texture.

### Meta-progression

- **The Codex** — every law correctly declared is inscribed as a page: the rule rendered in the visual grammar, plus when you found it and how many probes it took. Hundreds of pages, all procedurally derived. This is the collection loop.
- **The Anomaly** — one law per day, identical for every player on Earth, derived from `seed = hash(UTC date)`. No server needed; determinism gives you a global daily challenge with zero network. Player keeps a local streak.
- **The Profile** — five tracked axes: *Induction, Retention, Flexibility, Restraint, Tempo*. Render as a slowly morphing shape, not a chart with a score. It's a self-portrait, not a leaderboard.

### Copy and claims — read this carefully

Never state or imply that this game improves memory, intelligence, focus, work performance, or protects against cognitive decline. Not in the app, not in the App Store description, not in onboarding, not as a joke. In 2016 the FTC fined Lumosity $2 million over exactly these claims. Frame everything as a puzzle: "a machine with a hidden law," "how few probes can you do it in." Curiosity, not self-improvement.

</the_game>

---

<adaptive_difficulty>
Adaptive difficulty is the single highest-leverage system in this app. Games that adapt their challenge to the player measurably outperform fixed-difficulty games on both engagement and skill growth. Build it properly.

- Maintain a per-axis ability estimate per player, updated after every round.
- Use a one-parameter logistic (Rasch-style) model: probability of success given `ability − difficulty`. Update with a simple online rule; do not build a machine-learning system.
- **Target a ~80% success rate.** Too easy is boring, too hard is demoralizing; the productive zone is "usually succeeding, occasionally not."
- Move difficulty up fast on a win streak, down gently on failure. Never let a player get stuck in a loss loop — after two consecutive failures, drop a full band.
- Never surface a numeric difficulty level to the player.
- The estimator must be pure, deterministic, and unit-testable in isolation.
</adaptive_difficulty>

---

<architecture>
- **Two targets.** A pure-Swift SwiftPM package `HunchCore` (glyphs, grammar, AST, evaluator, generator, difficulty model, adaptive engine, scoring, seeded RNG, persistence models) with **zero UIKit/SwiftUI imports**, plus the app target `Hunch` that consumes it. Rationale: `swift test` on the core package runs in seconds with no simulator, which gives you a fast verification loop for the parts that actually contain the logic.
- **Swift 6, strict concurrency enabled.** Fix warnings, don't suppress them.
- **SwiftUI + `@Observable`.** No Combine unless something genuinely requires it.
- **Deployment target: iOS 18.0.** Build with the current Xcode. Do not assume which SDK is installed — run `xcodebuild -showsdks` and confirm before configuring.
- **Rendering: SwiftUI `Canvas` + `Shape`, vector only. No image assets for glyphs.** Every glyph is drawn from parameters. This keeps the binary tiny, makes theming trivial, and scales to every device without an asset catalog.
- **Persistence: `Codable` JSON in Application Support**, behind a `PersistenceStore` protocol, written atomically, with schema versioning from v1 and a migration path. Not SwiftData — the concurrency friction isn't worth it here and JSON keeps the core package platform-free and testable. `UserDefaults` for preferences only.
- **Seeded RNG:** implement SplitMix64 or Xoshiro256** conforming to `RandomNumberGenerator`. Every generated puzzle must be reproducible from `(seed, mode, difficulty)`. Determinism is a hard requirement — it powers the daily Anomaly, and it makes bugs reproducible.
- **No singletons for game state.** Dependency-inject the store, clock, and RNG so tests can substitute them.
</architecture>

---

<localization>
Ship 12 languages: **English, German, French, Spanish, Portuguese (Brazil), Italian, Turkish, Russian, Japanese, Korean, Simplified Chinese, Arabic.**

- Use a **String Catalog** (`Localizable.xcstrings`). It is the standard since Xcode 15 and there is no reason to use `.strings` files in a new project.
- Use `String(localized:)` / `LocalizedStringResource` in Swift code, and let SwiftUI's `Text` pick up literals automatically. **Watch the classic trap:** raw `String` values (e.g. `enum Mode: String` used directly in a `Text`) are *not* extracted by the catalog. Every user-facing string must be a localizable type. Add a test that fails if any is missed.
- **Never concatenate translated fragments.** Use full sentences with interpolation and let the catalog handle plurals per language.
- **Arabic means real RTL support.** `leading`/`trailing` only, never `left`/`right`. Mirror layout, not glyphs — the glyph shapes themselves must be identical in every locale, since they're game state. Test with `-AppleTextDirection YES` and by running the app in Arabic.
- **German, Russian and Turkish strings run long** — up to ~40% longer than English. Test every screen with pseudolocalization (Xcode's accented + expanded pseudo-language) and fix truncation before you consider a screen finished.
- Locale-aware formatting for all numbers, dates, durations, percentages. `Date.FormatStyle`, `Measurement`, `NumberFormatter` — never string arithmetic.
- Provide an **in-app language override** in Settings (defaulting to "System"), so the player can play in a language other than their device's.
- **Write the base English strings yourself as a careful copywriter would**, then produce the other 11. Keep every string short — this is a game with almost no text, and that's an asset. If a string is over ~10 words, ask whether the UI needs it at all.
- Add a test that asserts: no untranslated keys in any of the 12 languages, no keys marked "needs review," no duplicate keys.
</localization>

---

<accessibility>
Not optional, and it doubles as good design.

- Full VoiceOver support: every glyph gets a meaningful label ("hollow triangle, three pips, teal"), every state change is announced, the Loom's verdict is announced.
- Dynamic Type throughout, tested at the largest accessibility sizes.
- Colorblind-safe by construction (shape + fill + hue triple encoding, as specified above). Add a "high contrast" theme.
- Respect Reduce Motion — replace every animation with a crossfade when it's on.
- Minimum 44×44pt hit targets. Playable one-handed on an iPhone SE and comfortable on a Pro Max.
- Haptics as a real feedback channel via Core Haptics: distinct patterns for admit / reject / law-declared-correctly / law-broken. Always respect the system setting.
</accessibility>

---

<art_direction>
You tend to converge on generic, "on-distribution" visual choices — the flat purple-gradient-on-white look. Do not do that here. Commit hard to one specific aesthetic:

**Direction: a dead machine in a dark room.** Deep near-black background with a faint warm tint, glyphs rendered as thin luminous strokes like an oscilloscope or a phosphor display, one dominant accent (aged brass or signal amber) with sharp cold accents for the "rejected" state. Subtle scanline / grain / bloom via a Metal `colorEffect` shader. The UI chrome should feel like instrument panels — thin rules, small caps, precise spacing, generous negative space. Silent, patient, slightly archaeological.

- **Typography:** system fonts are acceptable but style them deliberately — a monospaced or condensed face for numerals and instrument labels, tight tracking, real typographic hierarchy. If you bundle a font it must be OFL/permissively licensed and you must include the license file.
- **Motion:** one well-orchestrated moment beats scattered micro-animations. The law-reveal at the end of a round is the money shot — stagger it, make it feel like a mechanism unlocking. Use CSS-equivalent SwiftUI transitions and `phaseAnimator`.
- **Audio:** generate all sound procedurally with `AVAudioEngine` — sine/triangle tones, short envelopes, a tuned scale where "admit" and "reject" are consonant/dissonant intervals. No audio files. This keeps the binary small, keeps feedback language-free, and sounds better than stock UI clicks. Mix quietly and respect the silent switch.
- Offer light and dark themes, but design dark-first — that's the real one.
</art_direction>

---

<constraints>
Hard requirements. Violating any of these is a failed build.

- **No network. At all.** No `URLSession`, no `Network` framework, no analytics, no crash reporting SDK, no ads, no accounts, no CloudKit. Add a build-phase script that greps the source tree for network APIs and fails the build if any appear.
- **No third-party dependencies.** Zero SPM packages, zero CocoaPods.
- **No in-app purchases, no subscriptions, no paywalls, no timers or lives.** Pay once or free — decide and log it.
- **Privacy:** include `PrivacyInfo.xcprivacy` declaring no data collection and no tracking. It's true; make it verifiably true.
- **iPhone only, portrait only.** Don't spend effort on iPad or landscape.
- **App size target: under 15 MB.** Vector rendering and procedural audio make this easy — protect it.
- **No health, medical, or cognitive-improvement claims anywhere.** See the copy note above.
</constraints>

---

<verification>
Every phase must end with a check you ran and whose output you show me.

- **Fast loop:** `swift test` in `HunchCore` — must run in under 10 seconds. Keep it that way.
- **Full loop:** `xcodebuild test -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone 16'` — confirm the exact simulator name available with `xcrun simctl list devices` rather than guessing.
- Use **Swift Testing** (`import Testing`, `@Test`), not XCTest, for new tests.
- Maintain `tests.json` at the repo root: a structured list of every invariant with its current pass/fail status. Update it as you go. Never remove or weaken an entry to make things pass.

**The critical tests — these are what make this project verifiable rather than vibes:**

1. **Generator invariants at scale.** Generate 10,000 laws per difficulty band and assert: every law is satisfiable and falsifiable by at least one glyph in the deck; no law is trivially always-true or always-false; no two structurally identical laws are emitted as different; the declaration UI can express every generated law.
2. **Simulated player harness.** Implement a synthetic player with a tunable ability parameter that plays thousands of rounds headlessly. Assert that the adaptive engine converges to that ability within N rounds and holds the ~80% success target. Assert it never traps the player in a loss loop. This single harness is worth more than any amount of manual playtesting.
3. **Difficulty calibration.** Show empirically that `difficulty(of:)` correlates with the simulated player's actual failure rate. If it doesn't, fix the function — do not fix the test.
4. **Determinism.** The same `(seed, mode, difficulty)` must produce a byte-identical puzzle across runs and across processes. Assert it.
5. **Localization completeness.** Fail if any key is untranslated, stale, or duplicated in any of the 12 languages.
6. **Persistence round-trip and migration.** Save → kill → relaunch → identical state. Plus a v1 fixture that must still load after any schema change.
7. **No-network assertion.** The grep build phase described above.

After the app is playable, use the iOS Simulator to take screenshots of each screen in English, German, and Arabic, look at them, and fix what's visibly wrong. Do this before you tell me a screen is done.
</verification>

---

<phases>
Complete each phase and show its verification output before starting the next. Update `PROGRESS.md` and commit at every gate.

1. **Foundations** — repo, `HunchCore` package, app target, seeded RNG, `CLAUDE.md` / `SPEC.md` / `DECISIONS.md` / `PROGRESS.md`. *Gate:* `swift test` runs and passes with a trivial test.
2. **Grammar and generator** — glyph model, rule AST, evaluator, generator, difficulty function. *Gate:* the 10,000-law invariant suite passes.
3. **PROBE end-to-end** — the full vertical slice: generate → play → declare → score → persist → render, with localized UI. This is the riskiest phase; front-load it. *Gate:* I can play a real round in the simulator, quit, relaunch, and see my result.
4. **Adaptive engine** — ability model, simulated player harness, calibration. *Gate:* convergence and 80%-target tests pass.
5. **Remaining modes** — DRIFT, ECHO, SIEVE, one at a time, each fully finished before the next.
6. **Meta layer** — Codex, daily Anomaly, Profile, Settings, onboarding-by-doing (teach the mechanic through play, never with a tutorial screen).
7. **Localization and accessibility pass** — all 12 languages, pseudolocalization, RTL, VoiceOver, Dynamic Type, screenshots in three languages. *Gate:* localization tests pass and you've reviewed screenshots.
8. **Polish and ship prep** — art direction fully applied, procedural audio, haptics, app icon, launch screen, App Store metadata and description in all 12 languages, privacy manifest, size check. *Gate:* archive builds clean with zero warnings.

At the end of phases 3, 5, and 8, use a **subagent in a fresh context** to review the diff against `SPEC.md`. Tell the reviewer to report only gaps that affect correctness or stated requirements — not style preferences — so I don't end up with a pile of defensive over-engineering.
</phases>

---

<anti_patterns>
- **Don't over-engineer.** No abstractions for hypothetical future features, no protocol for something with one implementation, no configurability I didn't ask for. The right amount of complexity is the minimum that satisfies this brief.
- **Don't write to the test.** Implement the actual general algorithm. Never hardcode values or special-case inputs to make an assertion pass. If a requirement in this brief is unreasonable or a test is wrong, tell me — don't work around it.
- **Don't speculate about code you haven't opened.** Read the file before you claim anything about it.
- **Don't accumulate a broken build.** Never end a phase with failing tests or compiler warnings.
- **Don't leave scratch files behind.** Clean up temporary scripts and helpers at the end of each phase.
- **Don't narrate.** I want commits, test output, and a PROGRESS.md — not summaries of your intentions.
</anti_patterns>

---

<definition_of_done>
I can open the project in Xcode, hit Run, and play a game that is genuinely absorbing. It works in airplane mode. It works in Arabic. It works with VoiceOver on. Every test passes, `tests.json` is green, the archive builds without warnings, and `DECISIONS.md` explains every judgment call you made for me.

Begin with plan mode. Show me the plan, then build.
</definition_of_done>
