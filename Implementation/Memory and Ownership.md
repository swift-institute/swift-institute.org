# Pattern: Memory and Ownership

<!--
---
title: Pattern Memory and Ownership
version: 1.0.0
last_updated: 2026-01-21
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Patterns for noncopyable, linear, and move-only types in Swift Institute packages.

## Overview

> This document answers: "What patterns govern noncopyable, linear, and move-only types in Swift Institute packages?"

This document defines implementation patterns for memory ownership: linear types, move-only semantics, and noncopyable type workarounds. These patterns encode resource linearity and exactly-once semantics at the type level.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## [PATTERN-014] Linear Types for Invariant Enforcement

**Scope**: Types that encode exactly-once or at-most-once semantics.

**Statement**: When an invariant requires that a value be used exactly once (linear) or at most once (affine), the type MUST be `~Copyable`. The `consuming` keyword and `deinit` MUST encode the invariant at the type level.

> **Full details**: See <doc:Memory> sections [MEM-LINEAR-001] and [MEM-LINEAR-002].

| Semantics | Implementation |
|-----------|----------------|
| **Exactly-once** | `~Copyable` + `consuming func` + `deinit` with precondition |
| **At-most-once** | `~Copyable` + `consuming func` + silent `deinit` |

**Cross-references**: [API-ERR-005], [API-ERR-006], [PATTERN-007], <doc:Memory>

---

## [PATTERN-016] Move-Only Types as Proof Assistants

**Scope**: Types encoding resource linearity or exactly-once semantics.

**Statement**: When `~Copyable` types with `consuming func` are used to enforce exactly-once semantics, the ownership system functions as a compile-time proof assistant. Apply systematically to any "exactly once" or "at most once" invariant.

> **Full details**: See <doc:Memory> section [MEM-LINEAR-003].

**Cross-references**: [PATTERN-014], [API-ERR-005], [API-ERR-006], <doc:Memory>

---

## [PATTERN-021] Class Wrapper for ~Copyable in Collections

**Scope**: Storing `~Copyable` types in enums, dictionaries, or other collections.

**Statement**: When `~Copyable` types must be stored in collections (which require `Copyable` values), wrap the `~Copyable` content in a class. The class provides reference semantics (copyable), while the content remains move-only.

> **Full details**: See <doc:Memory> section [MEM-COPY-003].

**Cross-references**: [PATTERN-014], [PATTERN-016], [API-IMPL-004], <doc:Memory>

---

## [PATTERN-033] Noncopyable Workarounds for Associated Types

**Scope**: Protocols where associated types should be `~Copyable` but Swift doesn't yet support this.

**Statement**: When a protocol's semantic contract implies noncopyable associated types but Swift's type system doesn't support `associatedtype T: ~Copyable`, use `Reference.Box<T>` as a workaround. Document the intent and anticipate language evolution.

**Cross-references**: [PATTERN-014], [PATTERN-016], [PATTERN-007], <doc:Memory>

---

## [PATTERN-047] Two-World Separation for Owned and Borrowed Types

**Scope**: APIs where both owned (escapable) and borrowed (`~Escapable`) variants exist.

**Statement**: When a type has both owned and borrowed variants with fundamentally different properties, they MUST be represented as separate types with separate protocol conformances—not unified through abstraction. The separation is semantically correct, not a workaround for language limitations.

### The Constraint Triangle

Three desirable properties cannot all be satisfied in Swift 6.x:

1. **Reuse existing protocol infrastructure** (combinators, extensions)
2. **Keep borrowed type `~Escapable`** (compile-time lifetime safety)
3. **Keep zero-copy parsing** (no copying)

Swift 6.x does not allow `~Escapable` constraints on protocol associated types. This forces a choice: which two properties to keep?

| World | Prioritizes | Sacrifices | Use Case |
|-------|-------------|------------|----------|
| **Owned** | (1) + combinator reuse | (2) compile-time safety | Cross-task transfer, recursive structures |
| **Borrowed** | (2) + (3) zero-copy | (1) separate protocol | Maximum performance, scoped parsing |

**Correct**:
```swift
// Two separate protocols - semantically correct separation
public protocol Parser<Input, Output, Failure> {
    associatedtype Input  // Must be Escapable (language limitation)
    func parse(_ input: inout Input) throws(Failure) -> Output
}

extension Binary.Bytes {
    // Separate protocol for borrowed world
    public protocol Parser<Output, Failure> {
        mutating func parse(_ input: inout Input.View) throws(Failure) -> Output
    }
}

// Bridge for cross-world reuse
struct OwnedBridge<P: Parsing.Parser>: Binary.Bytes.Parser {
    mutating func parse(_ input: inout Input.View) throws(P.Failure) -> P.Output {
        var owned = input.copyToOwned()  // Explicit copy at bridge point
        let result = try owned.parse(&owned)
        input.removeFirst(owned.consumedCount)
        return result
    }
}
```

**Incorrect**:
```swift
// Forcing unification through abstraction
public protocol Parser<Input, Output, Failure> {
    associatedtype Input: ~Escapable  // Cannot do this in Swift 6.x
    func parse(_ input: inout Input) throws(Failure) -> Output
}

// Using owned type as "borrowed" API
func withBorrowed(_ bytes: [UInt8], _ body: (inout OwnedInput) -> T) -> T
// Copies data; defeats purpose of borrowed API
```

### Why Separation Is Correct

Owned and borrowed inputs have genuinely different semantic properties:

| Property | Owned | Borrowed |
|----------|-------|----------|
| Storage | Can be stored indefinitely | Scoped to borrow lifetime |
| Task transfer | Safe to send across tasks | Cannot cross task boundaries |
| Recursive structures | Can be used in trees, graphs | Cannot participate in recursive types |
| Lifetime safety | Runtime contract | Compile-time enforcement |

A unified type would either:
- Lose compile-time guarantees (making `~Escapable` meaningless)
- Lose flexibility of owned (breaking legitimate use cases)

The two-world model makes these trade-offs explicit and provides controlled bridge points.

**Rationale**: When language limitations prevent unification, the correct response is honest separation—not abstraction that hides the trade-offs. The limitation makes two worlds *mandatory*; the semantic distinction makes them *correct*.

**Cross-references**: [PATTERN-033], [PATTERN-014], [API-DESIGN-002], <doc:Memory>

---

## Topics

### Related Documents

- <doc:Memory>
- <doc:Memory-Copyable>
- <doc:Implementation-Patterns>
- <doc:Pattern-Advanced>
