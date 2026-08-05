# E20 — Polish and ship

| | |
|---|---|
| **id** | E20 |
| **title** | Polish and ship |
| **branch** | `epic/E20-polish-ship` |
| **depends on** | E19 (which itself carries E01–E18) |
| **gate** | The archive builds with **zero warnings** under `-warnings-as-errors` · the binary is under the brief's 15 MB ceiling · an airplane-mode playthrough completes on a device · the shader measures ≤ 0.4 ms/frame on an A15 and auto-disables below 30 fps · three testers discriminate `admit` / `reject` / `bar` face-down without being told which is which · the audio session asserts `.ambient` / `.default` / `[]` with lazy start and a 20 s idle stop · the full nightly Level-B matrix is green as the pre-archive gate · every string re-read against §1.13 |
| **tasks** | 12 |
| **status** | not started |

---

## Goal

When this epic merges, HUNCH **makes a sound and has a feel**, and it is submittable. Fifteen audio
cues are computed per sample by one `AVAudioEngine` feeding one `AVAudioSourceNode` — no file, no
buffer, no asset — over an eight-slot lock-free voice bank behind the codebase's single documented
`@unchecked Sendable`; they sit on five-limit just intonation over D3, where `admit` is a beat-free
just fifth that audibly *locks* and `reject` is a just tritone a fifth below it that does not, so the
verdict is legible with no context, no colour and no screen. Eleven Core Haptics patterns land on the
same frames, built so that `admit` is one soft event, `reject` is two sharp ones and `bar` is the
game's only blunt heavy one — three corners of the intensity/sharpness square that three testers can
tell apart with the phone face-down. Both channels attach to firing points **E08·T06 and E09·T10
already published as data**, so nothing in this epic discovers a beat; it hangs a player on one.

Around that: the `loomGrain` `colorEffect` gives the play surface its scanline, its 8 Hz grain and its
vignette, inside 0.4 ms/frame on an A15, with a governor that turns it off when the frame rate says so
and turns it back on only at a round boundary. Every token and every type role gets its final pass
across all eighteen screens, and register segregation is re-proved by a build that is *required to
fail*. The throat ring becomes the app icon, tested at 29, 60 and 1024 pt before anything else is
drawn. `PrivacyInfo.xcprivacy` declares — truthfully, and provably, because there is no network symbol
anywhere in the repository — that nothing is collected and nothing is tracked. And sixty units of App
Store metadata in twelve languages are re-read against §1.13's banned list, including in jest.

That closes §14.3's phase 8, the AUDIO, HAPTICS and remaining ART/MOTION rows of §14.1, and every
release gate in `hunch-release`'s section A.

## Why now

This epic is last for three mechanical reasons, not for taste.

- **Audio and haptics attach to beats, and the beats had to be timed first.** §13.8 and §13.9 own
  frequencies, envelopes, intensities and sharpnesses; the mode sections own *beat positions*, and
  there are four modes' worth of them. E08·T06 defined the `Cue` vocabulary behind a `SilentCuePlayer`
  seam and E09·T10 published the reveal's cue and haptic points as data precisely so that this epic
  attaches players to firing points that already exist and have already been timing-tested. Writing
  the synth in phase 3 would have meant re-timing it in phases 5, 6 and 7. This is §14.3's own
  ordering, and the plan's one deliberate re-ordering note.
- **The final token pass can only be final once there is nothing left to draw.** T09 is a sweep over
  eighteen shipped screens. Run it in E17 and E18's and E19's screens would have missed it.
- **Everything App Review looks at is downstream of the binary being finished.** The size number can
  only be read from an App Thinning Size Report, which requires an archive; the icon has to be drawn
  from shipped drawing code so it cannot drift from it; and the claims re-read (§1.13, gate 13) is
  worthless if a string can still change afterwards.

Nothing follows this epic. Its last task hands over to `/hunch-release`, which is user-invoked only.

## Scope

