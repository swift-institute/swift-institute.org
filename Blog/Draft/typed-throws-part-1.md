<!--
---
id: BLOG-IDEA-013
title: "Typed throws in Swift, part 1: error handling from first principles"
slug: typed-throws-part-1
category: Technical Deep Dive
series: typed-throws
series_part: 1
series_title: Typed throws in Swift
date_drafted: 2026-03-11
date_published:
author: Coen ten Thije Boonkkamp
source_artifacts:
  - swift-institute/Research/typed-throws-standards-inventory.md
  - swift-standards/Experiments/typed-throws-protocol-conformance/
tags:
  - swift
  - error-handling
  - typed-throws
---
-->

# Typed throws in Swift, part 1: error handling from first principles

Here's what typed error handling looks like when the language carries the type:

```swift
struct Port {
    let value: Int

    init(_ string: some StringProtocol) throws(Port.Error) {
        guard let port = Int(string) else {
            throw .invalid(String(string))
        }
        guard (1...65535).contains(port) else {
            throw .outOfRange(port)
        }
        self.value = port
    }
}
```

```swift
do {
    let port = try Port("8080")
} catch {
    switch error {
    case .invalid(let string):
        print("'\(string)' is not a number")
    case .outOfRange(let port):
        print("Port \(port) out of range")
    }
}
```

The error type is in the signature. Inside this single-try `do` block, the compiler infers the caught error type from `Port.init`'s `throws(Port.Error)` declaration — the `switch` is exhaustive, no recovery cast, no defensive fallback.

Swift didn't always let us write this. To understand why it matters, let's start from the beginning.

> **A note on scope.** This series is not arguing that all public APIs should use typed throws, or that untyped `throws` is obsolete. Untyped `throws` is often the correct choice — when callers don't benefit from matching specific error cases, when the error domain is broad, or when the API crosses module boundaries. Typed throws adds precision where the error type is semantically part of the contract. This series explores where that precision matters and where the ecosystem supports it today.

## Return a special value

The oldest approach. Use a sentinel value to signal failure:

```swift
func parsePort(_ string: String) -> Int {
    guard let port = Int(string), (1...65535).contains(port) else {
        return -1
    }
    return port
}
```

This compiles. It runs. And it's a trap.

```swift
let port = parsePort("hello")
// port is -1 — but -1 is a valid Int
// Nothing stops us from using it
let configuration = Service.Configuration(
    host: "localhost", port: port, maxRetries: 3
)
// configuration.port is now -1
// A bug that will surface far from its cause
```

What does -1 mean? The caller has to know. The compiler can't distinguish -1-as-error from -1-as-value. And if the caller forgets to check, the bad value flows silently through the program.

We need the error to be part of the type.

## Make the error a type

`Result` makes the success/failure distinction explicit:

```swift
func parsePort(
    _ string: String
) -> Result<Int, Port.Error> {
    guard let port = Int(string) else {
        return .failure(.invalid(string))
    }
    guard (1...65535).contains(port) else {
        return .failure(.outOfRange(port))
    }
    return .success(port)
}
```

Now the error type is right there in the signature: `Result<Int, Port.Error>`. The caller can't ignore it — they must unwrap the `Result` to get the value. And the compiler knows *exactly* which errors are possible: `.invalid` when the string isn't a number, `.outOfRange` when the number falls outside 1–65535.

The error type is visible. But `Result` is a container — it composes through `flatMap` and `mapError`, not through linear code. What happens when we compose multiple fallible operations?

## The cost of composition

Let's add a second parsing function and try to build a configuration:

```swift
func parseRetries(
    _ string: String
) -> Result<Int, Retries.Error> {
    guard let n = Int(string) else {
        return .failure(.invalid(string))
    }
    guard n >= 0 else {
        return .failure(.negative(n))
    }
    return .success(n)
}
```

Now combine them. But there's a problem: `parsePort` returns `Result<Int, Port.Error>` and `parseRetries` returns `Result<Int, Retries.Error>`. Different error types — different domains. To compose them, we first need a common error type and must map each leaf into it:

