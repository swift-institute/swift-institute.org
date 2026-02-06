---
name: conversions
description: |
  Typed index patterns, conversion APIs, and rawValue access rules.
  Apply when working with Index<T>, Offset, Count, Ordinal, Cardinal,
  cross-domain index conversion, or accessing rawValue.

layer: implementation

requires:
  - swift-institute
  - naming

applies_to:
  - swift
  - primitives
  - standards
  - foundations
---

# Conversions

Typed index patterns and conversion APIs for primitives types. These rules ensure type-safe arithmetic, clean call-sites, and proper encapsulation of layer boundaries.

**Core Principle**: Arithmetic stays typed. `.rawValue` and `.position` access belong in extension initializers only. Call-sites pass higher-level types.

---

## Core Types

### [IDX-001] Index as Tagged Ordinal

**Statement**: `Index<Element>` is a typealias for `Tagged<Element, Ordinal>`.

```swift
public typealias Index<Element: ~Copyable> = Tagged<Element, Ordinal>
```

**Properties**:
- `.position: Ordinal` --- underlying position value
- `.zero: Index<T>` --- first position
- Conforms to `Equatable`, `Hashable`, `Comparable`, `Sendable`

---

### [IDX-002] Index.Offset as Tagged Vector

**Statement**: `Index<T>.Offset` wraps `Affine.Discrete.Vector` for signed displacement.

```swift
public typealias Offset = Tagged<Tag, Affine.Discrete.Vector>
```

**Properties**:
- `.rawValue: Affine.Discrete.Vector` --- underlying displacement
- `.zero: Index<T>.Offset` --- no displacement
- Supports negation: `-offset`

---

### [IDX-003] Index.Count as Tagged Cardinal

**Statement**: `Index<T>.Count` wraps `Cardinal` for unsigned count.

```swift
public typealias Count = Tagged<Tag, Cardinal>
```

**Properties**:
- `.count: Cardinal` --- underlying count value (via `.rawValue`)
- `.zero: Index<T>.Count` --- empty count

---

## rawValue Access Rules

### [CONV-001] rawValue Location

**Statement**: `.rawValue` access MUST be confined to extension initializers and same-package implementations. Call-sites MUST pass higher-level types directly.

**Correct** --- extension init encapsulates rawValue:
```swift
// In Ordinal Primitives
extension Int {
    public init(bitPattern position: Ordinal) {
        self = Int(bitPattern: position.rawValue)  // rawValue here only
    }
}

// In Tagged+Ordinal --- delegates to Ordinal version
extension Int {
    public init<Tag: ~Copyable>(bitPattern position: Tagged<Tag, Ordinal>) {
        self = Int(bitPattern: position.rawValue)
    }
}
```

**Correct** --- clean call-site:
```swift
let i = Int(bitPattern: index)
```

**Incorrect** --- rawValue chain at call-site:
```swift
let i = Int(bitPattern: index.position.rawValue)  // ❌ Never
```

**Rationale**: Extension inits encapsulate layer boundaries. Call-sites remain clean and type-safe. When internal representations change, only extension inits need updates.

**Cross-references**: [PATTERN-012], [PATTERN-017]

---

### [CONV-001a] Intermediate Property Access Location

**Statement**: Intermediate property access (`.position`, `.rawValue`) MUST be confined to extension initializers and same-package implementations. Higher-layer packages and call-sites MUST compare at the semantic type level using literal conformances.

**Incorrect** --- property access at call-site:
```swift
#expect(element.position == 3)           // ❌ Crosses layer boundary
#expect(index.rawValue == 3)             // ❌ Accesses internal representation
#expect(cyclicIndex.rawValue == 3)       // ❌ Accesses internal representation
#expect(cyclicIndex.rawValue.position == 3)  // ❌ Severe --- multi-level unwrap
```

**Correct** --- compare at semantic type level:
```swift
#expect(element == 3)           // ✓ Literal comparison
#expect(index == 3)             // ✓ Literal comparison (Tagged)
#expect(cyclicIndex == 3)       // ✓ Literal comparison (Tagged)
```

**Rationale**: `.rawValue` and `.position` are implementation details. Test Support provides `ExpressibleByIntegerLiteral` for Tagged types specifically so call-sites don't need property access.

**Cross-references**: [CONV-007], [CONV-008]

---

### [CONV-002] Justified rawValue Access

