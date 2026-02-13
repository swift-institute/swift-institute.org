---
name: existing-infrastructure
description: |
  Complete catalog of reusable typed infrastructure across swift-primitives (tiers 0–15).
  ALWAYS consult before writing new operators, overloads, accessors, or manual arithmetic.
  The infrastructure you need likely already exists — the fix is usually an import, not new code.

layer: implementation

requires:
  - swift-institute
  - implementation
  - conversions

applies_to:
  - swift-primitives
  - swift-standards
  - swift-foundations
---

# Existing Infrastructure

Before writing ANY implementation code, consult this catalog. The typed infrastructure you need likely already exists. Common symptoms of missing infrastructure awareness:

- Writing `Int(bitPattern:)` at call sites → stdlib integration overload exists
- Extracting `.rawValue.rawValue` chains → `.map()` or `.retag()` exists
- Writing `while` loops at call sites → `.forEach` / `.reduce` iteration exists
- Hand-rolling pointer arithmetic → `pointer(at:)` exists
- Implementing accessor structs → `Property<Tag, Base>` / `Property.View` exists
- Writing `count - 1` → `.subtract.saturating(.one)` exists (no `-` operator — principled)
- Using `Swift.min()` with rawValue → `Type.min(a, b)` exists on `Tagged`

---

## Protocol Lifting — How Operations Propagate

### [INFRA-100] Cardinal.Protocol and Ordinal.Protocol

**Statement**: Operations defined on `Cardinal.Protocol` or `Ordinal.Protocol` automatically work on ALL `Tagged<Tag, Cardinal>` and `Tagged<Tag, Ordinal>` types. You do NOT need to add operators to specific tagged types — the protocol conformance lifts them.

| Protocol | Conformers | Effect |
|----------|-----------|--------|
| `Cardinal.Protocol` | `Cardinal`, `Tagged<T, Cardinal>` for all `T: ~Copyable` | `.zero`, `.one`, `+`, `+=`, `.subtract` all work on `Index<T>.Count`, `Memory.Address.Count`, etc. |
| `Ordinal.Protocol` | `Ordinal`, `Tagged<T, Ordinal>` for all `T: ~Copyable` | `.successor`, `.predecessor`, `.advance`, `.retreat`, `.distance`, `+`, `+=` all work on `Index<T>`, `Memory.Address`, etc. |

**Common mistake**: Proposing a new `+` operator on `Index<Element>.Count`. It already exists because `Tagged<Element, Cardinal>` conforms to `Cardinal.Protocol`, which provides `+`.

**Common mistake**: Proposing `.successor` on `Index<Element>`. It already exists because `Tagged<Element, Ordinal>` conforms to `Ordinal.Protocol`, which provides `.successor`.

**The rule**: If the operation applies to `Cardinal` or `Ordinal` as concepts, define it on the protocol. All tagged forms inherit it automatically.

---

## I Need to Count — Cardinal Infrastructure

### [INFRA-101] Cardinal Quantities

**Package**: `Cardinal Primitives Core` (tier 3)

**Statement**: All quantities (counts, sizes, capacities) use `Cardinal` or `Tagged<T, Cardinal>`. Never bare `UInt` or `Int` at call sites.

| Operation | Signature | Notes |
|-----------|-----------|-------|
| Zero constant | `.zero` | Via `Cardinal.Protocol` — works on all tagged cardinals |
| One constant | `.one` | Via `Cardinal.Protocol` — works on all tagged cardinals |
| Addition | `c1 + c2`, `c1 += c2` | Trapping (total for non-overflow) |
| Subtract saturating | `.subtract.saturating(other)` | Monus: clamps at zero — returns `Self` |
| Subtract exact | `.subtract.exact(other)` | Throws `.underflow` |
| Comparison | `<`, `<=`, `>`, `>=`, `==` | All operators via `Cardinal.Protocol` |

**Key types**:

| Type | Definition | Meaning |
|------|-----------|---------|
| `Cardinal` | `struct Cardinal { let rawValue: UInt }` | Base quantity type |
| `Index<T>.Count` | `Tagged<T, Cardinal>` | Phantom-typed quantity |
| `Memory.Address.Count` | `Tagged<Memory, Cardinal>` | Byte quantity |

**Common mistakes**:

| Mistake | Correct |
|---------|---------|
| `Cardinal(0)` | `.zero` |
| `Cardinal(1)` | `.one` |
| `.init(Cardinal(1))` | `.one` |
| `count - .one` | `count.subtract.saturating(.one)` — no `-` on cardinals |
| `count.rawValue - 1` | `count.subtract.saturating(.one)` |
| `count &-= 1` | `count = count.subtract.saturating(.one)` |

**Cross-references**: [IMPL-002], [INFRA-200]

---

## I Need a Position — Ordinal Infrastructure

### [INFRA-102] Ordinal Positions

**Package**: `Ordinal Primitives Core` (tier 4)

**Statement**: All positions (indices, addresses, slots) use `Ordinal` or `Tagged<T, Ordinal>`. Operations are policy-aware via Property accessors.

| Operation | Accessor | Policies | Notes |
|-----------|----------|----------|-------|
| Next position | `.successor` | `.saturating()`, `.exact()` | Returns `Self` or throws |
| Previous position | `.predecessor` | `.saturating()`, `.exact()` | Returns `Self` or throws |
| Move forward by N | `.advance` | `.saturating(by:)`, `.exact(by:)`, `.clamped(by:to:)` | Count parameter |
| Move backward by N | `.retreat` | `.saturating(by:)`, `.exact(by:)` | Count parameter |
| Distance to | `.distance` | `.forward(to:)` | Returns `Count`, throws `.notForward` |
| Add count | `position + count`, `position += count` | — | Via `Ordinal.Protocol` |
| Zero | `.zero` | — | Static property |

