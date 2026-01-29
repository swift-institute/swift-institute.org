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

**Core Principle**: `.rawValue` access belongs in extension initializers only. Call-sites pass higher-level types.

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

### [CONV-002] Justified rawValue Access

**Statement**: Direct `.rawValue` access is justified ONLY in these locations:

| Location | Example | Justified |
|----------|---------|-----------|
| Extension initializer | `Int.init(bitPattern: Ordinal)` | Yes |
| Same-package implementation | `UnsafeRawPointer.init(_ address:)` | Yes |
| Same-package bit-pattern test | Memory primitives testing arithmetic | Yes |
| Higher-layer package | Storage primitives | Never |
| Application code | Any call-site | Never |

**Incorrect** — higher-layer package accessing dependency internals:
```swift
// In storage-primitives tests — WRONG
Int(bitPattern: index.position.rawValue) * 10
```

**Rationale**: Package boundaries should be respected. Higher packages use the APIs lower packages export, not their internal representations.

---

## Conversion API Reference

### [CONV-003] Index Conversions

**Statement**: Use these APIs for `Index<T>` (aka `Tagged<T, Ordinal>`) conversions.

| From | To | API | Throws | Notes |
|------|-----|-----|--------|-------|
| `Index<T>` | `Int` | `Int(bitPattern: index)` | No | Unchecked bit reinterpret |
| `Index<T>` | `Int` | `try Int(index)` | Yes | Throws if > Int.max |
| `Index<T>` | `Int` | `Int(exactly: index)` | No | nil if > Int.max |
| `Index<T>` | `Ordinal` | `.position` | No | Property access |
| `Int` | `Index<T>` | `try Index(int)` | Yes | Throws if negative |
| `Int` | `Index<T>` | `Index(exactly: int)` | No | nil if negative |
| `Ordinal` | `Index<T>` | `Index(ordinal)` | No | Total |
| `Cardinal` | `Index<T>` | `Index(cardinal)` | No | Total |

**Example**:
```swift
let index: Index<Int> = try Index(5)
let position: Ordinal = index.position
let int: Int = Int(bitPattern: index)
```

---

### [CONV-004] Cardinal Conversions

**Statement**: Use these APIs for `Cardinal` and `Index<T>.Count` conversions.

| From | To | API | Throws | Notes |
|------|-----|-----|--------|-------|
| `Cardinal` | `Int` | `Int(bitPattern: cardinal)` | No | Unchecked |
| `Cardinal` | `Int` | `try Int(cardinal)` | Yes | Throws if > Int.max |
| `Cardinal` | `Int` | `Int(exactly: cardinal)` | No | nil if > Int.max |
| `Int` | `Cardinal` | `try Cardinal(int)` | Yes | Throws if negative |
| `Ordinal` | `Cardinal` | `Cardinal(ordinal)` | No | Total |
| `Cardinal` | `Ordinal` | `Ordinal(cardinal)` | No | Total |

**Index<T>.Count** follows same pattern (is `Tagged<T, Cardinal>`).

---

### [CONV-005] Ordinal Conversions

**Statement**: Use these APIs for `Ordinal` conversions.

| From | To | API | Throws | Notes |
|------|-----|-----|--------|-------|
| `Ordinal` | `Int` | `Int(bitPattern: ordinal)` | No | Unchecked |
| `Ordinal` | `Int` | `try Int(ordinal)` | Yes | Throws if > Int.max |
| `Ordinal` | `Int` | `Int(exactly: ordinal)` | No | nil if > Int.max |
| `Int` | `Ordinal` | `try Ordinal(int)` | Yes | Throws if negative |
| `Int` | `Ordinal` | `Ordinal(exactly: int)` | No | nil if negative |
| `UInt` | `Ordinal` | `Ordinal(uint)` | No | Total |

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

**Statement**: Test Support modules provide `ExpressibleByIntegerLiteral` via re-export chain. Tests SHOULD use literal syntax.

**Source**: `Identity_Primitives_Test_Support` provides:
```swift
extension Tagged: ExpressibleByIntegerLiteral
where Tag: ~Copyable, RawValue: ExpressibleByIntegerLiteral {
    @_disfavoredOverload
    public init(integerLiteral value: RawValue.IntegerLiteralType) { ... }
}
```

**Re-export chain**:
```
Identity Primitives Test Support (source)
    ↓
Index Primitives Test Support (hub)
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

**Note**: These are `@_disfavoredOverload` — test convenience only, not production.

**Cross-references**: [TEST-018]

---

### [CONV-008] Test Value Patterns

**Statement**: Tests MUST NOT derive values from index conversions. Use external counters.

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
#expect(index == 5)           // ✓ Literal comparison
#expect(index.position == 5)  // ✓ Ordinal literal
```

**Incorrect comparison**:
```swift
#expect(index.position.rawValue == 5)  // ❌ Unwrapping
```

**Rationale**: Literal conformances exist specifically for test convenience. Using rawValue chains when literals work is unnecessarily verbose.

---

## Cross-References

See also:
- **anti-patterns** skill for [PATTERN-017] rawValue access location
- **testing** skill for [TEST-018] Test Support literal conformances
- Research: `swift-institute/Research/primitives-conversion-anti-patterns.md`
