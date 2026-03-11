<!--
---
id: BLOG-IDEA-030
title: "Typed throws in Swift, part 3: typed throws in practice"
slug: typed-throws-part-3
category: Technical Deep Dive
series: typed-throws
series_part: 3
series_title: Typed throws in Swift
date_drafted: 2026-03-11
date_published:
author:
source_artifacts:
  - swift-institute/Research/typed-throws-standards-inventory.md
  - swift-standards/Experiments/typed-throws-protocol-conformance/
tags:
  - swift
  - error-handling
  - typed-throws
---
-->

# Typed throws in Swift, part 3: typed throws in practice

The model is sound. `throws(E)` gives us a spectrum from `throws(Never)` to `throws(any Error)`, with subtyping at every level. Part 2 showed where the model works — signatures, catch sites, protocol conformance covariance — and where it meets boundaries — closure inference, generic callers.

Now let's use it with the standard library. Everything in this post reflects Swift 6.2 — the compatibility landscape will change as the stdlib adopts typed throws signatures.

## The map test

Part 1's `Port.init` declared `throws(Port.Error)`. Part 2 showed that closure inference can erase that type. Now let's see exactly what happens with the simplest higher-order function. Given a list of port strings, parse each one:

```swift
let strings = ["8080", "443", "hello"]
```

With an explicit closure annotation, `map` preserves the typed throw:

```swift
let ports = try strings.map { (s: String) throws(Port.Error) -> Port in
    try Port(s)
}
```

The `map` call throws `Port.Error`. The catch site gets a typed error. This works because the explicit annotation tells the compiler exactly which error type the closure throws.

Now try the natural spelling:

```swift
let ports = try strings.map { try Port($0) }
```

The error type widens to `any Error`. The compiler infers the closure as `(String) throws -> Port` — untyped — even though `Port.init` declares `throws(Port.Error)`. The annotation is required to preserve the type.

Verbose, but it works.

## Where `rethrows` falls short

Try the same pattern with `compactMap`:

```swift
let ports = try strings.compactMap {
    (s: String) throws(Port.Error) -> Port? in
    try Port(s)
}
```

This compiles, but the error type is erased. Even with the explicit `throws(Port.Error)` annotation, `compactMap` treats the call as untyped — the catch site sees `any Error`, not `Port.Error`. The function is declared with `rethrows`, which doesn't preserve the generic error type `E`.

The same is true for `filter`, `reduce`, `forEach`, `contains(where:)`, `allSatisfy`, `first(where:)`, `sorted(by:)`, `min(by:)`, `max(by:)`, `drop(while:)`, and `prefix(while:)`.

Here's what works and what doesn't as of Swift 6.2 (based on our [typed throws standards inventory](/research/typed-throws-standards-inventory)):

| Function | Typed throws | Notes |
|----------|:---:|-------|
| `Sequence.map` | yes | Explicit closure annotation required |
| `withUnsafeBytes(of:)` | yes | Explicit closure annotation required |
| `Mutex.withLock` | yes | Explicit closure annotation required |
| `compactMap` | no | `rethrows` erases `E` |
| `flatMap` | no | `rethrows` erases `E` |
| `filter` | no | `rethrows` erases `E` |
| `forEach` | no | `rethrows` erases `E` |
| `reduce` | no | `rethrows` erases `E` |
| `contains(where:)` | no | `rethrows` erases `E` |
| `sorted(by:)` | no | `rethrows` erases `E` |

The pattern: most `rethrows` functions in the standard library don't preserve typed throws. `map` is the exception, not the rule.

### Why the difference?

The stdlib's `rethrows` predates typed throws. When `compactMap` was written, the only question was "does the closure throw?" — binary. The `rethrows` mechanism was designed around that binary distinction.

To preserve `E`, a function needs to be generic over the error type:

```swift
// Preserves E:
func map<T, E: Error>(
    _ transform: (Element) throws(E) -> T
) throws(E) -> [T]

// Erases E:
func compactMap<T>(
    _ transform: (Element) throws -> T?
) rethrows -> [T]
```

The first signature carries `E` through. The second doesn't — it accepts `throws` (untyped) and `rethrows`, losing whatever specific error type the closure had.

Updating these signatures is an additive, non-breaking change. `throws(E)` is a subtype of `throws`, so existing callers continue to compile. But it requires changes to the standard library — function by function.

## Protocol-mandated throws

Some protocols require untyped `throws` in their conformance points. Part 2 showed that conformance covariance *allows* narrowing — a conformer can declare `throws(E)` where the protocol says `throws`. The question is whether it's *worth it*.

### Codable

`Codable` declares `init(from decoder: any Decoder) throws` and `func encode(to encoder: any Encoder) throws`. You *can* narrow to `throws(DecodingError)`. The compiler accepts the conformance. But every `Decoder` and `container` method uses untyped `throws`, so the body requires wrapping:

```swift
init(from decoder: any Decoder) throws(DecodingError) {
    do {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(Int.self)
    } catch let error as DecodingError {
        throw error
    } catch {
        preconditionFailure(
            "Decoder contract violation: \(type(of: error))"
        )
    }
}
```

