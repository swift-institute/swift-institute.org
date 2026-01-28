# Memory Copyable

<!--
---
title: Memory Copyable
version: 1.0.0
last_updated: 2026-01-19
applies_to: [swift-primitives, swift-institute, swift-standards, swift-foundations]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Noncopyable types (~Copyable): declaration, error handling, and collections.

## Overview

This document defines patterns for noncopyable types.

**Applies to**: Types representing resources with exclusive ownership.

---

## [MEM-COPY-001] Noncopyable Type Declaration

**Scope**: Types requiring single-ownership semantics.

**Statement**: Types that represent resources with exclusive ownership MUST be marked `~Copyable`. This prevents implicit copying and enables move semantics.

**Correct**:
```swift
struct FileDescriptor: ~Copyable {
    private let fd: CInt

    deinit {
        close(fd)
    }
}

struct Buffer: ~Copyable, Sendable {
    private let pointer: UnsafeMutableRawPointer
    private let size: Int

    deinit {
        pointer.deallocate()
    }
}
```

**Incorrect**:
```swift
// ❌ Copyable resource handle - allows double-free
struct FileDescriptor {
    let fd: CInt
    // Can be copied, leading to multiple close() calls
}
```

**Rationale**: Move-only semantics prevent use-after-free and double-free at compile time. The type system enforces that exactly one owner manages each resource.

**Cross-references**: [PATTERN-014], [SYS-MEM-002], [API-ERR-005]

---

## [MEM-COPY-002] Noncopyable in Error Types

**Scope**: Error type design involving `~Copyable` values.

**Statement**: `Swift.Error` requires `Copyable`. Move-only (`~Copyable`) values MUST NOT be embedded in types conforming to `Error`. APIs that must preserve move-only state across failure MUST use non-throwing outcome types.

**Correct**:
```swift
enum RegistrationOutcome {
    case success(RegisteredToken)
    case failure(UnregisteredToken, RegistrationError)
}

func register(_ token: consuming UnregisteredToken) -> RegistrationOutcome
```

**Incorrect**:
```swift
// ❌ Token lost on failure - ~Copyable cannot be in Error
func register(_ token: consuming UnregisteredToken) throws -> RegisteredToken
```

**Rationale**: Prevents accidental loss of move-only resources when errors are thrown.

**Cross-references**: [API-ERR-005], [API-ERR-006]

---

## [MEM-COPY-003] Noncopyable in Collections

**Scope**: Storing `~Copyable` types in collections.

**Statement**: When `~Copyable` types must be stored in collections (which require `Copyable` values), wrap the `~Copyable` content in a class. The class provides reference semantics (copyable), while the content remains move-only.

**Correct**:
```swift
final class Entry<T: Sendable>: @unchecked Sendable {
    enum State: ~Copyable {
        case pending(Waiter.Queue)
        case computing
        case completed(T)
    }

    private let lock = Mutex<State>(.pending(.init()))
}

// Entry is copyable (reference semantics)
var cache: [Key: Entry<Value>] = [:]
```

**Incorrect**:
```swift
// ❌ Cannot store ~Copyable directly in dictionary
var cache: [Key: State] = [:]  // Compiler error: State is ~Copyable
```

**Rationale**: Swift's ownership system doesn't yet support move-only dictionary values. Classes provide the reference semantics needed for collection storage while preserving move-only content semantics through encapsulation.

**Cross-references**: [PATTERN-021]

---

## [MEM-COPY-004] Extension Constraints for ~Copyable Types

**Scope**: Writing extensions on generic types with `~Copyable` type parameters.

**Statement**: Extensions on generic types with `~Copyable` type parameters MUST include explicit `where Element: ~Copyable` constraints. Without this, extensions implicitly add `where Element: Copyable`, making them inaccessible for noncopyable elements.

### The Suppression Propagation Rule

In Swift 6, `~Copyable` is a *suppression* of the implicit `Copyable` requirement. Unlike protocol conformances (which propagate through extensions), suppressions do not propagate automatically.

