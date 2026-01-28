# Code Organization

<!--
---
title: Code Organization
version: 1.0.0
last_updated: 2026-01-28
applies_to: [swift-primitives, swift-standards, swift-foundations]
normative: true
---
-->

@Metadata {
    @TitleHeading("Implementation")
}

Code organization and file structure requirements for all Swift Institute packages.

## Overview

This document defines how code should be organized within packages, including file naming, type placement, and extension patterns.

---

## File Structure

### [API-IMPL-005] One Type Per File

**Scope**: All Swift source files.

**Statement**: Each `.swift` file MUST contain exactly one type declaration.

**Correct**:
```
File.Directory.Walk.swift     → contains File.Directory.Walk
File.Directory.Walk.Options.swift → contains File.Directory.Walk.Options
```

**Incorrect**:
```swift
// File: Models.swift
struct User { }      // Multiple types
struct Profile { }   // in one file
```

**Rationale**: Single-type files enable:
- Precise file naming that matches type hierarchy
- Easier navigation via file system
- Clear ownership and reduced merge conflicts
- Consistent organization across packages

---

### [API-IMPL-006] File Naming

**Scope**: All Swift source files.

**Statement**: File names MUST match the type's full nested path with dots separating components.

**Correct**:
```
Array.Dynamic.swift
Array.Dynamic.Iterator.swift
Set.Ordered.Element.swift
```

**Incorrect**:
```
DynamicArray.swift           // Compound name
ArrayDynamicIterator.swift   // No dot separation
```

---

### [API-IMPL-007] Extension Files

**Scope**: Extensions to types defined elsewhere.

**Statement**: Extensions MUST use `+` suffix pattern: `TypeName+Protocol.swift`

**Correct**:
```
Array.Dynamic+Sequence.swift
Set.Ordered+Hashable.swift
```

---

## State Modeling

### [API-IMPL-003] Enum Over Boolean

**Scope**: All state representation.

**Statement**: Use enums instead of boolean flags when state can expand.

**Correct**:
```swift
enum Connection {
    enum State {
        case disconnected
        case connecting
        case connected(Session)
        case disconnecting
    }
}
```

**Incorrect**:
```swift
var isConnected: Bool
var isConnecting: Bool
```

---

## Topics

### Related
- <doc:Naming>
- <doc:Design>
- <doc:Layering>
