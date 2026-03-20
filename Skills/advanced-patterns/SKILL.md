---
name: advanced-patterns
description: |
  Memory ownership patterns, unsafe operation design, refactoring and audit patterns.
  Apply when working with ~Copyable types in collections, unsafe API design, or systematic refactoring.

layer: implementation

requires:
  - memory
  - memory-safety
  - implementation

applies_to:
  - swift
  - swift6
  - primitives
  - standards

migrated_from:
  - Implementation/Memory and Ownership.md
  - Implementation/Unsafe Operations.md
  - Implementation/Package Refactoring.md
migration_date: 2026-01-28
last_reviewed: 2026-03-20
---

# Advanced Patterns

Memory ownership patterns, unsafe operation API design, and systematic refactoring patterns.

**Note**: PATTERN-016 "Move-Only Types as Proof Assistants" from the source documents is an alias for [MEM-LINEAR-003] in the **memory** skill. It shares an ID number with PATTERN-016 "Conscious Technical Debt" in the **anti-patterns** skill. The canonical reference for move-only proof assistants is [MEM-LINEAR-003].

---

## Memory Ownership Patterns

### [PATTERN-014] Linear Types for Invariant Enforcement

**Statement**: When an invariant requires that a value be used exactly once (linear) or at most once (affine), the type MUST be `~Copyable`. The `consuming` keyword and `deinit` MUST encode the invariant at the type level.

| Semantics | Implementation |
|-----------|----------------|
| **Exactly-once** | `~Copyable` + `consuming func` + `deinit` with precondition |
| **At-most-once** | `~Copyable` + `consuming func` + silent `deinit` |

See **memory** skill [MEM-LINEAR-001] and [MEM-LINEAR-002] for full details.

**Cross-references**: [MEM-LINEAR-001], [MEM-LINEAR-002], [PATTERN-007]

---

### [PATTERN-021] Class Wrapper for ~Copyable in Collections

**Statement**: When `~Copyable` types must be stored in collections (which require `Copyable` values), wrap the `~Copyable` content in a class. The class provides reference semantics (copyable), while the content remains move-only.

See **memory** skill [MEM-COPY-003] for full details.

**Cross-references**: [PATTERN-014], [MEM-COPY-003]

---

### [PATTERN-033] Noncopyable Workarounds for Associated Types

**Statement**: When a protocol's semantic contract implies noncopyable associated types but Swift doesn't yet support `associatedtype T: ~Copyable`, use `Reference.Box<T>` as a workaround. Document the intent and anticipate language evolution.

**Cross-references**: [PATTERN-014], [PATTERN-007]

---

### [PATTERN-047] Two-World Separation for Owned and Borrowed Types

**Statement**: When a type has both owned (escapable) and borrowed (`~Escapable`) variants with fundamentally different properties, they MUST be represented as separate types with separate protocol conformances — not unified through abstraction.

**The Constraint Triangle** (Swift 6.x):

Three desirable properties cannot all be satisfied:
1. Reuse existing protocol infrastructure
2. Keep borrowed type `~Escapable` (compile-time lifetime safety)
3. Keep zero-copy parsing

| World | Prioritizes | Sacrifices | Use Case |
|-------|-------------|------------|----------|
| **Owned** | (1) + combinator reuse | (2) compile-time safety | Cross-task transfer, recursive structures |
| **Borrowed** | (2) + (3) zero-copy | (1) separate protocol | Maximum performance, scoped parsing |

```swift
// CORRECT — Two separate protocols
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
struct OwnedBridge<P: Parsing.Parser>: Binary.Bytes.Parser { ... }

// INCORRECT — Forcing unification
public protocol Parser<Input, Output, Failure> {
    associatedtype Input: ~Escapable  // Cannot do this in Swift 6.x
}
```

| Property | Owned | Borrowed |
|----------|-------|----------|
| Storage | Indefinite | Scoped to borrow lifetime |
| Task transfer | Safe | Cannot cross task boundaries |
| Recursive structures | Yes | No |
| Lifetime safety | Runtime contract | Compile-time enforcement |

**Cross-references**: [PATTERN-033], [PATTERN-014]

---

## Unsafe Operation Patterns

### [PATTERN-038] Dual-Overload Anti-Pattern

**Statement**: Public APIs MUST NOT provide dual overloads where one takes unsafe pointers and another takes safe types. The unsafe overload SHOULD be `internal` or `@usableFromInline internal`.

```swift
// CORRECT — Unsafe implementation internal
public func process(_ data: [UInt8]) -> Result {
    data.withUnsafeBufferPointer { _processUnsafe($0) }
}

@usableFromInline
internal func _processUnsafe(_ buffer: UnsafeBufferPointer<UInt8>) -> Result { ... }

// INCORRECT — Both public
public func process(_ data: [UInt8]) -> Result
public func process(_ buffer: UnsafeBufferPointer<UInt8>) -> Result
```

See also **memory-safety** skill [MEM-SAFE-010].

**Cross-references**: [PATTERN-039], [MEM-SAFE-010]

---

### [PATTERN-039] Inline Clarity Over Helper Consolidation

**Statement**: Helper functions are appropriate for abstracting *complexity* but inappropriate for abstracting *danger*. Unsafe operations SHOULD be inline and explicit, not hidden behind convenience helpers.

