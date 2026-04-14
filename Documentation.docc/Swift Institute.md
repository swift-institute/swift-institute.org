# Swift Institute

@Metadata {
    @TitleHeading("Documentation")
}

Documentation, conventions, and research for a layered Swift package ecosystem.

## Overview

Infrastructure compounds when its building blocks compose, and composition requires shared discipline across every layer. Type-safe packages that each solve one problem will, without a unifying convention, pile up incompatible abstractions until nothing fits together. Swift Institute is the umbrella that holds that discipline together — the conventions that keep the layered packages coherent, the research that grounds architectural decisions, and the experiments that verify claims before those claims become conventions.

This documentation is for human readers. Developer-facing conventions live in `Skills/`, which is the canonical source for the rules and requirements used when writing code inside the ecosystem.

## Start here

| Document | Topic |
|----------|-------|
| <doc:Five-Layer-Architecture> | The core organizational model — Primitives, Standards, Foundations, Components, Applications |
| <doc:Identity> | Why this is called the Swift Institute, and what that name commits to |
| <doc:Glossary> | Canonical vocabulary used across the ecosystem |
| <doc:Mathematical-Foundations> | Type-safe dimensional analysis, algebraic structures, category-theoretic organization |
| <doc:Embedded-Swift> | Writing packages compatible with Embedded Swift compilation |
| <doc:FAQ> | Common questions about the architecture and how to use it |
| <doc:Contributing> | How to contribute — where conventions live, how proposals flow |

## The wider ecosystem

Swift Institute is one of several GitHub organizations that make up the ecosystem. The code lives elsewhere:

| Layer | Organization | Role |
|-------|--------------|------|
| 1 | [swift-primitives](https://github.com/swift-primitives) | Atomic building blocks — buffer, geometry, algebra, memory, kernel |
| 2 | [swift-standards](https://github.com/swift-standards) + per-authority orgs | Specification implementations |
| 3 | [swift-foundations](https://github.com/swift-foundations) | Composed building blocks — IO, HTML, CSS, SVG, PDF, networking |
| 4 | Components | Opinionated assemblies — planned |
| 5 | Applications | End-user systems — planned |

Layer 2 is organized as a set of per-authority organizations — [swift-ietf](https://github.com/swift-ietf) (RFCs), [swift-iso](https://github.com/swift-iso), [swift-w3c](https://github.com/swift-w3c), [swift-whatwg](https://github.com/swift-whatwg), and single-package organizations for IEEE, IEC, ECMA, INCITS, ARM, Intel, RISC-V, and Microsoft — so governance, release cadence, and audience align with real-world specification authority.

Every repository in the ecosystem is a standalone Swift package consumed the way any other Swift package is consumed: a `.package(url: ...)` line per dependency. Super-repositories (`swift-primitives`, `swift-standards`, `swift-foundations`) exist for browsing — they aggregate submodule pointers so the whole layer can be cloned at once.

## Status

This is an early public release. The documentation in this repository is available now. The Swift package layers it describes are being released repository by repository over the coming weeks. Some cross-references from blog posts and research documents point to repositories that are not yet world-readable; those links resolve as the release tags land.

## License

All packages use the Apache License 2.0.
