# Implementation Patterns

@Metadata {
    @TitleHeading("Swift Institute")
}

C shims, multi-library products, circular dependency breaking, and Swift 6 features.

## Overview

This document defines implementation patterns for Swift Institute packages. These patterns address infrastructure concerns: platform integration, dependency management, and Swift language feature adoption.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## C Shim Architecture

**Applies to**: Packages requiring platform-specific functionality (math primitives, system calls, hardware access).

**Does not apply to**: Pure Swift packages with no platform dependencies.

---

### C Shim Layer Structure

**Scope**: Package organization for platform-specific code.

**Statement**: Where platform-specific functionality is required, packages MUST use minimal C shim targets isolated from Swift code.

**Correct**:
```
swift-numeric-primitives/
├── _Shims/                          # C target
│   └── include/
│       └── shims.h                  # C declarations (sin, cos, exp, etc.)
└── Real Primitives/
    └── Numeric.Math.swift           # Swift wrapper
```

**Incorrect**:
```
swift-numeric-primitives/
└── Real Primitives/
    ├── Numeric.Math.swift
    └── platform_shims.c             # ❌ C code mixed with Swift
```

The C shim layer:
- Isolates platform-specific inline assembly
- Provides unified interface across Darwin (libm), Glibc, Musl
- Remains internal—not exposed in public API

**Rationale**: Isolating C code minimizes unsafe code exposure while providing access to platform primitives. Separation enables independent testing and platform-specific optimization.

---

## Multi-Library Products

**Applies to**: Complex packages with separable functionality.

**Does not apply to**: Simple packages with a single coherent API surface.

---

### Fine-Grained Library Exposure

**Scope**: Package product definitions.

**Statement**: Complex packages SHOULD expose multiple libraries for fine-grained dependency management.

**Correct**:
```swift
// swift-numeric-primitives/Package.swift
products: [
    .library(name: "Numeric Primitives", targets: ["Numeric Primitives"]),
    .library(name: "Real Primitives", targets: ["Real Primitives"]),
    .library(name: "Integer Primitives", targets: ["Integer Primitives"]),
]
```

**Incorrect**:
```swift
// ❌ Single monolithic library
products: [
    .library(name: "Numeric Primitives", targets: [
        "Numeric Primitives",
        "Real Primitives",
        "Integer Primitives",
        "Complex Primitives",
    ]),
]
```

A downstream package needing only integer operations can depend on `Integer Primitives` without pulling in transcendental functions.

**Rationale**: Fine-grained libraries reduce compilation time and binary size. Consumers import only what they need.

---

## Circular Dependency Breaking

**Applies to**: Packages with potential circular dependencies with test frameworks.

**Does not apply to**: Packages without test framework dependencies in their core target.

---

### Nested Test Package Pattern

**Scope**: Test target organization.

**Statement**: When packages face potential circular dependencies with swift-testing, the package MUST use nested test packages.

**Correct**:
```
swift-identity-primitives/
├── Package.swift                    # Main package (no test target)
└── Tests/
    └── Package.swift                # Separate package for tests
        └── depends on swift-testing
```

**Incorrect**:
```swift
// ❌ Test target in main package creates circular dependency
// swift-identity-primitives/Package.swift
targets: [
    .target(name: "Identity Primitives"),
    .testTarget(
        name: "Identity Primitives Tests",
        dependencies: [
            "Identity Primitives",
            .product(name: "Testing", package: "swift-testing"),  // ❌ Circular
        ]
    ),
]
```

This breaks the cycle: `swift-testing` depends on primitives, but primitives' tests (in a separate package) depend on `swift-testing`.

**Rationale**: Nested test packages decouple test dependencies from the main package, eliminating circular dependency errors.

---

## Conditional Platform Compilation

**Applies to**: Platform-specific target dependencies.

**Does not apply to**: Platform-agnostic code.

---

### SwiftPM Platform Conditions

**Scope**: Target dependency declarations.

**Statement**: Platform-specific dependencies MUST use SwiftPM condition directives to exclude incompatible platforms.

**Correct**:
```swift
.product(
    name: "X86 Primitives",
    package: "swift-x86-primitives",
    condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .linux, .windows])
),
.product(
    name: "ARM Primitives",
    package: "swift-arm-primitives",
    condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .linux])
)
```

**Incorrect**:
```swift
// ❌ No condition - ARM code compiled on x86
.product(name: "ARM Primitives", package: "swift-arm-primitives"),
```

This ensures ARM-specific code is not compiled (or linked) on x86 targets, and vice versa.

**Rationale**: Platform conditions prevent compilation errors and reduce binary size by excluding irrelevant platform code.

---

### Source-Level Platform Conditionals

**Scope**: `#if` directives in Swift source files for platform-specific code paths.

**Statement**: For platform identity checks, `#if os()` MUST be used instead of `#if canImport()`. `canImport` is appropriate only when checking for optional module availability, not for platform identity.

**Correct**:
```swift
// Platform identity - use os()
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import Darwin_Kernel_Primitives
#elseif os(Linux)
import Linux_Kernel_Primitives
#elseif os(Windows)
import Windows_Kernel_Primitives
#endif
```

**Incorrect**:
```swift
// ❌ canImport for platform identity
#if canImport(Darwin_Kernel_Primitives)
import Darwin_Kernel_Primitives
#elseif canImport(Linux_Kernel_Primitives)
import Linux_Kernel_Primitives
#endif
// Problem: canImport can succeed based on module availability
// even when the module shouldn't be used on this platform
```

#### Why `os()` Over `canImport`

| Check | Evaluated Against | Determinism |
|-------|-------------------|-------------|
| `os()` | Target triple | Always deterministic |
| `canImport()` | Module resolution | Varies by build system, module search paths |

`canImport` creates a dependency on module resolution order, which can vary between build systems (SwiftPM, Xcode, Bazel). `os()` checks are evaluated purely on target triple, independent of what modules exist.

**When `canImport` IS Appropriate**:
```swift
// Optional feature detection - canImport is correct
#if canImport(SwiftUI)
import SwiftUI
// Use SwiftUI features
#else
// Fallback without SwiftUI
#endif
```

Use `canImport` when checking for optional modules that may or may not be available on a platform. Use `os()` when establishing platform identity.

**Rationale**: For platform conditionals, determinism matters more than elegance. `os()` guarantees consistent behavior across all build environments.

---

### Module Name Normalization

**Scope**: Import statements and fully-qualified type paths.

