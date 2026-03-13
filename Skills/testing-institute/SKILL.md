---
name: testing-institute
description: |
  Nested package pattern for performance and snapshot testing using
  swift-foundations/swift-testing.
  ALWAYS apply when adding performance tests, snapshot tests, or any
  tests requiring swift-testing features to ANY ecosystem package.

layer: process

requires:
  - swift-institute-core
  - testing
  - platform

applies_to:
  - swift
  - swift6
  - swift-primitives
  - swift-standards
  - swift-foundations
---

# Institute Testing via Nested Packages

The Swift Institute ecosystem has two testing layers:

| Layer | Framework | Features | Where |
|-------|-----------|----------|-------|
| Unit + Edge Case | Apple Testing (toolchain) | `@Test`, `@Suite`, `#expect` | Main `Package.swift` test targets |
| Performance + Snapshot | swift-foundations/swift-testing | `.timed()`, `#snapshot`, `#Tests` macro | Nested `Tests/` package |

The nested package pattern keeps the swift-testing dependency isolated from the parent `Package.swift`. This is mandatory for all ecosystem packages — even those that are not transitive dependencies of swift-testing — to maintain a uniform structure and prevent swift-testing from polluting the main dependency graph.

---

## When to Use

### [INST-TEST-001] Nested Package Requirement

**Statement**: ALL ecosystem packages MUST use the nested `Tests/Package.swift` package pattern for performance tests, snapshot tests, and any tests requiring swift-testing features. Direct dependencies on swift-testing in a package's main `Package.swift` are forbidden.

**Rationale**: Uniformity. Every package follows the same structure regardless of whether it's a transitive dependency of swift-testing. This keeps main `Package.swift` files clean, avoids pulling swift-syntax and the full swift-testing dependency graph into regular builds, and makes the testing approach discoverable and consistent across primitives, standards, and foundations.

**Rationale**: SwiftPM does not allow circular dependencies.

---

## Directory Structure

### [INST-TEST-002] Nested Package Location

**Statement**: The nested testing package MUST be located at `Tests/Package.swift` within the parent package. All test directories — both Apple Testing (unit) and swift-testing (performance, snapshot) — are flat siblings under `Tests/`.

**Statement**: The parent `Package.swift` MUST declare test targets with explicit `path:` parameters, since SwiftPM skips automatic target discovery in directories with their own `Package.swift`.

**Correct**:
```
swift-{package}/
  Package.swift                          # Parent — explicit path: for test targets
  Sources/
    {Module}/
  Tests/
    Package.swift                        # Nested — depends on parent + swift-testing
    {Module} Tests/                      # Apple Testing (unit + edge case)
    {Module} Performance Tests/          # swift-testing performance tests
      {Type} Performance Tests.swift
    {Module} Snapshot Tests/             # swift-testing snapshot tests
      {Type} Snapshot Tests.swift
      __Snapshots__/                     # Committed reference files
```

**Parent Package.swift** test target declaration:
```swift
.testTarget(
    name: "{Module} Tests",
    dependencies: [...],
    path: "Tests/{Module} Tests"         // explicit path required
)
```

**Rationale**: SwiftPM ignores subdirectories with their own `Package.swift` during automatic target discovery, but explicit `path:` overrides this. The flat sibling layout eliminates the `Tests/Testing/Tests/` stutter (validated by experiment `nested-package-source-ownership`). A single nested package avoids duplicating swift-syntax compilation (~40MB) across multiple nested packages.

---

### [INST-TEST-003] `#Tests` Macro Scaffolding (Recommended)

**Statement**: Packages that define their own types SHOULD use the `#Tests` macro for test scaffolding. This generates standardized suites including `.Performance` and `.Snapshot` with correct traits applied.

**Pattern**:
```swift
import Testing
@testable import {Module}

extension {Type} {
    #Tests(snapshots: .init(recording: .missing))
}

extension {Type}.Test.Performance {
    @Test(.timed(threshold: .milliseconds(50)))
    func `operation within budget`() {
        // ...
    }
}

extension {Type}.Test.Snapshot {
    @Test
    func `output format`() {
        #snapshot(instance.render(), as: .lines)
    }
}
```

**When `#Tests` does NOT apply**: Tests on stdlib types or protocols you don't own (e.g., `Sequence` extensions). Use manual `@Suite` instead.

**Rationale**: `#Tests` generates Unit/EdgeCase/Integration/Performance/Snapshot suites with `.serialized` and `.exclusive` traits pre-applied. Consistent scaffolding across the ecosystem.

---

## Package.swift Configuration

### [INST-TEST-004] Nested Package.swift Template

**Statement**: The nested `Package.swift` MUST declare dependencies on the parent package via `..` and on swift-testing via relative path. Test targets MUST use explicit `path:` parameters since the package root is `Tests/` (SwiftPM would otherwise look for targets in `Tests/Tests/`).

**Template**:
```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "testing",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        .package(path: ".."),
        .package(path: "{relative-path-to-swift-testing}"),
    ],
    targets: [
        .testTarget(
            name: "{Module} Performance Tests",
            dependencies: [
                .product(name: "{Module}", package: "swift-{package}"),
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "{Module} Performance Tests"
        ),
        .testTarget(
            name: "{Module} Snapshot Tests",
            dependencies: [
                .product(name: "{Module}", package: "swift-{package}"),
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "{Module} Snapshot Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
```

