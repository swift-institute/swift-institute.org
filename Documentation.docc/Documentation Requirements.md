# Documentation Requirements

<!--
---
title: Documentation Requirements
version: 2.0.0
last_updated: 2026-01-16
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Documentation standards for README files and inline DocC documentation.

## Overview

This document defines the non-negotiable documentation standards for all packages in this repository.
These requirements apply to **README.md** files and **inline (DocC) documentation**, and are normative unless an explicit, reviewed exception is recorded.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

This document is complementary to <doc:Implementation> and MUST be interpreted consistently with it. Where conflicts arise, API Requirements takes precedence.

---

## Scope and Intent

**Applies to**: All README.md files, DocC documentation, and code comments in swift-primitives, swift-institute, and swift-standards packages.

**Does not apply to**: Generated documentation, changelog files, or GitHub release notes.

---

### [DOC-SCOPE-001] Documentation Purpose

**Scope**: All documentation artifacts.

**Statement**: Documentation in this repository serves three purposes only:

1. Make the **behavioral contract** of APIs explicit
2. Make **architecture and layering** mechanically understandable
3. Enable **correct use without reading implementation code**

Documentation MUST NOT serve as:
- Marketing material
- Roadmap or planning document
- Tutorial series or educational content

**Rationale**: Focused documentation enables accurate LLM retrieval and prevents scope creep that dilutes technical precision.

**Cross-references**: [DOC-README-001], [API-DOC-001]

---

## README Structure

**Applies to**: All README.md files in package roots.

**Does not apply to**: README files in example directories or documentation folders.

---

### [DOC-README-001] Required Sections

**Scope**: All package README.md files.

**Statement**: README.md files MUST follow the section order below. Optional sections MAY be omitted if genuinely not applicable.

**Required sections (in order)**:

1. **Title and badges** - Package name as H1, followed by badges
2. **One-liner** - Single sentence describing what the package does
3. **Key Features** - 4-8 bullets of primary capabilities
4. **Installation** - Package.swift dependency and target configuration
5. **Quick Start** - Minimal working example (10-20 lines)
6. **Architecture** - Layer diagram or key types table
7. **Platform Support** - Supported platforms and CI status
8. **License** - License type with link to LICENSE file

