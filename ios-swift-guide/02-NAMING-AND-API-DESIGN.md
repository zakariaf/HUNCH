# Naming and API Design

This file is the naming law for the guide: how to name types, methods, properties, argument labels, enum cases, errors, generic parameters, actors, SwiftUI views and modifiers, tests and files — and how to write the doc comment that proves the name works. Read it if you are about to type a declaration and want a defensible default instead of a debate. Rules are numbered `N1`–`N47` so the other files can cite them; where a topic is really about layout, architecture, concurrency or tooling, this file gives the *name* and points at the owning file rather than repeating it.

**Version context.** `07-TOOLING-BUILD-AND-SHIPPING.md` §0 is the guide's single source for toolchain versions — Xcode 26.6 (17F113), Swift 6.3.3, iOS 26.5 SDK, verified 2026-07-27; Swift 6.4 exists only inside the Xcode 27 beta. Everything version-sensitive below is marked inline. The one fact that governs this file: Apple's [API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) are still live and still the spine, and no evolution proposal amending them has appeared since SE-0023 (2016). Apple publishes no changelog for that page, so "unrevised since 2016" is inference from repeated reads, not a documented fact — but every quotation below was re-read against the live page on 2026-07-27. What changed in the last three years is the *surface*: Swift Testing removed the `test_` prefix, `@Observable` removed the `$`/`@Published` ceremony, `@Entry` removed `EnvironmentKey` types, and module selectors (SE-0491, implemented in Swift 6.3) removed the need to rename a type to dodge a collision. Learn the spine once; re-learn the surface each September.

---

## 1. The prime directive

**N1. Read the call site out loud. If the sentence is ungrammatical or ambiguous, the name is wrong — not the reader.** A declaration is written once and read thousands of times; optimise the reading. The guidelines: *"Clarity at the point of use is your most important goal"* and *"Clarity is more important than brevity… it is a non-goal to enable the smallest possible code with the fewest characters."*

```swift
// ❌ "employees remove x" — element or index? Both compile when Element == Int.
employees.remove(x)

// ✅ "employees, remove at x"
employees.remove(at: x)
```

**N2. If you cannot write a one-sentence summary of the declaration, the problem is the design, not the name.** A naming argument that will not resolve is almost always an abstraction doing two things. Split it, then name the halves. This is the highest-leverage rule in the file because it converts an unfalsifiable taste debate into a design task.

*Cost:* names get longer, and you will lose an argument or two with someone who values terseness. *Deviate when* the domain already has a shorter term of art (N36).

---

## 2. Say exactly enough

**N3. Include every word needed to remove ambiguity at the use site, and delete every word the types already say.** One rule, applied in both directions.

```swift
// ❌ "Element" restates the parameter type; it conveys nothing where the name is used
public mutating func removeElement(_ member: Element) -> Element?
allViews.removeElement(cancelButton)

// ✅
public mutating func remove(_ member: Element) -> Element?
allViews.remove(cancelButton)
```

**N4. Name variables, parameters and associated types for their *role*, not their type.** A type-echo name repeats what the compiler already displays.

```swift
// ❌                                              // ✅
var string = "Hello"                               var greeting = "Hello"
associatedtype ViewType: View                      associatedtype ContentView: View
func restock(from widgetFactory: WidgetFactory)    func restock(from supplier: WidgetFactory)
```

**N5. When a parameter's type carries no domain meaning (`Any`, `AnyObject`, `String`, `Int`, `Data`, `URL`), put a role noun in front of it.** This is the one place you deliberately add words — the guidelines call it compensating for weak type information.

```swift
// ❌ "grid, add self for graphics"
func add(_ observer: NSObject, for keyPath: String)
grid.add(self, for: graphics)

// ✅ "grid, add observer self for key path graphics"
func addObserver(_ observer: NSObject, forKeyPath path: String)
grid.addObserver(self, forKeyPath: graphics)
```

*Deviate when* you can fix the type instead: wrap the `String` in a `RawRepresentable` and the type becomes the documentation, at which point N3 takes back over and the extra words go. Prefer that fix — `03-WRITING-THE-CODE.md` §6.

---

## 3. Verbs, nouns and side effects

**N6. No side effects → noun phrase. Side effects → imperative verb phrase.** `x.distance(to: y)`, `i.successor()`, `cart.total` versus `x.sort()`, `x.append(y)`, `session.invalidateAndCancel()`. This is the fastest signal in the language for "can I move this call, or drop it?"

**N7. Name mutating/non-mutating pairs from this table. There is no third option.** Verbatim: *"When the operation is naturally described by a verb, use the verb's imperative for the mutating method and apply the 'ed' or 'ing' suffix to name its nonmutating counterpart. When the operation is naturally described by a noun, use the noun for the nonmutating method and apply the 'form' prefix to name its mutating counterpart."*

| The operation is | Mutating | Non-mutating | Why |
|---|---|---|---|
| a verb, no direct object | `x.sort()` | `x.sorted()` | past participle |
| a verb, no direct object | `x.reverse()` | `x.reversed()` | past participle |
| a verb **with** a direct object | `s.stripNewlines()` | `s.strippingNewlines()` | "stripped newlines" renames the *object*, so use `-ing` |
| a noun | `y.formUnion(z)` | `y.union(z)` | `form` prefix |
| a noun | `c.formSuccessor(&i)` | `c.successor(i)` | `form` prefix |

The guidelines list `append` / `appending` under the past-participle heading even though `appending` is a present participle — a wart in the source document, not a licence to freestyle. `append` takes a direct object, so the `-ing` row is the one that actually explains it.

**N8. When neither `-ed`/`-ing` nor `form` reads well, ship only the non-mutating version** and let callers write `x = x.foo()`. Never invent a suffix.

