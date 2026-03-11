<!--
---
id: BLOG-IDEA-013
title: "Typed throws in Swift, part 2: the throwing spectrum"
slug: typed-throws-part-2
category: Technical Deep Dive
series: typed-throws
series_part: 2
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

# Typed throws in Swift, part 2: the throwing spectrum

Typed throws does more than attach an error enum to a function. It turns "throwing" from a binary distinction into a spectrum.

## The throwing spectrum

In [Part 1](/blog/typed-throws-part-1), we saw functions that can't fail, functions that fail with `Result`, and functions that fail with `throws`. Typed throws adds `throws(E)`. But these aren't separate categories. They're points on a spectrum.

```swift
// Cannot throw
func defaultPort() -> Port { Port(value: 8080) }

// Typed throw — Port.init
init(_ string: some StringProtocol) throws(Port.Error) { ... }

// Untyped throw
func loadPort() throws -> Port { ... }
```

Swift represents this spectrum through a single mechanism. A non-throwing function is a function that `throws(Never)` — the `Never` type has no values and therefore can never be thrown:

```swift
// These are equivalent:
func defaultPort() -> Int { 8080 }
func defaultPort() throws(Never) -> Int { 8080 }
```

An untyped `throws` is `throws(any Error)` — the widest possible error type:

```swift
// These are equivalent:
func loadPort() throws -> Int { ... }
func loadPort() throws(any Error) -> Int { ... }
```

The spectrum:

```
throws(Never)  →  throws(Port.Error)  →  throws(any Error)
can't throw       specific error          any error
```

Each point is a *subtype* of the points to its right. A function that can't throw is also a function that throws `Port.Error` — it just never does. A function that throws `Port.Error` is also a function that throws `any Error` — because `Port.Error` conforms to `Error`.

This means you can use a narrower function wherever a wider one is expected:

```swift
// Non-throwing where typed throw is expected:
let f: (String) throws(Port.Error) -> Port = { _ in Port(value: 8080) }

// Typed throw where untyped throw is expected:
let g: (String) throws -> Port = { try Port($0) }
```

The reverse doesn't work. You can't use a wider function where a narrower one is expected — an untyped-throwing function might throw something other than `Port.Error`.

## rethrows, generalized

Swift has had `rethrows` since the beginning. A `rethrows` function throws if and only if its closure argument throws:

```swift
// stdlib:
func map<T>(_ transform: (Element) throws -> T) rethrows -> [T]
```

```swift
[1, 2, 3].map { $0 * 2 }              // No try — closure doesn't throw
try [1, 2, 3].map { try riskyOp($0) } // Needs try — closure throws
```

With typed throws, `rethrows` reveals itself as a special case of a more general pattern:

```swift
func map<T, E: Error>(
    _ transform: (Element) throws(E) -> T
) throws(E) -> [T]
```

The function is generic over the error type `E`. When the closure doesn't throw, `E` is `Never`, and `throws(Never)` is non-throwing — no `try` needed. When the closure throws `Port.Error`, the function throws `Port.Error`.

This is strictly more powerful than `rethrows`. Where `rethrows` preserves a binary distinction — throws or doesn't — `throws(E)` preserves the *specific error type*. The closure's error identity survives.

At least in theory.

## Where the model works

The typed throws model works cleanly where the compiler has full control.

**Signatures** declare the error type:

```swift
// Port:
init(_ string: some StringProtocol) throws(Port.Error)
```

The caller knows exactly which errors are possible before reading the implementation.

**Implementation bodies** get dot syntax:

```swift
throw .invalid(string)     // not Port.Error.invalid(string)
throw .outOfRange(port)    // not Port.Error.outOfRange(port)
```

The compiler infers the error type from the declaration.

**Catch sites** get exhaustive switching:

```swift
do {
    let port = try Port("8080")
} catch {
    switch error {                      // error: Port.Error
    case .invalid(let string): ...
    case .outOfRange(let port): ...
    }                                   // exhaustive — no default needed
}
```

These are the points Part 1 arrived at. The spectrum model explains *why* they work: the compiler knows the exact position on the spectrum — `throws(Port.Error)` — and uses that for inference, exhaustiveness, and subtyping.

But the model meets resistance at boundaries where the compiler's control ends.

## Where the model meets boundaries

### Closures and inference

Pass a typed-throwing initializer to a higher-order function. With an explicit annotation, the error type survives:

```swift
let strings = ["8080", "hello", "443"]

let ports = try strings.map { (s: String) throws(Port.Error) -> Port in
    try Port(s)
}
```

