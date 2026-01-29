---
name: code-organization
description: |
  Code organization: one type per file, extension patterns, state modeling.
  ALWAYS apply when creating or organizing Swift source files.

layer: implementation

requires:
  - swift-institute
  - naming
  - errors

applies_to:
  - swift
  - swift6
  - primitives
  - standards
  - foundations

migrated_from: Implementation/Code Organization.md
migration_date: 2026-01-28
---

# Code Organization Conventions

All source files MUST follow these organization rules.

---

## File Structure

### [API-IMPL-005] One Type Per File

Each `.swift` file MUST contain exactly one type declaration.

```
// CORRECT
File.Directory.Walk.swift     → contains File.Directory.Walk
File.Directory.Walk.Options.swift → contains File.Directory.Walk.Options

// INCORRECT
// File: Models.swift
struct User { }      // Multiple types - FORBIDDEN
struct Profile { }   // in one file - FORBIDDEN
```

**Rationale**: Single-type files enable precise naming, easier navigation, clear ownership, and reduced merge conflicts.

---

### [API-IMPL-006] File Naming Convention

File names MUST match the type's full nested path with dots.

```
// CORRECT
Array.Dynamic.swift
Array.Dynamic.Iterator.swift
Set.Ordered.Element.swift

// INCORRECT
DynamicArray.swift           // Compound name
ArrayDynamicIterator.swift   // No dot separation
```

---

### [API-IMPL-007] Extension Files

Extensions MUST use `+` suffix pattern.

```
// CORRECT
Array.Dynamic+Sequence.swift
Set.Ordered+Hashable.swift

// File contains:
extension Array.Dynamic: Sequence { ... }
```

---

### [API-IMPL-008] Minimal Type Body

Type declarations MUST contain only stored properties and the canonical initializer. Everything else MUST be in extensions.

```swift
// CORRECT
public struct Buffer {
    @usableFromInline
    var storage: Storage

    @usableFromInline
    var count: Int

    @inlinable
    public init() {
        self.storage = Storage()
        self.count = 0
    }
}

extension Buffer {
    public var isEmpty: Bool { count == 0 }

    public mutating func append(_ element: Element) { ... }
}

extension Buffer: Sequence {
    public func makeIterator() -> Iterator { ... }
}

// INCORRECT — methods in type body
public struct Buffer {
    var storage: Storage
    var count: Int

    public init() { ... }

    public var isEmpty: Bool { count == 0 }  // ❌ Should be in extension

    public mutating func append(_ element: Element) { ... }  // ❌ Should be in extension
}
```

**What belongs in the type body**:
- Stored instance properties
- Canonical initializer(s)
- `deinit` (for classes and ~Copyable types)

**What belongs in extensions**:
- Computed properties
- Methods
- Protocol conformances
- Static members
- Nested types (with exception below)

**Exception for ~Copyable types**: Per [MEM-COPY-006], types with `~Copyable` generic parameters MAY include in the body:
- Nested storage types (e.g., `ManagedBuffer` subclasses)
- Nested types referencing the `~Copyable` parameter

This avoids constraint poisoning. Conditional conformances MUST still be in the same file.

```swift
// ~Copyable exception — nested Storage in body
public struct Container<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    final class Storage: ManagedBuffer<Int, Element> { }  // ✓ OK in body

    @usableFromInline
    var storage: Storage

    @inlinable
    public init() { ... }
}

// Conformances in same file, as extensions
extension Container: Copyable where Element: Copyable { }
extension Container: Sendable where Element: Sendable { }
```

**Rationale**: Minimal bodies make storage layout immediately visible, separate stable data from evolving behavior, and simplify code review.

**Research**: [minimal-type-declaration-pattern.md](../../Research/minimal-type-declaration-pattern.md)

---

## State Modeling

### [API-IMPL-003] Enum Over Boolean

Use enums instead of boolean flags when state can expand.

```swift
// CORRECT
enum Connection {
    enum State {
        case disconnected
        case connecting
        case connected(Session)
        case disconnecting
    }
}

// INCORRECT
var isConnected: Bool     // Cannot represent connecting/disconnecting
var isConnecting: Bool    // Requires multiple booleans
```

---

## Cross-References

See also:
- **naming** skill for file naming rules
- **memory** skill for ~Copyable type organization