**Statement**: Direct `.rawValue` or `.position` access is justified ONLY in these locations:

| Location | Example | Justified |
|----------|---------|-----------|
| Extension initializer | `Int.init(bitPattern: Ordinal)` | Yes |
| Same-package implementation | `Cyclic.Group + operator using .position` | Yes |
| Same-package bit-pattern test | Cyclic primitives testing Element internals | Yes |
| Higher-layer package | Cyclic Index Primitives | Never |
| Application code | Any call-site | Never |

**Incorrect** --- higher-layer package accessing dependency internals:
```swift
// In cyclic-index-primitives tests --- WRONG
#expect(index.rawValue.position == 3)
```

**Rationale**: Package boundaries should be respected. Higher packages use the APIs lower packages export, not their internal representations.

---

## Conversion API Reference

### [CONV-003] Index Conversions

**Statement**: Use these APIs for `Index<T>` (aka `Tagged<T, Ordinal>`) conversions. Prefer typed arithmetic over conversion to `Int`.

| From | To | API | Throws | Notes |
|------|-----|-----|--------|-------|
| `Ordinal` | `Index<T>` | `Index(ordinal)` | No | Total |
| `Cardinal` | `Index<T>` | `Index(cardinal)` | No | Total |
| `Int` | `Index<T>` | `try Index(int)` | Yes | Throws if negative |
| `Int` | `Index<T>` | `Index(exactly: int)` | No | nil if negative |
| `Index<T>` | `Ordinal` | `.position` | No | Property access |
| `Index<T>` | `Int` | `try Int(index)` | Yes | Throws if > Int.max |
| `Index<T>` | `Int` | `Int(exactly: index)` | No | nil if > Int.max |
| `Index<T>` | `Int` | `Int(bitPattern: index)` | No | **Last resort** --- interop only |

**Example**:
```swift
let index: Index<Int> = try Index(5)

// Typed arithmetic --- PREFERRED
let next = index + 1
let distance = otherIndex - index

// Int conversion --- ONLY for interop
array[Int(bitPattern: index)]  // Standard Library needs Int
```

---

### [CONV-004] Cardinal Conversions

**Statement**: Use these APIs for `Cardinal` and `Index<T>.Count` conversions. Prefer typed arithmetic over conversion to `Int`.

| From | To | API | Throws | Notes |
|------|-----|-----|--------|-------|
| `Ordinal` | `Cardinal` | `Cardinal(ordinal)` | No | Total |
| `Cardinal` | `Ordinal` | `Ordinal(cardinal)` | No | Total |
| `Int` | `Cardinal` | `try Cardinal(int)` | Yes | Throws if negative |
| `Cardinal` | `Int` | `try Int(cardinal)` | Yes | Throws if > Int.max |
| `Cardinal` | `Int` | `Int(exactly: cardinal)` | No | nil if > Int.max |
| `Cardinal` | `Int` | `Int(bitPattern: cardinal)` | No | **Last resort** --- interop only |

**Index<T>.Count** follows same pattern (is `Tagged<T, Cardinal>`).

---

### [CONV-005] Ordinal Conversions

**Statement**: Use these APIs for `Ordinal` conversions. Prefer typed arithmetic over conversion to `Int`.

| From | To | API | Throws | Notes |
|------|-----|-----|--------|-------|
| `UInt` | `Ordinal` | `Ordinal(uint)` | No | Total |
| `Int` | `Ordinal` | `try Ordinal(int)` | Yes | Throws if negative |
| `Int` | `Ordinal` | `Ordinal(exactly: int)` | No | nil if negative |
| `Ordinal` | `Int` | `try Int(ordinal)` | Yes | Throws if > Int.max |
| `Ordinal` | `Int` | `Int(exactly: ordinal)` | No | nil if > Int.max |
| `Ordinal` | `Int` | `Int(bitPattern: ordinal)` | No | **Last resort** --- interop only |

---

### [CONV-006] Memory Address Conversions

**Statement**: Use these APIs for `Memory.Address` conversions.

| From | To | API | Notes |
|------|-----|-----|-------|
| `UnsafeRawPointer` | `Memory.Address` | `Memory.Address(pointer)` | Non-null |
| `UnsafeRawPointer?` | `Memory.Address` | `try Memory.Address(pointer)` | Throws if nil |
| `Memory.Address` | `UnsafeRawPointer` | `UnsafeRawPointer(address)` | |
| `Memory.Address` | `UnsafeMutableRawPointer` | `UnsafeMutableRawPointer(address)` | |

