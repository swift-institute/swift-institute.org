---
name: memory
description: |
  Memory ownership, copyability, lifetime safety, strict memory safety,
  unsafe marking, sendable conformance, and reference primitives.
  ALWAYS apply when working with ~Copyable types, ownership annotations,
  unsafe operations, reference types, or concurrency safety.

layer: implementation

requires:
  - swift-institute

applies_to:
  - swift
  - swift6
  - primitives

absorbs:
  - memory-safety
---

# Memory Conventions

Rules for ownership, copyability, linear types, strict memory safety, reference primitives, and lifetime management.

**Source documents**: Memory Copyable.md, Memory Ownership.md, Memory Safety.md, Memory Reference.md

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

**Nested type extensions**: This rule also applies to extensions on nested types within a generic outer type. Even when `Storage<Element: ~Copyable>` already constrains `Element`, extensions on nested types like `Storage.Heap` still require `where Element: ~Copyable`:

```swift
public enum Storage<Element: ~Copyable> {
    public final class Heap: ManagedBuffer<Header, Element> { }
}

// ❌ FAILS - constraint appears redundant but is required
extension Storage.Heap {
    public struct Header { ... }
}

// ✓ WORKS - explicit constraint on nested type extension
extension Storage.Heap where Element: ~Copyable {
    public struct Header { ... }
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
| 1 | Extension declaration site | PARTIALLY RESOLVED in 6.2.4 — value-generic types can use extensions; parent context refs still require body |
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

## Strict Memory Safety

### [MEM-SAFE-001] Enable Strict Memory Safety

**Scope**: Memory-critical packages.

**Statement**: Memory-critical packages MUST enable strict memory safety via `.strictMemorySafety()`.

```swift
// Package.swift
.target(
    name: "Buffer Primitives",
    dependencies: [],
    swiftSettings: [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety(),
    ]
)
```

---

### [MEM-SAFE-002] Unsafe Expression Marking

**Scope**: Marking unsafe operations in strict mode.

**Statement**: Each unsafe operation requires its own `unsafe` acknowledgment. Expression granularity.

```swift
// CORRECT
@unsafe
public func allocate(capacity: Int) -> UnsafeMutablePointer<Element> {
    let ptr = unsafe UnsafeMutablePointer<Element>.allocate(capacity: capacity)
    unsafe ptr.initialize(repeating: .init(), count: capacity)
    return ptr
}

// For assignments to unsafe storage, use parentheses
unsafe (self.raw = Unmanaged.passRetained(instance).toOpaque())

// INCORRECT
self.raw = unsafe Unmanaged.passRetained(instance).toOpaque()  // Destination uncovered
```

- `@unsafe` on a function declares that *calling* is unsafe
- Operations *within* still require individual `unsafe` markers
- Parentheses define the expression boundary for assignments

---

### [MEM-SAFE-003] Warning Classification

**Scope**: Handling StrictMemorySafety warnings.

**Statement**: Two buckets:

| Category | Description | Action |
|----------|-------------|--------|
| **Bucket A** | Operations requiring `unsafe` acknowledgment | Mark with `unsafe` |
| **Bucket B** | "Struct has storage involving unsafe types" | Audit marker only — no action needed |

---

### [MEM-SAFE-004] Five Dimensions of Memory Safety

| Dimension | Guarantee | Mechanism |
|-----------|-----------|-----------|
| Lifetime Safety | Values accessed within their lifetime | ARC, `~Copyable`, `@_lifetime` |
| Bounds Safety | Accesses within allocation bounds | Array bounds checking |
| Type Safety | Values accessed using compatible types | Strong typing |
| Initialization Safety | Values initialized before use | Definite initialization |
| Thread Safety | Invariants maintained under concurrency | `Sendable`, actors, Swift 6 |

---

## Unsafe Operation Tracking

### [MEM-UNSAFE-001] Unsafe Operation Tracking

**Statement**: Unsafe operations MUST be tracked and eventually marked with `unsafe`. Warnings serve as a TODO list.

| Warning Type | Response | Timeline |
|--------------|----------|----------|
| Pointer operations | Mark with `unsafe` | Now |
| C interop calls | Mark with `unsafe` | Now |
| Concurrency isolation | Fix immediately | Now |

---

### [MEM-UNSAFE-002] Lifetime Annotations

**Statement**: APIs exposing pointers with limited lifetime MUST use `@_lifetime` annotations.

```swift
// CORRECT
extension Buffer.Aligned {
    @_lifetime(borrow self)
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
        body(UnsafeRawBufferPointer(start: pointer, count: size))
    }
}

