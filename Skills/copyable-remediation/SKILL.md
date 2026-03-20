---
name: copyable-remediation
description: |
  ~Copyable/Copyable constraint audit and fix workflow.
  Apply when diagnosing or fixing ~Copyable constraint propagation failures.

layer: process

requires:
  - memory

applies_to:
  - swift
  - swift6
  - primitives

migrated_from: Documentation.docc/Copyable Remediation.md
migration_date: 2026-01-28
last_reviewed: 2026-03-20
---

# Copyable Remediation

Process workflow for auditing and fixing ~Copyable/Copyable constraint issues.

**Entry point**: Package fails with `type 'X' does not conform to protocol 'Copyable'`, or proactive audit.

**Prerequisites**: Read **memory** skill [MEM-COPY-004] through [MEM-COPY-006].

**Canonical references**:
- `swift-stack-primitives` — Single-file conformances, deinit workaround
- `swift-array-primitives` — Module boundary solution

---

## Quick Reference: Symptom Identification

| Error Message / Symptom | Likely Category | Fix |
|------------------------|-----------------|-----|
| `type 'Element' does not conform to protocol 'Copyable'` | 2, 3, or 5 | [COPY-FIX-003], [COPY-FIX-004] |
| Error appears only during `swift build` (not in IDE) | 5 | [COPY-FIX-006] |
| Error appears after adding `Sequence` conformance | 3 or 4 | [COPY-FIX-005] |
| Nested type fails with ~Copyable constraint | 1 | [COPY-FIX-002] |
| Extension methods unavailable for ~Copyable elements | 2 | [COPY-FIX-003] |
| `ManagedBuffer` subclass fails in nested type | 1 | [COPY-FIX-002] |
| ~Copyable element deinit NOT called (memory leak) | Runtime | [COPY-FIX-009] |
| Cross-package `@_rawLayout` stored property | Runtime | [COPY-FIX-009] |
| Extension on nested type within generic fails | 2 | [COPY-FIX-003] |

---

## [COPY-REM-001] Remediation Triggers

| Trigger | Priority | Action |
|---------|----------|--------|
| Build failure with Copyable conformance error | Critical | Apply workflow immediately |
| Adding conditional `Sequence`/`Collection` conformance | High | Apply before implementation |
| New package with ~Copyable generic parameters | High | Apply during initial design |
| Existing package audit | Medium | Apply systematically |
| Toolchain update | Low | Verify existing patterns |

---

## [COPY-REM-002] Pre-Audit Checklist

Before remediation, collect:

| Item | Information Needed |
|------|--------------------|
| Generic types | List all types with `<Element: ~Copyable>` |
| Nested types | Map nesting hierarchy |
| Storage types | Identify `ManagedBuffer`, `UnsafeMutablePointer`, etc. |
| Conditional conformances | List all `where Element: Copyable` conformances |
| File organization | Map which types/extensions are in which files |
| Protocol conformances | List `Sequence`, `Collection`, custom protocols |

---

## Planning ~Copyable/~Escapable Changes

### [COPY-REM-003] Constraint Cascade Audit

**Statement**: Before implementing a `~Copyable` or `~Escapable` change to an associated type or generic parameter, the planner MUST trace every associated type through every conformer and extension to predict where explicit `Copyable`/`Escapable` constraints will be needed.

**Audit procedure**:

1. **Identify** the associated type or parameter being changed (e.g., `associatedtype Element: ~Copyable`)
2. **List** all conformers of the protocol
3. **For each conformer**, check:
   - Does it store the associated type? → Subscript access on borrowed containers may break
   - Does it use the type as a return value? → Implicit `Copyable` on return types may break
   - Does it set another protocol's associated type to this type? → Downstream `Copyable` requirements propagate
4. **For each extension** on the protocol or its conformers, check:
   - Does it constrain on the associated type? → May need explicit `Copyable`/`~Copyable`
   - Does it pass the type to a generic parameter? → That parameter may need `~Copyable`/`~Escapable`

