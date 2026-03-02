---
name: readme
description: |
  README conventions: required sections, badges, maturity tiers, monorepo patterns.
  Apply when creating or reviewing README.md files.

layer: implementation

requires:
  - swift-institute

applies_to:
  - swift-primitives
  - swift-standards
  - swift-foundations
  - swift-institute
  - readme
---

# README

Conventions for README.md files across the Swift Institute ecosystem. Covers required sections, ordering, badges, maturity tiers, monorepo patterns, and maintenance obligations.

## Workflow Position

READMEs can be written at any point — even before implementation (README-driven development). Unlike `/documentation` (which synthesizes after implementation), READMEs describe **what the package does and how to use it** and can evolve alongside the code.

| Phase | README State |
|-------|-------------|
| Pre-implementation | Title, badge, one-liner, architecture sketch |
| Active development | + Installation, Quick Start |
| Feature-complete | + Key Features, Platform Support, Error Handling |
| v1.0+ | Full README with all applicable sections |

**Scope**: All README.md files in package roots and sub-package roots. Inline DocC and .docc catalogue conventions are covered by the **documentation** skill.

---

## Structure

### [README-001] Required Sections and Ordering

**Statement**: README.md files MUST follow the section order below. Optional sections MAY be omitted if genuinely not applicable.

**Required sections (in order)**:

1. **Title and badges** — Package name as H1, followed by badges
2. **One-liner** — Single sentence describing what the package does
3. **Key Features** — 4–8 bullets of primary capabilities
4. **Installation** — Package.swift dependency and target configuration
5. **Quick Start** — Minimal working example (10–20 lines)
6. **Architecture** — Layer diagram or key types table
7. **Platform Support** — Supported platforms and CI status
8. **License** — License type with link to LICENSE file

**Correct**:
```markdown
# swift-io

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

A high-performance async I/O executor for Swift.

## Key Features
- **Typed throws end-to-end** — No `any Error` escapes

## Installation
...
```

**Incorrect**:
```markdown
# swift-io

## Installation  <!-- ❌ Missing one-liner and badges -->
...

## Key Features  <!-- ❌ Wrong section order -->
```

**Rationale**: Predictable structure enables consistent developer experience across all packages.

---

### [README-002] Maturity Tiers

**Statement**: READMEs MUST meet the minimum tier for their package's maturity. Packages SHOULD progress through tiers as they develop.

| Tier | When | Required Sections |
|------|------|-------------------|
| Minimum | All packages, always | Title, badge, one-liner, Installation, License |
| Standard | Packages with public API documentation | + Key Features, Quick Start, Architecture, Platform Support |
| Complete | Packages at v1.0+ or with external users | + Error Handling, Related Packages, optional sections as applicable |

**Minimum-tier example**:
```markdown
# swift-pool-primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Pool allocation primitives for Swift.

## Installation

` ` `swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-pool-primitives.git", from: "0.1.0")
]
` ` `

## License

Apache 2.0. See [LICENSE](LICENSE).
```

**Rationale**: The ecosystem has 61+ packages. Requiring full READMEs for all packages immediately is impractical. Tiers provide a clear upgrade path while ensuring every package has at minimum: identity (title + badge), purpose (one-liner), usability (installation), and legal clarity (license).

---

### [README-015] Optional Sections

**Statement**: Optional sections MAY be inserted at logically appropriate positions. Recognized optional sections:

- **Table of Contents** — READMEs > ~200 lines
- **Design Philosophy** — Goals and explicit non-goals
- **Why This Package?** — Comparison with alternatives
- **Performance** — Benchmarks with methodology
- **Usage Examples** — Beyond Quick Start
- **Error Handling** — Typed error hierarchy (MUST for packages with typed throws per [README-013])
- **Configuration** — Configurable parameters
- **Monitoring** — Observability hooks
- **Testing** — Test patterns specific to the package
- **Test Support** — Test utilities exported for consumers
- **Related Packages** — Dependencies, dependents, third-party
- **Contributing** — Or link to CONTRIBUTING.md
- **Acknowledgments** — Credits

**Rationale**: Flexibility for package-specific needs while maintaining core structure consistency.

---

### [README-016] Prohibited Content

**Statement**: READMEs MUST NOT include:

| Prohibited | Reason | Alternative |
|-----------|--------|-------------|
| Roadmaps or TODOs | Stale quickly, create false expectations | GitHub Issues / Milestones |
| Changelogs | Belongs in dedicated file | CHANGELOG.md or GitHub Releases |
| Failing CI badges | Signals unacknowledged technical debt | Remove badge until CI passes |
| Screenshots | Unless package is inherently visual | Link to docs instead |
| Marketing language without substance | Violates documentation purpose | Use technical descriptions |

