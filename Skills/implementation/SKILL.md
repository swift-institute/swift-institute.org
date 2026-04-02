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
last_reviewed: 2026-04-01
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

**Cross-references**: [API-ERR-001], [API-NAME-001]

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

Rules absorbed from former `anti-patterns` and `design` skills. Rules whose canonical home is another skill have been removed — see that skill directly via the routing table in CLAUDE.md.

### Anti-Pattern Reference

| ID | Statement | Cross-ref |
|----|-----------|-----------|
| [PATTERN-012] | Canonical implementation for type transformations MUST live in initializers or static methods on the target type | — |
| [PATTERN-013] | Protocols MUST NOT be designed before having 3+ concrete conformers | — |
| [PATTERN-016] | Code violating a pattern MAY be acceptable when intentional, documented (`// WORKAROUND:`, `// WHY:`, `// WHEN TO REMOVE:`, `// TRACKING:`), bounded, and has specific removal criteria | — |
| [PATTERN-017] | `.rawValue` and `.position` MUST be confined to extension initializers and same-package implementations | [IMPL-002], [CONV-001] |
| [PATTERN-019] | Extensions on `Tagged where RawValue == T` MUST NOT provide public `init` — bypasses bounded invariants | [IMPL-001] |
| [PATTERN-020] | A throwing init on a wrapper MUST NOT validate only the base type's invariant when the wrapper specializes to stricter types | [PATTERN-019] |

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

## Post-Implementation Checklist

Before presenting code as complete, verify EACH item:

**Expression quality**:
- [ ] No `.rawValue` chains at call sites — use typed operators [IMPL-002]
- [ ] No `Int(bitPattern:)` at call sites — push to boundary overloads [IMPL-010]
- [ ] No intermediate variables that merely restate expressions [IMPL-EXPR-001]
- [ ] Ecosystem types used where available — no ad-hoc reimplementations [IMPL-060]
- [ ] Property.View used for verb-as-property patterns — no hand-rolled structs [IMPL-020/021]
- [ ] Bounded indices for static-capacity types [IMPL-050]

**Compiler-enforced strictness**:
- [ ] Types default to `~Copyable` unless Copyable is justified [IMPL-064]
- [ ] Scoped/view types use `~Escapable` where `Lifetimes` is enabled [IMPL-065]
- [ ] `sending` on all isolation-boundary parameters and returns [IMPL-066]
- [ ] Ownership annotations on non-obvious parameter semantics [IMPL-067]
- [ ] No unnecessary `Sendable` conformances [IMPL-068]
- [ ] Concurrency mechanism selected by isolation hierarchy rank [IMPL-069]
- [ ] ~Copyable ownership transfer uses coroutine accessor or Layer 1 abstractions [IMPL-070]
- [ ] Interior-mutable views use `nonmutating _modify`, not plain `_modify` [IMPL-071]

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
