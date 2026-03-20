---
name: testing
description: |
  Test organization patterns using Swift Testing framework.
  ALWAYS apply when writing or reviewing test code.

layer: implementation

requires:
  - swift-institute
  - code-surface

applies_to:
  - swift
  - swift6
  - primitives
  - standards
  - foundations
  - tests
last_reviewed: 2026-03-20
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
    @Test
    func `init creates empty buffer`() { }
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
    @Test
    func `init with valid position`() { }
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

**Statement**: Test functions MUST use `@Test` without string parameter. Function names MUST use backticks with descriptive sentences.

**Correct**:
```swift
@Test
func `Memory.Address from UnsafeRawPointer preserves identity`() { }

@Test
func `Advance address by positive offset`() { }

@Test
func `Distance is antisymmetric: a→b == -(b→a)`() { }

@Test
func `Round-trip: address + distance(to: other) == other`() { }
```

**Incorrect**:
```swift
@Test("init creates empty buffer")  // ❌ String parameter
func initEmpty() { }

@Test
func initEmpty() { }  // ❌ No backticks, not descriptive

@Test
func testThatInitCreatesEmptyBuffer() { }  // ❌ No backticks
```

**Rationale**: Backtick names provide single source of truth — the function name IS the description. No duplication, fully searchable, readable in test output.

---

### [TEST-008] Test Implementation Pattern

**Statement**: Tests MUST follow arrange-act-assert pattern. Setup MAY use `defer` for cleanup.

**Correct**:
```swift
@Test
func `allocate creates buffer with specified size`() {
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

## Test Support Infrastructure

### [TEST-025] Using Test Support — Quick Start

**Statement**: Tests MUST import their package's Test Support module to get literal conformances, factory methods, and transitive access to all upstream utilities. A single import replaces the need for manual type construction.

**The single import**:
```swift
import Memory_Primitives_Test_Support
```

This one import transitively provides: `Memory_Primitives`, `Index_Primitives_Test_Support`, `Vector_Primitives_Test_Support`, `Identity_Primitives_Test_Support`, `Ordinal_Primitives_Test_Support`, `Cardinal_Primitives_Test_Support`, and `Affine_Primitives_Test_Support` — every upstream module and its test utilities.

#### Index, Offset, and Count as Integer Literals

The most important capability Test Support provides is `ExpressibleByIntegerLiteral` for all `Tagged` types. Since `Index<T>`, `Index<T>.Offset`, `Index<T>.Count`, `Ordinal`, and `Cardinal` are all `Tagged`, you can write:

```swift
import Index_Primitives_Test_Support

private enum IntTag {}

@Test
func `advance index by positive offset`() {
    let index: Index<IntTag> = 5
    let offset: Index<IntTag>.Offset = 3
    let result = index.advanced(by: offset)
    #expect(result == 8)
}

@Test
func `count from range`() {
    let start: Index<IntTag> = 2
    let end: Index<IntTag> = 7
    let count: Index<IntTag>.Count = 5
    #expect(end - start == count)
}

@Test
func `negative offset`() {
    let offset: Index<IntTag>.Offset = -3
    #expect(offset == -3)
}

@Test
func `ordinal and cardinal`() {
    let ord: Ordinal = 1
    let card: Cardinal = 42
    #expect(ord.rawValue == 1)
    #expect(card.rawValue == 42)
}
```

**Without Test Support** (never do this in tests):
```swift
// ❌ Manual construction — verbose and obscures intent
let index = Index<IntTag>(position: Tagged(__unchecked: (), 5))
let offset = Index<IntTag>.Offset(Tagged(__unchecked: (), 3))

// ❌ Unwrapping through rawValue chains for comparison
#expect(index.position.rawValue == 5)
```

#### Comparison with Literals

Literal conformances also enable direct comparison with `#expect`:

```swift
let index: Index<IntTag> = 10
#expect(index == 10)        // ✅ Direct comparison
#expect(index != 0)         // ✅
#expect(index > 5)          // ✅ (if Comparable)

// ❌ Do not unwrap for comparison
#expect(index.position.rawValue == 10)  // ❌ Unnecessary
```

#### Bit.Index with Literals

```swift
import Bit_Index_Primitives_Test_Support

@Test
func `Bit.Index from byte index`() {
    let byteIndex: Index<UInt8> = 3
    let bitIndex = Bit.Index(byteIndex)
    #expect(bitIndex == 24)
}
```

