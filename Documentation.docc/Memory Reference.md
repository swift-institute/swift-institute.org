# Memory Reference

<!--
---
title: Memory Reference
version: 1.0.0
last_updated: 2026-01-19
applies_to: [swift-primitives, swift-institute, swift-standards, swift-foundations]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Reference primitives: Box, Indirect, Weak, Unowned, Slot, and Transfer.

## Overview

This document defines reference primitives from `swift-reference-primitives`.

**Applies to**: Types in `swift-reference-primitives`.

---

## [MEM-REF-001] Reference Primitive Selection

**Scope**: Choosing the correct reference primitive.

**Statement**: Choose reference primitives by their ownership/mutability/Sendable contract.

| Type | Ownership | Mutability | Sendable |
|------|-----------|------------|----------|
| `Reference.Box` | Strong | Immutable | When `Value: Sendable` |
| `Reference.Indirect` | Strong | Mutable | Not Sendable (use `.Unchecked`) |
| `Reference.Weak` | Weak | N/A | When `Object: Sendable` |
| `Reference.Unowned` | Unowned | N/A | Not Sendable (use `.Sendable.*`) |
| `Reference.Slot` | Strong | Move semantics | `@unchecked` (atomic sync) |
| `Reference.Transfer` | One-shot | Move-only | Tokens are Sendable |
| `Reference.Sendability.Unchecked` | N/A | Immutable | `@unchecked` (assertion) |

**Use Cases**:
 `Box`
 `Indirect`
 `Weak`
 `Slot`
 `Transfer`
 `Sendability.Unchecked`

---

## [MEM-REF-002] Reference.Box

**Scope**: Immutable heap-allocated values.

**Statement**: Use `Reference.Box` for immutable heap allocation of `~Copyable` values.

```swift
@safe
public final class Box<Value: ~Copyable & Sendable>: @unchecked Sendable {
    public let value: Value

    @inlinable
    public init(_ value: consuming Value) {
        self.value = value
    }
}
```

**Use Cases**:
- Heap allocation for values needing stable identity
- Type erasure via `Unmanaged` + `UnsafeRawPointer`
- Breaking recursive type definitions
- Storage for `~Copyable` types requiring heap allocation

---

## [MEM-REF-003] Reference.Indirect

**Scope**: Mutable shared state with reference semantics.

**Statement**: Use `Reference.Indirect` for mutable heap-allocated values. It is NOT Sendable by design.

```swift
@safe
public final class Indirect<Value: ~Copyable> {
    @usableFromInline
    var _value: Value

    public var value: Value {
        _read { yield _value }
        _modify { yield &_value }
    }

    public func withValue<Result>(
        _ body: (borrowing Value) throws -> Result
    ) rethrows -> Result

    public func update<Result>(
        _ body: (inout Value) throws -> Result
    ) rethrows -> Result
}

// For cross-isolation transfer, use explicit opt-in:
extension Reference.Indirect where Value: ~Copyable {
    public struct Unchecked: @unchecked Sendable {
        public let indirect: Reference.Indirect<Value>
    }
}
```

**Use Cases**:
- Breaking infinite-size cycles in recursive definitions
- Shared mutable state with identity
- Heap allocation for values needing stable identity

**Thread Safety**: Provides no synchronization. Wrap synchronized types if needed.

---

## [MEM-REF-004] Reference.Transfer

**Scope**: Cross-boundary ownership transfer.

**Statement**: Use `Reference.Transfer` types for moving `~Copyable` values across `@Sendable` boundaries with exactly-once semantics.

**Transfer Variants**:

| Type | Use Case | Allocation |
|------|----------|------------|
| `Cell<T>` | Pass existing value through escaping boundary | One (box) |
| `Storage<T>` | Create inside closure, retrieve after | One (box) |
| `Retained<T>` | Zero-allocation class transfer | Zero |

**Cell Pattern** (pass existing value):
```swift
let cell = Reference.Transfer.Cell(myValue)
let token = cell.token()
spawnThread {
    let value = token.take()  // Exactly once, enforced atomically
}
```

**Storage Pattern** (create inside, retrieve after):
```swift
let storage = Reference.Transfer.Storage<MyType>()
let storeToken = storage.token
spawnThread {
    storeToken.store(createValue())  // Producer
}
let value = storage.take()  // Consumer
```

**Safety Guarantees**:
- Tokens are Copyable (required for escaping closure capture)
- All invariant violations trap deterministically (not undefined behavior)
- ARC-managed storage with atomic one-shot enforcement

---

## [MEM-REF-005] Reference.Slot

**Scope**: Reusable heap slot with move semantics.

**Statement**: Use `Reference.Slot` for atomic, reusable store/take operations on `~Copyable` values.

```swift
@safe
public final class Slot<Value: ~Copyable & Sendable>: @unchecked Sendable {
    // State machine: empty ↔ initializing ↔ full

    public func store(_ value: consuming Value) -> Store
    public func take() -> Value?
}

public enum Store: ~Copyable {
    case stored
    case occupied(Value)  // Returns value on failure
}
```

**Key Difference from Transfer**:
 taken, then done)
- `Slot`: Reusable (empty ↔ filled, can cycle indefinitely)

**Thread Safety**: All operations are atomic via release/acquire barriers.

---

## Lifetime Primitives

### [MEM-LIFE-001] Lifetime.Scoped

**Scope**: RAII-style deterministic cleanup.

**Statement**: Use `Lifetime.Scoped` for values requiring cleanup when scope exits.

```swift
public struct Scoped<Value>: ~Copyable {
    public let value: Value

    public init(_ value: Value, cleanup: @escaping (Value) -> Void)

    deinit {
        _cleanup(value)
    }
}

// Usage:
func process() {
    let file = Lifetime.Scoped(FileHandle(path: "/tmp/x")) { handle in
        handle.close()
    }
    // use file.value...
}  // close() called here automatically
```

---

### [MEM-LIFE-002] Lifetime.Lease

**Scope**: Borrowed values that must be returned.

**Statement**: Use `Lifetime.Lease` for temporary access to a value with guaranteed return.

```swift
@safe
public struct Lease<Value: ~Copyable>: ~Copyable {
    public var value: Value { _read }
    public mutating func release() -> Value
}

// Usage:
var lease = borrow(myResource)
// use lease.value...
let returned = lease.release()  // Must call to get value back
```

---

### [MEM-LIFE-003] Lifetime.Disposable

**Scope**: Types requiring explicit cleanup.

**Statement**: Conform to `Lifetime.Disposable` when a type holds resources requiring deterministic release.

```swift
public protocol Disposable {
    /// Releases resources held by this instance.
    /// Implementations MUST be idempotent.
    func dispose()
}
```

---

## Topics

### Related Documents

- <doc:Memory>
- <doc:Memory-Ownership>
- <doc:Memory-Copyable>
