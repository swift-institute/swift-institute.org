---
name: research-process
description: |
  Research workflows: investigation, discovery, documentation.
  Apply when conducting design research or exploring alternatives.

layer: process

requires:
  - swift-institute

applies_to:
  - research
  - design

migrated_from: Research/Research.md
migration_date: 2026-01-28
---

# Research Process

Workflows for conducting design research.

---

## Research Types

### Investigation (Reactive)

Triggered by:
- Implementation uncertainty
- Design question during coding
- Bug requiring deeper understanding

### Discovery (Proactive)

Triggered by:
- Ecosystem audit
- New primitive proposal
- Architecture review

---

## Research Document Structure

```markdown
# Research: [Topic]

## Question
What specific question are we answering?

## Context
Background and constraints.

## Options Considered
1. Option A - description
2. Option B - description

## Analysis
Trade-offs and comparisons.

## Recommendation
Chosen approach and rationale.

## References
External sources consulted.
```

---

## Output Locations

| Output | Location |
|--------|----------|
| Research documents | `Research/` |
| Design decisions | `Research/` with `decision: true` |
| Blog candidates | Add to `Blog/_index.md` |

---

## Cross-References

See also:
- **experiment-process** skill for validation workflows