```swift
let configuration = parsePort("8080")
    .mapError(Service.Error.port)
    .flatMap { port in
        parseRetries("3")
            .mapError(Service.Error.retries)
            .map { retries in
                Service.Configuration(
                    host: "localhost",
                    port: port,
                    maxRetries: retries
                )
            }
    }
// configuration: Result<Service.Configuration, Service.Error>
```

Two operations, two levels of nesting, and two `.mapError` calls to unify the error types. Three fields would be three levels. A real configuration with ten fields would be unreadable.

Compare this with the opening: `let port = try Port(...)` — one line, no nesting, no closures, no manual error mapping. The code that *does the work* dominates the code that *handles errors*, not the other way around.

We gained precision — each operation declares exactly which errors it can produce, the compiler enforces handling — but we paid for it in ergonomics.

## Let the language carry the error

Swift's `throws` keyword solves the ergonomics problem:

```swift
func parsePort(_ string: String) throws -> Int {
    guard let port = Int(string) else {
        throw Port.Error.invalid(string)
    }
    guard (1...65535).contains(port) else {
        throw Port.Error.outOfRange(port)
    }
    return port
}
```

And composition becomes linear:

```swift
func parseConfiguration(
    _ dict: [String: String]
) throws -> Service.Configuration {
    guard let host = dict["host"] else {
        throw Service.Error.missing("host")
    }
    let port = try parsePort(dict["port"] ?? "")
    let retries = try parseRetries(dict["max_retries"] ?? "")

    return Service.Configuration(
        host: host, port: port, maxRetries: retries
    )
}
```

The `flatMap` pyramid is gone. The `.mapError` calls are gone. Each step is a single line. `try` marks every point where control might transfer. The compiler enforces that you handle errors — you can't call a `throws` function without `try` or wrapping it in a `do`/`catch`.

The syntax is clean. Linear. Each step reads as intent. For many APIs, this is exactly the right abstraction — callers want to know "this can fail" without matching specific cases. A networking layer that might throw DNS errors, TLS errors, timeout errors — the caller retries or shows a message. Listing every error type in the signature would be noise.

But consider domain types where the caller *does* need to match specific cases. Here, notice what we lost. We have to write `Port.Error.invalid(...)` — the full path — because the compiler doesn't know the error type. Compare that with the opening's `throw .invalid(...)`. That dot syntax is only possible when the compiler knows the error type from the signature.

And there's a deeper loss for these domain-specific APIs. `parsePort` throws `Port.Error`. `parseRetries` throws `Retries.Error`. `parseConfiguration` adds its own `Service.Error`. Three error domains — all erased to `any Error`. The domain structure we designed with leaf error types is invisible to the caller.

Now look at the call site.

## The cost of erasure

```swift
do {
    let configuration = try parseConfiguration(pairs)
    startServer(configuration)
} catch {
    // error: any Error
    print("Failed: \(error)")
}
```

What is `error`? It's `any Error` — an existential that could be *anything*. We know what `parseConfiguration` throws — `Port.Error` from port parsing, `Retries.Error` from retries parsing, `Service.Error` for missing keys. The compiler doesn't.

You *can* cast to recover the type:

```swift
do {
    let port = try parsePort("8080")
} catch let error as Port.Error {
    switch error {
    case .invalid(let string):
        print("'\(string)' is not a number")
    case .outOfRange(let port):
        print("Port \(port) out of range")
    }
} catch {
    // The compiler forces this branch.
    // We know it can't happen. But the compiler doesn't.
    print("Unexpected error: \(error)")
}
```

This compiles. But consider what you're doing:

- **Runtime recovery of compile-time information.** The throw site knew the type — `Port.Error`. The catch site casts to get it back. You're doing the compiler's job at runtime.
- **Silent breakage.** If the error type changes, the `as` cast stops matching. No compiler diagnostic. The catch-all absorbs the error silently.
- **Forced dead code.** That final `catch` is dead code — `parsePort` only throws `Port.Error`. But the compiler demands it because it can't see through the erasure.
- **No exhaustiveness guarantee.** If a case is added to `Port.Error`, the switch doesn't warn. You discover the gap at runtime, not compile time.

With `parseConfiguration`, it's worse: three error domains flow through one `throws`. The caller must guess which types to cast for, with no guidance from the signature.

Compare this with the opening: no cast, no catch-all, exhaustive `switch` directly on the error. The syntax is linear again. But the error type itself has been erased — the very information that makes error handling precise.

