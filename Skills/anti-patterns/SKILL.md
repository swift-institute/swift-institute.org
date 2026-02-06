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

## [PATTERN-019] No Blanket Tagged Init Constructors

**Scope**: All `extension Tagged where RawValue == T` declarations.

**Statement**: Extensions on `Tagged` constrained only by `RawValue` and `Tag: ~Copyable` MUST NOT provide public `init` constructors. Such inits are available on ALL `Tagged<_, T>` specializations, including bounded types that require stricter validation.

```swift
// ANTI-PATTERN — Blanket init bypasses bounded type invariants
extension Tagged where RawValue == Ordinal, Tag: ~Copyable {
    public init(_ count: Tagged<Tag, Cardinal>) {  // ❌ Available on Ordinal.Finite<N>
        self.init(__unchecked: (), Ordinal(count.rawValue))
    }
}
// Ordinal.Finite<5>(someCardinal) silently accepts values >= 5

// CORRECT — Typed arithmetic (preferred when an operator exists)
let endIndex: Index<Element> = .zero + header.count

// CORRECT — __unchecked when no typed operator path exists
let index = Index<Element>(__unchecked: (), Ordinal(header.count.rawValue))

// CORRECT — Bounded types provide their own validated init
extension Tagged where Tag == Finite.Bound<N>, RawValue == Ordinal {
    public init?(_ position: Ordinal) { ... }  // Validates position < N
}
```

**Victim types**: Any `Tagged<SpecificTag, T>` where `SpecificTag` constrains the valid range. Examples: `Ordinal.Finite<N>`, `Algebra.Z<n>`, `Memory.Address`.

**Rationale**: Blanket inits on Tagged create a universal backdoor. Swift's overload resolution prefers non-optional, non-throwing overloads, so the blanket init wins over the bounded type's validated `init?`. The compiler will never warn about this — the bounded type's invariant is silently bypassed.

**Cross-references**: [PATTERN-020], [CONV-001]

---

## [PATTERN-020] No False-Security Throwing Inits

**Scope**: Blanket or base-type throwing initializers on wrapper types.

**Statement**: A throwing init on a wrapper type MUST NOT validate only the base type's invariant when the wrapper may specialize to types with stricter invariants. The `try` keyword gives callers false confidence that full validation occurred.

```swift
// ANTI-PATTERN — Validates non-negativity but not upper bound
extension Tagged where RawValue == Ordinal, Tag: ~Copyable {
    public init(_ position: Int) throws(Ordinal.Error) {  // ❌
        self.init(__unchecked: (), try Ordinal(position))
    }
}
// try Ordinal.Finite<5>(10) succeeds — try gives false confidence

// CORRECT — No blanket throwing init; bounded types validate fully
extension Tagged where Tag == Finite.Bound<N>, RawValue == Ordinal {
    public init(_ position: Int) throws(Ordinal.Finite<N>.Error) {
        // Validates BOTH non-negativity AND < N
    }
}
```

**The false-security pattern**: The caller writes `try`, sees a potential error path, and reasonably concludes the value is validated. But the validation only checks the base type's invariant (non-negative), not the specialized type's invariant (< N). This is worse than no validation because it creates a false sense of safety.

**Rationale**: Throwing inits on generic wrapper types conflate base-type validation with domain validation. Each bounded specialization must validate its own invariants through its own init.

**Cross-references**: [PATTERN-019], [API-ERR-001]

---

## [PATTERN-021] Prefer Typed Arithmetic over __unchecked

**Scope**: All construction of Index, Ordinal, and Tagged types.

**Statement**: When a typed arithmetic operator exists for a conversion, it MUST be preferred over `__unchecked` with rawValue extraction. `__unchecked` is a last-resort construction path for same-package internals where no typed operator exists.

```swift
// CORRECT — Typed arithmetic (preferred)
let endIndex: Index<Element> = .zero + count       // Count → Index via Ordinal.Protocol +
let next = index + .one                            // Advance via Tagged + Cardinal
let prev = try index - .one                        // Retreat via Tagged - Vector

// AVOID — rawValue extraction when typed arithmetic is available
let endIndex = Index<Element>(__unchecked: (), Ordinal(count.rawValue))  // ❌ Use .zero + count
let next = Index<Element>(__unchecked: (), Ordinal(index.position.rawValue + 1))  // ❌ Use + .one
```

**When `__unchecked` IS justified**:
- Same-package operator implementations that define the typed arithmetic
- Construction from raw values at system boundaries (C interop, deserialization)
- Cases where no typed operator path exists between source and target types

**In test code**: Test Support provides `ExpressibleByIntegerLiteral` [CONV-007] for all Tagged types, so tests can construct values directly from literals:
```swift
let index: Index<Int> = 5           // Test only
let count: Index<Int>.Count = 10    // Test only
```
This is the preferred construction in tests — neither `__unchecked` nor verbose typed arithmetic is needed.

**Rationale**: Typed arithmetic stays within the type system, preserves invariants, and is self-documenting. `__unchecked` bypasses validation, exposes rawValue, and couples call-sites to internal representations. When the type system provides an operator, use it.

**Cross-references**: [CONV-015], [CONV-010], [PATTERN-018]

---

## Cross-References

See also:
- **naming** skill for correct naming patterns
- **errors** skill for correct error handling
- **memory** skill for correct ~Copyable patterns
- **conversions** skill for [CONV-010] typed arithmetic, [CONV-015] prefer typed arithmetic over `__unchecked`, [IDX-006a] `.one` resolution
- **memory-arithmetic** skill for [MEM-ARITH-001] typed address arithmetic
- **pointer-arithmetic** skill for [PTR-ARITH-001] typed pointer arithmetic
- **testing** skill for [TEST-018] Test Support literal conformances