**The three cascade categories** (from Input.Stream.Protocol experience):
- **~Copyable on Element**: Subscript access on borrowed containers breaks (fix: conditional conformance `where Base.Element: Copyable`)
- **~Copyable on output types**: Protocol requirements with implicit `Copyable` on outputs break (fix: `where Input.Element: Copyable` on specific conformers)
- **~Escapable on generic parameters**: Parameters with implicit `Escapable` break (fix: add `~Escapable` to the parameter declaration)

**Cross-references**: [COPY-FIX-003], [COPY-FIX-004], [MEM-COPY-006]

---

## Remediation Rules

### [COPY-FIX-001] Nesting Level Principle

**Statement**: Types requiring access to a `~Copyable` generic parameter MUST be nested at the **same level** as the parameter declaration.

```text
Level 0: Container<Element: ~Copyable>  ← Constraint declared here
         ├─ Storage: ManagedBuffer<Int, Element>  ← WORKS (Level 0)
         └─ Variant: ~Copyable
             └─ Storage: ManagedBuffer<Int, Element>  ← FAILS (Level 1)
```

```swift
// CORRECT - Storage at Level 0
public struct Stack<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    final class Storage: ManagedBuffer<Int, Element> { }

    public struct Bounded: ~Copyable {
        var _storage: Stack<Element>.Storage  // References Level 0
    }
}

// INCORRECT - Storage at Level 1
public struct Stack<Element: ~Copyable>: ~Copyable {
    public struct Bounded: ~Copyable {
        final class Storage: ManagedBuffer<Int, Element> { }  // FAILS
    }
}
```

**Cross-references**: [MEM-COPY-006] Category 1

---

### [COPY-FIX-002] Nested Type Declaration Site

**Status**: RESOLVED in Swift 6.2.4.

**Statement**: Value-generic nested types (e.g., `struct Static<let capacity: Int>`) CAN be declared in extensions with `where Element: ~Copyable`. This was a compiler bug, fixed in Swift 6.2.4.

```swift
// WORKS in Swift 6.2.4+
extension Container where Element: ~Copyable {
    public struct Static<let capacity: Int>: ~Copyable {
        var _buffer: Buffer<Element>.Linear.Inline<capacity>  // Works
    }
}
```

**Separate design constraint**: Nested types declared in extensions CANNOT reference parent type context (typealiases, static properties, sentinel values). This is unrelated to ~Copyable — it applies to all extension-nested types. Types that need `Table.Bucket`, `Table.empty`, etc. MUST remain in the struct body.

```swift
// MUST BE IN BODY — references Table.Bucket, Table.empty (not a ~Copyable issue)
public struct Table<Element: ~Copyable>: ~Copyable {
    public struct Static<let bucketCapacity: Int>: ~Copyable {
        public typealias Bucket = Table.Bucket  // Needs parent context
        public static var empty: Int { Table.empty }  // Needs parent context
    }
}
```

**Applied in Swift 6.2.4**: 13 value-generic types extracted to extension files across 6 packages (array, stack, heap, queue, dictionary, set). Hash.Table.Static remains in body due to parent context references.

**Verification**: Experiment `value-generic-nested-type-bug` — both body and extension variants compile and run.

**Cross-references**: [MEM-COPY-006] Category 1, [API-IMPL-005]

---

### [COPY-FIX-003] Extension Constraint Requirement

**Statement**: Every extension on a type with `~Copyable` parameters MUST include explicit `where Element: ~Copyable`, unless intentionally restricted to `Copyable` elements.

```swift
// CORRECT
extension Container where Element: ~Copyable {
    func baseOperation() { }
}

// INCORRECT - Implicitly adds 'where Element: Copyable'
extension Container {
    func operation() { }
}
```

Applies to methods, computed properties, typealiases, and nested types.

**Nested type extensions**: This rule also applies to extensions on **nested types** within a generic outer type. Even though `Storage<Element: ~Copyable>` already constrains `Element`, extensions on `Storage.Heap` or `Storage.Initialization` still require `where Element: ~Copyable`:

```swift
public enum Storage<Element: ~Copyable> {
    public final class Heap: ManagedBuffer<Header, Element> { }
    public enum Initialization { ... }
}

// CORRECT - Constraint appears redundant but is REQUIRED
extension Storage.Heap where Element: ~Copyable {
    public struct Header { ... }
}

extension Storage.Initialization where Element: ~Copyable {
    public var count: Int { ... }
}

// INCORRECT - Fails with "type 'Element' does not conform to protocol 'Copyable'"
extension Storage.Heap {
    public struct Header { ... }  // FAILS
}
```

