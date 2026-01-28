---
name: errors
description: |
  Error handling patterns: typed throws, structured errors, move-only boundaries.
  ALWAYS apply when defining error types or throwing functions
  in swift-primitives, swift-standards, or swift-foundations.

layer: implementation

requires:
  - naming

applies_to:
  - swift
  - swift-primitives
  - swift-standards
  - swift-foundations

migrated_from: Implementation/Errors.md
migration_date: 2026-01-28
---

# API Errors

Error handling requirements for Swift Institute packages.

**Applies to**: All error types and throwing functions.

**Does not apply to**: Debug-only assertions in test code.

---

## Typed Throws

### [API-ERR-001] Typed Throws Everywhere

**Scope**: All throwing functions.

**Statement**: MUST use typed throws throughout. Errors MUST be domain-scoped and structured.

- **Leaf error**: e.g., `IO.NonBlocking.Error`
- **Lifecycle wrapper**: `IO.Lifecycle.Error<Leaf>`

Rules:
- Drivers and backends throw leaf errors only
- Runtime layers wrap leaf errors into lifecycle errors at the boundary where lifecycle semantics exist

**Correct**:
```swift
func read() throws(IO.NonBlocking.Error) -> Data
func submit() throws(IO.Lifecycle.Error<IO.NonBlocking.Error>)
```

**Incorrect**:
```swift
func read() throws -> Data  // Untyped throws
func submit() throws(any Error)  // Existential error
```

**Rationale**: Typed throws enable exhaustive error handling and prevent error type erasure.

---

### [API-ERR-002] Lifecycle Precedence Rules

**Scope**: Operations with multiple lifecycle conditions.

**Statement**: When multiple lifecycle conditions apply, precedence MUST be enforced:

1. **Shutdown dominates all outcomes** - If shutdown is in progress, operations MUST fail with `.shutdownInProgress` regardless of cancellation or state
2. **Cancellation dominates success** - A cancelled operation MUST NOT surface a success value
3. **Operational failures are lowest precedence** - Leaf or handle errors MUST NOT mask shutdown or cancellation

Precedence MUST be enforced at the final resumption boundary.

---

### [API-ERR-003] Typed Continuation Pattern

**Scope**: Async boundaries where Swift lacks typed throwing continuations.

**Statement**: When Swift does not support typed throwing continuations, implementations SHOULD use non-throwing continuations carrying `Result<Success, Failure>`. The async boundary MUST unwrap the Result and throw the typed error.

**Correct**:
```swift
func operation() async throws(MyError) -> Value {
    await withCheckedContinuation { continuation in
        performAsync { result: Result<Value, MyError> in
            continuation.resume(returning: result)
        }
    }.get()  // Unwrap and throw typed error
}
```

**Incorrect**:
```swift
// Using existential error continuation
await withCheckedThrowingContinuation { continuation in
    // Error type is erased to `any Error`
}
```

This pattern is preferred over:
- `CheckedThrowingContinuation<any Error>`
- Existential error funnels
- Runtime casts

---

### [API-ERR-003a] Typed Do Blocks Over Result Initializers

**Scope**: Capturing typed throws in local scope without erasure.

**Statement**: When capturing the result of a throwing operation, use `do throws(E) { } catch { }` instead of `Result { try ... }`. The `Result` initializer erases typed throws to `any Error`.

**Correct**:
```swift
do throws(IO.Event.Error) {
    let id = try driver.register(handle, descriptor: descriptor, interest: interest)
    replyBridge.push(.success(.registered(id)))
} catch {
    replyBridge.push(.failure(error))  // error is IO.Event.Error, not any Error
}
```

**Incorrect**:
```swift
// Error type erased
let result = Result { try throwingOperation() }
// result is Result<T, any Error>, not Result<T, SomeError>
```

| Pattern | Use When |
|---------|----------|
| `do throws(E) { } catch { }` | Need to preserve typed error, handle locally |
| `Result { }` | Error type preservation not required |
| Direct `try` | Propagating to caller |

---

### [API-ERR-007] Typed Throws Closure Annotation

**Scope**: Closures passed to methods that preserve typed errors.

**Statement**: When passing a closure to a typed-throws-preserving extension, the closure MUST be explicitly annotated with `throws(E) -> T` to enable proper type inference.

