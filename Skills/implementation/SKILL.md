---
name: implementation
description: |
  Intent-over-mechanism and compiler-enforced strictness as dual foundational
  axioms. Expression-first style, call-site-first design, typed arithmetic,
  boundary overloads, property accessors, ownership-first type design,
  isolation hierarchy. Absorbs anti-patterns and design patterns.
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
last_reviewed: 2026-04-15
---

# Implementation

Every line of implementation code reads as intent — and is verified by the compiler.

---

## Foundational Axioms

### [IMPL-INTENT] Code Reads as Intent, Not Mechanism

**Statement**: All implementation code MUST read as a declaration of *what* is being accomplished, never as a description of *how* the machine accomplishes it. This is the governing principle of the entire skill. Every other rule is a corollary.

- If a line describes *what* happens → intent. Keep it.
- If a line describes *how* it happens → mechanism. Refactor it.

**Intent** is the domain operation: initialize, move, copy, insert, remove, count, compare, iterate.
**Mechanism** is the implementation machinery: offset computation, pointer arithmetic, raw value extraction, bitPattern conversion, closure scaffolding, manual index construction.

Mechanism belongs inside infrastructure (operators, overloads, accessors, boundary methods). Intent belongs at call sites. When mechanism leaks into a call site, the infrastructure is incomplete.

**Cross-references**: [Research: intent-over-mechanism-expression-first.md]

---

### [IMPL-000] Call-Site-First Design

**Statement**: Write the ideal expression first. If the infrastructure doesn't support it, improve the infrastructure — unless the absence is principled (see [IMPL-001]).

1. **If it compiles** → done.
2. **If it doesn't compile** → is the absence principled?
   - **Yes** → rethink the expression. The type system is telling you something.
   - **No** → improve the infrastructure:

| What's missing | Where to add it |
|----------------|----------------|
| Operator (`+`, `-`, `<`) | Arithmetic primitives for the type |
| Stdlib overload (`initialize`, `distance`) | Stdlib integration layer (e.g., affine-primitives) |
| Accessor (`.pointer(at:)`, `.span`) | The type itself |
| Property.View tag | Tag enum + `Property` extension |
| Iteration (`.forEach`, `.reduce`) | The collection/enum type |
| Transformation (`.map.bounds`) | Range/collection primitives |

After improving infrastructure, all other call sites also benefit. The infrastructure serves the expression — not the other way around.

---

### [IMPL-001] Principled Absences

**Statement**: Before adding missing infrastructure, verify the absence is not principled. An absence is principled when the operation would violate mathematical properties, type-theoretic foundations, or established design constraints.

**Principled — do NOT add:**

| You want to write | Why it doesn't exist | What to write instead |
|---|---|---|
| `count - count` with `-` | Subtraction on naturals isn't total | `count.subtract.saturating(other)` or `try count.subtract.exact(other)` |
| `index * 2` | Indices are ordinals; scaling a position is meaningless | Rethink: do you mean `offset * 2`? |
| `bounded + .one` returning `Bounded<N>` | Addition on bounded ordinal is partial | `bounded.successor()` (returns `Optional`) |

For the complete catalog of principled absences, see [INFRA-200].

**Gap — DO add:**

| You want to write | Why it should exist | Where to add it |
|---|---|---|
| `count + .one` | `Cardinal + Cardinal → Cardinal` is total | cardinal-primitives |
| `pointer.initialize(from:count: typedCount)` | Valid operation; only the `Int` bridge is missing | affine-primitives stdlib integration |
| `slot < capacity` (Index vs Count) | Comparison is well-defined between position and size | ordinal-primitives |

**The test**: Does the operation preserve the mathematical properties of the types involved? If it would make a partial operation look total, mix dimensions, or violate affine space rules — the absence is a feature.

**Cross-references**: [CONV-010], [MEM-ARITH-001]

---

### [IMPL-COMPILE] Compiler as Primary Correctness Mechanism

**Statement**: Code MUST be written so the compiler enforces as many correctness properties as possible at compile time. Every invariant expressible in the type system MUST be expressed there, not verified at runtime.

This is the dual of [IMPL-INTENT]: intent-over-mechanism governs *how code reads*; compiler-as-enforcer governs *what the compiler proves*.

**Corollaries**:

| Invariant | Mechanism | Rule |
|-----------|-----------|------|
| Resource has exactly-once lifecycle | `~Copyable` | [IMPL-064] |
| View must not outlive its source | `~Escapable` | [IMPL-065] |
| Value crosses isolation boundary | `sending` | [IMPL-066] |
| Parameter ownership semantics | `consuming` / `borrowing` / `inout` | [IMPL-067] |
| Type does not need thread sharing | Non-`Sendable` by default | [IMPL-068] |
| Concurrency mechanism selection | Isolation hierarchy | [IMPL-069] |
| ~Copyable ownership through locks | Coroutine accessor or layer model | [IMPL-070] |
| Interior mutability from let binding | `nonmutating _modify` | [IMPL-071] |
| Error domain | Typed throws | [API-ERR-001] |
| Capacity bound | `Bounded<N>` | [IMPL-050] |
| Unsafe operation boundary | `@safe` / `@unsafe` | [MEM-SAFE-020] |

**The question at every declaration**: *"Is there a compile-time constraint I could add that would make a class of runtime bugs impossible?"*

---

## Dependency Strategy

### [IMPL-060] Ecosystem Dependencies Over Ad-Hoc Implementation

**Statement**: When the ecosystem provides a type, operation, or infrastructure at any layer, it MUST be used via dependency rather than reimplemented. "Minimizing dependencies" is NOT a valid reason to reimplement what the ecosystem provides.

| Question | If Yes | If No |
|----------|--------|-------|
| Does the ecosystem provide this type/operation? | Import and use it | Implement it |
| Does importing it violate tier constraints? | Investigate: wrong tier, or need join-point | Import it |
| Is the local version "simpler"? | Still import — simplicity ≠ justification for duplication | — |

**Why**: Ad-hoc reimplementations create type incompatibility, duplicate maintenance, miss upstream improvements, and fragment the ecosystem.

**Cross-references**: [PATTERN-053], [PATTERN-026], [IMPL-000], [API-LAYER-001], [SEM-DEP-009]

---

## Typed Arithmetic

### [IMPL-002] Write the Math, Not the Mechanism

**Statement**: All operations on typed values MUST use typed operators, functors, and comparisons. Raw value extraction (`.rawValue`, `.position`) MUST NOT appear at call sites. This is a direct corollary of [IMPL-INTENT].

| Category | Typed (correct) | Raw (incorrect) |
|----------|-----------------|-----------------|
| **Arithmetic** | `currentCount + .one` | `Cardinal(currentCount.rawValue + 1)` |
| **Functor** [IMPL-003] | `currentCount.map(Ordinal.init)` | `Ordinal(currentCount.rawValue.rawValue)` |
| **Domain crossing** [IMPL-003a] | `offset.retag(Element.self)` then compare | `offset.rawValue < count.rawValue` |
| **Comparison** [IMPL-004] | `slot < base.slotCapacity` | `slot.rawValue < heap.slotCapacity.rawValue` |
| **Min/Max** [IMPL-005] | `Type.min(a, b)` | `Swift.min(a.rawValue, b.rawValue)` |
| **Subtraction** | `count.subtract.saturating(.one)` | `count.rawValue - 1` |

If you find yourself chaining `.rawValue.rawValue`, that's a missing operator. Add it.

**[IMPL-003] Functor Operations**: Cross-domain conversions MUST use `.map()` (transform raw value, preserve tag) or `.retag()` (preserve raw value, change tag). Direct `__unchecked` construction SHOULD be avoided when a functor path exists. See [INFRA-103].

**[IMPL-003a] Domain-Crossing Before Operations**: When an operation requires values from different phantom-typed domains, convert to the target domain first using `.retag()`, then operate. Do NOT extract `.rawValue` as a domain escape hatch. When `Domain` enforcement arrives (via `SuppressedAssociatedTypes`), domain-agnostic operations break.

**[IMPL-006] Typed Stored Properties**: Stored properties holding quantities SHOULD use typed wrappers (`Index<Element>.Count`, `Index<Element>`) rather than raw `UInt`. `Tagged` is zero-cost — same memory layout. Store typed, eliminate N extraction sites.

For canonical constants (`.one`, `.zero`) and their protocol lifting, see [INFRA-101].

**Cross-references**: [CONV-010], [CONV-001], [CONV-003], [IDX-010], [INFRA-101], [INFRA-103]

---

## Boundary Overloads

### [IMPL-010] Push Int to the Edge

**Statement**: `Int(bitPattern:)` conversions MUST live inside boundary overloads, never at call sites. If a stdlib API only accepts `Int`, provide a typed overload that converts internally.

