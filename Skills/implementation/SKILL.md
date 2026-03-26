---
name: implementation
description: |
  Intent-over-mechanism as foundational axiom. Expression-first style,
  call-site-first design, typed arithmetic, boundary overloads,
  property accessors. Absorbs anti-patterns and design patterns.
  ALWAYS apply when writing or reviewing implementation code.

layer: implementation

requires:
  - swift-institute
  - code-surface
  - conversions

applies_to:
  - swift
  - swift6
  - primitives
  - standards
  - foundations
last_reviewed: 2026-03-20
---

# Implementation

Every line of implementation code reads as intent.

---

## Foundational Axiom

### [IMPL-INTENT] Code Reads as Intent, Not Mechanism

**Statement**: All implementation code MUST read as a declaration of *what* is being accomplished, never as a description of *how* the machine accomplishes it. This is the governing principle of the entire implementation skill. Every other rule in this document is a corollary.

The question at every line, every expression, every code review is: **"Does this read as intent?"**

- If a line describes *what* happens → it reads as intent. Keep it.
- If a line describes *how* it happens → it reads as mechanism. Refactor it.
- If you cannot tell the difference → the code is unclear. Refactor it.

**Intent** is the domain operation: initialize, move, copy, insert, remove, count, compare, iterate.
**Mechanism** is the implementation machinery: offset computation, pointer arithmetic, raw value extraction, bitPattern conversion, closure scaffolding, manual index construction.

Mechanism belongs inside infrastructure (operators, overloads, accessors, boundary methods). Intent belongs at call sites. When mechanism leaks into a call site, the infrastructure is incomplete.

This principle has convergent support spanning 50+ years of language design (Landin 1966, Backus 1978, Dijkstra 1968), practitioner consensus (Beck, Fowler, Martin), empirical research (Cates et al. 2021), and Swift's own evolution toward expression-oriented style (SE-0255, SE-0380).

**Cross-references**: [Research: intent-over-mechanism-expression-first.md]

---

### [IMPL-EXPR-001] Prefer Single Expressions Over Separate Declarations

**Statement**: Implementation code MUST prefer single-line expressions over separate `let`/`var` declarations. An intermediate variable is justified only when it meets one of the three boundary conditions below. Otherwise, inline the expression.

**Boundary conditions** (the only valid reasons for an intermediate binding):

