# API Concurrency

<!--
---
title: API Concurrency
version: 1.0.0
last_updated: 2026-01-19
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Modern Swift concurrency: async, actors, executors, cancellation, and Sendable defaults.

## Overview

This document defines concurrency requirements for Swift Institute packages.

**Applies to**: All concurrent code including async functions, actors, and multi-threaded operations.

**Does not apply to**: Synchronous-only utility packages or pure data types without shared state.

---

## [API-CONC-001] Modern Swift Concurrency

**Scope**: All concurrent implementations.

**Statement**: MUST use Swift concurrency primitives:
- `async` / structured concurrency
- Actors where isolation is required
- Explicit executors where determinism or performance requires it

MUST NOT introduce ad-hoc threading models when structured concurrency suffices.

**Rationale**: Swift concurrency provides compile-time safety guarantees that ad-hoc threading cannot.

**Cross-references**: [API-CONC-002], [API-CONC-003]

---

## [API-CONC-002] Executor and Thread Topology

**Scope**: APIs with thread affinity requirements.

**Statement**:
- APIs promising "pinned execution" MUST use an explicit executor and document it clearly.
- Cross-thread delivery MUST go through explicit bridges or queues.
- Resumption MUST be exactly-once.

**Rationale**: Explicit executor control prevents accidental thread-safety violations.

**Cross-references**: [API-CONC-001], [API-CONC-003]

---

## [API-CONC-003] Single Resumption Funnel Invariant

**Scope**: All suspended operations.

**Statement**:
- Each suspended operation MUST have exactly one resumption path.
- All resumptions MUST funnel through a single, explicit component (actor, executor, or state machine).
- Cancellation handlers MUST NOT resume continuations directly.
- Cancellation MAY only synchronously record intent or enqueue work to the resumption funnel.

This invariant guarantees:
- Exactly-once resume
- Consistent lifecycle precedence
- Absence of double-resume races

**Rationale**: Single resumption funnel eliminates an entire class of concurrency bugs.

**Cross-references**: [API-CONC-002], [API-CONC-004]

---

## [API-CONC-004] Cancellation and Shutdown Invariants

**Scope**: All cancellable and shutdownable operations.

**Statement**:
- Cancellation MUST NOT cause hangs.
- Shutdown MUST be explicit and reject new work deterministically.
- All outstanding work MUST be drained or rejected with a typed lifecycle error.

**Rationale**: Predictable cancellation and shutdown behavior is essential for resource management.

**Cross-references**: [API-ERR-002], [API-CONC-003]

---

## [API-CONC-005] Conservative Sendable Defaults

**Scope**: Mutable reference wrappers and types that cross concurrency domains.

**Statement**: General-purpose mutable reference wrappers MUST NOT be unconditionally `@unchecked Sendable` unless they provide synchronization or actor isolation by construction. The default MUST be conservative (Sendable only when wrapped value is Sendable), with explicit opt-in for unsafe escapes.

> **Full details**: See <doc:Memory> sections [MEM-SEND-001], [MEM-SEND-002], and [MEM-SEND-003].

**The "Pit of Success" Principle**:

| Path | Experience |
|------|------------|
| Default (safe) | `Reference.Indirect<T>` - no ceremony required |
| Unsafe escape | `Reference.Indirect<T>.Unchecked` - name declares intent |

**Rationale**: Swift Concurrency uses `Sendable` as the type-system marker for preventing data races. Making a mutable reference type unconditionally `@unchecked Sendable` removes the compiler's primary guardrail.

**Cross-references**: [API-CONC-001], [API-CONC-004], [API-IMPL-010], <doc:Memory>

---

## [API-CONC-006] Two-API Pattern for Sync and Async Ownership

**Scope**: APIs that accept buffers or resources in both synchronous and asynchronous variants.

**Statement**: Sync and async APIs operating on the same resource MUST have different shapes reflecting their different ownership semantics. Attempting to unify them adds overhead to sync or breaks async.

#### Why the Shapes Must Differ

| World | Ownership | Reason |
|-------|-----------|--------|
| **Sync** | Borrows | Data never leaves the call stack. The caller's buffer remains valid throughout the operation. |
| **Async** | Transfers | Thread boundaries are crossed. The buffer must survive until the I/O thread finishes—potentially long after the caller returns. |

