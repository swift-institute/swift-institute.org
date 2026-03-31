---
name: benchmark
description: |
  Performance testing: .timed(), .build cleanup, same-package vs nested,
  comparison benchmarks.
  ALWAYS apply when writing or reviewing performance tests and benchmarks.

layer: implementation

requires:
  - testing

applies_to:
  - swift
  - swift6
  - swift-primitives
  - swift-standards
  - swift-foundations
last_reviewed: 2026-03-27
---

# Benchmark Conventions

Performance testing patterns for the Swift Institute ecosystem. Covers benchmark placement, `.timed()` trait usage, `.build` cleanup, comparison benchmarks, and result storage.

---

## Benchmark Placement

### [BENCH-001] Same-Package vs Nested Package Decision Tree

**Statement**: Benchmark test placement MUST follow the layer-based decision tree.

| Layer | Placement | Reason |
|-------|-----------|--------|
| **Foundations** | Same-package `.testTarget()` | swift-testing is reachable within the same superrepo |
| **Standards** | Same-package `.testTarget()` | swift-testing is reachable via relative path to swift-foundations |
| **Primitives** | Nested `Tests/Package.swift` | Layer constraint prevents direct swift-testing dependency in main Package.swift |

**Foundations / Standards** (same-package target):
```swift
// In Package.swift
.testTarget(
    name: "{Module} Performance Tests",
    dependencies: [
        "{Module}",
        .product(name: "Testing", package: "swift-testing"),
    ],
    path: "Tests/{Module} Performance Tests"
)
```

**Primitives** (nested package):
```swift
// In Tests/Package.swift
.testTarget(
    name: "{Module} Performance Tests",
    dependencies: [
        .product(name: "{Module}", package: "swift-{package}"),
        .product(name: "Testing", package: "swift-testing"),
    ],
    path: "{Module} Performance Tests"
)
```

**Rationale**: Foundations and standards can reach swift-testing without circular dependency issues. Primitives packages may be transitive dependencies of swift-testing itself, requiring the nested package to break cycles.

**Cross-references**: [INST-TEST-001] for the nested package pattern details.

---

## Build Cleanup

### [BENCH-002] .build Cleanup Requirement

**Statement**: Before running benchmarks, ALWAYS `rm -rf .build` from the benchmark directory (nested `Tests/` or same-package root). Stale build artifacts cause false results and confusing failures.

```bash
# Nested package benchmarks (primitives)
cd swift-{package}/Tests
rm -rf .build
swift test --filter Performance

# Same-package benchmarks (foundations/standards)
cd swift-{package}
rm -rf .build
swift test --filter Performance
```

**Rationale**: Incremental builds can produce measurement artifacts. A clean build ensures reproducible benchmark baselines. This was a recurring footgun in swift-io development.

---

## .timed() Trait

### [BENCH-003] .timed() Trait Usage

**Statement**: Performance tests MUST use the `.timed()` trait from swift-testing for structured measurement.

| Syntax | Purpose |
|--------|---------|
| `.timed()` | Measure with defaults (10 iterations, median) |
| `.timed(threshold: .milliseconds(N))` | Fail if median exceeds budget |
| `.timed(iterations: N, warmup: M)` | Exclude warmup from measurement |
| `.timed(iterations: N, threshold: .milliseconds(T), metric: .median)` | Full control |

**Parameters**:

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `iterations` | `Int` | 10 | Measured runs |
| `warmup` | `Int` | 0 | Untimed warmup runs |
| `threshold` | `Duration?` | nil | Fails if exceeded |
| `metric` | `Metric` | `.median` | Which metric to check |

**Correct**:
```swift
@Test(.timed(iterations: 100, warmup: 10))
func `sequential read`() {
    // Performance-critical code
}

@Test(.timed(iterations: 50, threshold: .milliseconds(50)))
func `must complete within 50ms`() {
    // Fails if median exceeds 50ms
}

@Test(.timed(threshold: .milliseconds(50)))
func `descriptive name`() {
    let data = ...
    _ = data.operation()
}
```

**Rationale**: Structured measurement with statistical analysis, thresholds, and trend detection.

**Origin**: TEST-015, INST-TEST-006, INST-TEST-007

---

### [BENCH-004] Performance Suite Serialization

**Statement**: Performance test suites MUST use `.serialized` trait to prevent parallel execution interference. The `#Tests` macro applies this automatically.

**Correct**:
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

