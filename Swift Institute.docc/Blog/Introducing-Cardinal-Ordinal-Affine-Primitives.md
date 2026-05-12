# Numbers, by kind: typed counts, positions, and offsets

@Metadata {
  @TitleHeading("Swift Institute Blog")
  @PageImage(purpose: card, source: "blog-card", alt: "Swift Institute Blog")
}

Three packages went public on GitHub today: [`swift-cardinal-primitives`][cardinal-repo], [`swift-ordinal-primitives`][ordinal-repo], and [`swift-affine-primitives`][affine-repo]. They ship `Cardinal`, `Ordinal`, and `Affine.Discrete.Vector` — three typed numbers that split apart what stdlib calls `Int`.

Swift's `Int` is excellent storage for small whole numbers. It is a poor type for meaning. A count, a position, and a signed offset can all be represented as `Int`, so the compiler cannot tell when you pass one where another was intended.

## The bug `Int` can't catch

If you've written Swift, you've written this:

```swift
func reserve(count: Int) { /* ... */ }

let index = 5
reserve(count: index)   // compiles — and means nothing
```

`count: Int` accepts the integer `5`. `index: Int` is also `5`. The type signature has no way to tell you that you've just asked the function to reserve five elements when you meant to identify the fifth one.

The same problem shows up at every boundary: `offset: Int` accepts a count, `position: Int` looks like a signed difference, and `count: -3` typechecks even though a negative count is nonsensical.

Three types make the confusion impossible:

```swift
import Cardinal_Primitives
import Ordinal_Primitives

func reserve(count: Cardinal) { /* ... */ }

let index: Ordinal = 5
reserve(count: index)   // compile error: Ordinal is not Cardinal
```

The compiler now knows that *how many*, *which one*, and *how far between* are different questions, and it stops you from answering the wrong one.

## Cardinal — counts

`Cardinal` answers *how many?* It is a non-negative integer, backed by `UInt`. It cannot represent a negative value: there is no valid `Cardinal(-3)`, because the underlying storage cannot hold one.

```swift
let items: Cardinal = 5
let total = items + Cardinal(3)   // 8 (trapping +)
```

There is no plain `-` operator on `Cardinal`, because counts cannot go negative. `0 - 1` has no answer the type can hold. Subtraction has to commit to a policy, and the API forces the choice at the call site:

```swift
let stock: Cardinal = 12
let requested: Cardinal = 20

let remaining = stock.subtract.saturating(requested)   // Cardinal(0) — clamps at zero

do {
    let amount = try stock.subtract.exact(requested)   // throws .underflow
} catch Cardinal.Error.underflow {
    // Caller decides what underflow means here.
}
```

Addition has the same shape: trapping `+` for the everyday case, with `.add.saturating` and `.add.exact` for explicit overflow handling. The policy is visible at the call site, so code review can ask whether saturation or exact failure is the right behavior here.

### Counts by domain

Once the kind is right, you can also separate domains. `Tagged<Tag, Cardinal>` from [`swift-tagged-primitives`][tagged-repo] wraps the same `Cardinal` value with a compile-time domain label. Given domain types such as `User` and `Inbox`, that gives each domain its own count type:

```swift
extension User  { typealias Count = Tagged<Self, Cardinal> }
extension Inbox { typealias Count = Tagged<Self, Cardinal> }

let users: User.Count = 100
let inbox: Inbox.Count = 12
// users + inbox          // ❌ compile error — different tags
let next = try users.add.exact(1)   // User.Count(101)
```

Two `UInt`-backed counts that mean different things in the domain will not add. You write the typealias once per domain, and the compiler keeps the domains apart from there.

## Ordinal — positions

`Ordinal` answers *which one?* It is a non-negative position in a 0-indexed sequence, also backed by `UInt`. `Ordinal.zero` is the first position; there is no representation for "before zero".

```swift
let first: Ordinal = 0
let next     = try first.successor.exact()                 // Ordinal(1)
let fifth    = try first.advance.exact(by: Cardinal(4))    // Ordinal(4)
let previous = try fifth.predecessor.exact()               // Ordinal(3)
```

Five accessors handle movement through a sequence — `.successor`, `.predecessor`, `.advance`, `.retreat`, `.distance` — and each ships only the policies that make sense for its operation. `.exact` (throws on overflow) is universal; `.saturating` (clamps at the type boundary) and `.clamped` (clamps to a caller-supplied bound) are available where they fit. `.predecessor` ships only `.exact`, because saturating-predecessor-at-zero is meaningless in a sequence. `.distance` is the exception — instead of overflow policies, it ships `.forward(to:)` (throws if the target is behind) and `.unchecked(to:)`.

