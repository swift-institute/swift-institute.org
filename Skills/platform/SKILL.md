---
name: platform
description: |
  Platform code layering (L1–L3), platform compilation mechanics, Swift 6 features,
  C shims, and build infrastructure.
  ALWAYS apply when deciding where to place platform-specific code, configuring
  Package.swift, working with platform conditionals, or using Swift feature flags.

layer: architecture

requires:
  - swift-institute

applies_to:
  - swift
  - swift6
  - swift-primitives
  - swift-standards
  - swift-foundations
  - kernel
  - darwin
  - linux
  - windows
  - posix
  - platform
last_reviewed: 2026-03-20
---

# Platform

Platform code architecture, compilation mechanics, and build infrastructure. Covers where system/platform code lives, how cross-platform abstraction is achieved, and how packages are configured.

---

## Platform Architecture

### [PLAT-ARCH-001] Four-Level Platform Stack

**Statement**: Platform code MUST be organized into exactly four levels, each in a dedicated package. Code MUST be placed at the lowest level where it can correctly live.

```
L3  swift-kernel          (Foundations)   Unified cross-platform module
         ↑                                `import Kernel` — one import, any platform
         ├── swift-darwin    (Foundations)   Darwin L3: re-exports + Darwin-specific L3 code
         ├── swift-linux     (Foundations)   Linux L3: re-exports + Linux-specific L3 code
         └── swift-windows   (Foundations)   Windows L3: re-exports + Windows-specific L3 code
              ↑
L2  swift-iso-9945        (Standards)     POSIX specification — shared by Darwin + Linux
              ↑
L1  swift-kernel-primitives (Primitives)  Cross-platform syscall-shaped vocabulary
         ├── swift-darwin-primitives        Darwin-specific primitives (kqueue, mach)
         ├── swift-linux-primitives         Linux-specific primitives (epoll, io_uring)
         └── swift-windows-primitives       Windows-specific primitives (IOCP, WinSock)
```

| Level | Package | Layer | Contains |
|-------|---------|-------|----------|
| L1 shared | `swift-kernel-primitives` | Primitives | Cross-platform `Kernel` namespace, `Kernel.Descriptor`, `Kernel.Error`, file/socket/thread/memory primitives |
| L1 platform | `swift-{darwin,linux,windows}-primitives` | Primitives | Platform-specific syscall wrappers that extend `Kernel` |
| L2 | `swift-iso-9945` | Standards | POSIX specification (IEEE 1003.1), shared by Darwin and Linux |
| L3 platform | `swift-{darwin,linux,windows}` | Foundations | Platform-specific foundations code (NUMA, entropy, thread affinity) |
| L3 unified | `swift-kernel` | Foundations | Cross-platform unification via conditional re-exports |

**Rationale**: This separation ensures platform-specific code never leaks into consumer packages. Every consumer writes `import Kernel` and gets the right platform automatically.

**Cross-references**: [ARCH-LAYER-001], **swift-institute** skill

---

### [PLAT-ARCH-002] Placement Decision Rules

**Statement**: When adding new platform code, it MUST be placed according to these rules:

| The code is... | Place it in... | Example |
|----------------|----------------|---------|
| A raw syscall wrapper used by all platforms | `swift-kernel-primitives` | `Kernel.File.open()`, `Kernel.Socket.create()` |
| A raw syscall wrapper specific to one platform | `swift-{platform}-primitives` | `Kernel.IO.Uring` (Linux), `Kernel.Kqueue` (Darwin) |
| A POSIX syscall shared by Darwin and Linux | `swift-iso-9945` | `POSIX.Kernel.Signal`, `POSIX.Kernel.Process.Fork` |
| A higher-level abstraction over platform primitives | `swift-{platform}` (L3) | `Darwin.System.NUMA`, `Linux.Thread.Affinity` |
| Cross-platform composed behavior | `swift-kernel` (L3) | `Kernel.File.Write.Atomic`, `Kernel.Thread.Executor` |

