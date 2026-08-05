# Retrieving any of the 365 rules

1. [Prefix to file](#1-prefix-to-file)
2. [How to print a rule](#2-how-to-print-a-rule)
3. [The four IDs that have no heading, and the seven lettered ones](#3-the-four-ids-that-have-no-heading-and-the-seven-lettered-ones)
4. [Symptom to rule ID](#4-symptom-to-rule-id)
5. [`08-APPLIED-TO-HUNCH.md` by section](#5-08-applied-to-hunchmd-by-section)
6. [Which skill owns which prefix](#6-which-skill-owns-which-prefix)

---

## 1. Prefix to file

The guide lives at `ios-swift-guide/`. Every rule is numbered, every file owns one prefix, and citations are file-qualified.

| Prefix | File | IDs | Covers |
|---|---|---|---|
| `P` | `01-PROJECT-STRUCTURE.md` | P1–P46 | tree, buildable folders, feature-first layout, the app shell, modularisation, one package with N targets, deployment floor, test placement, which file a declaration goes in, resources, the wizard, what to commit |
| `N` | `02-NAMING-AND-API-DESIGN.md` | N1–N47 | types, methods, argument labels, booleans, initialisers, protocols, enums and errors, generics, acronyms, async and actors, SwiftUI names, test names, file and module names, doc comments, the ban list |
| `W` | `03-WRITING-THE-CODE.md` | W1–W57 | kind of type, access control, files and extensions, immutability, optionals, illegal states, errors and typed throws, generics vs existentials, protocol vs struct-of-closures, the metaprogramming budget, doc comments, `swift-format`, the fails-review table |
| `A` | `04-ARCHITECTURE-AND-STATE.md` | A1–A50 | Observation, the property-wrapper table, the view-model ruling, the UI-free core, dependency injection, navigation as data, persistence, the networking client, whether to buy TCA |
| `R` | `05-CONCURRENCY.md` | R1–R56 | settings and their order, default isolation per module, the two classes of diagnostic, `nonisolated` after SE-0461, `Sendable` vs `sending`, actor reentrancy, SwiftUI isolation, structured concurrency, bridging callbacks |
| `T` | `06-TESTING.md` | T1–T63 | what to test and what to refuse, Swift Testing mechanics, `#expect` vs `#require`, traits and tags, parameterized tests, hand-written doubles, determinism, what stays in XCTest, fixtures, the ten-second budget, flakes |
| `B` | `07-TOOLING-BUILD-AND-SHIPPING.md` | B1–B46 | language mode, xcconfig, build settings, run-script phases, formatting and linting, `Package.swift` mechanics, schemes and test plans, versioning, CI and source-hygiene checks, archive/sign/upload, rejection triggers, localization, size, accessibility audits |

`00-README.md` carries the twenty highest-leverage rules and a symptom table; `08-APPLIED-TO-HUNCH.md` is the projection onto this project and restates nothing.

## 2. How to print a rule

Never quote a rule from memory, and never copy one into code, a comment or another skill. Print it.

```bash
grep -n '^\*\*W44[. ]'    ios-swift-guide/*.md      # one rule heading, exact
grep -n '^\*\*T5a[. ]'    ios-swift-guide/*.md      # a lettered sub-rule
grep -rn '\bA18\b'        ios-swift-guide/          # every mention, citations included
```

Whole sections, when the rule is a table or a procedure:

```bash
sed -n '/^\*\*N15\./,/^\*\*N16\./p' ios-swift-guide/02-NAMING-AND-API-DESIGN.md   # one rule with its table
sed -n '/^## 5\. Modularisation/,/^## 6\./p' ios-swift-guide/01-PROJECT-STRUCTURE.md
```

Every rule heading in a file, when you do not know the ID yet:

```bash
grep -oE '^\*\*[PNWARTB][0-9]+[a-z]?\.[^*]*' ios-swift-guide/04-ARCHITECTURE-AND-STATE.md | cut -c1-110
```

`Scripts/rule.sh <ID>` is the repo-root wrapper for the first form. It exists so that the standing rule — *if a value can be read in one tool call, write the tool call, not the value* — costs one word instead of a `grep` incantation. Use the raw `grep` when the wrapper does not exist; it adds nothing but the typing.

**The trailing `[. ]` in the pattern is load-bearing.** Three rules are declared `**W5 (Swift 6.4).**`, `**W27 (Swift 6.4).**` and `**W31 (library authors).**` — a `\.`-only pattern silently misses them and you will conclude the rule does not exist.

## 3. The four IDs that have no heading, and the seven lettered ones

Verified against the guide on 2026-07-27 by counting headings — recount any time with:

```bash
grep -hoE '^\*\*[PNWARTB][0-9]+[a-z]?[. ]' ios-swift-guide/*.md | tr -d ' .' | sort -u | wc -l
```

- **368 rule headings on disk. 365 distinct numeric IDs** (46 + 47 + 57 + 50 + 56 + 63 + 46), and **7 lettered sub-rules**: `T5a`, `T5b`, `T18a`, `B7a`, `B7b`, `B30a`, `B34a`. All seven are cited by `08-APPLIED-TO-HUNCH.md` — `T5a` for keeping `import Testing` out of the release binary, `B34a` for the source-hygiene script HUNCH extends with four checks.
- **`T20`, `T51`, `T53` and `T57` are cited in prose but carry no bold heading.** `grep '^\*\*T53'` returns nothing and the rule still exists. Fall back to `grep -n 'T53' ios-swift-guide/06-TESTING.md`, which finds it. Do not conclude a citation is dangling until you have run the plain grep.

## 4. Symptom to rule ID

Look up the ID, then print it with §2. No rule text is reproduced here — that is the point of the file.

| You are about to / you see | Rules |
|---|---|
| "Where does this new file go?" | `01 §5a` table, `P11`–`P13`; for the package, `08 §2` |
| One type per file, and the exceptions | `P24`, `P25`, `W11` |
| An extension on a foreign type; a conformance split out | `P27`, `P26`, `W12` |
| A filename you cannot defend | `P28`, `N45` |
| Two packages, `package` vs `public` | `P14`, `W6`, `08 §7.2` |
| A new target's isolation and language mode | `P16`–`P18`, `R7`, `R8` |
| Choosing struct / enum / class / actor | `W2`, `W1`, `W3`, `W10` |
| A `Bool` and an optional that are only meaningful together | `W28` |
| `default:` in a switch | `W29`, `W30` |
| A force-unwrap or a `try!` | `W24`, `W25`, `W37` |
| `assert` vs `precondition` vs `fatalError` | `W39`, `W40` |
| Protocol or a struct of closures | `W44`, `T39` |
| A macro, property wrapper or result builder | `W45`–`W50` |
| Doc comment shape; complexity on a property | `W51`, `W52`, `N46`, `N47` |
| The formatter's committed delta | `W54`, `W55` |
| Argument labels | `N15`, `N16` |
| Naming a boolean; a mutating/non-mutating pair | `N9`, `N10`, `N7`, `N8` |
| Naming a protocol, an actor, an enum case, an error | `N24`–`N27`, `N38`, `N29`–`N31` |
| Acronym casing; an abbreviation | `N34`, `N35`, `N36` |
| An `async` function's name | `N37` |
| Naming a view, a modifier, an environment value | `N39`, `N41`, `N42` |
| Naming an observable model | `N40`, `A19` |
| The composition root | `A2`, `A3` |
| A store per screen or per context | `A17`, `A18`, `A19`, `A20` |
| Which property wrapper | `A11`, `A12`, `A13` |
| A view that silently stopped updating | `A6` |
| A value mirrored into `@State`; a derived value stored | `A14`, `A15`, `A16` |
| A sheet whose subtree traps at runtime | `A25`, `A26` |
| A custom environment value | `A27`, `A28` |
| Routes, routers, deep links, destinations | `A32`–`A36`, `A39` |
| Presenting with `isPresented` plus a payload | `A37` |
| Persistence shape and its failure policy | `A40`, `A46`, `08 §7.5` |
| A singleton, or `.shared` outside the root | `A29`, `A30` |
| Isolation, `Sendable`, actors, `@unchecked` | `R7`, `R8`, `R13`, `R14`, `R17`, `R18`, `R21`, `R26`, `R27`, `R30` |
| Test placement, doubles, determinism, XCTest survivors | `T3`, `T5`, `T5a`, `T5b`, `T21`, `T38`, `T39`, `T43`, `T49`, `T54` |
| Language mode, xcconfig, CI, hygiene greps | `B1`, `B2`, `B5`, `B6`, `B18`, `B28`–`B31`, `B34a` |
| Localization, privacy manifest, size | `B39`, `B36`, `B37`, `P32`, `B12` |

## 5. `08-APPLIED-TO-HUNCH.md` by section

The projection onto this project. It says which rule fires and what it produces here; it restates nothing, so read it *with* the cited rule, not instead of it.

| Section | What it fixes |
|---|---|
| §1 | The tree, annotated per line with the rule that put it there |
| §2 | The module boundary as a checkable predicate, plus four "looks core, is not" and two "looks app-layer, is core" |
| §3 | The naming pass — 20 design terms to Swift, including the three collisions and the Band/Family collapse |
| §4 | The concurrency plan — default isolation per target, `Sendable`, exactly two actors, the RNG scoping rule, the one escape hatch |
| §5 | The test plan — the brief's seven invariants mapped, the ten-second budget defended, the four extra CI greps |
| §6 | Dependency injection — the composition root, `SeedSource`, previews, re-injection, routers, `@Entry` values |
| §7 | The twelve places the constraints fight the guide, each with a ruling |

```bash
sed -n '/^## 3\. The naming pass/,/^---/p' ios-swift-guide/08-APPLIED-TO-HUNCH.md
```

## 6. Which skill owns which prefix

Knowing when to stop reading and load a sibling is half the value of an index.

| Prefix | Skill |
|---|---|
| `P`, `N`, `W`, `A` | **this skill** — placement, naming, code style, state ownership |
| `R` | `hunch-swift-concurrency` — isolation, `Sendable`, the two actors, the RNG, the audio escape hatch |
| `T` | `hunch-swift-testing` — what to test, Swift Testing mechanics, determinism, the ten-second budget |
| `B` | `hunch-build-and-ci` — xcconfig, manifests, source hygiene, the workflow, `swift-format`'s installation |
| — | `hunch-design-tokens` and the drawing skills own every colour, dimension, duration and geometry; no `P`/`N`/`W`/`A` rule reaches them |

A few rules sit on a seam and are cited by two skills. When that happens the owner is the one in this table, and the other skill cites the ID rather than restating it — `P16`/`P17` (isolation is declared in the manifest, valued by `R7`), `W54` (the config is `W54`'s, where it runs is `B`'s), `P22` (placement is `P`'s, content is `T`'s).
