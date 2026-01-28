# Copyable Remediation

@Metadata {
    @TitleHeading("Swift Institute")
}

Process workflow for systematically auditing and fixing ~Copyable/Copyable constraint issues in Swift packages.

## Overview

This document defines the *remediation workflow* for identifying and resolving ~Copyable constraint propagation failures in Swift packages. It provides a systematic process for working through a package, identifying constraint issues, and applying the canonical architectural patterns documented in <doc:Memory-Copyable>.

**Entry point**: A package fails to compile with `type 'X' does not conform to protocol 'Copyable'`, or you want to proactively ensure proper ~Copyable support.

**Prerequisites**:
1. Read <doc:Memory-Copyable> for constraint propagation rules through
2. Understand the six categories of propagation failure

**Canonical references**:
- `swift-stack-primitives` at `/Users/coen/Developer/swift-primitives/swift-stack-primitives` — Module boundary solution with `Swift.Sequence` in Core and `Sequence.Protocol` in Sequence module
- `swift-array-primitives` at `/Users/coen/Developer/swift-primitives/swift-array-primitives` — Module boundary solution

**Applies to**: Packages with generic types that support `~Copyable` elements and need conditional `Copyable` conformance.

**Does not apply to**: Packages with no generic types, or types that are unconditionally `Copyable`.

---

## Quick Reference: Symptom Identification

**Scope**: Mapping error messages to failure categories and remediation rules.

| Error Message / Symptom | Likely Category | Remediation Rule |
|------------------------|-----------------|------------------|
| `type 'Element' does not conform to protocol 'Copyable'` | 2, 3, or 5 | |
| Error appears only during `swift build` (not in IDE) | 5 | |
| Error appears after adding `Sequence` conformance | 3 or 4 | |
| Nested type fails with ~Copyable constraint | 1 | |
| Extension methods unavailable for ~Copyable elements | 2 | |
| `ManagedBuffer` subclass fails in nested type | 1 | |
| **~Copyable element deinit NOT called** (memory leak) | Runtime bug | |
| `InlineArray<capacity, ...>` with value generic | Runtime bug | |

**Research documents**:
- `Noncopyable Generics Constraint Propagation.md` — Full research paper on constraint poisoning
- `Noncopyable Generics Investigation Brief.md` — Investigation brief with solution summary

**Experiments index**: See `Experiments/_index.md` for 34 documented experiments including 13 ~Copyable-related investigations.

---

## Remediation Triggers

**Scope**: Conditions that warrant applying this workflow.

**Statement**: The remediation workflow MUST be applied when a package exhibits ~Copyable constraint propagation failures, or SHOULD be applied proactively when auditing packages for ~Copyable support.

### Trigger Categories

| Trigger | Priority | Action |
|---------|----------|--------|
| Build failure with Copyable conformance error | Critical | Apply workflow immediately |
| Adding conditional `Sequence`/`Collection` conformance | High | Apply workflow before implementation |
| New package with ~Copyable generic parameters | High | Apply workflow during initial design |
| Existing package audit | Medium | Apply workflow systematically |
| Toolchain update | Low | Verify existing patterns still work |

**Rationale**: Proactive application of this workflow prevents constraint poisoning issues from being introduced. Reactive application after build failures ensures systematic diagnosis rather than ad-hoc fixes.

---

## Pre-Audit Checklist

**Scope**: Information to gather before starting remediation.

**Statement**: Before beginning remediation, the following information MUST be collected to guide architectural decisions.

### Package Analysis Checklist

| Item | Information Needed | Why |
|------|-------------------|-----|
| Generic types | List all types with `<Element: ~Copyable>` | Identifies scope of work |
| Nested types | Map nesting hierarchy (which types nest inside which) | Determines constraint propagation path |
| Storage types | Identify `ManagedBuffer`, `UnsafeMutablePointer`, etc. | These are constraint-sensitive |
| Conditional conformances | List all `where Element: Copyable` conformances | Primary source of poisoning |
| File organization | Map which types/extensions are in which files | Multi-file issues (Category 5) |
| Protocol conformances | List `Sequence`, `Collection`, custom protocols | Category 4 issues |

### Template: Package Analysis

```text
Package: {package-name}
Date: {YYYY-MM-DD}

Generic Types with ~Copyable:
- {Type1}<Element: ~Copyable>
- {Type2}<Element: ~Copyable>
  - Nested: {Type2.Variant1}
  - Nested: {Type2.Variant2}

Storage Types:
- {Type1}: ManagedBuffer<Int, Element>
- {Type2}: UnsafeMutablePointer<Element>

Current Conditional Conformances:
- {Type1}: Sequence where Element: Copyable (File: {filename})
- {Type1}: Copyable where Element: Copyable (File: {filename})

File Organization:
- {Type1}.swift: Type definition, Storage class
- {Type1}+Sequence.swift: Sequence conformance
- {Type1}+Methods.swift: Extension methods
```

