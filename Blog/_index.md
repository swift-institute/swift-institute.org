# Blog Ideas Index

@Metadata {
    @TitleHeading("Swift Institute")
}

Central backlog of blog post ideas captured from Swift Institute work.

## Overview

**Scope**: This index tracks all blog post ideas from capture through publication.

**Workflow**: See <doc:Blog-Post-Process> for the complete two-phase workflow.

**Adding ideas**: When a trigger event occurs per [BLOG-001], add an entry to "Ready for Drafting" or "Needs More Context" as appropriate.

**Claiming ideas**: Move the entry to "In Progress" and add your name as Writer before beginning a draft.

---

## Ready for Drafting

**Scope**: Ideas with sufficient context for a writer to begin drafting.

**Criteria**: Source artifact exists, category assigned, key points identified.

| ID | Title | Category | Source | Captured | Notes |
|----|-------|----------|--------|----------|-------|
| BLOG-IDEA-001 | The Hidden Deinit Bug in ~Copyable Inline Storage | Technical Deep Dive | [Experiments/_index.md](Experiments/_index.md) | 2026-01-23 | Swift 6.2 bug, workaround documented, affects Deque/Queue/Stack |
| BLOG-IDEA-002 | Module Boundaries and ~Copyable Constraint Poisoning | Lessons Learned | [Experiments/_index.md](Experiments/_index.md) | 2026-01-23 | Module splitting as solution, applied in array-primitives |
| BLOG-IDEA-003 | BitwiseCopyable's Hidden Constraint on Lifetime Inference | Technical Deep Dive | [BitwiseCopyable Analysis.md](/Users/coen/Developer/swift-primitives/Sources/Swift Primitives/Swift Primitives.docc/Reference/BitwiseCopyable Analysis.md) | 2026-01-23 | Category error in compiler, accidental workaround found |
| BLOG-IDEA-004 | Conditional Copyability: Unified Architecture for Containers | Technical Deep Dive | [Stack Research Paper](/Users/coen/Developer/swift-primitives/swift-stack-primitives/Research/Research Paper.md) | 2026-01-23 | ManagedBuffer enables conditional Copyable, full research paper |
| BLOG-IDEA-005 | Why Swift Can't Overload by Ownership Modifiers | Lessons Learned | [SE-Pitch PITCH-0001](SE-Pitches/Draft/PITCH-0001%20Ownership-Based%20Method%20Overloading.md) | 2026-01-23 | Forces consumingForEach naming, SE-Pitch drafted |
| BLOG-IDEA-006 | The `__unchecked` Phantom Parameter Problem | Lessons Learned | [SE-Pitch PITCH-0002](SE-Pitches/Draft/PITCH-0002%20Throws-Based%20Method%20Overloading.md) | 2026-01-23 | Throws overloading gap, SE-Pitch drafted |
| BLOG-IDEA-007 | Consuming Iterators for ~Copyable Collections | Pattern Documentation | [Set Experiments](/Users/coen/Developer/swift-primitives/swift-set-primitives/Experiments/_index.md) | 2026-01-23 | ~Copyable iterators work, tuple limitation workaround |
| BLOG-IDEA-008 | Ownership Overloading REFUTED: Swift 6.2 Limitations | Lessons Learned | [Set Experiments](/Users/coen/Developer/swift-primitives/swift-set-primitives/Experiments/_index.md) | 2026-01-23 | 6 approaches tested, all failed - validates naming convention |
| BLOG-IDEA-009 | Dual-Track API for stdlib Integration | Pattern Documentation | [stdlib-comparison-conformance](Experiments/stdlib-comparison-conformance/) | 2026-01-23 | Parallel hierarchies for ~Copyable + stdlib Comparable |
| BLOG-IDEA-010 | Phantom Types Meet Affine Geometry: Index Type Design | Technical Deep Dive | [Research/index-type-consistency.md](Research/index-type-consistency.md) | 2026-01-23 | Category theory grounding, 100% consistency across 9 packages |
| BLOG-IDEA-011 | State-Tracking Pattern for Consuming Accessors | Pattern Documentation | [Property Experiments](/Users/coen/Developer/swift-primitives/swift-property-primitives/Experiments/_index.md) | 2026-01-23 | .forEach.consuming via reference-type state tracking |
| BLOG-IDEA-012 | Reference Primitives Taxonomy: 23 Ownership Patterns | Pattern Documentation | [Tier 0 Analysis](/Users/coen/Developer/swift-primitives/Sources/Swift Primitives/Swift Primitives.docc/Research/Tier%200%20Comparative%20Analysis.md) | 2026-01-23 | Complete reference type taxonomy, exemplar package |
| BLOG-IDEA-013 | Typed Throws Wrapper Pattern for stdlib Functions | Pattern Documentation | [Tier 0 Analysis](/Users/coen/Developer/swift-primitives/Sources/Swift Primitives/Swift Primitives.docc/Research/Tier%200%20Comparative%20Analysis.md) | 2026-01-23 | 60+ typed throws functions, error preservation pattern |
| BLOG-IDEA-014 | Combining ~Copyable and ~Escapable for Lifetime Safety | Technical Deep Dive | [Tier 0 Analysis](/Users/coen/Developer/swift-primitives/Sources/Swift Primitives/Swift Primitives.docc/Research/Tier%200%20Comparative%20Analysis.md) | 2026-01-23 | String primitives double-safety pattern |
| BLOG-IDEA-015 | Seven Patterns of Best-in-Class Technical Blog Posts | Tutorial | [Research/Best-in-Class Blog Post Pattern.md](Research/Best-in-Class%20Blog%20Post%20Pattern.md) | 2026-01-23 | Evidence-based writing patterns, actionable framework |
| BLOG-IDEA-026 | BorrowingSequence: Span-Based Iteration Without Copies | Pattern Documentation | [borrowing-sequence-pitch](/Users/coen/Developer/swift-primitives/swift-sequence-primitives/Experiments/borrowing-sequence-pitch/) | 2026-01-24 | Implementation of Swift Forums pitch with Nest.Name conventions. Sequence.Borrowing.Protocol, Span.Batch.Iterator patterns. |

