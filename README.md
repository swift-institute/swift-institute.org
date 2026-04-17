# Swift Institute

Documentation, conventions, and research for a layered Swift package ecosystem.

## Overview

Swift Institute is a layered Swift package ecosystem — primitives, standards implementations, and composed foundations — aimed at correctness, composability, and long-term evolution. Shared conventions across layers let compile-time guarantees hold across the stack rather than stopping at package boundaries.

## Technical Approach

The ecosystem is organized into layers, each with its own GitHub organization. Packages in each layer may depend on packages in their own layer and in layers below, never above. `swift-primitives` depends only on itself. `swift-standards` may depend on `swift-primitives`. `swift-foundations` may depend on both.

Every repository is a standalone Swift package with its own version history, release tags, and `Package.swift`. Consumers depend on individual packages directly — a `.package(url: ...)` line per dependency — rather than on umbrella imports. The superrepos (`swift-primitives`, `swift-standards`, `swift-foundations`) are git submodule aggregators that exist for browsing, not for consumption.

`swift-standards` is primarily an organization of organizations. Each standards body has its own GitHub organization hosting its specifications, so governance, release cadence, and audience align with real-world specification authority. The question each organization name answers is "who standardized this?"

Shared conventions live as Skills — the canonical source for naming, errors, memory safety, testing, modularization, and more. Research documents record architectural rationale. Experiments reduce claims to runnable Swift packages. Blog posts link load-bearing claims directly to those experiments, so readers can verify rather than trust.

## The Ecosystem

| Layer | Organization | Status |
|-------|--------------|--------|
| 1 | [swift-primitives](https://github.com/swift-primitives) | released |
| 2 | [swift-standards](https://github.com/swift-standards) + per-authority orgs | released |
| 3 | [swift-foundations](https://github.com/swift-foundations) | released |
| 4 | Components | planned |
| 5 | Applications | planned |

> **Release in progress.** Packages are being released repository by repository on a rolling basis. Some links may currently return 404; they resolve as each release tag lands.

The per-authority organizations include [swift-ietf](https://github.com/swift-ietf) (RFCs), [swift-iso](https://github.com/swift-iso), [swift-w3c](https://github.com/swift-w3c), and [swift-whatwg](https://github.com/swift-whatwg), plus additional per-authority organizations for other standards bodies. `swift-standards` itself retains the cross-body and historical packages.

## Repository Contents

| Directory | Contents |
|-----------|----------|
| [`Audits/`](Audits) | Repository- and ecosystem-level audit reports |
| [`Blog/`](Blog) | Blog posts (drafts, published), the ideas index, style guide, and series plans |
| [`Skills/`](Skills) | Development conventions — naming, errors, memory safety, testing, modularization. Each skill is the canonical source for its conventions |
| [`Swift Evolution/`](Swift%20Evolution) | Draft proposals for Swift Evolution |
| [`Swift Institute.docc/`](Swift%20Institute.docc) | Public-facing DocC documentation — architecture, platform, per-layer articles, blog |
| [`Scripts/`](Scripts) | Scripts used by the institute's own processes (see [Scripts/README.md](Scripts/README.md)) |

## Related Repositories

| Repository | Contents |
|------------|----------|
| [swift-institute/Research](https://github.com/swift-institute/Research) | Design rationale, trade-off analyses, and investigation notes (includes `Reflections/` for post-session reflections). Non-normative |
| [swift-institute/Experiments](https://github.com/swift-institute/Experiments) | Minimal reproductions — each experiment is a standalone Swift package testing one claim, used as receipts for blog posts |

## Where to start

| If you are... | Read |
|---------------|------|
| Evaluating whether this is worth your time | [FAQ](Swift%20Institute.docc/FAQ.md) |
| Trying to understand the architecture | [Architecture](Swift%20Institute.docc/Architecture.md) |
| Looking for conventions to adopt | [Skills/](Skills) |
| Here from a blog post's receipt link | [swift-institute/Experiments](https://github.com/swift-institute/Experiments) — each subdirectory is a standalone Swift package exercising one investigation; multi-variant packages address related claims through separate targets |
| Curious why a decision was made a particular way | [swift-institute/Research](https://github.com/swift-institute/Research) — design rationale and trade-off analyses |

## Status

This is an early public release, maintained by [Coen ten Thije Boonkkamp](https://github.com/coenttb). The documentation, research, experiments, and blog workflow in this repository are available now. The Swift package layers they describe are being released repository by repository on a rolling basis. Some links from blog posts and research documents point to repositories that are not yet world-readable; those links resolve as the release tags land.

If you arrived here from a blog post's receipt link, you're looking at the minimal Swift package that backs a specific technical claim. The relevant experiment lives in [swift-institute/Experiments](https://github.com/swift-institute/Experiments) and can be cloned and built with `swift build` on Swift 6.3 or newer.

## Requirements

- Swift 6.3+
- macOS 26.0+ / iOS 26.0+ / Linux

## License

Each repository carries its own `LICENSE.md` file. See [LICENSE.md](LICENSE.md) for this repository.