---

## Typed Arithmetic

### [CONV-010] Prefer Typed Arithmetic

**Statement**: Arithmetic MUST use typed operators on primitives types (`Index<T>`, `Offset`, `Count`, `Memory.Address`). Converting to `Int` for computation defeats type safety and is ONLY justified for interop with external APIs that require `Int`.

**Correct** --- typed arithmetic:
```swift
let next = index + 1                    // Index<T> + Offset -> Index<T>
let distance = end - start              // Index<T> - Index<T> -> Offset
let stride = count * MemoryLayout<T>.stride  // Count arithmetic
address + offset                        // Memory.Address + Offset
```

**Incorrect** --- escaping to Int for computation:
```swift
let next = Index(Int(bitPattern: index) + 1)  // ❌ Escaped to Int
let distance = Int(bitPattern: end) - Int(bitPattern: start)  // ❌
```

**`Int(bitPattern:)` is a last resort**. Valid uses:
- Passing to C APIs that take `Int` or `size_t`
- Passing to Standard Library APIs that take `Int` (e.g., array indices)
- Debug/logging output

**Rationale**: Typed arithmetic preserves invariants (non-negative indices, wraparound for cyclic types). `Int(bitPattern:)` strips these guarantees and should only appear at system boundaries.

**Cross-references**: [MEM-ARITH-001], [PTR-ARITH-001]

---

### [IDX-006] Index Arithmetic with Offset

**Statement**: Use `Index + Offset -> Index` and `Index - Index -> Offset`.

```swift
let start: Index<Int> = try Index(5)
let offset: Index<Int>.Offset = 3

// Advance by offset (may throw on underflow)
let end = try start + offset  // Index at position 8

// Compute displacement
let distance: Index<Int>.Offset = try end - start  // Offset of 3
```

**Arithmetic**:
- `Index + Offset -> Index` (throws)
- `Index - Offset -> Index` (throws)
- `Offset + Index -> Index` (commutative, throws)
- `Index - Index -> Offset` (throws)

---

### [IDX-006a] Index Arithmetic with Count (Total)

**Statement**: Use `Index + Count -> Index` for forward advancement. This is **total** (non-throwing).

```swift
var position: Index<Int> = .zero
let count: Index<Int>.Count = try Index<Int>.Count(3)

// Advance by count - pure typed arithmetic, total!
position = position + count  // Index at position 3

// Single element increment
position = position + .one   // Index at position 4
```

**Arithmetic**:
- `Index + Count -> Index` (total, from ordinal-primitives)
- `Count + Index -> Index` (commutative)

**Key insight**: `Index + Count` is total because both are non-negative. Prefer this over `Index + Offset` when the displacement is known to be non-negative.

---

### [IDX-006c] Index <-> Count Conversions

**Statement**: Convert between `Index<T>` and `Index<T>.Count` using initializers. Both directions are total because both represent non-negative values.

```swift
let position: Index<Int> = try Index(5)

// Index -> Count (total)
let consumed: Index<Int>.Count = Index<Int>.Count(position)

// Count -> Index (total)
let count: Index<Int>.Count = try Index<Int>.Count(10)
let endIndex: Index<Int> = Index<Int>(count)
```

---

### [IDX-006d] Count Subtraction (Saturating)

**Statement**: Use `.subtract.saturating()` for `Count - Count` operations. Direct `-` operator is not defined on Count.

```swift
let total: Index<Int>.Count = try Index<Int>.Count(10)
let consumed: Index<Int>.Count = try Index<Int>.Count(3)

// CORRECT: Property-based saturating subtraction
let remaining = total.subtract.saturating(consumed)  // Count of 7

// WRONG: No direct - operator on Count
// let remaining = total - consumed  // Does not compile
```

**Rationale**: Subtraction on cardinals (non-negative quantities) could underflow. The property-based API makes the saturation behavior explicit.

---

### [IDX-007] Bounds Checking

**Statement**: Use `Index < Count` for bounds validation.

```swift
let index: Index<Int> = try Index(5)
let count: Index<Int>.Count = 10

guard index < count else {
    return nil  // Out of bounds
}
```

**Cross-type comparisons** (disfavored overloads):
- `Index < Count`
- `Index <= Count`
- `Index > Count`
- `Index >= Count`