// INCORRECT - Pointer can escape scope
func getPointer() -> UnsafeRawPointer {
    return pointer
}
```

---

### [MEM-UNSAFE-003] Safe Attribute

**Statement**: Use `@safe` to assert that a function containing unsafe operations maintains safety through careful design.

```swift
@safe
public final class Box<Value: ~Copyable & Sendable>: @unchecked Sendable {
    // Safe despite @unchecked - immutable value with Sendable constraint
}
```

---

## Safety Techniques

### [MEM-SAFE-010] No Dual Public Overloads

**Statement**: Public APIs MUST NOT provide both safe and unsafe overloads. Unsafe implementation SHOULD be `internal` or `@usableFromInline internal`.

```swift
// CORRECT
public func process(_ data: [UInt8]) -> Result {
    data.withUnsafeBufferPointer { _processUnsafe($0) }
}

@usableFromInline
internal func _processUnsafe(_ buffer: UnsafeBufferPointer<UInt8>) -> Result { ... }

// INCORRECT - Both public
public func process(_ data: [UInt8]) -> Result
public func process(_ buffer: UnsafeBufferPointer<UInt8>) -> Result
```

---

### [MEM-SAFE-011] Inline Clarity Over Helper Consolidation

**Statement**: Unsafe operations SHOULD be inline and explicit, not hidden behind convenience helpers.

```swift
// CORRECT - Danger visible
let result = pointer.withMemoryRebound(to: UInt32.self, capacity: count) { typed in
    typed.baseAddress!.pointee
}

// INCORRECT - Danger hidden
func readUInt32(from pointer: UnsafeRawPointer) -> UInt32 {
    pointer.assumingMemoryBound(to: UInt32.self).pointee
}
```

---

### [MEM-SAFE-012] Span as Normative Interface

**Statement**: APIs providing contiguous memory access SHOULD use `Span` as primary interface. Unsafe pointer access is an escape hatch, not primary API.

```swift
// CORRECT
public struct Buffer {
    public var span: Span<UInt8> { ... }
    // Escape hatch for interop
    public func withUnsafeBufferPointer<R>(...) rethrows -> R
}

// INCORRECT - Pointer-first
public struct Buffer {
    public var baseAddress: UnsafePointer<UInt8>? { ... }
}
```

---

### [MEM-SAFE-013] API Surface Reduction as Safety

**Statement**: Removing public unsafe overloads in favor of scoped accessors reduces API surface without reducing capability.

---

### [MEM-SAFE-014] Closure Scope Over Property Access

**Statement**: Unsafe operations MUST use closure-scoped access (`withUnsafe*`) rather than property access. Properties make unsafe operations look safe.

```swift
// CORRECT - Closure enforces lifetime
path.withUnsafeCString { ptr in
    usePointer(ptr)
}

// INCORRECT - Property makes danger invisible
public var unsafeCString: UnsafePointer<CChar> {
    _storage.baseAddress  // Can escape and dangle
}
```

---

## Concurrency Safety (Sendable)

### [MEM-SEND-001] Conservative Sendable Defaults

**Statement**: Mutable reference wrappers MUST NOT be unconditionally `@unchecked Sendable` unless they provide synchronization.

```swift
// CORRECT
extension Reference.Indirect: @unchecked Sendable where Value: Sendable {}

// Explicit unsafe escape
extension Reference.Indirect {
    public struct Unchecked: @unchecked Sendable {
        public let indirect: Reference.Indirect<Value>
    }
}

