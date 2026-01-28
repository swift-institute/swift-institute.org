# Memory Copyable

<!--
---
title: Memory Copyable
version: 1.0.0
last_updated: 2026-01-28
applies_to: [swift-primitives, swift-standards, swift-foundations]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Patterns and requirements for ~Copyable (noncopyable) types.

## Overview

This document defines patterns for implementing types that suppress the `Copyable` constraint.

---

## Core Rules

### [MEM-COPY-001] ~Copyable Declaration

**Statement**: Types that manage unique resources SHOULD be declared as `~Copyable`.

```swift
public struct UniqueHandle: ~Copyable {
    private var handle: Handle

    deinit {
        close(handle)
    }
}
```

---

### [MEM-COPY-002] Storage Nesting

**Statement**: Storage classes for ~Copyable types MUST be nested inside the type declaration, not in extensions.

**Correct**:
```swift
public struct Stack<Element: ~Copyable>: ~Copyable {
    // Storage nested inside Stack
    @usableFromInline
    final class Storage: ManagedBuffer<Int, Element> { }
}
```

**Incorrect**:
```swift
extension Stack {
    // Storage in extension loses ~Copyable context
    final class Storage: ManagedBuffer<Int, Element> { }  // FAILS
}
```

---

### [MEM-COPY-003] Module Boundary Pattern

**Statement**: Swift.Sequence conformances MUST stay in Core module to avoid constraint poisoning.

```
Package/
├── Sources/
│   ├── {Type} Primitives Core/       # Type + Swift.Sequence
│   ├── {Type} Primitives Sequence/   # Sequence.Protocol only
│   └── {Type} Primitives/            # Umbrella exports
```

---

## Techniques

### [MEM-COPY-010] Associated Type Workaround

For protocols with associated types that need ~Copyable element support, use phantom-typed indexes.

### [MEM-COPY-011] Two-World Separation

Maintain separate conformances for Copyable and ~Copyable paths when necessary.

---

## Topics

### Related
- <doc:Memory>
- <doc:Memory-Ownership>
- <doc:Copyable-Remediation>
