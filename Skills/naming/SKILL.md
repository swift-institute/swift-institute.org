---
name: naming
description: |
  API naming conventions: namespace structure, nested accessors, specification-mirroring.
  ALWAYS apply when declaring types, methods, or properties.

layer: implementation

requires:
  - swift-institute

applies_to:
  - swift
  - swift6
  - primitives
  - standards
  - foundations

migrated_from: Implementation/Naming.md
migration_date: 2026-01-28
---

# Naming Conventions

All types, methods, and properties MUST follow these naming rules.

---

## Namespace Structure

### [API-NAME-001] Nest.Name Pattern

All types MUST use the `Nest.Name` pattern. Compound type names are FORBIDDEN.

```swift
// CORRECT
File.Directory.Walk
IO.NonBlocking.Selector
RFC_4122.UUID

// INCORRECT
FileDirectoryWalk      // Compound name - FORBIDDEN
DirectoryWalk          // Compound name - FORBIDDEN
NonBlockingSelector    // Compound name - FORBIDDEN
```

**Rationale**: Nested types create natural namespaces, improve discoverability via autocomplete, and prevent naming collisions.

---

### [API-NAME-002] No Compound Identifiers

Methods and properties MUST NOT use compound names. Use nested accessors.

```swift
// CORRECT
instance.open.write { }
dir.walk.files()

// INCORRECT
instance.openWrite { }  // Compound method - FORBIDDEN
dir.walkFiles()         // Compound method - FORBIDDEN
```

**Rationale**: Nested accessors mirror the nested type philosophy and enable progressive disclosure.

---

### [API-NAME-003] Specification-Mirroring Names

Types implementing specifications MUST mirror the specification terminology.

```swift
// CORRECT
RFC_4122.UUID
ISO_32000.Page
RFC_3986.URI

// INCORRECT
UUID        // No specification context
PDFPage     // Compound, no spec namespace
URL         // No specification context
```

**Rationale**: Specification-mirroring names provide traceability and prevent naming drift.

---

## File Naming

### [API-NAME-004] File Names Match Types

File names MUST match the type's full nested path with dots separating components.

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

### [API-NAME-005] Extension File Naming

Extensions use `+` suffix pattern: `TypeName+Protocol.swift`

```
// CORRECT
Array.Dynamic+Sequence.swift
Set.Ordered+Hashable.swift
```

---

## Cross-References

See also:
- **errors** skill for error type naming
- **code-organization** skill for file structure
