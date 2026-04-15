# FAQ

@Metadata {
    @TitleHeading("Swift Institute")
}

Frequently asked questions about Swift Institute architecture, packaging, and usage.

## How do I depend on one of these packages?

Each repository in the ecosystem is a standalone Swift package. Add it as a dependency directly in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-geometry-primitives", from: "0.1.0"),
    .package(url: "https://github.com/swift-foundations/swift-json", from: "0.1.0"),
]
```

> The specific packages shown above are illustrative. Individual packages are being released over the coming weeks; `swift package resolve` against a not-yet-public repository returns a 404 until its release tag lands.

There is no umbrella package to import. The superrepos (`swift-primitives`, `swift-standards`, `swift-foundations`) are git submodule aggregators for browsing the ecosystem. They are not meant to be consumed as dependencies.

---

## What's the license?

Primitives and Standards packages are released under Apache 2.0 without exception. Foundations packages are Apache 2.0 by default, with selective commercial terms reserved for specific packages where appropriate. Components and Applications use more flexible licensing, since that is where policy and opinion accumulate. See the Licensing strategy section of [Five Layer Architecture](Five%20Layer%20Architecture.md).

Every repository carries its own `LICENSE.md` file. When in doubt, check the repository.

---

## What's the current state of the ecosystem?

As of this release:

- 127 repositories at the Primitives layer
- Standards distributed across `swift-standards` itself plus per-authority organizations (swift-ietf, swift-iso, swift-w3c, swift-whatwg, and single-package organizations for other standards bodies)
- 136 repositories at the Foundations layer
- Components and Applications are planned; no packages at those layers have been released yet

This is an early public release. Documentation, research, experiments, and the blog workflow are all available now. The Swift packages themselves are being released repository by repository; some links in the documentation may resolve only as release tags land.

---

## Why can I not use Apple's Foundation framework?

Foundation (`Date`, `URL`, `Data`, `String` bridging) introduces dependencies that prevent deployment in several environments:

- Embedded Swift has no Foundation runtime
- Kernel extensions cannot afford the overhead
- Behavior drifts between Darwin and swift-corelibs-foundation on Linux

Keeping Foundation out of the Primitives and Standards layers lets those packages deploy across the entire Swift ecosystem without modification. At the Foundations layer and above, Foundation is a legitimate dependency if a package genuinely needs it — the constraint applies to the lower layers, not everywhere.

See [Identity](Identity.md) for the reasoning behind this choice.

---

## Why so many small packages?

Fine-grained packaging provides:

1. Minimal dependencies — a package needing only affine transforms does not pull in temporal primitives
2. Faster builds — smaller dependency graphs compile faster
3. Clearer semantics — each package answers one question well
4. Independent versioning — breaking changes propagate only to actual dependents

The alternative, a monolithic `SwiftPrimitives` package, would force every consumer to accept every type, including those irrelevant to their domain. This contradicts the principle of minimal coupling.

---

## How do I know which layer my package belongs to?

Ask these questions in order:

1. Does an external specification define it? If implementing an ISO, RFC, IEEE, W3C, or similar standard, the package belongs in the appropriate per-authority organization or in `swift-standards` as a convergence package.
2. Do standards need it but not define it? If it is a prerequisite for standards, it belongs in `swift-primitives`.
3. Does it compose standards and primitives into a reusable domain abstraction? It belongs in `swift-foundations`.
4. Is it an opinionated assembly with defaults? It belongs in `swift-components`.
5. Is it an end-user product? It belongs in `swift-applications`.

See [Five Layer Architecture](Five%20Layer%20Architecture.md) for the full decision model.

---

## Can I depend on only part of a package?

Yes. Many packages expose multiple library products for fine-grained dependencies:

```swift
// Depend on all numeric primitives
.product(name: "Numeric Primitives", package: "swift-numeric-primitives"),

// Or depend only on what you need
.product(name: "Integer Primitives", package: "swift-numeric-primitives"),
.product(name: "Real Primitives", package: "swift-numeric-primitives"),
```

This reduces compile times and binary sizes. Check each package's `Package.swift` for available products.

---

## Why "Institute" and not "Framework"?

The naming signals intent:

- Framework implies consumption — you use it as provided
- Institute implies stewardship — a body that maintains standards over time

The Swift Institute does not ship a framework; it maintains a body of layered infrastructure. The "institute" framing communicates long-term stability, stewardship over ownership, and principled evolution over feature accumulation.

See [Identity](Identity.md) for the full explanation.

---

## When will the Components and Applications layers be released?

No date is committed. The Primitives, Standards, and Foundations layers are being published first, because Components and Applications depend on them. Once those lower layers are stable and the releases have settled, work on Components will begin in public.

---

## Where do I report issues or ask questions?

- GitHub Issues — for bugs and feature requests, file on the relevant package repository
- GitHub Discussions — for architectural questions and design discussions on the `swift-institute` repository (ensure [Discussions is enabled](https://docs.github.com/en/discussions/quickstart) on the repo)
- Pull Requests — for contributions, see [`CONTRIBUTING.md`](../CONTRIBUTING.md)

## Topics

### Related

- [Five Layer Architecture](Five%20Layer%20Architecture.md)
- [Identity](Identity.md)
- [Glossary](Glossary.md)
