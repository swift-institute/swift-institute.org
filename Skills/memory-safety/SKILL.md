---
name: memory-safety
description: |
  Memory ownership, copyability, lifetime safety, strict memory safety,
  unsafe marking, sendable conformance, and reference primitives.
  ALWAYS apply when working with ~Copyable types, ownership annotations,
  unsafe operations, reference types, or concurrency safety.

layer: implementation

requires:
  - swift-institute

applies_to:
  - swift
  - swift6
  - primitives

last_reviewed: 2026-03-25
---

# Memory Safety Conventions

Rules for safety isolation, strict memory safety (SE-0458), ownership, copyability, concurrency safety, reference primitives, and lifetime management.

**Canonical reference**: `swift-institute/Research/swift-safety-model-reference.md`

---

## Safety Isolation

The organizing principle: isolate unsafe code and prevent virality. Place `@safe` boundaries as low as possible. Maximize absorbers, minimize propagators.

### [MEM-SAFE-020] Isolation Principle

**Scope**: All types with unsafe internals.

**Statement**: `@safe` boundaries MUST be placed as low as possible — as close to the raw pointer operations as achievable. The goal is to maximize absorbers (`@safe`) and minimize propagators (`@unsafe`). Every `@unsafe` in the public API is a deliberate escape hatch, not the primary interface.

**The acid test**: Can a caller use this type's complete public API without ever writing the `unsafe` keyword? If yes, the type is properly isolated.

Every declaration plays one of three roles:

| Role | Annotation | Caller Obligation | Purpose |
|------|-----------|-------------------|---------|
| **Absorber** | `@safe` | None | Encapsulates unsafe internals behind a safe API |
| **Propagator** | `@unsafe` | Must use `unsafe` | Escape hatch that pushes safety responsibility to caller |
| **Unspecified** | (none) | Depends on signature | Compiler infers from types in signature |

**Rationale**: Without isolation, unsafety propagates virally through the call graph. One unsafe type at the bottom infects every layer above it. `@safe` is the firewall that stops propagation.

**Cross-references**: [MEM-SAFE-021], [MEM-SAFE-022], [MEM-SAFE-023]

---

### [MEM-SAFE-021] No `@unsafe` on Encapsulating Types

**Scope**: Types that encapsulate unsafe storage behind a safe API.

**Statement**: Types that encapsulate unsafe storage MUST use `@safe`, NOT `@unsafe`. `@unsafe struct` makes `self` an unsafe type, causing cascading warnings on every property access and method call inside the type's own methods — including safe operations like `precondition(index < capacity)`.

```swift
// INCORRECT - self becomes unsafe, infecting every method body
@unsafe struct Slab<Element> {
    var storage: UnsafeMutablePointer<Element>
    let capacity: Int

    func foo() {
        precondition(index < capacity)  // WARNING: self.capacity involves unsafe type
    }
}

// CORRECT - only actual unsafe operations need unsafe
@safe struct Slab<Element> {
    var storage: UnsafeMutablePointer<Element>
    let capacity: Int

    func foo() {
        precondition(index < capacity)  // Clean
        unsafe (storage + index).initialize(to: value)  // Only the actual unsafe op
    }

    @unsafe  // Escape hatch
    func withUnsafePointer(_ body: (UnsafePointer<Element>) -> Void) { ... }
}
```

**Exception**: Types that exist solely AS the unsafe escape hatch (e.g., `Loader.Library.Handle` wrapping a raw `dlopen` handle) MAY use `@unsafe struct`.

**Cross-references**: [MEM-SAFE-020], [MEM-UNSAFE-003]

---

### [MEM-SAFE-022] `@unsafe` Only on Escape Hatches

**Scope**: Public API design for types with unsafe internals.

**Statement**: `@unsafe` MUST only appear on escape hatch methods, never on the primary API. If the primary API requires `unsafe` at the call site, isolation has failed.

```swift
@safe public struct Buffer<Element: ~Copyable>: ~Copyable {
    private var storage: UnsafeMutablePointer<Element>

    // PRIMARY: safe, normative interface
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < capacity)
        return unsafe storage[index]
    }

    public var span: Span<Element> { ... }

    // ESCAPE HATCH: only when Span/subscript is insufficient
    @unsafe
    public borrowing func withUnsafePointer<R>(
        _ body: (UnsafePointer<Element>) throws -> R
    ) rethrows -> R { ... }
}
```

**Cross-references**: [MEM-SAFE-012], [MEM-SAFE-020]

---

### [MEM-SAFE-023] Private Unsafe Storage

**Scope**: Stored properties of unsafe pointer types.

**Statement**: Stored properties of unsafe pointer types on `@safe` types MUST be `private` or `internal`. Public properties returning unsafe pointer types MUST be annotated `@unsafe` to signal that they are deliberate escape hatches.

```swift
// INCORRECT - public pointer on @safe Escapable type, pointer can dangle
@safe public struct Buffer {
    public let storage: UnsafeMutablePointer<UInt8>  // Leaks unsafety
}

// CORRECT - pointer is private, Span is the public interface
@safe public struct Buffer {
    private let storage: UnsafeMutablePointer<UInt8>
    public var span: Span<UInt8> { ... }

    @unsafe public func withUnsafePointer<R>(...) -> R { ... }
}
```

**`~Escapable` exception**: On `~Escapable` types, public pointer properties are **structurally safe** — the view cannot outlive the source, so the pointer cannot dangle. The type system enforces the lifetime boundary that closures (`withUnsafePointer`) enforce by convention. `@unsafe` is still recommended for documentation clarity, but the severity is LOW, not HIGH.

```swift
// ACCEPTABLE - ~Escapable prevents the pointer from outliving the source
@safe public struct View: ~Copyable, ~Escapable {
    public let pointer: UnsafePointer<Char>  // Cannot dangle by construction
    public var span: Span<Char> { ... }      // Still preferred for callers
}
```

| Containing type | Pointer exposure | Severity |
|----------------|-----------------|----------|
| `Escapable` | Public pointer property | HIGH — pointer can dangle |
| `~Escapable` | Public pointer property | LOW — structurally safe |
| Coroutine-scoped (not `~Escapable`) | Public pointer property | MEDIUM — safe by convention, not type system |

