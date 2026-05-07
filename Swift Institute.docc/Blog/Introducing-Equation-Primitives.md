# Introducing swift-equation-primitives

@Metadata {
  @TitleHeading("Swift Institute Blog")
  @PageImage(purpose: card, source: "blog-card", alt: "Swift Institute Blog")
}

[`swift-equation-primitives`](https://github.com/swift-primitives/swift-equation-primitives) is now public on GitHub. It ships `Equation.Protocol` — an equality protocol that natively supports `~Copyable` types — and the namespace under which the matching hash and comparison primitives compose.

The package is the root of a three-package sub-cohort: [`swift-equation-primitives`](https://github.com/swift-primitives/swift-equation-primitives), [`swift-comparison-primitives`](https://github.com/swift-primitives/swift-comparison-primitives), and [`swift-hash-primitives`](https://github.com/swift-primitives/swift-hash-primitives) — each shipping a stdlib-mirror protocol that admits move-only types and a small value-type surface that is independent of the protocol question. This post covers the root.

## What's new

`Equation.Protocol` is a one-method protocol with `borrowing` parameters, declared on the `Equation` namespace:

```swift
import Equation_Primitives

extension Equation {
    public protocol `Protocol`: ~Copyable {
        static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
    }
}
```

The protocol does one thing: it lets you compare two values for equality without copying either. That matters for move-only types — file descriptors, owned buffers, exclusive resources — where copying is forbidden and the stdlib's `Equatable` (until recently) could not reach.

A move-only token type conforms in two lines:

```swift
struct Token: ~Copyable {
    let id: Int
}

extension Token: Equation.Protocol {
    static func == (lhs: borrowing Token, rhs: borrowing Token) -> Bool {
        lhs.id == rhs.id
    }
}
```

The default `!=` comes from the protocol — you write `==`, you get `!=` for free.

## SE-0499 lands underneath

[SE-0499](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md) extends `Swift.Equatable`, `Swift.Hashable`, and `Swift.Comparable` to natively admit `~Copyable` and `~Escapable` conformers. The proposal is implemented in Swift 6.4. Once 6.4 is your floor, the stdlib protocols cover the case directly — no fork needed.

`Equation.Protocol` is built so the transition is invisible. Under Swift <6.4, you get the package's own protocol fork. Under Swift 6.4+, the protocol is a typealias to `Swift.Equatable`:

```swift
#if swift(>=6.4)
    extension Equation {
        public typealias `Protocol` = Swift.Equatable
    }
#else
    extension Equation {
        public protocol `Protocol`: ~Copyable {
            static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
        }
    }
#endif
```

Both branches build clean. Conforming types written today work on both compiler families — the `borrowing` signature matches what 6.4's `Swift.Equatable` requires, and on 6.3 it matches the fork. The [cross-package research](https://github.com/swift-institute/Research/blob/main/se-0499-implications-for-equation-hash-comparison-primitives.md) walks the transition end-to-end and verifies both branches against the 6.4-dev nightly.

The endgame, once the ecosystem's minimum Swift version reaches 6.4, is to retire the `Equation` namespace entirely and use `Swift.Equatable` directly. The 0.1.0 tag ships the dual-mode bridge so consumers can adopt now without committing to that endgame timeline.

## Getting started

Until `0.1.0` is tagged, depend on `main` directly:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-equation-primitives.git", branch: "main")
]

.target(
    name: "App",
    dependencies: [
        .product(name: "Equation Primitives", package: "swift-equation-primitives"),
    ]
)
```

Once tagged, this becomes `from: "0.1.0"`. The package is Apache 2.0 and ships three library products — `Equation Primitives` (the umbrella; what most consumers want), `Equation Primitives Core` (protocol + namespace, no stdlib bridge), and `Equation Primitives Standard Library Integration` (re-conformance of `[Int]`, `[String]`, `Optional`, `Range`, and other stdlib types under Swift <6.4).

Conform a Swift `Equatable` type to `Equation.Protocol` with an empty extension — the `==` already exists:

```swift
struct UserID: Equatable, Equation.Protocol {
    let value: UInt64
}
// no body required — Swift.Equatable's `==` satisfies the requirement
```

For `~Copyable` types, write `==` once with `borrowing` parameters and the protocol takes care of the rest.

## What's next

`swift-comparison-primitives` (see <doc:Introducing-Comparison-Primitives>) and `swift-hash-primitives` (see <doc:Introducing-Hash-Primitives>) ship alongside this package. They share the dual-mode pattern and the namespace shape. `Comparison.Protocol` refines `Equation.Protocol` (matching Swift's `Comparable: Equatable`); `Hash.Protocol` refines `Equation.Protocol` (encoding the equals/hashCode contract at the type level — equal values must hash equal).

Beyond 0.1.0, the package's surface is intentionally small. The most likely future change is the retirement that SE-0499 enables — a separate cycle once the ecosystem moves to Swift 6.4 minimum.