**Statement**: Swift normalizes Package.swift target names containing spaces by replacing spaces with underscores. Import statements MUST use the normalized form.

**Correct**:
```swift
// Package.swift target: "Darwin Kernel Primitives"
// Import uses underscores:
import Darwin_Kernel_Primitives

// Fully-qualified type path:
let uuid = Darwin_Kernel_Primitives.Darwin.Identity.UUID.parse(string)
```

**Incorrect**:
```swift
// ❌ Using spaces (syntax error)
import Darwin Kernel Primitives

// ❌ Concatenating without underscores
import DarwinKernelPrimitives  // Module not found

// ❌ Using hyphens
import Darwin-Kernel-Primitives  // Syntax error
```

#### Normalization Rule

| Package.swift Target | Import Identifier |
|---------------------|-------------------|
| `"Darwin Kernel Primitives"` | `Darwin_Kernel_Primitives` |
| `"Real Primitives"` | `Real_Primitives` |
| `"IO Primitives"` | `IO_Primitives` |

The normalization is invisible until you need to reference it in import statements or fully-qualified type paths. The underscore convention applies to all targets with spaces.

**Rationale**: Understanding the normalization rule prevents confusion when imports fail. Swift requires valid identifiers, and underscores replace spaces automatically.

---

### C Library Linker Flags

**Scope**: Package.swift configuration for platform-specific C library dependencies.

**Statement**: When a platform requires linking against a C library not automatically provided by the system, linker settings MUST declare the dependency explicitly with platform conditions.

**Correct**:
```swift
// Package.swift for Linux primitive requiring libuuid
targets: [
    .target(
        name: "Linux Kernel Primitives",
        dependencies: [...],
        linkerSettings: [
            .linkedLibrary("uuid", .when(platforms: [.linux]))
        ]
    )
]
```

**Incorrect**:
```swift
// ❌ No linker flag - link error on Linux
targets: [
    .target(
        name: "Linux Kernel Primitives",
        dependencies: [...]
        // Missing: .linkedLibrary("uuid")
    )
]

// ❌ Unconditional - breaks on platforms without libuuid
linkerSettings: [
    .linkedLibrary("uuid")  // Fails on Darwin, Windows
]
```

#### Platform Library Requirements

| Platform | Library | Linked By Default | Notes |
|----------|---------|-------------------|-------|
| Darwin | libc (uuid_parse) | Yes | Part of system library |
| Linux | libuuid | No | Requires `-luuid`, libuuid-dev package |
| Windows | Rpcrt4.lib | Yes | Part of Windows SDK |

Linux's modular library architecture is the exception. Darwin and Windows include UUID functions in their default system libraries. The linker flag captures Linux's requirement explicitly.

**Documentation Requirement**: When a package requires external library installation (like `libuuid-dev`), the README MUST document this prerequisite.

**Rationale**: Explicit linker flags make C-level dependencies visible and prevent mysterious link failures. Platform conditions ensure the flag only applies where needed.

---

## Swift Language Features

**Applies to**: All packages in swift-primitives, swift-institute, and swift-standards.

**Does not apply to**: External dependencies or generated code.

---

### Swift 6 Language Mode

**Scope**: Package manifest configuration.

**Statement**: All packages MUST require Swift 6.2+ and use Swift 6 language mode.

**Correct**:
```swift
// Package.swift
swift-tools-version: 6.2
platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26), .watchOS(.v26), .visionOS(.v26)]
swiftLanguageModes: [.v6]
```

**Incorrect**:
```swift
// ❌ Outdated Swift version
swift-tools-version: 5.9
swiftLanguageModes: [.v5]
```

All packages MUST support Darwin, Linux, Windows, POSIX, and Swift Embedded.

This enables:
- Complete concurrency checking
- Strict sendability enforcement
- Actor isolation guarantees

**Rationale**: Swift 6 provides compile-time concurrency safety that eliminates entire categories of runtime bugs.

---

### Memory Safety Warnings as Design Feedback

**Scope**: Handling Swift 6 strict memory safety diagnostics.

**Statement**: `#StrictMemorySafety` warnings MUST be treated as design feedback, not noise. Each warning marks a site requiring eventual `unsafe` annotation. Warnings serve as a TODO list for explicit danger acknowledgment.

**The Compiler as Collaborator**:

Swift 6's expanded safety checks flag every raw pointer operation, every `kevent` structure access, every C interop call. These aren't bugs—they're the compiler demanding acknowledgment of unsafe operations.

```swift
// These operations will emit warnings until marked unsafe:
let ptr = UnsafeMutablePointer<kevent>.allocate(capacity: 64)
ptr.initialize(repeating: .init(), count: 64)
kevent(kq, ptr, 0, ptr, 64, nil)  // C function call
```

**Correct Response**:
```swift
// Track warnings as technical debt
// TODO: Mark with @unsafe when stabilized
unsafe {
    let ptr = UnsafeMutablePointer<kevent>.allocate(capacity: 64)
    // ...
}
```

**Incorrect Response**:
```swift
// ❌ Silencing warnings without tracking
@_silenceWarnings  // Hiding the problem
// or
// Ignoring warnings entirely
```

#### Treatment of Safety Warnings

| Warning Type | Response | Timeline |
|--------------|----------|----------|
| Pointer operations | Track for `unsafe` annotation | When syntax stabilizes |
| C interop calls | Track for `unsafe` annotation | When syntax stabilizes |
| Concurrency isolation | Fix immediately | Now |

The warnings make danger visible in the build output. When the `unsafe` keyword syntax stabilizes, these sites will be annotated, making danger visible in source code.

**Rationale**: The compiler doesn't prevent the work—it demands awareness. Treating safety warnings as collaborative feedback rather than annoyance improves code quality and prepares for future language evolution.

---

### Upcoming Feature Flags

**Scope**: SwiftSettings configuration.

**Statement**: Packages SHOULD enable upcoming Swift features for forward compatibility.

**Correct**:
```swift
swiftSettings: [
    .enableUpcomingFeature("ExistentialAny"),
    // Forces explicit `any` keyword for existentials

    .enableUpcomingFeature("InternalImportsByDefault"),
    // Makes imports internal by default

    .enableUpcomingFeature("MemberImportVisibility"),
    // Controls member visibility on imported types
]
```

**Incorrect**:
```swift
// ❌ No upcoming features - code will break in future Swift versions
swiftSettings: []
```

**Rationale**: Upcoming features improve API hygiene and will become defaults in future Swift versions. Early adoption prevents migration pain.

---