**Cross-references**: [MEM-SAFE-012], [MEM-SAFE-014], [MEM-SAFE-020], [MEM-COPY-013], [IMPL-085] (prefer `sending` + `nonisolated(unsafe)` when a lock provides synchronization — narrower than type-wide `@unchecked Sendable`)

---

### [MEM-SAFE-024] `@unchecked Sendable` Semantic Categories

**Scope**: All `@unchecked Sendable` conformances.

**Statement**: `@unchecked Sendable` conformances MUST be classified into one of four semantic categories. The correct annotation depends on the category.

| Category | Semantics | Annotation | Safety invariant |
|----------|-----------|------------|-----------------|
| **A: Synchronized** | Internal mutex, atomic, or lock | `@unsafe @unchecked Sendable` | Document synchronization mechanism |
| **B: Ownership transfer** | `~Copyable` prevents sharing; Sendable enables move | `@unsafe @unchecked Sendable` | Document `~Copyable` ownership guarantee |
| **C: Thread-confined** | Single-thread access; `@unchecked Sendable` used to cross one boundary | **Should be `~Sendable`** (SE-0518) | DEFER until `~Sendable` stabilizes |
| **D: Structural workaround** | Type is value-like and safe, but compiler inference cannot prove Sendable due to a structural limitation | `@unsafe @unchecked Sendable` | Document which inference gap the annotation bridges |

**Category A** — synchronized:
```swift
/// ## Safety Invariant
/// Internal `Mutex<State>` serializes all access.
extension Kernel.Thread.Synchronization: @unsafe @unchecked Sendable {}
```

**Category B** — ownership transfer:
```swift
/// ## Safety Invariant
/// `~Copyable` unique ownership ensures only one thread can access at a time.
/// Transfer via `consuming` parameter relinquishes the sender's access.
@safe public struct Arena: ~Copyable { ... }
extension Arena: @unsafe @unchecked Sendable {}
```

**Category C** — thread-confined (DO NOT add `@unsafe`):
```swift
// CURRENT (semantic lie — type is not safe to send arbitrarily)
final class Ring: @unchecked Sendable { ... }

// FUTURE (SE-0518) — express the truth at the type level
final class Ring: ~Sendable { ... }
// Transfer to poll thread uses explicit unsafe at the transfer site
```

Category C types MUST adopt `~Sendable` instead of `@unchecked Sendable`. Adding `@unsafe` to a thread-confined type is a bandaid — the real fix is expressing confinement at the type level.

**Category D** — structural workaround (three recognized subpatterns):

Category D covers sites where the type is structurally value-like and concurrency-safe, but Swift's compiler cannot synthesize `Sendable` automatically because of a specific structural limitation. The annotation compensates for the inference gap; the safety invariant is inherent to the type's shape, not to a synchronization mechanism.

| Subpattern | Structure | Why inference fails |
|-----------|-----------|---------------------|
| **SP-2: `@_rawLayout` bridges** | Type uses `@_rawLayout` attribute to specify explicit memory layout (e.g., atomics storage) | `@_rawLayout` types are not eligible for Sendable synthesis; the annotation bridges the gap for types that are provably safe by layout |
| **SP-4: Non-Sendable generic parameter** | Type is generic over a parameter that cannot be constrained `: Sendable` (e.g., protocols like `AsyncIteratorProtocol`, closure types) but the type's actual use never exposes the parameter in a racy way | The generic parameter is structurally non-Sendable, but the type's API wraps it safely; the annotation is the only way to express the composite type's Sendable contract |
| **SP-5: Pointer-backed Copyable** | Value-like wrapper over a pointer where the pointer's referent is immutable / by-construction uniquely owned | The pointer is a reference type as far as Sendable inference is concerned; the annotation declares the wrapper's value semantics |

**Required doc form for Category D**:

```swift
/// ## Safety Invariant (Category D — structural workaround)
/// SP-N subpattern: {explanation of the inference gap}.
/// Why safe: {the structural property that makes this concurrency-safe}.
extension MyType: @unsafe @unchecked Sendable {}
```

**What Category D is NOT**:

| Mistaken use | Correct classification |
|--------------|-----------------------|
| "My type has synchronization and I find D's explanation easier" | A |
| "My type is `~Copyable` and owns a resource" | B |
| "My type is thread-confined but I don't want to adopt `~Sendable`" | C (pending SE-0518) |
| "I didn't think through the invariant and D seems permissive" | Stop and classify properly |

Category D is the narrow escape hatch for provable-safe types the compiler cannot verify, not a bucket for unclassified annotations.

**Enablement**: `~Sendable` is available via `.enableExperimentalFeature("TildeSendable")` in Swift 6.3.

**Reference**: `swift-institute/Research/tilde-sendable-semantic-inventory.md`; ecosystem audit finding 35 sites (16% of 218) across three subpatterns — `swift-institute/Audits/unsafe-audit-findings.md` "Category D Adjudication" section.

**Provenance**: Category A/B/C originally per tilde-sendable-semantic-inventory. Category D added per reflection `2026-04-15-ecosystem-unsafe-audit.md`, where 35 existing `@unchecked Sendable` sites were found to be none of A/B/C and resolved into three coherent subpatterns (SP-2, SP-4, SP-5). Two candidate subpatterns (SP-1, SP-8) were reclassified to B by the governing principle ("ownership transfer is the primary invariant; value-generic is incidental").

**Cross-references**: [MEM-SEND-001], [MEM-SEND-002], [MEM-SAFE-020]

---

### [MEM-SAFE-025] `nonisolated(unsafe)` Globals Require `@safe`

**Scope**: Module-level or static `nonisolated(unsafe)` declarations.

**Statement**: `nonisolated(unsafe)` globals that are safely encapsulated (allocated once, never mutated after initialization, used only as sentinels or constants) MUST be annotated with `@safe`.

```swift
// INCORRECT - no safety assertion
@usableFromInline
nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)

// CORRECT - @safe asserts the invariant
@safe @usableFromInline
nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
```