**Errors**: `Ordinal.Error` — `.overflow`, `.underflow`, `.notForward`

**Key types**:

| Type | Definition | Meaning |
|------|-----------|---------|
| `Ordinal` | `struct Ordinal { let rawValue: UInt }` | Base position type |
| `Index<T>` | `Tagged<T, Ordinal>` | Phantom-typed position |
| `Memory.Address` | `Tagged<Memory, Ordinal>` | Byte position |

**Common mistakes**:

| Mistake | Correct |
|---------|---------|
| `Ordinal(position.rawValue + 1)` | `position.successor.exact()` or `position.successor.saturating()` |
| Manual `while slot < end { slot = ... }` | Use `.forEach` from sequence infrastructure [INFRA-107] |
| `Int(bitPattern: slot)` for pointer access | `pointer[slot]` via ordinal subscript [INFRA-003] |

**Cross-references**: [IMPL-002], [IMPL-033]

---

## I Need to Convert — Domain Crossing Infrastructure

### [INFRA-103] Tagged Functors — retag and map

**Package**: `Identity Primitives` (tier 0)

**Statement**: When converting between typed domains, use `.retag()` (change tag, keep raw value) or `.map()` (keep tag, transform raw value). Do NOT extract `.rawValue` to reconstruct manually.

| Operation | Meaning | Example |
|-----------|---------|---------|
| `.retag(NewTag.self)` | Change phantom type, zero cost | `slot.retag(Bit.self)` — `Index<Element>` → `Bit.Index` |
| `.map(Ordinal.init)` | Transform raw value, keep tag | `count.map(Ordinal.init)` — `Index<T>.Count` → `Index<T>` |
| `.map { transform }` | Transform with closure | Arbitrary raw value mapping |

**Static min/max** (via conditional `Comparable` on `Tagged`):

| Operation | Signature | Notes |
|-----------|-----------|-------|
| `Type.min(a, b)` | `Tagged.min(_ a: Self, _ b: Self) -> Self` | Use instead of `Swift.min()` |
| `Type.max(a, b)` | `Tagged.max(_ a: Self, _ b: Self) -> Self` | Use instead of `Swift.max()` |

**Common mistakes**:

| Mistake | Correct |
|---------|---------|
| `Bit.Index(Ordinal(UInt(i)))` | `slot.retag(Bit.self)` |
| `Index<Element>.Count(Cardinal(count.rawValue.rawValue))` | `count.retag(Element.self)` |
| `Index<Element>(__unchecked: (), Ordinal(count.rawValue.rawValue))` | `count.map(Ordinal.init)` |
| `Swift.min(a.rawValue, b.rawValue)` | `Type.min(a, b)` |
| `Swift.max(a.rawValue, b.rawValue)` | `Type.max(a, b)` |

**Cross-references**: [IMPL-003], [CONV-003]

---

## I Need to Scale — Affine Infrastructure

### [INFRA-104] Affine.Discrete.Ratio — Typed Scaling

**Package**: `Affine Primitives Core` (tier 5)

**Statement**: When scaling a typed quantity (doubling capacity, converting between units), use `Affine.Discrete.Ratio` multiplication. Do NOT extract `.rawValue` to perform arithmetic.

| Operation | Signature |
|-----------|-----------|
| Cardinal scaling | `Tagged<From, Cardinal> * Ratio<From, To> → Tagged<To, Cardinal>` |
| Vector scaling | `Tagged<From, Vector> * Ratio<From, To> → Tagged<To, Vector>` |
| Ratio composition | `Ratio<A,B> * Ratio<B,C> → Ratio<A,C>` |
| Quotient/remainder | `.quotientAndRemainder(dividingBy:)` |
| Identity | `Ratio<T, T>.identity` — factor 1 |

**Types**:

| Type | Definition | Meaning |
|------|-----------|---------|
| `Affine.Discrete.Vector` | `struct { let rawValue: Int }` | Signed displacement |
| `Affine.Discrete.Ratio<From, To>` | `struct { let factor: Int }` | Scaling factor |
| `Index<T>.Offset` | `Tagged<T, Affine.Discrete.Vector>` | Typed displacement |

**Common mistakes**:

| Mistake | Correct |
|---------|---------|
| `Cardinal(count.rawValue &<< 1)` | `count * Affine.Discrete.Ratio<Element, Element>(2)` |
| `pointer + Int(bitPattern: offset)` | `pointer + offset` via affine integration |
| `(pointer2 - pointer1)` yielding `Int` | `pointer2 - pointer1` yielding typed `Offset` |

**Cross-references**: [IMPL-002], [PATTERN-017]

---

## I Need Bounds — Finite Infrastructure

### [INFRA-105] Bounded Indices

**Package**: `Finite Primitives` (tier 7)

**Statement**: For static-capacity types, use `Index<Element>.Bounded<N>` (compile-time bounded ordinal) instead of `Index<Element>` (unbounded). This eliminates runtime bounds checks that are provable at compile time.

| Type | Definition | Meaning |
|------|-----------|---------|
| `Ordinal.Finite<N>` | `Tagged<Finite.Bound<N>, Ordinal>` | Position bounded by N |
| `Index<T>.Bounded<N>` | `Tagged<T, Ordinal.Finite<N>>` | Typed bounded position |