---

### [IDX-008] Range Iteration

**Statement**: Use `(.zero..<count)` for index ranges.

```swift
let count: Index<Int>.Count = 8

(.zero..<count).forEach { index in
    // index: Index<Int>
    process(at: index)
}
```

---

## Domain Separation and Retag

### [IDX-004] Type-Safe Domain Separation

**Statement**: Use different phantom types to prevent mixing indices from different domains.

```swift
enum Bit {}
enum Byte {}

let bitIndex: Index<Bit> = try Index(5)
let byteIndex: Index<Byte> = try Index(5)

// Same position, different types
bitIndex.position == byteIndex.position  // true (Ordinal comparison)
// bitIndex == byteIndex  // ❌ Compile error - different Index types
```

**Rationale**: Phantom types catch domain confusion at compile time.

---

### [IDX-010] Retag for Domain Conversion

**Statement**: Use `.retag()` for zero-cost cross-domain conversion when the numeric value is unchanged.

```swift
let bitOffset: Index<Bit>.Offset = 5
let byteOffset: Index<Byte>.Offset = bitOffset.retag(Byte.self)
```

**Note**: Retagging changes phantom type only --- underlying value unchanged. If domains have different scales (e.g., bits vs bytes), use ratio-based conversion [CONV-011] instead.

---

## Cross-Domain Index Conversion

### [CONV-011] Count Chain for Cross-Domain Index Conversion

**Statement**: When converting an `Index<A>` to `Index<B>` via a known ratio, use the **count chain**: `Position -> Count -> scale -> Count -> Position`. This chain is entirely non-throwing when the ratio is positive and the source position is non-negative.

**Pattern** (one-liner):
```swift
Self(Index<A>.Count(sourceIndex) * .ratio)
```

**Expanded** (for readability when needed):
```swift
let sourceCount = Index<A>.Count(sourceIndex)    // Position -> Count (total)
let targetCount = sourceCount * .ratio           // Count<A> -> Count<B> (total)
let targetIndex = Index<B>(targetCount)          // Count -> Position (total)
```

**Semantic justification**: Position N means "N elements precede this position". Converting to Count makes this cardinality explicit, which can then be scaled to another domain's cardinality, which maps back to a position. All steps are total (non-negative x positive = non-negative).

**Why `Count(index)` is required**: In affine geometry, you cannot scale a point --- only vectors and magnitudes. The `Count(index)` step decomposes the point into a magnitude (the cardinality of elements preceding it), which CAN be scaled. With origin fixed at zero, this is numerically a no-op but type-theoretically necessary.

**Case study** --- byte index to bit index (`Bit.Index+Byte.swift`):

**Correct** --- count chain one-liner:
```swift
public init(_ index: Index<UInt8>) {
    self = Self(Index<UInt8>.Count(index) * .bitsPerByte)
}
```

**Incorrect** --- manual Int arithmetic:
```swift
public init(_ byteIndex: Index<UInt8>) {
    let byteOffset = Index<UInt8>.Offset(Affine.Discrete.Vector(Int(bitPattern: byteIndex.position)))
    let bitOffset = byteOffset * .bitsPerByte
    self.init(__unchecked: (), Ordinal(UInt(bitOffset.rawValue.rawValue)))  // ❌
}
```

**Rationale**: The incorrect version has 4 manual Int conversions and 2 `.rawValue` unwraps. The correct version has zero --- all arithmetic stays typed.

---

### [CONV-012] Hybrid Count + Offset for Mixed Conversion

**Statement**: When a cross-domain index conversion also requires an intra-domain signed offset, use the count chain for the base conversion and typed offset addition for the displacement. Prefer `throws(Ordinal.Error)` with `try` over internal `try!` --- let the caller decide.

**Pattern** (one-liner, throwing):
```swift
try Self(Index<A>.Count(sourceIndex) * .ratio) + offset
```

**Expanded**:
```swift
let sourceCount = Index<A>.Count(sourceIndex)    // Position -> Count (total)
let targetCount = sourceCount * .ratio           // Count<A> -> Count<B> (total)
let baseIndex = Index<B>(targetCount)            // Count -> Position (total)
let result = try baseIndex + offset              // Position + Offset (throws)
```

**Case study** --- byte index with bit offset:

**Correct** --- hybrid chain one-liner:
```swift
public init(_ index: Index<UInt8>, offset: Index<Bit>.Offset) throws(Ordinal.Error) {
    self = try Self(Index<UInt8>.Count(index) * .bitsPerByte) + offset
}
```

**Incorrect** --- raw Int addition:
```swift
let totalBitOffset = baseBitOffset.rawValue.rawValue + bitOffset.rawValue.rawValue  // ❌
self.init(__unchecked: (), Ordinal(UInt(totalBitOffset)))                           // ❌
```

**Why `throws` over `try!`**: The offset parameter is typed as signed (`Vector`-based). Rather than asserting the invariant internally with `try!`, propagate via typed throws [API-ERR-001] and let the caller decide: `try!` when the invariant is known, `try` when it isn't.

---

### [CONV-013] Offset Chain as Alternative

**Statement**: The **offset chain** (`Position -> Offset -> scale -> Offset -> Position`) is an alternative to the count chain. It uses `Offset(fromZero:)` to convert a position to a signed displacement, scales it, then adds back to zero. This chain requires `try!` for the final step because `Position + Offset` is partial.

**Pattern** (one-liner):
```swift
try .zero + Index<A>.Offset(fromZero: sourceIndex) * .ratio
```

**Expanded**:
```swift
let sourceOffset = Index<A>.Offset(fromZero: sourceIndex)  // encapsulates Int conversion
let targetOffset = sourceOffset * .ratio                   // Offset<A> -> Offset<B>
let targetIndex = try .zero + targetOffset                 // Offset -> Position (throws)
```

**When to prefer the count chain [CONV-011] over offset chain**:
- Count chain is entirely non-throwing --- no `try!` needed
- Count chain is semantically cleaner --- positions ARE counts from zero
- Offset chain requires `try!` even when the invariant is trivially satisfied

**When the offset chain is appropriate**:
- When the conversion involves negative ratios (direction reversal)
- When the displacement is genuinely signed and may be negative
- When `Offset(fromZero:)` is already the natural starting point

---

### [CONV-014] stdlib Boundary Conversions

**Statement**: Conversions from Swift standard library properties that return `Int` (e.g., `FixedWidthInteger.bitWidth`, `MemoryLayout<T>.stride`) are **stdlib boundary conversions**. These are the correct location for `Int` values to enter the typed system. No further encapsulation is needed.

**Correct** --- stdlib boundary:
```swift
extension Affine.Discrete.Ratio where To == Bit, From: FixedWidthInteger {
    public static var bitWidth: Self { .init(From.bitWidth) }  // Int from stdlib
}
```

**Rationale**: `From.bitWidth` returns `Int` by protocol definition. The `Ratio.init(_ factor: Int)` accepts `Int`. This is the natural entry point --- wrapping it further would add complexity without benefit.

---

## Collection Patterns

### [IDX-006b] Typed Position as Primary Representation

**Statement**: When wrapping stdlib collections, store `Index<Element>` as the primary position representation. Derive raw `Storage.Index` only at subscript boundaries.

```swift
struct Cursor<Base: RandomAccessCollection> {
    let base: Base
    var position: Index<Base.Element>  // PRIMARY: typed index

    // Derive raw index only for subscripting (O(1) for RandomAccessCollection)
    var rawIndex: Base.Index {
        base.index(base.startIndex, offsetBy: Int(bitPattern: position))
    }

    // Pure typed arithmetic - no scalar conversions!
    mutating func advance(by count: Index<Base.Element>.Count) {
        position = position + count
    }

    var current: Base.Element? {
        guard position < totalCount else { return nil }
        return base[rawIndex]  // Single conversion point
    }
}
```

**Benefits**:
- All arithmetic stays typed: `position + count`
- `Int(bitPattern:)` conversion encapsulated in single `rawIndex` getter
- No dual tracking needed

---

### [IDX-017] RandomAccessCollection Offset

**Statement**: Use `Index<T>.Offset` with `collection.index(_:offsetBy:)`.

```swift
let array = [10, 20, 30, 40, 50]
let offset: Index<Int>.Offset = 3

let newIndex = array.index(array.startIndex, offsetBy: offset)
#expect(array[newIndex] == 40)
```

---

### [IDX-018] Span with Index.Count

**Statement**: Use `Index<T>.Count` for Span construction.

```swift
let span = Span(
    _unsafeStart: pointer,
    count: Index<Element>.Count(elementCount)
)
```

