---
name: anti-patterns
description: |
  Common mistakes and anti-patterns to avoid.
  Reference this skill when reviewing code for correctness.

layer: implementation

requires:
  - swift-institute
  - naming
  - errors
  - code-organization

applies_to:
  - swift
  - swift6
  - primitives
  - standards
  - foundations

migrated_from: Implementation/Anti-Patterns.md
migration_date: 2026-01-28
---

# Anti-Patterns

Common mistakes to avoid when implementing Swift Institute packages.

**Applies to**: All implementation code in Swift Institute packages.

**Does not apply to**: External dependencies or third-party code.

---

## [PATTERN-009] No Foundation Types

**Scope**: All primitive and standard packages.

**Statement**: Primitive and standard packages MUST NOT use Foundation types.

```swift
// CORRECT
import Buffer_Primitives
import Temporal_Primitives
func parse(_ buffer: Buffer) -> Instant { ... }

// ANTI-PATTERN
import Foundation
func parse(_ data: Data) -> Date { ... }
```

**Rationale**: Foundation types prevent Swift Embedded deployment and introduce platform-specific behavior differences.

**Cross-references**: [API-NAME-001], [API-PLAT-001]

---

## [PATTERN-010] Nested Type Names

**Scope**: All type declarations.

**Statement**: Types MUST use nested namespaces, not compound names.

```swift
// CORRECT
enum PDF {
    struct Page { }
    struct Document { }
}
// Usage: PDF.Page, PDF.Document

// ANTI-PATTERN
struct PDFPage { }
struct PDFDocument { }
```

**Rationale**: Nested types provide namespace organization and read as `PDF.Page`, matching specification terminology. Type `PDF.` and autocomplete reveals the entire domain.

**Cross-references**: [API-NAME-001], [API-NAME-002]

---

## [PATTERN-011] Typed Error Enums

**Scope**: All error types.

**Statement**: Errors MUST be typed enums with associated values, not string-based errors.

```swift
// CORRECT
enum ParseError: Error {
    case invalidHeader(expected: UInt32, found: UInt32)
}
throw ParseError.invalidHeader(expected: 0x25504446, found: header)

// ANTI-PATTERN
throw NSError(domain: "Parser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid header"])
```

**Rationale**: Typed errors enable exhaustive switch handling and preserve diagnostic information for programmatic error recovery.

**Cross-references**: [API-ERR-001]

---

## [PATTERN-012] Initializers as Canonical Implementation

**Scope**: Type transformations and conversions.

**Statement**: Canonical implementation for type transformations MUST live in initializers or static methods on the target type. Instance methods are convenience wrappers only.

```swift
// CORRECT
extension Radian {
    init(_ degrees: Degree) { ... }  // Canonical
}
extension Degree {
    var asRadians: Radian { Radian(self) }  // Convenience only
}

// ANTI-PATTERN
extension Angle {
    func toRadians() -> Double { ... }  // Where is the real logic?
}
```

**Rationale**: Initializers on the target type make the transformation discoverable via autocomplete on the target type. The canonical implementation has a single, predictable location.

**Cross-references**: [API-IMPL-001]

---

## [PATTERN-013] Concrete Types Before Abstraction

**Scope**: Protocol and generic type design.

**Statement**: Abstractions MUST emerge from concrete implementations. Protocols MUST NOT be designed before having 3+ concrete conformers.

```swift
// CORRECT - Start concrete
struct Circle<T: BinaryFloatingPoint> {
    var center: Point<2, T>
    var radius: T
}
// Abstract only when you have 3+ concrete conformers

// ANTI-PATTERN - Abstract for hypotheticals
protocol GeometricShape {
    associatedtype Coordinate
    func contains(_ point: Coordinate) -> Bool
    func intersects(_ other: Self) -> Bool
    // ... 20 more requirements
}
```

**Rationale**: Premature abstraction creates protocols that do not fit real use cases. Concrete implementations reveal actual requirements before abstracting.

---

## [PATTERN-015] Macro Naming Exception

**Scope**: Swift macro declarations.

