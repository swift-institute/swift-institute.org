# Package Inventory

@Metadata {
    @TitleHeading("Swift Institute")
}

Complete reference inventory of all 66 packages in the swift-primitives ecosystem, organized by dependency tier.

## Overview

**Scope**: This document catalogs all packages in the swift-primitives ecosystem. It serves as a reference for package discovery and dependency planning.

**Does not apply to**: Application-level packages (coenttb-*), swift-standards packages, or third-party dependencies.

---

## Tier Structure

Packages are organized into tiers based on dependency relationships. Lower-tier packages have no dependencies on higher tiers. This enables:

- **Incremental adoption**: Import only the tiers you need
- **Build isolation**: Changes in higher tiers do not affect lower tiers
- **Dependency predictability**: Each tier's dependencies are bounded

| Tier | Name | Package Count | Description |
|------|------|---------------|-------------|
| 0 | Atomic | 8 | Zero-dependency primitives |
| 1 | Foundation | 7 | Core abstractions |
| 2 | Memory & Storage | 4 | Memory management |
| 3 | Binary & Numeric | 6 | Numeric representations |
| 4 | Dimensional | 6 | Units and dimensions |
| 5 | Linear Algebra | 2 | Vector and matrix operations |
| 6 | Geometry | 4 | Spatial primitives |
| 7 | System | 5 | OS-level abstractions |
| 8 | Platform | 7 | Platform-specific bindings |
| 9 | Infrastructure | 17 | Compiler and tooling support |

---

## Tier 0: Atomic

**Scope**: Zero-dependency packages that form the foundation of all other primitives.

**Characteristics**: No imports from other swift-primitives packages. Suitable for the most constrained environments.

### swift-standard-library-extensions

Extensions to Swift standard library types. Provides ergonomic additions without introducing new abstractions.

### swift-parser-primitives

Fundamental parsing abstractions. Defines parse/print invertibility contracts and basic combinators.

### swift-positioning-primitives

Position and range types for text and binary data. Foundation for source location tracking.

### swift-facet-primitives

Borrowing behavioral views. Provides phantom-typed facets for namespaced operation algebras over borrowed base values.

### swift-identity-primitives

Identity and handle types. Provides opaque identifiers with strong typing.

### swift-test-primitives

Testing infrastructure primitives. Deterministic test helpers without external dependencies.

### swift-stack-primitives

Stack data structure. Last-in-first-out (LIFO) collection with push/pop operations.

### swift-list-primitives

Linked list data structure. Sequential access collection with efficient insertion and removal.

---

## Tier 1: Foundation

**Scope**: Core abstractions that most packages will depend upon.

**Dependencies**: Tier 0 only.

### swift-formatting-primitives

Formatting abstractions for output generation. Defines format/parse duality patterns.

### swift-ternary-logic-primitives

Three-valued logic types. Supports true/false/unknown semantics for partial evaluation.

### swift-locale-primitives

Locale-independent primitives. Language and region identifiers without Foundation dependency.

### swift-async-primitives

Async coordination primitives. Locks, signals, and synchronization without runtime coupling.

### swift-pool-primitives

Resource pooling abstractions. Generic pool contracts for handle-based access patterns.

### swift-container-primitives

Container type abstractions. Defines collection contracts beyond standard library.

### swift-queue-primitives

Queue data structure. First-in-first-out (FIFO) collection with enqueue/dequeue operations.

---

## Tier 2: Memory & Storage

**Scope**: Memory management and storage abstractions.

**Dependencies**: Tiers 0-1.

### swift-memory-primitives

Memory region and allocation primitives. Low-level memory contracts for embedded use.

### swift-buffer-primitives

Buffer types for I/O operations. Defines read/write buffer contracts.

### swift-storage-primitives

Storage abstractions for persistence. Key-value and blob storage contracts.

### swift-tree-primitives

Tree data structures. Hierarchical collections including binary trees and traversal algorithms.

### swift-pointer-primitives

Low-level pointer abstractions. Safe pointer types with lifetime tracking and ownership semantics.

### swift-reference-primitives

Non-owning reference types. Weak and unowned references for relationship modeling without ownership.

**Types**:
- `Reference.Weak<T>` - Zeroing weak reference
- `Reference.Unowned<T>` - Unsafe unowned reference
- `Reference.Sendability.*` - Sendability escape hatches

### swift-ownership-primitives

Ownership primitives for value management. Types that own values with distinct ownership contracts.

**Types**:
- `Ownership.Unique<T>` - Exclusive ownership (move-only)
- `Ownership.Shared<T>` - Shared immutable ownership via ARC
- `Ownership.Mutable<T>` - Shared mutable ownership via ARC
- `Ownership.Slot<T>` - Atomic reusable ownership slot
- `Ownership.Transfer.*` - One-shot ownership transfer mechanisms

---

## Tier 3: Binary & Numeric

**Scope**: Binary data representation and numeric types.

**Dependencies**: Tiers 0-2.

### swift-bit-primitives

Bit-level operations. Bit fields, flags, and binary manipulation.

### swift-endian-primitives

Endianness handling. Big-endian and little-endian conversion primitives.

### swift-binary-primitives

Binary data types. Byte sequences with encoding awareness.

### swift-numeric-primitives

Extended numeric protocols. Numeric abstractions beyond standard library.

### swift-decimal-primitives

Decimal number types. Fixed-point and arbitrary-precision decimals.

### swift-complex-primitives

Complex number types. Real and imaginary component representations.

---

## Tier 4: Dimensional

