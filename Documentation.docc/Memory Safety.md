# Memory Safety

@Metadata {
    @TitleHeading("Swift Institute")
}

StrictMemorySafety mode: unsafe expression marking, warning classification, and safety dimensions.

## Overview

This document defines strict memory safety patterns per SE-0458.

**Applies to**: SE-0458 Strict Memory Safety checking.

---

## [MEM-SAFE-001] Enable Strict Memory Safety

**Scope**: Memory-critical packages.

**Statement**: Memory-critical packages MUST enable strict memory safety mode via `.strictMemorySafety()` in the package manifest.

**Correct**:
```swift
// Package.swift
.target(
    name: "BufferPrimitives",
    dependencies: [],
    swiftSettings: [
        .strictMemorySafety()
    ]
)
```

**Compiler Features to Enable**:
```swift
swiftSettings: [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableExperimentalFeature("Lifetimes"),
    .strictMemorySafety(),
]
```

**Rationale**: Compiler enforcement catches memory safety violations at build time rather than runtime.

**Cross-references**: [SYS-MEM-001], [PATTERN-005]

---

## [MEM-SAFE-002] Unsafe Expression Marking

**Scope**: Marking unsafe operations in strict mode.

**Statement**: Swift's strict memory safety operates at expression granularity. Each unsafe operation requires its own `unsafe` acknowledgment.

**Correct**:
```swift
@unsafe
public func allocate(capacity: Int) -> UnsafeMutablePointer<Element> {
    // Each operation requires its own unsafe marker
    let ptr = unsafe UnsafeMutablePointer<Element>.allocate(capacity: capacity)
    unsafe ptr.initialize(repeating: .init(), count: capacity)
    return ptr
}

// For assignments to unsafe storage, use parentheses
unsafe (self.raw = Unmanaged.passRetained(instance).toOpaque())
```

**Incorrect**:
```swift
// ❌ Value-only marking leaves destination uncovered
self.raw = unsafe Unmanaged.passRetained(instance).toOpaque()

// ❌ Block syntax doesn't create unsafe context
unsafe { self.name = name }  // Error in initializer context
```

**The Granularity Model**:
- `@unsafe` on a function declares that *calling* the function is unsafe
- Operations *within* the function still require individual `unsafe` markers
- Parentheses define the expression boundary for assignments

**Cross-references**: [PATTERN-005b]

---

## [MEM-SAFE-003] Warning Classification

**Scope**: Handling StrictMemorySafety warnings.

**Statement**: StrictMemorySafety warnings fall into two categories. Bucket A requires action; Bucket B is informational.

| Category | Description | Action |
|----------|-------------|--------|
| **Bucket A** | Operations requiring `unsafe` acknowledgment | Mark with `unsafe` |
| **Bucket B** | "Struct has storage involving unsafe types" | Audit marker only |

**Expected Bucket B Warnings**:

| Module | Types | Rationale |
|--------|-------|-----------|
| `Reference_Primitives` | `Header`, `Pointer` | Pointer wrappers for ownership transfer |
| `Async_Primitives` | Channel state enums | `UnsafeContinuation` storage |
| `Kernel_Primitives` | `Entry` | Borrowed pointers to OS data structures |

**Rationale**: Bucket B warnings exist to make unsafe storage visible in build output, not to demand remediation.

**Cross-references**: [PATTERN-005a], [STRICT_MEMORY_SAFETY.md]

---

## [MEM-SAFE-004] Five Dimensions of Memory Safety

**Scope**: Understanding memory safety guarantees.

**Statement**: Memory safety has five dimensions. Swift provides guarantees across all five.

| Dimension | Guarantee | Mechanism |
|-----------|-----------|-----------|
| **Lifetime Safety** | Values accessed within their lifetime | ARC, `~Copyable`, `@_lifetime` |
| **Bounds Safety** | Accesses within allocation bounds | Array bounds checking |
| **Type Safety** | Values accessed using compatible types | Strong typing |
| **Initialization Safety** | Values initialized before use | Definite initialization |
| **Thread Safety** | Invariants maintained under concurrency | `Sendable`, actors, Swift 6 |

**Cross-references**: SE-0458

---

## Unsafe Operation Tracking

### [MEM-UNSAFE-001] Unsafe Operation Tracking

**Scope**: Tracking unsafe operations for future annotation.

**Statement**: Unsafe operations MUST be tracked and eventually marked with `unsafe`. Warnings serve as a TODO list.

**Treatment of Warnings**:

| Warning Type | Response | Timeline |
|--------------|----------|----------|
| Pointer operations | Mark with `unsafe` | Now |
| C interop calls | Mark with `unsafe` | Now |
| Concurrency isolation | Fix immediately | Now |

**Cross-references**: [PATTERN-005a]

---