### Experimental Feature Flags

**Scope**: Memory-critical and performance-critical packages.

**Statement**: Memory-critical packages MAY enable experimental features when compile-time resource verification is required.

**Correct**:
```swift
swiftSettings: [
    .enableExperimentalFeature("Lifetimes"),
    // Noncopyable types with ~Copyable

    .enableExperimentalFeature("LifetimeDependence"),
    // Tracks dependencies between object lifetimes
]
```

These features enable compile-time verification of resource management, eliminating runtime checks for correctness that can be proven statically.

**Rationale**: Experimental lifetime features enable move-only semantics required for zero-copy resource management.

---

### Parameter Packs for N-Ary Types

**Scope**: Types requiring heterogeneous collections with compile-time dimension tracking.

**Statement**: Packages requiring n-ary heterogeneous products SHOULD use Swift's parameter packs.

**Correct**:
```swift
struct Product<each Element> {
    var elements: (repeat each Element)
}

// Usage: type-safe heterogeneous tuple
let product = Product(elements: (1, "hello", 3.14))
```

**Incorrect**:
```swift
// ❌ Type-erased heterogeneous collection
struct Product {
    var elements: [Any]
}
```

**Rationale**: Parameter packs enable type-safe heterogeneous tuples with compile-time dimension tracking, preserving type information that `Any` arrays lose.

---

## Anti-Patterns

**Applies to**: All implementation code in Swift Institute packages.

**Does not apply to**: External dependencies or third-party code.

This section documents common mistakes to avoid when implementing Swift Institute packages.

---

### No Foundation Types

**Scope**: All primitive and standard packages.

**Statement**: Primitive and standard packages MUST NOT use Foundation types.

**Correct**:
```swift
import Buffer_Primitives
import Temporal_Primitives
func parse(_ buffer: Buffer) -> Instant { ... }
```

**Incorrect**:
```swift
// ❌ Foundation dependency
import Foundation
func parse(_ data: Data) -> Date { ... }
```

**Rationale**: Foundation types prevent Swift Embedded deployment and introduce platform-specific behavior differences.

---

### Nested Type Names

**Scope**: All type declarations.

**Statement**: Types MUST use nested namespaces, not compound names.

**Correct**:
```swift
enum PDF {
    struct Page { }
    struct Document { }
}
// Usage: PDF.Page, PDF.Document
```

**Incorrect**:
```swift
// ❌ Compound names
struct PDFPage { }
struct PDFDocument { }
```

**Rationale**: Nested types provide namespace organization and read as `PDF.Page`, matching specification terminology. Type `PDF.` and autocomplete reveals the entire domain.

---

### Typed Error Enums

**Scope**: All error types.

**Statement**: Errors MUST be typed enums with associated values, not string-based errors.

**Correct**:
```swift
enum ParseError: Error {
    case invalidHeader(expected: UInt32, found: UInt32)
}
throw ParseError.invalidHeader(expected: 0x25504446, found: header)
```

**Incorrect**:
```swift
// ❌ String errors
throw NSError(domain: "Parser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid header"])
```

**Rationale**: Typed errors enable exhaustive switch handling and preserve diagnostic information for programmatic error recovery.

---

### Initializers as Canonical Implementation

**Scope**: Type transformations and conversions.

**Statement**: Canonical implementation for type transformations MUST live in initializers or static methods on the target type. Instance methods are convenience wrappers only.

**Correct**:
```swift
extension Radian {
    init(_ degrees: Degree) { ... }  // Canonical
}
extension Degree {
    var asRadians: Radian { Radian(self) }  // Convenience only
}
```

**Incorrect**:
```swift
// ❌ Method as canonical
extension Angle {
    func toRadians() -> Double { ... }  // Where is the real logic?
}
```

**Rationale**: Initializers on the target type make the transformation discoverable via autocomplete on the target type. The canonical implementation has a single, predictable location.

---

### Concrete Types Before Abstraction

**Scope**: Protocol and generic type design.

**Statement**: Abstractions MUST emerge from concrete implementations. Protocols MUST NOT be designed before having 3+ concrete conformers.

**Correct**:
```swift
// Start concrete
struct Circle<T: BinaryFloatingPoint> {
    var center: Point<2, T>
    var radius: T
}
// Abstract only when you have 3+ concrete conformers
```

**Incorrect**:
```swift
// ❌ Abstract for hypotheticals
protocol GeometricShape {
    associatedtype Coordinate
    func contains(_ point: Coordinate) -> Bool
    func intersects(_ other: Self) -> Bool
    // ... 20 more requirements
}
```

**Rationale**: Premature abstraction creates protocols that do not fit real use cases. Concrete implementations reveal actual requirements before abstracting.

---

### Linear Types for Invariant Enforcement

**Scope**: Types that encode exactly-once or at-most-once semantics.

**Statement**: When an invariant requires that a value be used exactly once (linear) or at most once (affine), the type MUST be `~Copyable`. The `consuming` keyword and `deinit` MUST encode the invariant at the type level.

This pattern moves invariants from "things humans must remember" to "things the compiler enforces."

**Correct**:
```swift
/// A continuation that must be resumed exactly once.
public struct Continuation<T>: ~Copyable, Sendable {
    private let resume: @Sendable (T) -> Void

    public init(_ resume: @escaping @Sendable (T) -> Void) {
        self.resume = resume
    }

    /// Consumes the continuation, resuming it with a value.
    /// After this call, the continuation cannot be used again.
    public consuming func callAsFunction(_ value: T) {
        resume(value)
    }

    deinit {
        // If deinit runs, the continuation was never resumed - this is a bug.
        // In debug builds, trap. In release, the type system already prevented
        // double-resume at compile time.
        preconditionFailure("Continuation was dropped without being resumed")
    }
}

// Compiler enforces exactly-once:
func example(_ cont: consuming Continuation<Int>) {
    cont(42)        // ✓ Consumes the continuation
    // cont(43)     // ❌ Compile error: 'cont' used after consume
}

// Cannot forget to resume:
func badExample(_ cont: consuming Continuation<Int>) {
    // Function returns without calling cont
}  // ❌ deinit traps: continuation dropped
```

**Incorrect**:
```swift
// ❌ Comment-based invariant - not enforced
/// Must be called exactly once!
class Continuation<T> {
    private var resumed = false

    func resume(_ value: T) {
        precondition(!resumed, "Already resumed")  // Runtime check
        resumed = true
        // ...
    }
    // Nothing prevents forgetting to resume
}

// ❌ Boolean tracking - runtime enforcement only
struct Continuation<T> {
    private var hasResumed = false
    mutating func resume(_ value: T) { ... }  // Copies allowed!
}
```