**Perfect** — stdlib boundary is invisible:
```swift
unsafe destination.pointer(at: offset)
    .initialize(from: base.pointer(at: range.lowerBound), count: range.count)
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

**Cross-references**: [CONV-014]

---

### [IMPL-011] Pointer Primitives

**Statement**: Types that manage memory SHOULD provide a `pointer(at: Index<Element>)` method that encapsulates offset computation. All other slot access methods delegate to this primitive.

```swift
let ptr = unsafe storage.pointer(at: slot)  // ✓ Intent
// vs.
let ptr = unsafe withUnsafeMutablePointerToElements { base in  // ✗ Mechanism
    let offset = Index<Element>.Offset(fromZero: slot)
    return unsafe base + offset
}
```

---

### [IMPL-012] Range Bound Transformation

**Statement**: Transforming both bounds of a range MUST use `range.map.bounds { }`, not manual decomposition.

```swift
_slots.set.range(range.map.bounds { $0.retag(Bit.self) })  // ✓
```

**Cross-references**: [IMPL-003]

---

## Property Accessors

### [IMPL-020] Verb-as-Property with callAsFunction

**Statement**: When a type has a verb-like operation namespace, express it as a property returning `Property<Tag, Base>` with `callAsFunction` for the direct operation and named methods for qualified variants.

```swift
heap.initialize(to: element, at: slot)     // callAsFunction — direct
heap.initialize.next(to: element)          // named method — tracked
heap.move(at: slot)                        // callAsFunction — direct
heap.move.last()                           // named method — tracked
heap.deinitialize(at: slot)                // callAsFunction — direct
heap.deinitialize.all()                    // named method — tracked
```

Tag types are empty enums. Methods are extensions on `Property` constrained by `where Tag == ..., Base == ...`. See [INFRA-106].

**Cross-references**: [API-NAME-002], [INFRA-106]

---

### [IMPL-021] Property vs Property.View

**Statement**: Use `Property<Tag, Base>` for Copyable bases (owned access). Use `Property<Tag, Base>.View` for `~Copyable` bases (pointer-based mutable access). MUST NOT hand-roll accessor structs.

| Base type | Use | Accessor pattern |
|-----------|-----|------------------|
| Copyable (struct) | `Property<Tag, Base>` | `var x: Property<Tag, Self> { Property(self) }` |
| ~Copyable (struct) | `Property<Tag, Base>.View` | `var x: ... { mutating _read { yield unsafe ...View(&self) } }` |
| Class-backed | `Property<Tag, Base>` | `var x: Property<Tag, Self> { Property(self) }` — `.View` fails because classes forbid `mutating` accessors |

**Validated by**: `swift-primitives/Experiments/property-view-class-accessor/`

---

### [IMPL-022] _read + _modify for Mutating Property Accessors

**Statement**: When a `Property.View` extension includes **mutating** methods, the accessor property MUST provide both `_read` and `_modify` coroutines. Without `_modify`, the compiler treats the yield as read-only.

```swift
var remove: Property<Remove, Self>.View.Typed<Element> {
    mutating _read  { yield unsafe Property<Remove, Self>.View.Typed(&self) }
    mutating _modify { var view = unsafe Property<Remove, Self>.View.Typed<Element>(&self); yield &view }
}
```

If the extension only has non-mutating methods, `_read` alone is sufficient. The same applies to `.View.Typed.Valued` for value-generic types.

**Cross-references**: [IMPL-021], [API-NAME-002]

---

### [IMPL-026] Property.View Protocol Delegation

**Statement**: When a `~Copyable` protocol's conformers share Property.View operations with identical semantics, the accessors and Property.View methods MUST be provided as protocol defaults. Per-type accessors MUST NOT duplicate the default. Per-type extensions MAY add type-specific methods that coexist.

```swift
// Protocol provides defaults — all conformers get pop.first() automatically
extension MyProtocol where Self: ~Copyable {
    public var pop: Property<Pop, Self>.View {
        mutating _read { yield unsafe Property<Pop, Self>.View(&self) }
        mutating _modify { var view = unsafe Property<Pop, Self>.View(&self); yield &view }
    }
}
extension Property.View where Tag == Pop, Base: MyProtocol & ~Copyable {
    public func first() -> Index? { unsafe base.pointee.popFirst() }
}
```

**Compiler constraints**: (1) `where Self: ~Copyable` on protocol extensions — required. (2) `Base: Protocol & ~Copyable` on Property.View extensions — required for both Copyable and ~Copyable conformers. (3) Per-type overrides with identical body are redundant — remove them.

**Semantic boundary**: Applies when operations are expressible purely through protocol requirements with identical semantics. Does NOT apply when operations check type-specific state, return types differ, or require type-specific initializers.

**Compiler limitation**: Protocol type inference fails with `~Copyable Element` in `_read`/`_modify` coroutine accessors provided by protocol extensions. The protocol default compiles but conformers cannot resolve the Element type through the coroutine. Status: OPEN, present in Swift 6.3.

**Validated by**: `swift-institute/Experiments/property-view-pattern/`, `protocol-coroutine-accessor-limitation/`

**Cross-references**: [IMPL-020], [IMPL-021], [IMPL-022]

---

## Static Method Architecture

### [IMPL-023] Core Logic in Static Methods

**Statement**: Types with `~Copyable` generic parameters needing both `~Copyable` and `Copyable` overloads MUST place core logic in static methods. Instance methods delegate to statics. This eliminates Swift's overload recursion problem.

**The problem**: Two extensions with same method name, different constraints — the more-constrained overload calling `self.method()` resolves to itself, producing infinite recursion.

**The solution**: Statics are called on the type, not `self`, so overload resolution cannot recurse. See [INFRA-110].

**Static signature pattern**: Statics take decomposed state as parameters (e.g., `state: inout State`, `storage: Storage`). Methods that replace `self` as a whole (growth, CoW) remain as instance methods.

**Validated by**: `swift-buffer-primitives/Experiments/static-property-view-pattern/`

**Cross-references**: [IMPL-020], [IMPL-024], [IMPL-025], [API-NAME-002]

---

### [IMPL-024] Compound Identifiers in the Static Layer

**Statement**: Static methods (implementation layer) MAY use compound names. The public API layer MUST NOT — it uses Property.View nested accessors per [API-NAME-002].

| Layer | Audience | Naming | Example |
|-------|----------|--------|---------|
| Static | Package author | Compound allowed | `MyType.insertFront(_:state:storage:)` |
| Property.View | Consumer | Nested required | `instance.insert.front(element)` |

**Cross-references**: [API-NAME-002], [IMPL-023], [INFRA-110], [INFRA-106]

---

### [IMPL-025] Two-Tier Overload Resolution

**Statement**: Types supporting both `~Copyable` and `Copyable` elements MUST provide two tiers of public methods. Both delegate to the same static. The `Copyable` tier adds preparation logic (e.g., CoW uniqueness checks). Neither tier calls `self.method()`. See [INFRA-110].

**Cross-references**: [IMPL-023], [MEM-COPY-006]

---

## Expression Style

### [IMPL-EXPR-001] Prefer Single Expressions Over Intermediate Bindings

**Statement**: Implementation code MUST prefer single-line expressions over separate `let`/`var` declarations and inline construction over intermediate variables. Subsumes [IMPL-030].

**Boundary conditions** (the only valid reasons for an intermediate binding):

1. **Multi-use**: The sub-expression is consumed more than once.
2. **Explanatory name**: The name communicates domain knowledge not visible in the expression.
3. **Complexity ceiling**: Extract a named function (Fowler's "Replace Temp with Query"), not a local variable.

**Perfect** — single expression reads as intent:
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

**Cross-references**: [IMPL-INTENT]

---

### [IMPL-033] Iteration: Intent Over Mechanism

**Statement**: Iteration MUST use the highest-level abstraction that expresses intent. Subsumes [IMPL-031] (enum iteration) and [IMPL-032] (bulk operations).

| Level | Style | When |
|-------|-------|------|
| **1. Bulk operation** | `set.range()`, `deinitialize(count:)` | Uniform operation on a range |
| **2. Iteration infra** | `.forEach { }`, `.reduce.into { }`, `.linearize { }` | Per-element logic |
| **3. Typed while loop** | `while slot < end { slot += .one }` | Inside iteration infra only |
| **4. Raw while loop** | Forbidden | Never |

When no iteration infrastructure exists: per [IMPL-000], add `.forEach`, `.reduce`, or the appropriate method, then use it. See [INFRA-107], [INFRA-108], [INFRA-022].

---

### [IMPL-034] unsafe Keyword Placement

**Statement**: `unsafe` MUST wrap the entire expression from the left. It cannot appear to the right of a non-assignment binary operator.

```swift
guard unsafe slot < base.pointee.slotCapacity else { throw .capacityExceeded }  // ✓
guard slot < unsafe base.pointee.slotCapacity else { ... }                       // ✗
```

---

### [IMPL-035] Uniform Execution Model

**Statement**: When computation is deferred to a work queue or stack, ALL items at the same structural level MUST use the same execution model. Mixing immediate and deferred execution creates ordering violations invisible at the dispatch site.

**Cross-references**: [IMPL-INTENT]

---

### [IMPL-036] Minimal Storage for Deferred Computation

**Statement**: When ownership prevents storing a computed value (`~Copyable` or `~Escapable`), store the minimum necessary to *recompute* it. The storable unit is typically the source (often `Copyable`) rather than the result (often `~Copyable`). Generalized: when you cannot store X, find Y where X = f(Y) and store Y.

**Cross-references**: [MEM-COPY-005], [MEM-COPY-012]

---

### [IMPL-037] String Interpolation as Type Bridge

**Statement**: When a type conforms to `ExpressibleByStringLiteral` and also has `init(_:) throws`, Swift selects the literal conformance unconditionally — even inside `try`. The non-throwing bridge for String variables is interpolation: `"\(stringVar)"`.

---

## Error Strategy

### [IMPL-040] Typed Throws and Error Types

**Statement**: The boundary between typed throws and preconditions is determined by whether the caller can reasonably check the condition. Subsumes [IMPL-041].

| Situation | Mechanism | Example |
|-----------|-----------|---------|
| Caller can check | Typed throw | `guard slot < capacity else { throw .capacityExceeded }` |
| Programming error | Precondition | `pointer(at:)` with invalid slot |

High-level tracked operations (`initialize.next`, `move.last`) throw. Low-level primitives (`pointer(at:)`, `initialize(to:at:)`) precondition.

Error types for tracked operations MUST be nested enums per [API-ERR-001]. Cases describe the failure:

```swift
extension Storage where Element: ~Copyable {
    public enum Error: Swift.Error, Hashable, Sendable {
        case capacityExceeded
        case empty
    }
}
```

**Cross-references**: [API-ERR-001], [API-NAME-001], [IMPL-042]

---

### [IMPL-042] Non-Throwing Specialization for Generic Callback APIs

**Statement**: When a public API propagates a user-supplied typed error through a generic parameter (a closure `throws(E)` or a protocol witness with `associatedtype Failure: Error`) and the callback is invoked in a hot path, the API MUST provide a specialized overload constrained to `Failure == Never`. The specialized overload MUST duplicate the implementation body — it MUST NOT forward to the generic version.

**Problem**: Typed throws with a *generic* error parameter cannot always be specialized away by the compiler. Even when the caller binds the parameter to `Never`, a generic outer type (e.g. `struct Parser<Sink: Handler>` where `Handler.Failure` is the propagated error) hides the binding from the body's codegen. The callee retains error-propagation scaffolding — boxing, spill slots, and cleanup edges that can never execute — and the hot path pays for machinery it does not use.

**Solution**: Duplicate the hot-path body under a `where` clause that fixes the propagated error to `Never`. Because the duplicated body is compiled in a context where the error type is *concrete*, the compiler eliminates the propagation scaffolding entirely. This is a direct application of [IMPL-COMPILE]: the invariant "this callback cannot throw" is expressed where the compiler can act on it.

```swift
public struct Parser<Sink: SAX.Handler> {
    // Generic body — propagates Sink.Failure through the per-token loop.
    public mutating func parse(bytes: Span<Byte>) throws(Parse.Error) {
        /* full body */
    }
}

