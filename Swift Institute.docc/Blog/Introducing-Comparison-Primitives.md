# Introducing swift-comparison-primitives

@Metadata {
  @TitleHeading("Swift Institute Blog")
  @PageImage(purpose: card, source: "blog-card", alt: "Swift Institute Blog")
}

[`swift-comparison-primitives`](https://github.com/swift-primitives/swift-comparison-primitives) is now public on GitHub. It ships two things: a three-way comparison value type — `Comparison` with `.less` / `.equal` / `.greater` cases — and `Comparison.Protocol`, an ordering protocol that natively supports `~Copyable` types.

The package is the middle of a three-package sub-cohort that ships together. The companion posts cover <doc:Introducing-Equation-Primitives> (the equality root) and <doc:Introducing-Hash-Primitives> (the hash leaf).

## What's new

The headline type is `Comparison`:

```swift
import Comparison_Primitives

public enum Comparison: Sendable, Hashable, CaseIterable {
    case less
    case equal
    case greater
}
```

A three-way comparison returns one of three values, by trichotomy. A dedicated type beats the `negative / zero / positive` Int convention from C and Java: the type system enforces the domain, the cases carry semantic meaning, and the operations on the result have algebraic structure that integers don't.

Reverse a comparison (involution — applying it twice gives back the original):

```swift
let result = Comparison(comparing: 5, to: 10)   // .less
result.reversed                                 // .greater
!result                                         // .greater (prefix !)
```

Compose comparisons lexicographically. `then` is the monoid operation under `.equal` as identity:

```swift
struct Person { let name: String; let age: Int; let id: Int }

func compare(_ lhs: Person, _ rhs: Person) -> Comparison {
    Comparison(comparing: lhs.name, to: rhs.name)
        .then(Comparison(comparing: lhs.age, to: rhs.age))
        .then(Comparison(comparing: lhs.id, to: rhs.id))
}
```

The lazy form `then(with:)` defers later comparisons until the prior one returns `.equal` — useful when subsequent comparisons are expensive.

## Highlights

### Move-only ordering through `Comparison.Protocol`

`Comparison.Protocol` mirrors `Swift.Comparable` but with `borrowing` parameters, so `~Copyable` types can implement it without being copied:

```swift
struct Token: ~Copyable {
    let priority: Int
}

extension Token: Comparison.Protocol {
    static func < (lhs: borrowing Token, rhs: borrowing Token) -> Bool {
        lhs.priority < rhs.priority
    }

    static func == (lhs: borrowing Token, rhs: borrowing Token) -> Bool {
        lhs.priority == rhs.priority
    }
}

var a = Token(priority: 5)
var b = Token(priority: 10)
a < b                            // true
a.compare.to(b)                  // .less
```

The protocol refines `Equation.Protocol`, mirroring Swift's `Comparable: Equatable`. You implement `<` and `==`; the protocol provides default `<=`, `>`, `>=`.

### Fluent compare and clamp

A `.compare` accessor namespace gives you boolean queries that read at the call site:

```swift
var apple = "apple"
let banana = "banana"

apple.compare.to(banana)             // .less
apple.compare.isLess(than: banana)   // true
apple.compare.isEqual(to: "apple")   // true
```

`.clamp` mirrors the shape for bound-restriction:

```swift
var temperature = 105.0
temperature.clamp.between(0.0, and: 100.0)   // 100.0
temperature.clamp.above(110.0)               // 110.0
```

Both accessor namespaces work on stdlib `Comparable` types (`String`, `Int`, `Double`, `Character`, …) and on custom types conforming to `Comparison.Protocol`. The implementations are backed by the `Property.Inout` pattern from [`swift-property-primitives`](https://github.com/swift-primitives/swift-property-primitives) — fluent namespaces without per-type proxy structs.

### Dual-mode protocol, SE-0499 ready

[SE-0499](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md) extends `Swift.Comparable` to natively admit `~Copyable` and `~Escapable` conformers. The proposal is implemented in Swift 6.4. Until 6.4 is your floor, `Comparison.Protocol` ships its own fork; from 6.4 onwards, the protocol is a typealias to `Swift.Comparable`:

```swift
#if swift(>=6.4)
    extension Comparison {
        public typealias `Protocol` = Swift.Comparable
    }
#else
    extension Comparison {
        public protocol `Protocol`: Equation.`Protocol`, ~Copyable {
            static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool
        }
    }
#endif
```

Conformances written today work on both compiler families. The [cross-package research](https://github.com/swift-institute/Research/blob/main/se-0499-implications-for-equation-hash-comparison-primitives.md) walks the transition.

The `Comparison` enum (the three-way result type) and the `.compare` / `.clamp` namespaces are independent of this — they stay regardless of which compiler your consumer ships against.

## Getting started

Until `0.1.0` is tagged, depend on `main` directly:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-comparison-primitives.git", branch: "main")
]

.target(
    name: "App",
    dependencies: [
        .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
    ]
)
```

Once tagged, this becomes `from: "0.1.0"`. The package is Apache 2.0 and ships four library products — `Comparison Primitives` (the umbrella), `Comparison Primitives Core` (the value type, protocol, and fluent accessors without stdlib bridge), `Comparison Primitives Standard Library Integration` (re-conformance of stdlib types under Swift <6.4 plus the `Comparable` bridge that powers `.compare` / `.clamp` on stdlib types), and `Comparison Primitives Test Support`.

## What's next

The companion packages — `swift-equation-primitives` (see <doc:Introducing-Equation-Primitives>) and `swift-hash-primitives` (see <doc:Introducing-Hash-Primitives>) — ship alongside this one. `Hash.Protocol` refines `Equation.Protocol` (encoding the equals/hashCode contract at the type level); `Comparison.Protocol` refines `Equation.Protocol` (matching Swift's `Comparable: Equatable`).

The `Comparison` enum's monoidal `then` makes it useful as a sort-key combinator. If you're building a sort comparator over multiple fields, the lexicographic-composition pattern shown above replaces nested if-else chains with one expression.