**Rationale**: Understanding the full architecture before making changes prevents introducing new issues while fixing existing ones.

---

## Remediation Rules

### Nesting Level Principle

**Scope**: Fundamental architecture rule for ~Copyable constraint propagation.

**Statement**: Types that require access to a `~Copyable` generic parameter MUST be nested at the **same level** as the parameter declaration, not deeper. Constraint propagation fails across nesting boundaries.

### The Nesting Level Rule

```text
Level 0: Container<Element: ~Copyable>  ← Constraint declared here
         │
         ├─ Storage: ManagedBuffer<Int, Element>  ← WORKS (Level 0)
         │
         └─ Variant: ~Copyable
             │
             └─ Storage: ManagedBuffer<Int, Element>  ← FAILS (Level 1)
```

### Correct Pattern (swift-stack-primitives)

```swift
// Storage at Container level (Level 0) - constraint propagates
public struct Stack<Element: ~Copyable>: ~Copyable {

    @usableFromInline
    final class Storage: ManagedBuffer<Int, Element> {
        // Element: ~Copyable is visible here
    }

    public struct Bounded: ~Copyable {
        var _storage: Stack<Element>.Storage  // References Level 0 Storage
    }
}
```

### Incorrect Pattern (fails)

```swift
public struct Stack<Element: ~Copyable>: ~Copyable {

    public struct Bounded: ~Copyable {
        // Storage at Bounded level (Level 1) - constraint lost
        final class Storage: ManagedBuffer<Int, Element> {
            // ERROR: type 'Element' does not conform to protocol 'Copyable'
        }
    }
}
```

### Remediation Steps

1. **Identify** all types that subclass `ManagedBuffer` or use `UnsafeMutablePointer<Element>`
2. **Check** their nesting level relative to the `~Copyable` declaration
3. **Move** any Level 1+ storage types to Level 0
4. **Update** references in nested types to use the Level 0 type

**Rationale**: This is the fundamental constraint of Swift's ~Copyable generics. The compiler does not propagate `~Copyable` suppression across nesting boundaries.

---

### Nested Type Declaration Site

**Scope**: Where to declare nested types that use the outer type's generic parameter.

**Statement**: Nested types that reference the outer type's `~Copyable` generic parameter MUST be declared in the struct/enum body, NOT in extensions.

### Correct Pattern

```swift
public struct Container<Element: ~Copyable>: ~Copyable {

    // Declared in body - inherits Element's ~Copyable context
    public struct Variant: ~Copyable {
        var storage: UnsafeMutablePointer<Element>  // Works
    }

    // Also declared in body - works
    public struct Index: Sendable {
        let offset: Int
    }
}
```

### Incorrect Pattern

```swift
public struct Container<Element: ~Copyable>: ~Copyable { }

extension Container {
    // Declared in extension - does NOT inherit ~Copyable context
    public struct Variant: ~Copyable {
        var storage: UnsafeMutablePointer<Element>  // FAILS
    }
}
```

### Remediation Steps

1. **Find** all nested types declared in extensions
2. **Move** them into the main type body
3. **Keep** the extensions for methods only

**Exception**: Nested types that don't reference `Element` can remain in extensions.

**Workaround Note**: swift-stack-primitives documents this pattern:
```swift
// Stack.Inline and Stack.Small declared here (not in extensions)
// due to Swift compiler bug with value generic parameters in ~Copyable contexts
```

**Rationale**: The Swift compiler establishes constraint contexts at type declaration boundaries. When a nested type is declared inside the main type body, it inherits the enclosing generic context. Extensions create separate constraint contexts that do not automatically inherit `~Copyable` suppressions.

---

### Extension Constraint Requirement

**Scope**: All extensions on types with `~Copyable` generic parameters.

**Statement**: Every extension on a type with `~Copyable` parameters MUST include an explicit `where Element: ~Copyable` constraint, unless the extension is intentionally restricted to `Copyable` elements.

### The Implicit Copyable Rule

Extensions without constraints **implicitly** add `where Element: Copyable`:

```swift
struct Container<Element: ~Copyable>: ~Copyable { }

// IMPLICIT: where Element: Copyable
extension Container {
    func operation() { }  // Only available when Element: Copyable!
}
```

### Correct Pattern

```swift
// For ALL elements (including ~Copyable)
extension Container where Element: ~Copyable {
    func baseOperation() { }  // Available for all Element types
}

// For Copyable elements only (explicit)
extension Container where Element: Copyable {
    func copyOnlyOperation() { }  // Intentionally restricted
}
```

### Audit Process

1. **List** all extensions on types with `~Copyable` parameters
2. **Check** each extension for explicit constraint
3. **Add** `where Element: ~Copyable` to all extensions that should work with ~Copyable elements
4. **Document** extensions that intentionally require `Copyable`

### Applies to All Extension Content

