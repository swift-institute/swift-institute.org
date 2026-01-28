# Package Inventory

@Metadata {
    @TitleHeading("Swift Institute")
}

Complete reference inventory of all 66 packages in the swift-primitives ecosystem, organized by dependency tier.

## Overview

**Scope**: This document catalogs all packages in the swift-primitives ecosystem. It serves as a reference for package discovery and dependency planning.

**Does not apply to**: Application-level packages (coenttb-*), swift-standards packages, or third-party dependencies.

**Cross-references**: <doc:Five-Layer-Architecture>, <doc:Implementation>

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

### [PKG-STDLIB-EXT] swift-standard-library-extensions

Extensions to Swift standard library types. Provides ergonomic additions without introducing new abstractions.

### [PKG-PARSING] swift-parser-primitives

Fundamental parsing abstractions. Defines parse/print invertibility contracts and basic combinators.

### [PKG-POSITIONING] swift-positioning-primitives

Position and range types for text and binary data. Foundation for source location tracking.

### [PKG-FACET] swift-facet-primitives

Borrowing behavioral views. Provides phantom-typed facets for namespaced operation algebras over borrowed base values.

### [PKG-IDENTITY] swift-identity-primitives

Identity and handle types. Provides opaque identifiers with strong typing.

### [PKG-TEST] swift-test-primitives

Testing infrastructure primitives. Deterministic test helpers without external dependencies.

### [PKG-STACK] swift-stack-primitives

Stack data structure. Last-in-first-out (LIFO) collection with push/pop operations.

### [PKG-LIST] swift-list-primitives

Linked list data structure. Sequential access collection with efficient insertion and removal.

---

## Tier 1: Foundation

**Scope**: Core abstractions that most packages will depend upon.

**Dependencies**: Tier 0 only.

### [PKG-FORMATTING] swift-formatting-primitives

Formatting abstractions for output generation. Defines format/parse duality patterns.

### [PKG-TERNARY] swift-ternary-logic-primitives

Three-valued logic types. Supports true/false/unknown semantics for partial evaluation.

### [PKG-LOCALE] swift-locale-primitives

Locale-independent primitives. Language and region identifiers without Foundation dependency.

### [PKG-ASYNC] swift-async-primitives

Async coordination primitives. Locks, signals, and synchronization without runtime coupling.

### [PKG-POOL] swift-pool-primitives

Resource pooling abstractions. Generic pool contracts for handle-based access patterns.

### [PKG-CONTAINER] swift-container-primitives

Container type abstractions. Defines collection contracts beyond standard library.

### [PKG-QUEUE] swift-queue-primitives

Queue data structure. First-in-first-out (FIFO) collection with enqueue/dequeue operations.

---

## Tier 2: Memory & Storage

**Scope**: Memory management and storage abstractions.

**Dependencies**: Tiers 0-1.

### [PKG-MEMORY] swift-memory-primitives

Memory region and allocation primitives. Low-level memory contracts for embedded use.

### [PKG-BUFFER] swift-buffer-primitives

Buffer types for I/O operations. Defines read/write buffer contracts.

### [PKG-STORAGE] swift-storage-primitives

Storage abstractions for persistence. Key-value and blob storage contracts.

### [PKG-TREE] swift-tree-primitives

Tree data structures. Hierarchical collections including binary trees and traversal algorithms.

### [PKG-POINTER] swift-pointer-primitives

Low-level pointer abstractions. Safe pointer types with lifetime tracking and ownership semantics.

### [PKG-REFERENCE] swift-reference-primitives

Non-owning reference types. Weak and unowned references for relationship modeling without ownership.

**Types**:
- `Reference.Weak<T>` - Zeroing weak reference
- `Reference.Unowned<T>` - Unsafe unowned reference
- `Reference.Sendability.*` - Sendability escape hatches

### [PKG-OWNERSHIP] swift-ownership-primitives

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

### [PKG-BIT] swift-bit-primitives

Bit-level operations. Bit fields, flags, and binary manipulation.

### [PKG-ENDIAN] swift-endian-primitives

Endianness handling. Big-endian and little-endian conversion primitives.

### [PKG-BINARY] swift-binary-primitives

Binary data types. Byte sequences with encoding awareness.

### [PKG-NUMERIC] swift-numeric-primitives

Extended numeric protocols. Numeric abstractions beyond standard library.

### [PKG-DECIMAL] swift-decimal-primitives

Decimal number types. Fixed-point and arbitrary-precision decimals.

### [PKG-COMPLEX] swift-complex-primitives

Complex number types. Real and imaginary component representations.

---

## Tier 4: Dimensional

**Scope**: Dimensional analysis and unit types.

**Dependencies**: Tiers 0-3.

### [PKG-DIMENSION] swift-dimension-primitives

Dimensional quantity types. Type-safe units with compile-time dimension checking.

### [PKG-ALGEBRA] swift-algebra-primitives

Algebraic structure protocols. Groups, rings, and fields as protocol hierarchies.