| Constraint Type | Propagation to Extensions |
|-----------------|---------------------------|
| Protocol conformance (`Element: Equatable`) | Automatic |
| Suppression (`Element: ~Copyable`) | **Must be explicit** |

**Correct**:
```swift
struct Container<Element: ~Copyable>: ~Copyable { }

// Extension for ALL elements (including ~Copyable)
extension Container where Element: ~Copyable {
    func operation() { }  // Available for all Element types
}

// Extension only for Copyable elements
extension Container where Element: Copyable {
    func copyableOnlyOperation() { }  // Only when Element: Copyable
}
```

**Incorrect**:
```swift
struct Container<Element: ~Copyable>: ~Copyable { }

// ❌ Implicitly adds 'where Element: Copyable'
extension Container {
    func operation() { }  // Only available when Element: Copyable!
}
```

The compiler may not warn about the missing constraint. The error appears at call sites when `Element` is `~Copyable`:

```text
error: type 'MyNonCopyableType' does not conform to protocol 'Copyable'
note: 'where Element: Copyable' is implicit here
```

### Applies to All Extension Content

This rule applies to everything in extensions:
- Methods
- Computed properties
- Nested types
- **Typealiases** (see example below)

```swift
// ❌ Typealias with implicit Copyable constraint
extension Container {
    typealias Error = ContainerError  // Only visible when Element: Copyable!
}

// ✓ Typealias available for all Element types
extension Container where Element: ~Copyable {
    typealias Error = ContainerError
}
```

**Rationale**: This is a fundamental asymmetry in Swift's noncopyable generics model. Developers expecting constraint propagation from protocol conformances will be surprised. Explicit constraints are required for every extension.

**Cross-references**: [MEM-COPY-001], [PATTERN-005-004]

---

## [MEM-COPY-005] Nested Accessor Pattern Incompatibility

**Scope**: Using the nested accessor pattern ([API-NAME-005]) with `~Copyable` containers.

**Statement**: Non-consuming nested accessor patterns are fundamentally incompatible with `~Copyable` containers. The accessor struct must store a reference to the container, which requires copying—impossible for `~Copyable` types.

### The Two Accessor Forms

| Form | Ownership | ~Copyable Compatible | Example |
|------|-----------|---------------------|---------|
| Consuming | Transfers ownership | ✅ Yes | `channel.take().send` |
| Non-consuming | Borrows or copies | ❌ No | `deque.peek.back` |

**Consuming accessors** work because they transfer ownership:

```swift
// WORKS: Container is consumed into accessor
consuming func take() -> Take {
    Take(channel: consume self)
}
// After channel.take(), channel is gone
```

**Non-consuming accessors** fail because they require copying:

```swift
// FAILS: Cannot copy ~Copyable container into accessor struct
var peek: Peek {
    Peek(deque: self)  // Requires copying self
}
// After deque.peek.back, deque still exists
```

### Why There's No Middle Ground

The natural solution would be a *borrowing* accessor—one that temporarily borrows `self` without copying or consuming. Swift 6 has `borrowing` for function parameters, but no mechanism for user-defined types to hold borrowed references.

`Span` and `MutableSpan` achieve borrowed views through compiler magic (`~Escapable` + `@_lifetime`), but user types cannot replicate this for accessor structs.

### Design Implications

For `~Copyable` containers requiring the nested accessor pattern, choose one:

1. **Keep container Copyable** - Accept that ~Copyable elements aren't supported
2. **Use direct methods** - `container.peekBack()` instead of `container.peek.back`
3. **Wait for language evolution** - Borrowing references in user types

**Exception**: Consuming accessors (one-shot operations like endpoint extraction) work and are legitimate.

**Rationale**: This is not a bug—it's a fundamental constraint of Swift's current ownership model. [API-NAME-005] must be applied with awareness that it excludes `~Copyable` container support for non-consuming patterns.

**Cross-references**: [API-NAME-005], [MEM-COPY-001], [MEM-COPY-004]

---

