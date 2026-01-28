# Pattern: Unsafe Operations

<!--
---
title: Pattern Unsafe Operations
version: 1.0.0
last_updated: 2026-01-21
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Patterns for safe handling of unsafe operations: API design, visibility, and lifetime management.

## Overview

> This document answers: "What patterns govern the design and exposure of unsafe operations?"

This document defines implementation patterns for unsafe operations: avoiding dual overloads, preferring Span over raw pointers, and using closure scope for lifetime safety.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## [PATTERN-038] Dual-Overload Anti-Pattern

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

**Cross-references**: [PATTERN-039], [API-NAME-008]

---

## [PATTERN-039] Inline Clarity Over Helper Consolidation

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

**Cross-references**: [PATTERN-038], [API-NAME-008]

---

## [PATTERN-040] Span as Normative Interface

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

**Cross-references**: [PATTERN-038], [PATTERN-039], [PATTERN-005b]

---

## [PATTERN-041] API Surface Reduction as Safety

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

**Cross-references**: [PATTERN-038], [PATTERN-040]

---

## [PATTERN-048] Closure Scope Over Property Access for Unsafe Operations

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

### Why Properties Are Dangerous

| Property Access | Closure Access |
|-----------------|----------------|
| One line | 3-4 lines (with closure) |
| Looks like normal member access | Looks like careful lifetime management |
| Pointer can escape anywhere | Pointer confined to closure body |
| Lifetime implicit | Lifetime explicit |

The verbosity of closure access is a feature. The code says "I am doing something that requires careful lifetime management" at every call site.

### Standard Library Precedent

Swift's standard library uses this pattern consistently:
- `withUnsafeBufferPointer`
- `withContiguousStorageIfAvailable`
- `withCString`
- `withUnsafeBytes`

Consistency teaches developers to expect scoped access for unsafe operations.

**Rationale**: Properties that return pointers lie about safety through ergonomics. Closures make the contract visible: the pointer is valid only within the scope. Migration from property to closure access increases verbosity but converts implicit contracts into explicit code structure.

**Cross-references**: [PATTERN-038], [PATTERN-039], [PATTERN-040], [MEM-SAFE-002]

---

## Topics

### Related Documents

- <doc:Implementation-Patterns>
- <doc:Memory-Safety>
- <doc:API-Requirements>