#### Exactly-Once vs At-Most-Once

| Semantics | Implementation |
|-----------|----------------|
| **Exactly-once** | `~Copyable` + `consuming func` + `deinit` with precondition |
| **At-most-once** | `~Copyable` + `consuming func` + silent `deinit` |

For exactly-once (linear), the `deinit` traps if the value wasn't consumed—dropping without use is a bug. For at-most-once (affine), the `deinit` is silent—dropping without use is valid.

#### Integration with Ownership System

The `consuming` keyword is critical:
- Prevents use after consumption at compile time
- Makes the exactly-once nature visible in function signatures
- Works with borrowing/inout for temporary access without consumption

```swift
extension Continuation {
    /// Observes the continuation without consuming it.
    public borrowing func onResume(_ observer: @escaping (T) -> Void) -> Self {
        // Return a new continuation that notifies the observer
        Continuation { value in
            observer(value)
            self.resume(value)
        }
    }
}
```

**Rationale**: Linear and affine types encode resource semantics at the type level. The compiler becomes a proof assistant for exactly-once usage, eliminating double-resume and forgotten-resume bugs that plague callback-based APIs. This is the Swift equivalent of Rust's ownership system for semantic invariants.

---

### Macro Naming Exception

**Scope**: Swift macro declarations.

**Statement**: Swift macros MUST be declared at file scope. Macros CANNOT be nested in extensions or types. When the nesting convention would produce `@Namespace.MacroName`, the macro MUST instead use a compound name: `@NamespaceMacroName`.

This is a language limitation that overrides the design convention. Documentation MUST acknowledge such exceptions explicitly rather than pretending the nesting convention is universal.

**Correct**:
```swift
// Macro at file scope with compound name
@attached(member, names: named(init), named(scope))
public macro WitnessScope() = #externalMacro(...)

// Usage
@WitnessScope
struct MyDependencies { ... }
```

**Incorrect**:
```swift
// ❌ Cannot nest macro in extension - compiler rejects this
extension Witness {
    @attached(member, names: named(init), named(scope))
    public macro Scope() = #externalMacro(...)  // Error: macro must be at file scope
}
```

#### Why Nesting Fails

Swift's macro declarations require file-scope visibility for:
1. Compiler plugin resolution
2. Module-level symbol registration
3. Cross-module macro availability

The `@attached` and `@freestanding` attributes work only on file-scope declarations.

#### Naming Guidance for Macros

| Intended Namespace | Macro Name | Rationale |
|--------------------|------------|-----------|
| `Witness.Scope` | `@WitnessScope` | Compound name required |
| `Effect.Generator` | `@EffectGenerator` | Compound name required |
| `Codable.Custom` | `@CodableCustom` | Compound name required |

The compound name preserves the namespace association while satisfying the language constraint.

**Rationale**: Language limitations sometimes override design conventions. Acknowledging these exceptions explicitly—with documented rationale—maintains convention integrity while accommodating compiler requirements. The exception is narrow (macros only) and the rationale is clear (language constraint).

---

### Move-Only Types as Proof Assistants

**Scope**: Types encoding resource linearity or exactly-once semantics.

**Statement**: When `~Copyable` types with `consuming func` are used to enforce exactly-once semantics, the ownership system functions as a compile-time proof assistant. The pattern should be recognized as such and applied systematically to any "exactly once" or "at most once" invariant.

This pattern extends with the observation that Swift's ownership system is not merely a resource management tool—it is a proof system for linear logic.

**Proof Categories**:

| Invariant | Ownership Encoding | Compiler Enforcement |
|-----------|-------------------|---------------------|
| Exactly-once use | `~Copyable` + `consuming func` + `deinit` trap | Double-use caught at compile time; dropped-without-use caught at runtime |
| At-most-once use | `~Copyable` + `consuming func` + silent `deinit` | Double-use caught at compile time; unused is valid |
| Transfer semantics | `consuming` parameter | Caller cannot use value after transfer |
| Borrow semantics | `borrowing` parameter | Callee cannot consume or store |

**Example Applications**:

```swift
// Witness.Scope - exactly-once scope consumption
public struct Scope: ~Copyable, Sendable {
    public consuming func finalize() -> Witness.Values {
        // Consumes scope, returns values
    }

    deinit {
        preconditionFailure("Scope dropped without calling finalize()")
    }
}

// Effect.Continuation.One - exactly-once continuation
public struct One<T>: ~Copyable, Sendable {
    public consuming func resume(returning value: T) {
        // Consumes continuation
    }

    deinit {
        preconditionFailure("Continuation dropped without resuming")
    }
}
```

The same pattern structure appears in both—different domains, same proof obligation.

**Rationale**: Recognizing `~Copyable` as a proof assistant rather than just a memory optimization changes how developers approach API design. Any invariant expressible as "exactly N times" or "at most N times" should trigger consideration of ownership-based enforcement.

---

### Fallback as Feature, Not Compromise

**Scope**: APIs with optimized paths that may not handle all cases.

**Statement**: When a native/optimized path handles only a subset of cases, the fallback to a slower but complete path is an intentional feature, not defensive programming. The API SHOULD accept all valid inputs and route internally.

**Correct**:
```swift
// Parser accepts both formats, routes internally
public static func parse(_ string: String) -> UUID? {
    if string.count == 36 {
        // Native path: handles hyphenated format (common case)
        if let uuid = nativeParse(string) { return uuid }
    }
    // Swift path: handles compact format or fallback
    return pureSwiftParse(string)
}
```

**Incorrect**:
```swift
// ❌ Forcing callers to pre-validate
public static func parseHyphenated(_ string: String) -> UUID?  // Native
public static func parseCompact(_ string: String) -> UUID?     // Swift fallback
// Caller must know which to use
```

#### Fallback Economics

| Concern | Approach |
|---------|----------|
| Hot path performance | Native path handles common case |
| Feature completeness | Fallback handles edge cases |
| API simplicity | Single entry point, internal routing |
| Benchmark impact | Fallback never hit in hot path benchmarks |

**Rationale**: Callers should not need to know implementation details. The native path is an optimization; the Swift path preserves functionality. Internal routing provides both without API complexity.

---

### C Shim as Semantic Boundary

**Scope**: Swift/C interop in platform primitives.

