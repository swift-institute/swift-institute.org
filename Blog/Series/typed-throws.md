# Typed throws in Swift

## Series thesis

Typed throws turns error handling from a binary distinction — throws or doesn't — into a type-level spectrum. Each part of this series is a necessary step in that argument: Part 1 establishes *why* the spectrum matters by showing what erasure costs you. Part 2 defines *what* the spectrum is and where it holds. Part 3 shows *where* the spectrum meets the current ecosystem and how to work within it.

## Arc

Error handling in Swift has always forced a trade-off: the precision of typed errors against the ergonomics of `try`/`catch`. SE-0413 introduced `throws(E)` to resolve that tension. This series follows the resolution from first principles — through return values, `Result`, and untyped `throws` — to the spectrum that typed throws provides. Part 1 arrives at typed throws as a practical synthesis, introducing leaf error types that model each domain independently. Part 2 reveals typed throws as a structured spectrum of throwing function types, then shows where that model meets real boundaries. Part 3 applies the model to stdlib integration, shows where friction remains, and provides a decision framework for adoption today.

The conceptual model (Parts 1–2) is evergreen. The ecosystem compatibility details (Part 3) reflect Swift 6.2 and will evolve as the standard library adopts `throws(E)` signatures.

## Parts

### Part 1: Error handling from first principles

**Promise**: Establishes *why* typed throws matters — by showing what every alternative loses.

- **Opens with**: Compressed bookend — the ideal typed-throws code with `Port.Error` (leaf), then "Swift didn't always let us write this"
- **Builds through**: Sentinel values → `Result` (with leaf errors, showing `.mapError` cost) → untyped `throws` (linear but erases domains), each approach failing on its own terms
- **Casting stance**: Shows that `as?` casting *works*, then dismantles it: runtime recovery of compile-time info, silent breakage, forced dead code, no exhaustiveness guarantee
- **Builds to**: Typed throws as the practical synthesis — type-safe errors with `try`/`catch` syntax, leaf error composition via `Service.Error`
- **Running example**: Port parsing progresses through return values → `Result` → untyped `throws` → typed `throws(Port.Error)` on `Port.init`. `Retries` + `Service.Error` show composition.
- **Ends with**: "What is the relationship between non-throwing, `throws(E)`, and `throws`? And when you pass a typed-throwing closure to a higher-order function, does the error type survive?"
- **Source ideas**: BLOG-IDEA-013, BLOG-IDEA-030

### Part 2: The throwing spectrum

**Promise**: Defines *what* the spectrum is — `throws(Never)` → `throws(E)` → `throws(any Error)` — and where it holds.

- **Opens with**: "Typed throws does more than attach an error enum to a function. It turns 'throwing' from a binary distinction into a spectrum."
- **Act 1 — The spectrum**: The throwing spectrum as a function-type relationship: `throws(Never)` → `throws(E)` → `throws`. `rethrows` reinterpreted as part of a broader model. The `<E: Error> throws(E)` pattern and how `Never` makes non-throwing a special case.
- **Act 2 — Where the model works** (short, stabilizing): Function signatures, implementation-site dot syntax, catch-site exhaustiveness. Confirmation that the model works where the language has full control.
- **Act 3 — Where the model meets boundaries**: Passing typed-throwing closures (inference widening), higher-order functions, protocol conformance covariance (`throws` → `throws(E)` narrowing works). The friction: closures erase, conformances can narrow but downstream APIs may not cooperate.
- **Supporting material** (brief, subordinate to spectrum thesis): Error type design — leaf errors vs god errors, hoisted vs generic-nested. Compressed treatment; the spectrum is the main event.
- **Running example**: `Port.init` in closures (`map` with/without annotation), `Port` conforming to `Parseable` protocol (covariance demo).
- **Builds to**: The subtyping chain means typed throws is opt-in at every boundary — you narrow where it helps and widen where it doesn't
- **Ends with**: "The model is elegant. The ecosystem doesn't always preserve it."
- **Source ideas**: BLOG-IDEA-013

