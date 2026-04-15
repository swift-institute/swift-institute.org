# Getting Started

@Metadata {
    @TitleHeading("Swift Institute")
}

Add a package, import it, write code.

## Add a dependency

Each package is a standalone Swift package. Add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-clock-primitives", from: "0.1.0"),
],
targets: [
    .executableTarget(
        name: "MyProject",
        dependencies: [
            .product(name: "Clock Primitives", package: "swift-clock-primitives"),
        ]
    ),
]
```

## Import and use

```swift
import Clock_Primitives

let now: Clock.Continuous.Instant = Clock.Continuous().now
```

Types use the `Nest.Name` convention — `Clock.Continuous.Instant`, not `ContinuousClockInstant`. Methods follow the same pattern: `dir.walk.files()` instead of `dir.walkFiles()`.

## Choosing a package

There is no umbrella import. Depend on what you need:

| You need | Package | Layer |
|----------|---------|-------|
| Clock types | `swift-clock-primitives` | Primitives |
| Buffer types | `swift-buffer-primitives` | Primitives |
| Email addresses | `swift-emailaddress-standard` | Standards |
| Time interchange | `swift-time-standard` | Standards |
| JSON parsing | `swift-json` | Foundations |
| HTTP routing | `swift-http-routing` | Foundations |

## Platform support

| Platform | Status |
|----------|--------|
| Darwin (macOS, iOS, tvOS, watchOS, visionOS) | Supported |
| Linux | Supported |
| Embedded Swift | Coming soon |
| Windows | Coming soon |

See <doc:Architecture> for how the layers relate, <doc:Platform> for platform specifics, or <doc:FAQ> for common questions.
