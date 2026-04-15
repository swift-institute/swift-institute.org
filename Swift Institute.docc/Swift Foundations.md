# Swift Foundations

@Metadata {
    @TitleHeading("Swift Institute")
}

Composed building blocks that integrate primitives and standards into reusable infrastructure.

## Overview

Foundations are where primitives and standards become useful infrastructure. Standards-layer packages faithfully implement external specifications; foundations-layer packages compose them into reusable abstractions. For example, a configuration system at the foundations layer composes a data-format parser, file I/O, validation, and type coercion into a single integrated component.

Packages at this layer are published at the [swift-foundations](https://github.com/swift-foundations) organization, following the naming pattern `swift-{concept}` (clean names, no suffix). Foundations are the first layer where ecosystem integration begins — still policy-light, but composed rather than atomic.

---

## Composition over accretion

The distinction between Standards and Foundations is composition.

**Standards** faithfully implement external specifications. Semantics are dictated elsewhere. Standards depend only on primitives and are policy-free.

**Foundations** compose standards and primitives into reusable abstractions. Foundations introduce structural decisions — how types relate, what is wired together by default — without prescribing end-user policy.

**Distinction from Primitives**: Foundations have dependencies on standards. A TLS foundation depends on cryptographic standards; a logging foundation may depend on timestamp standards. Primitives depend only on other primitives.

---

## Design principles

Foundations inherit the discipline of lower layers:

- **Typed throws.** Fallible operations declare their concrete error type. Consumers get exhaustive switches, not catch-all blocks.
- **No Foundation import.** Timestamps, paths, data buffers, and string processing come from primitives and standards, not `Foundation.Date`/`URL`/`Data`.
- **Cross-platform by default.** Code is designed to be portable; platform-specific behaviour is isolated. See <doc:Platform> for current support.
- **Granular packaging.** Each package answers one question well. Consumers depend on what they need.

---

## Choosing dependencies

There is no umbrella foundation package. Each package is a standalone Swift package; consumers add individual dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-{package}", from: "0.1.0"),
]
```

Each package documents its own dependencies and version support.
