# Platform Compilation

<!--
---
title: Platform Compilation
version: 1.0.0
last_updated: 2026-01-19
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Conditional platform compilation, `#if os()` vs `canImport`, module normalization, and linker flags.

## Overview

This document defines patterns for platform-specific code compilation.

**Applies to**: Platform-specific target dependencies and source-level conditionals.

**Does not apply to**: Platform-agnostic code.

---

## [PATTERN-004] SwiftPM Platform Conditions

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

**Cross-references**: [API-PLAT-001]

---

## [PATTERN-004a] Source-Level Platform Conditionals

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

### Why `os()` Over `canImport`

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

**Cross-references**: [PATTERN-004], [API-PLAT-001]

---

## [PATTERN-004b] Module Name Normalization

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

### Normalization Rule

| Package.swift Target | Import Identifier |
|---------------------|-------------------|
| `"Darwin Kernel Primitives"` | `Darwin_Kernel_Primitives` |
| `"Real Primitives"` | `Real_Primitives` |
| `"IO Primitives"` | `IO_Primitives` |

The normalization is invisible until you need to reference it in import statements or fully-qualified type paths. The underscore convention applies to all targets with spaces.

**Rationale**: Understanding the normalization rule prevents confusion when imports fail. Swift requires valid identifiers, and underscores replace spaces automatically.

**Cross-references**: [API-NAME-001], [PATTERN-004a]

---

## [PATTERN-004c] C Library Linker Flags

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

### Platform Library Requirements

| Platform | Library | Linked By Default | Notes |
|----------|---------|-------------------|-------|
| Darwin | libc (uuid_parse) | Yes | Part of system library |
| Linux | libuuid | No | Requires `-luuid`, libuuid-dev package |
| Windows | Rpcrt4.lib | Yes | Part of Windows SDK |

Linux's modular library architecture is the exception. Darwin and Windows include UUID functions in their default system libraries. The linker flag captures Linux's requirement explicitly.

**Documentation Requirement**: When a package requires external library installation (like `libuuid-dev`), the README MUST document this prerequisite.

**Rationale**: Explicit linker flags make C-level dependencies visible and prevent mysterious link failures. Platform conditions ensure the flag only applies where needed.

**Cross-references**: [PATTERN-004], [PRIM-ORG-003]

---

## Namespace Collision Handling

**Scope**: Types that collide with system module names.

When a Swift type name collides with a system C module (e.g., `Darwin` type vs Apple's `Darwin` module), usage sites MUST use fully-qualified paths with module prefixes.

**Correct**:
```swift
// Explicit module qualification resolves collision
let uuid = Darwin_Primitives.Darwin.Identity.UUID.parse(string)

// Import and use nested typealias for frequently-used types
import Darwin_Primitives
enum Local {}
extension Local {
    typealias UUID = Darwin_Primitives.Darwin.Identity.UUID
}
```

**Incorrect**:
```swift
// ❌ Ambiguous - which Darwin?
let uuid = Darwin.Identity.UUID.parse(string)  // Compiler error or wrong type
```

### Common Collisions

| Type Name | Collides With | Resolution |
|-----------|---------------|------------|
| `Darwin` | Apple's Darwin C module | `Darwin_Primitives.Darwin` |
| `Foundation` | Apple's Foundation | Avoid; primitives don't use Foundation |
| `System` | Apple's System module | `System_Primitives.System` |

This will recur: any name matching a system header becomes contested namespace. The workaround scales—always qualify at usage sites when ambiguity is possible.

**Rationale**: Explicit module qualification makes namespace ownership visible. `Darwin_Primitives.Darwin` is unambiguously "our" Darwin, distinct from the system's.

**Cross-references**: [PATTERN-004b], [API-NAME-001]

---

## Conditional Compilation Foresight

**Scope**: Anticipatory feature guards for future compilation modes.

Packages SHOULD include conditional compilation guards for known future features (Embedded Swift, WebAssembly) even before those features are used. Foresight guards enable zero-modification compilation when the future arrives.

**The Pattern**:
```swift
// Added proactively, months before Embedded compilation was attempted
#if !hasFeature(Embedded)
extension Tagged: Codable where RawValue: Codable { ... }
#endif
```

When Embedded compilation was attempted months later, the package compiled without modification.

### Foresight vs Remediation

| Approach | Effort | Risk |
|----------|--------|------|
| **Foresight** (guards added early) | 5 lines during initial development | None—guards are no-ops until needed |
| **Remediation** (guards added later) | Hours of investigation + refactoring | Breaking changes, missed edge cases |

### When to Add Foresight Guards

Add `#if` guards when using features known to be unavailable in compilation modes you might target:

| Feature | Embedded | WebAssembly |
|---------|----------|-------------|
| `Codable` | Unavailable | Usually available |
| Existentials (`any`) | Unavailable | Available |
| Runtime reflection | Unavailable | Limited |
| Foundation types | Unavailable | Platform-dependent |

**Rationale**: Foresight guards cost nothing when unused and save hours when needed. The five lines of conditional compilation in initial development prevent hours of potential remediation.

**Cross-references**: [PATTERN-004], [API-PLAT-001]

---

## Topics

### Related Documents

- <doc:Implementation>
- <doc:C-Shims>
- <doc:Swift-6>