**Correct**:
```swift
// SYNC: Borrows buffer - zero-copy, scoped to call
extension File.Write {
    public static func atomic(
        _ bytes: borrowing Span<UInt8>,
        to path: borrowing File.Path
    ) throws(Error)
}

// ASYNC: Transfers ownership - buffer moves to I/O thread and back
extension File.Write {
    public static func atomic<B: Binary.Mutable & Sendable>(
        consuming buffer: consuming B,
        to path: File.Path
    ) async throws(Error)
}
```

**Incorrect**:
```swift
// ❌ Unified shape forces unnecessary copies
extension File.Write {
    public static func atomic(
        _ bytes: [UInt8],  // Forces allocation even for sync
        to path: File.Path
    ) async throws(Error)
}

// ❌ Attempting to borrow across async boundary
extension File.Write {
    public static func atomic(
        _ bytes: borrowing Span<UInt8>,  // Dangling reference!
        to path: File.Path
    ) async throws(Error)
}
```

#### Ownership Transfer for Async

Use `Reference.Transfer` types to move `~Copyable` values across async boundaries:

```swift
let forwardCell = Reference.Transfer.Cell(buffer)
let forwardToken = forwardCell.token()
let returnStorage = Reference.Transfer.Storage<(B, Int)>()
let returnToken = returnStorage.token

try await IO.run {
    var buffer = forwardToken.take()  // Ownership arrives on I/O thread
    let count = try read(from: path, into: &buffer)
    returnToken.store((buffer, count))  // Ownership returns
}

return returnStorage.take()  // Caller receives buffer back
```

The buffer moves to the I/O thread, gets filled, and moves back. True zero-copy ownership transfer across async boundaries.

**Rationale**: The two-API shape isn't inconsistency; it's architecturally correct. Borrowing works for sync because the borrow scope encompasses the entire operation. Async operations span thread boundaries—borrows cannot survive this transition. Each shape optimally serves its concurrency model.

**Cross-references**: [API-CONC-001], [PATTERN-047], [MEM-REF-002], [MEM-REF-003]

---

## Techniques

**Applies to**: Practical implementation of concurrency patterns.

---

### [API-CONC-010] Never Resume Under Lock

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

**Cross-references**: [API-CONC-003], [MEM-LINEAR-001]

---

### [API-CONC-011] Inout-Across-Await Hazard

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

**Cross-references**: [API-CONC-005], [API-CONC-010]

---

### [API-CONC-012] Type Erasure vs Sendable Tension

**Scope**: Heterogeneous storage and type erasure in Swift 6 with strict concurrency.

**Statement**: Type erasure mechanisms (raw pointers, `Unmanaged`, unsafe bitcasts) predate Swift Concurrency and are explicitly non-Sendable in Swift 6. When type erasure is required for heterogeneous storage, the composition with Sendable-requiring primitives creates an architectural tension that MUST be resolved explicitly.

#### Resolution Approaches

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

**Cross-references**: [API-CONC-005], [MEM-SEND-001]

---

## Summary Table

| Requirement | Focus | Key Constraint |
|-------------|-------|----------------|
| API-CONC-001 | Concurrency model | Use Swift concurrency, not ad-hoc threading |
| API-CONC-002 | Executor topology | Explicit executors, exactly-once resumption |
| API-CONC-003 | Resumption funnel | Single path, no direct cancellation resume |
| API-CONC-004 | Cancellation/shutdown | No hangs, typed lifecycle errors |
| API-CONC-005 | Sendable defaults | Conservative by default, explicit escape |
| API-CONC-006 | Sync/async ownership | Different shapes for different ownership models |
| API-CONC-010 | Lock-free resumption | Never resume continuations under lock |
| API-CONC-011 | Inout-await hazard | Exclusivity doesn't cross suspension points |
| API-CONC-012 | Type erasure tension | Explicit resolution for Sendable composition |

---

## Topics

### Related Documents

- <doc:API-Requirements>
- <doc:Memory>
- <doc:Memory-Sendable>