**Rationale**: Relative paths keep everything self-contained. Ecosystem Swift settings match parent conventions. Package name is always `testing`.

---

### [INST-TEST-005] Relative Path Calculation

**Statement**: Relative paths MUST be calculated from `Tests/` as the working directory.

| Parent Repo | Path to parent | Path to swift-testing |
|-------------|---------------|----------------------|
| `swift-primitives/swift-{pkg}/` | `..` | `../../../swift-foundations/swift-testing` |
| `swift-standards/swift-{pkg}/` | `..` | `../../../swift-foundations/swift-testing` |
| `swift-foundations/swift-{pkg}/` | `..` | `../../swift-testing` |

The parent package is always `..`.

**Rationale**: Incorrect relative paths cause "no package found" errors.

---

## Performance Tests

### [INST-TEST-006] Performance Test Structure

**Statement**: Performance test suites MUST use `.serialized` (or `#Tests` which applies it automatically) to prevent interference between measurements.

```swift
@Suite(.serialized)
struct `{Type} - Performance` {

    @Test(.timed(threshold: .milliseconds(50)))
    func `descriptive name`() {
        let data = ...
        _ = data.operation()
    }
}
```

---

### [INST-TEST-007] Performance Trait Usage

**Statement**: Performance tests MUST use the `.timed()` trait.

| Syntax | Purpose |
|--------|---------|
| `.timed()` | Measure with defaults (10 iterations, median) |
| `.timed(threshold: .milliseconds(N))` | Fail if median exceeds budget |
| `.timed(iterations: N, warmup: M)` | Exclude warmup from measurement |
| `.timed(iterations: N, threshold: .milliseconds(T), metric: .median)` | Full control |

**Rationale**: Structured measurement with statistical analysis, thresholds, and trend detection.

---

## Snapshot Tests

### [INST-TEST-008] Snapshot Test Structure

**Statement**: Snapshot tests SHOULD use `#snapshot` for assertions. Snapshot reference files are stored in `__Snapshots__/` relative to the test source and MUST be committed to version control.

**Inline snapshot** (expected value in source):
```swift
@Test
func `output format`() {
    #snapshot(instance.description, as: .lines)
    // First run records; subsequent runs compare
}
```

**Named file-backed snapshot**:
```swift
@Test
func `complex output`() {
    #snapshot(instance.render(), as: .lines, named: "rendered")
}
```

**Inline with explicit expected value** (trailing closure):
```swift
@Test
func `known output`() {
    #snapshot(value.description, as: .lines) {
        """
        expected output
        """
    }
}
```

**Recording modes**:

| Mode | Behavior |
|------|----------|
| `.missing` | Record new, compare existing (default) |
| `.all` | Always record/update (development) |
| `.failed` | Record on failure, still fail |
| `.never` | Compare only, fail if missing (CI) |

---

### [INST-TEST-009] Snapshot Configuration with `#Tests`

**Statement**: When using `#Tests`, snapshot recording mode SHOULD be configured in the macro call.

```swift
extension MyType {
    #Tests(snapshots: .init(recording: .missing))
}
```

**Rationale**: Centralizes snapshot configuration per type rather than scattering it across individual tests.

---

## Building and Running

### [INST-TEST-010] Build and Test Commands

**Statement**: Unit tests run from the parent package root. Performance and snapshot tests run from `Tests/`.

```bash
# Unit tests (Apple Testing)
cd swift-{package}
swift test

# Performance + snapshot tests (swift-testing)
cd swift-{package}/Tests
swift package resolve    # First run only
swift test

# Filter by target:
swift test --filter Performance
swift test --filter Snapshot
```

**Rationale**: The nested package has its own `.build/` directory and dependency graph.

---

## Build Artifacts

### [INST-TEST-011] .gitignore

**Statement**: The nested `.build/`, `.swiftpm/`, and `.benchmarks/` directories SHOULD be excluded via `.gitignore`. The parent package's gitignore typically covers this already.

---

## Migration from `Tests/Testing/` (Legacy)

### [INST-TEST-012] Migration Procedure

**Statement**: Packages using the legacy `Tests/Testing/` pattern SHOULD migrate to `Tests/Package.swift`.

| Step | Action |
|------|--------|
| 1 | Move `Tests/Testing/Tests/{Module} * Tests/` → `Tests/{Module} * Tests/` |
| 2 | Move `Tests/Testing/Package.swift` → `Tests/Package.swift` |
| 3 | Update nested `Package.swift`: parent `../..` → `..`, swift-testing path loses one `../` |
| 4 | Add explicit `path:` to nested test targets (e.g., `path: "{Module} Snapshot Tests"`) |
| 5 | Add explicit `path:` to parent `Package.swift` test targets (e.g., `path: "Tests/{Module} Tests"`) |
| 6 | Remove old `Tests/Testing/` directory |
| 7 | Verify: `swift test` from parent runs unit tests only; `swift test` from `Tests/` runs performance + snapshot |

**Rationale**: Eliminates the `Tests/Testing/Tests/` stutter and reduces `__Snapshots__/` path depth from 5 to 3 levels.

---

## Cross-References

- **testing** skill — [TEST-*] for unit test organization with Apple Testing
- **platform** skill — [PLAT-ARCH-*] for Package.swift configuration
- Research: `swift-institute/Research/nested-testing-package-flattening.md`
- Research: `swift-institute/Research/nested-testing-package-structure.md`
- Experiment: `swift-institute/Experiments/nested-package-source-ownership/`