**When using `#Tests`**:
```swift
extension {Type} {
    #Tests(snapshots: .init(recording: .missing))
}

extension {Type}.Test.Performance {
    @Test(.timed(threshold: .milliseconds(50)))
    func `operation within budget`() {
        // ...
    }
}
```

**Rationale**: Parallel test execution causes timing measurement variance. `#Tests` macro handles this automatically.

---

## Comparison Benchmarks

### [BENCH-005] Comparison Benchmark Pattern

**Statement**: When comparing performance of two implementations, benchmarks SHOULD use separate benchmark targets with identical test structure and shared fixture setup.

**Pattern** (e.g., `io-bench` vs `nio-bench`):
```
swift-{package}/
  Tests/
    {Module} IO Benchmarks/         # Implementation A
      {Operation} Benchmark.swift
    {Module} NIO Benchmarks/        # Implementation B (reference)
      {Operation} Benchmark.swift
```

Each benchmark file uses the same operations and data sizes:
```swift
@Suite(.serialized)
struct `Read Benchmark` {

    @Test(.timed(iterations: 100, warmup: 10, threshold: .milliseconds(5)))
    func `sequential read 4KB`() {
        // Same workload as comparison target
    }

    @Test(.timed(iterations: 100, warmup: 10, threshold: .milliseconds(50)))
    func `sequential read 1MB`() {
        // Same workload as comparison target
    }
}
```

**Rationale**: Identical test structure and data sizes enable direct performance comparison between implementations.

---

## Result Storage

### [BENCH-006] Benchmark Result Storage

**Statement**: Benchmark results SHOULD be stored in `.benchmarks/` relative to the benchmark root. This directory MUST be excluded from version control via `.gitignore`.

```
Tests/
  .benchmarks/           # Excluded from git
    {date}-{target}.json
  {Module} Performance Tests/
```

**Rationale**: Persistent local results enable trend tracking across development iterations without polluting the repository.

---

## Benchmark Fixtures

### [BENCH-007] Standardized Benchmark Fixtures

**Statement**: I/O benchmarks SHOULD use `IO.Benchmark.Fixture` from IO Test Support for standardized thread pool configuration.

```swift
import IO_Test_Support

@Suite(.serialized)
struct `IO Read Benchmark` {

    let fixture = IO.Benchmark.Fixture()

    @Test(.timed(iterations: 100, warmup: 10))
    func `sequential read`() throws {
        try fixture.withThreadPool { pool in
            // Benchmark code using standardized pool
        }
    }
}
```

**Rationale**: Shared fixture configuration eliminates thread pool setup variance between benchmark runs. Fixture provides consistent worker counts and shutdown semantics.

**Cross-references**: [TEST-026] for IO Test Support module reference.

---

## Build and Test Commands

### [BENCH-008] Build and Test Commands

**Statement**: Benchmark execution depends on placement pattern.

**Same-package benchmarks** (foundations/standards):
```bash
cd swift-{package}
rm -rf .build                          # [BENCH-002]
swift test --filter Performance
swift test --filter "Benchmark"        # Named benchmarks
```

**Nested package benchmarks** (primitives):
```bash
cd swift-{package}/Tests
rm -rf .build                          # [BENCH-002]
swift package resolve                  # First run only
swift test --filter Performance
swift test --filter "Benchmark"        # Named benchmarks
```

**Rationale**: The nested package has its own `.build/` directory and dependency graph.

**Origin**: INST-TEST-010

---

## Warmup Patterns

### [BENCH-009] Manual Warmup When .timed() Unavailable

**Statement**: When `.timed()` trait is unavailable (e.g., Apple Testing without swift-testing), performance tests MUST include explicit warmup loops.

**Correct**:
```swift
@Test
func `slice creation`() {
    let buffer = Memory.Buffer.Mutable.allocate(count: 1000, alignment: 1)
    defer { buffer.deallocate() }

    // Warmup
    for _ in 0..<10 {
        _ = buffer.slice(start: 0, count: 10)
    }

    // Measured
    for _ in 0..<100 {
        _ = buffer.slice(start: 0, count: 10)
    }
}
```

**Rationale**: Warmup eliminates cold-start variance from measurements.

**Origin**: TEST-016

---

## Cross-References

See also:
- **testing** skill — [TEST-*] for umbrella routing and test support infrastructure
- **testing-swiftlang** skill — [SWIFT-TEST-004] for performance suite serialization in Swift Testing
- **testing-institute** skill — [INST-TEST-001] for nested package pattern details
- **existing-infrastructure** skill — for IO Test Support module inventory