### Distance is directional

`.distance.forward(to:)` returns the number of steps between two positions — but only when the target is forward of `self`:

```swift
let earlier: Ordinal = 3
let later: Ordinal = 7
let span = try earlier.distance.forward(to: later)   // Cardinal(4)

do {
    _ = try later.distance.forward(to: earlier)
} catch Ordinal.Error.notForward {
    // Backward distance is a different question.
}
```

That's the right shape for *how many steps from here to there*. It's the wrong shape for *how far apart, signed*. The signed-distance question is what makes the next type necessary.

### Positions by domain

The same pattern gives each domain its own position type:

```swift
extension Element { typealias Index = Tagged<Self, Ordinal> }

let position: Element.Index = 5
let after = position + 1   // Element.Index(6)
```

Positions in different domains can't mix. Here, `+ 1` advances by one count in the same domain; the tag is preserved through the operation.

## Affine.Discrete.Vector — signed offsets

`Affine.Discrete.Vector` answers *how far between?* It is the type for signed movement: three steps forward, one step back, or the displacement from one position to another.

Positions are still non-negative. Vectors are signed. That asymmetry shows up at the type level: a position can move by a vector, and two positions can produce a vector, but positions themselves are not offsets.

Three operations connect positions and vectors:

| Operation              | Result                            | Throws                          |
|------------------------|-----------------------------------|---------------------------------|
| `Position + Vector`    | `Position` (translated forward)   | `Ordinal.Error`                 |
| `Position − Vector`    | `Position` (translated backward)  | `Ordinal.Error`                 |
| `Position − Position`  | `Vector` (the displacement)       | `Affine.Discrete.Vector.Error`  |

The throws aren't decorative. The position side is `UInt`, so it can over- or underflow when translated. The displacement side is `Int`, so two positions more than `Int.max` apart can't be represented. Each call site picks its own `try` discipline:

```swift
let position: Element.Index = 5
let step: Element.Index.Offset = 1

let advanced  = try position + step                                  // Element.Index(6)
let retreated = try advanced - step                                  // Element.Index(5)
let displacement: Element.Index.Offset = try advanced - retreated    // Offset(1)
```

`Element.Index.Offset` is the offset type paired with `Element.Index`. An index from one domain will not combine with an offset from another.

The Affine package also includes typed ratios for scaling between related domains, such as bytes to bits or frames to seconds. That keeps conversions explicit without falling back to untyped multiplication.

## Scope

A few things these packages don't try to do.

**No `Numeric` conformance.** None of these types is "a number you can multiply by a `Double`". They're a count, a position, and an offset; multiplying a position by `2.5` is meaningless, and forcing them to look like `Double`s would erase the very distinctions the types exist to enforce.

**No transfinite cardinals or ordinals.** ℵ₀, ω, and the rest of set-theoretic arithmetic are out of scope. These are finite numbers for programming.

**No multidimensional vectors.** `Affine.Discrete.Vector` is one-dimensional. Multidimensional affine geometry and continuous transforms over `Double`/`Float` belong in a downstream linear-algebra package.

**Foundation-free.** All three packages compile under Swift Embedded the same as on a server.

## Getting started

For the combined path, depending on `swift-affine-primitives` is enough: it re-exports Cardinal and Ordinal because affine operations refer to both.

```swift
dependencies: [
    .package(
        url: "https://github.com/swift-primitives/swift-affine-primitives.git",
        branch: "main"
    ),
]

.target(
    name: "App",
    dependencies: [
        .product(name: "Affine Primitives", package: "swift-affine-primitives"),
    ]
)
```

If you only need counts or positions, the Cardinal and Ordinal packages can also be adopted independently. All three are Apache 2.0 and require Swift 6.3.1.

## Links

- [GitHub repository: swift-cardinal-primitives][cardinal-repo]
- [GitHub repository: swift-ordinal-primitives][ordinal-repo]
- [GitHub repository: swift-affine-primitives][affine-repo]

[cardinal-repo]: https://github.com/swift-primitives/swift-cardinal-primitives
[ordinal-repo]: https://github.com/swift-primitives/swift-ordinal-primitives
[affine-repo]: https://github.com/swift-primitives/swift-affine-primitives
[tagged-repo]: https://github.com/swift-primitives/swift-tagged-primitives