| Operation | Signature | Notes |
|-----------|-----------|-------|
| Narrowing | `Ordinal.Finite<N>(position)` → `Self?` | Checked |
| Widening | `Index<T>(bounded)` | Always succeeds |
| Successor | `.successor()` → `Self?` | Partial (principled — [IMPL-001]) |
| Predecessor | `.predecessor()` → `Self?` | Partial |
| Offset | `.offset(by: delta)` → `Self?` | Partial |
| Clamped | `.clamped(offsetBy: delta)` → `Self` | Clamps to bounds |
| Distance | `.distance(to: other)` → `Int` | Signed distance |
| Complement | `.complement()` → `Self` | N - 1 - self |
| Injection | `.injected<M>()` | Safe upcast (N → M) |
| Projection | `.projected<M>()` → `Self?` | Checked downcast |
| Decompose | `.decomposed<Rows, Cols>()` | Row-major decomposition |
| Compose | `.composed(row:, column:)` | Row-major composition |
| Capacity | `Self.capacity()` → `Cardinal` | The bound N |
| Max | `Self.max()` → `Self?` | N - 1 |

**Cross-references**: [IMPL-050], [IMPL-051], [IMPL-052], [IMPL-053]

---

## I Need Mutation — Property Accessor Infrastructure

### [INFRA-106] Property<Tag, Base> Pattern

**Package**: `Property Primitives` (tier 0)

**Statement**: When a type needs verb-as-property accessors (e.g., `instance.initialize.next(to:)`, `instance.move.last()`), use `Property<Tag, Base>` or `Property<Tag, Base>.View`. Do NOT hand-roll accessor structs.

| Type | Use Case | Base |
|------|----------|------|
| `Property<Tag, Base>` | Copyable base, method extensions | Copyable |
| `Property<Tag, Base>.Typed<E>` | Copyable base, property extensions | Copyable |
| `Property<Tag, Base>.View` | ~Copyable base, mutable access | ~Copyable |
| `Property<Tag, Base>.View.Typed<E>` | ~Copyable base + Element | ~Copyable |
| `Property<Tag, Base>.View.Typed<E>.Valued<n>` | ~Copyable base + Element + 1 value generic | ~Copyable |
| `Property<Tag, Base>.View.Typed<E>.Valued<n>.Valued<m>` | ~Copyable base + Element + 2 value generics | ~Copyable |
| `Property<Tag, Base>.View.Read` | ~Copyable base, read-only | ~Copyable |
| `Property<Tag, Base>.View.Read.Typed<E>` | ~Copyable read-only + Element | ~Copyable |
| `Property<Tag, Base>.Consuming<E>` | State-tracking consuming | Consuming |

**Pattern**:

```swift
// 1. Define tag (empty enum)
extension MyType where Element: ~Copyable {
    enum Move {}
}

// 2. Define accessor property
extension MyType where Element: ~Copyable {
    var move: Property<Move, Self>.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var v = unsafe Property<Move, Self>.View(&self); yield &v }
    }
}

// 3. Extend Property with operations
extension Property<MyType<Element>.Move, MyType<Element>>.View
where Element: ~Copyable {
    mutating func callAsFunction(at slot: Index<Element>) -> Element { ... }
    mutating func last() throws(MyType.Error) -> Element { ... }
}

// 4. Call site reads as intent
instance.move(at: slot)       // callAsFunction
instance.move.last()          // named variant
```

**IMPORTANT**: When a `.View` extension includes mutating methods, the accessor MUST provide BOTH `_read` and `_modify` coroutines per [IMPL-022]. Without `_modify`, the compiler treats the yield as read-only.

**Correct** — both `_read` and `_modify` coroutines:
```swift
var remove: Property<Remove, Self>.View.Typed<Element> {
    mutating _read {
        yield unsafe Property<Remove, Self>.View.Typed(&self)
    }
    mutating _modify {
        var view = unsafe Property<Remove, Self>.View.Typed<Element>(&self)
        yield &view
    }
}
```

**Incorrect** — `_read` only:
```swift
var remove: Property<Remove, Self>.View.Typed<Element> {
    mutating _read {
        yield unsafe Property<Remove, Self>.View.Typed(&self)
    }
}
// table.remove.all()  // ❌ "cannot use mutating member on immutable value"
```

The same applies to `Property.View.Typed.Valued` for value-generic types:
```swift
var remove: Property<Tag, Self>.View.Typed<Element>.Valued<bucketCapacity> {
    mutating _read {
        yield unsafe .init(&self)
    }
    mutating _modify {
        var view = unsafe Property<Tag, Self>.View.Typed<Element>.Valued<bucketCapacity>(&self)
        yield &view
    }
}
```

If the extension only has non-mutating methods (e.g., `bucket.for(hash:)`, `forEach.occupied { }`), `_read` alone is sufficient.

**When to use Valued**: Use `.View.Typed<E>.Valued<n>` when the `Base` type has one value generic (`<let N: Int>`) and the extension needs `where Element: ~Copyable`. Use `.View.Typed<E>.Valued<n>.Valued<m>` when the `Base` type has two value generics. Value generics are lowercase (`n`, `m`) at the extension level.

**CRITICAL — Extension-level constraints for ~Copyable**: When extending `Property.View.Typed.Valued` (or `.Valued.Valued`), ALL constraints (`Tag ==`, `Base ==`, `Element: ~Copyable`) MUST be at the **extension level**, not the method level. The compiler adds an implicit `Base: Copyable` requirement when `Base ==` is constrained at method level inside a generic extension. This silently poisons ~Copyable support.

**Correct** — all constraints at extension level:
```swift
extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Linked<n>.Insert,
      Base == Buffer<Element>.Linked<n>,
      Element: ~Copyable
{
    @_lifetime(&self) @inlinable
    public mutating func front(_ element: consuming Element) throws(Buffer<Element>.Linked<n>.Error) {
        try unsafe Buffer<Element>.Linked<n>.insertFront(
            consume element,
            header: &base.pointee.header,
            storage: base.pointee.storage
        )
    }
}
```