```swift
// ❌ inventions no Swift API uses
mutating func shuffleInPlace()
mutating func normalizeSelf()
mutating func mutatingNormalize()

// ✅
mutating func shuffle()               // verb
func shuffled() -> [Element]          // past participle
func normalized() -> Path             // ship only this when `formNormalized` reads badly
```

**N9. Booleans read as assertions about the receiver.** The legal prefix set is `is`, `has`, `can`, `should`, `will`, `did`, `does`, plus a bare third-person-singular verb (`contains`, `intersects`, `matches`). Microsoft's guide restricts it to `is`/`has`; that set is too small — forcing `is` onto `canEdit` makes it worse. Note the third person: `intersects`, not `intersect`, because an imperative implies mutation (N6).

```swift
// ✅ isEmpty, isEnabled, hasSuffix, canDeclare(_:), shouldRetry, line1.intersects(line2)
// ❌ empty (reads as a noun), enabled, flag, valid, doIntersect
```

**N10. Never name a boolean negatively.** `isNotHidden` produces `if !view.isNotHidden` at some call site and someone will get it wrong at 6pm on a Friday. Store the positive; negate at the one place that needs it. *Deviate when* the domain itself is negative — `isDisabled` on a control whose whole API is about disabling — so the double negative lives in the domain rather than in your name.

---

## 4. Initialisers and factories

**N11. Factory methods begin with `make`; factory *properties* never repeat the type name.** `x.makeIterator()`, `factory.makeWidget(gears:spindles:)` — never `create…`.

```swift
// ❌                                            // ✅
UIColor.redColor                                 UIColor.red
URLSession.sharedSession                         URLSession.shared
extension Theme { static let darkTheme: Theme }  extension Theme { static let dark: Theme }
```

`swift-format` enforces the second half as `DontRepeatTypeInStaticProperties`; `03-WRITING-THE-CODE.md` §12 owns the formatter configuration.

**N12. An initialiser's first argument must not form a grammatical phrase with the type name.** An initialiser *constructs*; a phrase implies it *acts*.

```swift
// ✅                                          // ❌
Color(red: 32, green: 64, blue: 128)           Color(havingRGBValuesRed: 32, green: 64, andBlue: 128)
Link(target: destination)                      Link(to: destination)      // reads "Link to destination"
factory.makeWidget(gears: 42, spindles: 14)    factory.makeWidget(havingGearCount: 42, andSpindleCount: 14)
```

**N13. Initialiser parameters that map straight to stored properties take the property's exact name; disambiguate with `self.`.**

```swift
// ✅
public struct Person {
    public let name: String
    public let phoneNumber: String
    public init(name: String, phoneNumber: String) {
        self.name = name
        self.phoneNumber = phoneNumber
    }
}

// ❌ two names per property, and a call site that no longer matches the memberwise init
public init(name otherName: String, phoneNumber otherPhoneNumber: String) {
    name = otherName
    phoneNumber = otherPhoneNumber
}
```

**N14. Value-preserving conversions drop the first label; narrowing conversions label the narrowing.**

```swift
extension String {
    init(_ x: BigInt)                     // value preserving → no label
    init(_ x: BigInt, radix: Int)         // still value preserving
}
extension UInt32 {
    init(_ value: Int16)                  // widening  → no label
    init(truncating source: UInt64)       // narrowing → the label names the loss
    init(saturating source: UInt64)       // different loss, different label
}
```

The label exists so a reader who has never seen the API knows *which* data disappears. `UInt32(x)` where `x: UInt64` is a bug report waiting to be filed.

---

## 5. Argument labels — the decision procedure

**N15. Run this table top to bottom and take the first match. Do not freestyle.**

| Test | Result | Example |
|---|---|---|
| Value-preserving conversion initialiser? | omit the first label | `Int64(someUInt32)` |
| Can the arguments not be usefully distinguished? | omit **all** labels | `min(a, b)`, `zip(s1, s2)` |
| Does arg 1 complete a verb phrase with the base name? | fold the word into the base name, label `_` | `x.addSubview(y)`, not `x.add(subview: y)` |
| Does arg 1 read after a preposition? | label starts **at** the preposition | `x.removeBoxes(havingLength: 12)` |
| Do 2+ args form one abstraction the preposition governs? | preposition joins the **base name** | `a.moveTo(x: b, y: c)`, not `a.move(toX: b, y: c)` |
| Does the argument have a default value? | it **must** have a label | `view.dismiss(animated: false)` |
| Otherwise | label it | `words.split(maxSplits: 12)` |

Rows 3 and 5 are the ones people get wrong. Row 3: `x.add(subview: y)` looks tidier in the declaration and reads worse at the call site — that is exactly the trade these guidelines exist to settle, and the call site wins. Row 5 exists because `a.fade(fromRed: b, green: c, blue: d)` splits one colour into a labelled head and two orphans, while `a.fadeFrom(red: b, green: c, blue: d)` keeps the abstraction whole.

**N16. Prefer defaulted parameters to method families, and put the defaulted ones last.** One entry in the docs, one line of autocomplete, one implementation to keep correct — instead of four overloads that must each be read, tested and kept in sync.

```swift
// ✅
public func compare(_ other: String,
                    options: CompareOptions = [],
                    range: Range<Index>? = nil,
                    locale: Locale? = nil) -> Ordering
```

*Cost:* in a published library, defaults are part of your resilience story and adding one is not automatically source-compatible for callers referencing the compound name. In an app module, ignore this.

**N17. Choose internal parameter names to serve the documentation, even though they never appear at the call site.**

```swift
// ✅  func filter(_ predicate: (Element) -> Bool) -> [Element]
// ❌  func filter(_ includedInResult: (Element) -> Bool) -> [Element]
// ✅  mutating func replaceRange(_ subRange: Range<Index>, with newElements: [Element])
// ❌  mutating func replaceRange(_ r: Range<Index>, with: [Element])
```