### Part 3: Typed throws in practice

**Promise**: Shows *where* the spectrum meets the current ecosystem — what works, what doesn't, and how to decide.

- **Opens with**: Picks up from Part 2 — the model is sound, now let's use it with the standard library
- **Builds through**:
  - stdlib partial support: `map` works with explicit closure annotation, but `compactMap`, `filter`, `reduce` etc. still erase via `rethrows`
  - Show the actual stdlib source — `rethrows` predates typed throws and can't preserve `E`
  - Protocol-mandated throws: Codable (over a hundred untyped conformances), Clock conformances — focus on operational cost, not re-explaining covariance from Part 2
  - Workarounds: do/catch wrapping for protocol conformances, explicit closure annotations
- **Running example**: `Port.init` in `strings.map { }` (typed vs inferred), `parseConfiguration` as leaf composition (same function from Part 1, now a workaround pattern).
- **Builds to**: A decision framework: use typed throws at your API boundaries, accept untyped at stdlib boundaries, annotate closures explicitly
- **Ends with**: What's coming — `FullTypedThrows` experimental feature, stdlib evolution. Measured tone: direction is clear, timeline is not.
- **Ecosystem scoping**: All compatibility claims scoped to Swift 6.2. This part will date; the decision framework is the durable contribution.
- **Source ideas**: BLOG-IDEA-030

## Target audience

Swift developers who use `throws` and `do`/`try`/`catch` regularly but haven't adopted typed throws (`throws(E)`). Intermediate to advanced Swift developers building libraries or applications with meaningful error handling.

## Entry assumptions

**Assumed**: Familiarity with Swift error handling — `do`/`try`/`catch`, the `Error` protocol, `Result<T, E>`. Basic understanding of generics and protocols.

**Not assumed**: Knowledge of SE-0413 (typed throws), the `throws(E)` syntax, or the subtyping relationship between throwing and non-throwing functions.

## Shared example

A `Service.Configuration` parser that converts string key-value pairs into a typed configuration struct. Each parsing domain has its own value type and leaf error type — `Port` with `Port.Error`, `Retries` with `Retries.Error` — and a composed `Service.Error` that wraps the leaves. The example starts minimal in Part 1 (a single `Port` type with a throwing init) and evolves across the series:

- **Part 1**: Port parsing progresses through return values → `Result` → untyped `throws` → typed `throws(Port.Error)` on `Port.init`, demonstrating the trade-offs at each stage. `Retries` with `Retries.Error` shows composition costs with different error types. `Service.Error` composes the leaves.
- **Part 2**: `Port.init` appears in closures (demonstrating closure annotation and inference) and `Port` conforms to a `Parseable` protocol (demonstrating throws covariance on conformances). Error type design explored: leaf models vs god errors, hoisted vs generic-nested.
- **Part 3**: `Port.init` integrates with stdlib functions (`map`, `compactMap`) — revealing which stdlib higher-order functions preserve typed throws and which erase them via `rethrows`.

## Error modeling stance

Leaf error types that model a single domain are preferred over "god" error types that accumulate cases across domains. Each operation defines only the error cases it can produce. Composition happens explicitly — parent operations wrap leaf errors in cases that name the domain (`Service.Error.port(Port.Error)`). Type nesting carries semantic meaning: `Port.Error.invalid` reads as "invalid port" without encoding "port" in the case name.

## References

- [SE-0413: Typed throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md)
- [Research: Typed throws standards inventory](../Research/typed-throws-standards-inventory.md)
- [Experiment: Typed throws protocol conformance](../../swift-standards/Experiments/typed-throws-protocol-conformance/)
- [FullTypedThrows feature flag](https://github.com/swiftlang/swift/blob/main/include/swift/Basic/Features.def)
