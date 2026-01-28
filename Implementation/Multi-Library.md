# Multi-Library Products

<!--
---
title: Multi-Library Products
version: 1.0.0
last_updated: 2026-01-19
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Fine-grained library exposure and circular dependency breaking.

## Overview

This document defines patterns for multi-library product organization and circular dependency resolution.

---

## [PATTERN-002] Fine-Grained Library Exposure

**Applies to**: Complex packages with separable functionality.

**Does not apply to**: Simple packages with a single coherent API surface.

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

**Cross-references**: [API-LAYER-001], [PATTERN-001]

---

## [PATTERN-003] Nested Test Package Pattern

**Applies to**: Packages with potential circular dependencies with test frameworks.

**Does not apply to**: Packages without test framework dependencies in their core target.

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

**Cross-references**: [API-LAYER-001]

---

## Topics

### Related Documents

- <doc:Implementation>
- <doc:C-Shims>
- <doc:Platform-Compilation>