This rule applies to everything declared in extensions:
- Methods
- Computed properties
- **Typealiases** (commonly overlooked)
- Nested types (but prefer body declaration per)

```swift
// WRONG: Typealias with implicit Copyable constraint
extension Container {
    typealias Error = ContainerError  // Only visible when Element: Copyable!
}

// CORRECT: Typealias available for all Element types
extension Container where Element: ~Copyable {
    typealias Error = ContainerError
}
```

**Rationale**: Per SE-0427, "Plain extensions default to being constrained to types where generic parameters are Copyable." This implicit constraint causes methods and members to silently become unavailable for `~Copyable` elements. Explicit constraints make the API contract visible and intentional.

---

### Conditional Conformance Placement

**Scope**: Where to declare conditional `Copyable` and protocol conformances.

**Statement**: Conditional conformances (`extension Type: Protocol where Element: Copyable`) MUST be in the **same file** as the type definition to avoid constraint poisoning.

### The Poisoning Problem

When conditional conformances are in separate files, the constraint solver may "poison" stored properties in the type definition:

```swift
// File: Container.swift
struct Container<Element: ~Copyable>: ~Copyable {
    var ptr: UnsafeMutablePointer<Element>  // FAILS when conformance below exists
}

// File: Container+Sequence.swift
extension Container: Sequence where Element: Copyable { }
// This conformance poisons the stored property above
```

### Correct Pattern (swift-stack-primitives)

All conditional conformances are in the main type file:

```swift
// File: Stack.swift (lines 583-599)

// MARK: - Conditional Copyable

/// `Stack` is `Copyable` when its elements are `Copyable`.
extension Stack: Copyable where Element: Copyable {}

/// `Stack.Bounded` is `Copyable` when its elements are `Copyable`.
extension Stack.Bounded: Copyable where Element: Copyable {}

/// `Stack.Bounded` conforms to `Sequence` when `Element` is `Copyable`.
extension Stack.Bounded: Sequence where Element: Copyable { ... }
```

### Remediation Steps

1. **Identify** all conditional conformances across all files
2. **Move** them to the same file as the type definition
3. **Place** them in a clearly marked section (e.g., `// MARK: - Conditional Copyable`)
4. **Test** build to verify poisoning is resolved

### Module Boundary Alternative

If same-file placement is not possible (e.g., large types), use separate SPM modules:

```text
Package/
├── Sources/
│   ├── Core/              # Type definition only
│   │   └── Container.swift
│   ├── Sequence/          # Conformances (imports Core)
│   │   └── Container+Sequence.swift
│   └── Public/            # Re-exports both
│       └── exports.swift
```

See Category 6 for details.

**Rationale**: The Swift compiler's constraint solver processes all extensions in a module together. When it sees both a stored property using `Element` and a conformance requiring `Element: Copyable`, it propagates the `Copyable` requirement backwards to the stored property—causing "poisoning." Same-file placement allows careful ordering; module boundaries create separate compilation units that prevent cross-propagation.

---

### Protocol Conformance Strategy

**Scope**: Conforming to `Sequence`, `Collection`, and custom protocols.

**Statement**: Protocol conformances that require `Copyable` (like `Swift.Sequence`) MUST be conditional on `Element: Copyable` and placed per.

### Swift.Sequence/Collection Limitation

Swift's `Sequence` and `Collection` protocols implicitly require `Self: Copyable`. A `~Copyable` container cannot directly conform:

```swift
struct Container<Element: ~Copyable>: ~Copyable { }
extension Container: Sequence { }  // ERROR: Copyable required on Container
```

### Correct Pattern

Conform conditionally when elements are `Copyable`:

```swift
// Container remains ~Copyable, but gains Sequence when Element: Copyable
extension Container: Sequence where Element: Copyable {
    struct Iterator: IteratorProtocol {
        mutating func next() -> Element? { ... }
    }

    func makeIterator() -> Iterator { ... }
}
```

### Incorrect Pattern

```swift
// WRONG: Unconditional Sequence conformance on ~Copyable container
struct Container<Element: ~Copyable>: ~Copyable { }
extension Container: Sequence {  // ERROR: Self must be Copyable
    // ...
}
```

### Custom Protocol Alternative

For iteration over ~Copyable elements, use custom protocols:

```swift
// In swift-collection-primitives
public protocol `Protocol`: ~Copyable {
    associatedtype Element: ~Copyable
    // ...
}
```

### Remediation Steps

1. **Check** if `Sequence`/`Collection` conformance exists
2. **Add** `where Element: Copyable` constraint if missing
3. **Move** conformance to type definition file per
4. **Consider** custom protocols for ~Copyable element iteration

**Rationale**: Swift's standard library `Sequence` and `Collection` protocols predate noncopyable types and implicitly require `Self: Copyable`. Until these protocols are updated (pending Swift Evolution), containers supporting ~Copyable elements cannot unconditionally conform. Conditional conformance provides the best of both worlds: standard iteration for copyable elements, custom patterns for noncopyable.

