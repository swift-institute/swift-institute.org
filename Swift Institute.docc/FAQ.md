# FAQ

@Metadata {
    @TitleHeading("Swift Institute")
    @PageImage(purpose: card, source: "card-faq", alt: "FAQ")
}

Frequently asked questions about Swift Institute architecture, packaging, and usage.

## What's the current state of the ecosystem?

The package ecosystem spans three layers — primitives, standards, and foundations — and is under active development. Most package repositories are still private and are being released on a rolling basis as they reach release quality. This website, [Research](https://github.com/swift-institute/Research), and [Experiments](https://github.com/swift-institute/Experiments) are public now.

---

## What platforms are supported?

| Platform | Status |
|----------|--------|
| Darwin (macOS, iOS, tvOS, watchOS, visionOS) | Supported |
| Linux | Supported |
| Embedded Swift | Coming soon |
| Windows | Coming soon |

All layers are Foundation-independent by design, which makes the entire ecosystem portable across the full Swift target matrix. Consumer code writes one import (`import Kernel`) and the right platform is wired automatically — platform conditionals are concentrated at the boundary, not in consumer code.

---

## Why is Apple's Foundation framework not used?

Two primary reasons:

- **Cross-platform and faster iteration.** Foundation's behaviour drifts between Darwin and swift-corelibs-foundation on Linux. Building on Swift directly lets the ecosystem iterate without waiting for Foundation's release cycle.
- **Embedded Swift.** Embedded Swift has no Foundation runtime. Keeping Foundation out of every layer means the same packages compile for baremetal targets.

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

See the Layers section on the main page for the full decision model.

---

## Can I depend on only part of a package?

Yes. Many packages expose multiple library products for fine-grained dependencies — an umbrella product alongside narrower sub-products. Depending only on what you need reduces compile times and binary sizes. Check each package's `Package.swift` for available products.

---

## Where do I report issues or ask questions?

- GitHub Issues — file on the relevant package repository
- Pull Requests — see the [contribution guide](https://github.com/swift-institute/.github/blob/main/CONTRIBUTING.md)