## [MEM-COPY-006] ~Copyable Propagation Gotchas

**Scope**: All scenarios where `~Copyable` constraint suppression fails to propagate.

**Statement**: Swift's `~Copyable` constraint suppression fails to propagate across certain boundaries. This section documents all known categories for reference.

### Category 1: Extension Declaration Site

Nested types declared in extensions don't inherit `~Copyable` from the outer type:

```swift
struct Outer<Element: ~Copyable>: ~Copyable { }
extension Outer {
    struct Nested: ~Copyable { }  // ❌ Element: Copyable is implicit!
}
```

**Workaround**: Declare nested types inside the struct body, not extensions.

### Category 2: Implicit Copyable in Extensions

Extensions on `~Copyable` types implicitly add `where Element: Copyable`. See [MEM-COPY-004] for full details.

```swift
extension Container {  // Implicitly: where Element: Copyable
    func foo() { }
    typealias Alias = SomeType  // Also implicit Copyable!
}
```

**Workaround**: Add explicit `where Element: ~Copyable` to every extension.

### Category 3: Protocol Conformance in Separate Files

Protocol conformances for nested types, when in separate files, break `~Copyable` propagation:

```swift
// File: Main.swift
struct Stack<Element: ~Copyable>: ~Copyable {
    struct Bounded: ~Copyable {
        var ptr: UnsafeMutablePointer<Element>  // Works here
    }
}

// File: Bounded.swift
extension Stack.Bounded: Sequence where Element: Copyable { }
// ❌ Causes ptr declaration to fail with Copyable requirement
```

**Workaround**: Put protocol conformances for nested types in the same file as the type declaration.

### Category 4: Sequence/Collection Protocol Requirements

Swift's `Sequence` and `Collection` protocols have hidden `Copyable` requirements:

```swift
struct Container<Element: ~Copyable>: ~Copyable { }
extension Container: Sequence { }  // ❌ Copyable required on Container
```

**Workaround**: No workaround—`~Copyable` types cannot conform to standard collection protocols. Use `forEach(_:)` with borrowing closures for iteration.

### Category 5: Module Emission Phase Constraint Solver Failure

This category manifests only during `-emit-module`, not during parse or type-check. It requires the specific combination of ALL these conditions:

| # | Condition | Description |
|---|-----------|-------------|
| 1 | Compound constraint | `Element: ~Copyable & Protocol` |
| 2 | Unsafe pointer | `UnsafeMutablePointer<Element>` in nested type |
| 3 | Conditional Sequence | `extension ...: Sequence where Element: Copyable` |
| 4 | Extension file | `borrowing Element` closure in **separate file** |
| 5 | Library target | Uses `-emit-module` (not executable) |
| 6 | Lifetimes feature | `-enable-experimental-feature Lifetimes` flag |

```swift
// File: Container.swift
struct Container<Element: ~Copyable & SomeProtocol>: ~Copyable {
    struct Bounded: ~Copyable {
        var ptr: UnsafeMutablePointer<Element>  // Trigger condition 2
    }
}
extension Container.Bounded: Sequence where Element: Copyable { }  // Trigger 3

// File: Methods.swift - SEPARATE FILE triggers the bug
extension Container.Bounded where Element: ~Copyable {
    func withElement<R>(_ body: (borrowing Element) -> R) -> R { ... }  // Trigger 4
}
```

This compiles during parse and type-check, but fails during module emission:
```text
error: type 'Element' does not conform to protocol 'Copyable'
```

**Workaround**: Consolidate all source code into a single file. When all code is in one file, the constraint solver sees the complete picture in a single pass. See [PATTERN-016] for documentation requirements.

**Tracking**: Swift issue #86669

### The Common Thread

All categories involve the compiler failing to propagate `~Copyable` constraint suppression across boundaries:

| Category | Boundary |
|----------|----------|
 extension |
 extension on that type |
 conformance file |
 standard protocol |
| 5 | Cross-file during module emission (compound constraints) |

### Generic Parameter Identity

