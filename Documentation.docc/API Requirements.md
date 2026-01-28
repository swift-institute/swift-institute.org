# API Requirements

<!--
---
title: API Requirements
version: 2.2.0
last_updated: 2026-01-17
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Engineering patterns and non-negotiable requirements for API design.

## Overview

This document defines the project-wide engineering patterns and non-negotiable requirements.
These rules apply across all packages and targets unless an explicit, reviewed exception is recorded.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## Document Structure

| Section | Requirements | Focus |
|---------|--------------|-------|
| [Naming and API Surface](#naming-and-api-surface) | 6 | Type names, nesting patterns, identifiers |
| [Information Preservation](#information-preservation) | 1 | Preserving meaning across abstraction layers |
| [Layering Model](#layering-model) | 2 | Package and target architecture |
| [Error Handling](#error-handling) | 9 | Typed throws, error types, move-only boundaries |
| [Concurrency Model](#concurrency-model) | 4 | Async, actors, resumption invariants |
| [Implementation Style](#implementation-style) | 14 | Code patterns, totality, inlining |
| [Cross-Platform Requirements](#cross-platform-requirements) | 1 | Platform abstraction contracts |
| [Documentation and Comments](#documentation-and-comments) | 1 | DocC conventions |
| [Testing and Benchmarks](#testing-and-benchmarks) | 1 | Test strategies |
| [Design Validation](#design-validation) | 3 | Architectural decision validation |
| [Exceptions](#exceptions) | 1 | Deviation rules |

---

## Quick Reference: Foundational Requirements

These requirements are referenced most frequently and form the foundation of all API design:

| Requirement | Domain | Summary |
|-------------|--------|---------|
| [API-NAME-001](#api-name-001-namespace-structure-nestname-pattern) | Naming | `Nest.Name` pattern for all types |
| [API-NAME-002](#api-name-002-no-compound-identifiers) | Naming | No compound identifiers |
| [API-ERR-001](#api-err-001-typed-throws-everywhere) | Errors | Typed throws throughout |
| [API-INFO-001](#api-info-001-information-preservation-principle) | Design | Preserve information across layers |
| [API-IMPL-003](#api-impl-003-totality-for-primitives) | Implementation | Primitives must be total |
| [API-IMPL-005](#api-impl-005-one-type-per-file) | Organization | One type per file |

---

## Scope and Goals

**Applies to**: All packages in swift-primitives, swift-institute, and swift-standards.

- **Target**: Swift 6.2+ (Apple platform version v26+) with first-class support for Linux and Windows.
- **Totality**: swift-primitive packages MUST be total in their implementation, and perfect from day 1.
- **Domain**: Timeless, infrastructure-level libraries with long operational lifetimes.
- **Dependencies**:
  - No Foundation.
  - Prefer the Swift standard library plus minimal, well-justified system modules only (Darwin, Glibc, WinSDK, Synchronization, Clocks, StandardTime, etc.).

---

## Naming and API Surface

**Applies to**: All public types, functions, methods, properties, and enum cases across all packages.

**Does not apply to**: Private implementation details, test code, or generated code.

---

### [API-NAME-001] Namespace Structure: Nest.Name Pattern

**Scope**: All type declarations.

**Statement**: All types MUST use the `Nest.Name` pattern where **Nest** is the larger domain (the conceptual container) and **Name** is the subdomain or specific concept within that domain. This is a foundational, non-negotiable requirement.

#### Core Rules

1. **MUST use `Nest.Name` namespaces** - Types are nested within their domain.
2. **MUST NOT use compound type names** - Never concatenate words into a single identifier.
3. **Related concepts MUST share the same domain namespace** - Cohesion over convenience.

**Correct**:
```swift
File.Directory              // File is the domain, Directory is the concept
File.Directory.Walk         // Walk is a sub-concept of Directory
File.Directory.Walk.Options // Options specific to Walk
 Selector
 Lane
 Handle
 Ordinal
 Enumerable
 Accessible (protocol)
 Composition
```

**Incorrect**:
```swift
FileDirectory               // ❌ Compound name
DirectoryWalk               // ❌ Compound name
NonBlockingSelector         // ❌ Compound name
SelectorNonBlocking         // ❌ Compound name (also wrong word order)
ThreadHandle                // ❌ Compound name
FiniteOrdinal               // ❌ Compound name
```

**Rationale**:
1. **Discoverability**: Type `File.` and autocomplete reveals the entire File domain.
2. **Hierarchy communicates relationships**: `File.Directory.Walk` clearly shows Walk belongs to Directory belongs to File.
3. **Avoids naming collisions**: `IO.Error` vs `File.Error` vs `Kernel.Error` coexist naturally.
4. **Scales gracefully**: New concepts nest without polluting the global namespace.
5. **Reads like documentation**: The type name itself explains where it belongs.

#### Implementation

Nesting is achieved via extensions:

```swift
// In File.swift
public enum File {}

// In File.Directory.swift
extension File {
    public struct Directory: Sendable { ... }
}

// In File.Directory.Walk.swift
extension File.Directory {
    public struct Walk: Sendable { ... }
}
```

#### When Nesting Is Blocked

Swift does not allow protocols nested in generic types. In these cases:

1. **Hoist the protocol** to the module level with a `__` prefix
2. **Create a typealias** inside the intended namespace

```swift
// Hoisted (module level) - necessary due to Swift limitation
public protocol __PrismAccessible { ... }

// Typealias provides the correct Nest.Name API
extension Prism {
    public typealias Accessible = __PrismAccessible
}

// Usage: Prism.Accessible (appears nested)
```

**Cross-references**: [API-NAME-002], [API-IMPL-005]

---

### [API-NAME-002] No Compound Identifiers

**Scope**: All identifiers including types, functions, methods, properties, variables, and enum cases.

**Statement**: MUST avoid compound identifiers. Prefer path-like composition via nested values and calls.

**Correct**:
```swift
instance.open.read { … }
File.Directory.Walk
IO.NonBlocking.Selector
```

**Incorrect**:
```swift
instance.openRead { … }    // ❌ Compound method name
FileDirectoryWalk          // ❌ Compound type name
NonBlockingSelector        // ❌ Compound type name
```

This rule applies universally, including:
- Error types
- Result / outcome types
- Internal helpers
- "Technical" APIs not intended for end users

**Rationale**: Compound names defeat discoverability and create inconsistent naming patterns. Path-like composition allows autocomplete to guide users through the API.

**Cross-references**: [API-NAME-001], [API-NAME-003]

---

### [API-NAME-003] Specification-Mirroring Type Names

**Scope**: Types implementing external specifications (RFCs, ISOs, W3C, etc.).

**Statement**: When implementing external specifications, type names MUST mirror the specification's terminology exactly. The namespace SHOULD reflect the specification identifier.

**Correct**:
```swift
RFC_4122.UUID              // RFC 4122 UUID
RFC_4122.UUID.Version      // Version as defined in RFC 4122
RFC_4122.UUID.Variant      // Variant as defined in RFC 4122
RFC_9562.UUID.Version      // Extended versions from RFC 9562
ISO_32000.Page             // PDF page per ISO 32000
RFC_3986.URI               // URI per RFC 3986
```

**Incorrect**:
```swift
UUID                       // ❌ No specification context
UUIDVersion                // ❌ Compound name, no spec namespace
PDFPage                    // ❌ Compound name, no spec namespace
UniversallyUniqueID        // ❌ Invented name, doesn't match spec
```

**Rationale**:
1. **Traceability**: Each type maps directly to a specification section
2. **Disambiguation**: `RFC_4122.UUID.Version` vs `RFC_9562.UUID.Version` coexist naturally
3. **Documentation**: The type name IS the documentation reference
4. **Compliance verification**: Easy to audit spec compliance when names match

**Cross-references**: [API-NAME-001], [API-NAME-004]

---

### [API-NAME-004] Flat Namespace Constants

**Scope**: Static constants and well-known values on types.

**Statement**: Static constants MUST be direct properties on the type, not nested in unnecessary sub-namespaces. Avoid creating container enums or structs solely to group constants.

**Correct**:
```swift
extension RFC_4122.UUID {
    /// Namespace UUID for DNS names (RFC 4122 Appendix C).
    public static let dns = Self(bytes: (...))

    /// Namespace UUID for URLs (RFC 4122 Appendix C).
    public static let url = Self(bytes: (...))

    /// The nil UUID (all zeros).
    public static let `nil` = Self(bytes: (...))

    /// The max UUID (all ones).
    public static let max = Self(bytes: (...))
}

// Usage: clean shorthand works
let uuid = RFC_4122.UUID.v5(namespace: .dns, name: "example.com", using: hasher)
```

**Incorrect**:
```swift
// ❌ Unnecessary sub-namespace
extension RFC_4122.UUID {
    public enum Namespace {
        public static let dns = RFC_4122.UUID(bytes: (...))
        public static let url = RFC_4122.UUID(bytes: (...))
    }
}

// Usage: verbose, shorthand breaks
let uuid = RFC_4122.UUID.v5(namespace: RFC_4122.UUID.Namespace.dns, ...)
//                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^ verbose
// .dns shorthand won't work because Namespace.dns returns RFC_4122.UUID,
// but parameter type is Self - Swift can't infer the connection
```

**Rationale**:
1. **Shorthand works**: `.dns` resolves correctly when constants are on `Self`
2. **Discoverability**: `RFC_4122.UUID.` + autocomplete shows all constants
3. **Avoids type inference failures**: Sub-namespaces break Swift's ability to infer `.shorthand`
4. **Simpler hierarchy**: Fewer types to maintain and document

**Exception**: Sub-namespaces are appropriate when the nested type has its own behavior (methods, conformances) or when constants have different types than the parent.

**Cross-references**: [API-NAME-001], [API-NAME-002]

---

### [API-NAME-005] Nested Accessor Pattern

**Scope**: Instance methods that group related operations.

**Statement**: Instance methods that group related operations MUST use nested accessor structs rather than compound method names.

**Correct**:
```swift
// The namespace struct holds a reference to the parent
extension File {
    public struct Walk: Sendable {
        let path: File.Path

        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

// Instance property returns the namespace
extension File.Directory {
    public var walk: Walk {
        Walk(path)
    }
}

// Operations live on the namespace struct
extension File.Directory.Walk {
    public func callAsFunction(options: Options = Options()) throws -> [Entry] {
        // implementation
    }

    public func files(options: Options = Options()) throws -> [File] {
        // implementation
    }

    public func directories(options: Options = Options()) throws -> [Directory] {
        // implementation
    }
}
```

Usage becomes path-like:

```swift
// Primary action via callAsFunction
for entry in try dir.walk() { ... }

// Variant operations
for file in try dir.walk.files() { ... }
for subdir in try dir.walk.directories() { ... }

// With options
for entry in try dir.walk(options: .init(maxDepth: 2)) { ... }
```

**Incorrect**:
```swift
// ❌ Compound method names
dir.walkFiles()
dir.walkDirectories()
file.readFull()
file.readStreaming()
```

**Rationale**:
- `dir.walk` + autocomplete reveals all walk operations
- `dir.walkFiles()` requires knowing the exact method name
- Namespace structs can hold shared state/configuration
- Pattern scales: `file.read.full()`, `file.read.streaming()`, `file.read.buffered()`

This pattern SHOULD be used when:
- An instance has multiple related operations (read variants, write modes, etc.)
- Operations share common configuration or context
- Discoverability benefits from grouping

The namespace struct SHOULD:
- Be lightweight (store only references, not copies)
- Be `Sendable` when the parent is `Sendable`
- Use `callAsFunction` for the primary/default operation
- Provide named methods for variants

**Cross-references**: [API-NAME-002], [API-IMPL-008]

---

### [API-NAME-006] API Minimalism

**Scope**: All public APIs.

**Statement**: Public APIs MUST be small, composable, and mechanically predictable.

- Convenience APIs MAY exist only at the highest-level user-facing targets.
- Lower-level targets SHOULD prefer:
  - `init(...)` in extensions
  - Static factory functions
  - Pure transformations
  - Small value types
- Methods are allowed only when:
  - Required by the language (actors, protocols, operators)
  - Modeling essential, local mutation
  - Correctness materially improves
  - Ergonomics cannot be achieved via initializers or statics

**Rationale**: Minimal APIs are easier to understand, test, and maintain. Composable primitives enable users to build exactly what they need.

**Cross-references**: [API-NAME-004], [API-IMPL-001]

---

## Information Preservation

**Applies to**: All API design decisions across all layers.

**Does not apply to**: Internal implementation details not exposed through APIs.

---

### [API-INFO-001] Information Preservation Principle

**Scope**: All type design, error handling, and API surface decisions.

**Statement**: Infrastructure design MUST preserve information across layers. Every abstraction boundary is an opportunity to lose or preserve meaning—deliberate infrastructure carries meaning through.

Types, errors, and APIs MUST NOT erase information that callers may need:
- Error types MUST be typed (`throws(E)`), not existential (`throws any Error`)
- Specification structure MUST be preserved in type names (`RFC_4122.UUID`, not `UUID`)
- Context MUST be explicit (dependency injection), not implicit (global state)
- Closures MUST preserve typed errors through explicit annotation when needed

**Correct**:
```swift
// Error types preserved
func parse() throws(Parse.Error) -> Document

// Specification structure in type names
let uuid: RFC_4122.UUID

// Context explicit via dependency injection
func operation(context: Context) throws -> Result

// Typed errors through closure annotation
bytes.withUnsafeBufferPointer { buffer throws(E) -> T in
    try body(&input)
}
```

**Incorrect**:
```swift
// ❌ Error type erased
func parse() throws -> Document  // Becomes `any Error`

// ❌ Specification structure lost
let uuid: UUID  // Which UUID? Which spec?

// ❌ Context hidden in global state
func operation() throws -> Result  // Uses GlobalConfig.shared

// ❌ Typed error lost through inference
bytes.withUnsafeBufferPointer { buffer in  // E becomes `any Error`
    try body(&input)
}
```

**Rationale**: Most code loses information—error types become `any Error`, specifications become "just strings", context disappears into global state. Deliberate infrastructure carries meaning through every layer. The typed-throws extensions, specification-mirroring names, and explicit context patterns exist specifically to preserve information that would otherwise be lost.

**Cross-references**: [API-ERR-001], [API-ERR-007], [API-NAME-003], [API-IMPL-010]

---

## Layering Model

**Applies to**: All package and target architecture decisions.

**Does not apply to**: Single-file scripts, prototypes, or exploration code.

---

### [API-LAYER-001] Explicit Target Layers

**Scope**: Package and target organization.

**Statement**: Code MUST be designed in layers, each depending only on layers below it.

Typical shape:

1. **Primitives**
   - Minimal tokens, IDs, events, handles
   - Zero policy, zero platform choice

2. **Driver / backend contracts**
   - Capability interfaces
   - Leaf errors
   - Stable, testable contracts

3. **Platform backends**
   - kqueue, epoll, IOCP, etc.

4. **Runtime orchestration**
   - Lifecycles
   - Scheduling
   - Cancellation
   - Cross-thread coordination

5. **User-facing convenience**
   - Ergonomic wrappers
   - Default policies
   - Platform factories

**Rationale**: Layered architecture enables testing at each level, platform portability, and clear dependency boundaries.

**Cross-references**: [API-LAYER-002]

---

### [API-LAYER-002] Responsibility Separation

**Scope**: Layer boundaries.

**Statement**: Lower layers MUST NOT embed lifecycle policy, introduce cancellation or shutdown semantics, construct user-facing errors requiring runtime context, or depend on higher-level scheduling decisions.

Higher layers are the only place where:
- Lifecycle semantics exist
- Cancellation and shutdown are unified
- Backpressure and retry policy are applied

**Rationale**: Separation ensures lower layers remain testable and reusable across different runtime contexts.

**Cross-references**: [API-LAYER-001], [API-ERR-002]

---

## Error Handling

**Applies to**: All error types and throwing functions.

**Does not apply to**: Debug-only assertions in test code.

---

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
func read() throws -> Data  // ❌ Untyped throws
func submit() throws(any Error)  // ❌ Existential error
```

**Rationale**: Typed throws enable exhaustive error handling and prevent error type erasure.

**Cross-references**: [API-ERR-003], [API-ERR-004], [API-ERR-008]

---

### [API-ERR-002] Lifecycle Precedence Rules

**Scope**: Operations with multiple lifecycle conditions.

**Statement**: When multiple lifecycle conditions apply, precedence MUST be enforced:

1. **Shutdown dominates all outcomes** - If shutdown is in progress, operations MUST fail with `.shutdownInProgress` regardless of cancellation or state.
2. **Cancellation dominates success** - A cancelled operation MUST NOT surface a success value.
3. **Operational failures are lowest precedence** - Leaf or handle errors MUST NOT mask shutdown or cancellation.

Precedence MUST be enforced at the final resumption boundary.

**Rationale**: Consistent precedence prevents ambiguous error states and ensures predictable shutdown behavior.

**Cross-references**: [API-LAYER-002], [API-CONC-004]

---

### [API-ERR-003] Typed Continuation Pattern

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

**Cross-references**: [API-ERR-001]

---

### [API-ERR-004] No Stringly-Typed Errors

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

**Cross-references**: [API-ERR-001]

---

### [API-ERR-005] Move-Only Values and Error Boundaries

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

**Cross-references**: [API-ERR-006]

---

### [API-ERR-006] Token-Preserving Operation Pattern

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

**Cross-references**: [API-ERR-005]

---

### [API-ERR-007] Typed Throws Closure Annotation

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

**Cross-references**: [API-ERR-001], [API-ERR-003]

---

### [API-ERR-008] Language Semantics Over Naming Conventions

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

// Unchecked via marker parameter (see [API-IMPL-003])
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

**Cross-references**: [API-ERR-001], [API-IMPL-001], [API-IMPL-003]

---

### [API-ERR-009] Swift.Error Qualification in Nested Contexts

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

**Cross-references**: [API-ERR-001], [API-NAME-001]

---

## Concurrency Model

**Applies to**: All concurrent code including async functions, actors, and multi-threaded operations.

**Does not apply to**: Synchronous-only utility packages or pure data types without shared state.

---

### [API-CONC-001] Modern Swift Concurrency

**Scope**: All concurrent implementations.

**Statement**: MUST use Swift concurrency primitives:
- `async` / structured concurrency
- Actors where isolation is required
- Explicit executors where determinism or performance requires it

MUST NOT introduce ad-hoc threading models when structured concurrency suffices.

**Rationale**: Swift concurrency provides compile-time safety guarantees that ad-hoc threading cannot.

**Cross-references**: [API-CONC-002], [API-CONC-003]

---

### [API-CONC-002] Executor and Thread Topology

**Scope**: APIs with thread affinity requirements.

**Statement**:
- APIs promising "pinned execution" MUST use an explicit executor and document it clearly.
- Cross-thread delivery MUST go through explicit bridges or queues.
- Resumption MUST be exactly-once.

**Rationale**: Explicit executor control prevents accidental thread-safety violations.

**Cross-references**: [API-CONC-001], [API-CONC-003]

---

### [API-CONC-003] Single Resumption Funnel Invariant

**Scope**: All suspended operations.

**Statement**:
- Each suspended operation MUST have exactly one resumption path.
- All resumptions MUST funnel through a single, explicit component (actor, executor, or state machine).
- Cancellation handlers MUST NOT resume continuations directly.
- Cancellation MAY only synchronously record intent or enqueue work to the resumption funnel.

This invariant guarantees:
- Exactly-once resume
- Consistent lifecycle precedence
- Absence of double-resume races

**Rationale**: Single resumption funnel eliminates an entire class of concurrency bugs.

**Cross-references**: [API-CONC-002], [API-CONC-004]

---

### [API-CONC-004] Cancellation and Shutdown Invariants

**Scope**: All cancellable and shutdownable operations.

**Statement**:
- Cancellation MUST NOT cause hangs.
- Shutdown MUST be explicit and reject new work deterministically.
- All outstanding work MUST be drained or rejected with a typed lifecycle error.

**Rationale**: Predictable cancellation and shutdown behavior is essential for resource management.

**Cross-references**: [API-ERR-002], [API-CONC-003]

---

## Implementation Style

**Applies to**: All implementation code in production packages.

**Does not apply to**: Test fixtures, mocks, or temporary exploration code.

---

### [API-IMPL-001] Construction and Transformation

**Scope**: Type construction and value transformation.

**Statement**:
- Prefer construction via extension initializers and static factory methods.
- Fallible construction uses `init() throws(Error)`, not labeled variants like `init(validating:)`.
- Methods SHOULD be thin conveniences at top layers only.
- Mutating methods are allowed when modeling clear, local state transitions.

**Correct**:
```swift
// Fallible initializer - throws, not labeled
extension URL {
    init(_ string: String) throws(URL.Error)
}

// Transformation via typed throws
extension Data {
    init(_ string: String, using encoding: Encoding) throws(Encoding.Error)
}

// Usage reads naturally
let url = try URL(urlString)
let data = try Data(input, using: .utf8)
```

**Incorrect**:
```swift
// ❌ Behavior encoded in label
init(validating string: String)
init(parsing data: Data)
init(transforming value: T)
```

**Rationale**: Initializers and static methods make construction explicit and discoverable. Fallibility is expressed via `throws`, not labels—see [API-ERR-008].

**Cross-references**: [API-NAME-006], [API-ERR-008]

---

### [API-IMPL-002] Keep Core Types Lean

**Scope**: Core type definitions.

**Statement**:
- Prefer explicit state machines over booleans.
- Prefer typestate when it clarifies correctness.
- Value types SHOULD be small, predictable, and explicit.

**Correct**:
```swift
enum ConnectionState {
    case disconnected
    case connecting
    case connected(Session)
    case disconnecting
}
```

**Incorrect**:
```swift
// ❌ Boolean flags for state
struct Connection {
    var isConnecting: Bool
    var isConnected: Bool
    var session: Session?
}
```

**Rationale**: Explicit state machines make invalid states unrepresentable.

**Cross-references**: [API-IMPL-003]

---

### [API-IMPL-003] Totality for Primitives

**Scope**: All primitive packages.

**Statement**: Primitive packages MUST be total in their implementation. Totality means: every function returns a valid result for every valid input. No crashes, no undefined behavior, no precondition failures for inputs that the type system allows.

#### Rules for Primitives

1. **No preconditions for policy** - Primitives MUST NOT use `precondition`, `fatalError`, or `assert` to enforce usage patterns.
2. **Structural invariants only** - The only acceptable use of precondition is when the type system cannot express a true invariant (rare).
3. **Partiality must be in the type** - If an operation can fail, the return type MUST reflect it (`Optional`, `Result`, `throws`).

#### Checked vs Unchecked API Split

When an operation has both a safe path (with validation) and a fast path (trusting the caller), provide both:

```swift
public protocol Enumerable {
    static var caseCount: Int { get }
    var caseIndex: Int { get }

    /// Fast path - caller guarantees index is valid.
    /// The `__unchecked` marker makes the contract explicit.
    init(__unchecked: Void, _ index: Int)
}

extension Enumerable {
    /// Safe path - validates and returns nil for invalid input.
    @inlinable
    public init?(_ index: Int) {
        guard index >= 0 && index < Self.caseCount else { return nil }
        self.init(__unchecked: (), index)
    }
}
```

The `__unchecked` marker parameter:
- Makes the unchecked nature visible at call sites: `Ordinal(__unchecked: (), 5)`
- Prevents accidental use (you can't call it without the marker)
- Follows stdlib patterns (`UnsafePointer`, etc.)

#### Collection Subscript Semantics

`Collection.subscript` is unchecked by design (stdlib contract). This is acceptable because:
- The contract is well-established and expected
- Callers use `indices`, iteration, or bounds checking
- Providing a separate total accessor (e.g., `element(at:)`) gives safe access

```swift
extension Enumeration: Collection {
    /// Unchecked - follows Collection contract.
    public subscript(position: Int) -> Element {
        Element(__unchecked: (), position)
    }
}

extension Enumeration {
    /// Total - returns nil for invalid positions.
    public func element(at position: Int) -> Element? {
        Element(position)  // Uses the failable initializer
    }
}
```

**Rationale**: Totality eliminates runtime crashes and makes APIs predictable.

**Cross-references**: [API-IMPL-002]

---

### [API-IMPL-004] Code Awaiting Language Features

**Scope**: APIs blocked by missing Swift features.

**Statement**: When Swift lacks a feature needed for correct API design, write the code now and comment it out with explanation.

This pattern:
- Documents the intended API
- Ensures the code is ready when Swift adds the feature
- Makes the limitation explicit
- Prevents incorrect workarounds

**Correct**:
```swift
// MARK: - Inhabitant Conveniences (Awaiting Language Support)
//
// The following extension requires value-generic constraints (`where N > 0`),
// which Swift does not yet support. These APIs are only total for N > 0:
//
// - `zero` returns the first inhabitant (index 0)
// - `max` returns the last inhabitant (index N - 1)
//
// For `Ordinal<0>`, the type has no inhabitants, so these would be unsound.
//
// When Swift adds value-generic constraints, uncomment this extension:
//
// extension Finite.Ordinal where N > 0 {
//     @inlinable
//     public static var zero: Self { Self(__unchecked: (), 0) }
//
//     @inlinable
//     public static var max: Self { Self(__unchecked: (), N - 1) }
// }
//
// Until then, use the failable initializer: `Ordinal(0)` or `Ordinal(N - 1)`.
```

**Incorrect**:
- Using runtime checks as a workaround (`precondition(N > 0)`)
- Changing the semantics to work around the limitation
- Omitting the API without documenting why

**Rationale**: Preserves design intent while waiting for language evolution.

**Cross-references**: [API-IMPL-009]

---

### [API-IMPL-005] One Type Per File

**Scope**: All type declarations.

**Statement**: Every `.swift` file MUST contain exactly one type declaration. This is a foundational, non-negotiable requirement. This rule applies to all types: structs, enums, actors, classes, and protocols.

#### Core Rules

1. **One type per file** - No exceptions. Each type gets its own file.
2. **File name matches type path** - `File.Directory.Walk.swift` contains `File.Directory.Walk`.
3. **Minimal type declaration** - The type body contains only stored properties/cases and the canonical initializer.
4. **Everything else in extensions** - Methods, computed properties, protocol conformances go in extensions.

#### File Naming Convention

The file name MUST match the full `Nest.Name` path of the type:

| Type | File Name |
|------|-----------|
| `File` | `File.swift` |
| `File.Directory` | `File.Directory.swift` |
| `File.Directory.Walk` | `File.Directory.Walk.swift` |
| `File.Directory.Walk.Options` | `File.Directory.Walk.Options.swift` |
| `IO.NonBlocking.Selector` | `IO.NonBlocking.Selector.swift` |
| `Finite.Ordinal` | `Finite.Ordinal.swift` |
| `Finite.Ordinal.Successor` | `Finite.Ordinal.Successor.swift` |

#### Type Declaration Structure

**Correct**:
```swift
// File: IO.Executor.Pool.swift

extension IO.Executor {
    /// A pool that manages resources with handle-based access.
    public actor Pool<Resource: ~Copyable & Sendable> {
        // ONLY stored properties
        private var handles: [IO.Handle.ID: Entry<Resource>]
        private let lane: IO.Blocking.Lane
        private let scope: IO.Handle.Scope

        // ONLY the canonical initializer (if needed)
        public init(lane: IO.Blocking.Lane, policy: IO.Backpressure.Policy = .default) {
            self.handles = [:]
            self.lane = lane
            self.scope = IO.Handle.Scope()
        }
    }
}

// ALL other functionality in extensions (same file or separate files)
extension IO.Executor.Pool where Resource: ~Copyable {
    public func register(_ resource: consuming Resource) throws(IO.Handle.Error) -> IO.Handle.ID {
        // ...
    }
}

extension IO.Executor.Pool where Resource: ~Copyable {
    public func transaction<T, E: Error>(
        _ id: IO.Handle.ID,
        _ body: (inout Resource) throws(E) -> T
    ) async throws(IO.Lifecycle.Error<IO.Error<E>>) -> T {
        // ...
    }
}
```

#### Nested/Related Types Get Separate Files

Each nested type MUST be in its own file:

```
IO.Executor.Pool.swift           # The Pool actor
IO.Executor.Pool.Entry.swift     # The Entry helper type
IO.Executor.Pool.Metrics.swift   # The Metrics struct
IO.Executor.Pool.Error.swift     # The Error enum
```

#### Protocol Conformances

Protocol conformances SHOULD be in separate files when they add substantial functionality:

```
Finite.Ordinal.swift                    # Core type
Finite.Ordinal+Comparable.swift         # Comparable conformance
Finite.Ordinal+Codable.swift            # Codable conformance
Finite.Ordinal+Enumerable.swift         # Finite.Enumerable conformance
```

For trivial conformances (marker protocols, single-line implementations), they MAY remain in the main type file.

**Incorrect**:
```swift
// ❌ WRONG: Multiple types in one file
// File: Models.swift
struct User { ... }
struct Profile { ... }
struct Settings { ... }

// ❌ WRONG: Helper types inline
// File: Parser.swift
struct Parser {
    struct Options { ... }  // Should be in Parser.Options.swift
    enum Error { ... }      // Should be in Parser.Error.swift
}

// ❌ WRONG: Methods in type declaration
struct Point {
    var x: Double
    var y: Double

    func distance(to other: Point) -> Double { ... }  // Should be in extension
}
```

**Correct**:
```swift
// ✅ CORRECT: One type, minimal declaration
// File: Point.swift
struct Point: Sendable {
    var x: Double
    var y: Double
}

// File: Point.swift (continued) or Point+Geometry.swift
extension Point {
    func distance(to other: Point) -> Double {
        // ...
    }
}
```

**Rationale**:
1. **Predictable navigation**: To find `File.Directory.Walk`, open `File.Directory.Walk.swift`. Always.
2. **Clean git history**: Changes to one type don't touch files for other types.
3. **Enforces Nest.Name**: The file system mirrors the type hierarchy.
4. **Separation of concerns**: "What this type IS" (declaration) vs "what it DOES" (extensions).
5. **Constrained extensions**: Extensions can have `where` clauses; type declarations cannot.
6. **Merge conflict reduction**: Parallel work on different aspects of a type doesn't conflict.

**Cross-references**: [API-NAME-001]

---

### [API-IMPL-006] Abstraction Boundary Integrity

**Scope**: All abstraction implementations.

**Statement**:
- Core abstraction internals (e.g., `_run`) MUST remain private.
- Higher-level composition MUST NOT reach into private implementation details.
- If composition is impossible, introduce a new internal helper or refactor the abstraction itself.
- Private internals are part of the abstraction's correctness boundary.

**Rationale**: Encapsulation enables safe refactoring and prevents coupling to implementation details.

---

### [API-IMPL-007] Sharding and Scaling Strategies

**Scope**: Performance optimizations involving parallelism.

**Statement**:
- Sharding is a performance optimization, not a semantic abstraction.
- Sharding SHOULD be invisible at the API level whenever possible.
- Prefer sharded implementations of existing abstractions and factories returning the same abstract type.
- Avoid parallel "plural" types (`Lanes`, `Pools`) unless semantics differ.

**Rationale**: Sharding is an implementation detail; users should not need to change code when scaling.

---

### [API-IMPL-008] Inlining Rules

**Scope**: Performance-critical code.

**Statement**:

**`@inlinable`**: Makes the function body available for inlining across module boundaries. Use for leaf-level, performance-critical code.

**`@usableFromInline`**: Makes an `internal` symbol visible to `@inlinable` code without making its implementation inlinable.

#### When to Use `@inlinable`

```swift
extension Prism {
    /// Simple, leaf-level operation - good candidate for inlining.
    @inlinable
    public func matches(_ whole: Whole) -> Bool {
        extract(whole) != nil
    }
}

extension Finite.Ordinal {
    /// Trivial accessor - inline for zero overhead.
    @inlinable
    public var rawValue: Int { _rawValue }
}
```

#### When to Use `@usableFromInline`

```swift
extension File.Directory {
    public struct Walk: Sendable {
        /// Internal storage, but @inlinable code needs to see it.
        @usableFromInline
        internal let path: File.Path

        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }

    /// Public, inlinable accessor that references internal storage.
    @inlinable
    public var walk: Walk { Walk(path) }
}
```

#### Rules

1. **`@inlinable` MUST NOT reference private symbols** - Use `@usableFromInline` for internal symbols that inlinable code needs.
2. **`@inlinable` is for leaf-level code** - Small, performance-critical functions.
3. **Orchestration logic SHOULD NOT be `@inlinable`** - Complex logic changes more often; inlining locks in the implementation.
4. **Primitives packages SHOULD be heavily `@inlinable`** - They're leaf-level by design.

**Cross-references**: [API-NAME-003]

---

### [API-IMPL-009] Value Generics

**Scope**: Types with compile-time constant parameters.

**Statement**: Swift 6.0+ supports value generics with `<let N: Int>` syntax. Use these for compile-time constants that affect type identity.

#### Usage

```swift
/// A finite ordinal in {0, 1, ..., N-1}.
public struct Ordinal<let N: Int>: Sendable {
    public let rawValue: Int

    public init?(_ rawValue: Int) {
        guard rawValue >= 0 && rawValue < N else { return nil }
        self.rawValue = rawValue
    }
}

// Different N means different types:
let a: Ordinal<3> = Ordinal(1)!  // Can hold 0, 1, or 2
let b: Ordinal<5> = Ordinal(1)!  // Can hold 0, 1, 2, 3, or 4
// a = b  // ❌ Type error: Ordinal<3> vs Ordinal<5>
```

#### Accessing the Value

The generic parameter `N` is available as a compile-time constant:

```swift
extension Ordinal {
    /// Number of inhabitants of this type.
    @inlinable
    public static var count: Int { N }

    /// Whether this is the last inhabitant.
    @inlinable
    public var isMax: Bool { rawValue == N - 1 }
}
```

#### Current Limitations

Swift does not yet support value-generic constraints (`where N > 0`). See [API-IMPL-004] for how to handle this.

**Cross-references**: [API-IMPL-004]

---

### [API-IMPL-010] No Hidden Global State

**Scope**: All code.

**Statement**:
- Avoid singletons.
- Avoid global mutable storage.
- Any global configuration MUST be explicit, immutable, and testable.

**Rationale**: Hidden global state makes code untestable and creates implicit dependencies.

---

### [API-IMPL-011] No Ad-Hoc Helpers

**Scope**: All implementation code.

**Statement**: Ad-hoc helper functions, types, and extensions MUST NOT be created. The ecosystem is assumed complete—every common operation has a canonical implementation in an existing dependency.

Before writing any helper:
1. **Search exhaustively** - Check swift-primitives, swift-standards, and all transitive dependencies for existing functionality.
2. **Compose existing primitives** - If no direct match exists, compose existing types and functions to achieve the goal.
3. **Escalate gaps** - Only if no composition is possible, present the missing capability for review. Do not implement a local workaround.

**Correct**:
```swift
// Use existing Finite.Ordinal from swift-primitives
let index: Finite.Ordinal<10> = Ordinal(5)!

// Use existing File.Directory.Walk from swift-posix
for entry in try dir.walk() { ... }

// Compose existing primitives
let result = existingTransform(existingParse(input))
```

**Incorrect**:
```swift
// ❌ Ad-hoc helper duplicating existing functionality
func clampedIndex(_ i: Int, max: Int) -> Int {
    min(max(0, i), max - 1)
}

// ❌ Local extension duplicating ecosystem capability
extension Array {
    func safeSubscript(_ index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// ❌ Private helper type that should come from a dependency
private struct Pair<A, B> {
    let first: A
    let second: B
}
```

**Rationale**: Ad-hoc helpers fragment the codebase, create maintenance burden, and often duplicate battle-tested implementations with subtle bugs. A complete ecosystem means local helpers indicate either unfamiliarity with available tools or a genuine gap that should be addressed at the ecosystem level—not worked around locally.

**Cross-references**: [API-NAME-006], [API-IMPL-001]

---

### [API-IMPL-012] Protocol-Based Capability Injection

**Scope**: APIs requiring platform or cryptographic capabilities.

**Statement**: When an operation requires capabilities that cannot be provided without platform dependencies (randomness, hashing, time, file I/O), the API MUST accept those capabilities via protocol-constrained parameters rather than importing platform libraries directly.

This pattern enables:
- Foundation-free packages (Swift Embedded compatible)
- Testability via mock implementations
- User choice of cryptographic libraries
- Cross-platform portability

**Correct**:
```swift
// Define capability protocol in the standards layer
extension RFC_4122 {
    /// Protocol for providing hash functions to name-based UUID generators.
    public protocol HashProvider: Sendable {
        func md5(_ data: [UInt8]) -> [UInt8]
        func sha1(_ data: [UInt8]) -> [UInt8]
    }

    /// Protocol for providing random bytes to UUID generators.
    public protocol RandomProvider: Sendable {
        associatedtype RandomError: Error
        func fill(_ buffer: UnsafeMutableRawBufferPointer) throws(RandomError)
    }
}

// API accepts capability as parameter
extension RFC_4122.UUID {
    public static func v5<H: RFC_4122.HashProvider>(
        namespace: Self,
        name: String,
        using hashProvider: H
    ) -> Self

    public static func v4<R: RFC_4122.RandomProvider>(
        using random: R
    ) throws(R.RandomError) -> Self
}

// Usage: caller provides capability
let uuid = RFC_4122.UUID.v5(namespace: .dns, name: "example.com", using: myHasher)
let random = try RFC_4122.UUID.v4(using: SystemRandom())
```

**Incorrect**:
```swift
// ❌ Direct platform dependency
import CryptoKit  // Foundation dependency

extension RFC_4122.UUID {
    public static func v5(namespace: Self, name: String) -> Self {
        let hash = Insecure.SHA1.hash(data: ...)  // Couples to CryptoKit
        ...
    }
}

// ❌ Global singleton for capability
extension RFC_4122.UUID {
    public static func v4() -> Self {
        SystemRandomNumberGenerator.shared.fill(...)  // Hidden global state
    }
}
```

#### Closure-Based Convenience

For one-off usage, provide a closure-based overload alongside the protocol-based API:

```swift
extension RFC_4122.UUID {
    /// Closure-based v4 generation for convenience.
    public static func v4<E: Swift.Error>(
        fillRandom: (UnsafeMutableRawBufferPointer) throws(E) -> Void
    ) throws(E) -> Self
}

// Usage: inline closure
let uuid = try RFC_4122.UUID.v4 { buffer in
    try myCSPRNG.fill(buffer)
}
```

#### Platform Layer Provides Implementations

The platform layer (swift-darwin, swift-linux, etc.) provides concrete implementations:

```swift
// In swift-darwin
extension Darwin {
    public struct SecureRandom: RFC_4122.RandomProvider {
        public func fill(_ buffer: UnsafeMutableRawBufferPointer) throws(Errno) {
            // Use SecRandomCopyBytes
        }
    }
}

// In swift-linux
extension Linux {
    public struct SecureRandom: RFC_4122.RandomProvider {
        public func fill(_ buffer: UnsafeMutableRawBufferPointer) throws(Errno) {
            // Use getrandom(2)
        }
    }
}
```

**Rationale**: This pattern keeps the standards layer Foundation-free and testable while allowing full functionality when platform capabilities are available. The caller controls dependencies, not the library.

**Cross-references**: [API-LAYER-001], [API-LAYER-002], [API-IMPL-010]

---

### [API-IMPL-013] Effect-Based API Design

**Scope**: APIs where callers need to express intentions that will be interpreted by handlers.

**Statement**: When designing APIs where actions should be interceptable, testable, or composable, prefer *describing* actions over *performing* them. Effect types MUST be values that represent intentions rather than functions that execute immediately.

This pattern enables:
- Testability via inspection and mocking
- Composition via standard value operations
- Separation between expression and interpretation

**Correct**:
```swift
// Effect as value - describes intention
struct Effect<A> {
    enum Kind {
        case yield           // Intention to yield control
        case log(String)     // Intention to log
        case read(Path)      // Intention to read a file
    }
    let kind: Kind
    let continuation: (Result<A, Error>) -> Void
}

// Handler interprets the description
func handle<A>(_ effect: Effect<A>) async {
    switch effect.kind {
    case .yield:
        await Task.yield()
        effect.continuation(.success(()))
    case .log(let message):
        print(message)
        effect.continuation(.success(()))
    case .read(let path):
        // Perform actual read
    }
}

// Test can inspect without executing
func testEffectSequence() {
    let effects = collectEffects(myOperation)
    #expect(effects[0].kind == .log("Starting"))
    #expect(effects[1].kind == .read(expectedPath))
}
```

**Incorrect**:
```swift
// ❌ Action as function - performs immediately
func yield() async {
    await Task.yield()  // Executes - cannot intercept
}

func log(_ message: String) {
    print(message)  // Executes - cannot test without side effects
}

// Cannot inspect what operations will occur without running them
// Cannot mock without dependency injection infrastructure
```

#### When to Use Effect-Based Design

Effect-based design is REQUIRED when:
1. Operations must be testable without executing side effects
2. Multiple handlers might interpret the same operation differently
3. Operations need to be recorded, replayed, or composed

Effect-based design is NOT needed when:
1. Operations are pure transformations (no side effects)
2. There is only one possible interpretation
3. Immediate execution is the only use case

**Rationale**: Descriptions are data. Data can be inspected, transformed, mocked, recorded. Actions just happen and leave no trace. The shift from doing to describing makes the impossible possible—testing without mocking frameworks, composition without inheritance, interpretation without coupling.

**Cross-references**: [API-INFO-001], [API-ERR-006], [API-IMPL-002]

---

### [API-IMPL-014] Zero-Cost Phantom Types

**Scope**: Type-safe wrappers and domain identifiers.

**Statement**: When compile-time type safety is needed without runtime overhead, use phantom type parameters with zero-cost wrappers. The wrapper MUST store only the underlying value with no additional metadata.

**Correct**:
```swift
/// A tagged value that provides compile-time type safety without runtime cost.
public struct Tagged<Tag, RawValue>: Sendable where RawValue: Sendable {
    public var rawValue: RawValue

    public init(_ rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

// Domain-specific IDs with compile-time safety
enum User { enum IDTag {} }
enum Order { enum IDTag {} }

typealias UserID = Tagged<User.IDTag, UUID>
typealias OrderID = Tagged<Order.IDTag, UUID>

// Compile-time safety: cannot mix user and order IDs
func fetchUser(id: UserID) -> User
func fetchOrder(id: OrderID) -> Order

let userId: UserID = UserID(uuid)
let orderId: OrderID = OrderID(uuid)

fetchUser(id: userId)   // ✓ Compiles
fetchUser(id: orderId)  // ✗ Compile error - type mismatch
```

#### Zero-Cost Guarantee

The phantom type parameter `Tag` exists only at compile time:
- `sizeof(Tagged<A, Int>) == sizeof(Int)`
- No heap allocation
- No runtime type metadata for `Tag`
- Inline storage identical to `RawValue`

#### Conditional Conformances

Extend the wrapper to inherit conformances from the underlying value:

```swift
extension Tagged: Equatable where RawValue: Equatable {}
extension Tagged: Hashable where RawValue: Hashable {}
extension Tagged: Comparable where RawValue: Comparable {}
extension Tagged: Codable where RawValue: Codable {}

// Literal expressibility
extension Tagged: ExpressibleByIntegerLiteral where RawValue: ExpressibleByIntegerLiteral {}
extension Tagged: ExpressibleByStringLiteral where RawValue: ExpressibleByStringLiteral {}
```

#### Tag Conversion

Allow zero-cost tag conversion when semantically valid:

```swift
extension Tagged {
    /// Changes the tag without affecting the underlying value.
    public func retag<NewTag>() -> Tagged<NewTag, RawValue> {
        Tagged<NewTag, RawValue>(rawValue)
    }
}
```

**Incorrect**:
```swift
// ❌ Runtime overhead for type safety
struct UserID {
    let uuid: UUID
    let type: String = "user"  // Runtime metadata - wasteful
}

// ❌ Using classes for phantom types (heap allocation)
class Tagged<Tag, Value> {  // ❌ Reference type
    let value: Value
}
```

**Rationale**: Phantom types provide compile-time guarantees (prevent mixing `UserID` and `OrderID`) with zero runtime cost. This is the Swift equivalent of Haskell's `newtype` or Rust's zero-cost newtypes.

**Cross-references**: [API-IMPL-002], [API-NAME-001]

---

## Cross-Platform Requirements

**Applies to**: All code that may run on multiple platforms.

**Does not apply to**: Platform-specific utilities or single-platform packages.

---

### [API-PLAT-001] Cross-Platform Requirements

**Scope**: Platform-specific code.

**Statement**:
- Platform selection MUST be centralized.
- Callers MUST NOT use `#if`.
- Handles MUST be opaque and platform-agnostic.
- Backends MUST satisfy the same contract:
  - `register`
  - `modify`
  - `deregister`
  - Deterministic shutdown
  - Defined behavior for late events (drop)

**Rationale**: Centralized platform selection enables consistent behavior and easier testing.

---

## Documentation and Comments

**Applies to**: All public API documentation and inline comments.

**Does not apply to**: Private implementation notes or TODO comments.

---

### [API-DOC-001] Documentation and Comments

**Scope**: All documentation and comments.

**Statement**:
- DocC (`///`) documents caller-visible behavior only.
- Implementation notes use non-DocC comments and must be concise.
- Documentation MUST state:
  - Executor guarantees
  - Cancellation behavior
  - Shutdown behavior
  - Resource scope limits

**Rationale**: Clear documentation of async behavior prevents misuse.

---

## Testing and Benchmarks

**Applies to**: All test and benchmark code in production packages.

**Does not apply to**: Exploratory tests, spike code, or ad-hoc debugging scripts.

---

### [API-TEST-001] Testing and Benchmarks

**Scope**: All testing strategies.

**Statement**:
- MUST provide deterministic tests for core invariants:
  - Fake backends
  - Explicit event injection
  - Exactly-once resume guarantees
  - Shutdown rejection and drain behavior
- Integration tests SHOULD exist per platform backend.
- Benchmarks SHOULD measure:
  - Throughput
  - p50 / p99 latency
  - Contention variance

**Rationale**: Deterministic tests catch bugs reliably; benchmarks prevent regressions.

---

## Design Validation

**Applies to**: Architectural decisions where multiple approaches exist.

**Does not apply to**: Purely aesthetic preferences without functional implications.

---

### [API-DESIGN-001] Subscript Syntax as Correct API for Type-Safe Containers

**Scope**: APIs providing type-keyed access to values (dependency containers, heterogeneous storage).

**Statement**: When implementing type-keyed containers in a modular system, subscript syntax with explicit type parameters (`container[Key.self]`) is the CORRECT API design, not a compromise. Property syntax (`container.key`) requires compile-time mappings from names to types that cannot exist in modular systems.

#### Why Property Syntax Cannot Work

Property syntax for type-keyed access would require:
1. **Implicit resolution** (Scala's `implicit`) - Swift lacks this
2. **Open type families** (extensible type-level mappings) - Swift lacks this
3. **Type-to-name reflection** (deriving `apiClient` from `APIClient`) - Swift lacks this

Without these features, there is no way to provide `context.apiClient` that resolves to a specific type without central registration—which defeats the purpose of modular, independently-compiled witness definitions.

**Correct**:
```swift
// Subscript with type parameter - works in modular systems
let client = context[APIClient.self]
let logger = values[Logger.self]

// The type parameter IS the name
extension Witness.Values {
    public subscript<W: Witness>(type: W.Type) -> W.Value {
        // Resolution uses W as the key
    }
}
```

**Incorrect**:
```swift
// ❌ Property syntax requiring central registration
let client = context.apiClient  // Requires @dynamicMemberLookup
type mapping
                                 // Which requires central registration
                                 // Which defeats modular witness definitions

// ❌ Attempting registry patterns
extension WitnessRegistry {
    static func register<W: Witness>(_ type: W.Type, name: String)
}
// Now every module must call register() at startup - fragile, order-dependent
```

#### Cross-Language Analysis as Design Tool

Examining how other languages solve a problem is a systematic design methodology, not idle curiosity. Each language's solution reveals a different point in the design space:

| Language | Solution | Why It Works |
|----------|----------|--------------|
| Scala (ZIO) | `implicit` resolution | Open resolution without registration |
| Haskell (mtl) | Type classes | Distributed `Has` instances |
| TypeScript (Effect-TS) | String tags | Explicit name mapping accepted |
| Swift | Type parameter subscript | Type parameter serves as name |

Swift's subscript solution achieves the same goal through different means. The type parameter `[Key.self]` serves as both identifier and type constraint—it is Swift's idiom for type-keyed access.

The exercise of sketching "ideal" syntax maps each desire to a specific missing feature. These sketches become specifications for what language evolution would need to provide—and proof that current constraints are real, not accidental.

**Rationale**: Proving an ergonomic desire is impossible within language constraints is as valuable as implementing it. The analysis prevents wasted effort exploring impossible paths and transforms the team's relationship to the API—there is no lingering sense that "we should find a better way." Design maturity includes knowing when to stop searching.

**Cross-references**: [API-NAME-002], [FUTURE-006]

---

### [API-DESIGN-002] Simplify When Features Don't Compose

**Scope**: API design decisions when Swift language features conflict.

**Statement**: When a language feature does not compose with another required feature, the correct response is simplification—removing the non-composing feature—rather than elaborate workarounds.

**Correct**:
```swift
// Typed throws desired, but Mutex.withLock cannot propagate typed errors
// Correct response: simplify to non-throwing API

extension Witness {
    public struct Preparation: ~Copyable, Sendable {
        // Non-throwing API - clean composition with Mutex
        public consuming func finalize() -> Witness.Values {
            storage.withLock { $0 }
        }
    }
}
```

**Incorrect**:
```swift
// ❌ Fighting the constraint with workarounds
extension Witness {
    public struct Preparation<E: Error>: ~Copyable, Sendable {
        // Typed throws with Result wrapper to work around Mutex limitation
        public consuming func finalize() -> Result<Witness.Values, E> {
            // Complex error threading...
        }
    }
}
// Adds complexity without achieving the goal cleanly
```

#### Categories of Non-Composition

| Constraint Type | Response |
|-----------------|----------|
| **Fundamental** (Atomic's non-copyability, macro declaration rules) | Adapt immediately |
| **Accidental** (Mutex's throwing limitation) | Still adapt—fighting wastes more time |
| **Temporary** (Swift version gap) | Document and adapt; revisit when Swift evolves |

**Rationale**: Elaborate workarounds add complexity, obscure intent, and create maintenance burden. Simplification often produces better APIs than the original design would have—constraints reveal over-specification.

**Cross-references**: [API-EXC-001], [API-IMPL-004]

---

### [API-DESIGN-003] Separate Policy from Storage

**Scope**: Types that store data and may behave differently in different contexts.

**Statement**: Storage types MUST be inert—they hold data but do not interpret it. Policy types interpret data. Storage and policy MUST NOT be mixed in the same type when the data might cross context boundaries.

**Correct**:
```swift
// Storage is inert - holds data only
public struct Values: Sendable {
    var overrides: [ObjectIdentifier: Any]
    var storage: Storage  // Cache reference
}

// Policy is separate - interprets data
public struct Context: Sendable {
    public enum Mode { case live, test, preview }
    let mode: Mode
    let values: Values

    // Policy determines behavior
    public func value<W: Witness>(_: W.Type) -> W.Value {
        switch mode {
        case .test: return values.testValue(W.self)
        case .live: return values.liveValue(W.self)
        case .preview: return values.previewValue(W.self)
        }
    }
}
```

**Incorrect**:
```swift
// ❌ Storage carries its own policy
public struct Values: Sendable {
    var isTestContext: Bool  // Policy mixed into storage
    var overrides: [ObjectIdentifier: Any]

    public func value<W: Witness>(_: W.Type) -> W.Value {
        if isTestContext { ... }  // Storage interprets itself
    }
}
// Problem: Values prepared at app launch (isTestContext: false)
// inherited into test scope carries wrong policy
```

#### Why Separation Matters

| Concern | Consequence of Mixing |
|---------|----------------------|
| Inheritance | Child contexts inherit wrong policy |
| Reuse | Same data can't behave differently in different contexts |
| Testing | Test values carry production policy flags |
| Debugging | Policy state hidden inside storage |

The same `Values` instance might be used in different contexts. A values container prepared at app launch (mode: `.live`) might be inherited into a test scope. If mode were stored in Values, inheritance would carry the wrong policy.

**Rationale**: Storage types should be pure data. Policy types should interpret data. Mixing them creates subtle bugs when the same data crosses policy boundaries. Separation makes policy visible and data reusable.

**Cross-references**: [API-IMPL-002], [API-IMPL-010], [PATTERN-020]

---

### [API-DESIGN-004] Empirical Measurement Resolves Design Debates

**Scope**: Design decisions where multiple approaches have theoretical merit.

**Statement**: When design debates become theoretical—with arguments citing patterns, precedents, and abstractions on both sides—empirical measurement MUST be introduced to ground the discussion. Measurement takes precedence over theoretical argumentation.

#### Measurement Techniques by Concern

| Design Concern | Measurement Approach |
|----------------|---------------------|
| API usage patterns | Search/grep for actual usage across codebase |
| Type frequency | Count instances of each type variant |
| "Primary" vs "secondary" claims | Quantify which is actually used more |
| Performance assertions | Benchmark the alternatives |
| "Typical" usage claims | Verify against actual call sites |

**Correct**:
```
Design debate: Reference<T> (outer-generic) vs Reference.Box (namespace)?

Theoretical arguments (unresolved):
- "Array<Element> precedent supports outer-generic"
- "Types form hierarchy rooted at immutable box"
- "Namespace patterns suit peer groupings"

Empirical resolution (30 seconds):
 21
 8
 37

Result: Transfer dominates. No canonical "root" type exists.
Conclusion: Namespace pattern is correct—premises falsified by data.
```

**Incorrect**:
```
Design debate continues for hours through theoretical territory.
Each side cites valid precedents (Array<Element>, peer groupings).
Neither party stops to verify claims about "typical usage."
Decision made based on argument persuasion, not evidence.

❌ Ungrounded debates waste time and may reach wrong conclusions.
```

#### When to Measure

Measurement is REQUIRED when:
1. Both positions cite valid precedents or patterns
2. Arguments rest on claims about "typical usage" or "primary abstractions"
3. The debate has cycled through the same points more than twice
4. A hidden premise could be empirically verified or falsified

The measurement need not be perfect—a crude grep across the workspace often suffices. What matters is that *something empirical* enters the discussion.

**Rationale**: Theoretical arguments can continue indefinitely when both sides have valid points. Each position seems defensible on its own terms. Empirical measurement—even imperfect measurement—introduces data that can falsify premises. The grep takes 30 seconds; the ungrounded debate can take hours. This applies beyond API design to package organization, module boundaries, and abstraction choices.

**Cross-references**: [API-DESIGN-001], [API-DESIGN-002], [API-DESIGN-005]

---

## Exceptions

**Applies to**: Any deviation from these requirements.

---

### [API-EXC-001] Exceptions

**Scope**: Deviations from requirements.

**Statement**: Exceptions are allowed only when:
- Correctness demands it
- The language forces it
- Ergonomics are overwhelming and unavoidable

Any exception MUST be:
- Explicitly documented
- Narrowly scoped
- Covered by tests that lock in behavior

**Rationale**: Explicit exceptions maintain document integrity while allowing pragmatic choices.

---

## Topics

### Related Documents

- <doc:Primitives-Architecture>
- <doc:Implementation-Patterns>
- <doc:Testing-Requirements>
- <doc:Documentation-Requirements>

### Process Documents

- <doc:Reflections-Consolidation>
- <doc:Documentation-Maintenance>