**Rationale**: Swift's constraint system doesn't automatically propagate `~Copyable` from the outer generic parameter to nested type extensions, even when the nested type is only defined within the constrained scope.

**Cross-references**: [MEM-COPY-004], [MEM-COPY-006] Category 2

---

### [COPY-FIX-004] Conditional Conformance Placement

**Statement**: Conditional conformances MUST be in the **same file** as the type definition to avoid constraint poisoning.

```swift
// CORRECT - Same file
// File: Stack.swift
struct Stack<Element: ~Copyable>: ~Copyable { ... }
extension Stack: Copyable where Element: Copyable {}
extension Stack: Sequence where Element: Copyable { ... }

// INCORRECT - Separate file causes poisoning
// File: Container.swift
struct Container<Element: ~Copyable>: ~Copyable {
    var ptr: UnsafeMutablePointer<Element>  // POISONED
}
// File: Container+Sequence.swift
extension Container: Sequence where Element: Copyable { }
```

**Module boundary alternative**: Split into separate SPM modules (Core + Sequence + Umbrella). See [COPY-FIX-010].

**Cross-references**: [MEM-COPY-006] Categories 3, 5

---

### [COPY-FIX-005] Protocol Conformance Strategy

**Statement**: `Sequence`/`Collection` conformances MUST be conditional on `Element: Copyable`.

```swift
// CORRECT
extension Container: Sequence where Element: Copyable {
    struct Iterator: IteratorProtocol {
        mutating func next() -> Element? { ... }
    }
    func makeIterator() -> Iterator { ... }
}

// INCORRECT - Unconditional
extension Container: Sequence { }  // ERROR: Self must be Copyable
```

For ~Copyable element iteration, use custom protocols or `forEach` with borrowing closures.

**Cross-references**: [MEM-COPY-006] Category 4

---

### [COPY-FIX-006] Multi-File Emit-Module Bug

**Statement**: When errors appear during `-emit-module` but not type-checking, and involve `borrowing Element` closures in separate files, consolidate all source into a single file.

**All six conditions must be present**:

| # | Condition |
|---|-----------|
| 1 | Compound constraint: `Element: ~Copyable & Protocol` |
| 2 | `UnsafeMutablePointer<Element>` in nested type |
| 3 | Conditional Sequence conformance |
| 4 | `borrowing Element` closure in separate file |
| 5 | Library target (uses `-emit-module`) |
| 6 | `-enable-experimental-feature Lifetimes` flag |

**Tracking**: Swift issue #86669

**Cross-references**: [MEM-COPY-006] Category 5

---

### [COPY-FIX-007] Copy-on-Write Implementation

**Statement**: Types with conditional `Copyable` conformance MUST implement CoW in all mutating operations when `Element: Copyable`.

```swift
// Base: All elements (no CoW needed for ~Copyable)
extension Stack where Element: ~Copyable {
    public mutating func push(_ element: consuming Element) {
        ensureCapacity(_storage.header + 1)
        // direct mutation
    }
}

// Copyable: Adds CoW check
extension Stack where Element: Copyable {
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL
        }
    }

    public mutating func push(_ element: Element) {
        makeUnique()
        ensureCapacity(_storage.header + 1)
        // mutation with value semantics
    }
}
```

**Critical**: Always update cached pointers after CoW copy.

---

### [COPY-FIX-008] Sendable Conformance

**Statement**: `Sendable` conformance MUST be conditional on `Element: Sendable` and is independent of `Copyable`.

```swift
// CORRECT - Independent of Copyable
extension Stack: @unchecked Sendable where Element: Sendable {}

// INCORRECT - Tied to Copyable
extension Stack: Sendable where Element: Copyable & Sendable {}
```

**Silent failure mode**: `@unchecked Sendable where Element: ~Copyable` compiles without any warning but makes the type Sendable for ALL element types — including non-Sendable ones. The compiler trusts `@unchecked` and cannot catch this. Always use `where Element: Sendable`, never `where Element: ~Copyable`.

