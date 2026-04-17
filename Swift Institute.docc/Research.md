# Research

@Metadata {
    @TitleHeading("Swift Institute")
    @PageImage(purpose: card, source: "card-research", alt: "Research")
}

Design rationale and trade-off analysis — why the ecosystem is shaped the way it is.

## Overview

When a design decision has non-obvious alternatives, the reasoning is recorded as a research document rather than lost in commit history. Each document captures the question, the options considered, the trade-offs evaluated, and the outcome — so future readers can understand not just what was decided, but why.

Research documents are persistent and version-controlled. They are not internal drafts; they are part of the public record.

## Where to browse

Ecosystem-wide research is published in [swift-institute/Research](https://github.com/swift-institute/Research). The repository's [`_index.md`](https://github.com/swift-institute/Research/blob/main/_index.md) lists every document with its topic and status; [`Reflections/`](https://github.com/swift-institute/Research/tree/main/Reflections) holds shorter post-session notes captured at the time of the work.

Per-layer research lives alongside the code it concerns — in the `Research/` directory of each superrepo (primitives, standards, foundations).

## What gets a research document

A research document is created when a design decision cannot be made without systematic analysis of alternatives. If existing conventions clearly answer the question, no research is needed.

| Trigger | Example |
|---------|---------|
| Multiple valid approaches | "Should clock types use phantom tags or distinct structs?" |
| Trade-off between competing concerns | "Granularity vs. compile time in package decomposition" |
| Architecture choice with cross-package implications | "Where does POSIX code live in the platform stack?" |
| Convention that needs explicit rationale | "Why `~Copyable` by default?" |

## Document structure

Each document follows a consistent format:

1. **Context** — what prompted the investigation
2. **Question** — the specific design question
3. **Analysis** — options enumerated, criteria identified, trade-offs compared
4. **Outcome** — the decision (or deferral) with rationale

Documents carry a status:

| Status | Meaning |
|--------|---------|
| IN_PROGRESS | Analysis ongoing |
| DECISION | Complete; decision made and implemented |
| RECOMMENDATION | Complete; not yet implemented |
| DEFERRED | Complete; awaiting future information |
| SUPERSEDED | Replaced by newer research |

## Relationship to other artifacts

Research documents explain *why*. Code explains *what*. Experiments (see <doc:Experiments>) verify *whether*. Blog posts may link to research documents that provide the design rationale behind a technical claim.