---

### Multi-File Emit-Module Bug

**Scope**: Errors that appear only during `swift build` with library targets.

**Statement**: When errors appear during `-emit-module` but not during type-checking, and involve `borrowing Element` closures in separate files, all source MUST be consolidated into a single file.

### Symptom Recognition

This bug manifests when **all six conditions** are present:

| # | Condition |
|---|-----------|
| 1 | Compound constraint: `Element: ~Copyable & Protocol` |
| 2 | `UnsafeMutablePointer<Element>` in nested type |
| 3 | Conditional Sequence: `extension ...: Sequence where Element: Copyable` |
| 4 | `borrowing Element` closure in **separate file** |
| 5 | Library target (uses `-emit-module`) |
| 6 | `-enable-experimental-feature Lifetimes` flag |

### Diagnosis

- Error appears during `swift build` but not in IDE
- Error message: `type 'Element' does not conform to protocol 'Copyable'`
- Error references code that appears correct

### Correct Pattern (swift-stack-primitives)

All Stack code is in a single file (`Stack.swift`, 1133 lines):

```text
Sources/Stack Primitives/
├── Stack.swift          # ALL type definitions, extensions, conformances
├── Stack.Bounded.swift  # Only Bounded-specific extension methods
├── Stack.Inline.swift   # Only Inline-specific extension methods
├── Stack.Error.swift    # Error type definitions (separate due to hoisting)
└── Stack.Index.swift    # Index-specific extensions
```

### Remediation Steps

1. **Identify** all files containing extensions with `borrowing Element`
2. **Consolidate** into the main type file
3. **Test** build to verify resolution
4. **Document** the consolidation with a comment:

```swift
// NOTE: All extensions consolidated into single file due to Swift compiler
// emit-module phase bug. See Category 5.
// Tracking: Swift issue #86669
```

### Incorrect Pattern

```swift
// WRONG: borrowing Element closure in separate file from type definition
// File: Container.swift
struct Container<Element: ~Copyable>: ~Copyable { ... }

// File: Container+Methods.swift (SEPARATE FILE)
extension Container where Element: ~Copyable {
    func forEach(_ body: (borrowing Element) -> Void) { ... }  // FAILS during emit-module
}
```

**Rationale**: The Swift compiler's `-emit-module` phase processes files differently than type-checking. When all six trigger conditions are present, the compiler loses track of the `~Copyable` suppression during module serialization. This is a confirmed compiler bug (#86669), not intended behavior. Consolidation into a single file is a workaround until the bug is fixed.

---

### Copy-on-Write Implementation

**Scope**: Implementing CoW for types that are conditionally `Copyable`.

**Statement**: Types with conditional `Copyable` conformance MUST implement copy-on-write semantics in all mutating operations when `Element: Copyable`.

### Pattern: Method Shadowing

Provide two versions of mutating methods—one for ~Copyable (no CoW), one for Copyable (with CoW):

```swift
// Base: Works for all elements (no CoW needed for ~Copyable)
extension Stack where Element: ~Copyable {
    @inlinable
    public mutating func push(_ element: consuming Element) {
        ensureCapacity(_storage.header + 1)
        // ... direct mutation
    }
}

// Copyable: Adds CoW check
extension Stack where Element: Copyable {
    @usableFromInline
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL
        }
    }

    @inlinable
    public mutating func push(_ element: Element) {
        makeUnique()  // CoW check
        ensureCapacity(_storage.header + 1)
        // ... mutation with value semantics
    }
}
```

### Critical: Cached Pointer Update

If using cached pointers (for Span access), **always** update after CoW copy:

```swift
mutating func makeUnique() {
    if !isKnownUniquelyReferenced(&_storage) {
        _storage = _storage.copy()
        // CRITICAL: Update cached pointer after reallocation
        unsafe (_cachedPtr = _storage._elementsPointer)
    }
}
```

swift-stack-primitives marks all such locations with `// CRITICAL` comments.

### Incorrect Pattern

```swift
// WRONG: No CoW check in Copyable variant
extension Stack where Element: Copyable {
    public mutating func push(_ element: Element) {
        // MISSING: makeUnique() call
        ensureCapacity(_storage.header + 1)
        // Mutation may affect shared storage!
    }
}
```

### Remediation Steps

1. **Identify** all mutating methods
2. **Add** `makeUnique()` helper with proper constraint
3. **Create** Copyable-constrained overloads that call `makeUnique()`
4. **Audit** all pointer updates after reallocation

**Rationale**: When `Element: Copyable`, the container itself becomes `Copyable` and supports value semantics. Users expect that copying a container creates an independent copy. Without CoW, mutations to one copy affect all copies sharing the same storage. The ~Copyable variant doesn't need CoW because move-only types cannot be copied—each instance owns its storage uniquely.

---

### Sendable Conformance