**Rationale**: Excluded content either belongs elsewhere or degrades README quality.

---

## Badges

### [README-003] Development Status Badge

**Statement**: Every README MUST include a development status badge as the first badge, immediately after the H1 title.

```markdown
![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
```

**Allowed status values**:

| Status | Badge | Meaning |
|--------|-------|---------|
| `active--development` | blue | Active work, API may change |
| `stable` | green | Production-ready, semantic versioning enforced |
| `maintenance` | yellow | Bug fixes only |
| `experimental` | red | Proof of concept |

**Incorrect**:
```markdown
![Status](https://img.shields.io/badge/status-beta-yellow.svg)  <!-- ❌ Non-standard status -->
```

**Rationale**: Consistent status vocabulary enables accurate assessment of package maturity.

---

### [README-004] CI Badge

**Statement**: CI badges MAY be included only when CI is configured and passing.

```markdown
[![CI](https://github.com/{ORG}/{REPO}/workflows/CI/badge.svg)](https://github.com/{ORG}/{REPO}/actions/workflows/ci.yml)
```

A failing CI badge MUST be removed until CI passes. An absent CI should not display as present.

**Rationale**: Failing CI badges signal unacknowledged technical debt.

---

### [README-005] Swift Package Index Badges

**Statement**: When a package is published to Swift Package Index, SPI endpoint badges SHOULD be included after the development status badge. SPI badges are preferred over static version/platform badges because they auto-update from build results.

```markdown
[![Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F{owner}%2F{repo}%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/{owner}/{repo})
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F{owner}%2F{repo}%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/{owner}/{repo})
```

**Badge ordering**:

1. Development status (required — [README-003])
2. SPI Swift versions (recommended)
3. SPI platforms (recommended)
4. CI status (optional — [README-004])

**Rationale**: SPI badges reflect actual build results, not manually maintained claims. They auto-update when SPI rebuilds the package, eliminating badge maintenance.

---

## One-Liner

### [README-006] One-Liner Requirements

**Statement**: The one-liner MUST:

- Be a single sentence
- Describe **what** the package does, not how
- End with a period
- Include quantified claims where appropriate

The one-liner MUST NOT:

- Start with "A Swift package for ..."
- Use marketing language without technical substance
- Include implementation details

**Correct**:
```
A high-performance async I/O executor for Swift. Isolates blocking syscalls from Swift's cooperative thread pool.
```

```
Convert HTML to PDF on Apple platforms using WKWebView. Processes 1,939 PDFs/sec continuous mode with 35 MB steady-state memory.
```

**Incorrect**:
```
A Swift package for doing I/O operations.  <!-- ❌ Starts with "A Swift package for" -->
```

```
The best I/O library you'll ever use!  <!-- ❌ Marketing without substance -->
```

**Rationale**: Technical precision in descriptions enables accurate package selection and comparison.

---

## Key Features

### [README-007] Key Features Format

**Statement**: Key Features sections MUST:

- Contain 4–8 bullets
- Start each bullet with a **bold keyword**
- Use a single line per bullet
- Use `—` (em dash) to separate keyword from description

**Correct**:
```markdown
## Key Features

- **Typed throws end-to-end** — No `any Error` escapes the API surface
- **Swift 6 strict concurrency** — Full `Sendable` compliance
- **Zero-copy where possible** — Minimizes allocation overhead
- **Cross-platform** — macOS, Linux, and Windows support
```

**Incorrect**:
```markdown
- This library uses typed throws throughout the entire codebase to ensure
  that errors are always handled properly.  <!-- ❌ Multi-line, no bold keyword -->
- Fast  <!-- ❌ No explanation -->
- ✅ Supports typed throws  <!-- ❌ Emoji checkbox instead of bold keyword -->
```

**Rationale**: Consistent bullet format enables quick scanning and comparison across packages. The bold keyword pattern allows reading just the keywords for a feature overview.

---

## Installation

### [README-008] Installation Format

**Statement**: Installation sections MUST include both Package.swift dependency AND target configuration blocks.

**Package.swift Dependency**:
```swift
dependencies: [
    .package(url: "https://github.com/{ORG}/{REPO}.git", from: "X.Y.Z")
]
```

**Target Dependency**:
```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "ProductName", package: "package-name")
    ]
)
```

Requirements (Swift version, platform minimums) MUST be listed immediately after installation blocks when applicable.

