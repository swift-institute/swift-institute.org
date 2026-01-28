# Pattern: API Design

<!--
---
title: Pattern API Design
version: 1.0.0
last_updated: 2026-01-21
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Patterns for API design decisions: fallbacks, typealiases, and extension points.

## Overview

> This document answers: "What patterns govern API design decisions like fallbacks, type sharing, and extensibility?"

This document defines implementation patterns for API design: fallback strategies, typealias usage, and extension point design.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## [PATTERN-017] Fallback as Feature, Not Compromise

**Scope**: APIs with optimized paths that may not handle all cases.

**Statement**: When a native/optimized path handles only a subset of cases, the fallback to a slower but complete path is an intentional feature, not defensive programming. The API SHOULD accept all valid inputs and route internally.

**Correct**:
```swift
public static func parse(_ string: String) -> UUID? {
    if string.count == 36 {
        if let uuid = nativeParse(string) { return uuid }
    }
    return pureSwiftParse(string)
}
```

**Incorrect**:
```swift
// Forcing callers to pre-validate
public static func parseHyphenated(_ string: String) -> UUID?
public static func parseCompact(_ string: String) -> UUID?
```

**Rationale**: Internal routing simplifies caller code and ensures all valid inputs are accepted. The optimization is an implementation detail.

**Cross-references**: [TEST-PERF-006], [API-ERR-003]

---

## [PATTERN-024] Type Aliases as Architectural Boundaries

**Scope**: Localizing decisions about type usage, especially unsafe escapes.

**Statement**: When a package consistently uses a specific generic instantiation—especially one involving unsafe escapes—a typealias SHOULD be defined to localize the decision.

**Correct**:
```swift
// One typealias, documented justification
typealias Box<I> = Reference.Indirect<I>.Unchecked
// 27 usage sites just use Box<MyIterator>
```

**Incorrect**:
```swift
// 27 files each using the full type
let storage: Reference.Indirect<MyIterator>.Unchecked
// Decision scattered, no central justification
```

**Rationale**: Centralized typealiases make architectural decisions visible and changeable in one place.

**Cross-references**: [API-CONC-005], [API-IMPL-006]

---

## [PATTERN-032] Bound vs Independent Typealias Parameters

**Scope**: Typealiases in generic type extensions.

**Statement**: When exposing nested types through generic parents via typealias, parameters MUST be bound to the parent's parameters, not independent.

**Correct**:
```swift
extension Cache {
    public typealias Evict = __CacheEvict<Key, Value>
}
// Usage: Cache<String, Int>.Evict
```

**Incorrect**:
```swift
extension Cache {
    public typealias Evict<K, V> = __CacheEvict<K, V>
}
// Usage: Cache.Evict<String, Int>  // Ambiguous
```

**Rationale**: Bound parameters ensure type relationships are preserved and usage is unambiguous.

**Cross-references**: [API-NAME-001], [API-NAME-007a]

---

## [PATTERN-034] Requirements as Design Pressure

**Scope**: Using requirements documents as executable design constraints.

**Statement**: API requirements documents function as type systems for design decisions. Rigorous application of requirements redirects "easy" solutions toward correct solutions.

**Example**:
```
Initial design: UserManager.fetchUserData()
After [API-NAME-002]: User.Manager.fetch.data()
After review: User.fetch() — simplified when requirements applied
```

**Rationale**: Requirements documents prevent drift toward convenience at the cost of consistency.

**Cross-references**: [API-NAME-001], [API-NAME-002], [DOC-CONTENT-001]

---

## [PATTERN-049] Typealiases as the Reuse Primitive

**Scope**: Sharing types between facade packages and their implementation dependencies.

**Statement**: When multiple packages need to expose the same types with local names, typealiases MUST be used instead of wrapper types. Typealiases give zero-cost sharing at the ABI level. Wrapper types reintroduce duplication.

**Correct**:
```swift
// Facade re-exports with local name
public typealias Value = Machine_Primitives.Machine.Value
public typealias Transform = Machine_Primitives.Machine.Transform<Instruction>
public typealias Program = Machine_Primitives.Machine.Program<Instruction, Fault>

// Zero-cost: types are identical at ABI level
// No forwarding, no wrapping, no runtime cost
```

**Incorrect**:
```swift
// Wrapper type reintroduces duplication
public struct BinaryValue {
    public let inner: Machine_Primitives.Machine.Value

    // Every method must be forwarded
    public func map<T>(_ transform: (Any) -> T) -> T {
        inner.map(transform)
    }
    // Every combinator must unwrap/rewrap
}
```