```swift
// CORRECT — Danger visible
let result = pointer.withMemoryRebound(to: UInt32.self, capacity: count) { typed in
    typed.baseAddress!.pointee
}

// INCORRECT — Danger hidden
func readUInt32(from pointer: UnsafeRawPointer) -> UInt32 {
    pointer.assumingMemoryBound(to: UInt32.self).pointee
}
```

See also **memory-safety** skill [MEM-SAFE-011].

**Cross-references**: [PATTERN-038], [MEM-SAFE-011]

---

### [PATTERN-040] Span as Normative Interface

**Statement**: APIs providing contiguous memory access SHOULD use `Span` as the primary interface. Unsafe pointer access is an escape hatch, not primary API.

```swift
// CORRECT — Span-first
public struct Buffer {
    public var span: Span<UInt8> { ... }
    public func withUnsafeBufferPointer<R>(...) rethrows -> R  // Escape hatch
}

// INCORRECT — Pointer-first
public struct Buffer {
    public var baseAddress: UnsafePointer<UInt8>? { ... }
}
```

See also **memory-safety** skill [MEM-SAFE-012].

**Cross-references**: [PATTERN-038], [MEM-SAFE-012]

---

### [PATTERN-041] API Surface Reduction as Safety

**Statement**: Removing public unsafe overloads in favor of scoped accessors reduces API surface without reducing capability.

See also **memory-safety** skill [MEM-SAFE-013].

**Cross-references**: [PATTERN-038], [PATTERN-040], [MEM-SAFE-013]

---

### [PATTERN-048] Closure Scope Over Property Access

**Statement**: Unsafe operations MUST use closure-scoped access (`withUnsafe*`) rather than property access. Properties make unsafe operations look safe; closures make the lifetime relationship explicit.

```swift
// CORRECT — Closure enforces lifetime
path.withUnsafeCString { ptr in
    usePointer(ptr)
}

// INCORRECT — Property makes danger invisible
public var unsafeCString: UnsafePointer<CChar> {
    _storage.baseAddress  // Can escape and dangle
}
```

| Property Access | Closure Access |
|-----------------|----------------|
| One line | 3-4 lines |
| Looks like normal member access | Looks like careful lifetime management |
| Pointer can escape anywhere | Pointer confined to closure body |
| Lifetime implicit | Lifetime explicit |

Standard library precedent: `withUnsafeBufferPointer`, `withContiguousStorageIfAvailable`, `withCString`, `withUnsafeBytes`.

See also **memory-safety** skill [MEM-SAFE-014].

**Cross-references**: [PATTERN-038], [MEM-SAFE-014]

---

## Refactoring Patterns

### [PATTERN-023] Minimal Reproduction as Verification Tool

**Statement**: When technical debates rest on claims about compiler behavior, runtime semantics, or language mechanics, a minimal reproduction package MUST be built to verify the claim.

See **experiment-process** skill [EXP-004] for full reduction methodology and [EXP-003] for package structure.

**Cross-references**: [EXP-004], [EXP-003]

---

### [PATTERN-026] Centralization as Architectural Principle

**Statement**: Common patterns MUST be centralized in primitives, even when it adds verbosity at call sites. The same argument that could justify `Foundation.Date` in each package applies to ad-hoc wrappers — and is equally wrong.

```swift
// CORRECT — Using centralized primitive
import Time_Primitives
let instant = Time.Instant.now()

// INCORRECT — Ad-hoc wrapper in each package
struct MyTimestamp {
    let seconds: Int64
    let nanoseconds: Int32
}
```

**Cross-references**: [PATTERN-024], [PATTERN-027]

---

### [PATTERN-027] Custom Deinit as Migration Boundary

**Statement**: Custom `deinit` marks an architectural boundary for migration to primitives. When a wrapper class has cleanup logic beyond "deallocate memory," that logic encodes domain knowledge the primitive cannot provide.

| Deinit Content | Migration Possible? |
|----------------|---------------------|
| Empty or trivial | Yes — pure wrapper |
| Resource release (close file, etc.) | Maybe — if primitive handles lifecycle |
| Domain-specific cleanup | No — domain knowledge required |

**Cross-references**: [PATTERN-026], [PATTERN-014]

---

### [PATTERN-028] Audit-Driven Refactoring

**Statement**: Refactoring MAY be driven by consistency audits rather than bug reports or feature requests. When centralized primitives exist, the question "what's still ad-hoc?" reveals patterns that would never surface through bug reports.

Audit questions:
1. What types duplicate functionality available in primitives?
2. What patterns are repeated across packages without centralization?
3. What APIs violate naming conventions?
4. What error handling uses untyped throws?

**Cross-references**: [PATTERN-026], [PATTERN-027]

---

## Cross-References

See also:
- **memory** skill for [MEM-COPY-*], [MEM-LINEAR-*] canonical rules
- **memory-safety** skill for [MEM-SAFE-010-014] unsafe operation rules
- **design** skill for [PATTERN-049], [PATTERN-050] typealias patterns
- **experiment-process** skill for [EXP-004] minimal reproduction methodology
- **anti-patterns** skill for PATTERN-009-016 (things to avoid)
