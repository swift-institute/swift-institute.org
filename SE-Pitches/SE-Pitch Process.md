# SE-Pitch Process

<!--
---
title: SE-Pitch Process
version: 1.0.0
last_updated: 2026-01-22
applies_to: [swift-institute, swift-primitives, swift-standards, swift-foundations]
normative: true
llm_optimized: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Workflow for drafting and submitting Swift Evolution pitches to gather community feedback before formal proposal development.

## Overview

**Scope**: This document defines the pitch phase (Phase 1) of the Swift Evolution workflow—from trigger identification through forum submission and feedback iteration.

**Prerequisite**: For systematic discovery of pitch candidates, see <doc:SE-Pitch-Identification-Process>.

**Next step**: After pitch converges with positive reception, proceed to <doc:SE-Proposal-Process> for formal proposal drafting.

**Applies to**: Language changes, standard library evolution, compiler behavior modifications identified through package development.

**Does not apply to**: Bug reports (use <doc:Issue-Submission>), feature requests without implementation evidence, or changes achievable through library code.

**Official resources**:
- [Swift Evolution Process](https://github.com/swiftlang/swift-evolution/blob/main/process.md)
- [Commonly Proposed Changes](https://github.com/swiftlang/swift-evolution/blob/main/commonly_proposed.md)
- [Swift Forums: Evolution > Pitches](https://forums.swift.org/c/evolution/pitches/18)

**Normative language**: This document uses RFC 2119 conventions (MUST, SHOULD, MAY).

---

## Quick Reference: Directory Structure

**Scope**: File organization for tracking pitch lifecycle.

```text
swift-institute/Sources/Swift Institute/Swift Institute.docc/
└── SE-Pitches/
    ├── Draft/                    # Internal pitch drafts
    │   └── PITCH-XXXX {Title}.md
    └── Submitted/                # Posted to Swift Forums
        └── PITCH-XXXX {Title}.md # Contains forum link
```

**Cross-references**: [PITCH-PROC-004], [PITCH-PROC-005]

---

## Quick Reference: Pitch Lifecycle

**Scope**: Status progression from identification to proposal transition.

```text
<doc:SE-Pitch-Identification-Process>
        │ (candidate identified)
        ▼
SE-Pitches/Draft/PITCH-XXXX       ─┐
        │                          │  Phase 1: Pitch
        ▼ (post to Swift Forums)   │
SE-Pitches/Submitted/PITCH-XXXX   ─┘
        │
        ▼ (pitch converges)
<doc:SE-Proposal-Process>         ─── Phase 2: Proposal
```

| Status | Location | Meaning |
|--------|----------|---------|
| `IDENTIFIED` | Pitch Identification Report | Candidate found via DFS/BFS |
| `PITCH-DRAFT` | SE-Pitches/Draft/ | Internal pitch draft |
| `PITCH-SUBMITTED` | SE-Pitches/Submitted/ | Posted to forums, gathering feedback |
| `CONVERGED` | SE-Pitches/Submitted/ | Ready for proposal development |

**Cross-references**: [PITCH-PROC-001], [PITCH-PROC-005]

---

## [PITCH-PROC-001] Pitch Triggers

**Scope**: Conditions that warrant drafting a pitch.

**Statement**: A pitch SHOULD be drafted when a language or standard library limitation is identified through concrete implementation work, and the limitation cannot be reasonably addressed through library-level workarounds.

### Trigger Categories

| Category | Description | Priority |
|----------|-------------|----------|
| Blocking limitation | Cannot implement desired API at all | High |
| Ecosystem fragmentation | Workaround creates incompatible parallel hierarchies | High |
| Source compatibility cliff | Evolutionary improvement would break existing code | Medium |
| Ergonomic degradation | Workaround significantly worse than potential fix | Medium |
| Performance limitation | Language prevents optimal implementation | Medium |
| Consistency gap | Related features behave differently without justification | Low |

### When NOT to Pitch

Before drafting, verify the idea is NOT in the [Commonly Proposed Changes](https://github.com/swiftlang/swift-evolution/blob/main/commonly_proposed.md) list:

| Rejected Idea | Reason |
|---------------|--------|
| Python-style indentation | Swift maintains C-family heritage |
| Array subscript returning Optional | Out-of-bounds is logic error, not runtime failure |
| Remove force-unwrap operator | Legitimately useful language feature |
| Garbage collection over ARC | Unsuitable for systems programming |
| Union types (`Int \| String`) | Type system cannot support |
| Replace ternary operator | C-family precedent, important use cases |

**Rationale**: Commonly proposed changes have been extensively debated. Pitches revisiting them require substantial new evidence.

**Cross-references**: [PITCH-PROC-002], [PITCH-PROC-003], [PITCH-ID-003]

---

## [PITCH-PROC-002] Evidence Requirements

**Scope**: Required evidence to support pitch motivation.

**Statement**: Pitches MUST include concrete evidence from implementation work, experiments, or production usage demonstrating the limitation.

### Evidence Categories

| Category | Description | How to Obtain |
|----------|-------------|---------------|
| Experiment results | Verified behavior through isolated tests | <doc:Experiment-Discovery>, <doc:Experiment-Investigation> |
| Implementation attempts | Code that would work with proposed change | Package implementation |
| Workaround analysis | Documented alternatives and their costs | Design exploration |
| Ecosystem impact | Other packages/users affected | Survey, issue tracking |

### Evidence Quality Criteria

| Criterion | Required | Description |
|-----------|----------|-------------|
| Reproducible | MUST | Others can verify findings |
| Minimal | MUST | Focused on specific limitation |
| Referenced | MUST | Links to experiment packages or implementations |
| Cross-version | SHOULD | Tested on multiple Swift versions |

### Evidence Gathered During Identification

If you followed <doc:SE-Pitch-Identification-Process>, your evidence package should include:

- Related experiments from BFS
- Affected packages/APIs
- Workaround inventory
- Prior community discussions

**Rationale**: Swift Evolution requires concrete motivation. Implementation experience provides compelling evidence that theoretical arguments cannot.

**Cross-references**: [PITCH-PROC-001], [PITCH-ID-002], <doc:Experiment>

---

## [PITCH-PROC-003] Scope Analysis

**Scope**: Determining whether one or multiple pitches are needed.

**Statement**: Before drafting, the scope MUST be analyzed to determine if the solution requires one pitch or a sequence of dependent pitches.

### Dependency Analysis Process

1. **List all changes** needed for the complete solution
2. **Identify dependencies** between changes
3. **Determine minimal independent units** that provide value alone
4. **Order by dependency** — foundational changes first

**Correct**:
```text
Complete solution: ~Copyable support for Comparable

Changes identified:
1. Witness matching relaxation (compiler change)
2. Comparable protocol definition (stdlib change)

Dependency analysis:
- (2) depends on (1) for source compatibility
- (1) is independently useful beyond (2)

Decision: Two pitches
- PITCH-XXXX: Borrowing Parameter Witness Relaxation
- PITCH-YYYY: ~Copyable Equatable and Comparable (depends on XXXX)
```

### Dependency Tracking

When pitches have dependencies, document them in metadata:

```yaml
depends_on: PITCH-XXXX
```

**Rationale**: Smaller focused pitches are easier for the community to evaluate. Dependency chains allow incremental progress.

**Cross-references**: [PITCH-PROC-004]

---

## [PITCH-PROC-004] Pitch Drafting

**Scope**: Creating internal pitch drafts before forum submission.

**Statement**: Pitches MUST be drafted in `SE-Pitches/Draft/` before posting to Swift Forums.

### Pitch File Location

```text
SE-Pitches/Draft/PITCH-XXXX {Title}.md
```

### Pitch Naming Convention

| Placeholder | Meaning |
|-------------|---------|
| PITCH-XXXX | First pitch in a sequence |
| PITCH-YYYY | Dependent on PITCH-XXXX |
| PITCH-AAAA | Independent pitch |

### Pitch Content Structure

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
identification_report: path/to/report (if applicable)
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

### Pitch vs. Proposal Content

| Aspect | Pitch | Proposal |
|--------|-------|----------|
| Problem statement | Required | Required |
| Solution direction | General | Complete specification |
| Detailed design | Not needed | Required |
| Compatibility analysis | Brief mention | Full analysis |
| Implementation | Not required | Required for language changes |
| Length | ~500-1000 words | ~2000-5000 words |

### Quality Checklist

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

**Statement**: When a pitch draft is ready for community feedback, it MUST be posted to Swift Forums and moved to `SE-Pitches/Submitted/`.

### Submission Process

1. **Post to Forums**: Create thread in Evolution > Pitches
2. **Update file**: Add forum link to metadata
3. **Move file**: `SE-Pitches/Draft/` → `SE-Pitches/Submitted/`
4. **Engage**: Respond to feedback, iterate on pitch

### Forum Post Format

**Title**: `[Pitch] {Pitch Title}`

**Body**: Copy the pitch content, formatted for forum markdown.

**Tags**: Add relevant tags (e.g., `concurrency`, `ownership`, `generics`)

### Updated Metadata After Submission

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

### Tracking Pitch Progress

| Signal | Meaning | Action |
|--------|---------|--------|
| Positive reception | Community sees value | Proceed to proposal |
| Design questions | Clarification needed | Update pitch, respond |
| Alternative suggestions | Different approach proposed | Evaluate, possibly revise |
| Negative reception | Fundamental concerns | Address or reconsider |
| Core team feedback | Official guidance | Incorporate direction |

### Convergence Criteria

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

**Cross-references**: [PITCH-PROC-004], <doc:SE-Proposal-Process>

---

## [PITCH-PROC-006] Linking Evidence Bidirectionally

**Scope**: Maintaining connections between pitches and evidence.

**Statement**: Pitches MUST maintain bidirectional links to experiments and implementations.

### In Pitch

```markdown
**Related experiments**:
- [comparable-shadowing-test](link) — Demonstrates limitation
- [noncopyable-accessor-pattern](link) — Shows workaround costs
```

### In Experiment

```markdown
## Related Pitches

This experiment motivated:
- [PITCH-XXXX Borrowing Witness Relaxation](link)
```

### In Identification Report

If you used <doc:SE-Pitch-Identification-Process>:

```markdown
## Resulting Pitch

This identification led to:
- [PITCH-XXXX {Title}](link)
```

**Rationale**: Bidirectional links enable traceability from pitches to evidence.

**Cross-references**: [PITCH-PROC-002], <doc:Experiment>

---

## [PITCH-PROC-007] Pitch Iteration

**Scope**: Updating pitches based on forum feedback.

**Statement**: Pitches SHOULD be iterated based on community feedback. Significant changes MUST be documented in the pitch file.

### Iteration Process

1. **Receive feedback** on forums
2. **Evaluate** the feedback objectively
3. **Update pitch** in `SE-Pitches/Submitted/`
4. **Post update** to forum thread
5. **Record revision** in metadata

### Revision Tracking

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

### When to Withdraw

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

## Workflow Summary

```text
┌─────────────────────────────────────────────────────────────┐
│                    SE-PITCH WORKFLOW                         │
└─────────────────────────────────────────────────────────────┘

1. TRIGGER [PITCH-PROC-001]
   │
   ├─ From <doc:SE-Pitch-Identification-Process>
   ├─ Implementation blocked?
   ├─ Ecosystem fragmentation?
   └─ NOT in commonly_proposed.md?
                    │
                    ▼
2. EVIDENCE [PITCH-PROC-002]
   │
   ├─ Gather from identification BFS
   ├─ Run additional experiments if needed
   └─ Document findings
                    │
                    ▼
3. SCOPE [PITCH-PROC-003]
   │
   └─ One pitch or sequence?
                    │
                    ▼
4. DRAFT PITCH [PITCH-PROC-004]
   │
   ├─ Create SE-Pitches/Draft/PITCH-XXXX
   ├─ Problem + Direction + Evidence + Questions
   └─ Quality checklist
                    │
                    ▼
5. SUBMIT PITCH [PITCH-PROC-005]
   │
   ├─ Post to Swift Forums > Evolution > Pitches
   ├─ Move to SE-Pitches/Submitted/
   └─ Engage with feedback
                    │
                    ▼
6. ITERATE [PITCH-PROC-007]
   │
   ├─ Respond to feedback
   ├─ Update pitch as needed
   └─ Track revisions
                    │
                    ▼
7. CONVERGENCE CHECK [PITCH-PROC-005]
   │
   ├─▶ Converged    → Proceed to <doc:SE-Proposal-Process>
   ├─▶ Withdrawn    → Document reasoning, archive
   └─▶ Ongoing      → Continue iteration
```

---

## Topics

### Related Processes

- <doc:SE-Pitch-Identification-Process> — Discovering pitch candidates (upstream)
- <doc:SE-Proposal-Process> — Formal proposal development (downstream)

### Evidence Infrastructure

- <doc:Experiment> — Experiment infrastructure
- <doc:Experiment-Discovery> — Proactive verification
- <doc:Experiment-Investigation> — Debugging failures

### Official Resources

- [Swift Evolution Process](https://github.com/swiftlang/swift-evolution/blob/main/process.md)
- [Commonly Proposed Changes](https://github.com/swiftlang/swift-evolution/blob/main/commonly_proposed.md)
- [Swift Forums: Evolution > Pitches](https://forums.swift.org/c/evolution/pitches/18)

### Cross-Reference Index

| ID | Title | Focus |
|----|-------|-------|
| PITCH-PROC-001 | Pitch Triggers | When to draft pitches |
| PITCH-PROC-002 | Evidence Requirements | Supporting documentation |
| PITCH-PROC-003 | Scope Analysis | One vs. multiple pitches |
| PITCH-PROC-004 | Pitch Drafting | Creating internal drafts |
| PITCH-PROC-005 | Pitch Submission | Forum posting and tracking |
| PITCH-PROC-006 | Linking Evidence | Bidirectional traceability |
| PITCH-PROC-007 | Pitch Iteration | Updating based on feedback |
