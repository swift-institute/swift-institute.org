# Can Swift wrappers share one protocol?

@Metadata {
  @TitleHeading("Swift Institute Blog")
  @PageImage(purpose: card, source: "blog-card", alt: "Swift Institute Blog")
}

You reach for phantom-typed wrappers often enough: `User.ID` over `UInt64` to keep identifiers distinguished at the type level, `File.Handle` over `File.Descriptor` to keep resource ownership explicit, `Buffer.View` over a borrowed `Span` to bound a reference to its scope. Three wrappers, three reasons, one structural recipe — one private field, one initializer, one accessor. You'd expect generic code to abstract across them. So what protocol does?

The answer sits where Swift's ownership story meets its phantom-type story. The ordinary wrapper protocol works in the `Copyable & Escapable` quadrant, then breaks as soon as either default is suppressed. Following those breaks gives the shape a common protocol would need, including the fourth quadrant where move-only ownership and scoped lifetime combine.

## Q1 — Copyable wrapper, Copyable underlying

The ordinary case. `User.ID` is a nested struct over `UInt64`. `Order.ID` is a different nested struct over the same `UInt64`. At the type level they're distinguished by which namespace they nest under; at the value level the storage and the construction are identical.

```swift
extension User {
    struct ID {
        var _storage: UInt64

        init(_ underlying: consuming UInt64) {
            self._storage = underlying
        }
    }
}

extension User.ID {
    var underlying: UInt64 { _storage }
}
```

`consuming UInt64` is a no-op at runtime for a trivial type; the annotation matches the protocol requirement that follows. A local protocol captures the shape:

```swift
protocol Wrapper {
    associatedtype Underlying
    var underlying: Underlying { get }
    init(_ underlying: Underlying)
}
```

Conform `User.ID` and `Order.ID` to `Wrapper`, and generic code writes a function over both at once:

```swift
func describe<W: Wrapper>(_ w: W) -> String where W.Underlying == UInt64 {
    "wrapper over UInt64 holding \(w.underlying)"
}

describe(User.ID(42))
describe(Order.ID(100))
```

That works for every `Copyable & Escapable` underlying. But `Wrapper` carries two hidden assumptions about copying, and both break as soon as the underlying leaves Q1.

## Q2 — `~Copyable` underlying

`File.Descriptor` is a move-only resource. A file descriptor maps to an OS-level handle that has to be closed exactly once, and the type system enforces the "exactly once" by suppressing `Copyable`:

```swift
enum File {}

extension File {
    struct Descriptor: ~Copyable {
        var raw: Int32
    }
}
```

`File.Handle` wraps a descriptor to hang higher-level operations off. The handle has to be `~Copyable` too, because a copy of the handle would imply a copy of the descriptor, and `~Copyable` forbids the copy:

```swift
extension File {
    struct Handle: ~Copyable {
        var _storage: File.Descriptor

        init(_ underlying: consuming File.Descriptor) {
            self._storage = underlying
        }
    }
}
```

Conforming `File.Handle` to the `Wrapper` declared in Q1 fails on two axes:

```swift
extension File.Handle: Wrapper {
    typealias Underlying = File.Descriptor
    var underlying: File.Descriptor { _storage }       // ✗
    init(_ underlying: File.Descriptor) {              // ✗
        self._storage = underlying
    }
}
```

This example is cautionary, not prescriptive: it shows the point where the Q1 protocol gives way. The accessor fails because a by-value read would copy `_storage`, and `~Copyable` forbids the copy. The initializer fails because an unannotated parameter is passed under the copyable convention. The protocol has no place to express *borrow on the way out* or *consume on the way in*.

The repair is on the protocol, not the conformer. A getter that *borrows* and an init that *consumes* is the shape `~Copyable` wants:

```swift
protocol Wrapper: ~Copyable {
    associatedtype Underlying: ~Copyable
    var underlying: Underlying { borrowing get }
    init(_ underlying: consuming Underlying)
}
```

Three changes. `Self: ~Copyable` suppresses the default `Copyable` on conformers. `Underlying: ~Copyable` does the same on the associated type. `borrowing get` yields the underlying by borrow instead of copying, and `consuming Underlying` transfers ownership from the caller instead of copying. With those, `File.Handle` conforms — the accessor uses `_read { yield _storage }` to yield the stored `~Copyable` value without copying it out:

```swift
extension File.Handle: Wrapper {
    typealias Underlying = File.Descriptor
    var underlying: File.Descriptor {
        _read { yield _storage }
    }
}
```

`_read` is the coroutine form of a borrowing getter — it yields the stored value by reference, the caller uses it for the duration of the yield, and the yield returns without consuming. Plain `borrowing get { _storage }` fails here because `_storage` can't be implicitly copied out of the body.