```swift
// DANGEROUS — compiles silently, allows non-Sendable elements
extension Container: @unchecked Sendable where Element: ~Copyable {}

// CORRECT — restricts to Sendable elements only
extension Container: @unchecked Sendable where Element: Sendable {}
```

---

### [COPY-FIX-009] @_rawLayout Deinit Bug

**Status**: OPEN. Reproduced in Swift 6.2.4.

**Statement**: The compiler does not synthesize member destruction for `~Copyable` structs whose stored property chain includes `@_rawLayout`-backed types across package boundaries. Element deinitializers silently fail.

**Root cause** (narrowed 2026-03-20): `@_rawLayout` is the critical ingredient. Value generics, nesting depth, enum wrapping, and cross-module generics are all **non-contributing factors** — verified by experiment `noncopyable-nested-deinit-chain` Group A (11 variants without `@_rawLayout`, all pass in 6.2.4).

**Conditions**:

| # | Condition |
|---|-----------|
| 1 | Stored property uses `@_rawLayout` (directly or transitively) |
| 2 | Cross-package boundary between container and `@_rawLayout` type |
| 3 | Container is `~Copyable` |

**Workaround** (two parts, both required):

```swift
struct Container<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _buffer: Buffer<Element>.Ring.Inline<capacity>
    var _deinitWorkaround: AnyObject? = nil  // Part 1: forces deinit body to execute

    deinit {
        // Part 2: manually clean up via mutating path
        unsafe withUnsafePointer(to: _buffer) { ptr in
            unsafe UnsafeMutablePointer(mutating: ptr).pointee.remove.all()
        }
    }
}
```

**Applied to**: All types wrapping `Storage<Element>.Inline<capacity>` across package boundaries (21 types across 9 packages).

**Verification**: Experiment `noncopyable-nested-deinit-chain` Group B — V12/V14/V16 reproduce bug, V13/V15/V17 validate workaround.

**Tracking**: swiftlang/swift #86652

**Cross-references**: [MEM-COPY-001]

---

### [COPY-FIX-010] Module Boundary Solution

**Statement**: When same-file conformance placement isn't viable, split into separate SPM modules.

```text
Package/
├── Sources/
│   ├── Core/              # Type definitions only
│   ├── Sequence/          # Conformances (imports Core)
│   └── Public/            # Re-exports both
```

Module boundaries prevent constraint propagation because each target compiles independently.

**Applied in**: swift-array-primitives (Core + Sequence modules).

**Cross-references**: [MEM-COPY-006] Category 6, [COPY-FIX-004]

---

## Verification Tests

### [COPY-TEST-001] ~Copyable Element Test

```swift
struct Token: ~Copyable { let id: Int }

@Test func noncopyableElements() {
    var stack = Stack<Token>()
    stack.push(Token(id: 1))
    let popped = stack.pop()
    #expect(popped?.id == 1)
}
```

### [COPY-TEST-002] Conditional Copyable Test

```swift
@Test func conditionalCopyable() {
    var stack1 = Stack<Int>()
    stack1.push(1)
    let stack2 = stack1  // Copy
    stack1.push(2)
    #expect(stack1.count == 2)
    #expect(stack2.count == 1)  // CoW: independent
}
```

### [COPY-TEST-003] Sequence Conformance Test

```swift
@Test func sequenceConformance() {
    var stack = Stack<Int>()
    stack.push(1); stack.push(2); stack.push(3)
    let array = Array(stack)
    #expect(array == [1, 2, 3])
}
```

### [COPY-TEST-004] Deinit Verification Test

```swift
struct Element: ~Copyable {
    let id: Int
}

extension Element {
    struct Tracked: ~Copyable {
        let id: Int
        let tracker: Tracker
        deinit { tracker.append(id) }
    }
}

@Test func inlineDeinitOrder() {
    let tracker = Tracker()
    do {
        var container = Container<Element.Tracked>.Inline<4>()
        container.push(Element.Tracked(id: 0, tracker: tracker))
        container.push(Element.Tracked(id: 1, tracker: tracker))
    }
    #expect(!tracker.deinitOrder.isEmpty,
            "BUG: Elements leaked — apply [COPY-FIX-009] workaround")
}
```

