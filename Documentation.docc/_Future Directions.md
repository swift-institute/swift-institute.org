# Future Directions

<!--
---
title: Future Directions
version: 1.0.0
last_updated: 2026-01-16
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: false
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Swift Embedded expansion, additional standards, and community adoption.

## Overview

This document outlines planned expansions and future work for the Swift Institute ecosystem. It is informational, not normative. The directions described here represent active areas of development and community interest.

**Document type**: Informational roadmap (not prescriptive requirements).

**Applies to**: All packages in swift-primitives, swift-institute, and swift-standards.

---

## Swift Embedded

### [FUTURE-001] Swift Embedded Platform Support

**Scope**: All primitives packages for deployment on embedded targets.

**Status**: Ready. All 61 primitives packages compile without Foundation dependencies.

As Swift Embedded matures, the Swift Institute will serve as the foundation for embedded development:

- IoT device firmware
- Kernel modules
- Real-time systems
- Bare-metal applications

The Foundation-free design ensures primitives are ready for these constrained environments.

**Blocking factors**: Swift Embedded toolchain maturity. Current limitations include incomplete standard library support and platform-specific compiler flags still in flux.

**Next steps**:

1. Add CI jobs testing against Swift Embedded nightly builds
2. Document platform-specific compilation requirements
3. Provide example projects for common embedded targets (RP2040, ESP32, STM32)

**Cross-references**: <doc:Package-Inventory>, <doc:Five-Layer-Architecture>

---

## Mathematical Foundations

### [FUTURE-002] Complex Number Migration

**Scope**: Complex number primitives (`swift-complex-primitives`) and downstream consumers.

**Status**: In progress. Real-valued generic trigonometry is complete; complex operations are partially migrated.

While generic trigonometry is now achieved for real-valued geometry (see <doc:Mathematical-Foundations>), complex number primitives still use concrete Double/Float constraints in some operations. Future work includes migrating complex exponential and related functions to the `Numeric.Transcendental` pattern, enabling fully generic complex analysis.

**Blocking factors**: Complex transcendentals require careful handling of branch cuts and Riemann surfaces. The `cexp`, `clog`, and `cpow` functions have mathematical subtleties that require additional protocol requirements beyond `Numeric.Transcendental`.

**Next steps**:

1. Define `Complex.Transcendental` protocol extending `Numeric.Transcendental`
2. Implement branch-cut-aware complex logarithm
3. Migrate `swift-complex-primitives` to generic constraints
4. Update downstream consumers (signal processing, control theory packages)

**Cross-references**: <doc:Mathematical-Foundations>

---

## Standards Expansion

### [FUTURE-003] Additional Standard Implementations

**Scope**: New specification packages in swift-standards.

**Status**: Planning. Priority determined by downstream consumer requirements.

As primitives stabilize, swift-standards will expand to additional specifications. Each specification will build on primitives without duplicating their functionality.

| Specification | Description | Dependencies | Priority |
|---------------|-------------|--------------|----------|
| ISO 8601 | Date and time formats | Temporal primitives | High |
| IEEE 1788 | Interval arithmetic | Numeric primitives | Medium |
| ISO 80000 | Quantities and units | Dimension primitives | Medium |
| Unicode UAX #29 | Text segmentation | String primitives | High |
| Unicode UTS #35 | Locale data | None | Low |

**Blocking factors**: Priority is given to specifications required by downstream consumers. ISO 8601 is high priority because `swift-http` and other networking packages require standardized date parsing without Foundation's `DateFormatter`.

**Cross-references**: <doc:Package-Inventory>, <doc:Layer-Flowchart>

---

## Community and Ecosystem

### [FUTURE-004] Community Adoption

**Scope**: External projects and Swift community practices.

**Status**: Early adoption. Several external projects have expressed interest in depending on primitives for their Foundation-free guarantees.

The primitives model may influence broader Swift community practices:

- Library authors adopting Foundation-free approaches
- Framework developers separating primitives from conveniences
- Educational materials teaching type-safe dimensional analysis

**Adoption opportunities**:

