# Swift Institute

Documentation, conventions, and research for a layered Swift package ecosystem.

## Overview

Shared conventions turn a collection of Swift packages into a composable ecosystem. Without them, type-safe libraries accumulate incompatible abstractions and compose badly. With them, compile-time guarantees hold across layers.

Swift Institute hosts those conventions — rules for naming, error handling, memory ownership, and API shape — along with the research that grounds them, the experiments that verify them, and the writing that explains them. It is the connective tissue for a set of layered Swift packages organized into Primitives, Standards, Foundations, Components, and Applications.

## Technical Approach

The ecosystem is organized into five layers, each with its own GitHub organization. Packages in each layer may depend on packages in their own layer and in layers below, never above. `swift-primitives` is the bottom layer and depends only on itself. `swift-standards` may depend on `swift-primitives`. `swift-foundations` may depend on both. Components and Applications build on top.

Every repository in the ecosystem is a standalone Swift package with its own version history, release tags, and `Package.swift`. Consumers depend on individual packages directly — a `.package(url: ...)` line per dependency — rather than on umbrella imports. The super-repositories (`swift-primitives`, `swift-standards`, `swift-foundations`) are git submodule aggregators that exist for browsing, not for consumption.

`swift-standards` is primarily an organization of organizations. Each standards body has its own GitHub organization hosting its specifications, so governance, release cadence, and audience align with real-world specification authority. The question each organization name answers is "who standardized this?"

Shared conventions live in this repository as Skills — the canonical source for naming, errors, memory safety, testing, modularization, and more. Research documents ground architectural decisions without prescribing them. Experiments reduce claims to runnable Swift packages. Blog posts link load-bearing claims directly to those experiments, so readers can verify rather than trust.

## The Ecosystem

| Layer | Organization | Role |
|-------|--------------|------|
| 1 | [swift-primitives](https://github.com/swift-primitives) | Atomic building blocks — buffer, geometry, algebra, memory, kernel |
| 2 | [swift-standards](https://github.com/swift-standards) + per-authority orgs | Specification implementations |
| 3 | [swift-foundations](https://github.com/swift-foundations) | Composed building blocks — IO, HTML, CSS, SVG, PDF, networking |
| 4 | Components | Opinionated assemblies — planned |
| 5 | Applications | End-user systems — planned |

> **Release in progress.** The organization links above point to GitHub organizations that are being made world-readable over the coming weeks. Some may currently return 404; they resolve as each layer's release lands.

The per-authority organizations in active preparation include [swift-ietf](https://github.com/swift-ietf) (RFCs), [swift-iso](https://github.com/swift-iso), [swift-w3c](https://github.com/swift-w3c), [swift-whatwg](https://github.com/swift-whatwg), plus single-package organizations for IEEE, IEC, ECMA, INCITS, ARM, Intel, RISC-V, and Microsoft. `swift-standards` itself retains the cross-body and historical packages.

## Repository Contents

| Directory | Contents |
|-----------|----------|
| [`Audits/`](Audits) | Repository- and ecosystem-level audit reports (e.g., release-readiness reviews) |
| [`Blog/`](Blog) | Blog posts (drafts, published), the ideas index, style guide, and series plans |
| [`Documentation.docc/`](Documentation.docc) | Architecture documentation — the five-layer model, naming conventions, shared vocabulary |
| [`Experiments/`](Experiments) | Minimal reproductions — each experiment is a Swift package testing one claim, used as receipts for blog posts |
| [`Research/`](Research) | Design rationale, trade-off analyses, and investigation notes. Non-normative |
| [`Skills/`](Skills) | Development conventions — naming, errors, memory safety, testing, modularization. Each skill is the canonical source for its conventions |
| [`Swift Evolution/`](Swift%20Evolution) | Draft proposals for Swift Evolution |
| [`Scripts/`](Scripts) | Scripts used by the institute's own processes |

## Status

This is an early public release. The documentation, research, experiments, and blog workflow in this repository are available now. The Swift package layers they describe are being released repository by repository over the coming weeks. Some links from blog posts and research documents point to repositories that are not yet world-readable; those links resolve as the release tags land.

If you arrived here from a blog post's receipt link, you're looking at the minimal Swift package that backs a specific technical claim. The relevant experiment lives in [`Experiments/`](Experiments) and can be cloned and built with `swift build` on Swift 6.3 or newer.

## Requirements

- Swift 6.3+
- macOS 26.0+ / iOS 26.0+ / Linux

## License

All packages use the Apache License 2.0. See [LICENSE.md](LICENSE.md).
