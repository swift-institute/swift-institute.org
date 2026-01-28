# Pattern: Concurrency

<!--
---
title: Pattern Concurrency
version: 1.0.0
last_updated: 2026-01-21
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Patterns for async coordination, continuations, and Sendable composition.

## Overview

> This document answers: "What patterns govern async coordination, continuations, and Sendable composition?"

This document defines implementation patterns for Swift concurrency: continuation safety, inout-across-await hazards, and type erasure interactions with Sendable.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## [PATTERN-020] Never Resume Under Lock

**Scope**: Async coordination primitives using continuations and locks.

**Statement**: Continuations MUST NOT be resumed while holding a lock. The pattern is: collect resumption thunks under lock, release lock, then execute resumptions.

**Correct**:
```swift
// Collect resumptions under lock, execute after
func complete(with value: T) {
    let resumptions: [Async.Waiter.Resumption]
    lock.withLock {
        resumptions = waiters.drain().map { $0.resumption }
        state = .completed(value)
    }
    // Lock released - now safe to resume
    for resumption in resumptions {
        resumption.resume()
    }
}
```

**Incorrect**:
```swift
// Resuming under lock
func complete(with value: T) {
    lock.withLock {
        for waiter in waiters.drain() {
            waiter.continuation.resume(returning: value)  // DANGER
        }
    }
}
```

**Rationale**: Deferred resumption keeps user code out of critical sections, making deadlock impossible by construction.

**Cross-references**: [PATTERN-014], [PATTERN-016], [API-CONC-001]

---

## [PATTERN-022] Inout-Across-Await Hazard

**Scope**: Async methods accessing mutable state through `_modify` accessors.

**Statement**: When an async method accesses mutable state through a `_modify` accessor, the exclusivity check operates within a single execution context—it does NOT prevent concurrent access from different tasks.

This hazard reinforces why [API-CONC-005] requires conservative Sendable defaults.

**Example hazard**:
```swift
// This looks safe but isn't
actor Container {
    var items: [Item] = []

    func process() async {
        // _modify accessor opens here
        items.append(await fetchItem())  // Suspension point!
        // Another task could access items during the await
    }
}
```

**Mitigation**: Use local copies across suspension points, or restructure to avoid inout access across await.

**Cross-references**: [API-CONC-005], [PATTERN-020]

---

## [PATTERN-025] Type Erasure vs Sendable Tension

**Scope**: Heterogeneous storage and type erasure in Swift 6 with strict concurrency.

**Statement**: Type erasure mechanisms (raw pointers, `Unmanaged`, unsafe bitcasts) predate Swift Concurrency and are explicitly non-Sendable in Swift 6. When type erasure is required for heterogeneous storage, the composition with Sendable-requiring primitives creates an architectural tension that MUST be resolved explicitly.

### Resolution Approaches

| Approach | Trade-off |
|----------|-----------|
| **Sendable wrapper** (`Reference.Pointer`) | Encapsulates unsafety in one place |
| **Accept limitation** | Some compositions aren't possible without unsafe opt-in |
| **`@unchecked Sendable`** at use site | Makes unsafety visible but scattered |

**Example**:
```swift
// Type-erased storage needs to be Sendable for use with actors
final class AnyStorage: @unchecked Sendable {
    private var pointer: UnsafeMutableRawPointer

    // Explicit synchronization makes @unchecked Sendable justified
    private let lock = Lock()

    func withValue<T, R>(_ body: (inout T) -> R) -> R {
        lock.withLock {
            body(&pointer.assumingMemoryBound(to: T.self).pointee)
        }
    }
}
```

**Cross-references**: [API-CONC-005], [PATTERN-021]

---

## Topics

### Related Documents

- <doc:API-Concurrency>
- <doc:Memory-Sendable>
- <doc:Implementation-Patterns>
