# Swift Primitives

@Metadata {
    @TitleHeading("Swift Institute")
}

The atomic building blocks of the ecosystem — types that standards require but do not define.

## Overview

Primitives are the irreducible substrate of the Swift Institute. They are Foundation-free, policy-free, and designed to be timeless. The layer covers the foundational concepts that higher layers compose: algebra, geometry, memory, collections, concurrency, parsing, time, and kernel abstractions.

Packages at this layer are published under the [swift-primitives](https://github.com/swift-primitives) organization. Every package follows the naming pattern `swift-{concept}-primitives` and publishes one or more Swift products under the same concept name.

---

## Foundation independence

Primitives do not import Foundation. The layer provides its own timestamps, paths, data buffers, and string processing. The same types are designed to compile on every Swift target; see the <doc:FAQ> for the current platform matrix.