---

## Needs More Context

**Scope**: Ideas captured but requiring additional information before drafting.

**Action**: Resolve the blocker, then move to "Ready for Drafting".

| ID | Title | Category | Source | Captured | Blocker |
|----|-------|----------|--------|----------|---------|
| BLOG-IDEA-016 | Storage Variant Patterns: Centralization Limits | Pattern Documentation | [storage-variant-patterns](Experiments/storage-variant-patterns/) | 2026-01-23 | Needs clearer takeaway for external readers |
| BLOG-IDEA-017 | Academic Research Methodology for Infrastructure | Announcement | [Research/academic-research-methodology.md](Research/academic-research-methodology.md) | 2026-01-23 | May be too internal/process-focused |
| BLOG-IDEA-018 | Tier 0 Compliance: 98.4% Across 16 Packages | Announcement | [Tier 0 Analysis](/Users/coen/Developer/swift-primitives/Sources/Swift Primitives/Swift Primitives.docc/Research/Tier%200%20Comparative%20Analysis.md) | 2026-01-23 | Needs external-facing angle |
| BLOG-IDEA-019 | Protocol Extension Pattern for Property.View | Pattern Documentation | [index-totality FINDINGS](/Users/coen/Developer/swift-primitives/swift-index-primitives/Experiments/index-totality/FINDINGS.md) | 2026-01-23 | Needs broader context beyond Index |
| BLOG-IDEA-020 | Heap Ordering Duplication Discovery | Lessons Learned | [collection-ordering-analysis](/Users/coen/Developer/swift-primitives/Sources/Swift%20Primitives/Swift%20Primitives.docc/Experiments/collection-ordering-analysis/ANALYSIS.md) | 2026-01-23 | Internal refactoring story - needs external angle |
| BLOG-IDEA-021 | Conditional Copyable for Array.Bounded | Tutorial | [array conditional-copyable](/Users/coen/Developer/swift-primitives/swift-array-primitives/Experiments/conditional-copyable/) | 2026-01-23 | Overlaps with BLOG-IDEA-004, consider merging |
| BLOG-IDEA-022 | Deeply Nested Namespacing Pattern | Pattern Documentation | [Tier 0 Analysis](/Users/coen/Developer/swift-primitives/Sources/Swift Primitives/Swift Primitives.docc/Research/Tier%200%20Comparative%20Analysis.md) | 2026-01-23 | May be too narrow for standalone post |
| BLOG-IDEA-023 | Platform-Aware API Design for Embedded Swift | Pattern Documentation | [Tier 0 Analysis](/Users/coen/Developer/swift-primitives/Sources/Swift Primitives/Swift Primitives.docc/Research/Tier%200%20Comparative%20Analysis.md) | 2026-01-23 | Needs more examples beyond Codable |

---

## In Progress

**Scope**: Ideas currently being drafted.

**Location**: Drafts are in `Blog/Draft/{slug}.md`.

| ID | Title | Category | Writer | Started | Draft |
|----|-------|----------|--------|---------|-------|
| BLOG-IDEA-024 | The Pointer Acquisition Problem: Why Swift Can't Project Pointers from Borrowed Values | Technical Deep Dive | Swift Institute | 2026-01-23 | [Draft](Draft/pointer-acquisition-problem.md) |
| BLOG-IDEA-025 | Why you can't build a ~Escapable Pointer (and what Builtin.load teaches us) | Technical Deep Dive | Swift Institute | 2026-01-24 | [Review](Review/escapable-pointer-primitives.md) |
| BLOG-IDEA-027 | The Dual Protocol Conformance Trap: Swift.Comparable vs Comparison.Protocol | Technical Deep Dive | Swift Institute | 2026-01-24 | [Draft](Draft/dual-protocol-conformance-trap.md) |

---

## Published

**Scope**: Completed posts (historical record).

**Location**: Published posts are in `Blog/Published/YYYY-MM-DD-{slug}.md`.

| ID | Title | Published | Post |
|----|-------|-----------|------|
| — | — | — | No posts published yet |
