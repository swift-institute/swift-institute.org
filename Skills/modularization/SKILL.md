---
name: modularization
description: |
  Intra-package modularization: target decomposition, dependency structure, constraint isolation.
  Consumer import precision: primary vs supplementary decomposition, umbrella vs variant imports.
  Cross-package integration: SE-0450 trait-gated targets for optional inter-package conformances.
  Apply when organizing multiple targets within a SwiftPM package, auditing package structure,
  or determining which module to import from a multi-product package.

layer: implementation

requires:
  - swift-institute
  - code-surface
  - implementation

applies_to:
  - swift
  - swift6
  - primitives
last_reviewed: 2026-04-10
---

# Modularization

> How modules relate to each other within a package.

The **implementation** skill governs how code reads within a module; the **modularization** skill governs how modules compose within a package.

---

## Foundational Principle

### [MOD-DOMAIN] Factor the Law, Not the Module

**Statement**: A new target MUST represent a coherent semantic domain. Targets MUST NOT be created for shared code, convenience, or "helpers". The question at every decomposition is: "Is this a concept, or just code?"

This is the governing principle. Every MOD-* rule is a corollary.

**Rationale**: Parnas (1972) proved that the information-hiding decomposition — where each module hides one design decision — produces fundamentally better properties than processing-step partitioning. The ecosystem's Primitives Layering.md formalizes this as "Factor the Law, Not the Module."

**Cross-references**: [API-LAYER-001], Primitives Layering.md § "Factor the Law, Not the Module"

---

## Structural Requirements

### [MOD-001] Core Layer

**Statement**: Every multi-product package MUST have a `{Domain} Primitives Core` target containing namespace enums, foundational protocols, and minimal type definitions.

Core properties:
- Core is an **internal target only** — it MUST NOT be published as a library product. Only the umbrella and variant targets are products.
- Core re-exports external dependencies via `@_exported public import` in `exports.swift`
- Every other target in the package depends on Core (directly or transitively)
- Core holds the namespace enum and foundational protocol(s)

**Correct** (Package.swift):
```swift
// Core target: namespace + foundational protocol
.target(name: "Parser Primitives Core",
    dependencies: [
        .product(name: "Input Primitives", package: "swift-input-primitives"),
        .product(name: "Array Primitives", package: "swift-array-primitives"),
    ]),
```

**Incorrect**:
```swift
// ❌ No Core — each target imports external deps independently
.target(name: "Parser Map Primitives",
    dependencies: [
        .product(name: "Input Primitives", package: "swift-input-primitives"),  // ❌ Duplicated
    ]),
.target(name: "Parser Filter Primitives",
    dependencies: [
        .product(name: "Input Primitives", package: "swift-input-primitives"),  // ❌ Duplicated
    ]),
```

**Rationale**: Core acts as the dependency funnel. External package changes affect one target, not N. Martin's metrics confirm Core achieves I=0.0 (maximally stable), high fan-in (~34), low fan-out — the ideal stable foundation per Henry-Kafura.

**Cross-references**: [MOD-002], [MOD-005]

---

### [MOD-002] External Dependency Centralization

**Statement**: Only Core SHOULD depend on external packages. Variant targets SHOULD reach external types through Core's re-exports.

**Exception**: Variant targets MAY directly depend on external packages when they need protocol conformances that cannot be provided transitively (e.g., buffer variants depending on Sequence/Collection Primitives for conformance).

**Correct**:
```swift
// Core re-exports externals
// exports.swift in Parser Primitives Core
@_exported public import Input_Primitives
@_exported public import Array_Primitives

// Variant depends only on Core
.target(name: "Parser Map Primitives",
    dependencies: ["Parser Primitives Core"]),
```

**Incorrect**:
```swift
// ❌ Every variant duplicates external dependency declarations
.target(name: "Parser Map Primitives",
    dependencies: [
        "Parser Primitives Core",
        .product(name: "Input Primitives", package: "swift-input-primitives"),  // ❌
    ]),
```

**Rationale**: Centralizing external dependencies means upgrading an external package affects one `dependencies:` declaration, not N. This is the Parnas information-hiding criterion applied to dependency management.

**Cross-references**: [MOD-001]

---