#### Buffer Factory Methods

```swift
import Buffer_Primitives_Test_Support

@Test
func `ring buffer append and remove`() {
    var buffer = Buffer<Int>.Ring.with([10, 20, 30])
    #expect(buffer.count == 3)

    buffer.append(40)
    #expect(buffer.count == 4)
}

@Test
func `linear buffer from array`() {
    let buffer = Buffer<Int>.Linear.with([1, 2, 3, 4, 5])
    #expect(buffer.count == 5)
}

@Test
func `inline buffer`() {
    let buffer = Buffer<Int>.Linear.Inline<8>.with([10, 20, 30])
    #expect(buffer.count == 3)
}
```

#### Vectors from Swift Ranges

```swift
import Vector_Primitives_Test_Support

@Test
func `vector from Swift range`() {
    let vector = try Vector(0..<10) { $0 }
    #expect(vector.count == 10)
}

@Test
func `vector with transform`() {
    let vector = try Vector(0..<5) { $0 * 2 }
    // Produces: 0, 2, 4, 6, 8
}
```

#### Temporary Files and Directories

```swift
import File_System_Test_Support

@Test
func `write and read file`() throws {
    try File.temporary(extension: "txt") { path in
        try File.write("hello", to: path)
        let content = try File.read(from: path)
        #expect(content == "hello")
    }
    // Path automatically cleaned up
}

@Test
func `scoped temporary directory`() throws {
    try File.Directory.temporary { directory in
        let file = directory.appending("test.txt")
        try File.write("data", to: file)
        #expect(try File.exists(at: file))
    }
    // Directory automatically cleaned up
}
```

#### Thread Coordination Harnesses

```swift
import Kernel_Test_Support

@Test
func `thread coordination`() {
    let harness = KernelThreadTest.Harness(0)
    let gate = Gate()
    let signal = Signal()

    // Thread: wait for gate, update state, signal completion
    Thread.detach {
        gate.wait()
        harness.update { $0 += 1 }
        signal.signal()
    }

    gate.open()
    signal.wait()
    harness.withLocked { #expect($0 == 1) }
}
```

#### Dependency Overrides

```swift
import Dependencies_Test_Support

@Suite(.dependencies)  // Isolates test dependencies
struct MyFeatureTests {
    @Test(.dependency(\.clock, .immediate))
    func `timer fires immediately`() {
        // clock dependency overridden to .immediate
    }

    @Test(.dependencies { $0.apiClient = .mock })
    func `uses mock API client`() {
        // apiClient dependency overridden
    }
}
```

**Rationale**: Test Support exists to make tests readable. Literal conformances, factory methods, and harnesses eliminate boilerplate so tests focus on behavior under test.

---

### [TEST-026] Test Support Module Reference

**Statement**: This is the complete inventory of all Test Support modules and their unique API surface.

#### Primitives Layer — Literal Conformances

| Module | Unique API | What It Enables |
|--------|-----------|-----------------|
| **Identity Primitives TS** | 6 `ExpressibleBy*Literal` on `Tagged` (`@_disfavoredOverload`) | `let index: Index<T> = 5`, `let offset: Index<T>.Offset = -3`, `let count: Index<T>.Count = 10`, `let ord: Ordinal = 1`, `let card: Cardinal = 42` — and all other `Tagged` types |
| **Algebra Modular Primitives TS** | `@retroactive ExpressibleByIntegerLiteral` on `Tagged where Tag: Algebra.Residual` | `let z: Algebra.Z<5> = 3` |
| **Cyclic Primitives TS** | `ExpressibleByIntegerLiteral` on `Cyclic.Group.Static.Element` | `let g: Cyclic.Group.Static<5>.Element = 3` |

#### Primitives Layer — Factory Methods

| Module | Unique API |
|--------|-----------|
| **Buffer Primitives TS** | `Buffer.Ring: ExpressibleByArrayLiteral`. Factory methods: `Buffer.Ring.with(_:minimumCapacity:)`, `.Bounded.with(_:capacity:)`, `Buffer.Linear.with(...)`, `.Bounded.with(...)`, `Buffer.Slab.Bounded.with(...)`, `Buffer.Ring.Inline.with(...)`, `Buffer.Linear.Inline.with(...)`, `Buffer.Slab.Inline.with(...)` — all constrained to `Element == Int` |
| **Vector Primitives TS** | `Vector.init(_: Swift.Range<UInt>, transform:)`, `Vector.init(_: Swift.Range<Int>, transform:)`, `Vector.init(count:transform:)`, `Vector.init(start:end:transform:)` |

