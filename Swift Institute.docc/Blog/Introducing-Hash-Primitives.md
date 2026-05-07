# Introducing swift-hash-primitives

@Metadata {
  @TitleHeading("Swift Institute Blog")
  @PageImage(purpose: card, source: "blog-card", alt: "Swift Institute Blog")
}

[`swift-hash-primitives`](https://github.com/swift-primitives/swift-hash-primitives) is now public on GitHub. It ships `Hash.Value` — a typed wrapper for hash output — and `Hash.Protocol`, a hashing protocol that natively supports `~Copyable` types and refines the equation primitives' equality protocol so the equals/hashCode contract is a type-level invariant.

The package is the leaf of a three-package sub-cohort. The companion posts cover <doc:Introducing-Equation-Primitives> (the equality root) and <doc:Introducing-Comparison-Primitives> (the ordering middle).

## What's new

### `Hash.Value` is a typed wrapper, not a bare `Int`

```swift
import Hash_Primitives

extension Hash {
    public typealias Value = Tagged<Hash, Int>
}
```

`Hasher.finalize()` returns an `Int`, but not every `Int` is a hash. The typed wrapper prevents accidental misuse — you can't hand a hash value to a function expecting an offset, a count, or a magic constant, and you can't hand an arbitrary integer to a function expecting a hash. The phantom `Hash` tag (the namespace itself, reused as the tag) keeps these distinct at compile time.

The wrapper is built on [`swift-tagged-primitives`](https://github.com/swift-primitives/swift-tagged-primitives); the rationale lives in [`hash-value-newtype.md`](https://github.com/swift-primitives/swift-hash-primitives/blob/main/Research/hash-value-newtype.md).

### `Hash.Protocol` for move-only types

Hashing a move-only type was — until SE-0499 lands at the floor — out of reach with the stdlib's `Hashable`, because the protocol's methods take `Self` by-value. `Hash.Protocol` mirrors `Hashable` with a `borrowing` `hash(into:)`:

```swift
struct Token: ~Copyable {
    let id: Int
}

extension Token: Hash.Protocol {
    static func == (lhs: borrowing Token, rhs: borrowing Token) -> Bool {
        lhs.id == rhs.id
    }

    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

The `==` comes from `Equation.Protocol`, which `Hash.Protocol` refines:

```swift
extension Hash {
    public protocol `Protocol`: Equation.`Protocol`, ~Copyable {
        borrowing func hash(into hasher: inout Hasher)
    }
}
```

The refinement encodes Java's longstanding equals/hashCode contract at the type level: any type that can be hashed must also support equality. The compiler enforces it. The semantic invariant — equal values must produce equal hashes — is your responsibility, but the type system stops you from declaring a hash without an equality.

### Dual-mode protocol, SE-0499 ready

[SE-0499](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md) extends `Swift.Hashable` to natively admit `~Copyable` and `~Escapable` conformers. Implemented in Swift 6.4. Until 6.4 is your floor, `Hash.Protocol` ships its own fork; from 6.4 onwards, the protocol is a typealias to `Swift.Hashable`:

```swift
#if swift(>=6.4)
    extension Hash {
        public typealias `Protocol` = Swift.Hashable
    }
#else
    extension Hash {
        public protocol `Protocol`: Equation.`Protocol`, ~Copyable {
            borrowing func hash(into hasher: inout Hasher)
        }
    }
#endif
```

Conformances written today work on both compiler families — the `borrowing` signature matches what 6.4's `Swift.Hashable` requires, and on 6.3 it matches the fork. The [cross-package research](https://github.com/swift-institute/Research/blob/main/se-0499-implications-for-equation-hash-comparison-primitives.md) walks the transition end-to-end and verifies both branches against the 6.4-dev nightly.

`Hash.Value` (the typed wrapper) is independent of the protocol question. It stays at 0.1.0 and forward, regardless of which compiler your consumer ships against.

## Getting started

Until `0.1.0` is tagged, depend on `main` directly:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-hash-primitives.git", branch: "main")
]

.target(
    name: "App",
    dependencies: [
        .product(name: "Hash Primitives", package: "swift-hash-primitives"),
    ]
)
```

Once tagged, this becomes `from: "0.1.0"`. The package is Apache 2.0 and ships four library products — `Hash Primitives` (the umbrella), `Hash Primitives Core` (the typed wrapper, protocol, and namespace without stdlib bridge), `Hash Primitives Standard Library Integration` (re-conformance of stdlib types under Swift <6.4), and `Hash Primitives Test Support`.

Conform a Swift `Hashable` type with an empty extension under Swift <6.4 — or skip the conformance entirely under Swift 6.4+, because `Hash.Protocol` IS `Swift.Hashable` there:

```swift
struct UserID: Hashable, Hash.Protocol {
    let value: UInt64
}
// no body required — Swift.Hashable's hash(into:) satisfies the requirement
```

For `~Copyable` types, write `==` and `hash(into:)` once with `borrowing` parameters and the protocol takes care of the rest.

## What's next

The companion packages — `swift-equation-primitives` (see <doc:Introducing-Equation-Primitives>, the equality root) and `swift-comparison-primitives` (see <doc:Introducing-Comparison-Primitives>, the three-way comparison) — ship alongside this one. The three packages share the dual-mode pattern, the namespace shape, and the post-SE-0499 transition path.

`Hash.Value` is a candidate for adoption as a trivial self-wrapper under `Carrier` (see <doc:Introducing-Swift-Carrier-Primitives>) — a separate cycle, no dates. That's the natural next refactor: today `Hash.Value` is a typealias on top of `Tagged`; conforming to `Carrier` would make it a first-class participant in carrier-shaped generic dispatch.