**Scope**: Conditional `Sendable` conformance for ~Copyable types.

**Statement**: `Sendable` conformance MUST be conditional on `Element: Sendable` and is independent of `Copyable` conformance.

### Correct Pattern

```swift
// Sendable is independent of Copyable
extension Stack: @unchecked Sendable where Element: Sendable {}

// A type can be:
// - Sendable but not Copyable (Element: Sendable & ~Copyable)
// - Copyable but not Sendable (Element: Copyable & ~Sendable)
// - Both (Element: Sendable & Copyable)
// - Neither (Element: ~Sendable & ~Copyable)
```

### Incorrect Pattern

```swift
// WRONG: Sendable tied to Copyable
extension Stack: Sendable where Element: Copyable & Sendable {}
// This unnecessarily restricts Sendable to only Copyable elements

// WRONG: Unconditional Sendable
extension Stack: Sendable {}  // Unsafe if Element is not Sendable
```

### Why `@unchecked`

Container types with internal synchronization or reference storage often need `@unchecked`:

```swift
// Storage is a class (reference type) but controlled by the struct
extension Stack: @unchecked Sendable where Element: Sendable {}
```

**Rationale**: `Sendable` and `Copyable` are orthogonal properties. A type can be safely shared across concurrency domains (`Sendable`) regardless of whether it can be copied (`Copyable`). Tying `Sendable` to `Copyable` would prevent move-only thread-safe types from being used in concurrent contexts—an unnecessary restriction.

---

### InlineArray + Value Generic Deinit Bug

**Scope**: ~Copyable structs using `InlineArray` with value generic capacity parameters.

**Statement**: When a `~Copyable` struct uses `InlineArray<capacity, ...>` where `capacity` is a **value generic parameter** (not a literal), and the struct contains **only value-type properties**, the compiler fails to generate deinit dispatch for cross-module `~Copyable` elements. Elements are silently leaked.

### Trigger Conditions

**All four conditions must be present**:

| # | Condition | Description |
|---|-----------|-------------|
| 1 | `InlineArray<capacity, ...>` | Where `capacity` is a value generic parameter |
| 2 | Value-only struct | No reference type properties in the struct |
| 3 | Cross-module boundary | Element type defined in different module than container |
| 4 | deinit with manual cleanup | deinit that deinitializes elements |

### Symptom

~Copyable elements are silently leaked—their `deinit` is never called:

```swift
// In ContainerLib module:
struct Container<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
    var _count: Int
    // NO reference type properties - THIS IS THE BUG TRIGGER

    deinit {
        // This code path is never executed for cross-module ~Copyable elements!
        for i in 0..<_count {
            // deinitialize elements...
        }
    }
}

// In Tests module:
struct TrackedElement: ~Copyable {
    deinit { print("deinit called") }  // NEVER PRINTED
}

var container = Container<TrackedElement, 4>()
container.push(TrackedElement())
// container goes out of scope - TrackedElement.deinit NOT called
```

### What Does NOT Trigger the Bug

| Configuration | Result |
|---------------|--------|
| `InlineArray<4, ...>` (literal capacity) | ✅ Works |
| Value generic without InlineArray | ✅ Works |
| Same module (container and element) | ✅ Works |
| Struct with any reference type property | ✅ Works |

### Workaround

Add a reference type property to the struct:

```swift
struct Container<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
    var _count: Int
    var _deinitWorkaround: AnyObject? = nil  // WORKAROUND: Forces correct deinit dispatch
}
```

This forces the compiler to generate correct deinit dispatch.

### Documentation Comment

```swift
// WORKAROUND: Swift compiler bug - InlineArray with value generic capacity
// fails to call element deinitializers for cross-module ~Copyable elements
// when struct has only value-type properties.
// See: Experiments/noncopyable-inline-deinit/
// Tracking: To be filed
var _deinitWorkaround: AnyObject? = nil
```

### Affected Packages

| Package | Type | Status |
|---------|------|--------|
| swift-deque-primitives | `Deque.Inline` | Fixed (workaround applied) |
| swift-queue-primitives | `Queue.Inline` | Fixed (workaround applied) |
| swift-stack-primitives | `Stack.Inline` | Fixed (workaround applied) |

### Incorrect Pattern (Bug Trigger)

```swift
// WRONG: Value-only struct with InlineArray<capacity, ...> where capacity is generic
struct Container<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
    var _count: Int
    // NO reference type property - deinit will not be called for cross-module elements!
}
```

**Experiment**: `Experiments/noncopyable-inline-deinit/` contains a complete reproduction case with isolation tests.

**Rationale**: The Swift compiler generates different deinit dispatch code paths depending on whether a struct contains reference types. When a struct has only value-type properties and uses `InlineArray` with a value generic parameter, the compiler takes a fast path that fails to properly dispatch to the custom deinit for cross-module `~Copyable` elements. Adding any reference type property forces the compiler to use the correct, slower deinit path.