**Statement**: Swift macros MUST be declared at file scope. Macros CANNOT be nested in extensions or types. When the nesting convention [API-NAME-001] would produce `@Namespace.MacroName`, the macro MUST instead use a compound name: `@NamespaceMacroName`.

This is a language limitation that overrides the design convention.

```swift
// CORRECT - Macro at file scope with compound name
@attached(member, names: named(init), named(scope))
public macro WitnessScope() = #externalMacro(...)

// ANTI-PATTERN - Cannot nest macro in extension
extension Witness {
    @attached(member, names: named(init), named(scope))
    public macro Scope() = #externalMacro(...)  // Error: macro must be at file scope
}
```

### Naming Guidance for Macros

| Intended Namespace | Macro Name | Rationale |
|--------------------|------------|-----------|
| `Witness.Scope` | `@WitnessScope` | Compound name required |
| `Effect.Generator` | `@EffectGenerator` | Compound name required |
| `Codable.Custom` | `@CodableCustom` | Compound name required |

**Rationale**: Language limitations sometimes override design conventions. The exception is narrow (macros only) and the rationale is clear (language constraint).

**Cross-references**: [API-NAME-001]

---

## [PATTERN-016] Conscious Technical Debt

**Scope**: Intentional deviations from best practices due to compiler limitations or other constraints.

**Statement**: Code that violates a pattern MAY be acceptable when it meets ALL of these criteria:

| Criterion | Description | Required |
|-----------|-------------|----------|
| **Intentional** | Chosen after evaluating alternatives | Yes |
| **Documented** | Explicit comments explain the situation | Yes |
| **Bounded** | Limited to specific files or types | Yes |
| **Removal criteria** | Specific conditions for when to remove | Yes |

```swift
// CORRECT - Conscious technical debt
// ============================================================================
// TEMPORARY WORKAROUND - DO NOT MODIFY WITHOUT CHECKING COMPILER STATUS
// ============================================================================
//
// WHY THIS EXISTS:
// Swift compiler bug [MEM-COPY-006] Category 3 prevents using
// List<Element>.Linked<1> as storage when Element: ~Copyable.
//
// WHEN TO REMOVE:
// Delete these types when compiler fixes cross-module ~Copyable propagation.
// Track: swift/issues/86xxx
//
// MAINTENANCE:
// If List.Linked storage changes, these MUST be updated to match.
// Source of truth: swift-list-primitives/Sources/List Primitives/List.Linked.swift
// ============================================================================

// ANTI-PATTERN - Accidental debt
// Just copied this because I couldn't get the import working
// TODO: fix later
struct Storage { ... }
```

**Minimal inline format**:
```swift
// WORKAROUND: [What this works around]
// WHY: [Why normal approach doesn't work]
// WHEN TO REMOVE: [Specific removal criteria]
// TRACKING: [Issue URL or internal reference]
```

### Distinguishing Conscious from Accidental Debt

| Property | Conscious Debt | Accidental Debt |
|----------|----------------|-----------------|
| Origin | Deliberate decision | Expedience or neglect |
| Documentation | Explicit header block | None or "TODO: fix" |
| Scope | Precisely bounded | Undefined spread |
| Exit plan | Specific removal criteria | "Someday" |
| Tracking | Issue reference | None |

**Rationale**: Not all technical debt is bad. Conscious debt with clear boundaries and removal criteria is a legitimate engineering tool. The documentation ensures future maintainers understand the intent and can act when conditions change.

**Cross-references**: [MEM-COPY-006], [API-IMPL-005]

---

## [PATTERN-017] rawValue and Property Access Location

**Scope**: All code using primitives types (Index, Ordinal, Cardinal, Memory.Address, Cyclic.Group.Element, etc.).

**Statement**: `.rawValue` and intermediate property access (`.position`) MUST be confined to extension initializers and same-package implementations. Call-sites MUST use extension APIs that accept the higher-level type.

---

## [PATTERN-018] No Escaping to Int for Arithmetic

**Scope**: All arithmetic on primitives types.

**Statement**: Arithmetic MUST use typed operators. Converting to `Int` via `Int(bitPattern:)` or `.rawValue` to perform computation defeats type safety. `Int(bitPattern:)` is a **last resort** escape hatch for interop only.