**Rationale**: Copy-paste-ready installation blocks reduce integration friction. Both blocks are needed because SPM requires separate dependency and target configuration.

---

## Quick Start

### [README-009] Quick Start Requirements

**Statement**: Quick Start examples MUST:

- Be copy-paste runnable
- Show the primary use case
- Include all required imports
- Be 10–20 lines

If the package has multiple entry points, show up to three distinct quick starts.

**Correct**:
```swift
import IO

let executor = try IO.Executor()
let result = try await executor.read(from: path)
print(result)
```

**Incorrect**:
```swift
// Assume you have an executor configured...
let result = try await executor.read(from: path)  // ❌ Missing import, setup
```

**Rationale**: Runnable examples enable immediate verification. A Quick Start that requires context from other sections defeats its purpose.

---

## Architecture

### [README-010] Architecture Section

**Statement**: Multi-module or layered packages MUST include an ASCII layer diagram showing dependency direction. Simpler packages MAY instead include a table of key public types with one-line descriptions.

**ASCII diagram** (multi-module):
```
┌─────────────────────────────────────────────┐
│                    API                       │  ← User-facing types
├─────────────────────────────────────────────┤
│                  Core                        │  ← Business logic
├─────────────────────────────────────────────┤
│                Primitives                    │  ← Platform abstraction
└─────────────────────────────────────────────┘
```

**Key types table** (single-module):

| Type | Purpose |
|------|---------|
| `Buffer.Ring.Inline<E, N>` | Fixed-capacity FIFO ring buffer |
| `Buffer.Ring.Inline.Iterator` | Consuming iteration |

**Rationale**: Visual architecture aids comprehension of package structure.

---

## Platform Support

### [README-011] Platform Support Table

**Statement**: Platform support MUST be expressed using a table with Platform, CI, and Status columns.

| Platform | CI | Status |
|----------|-----|--------|
| macOS | Yes | Full support |
| Linux | Yes | Full support |
| Windows | Yes | Full support |
| iOS/tvOS/watchOS | — | Supported |
| Swift Embedded | — | Supported |

**Allowed status values**:

| Status | Meaning |
|--------|---------|
| `Full support` | CI-tested, production-ready |
| `Supported` | Works, not CI-tested |
| `Planned` | Architecture ready, implementation pending |
| `Possible` | Could be supported with work |
| `Not supported` | Fundamental limitation |

**Rationale**: Standardized platform tables enable platform compatibility queries across packages.

---

## Performance

### [README-012] Performance Documentation

**Statement**: When performance data is included, hardware, OS, Swift version, and what is actually being measured MUST be stated. Performance comparisons MUST be tabular.

**Correct**:
```markdown
## Performance

Benchmarked on M1 Mac Mini, macOS 14.0, Swift 5.10.

| Operation | Throughput | p99 Latency | Memory |
|-----------|------------|-------------|--------|
| Read      | 150K ops/s | 2.3ms       | 12 MB  |
| Write     | 120K ops/s | 3.1ms       | 15 MB  |
```

**Incorrect**:
```markdown
## Performance

This library is very fast.  <!-- ❌ No methodology, no data -->
```

Include only meaningful metrics: throughput, latency (p50, p95, p99), memory (steady-state and peak).

**Rationale**: Reproducible benchmarks enable accurate performance comparisons and prevent misleading claims.

---

## Error Handling

### [README-013] Error Handling Section

**Statement**: Packages using typed throws MUST include an Error Handling section documenting the full error shape using ASCII tree notation AND an exhaustive pattern matching example.

**Error hierarchy**:
```
IO.Lifecycle.Error<E>
├── .shutdownInProgress    // Lifecycle: pool shutting down
├── .cancelled             // Lifecycle: task cancelled
└── .failure(E)            // Wraps operational errors
    └── IO.Error<Leaf>
        ├── .leaf(Leaf)    // Your operation's error type
        ├── .handle(...)   // Handle errors
        ├── .executor(...) // Executor errors
        └── .lane(...)     // Lane errors
```

**Exhaustive matching**:
```swift
do {
    try await executor.submit(work)
} catch .shutdownInProgress {
    // Handle shutdown
} catch .cancelled {
    // Handle cancellation
} catch .failure(let ioError) {
    switch ioError {
    case .leaf(let leaf): // Handle leaf
    case .handle(let h): // Handle handle error
    // ... exhaustive
    }
}
```

**Rationale**: Visual error hierarchies + matching examples enable correct error handling code without reading source.

---

## Related Packages

### [README-014] Related Packages Organization