---

### Module Boundary Solution

**Scope**: Enabling conditional `Sequence`/`Collection` conformances without constraint poisoning.

**Statement**: When same-file placement of conditional conformances is not viable, split the package into separate SPM modules. Module boundaries prevent constraint propagation because the compiler processes each target independently.

### Architecture

```text
Package/
├── Sources/
│   ├── Core/              # Type definitions with ~Copyable support
│   │   └── Container.swift   # NO Sequence/Collection conformances here
│   ├── Sequence/          # Conditional conformances
│   │   └── Container+Sequence.swift  # imports Core
│   └── Public/            # Re-exports for unified API
│       └── exports.swift  # @_exported import Core; @_exported import Sequence
```

### Why Module Boundaries Work

When the Sequence module compiles and adds conformances, the Core module has **already been compiled**. The constraint solver never sees both the stored property validation and the conditional conformance in the same compilation unit—preventing poisoning.

### Package.swift Structure

```swift
let package = Package(
    name: "container-primitives",
    targets: [
        // Core: Type definitions only
        .target(name: "Core", path: "Sources/Core"),

        // Sequence: Conformances (imports Core)
        .target(name: "Sequence", dependencies: ["Core"], path: "Sources/Sequence"),

        // Public: Re-exports both
        .target(name: "Public", dependencies: ["Core", "Sequence"], path: "Sources/Public"),
    ]
)
```

### Key Requirements

| Requirement | Why |
|-------------|-----|
| `package` access level | Enables internal members to be accessible across modules within same SPM package |
| Separate SPM targets | Creates compilation boundary |
| Re-export module | Provides unified public API—users import one module |

### exports.swift

```swift
@_exported public import Core
@_exported public import Sequence
```

### Applied In

| Package | Core Module | Sequence Module |
|---------|-------------|-----------------|
| swift-array-primitives | `Array Primitives Core` | `Array Primitives Sequence` |

### Incorrect Pattern

```swift
// WRONG: Type definition and conditional conformance in same module (different files)
// Sources/Container/Container.swift
struct Container<Element: ~Copyable>: ~Copyable {
    var ptr: UnsafeMutablePointer<Element>  // POISONED by conformance below
}

// Sources/Container/Container+Sequence.swift (SAME MODULE)
extension Container: Sequence where Element: Copyable { }
// ERROR: type 'Element' does not conform to protocol 'Copyable'
```

**Experiment**: `Experiments/separate-module-conformance/` demonstrates the complete solution.

**Rationale**: The Swift compiler processes all files in a module together, allowing constraint propagation between files. By placing the type definition and conditional conformances in separate SPM targets (modules), each target compiles independently. When the Sequence module compiles, the Core module is already a compiled `.swiftmodule`—the constraint solver cannot propagate requirements backwards across the module boundary.

---

## Remediation Workflow

### Phase 1: Analysis

```text
┌─────────────────────────────────────────────────────────────┐
│                    PHASE 1: ANALYSIS                         │
└─────────────────────────────────────────────────────────────┘

1. BUILD AND CAPTURE ERRORS
   │
   ├─ swift build 2>&1 | tee build-output.txt
   └─ Note all 'does not conform to Copyable' errors
                                            │
                                            ▼
2. COMPLETE PRE-AUDIT CHECKLIST
   │
   ├─ List all generic types with ~Copyable
   ├─ Map nesting hierarchy
   ├─ Identify storage types
   ├─ List conditional conformances
   └─ Map file organization
                                            │
                                            ▼
3. CATEGORIZE ERRORS
   │
   ├─ Match each error to failure category (1-6)
   └─ Prioritize by severity
```

### Phase 2: Architecture Fixes

```text
┌─────────────────────────────────────────────────────────────┐
│               PHASE 2: ARCHITECTURE FIXES                    │
└─────────────────────────────────────────────────────────────┘

4. FIX NESTING LEVEL ISSUES
   │
   ├─ Move Storage classes to Level 0
   └─ Update references in nested types

5. FIX DECLARATION SITE ISSUES
   │
   ├─ Move nested types from extensions to body
   └─ Keep only methods in extensions

6. ADD EXTENSION CONSTRAINTS
   │
   ├─ Add `where Element: ~Copyable` to all base extensions
   └─ Verify typealiases have proper constraints

7. CONSOLIDATE CONDITIONAL CONFORMANCES
   │
   ├─ Move all conditional conformances to type file
   └─ Or split into separate SPM modules
```

### Phase 3: Verification

```text
┌─────────────────────────────────────────────────────────────┐
│                  PHASE 3: VERIFICATION                       │
└─────────────────────────────────────────────────────────────┘

8. BUILD AND TEST
   │
   ├─ swift build
   ├─ swift test
   └─ Verify all errors resolved

9. TEST WITH ~COPYABLE ELEMENTS
   │
   └─ Create test that uses ~Copyable element type

10. TEST WITH COPYABLE ELEMENTS
    │
    ├─ Verify CoW works correctly
    └─ Verify Sequence/Collection iteration works

11. DOCUMENT WORKAROUNDS
    │
    └─ Add comments per for any compiler bugs
```