| Domain | Description | Alignment |
|--------|-------------|-----------|
| Swift Server Working Group | Foundation-free alternatives for server-side Swift | High |
| Swift for Machine Learning | Numeric and linear algebra primitives for ML infrastructure | High |
| Game Development | Geometry and affine primitives for real-time rendering | Medium |

**How to contribute**:

1. Write blog posts explaining the architecture
2. Speak at Swift conferences about the primitives model
3. Port existing projects to depend on primitives

**Cross-references**: <doc:Five-Layer-Architecture>, <doc:Glossary>

---

## Design Evolution

### [FUTURE-005] Deletion as Refinement

**Scope**: Package and API evolution across all repositories.

**Status**: Ongoing. This is a design philosophy, not a specific feature.

Infrastructure refinement often means removing concepts rather than adding them. When a package is conceived, implemented, and then deleted because its abstractions do not compose with Swift's type system, this is not failure—it is refinement.

**Principle**: Timeless infrastructure does not add concepts. It clarifies them.

When exploring a new abstraction:
1. Attempt the implementation
2. If language constraints prevent clean composition, consider deletion
3. Prefer stdlib extensions that add no new concepts over packages that add many

**Example**: `swift-scope-primitives` was conceived to provide generic `Scope.TaskLocal<Values>` wrappers. The implementation failed because `@TaskLocal` cannot exist inside generic types. Rather than work around the limitation, the package was deleted. The stdlib extensions that replaced it are better precisely because they add no new concepts—they make existing concepts work correctly.

**Indicators of successful refinement**:
- Dependency graph ends with fewer packages than it started with
- Existing concepts gain capability without new types
- Code becomes more obvious, not more clever

**Cross-references**: <doc:API-Requirements>, <doc:Primitives-Architecture>

---

### [FUTURE-006] Language Features for Ergonomic Type-Keyed Access

**Scope**: Witness access patterns and dependency injection ergonomics.

**Status**: Blocked by Swift language evolution. These features would require significant language changes.

Cross-language analysis of dependency access patterns (ZIO, mtl, Effect-TS) revealed specific Swift language gaps that prevent property-style syntax for type-keyed containers. This analysis is valuable because it specifies exactly what language evolution would need to provide—and confirms that current subscript syntax is correct given constraints.

#### Missing Features

| Feature | Description | Example Syntax | Enables |
|---------|-------------|----------------|---------|
| **Implicit resolution** | Scala-style `implicit` parameters resolved by type | `context.apiClient` resolving `implicit APIClient` | Property access for witnesses |
| **Open type families** | Extensible type-level mappings across modules | `type family Lookup a` | Modular name→type registration |
| **Effect types** | Requirements declared in function signatures | `func fetch() -> Response requiring APIClient` | Self-documenting dependencies |
| **Type-to-name reflection** | Compile-time derivation of identifiers from types | `\(lowerCamelCase: APIClient.self)` → `"apiClient"` | Property synthesis |

#### Ideal Syntax Sketches

If these features existed, witness access could look like:

```swift
// Ideal: property syntax with implicit resolution
let client = $.apiClient  // Resolves APIClient from context

// Ideal: effect types in signatures
func fetchUser() -> User requiring APIClient, Logger {
    $.apiClient.get("/users/1")
}

// Ideal: automatic dependency declaration
@requiring(APIClient, Logger)
func syncData() async throws { ... }
```

#### Current Reality

Swift provides none of these mechanisms. The subscript syntax `values[Key.self]` is the correct idiom—the type parameter serves as the identifier. See [API-DESIGN-001] for detailed analysis of why alternatives fail.

**Blocking factors**: Each feature would require Swift Evolution proposals and significant compiler work. Implicit resolution particularly conflicts with Swift's philosophy of explicitness. Effect types may eventually appear in a different form (via typed throws evolution or macro-based solutions).

**Next steps**:

1. Monitor Swift Evolution for proposals related to effect systems
2. Consider macro-based solutions for dependency documentation (not resolution)
3. Continue refining subscript-based patterns for ergonomics within constraints

**Cross-references**: [API-DESIGN-001], <doc:API-Requirements>

---

### [FUTURE-007] Input Protocol Unification

