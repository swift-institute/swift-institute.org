# Swift Primitives

@Metadata {
    @TitleHeading("Swift Institute")
}

The atomic building blocks of the ecosystem — types that standards require but do not define.

## Overview

Primitives are the irreducible substrate of the Swift Institute. They are Foundation-free, policy-free, and designed to be timeless. 130 packages cover the concepts that higher layers compose: algebra, geometry, memory, numerics, bits, collections, parsing, concurrency, time, text, kernel abstractions, and more.

The layer is published under the [swift-primitives](https://github.com/swift-primitives) organization. Every package follows the naming pattern `swift-{concept}-primitives` and publishes one or more Swift products under the same concept name (e.g., `Geometry Primitives`, `Clock Primitives`).

Primitives are uniformly Apache 2.0 licensed. Value here comes from ubiquity, not scarcity.

---

## Scope

Organized by domain:

### Algebraic structures

Affine, cardinal, field, group, linear, modular, monoid, ring, semiring — plus foundational types (`Parity`, `Either`, `Pair`, `Sign`, `Comparison`).

### Geometry and space

Dimensions, positions, regions, spaces, vectors, matrices, and symmetry groups. The geometry primitives make mathematical structure visible to the compiler.

### Memory and buffers

Arenas, inline storage, buffer rings, slots, pools, caches, and heaps. All `~Copyable`-aware; resources with unique ownership cannot be accidentally duplicated.

### Numerics

Integers, decimals, fractions, scalars, cardinals, ordinals, and random number generation.

### Bits and binary

Bit sets, bit masks, endianness, binary parsers and serializers, packed representations.

### Collections

Arrays (small, static, fixed, dynamic, bounded variants), sets, dictionaries, lists, queues, stacks, graphs, trees, slices, ranges.

### Parsing and serialization

Parser combinators, ASCII parsers and serializers, binary parsers, parser state machines.

### Concurrency

Channels, broadcasts, timers, waiters, continuations, executors, job priorities.

### Time

Typed time instants, durations, nanoseconds, femtoseconds. Continuous and suspending clock domains distinguish monotonic time that advances during sleep from monotonic time that pauses.

### Text

String primitives (`~Copyable`), ASCII, tokens, lexers, formatting.

### Kernel and platform

Cross-platform syscall vocabulary — file descriptors, sockets, memory, threads, events. See <doc:Platform> for how this layers across operating systems.

### Language infrastructure

Abstract syntax trees, symbols, intermediate representation, drivers, backends, loaders, modules.

---

## Type-system patterns

Primitives make extensive use of Swift 6 language features. Three patterns recur across the layer.

### Phantom types

Domain meaning encoded in zero-cost type parameters. The `Tagged<Tag, RawValue>` primitive gives arbitrary types a phantom distinction without runtime overhead.

```swift
import Clock_Primitives

// The two clock domains produce different instant types.
let continuous: Clock.Continuous.Instant = Clock.Continuous().now
let suspending: Clock.Suspending.Instant = Clock.Suspending().now

continuous - suspending  // Compile error — different clock domains.
```

### ~Copyable resources

Types with unique ownership that the compiler tracks. Copies are prevented at the type level; transfer is explicit via `consume`; borrowing is scoped.

```swift
// A file descriptor moves through the program; it cannot be duplicated.
struct Descriptor: ~Copyable, Sendable { ... }

let fd = try Descriptor.open(path)
consume fd  // Used exactly once. Compiler enforces.
```

### Typed throws

Every throwing function declares its concrete error type. Callers get exhaustive switches rather than catch-all blocks.

```swift
public static func accept(
    _ descriptor: borrowing Kernel.Socket.Descriptor
) throws(Kernel.Socket.Error) -> Kernel.Socket.Accept.Result
```

---

## Mathematical foundations

Swift's type system is strong enough to encode mathematical structure directly. The Primitives layer takes that seriously: coordinates, displacements, extents, rotations, and angles are distinct types rather than bare floating-point values. Classes of error that would otherwise appear as subtle runtime bugs are caught at compile time, with no runtime cost.

### Type-safe dimensional analysis

The phantom-type pattern gives the compiler enough information to distinguish values that share a representation but not a meaning.

```swift
typealias PageX = Tagged<Coordinate.X<PageSpace>, Double>
typealias ScreenX = Tagged<Coordinate.X<ScreenSpace>, Double>

// Cannot add coordinates in different spaces.
let combined = pageX + screenX  // Compile error.
```

The same pattern distinguishes kinds of value within a single space:

```swift
let width: Width = 10       // Extent (unsigned)
let dx: Dx = 5              // Displacement (signed)
let x: X = 2                // Coordinate (position)

let newX = x + dx           // Coordinate + Displacement = Coordinate
let distance = x1 - x2      // Coordinate - Coordinate = Displacement
let invalid = x + x         // Does not compile
```

The phantom types exist only at compile time. The runtime representation is a bare `Double`, specialization eliminates any protocol overhead, and the generated machine code is equivalent to hand-written arithmetic on raw floating-point values.

### Affine and vector structure

Position and displacement are modelled as distinct types because the operations permitted on them differ. Affine spaces have no canonical origin: you can subtract two points to get the displacement between them, you can add a displacement to a point to get another point, but you cannot add two points.

```swift
let p1: Point<2> = ...
let p2: Point<2> = ...

let v: Vector<2> = p1 - p2    // Point - Point = Vector
let p3 = p1 + v               // Point + Vector = Point
let invalid = p1 + p2         // Does not compile
```

Linear transformations compose via matrix multiplication. Affine transformations extend linear maps with translation. Rotations, scalings, and shears form subgroups of the affine group and are typed accordingly: `Rotation<N>`, `Scale<N>`, and `Shear<N>` live in the symmetry primitives and compose through type-preserving operators where possible.

### Algebraic structures as types

Several small but common algebraic concepts are given their own types, rather than being flattened into `Int` or a stringly-typed enum.

- `Sign` is a three-valued sign classification: positive, negative, zero. It forms a monoid under multiplication.
- `Parity` is a two-valued classification: even, odd. It forms the Z₂ group under addition.
- `Comparison` is a three-valued ordering: lessThan, equal, greaterThan. It models the trichotomy relation that standard library comparisons return.

The point is not that these structures are deep — they are not. The point is that a function returning `Sign` communicates more than a function returning `Int` with the convention that values are -1, 0, or 1, and the compiler can keep the meaning straight as the value flows through the program.

### Trigonometry across scalar types

Swift's `BinaryFloatingPoint` protocol does not provide `sin`, `cos`, or other transcendental operations, which forced earlier geometry code to duplicate logic across `Double` and `Float`. The Primitives layer introduces a capability protocol, `Numeric.Transcendental`, that describes the ability to perform transcendental operations independently of representation.

- `BinaryFloatingPoint` describes representation (IEEE 754).
- `Numeric.Transcendental` describes capability (transcendental operations).

Conformances are provided in `Real Primitives` for `Double`, `Float`, and `Float16` (platform-conditional), all marked `@inlinable` for specialization. Geometric types such as `Rotation<N, T>`, `Arc<T>`, and `Ellipse<T>` are generic over the scalar type, with the appropriate constraint where transcendental operations are needed. Specialization in release builds eliminates the protocol overhead.

---

## Foundation independence

Primitives do not import Foundation. The layer provides its own timestamps, paths, data buffers, and string processing. The same types compile on every Swift target; see <doc:Platform>.
