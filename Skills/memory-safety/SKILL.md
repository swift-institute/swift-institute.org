---
name: memory-safety
description: |
  Strict memory safety, unsafe marking, sendable conformance, and reference primitives.
  Apply when working with unsafe operations, reference types, or concurrency safety.

layer: implementation

requires:
  - swift-institute
  - memory

applies_to:
  - swift
  - swift6
  - primitives

migrated_from: Documentation.docc/Memory Safety.md
migration_date: 2026-01-28
---

# Memory Safety

Strict memory safety patterns per SE-0458, reference primitives, and lifetime management.

**Source documents**: Memory Safety.md, Memory Reference.md

---

## Strict Memory Safety

### [MEM-SAFE-001] Enable Strict Memory Safety

**Scope**: Memory-critical packages.

**Statement**: Memory-critical packages MUST enable strict memory safety via `.strictMemorySafety()`.

```swift
// Package.swift
.target(
    name: "Buffer Primitives",
    dependencies: [],
    swiftSettings: [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety(),
    ]
)
```

---

### [MEM-SAFE-002] Unsafe Expression Marking

**Scope**: Marking unsafe operations in strict mode.

**Statement**: Each unsafe operation requires its own `unsafe` acknowledgment. Expression granularity.

```swift
// CORRECT
@unsafe
public func allocate(capacity: Int) -> UnsafeMutablePointer<Element> {
    let ptr = unsafe UnsafeMutablePointer<Element>.allocate(capacity: capacity)
    unsafe ptr.initialize(repeating: .init(), count: capacity)
    return ptr
}

// For assignments to unsafe storage, use parentheses
unsafe (self.raw = Unmanaged.passRetained(instance).toOpaque())

// INCORRECT
self.raw = unsafe Unmanaged.passRetained(instance).toOpaque()  // Destination uncovered
```

- `@unsafe` on a function declares that *calling* is unsafe
- Operations *within* still require individual `unsafe` markers
- Parentheses define the expression boundary for assignments

---

### [MEM-SAFE-003] Warning Classification

**Scope**: Handling StrictMemorySafety warnings.

**Statement**: Two buckets:

| Category | Description | Action |
|----------|-------------|--------|
| **Bucket A** | Operations requiring `unsafe` acknowledgment | Mark with `unsafe` |
| **Bucket B** | "Struct has storage involving unsafe types" | Audit marker only — no action needed |

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

## Unsafe Operation Tracking

### [MEM-UNSAFE-001] Unsafe Operation Tracking

**Statement**: Unsafe operations MUST be tracked and eventually marked with `unsafe`. Warnings serve as a TODO list.

| Warning Type | Response | Timeline |
|--------------|----------|----------|
| Pointer operations | Mark with `unsafe` | Now |
| C interop calls | Mark with `unsafe` | Now |
| Concurrency isolation | Fix immediately | Now |

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
func getPointer() -> UnsafeRawPointer {
    return pointer
}
```

---

### [MEM-UNSAFE-003] Safe Attribute

**Statement**: Use `@safe` to assert that a function containing unsafe operations maintains safety through careful design.

```swift
@safe
public final class Box<Value: ~Copyable & Sendable>: @unchecked Sendable {
    // Safe despite @unchecked - immutable value with Sendable constraint
}
```

---

## Safety Techniques

### [MEM-SAFE-010] No Dual Public Overloads

**Statement**: Public APIs MUST NOT provide both safe and unsafe overloads. Unsafe implementation SHOULD be `internal` or `@usableFromInline internal`.

```swift
// CORRECT
public func process(_ data: [UInt8]) -> Result {
    data.withUnsafeBufferPointer { _processUnsafe($0) }
}

@usableFromInline
internal func _processUnsafe(_ buffer: UnsafeBufferPointer<UInt8>) -> Result { ... }

