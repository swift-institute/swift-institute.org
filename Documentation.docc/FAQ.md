# FAQ

@Metadata {
    @TitleHeading("Swift Institute")
}

Frequently asked questions about Swift Institute architecture and usage.

## Why can't I use Foundation?

Foundation (`Date`, `URL`, `Data`, `String` bridging) introduces dependencies that prevent deployment in constrained environments:

- **Swift Embedded**: No Foundation runtime available
- **Kernel extensions**: Foundation adds unacceptable overhead
- **Cross-platform consistency**: Foundation behavior differs between Darwin and Linux

By maintaining Foundation independence, primitives deploy across the entire Swift ecosystem without modification. If you need Foundation conveniences, use them in the **foundations** layer or above, where policy decisions are appropriate.

See <doc:Identity> for more on the reasoning behind this constraint.

---

## Why 61 packages instead of fewer?

Fine-grained packages provide:

1. **Minimal dependencies**: A package needing only affine transforms doesn't pull in temporal primitives
2. **Faster builds**: Smaller dependency graphs compile faster
3. **Clearer semantics**: Each package answers one question well
4. **Independent versioning**: Breaking changes propagate only to actual dependents

The alternative—a monolithic `SwiftPrimitives` package—would force all consumers to accept all types, even those irrelevant to their domain. This contradicts the principle of minimal coupling.

See <doc:Primitives-Architecture> for the nine-tier dependency hierarchy.

---

## What's the difference between atomic and infrastructure tiers?

**Atomic tiers** (1-4) contain types with no dependencies beyond the Swift standard library:
- Tier 1: Kernel (identity, ordering, validation)
- Tier 2: Mathematical (parity, sign, comparison)
- Tier 3: Numeric (transcendentals, integers)
- Tier 4: Structural (algebra, tagged types)

**Infrastructure tiers** (5-9) compose atomic types into domain primitives:
- Tier 5: Dimensional (coordinates, angles, extents)
- Tier 6: Geometric (points, vectors, matrices)
- Tier 7: Spatial (transforms, symmetries)
- Tier 8: Memory (buffers, binary parsing)
- Tier 9: Platform (Darwin, Linux, Windows abstractions)

The distinction matters for dependency management: atomic types are universally reusable; infrastructure types serve specific domains.

See <doc:Layer-Flowchart> for a visual guide.

---

## How do I know which layer my package belongs to?

Ask these questions in order:

1. **Does a standard define it?** If implementing ISO, RFC, IEEE, or similar → **swift-standards**
2. **Do standards need it but not define it?** If it's a prerequisite for standards → **swift-primitives**
3. **Does it compose standards into a domain?** If building on standards → **swift-foundations**
4. **Is it an opinionated component?** If it includes UI or policy → **swift-components**
5. **Is it an end-user product?** → **swift-applications**

See <doc:Contributor-Guidelines> for a detailed decision tree.

---

## Why "Institute" and not "Framework"?

The naming signals intent:

- **Framework** implies consumption—you use it as provided
- **Institute** implies stewardship—a body that maintains standards over time

The Swift Institute doesn't ship a framework; it maintains a **body of layered infrastructure**. The "institute" framing communicates:

1. Long-term stability over rapid iteration
2. Stewardship over ownership
3. Principled evolution over feature accumulation

See <doc:Identity> for the full explanation of organizational identity.

---

## Can I depend on only part of a package?

Yes. Many packages expose multiple library products for fine-grained dependencies:

```swift
// Depend on all numeric primitives
.product(name: "Numeric Primitives", package: "swift-numeric-primitives")

// Or depend only on what you need
.product(name: "Integer Primitives", package: "swift-numeric-primitives")
.product(name: "Real Primitives", package: "swift-numeric-primitives")
```

This reduces compile times and binary sizes. Check each package's `Package.swift` for available products.

See <doc:Implementation-Patterns> for more on multi-library products.

---

## Where do I report issues or ask questions?

- **GitHub Issues**: For bugs and feature requests, file issues on the relevant package repository
- **GitHub Discussions**: For architectural questions and design discussions
- **Pull Requests**: For contributions (see <doc:Contributor-Guidelines>)

## Topics

### Related

- <doc:Identity>
- <doc:Contributor-Guidelines>
- <doc:Primitives-Architecture>