| In | Out — and who owns it |
|---|---|
| `Modules/Sources/Feedback/` completed: `CompositeCuePlayer`, `Cue.representatives`, the `AudioRow`/`HapticRow` row identities, the two spec tables | `Cue`, `CuePlayer`, `SilentCuePlayer` and `RecordingCuePlayer`, which already exist — **E08·T06**; the reveal's published cue points — **E09·T10** |
| `VoiceBank`, the render block, the one `@unchecked Sendable` and its four-question comment | Hygiene check 3 itself, which the hatch is the repo's first and only hit for — **E01·T06** |
| The 15 §13.8 cues, their interval logic, the drone-step transposition, the mix, the master ceiling, the soft clipper, the DC blocker and the session policy | `Sound`, `Level` and `Haptics` as **Settings rows and `UserDefaults` keys** — **E17·T06**; this epic consumes their values |
| The 11 §13.9 patterns, the engine lifecycle, the capability no-op and the Low Power suppression | The **beat positions** those patterns fire on — **E08·T06** (verdict), **E09·T09/T10** (strike, reveal), **E12·T08** (hinge), **E14·T04** (fouls), **E16·T04** (streak) |
| The `loomGrain` Metal function, the `GrainGovernor`, the Instruments measurement | `RenderEnv.isShaderEnabled` / `isScanlineEnabled` / `isShaderTimeFrozen` — **E03·T03**; the `Grain` Settings row — **E17·T06** |
| Attaching cues to the micro-responses, completing the six screen transitions, and the row-by-row re-verification of §13.7.4 across every animation now shipped | Each animation itself — **E08·T06**, **E09·T01/T09/T10/T12**, **E12·T08**, **E13·T04/T09**, **E14·T10**, **E16·T10**, **E17·T09** |
| The final token and type-role pass over all 18 screens, the register-segregation negative-compilation harness, the re-shot snapshot corpus | The token layers, `RenderEnv` and the resolution order — **E03·T01–T06**; the gallery and its registry — **E04·T09**; hygiene checks 9 and 10 — **E03·T06** |
| `AppIcon`, drawn from the shipped throat-ring and glyph code, and the cold-launch re-measurement | `LaunchScreen.storyboard`, its two colour sets and the `XCTApplicationLaunchMetric` baseline — **E17·T05**. This epic re-runs that measurement; it does not re-author the surface |
| `App/PrivacyInfo.xcprivacy`, and the 5 × 12 App Store metadata units with their banned-lexeme pass | `ITSAppUsesNonExemptEncryption`, `UIDeviceFamily`, portrait-only and the zero-`NS*UsageDescription` assertion — **E01·T02**; `Localizable.xcstrings` and hygiene check 8 — **E18·T01/T08** |
| Running `hunch-release`'s read-only gates A1–A9, the three-tester haptic panel, the airplane-mode playthrough, the final subagent diff review | **Archiving, signing, exporting and uploading — `/hunch-release`, user-invoked only.** This epic never runs section B or C |

## The task list

Execution order is top to bottom. `deps` are task ids inside this epic.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [The `Feedback` target and the cue vocabulary](T01-feedback-target-and-cue-vocabulary.md) | P0 | M | — | `CompositeCuePlayer` with haptics-first fan-out; `Cue.representatives` covering every case and parameterisation; `AudioRow` (15) and `HapticRow` (11) as the spec tables' typed keys, with the many-to-one expansions asserted in both directions |
| T02 | [The procedural audio engine](T02-procedural-audio-engine.md) | P0 | L | T01 | One `AVAudioEngine` + `AVAudioSourceNode`; the fixed 8-slot `VoiceBank` with an `Atomic` head index and the repository's single documented `@unchecked Sendable`; an allocation-free, lock-free render block; polyphony capped at 6 by a pure admission function; sample rate read from the session, never assumed |
| T03 | [The cue table](T03-the-cue-table.md) | P0 | M | T02 | The 15 cues on five-limit just intonation over D3 — `admit` a just fifth, `reject` a just tritone whose root is a fifth **below** it; 45/32 reserved; AD envelopes exponential to −60 dB; the drone step as a transposition of the root, not a sixteenth cue |
| T04 | [Mix and session policy](T04-mix-and-session-policy.md) | P0 | M | T03 | Three buses under a −6 dBFS ceiling behind `tanh(1.2x)/tanh(1.2)` and a 3-pole DC blocker; `.ambient` / `.default` / `[]`; −4 dB when `isOtherAudioPlaying` and never a duck; lazy start on the first cue, 20 s idle stop, resume only on `.shouldResume` |
| T05 | [Core Haptics patterns](T05-core-haptics-patterns.md) | P0 | M | T01 | The 11 patterns as values: `admit` one soft, `reject` two sharp, `bar` the only high-I low-Sh event; `twin` composed rather than cached; the two parameterised rows keyed by marks and streak step; the Low Power transients-only derivation done once |
| T06 | [Haptic engine lifecycle and the toggle](T06-haptic-engine-lifecycle-and-toggle.md) | P0 | M | T05 | A pure `HapticGate` policy, then the thin engine: capability checked once, `resetHandler`/`stoppedHandler` bridged by `AsyncStream`, `isAutoShutdownEnabled`, the `Haptics` switch honoured **before** any engine call, failures never surfaced — and the composition root switched to the real composite |
| T07 | [The `loomGrain` shader](T07-the-loomgrain-shader.md) | P1 | M | T04 | One stitchable `colorEffect` over the play surface below the chrome bar; `amt = 0` under Reduce Transparency, High Contrast and Low Power; `t` frozen under Reduce Motion; a pure `GrainGovernor` that disables below 30 fps for 2 s and re-enables only at a round boundary; ≤ 0.4 ms/frame measured with Instruments on an A15 |
| T08 | [Micro-responses and screen transitions](T08-micro-responses-and-screen-transitions.md) | P1 | M | T07 | Cues and haptics attached to admit, reject, twin at ×0.7, the DRIFT moment, the SIEVE tap and the barred Seal, all under 260 ms and none blocking input; the six screen transitions each naming a token; §13.7.4 re-verified row by row against every animation now shipped |
| T09 | [Full palette and type application](T09-full-palette-and-type-application.md) | P0 | M | T08 | The final pass: no literal anywhere, every type role resolved through `env.type(_:)`, register segregation re-proved by a build that must fail, and the snapshot gallery re-shot in three themes plus greyscale as the shipped visual-regression corpus |
| T10 | [App icon and launch screen](T10-app-icon-and-launch-screen.md) | P0 | M | T09 | The throat ring in brass on near-black with one glyph half-entering it, rendered from the shipped drawing code, opaque, legible at 29 / 60 / 1024 pt; the cold-launch budget re-measured against everything this epic added |
| T11 | [Privacy manifest and store metadata](T11-privacy-manifest-and-store-metadata.md) | P0 | M | T10 | A truthful `PrivacyInfo.xcprivacy` with the `UserDefaults` required-reason code; the encryption key asserted, not re-added; 5 fields × 12 locales written against §1.13's approved framings, screenshots wordless, and the banned-lexeme pass extended over the metadata files |
| T12 | [The archive gates](T12-the-archive-gates.md) | P0 | M | T11 | Zero warnings in Release, the size proxy and the real report, the airplane-mode playthrough, the three-tester face-down panel, the full nightly Level-B matrix, `tests.json` green with nothing removed or weakened, the final fresh-context subagent diff review — then hand over to `/hunch-release` |

