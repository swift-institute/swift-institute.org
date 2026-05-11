# Introducing swift-pair-primitives, swift-either-primitives, and swift-product-primitives

@Metadata {
  @TitleHeading("Swift Institute Blog")
  @PageImage(purpose: card, source: "blog-card", alt: "Swift Institute Blog")
}

[`swift-pair-primitives`][pair-repo], [`swift-either-primitives`][either-repo], and [`swift-product-primitives`][product-repo] are now public on GitHub. These three packages introduce the small composition primitives behind the boundary where Swift tuples stop being enough: `Pair` for two values together, `Either` for one of two alternatives, and `Product` for an arbitrary number of values. This post walks through what each shape is good for, where the boundaries are, and the language-feature constraints that explain the present package layout.

*Apache 2.0 · Foundation-free · Swift 6.3.1 · macOS / iOS / tvOS / watchOS / visionOS at v26, plus Linux and Windows.*

In the Swift Institute layering model, these are Layer 1 primitives: small, Foundation-free building blocks intended to sit below higher-level collections, protocols, and domain packages.

## The three shapes

| Shape | Holds | Reach for it when |
|---|---|---|
| `Pair<First, Second>` | `First` and `Second` | two values need a name, conformances, or move-only transport |
| `Either<Left, Right>` | `Left` or `Right` | two alternatives are both first-class |
| `Product<each Element>` | all elements in the pack | many typed values need one product-shaped surface |

Two values together → "product". One of two values → "coproduct". Many values together → "n-ary product". The naming is borrowed from category theory, which is also where the API family comes from: `map`, `fold`, `apply`, and `swapped`. You do not need the vocabulary to use these — but it explains why the three APIs line up.

## Pair: two values, transported together

`Pair<First, Second>` exposes its two components as stored properties — `first` and `second`. `swapped()` exchanges the arms. `map(first:)`, `map(second:)`, and `map(first:second:)` are labeled overloads of a single verb that transform the components independently. `apply(_:)` consumes the pair and hands both arms to a closure for a single result.

```swift
import Pair_Primitives

let coordinate = Pair(3, 4)
let flipped = coordinate.swapped()           // Pair(4, 3)

let labelled = Pair(7, "answer")
let widened = labelled.map(
    first:  { Double($0) },
    second: { $0.uppercased() }
)   // Pair(7.0, "ANSWER")
```

The labels on `map(first:)` and `map(second:)` are required: a trailing-closure call site would otherwise be ambiguous about which arm is moving.

The `~Copyable` tier is where `Pair` does work the bare tuple does not. When both arms are `~Copyable`, `Pair` is `~Copyable`. It transports paired resources without copying them, and it does not close, unlock, or otherwise act on them on drop — lifecycle is the consumer's call. `apply` is how you make that call:

```swift
struct Descriptor: ~Copyable { let raw: Int32 }

let pipe = Pair(Descriptor(raw: 3), Descriptor(raw: 4))
let result = pipe.apply { read, write in
    close(write.raw)        // consumer chooses what to close
    return read.raw
}   // pair consumed; single Int32 returned
```

`apply` consumes the pair, hands you both arms in a closure, and returns whatever the closure returns. The closure body decides which arm to release, which to keep, and what to surface as the result. Anything you can build from a `First` and a `Second` is exactly what `apply` lets you build from a `Pair<First, Second>`.

The `~Escapable` support matrix follows from how each operation handles closure-transformed arms:

| Operation | `~Escapable` arms | Why |
|---|---|---|
| `swapped()` | both arms | no closure transforms either arm; the result lifetime threads through |
| `apply(_:)` | both arms | the closure consumes the pair; both arms thread into a single result |
| `map(first:)`, `map(second:)` | un-transformed arm only | the closure-transformed arm must be `Escapable` — Swift cannot yet thread a `~Escapable` closure output to the result |
| `map(first:second:)` | none | both arms are closure-transformed |

The cohort verdict and the failure modes are written up in the [`~Escapable` cohort research][escapable-research], with empirical reproductions under each package's `Experiments/`.

For `Copyable` arms, the package adds bidirectional tuple conversion — `Pair((3, 4))` and `point.tuple` — so values flow into and out of code that prefers Swift's bare tuple syntax.