**Correct**:
```swift
// Explicit throws(E) annotation on closure
try unsafe bytes.withUnsafeBufferPointer(body: { buffer throws(E) -> T in
    var input = Binary.Bytes.Input(borrowing: buffer)
    return try body(&input)
})
```

**Incorrect**:
```swift
// Missing throws(E) annotation - compiler cannot infer E
try unsafe bytes.withUnsafeBufferPointer(body: { buffer in
    var input = Binary.Bytes.Input(borrowing: buffer)
    return try body(&input)  // Error: cannot convert to error type 'E'
})
```

Explicit annotation is REQUIRED when:
1. The closure calls another `throws(E)` function
2. The error type `E` is a generic parameter
3. The closure is passed to an extension that preserves typed errors

### Creating Typed-Throws Extensions

When extending stdlib methods to preserve typed errors, use `@_disfavoredOverload` and a distinguishing parameter label:

```swift
extension Array {
    @inlinable
    @_disfavoredOverload
    public func withUnsafeBufferPointer<T, E: Error>(
        body: (UnsafeBufferPointer<Element>) throws(E) -> T  // Note: 'body:' label
    ) throws(E) -> T {
        let result: Result<T, E> = unsafe self.withUnsafeBufferPointer { buffer in
            do throws(E) {
                return .success(try unsafe body(buffer))
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }
}
```

---

## Error Types

### [API-ERR-004] No Stringly-Typed Errors

**Scope**: All error types.

**Statement**: Errors MUST carry structured data (errno, platform code, operation, context). Strings MAY exist for debugging only, never as the primary signal.

**Correct**:
```swift
enum IO {}
extension IO {
    enum Error: Swift.Error {
        case posix(errno: CInt, operation: Operation, path: FilePath)
        case timeout(duration: Duration, operation: Operation)
    }
}
```

**Incorrect**:
```swift
// String-based error
struct IOError: Error {
    let message: String
}
```

**Rationale**: Structured errors enable programmatic handling and pattern matching.

---

### [API-ERR-009] Swift.Error Qualification in Nested Contexts

**Scope**: Generic error constraints inside type extensions with nested Error types.

**Statement**: When writing generic code inside an extension of a type that has a nested `Error` type, the constraint `E: Error` MUST be qualified as `E: Swift.Error` to avoid ambiguity.

**Incorrect**:
```swift
extension RFC_4122.UUID {
    // E: Error resolves to RFC_4122.UUID.Error, not Swift.Error
    public static func v4<E: Error>(
        fillRandom: (UnsafeMutableRawBufferPointer) throws(E) -> Void
    ) throws(E) -> Self
    // Error: type 'E' constrained to non-protocol, non-class type
}
```

**Correct**:
```swift
extension RFC_4122.UUID {
    // Explicitly qualify with Swift.Error
    public static func v4<E: Swift.Error>(
        fillRandom: (UnsafeMutableRawBufferPointer) throws(E) -> Void
    ) throws(E) -> Self
}
```

Qualification is REQUIRED when ALL of these conditions hold:
1. You are inside an extension of a type
2. That type has a nested `Error` enum/struct
3. You are writing a generic constraint on `Error`

---

## Move-Only Boundaries

### [API-ERR-005] Move-Only Values and Error Boundaries

**Scope**: APIs involving `~Copyable` types.

**Statement**: `Swift.Error` requires `Copyable`. Move-only (`~Copyable`) values MUST NOT be embedded in types conforming to `Error`.

Therefore:
- Typed throws MUST NOT be used for APIs that must preserve move-only state (tokens, capabilities, typestate values) across failure
- In such cases, APIs MUST instead return a non-throwing outcome type that:
  - Is `~Copyable`
  - Explicitly returns ownership on all paths
  - Makes state loss unrepresentable

This rule is non-negotiable.

See also: **memory** skill

---

### [API-ERR-006] Token-Preserving Operation Pattern

**Scope**: Operations that consume a move-only token and may fail.

**Statement**: Operations that consume a move-only token and may fail before a replacement token is produced MUST follow this pattern:

- Expose a non-throwing, token-preserving API returning an `Outcome` enum:
  - Success case carries the new token (or result containing it)
  - Failure case returns the original token plus a typed failure
