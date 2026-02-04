# Future Directions

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

### Swift Embedded Platform Support

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

---

## Mathematical Foundations

### Complex Number Migration

**Scope**: Complex number primitives (`swift-complex-primitives`) and downstream consumers.

**Status**: In progress. Real-valued generic trigonometry is complete; complex operations are partially migrated.

While generic trigonometry is now achieved for real-valued geometry (see <doc:Mathematical-Foundations>), complex number primitives still use concrete Double/Float constraints in some operations. Future work includes migrating complex exponential and related functions to the `Numeric.Transcendental` pattern, enabling fully generic complex analysis.

**Blocking factors**: Complex transcendentals require careful handling of branch cuts and Riemann surfaces. The `cexp`, `clog`, and `cpow` functions have mathematical subtleties that require additional protocol requirements beyond `Numeric.Transcendental`.

**Next steps**:

1. Define `Complex.Transcendental` protocol extending `Numeric.Transcendental`
2. Implement branch-cut-aware complex logarithm
3. Migrate `swift-complex-primitives` to generic constraints
4. Update downstream consumers (signal processing, control theory packages)

---

## Standards Expansion

### Additional Standard Implementations

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

---

## Community and Ecosystem

### Community Adoption

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

---

## Design Evolution

### Deletion as Refinement

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

---

### Language Features for Ergonomic Type-Keyed Access

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

Swift provides none of these mechanisms. The subscript syntax `values[Key.self]` is the correct idiom—the type parameter serves as the identifier. See for detailed analysis of why alternatives fail.

**Blocking factors**: Each feature would require Swift Evolution proposals and significant compiler work. Implicit resolution particularly conflicts with Swift's philosophy of explicitness. Effect types may eventually appear in a different form (via typed throws evolution or macro-based solutions).

**Next steps**:

1. Monitor Swift Evolution for proposals related to effect systems
2. Consider macro-based solutions for dependency documentation (not resolution)
3. Continue refining subscript-based patterns for ergonomics within constraints

---

### Input Protocol Unification

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

---

## Collection Primitives Evolution

### Arena-Based Linked Lists

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

The trade-off is clearly favorable for a primitives library targeting modern use cases. The arena approach aligns with Structural Parity, enabling `List.Bounded`, `List.Inline`, and `List.Small` variants.

**Blocking factors**: List refactoring must be completed first. The arena storage design is documented in `List-Refactoring-Brief.md`.

**Next steps**:

1. Complete List refactoring per `List-Refactoring-Brief.md`
2. Implement arena-based storage with free list management
3. Add `Bounded`, `Inline`, and `Small` variants
4. Validate `~Copyable` element support across all variants

---

## BitwiseCopyable and Lifetime Inference

### The Physical/Semantic Property Distinction

**Scope**: All primitives types that are both bitwise-trivial and lifetime-bound. Affects `_read` accessor patterns, borrowing views, and pointer-holding structs.

**Status**: Blocked by Swift language evolution. Verified experimentally in `re-accessor-bitwisecopyable`.

`BitwiseCopyable` describes a physical property: a type's memory layout permits `memcpy`. Lifetime dependence describes a semantic property: a value is only valid while another value exists. These concerns are orthogonal. A `Span<T>` containing a pointer and an integer is 16 bytes that can be `memcpy`'d (physical), yet depends on the memory it references (semantic). Neither fact implies nor contradicts the other.

The current compiler conflates them. When a type is inferred as `BitwiseCopyable`, the compiler blocks lifetime inference on `_read` accessors for that type. This collapses one quadrant of a four-quadrant design space that should be fully expressible:

| | Lifetime-bound | Lifetime-independent |
|---|----------------|----------------------|
| **BitwiseCopyable** | Span, Buffer views (blocked) | Int, primitives |
| **Not BitwiseCopyable** | MutableRef | Array, String |

The top-left quadrant — types that are physically trivial but semantically lifetime-bound — is where primitives frequently operate. Lightweight accessor types that borrow from containers (`Input.Access`, `Input.Remove`, and similar) hold pointers to parent containers. These pointers are physically trivial (8 bytes, `memcpy`-able) but semantically constrained (valid only while the parent exists).

### Implicit Inference as Hidden Constraint

`BitwiseCopyable` conformance is inferred, not declared. The compiler examines a struct's stored properties, determines the type can be copied bitwise, and silently adds the conformance. This invisible conformance then triggers visible restrictions — lifetime inference is blocked, and an error demands an annotation that current syntax cannot provide.

This is an instance of a general anti-pattern: implicit inference that creates user-facing constraints. Compare with `Sendable` inference, where the compiler also infers conformance for simple structs but the inference *enables* rather than *restricts*. An inferred `Sendable` struct can be used in more contexts. An inferred `BitwiseCopyable` struct can be used in fewer lifetime-dependent contexts.

When inference creates restrictions, an opt-out mechanism is required. Swift provides `@unchecked Sendable` when the compiler's analysis is too conservative. No `~BitwiseCopyable` suppression exists. The only current workaround is structural — adding non-trivial stored properties (e.g., an unused `[Int]` member) that break inference — which pollutes the type's interface to work around a type-system limitation.

### What BitwiseCopyable Actually Provides

`BitwiseCopyable` delivers genuine optimization value:

1. **Bulk copy optimization** — `memcpy` instead of element-wise initialization
2. **Generic specialization** — Functions constrained to `BitwiseCopyable` generate tighter code
3. **ABI documentation** — Stable memory layout for FFI and serialization
4. **Unsafe code soundness** — `copyMemory` operations are provably correct

None of these benefits require blocking lifetime inference. The optimization value is orthogonal to ownership semantics. A type can be both `memcpy`-optimizable and lifetime-constrained.

### Current Workarounds

Existing primitives avoid the issue accidentally. `Input.Buffer` stores `[Element]`, which prevents `BitwiseCopyable` inference, which in turn enables lifetime inference on its accessors. This is fragile: a future optimization to inline storage could break the entire accessor pattern without any obvious connection between the changes.

**Blocking factors**: The compiler does not support `@_lifetime` annotations on `_read` accessors. It demands explicit lifetime annotation for `BitwiseCopyable` types but provides no syntax to supply it. Resolution requires one of three language changes: (1) extend `@_lifetime` annotation syntax to `_read` accessors, (2) relax the inference restriction so `BitwiseCopyable` does not block lifetime inference, or (3) introduce `~BitwiseCopyable` as an explicit opt-out parallel to `~Copyable` and `~Escapable`.

**Next steps**:

1. Monitor Swift Evolution for `~BitwiseCopyable` opt-out proposals
2. Monitor Swift Evolution for `@_lifetime` syntax extensions to accessors
3. Audit all primitives accessor types for fragile reliance on accidental non-trivial members
4. Maintain the `re-accessor-bitwisecopyable` experiment as a living test of compiler behavior across Swift versions

---

## Topics

### Reference

- <doc:Package-Inventory>
- <doc:Layer-Flowchart>
- <doc:Glossary>