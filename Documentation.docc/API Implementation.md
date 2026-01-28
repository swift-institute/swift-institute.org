# API Implementation

<!--
---
title: API Implementation
version: 1.0.0
last_updated: 2026-01-18
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Implementation patterns and requirements for code organization, construction, and performance.

## Overview

This document defines the implementation style requirements for Swift Institute packages. These patterns ensure consistent, performant, and maintainable code across all packages.

**Applies to**: All implementation code in production packages.

**Does not apply to**: Test fixtures, mocks, or temporary exploration code.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## Document Structure

| Section | Requirements | Focus |
|---------|--------------|-------|
| [Construction and Transformation](#construction-and-transformation) | 1 | Type construction patterns |
| [Core Types](#core-types) | 2 | State machines, totality |
| [Code Organization](#code-organization) | 4 | File structure, awaiting features, inlining |
| [Global State and Helpers](#global-state-and-helpers) | 2 | No hidden state, no ad-hoc helpers |
| [Advanced Patterns](#advanced-patterns) | 5 | Capability injection, effects, phantom types, value generics |

---

## Construction and Transformation

**Applies to**: Type construction and value transformation APIs.

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

**Rationale**: Initializers and static methods make construction explicit and discoverable. Fallibility is expressed via `throws`, not labels—see <doc:API-Errors#API-ERR-008>.

**Cross-references**: [API-NAME-006], [API-ERR-008]

---

## Core Types

**Applies to**: Core type definitions and primitive packages.

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

// Mode enum instead of boolean
enum Mode { case live, preview, test }
```

**Incorrect**:
```swift
// ❌ Boolean flags for state
struct Connection {
    var isConnecting: Bool
    var isConnected: Bool
    var session: Session?
}

// ❌ Boolean hiding adjacent states
var isTestContext: Bool  // What is "not-test"? Production? Preview?
```

#### Booleans Hide Adjacent States

When you see a boolean controlling behavior, ask: "Are there really only two states, or did we collapse a third into one of them?"

| Boolean | Hidden State | What It Collapses |
|---------|--------------|-------------------|
| `isTestContext` | Preview mode | Is SwiftUI preview test=true or false? |
| `isDebug` | Staging environment | Development, staging, and debug conflated |
| `isEnabled` | Degraded mode | "Enabled but with errors" hidden |
| `isAuthenticated` | Expired session | "Authenticated but token expired" |

```swift
// Boolean implies two states
var isTestContext: Bool  // test vs not-test

// Reality: at least three contexts
enum Mode {
    case live      // Production
    case preview   // SwiftUI/design-time preview
    case test      // Automated testing
}
// Each resolves to different values (liveValue, previewValue, testValue)
```

The enum forces explicit naming of states that booleans collapse by omission.

**Rationale**: Explicit state machines make invalid states unrepresentable. Booleans lie by omission—they imply two states when three or more often exist.

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

## Code Organization

**Applies to**: File organization, code structure, and performance annotations.

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

## Global State and Helpers

**Applies to**: All code regarding state management and helper functions.

---

### [API-IMPL-010] No Hidden Global State

**Scope**: All code.

**Statement**:
- Avoid singletons.
- Avoid global mutable storage.
- Any global configuration MUST be explicit, immutable, and testable.
- When state requires setup, use scoped APIs that enforce lifecycle through structure.

#### Scoped APIs vs One-Shot APIs

If documentation promises "call once at startup" or "values are scoped," the API MUST enforce that promise structurally.

**Correct**:
```swift
// Scoped API - structure enforces lifecycle
await Witness.Preparation.with { store in
    store.set(API.self, value: .live)
} operation: {
    // Prepared values available here
    // Automatically cleaned up after
}
// Scope enforces:
// - Values exist only within operation
// - Cleanup is automatic
// - Nested scopes compose correctly
// - TaskLocal means child tasks inherit, siblings don't interfere
```

**Incorrect**:
```swift
// ❌ One-shot global API - documentation-only enforcement
Witness.Preparation.prepare { values in
    values[API.self] = .live
}
// Documentation says "call once at startup"
// But nothing enforces this:
// - Calling twice silently overwrites
// - Calling mid-execution changes behavior for in-flight operations
// - Global mutex is mutable state with honor-system access control
```

#### The Enforcement Principle

| Documentation Promise | Structural Enforcement |
|----------------------|----------------------|
| "Call once at startup" | `~Copyable` type consumed by setup |
| "Values are scoped" | Closure-based API with automatic cleanup |
| "Must call in order" | Typestate progression (`Init` → `Ready` → `Running`) |
| "Thread-safe" | Actor isolation or mutex by construction |

If the API can be misused in ways the documentation forbids, the API is incomplete.

**Rationale**: Hidden global state makes code untestable and creates implicit dependencies. Scoped APIs make documentation promises enforceable—if values are scoped, the API enforces scoping through structure, not through user discipline.

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

**Cross-references**: [API-NAME-006], [API-IMPL-001], <doc:Ecosystem-Process#ECO-REUSE-002>

---

## Advanced Patterns

**Applies to**: Capability injection, effect-based design, and type-level programming.

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

### [API-IMPL-017] Domain Boundary Types Guard Implicit Policy

**Scope**: APIs that cross semantic domain boundaries.

**Statement**: When data crosses semantic domain boundaries, distinct types MUST guard each domain. Return types MUST reflect the domain that produced the value, not the domain that will consume it.

#### The Principle

Every implicit conversion embeds a policy decision. When code silently converts between types, it makes assumptions about encoding, error handling, and validation that may not match the caller's needs.

**Correct**:
```swift
// Syscall wrapper returns kernel domain type
extension ISO_9945 {
    public static func realpath(_ path: Kernel.Path) throws(Kernel.Error) -> Kernel.String
}

// API communicates: "I give you path bytes as the OS returned them.
// Interpreting those bytes as text is your responsibility."

// Explicit conversion at call site - policy is visible
let resolved = try ISO_9945.realpath(kernelPath)
let text = try Swift.String(decoding: resolved, as: UTF8.self)  // Caller chooses encoding
```

**Incorrect**:
```swift
// ❌ Syscall wrapper performs implicit conversion
extension ISO_9945 {
    public static func realpath(_ path: String) throws -> String
    // Hidden: What if the filesystem path isn't valid UTF-8?
    // Hidden: What encoding does this assume?
    // Hidden: Does invalid encoding throw, crash, or substitute?
}
```

#### Domain-Specific String Types

Each string type guards a different domain:

| Type | Domain | Guards |
|------|--------|--------|
| `String_Primitives.String` | OS-native code units | Platform ABI |
| `Kernel.String` | Kernel operations | Syscall boundaries |
| `ISO_9899.String` | C specification bytes | C ABI |
| `Swift.String` | Unicode text | Human readability |

Each boundary crossing is a policy decision:
- Encoding choice (UTF-8? UTF-16? lossy?)
- Error handling (throw? substitute? crash?)
- Validation (strict? permissive?)

These decisions belong at the call site, not buried in low-level wrappers.

#### Layers and Policy

| Layer | Responsibility |
|-------|----------------|
| Primitives | Storage and code units |
| Standards | Syscall wrapping, domain types |
| Foundations | Policy decisions, conversions |
| Applications | Domain-specific interpretation |

The Standards layer (syscall wrappers) stays honest: it wraps syscalls, nothing more. Policy lives in Foundations, where it can be explicit and configurable.

**Rationale**: On systems with non-UTF8 filenames (they exist), converting kernel output to `Swift.String` can fail or corrupt data. The syscall wrapper cannot make that policy decision—it doesn't know if the caller wants lossy conversion, error propagation, or something else. Explicit boundaries force these decisions to the surface.

**Cross-references**: [API-IMPL-002], [API-ERR-001], [PRIM-FOUND-003]

---

## Topics

### Related Documents

- <doc:Memory>
- <doc:API-Requirements>
- <doc:API-Errors>
- <doc:API-Design>
- <doc:Primitives-Architecture>
- <doc:Implementation>

### Process Documents

- <doc:Ecosystem-Process>
- <doc:Documentation-Maintenance>
