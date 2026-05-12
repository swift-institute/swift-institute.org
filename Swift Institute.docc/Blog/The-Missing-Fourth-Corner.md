# The missing fourth corner: why swift-coproduct-primitives can't ship today

@Metadata {
  @TitleHeading("Swift Institute Blog")
  @PageImage(purpose: card, source: "blog-card", alt: "Swift Institute Blog")
}

<doc:Introducing-Pair-Either-Product-Primitives> introduced three small types: `Pair` for two values together, `Either` for one of two alternatives, and `Product` for an arbitrary number of values together. It is the two-by-two of typed composition, except for one detail: it isn't a two-by-two yet. There is a fourth corner the launch post did not mention. This post is about what that corner is, why we'd want it, and why the natural Swift shape for it does not compile in 2026-05.

## The 2×2 you didn't see

|                | binary    | n-ary                                |
|----------------|-----------|--------------------------------------|
| **product**    | `Pair`    | `Product`                            |
| **coproduct**  | `Either`  | `Coproduct` *(this post — deferred)* |

A product holds *both* arms; a coproduct holds *one of* the arms. `Pair` is the binary product; `Either` is the binary coproduct. `Product<each Element>` extends `Pair` to arbitrary arity over a parameter pack. The fourth corner is the matching extension of `Either` — an n-ary coproduct, `Coproduct<each Element>`, that holds exactly one value out of N typed arms.

## What you'd reach for it for

Coproducts are not catalogue-completeness types. There are five concrete consumer cases that need them and that nested `Either` does not adequately serve:

1. **Multi-cause typed throws on the input side.** A function that throws *one of* N errors — not all of them aggregated — wants a typed coproduct in its `throws` clause:
   ```swift
   func parse() throws(Coproduct<Lex.Error, Parse.Error, Validation.Error>) -> AST { ... }
   ```
   `Product<each E>` covers the dual case (multi-cause aggregation, all causes present). `Coproduct<each E>` would cover this case (one cause at a time, typed).

2. **Parser combinator alternatives.** A combinator branching across N typed productions, each with a different result type. Right-associated `Either<A, Either<B, Either<C, D>>>` is technically expressible, but the result-type computation infects every consumer.

3. **State machine output.** A machine where each step emits one of N typed events — UI machines emitting mouse/keyboard/system/window-state events; protocol machines emitting one of several typed frames.

4. **Pipeline stage dispatch.** Each stage emits one of N typed results consumed by the next stage's match.

5. **DSL AST node sums.** A node that can be one of N typed sub-nodes. Today's DSLs hand-roll an enum per AST. A first-class `Coproduct<Statement, Expression, Declaration, ...>` would replace the boilerplate.

These are real shapes. They show up across ecosystems. None of them is one-off; each has multiple independent consumers. The package would not be a primitive added for catalogue neatness — it solves a real problem.

## The shape that almost works

If you sit down and try to write the n-ary coproduct in Swift, the type that comes out of your fingers is something like:

```swift
public enum Coproduct<each Element>: ~Copyable {
    case at<i>(each Element)
}
```

You declare an enum, parameterise it over a pack, and let each pack position be its own case. The eliminator is the obvious n-ary `fold`: one closure per arm, the matching closure runs.

The compiler refuses on the first line. Verbatim from `include/swift/AST/DiagnosticsSema.def` on `swiftlang/swift` upstream `main`:

```
ERROR(enum_with_pack,none,
      "enums cannot declare a type pack", ())
```

The associated test, at `test/Generics/variadic_generic_types.swift:7`, is comment-explicit:

```swift
// Temporary limitations
enum EnumWithPack<each T> { // expected-error {{enums cannot declare a type pack}}
  case cheddar
}
```