extension Parser where Sink.Failure == Never {
    // Duplicated body — compiled with no error propagation through callbacks.
    public mutating func parse(bytes: Span<Byte>) throws(Parse.Error) {
        /* full body — NOT `try self.parseGeneric(bytes:)` */
    }
}
```

**Why not forward**: A `where Failure == Never` overload whose body is `try self.genericParse(bytes:)` does not specialize. The forwarded call resolves to the generic entry point, which still carries the propagation scaffolding. Specialization requires the body itself to be visible in the specialized context.

**When to apply**:

| Condition | Required |
|-----------|----------|
| Callback is invoked in a tight loop or per-element/per-token | Yes |
| Benchmarks attribute measurable cost to error propagation | Yes |
| Body is stable enough that duplication is maintainable | Yes |

If any condition fails, the duplication is unjustified — see [IMPL-001] (principled absence: no hot path, no specialization).

**Duplication hygiene**: Because the two bodies MUST stay in lockstep, place them in adjacent files or adjacent sections of the same file, mark the duplicate with a `// WHY:` comment per [PATTERN-016] that names the optimization and warns against folding, and verify SIL before merging.

**Provenance**: `compnerd/xylem` `Sources/SAXParser/SAXParser.swift:309` — the duplicated `parse(bytes:)` under `where Processor.Failure == Never` eliminates per-callback error boxing in the SAX hot loop. The source comment at line 313 explicitly warns: *"The body is intentionally duplicated from the generic overload so the compiler can eliminate per-callback error boxing when Failure == Never. Do not fold the two paths together without measuring SIL."*

**Cross-references**: [API-ERR-001], [IMPL-001], [IMPL-040], [IMPL-COMPILE], [PATTERN-016], [BENCH-*]

---

## Bounded Indexing

### [IMPL-050] Bounded Indices for Static-Capacity Types

**Statement**: Static-capacity types (`let N: Int`) MUST accept `Index<Element>.Bounded<N>` in subscripts and position-tracking APIs. The bounded type encodes capacity at compile time; the collection's API proves occupancy. Subsumes [IMPL-051], [IMPL-052], [IMPL-053].

**Type guarantees**: `index >= 0` (structural — Ordinal is non-negative), `index < N` (structural — Finite<N> is bounded).

**API guarantee**: An index returned by the collection (`index(_:)`, `position(forHash:equals:)`, `forEach.position { }`) is occupied by construction.

**Narrowing and widening** [IMPL-051]:
- Narrowing (unbounded → bounded): returns `Optional` — value may exceed bound.
- Widening (bounded → unbounded): always safe.
- Literal construction: `let pos: Index<Element>.Bounded<16> = 0`.

**API flow** [IMPL-052]: Methods on static-capacity types that accept, return, or pass positions MUST use `Index<Element>.Bounded<N>`. Unbounded variants MUST NOT co-exist alongside bounded variants — bounded is the sole public API. When remediating, the fix is subtractive (remove unbounded) not additive (add bounded alongside).

**Arithmetic** [IMPL-053]: Arithmetic on bounded indices follows [IMPL-000]. All advancement operations (`successor`, `predecessor`, `offset`) return `Optional` — principled per [IMPL-001]. If bounded arithmetic requires `.rawValue` extraction and `__unchecked` reconstruction, that is an infrastructure gap.

For bounded type structure and operations, see [INFRA-105].

**Cross-references**: [IMPL-000], [IMPL-001], [IMPL-002], [IMPL-006], [IMPL-010], [INFRA-105]

---

## Absorbed Patterns

Rules absorbed from former `anti-patterns` and `design` skills. Rules whose canonical home is another skill have been removed — see the Skill Index in [`swift-institute-core`](../swift-institute-core/SKILL.md) for the routing table.

### Anti-Pattern Reference

| ID | Statement | Cross-ref |
|----|-----------|-----------|
| [PATTERN-012] | Canonical implementation for type transformations MUST live in initializers or static methods on the target type | — |
| [PATTERN-013] | Protocols MUST NOT be designed before having 3+ concrete conformers; even with 3+ conformers, if unification would force axis-divergent signatures to lose information, concrete sibling types are preferred (lossy-unification criterion) | [IMPL-084], [IMPL-090] |
| [PATTERN-016] | Code violating a pattern MAY be acceptable when intentional, documented (`// WORKAROUND:`, `// WHY:`, `// WHEN TO REMOVE:`, `// TRACKING:`), bounded, and has specific removal criteria | — |
| [PATTERN-017] | `.rawValue` and `.position` MUST be confined to extension initializers and same-package implementations | [IMPL-002], [CONV-001] |
| [PATTERN-019] | Extensions on `Tagged where RawValue == T` MUST NOT provide public `init` — bypasses bounded invariants | [IMPL-001] |
| [PATTERN-020] | A throwing init on a wrapper MUST NOT validate only the base type's invariant when the wrapper specializes to stricter types | [PATTERN-019] |
| [PATTERN-054] | When tempted to invent a named type for a composition, verify academic grounding; if the composition has no standard construct, extend an existing primitive with a named method rather than minting a new type | [IMPL-INTENT], [IMPL-060], [PATTERN-013] |
| [PATTERN-055] | `@usableFromInline` property paired with `internal import` of the property's type is a compile error — downgrade visibility or make the import `public` / `package` | [PATTERN-052] |

### [PATTERN-022] ~Copyable Nested Types in Separate Files

**Statement**: Nested types inside `~Copyable`-generic parents MUST be defined in separate files via `extension Parent where Element: ~Copyable { }`, following [API-IMPL-005].

```swift
// File: Namespace.swift
public enum Namespace<Element: ~Copyable> {}

// File: Namespace.NestedData.swift
extension Namespace where Element: ~Copyable {
    public enum NestedData: Sendable, Equatable { ... }
}
```

**Deeply nested types** use extensions on the intermediate parent:
```swift
// File: Namespace.NestedHeap.Cyclic.swift
extension Namespace.NestedHeap where Element: ~Copyable {
    public struct Cyclic<let capacity: Int>: Copyable, Sendable { ... }
}
```

**ManagedBuffer nesting constraint**: `ManagedBuffer` subclasses MUST be nested at the **same level** as the `~Copyable` generic parameter declaration:

```swift
// CORRECT — Storage at same level as Element parameter
public struct Stack<Element: ~Copyable>: ~Copyable {
    final class Storage: ManagedBuffer<Int, Element> { }  // Level 0 — works
    public struct Bounded: ~Copyable {
        var _storage: Stack<Element>.Storage  // References Level 0
    }
}

// INCORRECT — Storage nested deeper
public struct Stack<Element: ~Copyable>: ~Copyable {
    public struct Bounded: ~Copyable {
        final class Storage: ManagedBuffer<Int, Element> { }  // Level 1 — FAILS
    }
}
```

**Cross-references**: [API-IMPL-005], [MEM-COPY-006], [COPY-FIX-003]

---

### Design Pattern Reference