---

## Verification Tests

### ~Copyable Element Test

**Scope**: Verifying the type works with ~Copyable elements.

**Statement**: After remediation, create a test using a ~Copyable element type.

```swift
import Testing

struct Token: ~Copyable {
    let id: Int
}

@Test("Stack works with ~Copyable elements")
func noncopyableElements() {
    var stack = Stack<Token>()
    stack.push(Token(id: 1))
    stack.push(Token(id: 2))

    let popped = stack.pop()
    #expect(popped?.id == 2)
}
```

### Conditional Copyable Test

**Scope**: Verifying conditional Copyable conformance works.

**Statement**: Test that the type becomes Copyable when Element is Copyable.

```swift
@Test("Stack is Copyable when Element is Copyable")
func conditionalCopyable() {
    var stack1 = Stack<Int>()
    stack1.push(1)
    stack1.push(2)

    let stack2 = stack1  // Should compile (copy)

    #expect(stack1.count == 2)
    #expect(stack2.count == 2)

    stack1.push(3)
    #expect(stack1.count == 3)
    #expect(stack2.count == 2)  // CoW: stack2 unchanged
}
```

### Sequence Conformance Test

**Scope**: Verifying Sequence conformance works when Element: Copyable.

**Statement**: After remediation, verify that `for-in` loops and Sequence-consuming APIs work with the container.

```swift
@Test("Stack conforms to Sequence when Element is Copyable")
func sequenceConformance() {
    var stack = Stack<Int>()
    stack.push(1)
    stack.push(2)
    stack.push(3)

    let array = Array(stack)  // Uses Sequence conformance
    #expect(array == [1, 2, 3])
}
```

### Deinit Verification Test

**Scope**: Verifying ~Copyable element deinitializers are called correctly.

**Statement**: For types with inline storage (InlineArray + value generic), verify elements are properly deinitialized.

```swift
import Testing

/// Thread-safe tracker for deinit order
final class Tracker: @unchecked Sendable {
    nonisolated(unsafe) var deinitOrder: [Int] = []
    func append(_ id: Int) { deinitOrder.append(id) }
}

/// Element that tracks its deinit
struct TrackedElement: ~Copyable {
    let id: Int
    let tracker: Tracker

    deinit { tracker.append(id) }
}

@Test("Inline container calls element deinit")
func inlineDeinitOrder() {
    let tracker = Tracker()
    do {
        var container = Container<TrackedElement>.Inline<4>()
        container.push(TrackedElement(0, tracker: tracker))
        container.push(TrackedElement(1, tracker: tracker))
        container.push(TrackedElement(2, tracker: tracker))
    }
    // Elements should be deinitialized in order
    #expect(tracker.deinitOrder == [0, 1, 2],
            "BUG: Elements leaked (deinitOrder was \(tracker.deinitOrder))")
}
```

**Critical**: If `deinitOrder` is empty (`[]`), the workaround is needed.

---

## Common Mistakes

### Mistake 1: Forgetting Extension Constraints

```swift
// WRONG: Implicit Copyable constraint
extension Container {
    func operation() { }
}

// RIGHT: Explicit ~Copyable constraint
extension Container where Element: ~Copyable {
    func operation() { }
}
```

### Mistake 2: Nested Storage at Wrong Level

```swift
// WRONG: Storage at Variant level
struct Container<Element: ~Copyable>: ~Copyable {
    struct Variant: ~Copyable {
        final class Storage: ManagedBuffer<Int, Element> { }  // FAILS
    }
}

// RIGHT: Storage at Container level
struct Container<Element: ~Copyable>: ~Copyable {
    final class Storage: ManagedBuffer<Int, Element> { }  // WORKS
    struct Variant: ~Copyable {
        var _storage: Container<Element>.Storage  // Reference Level 0
    }
}
```

### Mistake 3: Conditional Conformance in Separate File

```swift
// WRONG: Conformance in separate file causes poisoning
// File: Container+Sequence.swift
extension Container: Sequence where Element: Copyable { }

// RIGHT: Conformance in same file as type definition
// File: Container.swift
struct Container<Element: ~Copyable>: ~Copyable { ... }
extension Container: Sequence where Element: Copyable { }
```

### Mistake 4: Forgetting Pointer Update After CoW

```swift
// WRONG: Stale pointer after copy
mutating func makeUnique() {
    if !isKnownUniquelyReferenced(&_storage) {
        _storage = _storage.copy()
        // MISSING: _cachedPtr update
    }
}

// RIGHT: Update pointer after copy
mutating func makeUnique() {
    if !isKnownUniquelyReferenced(&_storage) {
        _storage = _storage.copy()
        unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL
    }
}
```