**Statement**: C shims exist not just for technical bridging but as semantic boundaries. Each platform's shim MUST be independent—even when wrapping identical C functions—to maintain independent compilability.

**Correct**:
```c
// CDarwinKernelShim/uuid_shim.h
#include <uuid/uuid.h>
static inline int swift_uuid_parse(const char* str, unsigned char* out) {
    return uuid_parse(str, out);
}

// CLinuxKernelShim/uuid_shim.h (SEPARATE FILE - same content but independent)
#include <uuid/uuid.h>
static inline int swift_uuid_parse(const char* str, unsigned char* out) {
    return uuid_parse(str, out);
}
```

**Incorrect**:
```c
// ❌ Shared header with conditionals
#if defined(__APPLE__)
#include <uuid/uuid.h>
#elif defined(__linux__)
#include <uuid/uuid.h>
#elif defined(_WIN32)
#include <rpc.h>
// Windows has different semantics - corrupts the abstraction
#endif
```

**Why Duplication is Intentional**:

Darwin's `uuid_parse` and Linux's `uuid_parse` have identical signatures and semantics, yet they live in separate shim files. This duplication ensures:
1. Packages compile independently
2. No conditional compilation hell
3. Platform-specific semantics (like Windows byte reordering) stay isolated

The Windows case proves the necessity: `UuidFromStringA` produces mixed-endian bytes. If shims were unified, Windows-specific logic would corrupt the "shared" layer.

**Rationale**: The shim declares "this is the contract" while the system library provides the implementation. Separation keeps platform accidents from leaking across boundaries.

---

### Namespace Collision Handling

**Scope**: Types that collide with system module names.

**Statement**: When a Swift type name collides with a system C module (e.g., `Darwin` type vs Apple's `Darwin` module), usage sites MUST use fully-qualified paths with module prefixes.

**Correct**:
```swift
// Explicit module qualification resolves collision
let uuid = Darwin_Primitives.Darwin.Identity.UUID.parse(string)

// Import with alias for frequently-used types
import Darwin_Primitives
typealias DarwinUUID = Darwin_Primitives.Darwin.Identity.UUID
```

**Incorrect**:
```swift
// ❌ Ambiguous - which Darwin?
let uuid = Darwin.Identity.UUID.parse(string)  // Compiler error or wrong type
```

#### Common Collisions

| Type Name | Collides With | Resolution |
|-----------|---------------|------------|
| `Darwin` | Apple's Darwin C module | `Darwin_Primitives.Darwin` |
| `Foundation` | Apple's Foundation | Avoid; primitives don't use Foundation |
| `System` | Apple's System module | `System_Primitives.System` |

This will recur: any name matching a system header becomes contested namespace. The workaround scales—always qualify at usage sites when ambiguity is possible.

**Rationale**: Explicit module qualification makes namespace ownership visible. `Darwin_Primitives.Darwin` is unambiguously "our" Darwin, distinct from the system's.

---

### Never Resume Under Lock

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
            // Resumed task runs arbitrary code
            // If that code acquires this lock: DEADLOCK
        }
    }
}
```

#### Why This Matters

| Problem | Consequence |
|---------|-------------|
| Deadlock | Resumed task may acquire same lock |
| Priority inversion | High-priority task blocked by lock holder |
| Unbounded lock hold | User code runs inside critical section |

The `Async.Waiter.Resumption` type enforces this by construction—resumptions are collected under lock but executed only after release.

**Rationale**: Deferred resumption keeps user code out of critical sections, making deadlock impossible by construction rather than by discipline.

---

### Class Wrapper for ~Copyable in Collections

**Scope**: Storing `~Copyable` types in enums, dictionaries, or other collections.

**Statement**: When `~Copyable` types must be stored in collections (which require `Copyable` values), wrap the `~Copyable` content in a class. The class provides reference semantics (copyable), while the content remains move-only.

**Correct**:
```swift
// Class wrapper for ~Copyable content
final class Entry<T: Sendable>: @unchecked Sendable {
    enum State: ~Copyable {
        case pending(Async.Waiter.Queue.Unbounded)
        case computing
        case completed(T)
    }

    private let lock = Mutex<State>(.pending(.init()))

    // Entry is copyable (reference semantics)
    // State is ~Copyable (accessed through lock)
}

// Now Entry can be dictionary value
var cache: [Key: Entry<Value>] = [:]
```

**Incorrect**:
```swift
// ❌ Cannot store ~Copyable directly in dictionary
var cache: [Key: State] = [:]  // Compiler error: State is ~Copyable

// ❌ Cannot use ~Copyable as enum associated value
enum CacheEntry {
    case pending(Async.Waiter.Queue.Unbounded)  // Error
}
```

This pattern recurs wherever `~Copyable` meets collection types. Recognizing it early saves design iterations.

**Rationale**: Swift's ownership system doesn't yet support move-only dictionary values. Classes provide the reference semantics needed for collection storage while preserving move-only content semantics through encapsulation.

---

### Minimal Reproduction as Verification Tool

**Scope**: Resolving debates about compiler behavior, runtime semantics, or "what Swift does."

**Statement**: When technical debates rest on claims about compiler behavior, runtime semantics, or language mechanics, a minimal reproduction package MUST be built to verify the claim. Theoretical debates about "what Swift does" have definitive answers available within minutes.

#### The Technique

When debate threatens to become theoretical, create a minimal test package:

```bash
cd /tmp
mkdir sendable-test && cd sendable-test
swift package init --type executable
# Add minimal code to test the claim
swift build
```

#### Properties of Minimal Reproductions

| Property | Benefit |
|----------|---------|
| **Isolation** | Only the relevant mechanics, nothing else |
| **Speed** | Modified and rebuilt in seconds |
| **Disposability** | Lives in `/tmp`, no commitment to keep |
| **Shareability** | Others can reproduce the exact experiment |

**Correct**:
```
Debate: "Is Reference.Indirect unconditionally @unchecked Sendable safe?"
Arguments about Swift's concurrency model, what @unchecked "really means"...

Resolution: "Create a minimal reproduction in /tmp to verify this claim."

Within minutes: test package exists showing exactly which patterns
compile, which fail, and what error messages appear.

 empirical verification.
```

**Incorrect**:
```
Debate continues through theoretical territory.
Arguments about semantics, analogies to UnsafeMutablePointer...
Neither party verifies claims against actual compiler behavior.

❌ The debate "will the compiler accept X?" has a definitive answer
   available in minutes. Continuing to theorize wastes time.
