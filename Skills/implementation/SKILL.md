---
name: implementation
description: |
  Call-site-first implementation patterns: typed arithmetic, boundary overloads,
  property accessors, expression style. Absorbs anti-patterns.
  ALWAYS apply when writing or reviewing implementation code.

layer: implementation

requires:
  - swift-institute
  - naming
  - errors
  - code-organization
  - conversions

applies_to:
  - swift
  - swift6
  - primitives
  - standards
  - foundations
---

# Implementation

Every line of implementation code should be locally perfect.

---

## Core Principle

### [IMPL-000] Call-Site-First Design

**Statement**: Implementation code MUST be written as the ideal expression first. If the infrastructure doesn't support it, the infrastructure MUST be improved — unless the absence is principled (see [IMPL-001]).

Write the expression that reads like intent, not mechanism. Then:

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
| `count * count` | Multiplying two quantities of the same dimension produces a different dimension. | `count.scale(by: ratio)` or the appropriate cross-domain operation. |
| `pointer + count` | Affine space: you add vectors (offsets) to points, not scalars (counts). | `pointer + offset` where offset is computed via the appropriate conversion. |
| `Index(rawValue: 5)` as public API | Bypasses the type's invariants. | Designated constructor, literal conformance (tests), or `__unchecked` (same-package). |
| Scalar operators on typed quantities | Typed quantities don't mix with bare `Int`/`UInt`. | Use the typed operator that preserves the domain. |

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

## Typed Arithmetic

### [IMPL-002] Write the Math, Not the Mechanism

**Statement**: Arithmetic on typed values MUST use typed operators. Raw value extraction (`.rawValue`, `.position`) MUST NOT appear at call sites for computation.

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

**Cross-references**: [CONV-010], [PATTERN-018]

---

### [IMPL-003] Functor Operations for Domain Crossing

**Statement**: Cross-domain type conversions MUST use `.map()` (transform raw value, preserve tag) or `.retag()` (preserve raw value, change tag). Direct `__unchecked` construction SHOULD be avoided when a functor path exists.

| Operation | Meaning | Example |
|-----------|---------|---------|
| `.map(Ordinal.init)` | `Count → Index` (Cardinal → Ordinal, same tag) | `currentCount.map(Ordinal.init)` |
| `.retag(Element.self)` | Change phantom type (zero-cost) | `_slots.popcount.retag(Element.self)` |
| `.map { $0 * 2 }` | Transform raw value | `count.map { Cardinal($0.rawValue * 2) }` |

**Cross-references**: [CONV-003], [IDX-010]

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

**Implementation**: Tag types are empty enums. Methods are extensions on `Property` constrained by `where Tag == ..., Base == ...`.

```swift
extension Storage where Element: ~Copyable {
    public enum Move {}
}

extension Storage.Heap where Element: ~Copyable {
    public var move: Property<Storage.Move, Storage.Heap> {
        Property(self)
    }
}

extension Property {
    public func callAsFunction<Element: ~Copyable>(
        at slot: Index<Element>
    ) -> Element where Tag == Storage<Element>.Move, Base == Storage<Element>.Heap {
        return unsafe base.pointer(at: slot).move()
    }
}
```

**Cross-references**: [API-NAME-002]

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

## Expression Style

### [IMPL-030] Inline Construction Over Intermediate Variables

**Statement**: When constructing a value to pass immediately, it SHOULD be constructed inline rather than bound to an intermediate variable.

**Perfect**:
```swift
return try body(unsafe Span(
    _unsafeStart: pointer(at: range.lowerBound),
    count: Int(bitPattern: range.count)
))
```

**Imperfect**:
```swift
try unsafe withUnsafeMutablePointerToElements { base throws(E) in
    let startOffset = Index<Element>.Offset(fromZero: range.lowerBound)
    let count = Int(bitPattern: range.count)
    let span = unsafe Span(_unsafeStart: UnsafePointer(base + startOffset), count: count)
    return try body(span)
}
```

**Exception**: When the intermediate improves readability or is used more than once, binding is appropriate.

---

### [IMPL-031] Enum Iteration Over Manual Switch

**Statement**: When applying a uniform operation across all cases of an enum, the enum SHOULD provide `.forEach` (and `.linearize` when offset tracking is needed). Call sites MUST NOT manually switch when a uniform iterator exists.

**Perfect**:
```swift
header.initialization.forEach { range in
    deinitialize(range: range)
}

base.initialization.linearize { range, offset in
    self(range: range, to: destination, at: offset)
}
```

**Imperfect**:
```swift
switch header.initialization {
case .empty: return
case .one(let range): deinitialize(range: range)
case .two(let first, let second):
    deinitialize(range: first)
    deinitialize(range: second)
}
```

If the iteration method doesn't exist on the enum, add it.

---

### [IMPL-032] Bulk Operations Over Per-Element Loops

**Statement**: When a bulk operation exists (e.g., `set.range()`, `clear.range()`, `deinitialize(count:)`), it MUST be preferred over per-element loops.

**Perfect**:
```swift
_slots.set.range(range.map.bounds { $0.retag(Bit.self) })
unsafe pointer(at: range.lowerBound).deinitialize(count: range.count)
```

**Imperfect**:
```swift
var slot = range.lowerBound
while slot < range.upperBound {
    _slots[Bit.Index(slot.rawValue)] = true
    slot = slot.successor.saturating()
}
```

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

### [PATTERN-022] ~Copyable Constraint Poisoning Prevents File Splitting

**Statement**: When a namespace type has `~Copyable` generic parameters, all nested types that reference those parameters MUST remain in the same file as the parent type. [API-IMPL-005] (one type per file) does not apply in this case.

Moving nested types into separate files (via `extension Parent { ... }`) triggers constraint poisoning: the compiler infers a `Copyable` requirement on the generic parameter in the extension, producing `'Element' required to be 'Copyable' but is marked with '~Copyable'` errors.

**Affected patterns**:
- Nested enums, structs, or classes inside a `~Copyable`-generic parent
- `ManagedBuffer` subclasses nested inside a `~Copyable`-generic namespace
- Conditional conformances on nested types (e.g., `Sendable where Element: Sendable`)

**What must stay together**:
```swift
// All in one file — cannot be split
public enum Namespace<Element: ~Copyable> {
    public enum NestedData: Sendable, Equatable { ... }
    public final class NestedHeap: ManagedBuffer<...> { ... }
    public struct NestedInline<let N: Int>: ~Copyable { ... }
}

extension Namespace.NestedInline: @unchecked Sendable where Element: Sendable {}
```

**What CAN be in separate files**: Extensions that add methods or computed properties (not type declarations) to already-declared nested types, provided the extension uses `where Element: ~Copyable`:
```swift
// Separate file — OK
extension Namespace.NestedHeap where Element: ~Copyable {
    public func someMethod() { ... }
}
```

**Cross-references**: [API-IMPL-005], [API-IMPL-008], [MEM-COPY-006]

---

## Cross-References

See also:
- **conversions** skill for [IDX-*], [CONV-*] type definitions and conversion APIs
- **naming** skill for [API-NAME-*] namespace structure
- **errors** skill for [API-ERR-*] typed throws
- **memory** skill for [MEM-*] ownership patterns
- **design** skill for [API-LAYER-*] layering decisions
- **testing** skill for [TEST-018] literal conformances in tests