**N18. Label tuple members, and name closure parameters, everywhere they appear in your API surface.** Swift has no labels on closure *arguments*; the `_ name:` form documents them anyway and costs the caller nothing.

```swift
mutating func ensureUniqueStorage(
    minimumCapacity requestedCapacity: Int,
    allocate: (_ byteCount: Int) -> UnsafeMutableRawPointer
) -> (reallocated: Bool, capacityChanged: Bool)
```

**N19. Never overload on return type alone.** `func value() -> Int?` beside `func value() -> String?` fights inference and produces "ambiguous use of" errors at call sites you did not touch. Ship `intValue()` / `stringValue()`, or one generic accessor.

**N20. A shared base name is correct when the operations mean the same thing in different domains, and wrong otherwise.**

```swift
// ✅ same semantics, different argument types
extension Shape {
    func contains(_ other: Point) -> Bool
    func contains(_ other: LineSegment) -> Bool
}

// ❌ two unrelated operations wearing one name
extension Database {
    func index()                                         // rebuilds the index
    func index(_ n: Int, inTable: TableID) -> TableRow    // returns a row
}
```

Corollary for unconstrained polymorphism: when the types cannot disambiguate, the label must.

```swift
var values: [Any] = [1, "a"]
values.append([2, 3, 4])            // ❌ one element or three? The stdlib avoids this:
// mutating func append(_ newElement: Element)
// mutating func append<S: Sequence>(contentsOf newElements: S) where S.Element == Element
```

---

## 6. Types, nesting and namespacing

**N21. Types are UpperCamelCase noun phrases with no Objective-C prefix.** Swift modules already namespace. `XYZEvent` → `Event`; use `@objc(XYZEvent) final class Event` only when you must export a prefixed name to Objective-C.

**N22. Nest error, configuration and state types inside their owner.** Free namespacing, and it kills stutter at the use site.

```swift
// ❌
struct HTTPClient {}
enum HTTPClientError: Error { case httpClientTimedOut }
throw HTTPClientError.httpClientTimedOut

// ✅
struct HTTPClient {
    enum Failure: Error { case timedOut, unauthorized, server(status: Int) }
    struct Configuration { var timeout: Duration = .seconds(30) }
}
throw HTTPClient.Failure.timedOut
```

*Cost:* a nested type cannot be extended from another module without spelling the full path, and nesting inside a generic type makes the nested type generic too. *Deviate when* several unrelated types throw the same error or it crosses a module boundary — then top-level `FooError` (N31).

**N23. A module whose name equals a type it vends is a preference now, not a rule.** Since **Swift 6.3**, module selectors (SE-0491, status *Implemented (Swift 6.3)*, re-verified 2026-07-27) disambiguate mechanically:

```swift
import Logging
let logger = Logging::Logger()     // picks Logging's Logger, ignoring anything else in scope
```

So stop renaming your type to `MyAppLogger` to dodge a collision. Still mildly prefer not to ship `module Logger` containing `struct Logger`, because DocC and some IDE lookups lag the language — a soft preference with an escape hatch, not a law. Module and target *layout* is `01-PROJECT-STRUCTURE.md` P19.

---

## 7. Protocols

**N24. A protocol that says what something *is* gets a noun (`Collection`, `UserStore`, `Tokenizer`). A protocol that says what something *can do* gets `-able`, `-ible`, or a genuine present participle (`Equatable`, `ProgressReporting`, `ExpressibleByStringLiteral`).** That is the guidelines' entire protocol rule; N25–N27 are enforcement.

**N25. The `Protocol` suffix is banned.** It names the language construct rather than the concept, and it exists almost entirely to leave the good name free for the single production implementation.

The carve-out is narrow but it is not a one-off: **the suffix is legitimate only when the good name is already taken in the same namespace by something you also have to keep** — an associated type, or the concrete type the protocol abstracts over. The standard library uses it ten times, and every one fits that description. Grepped from the `Swift` and `_Concurrency` `.swiftinterface` files in the iOS 26.5 SDK, 2026-07-27:

| `…Protocol` name | The good name was taken by |
|---|---|
| `IteratorProtocol` | `associatedtype Iterator` on `Sequence` |
| `AsyncIteratorProtocol` | `associatedtype AsyncIterator` on `AsyncSequence` |
| `StringInterpolationProtocol` | `associatedtype StringInterpolation` on `ExpressibleByStringInterpolation` |
| `InstantProtocol` | `associatedtype Instant` on `Clock` |
| `DurationProtocol` | `struct Duration` — and `associatedtype Duration` on `Clock`. Both at once |
| `StringProtocol` | `struct String` |
| `KeyedDecodingContainerProtocol` | `struct KeyedDecodingContainer` |
| `KeyedEncodingContainerProtocol` | `struct KeyedEncodingContainer` |
| `LazySequenceProtocol` | `struct LazySequence` |
| `LazyCollectionProtocol` | `typealias LazyCollection` |

Note what the test is not. It is not "a name I wanted was in use somewhere" — it is that the *other* holder of the name has a prior, independent claim you cannot revoke. `UserServiceProtocol` fails on exactly that point: the name is held by `UserService`, which is your own implementation, and N25's whole argument is that the implementation is the thing that should be renamed. Reach for the suffix only when you cannot rename the other holder, which in practice means never in your own module.

```swift
// ❌ the "mockable service" anti-pattern: the protocol is named after the class it mocks
protocol UserServiceProtocol { func fetchUser(id: String) async throws -> User }
final class UserService: UserServiceProtocol {}

// ✅ name the abstraction for what it is; name implementations for how they do it
protocol UserStore { func user(id: String) async throws -> User }
struct RemoteUserStore: UserStore {}
struct InMemoryUserStore: UserStore {}
```