// INCORRECT
extension Reference.Indirect: @unchecked Sendable {}  // Hidden footgun
```

---

### [MEM-SEND-002] Sendability Tiers

| Tier | When | Example |
|------|------|---------|
| Checked Sendable | Immutable, all fields Sendable | `struct Point: Sendable` |
| Conditional Sendable | Sendable when generic param is | `extension Box: Sendable where T: Sendable` |
| Unchecked Sendable | Synchronized by construction | `Slot`, `Transfer` (atomic state) |
| Not Sendable | Mutable without synchronization | `Indirect` base type |
| Explicit Escape | Caller asserts safety | `Indirect.Unchecked` |

---

### [MEM-SEND-003] Accurate Risk Description

**Statement**: When justifying unsafe escapes, describe the risk accurately — not euphemistically.

| Euphemistic | Accurate |
|-------------|----------|
| "This is about transferability" | "The compiler will not warn when this creates races" |
| "`@unchecked Sendable` means transferable" | "Removing the compiler's data-race prevention" |

---

## Reference Primitives

### [MEM-REF-001] Reference Primitive Selection

| Type | Ownership | Mutability | Sendable |
|------|-----------|------------|----------|
| `Reference.Box` | Strong | Immutable | When `Value: Sendable` |
| `Reference.Indirect` | Strong | Mutable | Not Sendable (use `.Unchecked`) |
| `Reference.Weak` | Weak | N/A | When `Object: Sendable` |
| `Reference.Unowned` | Unowned | N/A | Not Sendable |
| `Reference.Slot` | Strong | Move semantics | `@unchecked` (atomic) |
| `Reference.Transfer` | One-shot | Move-only | Tokens are Sendable |
| `Reference.Sendability.Unchecked` | N/A | Immutable | `@unchecked` (assertion) |

---

### [MEM-REF-002] Reference.Box

**Statement**: Use `Reference.Box` for immutable heap allocation of `~Copyable` values.

```swift
@safe
public final class Box<Value: ~Copyable & Sendable>: @unchecked Sendable {
    public let value: Value
    @inlinable public init(_ value: consuming Value) { self.value = value }
}
```

Use cases: heap allocation for stable identity, type erasure, breaking recursive types.

---

### [MEM-REF-003] Reference.Indirect

**Statement**: Use `Reference.Indirect` for mutable heap-allocated values. NOT Sendable by design.

```swift
@safe
public final class Indirect<Value: ~Copyable> {
    public var value: Value { _read { yield _value } _modify { yield &_value } }
    public func withValue<Result>(_ body: (borrowing Value) throws -> Result) rethrows -> Result
    public func update<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result
}
```

Use `.Unchecked` for explicit cross-isolation transfer.

---

### [MEM-REF-004] Reference.Transfer

**Statement**: Use `Reference.Transfer` for moving `~Copyable` values across `@Sendable` boundaries with exactly-once semantics.

| Type | Use Case | Allocation |
|------|----------|------------|
| `Cell<T>` | Pass existing value through escaping boundary | One (box) |
| `Storage<T>` | Create inside closure, retrieve after | One (box) |
| `Retained<T>` | Zero-allocation class transfer | Zero |

All invariant violations trap deterministically (not undefined behavior).

---

### [MEM-REF-005] Reference.Slot

**Statement**: Use `Reference.Slot` for atomic, reusable store/take operations on `~Copyable` values.

Key difference from Transfer: Transfer is one-shot; Slot is reusable (empty ↔ filled, cycles indefinitely). All operations atomic via release/acquire barriers.

---

## Lifetime Primitives

### [MEM-LIFE-001] Lifetime.Scoped

**Statement**: Use `Lifetime.Scoped` for RAII-style deterministic cleanup when scope exits.

```swift
let file = Lifetime.Scoped(FileHandle(path: "/tmp/x")) { $0.close() }
// use file.value...
// close() called automatically at scope exit
```

---

### [MEM-LIFE-002] Lifetime.Lease

**Statement**: Use `Lifetime.Lease` for temporary access with guaranteed return.

```swift
var lease = borrow(myResource)
// use lease.value...
let returned = lease.release()  // Must call to get value back
```

---

### [MEM-LIFE-003] Lifetime.Disposable

**Statement**: Conform to `Lifetime.Disposable` for types requiring explicit cleanup. Implementations MUST be idempotent.

---

## Post-Implementation Checklist

Before presenting code as complete, verify EACH item:

- [ ] All `~Copyable` constraints are at extension level, not method level [MEM-COPY-004]
- [ ] Ownership annotations (`consuming`, `borrowing`, `inout`) are correct for each parameter [MEM-OWN-001]
- [ ] `deinit` bodies explicitly clean up all ~Copyable stored properties [MEM-LINEAR-001]
- [ ] No implicit `Copyable` constraints leak through unconstrained generic extensions [MEM-COPY-006]
- [ ] Strict memory safety enabled for memory-critical packages [MEM-SAFE-001]
- [ ] Each unsafe operation has its own `unsafe` acknowledgment [MEM-SAFE-002]
- [ ] Sendable conformances use the correct tier (checked > conditional > unchecked) [MEM-SEND-002]

If ANY item fails, fix before presenting.

---

## Cross-References

See also:
- **implementation** skill for [IMPL-*] expression style, Property.View patterns
- **copyable-remediation** skill for auditing and fixing ~Copyable constraint issues
- **advanced-patterns** skill for memory ownership in collections, unsafe API design