`Pair` transports values; it does not run cleanup on drop. See [What this is not](#What-this-is-not) for the lifecycle boundary.

## Either: two alternatives, both first-class

`Either<Left, Right>` has two cases — `.left` and `.right`. `swapped()` exchanges them. `map(left:)`, `map(right:)`, and `map(left:right:)` transform one arm or both. `fold(left:right:)` collapses an `Either` to a single value by handling both cases. When one arm is `Never`, the inhabited side falls out by type.

```swift
import Either_Primitives

let success: Either<String, Int> = .right(42)
let failure: Either<String, Int> = .left("not found")

let doubled = success.map(right: { $0 * 2 })   // .right(84)
let flipped = success.swapped()                // Either<Int, String>.left(42)

let widened = success.map(
    left:  { "error: \($0)" },
    right: { Double($0) }
)   // Either<String, Double>.right(42.0)
```

`fold(left:right:)` is the eliminator. Anything you can build with "if the value is a `Left`, do A; if it is a `Right`, do B" is exactly what `fold` lets you build:

```swift
let message: String = either.fold(
    left:  { l in describe(l) },
    right: { r in describe(r) }
)
```

When one arm is `Never`, the case is uninhabited and the value falls out by type:

```swift
let certain: Either<Never, Int> = .right(10)
print(certain.value)  // 10 — left side is uninhabited
```

`value` is a property on the `Copyable` tier. For `~Copyable` and `~Escapable` arms, the package ships a `value(of:)` free function that consumes the `Either` and moves the inhabited side out — moving a value out of a generic `~Copyable` enum's case payload through a property accessor is currently blocked at the compiler level, so the surface splits to keep the move-only path available without losing the convenience of `e.value` on the common case:

```swift
struct Resource: ~Copyable { let id: Int }
let e: Either<Never, Resource> = .right(Resource(id: 7))
let r = value(of: e)    // moves the resource out of e
```

`Either` is the default for two-armed domain modelling — return types whose two arms are both meaningful, error channels that carry different information depending on the cause, parser branches, dual-path state machines, and cross-cutting concerns where one arm is a separate axis of control flow rather than a failure of the other:

```swift
// Cross-cutting cancellation: the right arm is not a failure of the
// domain operation, it is a separate axis of control flow.
func step() -> Either<Domain.Error, Interrupt> { … }
```

Modelling cancellation this way keeps `Domain.Error` honest about its domain — you do not have to add an `Interrupt` case to every domain error type, and you do not have to teach `Domain.Error` that cancellation exists.

Isn't this `Result`? Short answer: `Result<T, E>` privileges one arm as "the failure"; `Either` is for the symmetric case where neither arm is privileged. See [What this is not](#What-this-is-not) for the longer answer, including how SE-0413's typed-throws shape relates.

## Product: many values, one typed product

`Product<each Element>` is parameterised over a parameter pack — the n-ary generalisation of `Pair`. Components live in the `values` tuple, and `@dynamicMemberLookup` keyed on `KeyPath<(repeat each Element), T>` lets you skip the `.values` step:

```swift
import Product_Primitives

let triple = Product(1, "hello", true)   // Product<Int, String, Bool>

print(triple.values.0)   // 1 — direct tuple access
print(triple.0)          // 1 — via dynamic member lookup
print(triple.1)          // "hello"
print(triple.2)          // true
```

Dynamic member lookup is keyed on key paths, which means tuple-element resolution happens at compile time — `triple.0` knows it has type `Int`, not `Any`.

`map` is the n-ary functor action: one closure per position, all run in one pass. Pass identity (`{ $0 }`) for positions you want to leave unchanged:

```swift
let mapped = triple.map(
    { $0 + 1 },
    { $0.uppercased() },
    { !$0 }
)   // Product(2, "HI", false)
```

Pack-shape composition lets you grow, shrink, or rearrange the product without naming intermediate tuple types. `append` and `prepend` extend the pack by one position; `zip` pairs two products of equal arity; `fold` collapses to a single value:

```swift
let pair = Product(1, "hi")
pair.append(true)             // Product<Int, String, Bool>
pair.prepend(0.5)             // Product<Double, Int, String>

let a = Product(1, "x")
let b = Product(true, 0.5)
a.zip(b)                      // Product<(Int, Bool), (String, Double)>

triple.fold { (a, b, c) in "\(a) \(b) \(c)" }   // "1 hello true"
```

The headline payoff is typed multi-cause errors. When every component conforms to `Swift.Error`, `Product` itself conforms — which gives typed multi-cause aggregation directly in the `throws` clause:

```swift
enum Parse      { struct Error: Swift.Error {} }
enum Validation { struct Error: Swift.Error {} }

func process() throws(Product<Parse.Error, Validation.Error>) {
    // throw an aggregated cause...
}

do {
    try process()
} catch let causes {
    handle(parse: causes.0, validation: causes.1)
}
```

The catch site sees `causes` as `Product<Parse.Error, Validation.Error>`, with both arms accessible by position. No `any Error` existential, no enum-case proliferation when a third cause appears — extending the function's failure surface to `throws(Product<Parse.Error, Validation.Error, RateLimit.Error>)` makes every call site that previously matched the two-arm shape in a typed `do/catch` fail to typecheck until it covers the new arm.

`Product`'s arms are `Copyable & Escapable` only — Swift's parameter-pack syntax does not yet admit `each T: ~Copyable` or `each T: ~Escapable`. For the binary `~Copyable` case, use `Pair`. See [What this is not](#What-this-is-not) for the constraint detail.

## At a glance

| Conformance | Pair | Either | Product |
|---|:---:|:---:|:---:|
| `Sendable`, `Equatable`, `Hashable`, `Codable` | ✓ | ✓ | ✓ |
| `Comparable` | ✓ | -- | ✓ |
| `Equation.Protocol`, `Hash.Protocol`, `Comparison.Protocol` | ✓ | ✓ | ✓ |
| `Swift.Error` | -- | when both arms are errors | when every component is an error |
| `CustomStringConvertible` | -- | -- | ✓ |

`Equation.Protocol`, `Hash.Protocol`, and `Comparison.Protocol` come from three companion packages — see <doc:Introducing-Equation-Primitives>, <doc:Introducing-Hash-Primitives>, and <doc:Introducing-Comparison-Primitives> — that fork stdlib's `Equatable`, `Hashable`, and `Comparable` to admit `~Copyable` conformers via `borrowing` parameters on Swift 6.3, then collapse to typealiases over the stdlib originals on Swift 6.4+ per [SE-0499][se-0499]. The transition is invisible to consumers: write conformances once, both compiler families build clean.

Toolchain: Swift 6.3.1. Apple platforms target v26 (macOS, iOS, tvOS, watchOS, visionOS); Linux and Windows are part of the CI matrix. License: Apache 2.0. No Foundation imports anywhere in the three packages.

## Getting started

Until `0.1.0` is tagged, depend on `main` directly:

```swift
.package(
    url: "https://github.com/swift-primitives/swift-pair-primitives",
    branch: "main"
)
```

Replace `swift-pair-primitives` with `swift-either-primitives` or `swift-product-primitives` as needed, or add all three if your package uses the full family. The packages are independent; each re-exports the companion equality, hashing, and comparison primitives it needs.

## What this is not

A few boundaries deliberately left in place, so you do not have to discover them by surprise.

**`Pair` is not a resource-management vehicle.** It transports a pair of values; it does not run cleanup on drop. Consumers choose lifecycle through `apply` — the closure body is where you decide what to close, what to keep, and what to surface. If you want a type that owns and releases two resources together, build it on top of `Pair` and add the lifecycle behaviour at that layer.

**`Either` is not a drop-in for stdlib's `Result`.** Both are two-armed sums, but they cover different design spaces. `Either` is the default for domain modelling — returns, errors, branches — where both arms are first-class; pick by what the value carries on each arm, not by reflex. `Result<T, E>` covers the narrower case where you specifically need stdlib's `try` bridging on a Result-returning API, when `get()` is the natural call-site shape, or when one arm really is purely "the failure" with nothing else to model on the other side.

[SE-0413][se-0413] (Typed Throws) reaches for an `Either` shape pedagogically when describing how `throws(some Error)` *could* combine multiple thrown types under the hood; the proposal does not require it as an implementation. The connection runs the other way: the same shape that proves useful for that pedagogical sketch is what `swift-either-primitives` gives you as a public type for cases where a typed sum is what you actually want, while typed throws on a single error type — including `Product<each E: Swift.Error>` for the multi-cause case — covers the error channel itself.

**`Product` is not yet `~Copyable`-aware.** Swift's parameter-pack syntax does not yet admit `each T: ~Copyable` or `each T: ~Escapable`, so `Product`'s arms are `Copyable & Escapable` only. For the arity-2 `~Copyable` case, use `Pair`. The package will revisit pack support when the language extends parameter packs to suppressed conformances; until then `Pair` is the way to carry move-only resource pairs.

## What's next

DocC catalogs live alongside the source on `main` — see `Sources/Pair Primitives/Pair Primitives.docc/`, `Sources/Either Primitives/Either Primitives.docc/`, and `Sources/Product Primitives/Product Primitives.docc/` in their respective repos for the per-method constraint shapes.

The next compiler change that would expand `Product`'s reach is parameter-pack support for `each T: ~Copyable` and `each T: ~Escapable`. When that lands, `Product`'s arms will align with `Pair`'s and `Either`'s, and the parameter-pack asymmetry called out above will go away. `Pair` and `Product` will likely converge once that support arrives; the layering today keeps that change additive on the `Pair` side.

## Links

- [GitHub repository: swift-pair-primitives][pair-repo]
- [GitHub repository: swift-either-primitives][either-repo]
- [GitHub repository: swift-product-primitives][product-repo]
- Companion equality protocol: <doc:Introducing-Equation-Primitives>
- Companion hashing protocol: <doc:Introducing-Hash-Primitives>
- Companion comparison protocol: <doc:Introducing-Comparison-Primitives>
- [SE-0413: Typed Throws][se-0413]
- [SE-0499: Support ~Copyable, ~Escapable in simple standard library protocols][se-0499]
- [`~Escapable` cohort research][escapable-research]

[pair-repo]: https://github.com/swift-primitives/swift-pair-primitives
[either-repo]: https://github.com/swift-primitives/swift-either-primitives
[product-repo]: https://github.com/swift-primitives/swift-product-primitives
[se-0413]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md
[se-0499]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md
[escapable-research]: https://github.com/swift-institute/Research/blob/main/escapable-support-pair-either-product.md
