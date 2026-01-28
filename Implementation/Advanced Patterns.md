# Pattern: Advanced Patterns

<!--
---
title: Pattern Advanced Patterns
version: 1.0.0
last_updated: 2026-01-19
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Linear types, move-only semantics, concurrency coordination, audit patterns, and API design patterns.

## Overview

This document contains advanced implementation patterns for complex scenarios.

---

## Linear and Move-Only Types

### [PATTERN-014] Linear Types for Invariant Enforcement

**Scope**: Types that encode exactly-once or at-most-once semantics.

**Statement**: When an invariant requires that a value be used exactly once (linear) or at most once (affine), the type MUST be `~Copyable`. The `consuming` keyword and `deinit` MUST encode the invariant at the type level.

> **Full details**: See <doc:Memory> sections [MEM-LINEAR-001] and [MEM-LINEAR-002].

| Semantics | Implementation |
|-----------|----------------|
| **Exactly-once** | `~Copyable` + `consuming func` + `deinit` with precondition |
| **At-most-once** | `~Copyable` + `consuming func` + silent `deinit` |

**Cross-references**: [API-ERR-005], [API-ERR-006], [PATTERN-007], <doc:Memory>

---

### [PATTERN-016] Move-Only Types as Proof Assistants

**Scope**: Types encoding resource linearity or exactly-once semantics.

**Statement**: When `~Copyable` types with `consuming func` are used to enforce exactly-once semantics, the ownership system functions as a compile-time proof assistant. Apply systematically to any "exactly once" or "at most once" invariant.

> **Full details**: See <doc:Memory> section [MEM-LINEAR-003].

**Cross-references**: [PATTERN-014], [API-ERR-005], [API-ERR-006], <doc:Memory>

---

### [PATTERN-021] Class Wrapper for ~Copyable in Collections

**Scope**: Storing `~Copyable` types in enums, dictionaries, or other collections.

**Statement**: When `~Copyable` types must be stored in collections (which require `Copyable` values), wrap the `~Copyable` content in a class. The class provides reference semantics (copyable), while the content remains move-only.

> **Full details**: See <doc:Memory> section [MEM-COPY-003].

**Cross-references**: [PATTERN-014], [PATTERN-016], [API-IMPL-004], <doc:Memory>

---

### [PATTERN-033] Noncopyable Workarounds for Associated Types

**Scope**: Protocols where associated types should be `~Copyable` but Swift doesn't yet support this.

**Statement**: When a protocol's semantic contract implies noncopyable associated types but Swift's type system doesn't support `associatedtype T: ~Copyable`, use `Reference.Box<T>` as a workaround. Document the intent and anticipate language evolution.

**Cross-references**: [PATTERN-014], [PATTERN-016], [PATTERN-007], <doc:Memory>

---

### [PATTERN-047] Two-World Separation for Owned and Borrowed Types

**Scope**: APIs where both owned (escapable) and borrowed (`~Escapable`) variants exist.

**Statement**: When a type has both owned and borrowed variants with fundamentally different properties, they MUST be represented as separate types with separate protocol conformances—not unified through abstraction. The separation is semantically correct, not a workaround for language limitations.

#### The Constraint Triangle

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
// ❌ Forcing unification through abstraction
public protocol Parser<Input, Output, Failure> {
    associatedtype Input: ~Escapable  // Cannot do this in Swift 6.x
    func parse(_ input: inout Input) throws(Failure) -> Output
}