// INCORRECT - Both public
public func process(_ data: [UInt8]) -> Result
public func process(_ buffer: UnsafeBufferPointer<UInt8>) -> Result
```

---

### [MEM-SAFE-011] Inline Clarity Over Helper Consolidation

**Statement**: Unsafe operations SHOULD be inline and explicit, not hidden behind convenience helpers.

```swift
// CORRECT - Danger visible
let result = pointer.withMemoryRebound(to: UInt32.self, capacity: count) { typed in
    typed.baseAddress!.pointee
}

// INCORRECT - Danger hidden
func readUInt32(from pointer: UnsafeRawPointer) -> UInt32 {
    pointer.assumingMemoryBound(to: UInt32.self).pointee
}
```

---

### [MEM-SAFE-012] Span as Normative Interface

**Statement**: APIs providing contiguous memory access SHOULD use `Span` as primary interface. Unsafe pointer access is an escape hatch, not primary API.

```swift
// CORRECT
public struct Buffer {
    public var span: Span<UInt8> { ... }
    // Escape hatch for interop
    public func withUnsafeBufferPointer<R>(...) rethrows -> R
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

**Statement**: Unsafe operations MUST use closure-scoped access (`withUnsafe*`) rather than property access. Properties make unsafe operations look safe.

```swift
// CORRECT - Closure enforces lifetime
path.withUnsafeCString { ptr in
    usePointer(ptr)
}

// INCORRECT - Property makes danger invisible
public var unsafeCString: UnsafePointer<CChar> {
    _storage.baseAddress  // Can escape and dangle
}
```

---

## Concurrency Safety (Sendable)

### [MEM-SEND-001] Conservative Sendable Defaults

**Statement**: Mutable reference wrappers MUST NOT be unconditionally `@unchecked Sendable` unless they provide synchronization.

```swift
// CORRECT
extension Reference.Indirect: @unchecked Sendable where Value: Sendable {}

// Explicit unsafe escape
extension Reference.Indirect {
    public struct Unchecked: @unchecked Sendable {
        public let indirect: Reference.Indirect<Value>
    }
}

// INCORRECT
extension Reference.Indirect: @unchecked Sendable {}  // Hidden footgun
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
| "This is about transferability" | "The compiler will not warn when this creates races" |
| "`@unchecked Sendable` means transferable" | "Removing the compiler's data-race prevention" |

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

```swift
@safe
public final class Box<Value: ~Copyable & Sendable>: @unchecked Sendable {
    public let value: Value
    @inlinable public init(_ value: consuming Value) { self.value = value }
}
```

Use cases: heap allocation for stable identity, type erasure, breaking recursive types.

---

### [MEM-REF-003] Reference.Indirect

**Statement**: Use `Reference.Indirect` for mutable heap-allocated values. NOT Sendable by design.

```swift
@safe
public final class Indirect<Value: ~Copyable> {
    public var value: Value { _read { yield _value } _modify { yield &_value } }
    public func withValue<Result>(_ body: (borrowing Value) throws -> Result) rethrows -> Result
    public func update<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result
}
```

Use `.Unchecked` for explicit cross-isolation transfer.

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

Key difference from Transfer: Transfer is one-shot; Slot is reusable (empty ↔ filled, cycles indefinitely). All operations atomic via release/acquire barriers.

---

## Lifetime Primitives

### [MEM-LIFE-001] Lifetime.Scoped

**Statement**: Use `Lifetime.Scoped` for RAII-style deterministic cleanup when scope exits.

```swift
let file = Lifetime.Scoped(FileHandle(path: "/tmp/x")) { $0.close() }
// use file.value...
// close() called automatically at scope exit
```

---

### [MEM-LIFE-002] Lifetime.Lease

**Statement**: Use `Lifetime.Lease` for temporary access with guaranteed return.

```swift
var lease = borrow(myResource)
// use lease.value...
let returned = lease.release()  // Must call to get value back
```

---

### [MEM-LIFE-003] Lifetime.Disposable

**Statement**: Conform to `Lifetime.Disposable` for types requiring explicit cleanup. Implementations MUST be idempotent.

---

## Cross-References

See also:
- **memory** skill for ~Copyable types, ownership, linear types
- **copyable-remediation** skill for fixing constraint propagation failures