---

## Common Mistakes

### Mistake 1: Forgetting Extension Constraints

```swift
// WRONG
extension Container { func operation() { } }
// RIGHT
extension Container where Element: ~Copyable { func operation() { } }
```

### Mistake 2: Storage at Wrong Nesting Level

```swift
// WRONG - Storage at Variant level
struct Container<Element: ~Copyable>: ~Copyable {
    struct Variant: ~Copyable {
        final class Storage: ManagedBuffer<Int, Element> { }  // FAILS
    }
}

// RIGHT - Storage at Container level
struct Container<Element: ~Copyable>: ~Copyable {
    final class Storage: ManagedBuffer<Int, Element> { }  // WORKS
    struct Variant: ~Copyable {
        var _storage: Container<Element>.Storage
    }
}
```

### Mistake 3: Conformance in Separate File

```swift
// WRONG - Causes poisoning
// File: Container+Sequence.swift
extension Container: Sequence where Element: Copyable { }

// RIGHT - Same file as type definition
// File: Container.swift
struct Container<Element: ~Copyable>: ~Copyable { ... }
extension Container: Sequence where Element: Copyable { }
```

### Mistake 4: Forgetting Pointer Update After CoW

```swift
// WRONG
mutating func makeUnique() {
    if !isKnownUniquelyReferenced(&_storage) {
        _storage = _storage.copy()
        // MISSING: _cachedPtr update
    }
}

// RIGHT
mutating func makeUnique() {
    if !isKnownUniquelyReferenced(&_storage) {
        _storage = _storage.copy()
        unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL
    }
}
```

### Mistake 5: Missing Workaround for @_rawLayout Deinit Bug

```swift
// WRONG - Elements will leak (compiler skips member destruction)
struct Container<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _buffer: Buffer<Element>.Ring.Inline<capacity>  // Uses @_rawLayout internally
    deinit {}  // Empty — relies on compiler to destroy _buffer
}

// RIGHT - Two-part workaround: AnyObject? + manual cleanup
struct Container<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _buffer: Buffer<Element>.Ring.Inline<capacity>
    var _deinitWorkaround: AnyObject? = nil  // Forces deinit body to execute

    deinit {
        // Manual cleanup via mutating path
        unsafe withUnsafePointer(to: _buffer) { ptr in
            unsafe UnsafeMutablePointer(mutating: ptr).pointee.remove.all()
        }
    }
}
```

### Mistake 6: Missing Constraint on Nested Type Extensions

```swift
// WRONG - Fails even though outer type has ~Copyable constraint
public enum Storage<Element: ~Copyable> {
    public final class Heap: ManagedBuffer<Header, Element> { }
}

extension Storage.Heap {
    public struct Header { ... }  // ERROR: type 'Element' does not conform to 'Copyable'
}

// RIGHT - Explicit constraint on nested type extension
extension Storage.Heap where Element: ~Copyable {
    public struct Header { ... }  // WORKS
}
```

The `where Element: ~Copyable` appears redundant since `Heap` only exists within `Storage<Element: ~Copyable>`, but Swift requires it.

---

## Remediation Workflow

### Phase 1: Analysis
1. Build and capture errors: `swift build 2>&1 | tee build-output.txt`
2. Complete pre-audit checklist [COPY-REM-002]
3. Categorize errors by failure category (1–6)

### Phase 2: Architecture Fixes
4. Fix nesting level issues [COPY-FIX-001]
5. Fix declaration site issues [COPY-FIX-002]
6. Add extension constraints [COPY-FIX-003]
7. Consolidate conditional conformances [COPY-FIX-004]

### Phase 3: Verification
8. `swift build && swift test`
9. Test with ~Copyable elements [COPY-TEST-001]
10. Test with Copyable elements [COPY-TEST-002], [COPY-TEST-003]
11. Verify deinit correctness [COPY-TEST-004]
12. Document workarounds per [PATTERN-016]

---

## Cross-References

See also:
- **memory** skill for core ~Copyable rules [MEM-COPY-*]
- **anti-patterns** skill for [PATTERN-016] conscious technical debt documentation