**Incorrect** — constraints at method level (compiler adds implicit `Base: Copyable`):
```swift
extension Property.View.Typed where Element: ~Copyable {
    public mutating func front<let N: Int>(
        _ element: consuming Element
    ) throws(Buffer<Element>.Linked<N>.Error)
    where Tag == Buffer<Element>.Linked<N>.Insert,
          Base == Buffer<Element>.Linked<N>
    { ... }
    // ❌ "no type for 'Base' can satisfy both 'Base == ...' and 'Base : Copyable'"
}
```

**The rule**: `.Valued<n>` lifts value generics from the method level to the type level. This enables extension-level `where` clauses, which is the only way to avoid implicit `Copyable` constraints on `Base`.

**Common mistake**: Hand-rolling a custom accessor struct instead of using `Property<Tag, Base>.View`. The Property pattern is uniform across the ecosystem.

**Cross-references**: [IMPL-020], [IMPL-021], [IMPL-022], [API-NAME-002]

---

## I Need to Iterate — Sequence and Iteration Infrastructure

### [INFRA-107] Sequence Iteration Tags

**Package**: `Sequence Primitives` (tier 7)

**Statement**: Per [IMPL-033], iteration MUST use the highest-level abstraction. Manual `while` loops at call sites are mechanism — use iteration infrastructure instead.

| Tag | Operation | Pattern |
|-----|-----------|---------|
| `Sequence.ForEach` | For-each | `.forEach { element in }` |
| `Sequence.Reduce` | Reduction | `.reduce.into(initial) { acc, elem in }` |
| `Sequence.Map` | Mapping | `.map { transform }` |
| `Sequence.Drain` | Consuming iteration | `.drain { element in }` |
| `Sequence.Filter` | Filtering | `.filter { predicate }` |
| `Sequence.Satisfies` | Quantification | `.satisfies { predicate }` |

**Enum iteration** (initialization state, ring buffer segments):

| Operation | Pattern | Use |
|-----------|---------|-----|
| ForEach range | `.forEach { range in body(range) }` | Uniform operation on each range |
| Linearize | `.linearize { range, offset in body(range, offset) }` | Track cumulative offset |

**Common mistakes**:

| Mistake | Correct |
|---------|---------|
| `while slot < end { ... slot += .one }` | `.forEach { slot in ... }` on the type |
| Manual switch on initialization enum | `.forEach { range in ... }` or `.linearize { ... }` |
| `for i in 0..<count { ... }` | Use typed iteration infrastructure |

**Hierarchy** (prefer higher levels):

| Level | Style | When |
|-------|-------|------|
| 1. Bulk operation | No loop | Operation applies to range/all |
| 2. Iteration infrastructure | `.forEach {}`, `.reduce.into {}` | Per-element logic |
| 3. Typed while loop | `while slot < end { ... }` | Inside infrastructure implementation only |
| 4. Raw while loop | Forbidden | Never |

**Cross-references**: [IMPL-033]

---

## I Need Bits — Bit Vector Infrastructure

### [INFRA-108] Bit Vector Bulk Operations

**Package**: `Bit Vector Primitives` (tier 12)

**Statement**: When tracking occupancy or availability with bits, use `Bit.Vector` / `Bit.Vector.Static<N>` Property accessors. Do NOT write per-element loops for bulk operations.

| Operation | Accessor | Signature | Notes |
|-----------|----------|-----------|-------|
| Set bit | `.set(at:)` | `callAsFunction` | Single bit |
| Set range | `.set.range(range)` | Named method | Bulk set |
| Clear bit | `.clear(at:)` | `callAsFunction` | Single bit |
| Clear range | `.clear.range(range)` | Named method | Bulk clear |
| Clear all | `.clear.all()` | Named method | Reset all |
| Iterate ones | `.ones.forEach { }` | Wegner/Kernighan | Iterate set bits |
| Popcount | `.popcount` | Property | Count of set bits |
| Pop first | `.pop.first()` | Named method | Remove lowest set bit |
| Subscript | `bitvector[bitIndex]` | Getter/setter | Check/set bit |

**Cross-domain conversion**: Use `.retag(Bit.self)` to convert `Index<Element>` → `Bit.Index` for bit vector indexing. Use `.retag(Element.self)` to convert back.

```swift
// Correct:
_slots.set(at: slot.retag(Bit.self))
_slots.set.range(range.map.bounds { .retag(Bit.self) })

// Incorrect:
_slots[Bit.Index(Ordinal(slot.rawValue.rawValue))] = true  // rawValue chain
```

**Common mistakes**:

| Mistake | Correct |
|---------|---------|
| `while` loop setting bits one by one | `.set.range(range)` |
| Manual popcount implementation | `.popcount` property |
| Scanning for first set bit | `.pop.first()` or `.ones.forEach {}` |

---

## I Need Pointer Access — Storage Infrastructure

### [INFRA-109] Storage Primitives

**Package**: `Storage Primitives` (tier 14)

**Statement**: When managing heap-allocated element storage, use `Storage<Element>` and its Property accessors. Do NOT write manual `withUnsafe*` closures for element operations.

| Operation | Accessor | Signature | Notes |
|-----------|----------|-----------|-------|
| Pointer access | `pointer(at:)` | `→ UnsafeMutablePointer<Element>` | Core primitive |
| Initialize | `.initialize(to:, at:)` | `callAsFunction` | Direct init |
| Initialize next | `.initialize.next(to:)` | Named method | Tracked init |
| Move | `.move(at:)` | `callAsFunction` | Direct move |
| Move last | `.move.last()` | Named method | Tracked move |
| Deinitialize | `.deinitialize(at:)` | `callAsFunction` | Direct deinit |
| Deinitialize all | `.deinitialize.all()` | Named method | Bulk deinit |
| Deinitialize range | `.deinitialize(range:)` | Parameterized | Range deinit |
| Copy | `.copy(range:, to:)` | `callAsFunction` | Range copy |
| Copy clone | `.copy()` | `callAsFunction` | Full clone |