**Incorrect placement**:
```swift
// ❌ Platform-specific code in swift-kernel-primitives
#if os(Linux)
extension Kernel.IO { public enum Uring {} }  // Belongs in swift-linux-primitives
#endif

// ❌ POSIX code duplicated in both Darwin and Linux primitives
// Belongs in swift-iso-9945

// ❌ Platform conditional in a consumer package (swift-io, swift-file-system)
#if canImport(Darwin)
import Darwin_Kernel_Primitives  // Consumer should import Kernel, not platform modules
#endif
```

**Rationale**: Correct placement prevents duplication, keeps platform conditionals out of consumer code, and ensures independent compilability.

---

### [PLAT-ARCH-003] Namespace Extension Pattern

**Statement**: All platform-specific packages MUST extend the shared `Kernel` namespace from `swift-kernel-primitives` rather than defining their own root types.

```swift
// swift-kernel-primitives — defines the shared root
public enum Kernel {}

// swift-linux-primitives — extends it
extension Kernel.IO { public enum Uring {} }
extension Kernel.Event { public enum Poll {} }

// swift-darwin-primitives — extends it
extension Kernel { public enum Kqueue {} }

// swift-windows-primitives — extends it
extension Kernel.IO.Completion { public enum Port {} }

// swift-iso-9945 — extends it via typealias
public typealias Kernel = Kernel_Primitives.Kernel
extension Kernel { public enum Signal {} }
extension Kernel.Process { public enum Fork {} }
```

**Incorrect**:
```swift
// ❌ Own root namespace
public enum LinuxKernel {}           // Should extend Kernel

// ❌ Compound names
public enum KqueueEventNotification {}  // Should be Kernel.Kqueue
```

**Rationale**: A single `Kernel` namespace means consumers see one unified API. Platform-specific extensions appear naturally under `Kernel.*` without separate import paths.

**Cross-references**: [API-NAME-001]

---

### [PLAT-ARCH-004] Platform Root Namespaces

**Statement**: Each platform-specific package MUST also define a platform root namespace for platform-only types that don't fit under `Kernel`.

```swift
// swift-darwin-primitives
public enum Darwin: Sendable {}
extension Darwin { public typealias Kernel = Kernel_Primitives.Kernel }

// swift-linux-primitives
public enum Linux: Sendable {}
extension Linux { public typealias Kernel = Kernel_Primitives.Kernel }

// swift-windows-primitives
public enum Windows {}
extension Windows { public typealias Kernel = Kernel_Primitives.Kernel }

// swift-iso-9945
public enum ISO_9945: Sendable {}
public typealias POSIX = ISO_9945
```

The platform namespace convention follows `Platform.Domain.Concept`:

| Darwin | Linux | Windows |
|--------|-------|---------|
| `Darwin.Kernel.Kqueue` | `Linux.Kernel.IO.Uring` | `Windows.Kernel.IO.Completion.Port` |
| `Darwin.Identity.UUID` | `Linux.Identity.UUID` | `Windows.Identity.UUID` |
| `Darwin.Memory.Allocation` | `Linux.Memory.Allocation` | `Windows.Memory.Allocation` |

**Rationale**: Parallel namespace structure across platforms makes the architecture predictable. Conceptual equivalents occupy the same namespace position.

**Cross-references**: [API-NAME-001], [API-NAME-003]

---

### [PLAT-ARCH-005] Cross-Platform Descriptor Unification

**Statement**: `Kernel.Descriptor` MUST be the single file descriptor / handle type across all platforms. Platform-specific packages add veneer properties for their native handle type.

```swift
// swift-kernel-primitives — shared definition
// Wraps Int32 on POSIX, UInt on Windows

// swift-iso-9945 — POSIX veneer
extension Kernel.Descriptor {
    public static func borrowing(_ fd: Int32) -> Self { ... }
    public var fileDescriptor: Int32 { ... }
}

// swift-windows-primitives — Windows veneer
extension Kernel.Descriptor {
    public static func borrowing(handle: HANDLE) -> Self { ... }
    public var handle: HANDLE { ... }
}
```