| ID | Statement | Cross-ref |
|----|-----------|-----------|
| [API-LAYER-001] | Code MUST be designed in layers, each depending only on layers below | — |
| [PATTERN-025] | Type erasure and Sendable create tension; verify Sendable is needed before resolving | [IMPL-068], [IMPL-069] |
| [PATTERN-026] | Common patterns MUST be centralized in primitives, even when it adds call-site verbosity | [IMPL-060] |
| [PATTERN-027] | Custom `deinit` marks an architectural boundary for migration to primitives | [IMPL-064] |
| [PATTERN-028] | Refactoring MAY be driven by consistency audits: "what's still ad-hoc?" | [IMPL-060] |
| [PATTERN-052] | `@inlinable` cross-module access requires `@usableFromInline package`, not `internal` | — |
| [PATTERN-053] | Packages MUST use primitives-layer types for common concepts rather than local equivalents | [IMPL-060] |

### Semantic Dependencies

For detailed rules, see `Documentation.docc/Semantic Dependencies.md`.

| Rule | Statement |
|------|-----------|
| [SEM-DEP-006] | Distinguish essential vs incidental relationships; only essential creates SDG edges |
| [SEM-DEP-008] | Join-point packages resolve conflicts where two domains have mutual relevance |
| [SEM-DEP-009] | Package dependencies MUST be essential; orthogonal integrations require separate packages |

---

## ~Copyable Constraint Patterns

Rules for correctly structuring code with `~Copyable` generic parameters. Absorbed from the former copyable-remediation skill.

**Quick reference**:

| Error / Symptom | Fix |
|-----------------|-----|
| `type 'Element' does not conform to protocol 'Copyable'` | [COPY-FIX-003] or [COPY-FIX-004] |
| Error after adding `Sequence` conformance | [COPY-FIX-005] |
| Extension methods unavailable for ~Copyable elements | [COPY-FIX-003] |
| Error only during `swift build`, not in IDE | [COPY-FIX-006] |
| ~Copyable element deinit NOT called (memory leak) | [COPY-FIX-009] |

---

### [COPY-FIX-003] Extension Constraint Requirement

**Statement**: Every extension on a type with `~Copyable` parameters MUST include explicit `where Element: ~Copyable`, unless intentionally restricted to `Copyable` elements. This applies to methods, properties, typealiases, nested types, and extensions on nested types.

```swift
extension Container where Element: ~Copyable { func baseOperation() { } }     // ✓
extension Container { func operation() { } }                                     // ✗ implicitly Copyable-only
```

The constraint appears redundant on nested types but is required:
```swift
extension Storage.Heap where Element: ~Copyable { public struct Header { } }   // ✓
extension Storage.Heap { public struct Header { } }                              // ✗
```

**Cross-references**: [MEM-COPY-004], [MEM-COPY-006], [PATTERN-022]

---

### [COPY-FIX-004] Conditional Conformance Placement

**Statement**: Conditional conformances MUST be in the **same file** as the type definition to avoid constraint poisoning. Module boundary alternative: [COPY-FIX-010].

**Cross-references**: [MEM-COPY-006], [COPY-FIX-010]

---

### [COPY-FIX-005] Protocol Conformance Strategy

**Statement**: `Sequence`/`Collection` conformances MUST be conditional on `Element: Copyable`. For ~Copyable iteration, use custom protocols or `forEach` with borrowing closures.

---

### [COPY-FIX-006] Multi-File Emit-Module Bug

**Status**: OPEN. Tracking: swiftlang/swift #86669. Experiment: `swift-institute/Experiments/noncopyable-sequence-emit-module-bug/`

**Statement**: When errors appear during `-emit-module` but not type-checking, and all six conditions are present (compound `~Copyable & Protocol` constraint, `UnsafeMutablePointer<Element>` in nested type, conditional Sequence conformance, `borrowing Element` closure in separate file, library target, `-enable-experimental-feature Lifetimes`), consolidate all source into a single file.

---

### [COPY-FIX-007] Copy-on-Write for Conditional Copyable

**Statement**: Types with conditional `Copyable` conformance MUST implement CoW in all mutating operations when `Element: Copyable`. The `~Copyable` tier mutates directly; the `Copyable` tier adds uniqueness checks. Critical: always update cached pointers after CoW copy.

**Cross-references**: [IMPL-023], [IMPL-025]

---

### [COPY-FIX-008] Sendable Conformance Independence

**Statement**: `Sendable` conformance MUST be conditional on `Element: Sendable`, independent of `Copyable`.

**Silent failure**: `@unchecked Sendable where Element: ~Copyable` compiles without warning but grants Sendable to ALL element types — including non-Sendable ones.

**Cross-references**: [IMPL-068], [MEM-SEND-001]

---

### [COPY-FIX-009] @_rawLayout Deinit Bug

**Status**: OPEN. Tracking: swiftlang/swift #86652. Experiments: `swift-buffer-primitives/Experiments/rawlayout-*/` (6 variants).

**Statement**: The compiler does not synthesize member destruction for `~Copyable` structs whose stored property chain includes `@_rawLayout`-backed types across package boundaries. Element deinitializers silently fail — **memory leak**, not compile error.

**Conditions** (all three): (1) `@_rawLayout` stored property (directly or transitively), (2) cross-package boundary, (3) container is `~Copyable`.

**Workaround** (two parts, both required):
```swift
struct Container<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _buffer: Buffer<Element>.Ring.Inline<capacity>
    var _deinitWorkaround: AnyObject? = nil  // Part 1: forces deinit body to execute

    deinit {
        // Part 2: manually clean up via mutating path
        unsafe withUnsafePointer(to: _buffer) { ptr in
            unsafe UnsafeMutablePointer(mutating: ptr).pointee.remove.all()
        }
    }
}
```

**Cross-references**: [MEM-COPY-001], [PATTERN-016]

---

### [COPY-FIX-010] Module Boundary Solution

**Statement**: When same-file conformance placement [COPY-FIX-004] isn't viable, split into separate SPM modules. Module boundaries prevent constraint propagation.

---

### [COPY-REM-003] Constraint Cascade Planning

**Statement**: Before implementing a `~Copyable` or `~Escapable` change, trace every associated type through every conformer and extension to predict where constraints will be needed.

**Cascade categories**: ~Copyable on Element (subscript access breaks), ~Copyable on output types (protocol requirements break), ~Escapable on parameters (implicit Escapable breaks).

**Cross-references**: [COPY-FIX-003], [COPY-FIX-004], [MEM-COPY-006], [IMPL-064], [IMPL-065]

---

## Compiler-Enforced Strictness

Implements [IMPL-COMPILE]. Each rule converts a category of runtime failure into a compile-time error.

---

### [IMPL-061] Compiler Fix Over Workaround Accumulation

**Statement**: When a bug is traced to the compiler, investigating a source-level fix SHOULD be attempted before exhaustively exploring workarounds. Workaround cascade signal: when each workaround introduces a new constraint requiring another workaround, the structural fix is at the compiler level.

**Cross-references**: [EXP-011], [EXP-018]

---

### [IMPL-062] Prefer `nonisolated(nonsending)` Over `isolation:` Parameters

**Statement**: Async methods inheriting caller's isolation MUST use `nonisolated(nonsending)`, not `isolation: isolated (any Actor)? = #isolation` (deprecated).

**Exception**: SE-0421 protocol conformances (e.g., `AsyncIteratorProtocol.next(isolation:)`) retain the parameter.

**Scope**: `nonisolated(nonsending)` only applies to async function types. Sync closures (`map`, `filter`) cannot use it.

**Cross-references**: [IMPL-COMPILE], [MEM-SEND-001]

---

### [IMPL-063] Ownership Subsumes Synchronization

**Statement**: When a type is `~Copyable` with `mutating` methods, the compiler guarantees exclusive access. Adding actors, atomics, or locks to protect stored state introduces synchronization for a concurrency problem that does not exist.

**Detection**: Any `~Copyable` type containing an actor, `Atomic`, `Mutex`, or `OSAllocatedUnfairLock` for internal state is a simplification candidate — if all access paths are `mutating` or `consuming`.

**Cross-references**: [MEM-COPY-001], [IMPL-COMPILE]

---

### [IMPL-064] ~Copyable as Default Posture

**Statement**: New types MUST default to `~Copyable`. The question is "does this type need to be Copyable?" — Copyable is the exception requiring justification.

**Copyable justified**: Stored in stdlib collections, value-semantic CoW, lightweight value passed by copy, protocol requirement demands it.
**~Copyable required**: Resource with exactly-once lifecycle, exclusive-access container, unique ownership token, type where duplication is semantic error.

**Cross-references**: [IMPL-COMPILE], [MEM-COPY-001]

---

### [IMPL-065] ~Escapable for Scoped Access

**Statement**: Types representing borrowed access, scoped views, or lifetime-dependent references SHOULD use `~Escapable` when `Lifetimes` is enabled.

**Candidates**: Pointer-based views (`Property.View`), scoped access handles (`Span`), borrowed iterators.
**Does NOT apply**: Types stored in closures, types whose lifetime depends on closure parameters, types stored in collections.

**Cross-references**: [IMPL-COMPILE], [IMPL-021]

---

### [IMPL-066] `sending` at Isolation Boundaries

**Statement**: Parameters and return values crossing isolation boundaries MUST use `sending`.

