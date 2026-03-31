---
name: testing-swiftlang
description: |
  Apple Swift Testing framework: suites, naming, ~Copyable, async, model testing.
  ALWAYS apply when writing or reviewing test code using Apple Swift Testing.

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

# Swift Testing Framework Patterns

Patterns and conventions for using the Apple Swift Testing framework. These rules cover suite structure, test naming, ~Copyable type testing, async patterns, and model-based testing.

---

## Suite Structure

### [SWIFT-TEST-001] TestSuites Macro Usage

**Statement**: When available, types SHOULD use `#TestSuites` (current) or `#Tests` (future) macro to generate standard suite structure.

**Current** (swift-testing-extras):
```swift
import Testing_Extras

extension YourType {
    #TestSuites
}
// Generates: YourType.Test.{Unit, `Edge Case`, Integration, Performance}
```

**Future** (swift-foundations/swift-testing):
```swift
import Testing

extension YourType {
    #Tests
}
// Generates: YourType.Test.{Unit, `Edge Case`, Integration, Performance, Snapshot}
```

**When macro unavailable** (manual creation):
```swift
extension YourType {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}
```

**Rationale**: Macros ensure consistent structure; manual fallback maintains compatibility.

**Origin**: TEST-002

---

### [SWIFT-TEST-002] Type Extension Pattern

**Statement**: Non-generic types MUST use the type extension pattern for test suites.

**Correct**:
```swift
extension Memory.Buffer {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
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

**Origin**: TEST-003

---

### [SWIFT-TEST-003] Generic Type Exception

**Statement**: Generic type specializations MUST use parallel namespace pattern due to Swift Testing discovery limitation.

**Context**: `@Suite` in extensions of generic type specializations (e.g., `extension Container<Int>`) is silently not discovered. See [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508).

**Correct** (generic type):
```swift
// Generic type
struct Index<Tag> { }

// Tests use parallel namespace
@Suite
struct `Index Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
}

extension `Index Tests`.Unit {
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

**Origin**: TEST-004

---

### [SWIFT-TEST-004] Performance Suite Serialization

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

**Origin**: TEST-006

---

## Test Function Conventions

### [SWIFT-TEST-005] Test Naming Pattern

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

**Origin**: TEST-007

---

### [SWIFT-TEST-006] Test Implementation Pattern

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

**Origin**: TEST-008

---

## Testing ~Copyable Types

### [SWIFT-TEST-007] Observable Property Testing

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

**Origin**: TEST-011

---

### [SWIFT-TEST-008] Mutation Testing Pattern

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

**Origin**: TEST-012

---

### [SWIFT-TEST-009] Consuming Operation Testing

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

**Origin**: TEST-013

---

### [SWIFT-TEST-010] Helper Functions for ~Copyable

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

**Origin**: TEST-014

---

### [SWIFT-TEST-014] ~Copyable Values in #expect

**Statement**: `#expect` macro expansion copies its operands during evaluation. ~Copyable values MUST be projected to a Copyable value before passing to `#expect`.

**Correct**:
```swift
@Test
func `handle is fulfilled`() {
    let handle = IO.Blocking.Lane.Handle<Int>(...)
    let fulfilled = handle.isFulfilled  // Extract Copyable projection
    #expect(fulfilled)
}
```

**Incorrect**:
```swift
@Test
func `handle is fulfilled`() {
    let handle = IO.Blocking.Lane.Handle<Int>(...)
    #expect(handle.isFulfilled)  // ❌ Macro tries to copy ~Copyable handle
}
```

**Statement**: ~Copyable values MUST NOT be stored in `Array` or other `Copyable`-constrained collections for bulk assertion. Use sequential assertions or a loop with `borrowing` access.

**Rationale**: `#expect`, `Array`, and other generic stdlib infrastructure assume `Copyable`. This is the current state of generics adoption, not a bug. As stdlib adopts `~Copyable` generics, this friction will decrease.

**Cross-references**: [SWIFT-TEST-009], [SWIFT-TEST-010], [MEM-COPY-004]

**Provenance**: 2026-03-26-io-api-remediation-sync-submission.md

---

## Async Testing Patterns

### [SWIFT-TEST-011] Async Expect Bindings

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

**Origin**: TEST-027

---

### [SWIFT-TEST-012] Foundation-Free Isolation Verification

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

**Origin**: TEST-028

---

## Model-Based Testing

### [SWIFT-TEST-013] Model-Based Testing

**Statement**: Complex data structures SHOULD include model tests that compare behavior against a reference implementation.

**Pattern**:
```swift
@Suite
struct `Set.Ordered - Model Tests` {

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

**Origin**: TEST-017

---

## Cross-References

See also:
- **testing** skill — [TEST-*] for umbrella routing, test support infrastructure, file naming
- **benchmark** skill — [BENCH-*] for performance measurement patterns
- **testing-institute** skill — [INST-TEST-*] for nested package pattern and snapshots
- **code-surface** skill — [API-NAME-001] Nest.Name pattern, [API-IMPL-005] one type per file
- **memory-safety** skill — [MEM-COPY-*] for ~Copyable ownership rules
- [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508) for generic type limitation