**Incorrect**:
```swift
// ❌ Platform-specific descriptor types
struct POSIXFileDescriptor { ... }     // Use Kernel.Descriptor
struct WindowsHandle { ... }           // Use Kernel.Descriptor
```

**Rationale**: One descriptor type means cross-platform code can pass descriptors without type conversion. Platform veneers provide ergonomic access to the native representation when needed.

---

### [PLAT-ARCH-006] Re-Export Chain Architecture

**Statement**: Each level MUST re-export everything below it using `@_exported public import`, so that consumers only need one import at their chosen abstraction level.

The chain for a consumer writing `import Kernel`:

```
import Kernel                              ← consumer writes this
  └─ @_exported Kernel_Primitives          ← cross-platform primitives
  └─ @_exported POSIX_Kernel               ← (Darwin/Linux only)
  └─ @_exported Darwin_Kernel              ← (Darwin only)
       └─ @_exported Darwin_Primitives
       └─ @_exported Darwin_Kernel_Primitives
```

**The unification file** (`swift-kernel/Sources/Kernel/Exports.swift`):

```swift
@_exported public import Kernel_Primitives

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    @_exported public import POSIX_Kernel
#endif

#if canImport(Darwin)
    @_exported public import Darwin_Kernel
#elseif canImport(Glibc) || canImport(Musl)
    @_exported public import Linux_Kernel
#elseif os(Windows)
    @_exported public import Windows_Kernel
#endif
```

**Platform foundations exports** (e.g., `swift-darwin/Sources/Darwin Kernel/Exports.swift`):

```swift
@_exported public import Darwin_Primitives
@_exported public import Darwin_Kernel_Primitives
```

**Result**: Platform conditionals exist in exactly two places — the L3 `Exports.swift` files and `Package.swift` dependency conditions. Consumer code is unconditional.

**Rationale**: The re-export chain is what makes `import Kernel` work as a single cross-platform entry point. Without it, consumers would need platform conditionals in every file.

**Cross-references**: [PATTERN-004], [PATTERN-004a]

---

### [PLAT-ARCH-007] POSIX Code Belongs in ISO 9945

**Statement**: POSIX syscall wrappers shared by Darwin and Linux MUST live in `swift-iso-9945` (Layer 2, Standards), NOT be duplicated in `swift-darwin-primitives` and `swift-linux-primitives`.

```
                    swift-iso-9945 (POSIX)
                    ┌─────────────────────┐
                    │ Kernel.Signal       │
                    │ Kernel.Process.Fork │
                    │ Kernel.Memory.Map   │
                    │ Kernel.Socket       │
                    │ Kernel.Pipe         │
                    │ Kernel.Termios      │
                    └─────────┬───────────┘
                       ↗              ↖
    swift-darwin-primitives    swift-linux-primitives
    (kqueue, mach)             (epoll, io_uring)
```

Both `swift-darwin-primitives` and `swift-linux-primitives` depend on `swift-iso-9945`. `swift-windows-primitives` does NOT — Windows is not POSIX.

**Incorrect**:
```swift
// ❌ In swift-darwin-primitives
extension Kernel.Process {
    public static func fork() -> ... { }  // This is POSIX — belongs in swift-iso-9945
}

// ❌ In swift-linux-primitives (duplicated)
extension Kernel.Process {
    public static func fork() -> ... { }  // Same POSIX code duplicated
}
```

**Rationale**: ISO 9945 is the IEEE 1003.1 (POSIX) specification. Placing shared POSIX code there follows [API-NAME-003] (specification-mirroring names) and eliminates duplication between Darwin and Linux.

**Cross-references**: [API-NAME-003], [ARCH-LAYER-001]

---

### [PLAT-ARCH-008] Consumer Import Rule

**Statement**: Packages above Layer 3 (Components, Applications) MUST import `Kernel`, NOT individual platform modules. Platform conditionals in consumer code are forbidden.