**Errors**: `Storage.Error` — `.capacityExceeded`, `.empty`

**Split storage**: `Storage.Split` for dual-lane storage with `pointer(field:, at:)`.

**Common mistakes**:

| Mistake | Correct |
|---------|---------|
| `withUnsafeMutablePointerToElements { base in let ptr = base + Int(...) }` | `storage.pointer(at: slot)` |
| Manual `ptr.initialize(to: value)` | `storage.initialize(to: value, at: slot)` |
| Manual `ptr.move()` | `storage.move(at: slot)` |
| Manual `ptr.deinitialize(count: 1)` | `storage.deinitialize(at: slot)` |

**Cross-references**: [IMPL-011], [IMPL-020]

---

## I Need Static Method Architecture

### [INFRA-110] Static Method Delegation for ~Copyable

**Statement**: Types with `~Copyable` generic parameters that need both `~Copyable` and `Copyable` method overloads MUST place core logic in static methods per [IMPL-023]. Instance methods (or Property.View methods) delegate to statics.

**The problem** — when two extensions define the same method name with different constraints, the more-constrained (`Copyable`) overload calling `self.method()` resolves to itself, not the less-constrained (`~Copyable`) version:

```swift
// ❌ INFINITE RECURSION
extension Collection where Element: ~Copyable {
    mutating func add(_ element: consuming Element) { /* core logic */ }
}
extension Collection where Element: Copyable {
    mutating func add(_ element: consuming Element) {
        prepareForMutation()
        self.add(element)  // resolves to THIS method, not the ~Copyable one
    }
}
```

**The solution** — statics are called on the type, not `self`, so overload resolution cannot recurse:

**Pattern**:

```swift
// Static — core logic (once)
extension MyType where Element: ~Copyable {
    static func add(_ element: consuming Element, state: inout State, storage: Storage) { ... }
}

// Instance — ~Copyable overload
extension MyType where Element: ~Copyable {
    public mutating func add(_ element: consuming Element) throws(Error) {
        try MyType.add(consume element, state: &state, storage: storage)
    }
}

// Instance — Copyable overload (adds preparation)
extension MyType where Element: Copyable {
    public mutating func add(_ element: consuming Element) {
        ensureUnique()
        try! MyType.add(consume element, state: &state, storage: storage)
    }
}
```

**Static method signature pattern**: Statics take the type's decomposed state as explicit parameters (e.g., `state: inout State` and `storage: Storage`). Methods that replace `self` as a whole (e.g., growth, copy-on-write) remain as instance methods.

**Validated by**: Experiment `static-property-view-pattern` — all six variants CONFIRMED (consuming ~Copyable through view, Copyable overloads, growth through _modify, callAsFunction, overload coexistence, full end-to-end).

**The full pipeline** (static → Property.View → call site):

For types **without** value generics — use `.View`:
```swift
// 1. Static layer — compound name (implementation detail)
extension MyType where Element: ~Copyable {
    static func insertFront(
        _ element: consuming Element,
        state: inout State,
        storage: Storage
    ) { /* core logic */ }
}

// 2. Property.View layer — nested accessor (public API)
extension Property<MyType<Element>.Insert, MyType<Element>>.View
where Element: ~Copyable {
    @_lifetime(&self)
    public mutating func front(_ element: consuming Element) {
        MyType.insertFront(
            consume element,
            state: &base.pointee.state,
            storage: base.pointee.storage
        )
    }
}

// 3. Call site — reads as intent
instance.insert.front(element)
```

For types **with one value generic** — use `.View.Typed<Element>.Valued<n>`:
```swift
// 1. Static layer
extension Buffer.Linked where Element: ~Copyable {
    static func insertFront(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage<Node>.Pool
    ) throws(Error) { /* core logic */ }
}

// 2. Accessor — returns .Valued<N>
extension Buffer.Linked where Element: ~Copyable {
    public var insert: Property<Insert, Self>.View.Typed<Element>.Valued<N> {
        mutating _read {
            yield unsafe Property<Insert, Self>.View.Typed<Element>.Valued<N>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Insert, Self>.View.Typed<Element>.Valued<N>(&self)
            yield &view
        }
    }
}

// 3. Extension — ALL constraints at extension level (lowercase n)
extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Linked<n>.Insert,
      Base == Buffer<Element>.Linked<n>,
      Element: ~Copyable
{
    @_lifetime(&self) @inlinable
    public mutating func front(
        _ element: consuming Element
    ) throws(Buffer<Element>.Linked<n>.Error) {
        try unsafe Buffer<Element>.Linked<n>.insertFront(
            consume element,
            header: &base.pointee.header,
            storage: base.pointee.storage
        )
    }
}

// 4. Call site — reads as intent
buffer.insert.front(element)
```

For types **with two value generics** — use `.View.Typed<Element>.Valued<n>.Valued<m>`:
```swift
// Accessor — returns .Valued<N>.Valued<capacity>
extension Buffer.Linked.Inline where Element: ~Copyable {
    public var insert: Property<Buffer<Element>.Linked<N>.Insert, Self>.View.Typed<Element>.Valued<N>.Valued<capacity> {
        mutating _read {
            yield unsafe Property<Buffer<Element>.Linked<N>.Insert, Self>.View.Typed<Element>.Valued<N>.Valued<capacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Buffer<Element>.Linked<N>.Insert, Self>.View.Typed<Element>.Valued<N>.Valued<capacity>(&self)
            yield &view
        }
    }
}

// Extension — lowercase n, m for both value generics
extension Property.View.Typed.Valued.Valued
where Tag == Buffer<Element>.Linked<n>.Insert,
      Base == Buffer<Element>.Linked<n>.Inline<m>,
      Element: ~Copyable
{
    @_lifetime(&self) @inlinable
    public mutating func front(
        _ element: consuming Element
    ) throws(Buffer<Element>.Linked<n>.Inline<m>.Error) {
        try unsafe base.pointee._insertFront(element)
    }
}

// Call site — same as always
inlineBuffer.insert.front(element)
```

