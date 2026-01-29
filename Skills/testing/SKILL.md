---
name: testing
description: |
  Test organization patterns using Swift Testing framework.
  ALWAYS apply when writing or reviewing test code.

layer: implementation

requires:
  - swift-institute
  - naming
  - code-organization

applies_to:
  - swift
  - swift6
  - primitives
  - standards
  - foundations
  - tests
---

# Testing Conventions

Test organization patterns using Swift Testing framework. These rules ensure consistent test structure across all packages.

---

## Testing Framework

### [TEST-001] Framework Selection

**Statement**: All tests MUST use Swift Testing framework (not XCTest).

**Correct**:
```swift
import Testing

@Test("description")
func testName() { }
```

**Incorrect**:
```swift
import XCTest

class MyTests: XCTestCase {  // ❌ XCTest forbidden
    func testSomething() { }
}
```

**Rationale**: Swift Testing provides better ergonomics, nested suites, and is the future direction for Swift testing.

---

### [TEST-002] TestSuites Macro Usage

**Statement**: When available, types SHOULD use `#TestSuites` (current) or `#Tests` (future) macro to generate standard suite structure.

**Current** (swift-testing-extras):
```swift
import Testing_Extras

extension YourType {
    #TestSuites
}
// Generates: YourType.Test.{Unit, EdgeCase, Integration, Performance}
```

**Future** (swift-foundations/swift-testing):
```swift
import Testing

extension YourType {
    #Tests
}
// Generates: YourType.Test.{Unit, EdgeCase, Integration, Performance, Snapshot}
```

**When macro unavailable** (manual creation):
```swift
extension YourType {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}
```

**Rationale**: Macros ensure consistent structure; manual fallback maintains compatibility.

---

## Test Suite Organization

### [TEST-003] Type Extension Pattern

**Statement**: Non-generic types MUST use the type extension pattern for test suites.

**Correct**:
```swift
extension Memory.Buffer {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension Memory.Buffer.Test.Unit {
    @Test("init creates empty buffer")
    func initEmpty() { }
}
```

**Incorrect**:
```swift
@Suite struct MemoryBufferTests {  // ❌ Compound name, not nested
    @Test func test() { }
}
```

**Rationale**: Type extension mirrors [API-NAME-001] Nest.Name pattern. Test hierarchy matches type hierarchy.

**Cross-references**: [API-NAME-001], [API-NAME-002]

---

### [TEST-004] Generic Type Exception

**Statement**: Generic type specializations MUST use parallel namespace pattern due to Swift Testing discovery limitation.

**Context**: `@Suite` in extensions of generic type specializations (e.g., `extension Container<Int>`) is silently not discovered. See [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508).

**Correct** (generic type):
```swift
// Generic type
struct Index<Tag> { }

// Tests use parallel namespace
@Suite("Index")
struct IndexTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}

extension IndexTests.Unit {
    @Test("init with valid position")
    func initWithValidPosition() { }
}
```

**Incorrect** (would compile but tests never run):
```swift
extension Index<Int> {
    @Suite struct Test {  // ❌ Never discovered
        @Test func bug() { }
    }
}
```

**Rationale**: Workaround for Swift Testing framework limitation. Issue filed, awaiting fix.

---

### [TEST-005] Test Category Suites

**Statement**: Test suites MUST include four standard categories. Additional semantic sub-suites MAY be added within categories.

| Suite | Purpose | Trait |
|-------|---------|-------|
| `Unit` | Isolated functionality tests | — |
| `EdgeCase` | Boundary conditions, error paths | — |
| `Integration` | Cross-component behavior | — |
| `Performance` | Timing and allocation tracking | `.serialized` |

**Standard structure**:
```swift
@Suite struct Test {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
}
```

**With semantic sub-suites**:
```swift
extension Pointer.Arithmetic.Test {
    @Suite struct Basics {}
    @Suite struct Advance {}
    @Suite struct Distance {}
}
```

**Rationale**: Fixed categories enable cross-package grep ("find all edge cases"). Semantic sub-suites provide domain-specific organization.

---

### [TEST-006] Performance Suite Serialization

**Statement**: Performance test suites MUST use `.serialized` trait to prevent parallel execution interference.