`nonisolated(unsafe)` mutable statics that ARE accessed concurrently MUST use synchronization (`Mutex`, `Atomic`) instead of relying on temporal invariants ("set once before reads").

**Cross-references**: [MEM-SEND-001], [MEM-SAFE-020]

---

## Strict Memory Safety (SE-0458)

### [MEM-SAFE-001] Enable Strict Memory Safety

**Scope**: All ecosystem packages.

**Statement**: All packages MUST enable strict memory safety via `.strictMemorySafety()`.

```swift
// Package.swift
.target(
    name: "Buffer Primitives",
    swiftSettings: [.strictMemorySafety()]
)
```

---

### [MEM-SAFE-002] Unsafe Expression Marking

**Statement**: Each unsafe operation requires its own `unsafe` acknowledgment. Expression granularity.

```swift
// For assignments to unsafe storage, wrap the entire expression
unsafe (self.raw = Unmanaged.passRetained(instance).toOpaque())

// INCORRECT - destination uncovered
self.raw = unsafe Unmanaged.passRetained(instance).toOpaque()
```

- `@unsafe` on a function declares that *calling* is unsafe
- Operations *within* still require individual `unsafe` markers
- `unsafe` does NOT propagate into closures — mark both outer call and inner operations

---

### [MEM-SAFE-003] Warning Classification

**Statement**: Two buckets:

| Category | Description | Action |
|----------|-------------|--------|
| **Bucket A** | Operations requiring `unsafe` acknowledgment | Mark with `unsafe` |
| **Bucket B** | "Struct has storage involving unsafe types" | Decide `@safe` or `@unsafe` per [MEM-SAFE-021] |

---

### [MEM-SAFE-004] Five Dimensions of Memory Safety

| Dimension | Guarantee | Mechanism |
|-----------|-----------|-----------|
| Lifetime Safety | Values accessed within their lifetime | ARC, `~Copyable`, `@_lifetime` |
| Bounds Safety | Accesses within allocation bounds | Array bounds checking |
| Type Safety | Values accessed using compatible types | Strong typing |
| Initialization Safety | Values initialized before use | Definite initialization |
| Thread Safety | Invariants maintained under concurrency | `Sendable`, actors, Swift 6 |

---

### [MEM-UNSAFE-001] Unsafe Operation Tracking

**Statement**: Unsafe operations MUST be tracked and marked with `unsafe`. Warnings serve as a TODO list.

---

### [MEM-UNSAFE-002] Lifetime Annotations

**Statement**: APIs exposing pointers with limited lifetime MUST use `@_lifetime` annotations.

```swift
// CORRECT
extension Buffer.Aligned {
    @_lifetime(borrow self)
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
        body(UnsafeRawBufferPointer(start: pointer, count: size))
    }
}

// INCORRECT - Pointer can escape scope
func getPointer() -> UnsafeRawPointer { return pointer }
```

---

### [MEM-UNSAFE-003] Safe Attribute

**Statement**: Use `@safe` to assert that a declaration containing unsafe operations maintains safety through careful design.

```swift
@safe
public final class Box<Value: ~Copyable & Sendable>: @unchecked Sendable {
    // Safe despite @unchecked - immutable value with Sendable constraint
}
```

---

### [MEM-SAFE-010] No Dual Public Overloads

**Statement**: Public APIs MUST NOT provide both safe and unsafe overloads. Unsafe implementation SHOULD be `internal` or `@usableFromInline internal`.

---

### [MEM-SAFE-011] Inline Clarity Over Helper Consolidation

**Statement**: Unsafe operations SHOULD be inline and explicit, not hidden behind convenience helpers.

---

### [MEM-SAFE-012] Span as Normative Interface

**Statement**: APIs providing contiguous memory access MUST use `Span` as primary interface. Unsafe pointer access is an escape hatch, not primary API.

```swift
// CORRECT
public struct Buffer {
    public var span: Span<UInt8> { ... }
    @unsafe public func withUnsafeBufferPointer<R>(...) rethrows -> R
}

// INCORRECT - Pointer-first
public struct Buffer {
    public var baseAddress: UnsafePointer<UInt8>? { ... }
}
```

---

### [MEM-SAFE-013] API Surface Reduction as Safety

**Statement**: Removing public unsafe overloads in favor of scoped accessors reduces API surface without reducing capability.

---

### [MEM-SAFE-014] Closure Scope Over Property Access

**Statement**: When `Span` is not applicable, unsafe operations MUST use closure-scoped access (`withUnsafe*`) rather than property access. Properties make unsafe operations look safe.

```swift
// CORRECT - Closure enforces lifetime
path.withUnsafeCString { ptr in usePointer(ptr) }

// INCORRECT - Property makes danger invisible
public var unsafeCString: UnsafePointer<CChar> {
    _storage.baseAddress  // Can escape and dangle
}
```

---

## Ownership

### [MEM-COPY-001] Noncopyable Type Declaration

**Statement**: Types that represent resources with exclusive ownership MUST be marked `~Copyable`.

```swift
enum File {
    struct Descriptor: ~Copyable {
        private let fd: CInt
        deinit { close(fd) }
    }
}
```

**Cross-references**: [PATTERN-014]

---

### [MEM-COPY-001a] Deinit Immutability for ~Copyable Structs

**Statement**: `deinit` on a `~Copyable` struct grants *immutable* access to `self` and its stored fields — the same access level as `borrowing`. `consuming func` grants *mutable* access. These are different in exactly one way: any operation that requires mutation of a field (notably `Optional.take()`) compiles in `consuming` and fails in `deinit` with "cannot use mutating member on immutable value: 'self' is immutable."

**Access level table**:

| Context | Access to `self` | Access to fields | `Optional.take()` |
|---------|------------------|------------------|-------------------|
| `borrowing` | Immutable | Immutable | Fails |
| `deinit` | Immutable | Immutable | Fails |
| `mutating` | Mutable | Mutable | Works |
| `consuming` | Mutable (ownership) | Mutable | Works |