### [MEM-UNSAFE-002] Lifetime Annotations

**Scope**: APIs exposing temporary pointers.

**Statement**: APIs that expose pointers or references with limited lifetime MUST use lifetime annotations to ensure the compiler enforces scope constraints.

**Correct**:
```swift
extension Buffer.Aligned {
    @_lifetime(borrow self)
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
        body(UnsafeRawBufferPointer(start: pointer, count: size))
    }
}
```

**Incorrect**:
```swift
// ❌ Pointer can escape scope
func getPointer() -> UnsafeRawPointer {
    return pointer  // Escapes - lifetime not enforced
}
```

**Cross-references**: [SYS-MEM-003]

---

### [MEM-UNSAFE-003] Safe Attribute

**Scope**: Asserting function safety despite unsafe operations.

**Statement**: Use `@safe` to assert that a function containing unsafe operations maintains safety guarantees through careful design.

```swift
@safe
public final class Box<Value: ~Copyable & Sendable>: @unchecked Sendable {
    // Safe despite @unchecked - immutable value with Sendable constraint
}
```

---

## Techniques

**Applies to**: Practical implementation of safe API patterns for unsafe operations.

---

### [MEM-SAFE-010] Dual-Overload Anti-Pattern

**Scope**: APIs with both safe and unsafe overloads for the same operation.

**Statement**: Public APIs MUST NOT provide dual overloads where one takes unsafe pointers and another takes safe types. The unsafe overload SHOULD be `internal` or `@usableFromInline internal`.

**Correct**:
```swift
// Public API uses safe types
public func process(_ data: [UInt8]) -> Result {
    data.withUnsafeBufferPointer { buffer in
        _processUnsafe(buffer)
    }
}

// Unsafe implementation is internal
@usableFromInline
internal func _processUnsafe(_ buffer: UnsafeBufferPointer<UInt8>) -> Result {
    // Implementation
}
```

**Incorrect**:
```swift
// Both overloads public - invites misuse
public func process(_ data: [UInt8]) -> Result
public func process(_ buffer: UnsafeBufferPointer<UInt8>) -> Result
```

**Rationale**: Dual public overloads encourage unsafe usage when safe alternatives exist.

**Cross-references**: [MEM-SAFE-011], [API-NAME-008]

---

### [MEM-SAFE-011] Inline Clarity Over Helper Consolidation

**Scope**: Helper functions for unsafe operations.

**Statement**: Helper functions are appropriate for abstracting *complexity* but inappropriate for abstracting *danger*. Unsafe operations SHOULD be inline and explicit, not hidden behind convenience helpers.

**Correct**:
```swift
// Unsafe operation visible at call site
let result = pointer.withMemoryRebound(to: UInt32.self, capacity: count) { typed in
    typed.baseAddress!.pointee
}
```

**Incorrect**:
```swift
// Danger hidden behind helper
func readUInt32(from pointer: UnsafeRawPointer) -> UInt32 {
    pointer.assumingMemoryBound(to: UInt32.self).pointee
}
// Call site looks safe: readUInt32(from: ptr)
```

**Rationale**: Visible unsafety at call sites enables code review and audit. Hidden unsafety spreads undetected.

**Cross-references**: [MEM-SAFE-010], [API-NAME-008]

---

### [MEM-SAFE-012] Span as Normative Interface

**Scope**: APIs for contiguous memory access.

**Statement**: APIs providing contiguous memory access SHOULD use `Span` as the primary interface. Unsafe pointer access SHOULD be relegated to accessor escape hatches, not parallel overloads.

**Correct**:
```swift
public struct Buffer {
    public var span: Span<UInt8> { ... }

    // Escape hatch for interop, not primary API
    public func withUnsafeBufferPointer<R>(
        _ body: (UnsafeBufferPointer<UInt8>) throws -> R
    ) rethrows -> R
}
```

**Incorrect**:
```swift
public struct Buffer {
    // Pointer-first API
    public var baseAddress: UnsafePointer<UInt8>? { ... }
    public var count: Int { ... }
}
```

**Rationale**: Span provides bounds checking and lifetime safety. Pointer APIs should be escape hatches, not defaults.

**Cross-references**: [MEM-SAFE-010], [MEM-SAFE-011], [MEM-SPAN-001]

---

### [MEM-SAFE-013] API Surface Reduction as Safety

**Scope**: Reducing public API surface for safety improvements.

**Statement**: Removing public unsafe overloads in favor of scoped accessors reduces API surface without reducing capability. Less surface area means less documentation, less attack surface, and fewer paths to misuse.

**Before**:
```swift
public struct Path {
    public var cString: UnsafePointer<CChar> { ... }  // Dangerous
    public func withCString<R>(_ body: ...) rethrows -> R  // Safe
}
```