### Generic Typealias Extension Limitation

You cannot extend a generic typealias. When `Program` is a typealias to `Machine.Program<Instruction, Fault>`, the generic parameters aren't in scope for extensions:

```swift
// FAILS: generic parameters not in scope
extension Binary.Bytes.Machine.Program {
    func run() { ... }
}
```

**Workaround**: Use static functions on the facade namespace instead of instance methods:

```swift
// Static functions on facade namespace
extension Binary.Bytes.Machine {
    public static func run(program: Program, root: ID, ...) -> Result {
        // Implementation
    }
}

// Usage: Binary.Bytes.Machine.run(program:root:...) instead of program.run(root:...)
```

This is slightly less ergonomic but preserves the sharing benefit. The alternative—wrapper types—costs far more in duplication and maintenance.

### MemberImportVisibility Discipline

Swift 6's `MemberImportVisibility` feature requires that types used in `@inlinable` public functions be imported publicly.

**Rule of thumb**: Use `public import` only where `@inlinable` code references the module's types by name. Otherwise, keep imports internal to minimize API surface.

```swift
// In a file with @inlinable functions using Machine types
public import Machine_Primitives  // Required for inlinability

// In files without @inlinable code referencing the module
import Machine_Primitives  // Keep internal
```

Previously, imports were implementation details. Now they're part of the public contract when inlining is involved.

**Rationale**: Typealiases preserve type identity while providing local names. The ABI sees one type; the API sees a convenient local name. This is zero-cost abstraction in the truest sense.

**Cross-references**: [PATTERN-024], [PATTERN-032], [PATTERN-006]

---

## [PATTERN-050] Never as Closed Default for Extension Points

**Scope**: Designing generic types that allow facade-specific extensions without code duplication.

**Statement**: When designing shared types that may need facade-specific extensions, the extension capability SHOULD be encoded as a generic type parameter with `Never` as the closed default.

**The Pattern**:

```swift
// Core shared type with extension point
public enum Frame<NodeID, Checkpoint, Failure: Error, Extra> {
    case call(child: NodeID)
    case sequence(a: NodeID, b: NodeID, combine: Combine)
    case choice(first: NodeID, second: NodeID)
    case extra(Extra)  // Extension point
}

// Facade A: Needs memoization, so Extra = Memoization<Checkpoint>
public typealias ParsingFrame = Frame<NodeID, Checkpoint, Failure, Memoization<Checkpoint>>

// Facade B: Needs nothing extra, so Extra = Never
public typealias BinaryFrame = Frame<NodeID, Checkpoint, Failure, Never>
```

**Correct** (interpreter over Frame with `Extra = Never`):
```swift
switch frame {
case .call(let child): ...
case .sequence(let a, let b, let combine): ...
case .choice(let first, let second): ...
case .extra(let never):
    switch never {}  // Compiles to nothing; proves impossibility
}
```

**Incorrect**:
```swift
// Using fatalError for cases that "shouldn't happen"
case .extra:
    fatalError("BinaryFrame doesn't support extra")

// This is a runtime trap; Never gives compile-time proof
```

### Why `Never` Works

`Never` is Swift's bottom type—uninhabited and impossible to construct. When `Extra = Never`:

- The `case extra(Extra)` exists syntactically
- No value can be constructed to match it
- `switch never {}` compiles to nothing—it's a type-level assertion of impossibility
- Total interpreters remain total without runtime checks

### Naming Limitation with Typealiases

You cannot nest `Extra` inside `Frame` when `Frame` is a typealias. The solution: define the extension type at the facade's namespace level, then reference it in the Frame typealias:

```swift
// Cannot do: ParsingFrame.Extra (generic params not in scope)

// Instead: define at facade namespace level
extension Parsing.Machine {
    public enum Extra<Checkpoint> {
        case memoize(NodeID, checkpoint: Checkpoint)
    }
}

// Then reference in typealias
public typealias Frame = Machine_Primitives.Machine.Frame<
    NodeID, Checkpoint, Failure, Extra<Checkpoint>
>
```

This is slightly less tidy than `Frame.Extra`, but it's the only option when sharing via typealiases.

**Rationale**: The `Extra` parameter pattern enables shared types to serve multiple facades with different needs. Facades that need extensions provide a concrete type; facades that don't use `Never` and get compile-time elimination of the extension case.

**Cross-references**: [PATTERN-049], [PATTERN-024], [PATTERN-014]

---

## Topics

### Related Documents

- <doc:Implementation-Patterns>
- <doc:API-Requirements>
- <doc:API-Naming>
- <doc:API-Implementation>
