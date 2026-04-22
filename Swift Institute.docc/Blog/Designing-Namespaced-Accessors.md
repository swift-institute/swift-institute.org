# Designing namespaced accessors in Swift

@Metadata {
  @TitleHeading("Swift Institute Blog")
  @PageImage(purpose: card, source: "blog-card", alt: "Swift Institute Blog")
}

You want to give a `Stack` type a call site that reads like this:

```swift
stack.push.back(1)
stack.push.front(0)
let top = stack.peek.back
let first = stack.pop.front()
```

Swift doesn't have namespaced method dispatch. There is no syntax for declaring that `push` is a group with `back(_:)` and `front(_:)` as members, or that `peek` is a namespace of read-only queries. The accessors on `Stack` are flat: `pushBack(_:)`, `pushFront(_:)`, `peekBack`, `peekFront` — or, with enough discipline, you stop at compound names and that's the end of it.

But flat compound names leak the grouping into the name. A third-party library that wants to add `peek.count` can't extend `peek` — because `peek` isn't a *thing*. They have to define `peekCount` and hope it doesn't collide. When you read `stack.peekFront`, you're parsing `peek` and `Front` in your head every time.

So: where does `stack.push.back(_:)` come from, and what does it take to build it?

## One accessor, one proxy

Swift's namespace mechanism is the same one every Swift developer uses every day: a type. If `push` is a type rather than a prefix, then `push.back(_:)` is just method dispatch on an instance of that type. The shape we want at the call site reads as "a property on `Stack` that returns something with a method `back(_:)` on it."

The most direct implementation:

```swift
extension Stack where Element: Copyable {
    public struct Push {
        @usableFromInline var base: Stack<Element>

        @inlinable init(_ base: consuming Stack<Element>) {
            self.base = base
        }
    }

    public var push: Push {
        _read {
            yield Push(self)
        }
        _modify {
            makeUnique()
            var proxy = Push(consume self)
            self = Stack()
            defer { self = proxy.base }
            yield &proxy
        }
    }
}

extension Stack.Push {
    public mutating func back(_ element: Element) {
        base._storage.append(element)
    }
    public mutating func front(_ element: Element) {
        base._storage.insert(element, at: 0)
    }
}
```

`Push` is a one-field struct that owns the stack while the call is in flight. The `_modify` accessor performs a five-step dance: make the storage unique, transfer the stack into the proxy, clear `self` so the proxy is the sole owner, yield, and on scope exit restore `self` from the proxy's base. That dance is what preserves copy-on-write — if the caller holds another reference to the stack, uniqueness is established before mutation begins.