#### Primitives Layer — Pure Re-Export Aggregators

These modules provide no unique API — they exist to aggregate upstream re-exports into a single import:

| Module | Re-Exports |
|--------|-----------|
| **Cardinal Primitives TS** | Cardinal Primitives |
| **Ordinal Primitives TS** | Ordinal Primitives, Cardinal TS |
| **Affine Primitives TS** | Affine Primitives, Ordinal TS, Cardinal TS |
| **Index Primitives TS** | Identity TS, Ordinal TS, Cardinal TS, Affine TS |
| **Memory Primitives TS** | Memory Primitives, Index TS, Vector TS |
| **Storage Primitives TS** | Storage Primitives, Memory TS |
| **Bit Primitives TS** | Identity TS |
| **Bit Index Primitives TS** | Bit TS, Index TS |
| **Bit Pack Primitives TS** | Bit Index TS |
| **Bit Vector Primitives TS** | Bit Pack TS |
| **Cyclic Index Primitives TS** | Cyclic Index Primitives, Cyclic TS, Index TS |
| **Collection Primitives TS** | Index TS |
| **Finite Primitives TS** | Finite Primitives, Index TS |
| **Hash Table Primitives TS** | Hash Table Primitives, Index TS |
| **Set Primitives TS** | Bit TS, Index TS |
| **Vector Primitives TS** | Vector Primitives, Index TS |
| **Binary Primitives TS** | Binary Primitives, Memory TS, Bit TS |
| **Binary Parser Primitives TS** | Binary Parser Primitives, Binary TS, Index TS, Serialization Primitives, Parser Primitives |

#### Standards Layer

| Module | Unique API |
|--------|-----------|
| **ISO 9945 Kernel TS** | `KernelThreadTest.Harness<State>` (condvar coordination: `update`, `wait`, `withLocked`). `LockedBox<T>` (mutex-protected box). `Gate` (condition-based barrier). `Signal` (one-shot handshake). `Kernel.Event.Test` (pipe helpers: `makePipe`, `writeByte`, `readDrain`). `Kernel.Temporary` (temp dir/file paths). `KernelIOTest` (temp file lifecycle: `withTempFile`, `withTempFileWithContent`). Lock Helper executable (multi-process lock contention). |

#### Foundations Layer

| Module | Unique API |
|--------|-----------|
| **Kernel TS** | `expectThrows<E,R>(_:_:)` (typed-throws assertion). Same harness/primitives as ISO 9945 TS but targeting foundations `Kernel` module. Re-exports: Kernel Primitives TS. |
| **IO TS** | `ThreadPoolTesting.waitUntilIdle(...)`. `IOBenchmarkFixture` (standardized thread pool for benchmarks). `IO.Blocking.Threads.checkSubmit()`. `IO.Blocking.Lane.runImmediate(...)`. `Barrier` typealias. Re-exports: Kernel TS. |
| **File System TS** | `File.Directory.Temporary.Scope` (scoped temp dir with cleanup). `File.Temporary` (scoped temp file). `Test.Delay.milliseconds(...)`. `Test.Retry.withDelay(...)`. `createGlobTestFiles(in:)`. |
| **Parsers TS** | Snapshot testing utilities. Located at `Sources/Parsers Test Support/`. |
| **Dependencies TS** | `Dependency.Test.withOverrides(...)`. `assertMode(...)`, `assertValue(...)`. `__DependencyTestTrait` (suite/test trait for dependency isolation: `.dependencies`, `.dependency(_:_:)`). |

---

### [TEST-010] Test Support Target Declaration

**Statement**: Packages MAY provide a `{Module} Test Support` library for shared test utilities. Test Support MUST be declared as a `.target()` (regular library), NOT a `.testTarget()`. This enables cross-package consumption.

**Package.swift**:
```swift
products: [
    .library(
        name: "Memory Primitives Test Support",
        targets: ["Memory Primitives Test Support"]
    ),
],
targets: [
    .target(
        name: "Memory Primitives Test Support",
        dependencies: [
            "Memory Primitives",
            .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            .product(name: "Vector Primitives Test Support", package: "swift-vector-primitives"),
        ],
        path: "Tests/Support"
    ),
    .testTarget(
        name: "Memory Primitives Tests",
        dependencies: [
            "Memory Primitives",
            "Memory Primitives Test Support",
        ]
    ),
]
```

