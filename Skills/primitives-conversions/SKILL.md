---
name: primitives-conversions
description: |
  Conversion APIs between primitives types and rawValue access rules.
  Apply when converting between Index, Ordinal, Cardinal, Int, or accessing rawValue.

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

# Primitives Conversions

Conversion APIs and rawValue access rules for primitives types. These rules ensure clean call-sites and proper encapsulation of type layer boundaries.

**Core Principle**: `.rawValue` and `.position` access belong in extension initializers only. Call-sites pass higher-level types.

---

## rawValue Access Rules

### [CONV-001] rawValue Location

**Statement**: `.rawValue` access MUST be confined to extension initializers and same-package implementations. Call-sites MUST pass higher-level types directly.

**Correct** — extension init encapsulates rawValue:
```swift
// In Ordinal Primitives
extension Int {
    public init(bitPattern position: Ordinal) {
        self = Int(bitPattern: position.rawValue)  // rawValue here only
    }
}

// In Tagged+Ordinal — delegates to Ordinal version
extension Int {
    public init<Tag: ~Copyable>(bitPattern position: Tagged<Tag, Ordinal>) {
        self = Int(bitPattern: position.rawValue)
    }
}
```

**Correct** — clean call-site:
```swift
let i = Int(bitPattern: index)
```

**Incorrect** — rawValue chain at call-site:
```swift
let i = Int(bitPattern: index.position.rawValue)  // ❌ Never
```

**Rationale**: Extension inits encapsulate layer boundaries. Call-sites remain clean and type-safe. When internal representations change, only extension inits need updates.

**Cross-references**: [PATTERN-012], [PATTERN-017]

---

### [CONV-001a] Intermediate Property Access Location

**Statement**: Intermediate property access (`.position`, `.rawValue`) MUST be confined to extension initializers and same-package implementations. Higher-layer packages and call-sites MUST compare at the semantic type level using literal conformances.

**Incorrect** — property access at call-site:
```swift
#expect(element.position == 3)           // ❌ Crosses layer boundary
#expect(index.rawValue == 3)             // ❌ Accesses internal representation
#expect(cyclicIndex.rawValue == 3)       // ❌ Accesses internal representation
#expect(cyclicIndex.rawValue.position == 3)  // ❌ Severe — multi-level unwrap
```

**Correct** — compare at semantic type level:
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

**Incorrect** — higher-layer package accessing dependency internals:
```swift
// In cyclic-index-primitives tests — WRONG
#expect(index.rawValue.position == 3)
```

**Rationale**: Package boundaries should be respected. Higher packages use the APIs lower packages export, not their internal representations.

---

## Typed Arithmetic First

### [CONV-010] Prefer Typed Arithmetic

**Statement**: Arithmetic MUST use typed operators on primitives types (`Index<T>`, `Offset`, `Count`, `Memory.Address`). Converting to `Int` for computation defeats type safety and is ONLY justified for interop with external APIs that require `Int`.

**Correct** — typed arithmetic:
```swift
let next = index + 1                    // Index<T> + Offset → Index<T>
let distance = end - start              // Index<T> - Index<T> → Offset
let stride = count * MemoryLayout<T>.stride  // Count arithmetic
address + offset                        // Memory.Address + Offset
```

**Incorrect** — escaping to Int for computation:
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
| `Index<T>` | `Int` | `Int(bitPattern: index)` | No | **Last resort** — interop only |

**Example**:
```swift
let index: Index<Int> = try Index(5)
let position: Ordinal = index.position

// Typed arithmetic — PREFERRED
let next = index + 1
let distance = otherIndex - index

// Int conversion — ONLY for interop
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
| `Cardinal` | `Int` | `Int(bitPattern: cardinal)` | No | **Last resort** — interop only |

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
| `Ordinal` | `Int` | `Int(bitPattern: ordinal)` | No | **Last resort** — interop only |

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

## Test Support Literal Conformances

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

**Re-export chain**:
```
Identity Primitives Test Support (source)
    ↓
Index Primitives Test Support (hub)
    ↓
Cyclic Primitives Test Support
    ↓
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

**Note**: These are `@_disfavoredOverload` — test convenience only, not production.

**Cross-references**: [TEST-018]

---

### [CONV-008] Test Value Patterns

**Statement**: Tests MUST NOT derive values from index conversions. Use external counters. Tests MUST NOT access intermediate properties (`.position`, `.rawValue`) when literal comparisons work.

**Correct**:
```swift
var i = 0
(.zero..<count).forEach { index in
    storage.initialize(to: i * 10, at: index)
    i += 1
}
```

**Incorrect**:
```swift
(.zero..<count).forEach { index in
    // ❌ Converting index to compute value
    storage.initialize(to: Int(bitPattern: index.position.rawValue) * 10, at: index)
}
```

**Correct comparison**:
```swift
#expect(index == 5)              // ✓ Literal comparison
#expect(element == 3)            // ✓ Literal comparison
#expect(cyclicIndex == 3)        // ✓ Literal comparison (Tagged)
```

**Incorrect comparison**:
```swift
#expect(index.position.rawValue == 5)      // ❌ Multi-level unwrap
#expect(index.rawValue == 5)               // ❌ Accessing internal (for Index<T>)
#expect(element.position == 3)             // ❌ Accessing internal representation
#expect(cyclicIndex.rawValue == 3)         // ❌ Accessing internal (for Tagged)
#expect(cyclicIndex.rawValue.position == 3)  // ❌ Multi-level unwrap
```

**Rationale**: Literal conformances exist specifically for test convenience. Using property access when literals work is unnecessarily verbose and couples tests to implementation details.

---

## Cross-Domain Index Conversion

