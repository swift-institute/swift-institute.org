# Swift Institute

Documentation, conventions, and research for a layered Swift package ecosystem.

## Overview

Infrastructure compounds when its building blocks compose, and composition requires shared discipline across every layer. Type-safe packages that each solve one problem beautifully will, without a unifying convention, pile up incompatible abstractions until nothing fits together. We believe infrastructure deserves to be treated as a coherent whole — where every layer has a clear responsibility, every package a clear place, and the conventions that keep them coherent are themselves a first-class asset.

Swift's type system makes that discipline practical at scale. Layered packages with well-defined dependency rules, nested namespaces that mirror real-world domains, and rigorous conventions for error handling, memory ownership, and API shape together turn a collection of libraries into something closer to a platform. Compile-time guarantees that hold across a whole ecosystem are stronger than the sum of the guarantees of its individual parts.

Swift Institute is the umbrella that holds that discipline together. It hosts the conventions that keep the Primitives, Standards, and Foundations layers coherent, the research that grounds architectural decisions, the experiments that verify claims before those claims become conventions, and the writing that explains the result. What lives here is the connective tissue of the ecosystem — the part that turns independent packages into a composable whole.

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

The per-authority organizations in active preparation include [swift-ietf](https://github.com/swift-ietf) (RFCs), [swift-iso](https://github.com/swift-iso), [swift-w3c](https://github.com/swift-w3c), [swift-whatwg](https://github.com/swift-whatwg), plus single-package organizations for IEEE, IEC, ECMA, INCITS, ARM, Intel, RISC-V, and Microsoft. `swift-standards` itself retains the cross-body and historical packages.

## Repository Contents

| Directory | Contents |
|-----------|----------|
| [`Blog/`](Blog) | Blog posts (drafts, published), the ideas index, style guide, and series plans |
| [`Documentation.docc/`](Documentation.docc) | Architecture documentation — the five-layer model, naming conventions, shared vocabulary |
| [`Experiments/`](Experiments) | Minimal reproductions — each experiment is a Swift package testing one claim, used as receipts for blog posts |
| [`References/`](References) | BibTeX files — academic and industry sources cited in research documents |
| [`Research/`](Research) | Design rationale, trade-off analyses, and investigation notes. Non-normative |
| [`Skills/`](Skills) | Development conventions — naming, errors, memory safety, testing, modularization. Each skill is the canonical source for its conventions |
| [`SE-Pitches/`](SE-Pitches) | Draft proposals for Swift Evolution |
| [`Scripts/`](Scripts) | Scripts used by the institute's own processes |

## Status

This is an early public release. The documentation, research, experiments, and blog workflow in this repository are available now. The Swift package layers they describe are being released repository by repository over the coming weeks. Some links from blog posts and research documents point to repositories that are not yet world-readable; those links resolve as the release tags land.

If you arrived here from a blog post's receipt link, you're looking at the minimal Swift package that backs a specific technical claim. The relevant experiment lives in [`Experiments/`](Experiments) and can be cloned and built with `swift build` on Swift 6.3 or newer.

## Requirements

- Swift 6.3+
- macOS 26.0+ / iOS 26.0+ / Linux

## License

All packages use the Apache License 2.0. See [LICENSE.md](LICENSE.md).