**Key rules**:
- Product name and target name use **spaces**: `"Memory Primitives Test Support"`
- Import statements use **underscores**: `import Memory_Primitives_Test_Support`
- Path is **always** `"Tests/Support"`
- Dependencies include the package's **own main module** AND **upstream Test Support modules**
- Test targets depend on **both** the main module and its Test Support

**Incorrect**:
```swift
.testTarget(                              // ❌ testTarget cannot be consumed cross-package
    name: "Memory Primitives Test Support",
    ...
)
```

**Rationale**: A `.target()` library product can be depended upon by other packages' test targets and Test Support targets, enabling the transitive re-export chain.

---

### [TEST-019] Test Support Directory Structure

**Statement**: Test Support MUST use the two-file pattern at `Tests/Support/`: an `exports.swift` for re-exports and a `{Name} Test Support.swift` for utilities.

**Standard layout**:
```
Tests/Support/
├── exports.swift                              // @_exported re-imports
└── Memory Primitives Test Support.swift       // Shared utilities
```

**Multiple utility files** (when needed):
```
Tests/Support/
├── exports.swift
├── Buffer Primitives Test Support.swift       // Factory methods
└── Buffer.Ring+ArrayLiteral.swift             // Specific conformance
```

**Incorrect**:
```
Tests/Memory Primitives Tests/Support/         // ❌ Not inside test target dir
Sources/Memory Primitives Test Support/        // ❌ Not at Tests/Support (exceptions exist)
```

**Rationale**: Consistent directory placement enables predictable navigation across all packages.

---

### [TEST-020] Re-Export Pattern

**Statement**: `exports.swift` MUST use `@_exported public import` to transitively re-export all upstream Test Support modules. MAY also re-export the package's own main module.

**Correct** (`exports.swift`):
```swift
@_exported public import Memory_Primitives
@_exported public import Index_Primitives_Test_Support
@_exported public import Vector_Primitives_Test_Support
```

**Effect**: A test file that imports `Memory_Primitives_Test_Support` transitively receives:
- `Memory_Primitives` (main module)
- `Index_Primitives_Test_Support` (and its chain: Identity, Ordinal, Cardinal, Affine)
- `Vector_Primitives_Test_Support` (and its chain)

**Incorrect**:
```swift
import Index_Primitives_Test_Support           // ❌ Missing @_exported — not transitive
public import Index_Primitives_Test_Support    // ❌ Missing @_exported — not transitive
```

**Rationale**: `@_exported` makes the re-export transitive. Without it, downstream consumers would need to explicitly import every module in the chain.

---

### [TEST-021] Re-Export Chain Architecture

**Statement**: Test Support modules form a directed acyclic graph mirroring the package dependency graph. Each module re-exports its upstream Test Supports, creating a single-import experience for test consumers.

**Primitives re-export chain**:
```
Identity Primitives Test Support (root — literal conformances for Tagged)
    ↓
Index Primitives Test Support (hub — re-exports Identity, Ordinal, Cardinal, Affine)
    ↓                    ↓                          ↓
Vector Primitives TS   Cyclic Index Primitives TS   Collection Primitives TS
    ↓                    ↓
Memory Primitives Test Support (re-exports Index TS, Vector TS)
    ↓
Storage Primitives Test Support (re-exports Memory TS)
    ↓
Buffer Primitives Test Support (re-exports Storage TS, Cyclic Index TS, Bit Vector TS)
```

**Cross-layer chain** (Primitives → Standards → Foundations):
```
Kernel Primitives Test Support (primitives)
    ↓
ISO 9945 Kernel Test Support (standards)
    ↓
Darwin Kernel Primitives Test Support (primitives — re-exports both above)
    ↓
Kernel Test Support (foundations — re-exports Kernel Primitives TS)
    ↓
IO Test Support (foundations — re-exports Kernel TS)
```

**Consequence**: A test importing `Buffer_Primitives_Test_Support` transitively receives literal conformances, index utilities, memory helpers, and every upstream Test Support API — from a single import.

---

### [TEST-018] Test Support Literal Conformances

**Statement**: Tests MUST use literal conformances from Test Support for primitives type construction and comparison.