```

#### When to Reach for This Tool

Build a minimal reproduction when:
1. The debate rests on claims about compiler behavior
2. Someone says "Swift does X" or "Swift doesn't allow Y"
3. The answer would change the design decision
4. Multiple interpretations of language semantics exist

The reproduction often reveals that the question itself was wrong—testing the actual behavior surfaces distinctions that theoretical analysis missed.

**Rationale**: Debates about abstractions and principles can continue forever. Debates about "will the compiler accept X?" have definitive answers. The test package takes minutes to create; the ungrounded debate can take hours. The minimal reproduction is a truth machine—it settles claims that no amount of argument can resolve.

---

### Intentional Code Duplication (DITBR)

**Scope**: Situations where code duplication is chosen over shared abstractions due to compiler limitations.

**Statement**: When the alternative to code duplication requires fighting compiler limitations (e.g., `~Copyable` constraint propagation failures), duplication MAY be accepted as conscious technical debt provided it meets all five DITBR criteria: **Documented**, **Intentional**, **Time-bounded**, **Bounded in scope**, and **Reversible**.

**Correct**:
```swift
// ============================================================================
// TEMPORARY WORKAROUND - DO NOT MODIFY WITHOUT CHECKING COMPILER STATUS
// ============================================================================
//
// WHY THIS EXISTS:
// Swift compiler bug Category 3 — cross-module ~Copyable constraint propagation.
//
// WHEN TO REMOVE:
// Delete these types when compiler fixes cross-module ~Copyable propagation.
//
// MAINTENANCE:
// If List.Linked storage changes, these MUST be updated to match.
// Source of truth: swift-list-primitives/Sources/List Primitives/List.Linked.swift

// Duplicated storage types nested inside Queue.Linked
struct Header: ~Copyable { ... }  // Copy of List.Linked.Header
struct Node: ~Copyable { ... }    // Copy of List.Linked.Node
```

**Incorrect**:
```swift
// ❌ Undocumented duplication — no explanation, no removal criteria
struct Header: ~Copyable { ... }
struct Node: ~Copyable { ... }
// Future maintainers cannot tell this is intentional or accidental

// ❌ Restructuring the design to work around a compiler bug
enum Queue { }  // Making Queue an empty namespace just to avoid duplication
// Inverts the semantic model: Queue IS a container, not a namespace
```

#### DITBR Criteria

| Criterion | Requirement |
|-----------|-------------|
| **Documented** | Comments explain WHY duplication exists and WHERE the source of truth lives |
| **Intentional** | Chosen after evaluating alternatives, not accumulated through neglect |
| **Time-bounded** | Tied to a specific compiler fix or language evolution |
| **Bounded in scope** | Limited to a single file or class hierarchy |
| **Reversible** | Can be deleted and replaced with shared abstraction when the blocker resolves |

**Rationale**: Not all technical debt is accidental. When a compiler limitation makes shared abstractions impossible, documented duplication with explicit removal criteria is a legitimate engineering tool. The documentation ensures the debt remains visible and actionable.

---

## ~Copyable Patterns

**Applies to**: Types using `~Copyable` (move-only semantics) in Swift Institute packages.

**Does not apply to**: Types that are unconditionally `Copyable`.

---

### Hierarchy of ~Copyable Workarounds

**Scope**: Resolving cross-module `~Copyable` constraint propagation failures for generic container types.

**Statement**: When a `~Copyable` generic type fails to compile due to cross-module constraint propagation bugs, workarounds MUST be attempted in the following order. Only the nested storage type approach reliably preserves generic parameter identity.

#### Workaround Ordering (Failure to Success)

| Approach | Result | Why |
|----------|--------|-----|
| Extension placement with explicit `where Element: ~Copyable` | FAILS | Extensions do not create new constraint contexts |
| Module-level wrapper types (`__QueueLinkedStorage<Element: ~Copyable>`) | FAILS | Generic parameter is a different `Element` than the outer type's |
| Module-level typealiases (`typealias __Storage<Element: ~Copyable> = ...`) | FAILS | Typealias parameter is not the same as the outer type's parameter |
| `@_exported import` of the source module | NO EFFECT | The bug is about generic parameter identity, not module visibility |
| Nested storage types inside the consuming type | SUCCESS | Inherits the `Element` parameter with constraint suppression intact |

**Correct**:
```swift
struct Outer<T: ~Copyable>: ~Copyable {
    // Nested type inherits T — same generic parameter, same identity
    struct Inner: ~Copyable {
        var value: T  // Same T as Outer
    }
}
```

**Incorrect**:
```swift
// ❌ Different generic parameters despite identical constraints
struct Helper<T: ~Copyable>: ~Copyable { var value: T }

struct Outer<T: ~Copyable>: ~Copyable {
    var helper: Helper<T>  // Helper's T is a DIFFERENT parameter
}
// Constraint suppression on Outer's T does not transfer to Helper's T
```

**Rationale**: Swift's generics track parameter identity, not just constraints. Nesting preserves identity because the inner type's `T` is the same generic parameter as the outer type's. Cross-type instantiation creates a new parameter that happens to share constraints, which is insufficient for `~Copyable` constraint propagation.

---

### Category 4 ~Copyable Compiler Bug: Module Emission Phase

**Scope**: `~Copyable` types with conditional `Sequence` conformance and borrowing closures across multiple files.

**Statement**: A module emission phase constraint solver failure MAY occur when ALL of the following conditions are present simultaneously. This bug category MUST be documented alongside Categories 1-3 in any `~Copyable` constraint propagation reference.

#### Required Conditions (All Six Must Be Present)

| # | Condition |
|---|-----------|
| 1 | Compound generic constraint (`Element: ~Copyable & Protocol`) |
| 2 | Nested type with `UnsafeMutablePointer<Element>` stored property |
| 3 | Conditional `Sequence` conformance (`where Element: Copyable`) |
| 4 | Extension file with `(borrowing Element)` closure parameter |
| 5 | Library target (uses `-emit-module`) |
| 6 | `-enable-experimental-feature Lifetimes` flag |

**Correct**:
```swift
// Workaround: Consolidate all source into a single file
// This bypasses the module emission phase cross-file constraint failure.
// WORKAROUND: This Sequence conformance only compiles because all source code
// is consolidated into a single file. When the compiler bug is fixed, this
// package can be restructured into multiple files.
```

**Incorrect**:
```swift
// ❌ Splitting across files when all six conditions are present
// Container.swift
struct Container<Element: ~Copyable & Ordering>: ~Copyable { ... }
extension Container: Sequence where Element: Copyable { ... }

