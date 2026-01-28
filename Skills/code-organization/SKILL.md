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