**Cross-references**: [IMPL-023], [IMPL-024], [IMPL-025]

---

## Standard Library Integration Modules

### [INFRA-001] Integration Module Pattern

**Statement**: Each primitives package MAY provide a `* Standard Library Integration` module containing typed overloads that bridge primitives types to Swift stdlib APIs. Before writing `Int(bitPattern:)`, `.rawValue`, or manual pointer arithmetic at a call site, you MUST check whether an integration module already provides a typed overload.

Ten integration modules currently exist:

| Module | Package | Purpose |
|--------|---------|---------|
| Cardinal Primitives Standard Library Integration | swift-cardinal-primitives | `Span`, `UnsafeBufferPointer`, `UnsafeMutableBufferPointer`, `ContiguousArray`, `MutableSpan` constructors accepting `Cardinal.Protocol`; `Int` ↔ `Cardinal` conversions |
| Ordinal Primitives Standard Library Integration | swift-ordinal-primitives | `UnsafePointer`/`UnsafeMutablePointer` subscripts accepting `Ordinal.Protocol`; `Int` ↔ `Ordinal` conversions; `Range` operations on ordinals |
| Affine Primitives Standard Library Integration | swift-affine-primitives | `UnsafePointer`/`UnsafeMutablePointer` arithmetic with `Tagged<Pointee, Ordinal>.Offset`; `RandomAccessCollection` subscript with typed offset |
| Memory Primitives Standard Library Integration | swift-memory-primitives | Raw pointer `initialize`, `move.initialize`, `bind`, `copy`, `store`, `load` with `Index<T>.Count` and `Memory.Address.Offset` |
| Bit Primitives Standard Library Integration | swift-bit-primitives | `Bit` conformances: `CaseIterable`, `Comparable`, `Codable`, `ExpressibleByBooleanLiteral`, `FixedWidthInteger` cardinal operations |
| Equation Primitives Standard Library Integration | swift-equation-primitives | `Equation.Protocol` for stdlib types (Array, Dictionary, Optional, Range, etc.) |
| Comparison Primitives Standard Library Integration | swift-comparison-primitives | `Comparison.Protocol` for stdlib types |
| Hash Primitives Standard Library Integration | swift-hash-primitives | `Hash.Protocol` for stdlib types |
| Sequence Primitives Standard Library Integration | swift-sequence-primitives | `Sequence.Protocol` ↔ `Swift.Sequence` bridge; Span iteration |
| Vector Primitives Standard Library Integration | swift-vector-primitives | `UnsafeRawPointer`/`UnsafeMutableRawPointer` advanced/subscript with `Index<Element>` |

---

### [INFRA-002] Cardinal Integration — Counts and Sizes

**Statement**: When a stdlib API requires `Int` for a count or size, check this module first.

| Overload | Use Case |
|----------|----------|
| `Span.init(_unsafeStart:, count: C: Cardinal.Protocol)` | Constructing spans with typed count |
| `MutableSpan.init(_unsafeStart:, count: C: Cardinal.Protocol)` | Constructing mutable spans |
| `UnsafeBufferPointer.init(start:, count: C: Cardinal.Protocol)` | Buffer pointer from typed count |
| `UnsafeMutableBufferPointer.init(start:, count: C: Cardinal.Protocol)` | Mutable buffer pointer |
| `UnsafeMutableBufferPointer.allocate(capacity: C: Cardinal.Protocol)` | Typed allocation |
| `ContiguousArray.init(repeating:, count: C: Cardinal.Protocol)` | Array with typed count |
| `Int.init(bitPattern: Cardinal)` | Unchecked conversion (pointer math) |
| `Int.init(clamping: Cardinal)` | Clamped conversion (`underestimatedCount`) |
| `Int.init(_ Cardinal) throws(Cardinal.Error)` | Throwing conversion (overflow check) |
| `Tagged<Tag, Cardinal>.init(_ int: Int) throws(Cardinal.Error)` | Int value-generic to typed Count bridge (e.g., `try! Index<Element>.Count(capacity)`) |

---

### [INFRA-003] Ordinal Integration — Positions and Subscripts

**Statement**: When accessing an element by position via a pointer or array, check this module first.

| Overload | Use Case |
|----------|----------|
| `UnsafePointer[O: Ordinal.Protocol]` subscript | Element access by typed position |
| `UnsafeMutablePointer[O: Ordinal.Protocol]` subscript | Mutable element access |
| `Array[_ position: Ordinal]` subscript | Array access by ordinal |
| `Range.init(start:, count:)` | Range from position + count |
| `Range.count: Bound.Count` | Typed distance |
| `Int.init(bitPattern: Ordinal)` | Unchecked conversion |

**Common mistake**: Writing `(base + Int(bitPattern: slot)).pointee` when `base[slot]` is available.

---

### [INFRA-004] Affine Integration — Pointer Arithmetic

**Statement**: When doing pointer offset arithmetic, check this module first.

| Overload | Use Case |
|----------|----------|
| `UnsafePointer + Tagged<Pointee, Ordinal>.Offset` | Typed pointer advance |
| `UnsafePointer - Tagged<Pointee, Ordinal>.Offset` | Typed pointer retreat |
| `UnsafePointer - UnsafePointer → Offset` | Typed distance between pointers |
| `UnsafePointer[Tagged<Pointee, Ordinal>]` subscript | Subscript with typed index |
| Same for `UnsafeMutablePointer` | Mutable variants |

