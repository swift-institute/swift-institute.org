# Research

@Metadata {
    @TitleHeading("Swift Institute")
}

Design rationale and trade-off analysis — why the ecosystem is shaped the way it is.

## Overview

Every repository in the ecosystem contains a `Research/` directory at its root. When a design decision has non-obvious alternatives, the reasoning is recorded here rather than lost in commit history. Research documents are Markdown files that capture the question, the options considered, and the outcome — so future readers can understand not just what was decided, but why.

Research documents are persistent and version-controlled. They are not internal drafts; they are part of the public record.

---

## When research is created

A research document is created when a design decision cannot be made without systematic analysis of alternatives. If existing conventions clearly answer the question, no research is needed — the answer is already documented.

| Trigger | Example |
|---------|---------|
| Multiple valid approaches | "Should clock types use phantom tags or distinct structs?" |
| Trade-off between competing concerns | "Granularity vs. compile time in package decomposition" |
| Architecture choice with cross-package implications | "Where does POSIX code live in the platform stack?" |
| Convention that needs explicit rationale | "Why `~Copyable` by default?" |

---

## Structure

Each document follows a consistent format:

1. **Context** — what prompted the investigation
2. **Question** — the specific design question
3. **Analysis** — options enumerated, criteria identified, trade-offs compared
4. **Outcome** — the decision (or deferral) with rationale

Documents carry metadata indicating their status:

| Status | Meaning |
|--------|---------|
| IN_PROGRESS | Analysis ongoing |
| DECISION | Complete; decision made and implemented |
| RECOMMENDATION | Complete; not yet implemented |
| DEFERRED | Complete; awaiting future information |
| SUPERSEDED | Replaced by newer research |

---

## Where research lives

Research documents live at the root of the repository they concern:

| Scope | Location |
|-------|----------|
| Ecosystem-wide | `swift-institute/Research/` |
| Primitives-specific | `swift-primitives/Research/` |
| Standards-specific | `swift-standards/Research/` |
| Foundations-specific | `swift-foundations/Research/` |

Each `Research/` directory has an `_index.md` file listing all documents with their topic and status.

---

## Relationship to other artifacts

Research documents explain *why*. Code explains *what*. Experiments (see <doc:Experiments>) verify *whether*.

Blog posts may link to research documents that provide the design rationale behind a technical claim. The research is the backstory; the blog post is the narrative.
