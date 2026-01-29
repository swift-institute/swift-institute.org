---
name: memory
description: |
  Memory ownership, copyability, and lifetime safety rules.
  ALWAYS apply when working with ~Copyable types or ownership annotations.

layer: implementation

requires:
  - swift-institute
  - naming
  - errors

applies_to:
  - swift
  - swift6
  - primitives

migrated_from: Documentation.docc/Memory Copyable.md
migration_date: 2026-01-28
---

# Memory Conventions

Rules for ownership, copyability, linear types, and span access patterns.

**Source documents**: Memory Copyable.md, Memory Ownership.md

---

## ~Copyable Types

### [MEM-COPY-001] Noncopyable Type Declaration

**Scope**: Types requiring single-ownership semantics.

**Statement**: Types that represent resources with exclusive ownership MUST be marked `~Copyable`.

```swift
// CORRECT
enum File {
    struct Descriptor: ~Copyable {
        private let fd: CInt
        deinit { close(fd) }
    }
}

// INCORRECT - Allows double-free, compound name
struct FileDescriptor {
    let fd: CInt
}
```

**Cross-references**: [PATTERN-014]

---

### [MEM-COPY-002] Noncopyable in Error Types

**Scope**: Error type design involving `~Copyable` values.

**Statement**: `Swift.Error` requires `Copyable`. Move-only values MUST NOT be embedded in `Error` types. Use non-throwing outcome types instead.

```swift
// CORRECT
enum RegistrationOutcome {
    case success(RegisteredToken)
    case failure(UnregisteredToken, RegistrationError)
}
func register(_ token: consuming UnregisteredToken) -> RegistrationOutcome

// INCORRECT - Token lost on failure
func register(_ token: consuming UnregisteredToken) throws -> RegisteredToken
```

---

### [MEM-COPY-003] Noncopyable in Collections

**Scope**: Storing `~Copyable` types in collections.

**Statement**: When `~Copyable` types must be stored in collections, wrap the content in a class.

```swift
// CORRECT - Class provides reference semantics
final class Entry<T: Sendable>: @unchecked Sendable {
    enum State: ~Copyable {
        case pending(Waiter.Queue)
        case computing
        case completed(T)
    }
    private let lock = Mutex<State>(.pending(.init()))
}
var cache: [Key: Entry<Value>] = [:]

// INCORRECT - Cannot store ~Copyable directly
var cache: [Key: State] = [:]  // Compiler error
```

---

### [MEM-COPY-004] Extension Constraints for ~Copyable Types

**Scope**: Extensions on generic types with `~Copyable` type parameters.

**Statement**: Extensions MUST include explicit `where Element: ~Copyable` constraints. Without this, extensions implicitly add `where Element: Copyable`.

```swift
// CORRECT - Available for ALL elements
extension Container where Element: ~Copyable {
    func operation() { }
}

// CORRECT - Intentionally restricted
extension Container where Element: Copyable {
    func copyableOnlyOperation() { }
}

// INCORRECT - Implicitly adds 'where Element: Copyable'
extension Container {
    func operation() { }  // Only available when Element: Copyable!
}
```

Applies to **all extension content**: methods, computed properties, nested types, and typealiases.

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

**Cross-references**: [MEM-COPY-001]

---

### [MEM-COPY-005] Nested Accessor Pattern Incompatibility

**Scope**: Using nested accessor pattern with `~Copyable` containers.

**Statement**: Non-consuming nested accessor patterns are incompatible with `~Copyable` containers. The accessor struct must store a reference to the container, which requires copying.

| Form | Ownership | ~Copyable Compatible |
|------|-----------|---------------------|
| Consuming | Transfers ownership | Yes |
| Non-consuming | Borrows or copies | No |

For `~Copyable` containers, choose: keep container Copyable, use direct methods (`container.peekBack()` instead of `container.peek.back`), or wait for language evolution.

**Cross-references**: [API-NAME-002], [MEM-COPY-001]

---

### [MEM-COPY-006] ~Copyable Propagation Gotchas

**Scope**: All scenarios where `~Copyable` constraint suppression fails to propagate.

**Statement**: Swift's `~Copyable` suppression fails across certain boundaries. All known categories:

| Category | Boundary | Workaround |
|----------|----------|------------|
| 1 | Extension declaration site | Declare nested types inside struct body |
| 2 | Implicit Copyable in extensions | Add explicit `where Element: ~Copyable` |
| 3 | Protocol conformance in separate files | Move conformances to same file |
| 4 | Sequence/Collection protocol requirements | No workaround; use `forEach` with borrowing closures |
| 5 | Module emission phase (compound constraints + separate file + Lifetimes flag) | Consolidate to single file |

**Root cause**: Generic parameter identity. `~Copyable` suppression propagates only when the same generic parameter is referenced, not across different generic parameters with identical constraints.

**Workaround hierarchy** (most reliable first):
1. Nest types inside outer type body (same generic parameter identity)
2. Add explicit `where Element: ~Copyable` to extensions
3. Move conformances to same file as declaration
4. Module-level wrapper types (unreliable — different generic parameter)

**Tracking**: Category 5 — Swift issue #86669

**Cross-references**: [MEM-COPY-004], [MEM-COPY-005]

---

## Linear and Affine Types

