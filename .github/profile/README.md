# Swift Institute

A layered Swift package ecosystem organized around shared conventions.

## What this is

Swift Institute is a set of layered Swift packages organized as separate GitHub
organizations, one per layer. The layers share dependency rules, naming
conventions, error handling, memory ownership, and API shape — so that
compile-time guarantees hold across the entire stack rather than stopping at
package boundaries.

| Layer | Organization | Status |
|-------|--------------|--------|
| 1 | [swift-primitives](https://github.com/swift-primitives) | released |
| 2 | [swift-standards](https://github.com/swift-standards) + per-authority orgs | released |
| 3 | [swift-foundations](https://github.com/swift-foundations) | released |
| 4 | Components | planned |
| 5 | Applications | planned |

> **Release in progress.** Packages are being released on a rolling basis. Some links may currently 404; they resolve as each release tag lands.

Layer 2 is an organization of organizations. Each standards authority has its
own GitHub organization:
[swift-ietf](https://github.com/swift-ietf) (RFCs),
[swift-iso](https://github.com/swift-iso),
[swift-w3c](https://github.com/swift-w3c),
[swift-whatwg](https://github.com/swift-whatwg),
plus additional per-authority organizations for other standards bodies.

## Where to go next

| If you want to... | Go to |
|-------------------|-------|
| Understand the architecture, read conventions, or browse research | [swift-institute.org](https://github.com/swift-institute/swift-institute.org) — the website + meta-repository, with companion repos [Research](https://github.com/swift-institute/Research) and [Experiments](https://github.com/swift-institute/Experiments) |
| Use atomic primitives | [swift-primitives](https://github.com/swift-primitives) |
| Consume an RFC or ISO specification | [swift-ietf](https://github.com/swift-ietf), [swift-iso](https://github.com/swift-iso), or the relevant per-authority org |
| Use composed building blocks | [swift-foundations](https://github.com/swift-foundations) |
| Read the blog | [swift-institute.org/tree/main/Blog](https://github.com/swift-institute/swift-institute.org/tree/main/Blog) |
| Report an issue or contribute | Open an issue or pull request on the relevant repository |
| Report a security vulnerability | [Private security advisory](https://github.com/swift-institute/swift-institute.org/security/advisories/new) |

## Status

Initial public alpha. The meta-repository
([swift-institute/swift-institute.org](https://github.com/swift-institute/swift-institute.org))
is public, alongside companion repos [swift-institute/Research](https://github.com/swift-institute/Research) and [swift-institute/Experiments](https://github.com/swift-institute/Experiments). The package layers they describe are being released repository by
repository on a rolling basis.

Maintained by [Coen ten Thije Boonkkamp](https://github.com/coenttb).

## License

Each repository carries its own `LICENSE.md` file.
