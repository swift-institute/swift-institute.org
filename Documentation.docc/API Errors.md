# API Errors

@Metadata {
    @TitleHeading("Swift Institute")
}

Error handling patterns and requirements for typed throws, error types, and move-only boundaries.

## Overview

This document defines the error handling requirements for Swift Institute packages. These patterns ensure consistent, type-safe error handling that preserves information across abstraction boundaries.

**Applies to**: All error types and throwing functions.

**Does not apply to**: Debug-only assertions in test code.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## Document Structure

| Section | Requirements | Focus |
|---------|--------------|-------|
| [Typed Throws](#typed-throws) | 4 | Type-safe error propagation |
| [Error Types](#error-types) | 2 | Structured errors, no stringly-typed |
| [Move-Only Boundaries](#move-only-boundaries) | 2 | Token preservation across failures |
| [Language Semantics](#language-semantics) | 2 | Using Swift's type system over naming |

---

## Typed Throws

**Applies to**: All throwing functions and async boundaries.

---

### Typed Throws Everywhere

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
func read() throws -> Data  // ❌ Untyped throws
func submit() throws(any Error)  // ❌ Existential error
```

**Rationale**: Typed throws enable exhaustive error handling and prevent error type erasure.

---

### Lifecycle Precedence Rules

**Scope**: Operations with multiple lifecycle conditions.

**Statement**: When multiple lifecycle conditions apply, precedence MUST be enforced:

1. **Shutdown dominates all outcomes** - If shutdown is in progress, operations MUST fail with `.shutdownInProgress` regardless of cancellation or state.
2. **Cancellation dominates success** - A cancelled operation MUST NOT surface a success value.
3. **Operational failures are lowest precedence** - Leaf or handle errors MUST NOT mask shutdown or cancellation.

Precedence MUST be enforced at the final resumption boundary.

**Rationale**: Consistent precedence prevents ambiguous error states and ensures predictable shutdown behavior.

---

### Typed Continuation Pattern

**Scope**: Async boundaries where Swift lacks typed throwing continuations.

**Statement**: When Swift does not support typed throwing continuations, implementations SHOULD use non-throwing continuations carrying `Result<Success, Failure>`. The async boundary MUST unwrap the Result and throw the typed error.

**Correct**:
```swift
func operation() async throws(MyError) -> Value {
    await withCheckedContinuation { continuation in
        // Use Result to preserve typed error
        performAsync { result: Result<Value, MyError> in
            continuation.resume(returning: result)
        }
    }.get()  // Unwrap and throw typed error
}
```

**Incorrect**:
```swift
// ❌ Using existential error continuation
await withCheckedThrowingContinuation { continuation in
    // Error type is erased to `any Error`
}
```

This pattern is preferred over:
- `CheckedThrowingContinuation<any Error>`
- Existential error funnels
- Runtime casts

Typed errors MUST be preserved by construction.

**Rationale**: Preserves type information across async boundaries without runtime casting.

---

### Typed Throws Closure Annotation

**Scope**: Closures passed to methods that preserve typed errors.

**Statement**: When passing a closure to a typed-throws-preserving extension, the closure MUST be explicitly annotated with `throws(E) -> T` to enable proper type inference.

#### The Problem

Swift cannot always infer typed error types through nested closures. When calling a method with signature `(_ body: (T) throws(E) -> R) throws(E) -> R`, the inner closure's error type must be explicit.

**Correct**:
```swift
// Explicit throws(E) annotation on closure
try unsafe bytes.withUnsafeBufferPointer(body: { buffer throws(E) -> T in
    var input = Binary.Bytes.Input(borrowing: buffer)
    return try body(&input)
})

// The compiler can now trace E through the call
```

**Incorrect**:
```swift
// ❌ Missing throws(E) annotation - compiler cannot infer E
try unsafe bytes.withUnsafeBufferPointer(body: { buffer in
    var input = Binary.Bytes.Input(borrowing: buffer)
    return try body(&input)  // Error: thrown expression type 'any Error' cannot be converted to error type 'E'
})
```

#### When to Annotate

Explicit annotation is REQUIRED when:
1. The closure calls another `throws(E)` function
2. The error type `E` is a generic parameter
3. The closure is passed to an extension that preserves typed errors

Explicit annotation is NOT needed when:
1. The closure is non-throwing
2. The error type is concrete (e.g., `throws(MyError)`)
3. Swift can infer the type from context

#### Creating Typed-Throws Extensions

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

The `body:` label (vs stdlib's unlabeled parameter) disambiguates the overload. `@_disfavoredOverload` ensures the stdlib version is preferred when both match.

**Rationale**: Swift's type inference has limitations with nested generic closures. Explicit annotation ensures the compiler can trace error types through the call stack.

---

### Typed Do Blocks Over Result Initializers

**Scope**: Capturing typed throws in local scope without erasure.

**Statement**: When capturing the result of a throwing operation, use `do throws(E) { } catch { }` instead of `Result { try ... }`. The `Result` initializer erases typed throws to `any Error`.

#### The Erasure Problem

```swift
// ❌ Error type erased
let result = Result { try throwingOperation() }
// result is Result<T, any Error>, not Result<T, SomeError>
```

Swift's typed throws preserves error type information through call chains, but `Result`'s throwing initializer erases it.

#### The Solution

```swift
// ✓ Error type preserved
do throws(IO.Event.Error) {
    let id = try driver.register(handle, descriptor: descriptor, interest: interest)
    replyBridge.push(.success(.registered(id)))
} catch {
    replyBridge.push(.failure(error))  // error is IO.Event.Error, not any Error
}
```

The `throws(E)` annotation tells the compiler what error type to expect. The `catch` block receives that specific type without casting.

#### When to Use

| Pattern | Use When |
|---------|----------|
| `do throws(E) { } catch { }` | Need to preserve typed error, handle locally |
| `Result { }` | Error type preservation not required |
| Direct `try` | Propagating to caller |

The verbose `do throws(E) { } catch { }` is more honest than the terse `Result { }`.

---

## Error Types

**Applies to**: All error type definitions.

---

### No Stringly-Typed Errors

**Scope**: All error types.

**Statement**: Errors MUST carry structured data (errno, platform code, operation, context). Strings MAY exist for debugging only, never as the primary signal.

**Correct**:
```swift
enum IOError: Error {
    case posix(errno: CInt, operation: Operation, path: FilePath)
    case timeout(duration: Duration, operation: Operation)
}
```

**Incorrect**:
```swift
// ❌ String-based error
struct IOError: Error {
    let message: String
}
```

**Rationale**: Structured errors enable programmatic handling and pattern matching.

---

### Swift.Error Qualification in Nested Contexts

**Scope**: Generic error constraints inside type extensions with nested Error types.

**Statement**: When writing generic code inside an extension of a type that has a nested `Error` type, the constraint `E: Error` MUST be qualified as `E: Swift.Error` to avoid ambiguity.

#### The Problem

Swift resolves `Error` to the nearest enclosing type's nested `Error` if one exists. Inside `extension RFC_4122.UUID`, the identifier `Error` resolves to `RFC_4122.UUID.Error`, not `Swift.Error`.

**Incorrect**:
```swift
extension RFC_4122.UUID {
    // ❌ E: Error resolves to RFC_4122.UUID.Error, not Swift.Error
    public static func v4<E: Error>(
        fillRandom: (UnsafeMutableRawBufferPointer) throws(E) -> Void
    ) throws(E) -> Self
    // Error: type 'E' constrained to non-protocol, non-class type 'RFC_4122.UUID.Error'
}
```

**Correct**:
```swift
extension RFC_4122.UUID {
    // ✓ Explicitly qualify with Swift.Error
    public static func v4<E: Swift.Error>(
        fillRandom: (UnsafeMutableRawBufferPointer) throws(E) -> Void
    ) throws(E) -> Self
}
```

#### When Qualification Is Required

Qualification is REQUIRED when ALL of these conditions hold:
1. You are inside an extension of a type
2. That type has a nested `Error` enum/struct
3. You are writing a generic constraint on `Error`

**Common affected types**:
- `RFC_4122.UUID` (has `RFC_4122.UUID.Error`)
- `File.Path` (has `File.Path.Error`)
- Custom types with `.Error` nested types

#### Alternative: Define at Module Level

If the function is complex, define it at module level where `Error` is unambiguous:

```swift
// At module level, Error resolves to Swift.Error
public func makeUUID<E: Error>(
    fillRandom: (UnsafeMutableRawBufferPointer) throws(E) -> Void
) throws(E) -> RFC_4122.UUID
```

**Rationale**: Swift's name resolution prefers nested types over stdlib types. Explicit qualification prevents subtle compilation errors when your type has a nested `Error`.

---

## Move-Only Boundaries

**Applies to**: APIs involving `~Copyable` types and token-based patterns.

---

### Move-Only Values and Error Boundaries

**Scope**: APIs involving `~Copyable` types.

**Statement**: `Swift.Error` requires `Copyable`. Move-only (`~Copyable`) values MUST NOT be embedded in types conforming to `Error`.

Therefore:
- Typed throws MUST NOT be used for APIs that must preserve move-only state (tokens, capabilities, typestate values) across failure.
- In such cases, APIs MUST instead return a non-throwing outcome type that:
  - Is `~Copyable`
  - Explicitly returns ownership on all paths
  - Makes state loss unrepresentable

This rule is non-negotiable.

**Rationale**: Prevents accidental loss of move-only resources when errors are thrown.

> **Related guidance**: See <doc:Memory> for comprehensive ~Copyable and error handling patterns.

---

### Token-Preserving Operation Pattern

**Scope**: Operations that consume a move-only token and may fail.

**Statement**: Operations that consume a move-only token and may fail before a replacement token is produced MUST follow this pattern:

- Expose a non-throwing, token-preserving API returning an `Outcome` enum:
  - Success case carries the new token (or result containing it)
  - Failure case returns the original token plus a typed failure
- A separate ergonomic throwing API MAY exist, implemented in terms of the preserving one, and MUST be used only when token loss is acceptable.

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
// ❌ Token lost on failure
func register(_ token: consuming UnregisteredToken) throws -> RegisteredToken
```

This pattern is REQUIRED at:
- Registration / arming boundaries
- Scheduling funnels
- Selector, executor, and runtime submission points

Token fabrication is forbidden.

**Rationale**: Ensures move-only resources are never lost, maintaining typestate invariants.

---

## Language Semantics

**Applies to**: All API naming and design decisions regarding error handling.

---

### Language Semantics Over Naming Conventions

**Scope**: All API naming.

**Statement**: Behavior MUST be expressed via Swift's type system and language keywords, NEVER through naming conventions. The language provides `throws`, `async`, `?`, `!`, typed errors, and marker parameters—use them.

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

// Call site requires unsafe expression
let result = unsafe { withRawPointer { $0.load(as: Int.self) } }

// Force unwrap via language operator
let value = optional!

// Call sites use language constructs:
let item = try container.value()
let maybe = collection.first()
let response = try await client.fetch()
let ordinal = Ordinal(__unchecked: (), 5)  // Unchecked visible at call site
```

**Incorrect**:
```swift
// ❌ Fallibility encoded in name
func tryStart() -> Bool
func getValue() throws -> T          // "get" implies throwing
init(validating input: String)       // "validating" implies throwing
init(parsing data: Data)             // "parsing" implies throwing

// ❌ Optionality encoded in name
func maybeFirst() -> Element?
func firstOrNil() -> Element?

// ❌ Asynchrony encoded in name
func fetchAsync() async -> Response
func asyncFetch() async -> Response

// ❌ Unchecked/unsafe encoded in name instead of @unsafe
func unsafeValue() -> T              // Use @unsafe + unsafe { }
func unsafeWithPointer(_ body: ...) -> T  // Use @unsafe
func forceUnwrap() -> T              // Use !
func uncheckedSubscript(_ i: Int) -> Element
init(unchecked index: Int)           // Label instead of __unchecked marker
```

This rule applies universally:
- Initializers: `init() throws(Error)` not `init(validating:)`
- Accessors: `value() throws` not `getValue()` or `tryValue()`
- Queries: `first() -> T?` not `maybeFirst()`
- Async operations: `fetch() async` not `fetchAsync()`
- Unsafe operations: `@unsafe func foo()` not `unsafeFoo()`
- Unchecked fast-paths: `init(__unchecked:, _)` not `init(unchecked:)` or `unsafeInit()`

**Rationale**:
- Swift's type system already expresses these semantics precisely
- Naming conventions fragment into dialects (`try`, `get`, `maybe`, `orNil`, etc.)
- Language constructs are enforced by the compiler; names are not
- Call sites read naturally: `try foo()` not `tryFoo()`
- Autocomplete and documentation reflect actual behavior

---

## Topics

### Related Documents

- <doc:Memory>
- <doc:API-Requirements>
- <doc:API-Implementation>
- <doc:API-Design>
- <doc:Five-Layer-Architecture>
- <doc:Implementation>

### Process Documents

- <doc:Documentation-Maintenance>