The wrapping works, but the cost is high:

- **Soundness is questionable**: custom `Decoder` implementations *could* throw non-`DecodingError` types, hitting the `preconditionFailure`.
- **Scale**: across a real codebase, this is dozens or hundreds of conformances.
- **Benefit is limited**: generic callers go through the protocol witness — untyped `throws` — so only concrete callers see the typed error.

In our standards library, 122 Codable conformances use untyped `throws`. We don't convert them. The cost-to-benefit ratio is unfavorable.

### Clock

`_Concurrency.Clock` declares:

```swift
protocol Clock {
    func sleep(
        until deadline: Instant, tolerance: Duration?
    ) async throws
}
```

The conformer can narrow to `throws(CancellationError)`:

```swift
func sleep(
    until deadline: Instant, tolerance: Duration?
) async throws(CancellationError) {
    do {
        try await Task.sleep(for: deadline.offset)
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        preconditionFailure(
            "Task.sleep contract violation: \(type(of: error))"
        )
    }
}
```

This is more defensible than Codable. `Task.sleep` genuinely only throws `CancellationError` per the stdlib source. The `preconditionFailure` catch-all is sound — no third-party variation exists. And there are only 2 instances to convert, not 122.

## Workarounds

Three patterns help bridge the gap between typed throws and the current standard library.

### Explicit closure annotation

For stdlib functions that support it (`map`, `withUnsafeBytes`, `Mutex.withLock`):

```swift
let ports = try strings.map { (s: String) throws(Port.Error) -> Port in
    try Port(s)
}
```

Verbose, but preserves the error type end-to-end.

### do/catch wrapping for protocol conformances

For protocol conformances where the downstream APIs use untyped `throws`:

```swift
func sleep(
    until deadline: Instant, tolerance: Duration?
) async throws(CancellationError) {
    do {
        try await Task.sleep(for: deadline.offset)
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        preconditionFailure("...")
    }
}
```

Use this sparingly — it's defensible when the error contract is well-known (like `CancellationError`), but questionable at scale (like Codable).

### Leaf error composition

For your own APIs — like Part 1's `parseConfiguration` — compose typed-throwing initializers with explicit wrapping:

```swift
func parseConfiguration(
    _ dict: [String: String]
) throws(Service.Error) -> Service.Configuration {
    guard let host = dict["host"] else {
        throw .missing("host")
    }
    let port: Port
    do {
        port = try Port(dict["port"] ?? "")
    } catch {
        throw .port(error)
    }
    let retries: Retries
    do {
        retries = try Retries(dict["max_retries"] ?? "")
    } catch {
        throw .retries(error)
    }
    return Service.Configuration(
        host: host, port: port, maxRetries: retries
    )
}
```

Each `do`/`catch` wraps a leaf error into the parent domain. The compiler knows the type at every boundary.

## A decision framework

Where should you use typed throws today?

**Use typed throws** at your own API boundaries:
- Functions you control on both sides (caller and callee)
- Domain error types where callers match exhaustively
- Leaf error types that compose into parent domains

**Accept untyped throws** at stdlib and protocol boundaries:
- Codable conformances (122 untyped calls per codebase)
- Higher-order functions that don't preserve `E` (`compactMap`, `filter`, etc.)
- Protocol conformances where generic callers won't benefit

**Annotate closures explicitly** when passing to stdlib functions that support it:
- `map` with `throws(E)` annotation
- `withUnsafeBytes` with `throws(E)` annotation
- `Mutex.withLock` with `throws(E)` annotation

The spectrum from Part 2 gives you the model. This framework tells you where to apply it: narrow where you control the boundary, widen where you don't.

## What's coming

The friction in this post is a gap between what the language can express and what the standard library currently uses. The direction is clear; the timeline is not.

The Swift compiler has a `FullTypedThrows` experimental feature that makes closure inference and `do`/`catch` blocks preserve the error type automatically. When enabled, `{ try Port($0) }` would infer `throws(Port.Error)` instead of `throws(any Error)`. The explicit annotation would become optional, not required. As of Swift 6.2, this feature is not available in production toolchains.

The standard library can adopt `throws(E)` signatures function by function. `compactMap`, `filter`, `reduce` — each can be updated from `rethrows` to `<E: Error> throws(E)` without breaking existing callers, because `throws(E)` is a subtype of `throws`. Protocol APIs like `Encoder`, `Decoder`, and `Task.checkCancellation()` can similarly be updated. These are additive, non-breaking changes — but they require stdlib evolution proposals and have no announced timeline.

The language has the model. The ecosystem will follow.

## References

- [SE-0413: Typed throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md) — the proposal that introduced `throws(E)` in Swift
- [FullTypedThrows feature flag](https://github.com/swiftlang/swift/blob/main/include/swift/Basic/Features.def) — experimental compiler feature for full typed error propagation
- [The Swift Programming Language: Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/) — official documentation on `do`/`try`/`catch`
