# Introducing swift-carrier-primitives

@Metadata {
  @TitleHeading("Swift Institute Blog")
  @PageImage(purpose: card, source: "blog-card", alt: "Swift Institute Blog")
}

`swift-carrier-primitives` is now public on GitHub. It ships `Carrier<Underlying>`, a parameterized super-protocol for phantom-typed value wrappers.

The companion post <doc:Common-Wrapper-Protocol> develops the design problem: Swift wrappers can sit in any quadrant of the `Copyable × Escapable` grid, but the stdlib does not provide one protocol spanning that shape. This package provides that protocol.

The package contains the protocol, a default extension for trivial self-wrappers, and a companion target with 28 stdlib primitive conformances — including the four `~Escapable` span types (`Span`, `MutableSpan`, `RawSpan`, `MutableRawSpan`). It has zero external dependencies, imports no Foundation module, and requires Swift 6.3.1.

## Highlights

### One protocol, four quadrants

`Carrier<Underlying>` suppresses `Copyable` and `Escapable` on `Self`, on `Domain`, and on `Underlying`. The suppressions compose: the same protocol admits a wrapper over a plain `Int`, a wrapper over a `~Copyable` file descriptor, a wrapper over an `~Escapable` span, and a wrapper over a `~Copyable & ~Escapable` scoped reference — in a single declaration.

```swift
public protocol Carrier<Underlying>: ~Copyable, ~Escapable {
    associatedtype Domain: ~Copyable & ~Escapable = Never
    associatedtype Underlying: ~Copyable & ~Escapable

    var underlying: Underlying {
        @_lifetime(borrow self)
        borrowing get
    }

    @_lifetime(copy underlying)
    init(_ underlying: consuming Underlying)
}
```

The source is [`Carrier.swift`](https://github.com/swift-primitives/swift-carrier-primitives/blob/main/Sources/Carrier%20Primitives/Carrier.swift) on `main`. Four conformance shapes fall out of the grid, one per quadrant, each with slightly different concrete spellings — Q1 for `Copyable & Escapable` underlyings like `User.ID` over `UInt64`, Q2 for `~Copyable` underlyings like `File.Handle` over `File.Descriptor`, Q3 for `~Escapable` underlyings like `Buffer.View` over `Span`, and Q4 for the combined case like `Buffer.Scope` over `Ownership.Inout`. The [Conformance Recipes][conformance-recipes] article walks each variant.

### Trivial self-wrappers conform in one line

Bare value types that are their own `Underlying` conform in a single `typealias Underlying = Self` line. The protocol's default extension provides the accessor and the init:

```swift
extension Carrier where Underlying == Self {
    public var underlying: Self {
        _read { yield self }
    }

    public init(_ underlying: consuming Self) {
        self = underlying
    }
}
```

The Standard Library Integration target uses the default to conform 28 stdlib types in one line each:

```swift
extension Int: Carrier { public typealias Underlying = Int }
extension String: Carrier { public typealias Underlying = String }
extension Bool: Carrier { public typealias Underlying = Bool }
// ... 25 more, including the ~Escapable span family
```

The companion target applies the same pattern to 28 stdlib primitive types: every fixed-size integer, `Float`, `Float16`, `Double`, `Bool`, `String`, `Substring`, `Character`, `Unicode.Scalar`, `StaticString`, `Duration`, `ObjectIdentifier`, `Never`, and the four `~Escapable` span types (`Span`, `MutableSpan`, `RawSpan`, `MutableRawSpan`) via the Q3 default extension.

### Generic dispatch preserves the wrapper family

Per [SE-0346][se-0346], marking `Underlying` as the primary associated type (via the `Carrier<Underlying>` angle-bracket syntax) lets generic functions constrain the wrapped type directly without naming an intermediary per-type protocol. In the ordinary `Copyable & Escapable` case, this gives a generic function that constrains the underlying value and returns the same wrapper family:

```swift
func incremented<C: Carrier<Int>>(_ c: C) -> C {
    C(c.underlying + 1)
}
```

The important part is the return type. `C` remains `C`, so a `User`-tagged carrier returns as a `User`-tagged carrier, not as a bare `Int` or an `Order`-tagged carrier. The full-grid spelling adds the ownership and lifetime suppressions:

```swift
func incremented<C: Carrier<Int> & ~Copyable & ~Escapable>(
    _ c: borrowing C
) -> ...
```

The [Conformance Recipes][conformance-recipes] article walks the per-quadrant variants.

## Getting started

Until `0.1.0` is tagged, depend on `main` directly:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-carrier-primitives.git", branch: "main")
]

.target(
    name: "App",
    dependencies: [
        .product(name: "Carrier Primitives", package: "swift-carrier-primitives"),
    ]
)
```

Once the cohort tags, this becomes `from: "0.1.0"`. Use `Carrier Primitives` for the protocol alone. Use `Carrier Primitives Standard Library Integration` when you want bare stdlib values to conform too.

### Authoring a phantom-typed wrapper

Nest the wrapper under the domain type and conform it in a standalone extension. The `Domain` reuses the existing type as a compile-time tag — no empty `enum UserTag {}` required:

```swift
import Carrier_Primitives

struct User {
    var name: String
    var email: String
}

extension User {
    struct ID {
        var _storage: UInt64

        init(_ underlying: consuming UInt64) {
            self._storage = underlying
        }
    }
}

extension User.ID: Carrier {
    typealias Domain = User
    typealias Underlying = UInt64

