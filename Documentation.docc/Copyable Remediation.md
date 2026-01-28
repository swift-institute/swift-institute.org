# Copyable Remediation

<!--
---
title: Copyable Remediation
version: 1.0.0
last_updated: 2026-01-28
applies_to: [swift-primitives, swift-standards, swift-foundations]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Workarounds for known ~Copyable/Copyable compiler issues.

## Overview

This document catalogs known issues and their workarounds when implementing ~Copyable types.

---

## Storage and Nesting

### [COPY-FIX-001] Storage Class Location

**Problem**: Storage classes in extensions lose ~Copyable constraint propagation.

**Fix**: Declare storage classes inside the type body:

```swift
public struct Stack<Element: ~Copyable>: ~Copyable {
    // CORRECT: Storage inside body
    final class Storage: ManagedBuffer<Int, Element> { }
}
```

---

### [COPY-FIX-002] Nested Type Declaration Site

**Problem**: Nested types in extensions don't inherit outer type's generic constraints.

**Fix**: Declare ALL variant types inside the struct/enum body:

```swift
public enum Set<Element: ~Copyable>: ~Copyable {
    // All variants in body
    public struct Ordered: ~Copyable { }
    public struct Bounded: ~Copyable { }
}
```

---

## InlineArray Issues

### [COPY-FIX-003] Value Generic Deinit Bug

**Problem**: When using `InlineArray<capacity, Element>` with value generic capacity and only value-type properties, deinitializers may not be called for cross-module ~Copyable elements.

**Tracking**: https://github.com/swiftlang/swift/issues/86652

**Workaround**: Add a reference-type property:

```swift
struct Inline<let capacity: Int>: ~Copyable {
    var _elements: InlineArray<capacity, Element>
    var _deinitWorkaround: AnyObject? = nil  // Forces correct dispatch
}
```

---

## Sequence Conformance

### [COPY-FIX-004] Sequence Poisoning

**Problem**: Swift.Sequence requires `Element: Copyable`, poisoning ~Copyable types.

**Fix**: Keep Swift.Sequence in Core module, use custom Sequence.Protocol for ~Copyable-compatible iteration.

---

## Topics

### Related
- <doc:Memory-Copyable>
- <doc:Memory-Ownership>
