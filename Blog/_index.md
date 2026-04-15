# Blog Ideas Index

@Metadata {
    @TitleHeading("Swift Institute")
}

Central backlog of blog post ideas captured from Swift Institute work.

## Overview

**Scope**: This index tracks all blog post ideas from capture through publication.

**Workflow**: See the [blog-process skill](../Skills/blog-process/SKILL.md) for the complete two-phase workflow.

**Adding ideas**: When a trigger event occurs per [BLOG-001], add an entry to "Ready for Drafting" or "Needs More Context" as appropriate.

**Claiming ideas**: Move the entry to "In Progress" and add your name as Writer before beginning a draft.

---

## Prioritized

**Scope**: Top-priority ideas to draft next. Triaged 2026-03-15 from stalled backlog.

**Criteria**: Strong experiment/research backing, broad external audience appeal.

| ID | Title | Category | Source | Captured | Notes |
|----|-------|----------|--------|----------|-------|
| BLOG-IDEA-028 | What Swift 6.2.4 fixed (and didn't fix) for ~Copyable | Lessons Learned | [Experiments/_index.md](../Experiments/_index.md) | 2026-03-10 | 4 bugs fixed, 9 limitations remain. Revalidation of 13 experiments. Strong angle for external readers. |
| BLOG-IDEA-029 | The Sequence Copyable wall: why ~Copyable containers can't conform to Sequence | Technical Deep Dive | [Experiments/_index.md](../Experiments/_index.md) | 2026-03-10 | 6 experiments all hit the same wall — Sequence inherits Copyable. Implications for library design. |
| BLOG-IDEA-001 | The Hidden Deinit Bug in ~Copyable Inline Storage (and how Swift 6.2.4 fixed it) | Technical Deep Dive | [Research/noncopyable-value-generic-deinit-bug.md](../Research/noncopyable-value-generic-deinit-bug.md) | 2026-01-23 | Full research doc + experiment. Bug journey story angle. |
| BLOG-IDEA-002 | Module Boundaries and ~Copyable Constraint Poisoning | Lessons Learned | [Experiments/_index.md](../Experiments/_index.md) | 2026-01-23 | Module splitting as solution, applied in array-primitives |
| BLOG-IDEA-004 | Conditional Copyability: Unified Architecture for Containers | Technical Deep Dive | [Stack Research Paper](https://github.com/swift-primitives/swift-stack-primitives/blob/main/Research/Research Paper.md) | 2026-01-23 | ManagedBuffer enables conditional Copyable, full research paper |

---

## Ready for Drafting

**Scope**: Ideas with sufficient context for a writer to begin drafting.

**Criteria**: Source artifact exists, category assigned, key points identified.

| ID | Title | Category | Source | Captured | Notes |
|----|-------|----------|--------|----------|-------|
| BLOG-IDEA-007 | Consuming Iterators for ~Copyable Collections | Pattern Documentation | [Set Experiments](https://github.com/swift-primitives/swift-set-primitives/blob/main/Experiments/_index.md) | 2026-01-23 | ~Copyable iterators work, tuple limitation workaround. **Stalled 80 days — needs writer assignment.** |
| BLOG-IDEA-010 | Phantom Types Meet Affine Geometry: Index Type Design | Technical Deep Dive | Internal — supporting research TBD | 2026-01-23 | Category theory grounding, 100% consistency across 9 packages. **Stalled 80 days — needs writer assignment.** |
| ~~BLOG-IDEA-013~~ | ~~Typed Throws Wrapper Pattern for stdlib Functions~~ | — | — | 2026-01-23 | Moved to In Progress — part of [typed-throws series](Series/typed-throws.md) |
| BLOG-IDEA-014 | Combining ~Copyable and ~Escapable for Lifetime Safety | Technical Deep Dive | [Tier 0 Analysis](https://github.com/swift-primitives/Sources/blob/main/Swift Primitives/Swift Primitives.docc/Research/Tier%200%20Comparative%20Analysis.md) | 2026-01-23 | String primitives double-safety pattern. **Stalled 80 days — needs writer assignment.** |
| BLOG-IDEA-024 | The Pointer Acquisition Problem: Why Swift Can't Project Pointers from Borrowed Values | Technical Deep Dive | [Experiments/_index.md](../Experiments/_index.md) | 2026-01-23 | Was "In Progress" — no draft exists. Reset to Ready. **Stalled 80 days — needs writer assignment.** |
| BLOG-IDEA-025 | Why you can't build a ~Escapable Pointer (and what Builtin.load teaches us) | Technical Deep Dive | [Experiments/_index.md](../Experiments/_index.md) | 2026-01-24 | Was "In Progress" — no draft exists. Reset to Ready. **Stalled 80 days — needs writer assignment.** |
| BLOG-IDEA-026 | BorrowingSequence: Span-Based Iteration Without Copies | Pattern Documentation | [borrowing-sequence-pitch](https://github.com/swift-primitives/swift-sequence-primitives/tree/main/Experiments/borrowing-sequence-pitch/) | 2026-01-24 | Implementation of Swift Forums pitch with Nest.Name conventions. **Stalled 80 days — needs writer assignment.** |
| BLOG-IDEA-032 | Why We Don't Have io.Reader | Technical Deep Dive | [Research/io-prior-art-and-swift-io-design-audit.md](../Research/io-prior-art-and-swift-io-design-audit.md) | 2026-03-26 | Progression from "every IO system has a Reader/Writer trait" to "it would violate typed throws" to "the layered concrete approach is correct." Principled API design vs. cargo-culting prior art. |
| ~~BLOG-IDEA-030~~ | ~~Typed throws in practice: the stdlib compatibility matrix you need~~ | — | — | 2026-03-10 | Moved to In Progress — part of [typed-throws series](Series/typed-throws.md) |
| ~~BLOG-IDEA-031~~ | ~~The associated type trap: when your protocol's Body meets SwiftUI's Body~~ | — | — | 2026-03-13 | Moved to In Progress |
| BLOG-IDEA-033 | From "Provably Impossible" to Compiler Fix: The @_rawLayout Deinit Saga | Lessons Learned | [Reflections/2026-03-22-rawlayout-deinit-compiler-fix.md](../Research/Reflections/2026-03-22-rawlayout-deinit-compiler-fix.md) | 2026-04-14 | Starting from "this can't be fixed" to landing an upstream compiler patch eliminating 22 workaround sites. Step-by-step compiler investigation narrative — how to go from accepting workarounds to submitting fixes. |
| BLOG-IDEA-034 | Ownership Subsumes Synchronization: Removing Actors from ~Copyable Channels | Architecture Deep Dive | [Reflections/2026-03-26-channel-lifecycle-actor-removal-ownership-as-synchronization.md](../Research/Reflections/2026-03-26-channel-lifecycle-actor-removal-ownership-as-synchronization.md) | 2026-04-14 | Removing `actor Lifecycle` from IO.Event.Channel replaced actor-hops with direct stored state — 3x throughput improvement (4.06ms → 1.36ms). Unique ownership IS synchronization. |
| BLOG-IDEA-035 | The Isolation Hierarchy: Ranking Swift Concurrency Primitives by Safety | Technical Deep Dive | [Research/modern-concurrency-conventions.md](../Research/modern-concurrency-conventions.md) | 2026-04-14 | Actors > ~Copyable > sending > Mutex > @unchecked Sendable. 5-tier ranking turns concurrency choices from intuition to principle. Case study: 29 @unchecked Sendable audited in swift-io. |
| BLOG-IDEA-036 | When a Subsystem Has the Wrong Category: The IO.Blocking Redesign | Architecture Deep Dive | [Reflections/2026-04-08-io-blocking-domain-model-redesign.md](../Research/Reflections/2026-04-08-io-blocking-domain-model-redesign.md) | 2026-04-14 | Started as "simplify bloat," pivoted to discovering a category error: blocking I/O wasn't a standalone subsystem. 50 public types → 3. Recognizing when a major subsystem has the wrong architectural category. |
| BLOG-IDEA-037 | Three Mechanisms for Actor Transactional Access: When Each Applies | Pattern Documentation | Internal memory: `actor-isolation-three-mechanisms` | 2026-04-14 | Actor.run vs assumeIsolated vs isolated-parameter: distinct trade-off zones, proven empirically across 5+ experiments. Most developers default to one and miss optimization opportunities. |
| BLOG-IDEA-038 | Inout Sending: The Hidden Mechanism Behind Mutex.withLock Region Transfer | Technical Deep Dive | Internal memory: `inout-sending-mechanism` | 2026-04-14 | Why `(inout sending Value)` on withLock suppresses "returning task-isolated value" diagnostics. Compiler has undocumented special knowledge of the pattern in `diagnoseNonSendableTypesWithSendingCheck()`. Most wrapper methods get this wrong. |
| BLOG-IDEA-039 | Ecosystem-Wide Audit as a Skill: The Generalized /audit Pattern | Process Documentation | [Research/generalized-audit-skill-design.md](../Research/generalized-audit-skill-design.md) | 2026-04-14 | Single audit.md per scope, 10 requirement IDs [AUDIT-001–010], update-in-place. Solves orphan files, version proliferation, naming chaos. Pattern applies to any large codebase or monorepo. |
| BLOG-IDEA-040 | Cross-Package Integration Without Repo Proliferation: SE-0450 Trait-Gated Targets | Pattern Documentation | [Research/cross-package-integration-strategies.md](../Research/cross-package-integration-strategies.md) | 2026-04-14 | 5 strategies evaluated; SE-0450 trait gates dependency resolution at package boundary. Rust cargo-features pattern, now in Swift. Scales horizontal integration across 300+ repos without monorepo. |
| BLOG-IDEA-041 | WMO + CopyToBorrow: When Release Mode Corrupts Actor Enum State | Technical Deep Dive | Internal memory: `copytoborrow-actor-state-barrier` | 2026-04-14 | An innocuous `enum State` on an actor triggers LLVM misoptimization in release — the guard becomes permanently true after shutdown. How cross-module optimization can silently corrupt actor state. |
| BLOG-IDEA-042 | Transformation Domains as Namespaces: Parser, Serializer, Coder, Printer | Design Pattern | [Research/transformation-domain-architecture.md](../Research/transformation-domain-architecture.md) | 2026-04-14 | Why Parser, Serializer, Coder, and Formatter should be separate top-level domains, not nested. Formal semantics of parsing vs serialization vs coding. First-principles domain decomposition. |
| BLOG-IDEA-051 | Upgrading 1,390 Swift Packages to 6.3: What Broke, What Fixed Itself | Lessons Learned | [Research/swift-6.3-revalidation-status.md](../Research/swift-6.3-revalidation-status.md) + [Research/swift-6.3-ecosystem-opportunities.md](../Research/swift-6.3-ecosystem-opportunities.md) | 2026-04-14 | Ecosystem-scale migration report. 149 @_optimize(none) sites removed (#88022 fixed). 36 _deinitWorkaround sites remain (#86652 unfixed). 5 6.4-dev regressions catalogued. Time-sensitive news hook. |
| BLOG-IDEA-052 | Three Compiler Bugs We Filed, Three Fixes in Swift 6.3 | Lessons Learned | Reflections: rawlayout-deinit-compiler-fix, copypropagation-nonescapable-root-cause, copypropagation-noncopyable-enum-already-fixed | 2026-04-14 | Victory lap covering #88022 (CopyPropagation ~Escapable), #85743 (switch consume), and rawlayout compiler fix. Structured around reporting→reproducing→fixing upstream. |

---

## Needs More Context

**Scope**: Ideas captured but requiring additional information before drafting.

**Action**: Resolve the blocker, then move to "Ready for Drafting".

| ID | Title | Category | Source | Captured | Blocker |
|----|-------|----------|--------|----------|---------|
| BLOG-IDEA-003 | BitwiseCopyable's Hidden Constraint on Lifetime Inference | Technical Deep Dive | [BitwiseCopyable Analysis.md](https://github.com/swift-primitives/Sources/blob/main/Swift Primitives/Swift Primitives.docc/Reference/BitwiseCopyable Analysis.md) | 2026-01-23 | Niche compiler internals — needs external angle |
| BLOG-IDEA-005+008 | Ownership Overloading: Why Swift Can't and What We Learned | Lessons Learned | SE-Pitch (retired) — Ownership-Based Method Overloading | 2026-01-23 | Merged: 005 (why it fails) + 008 (6 approaches REFUTED). Needs single narrative. |
| BLOG-IDEA-006 | The `__unchecked` Phantom Parameter Problem | Lessons Learned | SE-Pitch (retired) — Throws-Based Method Overloading | 2026-01-23 | Very internal — needs external angle |
| BLOG-IDEA-009 | Dual-Track API for stdlib Integration | Pattern Documentation | [stdlib-comparison-conformance](../Experiments/stdlib-comparison-conformance/) | 2026-01-23 | Niche pattern — needs broader context |
| BLOG-IDEA-011 | State-Tracking Pattern for Consuming Accessors | Pattern Documentation | [Property Experiments](https://github.com/swift-primitives/swift-property-primitives/blob/main/Experiments/_index.md) | 2026-01-23 | Niche — needs broader applicability angle |
| BLOG-IDEA-012 | Reference Primitives Taxonomy: 23 Ownership Patterns | Pattern Documentation | [Tier 0 Analysis](https://github.com/swift-primitives/Sources/blob/main/Swift Primitives/Swift Primitives.docc/Research/Tier%200%20Comparative%20Analysis.md) | 2026-01-23 | Niche taxonomy — needs "why should I care" angle |
| BLOG-IDEA-015 | Seven Patterns of Best-in-Class Technical Blog Posts | Tutorial | Internal — supporting research TBD | 2026-01-23 | Meta content — deprioritized |
| BLOG-IDEA-016 | Storage Variant Patterns: Centralization Limits | Pattern Documentation | [storage-variant-patterns](../Experiments/storage-variant-patterns/) | 2026-01-23 | Needs clearer takeaway for external readers |
| BLOG-IDEA-017 | Academic Research Methodology for Infrastructure | Announcement | [Research/academic-research-methodology.md](../Research/academic-research-methodology.md) | 2026-01-23 | May be too internal/process-focused |
| BLOG-IDEA-018 | Tier 0 Compliance: 98.4% Across 16 Packages | Announcement | [Tier 0 Analysis](https://github.com/swift-primitives/Sources/blob/main/Swift Primitives/Swift Primitives.docc/Research/Tier%200%20Comparative%20Analysis.md) | 2026-01-23 | Needs external-facing angle |
| BLOG-IDEA-019 | Protocol Extension Pattern for Property.View | Pattern Documentation | [index-totality FINDINGS](https://github.com/swift-primitives/swift-index-primitives/blob/main/Experiments/index-totality/FINDINGS.md) | 2026-01-23 | Needs broader context beyond Index |
| BLOG-IDEA-020 | Heap Ordering Duplication Discovery | Lessons Learned | [collection-ordering-analysis](https://github.com/swift-primitives/Sources/blob/main/Swift%20Primitives/Swift%20Primitives.docc/Experiments/collection-ordering-analysis/ANALYSIS.md) | 2026-01-23 | Internal refactoring story — needs external angle |
| BLOG-IDEA-021 | Conditional Copyable for Array.Bounded | Tutorial | [array conditional-copyable](https://github.com/swift-primitives/swift-array-primitives/tree/main/Experiments/conditional-copyable/) | 2026-01-23 | Overlaps with BLOG-IDEA-004, consider merging |
| BLOG-IDEA-022 | Deeply Nested Namespacing Pattern | Pattern Documentation | [Tier 0 Analysis](https://github.com/swift-primitives/Sources/blob/main/Swift Primitives/Swift Primitives.docc/Research/Tier%200%20Comparative%20Analysis.md) | 2026-01-23 | May be too narrow for standalone post |
| BLOG-IDEA-023 | Platform-Aware API Design for Embedded Swift | Pattern Documentation | [Tier 0 Analysis](https://github.com/swift-primitives/Sources/blob/main/Swift Primitives/Swift Primitives.docc/Research/Tier%200%20Comparative%20Analysis.md) | 2026-01-23 | Needs more examples beyond Codable |
| BLOG-IDEA-027 | The Dual Protocol Conformance Trap: Swift.Comparable vs Comparison.Protocol | Technical Deep Dive | [Experiments/_index.md](../Experiments/_index.md) | 2026-01-24 | Niche — needs broader applicability angle |
| BLOG-IDEA-043 | Channel.split(): A Full-Duplex I/O Pattern for Affine Types | Pattern Documentation | [Reflections/2026-03-29-channel-split-full-duplex-io.md](../Research/Reflections/2026-03-29-channel-split-full-duplex-io.md) | 2026-04-14 | `consuming func split() -> Split` enables independent concurrent read/write halves with ARC-lifetime semantics on ~Copyable types. Needs tutorial framing for external audience. |
| BLOG-IDEA-044 | The @unsafe Compendium: A SE-0458 Memory Safety Model Reference | Tutorial | [Research/swift-safety-model-reference.md](../Research/swift-safety-model-reference.md) | 2026-04-14 | 14 unsafe use kinds, expression placement rules, audit checklists, anti-patterns. Compiler-source-derived. Needs external framing beyond reference doc. |
| BLOG-IDEA-045 | Why Your Swift Benchmark Framework Can't Guarantee Determinism | Lessons Learned | [Research/benchmark-serial-execution.md](../Research/benchmark-serial-execution.md) | 2026-04-14 | Root cause: structural nil nodes dispatch all suites with `.automatic`. One `@Suite(.serialized)` convention fixes it across 8 targets. Narrow but practically valuable. |
| BLOG-IDEA-046 | Canonical Witnesses vs Witness Properties: Multi-Implementation Without Ambiguity | Design Pattern | [Research/canonical-witness-capability-attachment.md](../Research/canonical-witness-capability-attachment.md) | 2026-04-14 | One canonical protocol (Codable, Parseable) + witness properties for alternatives. Option C, 10/10 CONFIRMED empirically. Needs external hook beyond DI framing. |
| BLOG-IDEA-047 | Parser, Decoder, Deserializer: Three Different Problems Sharing a Name | Lessons Learned | [Research/transformation-domain-architecture.md](../Research/transformation-domain-architecture.md) | 2026-04-14 | Parser owns format logic. Decoder shares format/value. Deserializer reverses control. Clear interface + ownership diagram for each. Risk of overlap with transformation-domains post. |
| BLOG-IDEA-048 | Storage.Inline Bottom-Up Deinit: RAII for ~Copyable Inline Containers | Technical Deep Dive | Internal memory: `noncopyable-deinit-workaround` | 2026-04-14 | `_deinitWorkaround: AnyObject?` forces compiler deinit dispatch for inline ~Copyable containers. Cross-module element cleanup was broken until this pattern. Niche — needs external hook. |
| BLOG-IDEA-049 | Parameter Pack Concrete Extensions: A Swift 6.2.4 Language Limitation | Lessons Learned | Internal memory: `pack-concrete-same-type` | 2026-04-14 | `extension Product<Int, String, Double>` does NOT unwrap pack — static type ≠ runtime type. Dynamic member lookup as escape hatch. Very niche — needs broader pack-programming angle. |
| BLOG-IDEA-050 | From `catch let as E` to `do throws(E)`: A Typed-Catch Migration Guide | Tutorial | [Reflections/2026-03-30-io-lane-boundary-completion-typed-throws.md](../Research/Reflections/2026-03-30-io-lane-boundary-completion-typed-throws.md) | 2026-04-14 | Replaced 18 instances of `catch let e as E` + `fatalError()` with `do throws(E)`, eliminating runtime traps. May overlap with typed-throws series — needs distinct angle. |

---

## In Progress

**Scope**: Ideas currently being drafted.

**Location**: Drafts are in `Blog/Draft/{slug}.md`.

| ID | Title | Category | Writer | Started | Draft |
|----|-------|----------|--------|---------|-------|
| BLOG-IDEA-INTRO | Restarting the blog: layered Swift, receipts, and what's next | Announcement | Coen ten Thije Boonkkamp | 2026-04-14 | [Draft](Draft/restarting-the-blog-final.md) |
| BLOG-IDEA-013 | Typed throws in Swift, part 1: error handling from first principles | Technical Deep Dive | — | 2026-03-11 | [Draft](Draft/typed-throws-part-1.md) |
| BLOG-IDEA-013 | Typed throws in Swift, part 2: the throwing spectrum | Technical Deep Dive | — | 2026-03-11 | [Draft](Draft/typed-throws-part-2.md) |
| BLOG-IDEA-030 | Typed throws in Swift, part 3: typed throws in practice | Technical Deep Dive | — | 2026-03-11 | [Draft](Draft/typed-throws-part-3.md) |
| BLOG-IDEA-031 | The associated type trap: when your protocol's Body meets SwiftUI's Body | Technical Deep Dive | — | 2026-03-13 | [Draft](Draft/associated-type-trap-final.md) |

> **Note**: BLOG-IDEA-024, 025, 027 were previously listed as "In Progress" but no draft files exist. Moved back to Ready for Drafting.
>
> **Series**: BLOG-IDEA-013 and BLOG-IDEA-030 combined into the [typed-throws series](Series/typed-throws.md) (3 parts).
>
> **Publication gate — typed-throws series**: Drafts reference `swift-standards/Experiments/typed-throws-protocol-conformance/` as a receipt artifact. Publication is gated on `swift-standards` being world-readable so the receipt link resolves.

---

## Published

**Scope**: Completed posts (historical record).

**Location**: Published posts are in `Blog/Published/YYYY-MM-DD-{slug}.md`.

| ID | Title | Published | Post |
|----|-------|-----------|------|
| — | — | — | No posts published yet |