### [MOD-003] Variant Decomposition

**Statement**: Domain-specific implementations MUST be isolated into separate targets along a single decomposition axis. Variants MUST be independent of each other (no inter-variant dependencies) unless a documented delegation relationship exists.

Decomposition axis names a single conceptual dimension: strategy, operation, behavior, representation.

**Correct** (buffer-primitives along "storage strategy" axis):
```swift
// Each variant depends on Core + only genuine siblings
.target(name: "Buffer Ring Primitives",
    dependencies: ["Buffer Primitives Core"]),
.target(name: "Buffer Linear Primitives",
    dependencies: ["Buffer Primitives Core"]),
.target(name: "Buffer Slab Primitives",
    dependencies: ["Buffer Primitives Core"]),
```

**Incorrect**:
```swift
// ❌ Inter-variant dependency without delegation justification
.target(name: "Buffer Ring Primitives",
    dependencies: ["Buffer Primitives Core", "Buffer Linear Primitives"]),  // ❌ Ring→Linear
```

**Rationale**: Variant independence enables selective import — a consumer needing only `Buffer_Ring_Primitives` pays no compile-time cost for Linear's algorithms. Parnas: each variant hides one design decision (its strategy). Baldwin-Clark: independent variants maximize option value.

**Cross-references**: [MOD-006], [MOD-008]

---

### [MOD-004] Constraint Isolation

**Statement**: When a package supports `Element: ~Copyable`, Core MUST NOT carry protocol conformances that impose `Copyable` constraints. Conformances to `Swift.Sequence`, `Swift.Collection`, `Collection.Protocol`, `Sequence.Protocol`, or `Sequence.Drain.Protocol` MUST be declared in variant targets, not Core.

What Core retains (with `Element: ~Copyable`):
- Type definitions
- Direct subscript access (index-based, no iteration)
- Span-based access (borrowed, no copy)
- Mutating operations (append, push, enqueue, insert, remove)
- Count, capacity, isEmpty
- Deinit

What Core excludes:
- `Swift.Sequence` / `Swift.Collection` conformances
- Custom `Sequence.Protocol` / `Collection.Protocol` conformances
- `Sequence.Drain.Protocol` conformances
- Any API whose signature requires `Element: Copyable`

**Correct** (Package.swift structure):
```swift
// Core: types with Element: ~Copyable, NO collection conformances
.target(name: "Array Primitives Core",
    dependencies: [/* external deps */]),

// Variant: adds conformances, forces Element: Copyable in scope
.target(name: "Array Dynamic Primitives",
    dependencies: [
        "Array Primitives Core",
        .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
        .product(name: "Collection Primitives", package: "swift-collection-primitives"),
    ]),
```

**Incorrect**:
```swift
// ❌ Core conforms to Collection → poisons Element: ~Copyable
.target(name: "Array Primitives Core",
    dependencies: [
        .product(name: "Collection Primitives", package: "swift-collection-primitives"),  // ❌
    ]),
// All code using Array<FileHandle> where FileHandle: ~Copyable now fails
```

**Rationale**: This is the strongest theoretical result from the literature study. Walker (2005) proves substructural constraints compose conjunctively — if `S` conforms to `Collection` with `Element: Copyable`, the constraint propagates to all uses. Module separation leverages the scope-limiting property of existential types (Mitchell-Plotkin 1988): the constraint is existentially quantified within its module and only propagates when imported. **Constraint isolation is type-theoretically necessary, not merely pragmatic** (SE-0427 context). This pattern is the dominant modularization driver for the entire data structure stack (storage → buffer → array/stack/queue/slab/set/dictionary).

**Cross-references**: [MEM-COPY-001–006], [MOD-001], SE-0427

---

### [MOD-005] Umbrella Re-export

**Statement**: Every multi-product package MUST have an umbrella target whose sole content is `@_exported public import` statements in `exports.swift` — zero implementation code.

The umbrella product name MUST match `{Domain} Primitives`. The umbrella target MUST depend on ALL sub-targets.

