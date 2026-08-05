# What gets a HUNCH build rejected

Ordered by how likely each one is to bite *this* app, not by how common it is in general. Almost all
of it is metadata, not code, which is why it surprises people at 6pm on a Friday.

Citation convention throughout: a bare `§n` is a section of `GAME_DESIGN.md`; `07 Bnn`, `08 §n`,
`01 Pnn` and `06 Tnn` are numbered rules in `ios-swift-guide/`. Print any rule with
`grep -n '^\*\*B36[. ]' ios-swift-guide/*.md` rather than trusting a paraphrase.

Three different things are called "rejection" and they fail at three different moments:

| Kind | When | Looks like | Cost |
|---|---|---|---|
| **Upload rejection** | seconds after `-exportArchive` uploads | an `ITMS-#####` code in the tool output or an email | the build number, burnt |
| **Review rejection** | days later | a guideline number in App Store Connect | the release date |
| **Distribution block** | after processing | no rejection at all, the build just cannot reach anyone | silent |

## Contents

1. [Claims — the one that binds every locale](#1-claims--the-one-that-binds-every-locale)
2. [Privacy manifest and required-reason APIs](#2-privacy-manifest-and-required-reason-apis)
3. [The App Privacy answers, which are not the manifest](#3-the-app-privacy-answers-which-are-not-the-manifest)
4. [Encryption compliance](#4-encryption-compliance)
5. [Tracking — the key that must be absent](#5-tracking--the-key-that-must-be-absent)
6. [Usage descriptions and Files presence](#6-usage-descriptions-and-files-presence)
7. [App icon](#7-app-icon)
8. [Screenshots](#8-screenshots)
9. [Device family and orientation](#9-device-family-and-orientation)
10. [Version and build numbers](#10-version-and-build-numbers)
11. [Age rating, price and business model](#11-age-rating-price-and-business-model)
12. [App Review notes — a wordless game needs them](#12-app-review-notes--a-wordless-game-needs-them)
13. [Third-party SDKs — void today, and why the line stays](#13-third-party-sdks--void-today-and-why-the-line-stays)

---

## 1. Claims — the one that binds every locale

**`GAME_DESIGN.md §1.13` is the authority and it is a compliance boundary, not a style preference.**
It binds the App Store listing, screenshots, keywords, onboarding, Settings, the Codex, the Profile,
release notes and every localisation — and review replies, which people forget because they are
written months later by someone not doing a release.

The surface is five App Store Connect fields — name, subtitle, description, keywords, what's-new —
times twelve locales, sixty units (`§12.9`). None of them is in `Localizable.xcstrings`, so **`A5`
check 8 does not see them.** They need the same per-locale banned-token pass run over the metadata
files, and that is the gap this reference exists to close.

- Read the banned/approved table in `§1.13` before writing any of the five fields. Do not paraphrase
  it here or into a commit message; the fourteen rows carry the *reason* each phrase fails, and the
  reason is what generalises to a phrase the table does not list.
- The risk is highest in the eleven translations, where a translator reaches for the local category
  term for "brain game" (`§14.6` risk 8). The per-locale token list in `§1.13` exists for exactly this
  and is the thing to grep the metadata against.
- Exclamation marks are on the same list.
- A token clears only by a written exception in `DECISIONS.md`. The default is deletion.

What it costs if it lands: Guideline 2.3 (accurate metadata) at best; the FTC precedent `§1.13` cites
is a $2 M fine, and that exposure does not expire when the review passes.

---

## 2. Privacy manifest and required-reason APIs

`App/PrivacyInfo.xcprivacy` (`01 P32` owns placement; `07 B36` owns the rule). Since 2024-05-01 App
Store Connect **rejects the upload** — not the review — when a required-reason API is used without a
declaration.

HUNCH uses one: `UserDefaults`, for preferences only (`hunch.settings.*`, `§11.13`). That is enough
to require a manifest even though the app collects nothing and tracks nothing. The five categories
are `NSPrivacyAccessedAPICategoryFileTimestamp`, `…SystemBootTime`, `…DiskSpace`, `…ActiveKeyboards`
and `…UserDefaults`.

**`07 B36` could not verify the reason-code strings against Apple's page, and neither should you take
them from here.** Read the rendered HTML at
`developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api` and copy the
code for "access your app's own `UserDefaults`" from there. A wrong code is a truthfulness problem,
not a typo.

Two HUNCH-specific notes:

- The manifest also declares **no data collection and no tracking**, and here that is verifiably
  true rather than asserted — the no-network grep (`A5` check 5) and the airplane-mode playthrough are
  the evidence. Keep it that way: the moment anything reads a file timestamp or disk space for a
  purpose other than its own container, this file changes.
- One manifest, at the app bundle root, unless a local package ends up as a dynamic framework —
  `01 P32` rules on placement. Every executable or dynamic library that uses such an API needs one in
  its **own** bundle.

---

## 3. The App Privacy answers, which are not the manifest

`PrivacyInfo.xcprivacy` is a file in the binary. The **App Privacy** questionnaire is a separate form
in App Store Connect that produces the public "nutrition label", and nothing checks the two against
each other. Answering it inconsistently with the manifest is a metadata problem that survives review
and then contradicts your own About screen.

For HUNCH every answer is **Data Not Collected**, and that is defensible because there is no network
code of any kind (`§14.4`). The About screen carries a no-data-collected statement (`§12.9`), so three
artefacts must agree: the manifest, the questionnaire, and a translated string in twelve languages.
If one changes, all three change.

---

## 4. Encryption compliance

`ITSAppUsesNonExemptEncryption = NO`, set once as an `INFOPLIST_KEY_*` build setting in
`Config/Base.xcconfig` (`07 B37`, `08 §1`). HUNCH ships no cryptography and makes no HTTPS calls, so
`NO` is the truthful answer.

Omitting it is a **distribution block, not a rejection**: every build lands in "Missing Compliance"
and cannot reach TestFlight testers until someone clicks through, per build. Nothing fails; testers
just never get it. If you are clicking that prompt, the setting is missing — fix the xcconfig rather
than the click.

---

## 5. Tracking — the key that must be absent

`NSUserTrackingUsageDescription` must **not be present**. `07 B38`'s rule is that the key and a real
`ATTrackingManager.requestTrackingAuthorization` call are a pair, and one without the other is a
Guideline 5.1.2(i) rejection — among the most common privacy rejections there is.

The usual trap is an ads or sign-in SDK pulling the key in months after someone added it. HUNCH has
zero third-party dependencies and no network, so the trap cannot spring — **which is exactly why the
line stays on this list.** The day someone adds a dependency "just for the release pipeline", it can.
The App Store Connect IDFA question is answered No for the same reason.

---

## 6. Usage descriptions and Files presence

`08 §1` and `§12.9`: the app requests no permission of any kind, so there are **zero
`NS*UsageDescription` keys**. A usage description that appears is three problems at once — an untrue
statement, a localization unit nobody translated, and a permission prompt for a capability the app
does not have.

`§12.9` additionally asserts that neither `UIFileSharingEnabled` nor
`LSSupportsOpeningDocumentsInPlace` is present: there is no export and no `Documents/` content
(`§11.5`), and a test asserts both keys are absent so the app cannot silently acquire a Files
presence. Verify it on the built product, not on the source:

```bash
/usr/libexec/PlistBuddy -c Print build/Hunch.xcarchive/Products/Applications/Hunch.app/Info.plist \
  | grep -iE 'UsageDescription|FileSharing|OpeningDocuments|ITSAppUsesNonExemptEncryption'
```

Expected output: the encryption key and nothing else.

---

## 7. App icon

An icon with an **alpha channel or transparency is an upload rejection** — `ITMS-90717`, before review
ever sees the build. It is the single most common way to burn a build number on a first submission,
because a PNG exported from a drawing tool keeps its alpha by default.

`§14.5` decision 7 fixes HUNCH's icon as the throat ring in brass on near-black with one glyph
half-entering it, tested at 29, 60 and 1024 pt before anything else is drawn. `08 §1` puts it in
`App/Assets.xcassets` / `AppIcon.icon` as the **only** image asset in the product — no glyph asset,
ever, in any form (`01 P33`, `P37`). An icon is the one place this app has pixels; that is not a
precedent for a second one.

---

## 8. Screenshots

**`§12.9` fixes them at zero words** — "wordless by decision — the game is wordless, the screenshots
should prove it". That is a design ruling, and it is also the safest possible position under `§1.13`,
because screenshots are metadata for claims purposes: a caption promising anything about the player's
mind is the same violation as putting it in the description.

The required device sizes change between App Store Connect revisions and are not worth writing down
anywhere. Read the current requirement in App Store Connect at submission time. What does not change:

- HUNCH is iPhone-only, so no iPad set is required — **provided §9 holds**.
- Take them from the simulator in en, de and ar (the brief's three review languages), so the shots you
  submit are the shots you reviewed in `A8`.
- No device frames carrying added text, no "Level 4" chrome, no numerals that `§12.9` says should be a
  tick row.

---

## 9. Device family and orientation

`UIDeviceFamily = 1` and portrait-only, set in `Config/Base.xcconfig` (`08 §1`). iPad, landscape,
macOS, visionOS and watchOS are explicitly out of scope (`§14.4`) and the layout is tuned to a 375 pt
thumb arc.

If the binary accidentally declares iPad support, two things happen and both cost a submission: App
Store Connect starts **requiring an iPad screenshot set**, and App Review tests the app on an iPad,
where a portrait-locked layout tuned to one width reads as Guideline 2.1 incompleteness. Verify on the
built product:

```bash
/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily' \
  build/Hunch.xcarchive/Products/Applications/Hunch.app/Info.plist   # expect: 1
```

---

## 10. Version and build numbers

`ITMS-90062` — the bundle version must be strictly higher than every previously uploaded build for
that marketing version. This is an upload rejection, and the burnt number is the one you tried to
reuse, not the one you meant to use.

`MARKETING_VERSION` → `CFBundleShortVersionString` is what users see; `CURRENT_PROJECT_VERSION` →
`CFBundleVersion` is the build number (`07 §8`). App Store Connect is the authority on what was last
uploaded — not your shell history, and not the tag list, which only records what *you* uploaded.

Set `manageAppVersionAndBuildNumber` to `false` in the App Store export options (see
`release-checklist.md` §3) so the number you injected is the number that ships. Left at its default,
the toolchain may pick one for you and your tag then names a binary that does not exist.

---

## 11. Age rating, price and business model

The **age-rating questionnaire** has been restructured more than once; answer it against the form
currently in App Store Connect rather than from any document. HUNCH's answers are trivial — no
violence, no gambling, no contests, no user-generated content, no unrestricted web access (there is no
web access at all) — and the only way to get it wrong is to answer it carelessly, which is a metadata
rejection under Guideline 2.3.

**Business model.** `§1.4` P5 and `§14.5` decision 1: paid-once, no free tier, no IAP, no
subscriptions, no ads, no timers, no lives. Three consequences at submission:

- Zero in-app-purchase products configured. A configured-but-unused IAP is a review question you do
  not want to answer.
- The listing must not describe a model the binary does not ship. `§1.13` row 14 puts "free", "premium"
  and "try before you buy" on the banned list for exactly this reason.
- No rating prompt, no "what's new" modal, no onboarding carousel (`§14.4`). The what's-new *field* in
  App Store Connect is still required and is still bound by `§1.13`.

---

## 12. App Review notes — a wordless game needs them

This one is not in any guide, and it is the most HUNCH-specific risk on the list.

**A play surface with zero text in any locale can read to a reviewer as an unfinished UI.** `§1.4` P1
forbids tooltips, hint text, difficulty labels, tutorial overlays and legends; `§14.4` forbids
tutorial screens, coach marks and hints. A reviewer opening the app sees an unlabelled instrument
panel and no instructions, and Guideline 2.1 (App Completeness) and 4.2 (Minimum Functionality) are
both available to them.

Mitigate in the App Review Notes field, in English, in three or four sentences: that the game is
wordless by design; that round 1 of band 1 *is* the tutorial and teaches by play (`§14.2`); that the
verdict lamp, the ribbon and the Assay are the entire feedback vocabulary; and that Settings, the
Codex and the Profile carry all readable text. No account is needed and no demo credentials exist —
say so, because an empty demo-account field is otherwise a query.

Keep the notes free of claims too. They are read by a human at Apple and they are still a statement
about the product.

---

## 13. Third-party SDKs — void today, and why the line stays

Apple requires SDKs on the commonly-used-third-party-SDK list to ship their **own** privacy manifest
and a valid signature as binary dependencies, and since 2025-02-12 any newly added privacy-impacting
SDK needs one (`07 B36`). Audit your dependencies' manifests, not just your own code (`07 B38`).

HUNCH has zero third-party dependencies — SPM, CocoaPods, binary or otherwise — and that is a brief
constraint, not a current state (`§14.4`). So every line in this section is void.

It stays on the list because it is the check that stops being void the moment someone adds one
dependency, and at that point four things re-open at once: this one, the tracking key in section 5,
the manifest obligation in section 2, and the size gate. A release is exactly when "just this one
package" gets proposed.