**Source**: `Identity_Primitives_Test_Support` provides `ExpressibleByIntegerLiteral` (and other literal protocols) for `Tagged`. Since `Index<T>`, `Ordinal`, `Cardinal`, etc. are all `Tagged` types, this single conformance enables literal syntax for the entire type hierarchy.

```swift
// In Identity Primitives Test Support:
extension Tagged: ExpressibleByIntegerLiteral
where Tag: ~Copyable, RawValue: ExpressibleByIntegerLiteral {
    @_disfavoredOverload
    public init(integerLiteral value: RawValue.IntegerLiteralType) {
        self = .init(__unchecked: (), RawValue(integerLiteral: value))
    }
}
```

**`@_disfavoredOverload`**: Prevents the test-only literal conformance from being preferred over more specific initializers in production code.

**Available when importing any Test Support that re-exports Identity Primitives Test Support**:

| Type | Literal Example |
|------|-----------------|
| `Index<T>` | `let index: Index<Int> = 5` |
| `Index<T>.Offset` | `let offset: Index<Int>.Offset = -3` |
| `Index<T>.Count` | `let count: Index<Int>.Count = 10` |
| `Ordinal` | `let ord: Ordinal = 1` |
| `Cardinal` | `let card: Cardinal = 42` |

**Correct**:
```swift
let index: Index<Int> = 5
#expect(index == 5)
#expect(index.position == 5)

var i = 0
(.zero..<count).forEach { index in
    storage.initialize(to: i * 10, at: index)
    i += 1
}
```

**Incorrect**:
```swift
#expect(index.position.rawValue == 5)  // ❌ Unwrapping when literals available
storage.initialize(to: Int(bitPattern: index.position.rawValue) * 10, at: index)  // ❌
```

**Rationale**: Test Support provides literal conformances for test convenience. Using rawValue chains when literals are available obscures intent.

**Cross-references**: [PATTERN-017], [CONV-007], [CONV-008]

---

### [TEST-022] Test Support Utility Categories

**Statement**: Test Support utilities fall into four categories. Each category has specific conventions.

#### Category 1: Literal Conformances

Provide `ExpressibleBy*Literal` for types that don't have them in production (to keep production APIs strict).

```swift
// Identity Primitives Test Support — root of all literal conformances
extension Tagged: ExpressibleByIntegerLiteral
where Tag: ~Copyable, RawValue: ExpressibleByIntegerLiteral {
    @_disfavoredOverload
    public init(integerLiteral value: RawValue.IntegerLiteralType) {
        self = .init(__unchecked: (), RawValue(integerLiteral: value))
    }
}
```

#### Category 2: Factory Methods and Convenience Constructors

Provide ergonomic construction for test data.

```swift
// Buffer Primitives Test Support
extension Buffer.Ring: ExpressibleByArrayLiteral { ... }

extension Buffer.Ring where Element == Int {
    public static func with(
        _ elements: [Int],
        minimumCapacity: UInt = 0
    ) -> Self { ... }
}
```

#### Category 3: Test Harnesses

Provide reusable coordination infrastructure for complex test scenarios (e.g., threading, I/O).

```swift
// ISO 9945 Kernel Test Support
public enum KernelThreadTest {
    public final class Harness<State: Sendable>: @unchecked Sendable {
        public func update(_ body: (inout State) -> Void) { ... }
        public func wait(until predicate: (State) -> Bool) throws(Timeout) { ... }
    }
}
```

#### Category 4: Temporary Resource Helpers

Provide safe setup/teardown for file system, I/O, and other resource-based tests.

```swift
// Kernel Test Support
extension Kernel.Temporary {
    public static var directory: Swift.String { ... }
    public static func filePath(prefix: Swift.String) -> Swift.String { ... }
}

// File System Test Support
extension File {
    public struct Temporary: Sendable {
        public func callAsFunction<T>(
            _ body: (File.Path) throws -> T
        ) throws -> T { ... }
    }
}
```

**Rationale**: Categorized utilities keep Test Support focused and discoverable.

---

### [TEST-023] Creating a New Test Support Module

**Statement**: When creating a new Test Support module, follow this checklist.

**Step 1** — Create directory:
```
mkdir Tests/Support
```

**Step 2** — Create `exports.swift` with re-exports of all upstream Test Supports:
```swift
@_exported public import Your_Module
@_exported public import Upstream_Primitives_Test_Support
```

**Step 3** — Create `{Name} Test Support.swift` with package-specific utilities:
```swift
public import Your_Module

// Literal conformances, factory methods, harnesses, etc.
```