**Correct**:
```swift
// exports.swift — complete file, zero implementation
@_exported public import Parser_Primitives_Core
@_exported public import Parser_Error_Primitives
@_exported public import Parser_Match_Primitives
@_exported public import Parser_Map_Primitives
// ... all remaining targets

// Package.swift
.target(name: "Parser Primitives",
    dependencies: [
        "Parser Primitives Core",
        "Parser Error Primitives",
        "Parser Match Primitives",
        "Parser Map Primitives",
        // ... all targets
    ]),
```

**Incorrect**:
```swift
// ❌ Umbrella contains implementation code
// Parser Primitives/ParserHelpers.swift
func defaultConfiguration() -> Config { ... }  // ❌ Implementation in umbrella
```

**Rationale**: The umbrella enables convenience without sacrificing granularity. Haskell's `module Foo (module Bar)` re-export and OCaml's Core library demonstrate this is a well-established cross-ecosystem pattern. The umbrella's role to consumers depends on the decomposition type — see [MOD-015].

**Cross-references**: [MOD-012], [MOD-015]

---

### [MOD-016] @_spi Per-File Opt-In

**Statement**: `@_spi` visibility is per-file. An `@_spi(Syscall) @_exported public import` in `exports.swift` re-exports the SPI surface to *downstream modules* that import the target with `@_spi(Syscall)`. It does NOT grant SPI access to sibling `.swift` files within the same target. Each implementation file MUST independently declare its own `@_spi` import.

**Correct** (every file that touches SPI members opts in):
```swift
// exports.swift — re-exports SPI to downstream modules
@_spi(Syscall) @_exported public import Kernel_Descriptor_Primitives

// IO.Read.swift — same target, still needs its own @_spi import
@_spi(Syscall) import Kernel_Descriptor_Primitives

// File.Open.swift — same target, still needs its own @_spi import
@_spi(Syscall) import Kernel_Descriptor_Primitives
```

**Incorrect**:
```swift
// ❌ Assuming exports.swift's @_spi import propagates to siblings
// exports.swift
@_spi(Syscall) @_exported public import Kernel_Descriptor_Primitives

// IO.Read.swift — no @_spi import, expects to inherit from exports.swift
let fd = descriptor._rawValue  // ❌ Compile error: _rawValue is not accessible
```

**Rationale**: Each `.swift` file is an independent compilation unit for SPI purposes. The per-file ceremony ensures every file that reaches into SPI members explicitly declares that intent, making the SPI boundary auditable (`grep @_spi(Syscall)` identifies all boundary code). The 81-file burden in iso-9945 is proportional to the risk and documents the exact blast radius.

**Provenance**: `swift-kernel-primitives/Research/spi-and-path-cleanup.md`, 2026-04-10.

**Cross-references**: [MOD-002], [MOD-005]

---

## Dependency Requirements

### [MOD-006] Dependency Minimization

**Statement**: Each target MUST declare exactly the dependencies it needs — no convenience imports, no "pull in everything" shortcuts. A target MUST NOT depend on another target unless it uses types or protocols from that target.

**Benchmark**: parser-primitives achieves mean 1.2 sibling dependencies per target across 34 non-umbrella targets.

**Correct**:
```swift
// Parser Optional depends only on Core (needs nothing else)
.target(name: "Parser Optional Primitives",
    dependencies: ["Parser Primitives Core"]),

// Parser Take depends on Core + 5 siblings it genuinely delegates to
.target(name: "Parser Take Primitives",
    dependencies: [
        "Parser Primitives Core",
        "Parser Error Primitives",
        "Parser Skip Primitives",
        "Parser Conditional Primitives",
        "Parser Optional Primitives",
        "Parser Always Primitives",
    ]),
```

**Incorrect**:
```swift
// ❌ Depends on umbrella instead of specific targets
.target(name: "Parser Optional Primitives",
    dependencies: ["Parser Primitives"]),  // ❌ Pulls in everything
```

**Rationale**: Minimal dependencies keep incremental compile times proportional to the change. Stevens-Myers-Constantine coupling density at ~7% is exceptionally low and near-optimal for balancing connectivity with independence. Adding a feature to Parser Error Primitives recompiles only the ~12 targets that depend on it, not all 34.

For cross-package import precision (which product to import from another package), see [MOD-015].

**Cross-references**: [MOD-007], [MOD-003], [MOD-015]

---

### [MOD-007] Dependency Graph Shape

