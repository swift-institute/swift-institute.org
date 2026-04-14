# Mathematical Foundations

@Metadata {
    @TitleHeading("Swift Institute")
}

Type-safe dimensional analysis, algebraic structures, and the type-system rationale behind the geometry stack.

## Overview

Swift's type system is strong enough to encode mathematical structure directly. The Primitives layer takes that seriously: coordinates, displacements, extents, rotations, and angles are distinct types rather than bare floating-point values, and the operations permitted between them follow the underlying algebra.

The goal is not mathematical purity for its own sake. The goal is that classes of error that would otherwise appear as subtle runtime bugs — mixing spaces, subtracting an extent from a coordinate, adding two positions — are caught at compile time, with no runtime cost.

## Type-safe dimensional analysis

The phantom-type pattern gives the compiler enough information to distinguish values that share a representation but not a meaning.

```swift
struct Tagged<Tag, Value> {
    var rawValue: Value
}

typealias PageX = Tagged<Coordinate.X<PageSpace>, Double>
typealias ScreenX = Tagged<Coordinate.X<ScreenSpace>, Double>

// Cannot add coordinates in different spaces
let combined = pageX + screenX  // Compile error
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

---

## Affine and vector structure

Position and displacement are modelled as distinct types because the operations permitted on them differ. Affine spaces have no canonical origin: you can subtract two points to get the displacement between them, you can add a displacement to a point to get another point, but you cannot add two points.

```swift
let p1: Point<2> = ...
let p2: Point<2> = ...

let v: Vector<2> = p1 - p2    // Point - Point = Vector
let p3 = p1 + v               // Point + Vector = Point
let invalid = p1 + p2         // Does not compile
```

Linear transformations compose via matrix multiplication. Affine transformations extend linear maps with translation. Rotations, scalings, and shears form subgroups of the affine group and are typed accordingly: `Rotation<N>`, `Scale<N>`, and `Shear<N>` live in the symmetry primitives and compose through type-preserving operators where possible.

The payoff is that a function signature announces its geometric contract. A `Rotation<2>` and a `Scale<2>` are different types; a function that takes one cannot silently accept the other.

---

## Algebraic structures as types

Several small but common algebraic concepts are given their own types, rather than being flattened into `Int` or a stringly-typed enum.

`Sign` is a three-valued sign classification: positive, negative, zero. It forms a monoid under multiplication, with `positive * negative = negative` and `zero * anything = zero`.

`Parity` is a two-valued classification: even, odd. It forms the Z₂ group under addition: `even + odd = odd`, `odd + odd = even`.

`Comparison` is a three-valued ordering: lessThan, equal, greaterThan. It models the trichotomy relation that standard library comparisons return.

The point is not that these structures are deep — they are not. The point is that a function returning `Sign` communicates more than a function returning `Int` with the convention that values are -1, 0, or 1, and the compiler can keep the meaning straight as the value flows through the program.

---

## Trigonometry across scalar types

Swift's `BinaryFloatingPoint` protocol does not provide `sin`, `cos`, or other transcendental operations, which forced earlier geometry code to duplicate logic across `Double` and `Float`. The Primitives layer introduces a capability protocol, `Numeric.Transcendental`, defined in `Numeric Primitives`, that describes the ability to perform transcendental operations independently of representation.

The protocol provides explicit requirements:

- Trigonometric: `_sin`, `_cos`, `_tan`, `_asin`, `_acos`, `_atan`, `_atan2`
- Hyperbolic: `_sinh`, `_cosh`, `_tanh`, `_asinh`, `_acosh`, `_atanh`
- Exponential and logarithmic: `_exp`, `_expm1`, `_exp2`, `_log`, `_log1p`, `_log2`, `_log10`
- Power and roots: `_pow`, `_sqrt`, `_cbrt`, `_hypot`

Conformances are provided in `Real Primitives` for `Double`, `Float`, and `Float16` (platform-conditional), all marked `@inlinable` for specialization.

The separation of concerns is:

- `BinaryFloatingPoint` describes representation (IEEE 754)
- `Numeric.Transcendental` describes capability (transcendental operations)

Call sites use protocol composition:

```swift
extension Tagged where
    Tag == Angle.Radian,
    RawValue: BinaryFloatingPoint & Numeric.Transcendental
{
    @inlinable
    public static func sin(of angle: Self) -> Scale<1, RawValue> {
        Scale(RawValue._sin(angle.rawValue))
    }
}
```

Geometric types such as `Rotation<N, T>`, `Arc<T>`, and `Ellipse<T>` are generic over the scalar type, with the appropriate constraint where transcendental operations are needed. Non-transcendental code uses `BinaryFloatingPoint` alone. Specialization in release builds eliminates the protocol overhead.
