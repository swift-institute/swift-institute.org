---
name: swift-evolution
description: |
  Drafting and submitting Swift Evolution pitches to gather community feedback
  before formal proposal development. Covers the pitch phase of the Swift
  Evolution workflow: triggers, evidence requirements, scope analysis, drafting,
  submission, iteration, and convergence. Later phases (formal proposal, review,
  decision, implementation) will be added as content develops.

layer: process

requires:
  - swift-institute-core

applies_to:
  - swift-evolution
  - swift-primitives
  - swift-standards
  - swift-foundations
  - swift-institute
last_reviewed: 2026-04-14
---

# Swift Evolution

Drafting and submitting Swift Evolution pitches to gather community feedback before formal proposal development.

**Scope**: This skill currently defines the pitch phase of the Swift Evolution workflow — from trigger identification through forum submission and feedback iteration. Subsequent phases (formal proposal, review, decision, implementation) use the official Swift Evolution process without additional institute-level convention.

**Applies to**: Language changes, standard library evolution, compiler behavior modifications identified through package development.

**Does not apply to**: Bug reports, feature requests without implementation evidence, or changes achievable through library code.

**Official resources**:
- [Swift Evolution Process](https://github.com/swiftlang/swift-evolution/blob/main/process.md)
- [Commonly Proposed Changes](https://github.com/swiftlang/swift-evolution/blob/main/commonly_proposed.md)
- [Swift Forums: Evolution > Pitches](https://forums.swift.org/c/evolution/pitches/18)

---

## Quick Reference: Directory Structure

File organization for tracking pitch lifecycle lives in the meta-repository:

```text
swift-institute/Swift Evolution/
├── README.md                # Directory layout and pointers to this skill
├── Drafts/                  # Internal, pre-pitch drafts
│   └── PITCH-XXXX {Title}.md
├── Pitches/                 # Posted to Swift Forums
│   └── PITCH-XXXX {Title}.md
├── Proposals/               # Formal SE-NNNN proposals in review pipeline
├── Accepted/                # Accepted, awaiting or in implementation
├── Implemented/             # Shipped in a Swift release
└── Declined/                # Rejected, withdrawn, or returned-never-resubmitted
```

**Cross-references**: [PITCH-PROC-004], [PITCH-PROC-005]

---

## Quick Reference: Pitch Lifecycle

Status progression from identification to proposal transition:

```text
Candidate identified (implementation work, experiment, package dev)
        │
        ▼
Swift Evolution/Drafts/PITCH-XXXX        ─┐
        │                                 │  Phase 1: Pitch
        ▼ (post to Swift Forums)          │
Swift Evolution/Pitches/PITCH-XXXX        ─┘
        │
        ▼ (pitch converges)
Swift Evolution/Proposals/                ─── Phase 2: Proposal
```

| Status | Location | Meaning |
|--------|----------|---------|
| `PITCH-DRAFT` | `Swift Evolution/Drafts/` | Internal pitch draft |
| `PITCH-SUBMITTED` | `Swift Evolution/Pitches/` | Posted to forums, gathering feedback |
| `CONVERGED` | `Swift Evolution/Pitches/` | Ready for proposal development |

**Cross-references**: [PITCH-PROC-001], [PITCH-PROC-005]

---

## [PITCH-PROC-001] Pitch Triggers

**Scope**: Conditions that warrant drafting a pitch.

**Statement**: A pitch SHOULD be drafted when a language or standard library limitation is identified through concrete implementation work, and the limitation cannot be reasonably addressed through library-level workarounds.

### Trigger categories

| Category | Description | Priority |
|----------|-------------|----------|
| Blocking limitation | Cannot implement desired API at all | High |
| Ecosystem fragmentation | Workaround creates incompatible parallel hierarchies | High |
| Source compatibility cliff | Evolutionary improvement would break existing code | Medium |
| Ergonomic degradation | Workaround significantly worse than potential fix | Medium |
| Performance limitation | Language prevents optimal implementation | Medium |
| Consistency gap | Related features behave differently without justification | Low |

### When NOT to pitch

Before drafting, verify the idea is NOT in the [Commonly Proposed Changes](https://github.com/swiftlang/swift-evolution/blob/main/commonly_proposed.md) list. These have been extensively debated and revisiting them requires substantial new evidence.

**Rationale**: Commonly proposed changes have been extensively debated. Pitches revisiting them require substantial new evidence.

**Cross-references**: [PITCH-PROC-002], [PITCH-PROC-003]

---

## [PITCH-PROC-002] Evidence Requirements

**Scope**: Required evidence to support pitch motivation.

**Statement**: Pitches MUST include concrete evidence from implementation work, experiments, or production usage demonstrating the limitation.

### Evidence categories

| Category | Description |
|----------|-------------|
| Experiment results | Verified behavior through isolated tests |
| Implementation attempts | Code that would work with proposed change |
| Workaround analysis | Documented alternatives and their costs |
| Ecosystem impact | Other packages/users affected |

### Evidence quality criteria

| Criterion | Required | Description |
|-----------|----------|-------------|
| Reproducible | MUST | Others can verify findings |
| Minimal | MUST | Focused on specific limitation |
| Referenced | MUST | Links to experiment packages or implementations |
| Cross-version | SHOULD | Tested on multiple Swift versions |

**Rationale**: Swift Evolution requires concrete motivation. Implementation experience provides compelling evidence that theoretical arguments cannot.

**Cross-references**: [PITCH-PROC-001]

---

## [PITCH-PROC-003] Scope Analysis

**Scope**: Determining whether one or multiple pitches are needed.

**Statement**: Before drafting, the scope MUST be analyzed to determine if the solution requires one pitch or a sequence of dependent pitches.

### Dependency analysis process

1. **List all changes** needed for the complete solution
2. **Identify dependencies** between changes
3. **Determine minimal independent units** that provide value alone
4. **Order by dependency** — foundational changes first

### Dependency tracking

When pitches have dependencies, document them in metadata:

```yaml
depends_on: PITCH-XXXX
```

**Rationale**: Smaller focused pitches are easier for the community to evaluate. Dependency chains allow incremental progress.

**Cross-references**: [PITCH-PROC-004]

---

## [PITCH-PROC-004] Pitch Drafting

**Scope**: Creating internal pitch drafts before forum submission.

**Statement**: Pitches MUST be drafted in `Swift Evolution/Drafts/` before posting to Swift Forums.

### Pitch file location

```text
Swift Evolution/Drafts/PITCH-XXXX {Title}.md
```

### Pitch naming convention

| Placeholder | Meaning |
|-------------|---------|
| PITCH-XXXX | First pitch in a sequence |
| PITCH-YYYY | Dependent on PITCH-XXXX |
| PITCH-AAAA | Independent pitch |

### Pitch content structure

A pitch draft MUST include:

```markdown
# Pitch: {Title}

<!--
---
pitch_id: PITCH-XXXX
date: YYYY-MM-DD
status: DRAFT
depends_on: PITCH-XXXX (if applicable)
related_experiments:
  - path/to/experiment
---
-->

## Problem
{Concrete problem with code examples}

## Proposed Direction
{General approach, not full specification}

## Evidence
{Links to experiments or implementations}

## Open Questions
{What needs community input}

## Impact
{What this enables}

## Related Work
{Relevant SE proposals}
```

### Pitch vs proposal content

| Aspect | Pitch | Proposal |
|--------|-------|----------|
| Problem statement | Required | Required |
| Solution direction | General | Complete specification |
| Detailed design | Not needed | Required |
| Compatibility analysis | Brief mention | Full analysis |
| Implementation | Not required | Required for language changes |
| Length | ~500-1000 words | ~2000-5000 words |

### Quality checklist

Before proceeding to submission:

- [ ] Problem is clearly stated with code examples
- [ ] Proposed direction is understandable
- [ ] Evidence is linked and reproducible
- [ ] Open questions are genuine (not rhetorical)
- [ ] Impact section explains why this matters
- [ ] Related SE proposals are cited

**Rationale**: Pitches are lighter-weight documents for gathering community feedback before investing in full proposal development.

**Cross-references**: [PITCH-PROC-005], [PITCH-PROC-002]

---

## [PITCH-PROC-005] Pitch Submission

**Scope**: Posting pitches to Swift Forums and tracking discussion.

**Statement**: When a pitch draft is ready for community feedback, it MUST be posted to Swift Forums and moved to `Swift Evolution/Pitches/`.

### Submission process

1. **Post to Forums**: Create thread in Evolution > Pitches
2. **Update file**: Add forum link to metadata
3. **Move file**: `Swift Evolution/Drafts/` → `Swift Evolution/Pitches/`
4. **Engage**: Respond to feedback, iterate on pitch

### Forum post format

**Title**: `[Pitch] {Pitch Title}`

**Body**: Copy the pitch content, formatted for forum markdown.

**Tags**: Add relevant tags (e.g., `concurrency`, `ownership`, `generics`)

### Updated metadata after submission

```yaml
<!--
---
pitch_id: PITCH-XXXX
date: 2026-01-22
status: SUBMITTED
forum_link: https://forums.swift.org/t/pitch-xxxx/12345
submitted_date: 2026-01-25
---
-->
```

### Tracking pitch progress

| Signal | Meaning | Action |
|--------|---------|--------|
| Positive reception | Community sees value | Proceed to proposal |
| Design questions | Clarification needed | Update pitch, respond |
| Alternative suggestions | Different approach proposed | Evaluate, possibly revise |
| Negative reception | Fundamental concerns | Address or reconsider |
| Core team feedback | Official guidance | Incorporate direction |

### Convergence criteria

A pitch has converged when:

- [ ] Core problem is acknowledged by community
- [ ] General direction has support (not necessarily unanimous)
- [ ] Major design questions are resolved
- [ ] No unaddressed fundamental objections
- [ ] Core team has not raised blocking concerns

When these criteria are met, update metadata:

```yaml
status: CONVERGED
converged_date: 2026-02-01
```

**Rationale**: The pitch phase surfaces design issues early and builds community support before formal proposal development.

**Cross-references**: [PITCH-PROC-004]

---

## [PITCH-PROC-006] Linking Evidence Bidirectionally

**Scope**: Maintaining connections between pitches and evidence.

**Statement**: Pitches MUST maintain bidirectional links to experiments and implementations.

### In pitch

```markdown
**Related experiments**:
- [comparable-shadowing-test](link) — Demonstrates limitation
- [noncopyable-accessor-pattern](link) — Shows workaround costs
```

### In experiment

```markdown
## Related Pitches

This experiment motivated:
- [PITCH-XXXX Borrowing Witness Relaxation](link)
```

**Rationale**: Bidirectional links enable traceability from pitches to evidence.

**Cross-references**: [PITCH-PROC-002]

---

## [PITCH-PROC-007] Pitch Iteration

**Scope**: Updating pitches based on forum feedback.

**Statement**: Pitches SHOULD be iterated based on community feedback. Significant changes MUST be documented in the pitch file.

### Iteration process

1. **Receive feedback** on forums
2. **Evaluate** the feedback objectively
3. **Update pitch** in `Swift Evolution/Pitches/`
4. **Post update** to forum thread
5. **Record revision** in metadata

### Revision tracking

```yaml
<!--
---
pitch_id: PITCH-XXXX
status: SUBMITTED
revisions:
  - date: 2026-01-28
    summary: Clarified scope to exclude consuming parameters
  - date: 2026-02-02
    summary: Added alternative approach section based on feedback
---
-->
```

### When to withdraw

A pitch SHOULD be withdrawn if:

- Fundamental objections cannot be addressed
- Core team indicates the direction is unacceptable
- A better alternative emerges during discussion
- The underlying limitation is resolved by another means

**Withdrawal metadata**:

```yaml
status: WITHDRAWN
withdrawn_date: 2026-02-05
withdrawal_reason: |
  Core team indicated this conflicts with future direction X.
  Will revisit when X is resolved.
```

**Rationale**: Iteration improves pitches. Knowing when to withdraw saves everyone's time.

**Cross-references**: [PITCH-PROC-005]

---

## Cross-References

See also:
- **experiment-process** skill for the experiment packages that generate pitch evidence
- **research-process** skill for the research documents that frame design questions
- **blog-process** skill for communicating pitch outcomes externally
- **issue-investigation** skill for compiler-bug pitches
- [Swift Evolution Process](https://github.com/swiftlang/swift-evolution/blob/main/process.md) — canonical workflow

## Cross-reference index

| ID | Title | Focus |
|----|-------|-------|
| [PITCH-PROC-001] | Pitch Triggers | When to draft pitches |
| [PITCH-PROC-002] | Evidence Requirements | Supporting documentation |
| [PITCH-PROC-003] | Scope Analysis | One vs. multiple pitches |
| [PITCH-PROC-004] | Pitch Drafting | Creating internal drafts |
| [PITCH-PROC-005] | Pitch Submission | Forum posting and tracking |
| [PITCH-PROC-006] | Linking Evidence | Bidirectional traceability |
| [PITCH-PROC-007] | Pitch Iteration | Updating based on feedback |