**Correct**:
```swift
@Suite(.serialized) struct Performance {}
```

**Incorrect**:
```swift
@Suite struct Performance {}  // ❌ Missing .serialized
```

**Rationale**: Parallel test execution causes timing measurement variance.

---

## Test Function Conventions

### [TEST-007] Test Naming Pattern

**Statement**: Test functions MUST use action-outcome naming with `@Test("description")` for display.

**Pattern**: `<action><Outcome>`

**Correct**:
```swift
@Test("init creates empty buffer with sentinel")
func initEmpty() { }

@Test("allocate updates offset")
func allocateUpdatesOffset() { }

@Test("slice returns nil for out-of-bounds")
func sliceOutOfBounds() { }
```

**Incorrect**:
```swift
@Test
func testThatInitCreatesEmptyBuffer() { }  // ❌ Verbose function name

func initEmpty() { }  // ❌ Missing @Test attribute
```

**Rationale**: Display name provides human readability; function name provides searchability.

---

### [TEST-008] Test Implementation Pattern

**Statement**: Tests MUST follow arrange-act-assert pattern. Setup MAY use `defer` for cleanup.

**Correct**:
```swift
@Test("allocate creates buffer with specified size")
func allocate() {
    // Arrange
    let count: Memory.Address.Count = 100

    // Act
    let buffer = Memory.Buffer.Mutable.allocate(count: count, alignment: 8)
    defer { buffer.deallocate() }

    // Assert
    #expect(!buffer.isEmpty)
    #expect(buffer.count == 100)
}
```

**Rationale**: Clear structure aids readability and maintenance.

---

## Test File Organization

### [TEST-009] File Naming Convention

**Statement**: Test files MUST be named `{TypePath} Tests.swift`, mirroring the type hierarchy.

**Correct**:
```
Tests/Memory Primitives Tests/
├── Memory.Buffer Tests.swift
├── Memory.Buffer.Mutable Tests.swift
├── Memory.Arena Tests.swift
└── Memory Arithmetic Tests.swift
```

**Incorrect**:
```
Tests/Memory Primitives Tests/
├── MemoryBufferTests.swift      // ❌ No space before "Tests"
├── BufferTests.swift            // ❌ Missing type hierarchy
└── AllMemoryTests.swift         // ❌ Combined tests
```

**Rationale**: Mirrors [API-IMPL-005] one type per file; enables predictable navigation.

**Cross-references**: [API-IMPL-005]

---

### [TEST-010] Test Support Targets

**Statement**: Packages MAY provide `{Module} Test Support` library for shared test utilities. Test Support MUST re-export dependency test support modules.

**Package.swift**:
```swift
.library(
    name: "Memory Primitives Test Support",
    targets: ["Memory Primitives Test Support"]
),
.target(
    name: "Memory Primitives Test Support",
    dependencies: [
        "Memory Primitives",
        .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
    ],
    path: "Tests/Support"
),
```

**Test Support directory**:
```
Tests/Support/
├── exports.swift                              // Re-exports
└── Memory Primitives Test Support.swift       // Shared utilities
```

**Rationale**: Transitive re-exports simplify test imports; shared utilities reduce duplication.

---

## Testing ~Copyable Types

### [TEST-011] Observable Property Testing

**Statement**: ~Copyable types MUST be tested via observable properties rather than copying values.

**Correct**:
```swift
@Test("init with capacity")
func initWithCapacity() {
    let arena = Memory.Arena(capacity: 1024)

    // Test via properties (non-consuming)
    #expect(arena.capacity.rawValue == 1024)
    #expect(arena.allocated.rawValue == 0)
    #expect(arena.remaining.rawValue == 1024)
}
```

**Incorrect**:
```swift
@Test("arena equality")
func arenaEquality() {
    let arena1 = Memory.Arena(capacity: 1024)
    let arena2 = arena1  // ❌ Cannot copy ~Copyable
    #expect(arena1 == arena2)
}
```

**Rationale**: ~Copyable types cannot be copied; test through properties that borrow self.

---

### [TEST-012] Mutation Testing Pattern

**Statement**: ~Copyable mutation tests MUST use `var` bindings and test state changes in place.

