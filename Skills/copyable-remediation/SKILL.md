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
| `InlineArray<capacity, ...>` with value generic | Runtime | [COPY-FIX-009] |

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

**Statement**: Nested types referencing the outer type's `~Copyable` parameter MUST be declared in the struct/enum body, NOT in extensions.

```swift
// CORRECT - In body
public struct Container<Element: ~Copyable>: ~Copyable {
    public struct Variant: ~Copyable {
        var storage: UnsafeMutablePointer<Element>  // Works
    }
}

// INCORRECT - In extension
extension Container {
    public struct Variant: ~Copyable {
        var storage: UnsafeMutablePointer<Element>  // FAILS
    }
}
```

**Exception**: Nested types that don't reference `Element` can remain in extensions.

**Cross-references**: [MEM-COPY-006] Category 1

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

---

### [COPY-FIX-009] InlineArray + Value Generic Deinit Bug

**Statement**: When a `~Copyable` struct uses `InlineArray<capacity, ...>` with a value generic parameter and only value-type properties, element deinitializers silently fail for cross-module elements.

**All four conditions must be present**:

| # | Condition |
|---|-----------|
| 1 | `InlineArray<capacity, ...>` where `capacity` is value generic |
| 2 | Value-only struct (no reference type properties) |
| 3 | Cross-module boundary |
| 4 | deinit with manual cleanup |

**Workaround**: Add a reference type property:

```swift
struct Container<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
    var _count: Int
    var _deinitWorkaround: AnyObject? = nil  // Forces correct dispatch
}
```

**Affected packages**: swift-deque-primitives, swift-queue-primitives, swift-stack-primitives (all fixed).

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
struct TrackedElement: ~Copyable {
    let id: Int
    let tracker: Tracker
    deinit { tracker.append(id) }
}

@Test func inlineDeinitOrder() {
    let tracker = Tracker()
    do {
        var container = Container<TrackedElement>.Inline<4>()
        container.push(TrackedElement(0, tracker: tracker))
        container.push(TrackedElement(1, tracker: tracker))
    }
    #expect(!tracker.deinitOrder.isEmpty,
            "BUG: Elements leaked — apply [COPY-FIX-009] workaround")
}
```

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