Swift has no `Impl` culture; do not import one — `FooImpl`, `DefaultFoo` and `FooBase` are the same smell. `04-ARCHITECTURE-AND-STATE.md` §9 owns *whether* you need the seam at all; this rule only covers what to call it once you do.

**N26. `Manager`, `Provider`, `Helper`, `Handler`, `Service`, `Util(s)`, `Info` and `Data` are banned as type-name suffixes.** They name a bag of code, not a concept, and they are how a class reaches 2,000 lines without anyone noticing it changed subject. Dave Abrahams — who wrote the API Design Guidelines — [framed it on the Swift forums](https://forums.swift.org/t/protocol-naming/59453) as taxonomy: a type name should answer "what *is* this thing?", and of a `RepositoryProvider`, *"there are a billion ways a thing could provide repositories; what's special about this one?"*

| Instead of | Ask | Name it |
|---|---|---|
| `NetworkManager` | what does it do? | `HTTPClient`, `APIClient`, `ImageLoader` |
| `DataManager` | what does it own? | `RecipeStore`, `SyncCoordinator` |
| `ColorProvider` | what role is this in the domain? | `Theme`, `Palette` |
| `StringHelper` | whose behaviour is this? | an extension on `String` |
| `UserInfo` | what *is* it? | `UserProfile`, `Credentials` |
| `LocationService` | what *is* it? | `Locator`, `GeocodingClient` |

**Honest disagreement:** John Sundell recommends `ColorProvider` over `Colorable` when a protocol *supplies* a value rather than enabling an action, and he is right that `Colorable` is ambiguous. Abrahams calls `-Provider` a red flag for an under-specified abstraction. **Rule: side with Abrahams.** A protocol with one property is not an abstraction — it is a closure or a key path. Concede Sundell's `-Convertible` pattern, which has direct Apple precedent (`CustomStringConvertible`, `ExpressibleByStringLiteral`).

**N27. Never manufacture a protocol name by `-ing`-ing a noun.** `Networking`, `Requesting`, `Routing`, `Persisting` are not capabilities. Test: can you say "a Foo *is* X-ing"? "A URLSession is progress-reporting" ✅. "An APIClient is networking" ❌.

**N28. Delegate protocols are fine, and their methods take one of three shapes chosen by return type.** The first parameter is always the object calling the method.

```swift
// Void → notification of an event: base name is the source type, then an indicative verb phrase
func scrollViewDidBeginScrolling(_ scrollView: UIScrollView)
func draftManager(_ manager: DraftManager, didDelete draft: Draft)

// Bool → an assertion the delegate is being asked to make
func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool

// Any other return → a query for a value: noun-phrase base name, source gets a prepositional label
func numberOfSections(in tableView: UITableView) -> Int

// ❌ says nothing about who called, and reads like a command
protocol DraftManagerDelegate {
    func draftDeleted(_ draft: Draft)
    func onDraftDelete(_ draft: Draft)
    func handleDraftDeletion(_ draft: Draft)
}
```

*Deviate when* you are modelling one callback: ship a closure property or an `AsyncStream` and skip the protocol. Delegation earns its ceremony at three-plus methods with a genuinely bidirectional relationship.

---

## 8. Enums, associated values and errors

**N29. Enum cases are `lowerCamelCase` values that never stutter the enum name and never start with `is`.** The enum name is present at every use site.

```swift
// ❌ enum ConnectionState { case connectionStateIdle, isConnecting }
// ✅
enum ConnectionState { case idle, connecting, connected, failed(any Error) }
```

**N30. Label associated values unless there is exactly one and its type is self-explanatory.** Labels are part of the case's compound name and support default values (SE-0155, implemented Swift 3).

```swift
// ❌ case failed(String, Int)          — which is which at the pattern-match site?
// ✅ case failed(reason: String, statusCode: Int)
// ✅ case loaded(User)                 — one value, unambiguous type, no label needed

enum Animation {
    case fadeIn(duration: Duration = .milliseconds(300))
    case move(from: CGPoint, to: CGPoint)
}
let a = Animation.fadeIn()
```

**N31. Nested errors are called `Failure`; top-level errors are called `FooError`. Cases describe what went wrong, as nouns or past participles — never as commands.**

```swift
// ✅ nested: no stutter, reads well at the catch site
struct ImageLoader {
    enum Failure: Error {
        case unsupportedFormat(String)
        case tooLarge(byteCount: Int, limit: Int)
        case decodingFailed(underlying: any Error)
    }
}
catch ImageLoader.Failure.tooLarge(let bytes, let limit) { … }

// ✅ top-level: several types produce it, or it crosses a module boundary
enum PaymentError: Error { case cardDeclined(reason: String), insufficientFunds, networkUnavailable }

// ❌
enum PaymentErrorType: Error { case error1, genericError, ERROR_CARD }
enum PaymentError: Error { case paymentErrorCardDeclined }   // stutter
enum PaymentError: Error { case declineCard }                // imperative — reads as a command
```

Do **not** name a nested error type `Error`: `Parser.Error` compiles but forces `enum Error: Swift.Error` and `Swift.Error` qualification for the rest of the file. `Failure` also matches `Result`'s vocabulary and reads correctly in a typed-throws signature — `func load() throws(Failure) -> Image` — which matters, because typed throws puts the error's *name* in every signature that can fail. `03-WRITING-THE-CODE.md` §7 owns when typed throws is appropriate (short answer: rarely) and how to design the payload; this rule owns only the name. Not every error is an enum — `CancellationError` is a plain `struct`.

---

## 9. Generic parameters

**N32. Name a generic parameter descriptively when it has a role; use a single letter only when it genuinely has none; never suffix `Type`.** TSPL: *"when there isn't a meaningful relationship between them, it's traditional to name them using single letters such as `T`, `U`, and `V`."* Threshold: **two or more parameters ⇒ name them.**

```swift
// ✅
struct Cache<Key: Hashable, Value> {}
protocol Collection { associatedtype Element }
func swap<T>(_ a: inout T, _ b: inout T)

// ❌
struct Cache<KeyType: Hashable, ValueType> {}
func decode<TypeToDecode: Decodable>(_ type: TypeToDecode.Type)
protocol ViewController { associatedtype ViewType: View }   // → ContentView (N4)
```

Choosing *between* generics, `some` and `any` is `03-WRITING-THE-CODE.md` §8.

---

## 10. Case, acronyms and abbreviations

**N33. Types and protocols are `UpperCamelCase`; everything else — including global and static constants — is `lowerCamelCase`.** No `k` prefix, no `SCREAMING_SNAKE`, no leading underscore. `swift-format`'s `AlwaysUseLowerCamelCase` and `NoLeadingUnderscores` enforce this. Naming is not access control: when you mean private, write `private`.

```swift
// ✅ let secondsPerMinute = 60
// ❌ let kSecondsPerMinute = 60 / let SECONDS_PER_MINUTE = 60 / var _cache: [Key: Value]
```

**N34. An acronym is a single atom: case the whole atom up, or the whole atom down. Never mixed.**

```swift
// ✅                        // ❌
let urlString: String        let uRLString, let URLString (as a local)
var htmlBody: String         var hTMLBody
struct HTMLParser {}         struct HtmlParser {}, struct HTMLparser {}
func parseJSON()             func parseJson()
var apiKey: String           var aPIKey
var utf8Bytes: [UInt8]       var uTF8Bytes
```

Acronyms not conventionally capitalised in English stay normal: `radarDetector`, `enjoysScubaDiving`. The canonical illustration of the rule firing both ways at once is `Identifiable` (SE-0261, Swift 5.1): `associatedtype ID` (a type ⇒ atom up) and `var id: ID` (a value ⇒ atom down).

**N35. Use an abbreviation only when the abbreviation *is* the term of art, not when it is merely a shortening of one.** The guidelines' own test: the intended meaning should be findable by a web search.

| Allowed (term of art / precedent) | Banned (typist's convenience) |
|---|---|
| `id`, `url`, `min`, `max`, `sin`, `cos`, `utf8`, `rgb`, `http`, `json`, `sql`, `png` | `btn`, `vc`, `cfg`, `mgr`, `usr`, `img`, `str`, `num`, `req`, `resp`, `tmp`, `idx`, `svc`, `repo`, `impl`, `obj` |
| `x`/`y`/`z`, `lhs`/`rhs` (operator parameters), `i` (loop index), `T`/`U` (arbitrary generics) | anything you would have to expand out loud in code review |

**N36. Precedent beats purity, and the rules have a priority order.** `Array` beats `List`; `sin(x)` beats `sine(x)` despite N35; `id` beats `identifier` because SE-0261 shipped it and justified it as *"a frequently used term of art."* When two rules collide, established domain vocabulary wins. Do not optimise for the total beginner at the expense of existing culture — a new hire is a beginner for a week and a native speaker of Cocoa forever.

---

## 11. Async, actors and streams

**N37. Never suffix `Async`, and never prefix `get`.** SE-0296 (async/await, Swift 5.5) explicitly designed overload resolution so Swift would not need C#'s pervasive `Async` suffix: resolution prefers non-`async` functions in a synchronous context and `async` functions in an asynchronous one. `async` is in the signature and `await` is mandatory at every call site, so the suffix is pure redundancy — an N3 violation. Apple's own surface confirms it: `URLSession.data(for:)`, `data(from:)`, `bytes(for:)`, `download(for:)`, `upload(for:from:)` are all `async throws` with noun-phrase base names.

```swift
// ❌
func getUserAsync(id: String) async throws -> User
func fetchUserDataAsync(_ id: String) async throws -> User

// ✅ returns a value, no caller-visible side effect → noun phrase
func user(id: String) async throws -> User
func image(at url: URL) async throws -> Image

// ✅ genuine side effects → imperative verb (N6)
func refreshInbox() async throws
func send(_ message: Message) async throws

// ✅ async property: noun, no "get" in the name
var latestSnapshot: Snapshot { get async throws }
```

*Carve-outs, both narrow:* a temporary migration seam where the sync and async variants cannot overload (delete the suffix when the sync one goes), and Objective-C bridging where the selector must differ. *Honest cost:* `store.user(id:)` is harder to grep than `fetchUser` and gives no textual hint that it hits the network. If that bites, disambiguate by *meaning* — `cachedUser(id:)` versus `user(id:)` — never by bolting `fetch` onto both.

**Async sequences are plural nouns**: `bytes`, `lines`, `updates`, `events`, matching `URLSession.bytes(for:)` and `FileHandle.bytes.lines`. Never `getUpdatesStream()`.

```swift
var updates: some AsyncSequence<Update, Never> { get }   // typed AsyncSequence needs Swift 6.0+ (SE-0421)
```

**N38. An actor is a thing, so it gets a plain noun: `actor ImageCache`, `actor DownloadCoordinator` — never `ImageCacheActor`** (same reasoning as N25). Isolation, `@MainActor` placement and `Sendable` are `05-CONCURRENCY.md`'s territory; only the names are here.

---

## 12. SwiftUI naming

**N39. A view is named for what appears on screen. Add the `View` suffix only to break a collision with a model type.**

```swift
struct BookRow: View {}          // ✅
struct LibraryShelf: View {}     // ✅
struct BookDetailView: View {}   // ✅ `BookDetail` would be fine; the suffix breaks a clash with a model

struct ContentView: View {}      // ❌ Xcode's template name. It means nothing. Rename it on day one.
struct MainView2: View {}        // ❌
struct BookVC: View {}           // ❌
```

**N40. An `@Observable` type takes the domain noun; `…Store` is the one sanctioned suffix, and only when the type gatekeeps a collection.** Apple's SwiftUI documentation names its observable models `Book`, `Library`, `Author` — no `Model`, `Manager` or `ViewModel`, and no `_`-prefixed backing properties (the macro generates those). `Store` survives N26 where `Manager` does not, because it names a real role: a type that *owns* a collection of domain objects and mediates every read and write of it. That is the shape `04-ARCHITECTURE-AND-STATE.md` A17 builds on — one store per bounded context, `CatalogStore`, `OrderingStore`. **Rule: `…Store` when the type owns a collection and is the only way to it; the bare domain noun when the type *is* the thing.** `LibraryStoreManager` is still banned, and so is `Store` on a type that owns a single value.

```swift
@Observable final class Library {
    var books: [Book] = []
    var availableBooksCount: Int { books.count(where: \.isAvailable) }   // derived value → noun phrase
}

@Observable final class Book: Identifiable {
    var title = ""
    var author = Author()
    var isAvailable = true          // booleans keep the `is` prefix (N9)
}
```

**Honest disagreement:** MVVM literature and a large share of iOS codebases assume a `ViewModel` suffix; Apple's samples and Point-Free's do not. **Rule: default to the domain noun, and when a per-screen type is genuinely justified, name it for the screen's *job* — `CheckoutFlow`, `SignUpForm`, `FeedPaginator` — per `04-ARCHITECTURE-AND-STATE.md` A19, not `CheckoutViewModel`.** The weaker position (allow `XViewModel` when it adapts exactly one view) is defensible and common; this guide takes the stricter line because the suffix invites the pass-through object A19 exists to prevent. Never `FooViewModelProtocol` — that is N25 and N26 in one identifier. And since `@Observable` removed `@Published` and `$`-projection, the `viewModel.$state` ceremony is gone; do not reintroduce it with hand-rolled publishers.

**N41. A `ViewModifier` type is a noun; the `View` extension method is the same word lowerCamelCased, so it composes like a built-in.**

```swift
struct Card: ViewModifier {                     // type: the noun
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content.padding(padding).background(.regularMaterial, in: .rect(cornerRadius: 12))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {   // method: same word, lowerCamelCased
        modifier(Card(padding: padding))
    }
}
```

| Shape | ✅ | ❌ |
|---|---|---|
| Configuration modifier — name the thing, not the action | `.cardStyle()` | `.applyCardStyle()` |
| Value-setting modifier — first argument unlabelled | `.navigationTitle("Library")`, `.tint(.orange)`, `.badge(3)` | `.setTitle(text:)`, `.addBadge(3)` |
| Boolean modifier — adjective or past participle | `.disabled(true)`, `.hidden()`, `.redacted(reason:)` | `.setDisabled(true)` |
| Style protocol pair — mirror `ButtonStyle` / `.buttonStyle(_:)` | `CardStyle` + `.cardStyle(_:)` | `CardStyler` + `.styleAsCard()` |

Design the simple call first and add capability through defaulted parameters and composition, not parallel method families (WWDC22, "The craft of SwiftUI API design"). Same rule as N16, applied to a DSL.

**N42. Name an environment entry after the *value*; there is no key type left to name.** The `@Entry` macro requires the Xcode 16 SDKs or later — check `07-TOOLING-BUILD-AND-SHIPPING.md` §0 for the toolchain floor before deleting the old form, and verify back-deployment against your minimum target before relying on it.

```swift
// ✅
extension EnvironmentValues {
    @Entry var iconColor: Color = .red
}
@Environment(\.iconColor) private var iconColor

// ❌ pre-@Entry boilerplate — and a `…Key` type you no longer have to name
private struct IconColorKey: EnvironmentKey { static let defaultValue: Color = .red }
extension EnvironmentValues {
    var iconColor: Color {
        get { self[IconColorKey.self] }
        set { self[IconColorKey.self] = newValue }
    }
}
```

Never `iconColorKey` or `customIconColorEnvironmentKey`. When the value is part of your public surface, pair it with a modifier of the same name: `func iconColor(_ color: Color) -> some View`.

---

## 13. Test names

Naming only; `06-TESTING.md` owns everything else about tests.

**N43. Drop the `test` prefix in Swift Testing.** The library identifies a test by the `@Test` attribute, not the name — its own migration guide: *"The testing library doesn't require a test function to have any particular name."* Function name = a short lowerCamelCase assertion about behaviour; the full sentence goes in `@Test("…")`.

```swift
// ❌ XCTest era — the sentence is crammed into the identifier because XCTest could only show the selector
final class FoodTruckTests: XCTestCase {
    func test_givenLoggedOut_whenOpened_thenShowsSignIn() { … }
}

// ✅ Swift Testing
struct FoodTruckTests {
    @Test func engineWorks() { … }
    @Test("Rejects a token that expired more than five minutes ago")
    func rejectsExpiredToken() async throws { … }
}
```

`swift-format`'s `AlwaysUseLowerCamelCase` deliberately permits underscores in test function names, so `test_engine_works` will not be flagged. That is tolerance, not endorsement. Keep the prefix only in files still on XCTest, where the runtime requires it.

**N44. Suites are a plain noun ending in `Tests`; tags are lowerCamelCase statics on `Tag`.** Raw identifiers (SE-0451, implemented **Swift 6.2**) are the sanctioned alternative to a camelCase identifier plus a display string — pick one form per repo, not both on one test.

```swift
struct CartTests {}
@Suite("Checkout flow") struct CheckoutTests {}

@Test func `an empty cart has a zero total`() { … }

extension Tag { @Tag static var legallyRequired: Self }
@Test("Vendor's license is valid", .tags(.legallyRequired)) func licenseValid() { … }
```

---

## 14. File, target and module names

`01-PROJECT-STRUCTURE.md` owns layout — which declarations go in which file (P24–P25) and how modules are cut (P19). These are the naming shapes only.

| Thing | Rule | ✅ | ❌ |
|---|---|---|---|
| File with one type | The filename *is* the type name — spelling only | `Book.swift` | `Models.swift` |
| Conformance extension | `Type+Protocol.swift` | `Book+Codable.swift` | `Codable.swift` |
| Extensions on a foreign type | `Foreign+Feature.swift` | `Date+Relative.swift` | `Extensions.swift` |
| Free declarations with no owner | Descriptive noun | `Math.swift` | `Helpers.swift`, `Utils.swift`, `Constants.swift` |
| Target / module | UpperCamelCase — it becomes the `import` name, and hyphens are illegal there | `PaymentsCore` | `payments-core` |
| Test target | `<Target>Tests`, under `Tests/` — SE-0129 links it automatically | `PaymentsCoreTests` | `PaymentsCoreTest` |
| Module suffixes that work | `…Kit`, `…Core`, `…UI`, `…Testing` | `PaymentsUI` | `…Common`, `…Shared`, `…Helpers` |

**N45. `Utils.swift` is the file-level form of a `Manager` class (N26).** It is where code goes when nobody decided what it is, and its name never stops being true, so nothing is ever removed from it.

---

## 15. Doc comments prove the name

**N46. Write the one-sentence summary before you finalise the signature. If it needs the word "and", split the API.** This is N2 made mechanical, and it is the only naming review that catches a *wrong abstraction* rather than a wrong word.

```swift
/// Fetches the user and updates the cache and posts a notification.   ← three "and"s → three APIs
func refreshUser(id: String) async throws -> User
```

`03-WRITING-THE-CODE.md` §11 owns doc-comment mechanics — `///` over `/** */`, tag order and syntax, symbol-link backticks, comment placement relative to attributes, and which `swift-format` doc rules to enable (W53, W54). There is deliberately no second copy here. What belongs to *naming*:

- Method summaries are verb phrases ("Returns the sum…"); property summaries are noun phrases ("The background colour of the view."). This is N6 at the documentation layer: if a property's summary starts with a verb, you probably named a method.
- Use the **internal** parameter name in the doc, not the external label — which is why N17 tells you to pick internal names that read in prose.
- A summary that can only be written by restating the signature means the name already carries the whole meaning; delete the comment rather than improving it.

**N47. Document `- Complexity:` on any computed property that is not O(1).** Property syntax promises cheap access; a hidden O(n) behind a dot is how O(n²) loops ship. This sits in the naming file because it is a naming consequence — a property whose access is O(n) is often a method wearing a noun (N6).

```swift
/// The number of elements in the collection.
///
/// - Complexity: O(*n*), where *n* is the number of elements.
var count: Int { … }
```

---

## 16. Renaming legacy APIs: run the importer in your head

SE-0005 is the Objective-C-to-Swift name translation algorithm — the guidelines expressed as mechanical transformations. Applied to your own old Swift, it settles most naming arguments without a meeting.

1. **Strip the completion handler** → `async throws`, return the value.
2. **Prune words that restate a parameter's type or the receiver's type.**
3. **Split at the last preposition** to form the first argument label.
4. **Type-preserving transforms lose the head word**: `colorWithAlphaComponent(_:) -> NSColor` becomes `withAlphaComponent(_:)`.
5. **Boolean properties get `is`**: `var empty: Bool` becomes `var isEmpty: Bool`.
6. **Infer defaults**: nullable trailing closures → `nil`, option sets → `[]`, dictionaries → `[:]`.
7. **Apply N6/N37**: a value returned with no visible side effect is a noun phrase — drop `get`, `fetch`, `Async`.

```swift
// Before
func fetchUserDataWithUserID(_ userID: String,
                             completionHandler: @escaping (UserData?, NSError?) -> Void)

// 1  async replaces the completion handler          → fetchUserDataWithUserID(_:) async throws -> UserData
// 2  "Data" restates nothing; UserData is a User    → fetchUserWithUserID(_:)
// 3  split at the preposition "With"                → fetchUser(userID:)
// 2  "User" is already in the return type           → fetchUser(id:)
// 7  a noun that returns a value needs no verb      → user(id:)

// After
func user(id: String) async throws -> User
let user = try await store.user(id: id)     // "store, user with id" ✅
```

Calibration pairs from the proposal: `moveToPoint(_:)` → `move(to:)`, `bezierPathByReversingPath()` → `reversing()`, `copyWithZone(_:)` → `copy(with:)`, `stringByTrimmingCharactersInSet(_:)` → `trimming(_:)`.

*Cost, stated plainly:* renaming a public API is a source break. Ship the rename behind `@available(*, deprecated, renamed: "user(id:)")` so callers migrate with a fix-it rather than a compile error, and delete the shim one minor version later. Inside an app module, just rename it — Xcode's refactor handles it and nobody is downstream. Deprecation and release mechanics are `07-TOOLING-BUILD-AND-SHIPPING.md`.

---

## 17. Banned-name lookup

Every name in the first column compiles. A reviewer should still reject it on sight. Decision tables live in §3 (mutating pairs), §5 (argument labels), §10 (abbreviations), §12 (modifiers) and §14 (files); this is only the ban list.

| ❌ Never | ✅ Instead | Rule |
|---|---|---|
| `FooProtocol`, `FooImpl`, `DefaultFoo`, `FooBase` | name the abstraction, qualify the implementation (`RemoteUserStore`) | N25 |
| `FooManager`, `FooProvider`, `FooHelper`, `FooHandler`, `FooService`, `FooInfo`, `FooData` | the domain noun (`Palette`, `HTTPClient`, `Ledger`) | N26 |
| `Networking`, `Requesting`, `Routing` as protocol names | `HTTPClient`, `Router` | N27 |
| `getUserAsync(id:)`, `fetchUserData(_:)` | `user(id:)` | N37 |
| `ImageCacheActor`, `LibraryViewModelManager` | `ImageCache`, `Library` | N38, N40 |
| `shuffleInPlace()`, `normalizeSelf()`, `mutatingFoo()` | `shuffle()` / `shuffled()`, or ship only `normalized()` | N8 |
| `empty`, `flag`, `isNotHidden` | `isEmpty`, `isRetryEnabled`, `isHidden` | N9, N10 |
| `UIColor.redColor`, `URLSession.sharedSession` | `UIColor.red`, `URLSession.shared` | N11 |
| `Link(to: destination)` | `Link(target: destination)` | N12 |
| `x.add(subview: y)` | `x.addSubview(y)` | N15 |
| `HTTPClientError.httpClientTimedOut` | `HTTPClient.Failure.timedOut` | N22, N29 |
| `case failed(String, Int)` | `case failed(reason: String, statusCode: Int)` | N30 |
| `Cache<KeyType, ValueType>`, `decode<TypeToDecode>` | `Cache<Key, Value>`, `decode<T>` | N32 |
| `kSecondsPerMinute`, `SECONDS_PER_MINUTE`, `_cache` | `secondsPerMinute`, `private var cache` | N33 |
| `uRLString`, `HtmlParser`, `parseJson()` | `urlString`, `HTMLParser`, `parseJSON()` | N34 |
| `btn`, `vc`, `mgr`, `cfg`, `resp`, `idx` | spell it | N35 |
| `ContentView`, `MainView2`, `BookVC` | `LibraryShelf`, `BookRow` | N39 |
| `.applyCardStyle()`, `.addBadge(3)` | `.cardStyle()`, `.badge(3)` | N41 |
| `func test_token_expired_1()` | `@Test("…") func rejectsExpiredToken()` | N43 |
| `Helpers.swift`, `Extensions.swift`, `Constants.swift` | `Book.swift`, `Date+Relative.swift` | N45 |
| `MyAppLogger` (renamed to dodge a collision) | `Logging::Logger` (SE-0491, Swift 6.3+) | N23 |

**Not yet settled.** SE-0516 (`Iterable`, formerly `BorrowingSequence`) was still listed as in active review on 2026-07-27 — its member names (`makeIterableIterator()`, `IterableIteratorProtocol`) may still change; verify before writing code against it. It is worth watching as a case study either way: the core team renamed an implementation-flavoured protocol (`BorrowingSequence`) to a capability name (`Iterable`) *during review*, and deliberately chose member names that would not collide with `Sequence`'s. If they can rename that late, so can you.

---

## Checklist

- [ ] Call site reads aloud as a grammatical, unambiguous English sentence (N1).
- [ ] The one-sentence doc summary writes itself; if it does not, the design is wrong (N2).
- [ ] No word restates a type the compiler already shows; weakly-typed parameters carry a role noun (N3–N5).
- [ ] Pure → noun phrase; effectful → imperative verb (N6).
- [ ] Mutating pairs use `-ed`, `-ing` or `form`; no invented suffix; ship one side alone if neither reads (N7, N8).
- [ ] Booleans are positive assertions using `is`/`has`/`can`/`should`/`will`/`did`/`does` or a third-person verb (N9, N10).
- [ ] `make` on factory methods; static factory properties do not repeat the type (N11).
- [ ] No initialiser reads as a phrase with its type; init parameters match stored properties; narrowing conversions are labelled (N12–N14).
- [ ] Argument labels came from the §5 table, not from taste; defaulted parameters are labelled and last (N15, N16).
- [ ] Internal parameter names, tuple members and closure parameters read well in generated docs (N17, N18).
- [ ] No overload differs only by return type; shared base names mean the same thing (N19, N20).
- [ ] No Objective-C prefixes; errors and configuration nested in their owner unless shared (N21, N22).
- [ ] No type renamed to dodge a module collision that `Module::Type` now solves (N23).
- [ ] Protocols are nouns or genuine `-able`/`-ing` capabilities; zero `Protocol` suffixes; zero bag-of-code suffixes (N24–N27).
- [ ] Delegate methods pass the sender first and match the Void/Bool/value shapes (N28).
- [ ] Enum cases are lowerCamelCase, stutter-free and `is`-free; associated values labelled unless singular and obvious (N29, N30).
- [ ] Errors are nested `Failure` or top-level `FooError`; cases describe the failure, never command (N31).
- [ ] Generic parameters named when they have a role; never `…Type` (N32).
- [ ] lowerCamelCase values, no `k`/SCREAMING/leading underscore; acronyms uniformly cased; abbreviations are real terms of art (N33–N36).
- [ ] No `Async` suffix, no `get` prefix; streams are plural nouns; actors are plain nouns (N37, N38).
- [ ] SwiftUI: no `ContentView`; models are domain nouns, `…Store` only when the type gatekeeps a collection; per-screen types named for the job (N39, N40).
- [ ] Modifiers name the thing configured, type `Foo` + method `.foo()`; environment values use `@Entry` and the value's name (N41, N42).
- [ ] Tests carry no `test` prefix, the sentence lives in `@Test("…")`, suites end in `Tests` (N43, N44).
- [ ] No `Utils.swift`, `Helpers.swift` or `Extensions.swift` in the diff (N45).
- [ ] Public declarations have a summary that audits the name; non-O(1) computed properties document `- Complexity:` (N46, N47).