// Container+Borrowing.swift  ← separate file triggers emission bug
extension Container where Element: ~Copyable {
    func withMin(_ body: (borrowing Element) -> Void) { ... }
}
```

**Rationale**: Category 4 bugs manifest only during `-emit-module`, not during parse or type-check. The six-condition specificity makes the bug difficult to reproduce in minimal reproductions and easy to trigger accidentally in production code. Single-file consolidation is the only known workaround.

---

### Accessor Patterns and ~Copyable Container Identity

**Scope**: Determining whether container types support accessor patterns (chained `container.take.min`) vs compound methods (`container.takeMin()`).

**Statement**: The choice between accessor patterns and compound methods MUST be determined by the container's `~Copyable` status and storage model. Accessor return types that hold a reference to the container require the container to be `Copyable`; `~Copyable` containers MUST use compound methods or borrowing closures instead.

#### Container API Pattern Selection

| Container Variant | Storage | ~Copyable? | API Pattern |
|-------------------|---------|------------|-------------|
| Base (CoW) | Class-based | Conditional | Accessor pattern when `Element: Copyable` |
| Bounded | Class-based | Always | Compound methods |
| Inline | Inline | Always | Compound methods |
| Small | Hybrid | Always | Compound methods |

**Correct**:
```swift
// Base container — conditional Copyable, supports accessors
let min = heap.take.min       // Accessor pattern (Element: Copyable)

// Bounded variant — always ~Copyable, uses compound methods
heap.withMin { element in     // Borrowing closure pattern
    process(element)
}
```

**Incorrect**:
```swift
// ❌ Attempting accessor pattern on ~Copyable container
let access = bounded.take     // Compiler error: accessor struct
                              // cannot hold ~Copyable container
```

**Rationale**: Accessor structs (e.g., `Take`) are implicitly `Copyable` and must hold a reference to the container. When the container is `~Copyable`, this creates a contradiction: a `Copyable` accessor cannot store a `~Copyable` value. The API divergence between base and variant containers reflects this constraint, not inconsistency.

---

### Error Type Hoisting for ~Copyable Generics

**Scope**: Error types that would otherwise be nested inside `~Copyable` generic types.

**Statement**: Error types nested inside `~Copyable` generic types inherit the `~Copyable` constraint, making them unusable with `throws`. Error types MUST be hoisted to module scope with a double-underscore prefix to signal implementation-detail status.

**Correct**:
```swift
// Hoisted to module scope — Copyable, usable with throws
public struct __TreeNBoundedError: Error, Sendable {
    // ...
}
public struct __TreeNInlineError: Error, Sendable {
    // ...
}

// Usage in the ~Copyable container
extension Tree.N.Bounded {
    public mutating func insert(_ element: consuming Element) throws(__TreeNBoundedError) {
        // ...
    }
}
```

**Incorrect**:
```swift
// ❌ Error type nested inside ~Copyable generic — inherits ~Copyable
extension Tree.N.Bounded {
    public struct Error: Swift.Error {  // Implicitly ~Copyable
        // Cannot be thrown: throws requires Copyable
    }
}
```

#### Naming Convention for Hoisted Types

| Intended Nesting | Hoisted Name | Purpose |
|------------------|--------------|---------|
| `Tree.N.Bounded.Error` | `__TreeNBoundedError` | Error for bounded tree operations |
| `Tree.N.Inline.Error` | `__TreeNInlineError` | Error for inline tree operations |
| `Stack.Small.Error` | `__StackSmallError` | Error for small stack operations |

The double-underscore prefix signals "implementation detail hoisted for compiler constraint reasons." These types appear in public API (typed throws signatures) but are not intended as primary API surface.

**Rationale**: Swift's `throws` mechanism requires errors to be `Copyable`. Types nested inside `~Copyable` generics inherit `~Copyable`, creating an irreconcilable constraint. Hoisting to module scope with a naming convention preserves the logical association while satisfying the compiler.

---

### Conditional @unchecked Sendable for ~Copyable Containers

**Scope**: `~Copyable` container types with unsafe internal storage that must conform to `Sendable`.

**Statement**: `~Copyable` containers with unsafe internals (raw pointers, optional class references) MUST use conditional `@unchecked Sendable` conformance constrained on `Element: Sendable`. The `@unchecked` annotation is justified when the container's ownership model prevents the scenarios where unsafety would manifest.

**Correct**:
```swift
extension Tree.N.Small: @unchecked Sendable where Element: Sendable {}
```

**Incorrect**:
```swift
// ❌ Unconditional Sendable — allows non-Sendable elements through
extension Tree.N.Small: @unchecked Sendable {}