| Boundary | Annotation |
|----------|------------|
| Value enters actor | `sending` on parameter |
| Value exits actor | `sending` on return |
| Value enters `Mutex.withLock` | `sending` on closure parameter |
| Channel send / fulfill | `sending` on payload |

**Cross-references**: [IMPL-COMPILE], [IMPL-062]

---

### [IMPL-067] Explicit Ownership Annotations

**Statement**: Parameters with non-obvious ownership semantics MUST use explicit annotations.

| Annotation | Caller obligation | When required |
|------------|-------------------|---------------|
| `consuming` | Gives up value | ~Copyable params, transfer operations |
| `borrowing` | Retains ownership | View-producing methods |
| `inout` | Grants exclusive mutable access | Mutation through exclusivity |

**When optional**: Simple Copyable value parameters, closures where annotation adds noise.

**Limitation**: Ownership modifiers are NOT an overload axis. `func f(_ x: borrowing T)` and `func f(_ x: consuming T)` are redeclarations, not overloads. This applies to all combinations (borrowing/consuming/inout) and to closure parameter ownership. Use different method names or the static method pattern ([IMPL-023]) for variants with different ownership semantics.

**Validated by**: `swift-institute/Experiments/ownership-overloading-limitation/`

**Cross-references**: [IMPL-COMPILE], [MEM-OWN-001]

---

### [IMPL-068] Sendable Minimalism

**Statement**: Types MUST NOT conform to `Sendable` unless they genuinely cross isolation boundaries. Granting it unnecessarily forces thread-safety requirements on the type and all stored properties.

**Anti-pattern — viral Sendability**: Making type A Sendable forces all properties Sendable → forces locks on type B → forces inner State structs → forces `withLock` everywhere → deadlock risk. Root cause: Sendable granted without need.

**Fix**: Keep non-Sendable by default. Use `nonisolated(nonsending)` to pass through function chains.

**Cross-references**: [IMPL-062], [IMPL-063]

---

### [IMPL-069] Isolation Hierarchy

**Statement**: Concurrency safety mechanisms MUST be selected starting from the highest rank.

| Rank | Mechanism | Compile-time guarantee | Runtime cost |
|------|-----------|----------------------|--------------|
| **1** | Actor + `nonisolated(nonsending)` | Data-race freedom | Async hop |
| **2** | `~Copyable` + `Sendable` | Single-owner transfer | Zero |
| **3** | `sending` annotation | Region-based transfer | Zero |
| **4** | `Mutex` / locking | Mutual exclusion (programmer-verified) | Lock |
| **5** | `@unchecked Sendable` | None (programmer assertion) | Zero |

Start at Rank 1. Move down only when higher rank is impossible due to a specific, documented constraint.

**Cross-references**: [IMPL-062], [IMPL-063], [IMPL-068]

---

### [IMPL-070] Ownership Transfer Through Mutex

**Statement**: Transferring `consuming ~Copyable` values through Mutex SHOULD use coroutine-based direct property access for new code.

**End-state pattern** (coroutine Mutex with `@_rawLayout` + `nonmutating _modify`):
```swift
_state.locked.value.buffer.push(consume element, to: .back)
```

**Backward-compat pattern** (closure Mutex): Layer 0 (`var slot: V? = value` + `.take()!`), Layer 1 (`withLock(consuming:body:)`), Layer 2 (`Bridge.push()`, `Channel.send()`). `.take()!` at Layer 2 is a compliance violation per [IMPL-INTENT].

**Validated by**: `swift-primitives/Experiments/mutex-coroutine-rawlayout/` (6/6 CONFIRMED, debug + release).

**Cross-references**: [IMPL-INTENT], [IMPL-071], [MEM-OWN-010], [MEM-OWN-011], [MEM-OWN-012]

---

### [IMPL-071] nonmutating _modify for Interior Mutability

**Statement**: When a `~Copyable` view provides mutation through a raw pointer, the `_modify` accessor MUST be `nonmutating`. This enables mutation through `let`-bound containers.

```swift
var value: Value {
    _read { yield unsafe pointer.pointee }
    nonmutating _modify { yield &pointer.pointee }  // ✓ works with `let`
}
```

**~Escapable note**: `~Escapable` on the view is desirable but currently blocked by a lifetime checker limitation on class stored properties. Use `~Copyable` alone — `_read` coroutine scope prevents escape, `~Copyable` prevents aliasing. Experiments: `swift-institute/Experiments/nonescapable-closure-storage/`, `pointer-nonescapable-storage/`, `nonescapable-gap-revalidation-624/`.

**Cross-references**: [IMPL-022], [IMPL-070], [IMPL-064]

---

### [IMPL-072] ~Copyable Multi-Value Return

**Statement**: Functions returning multiple `~Copyable` values MUST use a `~Copyable` bundle struct with Optional members and consuming extraction methods. Swift does not yet support `~Copyable` tuples.

```swift
struct Split: ~Copyable {
    private var _reader: Reader?
    private var _writer: Writer?
    consuming func reader() -> Reader { _reader.take()! }
    consuming func writer() -> Writer { _writer.take()! }
}
```

**Cross-references**: [IMPL-064], [MEM-COPY-001], [MEM-OWN-001]

---

### [IMPL-073] SE-0461 @concurrent Inference Is Body-Sensitive

**Statement**: Under SE-0461, `@concurrent` default for `@Sendable async` closures only triggers when the closure body contains `await`. A sync closure promoted to async does NOT trigger `@concurrent`.

| Closure Body | Parameter Type | Inference |
|-------------|---------------|-----------|
| Contains `await` | `@Sendable async` | `@concurrent` |
| No `await` | `@Sendable async` | Sync→async promotion, no `@concurrent` |
| Any | `nonisolated(nonsending)` | Explicitly non-concurrent |

**Validated by**: `swift-institute/Experiments/se0461-concurrent-body-sensitivity/`

**Cross-references**: [IMPL-062]

---

### [IMPL-074] Shared-Vocabulary Test for Cross-Layer Type References

**Statement**: When a higher-layer public API references a lower-layer type, the reference MUST pass three conditions: (1) **Stable concept** — not specific to lower layer's mechanics, (2) **No hidden boundary reasoning** — callers need not reason about lower layer internals, (3) **Wrapping adds no value**. If any fails, wrap or re-parameterize.

**Cross-references**: [API-LAYER-001], [IMPL-060]

---

### [IMPL-075] `do throws(E)` for Typed Catch Blocks

**Statement**: Inside non-throwing contexts, use `do throws(E) { ... } catch { ... }` to preserve the concrete error type. The `catch let e as E` + `fatalError("Unexpected")` pattern is an anti-pattern.

```swift
do throws(IO.Lane.Error) {
    try lane.run { work() }
} catch {
    logger.log(error)  // error is IO.Lane.Error, not any Error
}
```

**Key distinction**: `catch let error` erases to `any Error`. The implicit `error` binding in a `do throws(E)` catch preserves `E`.

**Cross-references**: [IMPL-040], [API-ERR-001]

---

### [IMPL-076] No @unchecked Sendable on Struct-Wrapping-Class

**Statement**: When a struct's only stored property is a `Sendable` class, the struct MUST use plain `Sendable` — not `@unchecked Sendable`. The `@unchecked` is redundant and misleading.

**Cross-references**: [IMPL-068], [IMPL-069], [MEM-SEND-002]

---

### [IMPL-077] Verify Constraints Before Workarounds

**Statement**: When a compiler error or handoff claims a limitation, the constraint MUST be verified via minimal experiment before implementing a workaround. Stale claims and remembered limitations are hypotheses, not facts.

1. Encounter apparent limitation → 2. Minimal experiment → 3. Confirmed? Implement workaround → 4. Refuted? Write the code as it should be.

**Cross-references**: [IMPL-061], [IMPL-COMPILE]

---

### [IMPL-078] Widen, Don't Duplicate

**Statement**: When adding `~Copyable` support to an existing `Copyable` API, the first approach MUST be to widen the existing constraint from `Copyable` to `~Copyable`. Add a parallel extension only where semantics genuinely diverge.

**Decision procedure**: For each method in the `Copyable` extension, ask: "Can this work with `consuming`/`borrowing` conventions?" If yes, widen. If no (e.g., value-returning accessors requiring copy), keep a Copyable-only convenience alongside the widened base.

The two-tier overload pattern ([IMPL-025]) applies when the Copyable tier needs *different preparation logic* (e.g., CoW checks) — not when the logic is identical.

**Cross-references**: [IMPL-025], [IMPL-064], [MEM-COPY-006]

---

### [IMPL-079] Property.View Is the Terminal ~Escapable Layer

**Statement**: Property.View methods MUST return Copyable values or use closures for borrowed access. A Property.View method MUST NOT return another `~Escapable` value.

**Why**: `_read` coroutine scoping prevents `~Escapable` values from crossing View boundaries. A `~Escapable` value produced inside an inner `_read` has its lifetime tied to that inner scope; an outer `_read` cannot yield the inner value because the inner scope ends first.

**Validated by**: `swift-institute/Experiments/tagged-escapable-accessor/`, `escapable-accessor-patterns/`

**Cross-references**: [IMPL-021], [IMPL-065], [MEM-LIFE-005], [MEM-COPY-013]

---

### [IMPL-080] Consuming Ternary for ~Copyable Selection

**Statement**: When selecting one of two `~Copyable` values based on a condition (`max`, `min`, ternary return), use `consuming` parameters with a ternary expression. Swift's ownership model handles it naturally — selected branch consumed, other dropped.