---

## Test Support

### [CONV-007] Test Support Chain

**Statement**: Test Support modules provide `ExpressibleByIntegerLiteral` via re-export chain. Tests SHOULD use literal syntax instead of property access.

**Source**: `Identity_Primitives_Test_Support` provides:
```swift
extension Tagged: ExpressibleByIntegerLiteral
where Tag: ~Copyable, RawValue: ExpressibleByIntegerLiteral {
    @_disfavoredOverload
    public init(integerLiteral value: RawValue.IntegerLiteralType) { ... }
}
```

**Cyclic Extension**: `Cyclic_Primitives_Test_Support` provides:
```swift
extension Cyclic.Group.Element: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { ... }
}
```

**Import pattern**:
```swift
import Testing
@testable import Index_Primitives
import Index_Primitives_Test_Support  // Enables literals
```

**Re-export chain**:
```
Identity Primitives Test Support (source)
    |
Index Primitives Test Support (hub)
    |
Cyclic Primitives Test Support
    |
Pointer/Memory/Storage Primitives Test Support
```

**Available in tests** (when importing `{Package} Test Support`):

| Type | Literal Example |
|------|-----------------|
| `Index<T>` | `let index: Index<Int> = 5` |
| `Index<T>.Offset` | `let offset: Index<Int>.Offset = -3` |
| `Index<T>.Count` | `let count: Index<Int>.Count = 10` |
| `Ordinal` | `let pos: Ordinal = 5` |
| `Cardinal` | `let card: Cardinal = 5` |
| `Cyclic.Group<N>.Element` | `let elem: Cyclic.Group<5>.Element = 3` |

**Note**: These are `@_disfavoredOverload` --- test convenience only, not production.

**Cross-references**: [TEST-018]

---

### [CONV-008] Test Value and Comparison Patterns

**Statement**: Tests MUST NOT derive values from index conversions. Use external counters. Tests MUST NOT access intermediate properties (`.position`, `.rawValue`) when literal comparisons work.

**Correct** --- external counter:
```swift
var i = 0
(.zero..<count).forEach { index in
    storage.initialize(to: i * 10, at: index)
    i += 1
}
```

**Incorrect** --- escaping to Int:
```swift
(.zero..<count).forEach { index in
    // ❌ Converting index to compute value
    storage.initialize(to: Int(bitPattern: index.position.rawValue) * 10, at: index)
}
```

**Correct comparison** --- literal:
```swift
#expect(index == 5)              // ✓ Literal comparison
#expect(element == 3)            // ✓ Literal comparison
#expect(cyclicIndex == 3)        // ✓ Literal comparison (Tagged)
#expect(offset == -3)            // ✓ Literal comparison
```

**Incorrect comparison** --- unwrapping:
```swift
#expect(index.position.rawValue == 5)      // ❌ Multi-level unwrap
#expect(index.rawValue == 5)               // ❌ Accessing internal (for Index<T>)
#expect(element.position == 3)             // ❌ Accessing internal representation
#expect(cyclicIndex.rawValue == 3)         // ❌ Accessing internal (for Tagged)
#expect(cyclicIndex.rawValue.position == 3)  // ❌ Multi-level unwrap
```

**Rationale**: Literal conformances exist specifically for test convenience. Using property access when literals work is unnecessarily verbose and couples tests to implementation details.

---

### [IDX-016] Test Suite Structure

**Statement**: Use type extension pattern for Index test suites.

```swift
private enum IntTag {}

@Suite("Index")
struct IndexTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}

extension IndexTests.Unit {
    @Test
    func `init with valid position`() throws {
        let index: Index<Int> = try Index(5)
        #expect(index == 5)
    }
}
```

**Note**: Generic type specializations (like `Index<Int>`) require parallel namespace pattern due to Swift Testing limitation.

---

## Cross-References

See also:
- **anti-patterns** skill for [PATTERN-017] rawValue access location and [PATTERN-018] no escaping to Int
- **memory-arithmetic** skill for typed `Memory.Address` arithmetic
- **pointer-arithmetic** skill for `Pointer<T>` subscripts with `Index<T>`
- **testing** skill for [TEST-018] literal conformances
- Research: `swift-institute/Research/primitives-conversion-anti-patterns.md`
- Test file: `Tests/Index Primitives Tests/Index Tests.swift`
