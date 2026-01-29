---
name: platform
description: |
  Build infrastructure, platform compilation, Swift 6 features, C shims, multi-library products.
  ALWAYS apply when configuring Package.swift, platform conditionals, or Swift feature flags.

layer: implementation

requires:
  - swift-institute

applies_to:
  - swift
  - swift6
  - primitives
  - standards

migrated_from:
  - Implementation/C Shims.md
  - Implementation/Multi-Library.md
  - Implementation/Platform Compilation.md
  - Implementation/Swift 6.md
migration_date: 2026-01-28
---

# Platform & Build Infrastructure

Build configuration, platform compilation, Swift 6 feature adoption, C shims, and multi-library products.

---

## C Shims

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

**Cross-references**: [PRIM-ORG-003], [PATTERN-004c]

---

## Multi-Library Products

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

## Platform Compilation

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

**Cross-references**: [PATTERN-004]

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

**Cross-references**: [PATTERN-004], [PRIM-ORG-003]

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

**Cross-references**: [PATTERN-004b], [API-NAME-001]

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

## Swift 6 Features

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

See **memory-safety** skill [MEM-SAFE-003] for warning classification (Bucket A vs Bucket B).

**Cross-references**: [PATTERN-005], [MEM-SAFE-003]

---

### [PATTERN-005b] Expression Granularity of Unsafe

**Statement**: Swift 6's strict memory safety operates at expression granularity. An `@unsafe` on a function declares *calling* is unsafe; operations *within* still require individual `unsafe` markers.

Key pattern: `unsafe (self.raw = value)` for assignments to unsafe storage.

See **memory-safety** skill [MEM-SAFE-002] for full details.

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

**Cross-references**: [PATTERN-006], [API-LAYER-001]

---

## Cross-References

See also:
- **swift-institute** skill for five-layer architecture
- **memory-safety** skill for [MEM-SAFE-002], [MEM-SAFE-003]
- **design** skill for [API-LAYER-*] layering rules