```swift
static func max(_ a: consuming Self, _ b: consuming Self) -> Self {
    a < b ? b : a
}
```

**Cross-references**: [IMPL-064], [IMPL-078], [MEM-OWN-001]

---

### [IMPL-081] Null-Termination Awareness for Sub-View APIs

**Statement**: When designing sub-view APIs on types derived from C strings, the return type MUST reflect whether null-termination is preserved.

| Operation | Null-terminated? | Safe return type |
|-----------|-----------------|-----------------|
| Suffix to end (`lastComponent`) | Yes — shares original `\0` | `Path.View` or typed view |
| Prefix (`parent`) | No — separator at boundary | `Span<Char>` or byte count |
| Arbitrary sub-range | No | `Span<Char>` |

**General principle**: When a type carries a hidden invariant (null-termination, alignment, capacity), sub-slicing operations must make explicit which invariants survive. Different return types for different guarantee levels.

**Cross-references**: [MEM-SPAN-001], [IMPL-065]

---

### [IMPL-082] Scope Resolution on Extension Extraction

**Statement**: When extracting methods from a nested extension body (`extension Outer { struct Inner { } }`) to an explicit extension (`extension Outer.Inner { }`), sibling types declared in `Outer` lose implicit scope resolution. All references to sibling types MUST be fully qualified after extraction.

