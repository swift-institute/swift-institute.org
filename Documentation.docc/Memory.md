# Memory and Ownership

@Metadata {
    @TitleHeading("Swift Institute")
}

Modern Swift memory ownership semantics: `~Copyable` types, borrowing, consuming, strict memory safety, and ownership transfer patterns.

## Overview

This document defines memory ownership patterns for the Swift Institute ecosystem. It consolidates guidance from Swift language features (SE-0390 through SE-0458), implementation patterns from swift-primitives, and Swift Institute requirements.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## Quick Reference

| Concept | Swift Feature | Use Case |
|---------|---------------|----------|
| Move-only types | `~Copyable` | Resources with single ownership |
| Consuming parameters | `consuming` | Ownership transfer to callee |
| Borrowing parameters | `borrowing` | Read-only access without ownership |
| Strict memory safety | `.strictMemorySafety()` | Compile-time unsafe operation tracking |
| Exactly-once semantics | `~Copyable` + `deinit` | Continuations, tokens, capabilities |

---

## Document Structure

| Section | Focus |
|---------|-------|
| [Noncopyable Types](#noncopyable-types) | `~Copyable` fundamentals |
| [Ownership Keywords](#ownership-keywords) | `consuming`, `borrowing`, ownership transfer |
| [Linear and Affine Types](#linear-and-affine-types) | Exactly-once and at-most-once patterns |
| [Strict Memory Safety](#strict-memory-safety) | SE-0458 and StrictMemorySafety mode |
| [Reference Primitives](#reference-primitives) | Swift Institute ownership types |
| [Lifetime Primitives](#lifetime-primitives) | RAII and scoped cleanup patterns |
| [Sendable and Concurrency](#sendable-and-concurrency) | Thread-safety and isolation |
| [Unsafe Operations](#unsafe-operations) | Marking and auditing unsafe code |

---

## Noncopyable Types

**Applies to**: Types representing resources with exclusive ownership.

### Noncopyable Type Declaration

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

---

### Noncopyable in Error Types

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

---

### Noncopyable in Collections

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

---

## Ownership Keywords

**Applies to**: Function parameters and ownership transfer.

### Consuming Parameters

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

### Borrowing Parameters

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

### Ownership in Function Signatures

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

## Linear and Affine Types

**Applies to**: Types encoding exactly-once or at-most-once semantics.

### Exactly-Once Types

**Scope**: Values that must be used exactly once.

**Statement**: When an invariant requires that a value be used exactly once (linear type), the type MUST be `~Copyable` with a `consuming func` for the use operation and a `deinit` that traps if the value was not consumed.

**Correct**:
```swift
/// A continuation that must be resumed exactly once.
public struct Continuation<T>: ~Copyable, Sendable {
    private let resume: @Sendable (T) -> Void

    public init(_ resume: @escaping @Sendable (T) -> Void) {
        self.resume = resume
    }

    /// Consumes the continuation, resuming it with a value.
    public consuming func callAsFunction(_ value: T) {
        resume(value)
    }

    deinit {
        // If deinit runs, the continuation was never resumed
        preconditionFailure("Continuation was dropped without being resumed")
    }
}

// Compiler enforces exactly-once:
func example(_ cont: consuming Continuation<Int>) {
    cont(42)        // ✓ Consumes the continuation
    // cont(43)     // ❌ Compile error: 'cont' used after consume
}
```

**Incorrect**:
```swift
// ❌ Comment-based invariant - not enforced
/// Must be called exactly once!
class Continuation<T> {
    private var resumed = false

    func resume(_ value: T) {
        precondition(!resumed, "Already resumed")  // Runtime check only
        resumed = true
    }
    // Nothing prevents forgetting to resume
}
```

**Rationale**: The compiler becomes a proof assistant for exactly-once usage, eliminating double-resume and forgotten-resume bugs.

---

### At-Most-Once Types

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

---

### Proof Categories

**Scope**: Using the ownership system as a proof assistant.

**Statement**: The Swift ownership system functions as a compile-time proof assistant. Recognize and apply these patterns systematically.

| Invariant | Ownership Encoding | Compiler Enforcement |
|-----------|-------------------|---------------------|
| Exactly-once use | `~Copyable` + `consuming func` + `deinit` trap | Double-use at compile time; dropped-without-use at runtime |
| At-most-once use | `~Copyable` + `consuming func` + silent `deinit` | Double-use at compile time; unused is valid |
| Transfer semantics | `consuming` parameter | Caller cannot use value after transfer |
| Borrow semantics | `borrowing` parameter | Callee cannot consume or store |

**Rationale**: Recognizing `~Copyable` as a proof assistant rather than just memory optimization changes API design approach. Any invariant expressible as "exactly N times" or "at most N times" should trigger consideration of ownership-based enforcement.

---

## Strict Memory Safety

**Applies to**: SE-0458 Strict Memory Safety checking.

### Enable Strict Memory Safety

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

---

### Unsafe Expression Marking

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

---

### Warning Classification

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

---

### Five Dimensions of Memory Safety

**Scope**: Understanding memory safety guarantees.

**Statement**: Memory safety has five dimensions. Swift provides guarantees across all five.

| Dimension | Guarantee | Mechanism |
|-----------|-----------|-----------|
| **Lifetime Safety** | Values accessed within their lifetime | ARC, `~Copyable`, `@_lifetime` |
| **Bounds Safety** | Accesses within allocation bounds | Array bounds checking |
| **Type Safety** | Values accessed using compatible types | Strong typing |
| **Initialization Safety** | Values initialized before use | Definite initialization |
| **Thread Safety** | Invariants maintained under concurrency | `Sendable`, actors, Swift 6 |

---

## Reference Primitives

**Applies to**: Types in `swift-reference-primitives`.

### Reference Primitive Selection

**Scope**: Choosing the correct reference primitive.

**Statement**: Choose reference primitives by their ownership/mutability/Sendable contract.

| Type | Ownership | Mutability | Sendable |
|------|-----------|------------|----------|
| `Reference.Box` | Strong | Immutable | When `Value: Sendable` |
| `Reference.Indirect` | Strong | Mutable | Not Sendable (use `.Unchecked`) |
| `Reference.Weak` | Weak | N/A | When `Object: Sendable` |
| `Reference.Unowned` | Unowned | N/A | Not Sendable (use `.Sendable.*`) |
| `Reference.Slot` | Strong | Move semantics | `@unchecked` (atomic sync) |
| `Reference.Transfer` | One-shot | Move-only | Tokens are Sendable |
| `Reference.Sendability.Unchecked` | N/A | Immutable | `@unchecked` (assertion) |

**Use Cases**:
- Need immutable heap storage? → `Box`
- Need mutable shared state? → `Indirect`
- Need weak back-references? → `Weak`
- Need atomic move semantics? → `Slot`
- Need cross-boundary ownership transfer? → `Transfer`
- Need unchecked sendability assertion? → `Sendability.Unchecked`

---

### Reference.Box

**Scope**: Immutable heap-allocated values.

**Statement**: Use `Reference.Box` for immutable heap allocation of `~Copyable` values.

```swift
@safe
public final class Box<Value: ~Copyable & Sendable>: @unchecked Sendable {
    public let value: Value

    @inlinable
    public init(_ value: consuming Value) {
        self.value = value
    }
}
```

**Use Cases**:
- Heap allocation for values needing stable identity
- Type erasure via `Unmanaged` + `UnsafeRawPointer`
- Breaking recursive type definitions
- Storage for `~Copyable` types requiring heap allocation

---

### Reference.Indirect

**Scope**: Mutable shared state with reference semantics.

**Statement**: Use `Reference.Indirect` for mutable heap-allocated values. It is NOT Sendable by design.

```swift
@safe
public final class Indirect<Value: ~Copyable> {
    @usableFromInline
    var _value: Value

    public var value: Value {
        _read { yield _value }
        _modify { yield &_value }
    }

    public func withValue<Result>(
        _ body: (borrowing Value) throws -> Result
    ) rethrows -> Result {
        try body(_value)
    }

    public func update<Result>(
        _ body: (inout Value) throws -> Result
    ) rethrows -> Result {
        try body(&_value)
    }
}

// For cross-isolation transfer, use explicit opt-in:
extension Reference.Indirect where Value: ~Copyable {
    public struct Unchecked: @unchecked Sendable {
        public let indirect: Reference.Indirect<Value>
    }
}
```

**Use Cases**:
- Breaking infinite-size cycles in recursive definitions
- Shared mutable state with identity
- Heap allocation for values needing stable identity

**Thread Safety**: Provides no synchronization. Wrap synchronized types if needed.

---

### Reference.Transfer

**Scope**: Cross-boundary ownership transfer.

**Statement**: Use `Reference.Transfer` types for moving `~Copyable` values across `@Sendable` boundaries with exactly-once semantics.

**Transfer Variants**:

| Type | Use Case | Allocation |
|------|----------|------------|
| `Cell<T>` | Pass existing value through escaping boundary | One (box) |
| `Storage<T>` | Create inside closure, retrieve after | One (box) |
| `Retained<T>` | Zero-allocation class transfer | Zero |

**Cell Pattern** (pass existing value):
```swift
let cell = Reference.Transfer.Cell(myValue)
let token = cell.token()
spawnThread {
    let value = token.take()  // Exactly once, enforced atomically
}
```

**Storage Pattern** (create inside, retrieve after):
```swift
let storage = Reference.Transfer.Storage<MyType>()
let storeToken = storage.token
spawnThread {
    storeToken.store(createValue())  // Producer
}
let value = storage.take()  // Consumer
```

**Retained Pattern** (zero-allocation class transfer):
```swift
let retained = Reference.Transfer.Retained(myObject)
spawnThread {
    let obj = retained.take()
}
```

**Safety Guarantees**:
- Tokens are Copyable (required for escaping closure capture)
- All invariant violations trap deterministically (not undefined behavior)
- ARC-managed storage with atomic one-shot enforcement

---

### Reference.Slot

**Scope**: Reusable heap slot with move semantics.

**Statement**: Use `Reference.Slot` for atomic, reusable store/take operations on `~Copyable` values.

```swift
@safe
public final class Slot<Value: ~Copyable & Sendable>: @unchecked Sendable {
    // State machine: empty ↔ initializing ↔ full
    private let _state: Atomic<UInt8>
    let _storage: UnsafeMutablePointer<Value>

    public func store(_ value: consuming Value) -> Store {
        // Atomic CAS empty → initializing → full
    }

    public func take() -> Value? {
        // Atomic CAS full → empty
    }
}

public enum Store: ~Copyable {
    case stored
    case occupied(Value)  // Returns value on failure
}
```

**Key Difference from Transfer**:
- `Transfer`: One-shot (empty → filled → taken, then done)
- `Slot`: Reusable (empty ↔ filled, can cycle indefinitely)

**Thread Safety**: All operations are atomic via release/acquire barriers.

---

## Lifetime Primitives

**Applies to**: Types in `swift-lifetime-primitives`.

### Lifetime.Scoped

**Scope**: RAII-style deterministic cleanup.

**Statement**: Use `Lifetime.Scoped` for values requiring cleanup when scope exits.

```swift
public struct Scoped<Value>: ~Copyable {
    public let value: Value

    @usableFromInline
    internal let _cleanup: (Value) -> Void

    public init(_ value: Value, cleanup: @escaping (Value) -> Void) {
        self.value = value
        self._cleanup = cleanup
    }

    deinit {
        _cleanup(value)
    }
}

// For Disposable types:
extension Lifetime.Scoped where Value: Lifetime.Disposable {
    public init(_ value: Value) {
        self.init(value) { $0.dispose() }
    }
}
```

**Usage**:
```swift
func process() {
    let file = Lifetime.Scoped(FileHandle(path: "/tmp/x")) { handle in
        handle.close()
    }
    // use file.value...
}  // close() called here automatically
```

---

### Lifetime.Lease

**Scope**: Borrowed values that must be returned.

**Statement**: Use `Lifetime.Lease` for temporary access to a value with guaranteed return.

```swift
@safe
public struct Lease<Value: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _storage: UnsafeMutablePointer<Value>

    @usableFromInline
    internal var _released: Bool

    public var value: Value {
        _read {
            precondition(!_released, "Lease already released")
            yield unsafe _storage.pointee
        }
    }

    public init(_ value: consuming Value) {
        unsafe self._storage = .allocate(capacity: 1)
        unsafe _storage.initialize(to: value)
        self._released = false
    }

    public mutating func release() -> Value {
        precondition(!_released, "Lease already released")
        _released = true
        return unsafe _storage.move()
    }

    deinit {
        if !_released {
            unsafe _storage.deinitialize(count: 1)
        }
        unsafe _storage.deallocate()
    }
}
```

**Usage**:
```swift
func borrow(_ resource: consuming Resource) -> Lifetime.Lease<Resource> {
    Lifetime.Lease(resource)
}

var lease = borrow(myResource)
// use lease.value...
let returned = lease.release()  // Must call to get value back
```

---

### Lifetime.Disposable

**Scope**: Types requiring explicit cleanup.

**Statement**: Conform to `Lifetime.Disposable` when a type holds resources requiring deterministic release.

```swift
public protocol Disposable {
    /// Releases resources held by this instance.
    /// Implementations MUST be idempotent.
    func dispose()
}
```

**Usage**:
```swift
struct FileHandle: Lifetime.Disposable {
    func dispose() {
        close(fd)
    }
}
```

---

## Sendable and Concurrency

**Applies to**: Types crossing concurrency boundaries.

### Conservative Sendable Defaults

**Scope**: Mutable reference wrappers.

**Statement**: General-purpose mutable reference wrappers MUST NOT be unconditionally `@unchecked Sendable` unless they provide synchronization. The default MUST be conservative.

**Correct**:
```swift
// Conservative default: Sendable only when Value is Sendable
extension Reference.Indirect: @unchecked Sendable where Value: Sendable {}

// Explicit unsafe escape: unconditionally Sendable wrapper
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

**The Pit of Success Principle**:

| Path | Experience |
|------|------------|
| Default (safe) | `Reference.Indirect<T>` - no ceremony |
| Unsafe escape | `Reference.Indirect<T>.Unchecked` - name declares intent |

---

### Sendability Tiers

**Scope**: Understanding Sendable conformance levels.

**Statement**: Apply the appropriate Sendability tier based on type characteristics.

| Tier | When | Example |
|------|------|---------|
| Checked Sendable | Immutable, all fields Sendable | `struct Point: Sendable` |
| Conditional Sendable | Sendable when generic param is | `extension Box: Sendable where T: Sendable` |
| Unchecked Sendable | Synchronized by construction | `Slot`, `Transfer` (atomic state) |
| Not Sendable | Mutable without synchronization | `Indirect` base type |
| Explicit Escape | Caller asserts safety | `Indirect.Unchecked`, `Sendability.Unchecked` |

---

### Accurate Risk Description

**Scope**: Justifying unsafe Sendable escapes.

**Statement**: When justifying unsafe escapes, describe the risk accurately—not euphemistically.

| Euphemistic | Accurate |
|-------------|----------|
| "This is about transferability, not thread-safety" | "The compiler will not warn when this creates races" |
| "`@unchecked Sendable` means the value can cross domains" | "Removing the compiler's data-race prevention" |
| "We're asserting transferability" | "We're disabling the Sendable check" |

---

## Unsafe Operations

**Applies to**: Working with unsafe Swift APIs.

### Unsafe Operation Tracking

**Scope**: Tracking unsafe operations for future annotation.

**Statement**: Unsafe operations MUST be tracked and eventually marked with `unsafe`. Warnings serve as a TODO list.

**Correct Response**:
```swift
// Track warnings as technical debt
unsafe {
    let ptr = UnsafeMutablePointer<kevent>.allocate(capacity: 64)
    // ...
}
```

**Treatment of Warnings**:

| Warning Type | Response | Timeline |
|--------------|----------|----------|
| Pointer operations | Mark with `unsafe` | Now |
| C interop calls | Mark with `unsafe` | Now |
| Concurrency isolation | Fix immediately | Now |

---

### Lifetime Annotations

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

// Usage - pointer confined to closure
buffer.withUnsafeBytes { ptr in
    process(ptr)  // Valid
}
// ptr is not accessible here - enforced by compiler
```

**Incorrect**:
```swift
// ❌ Pointer can escape scope
func getPointer() -> UnsafeRawPointer {
    return pointer  // Escapes - lifetime not enforced
}
```

---

### Safe Attribute

**Scope**: Asserting function safety despite unsafe operations.

**Statement**: Use `@safe` to assert that a function containing unsafe operations maintains safety guarantees through careful design.

```swift
@safe
public final class Box<Value: ~Copyable & Sendable>: @unchecked Sendable {
    // Safe despite @unchecked - immutable value with Sendable constraint
}

@safe
public struct Retained<T: AnyObject>: ~Copyable, @unchecked Sendable {
    @usableFromInline
    let raw: UnsafeMutableRawPointer

    @unsafe  // Init is unsafe - caller must ensure safety
    public init(_ instance: T) {
        unsafe (self.raw = Unmanaged.passRetained(instance).toOpaque())
    }
}
```

---

## Summary Tables

### Memory Safety Mechanisms

| Mechanism | Prevents | Enforcement |
|-----------|----------|-------------|
| Strict Memory Safety | Unsafe operations | Package manifest |
| Noncopyable Types | Double-free, shared mutation | Type system |
| Lifetime Annotations | Use-after-free, escaping pointers | Compiler |

### Ownership Keywords

| Keyword | Ownership | After Call | Callee Can |
|---------|-----------|------------|------------|
| `consuming` | Transferred | Cannot use | Store, consume |
| `borrowing` | Retained | Can use | Read only |
| `inout` | Loaned | Can use | Mutate |

### Exactly-Once Patterns

| Semantics | `~Copyable` | `consuming func` | `deinit` |
|-----------|-------------|------------------|----------|
| Exactly-once | Yes | Yes | Trap |
| At-most-once | Yes | Yes | Silent |

---

## Topics

### Related Documents

- <doc:API-Errors>
- <doc:Implementation-Patterns>
- <doc:Systems-Programming>
- <doc:Primitives-Architecture>

### Swift Evolution

- SE-0390: Noncopyable structs and enums
- SE-0427: Noncopyable generics
- SE-0437: Borrowing and consuming ownership modifiers
- SE-0458: Opt-in Strict Memory Safety Checking

### Package Documentation

- `swift-reference-primitives`: Ownership and reference semantics
- `swift-lifetime-primitives`: RAII and scoped cleanup