// ❌ Using owned type as "borrowed" API
func withBorrowed(_ bytes: [UInt8], _ body: (inout OwnedInput) -> T) -> T
// Copies data; defeats purpose of borrowed API
```

#### Why Separation Is Correct

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

## Concurrency Patterns

### [PATTERN-020] Never Resume Under Lock

**Scope**: Async coordination primitives using continuations and locks.

**Statement**: Continuations MUST NOT be resumed while holding a lock. The pattern is: collect resumption thunks under lock, release lock, then execute resumptions.

**Correct**:
```swift
// Collect resumptions under lock, execute after
func complete(with value: T) {
    let resumptions: [Async.Waiter.Resumption]
    lock.withLock {
        resumptions = waiters.drain().map { $0.resumption }
        state = .completed(value)
    }
    // Lock released - now safe to resume
    for resumption in resumptions {
        resumption.resume()
    }
}
```

**Incorrect**:
```swift
// ❌ Resuming under lock
func complete(with value: T) {
    lock.withLock {
        for waiter in waiters.drain() {
            waiter.continuation.resume(returning: value)  // DANGER
        }
    }
}
```

**Rationale**: Deferred resumption keeps user code out of critical sections, making deadlock impossible by construction.

**Cross-references**: [PATTERN-014], [PATTERN-016], [API-CONC-001]

---

### [PATTERN-022] Inout-Across-Await Hazard

**Scope**: Async methods accessing mutable state through `_modify` accessors.

**Statement**: When an async method accesses mutable state through a `_modify` accessor, the exclusivity check operates within a single execution context—it does NOT prevent concurrent access from different tasks.

This hazard reinforces why [API-CONC-005] requires conservative Sendable defaults.

**Cross-references**: [API-CONC-005], [PATTERN-020]

---

### [PATTERN-025] Type Erasure vs Sendable Tension

**Scope**: Heterogeneous storage and type erasure in Swift 6 with strict concurrency.

**Statement**: Type erasure mechanisms (raw pointers, `Unmanaged`, unsafe bitcasts) predate Swift Concurrency and are explicitly non-Sendable in Swift 6. When type erasure is required for heterogeneous storage, the composition with Sendable-requiring primitives creates an architectural tension that MUST be resolved explicitly.

Resolution approaches:
- Sendable wrapper (`Reference.Pointer`) - encapsulates unsafety
- Accept limitation - some compositions aren't possible without unsafe opt-in
- `@unchecked Sendable` at use site - makes unsafety visible but scattered

**Cross-references**: [API-CONC-005], [PATTERN-021]

---

## Audit and Refactoring Patterns

### [PATTERN-023] Minimal Reproduction as Verification Tool

**Scope**: Resolving debates about compiler behavior, runtime semantics, or "what Swift does."

**Statement**: When technical debates rest on claims about compiler behavior, runtime semantics, or language mechanics, a minimal reproduction package MUST be built to verify the claim.

> **Full methodology**: See <doc:Pattern-Experiment-Package> for complete experiment package creation protocol, including location conventions, reduction methodology, and result documentation.

**Cross-references**: [API-DESIGN-004], [API-DESIGN-007], <doc:Pattern-Experiment-Package>

---

### [PATTERN-026] Centralization as Architectural Principle

**Scope**: Decisions about whether to use primitives or domain-specific implementations.

**Statement**: Common patterns MUST be centralized in primitives, even when it adds verbosity at call sites. The same argument that could justify `Foundation.Date` in each package applies to ad-hoc wrappers—and is equally wrong.

**Cross-references**: [API-IMPL-011], [PATTERN-024], <doc:Ecosystem-Process#ECO-CENT-001>

---

### [PATTERN-027] Custom Deinit as Migration Boundary

**Scope**: Evaluating whether domain-specific wrappers can be replaced with primitives.

**Statement**: Custom `deinit` marks an architectural boundary for migration to primitives. When a wrapper class has cleanup logic beyond "deallocate memory," that logic encodes domain knowledge the primitive cannot provide.

**Cross-references**: [PATTERN-026], [PATTERN-014], <doc:Ecosystem-Process#ECO-EXTR-004>

---

### [PATTERN-028] Audit-Driven Refactoring

**Scope**: Systematic identification of architectural debt through consistency audits.

**Statement**: Refactoring MAY be driven by consistency audits rather than bug reports or feature requests. When centralized primitives exist, the question "what's still ad-hoc?" reveals patterns that would never surface through bug reports.

**Cross-references**: [PATTERN-026], [PATTERN-027], <doc:Ecosystem-Process#ECO-AUDIT-001>

---

## API Design Patterns

### [PATTERN-017] Fallback as Feature, Not Compromise

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
// ❌ Forcing callers to pre-validate
public static func parseHyphenated(_ string: String) -> UUID?
public static func parseCompact(_ string: String) -> UUID?
```

**Cross-references**: [TEST-PERF-006], [API-ERR-003]

---

### [PATTERN-024] Type Aliases as Architectural Boundaries

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
// ❌ 27 files each using the full type
let storage: Reference.Indirect<MyIterator>.Unchecked
// Decision scattered, no central justification
```

**Cross-references**: [API-CONC-005], [API-IMPL-006]

---

### [PATTERN-032] Bound vs Independent Typealias Parameters

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
// Usage: Cache.Evict<String, Int>  // ❌ Ambiguous
```

**Cross-references**: [API-NAME-001], [API-NAME-007a]

---

### [PATTERN-034] Requirements as Design Pressure

**Scope**: Using requirements documents as executable design constraints.

**Statement**: API requirements documents function as type systems for design decisions. Rigorous application of requirements redirects "easy" solutions toward correct solutions.

**Cross-references**: [API-NAME-001], [API-NAME-002], [DOC-CONTENT-001]

---

### [PATTERN-049] Typealiases as the Reuse Primitive

**Scope**: Sharing types between façade packages and their implementation dependencies.

**Statement**: When multiple packages need to expose the same types with local names, typealiases MUST be used instead of wrapper types. Typealiases give zero-cost sharing at the ABI level. Wrapper types reintroduce duplication.

**Correct**:
```swift
// Façade re-exports with local name
public typealias Value = Machine_Primitives.Machine.Value
public typealias Transform = Machine_Primitives.Machine.Transform<Instruction>
public typealias Program = Machine_Primitives.Machine.Program<Instruction, Fault>

// Zero-cost: types are identical at ABI level
// No forwarding, no wrapping, no runtime cost
```

**Incorrect**:
```swift
// ❌ Wrapper type reintroduces duplication
public struct BinaryValue {
    public let inner: Machine_Primitives.Machine.Value

    // Every method must be forwarded
    public func map<T>(_ transform: (Any) -> T) -> T {
        inner.map(transform)
    }
    // Every combinator must unwrap/rewrap
}
```