The header is the most quietly important word in the file: *temporary*. The limitation is a known gap, not a deliberate design choice. But "temporary" does not come with a date, and the diagnostic has been in force in the Swift compiler for as long as parameter packs have shipped. As of `2026-05-10` the diagnostic is still in place; no commits since 2026-01-01 touch the string `enum_with_pack` or the test file; no open pull requests address it; no Swift Evolution proposal — through SE-0528, the most recently published — addresses it; no feature flag in `Features.def` gates it. The "temporary" is real, but the timeline is not.

So the natural enum shape doesn't compile. What can we reach for instead?

## You can compose `Either`, but you don't want to

The shape that *does* compile today is the right-associated nested `Either`:

```swift
typealias Op = Either<Lex.Error, Either<Parse.Error, Validation.Error>>
```

This works. It type-checks. The pattern-match for it is where you'd stop:

```swift
switch op {
case .left(let lex):
    ...
case .right(.left(let parse)):
    ...
case .right(.right(let validation)):
    ...
}
```

For arity 3, this is *acceptable*. For arity 4 you are at three levels of `.right(.right(.left(...)))` to reach the third arm. For arity 5 you are at four. The pattern-match depth scales linearly with arity, and the position of an arm is implicit in how many times you typed `.right` before the `.left`. A reader counting `.right`s to find the arm they care about is the API failing.

There are tools that smooth this — balanced trees rather than right-associated chains, pattern-match macros that flatten the nesting — but they layer on top of `Either` rather than express the shape directly. The honest answer for arity ≥ 4 is that nested `Either` is not the right tool, and Swift does not currently let us express the right tool.

## What the third-party prior art does, and the cost

There is a third-party package that ships an n-ary coproduct in Swift today: [`Genaro-Chris/SwiftUtils.Variant`][variant]. Reading the implementation is informative — it shows exactly which trade-offs the institute would have to make to ship under current language constraints.

`Variant<each Item>` is a `~Copyable` struct with two stored fields: a `Builtin.RawPointer` for the active value and an `Int` tag for which pack position is active. Construction takes an `init(with: consuming T) throws`. At runtime it iterates the pack via `for meta in repeat ((each Item).self)`, finds the position whose metatype matches `T`, allocates a buffer sized for the largest type in the pack (`max(byteCount)` and `max(alignment)` over the pack), and stores the value into the raw pointer. The eliminator (`visit(_ closures: repeat (inout each Item) -> Result)`) iterates the pack at runtime to find the active position and dispatches to the matching closure.

The package solves a real problem. It also pays four costs that the institute's typed-correctness convention does not accept:

- **`Builtin.RawPointer` is a compiler-internal API**, not part of public Swift. The institute would not import `Builtin` into a primitives package.
- **`init(with:)` throws.** Constructing a `Variant<Int, String>` with a value of type `Int` is fallible at runtime — if Swift's runtime metatype matching can't find `Int` in the pack, you get an error. The point of a typed sum type is *compile-time* dispatch; pushing it to runtime defeats the type system's role. Compare `Either<Int, String>.left(42)` — pure compile-time, no init failure path.
- **`fatalError("Unreachable")` and `preconditionFailure` appear several times** in the eliminator paths. These are runtime traps where typed throws or compile-time exhaustiveness would otherwise serve.
- **`~Copyable` arms are explicitly unsupported.** A comment at the top of the file: *"Because of some limitations a generic parameter pack cannot have noncopyable type therefore Variant can not contain noncopyable types."* This is the same wall `Product<each Element>` hits today.

The institute's `Pair` and `Either` admit `~Copyable` arms; their move-only-resource transport story is the reason the binary cases ship as their own types. A `Coproduct` that doesn't admit `~Copyable` arms isn't the institute's analog of `Either` — it is a strictly weaker type that would force consumers carrying move-only values to revert to nested `Either`. That's not the contract we want to ship.

## Even if one wall lifted, there's a second

Suppose the `enum_with_pack` diagnostic disappeared tomorrow and Swift admitted parameter-pack enum cases. The natural shape — `enum Coproduct<each Element: ~Copyable> { case at<i>(each Element) }` — would still not compile. The reason is in a different test fixture, `test/Generics/inverse_copyable_requirement_errors.swift`:

```swift
func packingUniqueHeat_1<each T: ~Copyable>(_ t: repeat each T) {}
// expected-error: cannot suppress '~Copyable' on type 'each T'
// expected-note: 'where each T: Copyable' is implicit here
```

Pack `each T` requirements implicitly carry `Copyable`. Suppressing it (`each T: ~Copyable`) is rejected with a compile error. The same applies to `~Escapable`. Lifting this is the second blocker.

`Product<each Element>` has been hitting this wall since its 2026-05-11 launch — its own [`Research/escapable-blocked.md`][product-blocker] documents the same diagnostic in the same shape. `Coproduct` would inherit the same constraint. The cohort precedent is clear: when `Pair` shipped with full `~Copyable` and `~Escapable` arms (binary case, no pack involved) and `Product` shipped without them, the institute waited rather than ship a `Product` that quietly stripped move-only support out of consumer code.

`Coproduct` follows the `Product` precedent: defer until the language can express the natural shape.

## Why we're not shipping a workaround

Three implementable shapes are available today, each sacrificing something:

| Shape                                       | What it is                                                                                            | What it sacrifices                                                                                       |
|---------------------------------------------|-------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| **Per-arity types** (`Coproduct2..N`)       | A separate enum per arity, mirroring F#'s `Choice<T1..T7>`                                            | Bounded arity; `Coproduct.N` Nest.Name compounds; consumers hit the ceiling and revert to nesting        |
| **Generic struct + `Builtin.RawPointer`**   | One type with runtime tag + raw-pointer storage; runtime metatype dispatch (the Variant approach)     | `Builtin.RawPointer` is compiler-internal; throwing init defeats compile-time correctness; runtime traps |
| **Generic struct + tag + tuple-of-Optionals** | One type with `(repeat (each Element)?)` storage, exactly one non-nil at a time                       | O(arity) wasted space; storage erases the "exactly one" invariant                                        |

None of these is the perfect-future shape. All three encode the absent language feature with workarounds whose costs would be paid by every future consumer. The institute precedent — laid down by `Pair` (which waited and shipped clean) and reinforced by `Product` (which is shipping with documented gaps and a `Research/escapable-blocked.md` pointer to the unblock) — is to wait for the language rather than ship a vocabulary the future will have to migrate off of.

The migration cost of waiting is real and bounded: today, no consumer has *blocked work* on `Coproduct` — every named use case has a hand-rolled enum filling in. The migration cost of shipping a workaround is unbounded: every adopter would carry forward the workaround's vocabulary into call sites that future readers would have to recognise as historical.

## What we are watching for

We are watching the Swift compiler for two specific lifts: parameter-pack enum cases (so the natural shape compiles), and pack `~Copyable` / `~Escapable` admission (so move-only and non-escapable arms are admitted). When either lands — even just the first — `Coproduct<each Element>` becomes implementable in the natural shape, and we ship the package. Until then it remains unwritten.

## Closing

The institute composition cohort that landed on Monday is three corners of a 2×2. The fourth corner is real, has named consumers, and has a natural Swift shape. That shape does not compile in 2026-05. We are choosing to wait rather than ship a workaround we'd later have to migrate consumers off of. When the Swift language admits the missing pieces, this post gets a follow-up.

In the meantime: nest `Either` for arity 3 if you have to, and hand-roll an enum for arity ≥ 4.

## Links

- Launch post: <doc:Introducing-Pair-Either-Product-Primitives>
- Third-party prior art: [`Genaro-Chris/SwiftUtils.Variant`][variant]
- `Product`'s parallel blocker: [`Research/escapable-blocked.md`][product-blocker]

[variant]: https://github.com/Genaro-Chris/SwiftUtils/blob/main/Sources/SwiftUtils/Variant.swift
[product-blocker]: https://github.com/swift-primitives/swift-product-primitives/blob/main/Research/escapable-blocked.md