**Root cause**: `extension Outer { struct Inner {} }` places methods at nesting depth 2 (Outer scope visible). `extension Outer.Inner {}` places methods at depth 1 (only Inner's own scope). The fully-qualified type path is the same, but lexical nesting differs.

**Validated by**: `swift-institute/Experiments/extension-extraction-scope-resolution/`

**Cross-references**: [API-IMPL-005], [API-IMPL-008]

---

### [IMPL-083] Custom-Executor-to-Actor Bridge Pattern

**Statement**: When a custom `SerialExecutor` owns an OS thread running a synchronous event loop and the tick callback must reach actor-isolated state, the bridge MUST use the SE-0424 mechanism — `isIsolatingCurrentContext()` override on the executor + `assumeIsolated` in the tick body — combined with a local weak-box class captured by the tick to break the definite-init trap. The SE-0424 pieces are designed bridges, NOT workarounds; the weak-box is the minimum-viable workaround for Swift 6.3's DI rule.

**The triad**:

| Piece | Classification |
|-------|---------------|
| `isIsolatingCurrentContext() -> Bool?` returning "is current thread the executor's thread" on the executor class | Designed bridge (SE-0424) |
| `assumeIsolated { isolated in … }` inside the tick body | Designed bridge (SE-0424) |
| Local `Handle` class with `weak var actor: MyActor?`, captured by tick, tail-assigned `handle.actor = self` after the executor is initialized | Minimum-viable workaround |

**Why Handle is required**: the executor is a stored property being assigned in the actor's init. The tick closure literal is the RHS of that assignment. Self-capture in the RHS (`[weak self]`, `[self]`, bare `self`) is rejected by Swift 6.3's DI rule because `self.executor` is not yet initialized. A local `let handle = Handle()` captured by the tick (not self) sidesteps DI — the closure captures the local binding, and the tail `handle.actor = self` runs after all stored properties are assigned.

**Closed avenues on Swift 6.3** (see `swift-foundations/Experiments/`): `sending @escaping` at init, `@isolated(any)` sync or async tick, `var polling: Polling! = nil` default, `Unmanaged.passUnretained(self)` during init, stored-Handle captured by name (compiles but provides no structural improvement), polling-as-actor (actor cannot be its own executor), alternative custom SerialExecutor patterns (SE-0424 IS the canonical pattern), macro-based Handle synthesis (expands to equivalent binary), Swift 6.4+ DI relaxation (no evidence in swiftlang/swift tree as of 2026-03-16 snapshot).

**Only known elimination path on Swift 6.3**: two-phase executor API — `init(source:)` + `public func start(tick:)`. Adds one public method to the executor. Requires explicit owner approval given the API surface growth. See `swift-foundations/Experiments/polling-two-phase-api/` (CONFIRMED).

**Reference implementation**: `swift-executors/Sources/Executors/Kernel.Thread.Executor.Polling.swift` (executor with SE-0424 hooks + `sending @escaping` tick + `@safe` class); `swift-io/Sources/IO Events/IO.Events.Actor.swift` (actor using the bridge); `swift-io/Sources/IO Events/IO.Events.Actor.Handle.swift` (weak-box).

**Cross-references**: [IMPL-066], [IMPL-069], [IMPL-COMPILE], [PATTERN-016], SE-0424

---

### [IMPL-084] Single-Inhabitant Namespaces — See [API-NAME-001a]

**Statement**: A namespace enum containing exactly one type is not a namespace — it is a variant label. This is a naming concern; the canonical rule lives in the **code-surface** skill as [API-NAME-001a] Single-Type-No-Namespace Rule.

**When this comes up in implementation**: The refactor — collapse `Outer.Middle.Only` → `Outer.Middle`, or preserve `Outer.Middle` when it is a variant label under a sibling-having parent (`Executor.Cooperative` alongside `Executor.Stealing`, `Executor.Scheduled`) — is an implementation of the naming rule. See [API-NAME-001a] for the canonical decision procedure and examples.

**Cross-references**: [API-NAME-001a] (canonical), [PATTERN-013], [IMPL-INTENT]

---

### [IMPL-085] Prefer `sending` + `nonisolated(unsafe)` Over `@unchecked Sendable` for Locked Transfer

**Statement**: When transferring a value across region boundaries and a lock provides the synchronization, the value MUST be passed with `sending` (at the API boundary) and stored behind `nonisolated(unsafe)` (inside the synchronized container). `@unchecked Sendable` on the transferred type MUST NOT be used as a substitute.

**Why `@unchecked Sendable` loses**: Granting `@unchecked Sendable` to a type makes it freely shareable across ALL isolation boundaries, at all call sites, forever — regardless of whether the lock is present. The assertion is about the type; the safety is about a specific site. `sending` + `nonisolated(unsafe)` scopes the unsafe promise to the exact transfer point where the lock dominates, preserving the type's unsendability elsewhere.

**Correct** — scoped unsafe promise, lock-enforced:
```swift
final class Slot<Value: ~Copyable> {
    private let mutex: Mutex<()>
    nonisolated(unsafe) private var _value: Value?     // ✓ unsafe scope bounded by mutex
    func fulfill(_ value: sending Value) {             // ✓ sending at the boundary
        mutex.withLock { self._value = value }
    }
}
```

**Incorrect** — type-wide unsafe promise:
```swift
struct Handle: @unchecked Sendable {                   // ✗ asserts safety everywhere
    let value: Value                                    //   even where no lock exists
}
```

**Rationale**: `@unchecked Sendable` is rank 5 in the isolation hierarchy ([IMPL-069]) — strictly the last resort. `sending` + `nonisolated(unsafe)` is the region-based transfer (rank 3) with a narrowly scoped unsafe assertion. When a lock already provides synchronization, the region transfer can be honestly expressed without elevating the type's shareability.

**Provenance**: `swift-foundations/swift-io/Research/Reflections/2026-04-08-architectural-simplification-and-api-consolidation.md` — `Handle.Slot` rendezvous pattern replaced initial `@unchecked Sendable` design.

**Cross-references**: [IMPL-066], [IMPL-068], [IMPL-069], [IMPL-076], [MEM-SAFE-024] (Category D: `@unchecked Sendable` as structural workaround — when sending+nonisolated(unsafe) is not applicable)

---

### [IMPL-086] Deletion-First Structural Fix

**Statement**: When a bug is in a runtime-checked invariant, the first question MUST be "is the invariant itself load-bearing?" — not "how do I enforce this invariant via the type system?" If the invariant exists because we wrote it (not because it is semantically required), deleting the check, the code that maintains it, and the tests that exercise it is often the right structural fix. Language-level enforcement is the answer only when the invariant is semantically load-bearing.

**Decision procedure**:

1. Identify the runtime check failing (the invariant).
2. Ask: *"What breaks if I delete the check and everything that depends on its correctness?"*
3. If the answer is "a test and a looser contract," deletion is the structural fix.
4. Only if the answer is "memory safety / correctness / user-facing contract," escalate to type-system enforcement (`~Copyable`, `~Escapable`, capability tokens).

**Correct** — delete the invariant when it is not load-bearing:
```swift
// Before: actor tracks state enum + runtime checks on every access
// After: state enum removed, checks removed, tests asserting "throws after shutdown" removed.
// The actor's post-shutdown contract is now "undefined"; no runtime-visible regression.
```

**Incorrect** — escalate to type-system enforcement without questioning the invariant:
```swift
// Proposed fix cycle: ~Copyable → scope methods → Channel API change → idempotency contract.
// Each proposal adds structure to maintain an invariant that was never load-bearing.
```

**Rationale**: Swift's type system does not have to defend every invariant. Invariants fall into two classes: (1) load-bearing — deleting them breaks memory safety, user contracts, or compositional correctness, and (2) author-imposed — we wrote the check because it seemed tidy, but the looser contract produces acceptable behavior. Class 2 is surprisingly common in actor-based designs where state machines accumulate.

**Diagnostic signal**: If proposals to fix a bug keep iterating on "add more structure" (slip pattern → L1 scope methods → L2 Channel API → idempotency), and each iteration surfaces new latent issues, the structural fix is probably deletion, not addition. Addition-fatigue is evidence.

**Provenance**: `swift-foundations/swift-io/Research/Reflections/2026-04-08-parent-side-deletion-vs-addition.md` — actor-state visibility fix where 5 proposal iterations of "add structure" preceded the realization that deletion was the right move.

**Cross-references**: [IMPL-COMPILE], [IMPL-063], [PATTERN-016], [AUDIT-017] (when deletion authority is not present in the current session, park the investigation as DEFERRED rather than forcing a fix)

---

### [IMPL-087] Question Whether the Component Needs to Exist

**Statement**: Before designing how a component should work, ask whether it needs to exist at all. This is [IMPL-000] (call-site-first design) applied at the architectural level: the right first question is *"does this need to exist?"*, not *"how should this be implemented?"*. A component that has no data-contract consumer, or whose work is already performed by an existing component, MUST NOT be built on the assumption that the conventional pattern requires it.

**Decision procedure** — for any proposed new component:

1. Identify the specific operation the component must perform.
2. Identify the specific consumer that will invoke that operation.
3. Ask: *"Is there an existing component that already runs at the right time with the right resources?"*
4. If yes, piggyback — add the operation to the existing component.
5. If no, ask: *"Is this component required by the paradigm, or by convention copied from other frameworks?"*
6. Build only what the paradigm requires, not what the convention suggests.

**Correct** — the component is not built because it is not required:
```swift
// io_uring completions discoverable via eventfd + epoll.
// The existing IO.Event.Loop already blocks on epoll.
// → No IO.Completion.Loop with its own poll thread.
// → Completion discovery is a free piggyback on the existing blocking wait.
```

**Incorrect** — the component is built because every framework has one:
```swift
// IO.Completion.Loop with its own OS thread, its own executor, its own shutdown machinery.
// Reasoning: "io_uring is a backend, backends need poll threads."
// Root cause: convention from frameworks that predated eventfd integration.
```

**Rationale**: Every IO framework tutorial starts with "create an event loop." This creates the implicit premise that every backend needs one. Modern kernel interfaces (io_uring's shared-memory rings, IOCP's completion port semantics, eventfd notification) were designed specifically to invalidate that premise. Building on the inherited convention reproduces the constraints of older paradigms inside a newer one.

**The architectural corollary of [IMPL-000]**: at call sites, "write the ideal expression first; improve the infrastructure if it doesn't compile." At the architecture level, "write the ideal system first; question the component if it does not serve a consumer." Same principle, different scope.

**Provenance**: `swift-foundations/swift-io/Research/Reflections/2026-04-09-io-uring-no-separate-loop.md` — `IO.Completion.Loop` proposed, then deleted after recognizing that io_uring + eventfd requires no separate poll thread.

**Cross-references**: [IMPL-000], [IMPL-INTENT], [IMPL-060], [IMPL-074]

---

### [IMPL-088] Lock-Ordering Analysis for Multi-Lock Compositions

**Statement**: Any composition that may hold two locks simultaneously MUST document a total ordering — lock A is always acquired before lock B — or MUST NOT hold both at once. The default posture is separate lock scopes. Acquiring lock B while holding lock A without a documented global ordering is an ABBA-deadlock candidate.

**Decision procedure**:

1. For each method, enumerate the locks held at each point in its body.
2. For each type that holds a lock and calls a method on another lock-holding type, check whether the callee may acquire its own lock.
3. If the call sequence produces "A then B" in one method and "B then A" in another (same types or across types), that is an ABBA deadlock.
4. Prefer separating lock scopes: acquire A, release A, then acquire B. Store the value extracted under A as a local; use it under B.

**Correct** — separated lock scopes:
```swift
func dispatch(_ job: Job) {
    let worker = cursor.advance(within: count)       // no lock held
    workers[worker].enqueue(job)                     // worker's lock acquired in isolation
}
```

**Incorrect** — ABBA via nested locks:
```swift
func trySteal(from other: Worker) {
    self.lock.withLock {                             // A acquired
        other.lock.withLock {                        // B acquired while holding A
            // if another thread simultaneously does other.trySteal(from: self)
            // with B first then A, both deadlock.
        }
    }
}
```

**Rationale**: Lock ordering deadlocks are invisible in pseudo-code that describes lock scopes via indentation. They surface only when two threads encounter the cross-lock interaction simultaneously. A "lock ordering" column in any design table forces the interaction to be analyzed before implementation. Separated scopes are the default because they require no global ordering invariant — the fewer invariants the architecture depends on, the fewer ways it can fail.

**Provenance**: `swift-institute/Research/Reflections/2026-04-15-executor-primitives-l1-and-l3-compositions.md` — ABBA deadlock in Stealing's `trySteal` under own lock; `Scheduled`'s `base.enqueue` under scheduled lock. Both fixed by separating lock scopes.

**Cross-references**: [IMPL-063], [IMPL-069], [IMPL-COMPILE]

---

### [IMPL-089] Foundation-Free String Scanning Defaults to UTF-8 Byte View

**Statement**: At L1/L2 (primitives and standards), string scanning operations MUST default to iterating `content.utf8` (UTF-8 code unit view) with O(1) index arithmetic, not `Character` iteration. Grapheme-cluster semantics MUST be reserved for operations that explicitly require them, and the operation's doc comment MUST state the byte-literal semantics when UTF-8 scanning is used.

**Why**: `Character` iteration + `distance(from:to:)` produces O(n²) complexity on every re-index. Grapheme cluster boundary analysis on each iteration is 10-1000× slower than byte comparison. For the vast majority of foundation-free scans (newline discovery, substring search, percent decoding, path component splitting), byte-literal matching is the correct semantics — and the only semantics that does not require a Unicode table dependency.

**Correct** — UTF-8 byte scan:
```swift
// Find next newline using byte view — O(n) single pass, no allocation.
extension StringProtocol where UTF8View.Index == Index {
    func nextNewline(from start: Index) -> Index? {
        utf8[start...].firstIndex(of: 0x0A)
    }
}
```

**Incorrect** — Character iteration with per-step re-indexing:
```swift
// O(n²) — distance(from:to:) walks grapheme boundaries on every iteration.
for (i, ch) in content.enumerated() where ch == "\n" {
    let idx = content.index(content.startIndex, offsetBy: i + 1)  // ✗ O(n) per iter
}
```

**Doc-comment requirement**: When converting a Character-semantic API to byte-literal, the doc comment MUST record the semantic change:
```swift
/// Returns the range of the first occurrence of `substring`, matched byte-literal
/// against `self.utf8`. To match by grapheme-cluster equivalence, normalize both
/// sides (e.g., NFC) before calling.
```

**Rationale**: At L1/L2, byte-level is the right abstraction unless grapheme semantics are explicitly required. Foundation-free types cannot carry Unicode tables; pretending to provide Character equivalence without those tables either produces wrong results or reaches through to the stdlib's Unicode data, which is a hidden dependency. Byte-literal matching is explicit, O(n), and correct for the use cases where it applies.

**Provenance**: `swift-institute/Research/Reflections/2026-04-15-utf8-perf-and-string-primitives-shadow-fix.md` — `StringProtocol.range(of:)` and `Parsers.Diagnostic.Source.init` converted from O(n²) Character scans to UTF-8 byte scans. External trigger: tuist/FileSystem#325.

**Cross-references**: [IMPL-060], [IMPL-INTENT], [PRIM-FOUND-001]

---

### [IMPL-090] Abstraction-Seam Validity Requires Data-Contract Alignment

**Statement**: Before unifying two runtime patterns behind a shared abstraction (executor, driver, shell), verify that the consumer of each pattern would consume the abstraction's core data contract. If the consumer ignores the shell's core data output, the shared abstraction is at the wrong layer — unify at the primitives layer (shared types), not at the shell layer (shared runtime structure). Surface-shape similarity is NOT evidence of a valid seam.

**Decision procedure**:

1. Identify the candidate abstraction's core data output (what does its `tick` / `run` / `step` emit?).
2. For each prospective consumer, ask: *"Does the consumer's handler consume this data, or discard it?"*
3. If all consumers consume — valid seam; unify.
4. If any consumer discards the core output and consumes a parallel data source — invalid seam; the consumer needs a different shell.

**Correct** — seam at the primitives layer:
```swift
// Reactor (IO.Event.Loop) and Proactor (IO.Completion.Loop) share types:
//   Kernel.Event.Source, Kernel.Completion.Source, Executor.Job.Queue, Shutdown.Flag.
// But NOT run-loop shape — they each own their own 3-phase / 5-phase loop.
// The seam is types (primitives), not shell (Polling executor).
```

**Incorrect** — seam at the shell layer:
```swift
// Proposal: Completion.Loop adapter-wraps its notification eventfd in Kernel.Event.Source
//           so Polling can own both reactor and proactor run loops.
// Problem: Polling's tick emits Kernel.Events. Completion.Loop's handler ignores the
//          event (it already knows an eventfd fired) and runs flush → drain → dispatch.
// The consumer discards the shell's core output. Seam is invalid.
```

**Rationale**: An abstraction seam's validity is measured by data flow, not by surface shape. Two patterns can have matching method signatures ("both are executors with a run loop") while having non-overlapping data contracts (one emits events, the other consumes CQEs from a separate ring). Forcing the mismatched pair through a shared shell produces code where the core data contract is ignored — the shell's promise ("I hand you the important data") is broken at the seam.

**Surface-shape checklist (NOT sufficient evidence for unification)**:
- Both types have a `run()` method.
- Both types block on a primitive and wake via notification.
- Both types produce work for a dispatcher.

**Data-contract checklist (sufficient evidence for unification)**:
- Both consumers read the shell's core output with identical semantics.
- Both consumers handle the shell's core failure modes identically.
- Both consumers respect the shell's phase ordering (e.g., flush-before-wait) identically.

**Provenance**: `swift-foundations/swift-io/Research/Reflections/2026-04-15-completion-loop-proactor-reactor-boundary.md` — Polling (reactor) and IO.Completion.Loop (proactor) cannot share the run loop because proactor requires flush-before-wait, and the reactor shell's tick emits data the proactor consumer ignores.

**Cross-references**: [PATTERN-013], [IMPL-074], [API-LAYER-001], [IMPL-060]

---

### [IMPL-091] Materialise Before Crossing Region Boundaries

**Statement**: When a task-isolated closure parameter must produce a value consumed inside an actor-isolated `assumeIsolated` region, the closure MUST be invoked OUTSIDE the actor-isolated region, its result bound to `Sendable` local variables, and those locals consumed INSIDE the region. Invoking the closure inside the region triggers region-analysis errors that are compile-time artifacts, not runtime safety violations.

**The pattern**:
```swift
// Task-isolated tick parameter, actor-isolated handler.
executor.run { [weak self] wait in                    // wait: task-isolated
    guard let self else { return .halt }

    // Materialise: call the closure OUTSIDE assumeIsolated.
    let events: UnsafeBufferPointer<Kernel.Event>
    let waitError: Driver.Error?
    do throws(Driver.Error) {
        events = try wait()                           // ✓ called at tick scope
        waitError = nil
    } catch {
        events = UnsafeBufferPointer(start: nil, count: 0)
        waitError = error
    }

    // Cross: consume Sendable locals INSIDE assumeIsolated.
    self.assumeIsolated { isolated in
        if let waitError { isolated.handleFailure(waitError) }
        else              { isolated.dispatchEvents(events) }
    }
}
```

**Why the naive form fails**:
```swift
// ✗ sending 'wait' risks causing data races — region analysis rejects this.
self.assumeIsolated { isolated in
    let events = try wait()                            // closure crosses actor boundary
    isolated.dispatchEvents(events)
}
```

**Rationale**: Region analysis operates on types and closure annotations at compile time. It sees a task-isolated closure parameter passed into an actor-isolated closure body and treats the call as a boundary crossing — even when the runtime executor identity means no boundary is actually crossed. The runtime verifies via `isIsolatingCurrentContext` ([IMPL-083]); the compile-time analysis verifies via regions. Both systems must be satisfied, because they operate at different abstraction levels. Materialising the result into `Sendable` locals is the generic bridge: the locals cross the region boundary freely, and the closure body only reads them.

**Constraints on the locals**: they MUST be `Sendable`. `UnsafeBufferPointer<T> where T: Sendable` qualifies. For ~Copyable intermediates, the closure body must do the entire work inside the outer scope; only Sendable primitives / pointers may cross the boundary.

**Provenance**: `swift-foundations/swift-io/Research/Reflections/2026-04-15-polling-tick-isolation-checkisolated-landing.md` — `IO.Events.Actor` tick rewrite; `Polling.swift:220-228` is the internal precedent.

**Cross-references**: [IMPL-066], [IMPL-069], [IMPL-083], [IMPL-COMPILE]

---

### [IMPL-092] `throws(E)` Thunk Parameters Over `Result<T, E>` for Callback Outcomes

**Statement**: For callback APIs that deliver one-of (value, error) to a consumer closure, the outcome MUST be expressed as a `() throws(E) -> T` thunk parameter, not as a `Result<T, E>` value. Internal storage of the outcome (where throws cannot express a not-yet-resolved value — e.g., before the thunk is invoked) MAY use `Optional`, a private enum, or a Result-shaped struct; the consumer-facing interface remains typed throws.

**Correct** — thunk parameter at the interface:
```swift
// Executor supplies the outcome as a thunk; consumer invokes with `try`.
let tick: @Sendable (
    () throws(Kernel.Event.Driver.Error) -> UnsafeBufferPointer<Kernel.Event>
) -> Outcome

// At the consumer:
loop.runInTick { wait in
    do throws(Kernel.Event.Driver.Error) {
        let events = try wait()                      // typed throws — language semantics
        self.dispatch(events)
        return .continue
    } catch {
        return self.handleFailure(error)              // error is Kernel.Event.Driver.Error
    }
}
```

**Incorrect** — Result value at the interface:
```swift
// ✗ Consumer switches on the Result instead of using `try` / `catch`.
let tick: @Sendable (Result<UnsafeBufferPointer<Kernel.Event>, Driver.Error>) -> Outcome

loop.runInTick { result in
    switch result {
    case .success(let events): self.dispatch(events); return .continue
    case .failure(let error):  return self.handleFailure(error)
    }
}
```

**Internal storage is unaffected**: executor materialises the outcome into `let count: Int` and `let error: Error?` before constructing the thunk closure. That internal representation is private; the consumer interface is `throws(E)`.

**Rationale**: `[API-ERR-001]` prescribes typed throws for functions that throw. The analogous rule for a callback *parameter* that delivers an outcome is the thunk form — it uses the language's primitive error-propagation mechanism (`try` / `catch`) instead of adding a type-level ADT. Consumer code reads as intent ([IMPL-INTENT]): "try wait; handle error." A `Result` value forces the consumer to switch on cases explicitly, which is mechanism.

**When to use `Result` instead**: when the outcome must be stored, inspected multiple times, passed across a non-throwing API boundary (e.g., into `AsyncStream.yield`), or pattern-matched in a switch that tests additional conditions besides success/failure. Storage-shape needs are legitimate — interface-shape should still be throws.

**Provenance**: `swift-foundations/swift-io/Research/Reflections/2026-04-15-polling-tick-throws-thunk-over-result.md` — Polling tick signature migrated from `Result<T, E>` proposal to `() throws(E) -> T` thunk after user override: "use LANGUAGE SEMANTICS so throws see /implementation."

**Cross-references**: [API-ERR-001], [IMPL-040], [IMPL-075], [IMPL-INTENT]

---

## Post-Implementation Checklist

Before presenting code as complete, verify EACH item:

**Expression quality**:
- [ ] No `.rawValue` chains at call sites — use typed operators [IMPL-002]
- [ ] No `Int(bitPattern:)` at call sites — push to boundary overloads [IMPL-010]
- [ ] No intermediate variables that merely restate expressions [IMPL-EXPR-001]
- [ ] Ecosystem types used where available — no ad-hoc reimplementations [IMPL-060]
- [ ] Property.View used for verb-as-property patterns — no hand-rolled structs [IMPL-020/021]
- [ ] Bounded indices for static-capacity types [IMPL-050]
- [ ] Foundation-free string scans use `content.utf8`, not `Character` iteration [IMPL-089]

**Compiler-enforced strictness**:
- [ ] Types default to `~Copyable` unless Copyable is justified [IMPL-064]
- [ ] Scoped/view types use `~Escapable` where `Lifetimes` is enabled [IMPL-065]
- [ ] `sending` on all isolation-boundary parameters and returns [IMPL-066]
- [ ] Ownership annotations on non-obvious parameter semantics [IMPL-067]
- [ ] No unnecessary `Sendable` conformances [IMPL-068]
- [ ] Concurrency mechanism selected by isolation hierarchy rank [IMPL-069]
- [ ] ~Copyable ownership transfer uses coroutine accessor or Layer 1 abstractions [IMPL-070]
- [ ] Interior-mutable views use `nonmutating _modify`, not plain `_modify` [IMPL-071]
- [ ] Lock scopes separated unless a total ordering is documented [IMPL-088]
- [ ] Values crossing actor regions materialised as `Sendable` locals before `assumeIsolated` [IMPL-091]

**Design**:
- [ ] No namespace enum containing a single inhabitant [IMPL-084]
- [ ] `sending` + `nonisolated(unsafe)` preferred over `@unchecked Sendable` for locked transfer [IMPL-085]
- [ ] Runtime-checked invariants verified as load-bearing before type-system enforcement [IMPL-086]
- [ ] Component existence justified by a consumer's data contract, not by framework convention [IMPL-087]
- [ ] Callback outcomes expressed as `() throws(E) -> T` thunks, not `Result<T, E>` [IMPL-092]

If ANY item fails, fix before presenting.

---

## Cross-References

See also:
- **conversions** skill for [IDX-*], [CONV-*] type definitions and conversion APIs
- **code-surface** skill for [API-NAME-*], [API-ERR-*], [API-IMPL-*] naming, errors, file structure
- **memory-safety** skill for [MEM-*] ownership patterns, ~Copyable mechanics, unsafe marking
- **testing** skill for [TEST-018] literal conformances in tests
- **existing-infrastructure** skill for [INFRA-*] catalog of typed operations, integration modules, and principled absences
- **Semantic Dependencies.md** for [SEM-DEP-*] dependency classification rules