**Correct**:
```swift
// In any L4/L5 consumer package
import Kernel

func read(from descriptor: Kernel.Descriptor) throws(Kernel.Error) -> [UInt8] {
    // Works on Darwin, Linux, and Windows — no conditionals needed
}
```

**Incorrect**:
```swift
// ❌ Platform imports in consumer code
#if canImport(Darwin)
import Darwin_Kernel_Primitives
#elseif canImport(Glibc)
import Linux_Kernel_Primitives
#endif

// ❌ Platform conditionals in consumer logic
#if os(Linux)
let events = try Kernel.Event.Poll.wait(...)
#elseif os(macOS)
let events = try Kernel.Kqueue.kevent(...)
#endif
```

**Exception**: L3 foundation packages (`swift-darwin`, `swift-linux`, `swift-windows`, `swift-kernel`) are the designated boundary where platform conditionals live. They exist precisely so that no one else needs them.

**Rationale**: The entire point of the platform stack is that consumers never write `#if os(...)`. If platform conditionals appear in consumer code, it means the L3 abstraction is missing a capability.

---

### [PLAT-ARCH-008a] Domain Authority Exception (Limited)

> **Status**: PROVISIONAL — this exception requires explicit user confirmation before applying. When you encounter a case that appears to qualify, present the four criteria and ask the user to confirm before treating the conditional as accepted.

**Statement**: Non-platform-stack packages at any layer MAY contain `#if os(...)` or `#if canImport(...)` conditionals when **all four** of the following hold:

1. **Domain authority**: The package is the canonical owner of the concept that varies by platform.
2. **Kernel imports only**: All platform access goes through `import Kernel` (L3) or `import Kernel_Primitives` (L1) — never raw `import Darwin`/`Glibc`/`Musl`/`WinSDK`.
3. **Domain strategy, not syscall selection**: The conditional selects between domain-level strategies or defines platform-varying vocabulary types — it does not wrap raw syscalls.
4. **Irreducible**: The platform variation cannot be pushed to the platform stack without Kernel absorbing domain semantics it shouldn't own.

**Examples of accepted domain authority conditionals**:

| Package | Conditional | Justification |
|---------|-------------|---------------|
| swift-paths | `#if os(Windows)` for `\` vs `/` separator | Path separators are path domain knowledge, not kernel knowledge |
| swift-io | `#if canImport(Darwin)` selecting kqueue vs epoll strategy | IO event loop strategy is IO domain logic; both backends use Kernel types |
| swift-string-primitives | `#if os(Windows)` for `UInt16` vs `UInt8` char width | Character encoding width is string vocabulary, not kernel vocabulary |
| swift-file-system | `#if os(Windows)` for permission model differences | File permission semantics are file-system domain knowledge |

**Hard line — always a violation regardless of domain authority**:

```swift
// ❌ ALWAYS wrong: raw platform imports in non-platform-stack packages
#if canImport(Darwin)
import Darwin          // Must use import Kernel or import Kernel_Primitives
#elseif canImport(Glibc)
import Glibc           // If Kernel doesn't provide what you need, extend Kernel
#endif
```

Direct `import Darwin`/`Glibc`/`Musl`/`WinSDK` remains a violation in ALL non-platform-stack packages. If the platform stack doesn't expose the needed API, the fix is to extend the platform stack — not bypass it.

**Rationale**: The platform stack abstracts raw syscall interfaces. But domain packages that own platform-varying concepts (path separators, event loop strategies, character encodings) are the natural home for composing those abstractions differently per platform. Forcing all platform conditionals into Kernel would make Kernel absorb domain logic from every consumer, violating separation of concerns in the opposite direction.

**Cross-references**: [PLAT-ARCH-008], [PLAT-ARCH-002]

---

### [PLAT-ARCH-008b] Conditional Public API Surface in L3

**Statement**: L3 unified types (`swift-kernel`) MAY use `#if os(...)` on public enum cases when the wrapped type is defined in a platform-specific standard (e.g., `swift-iso-9945`) and cannot exist on all platforms. This is the sole acceptable form of conditional public API surface in L3.

**Conditions** (all must hold):