**Step 4** — Add to `Package.swift`:
```swift
// In products:
.library(
    name: "Your Module Test Support",
    targets: ["Your Module Test Support"]
),

// In targets:
.target(
    name: "Your Module Test Support",
    dependencies: [
        "Your Module",
        .product(name: "Upstream Primitives Test Support", package: "swift-upstream-primitives"),
    ],
    path: "Tests/Support"
),
```

**Step 5** — Add Test Support as a dependency of the test target:
```swift
.testTarget(
    name: "Your Module Tests",
    dependencies: [
        "Your Module",
        "Your Module Test Support",
    ]
),
```

**Step 6** — Import from test files:
```swift
import Your_Module_Test_Support
// Transitively provides: Your Module + all upstream Test Support APIs
```

---

### [TEST-024] Nested Package.swift for Circular Dependencies

**Statement**: When a package and `swift-testing` have a circular dependency, tests MUST use a nested `Tests/Package.swift` to break the cycle.

**Layout**:
```
swift-kernel-primitives/
├── Package.swift              // Main package — no swift-testing dependency
└── Tests/
    ├── Package.swift          // Separate SPM resolution scope
    ├── Support/
    └── Kernel Primitives Tests/
```

**Nested `Tests/Package.swift`**:
```swift
let package = Package(
    name: "swift-kernel-primitives-tests",
    dependencies: [
        .package(path: "../"),
        .package(path: "../../../swift-foundations/swift-testing"),
    ],
    targets: [
        .testTarget(
            name: "Kernel Primitives Tests",
            dependencies: [
                .product(name: "Kernel Primitives", package: "swift-kernel-primitives"),
                .product(name: "Kernel Primitives Test Support", package: "swift-kernel-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ],
        ),
    ],
)
```

**When to use**: Only when the package is a transitive dependency of `swift-testing` itself (e.g., kernel primitives, identity primitives).

**Rationale**: SPM cannot resolve circular dependencies. The nested package creates a separate resolution scope that depends on both the parent package and `swift-testing` without creating a cycle.

---

## Async Testing Patterns

### [TEST-027] Async Expect Bindings

**Statement**: When comparing two `async` values in `#expect`, both sides MUST be extracted to `let` bindings first. Direct `await` inside `#expect` causes compiler inference failures.

**Correct**:
```swift
@Test
func `stream produces expected value`() async {
    let actual = await stream.next()
    let expected = await reference.value()
    #expect(actual == expected)
}
```

**Incorrect**:
```swift
@Test
func `stream produces expected value`() async {
    #expect(await stream.next() == await reference.value())  // ❌ Inference failure
}
```

**Rationale**: Swift Testing's `#expect` macro expansion interacts poorly with multiple `await` expressions in a single macro invocation.

---

### [TEST-028] Foundation-Free Isolation Verification

**Statement**: Primitives-layer tests that need to verify main-actor isolation MUST use `pthread_main_np()` instead of Foundation's `Thread.isMainThread`.

**Correct**:
```swift
#if canImport(Darwin)
import Darwin

@Test
func `callback runs on main thread`() async {
    let isMain = pthread_main_np() != 0
    #expect(isMain)
}
#endif
```

**Incorrect**:
```swift
import Foundation  // ❌ Forbidden in primitives [PRIM-FOUND-001]
#expect(Thread.isMainThread)
```

**Rationale**: Foundation is forbidden in primitives and standards layers. `pthread_main_np()` is available directly from Darwin.

**Cross-references**: [PRIM-FOUND-001]

---

## Testing ~Copyable Types

### [TEST-011] Observable Property Testing

**Statement**: ~Copyable types MUST be tested via observable properties rather than copying values.

**Correct**:
```swift
@Test
func `init with capacity`() {
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
@Test
func `reset restores full capacity`() {
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
@Test
func `move transfers value`() {
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
@Test
func `move and continue`() {
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
@Test(.timed(iterations: 100, warmup: 10))
func `sequential read`() {
    // Performance-critical code
}

@Test(.timed(iterations: 50, threshold: .milliseconds(50)))
func `must complete within 50ms`() {
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

    @Test
    func `random operations match model`() {
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
- **conversions** skill for [CONV-007], [CONV-008] literal conformance usage
- **anti-patterns** skill for [PATTERN-017] rawValue access rules
- `Documentation.docc/Testing Requirements.md` for detailed testing documentation
- [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508) for generic type limitation