**Statement**: The intra-package dependency graph SHOULD be a wide, shallow DAG rooted at Core. Maximum depth (longest path from Core to a leaf) SHOULD NOT exceed 3.

**Measured exemplars**:

| Package | Max Depth | Shape |
|---------|-----------|-------|
| parser | 3 (Core → Take → Many) | Wide fan, one 3-deep chain |
| buffer | 3 (Core → Linear → Linear Inline → Linear Small) | Wide fan, per-variant 2-3 depth |
| memory | 2 (Core → StdLib Integration → Arena/Pool) | Flat star |

**Rationale**: Brent's theorem: given DAG with work W and span S, execution time on P processors is bounded by T_P >= max(W/P, S). With depth 3 and 35 targets: max parallelism = 35/3 ~ 11.7x. Contrast: a deeper DAG (depth 10) would yield only 3.5x — shallow DAGs are disproportionately better. The wide shallow shape is near-optimal for build parallelism (Mokhov et al. 2018, Amdahl's law: sequential fraction = 3/35 ~ 8.6%).

**Cross-references**: [MOD-001], [MOD-003]

---

## Consumer Import Requirements

### [MOD-015] Consumer Import Precision

**Statement**: Consumer packages MUST import the narrowest module that provides the types they need. The correct import depends on the provider package's decomposition type.

**Primary decomposition** — variants are independently useful modules along a clear axis (strategy, operation, algorithm). Core is scaffolding; the variants are the product.

- Consumers MUST import specific variant modules, never the umbrella
- Package.swift MUST declare dependencies on specific variant products, not the umbrella product

**Supplementary decomposition** — Core contains the main API surface (the protocols, the foundational types). Variants add minor opt-in features (one additional algorithm, stdlib extensions, one alternate representation).

- The umbrella IS the canonical consumer import
- Importing the umbrella is correct even though variants exist

**Distinguishing test**: Could Core stand alone as a complete, useful package? If yes — the variants are supplementary and the umbrella is canonical. If Core is just namespace scaffolding for the variants — the decomposition is primary and consumers must be selective.

**Classification** (L1 primitives):

| Decomposition | Packages | Consumer import |
|---------------|----------|----------------|
| Primary | array, ascii-parser, ascii-serializer, async, binary, binary-parser, bit-vector, buffer, graph, heap, kernel, list, machine, memory, numeric, parser, parser-machine, pool, serializer, slab, storage, test, time, tree | Specific variants |
| Supplementary | sequence, affine, queue, algebra, hash-table, bit, cardinal, ordinal, index, identity, finite, dimension, geometry, set, rendering, cyclic, cyclic-index, input, link, source, text, token, vector, range, sample, lexer, algebra-affine, algebra-cardinal, algebra-modular, bit-index, bit-pack | Umbrella |

**Correct** (primary decomposition — consumer imports specific variant):
```swift
// Consumer needs ring buffer specifically
import Buffer_Ring_Primitives

// Consumer needs DFS traversal specifically
import Graph_DFS_Primitives

// Package.swift
.product(name: "Buffer Ring Primitives", package: "swift-buffer-primitives"),
.product(name: "Graph DFS Primitives", package: "swift-graph-primitives"),
```

**Incorrect** (primary decomposition — umbrella pulls in everything):
```swift
// ❌ Pulls in Ring, Linear, Slab, Linked, Slots, Arena — only needs Ring
import Buffer_Primitives

// ❌ Pulls in all 16 graph algorithms — only needs DFS
import Graph_Primitives
```

**Correct** (supplementary decomposition — umbrella is canonical):
```swift
// Sequence protocols are the main product — umbrella is canonical
import Sequence_Primitives

// Cardinal arithmetic is the main product — umbrella is canonical
import Cardinal_Primitives
```

**Incorrect** (supplementary decomposition — Core is not consumer-facing):
```swift
// ❌ Core is an implementation detail, not a consumer-facing product
import Sequence_Primitives_Core
```

**Rationale**: Primary decomposition packages can have 10–35 variant modules. Importing the umbrella defeats the modularization investment — consumers pay compile-time cost for every variant and lose the signal of which specific capabilities they depend on. Supplementary decomposition packages have 1–2 minor additions atop a complete Core; the umbrella adds negligible overhead and is the natural consumer interface.