1. **Irreducible platform dependency**: The associated type is defined in a platform-specific standard layer (L2) with no Windows (or other absent platform) equivalent. A stub type would be semantically dishonest.
2. **No consumer impact**: No consumer exhaustively switches on the enum. Existing consumers use `default:` or match specific cases.
3. **L3 internal only**: The conditional lives in the L3 unified package itself, not in consumer code. Consumers still write `import Kernel` with no conditionals.
4. **Sole instance per type**: At most one conditional case per enum. Multiple conditional cases suggest the enum's abstraction level is wrong.

**Accepted instance**:

| Enum | Case | Guard | Wrapped Type | Source |
|------|------|-------|-------------|--------|
| `Kernel.Failure` | `.signal(Kernel.Signal.Error)` | `#if !os(Windows)` | `ISO_9945.Kernel.Signal.Error` | POSIX signals have no Windows analogue |

**Why not unconditional?**: `Kernel.Signal.Error` is defined in `swift-iso-9945` (L2 POSIX standard). Windows has no dependency on `swift-iso-9945`. Creating a stub `Signal.Error` in `swift-kernel-primitives` (L1) would add a signal error type on a platform with no signals — violating the principle that L1 types represent genuine domain concepts.

**Why not absorb into `.platform`?**: The `.signal` case carries semantic meaning distinct from `.platform` — it represents signal-specific operations (`sigaction`, `kill`, `raise`), not generic unmapped errors. Absorbing it would lose domain specificity on POSIX platforms.

**Prior art**: Apple's `swift-system` uses the same pattern — `#if os(...)` on ~20 of 224 `Errno` properties where the underlying POSIX concept is genuinely absent on a platform.