### [MEM-LINEAR-001] Exactly-Once Types

**Scope**: Values that must be used exactly once.

**Statement**: Linear types MUST be `~Copyable` with a `consuming func` for the use operation and a `deinit` that traps if not consumed.

```swift
public struct Continuation<T>: ~Copyable, Sendable {
    private let resume: @Sendable (T) -> Void

    public consuming func callAsFunction(_ value: T) {
        resume(value)
    }

    deinit {
        preconditionFailure("Continuation was dropped without being resumed")
    }
}
```

---

### [MEM-LINEAR-002] At-Most-Once Types

**Scope**: Values that may be used at most once.

**Statement**: Affine types MUST be `~Copyable` with a `consuming func` and a silent `deinit` (no trap).

| Semantics | `deinit` Behavior |
|-----------|-------------------|
| Exactly-once (linear) | `preconditionFailure` |
| At-most-once (affine) | Silent — unused is valid |

---

### [MEM-LINEAR-003] Proof Categories

**Scope**: Using ownership as a proof assistant.

| Invariant | Ownership Encoding | Compiler Enforcement |
|-----------|-------------------|---------------------|
| Exactly-once use | `~Copyable` + `consuming func` + `deinit` trap | Double-use at compile time; dropped-without-use at runtime |
| At-most-once use | `~Copyable` + `consuming func` + silent `deinit` | Double-use at compile time |
| Transfer semantics | `consuming` parameter | Caller cannot use value after transfer |
| Borrow semantics | `borrowing` parameter | Callee cannot consume or store |

---

## Span Access Patterns

### [MEM-SPAN-001] Property-Based Span Access

**Scope**: APIs providing `Span` or `MutableSpan` views.

**Statement**: Types that expose `Span` or `MutableSpan` MUST use property-based access, not closure-based `withSpan(_:)`.

```swift
// CORRECT - Property-based (SE-0456)
var span: Span<Element> {
    @_lifetime(borrow self)
    borrowing get { /* ... */ }
}

// INCORRECT - Closure-based is vestigial
func withSpan<R>(_ body: (Span<Element>) -> R) -> R
```

`Span` is `~Escapable` — the type system enforces scoping, making closures unnecessary.

| Type | Escapable | Scoping Mechanism |
|------|-----------|-------------------|
| `UnsafeBufferPointer` | Yes | Closure scope |
| `Span` | No (`~Escapable`) | Type system |

**Cross-references**: [MEM-COPY-001], SE-0456

---

## Techniques

### [MEM-COPY-010] Noncopyable Workarounds for Associated Types

**Scope**: Protocols where associated types should be `~Copyable`.

**Statement**: When Swift doesn't support `associatedtype T: ~Copyable`, use `Reference.Box<T>` as a workaround. Document the intent.

```swift
protocol ResourceManager {
    associatedtype Token  // Implicitly Copyable
    func acquire() -> Reference.Box<ActualToken>  // Workaround
    func release(_ token: consuming Reference.Box<ActualToken>)
}
```

---

### [MEM-COPY-011] Two-World Separation

**Scope**: APIs with both owned (escapable) and borrowed (`~Escapable`) variants.

**Statement**: When owned and borrowed variants have different semantic properties, they MUST be separate types with separate protocol conformances.

| World | Prioritizes | Sacrifices |
|-------|-------------|------------|
| Owned | Combinator reuse | Compile-time safety |
| Borrowed | Zero-copy | Separate protocol |

Provide explicit bridge types for cross-world reuse with controlled copy points.

**Cross-references**: [MEM-COPY-010], [MEM-LINEAR-001]

---

## Ownership Annotations

### [MEM-OWN-001] Consuming Parameters

**Statement**: Use `consuming` when taking ownership. Caller cannot use the value after passing it.

```swift
public init(_ value: consuming Value) {
    self._storage = value
}
```

---

### [MEM-OWN-002] Borrowing Parameters

**Statement**: Use `borrowing` for read-only access without ownership transfer.

```swift
public func withValue<Result>(
    _ body: (borrowing Value) throws -> Result
) rethrows -> Result
```

---

### Ownership Table

| Keyword | Ownership | Caller After Call | Callee Can |
|---------|-----------|-------------------|------------|
| `consuming` | Transferred to callee | Cannot use value | Store, consume |
| `borrowing` | Retained by caller | Can use value | Read only |
| `inout` | Temporarily loaned | Can use value | Mutate |

---

### Type-Level Ownership Naming

**Statement**: A primitive named after a **reference** (Address, Pointer, Handle) SHOULD be non-owning and `Copyable`. A primitive named after a **resource** (String, Array, Allocation) SHOULD be owning and MAY provide a `.View` borrowing type.

| Category | Examples | Copyable? | Owns Memory? |
|----------|----------|-----------|--------------|
| Reference | Address, Pointer, Handle | Yes | No |
| Resource | String, Array, Allocation | Varies | Yes |

Applying "resource owns, view borrows" to reference types is a **category error**. Pointers are the lens onto memory, not what should have views.

---

## Cross-References

See also:
- **memory-safety** skill for strict safety, unsafe marking, reference primitives
- **copyable-remediation** skill for auditing and fixing ~Copyable constraint issues
- **primitives** skill for ~Copyable collection patterns