This works. `stack.push.back(1)` compiles and does the right thing. The stack has one namespace, `push`, with two methods. ([V1](https://github.com/swift-institute/Experiments/tree/main/namespaced-accessors-walkthrough/Sources/V1_BespokeProxy))

## Five verbs, five nearly-identical proxies

Now add `pop`, `peek`, `forEach`, and `remove`. Each wants its own namespace. Each has to be its own type, because extensions attach to a type, and every namespace needs its own extension surface:

```swift
extension Stack where Element: Copyable {
    public struct Push    { var base: Stack<Element>; /* init */ }
    public struct Pop     { var base: Stack<Element>; /* init */ }
    public struct Peek    { var base: Stack<Element>; /* init */ }
    public struct ForEach { var base: Stack<Element>; /* init */ }
    public struct Remove  { var base: Stack<Element>; /* init */ }
}

extension Stack.Push    { public mutating func back(_ e: Element) { /* ... */ } }
extension Stack.Pop     { public mutating func front() -> Element { /* ... */ } }
extension Stack.Peek    { public var front: Element? { /* ... */ } }
extension Stack.ForEach { public func callAsFunction(_ body: (Element) -> Void) { /* ... */ } }
extension Stack.Remove  { public mutating func front() -> Element? { /* ... */ } }
```

And each gets its own accessor on `Stack`, each with its own five-step `_modify`:

```swift
public var push:    Push    { _read { ... } _modify { ... } }
public var pop:     Pop     { _read { ... } _modify { ... } }
public var peek:    Peek    { _read { ... } _modify { ... } }
public var forEach: ForEach { _read { ... } _modify { ... } }
public var remove:  Remove  { _read { ... } _modify { ... } }
```

The boilerplate explodes. Each proxy is structurally identical: one stored `base`, one initializer, one re-export of `base` so extensions can mutate it, and a conditional `Sendable` conformance when the base is `Sendable`. The only unique part of each is *its identity* — the fact that `Stack.Push` is a different type than `Stack.Pop`.

Add a sixth namespace and you write the same twelve lines of storage plumbing again. A third-party library that wants to add an `Upsert` namespace has to write its own struct from scratch, plus its own accessor property on `Stack` — which, for a type it doesn't own, means retrieving a value-typed receiver through an extension accessor that has to re-implement the same five-step dance. The structural duplication isn't just a code smell; it blocks extensibility at the source.

Something is wrong with the factoring. ([V2](https://github.com/swift-institute/Experiments/tree/main/namespaced-accessors-walkthrough/Sources/V2_FiveProxies))

## The proxies aren't about verbs, they're about tagging

Look at what's the same and what's different across the five proxies. Everything is shared *except the name of the type*. `Push` doesn't behave differently from `Pop` — it stores a base, it lets extensions mutate the base. The compile-time discrimination between them is what makes `stack.push.back(_:)` resolve to `Push.back(_:)` and not `Pop.back(_:)`. Beyond that, the two types are interchangeable.

In other words, the difference between `Push` and `Pop` is *a compile-time label*. Swift has a well-known mechanism for compile-time labels: generic type parameters. If we let one generic type carry the label, we can collapse five struct definitions into one.

## A discriminated wrapper

```swift
public struct Wrapper<Tag, Base> {
    @usableFromInline var base: Base

    @inlinable public init(_ base: consuming Base) {
        self.base = base
    }
}
```

`Wrapper<Push, Stack<Int>>` is a different type from `Wrapper<Pop, Stack<Int>>` even though they have identical storage. Swift's type system treats two specializations of a generic type as distinct types. The tags don't need to have any content at all — they just need to exist and have names:

```swift
extension Stack where Element: Copyable {
    public enum Push {}
    public enum Pop {}
    public enum Peek {}
    public enum ForEach {}
    public enum Remove {}
}
```

Each tag is a one-line empty enum. No cases. No storage. Its only job is to make the compiler pick a different specialization of `Wrapper`. In the literature this is called a *phantom type*: a type parameter that carries no runtime value, only compile-time identity.

The accessor on the base type returns `Wrapper<Push, Stack<Element>>`, and extensions attach to the specialization:

```swift
extension Stack where Element: Copyable {
    public var push: Wrapper<Push, Stack<Element>> {
        _read { yield Wrapper(self) }
        _modify {
            makeUnique()
            var proxy = Wrapper<Push, Stack<Element>>(consume self)
            self = Stack()
            defer { self = proxy.base }
            yield &proxy
        }
    }
}

extension Wrapper {
    public mutating func back<E>(_ element: E)
    where Tag == Stack<E>.Push, Base == Stack<E> {
        base._storage.append(element)
    }
}
```

The where-clause pins `Tag == Stack<E>.Push`, so this `back(_:)` method attaches only to the `push` specialization. A different where-clause — `Tag == Stack<E>.Pop` — creates a disjoint extension surface. Call sites resolve through the tag:

```swift
stack.push.back(1)  // Wrapper<Stack<Int>.Push, Stack<Int>>.back(_:)
stack.pop.front()   // Wrapper<Stack<Int>.Pop, Stack<Int>>.front()
```

The storage plumbing is written once, in `Wrapper`. Five namespaces become five empty enums plus five accessor properties plus five extension blocks. Downstream code can add a sixth namespace without ever touching `Wrapper` or `Stack`'s source: it defines its own tag, its own accessor on `Stack`, its own extensions. The extension sites compose.

([V3](https://github.com/swift-institute/Experiments/tree/main/namespaced-accessors-walkthrough/Sources/V3_Wrapper))

There is a structural note worth making before we move on. The shape `Wrapper<Tag, Base>` — a one-field wrapper parameterised by a phantom `Tag` and a value type — is structurally identical to the `Tagged<Tag, RawValue>` pattern from the identity-modelling literature. What differs is what the tag *means*. For `Tagged`, the tag is a domain: this value is a `User.ID`, not an `Order.ID` — where the phantom tag is `User` or `Order` and the raw value is, say, a `UInt64`. For `Wrapper`, the tag is an accessor namespace: this proxy is a `push`, not a `pop`. Same shape, different job.

## `~Copyable` doesn't cooperate

So far `Stack` is `Copyable`. The five-step `_modify` dance works because the stack can be transferred through the proxy by value. What happens when the base isn't `Copyable`?

Consider a fixed-capacity ring buffer backed by inline storage:

```swift
public struct Ring<Element: ~Copyable>: ~Copyable {
    // Inline, fixed-capacity storage — what makes it ~Copyable.
    // A reference-typed storage would be Copyable; inline storage cannot
    // be shared, so the container carries its full bytes through every move.
}
```

A `~Copyable` type's ownership is linear. It can be consumed, borrowed, or passed `inout`, but it can't be duplicated. You also can't transfer it into a proxy by value and then "put it back" on scope exit — "putting it back" means reassigning `self`, and the assignment operator for a `~Copyable` base has to drop the current `self` first, which isn't what we want in the middle of a scope.

The `_modify` recipe fails at the first step:

```swift
public var push: Wrapper<Push, Ring<Element>> {
    _modify {
        makeUnique()                                  // not meaningful
        var proxy = Wrapper<Push, Ring<Element>>(consume self)  // consumes self
        self = Ring()                                  // would drop — not what we want
        defer { self = proxy.base }                    // and this doesn't compile
        yield &proxy
    }
}
```

Even if we tried to cobble it together, the shape of the problem has changed. With `Copyable`, *value transfer through a proxy* is the idiom. With `~Copyable`, there's nothing to transfer — the base is right where it is, and we need the proxy to *point at it* instead of owning it. ([V4](https://github.com/swift-institute/Experiments/tree/main/namespaced-accessors-walkthrough/Sources/V4_NoncopyableFails))

## A pointer-backed variant

Swap the stored `var base: Base` for a pointer:

```swift
extension Wrapper {
    public struct View: ~Copyable, ~Escapable {
        @usableFromInline let _base: UnsafeMutablePointer<Base>

        @inlinable
        @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            self._base = base
        }

        @inlinable
        public var base: UnsafeMutablePointer<Base> { _base }
    }
}
```

`Wrapper.View` has no owned storage — it wraps an `UnsafeMutablePointer` to someone else's base. The `~Copyable, ~Escapable` declaration is load-bearing: `~Copyable` prevents a caller from duplicating the view, and `~Escapable` prevents the view from outliving the scope it was handed out from. The `@_lifetime(borrow base)` annotation tells the compiler the view borrows its pointer for the duration of that scope.

The accessor on the ring yields a view wrapping `&self`:

```swift
extension Ring where Element: ~Copyable {
    public enum Push {}

    public var push: Wrapper<Push, Ring<Element>>.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view = unsafe Wrapper<Push, Ring<Element>>.View(&self)
            yield &view
        }
    }
}
```

`mutating _read` and `mutating _modify` are coroutine accessors. The `_read` form yields the view for read-through use; `_modify` yields it by reference for calls that mutate through it. Both take `&self` as an `UnsafeMutablePointer<Ring<Element>>` to construct the view, and both bound the view's lifetime to the coroutine's scope — `begin_apply` to `end_apply` at the compiler's level. When control returns from the caller's use, the borrow ends and the pointer is gone.

Extensions attach exactly the way they did for the `Copyable` world — just on `Wrapper.View` instead of `Wrapper`:

```swift
extension Wrapper.View
where Tag == Ring<Element>.Push, Base == Ring<Element>, Element: ~Copyable {
    public mutating func back(_ element: consuming Element) {
        unsafe base.pointee._pushBack(consume element)
    }
}
```

The call site is identical:

```swift
var ring = Ring<Int>()
ring.push.back(1)  // Wrapper<Ring<Int>.Push, Ring<Int>>.View.back(_:)
```

The same `stack.push.back(_:)` shape the post opened with, now on a `~Copyable` container — without changing the pattern or teaching the caller anything new. The ownership difference is absorbed by the *type* (`Wrapper` versus `Wrapper.View`), not by the API contract the caller sees. ([V5](https://github.com/swift-institute/Experiments/tree/main/namespaced-accessors-walkthrough/Sources/V5_View))

## The shape that falls out

A small type family:

- A discriminated wrapper for `Copyable` bases — `Wrapper<Tag, Base>`.
- A pointer-backed sibling for `~Copyable` bases — `Wrapper<Tag, Base>.View`.
- Empty-enum tags as compile-time namespaces on the base type.
- Extensions constrained on the tag, attaching methods or properties to the namespace.

Both sides of the `Copyable`/`~Copyable` boundary produce the same call-site shape: `base.namespace.method(_:)`. The caller doesn't distinguish which side their value lives on; the type family absorbs the difference.

The library's name falls out of the access mechanism. Each namespace is reached through a computed *property* on the base that returns a `Wrapper<Tag, Base>` or its `.View` sibling. Call that the **Property** family: `Property<Tag, Base>` for the owned variant, `Property<Tag, Base>.View` for the pointer-backed variant. Stack and Ring both end up writing one accessor property, one empty tag enum, and one extension block per namespace. The storage plumbing is written once, in `Property`.

This is the shape `swift-property-primitives` provides. The walkthrough reached the main two variants; the library adds a handful of siblings that a first-principles post doesn't need to cover — a typed variant for when extensions need `Element` in scope for `var` properties, a read-only variant for `let`-bound call sites, and a value-generic chain for containers with compile-time-sized storage. Those are the same factoring argument applied one or two more times, along axes this post didn't need.

## Takeaway

Namespaced accessors aren't a language feature in Swift. They fall out of a design choice: route the call through a phantom-type-discriminated wrapper, and let extensions constrained on the tag carry the namespace's behaviour. Once the wrapper exists, ownership differences across the `Copyable`/`~Copyable` boundary are absorbed by two shapes of the same type family — one value-owning, one pointer-borrowing — with an identical call-site shape either way.

The walkthrough didn't start from this conclusion. It got there because every step answered a problem the previous step introduced: single proxy → more proxies → factor the tag → one wrapper → `~Copyable` breaks → pointer-backed variant. The factoring happened because the shape demanded it, not because anyone decided it upfront.

If you've ever hand-rolled a proxy struct — writing the same one-field storage, the same initializer, the same five-step `_modify` for the fifth time — `swift-property-primitives` is built for you. `Property<Tag, Base>` and its `.View` sibling are the baseline; on top sit typed, read-only, consuming, and value-generic siblings that fall out when you push the factoring further. The launch post walks the full map, the narrow import products, and a downstream consumer that adopts it.

This one covered the road that got us there.

## References

- [namespaced-accessors-walkthrough](https://github.com/swift-institute/Experiments/tree/main/namespaced-accessors-walkthrough) — runnable companion package with all five variants (V1–V5). Clone and step through each build's reasoning.
- [Property Type Family](https://github.com/swift-primitives/swift-property-primitives/blob/main/Research/property-type-family.md) — the authoritative design paper, with a full pattern taxonomy and the rationale for each variant.
- [`swift-property-primitives`](https://github.com/swift-primitives/swift-property-primitives) on GitHub — the library this post discovers.
