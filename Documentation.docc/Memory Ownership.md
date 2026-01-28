# Memory Ownership

@Metadata {
    @TitleHeading("Swift Institute")
}

Ownership keywords, ownership transfer patterns, and type-level ownership naming conventions.

## Overview

This document defines ownership patterns for function parameters, ownership transfer, and naming conventions for owning vs non-owning types.

**Applies to**: Function parameters, ownership transfer, and type naming.

---

## Consuming Parameters

**Scope**: Parameters that take ownership of a value.

**Statement**: Use `consuming` when a function takes ownership of a parameter. The caller cannot use the value after passing it.

**Correct**:
```swift
public init(_ value: consuming Value) {
    self._storage = value
}

public consuming func token() -> Token {
    Token(_box)  // self is consumed
}
```

**Usage**:
```swift
let cell = Reference.Transfer.Cell(myValue)
let token = cell.token()  // cell is consumed
// cell cannot be used here
```

**Rationale**: Makes ownership transfer explicit in the API. The compiler enforces that the caller relinquishes ownership.

---

## Borrowing Parameters

**Scope**: Parameters that provide temporary read-only access.

**Statement**: Use `borrowing` when a function needs read-only access without taking ownership. The caller retains ownership; the callee cannot consume or store the value.

**Correct**:
```swift
public func withValue<Result>(
    _ body: (borrowing Value) throws -> Result
) rethrows -> Result {
    try body(_value)
}
```

**Usage**:
```swift
indirect.withValue { value in
    print(value)  // Read-only access
    // Cannot consume or store `value`
}
```

**Rationale**: Enables safe scoped access for `~Copyable` values without ownership transfer.

---

## Ownership in Function Signatures

**Scope**: Documenting ownership contracts in APIs.

**Statement**: Function signatures MUST use ownership keywords to document the ownership contract.

| Keyword | Ownership | Caller After Call | Callee Can |
|---------|-----------|-------------------|------------|
| `consuming` | Transferred to callee | Cannot use value | Store, consume |
| `borrowing` | Retained by caller | Can use value | Read only |
| `inout` | Temporarily loaned | Can use value | Mutate |
| (none) | Default (varies) | Depends on type | Depends on context |

**Correct**:
```swift
// Clear ownership contracts
func transfer(_ resource: consuming Resource)
func inspect(_ resource: borrowing Resource) -> Info
func modify(_ resource: inout Resource)
```

---

## Type-Level Ownership Naming

**Scope**: Naming conventions for owning vs non-owning types.

**Statement**: A primitive named after a **reference** (Address, Pointer, Handle) SHOULD be non-owning. A primitive named after a **resource** (String, Array, Allocation) SHOULD be owning and MAY provide a `.View` borrowing type.

### Reference Types (Non-Owning)

Reference primitives represent addresses or handles to memory. They are semantically non-owning and SHOULD be `Copyable`.

**Correct**:
```swift
// Reference types are non-owning, Copyable
Memory.Address          // Raw address, non-owning
Pointer<T>              // Typed address, non-owning
Pointer<T>.Mutable      // Mutable typed address, non-owning

// Ownership is a separate wrapper
Pointer<T>.Owner        // Owning wrapper, ~Copyable
```

**Incorrect**:
```swift
// ❌ Making the reference type owning
struct Pointer<T>: ~Copyable {  // Wrong: pointer is an address
    deinit { deallocate() }
}
struct Pointer<T>.View { }       // Wrong: implies Pointer owns
```

### Resource Types (Owning)

Resource primitives represent storage-managed values. They are semantically owning and MAY provide `.View` types for borrowing.

**Correct**:
```swift
// Resource types own their storage
String                  // Owns string storage
String.View             // Borrowed view into String

Array<T>                // Owns element storage
Array<T>.SubSequence    // Borrowed slice
```

### Rationale

| Category | Examples | Copyable? | Owns Memory? |
|----------|----------|-----------|--------------|
| Reference | Address, Pointer, Handle | Yes | No |
| Resource | String, Array, Allocation | Varies | Yes |

**Why this distinction matters**:

1. **Pointer algebra requires copyability**: Iteration, slicing, comparison, and caching all require copying pointer values. Making `Pointer<T>` owning (~Copyable) would infect the entire pointer ecosystem with move-only friction.

2. **Ownership implies more than an address**: An owning type must track allocator, layout, and initialization state. That's not "a pointer" - it's a managed allocation record.

3. **FFI parity**: Interop with C/C++/Rust is predominantly non-owning pointers with lifetime contracts. The natural center of gravity for `Pointer<T>` is non-owning.

4. **Ecosystem precedent**:
   - Rust: `*const T` (non-owning) vs `Box<T>` (owning)
   - C++: `T*` (non-owning) vs `unique_ptr<T>` (owning)
   - Swift stdlib: `UnsafePointer<T>` (non-owning) vs managed collections (owning)

### The Category Error

Applying the "resource owns, view borrows" pattern to reference types is a **category error**. `String` owns storage because it's a value abstraction. `Pointer` is the lens onto memory - it's what views are built from, not what should have views.

The closer analogs in the ecosystem:
- `Span<T>` / `Buffer` as view types (like `String.View`)
- `Pointer<T>.Owner` as owned allocation (like `Box<T>`)

---

## Summary Table

| Keyword | Ownership | After Call | Callee Can |
|---------|-----------|------------|------------|
| `consuming` | Transferred | Cannot use | Store, consume |
| `borrowing` | Retained | Can use | Read only |
| `inout` | Loaned | Can use | Mutate |

---

## Topics

### Related Documents

- <doc:Memory>
- <doc:Memory-Copyable>
- <doc:Memory-Safety>