`User.ID` still conforms to the revised `Wrapper` — a `Copyable` conformer satisfies a `~Copyable` suppression trivially. The Q2 protocol covers Q1 as a degenerate case, and a generic function over `some Wrapper` now accepts bare `User.ID`, bare `Order.ID`, and `File.Handle` in the same signature. ([V5b](https://github.com/swift-primitives/swift-carrier-primitives/tree/main/Experiments/capability-lift-pattern) probes this shape in isolation on Swift 6.3.1; the repository's [*Round-trip semantics for `~Copyable` Underlyings*](https://github.com/swift-primitives/swift-carrier-primitives/blob/main/Research/round-trip-semantics-noncopyable-underlyings.md) documents the one surviving asymmetry — that `C(c.underlying)` does not compile when `Underlying` is `~Copyable`, because the borrow returned from `.underlying` can't be fed back into a `consuming` parameter.)

## Q3 — `~Escapable` underlying

`Span<Element>` is scoped. It points into a region of memory owned elsewhere, and it's valid only for the scope that handed it out. The type system enforces the scope bound by suppressing `Escapable`:

```swift
struct Span<Element>: ~Escapable, Copyable { /* stdlib */ }
```

A wrapper around a `Span` — `Buffer.View<Element>`, attaching higher-level operations to a borrowed region — has to be `~Escapable` too, because the wrapper can't outlive the span it holds:

```swift
enum Buffer {}

extension Buffer {
    struct View<Element>: ~Escapable {
        var _storage: Span<Element>

        @_lifetime(copy underlying)
        init(_ underlying: consuming Span<Element>) {
            self._storage = underlying
        }
    }
}
```

`@_lifetime(copy underlying)` is load-bearing. It tells the compiler that the initialized `Buffer.View` inherits the lifetime of the `underlying` parameter — the view is valid only as long as the span it wraps is. Without this annotation the compiler has no way to assign a lifetime to the `~Escapable` result, and rejects the declaration.

The getter needs a matching annotation:

```swift
extension Buffer.View {
    var underlying: Span<Element> {
        @_lifetime(borrow self)
        borrowing get { _storage }
    }
}
```

`@_lifetime(borrow self)` tells the compiler that the returned span is valid as long as the view is borrowed. Without it, there's no way to bound the lifetime of the `~Escapable` return.

The protocol from Q2 still doesn't fit — the conformer's annotations aren't something a Q2 protocol requirement covers. Promote the annotations to the protocol, and they become mandatory everywhere the protocol's requirement is read:

```swift
protocol Wrapper: ~Copyable, ~Escapable {
    associatedtype Underlying: ~Copyable & ~Escapable
    var underlying: Underlying {
        @_lifetime(borrow self)
        borrowing get
    }
    @_lifetime(copy underlying)
    init(_ underlying: consuming Underlying)
}
```

`~Escapable` suppression on `Self`, on `Underlying`, `@_lifetime(borrow self)` on the getter requirement, `@_lifetime(copy underlying)` on the init requirement. Q1's `User.ID` still conforms — a `Copyable & Escapable` conformer satisfies all suppressions trivially — but the protocol carries annotations the Q1 conformer itself doesn't write. Swift accepts this split because the annotations are rejected at *concrete* sites when `Underlying` is `Escapable` (you can't annotate the lifetime of an `Escapable` result), while they're required on the protocol so the `~Escapable` cases have somewhere to attach. The important split: the protocol requirement carries the lifetime contract, and concrete conformances only write the annotations in the quadrants where the result is actually non-escapable.

## Q4 — Both suppressions

`Ownership.Inout<Base>` is a move-only scoped reference — `~Copyable` because it's exclusive, `~Escapable` because it borrows its target. A wrapper around one combines everything Q2 and Q3 demanded:

```swift
extension Buffer {
    struct Scope<Base: ~Copyable>: ~Copyable, ~Escapable {
        var _storage: Ownership.Inout<Base>

        @_lifetime(copy underlying)
        init(_ underlying: consuming Ownership.Inout<Base>) {
            self._storage = underlying
        }
    }
}

extension Buffer.Scope: Wrapper where Base: ~Copyable {
    typealias Underlying = Ownership.Inout<Base>
    var underlying: Ownership.Inout<Base> {
        @_lifetime(borrow self)
        _read { yield _storage }
    }
}
```

`_read { yield }` from Q2, `@_lifetime` annotations from Q3, both suppressions on the wrapper and the underlying. The protocol from Q3 fits without change.

This quadrant isn't a new protocol problem. It's where Q2's repair and Q3's repair hold at once: the accessor yields storage by borrow because the value is move-only, and the lifetime annotations bind the result because the value is scoped. The protocol from Q3 already required both; Q4 exercises both requirements on the same conformer.

That's the shape across the grid. One protocol, four quadrants, no recompilation of requirements per quadrant. Conformers in Q1 skip the annotations because Swift rejects them on `Escapable` results. Conformers in Q2 use `_read` instead of `borrowing get` because a by-value getter can't be used for `~Copyable`. Conformers in Q3 keep the annotations and use plain `borrowing get`. Conformers in Q4 use `_read` and keep the annotations. ([The shipped Conformance Recipes article](https://github.com/swift-primitives/swift-carrier-primitives/blob/main/Sources/Carrier%20Primitives/Carrier%20Primitives.docc/Conformance-Recipes.md) walks each quadrant with a canonical stub and has test coverage for each.)

## Why the stdlib and the obvious alternatives don't cover it

Three alternatives suggest themselves before writing a new protocol. Each fits somewhere; none spans the grid.

### `RawRepresentable`

The stdlib's take on value-wrapping:

```swift
public protocol RawRepresentable {
    associatedtype RawValue
    init?(rawValue: RawValue)
    var rawValue: RawValue { get }
}
```

One associated type, one accessor, one init. Structurally it's the Q1 `Wrapper` plus a fallibility bit. It can't cross into Q2, Q3, or Q4 for three independent reasons.

First, `RawValue` is implicitly `Copyable & Escapable`. `RawRepresentable` predates [SE-0390][se-0390] (`~Copyable` types) and [SE-0446][se-0446] (`~Escapable` types). Retrofitting `RawValue: ~Copyable` would break every stdlib integration — `Codable` auto-synthesis for raw-valued enums, `OptionSet`'s bitmask arithmetic, derived `Hashable` and `Comparable` — each of those assumes a `Copyable` `RawValue`. The ABI freezes the shape. A `Tagged`-style wrapper with a `~Copyable` `RawValue` cannot satisfy `RawRepresentable`.

Second, `rawValue: RawValue { get }` is a by-value read — the same Q1 assumption that broke on `File.Handle`. Borrowing access is not available through `RawRepresentable`'s requirement.

Third, `init?(rawValue:)` bakes fallibility into the abstraction, while the structural wrapper recipe needs non-failable reconstruction from an already-valid underlying value. For enums (`Color(rawValue: 7)` rejects 7 when the enum has no case for it), fallibility is load-bearing. A wrapper conformer that always returns `.some` satisfies the signature but not the intent.

`RawRepresentable` covers Q1, with caveats even there — no phantom discriminator, fallibility that doesn't apply, Foundation-era integration assumptions. The caveats turn into hard blocks outside Q1. The full nine-dimension comparison lives in [`carrier-vs-rawrepresentable-comparative-analysis.md`](https://github.com/swift-primitives/swift-carrier-primitives/blob/main/Research/carrier-vs-rawrepresentable-comparative-analysis.md).

### Per-type protocols

Drop the cross-wrapper ambition and give each value type its own capability protocol:

```swift
extension Cardinal {
    protocol `Protocol` {
        associatedtype Domain: ~Copyable = Never
        var cardinal: Cardinal { get }
        init(_ cardinal: Cardinal)
    }
}

extension Cardinal: Cardinal.`Protocol` { /* self-conformance */ }

extension Tagged: Cardinal.`Protocol`
where RawValue == Cardinal, Tag: ~Copyable {
    // ... forward cardinal + init through rawValue
}
```

`Cardinal.\`Protocol\`` abstracts across bare `Cardinal` and any `Tagged<Tag, Cardinal>`. That works. Write one for `Ordinal`, another for `Hash.Value`, another for every wrapped type you care about, and each one works — for its one type. Every Layer-1 value type gets its own per-type protocol, its own accessor name (`cardinal`, `ordinal`, `hash`, `descriptor`, `span`), its own Tagged-forwarding extension. Two extensions per value type, one protocol per value type, N of everything at N value types. Each protocol can express its local domain, but none gives generic code one spelling for "a wrapper over this underlying value."

There's also no protocol that spans the per-type protocols, so a function that takes "any wrapper of any type" — a reflective diagnostic, a cross-type conversion, a witness-based serializer — can't be written. Each per-type protocol is its own island, and generic dispatch stops at the island boundary. ([V0 and V1 of the capability-lift experiment](https://github.com/swift-primitives/swift-carrier-primitives/tree/main/Experiments/capability-lift-pattern) exercise this shape on Cardinal and Ordinal stubs and confirm the two per-type protocols conform independently but share no cross-dispatch surface.)

### Existentials

Last move: erase the underlying entirely. Declare a protocol with no associated types and use `any` at API sites:

```swift
protocol AnyWrapper { /* no associatedtype */ }

func describe(_ w: any AnyWrapper) -> String { /* ... */ }
```

`describe` now accepts any wrapper — but it has nothing to say about the underlying, because the underlying is erased. The phantom-typed discrimination is also gone: `User.ID` and `Order.ID` are indistinguishable under `any AnyWrapper`, and inside the function there is no way to recover that one belongs to `User` and the other to `Order`.

Existentials of parameterized protocols (`any Wrapper<UInt64>`, per [SE-0353][se-0353]) recover the underlying at the signature level, but existential values still lose type-level access to associated types — so phantom discrimination at the generic level is unavailable. `any Wrapper<UInt64>` can preserve the underlying constraint, but it erases the concrete wrapper type. That's the wrong tool when the operation must return the same wrapper family it received. ([V5c in the capability-lift experiment](https://github.com/swift-primitives/swift-carrier-primitives/tree/main/Experiments/capability-lift-pattern) confirms `any Wrapper` erases `Underlying` to `Any`.)

## The shape that has to exist

The walk through the four quadrants produced this protocol:

```swift
protocol Wrapper: ~Copyable, ~Escapable {
    associatedtype Underlying: ~Copyable & ~Escapable
    var underlying: Underlying {
        @_lifetime(borrow self)
        borrowing get
    }
    @_lifetime(copy underlying)
    init(_ underlying: consuming Underlying)
}
```

That covers the four quadrants. The walk hasn't yet accounted for the phantom dimension — the reason `User.ID` and `Order.ID` are distinct types in the first place.

Add a second associated type — a phantom discriminator — and mark `Underlying` as the primary associated type so `some Wrapper<UInt64>` can be written at call sites per [SE-0346][se-0346]:

```swift
protocol Wrapper<Underlying>: ~Copyable, ~Escapable {
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

`Domain` defaults to `Never` so bare value types that wrap themselves — `Int` as its own `Underlying`, `Cardinal` as its own `Underlying` — skip the typealias and get the trivial semantics for free. Phantom-tagged wrappers like `User.ID` bind `Domain = User`; `Order.ID` binds `Domain = Order`. Generic code over `some Wrapper` reflects on `C.Domain` to tell them apart at the type level, without any runtime overhead.

That's the spec. Two suppressions on `Self`, two suppressions on `Underlying`, a borrowing getter with `@_lifetime(borrow self)`, a consuming init with `@_lifetime(copy underlying)`, a primary `Underlying` associated type, a phantom `Domain` that defaults to `Never`. Swift 6.3.1 ships every language feature the shape requires — [SE-0346][se-0346] for the primary associated type, [SE-0427][se-0427] for `~Copyable` generics, [SE-0446][se-0446] for `~Escapable` and `@_lifetime`, [SE-0506][se-0506] for `~Copyable` associated types.

The language now has the pieces for that shape. The stdlib does not provide the protocol.

## What's next

The follow-up post introduces the library that does: one protocol for the wrapper recipe, four conformance recipes for the quadrant grid, and generic dispatch that preserves the concrete wrapper family. [Read the next post.][launch]

## References

- Experiment: [`swift-carrier-primitives/Experiments/capability-lift-pattern`](https://github.com/swift-primitives/swift-carrier-primitives/tree/main/Experiments/capability-lift-pattern) — six variants V0–V5 probing per-type, super-protocol, and limit cases on Swift 6.3.1. Result: CONFIRMED.
- Research: [*Capability-lift pattern*](https://github.com/swift-primitives/swift-carrier-primitives/blob/main/Research/capability-lift-pattern.md) — recipe analysis, v1.1.0, RECOMMENDATION.
- Research: [*Carrier vs RawRepresentable — comparative analysis*](https://github.com/swift-primitives/swift-carrier-primitives/blob/main/Research/carrier-vs-rawrepresentable-comparative-analysis.md) — nine-dimension comparison backing the §*`RawRepresentable`* breakdown.
- Research: [*Round-trip semantics for `~Copyable` Underlyings*](https://github.com/swift-primitives/swift-carrier-primitives/blob/main/Research/round-trip-semantics-noncopyable-underlyings.md) — the semantic weakening noted under Q2.
- [SE-0346: Lightweight same-type requirements for primary associated types][se-0346] — enables `some Wrapper<Underlying>`.
- [SE-0390: Noncopyable structs and enums][se-0390] — introduces `~Copyable` types.
- [SE-0427: Noncopyable generics][se-0427] — `~Copyable` on generic parameters and on `Self`.
- [SE-0446: Nonescapable types][se-0446] — `~Escapable` and `@_lifetime` annotations.
- [SE-0506: Noncopyable associated types][se-0506] — `~Copyable` on associated types.
- [SE-0353: Constrained existential types][se-0353] — relevant to the §*Existentials* discussion.

[se-0346]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md
[se-0390]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md
[se-0427]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md
[se-0446]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md
[se-0506]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0506-noncopyable-associated-types.md
[se-0353]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0353-constrained-existential-types.md
[launch]: https://swift-institute.org/documentation/swift-institute/introducing-swift-carrier-primitives
