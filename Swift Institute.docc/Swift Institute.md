# ``Swift_Institute``

@Metadata {
  @DisplayName("Swift Institute")
  @TitleHeading("A layered Swift package ecosystem")
}

A stewarded body of typed Swift infrastructure — primitives, standards implementations, and composed foundations — designed for correctness, composability, and long-term evolution.

> Important: This is an early public release. Packages are being published incrementally across three layers. Some package URLs in examples may not resolve until their release tags land.

### Types encode meaning

The ecosystem encodes domain knowledge in the type system. Different clock domains produce different types. Different coordinate spaces cannot be mixed. The compiler enforces constraints that tests can only approximate.

```swift
import Clock_Primitives

let boot: Clock.Continuous.Instant    // monotonic, advances while asleep
let wake: Clock.Suspending.Instant    // monotonic, pauses while asleep

boot - wake  // Compile error — different clock domains.
```

### Specifications as namespaces

Types mirror the specifications that define them. The RFC or ISO standard is the namespace. When you read a type name, you know which specification governs its behavior — no ambiguity, no silent drift between implementations.

```swift
import Time_Standard
import Email_Standard

let timestamp: ISO_8601.DateTime      // governed by ISO 8601
let sender: RFC_5322.EmailAddress     // governed by RFC 5322
let tcp_state: RFC_9293.`3`.`3`.State // TCP state machine, RFC 9293 §3.3
```

### Concrete errors

Every throwing function declares its error type. Callers get exhaustive switches, not catch-all blocks. The error type is part of the API contract, not an afterthought.

```swift
// The error type is visible at the call site.
func read(into buffer: Memory.Buffer.Mutable) async throws(IO.Error) -> Int
```

### Foundation independence

No Foundation import at any layer. The ecosystem provides its own timestamps, paths, buffers, and string processing, so the same types compile wherever Swift compiles.

| Platform | Status |
|----------|--------|
| Darwin (macOS, iOS, tvOS, watchOS, visionOS) | Supported |
| Linux | Supported |
| Embedded Swift | Coming soon |
| Windows | Coming soon |

Primitives use `~Copyable` for resources with unique ownership — file descriptors, kernel handles, connection state — so the compiler tracks their lifecycle rather than deferring to runtime checks.

### Granular composition

130 primitive packages. 20 standards implementations. 136 foundation packages. Depend on what you need:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-clock-primitives", from: "0.1.0"),
    .package(url: "https://github.com/swift-ietf/swift-rfc-5322", from: "0.1.0"),
]
```

The ecosystem spans three layers — [primitives, standards, and foundations](<doc:Architecture>) — each building only on layers below. There is no umbrella import.

## Topics

### Start here

- <doc:Getting-Started>
- <doc:FAQ>

### Architecture

- <doc:Architecture>
- <doc:Platform>

### Layers

- <doc:Swift-Primitives>
- <doc:Swift-Standards>
- <doc:Swift-Foundations>

### Deep dives

- <doc:Embedded-Swift>

### Blog

- <doc:Blog>