1. **Multi-use**: The sub-expression is consumed more than once. Even then, prefer a named function over a local variable when the logic is reusable.
2. **Explanatory name**: The intermediate name communicates domain knowledge not visible in the expression itself. A name that merely restates the expression (e.g., `let count = range.count`) does not qualify.
3. **Complexity ceiling**: The expression composition has reached a point where it obscures rather than reveals intent. The correct extraction target is a named function (Fowler's "Replace Temp with Query"), not a local variable.

**Perfect** — single expression, reads as intent:
```swift
unsafe destination.pointer(at: offset)
    .initialize(from: base.pointer(at: range.lowerBound), count: range.count)
```

**Imperfect** — separate declarations expose mechanism:
```swift
let srcPointer = unsafe base.pointer(at: range.lowerBound)
let dstPointer = unsafe destination.pointer(at: offset)
let count = range.count
unsafe dstPointer.initialize(from: srcPointer, count: count)
```

The second form has three bindings. None carries explanatory value beyond what the expression already says. Each binding forces the reader to hold a name in working memory and match it to its use site. The first form composes the same operation as a single intent: "initialize destination from source."

**Perfect** — expression communicates the full operation:
```swift
return currentCount.map(Ordinal.init)
```

**Imperfect** — decomposition adds nothing:
```swift
let ordinal = Ordinal(currentCount.rawValue)
let index = Index<Element>(__unchecked: (), ordinal)
return index
```

**Empirical basis**: Cates, Yunik, & Feitelson (2021) showed that intermediate variables with non-informative names can *decrease* comprehension. Variables are cognitively beneficial only when the name carries genuine explanatory value.

**Cross-references**: [IMPL-INTENT], [IMPL-030], [Research: intent-over-mechanism-expression-first.md]

---

### [IMPL-000] Call-Site-First Design

**Statement**: Implementation code MUST be written as the ideal expression first. If the infrastructure doesn't support it, the infrastructure MUST be improved — unless the absence is principled (see [IMPL-001]).

Write the expression that reads like intent. Then:

1. **If it compiles** → done.
2. **If it doesn't compile** → is the absence principled?
   - **Yes** → rethink the expression. The type system is telling you something.
   - **No** → improve the infrastructure. Add the operator, overload, accessor, or method.

```
Write ideal expression
    │
    ├─ Compiles → done
    │
    └─ Doesn't compile → what's missing?
        │
        ├─ Principled absence → rethink expression [IMPL-001]
        │
        └─ Infrastructure gap → add it:
            ├─ Missing operator        → arithmetic primitives
            ├─ Missing overload        → stdlib integration layer
            ├─ Missing accessor        → the type itself
            ├─ Missing iteration       → the enum
            └─ Missing transformation  → range/collection primitives
```

After improving infrastructure, all other call sites also benefit.

**Rationale**: The infrastructure serves the expression. Not the other way around.

---

### [IMPL-001] Principled Absences

**Statement**: Before adding missing infrastructure, you MUST verify the absence is not principled. An absence is principled when adding the operation would violate mathematical properties, type-theoretic foundations, or established design constraints.

**Principled — do NOT add:**

| You want to write | Why it doesn't exist | What to write instead |
|---|---|---|
| `count - count` with `-` | Subtraction on naturals isn't total. `Cardinal - Cardinal` can underflow. | `count.subtract.saturating(other)` or `try count.subtract.exact(other)` |
| `index * 2` | Indices are ordinals (affine space positions). Scaling a position is meaningless. | Rethink: do you mean `offset * 2`? Express the actual operation. |
| `bounded + .one` returning `Bounded<N>` | Addition on a bounded ordinal is partial: the result may equal `N`, exceeding the bound. A non-Optional return hides capacity overflow. | `bounded.successor()` (returns `Optional`). Or widen to `Index<Element>`, operate, re-narrow. |

For the complete catalog of principled absences, see [INFRA-200].

**Gap — DO add:**

| You want to write | Why it should exist | Where to add it |
|---|---|---|
| `count + .one` | `Cardinal + Cardinal → Cardinal` is total. | cardinal-primitives |
| `pointer.initialize(from:count: typedCount)` | Valid operation; only the `Int` bridge is missing. | affine-primitives stdlib integration |
| `range.map.bounds { transform }` | Mapping both bounds preserves range semantics. | range-primitives |
| `slot < capacity` (Index vs Count) | Comparison is well-defined between position and size. | ordinal-primitives |

**The test**: Does the operation preserve the mathematical properties of the types involved? If adding it would make a partial operation look total, mix dimensions, or violate affine space rules — the absence is a feature. Rethink the expression.

**Cross-references**: [CONV-010], [MEM-ARITH-001]

---

## Dependency Strategy

### [IMPL-060] Ecosystem Dependencies Over Ad-Hoc Implementation

**Statement**: When the ecosystem already provides a type, operation, or infrastructure at any layer, it MUST be used via dependency rather than reimplemented ad-hoc. Adding a dependency to an existing ecosystem package is always preferred over writing a local implementation of equivalent functionality. "Minimizing dependencies" is NOT a valid reason to reimplement what the ecosystem already provides.

**Decision procedure**:

| Question | If Yes | If No |
|----------|--------|-------|
| Does the ecosystem provide this type/operation? | Import and use it | Implement it |
| Does importing it violate tier constraints? | Investigate: wrong tier placement, or need join-point | Import it |
| Is the local version "simpler"? | Still import — simplicity does not justify duplication | — |
| Would the dependency be the package's first external dep? | Still import — dependency count is not a design goal | — |

**Detection**: During code review, if a type, algorithm, or operation has the same semantics as something in the ecosystem — even if the local version is "simpler" or "smaller" — it is a duplication candidate. The ecosystem version is canonical.

**Why**: Ad-hoc reimplementations create type incompatibility across packages, duplicate maintenance burden, miss upstream improvements, and fragment the ecosystem. The entire layered architecture exists so that higher layers consume lower layers. Not consuming them defeats the architecture.

**Corollaries**:
- [PATTERN-053] is a specific instance of this rule for primitives-layer types
- [PATTERN-026] is a specific instance for centralized common patterns
- [IMPL-000] "improve the infrastructure" means improving the *ecosystem* infrastructure, not local workarounds

**Cross-references**: [PATTERN-053], [PATTERN-026], [IMPL-000], [API-LAYER-001], [SEM-DEP-009]

---

## Typed Arithmetic

### [IMPL-002] Write the Math, Not the Mechanism

**Statement**: Arithmetic on typed values MUST use typed operators. Raw value extraction (`.rawValue`, `.position`) MUST NOT appear at call sites for computation. This is a direct corollary of [IMPL-INTENT]: raw value extraction is mechanism; typed arithmetic is intent.

**Perfect**:
```swift
let slot = currentCount.map(Ordinal.init)
base.initialization = .linear(count: currentCount + .one)
let remaining = count.subtract.saturating(.one)
let bitCount = _slots.popcount.retag(Element.self)
```

**Imperfect**:
```swift
let slot = Index<Element>(__unchecked: (), Ordinal(currentCount.rawValue.rawValue + UInt(spanCount)))
let newCount = Index<Element>.Count(currentCount.rawValue + 1)
let count = Int(range.count.rawValue.rawValue)
```

If you find yourself chaining `.rawValue.rawValue`, that's a missing operator. Add it.

For canonical constants (`.one`, `.zero`) and their protocol lifting, see [INFRA-101].

**Cross-references**: [CONV-010], [PATTERN-018], [INFRA-101]

---

### [IMPL-003] Functor Operations for Domain Crossing

**Statement**: Cross-domain type conversions MUST use `.map()` (transform raw value, preserve tag) or `.retag()` (preserve raw value, change tag). Direct `__unchecked` construction SHOULD be avoided when a functor path exists.

For the complete functor operation catalog (`.map()`, `.retag()`) and common mistakes, see [INFRA-103].

**Cross-references**: [CONV-003], [IDX-010], [INFRA-103]

---

### [IMPL-003a] Domain-Crossing Before Operations

**Statement**: When an operation requires values from different phantom-typed domains, convert to the target domain first using `.retag()`, then operate. Do NOT extract `.rawValue` or use `.vector` as a domain escape hatch.

**Perfect** — convert to target domain, then compare:
```swift
let offset = offset.retag(Element.self)
guard offset.vector < count else { throw .outOfBounds }
```

**Imperfect** — extract raw value to bypass domain enforcement:
```swift
guard offset.vector.rawValue < count.rawValue else { throw .outOfBounds }
```

**Rationale**: When `Domain` enforcement arrives (via `SuppressedAssociatedTypes`), domain-agnostic operations break. The `.retag()` pattern makes the domain crossing explicit and survives Domain enforcement.

**Cross-references**: [IMPL-003], [INFRA-103]

---

### [IMPL-004] Typed Comparisons

**Statement**: Comparisons MUST use typed values directly. Raw value extraction for comparison is forbidden at call sites.

**Perfect**:
```swift
guard slot < base.slotCapacity else { throw .capacityExceeded }
guard currentCount > .zero else { throw .empty }
guard !range.isEmpty else { return }
```

**Imperfect**:
```swift
precondition(slot.rawValue < heap.slotCapacity.rawValue, "...")
precondition(currentCount.rawValue.rawValue > 0, "...")
```

If a comparison operator doesn't exist between two related types, add it.

**Cross-references**: [PATTERN-017], [CONV-001]

---

### [IMPL-005] Typed Static Min/Max

**Statement**: When computing the minimum or maximum of two values of the same `Tagged` type, use the static `Type.min(a, b)` / `Type.max(a, b)` methods. Do not extract raw values to use `Swift.min()`.

**Perfect**:
```swift
let take = Index<Element>.Count.min(.init(maximumCount), remaining)
```

**Imperfect**:
```swift
let take = Swift.min(maximumCount.rawValue, remaining.rawValue.rawValue)
```

**Rationale**: `Tagged` provides `min`/`max` via its `Comparable` conformance. Using them keeps the result typed, eliminating downstream raw-value extraction for subtraction or pointer math.

For the full `Type.min(a, b)` / `Type.max(a, b)` API, see [INFRA-103].

**Cross-references**: [IMPL-002], [IMPL-004], [INFRA-103]

---

### [IMPL-006] Zero-Cost Typed Stored Properties

**Statement**: Stored properties that hold quantities (counts, positions, sizes) SHOULD use typed wrappers (`Index<Element>.Count`, `Index<Element>`) rather than raw `UInt`. The conversion boundary belongs in the type's initializer — where data flows in from already-typed sources — not scattered across every method that reads the field.

**Perfect**:
```swift
var remaining: Index<Element>.Count

init(count: Index<Element>.Count) {
    self.remaining = count          // boundary: typed in, typed stored
}
```

**Imperfect**:
```swift
var remaining: UInt

init(count: Index<Element>.Count) {
    self.remaining = count.rawValue.rawValue  // boundary: typed in, raw stored
}
// Then every method repeats: Index<Element>.Count(Cardinal(remaining))
```

**Rationale**: `Tagged` is a zero-cost wrapper — same memory layout as the raw value. Storing the typed version eliminates N extraction sites across M methods, replacing them with one clean assignment at init.

**Cross-references**: [IMPL-002], [IMPL-010]

---

## Boundary Overloads

### [IMPL-010] Push Int to the Edge

**Statement**: `Int(bitPattern:)` conversions MUST live inside boundary overloads, never at call sites. If a stdlib API only accepts `Int`, provide a typed overload that accepts the domain type and converts internally.

**Perfect** — stdlib boundary is invisible:
```swift
unsafe destination.pointer(at: offset)
    .initialize(from: base.pointer(at: range.lowerBound), count: range.count)
```

**Imperfect** — boundary conversion pollutes call site:
```swift
let count = Int(range.count.rawValue.rawValue)
_ = unsafe withUnsafeMutablePointerToElements { src in
    let srcOffset = Index<Element>.Offset(fromZero: range.lowerBound)
    unsafe destination.withUnsafeMutablePointerToElements { dst in
        unsafe (dst + dstOffset).initialize(from: srcStart, count: count)
    }
}
```

**The overload pattern**:
```swift
extension UnsafeMutablePointer {
    public func initialize(
        from source: UnsafePointer<Pointee>,
        count: Tagged<Pointee, Ordinal>.Count
    ) {
        self.initialize(from: source, count: Int(bitPattern: count))
    }
}
```

The `Int` conversion lives in one place, once, forever.

**Cross-references**: [PATTERN-018], [CONV-014]

---

### [IMPL-011] Pointer Primitives

**Statement**: Types that manage memory SHOULD provide a `pointer(at: Index<Element>)` method that encapsulates offset computation. All other slot access methods SHOULD delegate to this primitive.

**Perfect**:
```swift
let ptr = unsafe storage.pointer(at: slot)
```

**Imperfect**:
```swift
let ptr = unsafe withUnsafeMutablePointerToElements { base in
    let offset = Index<Element>.Offset(fromZero: slot)
    return unsafe base + offset
}
```

**Rationale**: `pointer(at:)` eliminates `withUnsafe*` closures that exist only to compute an offset.

---

### [IMPL-012] Range Bound Transformation

**Statement**: Transforming both bounds of a range MUST use `range.map.bounds { }`, not manual decomposition.

**Perfect**:
```swift
_slots.set.range(range.map.bounds { $0.retag(Bit.self) })
```

**Imperfect**:
```swift
var slot = range.lowerBound
while slot < range.upperBound {
    _slots[Bit.Index(slot.rawValue)] = true
    slot = slot.successor.saturating()
}
```

**Cross-references**: [IMPL-003]

---

## Property Accessors

### [IMPL-020] Verb-as-Property with callAsFunction

**Statement**: When a type has a verb-like operation namespace, it SHOULD be expressed as a property returning `Property<Tag, Base>` with `callAsFunction` for the direct operation and named methods for qualified variants.

**Perfect**:
```swift
heap.initialize(to: element, at: slot)     // callAsFunction — direct
heap.initialize.next(to: element)          // named method — tracked

heap.move(at: slot)                         // callAsFunction — direct
heap.move.last()                            // named method — tracked

heap.deinitialize(at: slot)                 // callAsFunction — direct
heap.deinitialize.all()                     // named method — tracked

heap.copy(range: range, to: dest)           // callAsFunction — parameterized
heap.copy(to: dest)                         // callAsFunction — all elements
heap.copy()                                 // callAsFunction — clone
```

**Implementation**: Tag types are empty enums. Methods are extensions on `Property` constrained by `where Tag == ..., Base == ...`. For the full implementation pattern, see [INFRA-106].

**Cross-references**: [API-NAME-002], [INFRA-106]

---

### [IMPL-021] Property vs Property.View

**Statement**: Use `Property<Tag, Base>` for Copyable bases (owned access). Use `Property<Tag, Base>.View` for `~Copyable` bases (pointer-based mutable access). MUST NOT hand-roll accessor structs.

| Base type | Use | Accessor pattern |
|-----------|-----|------------------|
| Copyable | `Property<Tag, Base>` | `var x: Property<Tag, Self> { Property(self) }` |
| ~Copyable | `Property<Tag, Base>.View` | `var x: Property<Tag, Self>.View { mutating _read { yield unsafe ...View(&self) } }` |

**Imperfect** — hand-rolled struct:
```swift
public struct Initialize: ~Copyable, ~Escapable {
    @usableFromInline let heap: Storage.Heap
    @inlinable @_lifetime(borrow heap)
    init(heap: borrowing Storage.Heap) { self.heap = copy heap }
}
```

**Rationale**: `Property` and `Property.View` eliminate per-type boilerplate. The pattern is uniform across the ecosystem.

---

### [IMPL-022] _read + _modify for Mutating Property Accessors

**Statement**: When a `Property.View` (or `.View.Typed`, or `.View.Typed.Valued`) extension includes **mutating** methods, the accessor property MUST provide both `_read` and `_modify` coroutines. Without `_modify`, the compiler treats the yield as read-only and rejects mutating method calls at the call site.

**Correct** — both coroutines:
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

**Cross-references**: [IMPL-021], [API-NAME-002]

---

### [IMPL-026] Property.View Protocol Delegation

**Statement**: When a `~Copyable` protocol's conformers share Property.View operations with identical semantics, the accessors and Property.View methods MUST be provided as protocol defaults with `Base: Protocol & ~Copyable` constraints. Per-type accessors MUST NOT duplicate the protocol default. Per-type Property.View extensions MAY add type-specific methods that coexist with protocol-level defaults.

**Perfect** — one declaration serves all conformers:
```swift
// Protocol provides accessors as defaults
extension MyProtocol where Self: ~Copyable {
    @inlinable
    public var pop: Property<Pop, Self>.View {
        mutating _read { yield unsafe Property<Pop, Self>.View(&self) }
        mutating _modify { var view = unsafe Property<Pop, Self>.View(&self); yield &view }
    }
}

// Protocol-constrained Property.View methods
extension Property.View where Tag == Pop, Base: MyProtocol & ~Copyable {
    @inlinable
    public func first() -> Index? {
        unsafe base.pointee.popFirst()
    }
}

// All conformers — ~Copyable, Copyable, value-generic — get pop.first() automatically.
// Zero boilerplate per type.
```

**Imperfect** — duplicated per concrete type:
```swift
// Repeated for EVERY conformer
extension ConcreteType {
    public var pop: Property<Pop, Self>.View {
        mutating _read { yield unsafe Property<Pop, Self>.View(&self) }
        mutating _modify { var view = unsafe Property<Pop, Self>.View(&self); yield &view }
    }
}
extension Property.View where Tag == Pop, Base == ConcreteType {
    public func first() -> Index? { unsafe base.pointee.popFirst() }
}
// Same again for ConcreteType2, ConcreteType3...
```

**Type-specific methods coexist** with protocol-level defaults. A concrete `Base == ConcreteType` extension can add methods that resolve through the protocol-provided accessor:
```swift
// Protocol provides: var set: Property<Set, Self>.View (serves all conformers)
// Dynamic-specific method resolves through the protocol-provided accessor:
extension Property.View where Tag == Set, Base == Dynamic {
    public func returning(_ index: Index) throws(Dynamic.Error) -> Bool {
        let previous = try unsafe base.pointee.get(index)
        try unsafe base.pointee.set(index)
        return previous
    }
}
// dynamic.set.all()              — protocol-level default
// dynamic.set.returning(index)   — type-specific addition
```

**Compiler constraints**:

1. `where Self: ~Copyable` on protocol extensions — required. Without it, the compiler adds implicit `Self: Copyable`, preventing ~Copyable conformers from accessing the defaults.
2. `Base: Protocol & ~Copyable` on Property.View extensions — the `& ~Copyable` is required so the extension covers both Copyable and ~Copyable conformers.
3. Per-type overrides shadow protocol defaults. If a conformer declares its own accessor with an identical body, the override is redundant — remove it.

**Semantic boundary** — this pattern applies when:
- The operation is expressible purely through protocol requirements
- The semantics are identical across all conformers

It does NOT apply when:
- Operations check type-specific state not in the protocol (e.g., bounds-checking against `_count`)
- Return types differ per conformer
- Operations require type-specific initializers or growth behavior

**Validated by**: Experiment `swift-bit-vector-primitives/Experiments/property-view-protocol-constraint/` — 6 variants CONFIRMED (~Copyable, Copyable, value-generic, `some Protocol` generic function).

**Cross-references**: [IMPL-020], [IMPL-021], [IMPL-022], [Research: property-view-protocol-delegation.md]

---

## Static Method Architecture

### [IMPL-023] Core Logic in Static Methods

**Statement**: Types with `~Copyable` generic parameters that need both `~Copyable` and `Copyable` method overloads MUST place core logic in static methods. Instance methods (or Property.View methods) delegate to statics. This eliminates Swift's overload recursion problem.

**The problem**: When two extensions define the same method name with different constraints, the more-constrained (`Copyable`) overload calling `self.method()` resolves to itself, not the `~Copyable` version — producing infinite recursion.

**The solution**: Statics are called on the type, not `self`, so overload resolution cannot recurse. Both `~Copyable` and `Copyable` instance overloads delegate to the same static.

For the full problem/solution code examples and pattern, see [INFRA-110].

**Static method signature pattern**: Statics take the type's decomposed state as explicit parameters (e.g., `state: inout State` and `storage: Storage`). Methods that replace `self` as a whole (e.g., growth, copy-on-write) remain as instance methods.

**Validated by**: Experiment `static-property-view-pattern` — all six variants CONFIRMED (consuming ~Copyable through view, Copyable overloads, growth through _modify, callAsFunction, overload coexistence, full end-to-end).

**Cross-references**: [IMPL-020], [IMPL-024], [IMPL-025], [API-NAME-002]

---

### [IMPL-024] Compound Identifiers in the Static Layer

**Statement**: Static methods (the implementation layer) MAY use compound names. The public API layer MUST NOT — it uses Property.View nested accessors per [API-NAME-002]. The two layers have different naming rules because they serve different audiences.

| Layer | Audience | Naming | Example |
|-------|----------|--------|---------|
| Static (implementation) | Package author | Compound names allowed | `MyType.insertFront(_:state:storage:)` |
| Property.View (public API) | Consumer | Nested accessors required | `instance.insert.front(element)` |

**Rationale**: Static method names are implementation details — they appear in delegation code inside the package, not at consumer call sites. Compound names like `insertFront` are clear and conventional at this layer. The public API transforms them into the nested accessor pattern: `instance.insert.front()`.

For the full pipeline (static layer → Property.View layer → call site), see [INFRA-110] and [INFRA-106].

**Cross-references**: [API-NAME-002], [IMPL-023], [IMPL-020], [INFRA-110], [INFRA-106]

---

### [IMPL-025] Two-Tier Overload Resolution

**Statement**: When a type supports both `~Copyable` and `Copyable` elements, it MUST provide two tiers of public methods (instance or Property.View). Both tiers delegate to the same static. The `Copyable` tier adds preparation logic (e.g., copy-on-write uniqueness checks) before the static call. Neither tier calls `self.method()` — both call `Type.staticMethod()`.

For the full two-tier overload pattern with code examples, see [INFRA-110].

**Overload resolution**: When `Element` is `Copyable`, Swift selects the more-constrained overload. When `Element` is `~Copyable`, only the base overload is available. No ambiguity, no recursion.

**What stays as instance methods**: Methods that replace `self` as a whole (growth, copy-on-write checks) remain as instance methods — they mutate the entire value, not just individual stored properties.

**Cross-references**: [IMPL-023], [IMPL-024], [MEM-COPY-006]

---

## Expression Style

### [IMPL-030] Inline Construction Over Intermediate Variables

**Statement**: When constructing a value to pass immediately, it MUST be constructed inline rather than bound to an intermediate variable. Intermediate bindings are permitted only under the boundary conditions of [IMPL-EXPR-001].

**Perfect** — single expression reads as intent ("give body a span over this range"):
```swift
return try body(unsafe Span(
    _unsafeStart: pointer(at: range.lowerBound),
    count: Int(bitPattern: range.count)
))
```

**Imperfect** — four bindings expose mechanism ("compute offset, convert count, make pointer, construct span, then call"):
```swift
try unsafe withUnsafeMutablePointerToElements { base throws(E) in
    let startOffset = Index<Element>.Offset(fromZero: range.lowerBound)
    let count = Int(bitPattern: range.count)
    let span = unsafe Span(_unsafeStart: UnsafePointer(base + startOffset), count: count)
    return try body(span)
}
```

**Boundary conditions** (per [IMPL-EXPR-001]): An intermediate binding is justified only when the sub-expression is used more than once, the name carries genuine explanatory value, or the expression exceeds the complexity ceiling. In the latter case, prefer extracting a named function over introducing a local variable.

**Cross-references**: [IMPL-INTENT], [IMPL-EXPR-001]

---

### [IMPL-031] Enum Iteration Over Manual Switch

**Statement**: When applying a uniform operation across all cases of an enum, the enum SHOULD provide `.forEach` (and `.linearize` when offset tracking is needed). Call sites MUST NOT manually switch when a uniform iterator exists.

For enum iteration examples (`.forEach`, `.linearize`) vs manual `switch`, see [INFRA-107].

If the iteration method doesn't exist on the enum, add it.

**Cross-references**: [IMPL-INTENT], [IMPL-033]

---

### [IMPL-032] Bulk Operations Over Per-Element Loops

**Statement**: When a bulk operation exists (e.g., `set.range()`, `clear.range()`, `deinitialize(count:)`), it MUST be preferred over per-element loops.

For bulk operation examples (`.set.range()`, `.deinitialize(count:)`) vs per-element loops, see [INFRA-107] and [INFRA-108].

**Cross-references**: [IMPL-INTENT], [IMPL-033], [INFRA-107], [INFRA-108]

---

### [IMPL-033] Iteration: Intent Over Mechanism

**Statement**: Iteration MUST use the highest-level abstraction that expresses intent. Manual `while` loops are mechanism — they describe *how* to traverse, not *what* to traverse. The iteration infrastructure in sequence-primitives and vector-primitives exists to express intent. A manual loop is permitted only when implementing that infrastructure itself.

**Hierarchy** (prefer higher levels):

| Level | Style | When |
|-------|-------|------|
| **1. Bulk operation** | No loop | Operation applies uniformly to a range or all elements |
| **2. Iteration infrastructure** | `.forEach { }`, `.reduce.into { }`, `.map { }` | Per-element logic with closure |
| **3. Typed while loop** | `while slot < end { ... slot += .one }` | Inside iteration infrastructure implementation only |
| **4. Raw while loop** | Forbidden | Never |

For iteration examples at each level of this hierarchy, see [INFRA-107] and [INFRA-022].

**When you need a loop and no iteration infrastructure exists**: Per [IMPL-000], the absence is likely a gap. Add `.forEach`, `.reduce`, or the appropriate iteration method to the type, then use it at the call site. All other call sites also benefit.

**Rationale**: A `while` loop with `slot += .one` is typed mechanism — better than raw mechanism, but still mechanism. The intent is "do X for each element." The infrastructure `.forEach { }`, `.reduce.into { }`, `.map { }`, `.drain { }` from sequence-primitives and vector-primitives express exactly that intent.

**Cross-references**: [IMPL-INTENT], [IMPL-EXPR-001], [IMPL-000], [IMPL-031], [IMPL-032]

---

## Compiler Constraints on Expression Structure

### [IMPL-034] unsafe Keyword Placement

**Statement**: The `unsafe` keyword MUST wrap the entire expression from the left. It cannot appear to the right of a non-assignment binary operator.

**Correct**:
```swift
guard unsafe slot < base.pointee.slotCapacity else { throw .capacityExceeded }
```

**Incorrect**:
```swift
guard slot < unsafe base.pointee.slotCapacity else { throw .capacityExceeded }
// ❌ Compiler error: 'unsafe' cannot appear to the right of '<'
```

**Rationale**: Swift's `unsafe` is a statement-level annotation, not an expression-level operator. When it appears in a binary expression, it must precede the full expression, not a sub-expression.

**Cross-references**: [IMPL-INTENT], [IMPL-030]

---

### [IMPL-035] Uniform Execution Model

**Statement**: When computation is deferred to a work queue or stack, ALL items at the same structural level MUST use the same execution model. Mixing immediate execution for some items with deferred execution for others creates ordering violations that are invisible at the dispatch site.

**Perfect** — uniform deferral:
```swift
// All siblings deferred uniformly — ordering preserved by the queue
for item in items.reversed() {
    workStack.push(.process(item))
}
```

**Incorrect** — mixed execution models:
```swift
for item in items {
    if item.isSimple {
        item.process(context: &context)     // ❌ Immediate
    } else {
        workStack.push(.process(item))      // Deferred
    }
}
// Ordering between simple and complex items is now broken
```

**Applies to**: Any recursive-to-iterative conversion, work queue dispatch, event loop scheduling, or batched processing where items at the same level have ordering dependencies (parent/child scoping, sibling interleaving, push/pop pairing).

**Rationale**: Once a computation model moves from call-stack to heap-managed work, partial deferral breaks any invariant that depends on execution order at a given level. The fix is always the same: defer everything uniformly, then let the work queue enforce ordering.

**Provenance**: Reflection `2026-03-18-iterative-render-machine-stack-overflow-fix.md`.

**Cross-references**: [IMPL-INTENT], [IMPL-033]

---

### [IMPL-036] Minimal Storage for Deferred Computation

**Statement**: When ownership prevents storing a computed value (e.g., the value is `~Copyable` or `~Escapable`), store the minimum necessary to *recompute* it later. The storable unit is typically the source (often `Copyable`) rather than the result (often `~Copyable`).

**Perfect** — store the source, compute on demand:
```swift
// Store the Copyable container; compute the ~Copyable content at dispatch time
struct Thunk {
    let dispatch: (inout Context) -> Void
    init<Source: Container>(_ source: Source) {
        dispatch = { context in
            Source.Content.process(source.content, context: &context)
        }
    }
}
```

**Incorrect** — store the result directly:
```swift
struct Thunk<Content: ~Copyable> {
    let content: Content  // ❌ Requires Content: Copyable for heap storage
}
```

**Applies to**: Any scenario where a computed value cannot be stored due to ownership constraints — work queues holding `~Copyable` results, closures capturing `~Escapable` views, deferred evaluation of protocol associated types. The pattern generalizes: when you cannot store X, find Y such that X = f(Y) and store Y instead.

**Rationale**: The value needed for deferred work is often a computed property whose source has weaker ownership requirements. Storing the source and recomputing the value at dispatch time sidesteps the ownership constraint entirely. This also applies beyond `~Copyable` — any case where the result is harder to store than its inputs.

**Provenance**: Reflection `2026-03-18-store-view-not-body-noncopyable-rendering.md`.

**Cross-references**: [MEM-COPY-005], [MEM-COPY-012], [IMPL-INTENT]

---

### [IMPL-037] String Interpolation as Type Bridge

**Statement**: When a type conforms to `ExpressibleByStringLiteral` and also has a `init(_:) throws`, Swift's overload resolution selects the literal conformance unconditionally — even inside `try` expressions. The non-throwing bridge for String variables is string interpolation: `"\(stringVar)"`.

**Perfect** — interpolation coerces to literal-conforming type:
```swift
let component = path / "\(stringVariable)"  // Non-throwing via interpolation
```

**Incorrect** — trying to disambiguate with `try`:
```swift
let component = try path / Path.Component(stringVariable)
// ❌ Compiler selects literal conformance, warns "no calls to throwing functions"
```

**Also incorrect** — wrapping in explicit throwing init:
```swift
let component = try Path.Component(stringVariable)
// ❌ Same: literal conformance wins over throwing init(_ string:)
```

**Scope**: This applies to any type combining `ExpressibleByStringLiteral` (or `ExpressibleByStringInterpolation`) with a throwing `init(_ string:)`. The pattern resolves the tension without renaming or `@_disfavoredOverload`.

**Provenance**: Reflection `2026-03-20-file-path-literal-vs-throwing-init-harmonization.md`.

**Cross-references**: [IMPL-000], [IMPL-INTENT]

---

## Error Strategy

### [IMPL-040] Typed Throws vs Preconditions

**Statement**: The boundary between typed throws and preconditions is determined by whether the caller can reasonably check the condition:

| Situation | Mechanism | Example |
|-----------|-----------|---------|
| Caller can check | Typed throw | `guard slot < capacity else { throw .capacityExceeded }` |
| Programming error | Precondition | `pointer(at:)` with invalid slot |

High-level tracked operations (`initialize.next`, `move.last`) throw. Low-level primitives (`pointer(at:)`, `initialize(to:at:)`) precondition.

**Cross-references**: [API-ERR-001]

---

### [IMPL-041] Error Type Nesting

**Statement**: Error types for tracked operations MUST be nested enums following [API-ERR-001]. Cases describe the failure, not the mechanism.

```swift
extension Storage where Element: ~Copyable {
    public enum Error: Swift.Error, Hashable, Sendable {
        case capacityExceeded
        case empty
    }
}
```

**Cross-references**: [API-ERR-001], [API-NAME-001]

---

## Bounded Indexing

### [IMPL-050] Bounded Indices for Static-Capacity Types

**Statement**: Static-capacity types (value-generic `let N: Int`) MUST accept `Index<Element>.Bounded<N>` in subscripts and position-tracking APIs. When the bounded index is produced by the collection's own API, all runtime checks are eliminated — the type proves capacity, and the API proves occupancy.

**Type guarantees**:
- `index >= 0` — structural (Ordinal is non-negative)
- `index < N` — structural (Finite<N> is bounded)

**API guarantee**:
- `index < count` — an index returned by the collection (`index(_:)`, `position(forHash:equals:)`, `forEach.position { }`) is occupied by construction. The collection is the authority on which positions are valid.

**Applies to**: `Hash.Table.Static<N>`, `Set.Ordered.Static<N>`, `Buffer.Linear.Inline<N>`, `Array.Inline<Element, N>`, and all future static-capacity types.

**Perfect** — bounded index from collection API (no runtime check):
```swift
subscript(index: Index<Element>.Bounded<capacity>) -> Element {
    _buffer[index]
}
```

The bounded index was produced by the collection — `index(_:)`, `forEach.position { }`, or `position(forHash:equals:)`. The type proves `index < capacity`; the API proves `index < count`. No runtime check remains.

**Acceptable** — bounded index from external construction, typed throw per [IMPL-040]:
```swift
func element(at index: Index<Element>.Bounded<capacity>) throws(Error) -> Element {
    guard index < count else { throw .unoccupied }
    return _buffer[index]
}
```

**Imperfect** — unbounded index, 3 preconditions:
```swift
subscript(index: Index<Element>) -> Element {
    precondition(index >= .zero)       // ❌ Redundant — Ordinal is non-negative
    precondition(index < capacity)     // ❌ Provable at compile time with Bounded<N>
    precondition(index < count)        // ❌ Precondition where typed throw fits [IMPL-040]
    return _buffer[index]
}
```

For bounded index type structure and available operations, see [INFRA-105].

**Cross-references**: [IMPL-002], [IMPL-004], [IMPL-040], [IMPL-052], [INFRA-105]

---

### [IMPL-051] Bounded Construction: Narrowing and Widening

**Statement**: Narrowing (unbounded → bounded) MUST return `Optional` — the value may exceed the bound. Widening (bounded → unbounded) is always safe. These are the only two conversion directions between `Index<Element>` and `Index<Element>.Bounded<N>`.

**Narrowing** (checked, returns Optional):
```swift
let bounded: Index<Element>.Bounded<16>? = .init(index)
```

**Widening** (safe, always succeeds):
```swift
let index: Index<Element> = .init(bounded)
```

**Literal construction** (statically known values):
```swift
let position: Index<Element>.Bounded<16> = 0
```

**Imperfect** — raw-value chain construction:
```swift
let position: Index<Element>.Bounded<8> = .init(Index<Element>(Ordinal(UInt(i))))!
```

Per [IMPL-000]: if narrowing from runtime values requires chaining through `Ordinal` and `Index` constructors, that is an infrastructure gap. The ideal expression is direct narrowing from the runtime source.

**Cross-references**: [IMPL-000], [IMPL-003], [PATTERN-019]

---

### [IMPL-052] Bounded Index Flow Through APIs

**Statement**: Methods on static-capacity types that accept, return, or pass positions to closures MUST use `Index<Element>.Bounded<N>`, not unbounded `Index<Element>`. The compile-time bound MUST propagate to every call site that touches a position. Unbounded index variants MUST NOT co-exist alongside bounded variants on the same type — bounded is the sole public API, not an overload. When remediating, the fix is subtractive (remove unbounded) not additive (add bounded alongside).

**Perfect** — bounded flows end-to-end:
```swift
// Accept bounded
public mutating func insert(
    position: Index<Element>.Bounded<capacity>,
    hashValue: Hash.Value,
    equals: (Index<Element>.Bounded<capacity>) -> Bool
) -> Bool

// Return bounded
public func index(_ element: Element) -> Index<Element>.Bounded<capacity>?

// Iterate bounded
public func position(_ body: (Index<Element>.Bounded<capacity>) -> Void)

// Accept bounded for mutation
public mutating func decrement(after position: Index<Element>.Bounded<capacity>)
```

**Imperfect** — bound lost at API boundary:
```swift
public mutating func insert(
    position: Index<Element>,           // ❌ Capacity bound lost
    hashValue: Hash.Value,
    equals: (Index<Element>) -> Bool    // ❌ Caller must re-validate
) -> Bool
```

**Rationale**: A static-capacity type *knows* all stored positions are within [0, N). Exposing `Index<Element>` instead of `Index<Element>.Bounded<N>` discards this knowledge, forcing every consumer to re-establish it at runtime.

**Cross-references**: [IMPL-050], [IMPL-006], [IMPL-010]

---

### [IMPL-053] Bounded Arithmetic Follows [IMPL-000]

**Statement**: Arithmetic on `Index<Element>.Bounded<N>` MUST follow [IMPL-000] call-site-first design. The ideal expression operates directly on the bounded index. If a bounded arithmetic operation requires `.rawValue` extraction and `__unchecked` reconstruction, that is an infrastructure gap — not a workaround to accept.

**Ideal call-site expressions**:
```swift
let next = position.successor()              // Index<Element>.Bounded<N>?
let prev = position.predecessor()            // Index<Element>.Bounded<N>?
let shifted = position.offset(by: 2)         // Index<Element>.Bounded<N>?
let mirror = position.complement()           // Index<Element>.Bounded<N>
```

**Imperfect** — raw-value escape:
```swift
let next = position.rawValue.successor()
    .map { Index<Element>.Bounded<8>(__unchecked: (), $0) }
// ❌ [IMPL-002] rawValue extraction at call site
// ❌ [PATTERN-017] __unchecked construction at call site
```

**Current infrastructure gap**: `Ordinal.Finite<N>` provides `successor()`, `predecessor()`, `offset(by:)`, `complement()`, `injected()`, and `projected()` — but these are constrained to `where Tag == Finite.Bound<N>, RawValue == Ordinal`. They do not resolve on `Index<Element>.Bounded<N>` where `Tag == Element` and `RawValue == Ordinal.Finite<N>`. Per [IMPL-000], this gap MUST be filled by lifting these operations to the outer `Tagged` layer.

**Bounded arithmetic is total**: All advancement operations (`successor`, `predecessor`, `offset`) return `Optional`. This is principled — see [IMPL-001]. A non-Optional `bounded + .one` would hide overflow past the capacity bound.

**Cross-references**: [IMPL-000], [IMPL-001], [IMPL-002], [PATTERN-017]

---

## Absorbed Anti-Patterns

The following rules are absorbed from the former `anti-patterns` skill. Each describes imperfect code that violates a principle above.

### [PATTERN-009] No Foundation Types

**Statement**: Primitive and standard packages MUST NOT use Foundation types.

**Rationale**: Foundation prevents Swift Embedded deployment and introduces platform-specific behavior.

**Cross-references**: [PRIM-FOUND-001]

---

### [PATTERN-010] Nested Type Names

**Statement**: Types MUST use nested namespaces, not compound names.

**Cross-references**: [API-NAME-001]

---

### [PATTERN-011] Typed Error Enums

**Statement**: Errors MUST be typed enums with associated values, not string-based errors.

**Cross-references**: [API-ERR-001], [IMPL-041]

---

### [PATTERN-012] Initializers as Canonical Implementation

**Statement**: Canonical implementation for type transformations MUST live in initializers or static methods on the target type. Instance methods are convenience wrappers only.

---

### [PATTERN-013] Concrete Types Before Abstraction

**Statement**: Protocols MUST NOT be designed before having 3+ concrete conformers.

---

### [PATTERN-015] Macro Naming Exception

**Statement**: Swift macros MUST use compound names at file scope (language limitation overrides [API-NAME-001]).

---

### [PATTERN-016] Conscious Technical Debt

**Statement**: Code violating a pattern MAY be acceptable when intentional, documented, bounded, and has specific removal criteria.

**Required documentation**:
```swift
// WORKAROUND: [What this works around]
// WHY: [Why normal approach doesn't work]
// WHEN TO REMOVE: [Specific removal criteria]
// TRACKING: [Issue URL or internal reference]
```

---

### [PATTERN-017] rawValue and Property Access Location

**Statement**: `.rawValue` and `.position` MUST be confined to extension initializers and same-package implementations. Call-sites MUST use higher-level APIs.

**Cross-references**: [IMPL-002], [CONV-001]

---

### [PATTERN-018] No Escaping to Int for Arithmetic

**Statement**: Arithmetic MUST use typed operators. `Int(bitPattern:)` is a last-resort escape hatch for interop only.

**Valid uses**: C interop, Standard Library APIs, debug output. Never for computation.

**Cross-references**: [IMPL-002], [IMPL-010]

---

### [PATTERN-019] No Blanket Tagged Init Constructors

**Statement**: Extensions on `Tagged where RawValue == T` MUST NOT provide public `init`. Such inits bypass bounded type invariants.

**Cross-references**: [IMPL-001]

---

### [PATTERN-020] No False-Security Throwing Inits

**Statement**: A throwing init on a wrapper type MUST NOT validate only the base type's invariant when the wrapper may specialize to types with stricter invariants.

**Cross-references**: [PATTERN-019]

---

### [PATTERN-021] Prefer Typed Arithmetic over __unchecked

**Statement**: When a typed arithmetic operator exists for a conversion, it MUST be preferred over `__unchecked` with rawValue extraction.

**Cross-references**: [IMPL-002], [IMPL-003]

---

### [PATTERN-022] ~Copyable Nested Types in Separate Files

**Statement**: Nested types inside `~Copyable`-generic parents MUST be defined in separate files via `extension Parent where Element: ~Copyable { }`, following [API-IMPL-005] (one type per file).

**History**: Prior to Swift 6.2.4, constraint poisoning prevented this — the compiler inferred `Copyable` on the generic parameter in cross-file extensions. This is fixed in Swift 6.2.4+. The `where Element: ~Copyable` constraint on the extension is the mechanism that makes it work.

**Pattern**:
```swift
// File: Namespace.swift
public enum Namespace<Element: ~Copyable> {}

// File: Namespace.NestedData.swift
extension Namespace where Element: ~Copyable {
    public enum NestedData: Sendable, Equatable { ... }
}

// File: Namespace.NestedHeap.swift
extension Namespace where Element: ~Copyable {
    public final class NestedHeap: ManagedBuffer<...> { ... }
}

// File: Namespace.NestedInline.swift
extension Namespace where Element: ~Copyable {
    public struct NestedInline<let N: Int>: ~Copyable { ... }
}
```

**Conditional conformances** can live in the same file as their type or in a dedicated conformances file:
```swift
extension Namespace.NestedInline: @unchecked Sendable where Element: Sendable {}
```

**Deeply nested types** use extensions on the intermediate parent:
```swift
// File: Namespace.NestedHeap.Cyclic.swift
extension Namespace.NestedHeap where Element: ~Copyable {
    public struct Cyclic<let capacity: Int>: Copyable, Sendable { ... }
}
```

**Validated**: buffer-primitives `Buffer.swift` — all ~50 nested types moved to separate extensions, 391 tests pass (Swift 6.2.4).

**Cross-references**: [API-IMPL-005], [API-IMPL-008], [MEM-COPY-006]

---

## Absorbed Design Patterns

The following rules are absorbed from the former `design` skill.

### [API-LAYER-001] Explicit Target Layers

**Statement**: Code MUST be designed in layers, each depending only on layers below it.

Typical shape:

1. **Primitives** — Minimal tokens, IDs, events, handles. Zero policy, zero platform choice.
2. **Driver / backend contracts** — Capability interfaces, leaf errors, stable testable contracts.
3. **Platform backends** — kqueue, epoll, IOCP, etc.
4. **Runtime orchestration** — Lifecycles, scheduling, cancellation, cross-thread coordination.
5. **User-facing convenience** — Ergonomic wrappers, default policies, platform factories.

| Question | Expected Answer |
|----------|-----------------|
| Depends only on layers below? | Yes |
| Can be tested in isolation? | Yes |
| Avoids lifecycle policy? | Yes (for primitives) |
| Errors typed and layer-appropriate? | Yes |
| Platform backends swappable? | Yes (for abstractions) |

---

### [PATTERN-052] @usableFromInline Access Level for Cross-Module Inlining

**Statement**: `@inlinable` functions that reference internal types or properties MUST mark those declarations `@usableFromInline`. The access level determines the inlining boundary:

| Declaration | Inlinable Within | Cross-Module Inlinable |
|-------------|-----------------|----------------------|
| `@usableFromInline internal` | Same module only | No |
| `@usableFromInline package` | Same package | Yes (within package) |
| `public` | Everywhere | Yes |

**Correct**:
```swift
// Cross-module inlining required (e.g., primitives consumed by standards)
@usableFromInline package var _storage: RawValue

@inlinable
public var value: RawValue { _storage }
```

**Incorrect**:
```swift
@usableFromInline internal var _storage: RawValue  // ❌ Cannot inline cross-module

@inlinable
public var value: RawValue { _storage }  // Compiler error in consuming module
```

**Rationale**: `@usableFromInline internal` enables inlining only within the declaring module. Cross-package `@inlinable` access requires `package` or `public` visibility.

---

### [PATTERN-053] Prefer Primitives Types Over Local Equivalents

**Statement**: Packages MUST use primitives-layer types for common concepts (source location, error wrapping, indices) rather than defining local equivalents. When an existing primitives type covers the concept, import and use it. This rule is a specific instance of [IMPL-060].

**Correct**:
```swift
import Text_Primitives

// Use existing Text.Location from primitives
func report(at location: Text.Location) { }
```

**Incorrect**:
```swift
// ❌ Reinventing a type that already exists in primitives
struct SourceLocation {
    var line: Int
    var column: Int
}
```

**Detection**: During code review, if a type has the same fields and semantics as an existing primitives type, it is a duplication candidate. Unify via import, not via typealias indirection.

**Rationale**: Local equivalents create conversion overhead, type incompatibility across packages, and maintenance burden. Primitives exist to be consumed.

**Cross-references**: [IMPL-060], [API-LAYER-001]

---

### [PATTERN-025] Type Erasure vs Sendable Tension

**Statement**: Type erasure mechanisms (raw pointers, `Unmanaged`, unsafe bitcasts) are explicitly non-Sendable in Swift 6. When type erasure is required for heterogeneous storage, the composition with Sendable-requiring primitives creates a tension that MUST be resolved explicitly.

| Approach | Trade-off |
|----------|-----------|
| Sendable wrapper (`Reference.Pointer`) | Encapsulates unsafety in one place |
| Accept limitation | Some compositions aren't possible without unsafe opt-in |
| `@unchecked Sendable` at use site | Makes unsafety visible but scattered |

**Cross-references**: [PATTERN-021]

---

### Semantic Dependencies

For detailed rules on semantic vs implementation dependencies, see `Documentation.docc/Semantic Dependencies.md`.

| Rule | Statement |
|------|-----------|
| [SEM-DEP-006] | Distinguish essential vs incidental relationships; only essential creates SDG edges |
| [SEM-DEP-008] | Join-point packages resolve conflicts where two domains have mutual relevance |
| [SEM-DEP-009] | Package dependencies MUST be essential; orthogonal integrations require separate packages |

---

### [IMPL-061] Compiler Fix Over Workaround Accumulation

**Statement**: When a bug is traced to the compiler (or another external dependency whose source is available), investigating a source-level fix SHOULD be attempted before exhaustively exploring code-level workarounds. Compiler fixes are typically smaller and address the root cause; workarounds accumulate complexity proportional to the bug's blast radius across the ecosystem.

**Decision procedure**:

| Question | If Yes | If No |
|----------|--------|-------|
| Is the bug in the compiler/runtime? | Consider a compiler fix | Fix in application code |
| Is the compiler source available? | Investigate the relevant pass | Workaround is the only option |
| Does the bug affect >5 sites? | Compiler fix has high ROI | Localized workaround may suffice |
| Is the workaround cascade growing? | Stop — fix the compiler | Single workaround is acceptable |

**Workaround cascade signal**: When each workaround for a compiler bug introduces a new constraint that requires another workaround (e.g., enum wrapper → can't `_modify` payload → struct wrapper → triggers same crash), the workaround axis is wrong. The structural fix is at the compiler level, not the code level.

**Cross-references**: [EXP-011], [EXP-018]

---

### [IMPL-062] Prefer `nonisolated(nonsending)` Over `isolation:` Parameters

**Statement**: Async methods that need to inherit the caller's isolation MUST use `nonisolated(nonsending)` on the method declaration rather than an `isolation: isolated (any Actor)? = #isolation` parameter. The `isolation:` parameter pattern is deprecated in the Swift stdlib.

**Correct**:
```swift
nonisolated(nonsending)
public func map<U>(_ transform: (Value) throws -> U) async rethrows -> U {
    try transform(await self())
}
```

**Incorrect**:
```swift
public func map<U>(
    isolation: isolated (any Actor)? = #isolation,  // ❌ Deprecated pattern
    _ transform: (Value) throws -> U
) async rethrows -> U { ... }
```

**Exception**: SE-0421 protocol conformances (e.g., `AsyncIteratorProtocol.next(isolation:)`) MUST retain the `isolation:` parameter to satisfy the protocol requirement.

**Provenance**: Reflection `2026-03-22-nonsending-compiler-discovery-and-ecosystem-migration.md`.

**Cross-references**: [MEM-SEND-001]

---

### [IMPL-063] Ownership Subsumes Synchronization

**Statement**: When a type is `~Copyable` with `mutating` methods, the compiler guarantees exclusive access at the call site. Adding actors, atomics, or locks to protect stored state within such a type introduces synchronization mechanism for a concurrency problem that does not exist. Stored state on a `~Copyable` type with `mutating` access MUST use plain stored properties, not synchronization primitives.

**Decision procedure**:

| Question | If Yes | If No |
|----------|--------|-------|
| Is the type `~Copyable`? | Continue | Synchronization may be needed |
| Are the relevant methods `mutating` or `consuming`? | Ownership guarantees exclusive access | `borrowing` methods allow shared access — synchronization may be needed |
| Is the state accessed from multiple isolation domains? | Not possible — `~Copyable` + `mutating` prevents aliasing | — |

**Correct**:
```swift
struct Channel: ~Copyable {
    var closeState: HalfClose.State  // Plain stored property — ownership is the synchronization

    mutating func close(_ half: HalfClose) { closeState.close(half) }
}
```

**Incorrect**:
```swift
struct Channel: ~Copyable {
    let lifecycle = Lifecycle()  // ❌ Actor for state that ownership already protects

    mutating func close(_ half: HalfClose) async { await lifecycle.close(half) }
}
```

**Detection**: During code review, any `~Copyable` type that contains an actor, `Atomic`, `Mutex`, or `OSAllocatedUnfairLock` for internal state is a candidate for simplification. The synchronization primitive can be replaced with a plain stored property if all access paths are `mutating` or `consuming`.

**Rationale**: Actors introduce async hops, atomics introduce memory barriers, and locks introduce contention — all to solve a problem that the ownership system already prevents. Removing unnecessary synchronization eliminates per-call overhead (e.g., 3x write throughput improvement when replacing an actor with a stored property in swift-io's Channel).

**Provenance**: Reflection `2026-03-26-channel-lifecycle-actor-removal-ownership-as-synchronization.md`.

**Cross-references**: [MEM-COPY-001], [IMPL-INTENT]

---

## Post-Implementation Checklist

Before presenting code as complete, verify EACH item:

- [ ] No `.rawValue` chains at call sites — use typed operators [IMPL-002]
- [ ] No `Int(bitPattern:)` at call sites — push to boundary overloads [IMPL-010]
- [ ] No intermediate variables that merely restate expressions [IMPL-EXPR-001]
- [ ] Ecosystem types used where available — no ad-hoc reimplementations [IMPL-060]
- [ ] Property.View used for verb-as-property patterns — no hand-rolled structs [IMPL-020/021]
- [ ] Bounded indices for static-capacity types [IMPL-050]

If ANY item fails, fix before presenting.

---

## Cross-References

See also:
- **conversions** skill for [IDX-*], [CONV-*] type definitions and conversion APIs
- **code-surface** skill for [API-NAME-*], [API-ERR-*], [API-IMPL-*] naming, errors, file structure
- **memory-safety** skill for [MEM-*] ownership patterns
- **advanced-patterns** skill for [PATTERN-026] centralization, memory ownership, unsafe operation patterns
- **testing** skill for [TEST-018] literal conformances in tests
- **existing-infrastructure** skill for [INFRA-*] catalog of typed operations, integration modules, and principled absences
- **Semantic Dependencies.md** for [SEM-DEP-*] dependency classification rules
- `Ordinal.Finite<N>` in swift-finite-primitives for bounded ordinal arithmetic infrastructure
- `Index.Bounded.swift` in swift-finite-primitives for the typealias definition and narrowing/widening
