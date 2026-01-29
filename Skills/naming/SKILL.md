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

**Semantic rule**: In `Nest.Name`, the Nest is the broader domain and Name is the specific concept within it. Read `A.B.C` as "C within B within A" — each level narrows the scope.

| Path | Reading | Hierarchy |
|------|---------|-----------|
| `File.Directory.Walk` | A walk operation, for directories, in the file domain | Domain → Subdomain → Operation |
| `IO.NonBlocking.Selector` | A selector, for non-blocking I/O, in the IO domain | Domain → Variant → Type |
| `Memory.Address.Offset` | An offset, for addresses, in the memory domain | Domain → Concept → Aspect |

**Decision test**: If you can say "X is a kind of Y" or "X belongs to Y", then Y nests X.

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

## Cross-References

See also:
- **errors** skill for error type naming
- **code-organization** skill for file naming and structure