**Correct**:
```swift
@Test("reset restores full capacity")
func reset() {
    var arena = Memory.Arena(capacity: 1024)

    _ = arena.allocate(count: 500, alignment: 8)
    #expect(arena.remaining.rawValue < 1024)

    arena.reset()  // Mutates in place
    #expect(arena.allocated.rawValue == 0)
    #expect(arena.remaining.rawValue == 1024)
}
```

**Rationale**: Mutation via inout avoids copying.

---

### [TEST-013] Consuming Operation Testing

**Statement**: Consuming operations MUST be tested at the end of a test, after all other assertions.

**Correct**:
```swift
@Test("move transfers value")
func moveTransfersValue() {
    let ptr = Pointer<Int>.Mutable.allocate(capacity: 1)
    defer { ptr.deallocate() }

    ptr.initialize(to: 42)

    // Consuming operation at end
    let moved = ptr.move()
    #expect(moved == 42)
}
```

**Incorrect**:
```swift
@Test("move and continue")
func moveAndContinue() {
    let ptr = Pointer<Int>.Mutable.allocate(capacity: 1)
    ptr.initialize(to: 42)
    let moved = ptr.move()
    #expect(ptr.pointee == 42)  // ❌ Undefined after move
}
```

**Rationale**: Consuming destroys the value; no further operations are valid.

---

### [TEST-014] Helper Functions for ~Copyable

**Statement**: Helper functions operating on ~Copyable types MUST use `borrowing` parameter.

**Correct**:
```swift
func toArray<Element: Hashable>(
    _ set: borrowing Set<Element>.Ordered
) -> [Element] {
    var result: [Element] = []
    for i in 0..<set.count {
        result.append(set[i])
    }
    return result
}
```

**Incorrect**:
```swift
func toArray<Element: Hashable>(
    _ set: Set<Element>.Ordered  // ❌ Would consume
) -> [Element] { }
```

**Rationale**: `borrowing` enables read-only access without consuming.

---

## Performance Testing

### [TEST-015] Timed Test Configuration

**Statement**: Performance tests MUST specify `iterations`. SHOULD specify `warmup`. MAY specify `threshold`.

**Correct**:
```swift
@Test("sequential read", .timed(iterations: 100, warmup: 10))
func sequentialRead() {
    // Performance-critical code
}

@Test("must complete within 50ms", .timed(iterations: 50, threshold: .milliseconds(50)))
func fastOperation() {
    // Fails if median exceeds 50ms
}
```

**Parameters**:

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `iterations` | `Int` | 10 | Measured runs |
| `warmup` | `Int` | 0 | Untimed warmup runs |
| `threshold` | `Duration?` | nil | Fails if exceeded |
| `metric` | `Metric` | `.median` | Which metric to check |

**Rationale**: Consistent measurement configuration enables meaningful comparisons.

---

### [TEST-016] Manual Warmup Pattern

**Statement**: When `.timed()` trait is unavailable, performance tests MUST include explicit warmup loops.

**Correct**:
```swift
@Test("slice creation")
func sliceCreation() {
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

---

## Model Testing

### [TEST-017] Model-Based Testing

**Statement**: Complex data structures SHOULD include model tests that compare behavior against a reference implementation.

**Pattern**:
```swift
@Suite("Set.Ordered - Model Tests")
struct OrderedSetModelTests {

    struct ReferenceModel<Element: Hashable> {
        var elements: [Element] = []
        var set: Swift.Set<Element> = []

        mutating func insert(_ element: Element) -> Bool {
            guard !set.contains(element) else { return false }
            set.insert(element)
            elements.append(element)
            return true
        }
    }

    @Test("random operations match model")
    func randomOperations() {
        var sut = Set<Int>.Ordered()
        var model = ReferenceModel<Int>()

        for i in 0..<100 {
            let sutResult = sut.insert(i).inserted
            let modelResult = model.insert(i)
            #expect(sutResult == modelResult)
        }

        #expect(sut.count == model.elements.count)
    }
}
```

**Rationale**: Model tests verify invariants across many operations, catching subtle bugs.

---

## Cross-References

See also:
- **naming** skill for [API-NAME-001] Nest.Name pattern
- **code-organization** skill for [API-IMPL-005] one type per file
- `Documentation.docc/Testing Requirements.md` for detailed testing documentation
- [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508) for generic type limitation