```swift
// CORRECT - Typed arithmetic
let next = index + 1                    // Index<T> + Offset → Index<T>
let distance = end - start              // Index<T> - Index<T> → Offset
let address = base + (count * stride)   // Memory.Address arithmetic
let wrapped = cyclicIndex + 1           // Automatic wraparound

// ANTI-PATTERN - Escaping to Int
let next = Index(Int(bitPattern: index) + 1)          // ❌ Type safety lost
let distance = Int(bitPattern: end) - Int(bitPattern: start)  // ❌
let scaled = Int(bitPattern: count) * stride          // ❌
```

**Valid uses of `Int(bitPattern:)`**:
| Use Case | Example | Valid |
|----------|---------|-------|
| C interop | `read(fd, buffer, Int(bitPattern: count))` | ✓ Yes |
| Standard Library | `array[Int(bitPattern: index)]` | ✓ Yes |
| Debug output | `print("index: \(Int(bitPattern: index))")` | ✓ Yes |
| Computation | `Int(bitPattern: a) + Int(bitPattern: b)` | ✗ Never |

**Rationale**: Typed arithmetic preserves invariants: indices stay non-negative, cyclic types wrap correctly, offsets can be negative but indices cannot. Escaping to `Int` strips these guarantees and introduces bugs that the type system was designed to prevent.

**Cross-references**: [CONV-010], [MEM-ARITH-001], [PTR-ARITH-001]

```swift
// CORRECT - Extension init hides rawValue access
extension Int {
    public init(bitPattern position: Ordinal) {
        self = Int(bitPattern: position.rawValue)  // ✓ rawValue here only
    }
}

// CORRECT - Clean call-site passes higher type
let i = Int(bitPattern: index)

// ANTI-PATTERN - rawValue chain at call-site
let i = Int(bitPattern: index.position.rawValue)  // ❌ Never do this
```

**Multi-layer chains are always wrong at call-sites**:
```swift
// ANTI-PATTERN - All of these
Int(bitPattern: index.position.rawValue)    // ❌
element.position.rawValue                    // ❌
index.position.rawValue * 5                  // ❌
```

**Single-level property access is also wrong at call-sites**:
```swift
// ANTI-PATTERN - Accessing internal representation for comparison
#expect(element.position == 3)               // ❌ Use literal: element == 3
#expect(index.rawValue == 3)                 // ❌ Use literal: index == 3
#expect(cyclicIndex.rawValue == 3)           // ❌ Use literal: cyclicIndex == 3
```

**Justified locations for rawValue/position access**:

| Location | Example | Justified |
|----------|---------|-----------|
| Extension initializer | `Int.init(bitPattern: Ordinal)` | ✓ Yes |
| Same-package implementation | `Cyclic.Group + operator using .position` | ✓ Yes |
| Bit-pattern verification test (same package) | Cyclic primitives testing Element internals | ✓ Yes |
| Higher-layer package test | Cyclic Index Primitives tests | ✗ Never |
| Application code | Any call-site | ✗ Never |

**Special case for Index<T>.Cyclic<N>**:
```swift
// ✓ CORRECT: Compare Tagged index directly to literal
#expect(cyclicIndex == 3)

// ❌ WRONG: Access rawValue for comparison
#expect(cyclicIndex.rawValue == 3)

// ❌ WRONG: Peek at position (internal)
#expect(cyclicIndex.rawValue.position == 3)
```

**Rationale**: Extension inits encapsulate the layer boundary. Call-sites stay clean and type-safe. Test Support provides literal conformances specifically so tests don't need property access.

**Cross-references**: [PATTERN-012] Initializers as Canonical Implementation, [CONV-001], [CONV-001a], [TEST-018]

---

## Cross-References

See also:
- **naming** skill for correct naming patterns
- **errors** skill for correct error handling
- **memory** skill for correct ~Copyable patterns
- **conversions** skill for conversion API reference and [CONV-010] typed arithmetic
- **memory-arithmetic** skill for [MEM-ARITH-001] typed address arithmetic
- **pointer-arithmetic** skill for [PTR-ARITH-001] typed pointer arithmetic
- **testing** skill for [TEST-018] Test Support literal conformances