**Revisit if**: Swift gains `@nonExhaustive` semantics for non-resilient libraries (analogous to Rust's `#[non_exhaustive]`), which would allow unconditional cases without forcing consumer `#if` guards on exhaustive switches.

**Provenance**: Research document `swift-kernel/Research/conditional-compilation-public-enum-cases.md` (2026-03-24).

**Cross-references**: [PLAT-ARCH-008], [PLAT-ARCH-007], [API-ERR-001]

---

### [PLAT-ARCH-009] L3 Platform Package Responsibilities

**Statement**: Each L3 platform package (`swift-darwin`, `swift-linux`, `swift-windows`) MUST serve exactly two purposes: (1) re-export its platform primitives for the `swift-kernel` unification, and (2) provide L3-level platform-specific functionality.

| L3 Package | Re-exports | L3 Functionality |
|------------|------------|------------------|
| `swift-darwin` | `Darwin_Primitives`, `Darwin_Kernel_Primitives` | `Darwin.System.NUMA`, `Darwin.Random` (arc4random) |
| `swift-linux` | `Linux_Primitives`, `Linux_Kernel_Primitives` | `Linux.System.NUMA`, `Linux.Thread.Affinity`, `Linux.Random` (getrandom) |
| `swift-windows` | `Windows_Primitives`, `Windows_Kernel_Primitives` | `Windows.System.NUMA`, `Windows.Thread.Affinity`, `Windows.Random` |

The L3 unified package `swift-kernel` then:
- Re-exports the correct platform's L3 module via conditionals
- Adds cross-platform composed behavior (`Kernel.File.Write.Atomic`, `Kernel.Thread.Executor`)

**Rationale**: L3 platform packages are the composability layer. They bridge the gap between raw primitives and cross-platform foundations.

---

### [PLAT-ARCH-010] Platform Package Reference

**Statement**: The following packages constitute the complete platform stack. New platform packages MUST NOT be created without explicit architectural discussion.

| Package | Location | Tier/Layer |
|---------|----------|------------|
| `swift-kernel-primitives` | `swift-primitives/swift-kernel-primitives/` | L1, Tier 17 |
| `swift-darwin-primitives` | `swift-primitives/swift-darwin-primitives/` | L1, Tier 18 |
| `swift-linux-primitives` | `swift-primitives/swift-linux-primitives/` | L1, Tier 18 |
| `swift-windows-primitives` | `swift-primitives/swift-windows-primitives/` | L1, Tier 18 |
| `swift-iso-9945` | `swift-standards/swift-iso-9945/` | L2 |
| `swift-darwin` | `swift-foundations/swift-darwin/` | L3 |
| `swift-linux` | `swift-foundations/swift-linux/` | L3 |
| `swift-windows` | `swift-foundations/swift-windows/` | L3 |
| `swift-kernel` | `swift-foundations/swift-kernel/` | L3 (unified) |

All paths are relative to `/Users/coen/Developer/`.

**Cross-references**: [PLAT-ARCH-001]

---

### [PLAT-ARCH-011] `Swift.Error` Qualification in `.Error` Namespaces

**Statement**: Types nested inside a namespace called `Error` (e.g., `Parser.Error.Located`) MUST use fully-qualified `Swift.Error` — not bare `Error` — in conformance declarations, inheritance clauses, and constraint positions. Bare `Error` resolves to the enclosing namespace, creating circular references during type resolution.

**Correct**:
```swift
extension Parser.Error {
    public struct Located<E: Swift.Error>: Swift.Error {  // ✓ Fully qualified
        public let error: E
        public let location: Text.Location
    }
}
```

**Incorrect**:
```swift
extension Parser.Error {
    public struct Located<E: Error>: Error {  // ❌ Resolves to Parser.Error, not Swift.Error
        ...
    }
}
```

**Self-referential conformance trap**: When using protocol typealiases inside generic types, the conformance declaration in the declaring module MUST use the hoisted protocol name directly. `extension Located: Located.Protocol` creates a cycle — the compiler must resolve `Located.Protocol` while computing `Located`'s conformances. Consumer modules CAN use the typealias path.

**Provenance**: Reflection `2026-03-20-pass4-compound-renames-and-generic-nesting.md`.

**Cross-references**: [API-NAME-001], [API-IMPL-009]

---

## Platform Compilation

### [PATTERN-001] C Shim Layer Structure

**Statement**: Where platform-specific functionality is required, packages MUST use minimal C shim targets isolated from Swift code.

```text
swift-numeric-primitives/
├── _Shims/                           # C target
│   └── include/
│       └── shims.h                   # C declarations
└── Sources/
    └── Real Primitives/
        └── Numeric.Math.swift        # Swift wrapper
```

The C shim layer isolates platform-specific inline assembly, provides unified interface across Darwin (libm), Glibc, Musl, and remains internal.

**Semantic boundary**: Each platform's shim MUST be independent — even when wrapping identical C functions — to maintain independent compilability.

```c
// CORRECT — Separate files per platform
// CDarwinKernelShim/uuid_shim.h
#include <uuid/uuid.h>
static inline int swift_uuid_parse(const char* str, unsigned char* out) {
    return uuid_parse(str, out);
}

// CLinuxKernelShim/uuid_shim.h (SEPARATE FILE - independent)
#include <uuid/uuid.h>
static inline int swift_uuid_parse(const char* str, unsigned char* out) {
    return uuid_parse(str, out);
}

// INCORRECT — Shared header with conditionals
#if defined(__APPLE__)
#include <uuid/uuid.h>
#elif defined(__linux__)
...
#endif
```

Duplication is intentional: packages compile independently, no conditional compilation, platform-specific semantics stay isolated (e.g., Windows `UuidFromStringA` produces mixed-endian bytes).

**Cross-references**: [PLAT-ARCH-002], [PATTERN-004c]

---

### [PATTERN-004] SwiftPM Platform Conditions

**Statement**: Platform-specific dependencies MUST use SwiftPM condition directives.

```swift
.product(
    name: "ARM Primitives",
    package: "swift-arm-primitives",
    condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .linux])
)
```

**Cross-references**: [PATTERN-004a]

---

### [PATTERN-004a] Source-Level Platform Conditionals

**Statement**: For platform identity checks, `#if os()` MUST be used instead of `#if canImport()`. `canImport` is appropriate only for optional module availability, not platform identity.

```swift
// CORRECT — Platform identity
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import Darwin_Kernel_Primitives
#elseif os(Linux)
import Linux_Kernel_Primitives
#elseif os(Windows)
import Windows_Kernel_Primitives
#endif

// INCORRECT — canImport for platform identity
#if canImport(Darwin_Kernel_Primitives)
import Darwin_Kernel_Primitives
#endif
```

| Check | Evaluated Against | Determinism |
|-------|-------------------|-------------|
| `os()` | Target triple | Always deterministic |
| `canImport()` | Module resolution | Varies by build system |

Use `canImport` for optional features (e.g., `#if canImport(SwiftUI)`). Use `os()` for platform identity.

**Cross-references**: [PATTERN-004], [PLAT-ARCH-006]

---

### [PATTERN-004b] Module Name Normalization

**Statement**: Swift normalizes Package.swift target names by replacing spaces with underscores. Import statements MUST use the normalized form.

| Package.swift Target | Import Identifier |
|---------------------|-------------------|
| `"Darwin Kernel Primitives"` | `Darwin_Kernel_Primitives` |
| `"Real Primitives"` | `Real_Primitives` |
| `"IO Primitives"` | `IO_Primitives` |

**Cross-references**: [API-NAME-001], [PATTERN-004a]

---

### [PATTERN-004c] C Library Linker Flags

**Statement**: When a platform requires linking against a C library not automatically provided, linker settings MUST declare the dependency with platform conditions.

```swift
linkerSettings: [
    .linkedLibrary("uuid", .when(platforms: [.linux]))
]
```

| Platform | Library | Linked By Default |
|----------|---------|-------------------|
| Darwin | libc (uuid_parse) | Yes |
| Linux | libuuid | No — requires `-luuid` |
| Windows | Rpcrt4.lib | Yes |

Documentation MUST note external library prerequisites (e.g., `libuuid-dev`).

**Cross-references**: [PATTERN-004], [PATTERN-001]

---

### Namespace Collision Handling

When a Swift type name collides with a system module (e.g., `Darwin` type vs Apple's `Darwin` module), usage sites MUST use fully-qualified paths.

```swift
// CORRECT
let uuid = Darwin_Primitives.Darwin.Identity.UUID.parse(string)

// INCORRECT — Ambiguous
let uuid = Darwin.Identity.UUID.parse(string)
```

| Type Name | Collides With | Resolution |
|-----------|---------------|------------|
| `Darwin` | Apple's Darwin C module | `Darwin_Primitives.Darwin` |
| `Foundation` | Apple's Foundation | Avoid; primitives don't use Foundation |
| `System` | Apple's System module | `System_Primitives.System` |

**Cross-references**: [PATTERN-004b], [API-NAME-001], [PLAT-ARCH-004]

---

### Conditional Compilation Foresight

Packages SHOULD include conditional compilation guards for known future features (Embedded Swift, WebAssembly) proactively.

```swift
#if !hasFeature(Embedded)
extension Tagged: Codable where RawValue: Codable { ... }
#endif
```

| Feature | Embedded | WebAssembly |
|---------|----------|-------------|
| `Codable` | Unavailable | Usually available |
| Existentials (`any`) | Unavailable | Available |
| Runtime reflection | Unavailable | Limited |
| Foundation types | Unavailable | Platform-dependent |

Foresight guards cost nothing when unused and save hours when needed.

**Cross-references**: [PATTERN-004]

---

## Swift 6 & Build Infrastructure

### [PATTERN-002] Fine-Grained Library Exposure

**Statement**: Complex packages SHOULD expose multiple libraries for fine-grained dependency management.

```swift
// CORRECT
products: [
    .library(name: "Numeric Primitives", targets: ["Numeric Primitives"]),
    .library(name: "Real Primitives", targets: ["Real Primitives"]),
    .library(name: "Integer Primitives", targets: ["Integer Primitives"]),
]

// INCORRECT — Single monolithic library
products: [
    .library(name: "Numeric Primitives", targets: [
        "Numeric Primitives", "Real Primitives", "Integer Primitives", "Complex Primitives",
    ]),
]
```

**Cross-references**: [API-LAYER-001], [PATTERN-001]

---

### [PATTERN-003] Nested Test Package Pattern

**Statement**: When packages face potential circular dependencies with swift-testing, the package MUST use nested test packages.

```text
swift-identity-primitives/
├── Package.swift                    # Main package (no test target)
└── Tests/
    └── Package.swift                # Separate package for tests
        └── depends on swift-testing
```

This breaks the cycle: `swift-testing` depends on primitives, but primitives' tests (in a separate package) depend on `swift-testing`.

**Cross-references**: [API-LAYER-001]

---

### [PATTERN-005] Swift 6 Language Mode

**Statement**: All packages MUST require Swift 6.2+ and use Swift 6 language mode.

```swift
// Package.swift
// swift-tools-version: 6.2
platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26), .watchOS(.v26), .visionOS(.v26)]
swiftLanguageModes: [.v6]
```

All packages MUST support Darwin, Linux, Windows, POSIX, and Swift Embedded.

**Cross-references**: [PATTERN-006], [PATTERN-005a]

---

### [PATTERN-005a] Memory Safety Warnings as Design Feedback

**Statement**: `#StrictMemorySafety` warnings MUST be treated as design feedback, not noise. Each warning marks a site requiring eventual `unsafe` annotation.

See **memory** skill [MEM-SAFE-003] for warning classification (Bucket A vs Bucket B).

**Cross-references**: [PATTERN-005], [MEM-SAFE-003]

---

### [PATTERN-005b] Expression Granularity of Unsafe

**Statement**: Swift 6's strict memory safety operates at expression granularity. An `@unsafe` on a function declares *calling* is unsafe; operations *within* still require individual `unsafe` markers.

Key pattern: `unsafe (self.raw = value)` for assignments to unsafe storage.

See **memory** skill [MEM-SAFE-002] for full details.

**Cross-references**: [PATTERN-005], [MEM-SAFE-002]

---

### [PATTERN-006] Upcoming Feature Flags

**Statement**: Packages SHOULD enable upcoming Swift features for forward compatibility.

```swift
swiftSettings: [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
]
```

**Cross-references**: [PATTERN-005], [PATTERN-007]

---

### [PATTERN-007] Experimental Feature Flags

**Statement**: Memory-critical packages MAY enable experimental features for compile-time resource verification.

```swift
swiftSettings: [
    .enableExperimentalFeature("Lifetimes"),
    .enableExperimentalFeature("LifetimeDependence"),
]
```

**Cross-references**: [PATTERN-006]

---

### [PATTERN-008] Parameter Packs for N-Ary Types

**Statement**: Packages requiring n-ary heterogeneous products SHOULD use Swift's parameter packs.

```swift
// CORRECT
struct Product<each Element> {
    var elements: (repeat each Element)
}

// INCORRECT — Type-erased
struct Product {
    var elements: [Any]
}
```

**Cross-references**: [API-IMPL-002]

---

### Import Visibility as Module Contract

Swift 6 enforces that types used in `@inlinable` declarations MUST be visible to clients.

| Import Style | Dependency Visible | Use When |
|--------------|-------------------|----------|
| `import` (internal) | No | Encapsulating implementation details |
| `public import` | Yes | Creating facade modules, re-exporting APIs |

Import visibility MUST be consistent across a module's files. Use `public import` only where `@inlinable` code references the module's types by name.

**Cross-references**: [PATTERN-006], [API-LAYER-001], [PLAT-ARCH-006]

---

## Cross-References

See also:
- **swift-institute** skill for five-layer architecture [ARCH-LAYER-*]
- **code-surface** skill for namespace structure [API-NAME-001], specification-mirroring [API-NAME-003]
- **implementation** skill for API layering rules [API-LAYER-*]
- **memory** skill for [MEM-SAFE-002], [MEM-SAFE-003]