---

### [INFRA-005] Memory Integration — Raw Pointer Operations

**Statement**: When performing raw memory operations (initialize, move, bind, copy), check this module first.

| Overload | Use Case |
|----------|----------|
| `memory.initialize(as:, repeating:, count: Index<T>.Count)` | Typed element init |
| `memory.initialize(as:, from:, count: Index<T>.Count)` | Typed copy-init |
| `memory.move.initialize(as:, from:, count: Index<T>.Count)` | Typed move-init |
| `memory.bind(to:, capacity: Index<T>.Count)` | Typed bind |
| `memory.copy(from:, count: Memory.Address.Count)` | Typed byte copy |
| `store.bytes(of:, at: Memory.Address.Offset, as:)` | Typed byte store |

Note: These operate on `UnsafeMutableRawPointer`. Typed pointer (`UnsafeMutablePointer<T>`) overloads for `moveInitialize(from:, count:)` do not yet exist.

---

## Principled Absences — What Does NOT Exist and Why

### [INFRA-200] Operations That Are Intentionally Missing

**Statement**: The following operations do NOT exist because adding them would violate mathematical properties, type-theoretic foundations, or design constraints. These are features, not bugs. Per [IMPL-001], rethink the expression.

| Absent Operation | Why | Write Instead |
|-----------------|-----|---------------|
| `Cardinal - Cardinal` via `-` | Subtraction on naturals isn't total. Can underflow. | `.subtract.saturating(other)` or `.subtract.exact(other)` |
| `count &-= 1` | Wrapping subtract on naturals hides underflow. | `count = count.subtract.saturating(.one)` |
| `index * 2` | Indices are ordinals (affine space positions). Scaling a position is meaningless. | `offset * Ratio(2)` or rethink the operation. |
| `count * count` | Multiplying same-dimension quantities changes dimension. | `count.scale(by: ratio)` or cross-domain operation. |
| `pointer + count` | Affine space: add vectors (offsets) to points, not scalars (counts). | `pointer + offset` where offset is computed correctly. |
| `Index(rawValue: 5)` as public API | Bypasses type invariants. | Literal conformance (tests), `__unchecked` (same-package), or designated init. |
| Scalar operators on typed quantities | Typed quantities don't mix with bare `Int`/`UInt`. | Use typed operators that preserve the domain. |
| `bounded + .one → Bounded<N>` | Addition on bounded ordinals is partial: result may exceed bound. | `.successor()` returns `Optional`. Or widen, operate, re-narrow. |

---

## Decision Trees

### [INFRA-020] Before Writing Int(bitPattern:)

```
Need Int for stdlib API?
│
├─ Count/size parameter (Span, BufferPointer, ContiguousArray)?
│   └─ Use Cardinal integration overload [INFRA-002]
│
├─ Position/subscript parameter (pointer, array)?
│   └─ Use Ordinal integration subscript [INFRA-003]
│
├─ Pointer offset arithmetic?
│   └─ Use Affine integration operators [INFRA-004]
│
├─ Raw memory operation (initialize, move, bind)?
│   └─ Use Memory integration overloads [INFRA-005]
│
├─ underestimatedCount property?
│   └─ Use Int(clamping: cardinal) from [INFRA-002]
│
└─ None of the above?
    └─ Genuine boundary — acceptable per [IMPL-010]
```

---

### [INFRA-021] Before Writing .rawValue

```
Need to access the underlying value?
│
├─ Cross-domain type conversion (same ordinal, different tag)?
│   └─ Use .retag() [INFRA-103]
│
├─ Count → Index conversion?
│   └─ Use .map(Ordinal.init) [INFRA-103]
│
├─ Scaling (doubling, halving)?
│   └─ Use Affine.Discrete.Ratio [INFRA-104]
│
├─ Comparison with typed constant?
│   └─ Use .zero, .one, typed operators [INFRA-101]
│
├─ Bit.Index from Index<Element> (same numeric position)?
│   └─ Use .retag(Bit.self) [INFRA-103]
│
├─ Min/max of two values?
│   └─ Use Type.min(a, b) / Type.max(a, b) [INFRA-103]
│
└─ None of the above?
    └─ Infrastructure gap — add the overload, then use it
```

---

### [INFRA-022] Before Writing a while Loop

```
Need to iterate over elements?
│
├─ Uniform operation on a range?
│   └─ Bulk operation: .set.range(), .clear.range(), .deinitialize(range:) [INFRA-108, INFRA-109]
│
├─ Per-element logic on a collection?
│   └─ .forEach {}, .reduce.into {}, .map {} [INFRA-107]
│
├─ Consuming each element?
│   └─ .drain {} [INFRA-107]
│
├─ Iterating set bits?
│   └─ .ones.forEach {} [INFRA-108]
│
├─ Switch on initialization state (empty/one/two ranges)?
│   └─ .forEach { range in } or .linearize { range, offset in } [INFRA-107]
│
├─ Inside iteration infrastructure implementation?
│   └─ Typed while loop acceptable: while slot < end { ... slot += .one }
│
└─ None of the above?
    └─ Add iteration infrastructure to the type, then use it [IMPL-000]
```

---

### [INFRA-023] Before Hand-Rolling an Accessor Struct