**Scope**: Unifying parallel input abstractions across swift-input-primitives, swift-binary-primitives, and swift-parser-primitives.

**Status**: Opportunity identified. Implementation deferred pending ~Escapable protocol support.

A survey of swift-primitives packages revealed three packages that independently converged on identical input abstractions:

| Package | Types | Status |
|---------|-------|--------|
| swift-input-primitives | `Input.Streaming`, `Input.Protocol`, `Input.Slice` | Canonical |
| swift-parser-primitives | `Parsing.Streaming`, `Parsing.Input`, `Parsing.CollectionInput` | Parallel (identical contracts) |
| swift-binary-primitives | `Binary.Bytes.Input`, `Binary.Bytes.Input.View` | Parallel (owned + borrowed) |

The ideal unification:

```swift
// In Parser_Primitives
public typealias Streaming = Input_Primitives.Input.Streaming
public typealias Input = Input_Primitives.Input.Protocol
```

This would enable parsing combinators and binary parsers to share infrastructure.

**Blocking factors**:

1. `~Escapable` types cannot satisfy protocol associated types in Swift 6.x
2. `Binary.Bytes.Input.View` (the borrowed view) cannot conform to `Input.Protocol`
3. Until Swift supports `~Escapable` in protocol contexts, borrowed views must remain separate

The non-borrowed `Binary.Bytes.Input` could conform today. The unification would reduce maintenance burden and enable cross-package combinator sharing.

**Next steps**:

1. Add `Input.Protocol` conformance to `Binary.Bytes.Input` (owned variant)
2. Replace `Parsing.Streaming`/`Parsing.Input` with typealiases to Input primitives
3. Monitor Swift Evolution for `~Escapable` protocol support
4. Document the two-world pattern (owned/borrowed) until unification is complete

**Cross-references**: [MEM-COPY-011], [API-DESIGN-013], <doc:Memory-Copyable>

---

## Collection Primitives Evolution

### [FUTURE-008] Arena-Based Linked Lists

**Scope**: `List` primitive storage strategy to support `~Copyable` elements.

**Status**: Design complete. Implementation blocked on List refactoring.

Traditional linked list implementations use class-based nodes:

```swift
class Node<Element> {
    var element: Element
    var next: Node?
}
```

Classes in Swift require their generic parameters to be `Copyable`. There is no `class Node<Element: ~Copyable>`. This is a fundamental language constraint—classes are reference types with shared ownership, incompatible with move-only semantics.

#### The Arena Solution

Replace pointer-based linking with index-based linking into a contiguous buffer:

```swift
struct Node {
    var element: Element
    var prevIndex: Int  // -1 for none
    var nextIndex: Int  // -1 for none
}

// Storage is ManagedBuffer<Header, Node>
```

Now the element is stored in a struct (which can have `~Copyable` generic parameters), and the linking is via indices into the buffer rather than pointers to heap objects.

#### Trade-offs

| Category | Arena-Based | Class-Based |
|----------|-------------|-------------|
| `~Copyable` support | Full | None |
| Memory layout | Cache-friendly (contiguous) | Scattered heap allocations |
| Variant support | Bounded, Inline, Small | Only heap-allocated |
| Insertion/deletion | Complex (free list management) | Simple (pointer swap) |
| Capacity management | Must pre-allocate or resize | Grows one node at a time |

The trade-off is clearly favorable for a primitives library targeting modern use cases. The arena approach aligns with [API-DESIGN-009] Structural Parity, enabling `List.Bounded`, `List.Inline`, and `List.Small` variants.

**Blocking factors**: List refactoring must be completed first. The arena storage design is documented in `List-Refactoring-Brief.md`.

**Next steps**:

1. Complete List refactoring per `List-Refactoring-Brief.md`
2. Implement arena-based storage with free list management
3. Add `Bounded`, `Inline`, and `Small` variants
4. Validate `~Copyable` element support across all variants

**Cross-references**: [API-DESIGN-009], [MEM-COPY-001], <doc:_Reflections>

---

## Topics

### Reference

- <doc:Package-Inventory>
- <doc:Layer-Flowchart>
- <doc:Glossary>