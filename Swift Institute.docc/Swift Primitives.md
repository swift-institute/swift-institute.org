# Swift Primitives

@Metadata {
    @TitleHeading("Swift Institute")
}

The atomic building blocks of the ecosystem — types that standards require but do not define.

## Overview

Primitives are the irreducible substrate of the Swift Institute. They are Foundation-free, policy-free, and designed to be timeless. The layer covers the foundational concepts that higher layers compose: algebra, geometry, memory, collections, concurrency, parsing, time, and kernel abstractions.

Packages at this layer are published under the [swift-primitives](https://github.com/swift-primitives) organization. Every package follows the naming pattern `swift-{concept}-primitives` and publishes one or more Swift products under the same concept name.

---

## Type-system patterns

Primitives make extensive use of Swift 6 language features. Two patterns recur across the layer.

### Phantom types

Domain meaning encoded in zero-cost type parameters. A `Tagged<Tag, RawValue>` wrapper gives arbitrary types a phantom distinction without runtime overhead.

```swift
// Two tagged types over the same underlying representation
// become type-distinct through their phantom tags.
enum Timer {}
enum Session {}

let timer: Tagged<Timer, UInt64> = ...
let session: Tagged<Session, UInt64> = ...

timer == session  // Compile error — different phantom tags.
```

The tags exist only at compile time. Runtime representation and code generation are identical to the raw type.

### Latest Swift language features

The layer strives to adopt the latest Swift language features — `~Copyable` and `~Escapable` for ownership and lifetime, `consume`/`borrowing`/`sending` for transfer semantics, region isolation and `nonisolated(nonsending)` for concurrency, typed throws for error domains, coroutine accessors (`_read`, `_modify`, `nonmutating _modify`) for interior mutability, and strict memory safety — so invariants are enforced by the compiler rather than deferred to runtime checks.

Every invariant expressible in the type system is expressed there: a resource with exactly-once lifecycle uses `~Copyable`; a view that must not outlive its source uses `~Escapable`; a value crossing an isolation boundary uses `sending`; a throwing function declares its concrete error type so callers get exhaustive switches.

---

## Foundation independence

Primitives do not import Foundation. The layer provides its own timestamps, paths, data buffers, and string processing. The same types are designed to compile on every Swift target; see <doc:Platform>.
