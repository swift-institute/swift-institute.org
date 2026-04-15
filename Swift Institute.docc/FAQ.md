# FAQ

@Metadata {
    @TitleHeading("Swift Institute")
}

Frequently asked questions about Swift Institute architecture, packaging, and usage.

## How do I depend on one of these packages?

Each repository in the ecosystem is a standalone Swift package. Add it as a dependency directly in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/{org}/{package}", from: "0.1.0"),
]
```

> Packages are being released incrementally. `swift package resolve` against a not-yet-public repository returns a 404 until its release tag lands.

There is no umbrella package to import. The superrepos (`swift-primitives`, `swift-standards`, `swift-foundations`) are git submodule aggregators for browsing the ecosystem. They are not meant to be consumed as dependencies.

---

## What's the license?

Every repository carries its own `LICENSE.md` file. Layering gives licensing flexibility — foundational substrate can be permissively licensed for maximum embeddability, while higher layers where policy accumulates have room for different terms. See <doc:Architecture> for the rationale.

---

## What's the current state of the ecosystem?

This is an early public release. The primitives, standards, and foundations layers have active repositories; the components and applications layers exist in the design but have no released packages yet.

Documentation, research, and the blog workflow are all available now. The Swift packages themselves are being released repository by repository; some links in the documentation may resolve only as release tags land.

---

## What platforms are supported?

| Platform | Status |
|----------|--------|
| Darwin (macOS, iOS, tvOS, watchOS, visionOS) | Supported |
| Linux | Supported |
| Embedded Swift | Coming soon |
| Windows | Coming soon |

All layers are Foundation-independent by design, which makes the entire ecosystem portable across the full Swift target matrix.

---

## Why can I not use Apple's Foundation framework?

Foundation (`Date`, `URL`, `Data`, `String` bridging) introduces dependencies that prevent deployment in several environments:

- Embedded Swift has no Foundation runtime
- Kernel extensions cannot afford the overhead
- Behavior drifts between Darwin and swift-corelibs-foundation on Linux

Keeping Foundation out of every layer lets the whole ecosystem deploy across the Swift target matrix without modification. The ecosystem provides its own timestamps, paths, data buffers, and string processing — all Foundation-free.

See <doc:Architecture> for the reasoning behind this choice.

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

1. Does an external specification define it? If implementing an ISO, RFC, IEEE, W3C, or similar standard, the package belongs at the standards layer.
2. Do standards need it but not define it? If it is a prerequisite for standards, it belongs at the primitives layer.
3. Does it compose standards and primitives into a reusable domain abstraction? It belongs at the foundations layer.

See <doc:Architecture> for the full decision model.

---

## Can I depend on only part of a package?

Yes. Many packages expose multiple library products for fine-grained dependencies — an umbrella product alongside narrower sub-products. Depending only on what you need reduces compile times and binary sizes. Check each package's `Package.swift` for available products.

---

## What are the Research, Experiments, and Skills directories?

Each repository contains three artifact directories alongside the packages:

- **Research/** — design rationale and trade-off analysis. When a decision has non-obvious alternatives, the reasoning is recorded here rather than lost in commit history.
- **Experiments/** — Swift packages that verify compiler and runtime behaviour. Each experiment isolates one hypothesis with a runnable build, so claims about the type system, language features, or platform behaviour can be reproduced.
- **Skills/** — canonical conventions for naming, error handling, memory safety, testing, and related practices. Written to be read by AI-assisted tooling, but readable as reference material.

Blog posts link to experiments that back load-bearing claims, so readers can verify by running the code.

---

## Where do I report issues or ask questions?

- GitHub Issues — file on the relevant package repository
- Pull Requests — see [`CONTRIBUTING.md`](../CONTRIBUTING.md)