#### Generic Typealias Extension Limitation

You cannot extend a generic typealias. When `Program` is a typealias to `Machine.Program<Instruction, Fault>`, the generic parameters aren't in scope for extensions:

```swift
// ❌ FAILS: generic parameters not in scope
extension Binary.Bytes.Machine.Program {
    func run() { ... }
}
```

**Workaround**: Use static functions on the façade namespace instead of instance methods:

```swift
// ✓ Static functions on façade namespace
extension Binary.Bytes.Machine {
    public static func run(program: Program, root: ID, ...) -> Result {
        // Implementation
    }
}

// Usage: Binary.Bytes.Machine.run(program:root:...) instead of program.run(root:...)
```

This is slightly less ergonomic but preserves the sharing benefit. The alternative—wrapper types—costs far more in duplication and maintenance.

#### MemberImportVisibility Discipline

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

### [PATTERN-050] Never as Closed Default for Extension Points

**Scope**: Designing generic types that allow façade-specific extensions without code duplication.

**Statement**: When designing shared types that may need façade-specific extensions, the extension capability SHOULD be encoded as a generic type parameter with `Never` as the closed default.

**The Pattern**:

```swift
// Core shared type with extension point
public enum Frame<NodeID, Checkpoint, Failure: Error, Extra> {
    case call(child: NodeID)
    case sequence(a: NodeID, b: NodeID, combine: Combine)
    case choice(first: NodeID, second: NodeID)
    case extra(Extra)  // Extension point
}

// Façade A: Needs memoization, so Extra = Memoization<Checkpoint>
public typealias ParsingFrame = Frame<NodeID, Checkpoint, Failure, Memoization<Checkpoint>>

// Façade B: Needs nothing extra, so Extra = Never
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
// ❌ Using fatalError for cases that "shouldn't happen"
case .extra:
    fatalError("BinaryFrame doesn't support extra")

// This is a runtime trap; Never gives compile-time proof
```

#### Why `Never` Works

`Never` is Swift's bottom type—uninhabited and impossible to construct. When `Extra = Never`:

- The `case extra(Extra)` exists syntactically
- No value can be constructed to match it
- `switch never {}` compiles to nothing—it's a type-level assertion of impossibility
- Total interpreters remain total without runtime checks

#### Naming Limitation with Typealiases

You cannot nest `Extra` inside `Frame` when `Frame` is a typealias. The solution: define the extension type at the façade's namespace level, then reference it in the Frame typealias:

```swift
// Cannot do: ParsingFrame.Extra (generic params not in scope)

// Instead: define at façade namespace level
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

**Rationale**: The `Extra` parameter pattern enables shared types to serve multiple façades with different needs. Façades that need extensions provide a concrete type; façades that don't use `Never` and get compile-time elimination of the extension case.

**Cross-references**: [PATTERN-049], [PATTERN-024], [PATTERN-014]

---

## Unsafe and Safety Patterns

### [PATTERN-038] Dual-Overload Anti-Pattern

**Scope**: APIs with both safe and unsafe overloads for the same operation.

**Statement**: Public APIs MUST NOT provide dual overloads where one takes unsafe pointers and another takes safe types. The unsafe overload SHOULD be `internal` or `@usableFromInline internal`.

**Cross-references**: [PATTERN-039], [API-NAME-008]

---

### [PATTERN-039] Inline Clarity Over Helper Consolidation

**Scope**: Helper functions for unsafe operations.

**Statement**: Helper functions are appropriate for abstracting *complexity* but inappropriate for abstracting *danger*. Unsafe operations SHOULD be inline and explicit, not hidden behind convenience helpers.

**Cross-references**: [PATTERN-038], [API-NAME-008]

---

### [PATTERN-040] Span as Normative Interface

**Scope**: APIs for contiguous memory access.

**Statement**: APIs providing contiguous memory access SHOULD use `Span` as the primary interface. Unsafe pointer access SHOULD be relegated to accessor escape hatches, not parallel overloads.

**Cross-references**: [PATTERN-038], [PATTERN-039], [PATTERN-005b]

---

### [PATTERN-041] API Surface Reduction as Safety

**Scope**: Reducing public API surface for safety improvements.

**Statement**: Removing public unsafe overloads in favor of scoped accessors reduces API surface without reducing capability. Less surface area means less documentation, less attack surface, and fewer paths to misuse.

**Cross-references**: [PATTERN-038], [PATTERN-040]

---

### [PATTERN-048] Closure Scope Over Property Access for Unsafe Operations

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
        _ body: (UnsafePointer<Char>) throws -> R
    ) rethrows -> R {
        _storage.withUnsafeBufferPointer { buffer in
            try body(buffer.baseAddress!)
        }
    }
}
```

**Incorrect**:
```swift
// ❌ Property makes unsafe operation look safe
public var unsafeCString: UnsafePointer<Char> {
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

**Cross-references**: [PATTERN-038], [PATTERN-039], [PATTERN-040], [MEM-SAFE-002]

---

## Topics

### Related Documents

- <doc:Implementation-Patterns>
- <doc:Memory>
- <doc:API-Requirements>