### Mistake 5: Missing Deinit Workaround for InlineArray + Value Generic

```swift
// WRONG: Value-only struct with InlineArray<capacity, ...> where capacity is generic
struct Container<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
    var _count: Int
    // NO reference type property - elements will leak!
}

// RIGHT: Add reference type property as workaround
struct Container<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
    var _count: Int
    var _deinitWorkaround: AnyObject? = nil  // Forces correct deinit dispatch
}
```

---

## Topics

### Foundation Documents

- <doc:Memory-Copyable> — Authoritative ~Copyable rules and gotchas [MEM-COPY-*]
- <doc:Memory-Ownership> — Ownership semantics [MEM-OWN-*]

### Research Documents

- `Noncopyable Generics Constraint Propagation.md` — 657-line research paper (RESOLVED)
- `Noncopyable Generics Investigation Brief.md` — Investigation brief with solution summary

### Related Workflows

- <doc:Experiment-Investigation> — Debugging unexpected constraint failures
- <doc:Experiment-Discovery> — Proactive package audits
- <doc:Issue-Submission> — Filing compiler bugs

### Canonical References

| Package | Path | Notes |
|---------|------|-------|
| swift-stack-primitives | `/Users/coen/Developer/swift-primitives/swift-stack-primitives` | Single-file conformances, deinit workaround |
| swift-array-primitives | `/Users/coen/Developer/swift-primitives/swift-array-primitives` | Module boundary solution |
| Experiments | `/Users/coen/Developer/swift-institute/Sources/Swift Institute/Swift Institute.docc/Experiments/` | 34 documented experiments |

### Cross-Reference Index

| ID | Title | Focus |
|----|-------|-------|
| COPY-REM-001 | Remediation Triggers | When to apply workflow |
| COPY-REM-002 | Pre-Audit Checklist | Information gathering |
| COPY-FIX-001 | Nesting Level Principle | Level 0 storage requirement |
| COPY-FIX-002 | Nested Type Declaration Site | Body vs extension |
| COPY-FIX-003 | Extension Constraint Requirement | Explicit ~Copyable constraints |
| COPY-FIX-004 | Conditional Conformance Placement | Same-file requirement |
| COPY-FIX-005 | Protocol Conformance Strategy | Sequence/Collection handling |
| COPY-FIX-006 | Multi-File Emit-Module Bug | Single-file consolidation |
| COPY-FIX-007 | Copy-on-Write Implementation | CoW for conditional Copyable |
| COPY-FIX-008 | Sendable Conformance | Independent of Copyable |
| COPY-FIX-009 | InlineArray + Value Generic Deinit Bug | Runtime deinit workaround |
| COPY-FIX-010 | Module Boundary Solution | SPM module isolation |
| COPY-TEST-001 | ~Copyable Element Test | Verification |
| COPY-TEST-002 | Conditional Copyable Test | Verification |
| COPY-TEST-003 | Sequence Conformance Test | Verification |
| COPY-TEST-004 | Deinit Verification Test | Runtime verification |

### Experiments Index

Related experiments are documented in:
```
/Users/coen/Developer/swift-institute/Sources/Swift Institute/Swift Institute.docc/Experiments/
```

| Experiment | Status | Key Finding |
|------------|--------|-------------|
| `noncopyable-inline-deinit` | BUG REPRODUCED | InlineArray + value generic deinit failure |
| `noncopyable-pointer-propagation` | BUG REPRODUCED | `associatedtype Element: ~Copyable` not supported |
| `noncopyable-multifile-poisoning` | CONFIRMED | File organization doesn't prevent poisoning |
| `noncopyable-sequence-emit-module-bug` | BUG FILED #86669 | Module emission failure with ~Copyable + Sequence |
| `separate-module-conformance` | SOLUTION FOUND | Module boundaries prevent constraint poisoning |
| `wrapper-type-approach` | WORKAROUND FOUND | Wrapper types avoid direct conformance |
| `noncopyable-protocol-workarounds` | WORKAROUND FOUND | Protocols without Element associatedtype |
| `conditional-copyable-type` | CONFIRMED FAILS | Conditional Copyable alone doesn't help |

### Packages with ~Copyable Support

| Package | Storage Pattern | Conformance Pattern |
|---------|----------------|---------------------|
| swift-stack-primitives | ManagedBuffer (Level 0) | Same-file conformances |
| swift-array-primitives | ManagedBuffer (Level 0) | Module boundary solution |
| swift-deque-primitives | ManagedBuffer (ring buffer) | Same-file conformances |
| swift-queue-primitives | ManagedBuffer (ring buffer) | Same-file conformances |
| swift-set-primitives | ManagedBuffer | Same-file conformances |
| swift-heap-primitives | ManagedBuffer | Same-file conformances |
| swift-vector-primitives | ManagedBuffer | Same-file conformances |