### [CONV-011] Count Chain for Cross-Domain Index Conversion

**Statement**: When converting an `Index<A>` to `Index<B>` via a known ratio, use the **count chain**: `Position → Count → scale → Count → Position`. This chain is entirely non-throwing when the ratio is positive and the source position is non-negative.

**Pattern**:
```swift
let sourceCount = Index<A>.Count(sourceIndex)    // Position → Count (total)
let targetCount = sourceCount * .ratio           // Count<A> → Count<B> (total)
let targetIndex = Index<B>(targetCount)          // Count → Position (total)
```

**Semantic justification**: Position N means "N elements precede this position". Converting to Count makes this cardinality explicit, which can then be scaled to another domain's cardinality, which maps back to a position. All steps are total (non-negative × positive = non-negative).

**Case study** — byte index to bit index (`Bit.Index+Byte.swift`):

**Correct** — count chain:
```swift
public init(_ byteIndex: Index<UInt8>) {
    let byteCount = Index<UInt8>.Count(byteIndex)
    let bitCount = byteCount * .bitsPerByte
    self = Self(bitCount)
}
```

**Incorrect** — manual Int arithmetic:
```swift
public init(_ byteIndex: Index<UInt8>) {
    let byteOffset = Index<UInt8>.Offset(Affine.Discrete.Vector(Int(bitPattern: byteIndex.position)))
    let bitOffset = byteOffset * .bitsPerByte
    self.init(__unchecked: (), Ordinal(UInt(bitOffset.rawValue.rawValue)))  // ❌
}
```

**Rationale**: The incorrect version has 4 manual Int conversions and 2 `.rawValue` unwraps. The correct version has zero — all arithmetic stays typed.

---

### [CONV-012] Hybrid Count + Offset for Mixed Conversion

**Statement**: When a cross-domain index conversion also requires an intra-domain signed offset, use the count chain for the base conversion and typed offset addition for the displacement. The offset addition requires `try!` because `Position + Offset` is partial (offset is signed), but is safe when the offset is known non-negative by domain constraint.

**Pattern**:
```swift
let sourceCount = Index<A>.Count(sourceIndex)    // Position → Count (total)
let targetCount = sourceCount * .ratio           // Count<A> → Count<B> (total)
let baseIndex = Index<B>(targetCount)            // Count → Position (total)
let result = try! baseIndex + offset             // Position + Offset (safe by invariant)
```

**Case study** — byte index with bit offset:

**Correct** — hybrid chain:
```swift
public init(_ byteIndex: Index<UInt8>, bitOffset: Index<Bit>.Offset) {
    let byteCount = Index<UInt8>.Count(byteIndex)
    let bitCount = byteCount * .bitsPerByte
    let baseBitIndex = Self(bitCount)
    self = try! baseBitIndex + bitOffset
}
```

**Incorrect** — raw Int addition:
```swift
let totalBitOffset = baseBitOffset.rawValue.rawValue + bitOffset.rawValue.rawValue  // ❌
self.init(__unchecked: (), Ordinal(UInt(totalBitOffset)))                           // ❌
```

**When `try!` is justified**: The offset is bounded by domain constraint (0..<8 for bits within a byte). The base index is non-negative. Adding a non-negative offset to a non-negative position cannot underflow.

**When to avoid `try!`**: If the offset could genuinely be negative and the base could be zero, use `try` with proper error propagation instead.

---

### [CONV-013] Offset Chain as Alternative

**Statement**: The **offset chain** (`Position → Offset → scale → Offset → Position`) is an alternative to the count chain. It uses `Offset(fromZero:)` to convert a position to a signed displacement, scales it, then adds back to zero. This chain requires `try!` for the final step because `Position + Offset` is partial.

**Pattern**:
```swift
let sourceOffset = Index<A>.Offset(fromZero: sourceIndex)  // encapsulates Int conversion
let targetOffset = sourceOffset * .ratio                   // Offset<A> → Offset<B>
let targetIndex = try! Index<B>.zero + targetOffset        // Offset → Position (safe)
```

**When to prefer the count chain [CONV-011] over offset chain**:
- Count chain is entirely non-throwing — no `try!` needed
- Count chain is semantically cleaner — positions ARE counts from zero
- Offset chain requires `try!` even when the invariant is trivially satisfied

**When the offset chain is appropriate**:
- When the conversion involves negative ratios (direction reversal)
- When the displacement is genuinely signed and may be negative
- When `Offset(fromZero:)` is already the natural starting point

---

### [CONV-014] stdlib Boundary Conversions

**Statement**: Conversions from Swift standard library properties that return `Int` (e.g., `FixedWidthInteger.bitWidth`, `MemoryLayout<T>.stride`) are **stdlib boundary conversions**. These are the correct location for `Int` values to enter the typed system. No further encapsulation is needed.

**Correct** — stdlib boundary:
```swift
extension Affine.Discrete.Ratio where To == Bit, From: FixedWidthInteger {
    public static var bitWidth: Self { .init(From.bitWidth) }  // Int from stdlib
}
```

**Rationale**: `From.bitWidth` returns `Int` by protocol definition. The `Ratio.init(_ factor: Int)` accepts `Int`. This is the natural entry point — wrapping it further would add complexity without benefit.

---

## Cross-References

See also:
- **anti-patterns** skill for [PATTERN-017] rawValue access location and [PATTERN-018] no escaping to Int
- **memory-arithmetic** skill for typed `Memory.Address` arithmetic
- **pointer-arithmetic** skill for typed `Pointer<T>` arithmetic
- **testing** skill for [TEST-018] Test Support literal conformances
- Research: `swift-institute/Research/primitives-conversion-anti-patterns.md`
