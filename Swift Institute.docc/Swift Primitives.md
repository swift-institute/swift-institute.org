# Swift Primitives

@Metadata {
    @TitleHeading("Swift Institute")
}

The atomic building blocks of the ecosystem — types that standards require but do not define.

## Overview

Primitives are the irreducible substrate of the Swift Institute. They are Foundation-free, policy-free, and designed to be timeless. The layer covers the concepts that higher layers compose: algebra, geometry, memory, numerics, bits, collections, parsing, concurrency, time, text, and kernel abstractions.

Packages at this layer are published under the [swift-primitives](https://github.com/swift-primitives) organization. Every package follows the naming pattern `swift-{concept}-primitives` and publishes one or more Swift products under the same concept name.

---

## Type-system patterns

Primitives make extensive use of Swift 6 language features. Three patterns recur across the layer.

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

### ~Copyable resources

Types with unique ownership that the compiler tracks. Copies are prevented at the type level; transfer is explicit via `consume`; borrowing is scoped. The layer uses this extensively for resources that must have exactly one owner — file descriptors, kernel handles, connection state, channel endpoints.

### Typed throws

Throwing functions declare their concrete error type. Callers get exhaustive switches rather than catch-all blocks, and the error type becomes part of the API contract.

---

## Foundation independence

Primitives do not import Foundation. The layer provides its own timestamps, paths, data buffers, and string processing. The same types are designed to compile on every Swift target; see <doc:Platform>.
