# Swift Compositions

@Metadata {
    @TitleHeading("Swift Institute")
    @PageImage(purpose: card, source: "card-swift-foundations", alt: "Swift Compositions")
}

Layer 4: infrastructure composed from atoms, molecules and standards.

## Overview

A composition wires lower layers into a reusable component, such as command-line arguments, clocks or a file system. Compositions may depend on every layer below and on other compositions.

Compositions are published under the [swift-compositions](https://github.com/swift-compositions) organization as `swift-{concept}`. There is no umbrella package; consumers add individual packages:

```swift
dependencies: [
    .package(url: "https://github.com/swift-compositions/swift-{package}", branch: "main"),
]
```