**Scope**: Dimensional analysis and unit types.

**Dependencies**: Tiers 0-3.

### swift-dimension-primitives

Dimensional quantity types. Type-safe units with compile-time dimension checking.

### swift-algebra-primitives

Algebraic structure protocols. Groups, rings, and fields as protocol hierarchies.

### swift-time-primitives

Time representation primitives. Durations and instants without Foundation Date.

### swift-clock-primitives

Clock abstractions. Monotonic and wall-clock time sources.

### swift-region-primitives

Geographic region primitives. Region identifiers and containment.

### swift-serialization-primitives

Serialization contracts. Encode/decode protocol pairs for various formats.

---

## Tier 5: Linear Algebra

**Scope**: Vector and matrix operations.

**Dependencies**: Tiers 0-4.

### swift-algebra-linear-primitives

Linear algebra primitives. Vectors, matrices, and linear transformations.

### swift-affine-primitives

Affine transformation types. Translation, rotation, and scaling operations.

---

## Tier 6: Geometry

**Scope**: Spatial and geometric primitives.

**Dependencies**: Tiers 0-5.

### swift-geometry-primitives

Core geometry types. Points, lines, and basic shapes.

### swift-symmetry-primitives

Symmetry operations. Reflection, rotation groups, and tessellation.

### swift-layout-primitives

Layout computation types. Constraint-based positioning primitives.

### swift-space-primitives

Coordinate space types. Type-safe coordinate system transformations.

---

## Tier 7: System

**Scope**: Operating system abstractions.

**Dependencies**: Tiers 0-6.

### swift-cpu-primitives

CPU feature detection. Architecture-specific capability queries.

### swift-system-primitives

System call abstractions. Portable syscall interface contracts.

### swift-kernel-primitives

Kernel interaction types. Process, thread, and signal primitives.

### swift-loader-primitives

Dynamic loading primitives. Symbol resolution and library loading.

### swift-driver-primitives

Device driver interfaces. Hardware abstraction layer contracts.

---

## Tier 8: Platform

**Scope**: Platform-specific implementations.

**Dependencies**: Tiers 0-7.

### swift-darwin-primitives

Darwin/macOS/iOS primitives. Apple platform-specific bindings.

### swift-linux-primitives

Linux primitives. Linux-specific system interfaces.

### swift-posix-primitives

POSIX compatibility layer. Portable Unix interface implementations.

### swift-windows-primitives

Windows primitives. Windows API bindings and abstractions.

### swift-arm-primitives

ARM architecture primitives. ARM-specific intrinsics and features.

### swift-x86-primitives

x86/x86-64 architecture primitives. Intel/AMD-specific intrinsics.

### swift-abi-primitives

ABI compatibility types. Calling conventions and binary interface contracts.

---

## Tier 9: Infrastructure

**Scope**: Compiler tooling and language infrastructure.

**Dependencies**: Tiers 0-8.

### swift-lexer-primitives

Lexical analysis primitives. Token stream generation contracts.

### swift-token-primitives

Token types. Lexeme representation and classification.

### swift-symbol-primitives

Symbol table primitives. Name binding and scope resolution.

### swift-syntax-primitives

Syntax representation types. Parse tree node abstractions.

### swift-source-primitives

Source file handling. File loading and source location tracking.

### swift-abstract-syntax-tree-primitives

Abstract syntax tree types. Language-agnostic AST node contracts.

### swift-backend-primitives

Compiler backend interfaces. Code generation target abstractions.

### swift-intermediate-representation-primitives

Intermediate representation types. IR node and instruction primitives.

### swift-module-primitives

Module system primitives. Import/export and visibility contracts.

### swift-diagnostic-primitives

Diagnostic message types. Error, warning, and note representations.

### swift-predicate-primitives

Predicate types. Boolean-valued function abstractions.

### swift-outcome-primitives

Outcome types. Result and error handling beyond standard Result.

### swift-lifetime-primitives

Lifetime tracking types. Resource lifetime and scope management.

### swift-type-primitives

Type representation primitives. Type metadata and reflection contracts.

### swift-string-primitives

String processing primitives. Unicode-aware string operations.

### swift-terminal-primitives

Terminal I/O primitives. ANSI escape sequences and terminal control.

### swift-text-primitives

Text processing types. Document and paragraph-level text handling.

---

## Key Design Documents

**Scope**: Supporting documentation providing implementation detail.

The following documents provide additional detail on specific design decisions:

| Document | Purpose |
|----------|---------|
| IMPLEMENTATION_PLAN.md | Extraction phases, dependency tiers, migration strategy |
| NAMING.md | Semiotic analysis of naming candidates, scoring framework |
| TRIGONOMETRY-DESIGN-ANALYSIS.md | Generic transcendental function design, verification criteria |

These documents are maintained in the repository root and updated as the implementation evolves.

---

## Quick Reference

### Package Count by Tier

| Tier | Count |
|------|-------|
| Tier 0: Atomic | 8 |
| Tier 1: Foundation | 7 |
| Tier 2: Memory & Storage | 4 |
| Tier 3: Binary & Numeric | 6 |
| Tier 4: Dimensional | 6 |
| Tier 5: Linear Algebra | 2 |
| Tier 6: Geometry | 4 |
| Tier 7: System | 5 |
| Tier 8: Platform | 7 |
| Tier 9: Infrastructure | 17 |
| **Total** | **66** |

### Package Identifier Index

For programmatic reference, use the bracketed identifiers (e.g., `[PKG-MEMORY]`) to locate specific package documentation.