**Correct**:
```markdown
# swift-io

![Development Status](...)

A high-performance async I/O executor for Swift.

## Key Features
- **Typed throws end-to-end** - No `any Error` escapes

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

**Rationale**: Predictable structure enables reliable LLM section retrieval and consistent developer experience.

**Cross-references**: [DOC-README-002], [DOC-SCOPE-001]

---

### [DOC-README-002] Optional Sections

**Scope**: Package README.md files requiring additional content.

**Statement**: Optional sections MAY be inserted at logically appropriate positions. The following optional sections are recognized:

- Table of Contents (READMEs > ~200 lines)
- Design Philosophy (goals and explicit non-goals)
- Performance
- Why This Package?
- Usage Examples
- Error Handling
- Configuration
- Monitoring
- Testing
- Test Support
- Related Packages
- Contributing
- Acknowledgments

**Rationale**: Flexibility for package-specific needs while maintaining core structure consistency.

**Cross-references**: [DOC-README-001]

---

## Badges

**Applies to**: Badge sections in README.md files.

**Does not apply to**: Inline status indicators in documentation.

---

### [DOC-BADGE-001] Required Development Status Badge

**Scope**: All README.md files.

**Statement**: Every README MUST include a development status badge as the first badge.

**Correct**:
```markdown
![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
```

**Allowed status values**:

| Status | Meaning |
|--------|---------|
| `active--development` | Active work, API may change |
| `stable` | Production-ready, semantic versioning enforced |
| `maintenance` | Bug fixes only |
| `experimental` | Proof of concept |

**Incorrect**:
```markdown
![Status](https://img.shields.io/badge/status-beta-yellow.svg)  <!-- ❌ Non-standard status -->
```

**Rationale**: Consistent status vocabulary enables accurate LLM assessment of package maturity.

**Cross-references**: [DOC-BADGE-002]

---

### [DOC-BADGE-002] Optional CI Badges

**Scope**: CI status badges.

**Statement**: CI badges MAY be included only when CI is configured and passing.

**Correct**:
```markdown
[![CI](https://github.com/ORG/REPO/workflows/CI/badge.svg)](https://github.com/ORG/REPO/actions/workflows/ci.yml)
```

**Incorrect**:
```markdown
[![CI](https://github.com/ORG/REPO/workflows/CI/badge.svg)](...)  <!-- ❌ CI not configured or failing -->
```

**Rationale**: Failing CI badges signal technical debt; absent CI should not display as present.

**Cross-references**: [DOC-BADGE-001], [DOC-MAINT-001]

---

## One-Liner Description

**Applies to**: The one-liner description immediately following badges.

---

### [DOC-ONELINER-001] One-Liner Requirements

**Scope**: Package description one-liners.

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

**Rationale**: Technical precision in descriptions enables accurate LLM package selection and comparison.

**Cross-references**: [DOC-README-001]

---

## Key Features

**Applies to**: Key Features sections in README.md files.

---

### [DOC-FEATURES-001] Key Features Format

**Scope**: Key Features bullet lists.

**Statement**: Key Features sections MUST:

- Contain 4-8 bullets
- Start each bullet with a bold keyword
- Use a single line per bullet

**Correct**:
```markdown
- **Typed throws end-to-end** - No `any Error` escapes the API surface
- **Swift 6 strict concurrency** - Full `Sendable` compliance
- **Zero-copy where possible** - Minimizes allocation overhead
- **Cross-platform** - macOS, Linux, and Windows support
```

**Incorrect**:
```markdown
- This library uses typed throws throughout the entire codebase to ensure
  that errors are always handled properly.  <!-- ❌ Multi-line, no bold keyword -->
- Fast  <!-- ❌ No explanation -->
```

**Rationale**: Consistent bullet format enables LLM feature extraction and comparison across packages.

**Cross-references**: [DOC-README-001]

---

## Installation

**Applies to**: Installation sections in README.md files.

---

### [DOC-INSTALL-001] Installation Format

**Scope**: Package installation instructions.

**Statement**: Installation sections MUST include Package.swift dependency and target configuration blocks.

**Package.swift Dependency**:
```swift
dependencies: [
    .package(url: "https://github.com/ORG/REPO.git", from: "X.Y.Z")
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

Requirements MUST be listed immediately after installation blocks when applicable.

**Rationale**: Copy-paste-ready installation blocks reduce integration friction and LLM generation errors.

**Cross-references**: [DOC-MAINT-001]

---

## Quick Start

**Applies to**: Quick Start sections in README.md files.

---

### [DOC-QUICKSTART-001] Quick Start Requirements

**Scope**: Quick Start code examples.

**Statement**: Quick Start examples MUST:

- Be copy-paste runnable
- Show the primary use case
- Include all required imports
- Be 10-20 lines

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

**Rationale**: Runnable examples enable immediate verification and accurate LLM code generation.

**Cross-references**: [DOC-CODE-001]

---

## Architecture

**Applies to**: Architecture sections in README.md files.

---

### [DOC-ARCH-001] Layer Diagram Requirement

**Scope**: Multi-module or layered packages.

**Statement**: Multi-module or layered packages MUST include an ASCII layer diagram showing dependency direction.

**Correct**:
```
┌─────────────────────────────────────────────┐
│                    API                       │  ← User-facing types
├─────────────────────────────────────────────┤
│                  Core                        │  ← Business logic
├─────────────────────────────────────────────┤
│                Primitives                    │  ← Platform abstraction
└─────────────────────────────────────────────┘
```

Simpler packages MAY instead include a table of key public types with one-line descriptions.

**Rationale**: Visual architecture aids LLM comprehension of package structure and appropriate usage patterns.

**Cross-references**: [API-LAYER-001]

---

## Platform Support

**Applies to**: Platform Support sections in README.md files.

---

### [DOC-PLATFORM-001] Platform Support Table

**Scope**: Platform compatibility documentation.

**Statement**: Platform support MUST be expressed using a table with the following columns and allowed status values.

**Correct**:
| Platform         | CI  | Status       |
|------------------|-----|--------------|
| macOS            | Yes | Full support |
| Linux            | Yes | Full support |
| Windows          | Yes | Full support |
| iOS/tvOS/watchOS | -   | Supported    |

**Allowed status values**:

| Status | Meaning |
|--------|---------|
| `Full support` | CI-tested, production-ready |
| `Supported` | Works, not CI-tested |
| `Planned` | Architecture ready, implementation pending |
| `Possible` | Could be supported with work |
| `Not supported` | Fundamental limitation |

**Rationale**: Standardized platform tables enable LLM platform compatibility queries.

**Cross-references**: [API-PLAT-001]

---

## Performance Documentation

**Applies to**: Performance sections when included.

**Does not apply to**: General feature descriptions mentioning performance.

---

### [DOC-PERF-001] Performance Methodology

**Scope**: Performance data and benchmarks.

**Statement**: When performance data is included, hardware, OS, Swift version, and what is actually being measured MUST be stated.

**Correct**:
```markdown
## Performance

Benchmarked on M1 Mac Mini, macOS 14.0, Swift 5.10.

| Operation | Throughput | p99 Latency |
|-----------|------------|-------------|
| Read      | 150K ops/s | 2.3ms       |
| Write     | 120K ops/s | 3.1ms       |
```

**Incorrect**:
```markdown
## Performance

This library is very fast.  <!-- ❌ No methodology, no data -->
```

**Rationale**: Reproducible benchmarks enable accurate performance comparisons and prevent misleading claims.

**Cross-references**: [DOC-PERF-002]

---

### [DOC-PERF-002] Performance Data Format

**Scope**: Performance comparisons and metrics.

**Statement**: Performance comparisons MUST be tabular. Include only meaningful metrics:

- Throughput
- Latency (p50, p95, p99)
- Memory (steady-state and peak)

**Rationale**: Tabular data is machine-parseable and enables LLM extraction of specific metrics.

**Cross-references**: [DOC-PERF-001]

---

## Error Handling Documentation

**Applies to**: Error Handling sections for packages using typed throws.

---

### [DOC-ERR-001] Error Hierarchy Documentation

**Scope**: Packages with typed error hierarchies.

**Statement**: Packages using typed throws MUST include an Error Handling section documenting the full error shape using ASCII notation.

**Correct**:
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

**Rationale**: Visual error hierarchies enable LLM-generated exhaustive error handling code.

**Cross-references**: [API-ERR-001], [DOC-ERR-002]

---

### [DOC-ERR-002] Exhaustive Matching Example

**Scope**: Error handling examples.

**Statement**: Error documentation MUST provide an example showing exhaustive pattern matching over the error type.

**Correct**:
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

**Rationale**: Exhaustive examples demonstrate proper typed error handling and guide LLM code generation.

**Cross-references**: [DOC-ERR-001], [API-ERR-001]

---

## Related Packages

**Applies to**: Related Packages sections when included.

---

### [DOC-RELATED-001] Related Packages Organization

**Scope**: Package relationship documentation.

**Statement**: When included, Related Packages MUST be organized into the following subsections (omit empty subsections):

**Dependencies**: Packages this package depends on
```markdown
- [package-name](url): One-line description.
```

**Used By**: Packages that depend on this package
```markdown
- [package-name](url): One-line description.
```

**Third-Party Dependencies**: External dependencies not maintained by this organization
```markdown
- [org/package-name](url): One-line description.
```

**Rationale**: Structured dependency documentation enables LLM package graph traversal.

**Cross-references**: [DOC-README-002]

---

## Code Examples

**Applies to**: All code examples in documentation.

---

### [DOC-CODE-001] Import Requirements

**Scope**: All code blocks.

**Statement**: Every code block MUST include required imports.

**Correct**:
```swift
import IO

let executor = try IO.Executor()
```

**Incorrect**:
```swift
let executor = try IO.Executor()  // ❌ Missing import
```

**Rationale**: Complete imports enable copy-paste execution and accurate LLM code generation.

**Cross-references**: [DOC-QUICKSTART-001], [DOC-CODE-002]

---

### [DOC-CODE-002] Realistic Naming

**Scope**: Identifiers in code examples.

**Statement**: Code examples MUST use domain-meaningful identifiers. MUST NOT use placeholders like `Foo`, `Bar`, `x`, `y`.

**Correct**:
```swift
let connection = try Network.Connection(host: "api.example.com", port: 443)
```

**Incorrect**:
```swift
let foo = try Bar(x: "...", y: 123)  // ❌ Meaningless identifiers
```

**Rationale**: Realistic names demonstrate actual usage patterns and prevent LLM-generated placeholder code.

**Cross-references**: [DOC-CODE-001], [DOC-CODE-003]

---

### [DOC-CODE-003] Error Handling in Examples

**Scope**: Non-trivial code examples.

**Statement**: Non-trivial examples SHOULD demonstrate error handling explicitly.

**Correct**:
```swift
do {
    let result = try await executor.read(from: path)
    process(result)
} catch {
    log.error("Read failed: \(error)")
}
```

**Rationale**: Error handling examples establish proper patterns for production code.

**Cross-references**: [DOC-ERR-002], [DOC-CODE-004]

---

### [DOC-CODE-004] Comment Purpose

**Scope**: Comments in code examples.

**Statement**: Comments MUST explain *why*, not *what*.

**Correct**:
```swift
// Use non-blocking to avoid thread pool exhaustion
let selector = IO.NonBlocking.Selector()
```

**Incorrect**:
```swift
// Create a selector
let selector = IO.NonBlocking.Selector()  // ❌ Describes what, not why
```

**Rationale**: Purpose-driven comments add information the code cannot convey.

**Cross-references**: [DOC-CODE-001], [DOC-CODE-005]

---

### [DOC-CODE-005] Anticipatory Documentation

**Scope**: Code patterns that may surprise future readers.

**Statement**: When code makes a decision that future readers might question, comments MUST anticipate those questions and provide answers. The comment should transform "this looks wrong" into "this is correct for documented reasons."

#### Questions to Anticipate

| Question Type | What to Document |
|---------------|------------------|
| "Can this be done differently?" | Why alternatives don't work |
| "When will this change?" | Migration conditions |
| "Is this a bug or intentional?" | Explicit statement of intent |
| "Why isn't X used here?" | Constraints that prevent X |

**Correct**:
```swift
/// Note: Span<T> is ~Escapable, which requires special handling.
/// For now, we provide conformances only for Escapable collection types.
/// Span-based parsing will be added when lifetime annotations are stable.
associatedtype Input

// This comment answers:
// - "Can Span conform?" → No, here's why
// - "When will this change?" → When lifetime annotations are stable
// - "Is this a bug?" → No, it's a known limitation
```

```swift
/// For bytes parsing, use `Parsing.Bytes.Input` (an escapable cursor type)
/// rather than `Span<UInt8>` directly. Swift 6.2 does not allow `~Escapable`
/// constraints on protocol associated types.
associatedtype Input

// This comment answers:
// - "Why not use Span directly?" → Language limitation
// - "What should I use instead?" → Parsing.Bytes.Input
```

**Incorrect**:
```swift
associatedtype Input  // ❌ No explanation for surprising absence of Span

// Future reader wonders: "Why doesn't Span conform? Is this a bug?"
// Without anticipatory documentation, they waste time investigating
// a question that was already answered when the code was written.
```

#### When to Write Anticipatory Comments

Anticipatory documentation is REQUIRED when:

1. **Language limitations prevent obvious patterns**: Document the limitation and workaround
2. **Design defers to future language evolution**: Specify the trigger for change
3. **Code differs from similar code elsewhere**: Explain why the difference is intentional
4. **A pattern looks wrong but is correct**: Explicitly state it's intentional

#### The Migration Guide Pattern

When constraints are expected to lift, comments become migration guides:

```swift
// Current: Use Parsing.Bytes.Input (escapable wrapper)
// Migration: When Swift supports ~Escapable on associated types,
//            change conformance to accept Span<UInt8> directly
//            and update call sites to use borrowed parsing.
```

**Rationale**: The type system cannot express "Swift 6.2 doesn't support this." Comments can. Well-written anticipatory comments encode design decisions for future readers (including LLMs), reducing the time spent rediscovering answers to questions that were already resolved.

**Cross-references**: [DOC-CODE-004], [DOC-CONTENT-001], [DOC-CONTENT-002], [API-DESIGN-009]

---

## Inline Documentation (DocC)

**Applies to**: All DocC documentation comments.

---

### [DOC-DOCC-001] Public API Documentation

**Scope**: All public APIs.

**Statement**: All public APIs MUST have DocC comments describing:

- Caller-visible behavior
- Executor or threading guarantees
- Cancellation behavior
- Shutdown behavior
- Typed error conditions

These requirements extend <doc:Implementation> (Documentation and Comments section).

**Correct**:
```swift
/// Submits work to the executor pool.
///
/// - Parameter work: The work item to execute.
/// - Returns: The result of the work execution.
/// - Throws: `IO.Lifecycle.Error` if the pool is shutting down or the task is cancelled.
///
/// This method is safe to call from any thread. Work executes on the pool's
/// dedicated threads, not the Swift cooperative thread pool.
public func submit<T>(_ work: @Sendable () throws -> T) async throws(IO.Lifecycle.Error<IO.Error>) -> T
```

**Rationale**: Complete API documentation enables accurate LLM code generation and usage guidance.

**Cross-references**: [API-DOC-001], [DOC-DOCC-002]

---

### [DOC-DOCC-002] Avoiding Redundancy

**Scope**: Trivial API members.

**Statement**: MUST NOT document self-evident code or trivial accessors.

**Incorrect**:
```swift
/// The x coordinate.
var x: Double  // ❌ Documentation adds no information
```

**Rationale**: Redundant documentation creates noise that dilutes meaningful content.

**Cross-references**: [DOC-DOCC-001]

---

## Formatting Rules

**Applies to**: All documentation formatting.

---

### [DOC-FORMAT-001] Section Separators and Headings

**Scope**: Document structure.

**Statement**: Formatting rules:

- Use `---` between major sections
- H1: package name only
- H2/H3 only; deeper nesting discouraged
- Always specify code block language

**Rationale**: Consistent formatting enables predictable LLM document parsing.

**Cross-references**: [DOC-FORMAT-002]

---

### [DOC-FORMAT-002] Table Formatting

**Scope**: All tables.

**Statement**: Tables MUST be column-aligned for readability.

**Correct**:
```markdown
| Column A | Column B      | Column C    |
|----------|---------------|-------------|
| Short    | Longer value  | Description |
```

**Rationale**: Aligned tables are easier for both humans and LLMs to parse accurately.

**Cross-references**: [DOC-FORMAT-001]

---

### [DOC-FORMAT-003] Documentation File Naming

**Scope**: Markdown files in Documentation.docc, Research, Blog, and Implementation directories.

**Statement**: Documentation filenames SHOULD use natural title case with spaces, not kebab-case.

**Correct**:
```text
Five Layer Architecture.md
Memory Ownership.md
Algebraic Effects in Swift.md
Research/Pointer Acquisition Problem.md
```

**Incorrect**:
```text
five-layer-architecture.md      ❌ Kebab-case requires mental parsing
memory-ownership.md             ❌ Less readable in file listings
algebraic-effects-in-swift.md   ❌ Cognitive overhead on every access
```

### Rationale

Documentation exists to be read. A file listing is a table of contents. `Algebraic Effects in Swift.md` tells you what's inside; `algebraic-effects-in-swift.md` requires parsing. The cognitive tax of translating kebab-case to meaning accumulates across every directory listing, every search result, every file picker.

Modern file systems, shells, and tools handle spaces. Quoting paths (`"Research/Algebraic Effects in Swift.md"`) is a minor inconvenience. Tab-completion handles it automatically. Git handles it. The tooling objection is largely historical.

### Exception: Code Directories

**Source code** directories (Sources/, Tests/, Experiments/) use kebab-case per SPM conventions:
- `swift-heap-primitives/` ✓
- `sendable-closure-test/` ✓

This exception exists because SPM and tooling have stronger expectations for code directory naming.

**Cross-references**: [DOC-FORMAT-001], [EXP-002]

---

## Maintenance Obligations

**Applies to**: All documentation maintenance.

---

### [DOC-MAINT-001] Content Currency

**Scope**: All documentation content.

**Statement**: Maintenance obligations:

- Performance numbers MUST be kept current
- Installation snippets MUST match latest release
- All links MUST be valid; prefer relative links

**Rationale**: Stale documentation generates incorrect LLM responses and erodes user trust.

**Cross-references**: [DOC-INSTALL-001], [DOC-BADGE-002]

---

## Explicit Exclusions

**Applies to**: Content decisions.

---

### [DOC-EXCLUDE-001] Prohibited Content

**Scope**: All documentation.

**Statement**: Documentation MUST NOT include:

- Roadmaps or TODOs
- Changelogs (use CHANGELOG.md or GitHub releases)
- Failing CI badges
- Screenshots (unless the package is inherently visual)
- Marketing language without technical substance

**Rationale**: Excluded content either belongs elsewhere or degrades documentation quality.

**Cross-references**: [DOC-SCOPE-001], [DOC-BADGE-002]

---

## Content Quality

**Applies to**: All technical documentation content.

**Does not apply to**: Marketing materials or announcements.

---

### [DOC-CONTENT-001] Learning Path Preservation

**Scope**: Documentation for unfamiliar territory, new features, or complex patterns.

**Statement**: Documentation for unfamiliar territory SHOULD preserve learning paths, not just conclusions. Documentation that anticipates failure modes provides faster onboarding than documentation that presents only the final form.

#### The Principle

A document that says "use pattern X" is less useful than one that explains *why obvious alternatives Y and Z fail*. Developers encountering new features try the obvious patterns first. Documentation that addresses those failures provides faster onboarding.

**Correct**:
```markdown
## Unsafe Expression Marking

### The Parenthesization Pattern

For assignments to unsafe storage, parentheses define the expression boundary:

` ` `swift
unsafe (self.raw = value)  // Entire assignment as one expression
` ` `

### Why Other Patterns Fail

| Failed Pattern | Why It Fails |
|----------------|--------------|
| `self.raw = unsafe value` | Only marks the value, not the destination |
| `unsafe { self.raw = value }` | Block creates closure context; can't assign to `let` |

These patterns fail because Swift's unsafe operates at expression granularity,
not statement or block granularity.
```

**Incorrect**:
```markdown
## Unsafe Expression Marking

Use `unsafe (self.raw = value)` for pointer assignments.

❌ Missing: why the parentheses matter, what alternatives fail, why they fail
```

#### What to Preserve

| Element | Value |
|---------|-------|
| Failed approaches | Prevents rediscovery of dead ends |
| Why failures occur | Builds correct mental model |
| Edge cases | Identifies boundaries of the pattern |
| Compiler messages | Helps recognize similar situations |

#### When to Apply

This principle applies when:
1. Documenting new language features
2. Explaining patterns that contradict intuition
3. Writing guides for migration or remediation
4. Capturing knowledge from exploration sessions

**Rationale**: Most developers don't read documentation until their intuitive approach fails. Documentation that starts with "here's what you probably tried and why it doesn't work" meets developers where they are, not where we wish they started.

**Cross-references**: [DOC-CODE-004], [PATTERN-005b], [PATTERN-030]

---

### [DOC-CONTENT-002] Compromise Documentation Value

**Scope**: Documentation for workarounds and non-ideal solutions.

**Statement**: Documentation of compromises is more valuable than documentation of ideal code. Ideal code documents itself; compromises require explanation to avoid becoming permanent.

#### The Principle

When writing papers or documentation that will outlive the code, explicitly document:
1. Why the workaround exists
2. What the ideal solution would be
3. When the workaround can be removed

```markdown
## Resource Pool Effects

### Current Implementation

Uses `Reference.Box<Resource>` because Swift's associated types
implicitly require `Copyable`. See [PATTERN-033].

### Migration Path

When Swift Evolution accepts "Suppressed Associated Types,"
remove the `Box` wrapper and change `Value = Reference.Box<Resource>`
to `Value = Resource`.
```

Without this documentation, the workaround might be preserved out of caution even when Swift evolves to support the ideal implementation.

**Rationale**: Workarounds documented with migration paths are technical debt with known payoff dates. Workarounds without documentation become permanent.

**Cross-references**: [PATTERN-033], [DOC-CONTENT-001]

---

### [DOC-CONTENT-003] Empirical Verification as Documentation Source

**Scope**: Documentation for unfamiliar compiler features or tools.

**Statement**: When documenting unfamiliar features, intentional compilation failures SHOULD be used as a documentation discovery mechanism. The compiler knows what it needs; documentation may lag.

#### The Methodology

| Phase | Action | Value |
|-------|--------|-------|
| Research | Web search, official docs | General understanding, context |
| Verification | Attempt compilation | Working commands, actual requirements |
| Documentation | Write what worked | Accurate, executable instructions |

#### Example Discovery

```
Research: "Swift Embedded requires -enable-experimental-feature Embedded"

Verification:
$ swiftc -enable-experimental-feature Embedded ...
error: module 'Swift' cannot be imported in embedded Swift mode

Discovery: Release toolchains don't support Embedded; development snapshots required.
```

This requirement was absent from official documentation. The error message was the documentation.

**Rationale**: Thirty minutes of research produces general understanding. Five minutes of compilation produces working commands. Final documentation includes exact commands because they were executed, not because they were found.

> **Full methodology**: See [Experiment](../Experiments/Experiment.md) for complete experiment package creation protocol, including location conventions (`/tmp`), reduction methodology, and result documentation.

**Cross-references**: [ECO-TECH-001], [MEM-SAFE-002], [Experiment](../Experiments/Experiment.md)

---

### [DOC-CONTENT-004] Structured Rule Identifiers

**Scope**: Technical documentation requiring precise cross-referencing.

**Statement**: Technical documentation SHOULD use rule identifiers (`[XXX-YYY-NNN]`) for machine-readable cross-referencing and compliance checking.

#### The Pattern

```markdown
### [EMB-FLAG-002] Whole Module Optimization

**Scope**: Compiler flags for Embedded Swift compilation.

**Statement**: Embedded Swift compilation MUST use `-wmo` (whole module optimization).
```

#### Benefits

| Benefit | Description |
|---------|-------------|
| Precise references | "See [EMB-FLAG-002]" is unambiguous |
| Grep-based compliance | `grep -r "EMB-FLAG"` finds all Embedded requirements |
| LLM retrieval | Identifiers enable exact section extraction |

The pattern mirrors `[API-*]` from API Requirements—same principle, different domain.

**Rationale**: Machine-readable identifiers enable automated compliance checking and precise cross-referencing. Identifiers work for compilation procedures as well as API requirements.

**Cross-references**: [API-NAME-008], [DOC-FORMAT-001]

---

### [DOC-CONTENT-005] Escape Hatch Counter-Marketing

**Scope**: Documentation for unsafe escapes, workarounds, and "sharp edges."

**Statement**: Documentation for escape hatches SHOULD actively discourage use when alternatives exist. Escape hatches require counter-marketing, not selling.

#### The Problem

Escape hatches are easy to oversell. Documentation might claim "principled safety" or "invariants" for types that enforce nothing. Readers might trust that an escape hatch provides protection when it provides only visibility.

#### The Strategy

Repeat limitations explicitly:

```markdown
## Sendability.Unchecked

This type bypasses the compiler's `Sendable` checking.
This wrapper provides **no runtime validation** and **no guarantees**.
It is an auditable assertion site, not a safety mechanism.

**Prefer alternatives when possible**: For domain types you control,
mark the containing type `@unchecked Sendable` directly.
```

#### What Escape Hatches Actually Provide

| Claimed | Actual |
|---------|--------|
| Safety | None—bypasses compiler checking |
| Protection | None—no runtime validation |
| Invariants | None—wraps any value blindly |
| **Auditability** | **Yes**—grep finds every escape site |

The type's value is grep-ability, not safety. Honest documentation admits this.

**Rationale**: Most documentation sells its subject. Escape hatch documentation must do the opposite—discourage use when alternatives exist and honestly state limitations.

**Cross-references**: [DOC-CONTENT-002], [API-NAME-008]

---

## Topics

### Related Documents

- <doc:Implementation>
- <doc:Testing-Requirements>
- <doc:Contributor-Guidelines>

### Process Documents

- <doc:Documentation-Maintenance>