- A separate ergonomic throwing API MAY exist, implemented in terms of the preserving one, and MUST be used only when token loss is acceptable

**Correct**:
```swift
enum Registration {}
extension Registration {
    enum Outcome {
        case success(Token.Registered)
        case failure(Token.Unregistered, Registration.Error)
    }
}

enum Token {}
extension Token {
    struct Registered { /* ... */ }
    struct Unregistered { /* ... */ }
}

func register(_ token: consuming Token.Unregistered) -> Registration.Outcome
```

**Incorrect**:
```swift
// Token lost on failure
func register(_ token: consuming Token.Unregistered) throws -> Token.Registered
```

This pattern is REQUIRED at:
- Registration / arming boundaries
- Scheduling funnels
- Selector, executor, and runtime submission points

Token fabrication is forbidden.

---

## Language Semantics

### [API-ERR-008] Language Semantics Over Naming Conventions

**Scope**: All API naming.

**Statement**: Behavior MUST be expressed via Swift's type system and language keywords, NEVER through naming conventions.

- MUST NOT encode fallibility in names (`tryFoo`, `getFoo`, `init(validating:)`)
- MUST NOT encode asynchrony in names (`asyncFoo`, `fooAsync`)
- MUST NOT encode optionality in names (`maybeFoo`, `fooOrNil`)
- MUST NOT encode unchecked/unsafe in names (`unsafeFoo`, `forceFoo`, `uncheckedFoo`)
- MUST use language constructs: `throws(Error)`, `async`, `-> T?`, `!`, `@unsafe`, `__unchecked` marker

**Correct**:
```swift
// Fallibility via throws
init() throws(Validation.Error)
func start() throws(Transition.Error)
func value() throws(Access.Error) -> T

// Optionality via return type
func first() -> Element?

// Asynchrony via async
func fetch() async throws(Network.Error) -> Response

// Unchecked via marker parameter
init(__unchecked: Void, _ index: Int)

// Unsafe via @unsafe attribute and unsafe keyword (Swift 6.2+)
@unsafe func withRawPointer<T>(_ body: (UnsafeRawPointer) -> T) -> T
```

**Incorrect**:
```swift
// Fallibility encoded in name
func tryStart() -> Bool
func getValue() throws -> T          // "get" implies throwing
init(validating input: String)       // "validating" implies throwing
init(parsing data: Data)             // "parsing" implies throwing

// Optionality encoded in name
func maybeFirst() -> Element?
func firstOrNil() -> Element?

// Asynchrony encoded in name
func fetchAsync() async -> Response
func asyncFetch() async -> Response

// Unchecked/unsafe encoded in name instead of @unsafe
func unsafeValue() -> T              // Use @unsafe + unsafe { }
func forceUnwrap() -> T              // Use !
init(unchecked index: Int)           // Label instead of __unchecked marker
```

**Rationale**:
- Swift's type system already expresses these semantics precisely
- Naming conventions fragment into dialects (`try`, `get`, `maybe`, `orNil`, etc.)
- Language constructs are enforced by the compiler; names are not
- Call sites read naturally: `try foo()` not `tryFoo()`

---

### [API-ERR-010] Throws Over Preconditions for Partial Operations

**Scope**: Operations that are mathematically partial (can fail for some inputs).

**Statement**: When an operation is mathematically partial—it cannot succeed for all inputs—the function signature MUST reflect this via `throws`, not hide it via `precondition`.

**Incorrect**:
```swift
// Hiding partiality behind a trap
func advanced(by position: UInt) -> Address {
    guard let offset = try? Offset(position) else {
        preconditionFailure("Position exceeds representable offset")
    }
    return self + offset
}
```

**Correct**:
```swift
// Partiality visible in signature
func advanced(by position: UInt) throws(Offset.Error) -> Address {
    self + try Offset(position)
}
```

The signature now honestly advertises: "this operation can fail." Callers decide how to handle failure—they might `try!` if they can prove the input is valid, or propagate the error, or provide a fallback.

**Rationale**: Mathematical partiality is a property of the operation, not an implementation detail. Traps are appropriate for programmer errors (invariant violations); throws are appropriate for domain-level partiality.