// ❌ Missing @unchecked — compiler rejects due to unsafe internals
extension Tree.N.Small: Sendable where Element: Sendable {}
```

#### Justification Criteria for @unchecked

The `@unchecked` annotation is correct when ALL of the following hold:

| Criterion | Verification |
|-----------|-------------|
| Storage is exclusively owned | No copy-on-write sharing of the backing store |
| Cached pointers are derived | Computed from owned storage, not independent references |
| Access is synchronized by ownership | `~Copyable` prevents concurrent access to the same instance |

The `where Element: Sendable` constraint is essential: a container of non-`Sendable` elements MUST NOT be `Sendable`, regardless of the container's own thread-safety properties.

**Rationale**: `~Copyable` containers frequently contain unsafe pointers for performance. The `~Copyable` constraint itself provides the thread-safety guarantee (no aliasing), making `@unchecked Sendable` a correct annotation rather than a safety escape hatch.

---

### Value Generics and Conditional Copyable

**Scope**: Types parameterized with value generics (`let N: Int`) that store only trivial data.

**Statement**: Value generic parameters (`let N: Int`) MUST NOT be combined with `~Copyable` declarations when conditional `Copyable` conformance is the intent. Value generics provide no type parameter to constrain on, making conditional `Copyable` syntactically impossible.

**Correct**:
```swift
// Value generic with trivial storage — omit ~Copyable entirely
public struct Small<let inlineWordCount: Int>: Sendable {
    var _inlineStorage: InlineArray<inlineWordCount, UInt>
    var _heapStorage: ContiguousArray<UInt>?
    var _capacity: Int
    // All members are trivially Copyable
}
```

**Incorrect**:
```swift
// ❌ Cannot add Copyable back to a ~Copyable type with only value generics
public struct Small<let inlineWordCount: Int>: ~Copyable, Sendable { ... }
extension Small: Copyable {}  // Error: no type parameter to constrain on
```

#### Type Generics vs Value Generics

| Generic Kind | Example | Can Condition Copyable? |
|--------------|---------|------------------------|
| Type (`Element`) | `Stack<Element: ~Copyable>` | Yes: `where Element: Copyable` |
| Value (`let N: Int`) | `Small<let N: Int>` | No: no type to constrain |

When all stored members are unconditionally `Copyable` (e.g., `UInt`, `Int`, `ContiguousArray`), the type is unconditionally `Copyable`. Declaring `~Copyable` and attempting to restore `Copyable` conditionally creates a dead end.

**Rationale**: `~Copyable` exists for types whose copyability depends on their generic element types. Value generics parameterize over quantities, not types. A `Small<4>` has no reason to differ in copyability from a `Small<8>`. When storage is trivial, `~Copyable` introduces complexity without benefit.

---

### The ~Copyable Decision Framework

**Scope**: Deciding whether a new container type should be declared `~Copyable`.

**Statement**: The decision to declare a type `~Copyable` MUST be based on the storage pattern and generic parameter configuration. Types with trivial storage and no generic element type SHOULD NOT be `~Copyable`.

#### Decision Table

| Storage Pattern | Generic Element? | Use ~Copyable? | Rationale |
|-----------------|------------------|----------------|-----------|
| `Element` (might be ~Copyable) | Yes | Yes + conditional Copyable | Element's copyability is unknown |
| `[Element]` (array of elements) | Yes | Yes + conditional Copyable | Array inherits element's constraint |
| `UInt` / trivial types only | No | No, use Sendable | Storage is unconditionally Copyable |
| Value generic (`let N: Int`) only | No | No, cannot condition Copyable | No type parameter to constrain on |
| Inline storage with deinit | Yes | Yes (deinit requirement) | Deinit must run to clean up elements |

#### When ~Copyable Is Required

1. The type stores generic elements that could be move-only
2. The type has a `deinit` that must run (inline storage with element destruction)
3. Copying would violate ownership semantics (file handles, locks, unique resources)

#### When ~Copyable Is Wrong

1. Storage is unconditionally trivial (all members are always `Copyable`)
2. There is no generic element type to condition on
3. Protocol conformances (`Sequence`, `Equatable`, `Hashable`) are needed and cannot be conditional
4. Value semantics without manual `borrowing`/`consuming` handling is desired

**Rationale**: `~Copyable` is a tool for types whose copyability depends on their contents. Applying it to types with unconditionally trivial storage creates unnecessary API complexity and may trigger compiler limitations (e.g., value generic incompatibility) with no corresponding benefit.

---

## Migration and Refactoring

**Applies to**: Consolidating type variants, migrating position types, and evolving container APIs.

**Does not apply to**: Greenfield implementation where no migration path is needed.

---

### Typealias Migration for Type Consolidation

**Scope**: Replacing specialized type implementations with parameterized generics while preserving backward compatibility.

**Statement**: When consolidating specialized types into parameterized generics, a typealias MUST be used as the migration bridge. The migration MUST follow delete-then-create sequencing: delete the old implementation first, then create the typealias file at the same path.

**Correct**:
```swift
// After migration: Tree.Binary is a typealias for Tree.N<Element, 2>
extension Tree {
    public typealias Binary<Element: ~Copyable> = Tree.N<Element, 2>
}

// All existing Tree.Binary<Int> usage continues to work
// No runtime cost, no wrapper overhead
```

**Incorrect**:
```swift
// ❌ Maintaining parallel implementations during transition
struct Binary<Element: ~Copyable>: ~Copyable { ... }  // Old
struct N<Element: ~Copyable, let n: Int>: ~Copyable { ... }  // New
// Parallel implementations diverge, create confusion, double maintenance
```

#### Migration Sequencing

| Step | Action | Purpose |
|------|--------|---------|
| 1 | Create all parameterized variants | New implementation exists |
| 2 | Migrate tests to parameterized types | Verify behavioral equivalence |
| 3 | Verify tests pass | Confirm correctness |
| 4 | Delete old implementation files | Remove duplication |
| 5 | Create typealias file at the old path | Preserve backward compatibility |

#### Nested Type Migration

Nested types do not alias automatically. Position types hoisted to a shared namespace require explicit migration in client code:

```swift
// Before migration
var positions: [Tree.Binary<Int>.Position] = []

// After migration — Position hoisted to Tree.Position
var positions: [Tree.Position] = []
```

This change is mechanical but cannot be papered over with typealiases.

**Rationale**: Typealiases are resolved at compile time with zero runtime cost. Delete-then-create sequencing forces complete migration rather than gradual rot from parallel implementations. The typealias file reuses the old implementation's path, preserving the logical association.

---

## Build Infrastructure

**Applies to**: Monorepo development with local path dependencies.

**Does not apply to**: Production builds with pinned version dependencies.

---

### Dependency Graph Fragility in Monorepos

**Scope**: Build failures caused by local path dependencies in monorepo development.

**Statement**: When using local path dependencies, developers MUST expect transient build failures from dependency graph interactions. Build errors that do not correspond to local changes SHOULD be resolved with `swift package clean` before investigating further.

#### The Cascade Effect

Local path dependencies cause `swift build` to compile the entire dependency graph. A bug or transient failure in any dependency blocks all downstream work, even when the dependency and the target package have no logical coupling.

**Correct**:
```bash
# Build error doesn't match local changes — clean first
swift package clean
swift build

# If error persists, investigate the dependency
```

**Incorrect**:
```bash
# ❌ Investigating errors in code you didn't change without cleaning first
# Transient incremental build failures waste investigation time
```

#### Monorepo Development Guidelines

| Concern | Guideline |
|---------|-----------|
| Transient failures | Not all build errors indicate code problems; clean and rebuild |
| Dependency bugs | A broken dependency must be fixed before downstream progress |
| Incremental builds | May corrupt state; `swift package clean` resolves mysteries |
| Production isolation | Production builds SHOULD use pinned versions, not path dependencies |

**Rationale**: Local path dependencies provide development velocity but introduce build fragility. Incremental build state corruption and parallel compilation race conditions can produce errors unrelated to the developer's changes. Recognizing transient failures as a monorepo characteristic prevents wasted investigation time.

---

## Topics

### Related Documents

- <doc:API-Requirements>
- <doc:Primitives-Architecture>
- <doc:Testing-Requirements>

### Process Documents

- <doc:Reflections-Consolidation>
- <doc:Documentation-Maintenance>