T02–T04 are the audio spine and T05–T06 the haptic one; they share only T01 and may be worked in
either order. Everything from T07 down is strictly sequential, because each one sweeps a surface the
previous one changed.

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E20-polish-ship

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E20-polish-ship
gh pr create --title "E20 — Polish and ship" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**There is no next epic — but the rule is unchanged: do not archive, and do not run `/hunch-release`,
until this PR is merged.** An archive from an unmerged branch is a build that cannot be rebuilt from a
tag, and `hunch-release` gate A1 refuses a dirty tree for exactly that reason. If a check fails, fix it
on the same branch and push again; never merge red, never disable, skip or weaken a check to reach
green, and never remove or weaken a `tests.json` entry (§14.1, VERIFICATION). Two failures in this
epic have famously tempting wrong fixes and both are forbidden: adding a `-Wwarning <group>` to clear
A6 rather than fixing the warning, and adding a token to `DECISIONS.md`'s exception list to clear the
banned-lexeme check rather than deleting the string.

## The gate

Every one of these must be true, and each names the command that proves it, before the PR may merge.

| # | Must be true | Proved by |
|---|---|---|
| 1 | The fast suite is green and still inside its budget | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | The app-side suites are green in the simulator, including the new `FeedbackTests` target | `xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission -destination "id=$UDID"` with `set -o pipefail` |
| 3 | **The audio session asserts the exact triple, with lazy start and the 20 s idle stop** (§13.12 gate 11(a)) | `xcodebuild test … -only-testing:FeedbackTests/AudioSessionTests` — category `.ambient`, mode `.default`, options `[]`; no `AVAudioUnit` before the first cue; engine stopped 20 s after the last |
| 4 | **`admit`, `reject` and `bar` are discriminable face-down by three testers who were not told which is which** (§13.12 gate 12) | `PROGRESS.md` §Feedback carries a dated entry per tester with the build number, the presentation order, and each tester's three-way assignment — 9 of 9 correct, or the panel is re-run after a pattern change, never after a re-brief |
| 5 | **The shader measures ≤ 0.4 ms/frame on an A15 and the governor behaves** | `PROGRESS.md` §Shader carries the Instruments Metal-counter figure from an iPhone SE (3rd generation, A15) at 120 Hz — plus `xcodebuild test … -only-testing:HunchUITests/GrainGovernorTests` for the 30 fps / 2 s disable and the round-boundary re-enable |
| 6 | **The whole Reduce Motion table is verified row by row against every animation now shipped** (§13.12 gate 9) | `xcodebuild test … -only-testing:HunchUITests/MotionRowTests` (every row has a substitution, and no substitution translates, scales or rotates) plus the hand audit recorded in `PROGRESS.md` |
| 7 | **Zero warnings in a Release build** | `xcodebuild -project Hunch.xcodeproj -scheme Hunch -configuration Release -destination 'generic/platform=iOS' build 2>&1 \| grep -c ' warning: '` → `0`, and the build succeeds under `-warnings-as-errors` |
| 8 | Hygiene is green, including this epic's added checks, and each was demonstrated red on a planted violation | `Scripts/check-source-hygiene.sh` — the render-block purity check, the type-role check, and the metadata banned-lexeme check, each named in the roster table |
| 9 | **Exactly one `@unchecked Sendable` in the repository, and it carries the four-question comment** | `Scripts/check-source-hygiene.sh` check 3, plus `grep -rn '@unchecked Sendable' HunchCore Modules App \| wc -l` → `1` |
| 10 | **The binary is under the brief's ceiling** | The Release `.app` size proxy in CI **and** the real figure from `App Thinning Size Report.txt`, recorded in `PROGRESS.md` after `/hunch-release` §4 — never measured from the `.ipa`, the `.app` or the `.xcarchive` alone |
| 11 | **An airplane-mode playthrough completes on a real device** | `PROGRESS.md` §Release: aeroplane mode on, one full round played to inscription, one Codex page opened, one Anomaly cell tapped — dated, with the build number |
| 12 | **The full Level-B matrix is green** (§14.5 decision 5) | `HUNCH_CALIBRATION=1 swift test --package-path HunchCore --filter CalibrationTests`, and the run summary reports **cases executed, not zero** |
| 13 | `tests.json` is green with nothing removed or weakened | `Scripts/check-tests-json.sh` and running each entry's `command` |
| 14 | **Every string, in twelve languages and in sixty metadata units, has been re-read against §1.13** (§13.12 gate 13) | `Scripts/check-source-hygiene.sh` check 8 (the catalog) plus this epic's metadata check over `Metadata/<locale>/*.txt`, and the human re-read recorded in `PROGRESS.md` |
| 15 | A fresh-context subagent diff review against `SPEC.md` reports no correctness or stated-requirement gap | The review transcript pasted into `PROGRESS.md`, with every finding either fixed on this branch or answered in `DECISIONS.md` |