**Correct** — read-only pattern match in deinit:
```swift
struct Scope: ~Copyable {
    private var _token: Shutdown.Token?

    deinit {
        // deinit has immutable access — check presence, do not extract
        guard case .some = _token else { return }
        // Field is consumed by the compiler when self is destroyed
    }

    consuming func close() {
        // consuming grants mutation — extract is allowed
        if let token = _token.take() {
            token.fire()
        }
    }
}
```

**Incorrect** — `.take()` in deinit:
```swift
deinit {
    if let token = _token.take() { token.fire() }   // ❌ self is immutable
}
```

**Key insight**: both `consuming` and `deinit` destroy the value, but they grant different access levels. `consuming` is like `mutating` + destruction; `deinit` is like `borrowing` + destruction. The asymmetry matters when extracting values from Optional fields: `.take()` requires mutation and only works in `consuming`. In `deinit`, fields are consumed by the compiler as part of the value's destruction — you only need to *check presence* for any side effects you need to run, not extract.

**Canonical nil-check idiom for `Optional<~Copyable>` in deinit**: `guard case .some = _optionalField else { return }`. This reads the discriminator without touching the payload. The payload itself is destroyed when the struct is destroyed.

**When you need to run a side effect on the payload before destruction**: the side effect MUST be performed via a `consuming func` before the natural destruction path. If a type must always run a side effect on its resource, pair a `consuming func close()` with a `deinit` that traps on a non-closed state (the linear-type pattern per [MEM-LINEAR-001]).

**Rationale**: The deinit immutability asymmetry is a recurring surprise when moving code between `consuming` methods and `deinit`. It is not a bug — `self` being immutable in `deinit` matches the semantic model: the value is about to cease to exist, so the compiler forbids you from observing it in an intermediate mutated state. The canonical idiom (read-only presence check) preserves the safety model while letting the destructor take local decisions based on whether the Optional is populated.

**Provenance**: Reflection `2026-04-13-scope-mutex-removal-deinit-immutability.md`.

**Cross-references**: [MEM-COPY-001], [MEM-LINEAR-001], [MEM-OWN-001], [MEM-OWN-002]

---

### [MEM-COPY-014] Native Ownership for Resource Types

**Statement**: Types representing resources with lifecycle (file descriptors, handles, allocations) MUST be natively `~Copyable` — ownership is intrinsic to the type, not bolted on via a wrapper. Wrapper patterns (e.g., `Owned<Tag>`) are for cross-module adaptation of types you do not control.

**Correct**:
```swift
// Ownership is native to the type
struct Descriptor: ~Copyable {
    private let fd: CInt
    deinit { close(fd) }
}
```

**Incorrect**:
```swift
// ❌ Ownership bolted on via wrapper
typealias Descriptor = Owned<DescriptorTag>
// The wrapper duplicates what the type should express natively
```