### [PKG-TIME] swift-time-primitives

Time representation primitives. Durations and instants without Foundation Date.

### [PKG-CLOCK] swift-clock-primitives

Clock abstractions. Monotonic and wall-clock time sources.

### [PKG-REGION] swift-region-primitives

Geographic region primitives. Region identifiers and containment.

### [PKG-SERIALIZATION] swift-serialization-primitives

Serialization contracts. Encode/decode protocol pairs for various formats.

---

## Tier 5: Linear Algebra

**Scope**: Vector and matrix operations.

**Dependencies**: Tiers 0-4.

### [PKG-LINEAR] swift-algebra-linear-primitives

Linear algebra primitives. Vectors, matrices, and linear transformations.

### [PKG-AFFINE] swift-affine-primitives

Affine transformation types. Translation, rotation, and scaling operations.

---

## Tier 6: Geometry

**Scope**: Spatial and geometric primitives.

**Dependencies**: Tiers 0-5.

### [PKG-GEOMETRY] swift-geometry-primitives

Core geometry types. Points, lines, and basic shapes.

### [PKG-SYMMETRY] swift-symmetry-primitives

Symmetry operations. Reflection, rotation groups, and tessellation.

### [PKG-LAYOUT] swift-layout-primitives

Layout computation types. Constraint-based positioning primitives.

### [PKG-SPACE] swift-space-primitives

Coordinate space types. Type-safe coordinate system transformations.

---

## Tier 7: System

**Scope**: Operating system abstractions.

**Dependencies**: Tiers 0-6.

### [PKG-CPU] swift-cpu-primitives

CPU feature detection. Architecture-specific capability queries.

### [PKG-SYSTEM] swift-system-primitives

System call abstractions. Portable syscall interface contracts.

### [PKG-KERNEL] swift-kernel-primitives

Kernel interaction types. Process, thread, and signal primitives.

### [PKG-LOADER] swift-loader-primitives

Dynamic loading primitives. Symbol resolution and library loading.

### [PKG-DRIVER] swift-driver-primitives

Device driver interfaces. Hardware abstraction layer contracts.

---

## Tier 8: Platform

**Scope**: Platform-specific implementations.

**Dependencies**: Tiers 0-7.

### [PKG-DARWIN] swift-darwin-primitives

Darwin/macOS/iOS primitives. Apple platform-specific bindings.

### [PKG-LINUX] swift-linux-primitives

Linux primitives. Linux-specific system interfaces.

### [PKG-POSIX] swift-posix-primitives

POSIX compatibility layer. Portable Unix interface implementations.

### [PKG-WINDOWS] swift-windows-primitives

Windows primitives. Windows API bindings and abstractions.

### [PKG-ARM] swift-arm-primitives

ARM architecture primitives. ARM-specific intrinsics and features.

### [PKG-X86] swift-x86-primitives

x86/x86-64 architecture primitives. Intel/AMD-specific intrinsics.

### [PKG-ABI] swift-abi-primitives

ABI compatibility types. Calling conventions and binary interface contracts.

---

## Tier 9: Infrastructure

**Scope**: Compiler tooling and language infrastructure.

**Dependencies**: Tiers 0-8.

### [PKG-LEXER] swift-lexer-primitives

Lexical analysis primitives. Token stream generation contracts.

### [PKG-TOKEN] swift-token-primitives

Token types. Lexeme representation and classification.

### [PKG-SYMBOL] swift-symbol-primitives

Symbol table primitives. Name binding and scope resolution.

### [PKG-SYNTAX] swift-syntax-primitives

Syntax representation types. Parse tree node abstractions.

### [PKG-SOURCE] swift-source-primitives

Source file handling. File loading and source location tracking.

### [PKG-AST] swift-abstract-syntax-tree-primitives

Abstract syntax tree types. Language-agnostic AST node contracts.

### [PKG-BACKEND] swift-backend-primitives

Compiler backend interfaces. Code generation target abstractions.

### [PKG-IR] swift-intermediate-representation-primitives

Intermediate representation types. IR node and instruction primitives.

### [PKG-MODULE] swift-module-primitives

Module system primitives. Import/export and visibility contracts.

### [PKG-DIAGNOSTIC] swift-diagnostic-primitives

Diagnostic message types. Error, warning, and note representations.

### [PKG-PREDICATE] swift-predicate-primitives

Predicate types. Boolean-valued function abstractions.

### [PKG-OUTCOME] swift-outcome-primitives

Outcome types. Result and error handling beyond standard Result.

### [PKG-LIFETIME] swift-lifetime-primitives

Lifetime tracking types. Resource lifetime and scope management.

### [PKG-TYPE] swift-type-primitives

Type representation primitives. Type metadata and reflection contracts.

### [PKG-STRING] swift-string-primitives

String processing primitives. Unicode-aware string operations.

### [PKG-TERMINAL] swift-terminal-primitives

Terminal I/O primitives. ANSI escape sequences and terminal control.

### [PKG-TEXT] swift-text-primitives

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