## Definition of done

- [ ] All twelve task files are `Status: done`, each with its own commit.
- [ ] `swift test --package-path HunchCore` green in under 10 s; `Presubmission`, `Nightly` and `Prerelease` plans green in the simulator; `HUNCH_CALIBRATION=1` reports a non-zero case count.
- [ ] `Scripts/check-source-hygiene.sh` green with this epic's checks present in the roster table, and each demonstrated to fail on a deliberately planted violation before being reverted.
- [ ] `tests.json` carries this epic's entries — the session triple, the engine lifecycle, the cue-table interval invariants, the eleven-pattern shape, the Low Power derivation, the shader budget and governor, the Reduce Motion row completeness, the type-role sweep, the register-segregation negative build, the icon legibility set, the privacy manifest, the metadata claims pass, and the face-down haptic panel (owner: three named testers) — every one with a runnable `command`, and **no existing entry removed, re-worded or given a weaker pass condition**.
- [ ] `DECISIONS.md` carries this epic's rulings: `Cue`'s case count against `feedback-target.md`'s stated twelve; the drone step as a transposition of the cue table's root rather than a sixteenth cue, with step 0 verbatim §13.8; `VoiceBank`'s reclamation bound and why the fix for a breach is more slots and not a lock; `strike`'s cue and haptic at t = 1,300 (`reveal-beats.md` §5's ruling, adopted); the icon's opaque-ground derivation from shipped drawing code; and any §1.13 lexeme exception, which is granted only in writing and only by the user.
- [ ] `PROGRESS.md` records, each with a date and a build number: the face-down haptic panel, the Instruments shader figure on an A15, the Reduce Motion hand audit, the airplane-mode playthrough, the icon reviewed at 29 / 60 / 1024 pt, the screenshots reviewed in en / de / ar, and the size figure from the thinning report.
- [ ] Every AUDIO, HAPTICS and remaining ART/MOTION row of §14.1 is closed, and the VERIFICATION rows `Fast loop`, `Harness invariants H1–H21` and `tests.json` are green.
- [ ] The PR is merged with every check green, `main` is pulled, and the user has been told — in these words — to run **`/hunch-release`**, which is user-invoked only and is the only thing that may archive, sign, export or upload.