**When to use wrappers**: Only when adapting a type from another module that you cannot modify (e.g., wrapping a C library's handle type). For types you control, make them natively `~Copyable`.

**Rationale**: Analogous to `String` being an owned type (not a wrapper around `UnsafeBufferPointer`). When a type represents a resource with lifecycle, ownership should be expressed at the type level, not through an adapter.

**Cross-references**: [MEM-COPY-001], [IMPL-064]

**Provenance**: 2026-03-30-io-lane-boundary-completion-typed-throws.md

---

### [MEM-COPY-002] Noncopyable in Error Types

**Statement**: `Swift.Error` requires `Copyable`. Move-only values MUST NOT be embedded in `Error` types. Use non-throwing outcome types instead.

```swift
enum Registration.Outcome {
    case success(Registration.Token)
    case failure(Unregistration.Token, Registration.Error)
}
func register(_ token: consuming Unregistration.Token) -> Registration.Outcome
```

---

### [MEM-COPY-003] Noncopyable in Collections

**Statement**: When `~Copyable` types must be stored in collections, wrap the content in a class.

---

### [MEM-COPY-004] Extension Constraints for ~Copyable Types

**Statement**: Extensions MUST include explicit `where Element: ~Copyable` constraints. Without this, extensions implicitly add `where Element: Copyable`.

```swift
// CORRECT - Available for ALL elements
extension Container where Element: ~Copyable {
    func operation() { }
}

// INCORRECT - Implicitly adds 'where Element: Copyable'
extension Container {
    func operation() { }  // Only available when Element: Copyable!
}
```

Applies to **all extension content**: methods, computed properties, nested types, and typealiases. Also applies to extensions on nested types within a generic outer type — even when the outer type already constrains `Element: ~Copyable`.

**Cross-references**: [MEM-COPY-001]

---

### [MEM-COPY-005] Nested Accessor Pattern Incompatibility

**Statement**: Non-consuming nested accessor patterns are incompatible with `~Copyable` containers. The accessor struct must store a reference to the container, which requires copying.

For `~Copyable` containers: keep container Copyable, use direct methods, or wait for language evolution.

**Cross-references**: [API-NAME-002], [MEM-COPY-001]

---

### [MEM-COPY-006] ~Copyable Propagation Gotchas

**Statement**: Swift's `~Copyable` suppression fails across certain boundaries:

| Category | Boundary | Status |
|----------|----------|--------|
| 1 | Extension declaration site (value-generic nested types) | RESOLVED in 6.2.4 |
| 2 | Implicit Copyable in extensions | By design — add explicit `where Element: ~Copyable` |
| 3 | Protocol conformance in separate files | Move conformances to same file |
| 4 | Sequence/Collection protocol requirements | No workaround; use `forEach` with borrowing closures |
| 5 | Module emission phase (compound constraints + separate file + Lifetimes flag) | Consolidate to single file |
| 6 | Non-escaping closure capture consumption | Stage through Copyable reference before closure boundary |

**Category 6 detail**: Non-escaping closures cannot consume a `~Copyable` capture without reinitializing it — even when the capture is consumed exactly once on all paths. The compiler demands reinitialization regardless of the callee's guarantee of total consumption. This affects any `withLock { state in state.method(consuming element) }` pattern where `element: ~Copyable` is captured. The ecosystem solution: pass the element as a closure parameter via `withLock(consuming:body:)` ([MEM-OWN-010]) or stage through `Ownership.Slot` (a Copyable reference wrapper) before the closure boundary.

**Cross-module propagation**: RESOLVED in Swift 6.2.4.

**Workaround hierarchy**: (1) explicit `where Element: ~Copyable`, (2) same-file conformances, (3) single-file consolidation, (6) `Ownership.Slot` or `withLock(consuming:body:)`.

**Tracking**: Category 5 — Swift issue #86669

**Cross-references**: [MEM-COPY-004], [MEM-COPY-005], [MEM-OWN-010], [IMPL-070]

---

### [MEM-OWN-001] Consuming Parameters

**Statement**: Use `consuming` when taking ownership. Caller cannot use the value after passing it.

---

### [MEM-OWN-002] Borrowing Parameters

**Statement**: Use `borrowing` for read-only access without ownership transfer.

---

### Ownership Table

| Keyword | Ownership | Caller After Call | Callee Can |
|---------|-----------|-------------------|------------|
| `consuming` | Transferred to callee | Cannot use value | Store, consume |
| `borrowing` | Retained by caller | Can use value | Read only |
| `inout` | Temporarily loaned | Can use value | Mutate |

---

### Type-Level Ownership Naming

**Statement**: A primitive named after a **reference** (Address, Pointer, Handle) SHOULD be non-owning and `Copyable`. A primitive named after a **resource** (String, Array, Allocation) SHOULD be owning and MAY provide a `.View` borrowing type.

---

## Linear and Affine Types

### [MEM-LINEAR-001] Exactly-Once Types

**Statement**: Linear types MUST be `~Copyable` with a `consuming func` for the use operation and a `deinit` that traps if not consumed.

---

### [MEM-LINEAR-002] At-Most-Once Types

**Statement**: Affine types MUST be `~Copyable` with a `consuming func` and a silent `deinit` (no trap).

| Semantics | `deinit` Behavior |
|-----------|-------------------|
| Exactly-once (linear) | `preconditionFailure` |
| At-most-once (affine) | Silent — unused is valid |

---

### [MEM-LINEAR-003] Proof Categories

| Invariant | Ownership Encoding | Compiler Enforcement |
|-----------|-------------------|---------------------|
| Exactly-once use | `~Copyable` + `consuming func` + `deinit` trap | Double-use at compile time; dropped-without-use at runtime |
| At-most-once use | `~Copyable` + `consuming func` + silent `deinit` | Double-use at compile time |
| Transfer semantics | `consuming` parameter | Caller cannot use value after transfer |
| Borrow semantics | `borrowing` parameter | Callee cannot consume or store |

---

## Span Access

### [MEM-SPAN-001] Property-Based Span Access

**Statement**: Types that expose `Span` or `MutableSpan` MUST use property-based access, not closure-based `withSpan(_:)`.

```swift
var span: Span<Element> {
    @_lifetime(borrow self)
    borrowing get { /* ... */ }
}
```

`Span` is `~Escapable` — the type system enforces scoping, making closures unnecessary.

**Cross-references**: [MEM-COPY-001], SE-0456

---

## Concurrency Safety

### [MEM-SEND-001] Conservative Sendable Defaults

**Statement**: Mutable reference wrappers MUST NOT be unconditionally `@unchecked Sendable` unless they provide synchronization.

```swift
// CORRECT - Conditional
extension Reference.Indirect: @unchecked Sendable where Value: Sendable {}

// INCORRECT - Unconditional
extension Reference.Indirect: @unchecked Sendable {}
```

---

### [MEM-SEND-002] Sendability Tiers

| Tier | When | Example |
|------|------|---------|
| Checked Sendable | Immutable, all fields Sendable | `struct Point: Sendable` |
| Conditional Sendable | Sendable when generic param is | `extension Box: Sendable where T: Sendable` |
| Unchecked Sendable | Synchronized by construction | `Slot`, `Transfer` (atomic state) |
| Not Sendable | Mutable without synchronization | `Indirect` base type |
| Explicit Escape | Caller asserts safety | `Indirect.Unchecked` |

---

### [MEM-SEND-003] Accurate Risk Description

**Statement**: When justifying unsafe escapes, describe the risk accurately — not euphemistically.

| Euphemistic | Accurate |
|-------------|----------|
| "`@unchecked Sendable` means transferable" | "Removing the compiler's data-race prevention" |

---

### [MEM-SEND-004] ~Copyable Structs Can Use Plain Sendable

**Statement**: `~Copyable` structs whose stored properties are all `Sendable` MUST use plain `Sendable`, not `@unchecked Sendable`. The compiler synthesizes and checks `Sendable` conformance for `~Copyable` structs in the same way as `Copyable` structs.

**Correct**:
```swift
public struct Channel.Reader<Element: ~Copyable & Sendable>: ~Copyable, Sendable {
    let descriptor: Kernel.Descriptor  // Sendable
}
```

**Incorrect**:
```swift
public struct Channel.Reader<Element: ~Copyable & Sendable>: ~Copyable, @unchecked Sendable {
    let descriptor: Kernel.Descriptor  // ❌ @unchecked is unnecessary — all fields are Sendable
}
```

**When `@unchecked` IS still needed on `~Copyable` types**: When stored properties include non-Sendable types with internal synchronization (e.g., `UnsafeMutablePointer` to a lock-protected region). In this case, `@unchecked` is about the non-Sendable field, not about `~Copyable`.

**Rationale**: The assumption that `~Copyable` types require `@unchecked Sendable` is a common misconception. It was disproven empirically across swift-async-primitives (19 annotations removed) and swift-io (3 annotations removed). `@unchecked` suppresses the compiler's data-race checking — never use it when the compiler can verify safety directly.

**Cross-references**: [MEM-SEND-001], [MEM-SEND-002], [MEM-SEND-003], [MEM-COPY-001]

**Provenance**: 2026-03-31-convention3-unchecked-sendable-audit.md

---

## Ownership Techniques

### [MEM-COPY-010] Noncopyable Workarounds for Associated Types

**Statement**: When Swift doesn't support `associatedtype T: ~Copyable`, use `Reference.Box<T>` as a workaround.

---

### [MEM-COPY-011] Two-World Separation for Owned and Borrowed Types

**Statement**: When a type has both owned (escapable) and borrowed (`~Escapable`) variants with fundamentally different properties, they MUST be represented as separate types with separate protocol conformances — not unified through abstraction.

**The Constraint Triangle** (Swift 6.x) — three desirable properties cannot all be satisfied:
1. Reuse existing protocol infrastructure
2. Keep borrowed type `~Escapable` (compile-time lifetime safety)
3. Keep zero-copy parsing

| World | Prioritizes | Sacrifices | Use Case |
|-------|-------------|------------|----------|
| **Owned** | (1) + combinator reuse | (2) compile-time safety | Cross-task transfer, recursive structures |
| **Borrowed** | (2) + (3) zero-copy | (1) separate protocol | Maximum performance, scoped parsing |

**Correct** — two separate protocols:
```swift
public protocol Parser<Input, Output, Failure> {
    associatedtype Input  // Must be Escapable (language limitation)
    func parse(_ input: inout Input) throws(Failure) -> Output
}

extension Binary.Bytes {
    public protocol Parser<Output, Failure> {
        mutating func parse(_ input: inout Input.View) throws(Failure) -> Output
    }
}

// Bridge for cross-world reuse
struct Bridge<P: Parsing.Parser>: Binary.Bytes.Parser { ... }
```

**Incorrect** — forcing unification:
```swift
public protocol Parser<Input, Output, Failure> {
    associatedtype Input: ~Escapable  // ❌ Cannot do this in Swift 6.x
}
```

| Property | Owned | Borrowed |
|----------|-------|----------|
| Storage | Indefinite | Scoped to borrow lifetime |
| Task transfer | Safe | Cannot cross task boundaries |
| Recursive structures | Yes | No |
| Lifetime safety | Runtime contract | Compile-time enforcement |

**Cross-references**: [MEM-COPY-010], [MEM-LINEAR-001], [IMPL-065]

---

### [MEM-COPY-012] Protocol Property Dispatch for ~Copyable Return Types

**Statement**: Protocol properties with `~Copyable` return types dispatch through `_read` (yielding a borrowed value), while protocol *functions* return owned values.

| Declaration | Dispatch | Ownership of Return |
|-------------|----------|-------------------|
| `var body: Body { get }` | `_read` coroutine | Borrowed (caller cannot store) |
| `func body() -> Body` | Function entry | Owned (caller can store) |

**Workaround**: Store the *container* and compute the `~Copyable` value transiently (see [IMPL-036]).

**Cross-references**: [MEM-COPY-005], [MEM-COPY-006], [IMPL-036]

---

### [MEM-COPY-013] Redundant Annotations on Compiler Optimization Boundaries

**Statement**: When a type annotation (e.g., `~Escapable`) is semantically redundant because the usage context already provides the same guarantee, AND the annotation triggers a known compiler optimization bug, the annotation SHOULD be omitted until the compiler is fixed.

**Canonical example**: `Property.View` omits `~Escapable` because the `_read`/`_modify` coroutine scope already prevents escape. Adding it triggers CopyPropagation crashes.

**Cross-references**: [MEM-COPY-012], [IMPL-061]

---

### [MEM-LIFE-001] ~Escapable Class Stored Property Limitation

**Statement**: `~Escapable` types accessed through class stored properties trigger lifetime checker errors ("lifetime-dependent value escapes its scope"). This is a known limitation of the `Lifetimes` feature in Swift 6.3. Use `~Copyable` alone when the view must be accessed through a class property — the `_read` coroutine scope prevents escape, `~Copyable` prevents aliasing.

**Affected pattern**: Mutex `Locked` view, Property.View-like types stored in classes.

**When resolved**: Add `~Escapable` back to the view type for stronger compile-time safety.

**Cross-references**: [MEM-COPY-013], [IMPL-071], [Research: noncopyable-ergonomics-compiler-state.md]

---

### [MEM-OWN-010] Always-Consume Transfer (Closure Path)

**Statement**: When every code path through a `Mutex.withLock` closure consumes a `~Copyable` value, the value MUST be passed as a `consuming` closure parameter via `withLock(consuming:body:)`. The Optional wrapper mechanism (`.take()!`) is confined to the extension's implementation per [IMPL-070].

**Note**: For new code, prefer the coroutine accessor pattern (`_state.locked.value`) per [IMPL-070]. This closure pattern is backward compatibility for existing `withLock` call sites.

**Call site** (reads as intent):
```swift
_state.withLock(consuming: element) { state, element in
    state.buffer.push(consume element, to: .back)
}
```

**When to use**: The value is always consumed — buffered, delivered, or dropped. No code path retains it.

**Cross-references**: [IMPL-INTENT], [IMPL-067], [IMPL-070], [Research: noncopyable-ownership-transfer-patterns.md]

---

### [MEM-OWN-011] Maybe-Consume Transfer (Closure Path)

**Statement**: When a state machine decides per-path whether to consume a `~Copyable` value, the state machine method MUST take `inout Element?`. It uses `.take()!` on consume paths and leaves the Optional populated on non-consume paths. The caller passes `&slot` through standard `withLock`.

**Call site** (reads as intent):
```swift
let action = storage.withLock { state in
    state.send(&slot)  // state decides whether to take
}
```

**State machine** (mechanism confined here):
```swift
mutating func send(_ element: inout Element?) -> Send.Action {
    guard !_closed else { return .shut }          // leave element
    if hasReceiver { return .give(element.take()!) }  // take element
    buffer.push(element.take()!, to: .back); return .keep  // take element
}
```

**When to use**: Some paths consume (deliver, buffer), others don't (suspend, reject). A state machine determines the outcome.

**Cross-references**: [IMPL-INTENT], [IMPL-067], [IMPL-070], [Research: noncopyable-ownership-transfer-patterns.md]

---

### [MEM-OWN-012] Action Enum Dispatch

**Statement**: When a `Mutex.withLock` closure performs a state transition that requires post-lock side effects, the closure MUST return a `~Copyable` action enum. Side effects (continuation resume, element delivery) happen outside the lock via `switch consume action`. Continuations MUST be resumed post-lock to prevent reentrancy and deadlock.

```swift
// Inside lock: pure state transition
let action: _Take = _state.withLock { state in
    if let element = state.buffer.pop(from: .front) { return .element(element) }
    if state.isFinished { return .finished }
    return .suspend
}

// Outside lock: side effects
switch consume action {
case .element(let element): return element
case .finished: return nil
case .suspend: break
}
```

**Cross-references**: [IMPL-INTENT], [IMPL-070], [Research: noncopyable-ownership-transfer-patterns.md]

---

### [MEM-OWN-013] Consuming Does Not Suppress Deinit

**Statement**: A `consuming func` that extracts a value from a `~Copyable` type does NOT prevent `deinit` from running on the remaining stored properties. When a `consuming func` must signal to `deinit` that a value has already been extracted, the type MUST use a tracking flag (typically `Atomic<Bool>`) checked in `deinit`.

**Correct**:
```swift
struct Handle<Value: ~Copyable>: ~Copyable {
    private let _box: Reference.Box<Value>
    private let _taken = Atomic<Bool>(false)

    consuming func value() async throws(E) -> Value {
        _taken.store(true, ordering: .releasing)
        return _box.take()
    }

    deinit {
        guard !_taken.load(ordering: .acquiring) else { return }
        // Cleanup only if value was NOT already extracted
        _box.dispose()
    }
}
```

**Incorrect**:
```swift
struct Handle<Value: ~Copyable>: ~Copyable {
    private let _box: Reference.Box<Value>

    consuming func value() async throws(E) -> Value {
        return _box.take()
        // ❌ Assumes deinit won't run — it WILL run on _box
    }
}
```

**Rationale**: In Swift, a `consuming func` that does not `discard self` still runs `deinit` on all remaining stored properties. The mental model "consuming takes ownership, so deinit doesn't run" is incorrect. This is analogous to Rust's pre-drop-flag-removal era where a `moved` flag tracked partial moves.

**Cross-references**: [MEM-LINEAR-001], [MEM-LINEAR-002], [MEM-COPY-001]

**Provenance**: 2026-03-26-io-api-remediation-sync-submission.md

---

### [MEM-OWN-014] Batch Slot Staging for Non-Sendable Sequences

**Statement**: When a `Sequence` of non-Sendable elements must enter a `withLock` closure, the elements MUST be staged through `Ownership.Slot(Array(elements))` before the lock. Inside the lock, iterate from the Slot. The `sending` annotation on the parameter alone is not sufficient — captured sequences merge with the `inout sending State` region.

**Correct**:
```swift
func send<S: Sequence>(contentsOf elements: sending S)
    where S.Element == Element
{
    let slot = Ownership.Slot(Array(elements))
    let action = _state.withLock { state in
        let items = slot.take()
        for element in items {
            state.buffer.push(element, to: .back)
        }
        return state.signal()
    }
    action.execute()
}
```

**Incorrect**:
```swift
func send<S: Sequence>(contentsOf elements: sending S) {
    let action = _state.withLock { state in
        for element in elements {  // ❌ Captured `elements` merges with state region
            state.buffer.push(element, to: .back)
        }
        return state.signal()
    }
}
```

**Rationale**: `sending` transfers region ownership at the call boundary, but inside the closure, the captured value merges with the `inout sending State` parameter's region. `Ownership.Slot` is `@unchecked Sendable` — values taken from it are treated as "disconnected" from any region.

**Cross-references**: [MEM-OWN-010], [MEM-COPY-006] Category 6, [IMPL-070]

**Provenance**: 2026-03-30-sending-sendable-migration-cascade.md

---

## Reference Primitives

### [MEM-REF-001] Reference Primitive Selection

| Type | Ownership | Mutability | Sendable |
|------|-----------|------------|----------|
| `Reference.Box` | Strong | Immutable | When `Value: Sendable` |
| `Reference.Indirect` | Strong | Mutable | Not Sendable (use `.Unchecked`) |
| `Reference.Weak` | Weak | N/A | When `Object: Sendable` |
| `Reference.Unowned` | Unowned | N/A | Not Sendable |
| `Reference.Slot` | Strong | Move semantics | `@unchecked` (atomic) |
| `Reference.Transfer` | One-shot | Move-only | Tokens are Sendable |
| `Reference.Sendability.Unchecked` | N/A | Immutable | `@unchecked` (assertion) |

---

### [MEM-REF-002] Reference.Box

**Statement**: Use `Reference.Box` for immutable heap allocation of `~Copyable` values.

---

### [MEM-REF-003] Reference.Indirect

**Statement**: Use `Reference.Indirect` for mutable heap-allocated values. NOT Sendable by design. Use `.Unchecked` for explicit cross-isolation transfer.

---

### [MEM-REF-004] Reference.Transfer

**Statement**: Use `Reference.Transfer` for moving `~Copyable` values across `@Sendable` boundaries with exactly-once semantics.

| Type | Use Case | Allocation |
|------|----------|------------|
| `Cell<T>` | Pass existing value through escaping boundary | One (box) |
| `Storage<T>` | Create inside closure, retrieve after | One (box) |
| `Retained<T>` | Zero-allocation class transfer | Zero |

All invariant violations trap deterministically (not undefined behavior).

---

### [MEM-REF-005] Reference.Slot

**Statement**: Use `Reference.Slot` for atomic, reusable store/take operations on `~Copyable` values.

Key difference from Transfer: Transfer is one-shot; Slot is reusable (empty <-> filled, cycles indefinitely).

---

## Lifetime Primitives

### [MEM-LIFE-001] Lifetime.Scoped

**Statement**: Use `Lifetime.Scoped` for RAII-style deterministic cleanup when scope exits.

---

### [MEM-LIFE-002] Lifetime.Lease

**Statement**: Use `Lifetime.Lease` for temporary access with guaranteed return.

---

### [MEM-LIFE-003] Lifetime.Disposable

**Statement**: Conform to `Lifetime.Disposable` for types requiring explicit cleanup. Implementations MUST be idempotent.

---

### [MEM-LIFE-004] Experimental Lifetime Annotation Version Skew

**Statement**: The `@_lifetime` experimental annotation has incompatible semantics between Swift compiler versions:

| Compiler | Constraint |
|----------|-----------|
| 6.2.x | Requires `@_lifetime(self: ...)` on mutating methods where `self` is `~Escapable` |
| 6.4-dev | Rejects `@_lifetime` when the return type is `Escapable`, regardless of `self`'s escapability |

These constraints are **contradictory** for `~Escapable self` methods returning `Escapable` types. No source-level annotation satisfies both compilers simultaneously.

**Cross-references**: [MEM-LIFE-001], [MEM-COPY-013]

---

### [MEM-LIFE-005] Nested Coroutine ~Escapable Scope Limitation

**Statement**: A `~Escapable` value produced inside an inner `_read` coroutine MUST NOT be yielded from an outer `_read` coroutine. The inner value's lifetime is tied to the inner scope, which ends before the outer yield can deliver the value to the caller.

```swift
// FAILS — inner ~Escapable cannot escape to outer scope
var outer: Ownership.Borrow<Element> {
    _read {
        var inner_view = unsafe Property<Peek, Buffer>.View(&self.buffer)
        yield inner_view.first  // ❌ Borrow<Element> lifetime tied to inner_view's scope
    }
}
```

**This applies to any nested coroutine composition**: not just `_read` + `_read`, but any pattern where an outer coroutine attempts to yield a lifetime-dependent value from an inner scope. The limitation is fundamental to Swift's coroutine scoping model — the inner scope's stack frame is deallocated before the outer yield suspends.

**Workarounds**: Return Copyable projections (extract scalar values) or use closure-based access (`func peek<R>(_ body: (borrowing Element) -> R) -> R?`).

**Cross-references**: [IMPL-079], [IMPL-065], [MEM-COPY-013], [MEM-LIFE-001]

**Provenance**: 2026-03-31-noncopyable-peek-escapable-scope-nesting-limit.md

---

### [MEM-LIFE-006] ~Escapable Parameters in Async Methods

**Scope**: Async functions accepting `Span<T>` or `MutableSpan<T>` parameters.

**Statement**: `~Escapable` function parameters (`Span<T>`, `inout MutableSpan<T>`) CAN be used in `async` methods and survive across suspension points (`await`). The compiler ties their lifetime to the function scope — not to the synchronous interval between suspensions.

| Path | Parameter type | Why it works |
|------|---------------|--------------|
| Read | `inout MutableSpan<T>` | Coroutine stores a reference to caller's buffer; the `inout` binding is alive for the full function scope |
| Write | `Span<T>` | Value parameter; alive for the full function scope |
| Partial-write retry | `Span<T>` + `extracting(droppingFirst:)` | Sub-span derived from parameter; same lifetime |

**Correct** — Span across await in retry loop:
```swift
public mutating func write(
    _ buffer: Span<UInt8>
) async throws(IO.Event.Failure) -> Int {
    while true {
        // ... attempt syscall with buffer ...
        case .wouldBlock:
            try await arm()  // Span survives this suspension
        // ...
    }
}
```

**Correct** — MutableSpan across await:
```swift
public mutating func read(
    into buffer: inout MutableSpan<UInt8>
) async throws(IO.Event.Failure) -> Int {
    while true {
        // ... attempt syscall into &buffer ...
        case .wouldBlock:
            try await arm()  // inout MutableSpan survives this suspension
        // ...
    }
}
```

**Correct** — `extracting(droppingFirst:)` replaces pointer arithmetic for partial writes:
```swift
public mutating func write(
    all data: Span<UInt8>
) async throws(IO.Error) {
    var offset = 0
    while offset < data.count {
        let slice = data.extracting(droppingFirst: offset)
        let n = try await channel.write(slice)
        offset += n
    }
}
```

**The limitation remains**: `~Escapable` values cannot be *stored* in class fields or captured in `@escaping` closures ([MEM-LIFE-001]). Async function parameters are fine because the parameter lifetime is scoped to the function call — the caller's buffer is guaranteed alive until the function returns.

**Empirical proof**: swift-io Channel migration (commit `6a691f88`) — replaced 18 unsafe pointer sites with Span/MutableSpan parameters in async methods with EAGAIN retry loops.

**Cross-references**: [MEM-SPAN-001], [MEM-LIFE-001], [MEM-SAFE-012]

**Provenance**: HANDOFF-escapable-async-skill-update.md (swift-io unsafe pointer audit)

---

## Post-Implementation Checklist

Before presenting code as complete, verify EACH item:

**Safety isolation:**
- [ ] Types with unsafe storage use `@safe`, not `@unsafe` [MEM-SAFE-021]
- [ ] `@unsafe` only on escape hatches, primary API is safe [MEM-SAFE-022]
- [ ] Unsafe pointer storage is `private`/`internal`, not `public` [MEM-SAFE-023]
- [ ] `@unchecked Sendable` has `@unsafe` on the conformance [MEM-SAFE-024]
- [ ] `nonisolated(unsafe)` encapsulated globals have `@safe` [MEM-SAFE-025]

**Strict memory safety:**
- [ ] `.strictMemorySafety()` enabled [MEM-SAFE-001]
- [ ] Each unsafe operation has its own `unsafe` acknowledgment [MEM-SAFE-002]

**Ownership:**
- [ ] All `~Copyable` constraints are at extension level, not method level [MEM-COPY-004]
- [ ] Ownership annotations (`consuming`, `borrowing`, `inout`) are correct [MEM-OWN-001]
- [ ] `deinit` bodies explicitly clean up all ~Copyable stored properties [MEM-LINEAR-001]
- [ ] No implicit `Copyable` constraints leak through unconstrained extensions [MEM-COPY-006]

**Concurrency:**
- [ ] Sendable conformances use the correct tier [MEM-SEND-002]

If ANY item fails, fix before presenting.

---

## Cross-References

See also:
- **implementation** skill for [IMPL-*] expression style, Property.View patterns
- **implementation** skill for [COPY-FIX-*] ~Copyable constraint patterns (absorbed from copyable-remediation)
- **implementation** skill for [PATTERN-026–028] centralization and refactoring patterns (absorbed from advanced-patterns)