This is the **cost of erasure** in domain-specific APIs: where callers need to match specific error cases, they trade compile-time type information for runtime casting. The information exists at the throw site — the catch site just can't see it.

## A deliberate choice

The type erasure in `throws` wasn't an accident. When Swift first shipped, the core team considered typed throws and deliberately deferred it. The concern: declaring error types in public signatures makes them part of the API contract — a resilience hazard. Java's checked exceptions demonstrated exactly this failure mode.

For many APIs, erasure is still the right choice: a networking function might throw dozens of underlying error types, and the caller wants to retry or show a message, not match every case. But years of real-world Swift revealed cases where erasure genuinely costs you: internal APIs where you control both sides, domain errors that callers need to match exhaustively, and error propagation across module boundaries where `as?` casting feels brittle.

In 2023, [SE-0413](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md) introduced typed throws. The syntax: `throws(E)`.

## The synthesis

Here's the code from the opening — but now you can see what each line resolves.

The leaf error type — only the cases port parsing can produce:

```swift
extension Port {
    enum Error: Swift.Error {
        case invalid(String)
        case outOfRange(Int)
    }
}
```

Two cases. `Port.Error.invalid` — the input wasn't a number. `Port.Error.outOfRange` — the number wasn't in range. The type nesting carries the domain: this is a *port* error. No need to encode "port" in the case name.

The value type:

```swift
struct Port {
    let value: Int
}
```

The throwing initializer — defined in an extension so the memberwise `init(value:)` remains available:

```swift
extension Port {
    init(_ string: some StringProtocol) throws(Port.Error) {
        guard let port = Int(string) else {
            throw .invalid(String(string))
        }
        guard (1...65535).contains(port) else {
            throw .outOfRange(port)
        }
        self.value = port
    }
}
```

`throws(Port.Error)` gives us what untyped `throws` couldn't: the error type *in the signature*. And `throw .invalid(...)` uses dot syntax — the compiler infers the error type from the declaration. Compare this with the untyped version's `throw Port.Error.invalid(...)`. The type annotation does double duty: it informs the caller *and* simplifies the implementation.

The call site:

```swift
do {
    let port = try Port("8080")
} catch {
    switch error {
    case .invalid(let string):
        print("'\(string)' is not a number")
    case .outOfRange(let port):
        print("Port \(port) out of range")
    }
}
```

No `as?` cast. No dead branch. The `switch` is exhaustive because the compiler knows the error type. This is the synthesis: `Result`'s type precision, with `throws`'s ergonomic syntax.

When operations compose, leaf errors compose too:

```swift
enum Service {}
```

```swift
extension Service {
    struct Configuration {
        var host: String
        var port: Port
        var maxRetries: Retries
    }
}
```

`Retries` mirrors `Port` — a struct wrapping an `Int`, with `init(_ string: some StringProtocol) throws(Retries.Error)`. The configuration stores domain types directly, not the raw `Int` values from the earlier approaches.

```swift
extension Service {
    enum Error: Swift.Error {
        case missing(String)
        case port(Port.Error)
        case retries(Retries.Error)
    }
}
```

Each leaf error is wrapped in a case that names the domain. `Service.Error.port(Port.Error)` — a port error, within the service domain. The structure mirrors the domain.

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

Each `do`/`catch` wraps a leaf error into the parent domain. The compiler knows the type at every boundary — `error` in the first `catch` is `Port.Error`, and `.port(error)` wraps it into `Service.Error`. No casts. No guessing. The domain structure that `throws` erased is explicit again.

## What's next

We have the syntax. `throws(E)` gives us typed errors at catch sites and dot syntax in implementations. `Port.Error`, `Retries.Error`, and `Service.Error` show how leaf errors compose at domain boundaries.

But what is the actual relationship between non-throwing functions, `throws(E)`, and untyped `throws`? And when you pass `Port.init` to a higher-order function like `map`, does the error type survive?

That's [Part 2](/blog/typed-throws-part-2).

## References

- [SE-0413: Typed throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md) — the proposal that introduced `throws(E)` in Swift
- [The Swift Programming Language: Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/) — official documentation on `do`/`try`/`catch`