**Provenance**: Import precision audit, 2026-04-03 (`swift-primitives/Research/audit.md`).

**Cross-references**: [MOD-005], [MOD-006], [MOD-003]

---

### [MOD-015a] Narrow-Imports Exception for Shadow Disambiguation

**Statement**: `public import X` in a narrow product `Y` makes X's *types* visible to Y's consumers but does NOT promote Y to "declares X" status for the purpose of module-qualification. When a consumer needs `Module.Namespace` syntax to disambiguate a shadowed name (e.g., the primitives `Executor` namespace shadowed by stdlib's `_Concurrency.Executor` in a type that conforms to `SerialExecutor`), the consumer MUST import a module that *declares* the namespace — typically the umbrella product — not a narrow product that merely re-exports it.

**Structural reason**: Swift module qualification is about declaration, not visibility. `Module.TypeName` resolves only when `Module` is the module that actually declares `TypeName`. `public import X` in module Y makes X's types visible through Y but Y is a conduit, not a declaring owner. Consumers writing `Y.TypeName` will fail to resolve; they must write `X.TypeName`.

**Correct** (umbrella for shadow disambiguation):
```swift
// In a type that conforms to SerialExecutor (brings _Concurrency.Executor in scope):
import Executor_Primitives           // umbrella — declares Executor namespace via Core

let queue: Executor_Primitives.Executor.Job.Queue = ...   // disambiguates from _Concurrency.Executor
```

**Incorrect** (narrow product cannot be qualified):
```swift
import Executor_Job_Queue_Primitives    // narrow — re-exports Executor via public import of Core

let queue: Executor_Job_Queue_Primitives.Executor.Job.Queue = ...
// ❌ Does not resolve: Executor is declared in Executor Primitives Core, not in this module
```

**Decision procedure for consumers**:

| Situation | Import |
|-----------|--------|
| No name shadow, no need for module-qualified syntax | Narrow variant product per [MOD-015] |
| Name shadow exists AND disambiguation needs `Module.Namespace` prefix | Umbrella product (or whichever product's module declares the namespace) |
| Types live in a shared Core target that is NOT itself a product | Umbrella product (Core is not importable; umbrella re-exports Core and can be qualified as a proxy because its target has `@_exported public import` of Core) |

**Why this is not a [MOD-015] violation**: [MOD-015] prohibits umbrella imports to avoid paying compile-time cost for unused variants. Shadow disambiguation is a distinct need — the consumer needs a module *identity* for qualification, not broader visibility. When the shadow is real and narrow-import qualification fails structurally, the umbrella is the smallest import that resolves the disambiguation; this is the case the narrow-imports rule does not cover.

**Alternative (rejected)**: making Core a product. Making Core publishable would fix the qualification path but defeats the Core-is-internal invariant per [MOD-001]. The umbrella pathway preserves Core's internal role while giving consumers a declared-module anchor.

**Rationale**: The narrow-imports preference is correct in the common case and reduces compile-time coupling. The shadow-disambiguation case is an exception, not a violation — the same reasoning that makes narrow imports preferable does not account for the structural difference between visibility and declaration in Swift's module system. Codifying this exception prevents consumers from fighting the compiler when stdlib-conforming types bring stdlib namespaces into scope.

**Provenance**: Reflection `2026-04-15-completion-loop-proactor-reactor-boundary.md`.

**Cross-references**: [MOD-001], [MOD-005], [MOD-006], [MOD-015]

---

## Decision Guides

### [MOD-008] Split Decision Criteria

**Statement**: When deciding whether a concern gets its own target, apply these criteria.

A concern SHOULD be a separate target when any of:
1. **Different dependency set** — It needs fewer (or different) dependencies than its siblings
2. **Independent consumer value** — A downstream package would import this target alone
3. **Depended-on by siblings** — Other targets in the package need it (creating a shared core within the variant layer)
4. **Semantic independence** — It answers one specific question about the domain

A concern SHOULD NOT be a separate target when:
1. It always co-occurs with another target (no independent consumer)
2. It would create a depth > 3 chain without justification
3. The file count is 1 and no other target depends on it specifically

**Tradeoff**: Each additional target boundary requires `@inlinable` annotations for cross-target specialization. Whole Module Optimization (WMO) is bounded by target scope — code in separate targets cannot be jointly optimized without explicit `@inlinable`. Weigh this annotation burden against the modularity benefit.

**Evidence**:

| Target | Files | Split Justification |
|--------|-------|---------------------|
| Parser Optional | 3 | Different dep set (Core only, no Error) |
| Parser Peek | 2 | Unique concern (non-consuming lookahead) |
| Parser Take | 8 | Complex, many dependents |
| Parser Many | 5 | Delegates to Take, separate concern |

**Cross-references**: [MOD-DOMAIN], Primitives Layering.md § "Semantic Coherence Test"

---

### [MOD-009] Inline Variant Satellite

**Statement**: When a variant has both heap-allocated and inline (fixed-capacity) forms, the inline variant MUST depend on the heap variant. The reverse dependency is forbidden.

Dependency direction:
```
Core → Heap Variant → Inline Variant → Composite (Small) Variant
```

**Correct**:
```swift
.target(name: "Buffer Ring Primitives",           // heap
    dependencies: ["Buffer Primitives Core"]),
.target(name: "Buffer Ring Inline Primitives",     // inline depends on heap
    dependencies: ["Buffer Primitives Core", "Buffer Ring Primitives"]),
```

**Incorrect**:
```swift
// ❌ Heap depends on inline — reversed
.target(name: "Buffer Ring Primitives",
    dependencies: ["Buffer Primitives Core", "Buffer Ring Inline Primitives"]),  // ❌
```

**Rationale**: The inline variant reuses the heap variant's type definitions and algorithms, adding only fixed-capacity storage specialization. Reversing the direction would force the heap variant (used by most consumers) to compile inline storage code it doesn't need.

**Cross-references**: [MOD-003], [MOD-012]

---

## Integration Modules

### [MOD-010] Standard Library Integration Module

**Statement**: When a package extends Swift standard library types, those extensions SHOULD be isolated in a dedicated `{Domain} Primitives Standard Library Integration` target.

**Correct**:
```swift
.target(name: "Memory Primitives Standard Library Integration",
    dependencies: ["Memory Primitives Core"]),
// Contains: extensions on UnsafePointer, UnsafeBufferPointer, etc.
```

**Incorrect**:
```swift
// ❌ Stdlib extensions mixed into Core
// Memory Primitives Core/UnsafePointer+Memory.swift
extension UnsafePointer { ... }  // ❌ In Core, not isolated
```

**Rationale**: Stdlib extensions can cause implicit member resolution conflicts if imported broadly. Isolating them lets consumers who don't need stdlib interop avoid the extensions. Only present when stdlib extensions exist (not all packages have them).

**Cross-references**: [MOD-001], [MOD-012]

---

### [MOD-014] Cross-Package Integration via Traits

**Statement**: When package A needs to provide integration with package B's types (e.g., conformances, witness values, adapters), and B is not a universal dependency of A's consumers, the integration MUST be gated behind an SE-0450 package trait.

This is **Problem 2** (cross-package optional integration). It is distinct from Problem 1 (intra-package dependency isolation, solved by Core extraction per [MOD-001]).

Structure:
1. Package A declares a trait in its `Package.swift` via the `traits:` parameter
2. Package A declares B as a package-level dependency (always resolved for development, but gated for consumers)
3. Package A adds an integration target whose dependency on B uses `condition: .when(traits: ["TraitName"])`
4. Consumers opt in by adding `traits: ["TraitName"]` to their `.package(...)` dependency declaration
5. SE-0226 target-based dependency resolution ensures consumers who don't enable the trait never resolve B

**Correct** (provider package):
```swift
let package = Package(
    name: "swift-dependencies",
    products: [
        .library(name: "Dependencies", targets: ["Dependencies"]),
        .library(name: "Clocks Dependency", targets: ["Clocks Dependency"]),
    ],
    traits: [
        .trait(name: "Clocks"),
    ],
    dependencies: [
        .package(path: "../swift-witnesses"),
        .package(path: "../../swift-primitives/swift-clock-primitives"),
    ],
    targets: [
        .target(name: "Dependencies", dependencies: [
            .product(name: "Witnesses", package: "swift-witnesses"),
        ]),
        // MARK: - Integration
        .target(name: "Clocks Dependency", dependencies: [
            "Dependencies",
            .product(name: "Clock Primitives", package: "swift-clock-primitives",
                     condition: .when(traits: ["Clocks"])),
        ]),
    ]
)
```

**Correct** (consumer package):
```swift
.package(path: "../swift-dependencies", traits: ["Clocks"]),
// ...
.product(name: "Clocks Dependency", package: "swift-dependencies"),
```

**Incorrect**:
```swift
// ❌ Nested package for integration — fails GitHub publication (SPM limitation)
.package(path: "../swift-dependencies/integration/swift-clocks-dependency"),

// ❌ Separate repository for a single integration target — unnecessary proliferation
.package(url: "https://github.com/org/swift-clocks-dependency.git", from: "1.0.0"),

// ❌ Integration dependency unconditional — all consumers pay the cost
.target(name: "Clocks Dependency", dependencies: [
    "Dependencies",
    .product(name: "Clock Primitives", package: "swift-clock-primitives"),  // ❌ No trait gate
]),
```

Decision criteria — use traits when:
- The integration target connects two otherwise-independent packages
- Not all consumers of the provider need the integration
- The alternative would be a separate repository or nested package

Do NOT use traits for:
- Intra-package Core extraction (use [MOD-001] instead)
- Dependencies that all consumers need (just declare them normally)

**Rationale**: SE-0450 package traits (Swift 6.1+) solve the cross-package integration problem without repository proliferation, nested package limitations, or unconditional dependency resolution. The consumer opts in explicitly, and SE-0226 ensures unused integration targets don't pull in their dependencies. Validated with swift-dependencies clock integration (research: `cross-package-integration-strategies.md`).

**Cross-references**: [MOD-001], [MOD-002], SE-0450, SE-0226, `cross-package-integration-strategies.md`

---

### [MOD-011] Test Support Product

**Statement**: Every multi-product package MUST publish a `{Domain} Primitives Test Support` library product containing test fixtures, convenience initializers, and re-exports.

Properties:
- Published as a library product (visible to downstream packages)
- Depends on the umbrella (full API access for test helpers)
- Depends on upstream packages' test support products
- Located at `Tests/Support/` path
- Re-exports upstream test fixtures via `@_exported public import`

**Correct**:
```swift
.library(name: "Parser Primitives Test Support",
    targets: ["Parser Primitives Test Support"]),
// ...
.target(name: "Parser Primitives Test Support",
    dependencies: [
        "Parser Primitives",                    // umbrella
        .product(name: "Input Primitives Test Support",
                 package: "swift-input-primitives"),
    ],
    path: "Tests/Support"),
```

**Rationale**: Downstream packages need test fixtures for types from upstream. Publishing test support as a product creates a parallel dependency graph for testing infrastructure.

**Cross-references**: [TEST-001]

---

## Naming and Readability

### [MOD-012] Target Naming Convention

**Statement**: Multi-product target names MUST follow this scheme:

| Role | Pattern | Import Form |
|------|---------|-------------|
| Core | `{Domain} Primitives Core` | `{Domain}_Primitives_Core` |
| Variant | `{Domain} {Variant} Primitives` | `{Domain}_{Variant}_Primitives` |
| Inline satellite | `{Domain} {Variant} Inline Primitives` | `{Domain}_{Variant}_Inline_Primitives` |
| Composite satellite | `{Domain} {Variant} Small Primitives` | `{Domain}_{Variant}_Small_Primitives` |
| StdLib integration | `{Domain} Primitives Standard Library Integration` | `{Domain}_Primitives_Standard_Library_Integration` |
| Umbrella | `{Domain} Primitives` | `{Domain}_Primitives` |
| Test support | `{Domain} Primitives Test Support` | `{Domain}_Primitives_Test_Support` |

**Layer adaptation**: The table above uses L1 (Primitives) naming. Higher layers drop the layer-identifying word:

| Layer | Core | Variant | Umbrella |
|-------|------|---------|----------|
| L1 Primitives | `{Domain} Primitives Core` | `{Domain} {Variant} Primitives` | `{Domain} Primitives` |
| L2 Standards | `{Domain} Core` | `{Domain} {Variant}` | `{Domain}` |
| L3 Foundations | `{Domain} Core` | `{Domain} {Variant}` | `{Domain}` |

**Example**: L1 `IO Primitives Core` → L3 `IO Core`. L1 `IO Blocking Primitives` → L3 `IO Blocking`.

**Rationale**: Consistent naming enables predictable discovery. Module names use spaces in Package.swift and underscores in import statements per primitives convention. The "Primitives" suffix is layer-identifying and inappropriate at higher layers where packages compose rather than provide atomic building blocks.

**Provenance**: Reflection `2026-03-24-swift-io-audit-consolidation.md`.

**Cross-references**: [API-NAME-001], [PRIM-NAME-001], [ARCH-LAYER-001]

---

### [MOD-013] Semantic Group Markers

**Statement**: Package.swift files with 5+ targets SHOULD use `// MARK: -` comments to organize targets into semantic groups matching the decomposition axis.

**Correct**:
```swift
// MARK: - Core
.target(name: "Parser Primitives Core", ...),

// MARK: - Error & Match
.target(name: "Parser Error Primitives", ...),
.target(name: "Parser Match Primitives", ...),

// MARK: - Combinators
.target(name: "Parser Map Primitives", ...),
.target(name: "Parser FlatMap Primitives", ...),
// ...

// MARK: - Umbrella
.target(name: "Parser Primitives", ...),

// MARK: - Tests
.testTarget(name: "ParserPrimitivesTests", ...),
```

**Rationale**: Semantic grouping in Package.swift makes the decomposition axis legible to maintainers. The groups correspond to the variant decomposition axis.

**Cross-references**: [MOD-003]

---

## Audit Metrics

| Metric | Source | Threshold | What It Reveals |
|--------|--------|-----------|-----------------|
| Product tier spread | `compute-tiers.sh` | >= 3 is a concern | Bundled concerns at different abstraction levels — extraction candidates |
| Mean sibling dependencies | Package.swift analysis | <= 2.0 | Lower is better; parser-primitives achieves 1.2 |
| Max dependency depth | Package.swift analysis | <= 3 | Deeper chains reduce build parallelism |
| Semantic domain count | Manual analysis per Primitives Layering.md | 1 per package | Multiple domains → split needed |

**Audit invocation**: "Audit {package} against /modularization" checks each MOD-* requirement against the package's Package.swift and source layout, producing a compliance table per [RES-015].

---

## Accepted Deviations

### [MOD-EXCEPT-001] Platform Packages

**Statement**: Platform-abstraction packages at Layer 1 and Layer 3 are exempt from MOD-001 (Core), MOD-005 (Umbrella), and MOD-011 (Test Support). These packages use a peer-products pattern where each target independently wraps a platform subsystem (kernel, loader, system/memory).

**Affected packages**:
- L1: `swift-darwin-primitives`, `swift-linux-primitives`, `swift-windows-primitives`
- L3: `swift-darwin`, `swift-linux`, `swift-windows`

**Rationale**: These packages have 1-8 files per target. The overhead of Core + umbrella exceeds the benefit. Each target wraps a different OS subsystem with no shared types between them — a Core would be empty or contain only re-exports with no added semantic value.

**Established**: 2026-03-20 (ecosystem-wide modularization audit)

### [MOD-EXCEPT-002] Placeholder/Stub Packages

**Statement**: Packages with zero-byte source files that serve as architectural placeholders are exempt from MOD-006 (Dependency Minimization) and MOD-011 (Test Support). Their declared dependencies serve as a design intent record.

**Affected packages** (L3 compiler toolchain family): `swift-abstract-syntax-tree`, `swift-backend`, `swift-compiler`, `swift-diagnostic`, `swift-driver`, `swift-intermediate-representation`, `swift-lexer`, `swift-module`, `swift-symbol`, `swift-syntax`, `swift-type`

**Rationale**: These packages exist to reserve namespace and document intended dependency structure for a future compiler toolchain. Removing their dependencies would destroy design intent. Creating Test Support for empty packages is meaningless.

**Established**: 2026-03-20 (ecosystem-wide modularization audit)