The root cause of most propagation failures is **generic parameter identity**. Swift's generics aren't just about type constraints—they're about which generic parameter you're referencing.

```swift
struct Outer<T: ~Copyable> {
    struct Inner {
        var value: T  // Same T as Outer - suppression propagates
    }
}
```

The `T` in Inner is **the same generic parameter** as in Outer, not a new one that happens to be constrained identically. This identity relationship is what allows the constraint suppression to propagate.

When you reference an external type:

```swift
struct Helper<T: ~Copyable> { var value: T }

struct Outer<T: ~Copyable> {
    var helper: Helper<T>  // Different T parameters!
}
```

Even though both `T`s are `~Copyable`, they're different generic parameters. The constraint suppression on Outer's `T` doesn't transfer to Helper's `T` when you instantiate `Helper<T>`. Generic specialization is resolved at the call site, not propagated from the definition's constraints.

### Workaround Hierarchy

When encountering `~Copyable` propagation failures, attempt workarounds in this order (most likely to succeed first):

| Priority | Workaround | Why It Fails/Succeeds |
|----------|------------|----------------------|
| 1 | Nest types inside the outer type body | ✅ Same generic parameter identity |
| 2 | Add explicit `where Element: ~Copyable` to extensions | ✅ Explicit suppression |
| 3 | Move conformances to same file as declaration | ✅ Avoids cross-file boundary |
| 4 | Module-level wrapper types | ❌ Different generic parameter |
| 5 | Module-level typealiases | ❌ Different generic parameter |
| 6 | @_exported import | ❌ Visibility ≠ parameter identity |
| 7 | Extension with explicit `where` constraint | ❌ Extensions don't create new constraint contexts |

The nested type pattern (Priority 1) is the only reliable workaround for containers that need to support move-only elements with external storage types.

**Rationale**: Until Swift fixes these at the language level, the workarounds are essential knowledge for any code using `~Copyable` generics.

**Cross-references**: [MEM-COPY-004], [MEM-COPY-005]

---

## Linear and Affine Types

### [MEM-LINEAR-001] Exactly-Once Types

**Scope**: Values that must be used exactly once.

**Statement**: When an invariant requires that a value be used exactly once (linear type), the type MUST be `~Copyable` with a `consuming func` for the use operation and a `deinit` that traps if the value was not consumed.

**Correct**:
```swift
/// A continuation that must be resumed exactly once.
public struct Continuation<T>: ~Copyable, Sendable {
    private let resume: @Sendable (T) -> Void

    /// Consumes the continuation, resuming it with a value.
    public consuming func callAsFunction(_ value: T) {
        resume(value)
    }

    deinit {
        preconditionFailure("Continuation was dropped without being resumed")
    }
}

// Compiler enforces exactly-once:
func example(_ cont: consuming Continuation<Int>) {
    cont(42)        // ✓ Consumes the continuation
    // cont(43)     // ❌ Compile error: 'cont' used after consume
}
```

**Rationale**: The compiler becomes a proof assistant for exactly-once usage, eliminating double-resume and forgotten-resume bugs.

**Cross-references**: [PATTERN-014], [PATTERN-016]

---

### [MEM-LINEAR-002] At-Most-Once Types

**Scope**: Values that may be used at most once.

**Statement**: When an invariant allows a value to be used at most once (affine type), the type MUST be `~Copyable` with a `consuming func` for the use operation and a silent `deinit` (no trap).

**Correct**:
```swift
/// A token that may be redeemed at most once.
public struct Token: ~Copyable, Sendable {
    private let action: @Sendable () -> Void

    public consuming func redeem() {
        action()
    }

    deinit {
        // Silent - unused is valid for at-most-once
    }
}
```

| Semantics | `deinit` Behavior |
|-----------|-------------------|
| Exactly-once (linear) | `preconditionFailure` - must be used |
| At-most-once (affine) | Silent - unused is valid |

**Cross-references**: [PATTERN-014]

---

### [MEM-LINEAR-003] Proof Categories

**Scope**: Using the ownership system as a proof assistant.