    var underlying: UInt64 {
        borrowing get { _storage }
    }
}
```

`Order.ID` follows the same recipe, nested under its own domain:

```swift
struct Order {
    var items: [String]
}

extension Order {
    struct ID {
        var _storage: UInt64

        init(_ underlying: consuming UInt64) {
            self._storage = underlying
        }
    }
}

extension Order.ID: Carrier {
    typealias Domain = Order
    typealias Underlying = UInt64

    var underlying: UInt64 {
        borrowing get { _storage }
    }
}
```

`User.ID` and `Order.ID` both wrap `UInt64`, but their phantom `Domain` keeps them type-distinct. A generic function over `some Carrier<UInt64>` accepts either, and the `Domain` is preserved at the signature level:

```swift
func describe<C: Carrier<UInt64> & ~Copyable & ~Escapable>(
    id: borrowing C
) -> String {
    "Carrier<UInt64> in domain \(C.Domain.self) holding \(id.underlying)"
}

print(describe(id: User.ID(42)))    // Carrier<UInt64> in domain User holding 42
print(describe(id: Order.ID(100)))  // Carrier<UInt64> in domain Order holding 100
```

The seven-step [Getting Started tutorial][tutorial] walks this example from empty package to working generic dispatch. The [Conformance Recipes][conformance-recipes] article covers the three other quadrants — move-only resources, scoped views, and the combined case — each with a template extension you copy and adjust.

One note on round-trip semantics for `~Copyable` underlyings: reading `.underlying` and reconstructing via `C(.underlying)` works cleanly for `Copyable` underlyings, but weakens for `~Copyable` ones — the borrow returned by `.underlying` cannot be consumed back into `init(_:)`. The round-trip becomes *inspect via borrow, reconstruct with a fresh consumed value* rather than *extract and rewrap identically*. That follows from Swift's linear ownership model; it's not a defect in the protocol shape. The [Round-trip Semantics][round-trip] DocC article documents the detail.

## What's next

`swift-tagged-primitives` is the planned first downstream adopter. Conforming `Tagged<Tag, V>` to `Carrier` where `V` conforms would give every `Tagged<Tag, V>` a carrier conformance for free — the parametric extension covers the full family of tagged specializations in one declaration, without per-type forwarding.

`swift-cardinal-primitives`, `swift-ordinal-primitives`, and `swift-hash-primitives` are candidates for adoption as trivial self-wrappers. Each currently carries local protocols for a wrapper shape this package can now express centrally. Adopting Carrier would turn those per-type protocols into constrained extensions rather than standalone refinements, and would unlock cross-type generic dispatch without disturbing the per-type API. No dates.

Beyond the primitives layer, any package that wraps a value with a phantom tag — identity types, index types, resource handles, scoped references — can conform in the shape the [Conformance Recipes][conformance-recipes] article walks, and downstream API sites can constrain on `some Carrier<X>` to accept the bare value and its wrappers together.

## What this package is not

`Carrier<Underlying>` and Swift's `RawRepresentable` are non-substitutable protocols in different design spaces. `RawRepresentable` has a failable init, assumes `Copyable & Escapable` `RawValue`, and is the substrate for stdlib integrations (Codable auto-synthesis, OptionSet arithmetic, derived Hashable/Comparable/Equatable) that `Carrier` intentionally does not replicate. `Carrier` admits `~Copyable` and `~Escapable` on every axis, has a primary associated type per SE-0346, and carries a second associated type for phantom discrimination. Neither protocol subsumes or refines the other. The [Carrier vs RawRepresentable][carrier-vs-raw] DocC article has the decision tree.

The package is also not a replacement for per-type capability protocols like `Cardinal.\`Protocol\``. Those continue to serve domain-specific arithmetic APIs. `Carrier` is the super-abstraction under which per-type protocols can compose when they choose to, not a mandate for migration.

## Links

- [Documentation (DocC)][docc]
- [GitHub repository][repo]
- [Swift Package Index][spi]
- [Getting Started tutorial][tutorial]
- [Conformance Recipes article][conformance-recipes]
- [Understanding Carriers article][understanding]
- [Carrier vs RawRepresentable article][carrier-vs-raw]
- [Round-trip Semantics article][round-trip]
- Precursor post: <doc:Common-Wrapper-Protocol>

[docc]: https://swiftpackageindex.com/swift-primitives/swift-carrier-primitives/documentation/carrier_primitives
[repo]: https://github.com/swift-primitives/swift-carrier-primitives
[spi]: https://swiftpackageindex.com/swift-primitives/swift-carrier-primitives
[tutorial]: https://swiftpackageindex.com/swift-primitives/swift-carrier-primitives/tutorials/carrier-primitives/gettingstarted
[conformance-recipes]: https://github.com/swift-primitives/swift-carrier-primitives/blob/main/Sources/Carrier%20Primitives/Carrier%20Primitives.docc/Conformance-Recipes.md
[understanding]: https://github.com/swift-primitives/swift-carrier-primitives/blob/main/Sources/Carrier%20Primitives/Carrier%20Primitives.docc/Understanding-Carriers.md
[carrier-vs-raw]: https://github.com/swift-primitives/swift-carrier-primitives/blob/main/Sources/Carrier%20Primitives/Carrier%20Primitives.docc/Carrier-vs-RawRepresentable.md
[round-trip]: https://github.com/swift-primitives/swift-carrier-primitives/blob/main/Sources/Carrier%20Primitives/Carrier%20Primitives.docc/Round-trip-Semantics.md
[se-0346]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md