```
Need a namespaced operation?
│
├─ Copyable base, methods only?
│   └─ Property<Tag, Base> [INFRA-106]
│
├─ Copyable base, need properties?
│   └─ Property<Tag, Base>.Typed<Element> [INFRA-106]
│
├─ ~Copyable base, mutable methods?
│   └─ Property<Tag, Base>.View [INFRA-106]
│
├─ ~Copyable base, mutable + Element?
│   └─ Property<Tag, Base>.View.Typed<Element> [INFRA-106]
│
├─ ~Copyable base, mutable + Element + 1 value generic (e.g., <let N: Int>)?
│   └─ Property<Tag, Base>.View.Typed<Element>.Valued<N> [INFRA-106]
│
├─ ~Copyable base, mutable + Element + 2 value generics (e.g., <let N: Int, let M: Int>)?
│   └─ Property<Tag, Base>.View.Typed<Element>.Valued<N>.Valued<M> [INFRA-106]
│
├─ ~Copyable base, read-only?
│   └─ Property<Tag, Base>.View.Read [INFRA-106]
│
└─ None of the above?
    └─ Likely still covered — check Property.Consuming<E>
```

---

### [INFRA-024] Before Writing withUnsafe* Closures

```
Need to access element memory?
│
├─ Access pointer to element at a slot?
│   └─ storage.pointer(at: slot) [INFRA-109]
│
├─ Initialize an element?
│   └─ storage.initialize(to: value, at: slot) [INFRA-109]
│
├─ Move an element out?
│   └─ storage.move(at: slot) [INFRA-109]
│
├─ Deinitialize an element?
│   └─ storage.deinitialize(at: slot) [INFRA-109]
│
├─ Copy elements to another storage?
│   └─ storage.copy(range: range, to: destination) [INFRA-109]
│
└─ None of the above?
    └─ Check if Storage.Split covers dual-lane case
```

---

### [INFRA-025] Before Writing count - 1

```
Need to decrement a count?
│
├─ Decrement by one, clamp at zero?
│   └─ count.subtract.saturating(.one) [INFRA-101]
│
├─ Decrement by one, error if zero?
│   └─ try count.subtract.exact(.one) [INFRA-101]
│
├─ Decrement by N, clamp at zero?
│   └─ count.subtract.saturating(n) [INFRA-101]
│
├─ Decrement by N, error if underflow?
│   └─ try count.subtract.exact(n) [INFRA-101]
│
└─ Writing `count - 1` or `count -= 1`?
    └─ Won't compile. No `-` on Cardinal. This is principled [INFRA-200].
```

---

## Usage Gallery — Buffer-Primitives as Reference

Buffer-primitives (tier 15) is the canonical consumer of all lower-tier infrastructure. These examples show correct usage patterns.

### Typed Counting

```swift
// Increment count by one
header.count += .one                              // Cardinal.Protocol provides .one

// Decrement count
remaining = remaining.subtract.saturating(.one)   // No - operator; use policy

// Compare with zero
guard header.count > .zero else { throw .empty }  // Typed comparison
```

### Count → Index Conversion

```swift
// Convert count to index (next slot position)
let slot = currentCount.map(Ordinal.init)         // Index<T>.Count → Index<T>
```

### Cross-Domain Retag

```swift
// Index<Element> → Bit.Index for bit vector
_slots.set(at: slot.retag(Bit.self))

// Range of indices → range of bit indices
_slots.set.range(range.map.bounds { .retag(Bit.self) })
```

### Storage Delegation

```swift
// Initialize element at slot
storage.initialize(to: element, at: slot)

// Move element from slot (consuming)
let element = storage.move(at: slot)

// Get pointer for direct access
let ptr = unsafe storage.pointer(at: slot)
```

### Static Method Architecture

```swift
// Core logic in static (defined once)
static func append(
    _ element: consuming Element,
    state: inout Header,
    storage: Storage.Heap
) throws(Storage.Error) {
    let slot = state.count.map(Ordinal.init)
    guard slot < state.capacity.map(Ordinal.init) else { throw .capacityExceeded }
    unsafe storage.pointer(at: slot).initialize(to: element)
    state.count += .one
}

// ~Copyable instance delegates to static
mutating func append(_ element: consuming Element) throws(Storage.Error) {
    try Self.append(consume element, state: &header, storage: heap)
}
```

### Property.View.Typed.Valued — Nested Accessors with Value Generics

```swift
// Buffer.Linked<N> — one value generic, uses .Valued<N>
var buffer = Buffer<Int>.Linked<2>(minimumCapacity: 8)
buffer.insert.front(42)          // Property.View.Typed<Int>.Valued<2>
buffer.insert.back(99)
let first = buffer.remove.front() // → 42

// Buffer.Linked<N>.Inline<capacity> — two value generics, uses .Valued<N>.Valued<capacity>
var inline = Buffer<Int>.Linked<2>.Inline<8>()
try inline.insert.front(42)      // Property.View.Typed<Int>.Valued<2>.Valued<8>
try inline.insert.back(99)
let x = inline.remove.front()    // → 42

// Buffer.Linked<N>.Small<inlineCapacity> — two value generics, same pattern
var small = Buffer<Int>.Linked<2>.Small<4>()
small.insert.front(10)           // Property.View.Typed<Int>.Valued<2>.Valued<4>
small.insert.back(20)
```

### Enum Iteration

```swift
// Deinitialize all initialized ranges
header.initialization.forEach { range in
    deinitialize(range: range)
}

// Copy with offset tracking
base.initialization.linearize { range, offset in
    copy(range: range, to: destination, at: offset)
}
```

---

## Cross-References

See also:
- **implementation** skill — [IMPL-INTENT], [IMPL-000], [IMPL-001], [IMPL-002], [IMPL-003], [IMPL-010], [IMPL-020–025], [IMPL-030–033], [IMPL-050–053], [PATTERN-017–019]
- **conversions** skill — [IDX-*], [CONV-001], [CONV-003] — rawValue access location, functor operations
- **naming** skill — [API-NAME-002] — compound identifiers (not an infrastructure concern)
- **Research**: [typed-infrastructure-catalog.md](../../Research/typed-infrastructure-catalog.md) — Tier 3 systematic audit backing this skill