**Statement**: The Swift ownership system functions as a compile-time proof assistant.

| Invariant | Ownership Encoding | Compiler Enforcement |
|-----------|-------------------|---------------------|
| Exactly-once use | `~Copyable` + `consuming func` + `deinit` trap | Double-use at compile time; dropped-without-use at runtime |
| At-most-once use | `~Copyable` + `consuming func` + silent `deinit` | Double-use at compile time; unused is valid |
| Transfer semantics | `consuming` parameter | Caller cannot use value after transfer |
| Borrow semantics | `borrowing` parameter | Callee cannot consume or store |

**Rationale**: Recognizing `~Copyable` as a proof assistant rather than just memory optimization changes API design approach.

**Cross-references**: [PATTERN-016]

---

## Span Access Patterns

### [MEM-SPAN-001] Property-Based Span Access

**Scope**: APIs that provide `Span` or `MutableSpan` views.

**Statement**: Types that expose `Span` or `MutableSpan` views MUST use property-based access, not closure-based `withSpan(_:)` methods. SE-0456 establishes property-based access as the canonical pattern for the standard library.

**Correct**:
```swift
struct Container<Element: ~Copyable>: ~Copyable {
    var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get { /* ... */ }
    }

    var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get { /* ... */ }
    }
}

// Usage
let value = container.span[index]
container.mutableSpan[index] = newValue
```

**Incorrect**:
```swift
// ❌ Closure-based access is vestigial
func withSpan<R>(_ body: (Span<Element>) -> R) -> R {
    body(span)  // Just wraps the property—adds nothing
}

// ❌ Redundant element accessor
func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R
// Use span[index] instead
```

### Why Closures Are Vestigial

The closure pattern (`withUnsafeBufferPointer(_:)`) exists because `UnsafeBufferPointer` can escape—closures enforce scoping. But `Span` is `~Escapable`; the type system enforces scoping. The closure becomes a wrapper that adds ceremony without benefit.

| Type | Escapable | Scoping Mechanism |
|------|-----------|-------------------|
| `UnsafeBufferPointer` | Yes | Closure scope |
| `Span` | No (`~Escapable`) | Type system |

**Rationale**: SE-0456 explicitly recommends property-based span access: "Closure-taking API can also be difficult to compose with new features and with one another." Primitives packages should lead ecosystem convergence toward canonical patterns.

**Cross-references**: [MEM-COPY-001], SE-0456

---

## Techniques

**Applies to**: Practical implementation of noncopyable patterns.

---

### [MEM-COPY-010] Noncopyable Workarounds for Associated Types

**Scope**: Protocols where associated types should be `~Copyable` but Swift doesn't yet support this.

**Statement**: When a protocol's semantic contract implies noncopyable associated types but Swift's type system doesn't support `associatedtype T: ~Copyable`, use `Reference.Box<T>` as a workaround. Document the intent and anticipate language evolution.

**Example**:
```swift
// Cannot express: associatedtype Token: ~Copyable
protocol ResourceManager {
    associatedtype Token  // Implicitly Copyable

    // Workaround: box the ~Copyable value
    func acquire() -> Reference.Box<ActualToken>
    func release(_ token: consuming Reference.Box<ActualToken>)
}
```

**Rationale**: Language limitations shouldn't prevent expressing the correct semantic contract. Document the workaround and the intended semantics.

**Cross-references**: [MEM-LINEAR-001], [MEM-COPY-003]

---

### [MEM-COPY-011] Two-World Separation for Owned and Borrowed Types

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
// Forcing unification through abstraction
public protocol Parser<Input, Output, Failure> {
    associatedtype Input: ~Escapable  // Cannot do this in Swift 6.x
    func parse(_ input: inout Input) throws(Failure) -> Output
}

// Using owned type as "borrowed" API
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

**Cross-references**: [MEM-COPY-010], [MEM-LINEAR-001], [API-DESIGN-002]

---

## Topics

### Related Documents

- <doc:Memory>
- <doc:Memory-Ownership>
