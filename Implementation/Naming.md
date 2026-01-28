# Naming

<!--
---
title: Naming
version: 1.0.0
last_updated: 2026-01-28
applies_to: [swift-primitives, swift-standards, swift-foundations]
normative: true
---
-->

@Metadata {
    @TitleHeading("Implementation")
}

API naming conventions for all Swift Institute packages.

## Overview

This document defines the naming rules that MUST be followed across all Swift Institute packages. These rules ensure consistency, discoverability, and alignment with Swift's nested type philosophy.

---

## Namespace Structure

### [API-NAME-001] Namespace Structure

**Scope**: All type declarations.

**Statement**: All types MUST use the `Nest.Name` pattern. Compound type names are forbidden.

**Correct**:
```swift
File.Directory.Walk
IO.NonBlocking.Selector
RFC_4122.UUID
```

**Incorrect**:
```swift
FileDirectoryWalk      // Compound name
DirectoryWalk          // Compound name
NonBlockingSelector    // Compound name
```

**Rationale**: Nested types create natural namespaces, improve discoverability via autocomplete, and prevent naming collisions across packages.

---

### [API-NAME-002] No Compound Identifiers

**Scope**: All methods and properties.

**Statement**: Methods and properties MUST NOT use compound names. Use nested accessors.

**Correct**:
```swift
instance.open.write { }
dir.walk.files()
```

**Incorrect**:
```swift
instance.openWrite { }  // Compound method
dir.walkFiles()         // Compound method
```

**Rationale**: Nested accessors mirror the nested type philosophy and enable progressive disclosure of API surface.

---

### [API-NAME-003] Specification-Mirroring Names

**Scope**: All types implementing external specifications.

**Statement**: Types implementing specifications MUST mirror the specification terminology.

**Correct**:
```swift
RFC_4122.UUID
ISO_32000.Page
RFC_3986.URI
```

**Incorrect**:
```swift
UUID        // No specification context
PDFPage     // Compound, no spec namespace
URL         // No specification context
```

**Rationale**: Specification-mirroring names provide traceability to authoritative sources and prevent naming drift.

---

## Topics

### Essentials
- <doc:Code-Organization>
- <doc:Design>

### Related
- <doc:Errors>
- <doc:Layering>
