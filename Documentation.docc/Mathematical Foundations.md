# Mathematical Foundations

@Metadata {
    @TitleHeading("Swift Institute")
}

Type-safe dimensional analysis, category theory, algebraic structures, and trigonometry.

## Type-Safe Dimensional Analysis

Swift Primitives implements **dimensional analysis at compile time** through phantom types. This technique, common in scientific computing but rare in application frameworks, prevents entire categories of errors:

```swift
// Phantom type tags (zero runtime overhead)
struct Tagged<Tag, Value> {
    var rawValue: Value
}

// Type-safe coordinates in different spaces
typealias PageX = Tagged<Coordinate.X<PageSpace>, Double>
typealias ScreenX = Tagged<Coordinate.X<ScreenSpace>, Double>

// Compile-time error: cannot add coordinates in different spaces
let combined = pageX + screenX  // ❌ Type error

// Type-safe dimensional arithmetic
let width: Width = 10       // Extent (unsigned)
let dx: Dx = 5              // Displacement (signed)
let x: X = 2                // Coordinate (position)

let newX = x + dx           // ✅ Coordinate + Displacement = Coordinate
let distance = x1 - x2      // ✅ Coordinate - Coordinate = Displacement
let invalid = x + x         // ❌ Coordinate + Coordinate = undefined
```

This system enforces dimensional correctness without runtime overhead. The phantom types (`PageSpace`, `ScreenSpace`) exist only at compile time; the runtime representation is a bare `Double`.

---

## Category-Theoretic Organization

The Swift Institute organizes mathematical abstractions along category-theoretic lines:

**Category Vect**: Vector spaces and linear maps
- Objects: `Vector<N>` parameterized by dimension
- Morphisms: `Matrix<M,N>` as linear transformations
- Identity: Identity matrix
- Composition: Matrix multiplication

**Category Aff**: Affine spaces and affine maps
- Objects: `Affine.Point<N>` (positions without canonical origin)
- Morphisms: `Affine.Transform` (linear + translation)
- Key property: Points cannot be added (no origin); subtraction yields vectors

**Lie Groups**: Symmetry operations on Euclidean space
- `Rotation<N>` ∈ SO(n): Special orthogonal group
- `Scale<N>` ∈ (ℝ⁺)ⁿ: Positive diagonal matrices
- `Shear<N>`: Off-diagonal unipotent transformations
- Composition generates GL⁺(n), the general linear group with positive determinant

This organization is not merely aesthetic—it guides the API design:

```swift
// Affine arithmetic enforces geometric correctness
let p1: Point<2> = ...
let p2: Point<2> = ...
let v: Vector<2> = p1 - p2    // ✅ Point - Point = Vector

let p3 = p1 + v               // ✅ Point + Vector = Point
let invalid = p1 + p2         // ❌ Point + Point = undefined (no origin)
```

---

## Algebraic Structures as Types

Swift Primitives models algebraic structures as enumerated types with semantic operations:

**Sign**: Three-valued sign classification {positive, negative, zero}
- Monoid under multiplication
- `positive × negative = negative`
- `zero × anything = zero`
- Models Z₃ semigroup structure

**Parity**: Binary parity classification {even, odd}
- Z₂ group under addition
- `even + odd = odd`
- `odd + odd = even`
- Partitions ℤ/2ℤ

**Comparison**: Three-valued ordering {lessThan, equal, greaterThan}
- Trichotomy relation
- Standard ordering result type

These types replace stringly-typed enumerations with semantically meaningful structures. A function returning `Sign` communicates more than a function returning `Int` with values -1, 0, 1.

---

## The Trigonometry Solution

Swift's `BinaryFloatingPoint` protocol lacks `sin`, `cos`, `tan`, and other transcendental operations. This historically forced duplication across Double/Float extension pairs. Swift Primitives solves this with the `Numeric.Transcendental` protocol.

### The Protocol

`Numeric.Transcendental` (defined in `Numeric Primitives`) is a **capability marker** that describes the ability to perform transcendental operations, independent of numeric representation. It provides explicit requirements:
- Trigonometric: `_sin`, `_cos`, `_tan`, `_asin`, `_acos`, `_atan`, `_atan2`
- Hyperbolic: `_sinh`, `_cosh`, `_tanh`, `_asinh`, `_acosh`, `_atanh`
- Exponential/Logarithmic: `_exp`, `_expm1`, `_exp2`, `_log`, `_log1p`, `_log2`, `_log10`
- Power: `_pow`, `_sqrt`, `_cbrt`, `_hypot`

Conformances are provided in `Real Primitives` for `Double`, `Float`, and `Float16` (platform-conditional), all marked `@inlinable` for specialization.

### Principled Composition

The design separates concerns:
- `BinaryFloatingPoint` describes **representation** (IEEE 754)
- `Numeric.Transcendental` describes **capability** (transcendental operations)

Call sites use protocol composition: `BinaryFloatingPoint & Numeric.Transcendental`

### Generic Geometry Achieved

With this approach, geometric types are now fully generic:

```swift
extension Tagged where Tag == Angle.Radian, RawValue: BinaryFloatingPoint & Numeric.Transcendental {
    @inlinable
    public static func sin(of angle: Self) -> Scale<1, RawValue> {
        Scale(RawValue._sin(angle.rawValue))
    }
}
```

The protocol is deployed across the stack:
- **swift-dimension-primitives**: `Radian+Trigonometry.swift` — fully generic
- **swift-symmetry-primitives**: `Rotation.swift` — 2D rotations generic over scalar type
- **swift-affine-primitives**: Polar coordinates, angle computation
- **swift-algebra-linear-primitives**: Vector angles, polar coordinates
- **swift-geometry-primitives**: Arc, Ball, Bezier, Ellipse, Path — all generic

### Hybrid Approach

The implementation combines two strategies:
- Non-trigonometric operations use `BinaryFloatingPoint` constraints (standard library protocol)
- Trigonometric operations use `BinaryFloatingPoint & Numeric.Transcendental` constraints

This achieves the design goal: `Rotation<N,T>`, `Arc<T>`, `Ellipse<T>`, and other geometric types work with any conforming floating-point type, with specialization eliminating protocol overhead in optimized builds.