**Statement**: When included, Related Packages MUST be organized into subsections (omit empty subsections):

**Dependencies**: Packages this package depends on.
```markdown
- [swift-kernel-primitives](url) — Typed kernel syscall wrappers.
```

**Used By**: Packages that depend on this package.
```markdown
- [swift-io](url) — High-performance async I/O executor.
```

**Third-Party Dependencies**: External dependencies not maintained by this organization.
```markdown
- [swift-argument-parser](url) — Command-line argument parsing.
```

**Rationale**: Structured dependency documentation enables package graph traversal.

---

## Formatting

### [README-017] Formatting Rules

**Statement**: README formatting rules:

| Rule | Requirement |
|------|-------------|
| Section separators | `---` between major sections |
| H1 | Package name only — one H1 per README |
| Heading depth | H2 and H3 only; no deeper nesting |
| Code blocks | MUST specify language (`swift`, `bash`, `markdown`) |
| Tables | MUST be column-aligned |

**Rationale**: Consistent formatting enables predictable document parsing across all packages.

---

## Code Examples

### [README-022] Code Examples in README

**Statement**: All code examples in README MUST:

1. Include all required `import` statements
2. Use domain-meaningful identifiers (NOT `Foo`, `Bar`, `x`, `y`)
3. Be copy-paste runnable where possible

Non-trivial examples SHOULD demonstrate error handling explicitly.

**Correct**:
```swift
import IO

let connection = try Network.Connection(host: "api.example.com", port: 443)
```

**Incorrect**:
```swift
let foo = try Bar(x: "...", y: 123)  // ❌ Meaningless identifiers, missing import
```

**Rationale**: Complete, realistic examples demonstrate actual usage patterns and enable immediate verification.

**Cross-references**: [DOC-050]

---

## Monorepo Patterns

### [README-018] Monorepo Root README

**Statement**: Monorepo root READMEs MUST include:

1. Title and badges for the monorepo itself
2. One-liner describing the monorepo's scope
3. Package inventory table listing all sub-packages
4. Architecture overview (layer diagram showing package relationships)
5. Installation (how to depend on individual packages)

**Package inventory table**:

| Package | Description | Tier |
|---------|-------------|------|
| swift-buffer-primitives | Buffer containers (ring, linear, slab, arena) | 3 |
| swift-memory-primitives | Typed memory regions and allocation | 1 |
| ... | ... | ... |

**Rationale**: The monorepo root README is the entry point for the entire collection. Without a package inventory, developers cannot discover what's available.

---

### [README-019] Sub-Package README

**Statement**: Sub-packages within a monorepo SHOULD have their own README.md. Sub-package READMEs are self-contained — they MUST NOT assume the reader has seen the monorepo root README.

Self-contained means: the sub-package README includes its own title, badge, one-liner, installation (with the full monorepo URL), and any other applicable sections per [README-002] maturity tiers.

**Installation in sub-package README** (note: URL points to monorepo):
```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-primitives.git", from: "0.1.0")
]
// ...
.product(name: "Buffer_Ring_Inline_Primitives", package: "swift-primitives")
```

**Rationale**: Developers often land on a sub-package README via search or link. A self-contained README serves them without requiring navigation to the monorepo root.

---

### [README-020] GitHub Organization Profile README

**Statement**: GitHub organization profile READMEs (`.github/profile/README.md`) are a distinct artifact from package READMEs. They render on the GitHub organization landing page and SHOULD include:

1. Organization name and one-liner
2. Brief description of the ecosystem's purpose
3. Key repositories with links
4. Architecture overview (the five-layer diagram)

Organization profile READMEs MUST NOT include: installation instructions, code examples, or package-specific content.

**Rationale**: The organization profile README is the top-level entry point for the entire GitHub organization. Its job is navigation, not documentation.

---

## Maintenance

### [README-021] Maintenance Obligations

**Statement**: README maintenance obligations:

| Obligation | Requirement |
|-----------|-------------|
| Performance numbers | MUST be kept current with each major release |
| Installation snippets | MUST match latest release version |
| Links | MUST all be valid; prefer relative links |
| Badge status | MUST reflect actual package state |
| Platform Support | MUST reflect actual CI and testing state |

**Rationale**: Stale READMEs generate incorrect usage patterns and erode user trust.

---

## Cross-References

- **documentation** skill — Inline DocC and .docc catalogue conventions
- **swift-institute** skill — Five-layer architecture referenced in Architecture sections
- Research: `swift-institute/Research/readme-skill-design.md`
- Source: `Documentation Standards.md` (absorbed into this skill and the documentation skill)