The `map` call throws `Port.Error`. The catch site gets a typed error. Now remove the annotation:

```swift
let ports = try strings.map { try Port($0) }
```

Same initializer. Same call. The error type widens to `any Error`.

This is the wall: **closure inference doesn't preserve typed throws**. `Port.init` declares `throws(Port.Error)`. The compiler knows that. But it infers the closure as `(String) throws -> Port` — untyped — and the error identity is lost.

The gap between these two spellings is the entire cost:

```swift
{ (s: String) throws(Port.Error) -> Port in try Port(s) }  // typed
{ try Port($0) }                                             // erased
```

The `FullTypedThrows` experimental feature in the Swift compiler is designed to close this gap — making closure inference preserve the error type automatically. It isn't available in production toolchains yet.

### Protocol conformance covariance

The subtyping chain extends to protocol conformances. When a protocol declares `throws`, a conformer can narrow to `throws(E)`:

```swift
protocol Parseable {
    init(_ string: some StringProtocol) throws
}
```

Part 1's `Port` already has a typed-throwing initializer. The conformance is valid — `throws(Port.Error)` is a subtype of `throws`:

```swift
extension Port: Parseable {
    // init(_ string: some StringProtocol) throws(Port.Error)
    // satisfies: init(_ string: some StringProtocol) throws
}
```

The conformer provides a stronger guarantee than the protocol requires.

A concrete caller sees the typed error:

```swift
do {
    let port = try Port("hello")
} catch {
    switch error {
    case .invalid(let s):
        print("'\(s)' is not a number")
    case .outOfRange(let n):
        print("\(n) out of range")
    }
}
```

But a generic caller goes through the protocol witness and sees the untyped signature:

```swift
func parse<T: Parseable>(
    _ type: T.Type, from string: String
) throws -> T {
    try T(string)
    // error: any Error — typed throw invisible through the protocol
}
```

The covariance works at the type level. But the benefit disappears behind the protocol boundary. Generic code sees the protocol's `throws`, not `Port`'s `throws(Port.Error)`.

This matters most with stdlib protocols. `Codable` declares `init(from:) throws` and `encode(to:) throws`. A conformer *can* narrow to `throws(DecodingError)`. But the downstream APIs — `Decoder.container(keyedBy:)`, `container.decode(_:forKey:)` — all use untyped `throws`. The conformer must wrap every call in a `do`/`catch` to bridge back to the typed error. The conformance covariance is *possible* but often not *practical*.

## Error type design

Part 1 introduced leaf error types — `Port.Error`, `Retries.Error` — composed into `Service.Error` via wrapping cases. Two brief design notes for when typed throws meets generics.

**Leaf errors vs god errors.** A god error accumulates cases from every operation: `invalidPort`, `portOutOfRange`, `invalidRetries`, `negativeRetries`, `missingKey`, `networkTimeout`... Every function throws the same type. Every catch site handles cases that can't happen for that particular call. Leaf errors model each domain independently — `Port.Error` has two cases, `Retries.Error` has two cases, and `Service.Error` composes them by wrapping. The compiler enforces only the cases that actually apply.

**Hoisted vs generic-nested errors.** When a generic type like `Buffer<Element>` defines an error type, the question is whether the error cases need `Element`. If the failures are structural — out of bounds, full — the error type is independent of `Element` (hoisted). If the failures carry domain data — `invalid(Element)`, `duplicate(Element, existing: Element)` — the error type uses `Element` (generic-nested). Hoist when the failure is structural. Nest when the failure carries domain data.

## What's next

The subtyping chain means typed throws is opt-in at every boundary. You narrow where it helps — `throws(Port.Error)` in your domain — and widen where it doesn't — `throws` at protocol boundaries.

The model is elegant. The ecosystem doesn't always preserve it.

When you call `strings.map { try Port($0) }` without annotating the closure, the error type widens. When you reach for `compactMap` or `filter`, the stdlib's `rethrows` can't carry your error type at all. When you conform to `Codable`, the downstream APIs use untyped `throws`.

The same `Port.init` from Part 1 — with its clean `throws(Port.Error)` signature — will show us exactly where the standard library preserves that type and where it doesn't. That's [Part 3](/blog/typed-throws-part-3).

## References

- [SE-0413: Typed throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md) — the proposal that introduced `throws(E)` in Swift
- [FullTypedThrows feature flag](https://github.com/swiftlang/swift/blob/main/include/swift/Basic/Features.def) — experimental compiler feature for full typed error propagation
- [The Swift Programming Language: Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/) — official documentation on `do`/`try`/`catch`
