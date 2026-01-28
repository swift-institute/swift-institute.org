# Swift 6 Features

<!--
---
title: Swift 6 Features
version: 1.0.0
last_updated: 2026-01-19
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Swift 6 language mode, upcoming features, experimental features, and parameter packs.

## Overview

This document defines patterns for Swift 6 language feature adoption.

**Applies to**: All packages in swift-primitives, swift-institute, and swift-standards.

**Does not apply to**: External dependencies or generated code.

---

## [PATTERN-005] Swift 6 Language Mode

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

**Cross-references**: [API-CONC-001], [PATTERN-006], [PATTERN-005a]

---

## [PATTERN-005a] Memory Safety Warnings as Design Feedback

**Scope**: Handling Swift 6 strict memory safety diagnostics.

**Statement**: `#StrictMemorySafety` warnings MUST be treated as design feedback, not noise. Each warning marks a site requiring eventual `unsafe` annotation.

> **Full details**: See <doc:Memory> section [MEM-SAFE-003] for warning classification (Bucket A vs Bucket B) and treatment guidance.

**Rationale**: The compiler doesn't prevent the work—it demands awareness. Treating safety warnings as collaborative feedback improves code quality.

**Cross-references**: [PATTERN-005], [API-PLAT-001], <doc:Memory>

---

## [PATTERN-005b] Expression Granularity of Unsafe

**Scope**: Applying `unsafe` markers to Swift 6 StrictMemorySafety warnings.

**Statement**: Swift 6's strict memory safety operates at expression granularity, not function granularity. An `@unsafe` attribute on a function declares that *calling* the function is unsafe, but says nothing about operations *within* the function. Each unsafe operation inside requires its own `unsafe` acknowledgment.

> **Full details**: See <doc:Memory> section [MEM-SAFE-002] for the granularity model, parenthesization patterns, and working examples.

**Key Pattern**: For assignments to unsafe storage, use parentheses: `unsafe (self.raw = value)`

**Rationale**: Expression-level granularity ensures each unsafe operation is explicitly acknowledged.

**Cross-references**: [PATTERN-005], [PATTERN-005a], [PATTERN-023], [API-NAME-008], <doc:Memory>

---

## [PATTERN-006] Upcoming Feature Flags

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

**Cross-references**: [PATTERN-005], [PATTERN-007]

---

## [PATTERN-007] Experimental Feature Flags

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

**Cross-references**: [API-ERR-005], [API-ERR-006], [PATTERN-006]

---

## [PATTERN-008] Parameter Packs for N-Ary Types

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

**Cross-references**: [API-IMPL-002]

---

## Import Visibility as Module Contract

**Scope**: Swift 6 import visibility and inlinable code.

Swift 6 enforces that types used in `@inlinable` or `@usableFromInline` declarations MUST be visible to clients. Import visibility determines re-export behavior and MUST be consistent across module files.

### The Visibility Model

```swift
// Internal import - Slab is invisible to downstream clients
import Storage_Primitives

// Public import - Slab is re-exported to downstream clients
public import Storage_Primitives
```

An internal import of a module with `@inlinable` public APIs will fail when clients try to use inlined code paths.

### Re-Export vs Encapsulation

| Import Style | Dependency Visible | Use When |
|--------------|-------------------|----------|
| `import` (internal) | No | Encapsulating implementation details |
| `public import` | Yes | Creating facade modules, re-exporting APIs |

The Swift 6 model forces explicit choice: are you re-exporting or encapsulating?

### Consistency Requirement

Import visibility MUST be consistent across a module's files. If one file uses `public import` and another uses internal import, behavior depends on which file's code path executes.

**Rationale**: Import visibility is part of the module contract. Inconsistent imports create unpredictable behavior.

**Cross-references**: [PATTERN-006], [API-LAYER-001]

---

## Topics

### Related Documents

- <doc:Implementation>
- <doc:Memory>
- <doc:Platform-Compilation>