**After**:
```swift
public struct Path {
    public func withCString<R>(_ body: ...) rethrows -> R  // Only safe API
}
```

**Rationale**: Fewer public APIs means fewer ways to misuse the type. The capability remains; the danger is removed.

**Cross-references**: [MEM-SAFE-010], [MEM-SAFE-012]

---

### [MEM-SAFE-014] Closure Scope Over Property Access for Unsafe Operations

**Scope**: APIs providing access to unsafe pointers or resources with lifetime dependencies.

**Statement**: Unsafe operations MUST use closure-scoped access (`withUnsafe*`) rather than property access. Properties make unsafe operations look safe; closures make the lifetime relationship explicit.

**Correct**:
```swift
// Closure scope enforces lifetime
path.withUnsafeCString { ptr in
    // ptr is valid only within this closure
    usePointer(ptr)
}
// ptr no longer accessible

extension Kernel.Path {
    public func withUnsafeCString<R>(
        _ body: (UnsafePointer<CChar>) throws -> R
    ) rethrows -> R {
        _storage.withUnsafeBufferPointer { buffer in
            try body(buffer.baseAddress!)
        }
    }
}
```

**Incorrect**:
```swift
// Property makes unsafe operation look safe
public var unsafeCString: UnsafePointer<CChar> {
    _storage.baseAddress
}

// Caller can misuse:
let ptr = path.unsafeCString
// ...path could be deallocated here...
usePointer(ptr)  // Use-after-free
```

#### Why Properties Are Dangerous

| Property Access | Closure Access |
|-----------------|----------------|
| One line | 3-4 lines (with closure) |
| Looks like normal member access | Looks like careful lifetime management |
| Pointer can escape anywhere | Pointer confined to closure body |
| Lifetime implicit | Lifetime explicit |

The verbosity of closure access is a feature. The code says "I am doing something that requires careful lifetime management" at every call site.

#### Standard Library Precedent

Swift's standard library uses this pattern consistently:
- `withUnsafeBufferPointer`
- `withContiguousStorageIfAvailable`
- `withCString`
- `withUnsafeBytes`

Consistency teaches developers to expect scoped access for unsafe operations.

**Rationale**: Properties that return pointers lie about safety through ergonomics. Closures make the contract visible: the pointer is valid only within the scope. Migration from property to closure access increases verbosity but converts implicit contracts into explicit code structure.

**Cross-references**: [MEM-SAFE-010], [MEM-SAFE-011], [MEM-SAFE-012], [MEM-SAFE-002]

---

## Concurrency Safety (Sendable)

**Applies to**: Types crossing concurrency boundaries.

---

### [MEM-SEND-001] Conservative Sendable Defaults

**Scope**: Mutable reference wrappers.

**Statement**: General-purpose mutable reference wrappers MUST NOT be unconditionally `@unchecked Sendable` unless they provide synchronization.

**Correct**:
```swift
// Conservative default: Sendable only when Value is Sendable
extension Reference.Indirect: @unchecked Sendable where Value: Sendable {}

// Explicit unsafe escape
extension Reference.Indirect {
    public struct Unchecked: @unchecked Sendable {
        public let indirect: Reference.Indirect<Value>
    }
}
```

**Incorrect**:
```swift
// ❌ Unconditionally Sendable - hidden footgun
extension Reference.Indirect: @unchecked Sendable {}
```

**Cross-references**: [API-CONC-005]

---

### [MEM-SEND-002] Sendability Tiers

**Scope**: Understanding Sendable conformance levels.

**Statement**: Apply the appropriate Sendability tier based on type characteristics.

| Tier | When | Example |
|------|------|---------|
| Checked Sendable | Immutable, all fields Sendable | `struct Point: Sendable` |
| Conditional Sendable | Sendable when generic param is | `extension Box: Sendable where T: Sendable` |
| Unchecked Sendable | Synchronized by construction | `Slot`, `Transfer` (atomic state) |
| Not Sendable | Mutable without synchronization | `Indirect` base type |
| Explicit Escape | Caller asserts safety | `Indirect.Unchecked` |

---

### [MEM-SEND-003] Accurate Risk Description

**Scope**: Justifying unsafe Sendable escapes.

**Statement**: When justifying unsafe escapes, describe the risk accurately—not euphemistically.

| Euphemistic | Accurate |
|-------------|----------|
| "This is about transferability" | "The compiler will not warn when this creates races" |
| "`@unchecked Sendable` means transferable" | "Removing the compiler's data-race prevention" |

**Rationale**: Euphemisms hide risk. Accurate descriptions enable informed decisions.

**Cross-references**: [API-CONC-005]

---

## Topics

### Related Documents

- <doc:Memory>
- <doc:Memory-Copyable>
- <doc:Memory-Ownership>
- <doc:Systems-Programming>
