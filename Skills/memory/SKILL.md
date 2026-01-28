---
name: memory
description: |
  Memory ownership, copyability, and lifetime safety rules.
  ALWAYS apply when working with ~Copyable types or ownership annotations.

layer: implementation

requires:
  - swift-institute
  - naming
  - errors

applies_to:
  - swift
  - swift6
  - primitives

migrated_from: Documentation.docc/Memory Copyable.md
migration_date: 2026-01-28
---

# Memory Conventions

Rules for ownership, copyability, and memory safety.

---

## ~Copyable Types

### [MEM-COPY-001] When to Use ~Copyable

Types that manage unique resources SHOULD be declared as `~Copyable`.

```swift
public struct UniqueHandle: ~Copyable {
    private var handle: Handle

    deinit {
        close(handle)
    }
}
```

---

### [MEM-COPY-002] Storage Nesting Rule

Storage classes for ~Copyable types MUST be nested inside the type body, NOT in extensions.

```swift
// CORRECT - Storage inside body
public struct Stack<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    final class Storage: ManagedBuffer<Int, Element> { }
}

// INCORRECT - Storage in extension loses context
extension Stack {
    final class Storage: ManagedBuffer<Int, Element> { }  // FAILS
}
```

**Rationale**: Extensions lose the ~Copyable constraint propagation from the outer type's generic parameter.

---

### [MEM-COPY-003] Module Split for Sequence

`Swift.Sequence` requires `Element: Copyable`. Split modules:

```
Package/
├── {Type} Primitives Core/       # Type + Swift.Sequence (Copyable)
├── {Type} Primitives Sequence/   # Sequence.Protocol (~Copyable)
└── {Type} Primitives/            # Umbrella exports
```

---

## Bug Workarounds

### [COPY-FIX-001] Nested Type Declaration Site

Nested types in extensions don't inherit outer type's generic constraints.

**Fix**: Declare ALL variant types inside the struct/enum body:

```swift
public enum Set<Element: ~Copyable>: ~Copyable {
    // All variants in body
    public struct Ordered: ~Copyable { }
    public struct Bounded: ~Copyable { }
}
```

---

### [COPY-FIX-002] Value Generic Deinit Bug

When using `InlineArray<capacity, Element>` with value generics and only value-type properties, deinitializers may not be called.

**Tracking**: https://github.com/swiftlang/swift/issues/86652

**Workaround**: Add a reference-type property:

```swift
struct Inline<let capacity: Int>: ~Copyable {
    var _elements: InlineArray<capacity, Element>
    var _deinitWorkaround: AnyObject? = nil  // Forces correct dispatch
}
```

---

## Ownership Annotations

### [MEM-OWN-001] Borrowing for Read-Only

Use `borrowing` for read-only access to ~Copyable values.

```swift
func process(_ value: borrowing Resource) {
    // Can read but not consume
}
```

---

### [MEM-OWN-002] Consuming for Ownership Transfer

Use `consuming` when taking ownership.

```swift
func takeOwnership(_ value: consuming Resource) {
    // Now owns the value
}
```

---

## Cross-References

See also:
- **primitives** skill for ~Copyable collection patterns
- **code-organization** skill for file structure
