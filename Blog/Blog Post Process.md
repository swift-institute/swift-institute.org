# Blog Post Process

@Metadata {
    @TitleHeading("Swift Institute")
}

Two-phase workflow for capturing blog post ideas from ongoing work and developing them into published Swift Institute blog posts.

## Overview

**Scope**: This document defines the process for identifying, capturing, drafting, and publishing Swift Institute blog posts derived from experiments, research, SE work, and package development.

**Two-phase architecture**:

| Phase | Purpose | Artifact |
|-------|---------|----------|
| **Phase 1: Capture** | Note blog-worthy findings as they emerge | Ideas Index entry |
| **Phase 2: Publish** | Draft, review, and publish selected ideas | Published blog post |

**Applies to**: Technical deep dives, pattern documentation, announcements, lessons learned, and tutorials derived from Swift Institute work.

**Does not apply to**: Marketing content, community management, or content not derived from documented Swift Institute processes.

**Normative language**: This document uses RFC 2119 conventions (MUST, SHOULD, MAY).

---

## Quick Reference: Trigger Points

**Scope**: When to capture a blog idea from other processes.

| Source | Trigger | Blog Category |
|--------|---------|---------------|
| Experiment | `Result: REFUTED` with novel insight | Lessons Learned |
| Experiment | Compiler limitation discovered | Technical Deep Dive |
| Experiment | Surprising `Result: CONFIRMED` | Technical Deep Dive |
| Research | DECISION with broader relevance | Pattern Documentation |
| Research | Novel convention established | Pattern Documentation |
| SE-Pitch | Pitch submitted to Swift Forums | Announcement |
| SE-Pitch | Pitch converged | Update/Follow-up |
| SE-Proposal | Proposal accepted | Announcement |
| SE-Proposal | Proposal rejected | Lessons Learned |
| Package | v1.0 or major release | Announcement |
| Discovery | Cross-cutting pattern identified | Pattern Documentation |
| Implementation | Non-obvious solution found | Tutorial/How-To |

**Cross-references**: [BLOG-001]

---

## Quick Reference: Directory Structure

**Scope**: File organization for blog post lifecycle.

```text
swift-institute/Sources/Swift Institute/Swift Institute.docc/
└── Blog/
    ├── _index.md              # Ideas Index (Phase 1 output)
    ├── Draft/                 # Work in progress
    │   └── {slug}.md
    ├── Review/                # Awaiting review
    │   └── {slug}.md
    └── Published/             # Historical record
        └── YYYY-MM-DD-{slug}.md
```

**Cross-references**: [BLOG-002], [BLOG-005]

---

## Quick Reference: Blog Categories

**Scope**: Classification of blog post types.

| Category | Description | Typical Source |
|----------|-------------|----------------|
| **Technical Deep Dive** | Detailed exploration of compiler behavior, language semantics, or implementation details | Experiments |
| **Pattern Documentation** | Conventions, patterns, and design rationale | Research |
| **Announcement** | Package releases, SE proposal status, milestones | SE work, packages |
| **Lessons Learned** | What didn't work and why | REFUTED experiments, rejected proposals |
| **Tutorial/How-To** | Step-by-step implementation guidance | Implementation work |

---

## Phase 1: Idea Capture

### Phase Contract: Capture

**Scope**: Entry and exit criteria for the idea capture phase.

#### Entry Criteria

| Criterion | Required | Verification |
|-----------|----------|--------------|
| Trigger event occurred | MUST | One of [BLOG-001] triggers |
| Source artifact exists | MUST | Experiment, research, pitch, or implementation documented |
| Insight is communicable | MUST | Can be explained to external Swift developers |

#### Exit Criteria

| Criterion | Required | Verification |
|-----------|----------|--------------|
| Ideas Index entry created | MUST | Entry in `Blog/_index.md` per [BLOG-003] |
| Source documents linked | MUST | Bidirectional links established |
| Category assigned | MUST | One of the defined categories |
| Working title provided | MUST | Descriptive, not final |

---

### [BLOG-001] Idea Capture Triggers

**Scope**: Conditions that warrant adding an entry to the Ideas Index.

**Statement**: A blog idea SHOULD be captured when work produces an insight valuable to the broader Swift community that is not adequately served by internal documentation alone.

#### Trigger Categories

| Category | Signal | Priority |
|----------|--------|----------|
| Novel insight | Finding not documented elsewhere | High |
| Common pitfall | Mistake others will make | High |
| Pattern emergence | Convention with broad applicability | Medium |
| Milestone | Significant release or acceptance | Medium |
| Narrative | Interesting journey worth telling | Low |

#### Integration with Other Processes

When the following occur, evaluate for blog capture:

| Process | Event | Evaluation Question |
|---------|-------|---------------------|
| Experiment [EXP-006] | Result documented | Would external developers benefit from this finding? |
| Experiment [EXP-006a] | Findings promoted to docs | Is the finding significant enough for broader communication? |
| Research [RES-006] | DECISION reached | Does this establish a pattern others could adopt? |
| Research [RES-006a] | Findings promoted | Would the rationale interest the Swift community? |
| SE-Pitch [PITCH-PROC-005] | Pitch submitted | Is this worth announcing to build awareness? |
| SE-Proposal [PROP-PROC-005] | Decision reached | Should we communicate the outcome and implications? |

**Correct**:
```text
Event: Experiment "noncopyable-sequence-bug" Result: REFUTED
Finding: Swift compiler bug #86669 affects all ~Copyable Sequence implementations

Evaluation:
✓ Novel insight: Yes—affects anyone building ~Copyable collections
✓ Common pitfall: Yes—others will hit this
✓ Documented elsewhere: No—only in our experiment and bug report

Action: Add to Ideas Index
Category: Lessons Learned
Working Title: "The Hidden ~Copyable Sequence Trap (and How We Found It)"
```

**Incorrect**:
```text
Event: Experiment "basic-sendable-test" Result: CONFIRMED
Finding: Sendable works as documented

Evaluation:
✗ Novel insight: No—this is expected behavior
✗ Common pitfall: No—nothing surprising

Action: ❌ Do not add to Ideas Index (no external value)
```

**Rationale**: Not everything interesting internally is worth a public blog post. The filter is "would external Swift developers benefit?"

**Cross-references**: [BLOG-002], [BLOG-003]

---

### [BLOG-002] Ideas Index Format

**Scope**: Structure of the Ideas Index file.

**Statement**: The Ideas Index MUST be maintained in `Blog/_index.md` with entries organized by status and sorted by capture date within each section.

#### Index Structure

```markdown
# Blog Ideas Index

## Ready for Drafting

Ideas that have sufficient context and are ready for a writer to pick up.

| ID | Title | Category | Source | Captured | Notes |
|----|-------|----------|--------|----------|-------|
| BLOG-IDEA-003 | Title | Category | [Source](link) | YYYY-MM-DD | Brief context |

## Needs More Context

Ideas captured but requiring additional information before drafting.

| ID | Title | Category | Source | Captured | Blocker |
|----|-------|----------|--------|----------|---------|
| BLOG-IDEA-002 | Title | Category | [Source](link) | YYYY-MM-DD | What's needed |

## In Progress

Ideas currently being drafted.

| ID | Title | Category | Writer | Started | Draft |
|----|-------|----------|--------|---------|-------|
| BLOG-IDEA-001 | Title | Category | Name | YYYY-MM-DD | [Draft](link) |

## Published

Completed posts (brief record, full post in Published/).

| ID | Title | Published | Post |
|----|-------|-----------|------|
| BLOG-IDEA-000 | Title | YYYY-MM-DD | [Post](link) |
```

#### Idea IDs

Ideas are numbered sequentially: `BLOG-IDEA-001`, `BLOG-IDEA-002`, etc.

**Correct**:
```markdown
## Ready for Drafting

| ID | Title | Category | Source | Captured | Notes |
|----|-------|----------|--------|----------|-------|
| BLOG-IDEA-007 | The Hidden ~Copyable Sequence Trap | Lessons Learned | [noncopyable-sequence-bug](../Experiments/noncopyable-sequence-bug/) | 2026-01-23 | Compiler bug #86669, workaround documented |
| BLOG-IDEA-006 | Why We Use Phantom Generics for Index Types | Pattern Documentation | [index-type-hierarchy](../Research/index-type-hierarchy.md) | 2026-01-20 | Research DECISION, broadly applicable |
```

**Incorrect**:
```markdown
## Ideas

- Something about ~Copyable  ❌ No ID, no structure
- Index types are interesting  ❌ No source link, no category
```

**Rationale**: Structured index enables tracking, prioritization, and prevents ideas from being lost.

**Cross-references**: [BLOG-001], [BLOG-003]

---

### [BLOG-003] Idea Entry Template

**Scope**: Required information when capturing a blog idea.

**Statement**: Each Ideas Index entry MUST include sufficient context for someone else to draft the post.

#### Required Fields

| Field | Required | Description |
|-------|----------|-------------|
| ID | MUST | Sequential `BLOG-IDEA-XXX` |
| Title | MUST | Working title (can change) |
| Category | MUST | One of the defined categories |
| Source | MUST | Link to originating artifact |
| Captured | MUST | Date captured |
| Notes/Blocker | MUST | Context or what's needed |

#### Extended Context (Optional)

For complex ideas, create a brief context file:

```text
Blog/Ideas/BLOG-IDEA-007-context.md
```

```markdown
# BLOG-IDEA-007: The Hidden ~Copyable Sequence Trap

## Source
- Experiment: [noncopyable-sequence-bug](link)
- Bug Report: [swift#86669](link)

## Key Points to Cover
1. What we were trying to do
2. The surprising compiler error
3. Root cause investigation
4. The workaround we found
5. Status of the bug fix

## Target Audience
Swift developers building ~Copyable collections

## Estimated Complexity
Medium (needs code examples, but straightforward narrative)
```

**Correct**:
```text
Capture event: Research "index-type-hierarchy" reached DECISION

Index entry:
| BLOG-IDEA-006 | Why We Use Phantom Generics for Index Types | Pattern Documentation | [index-type-hierarchy](link) | 2026-01-20 | DECISION reached, alternatives documented |

Context: The research document has complete rationale. Post should:
- Explain the problem (type-safe indices without runtime cost)
- Show the alternatives we considered
- Explain why phantom generics won
```

**Incorrect**:
```text
Index entry:
| BLOG-IDEA-006 | Index stuff | ??? | somewhere | recently | it's interesting |

❌ No category
❌ No source link
❌ Vague date
❌ No actionable context
```

**Rationale**: Capture should be lightweight but sufficient. A future writer (possibly months later) needs enough context to proceed.

**Cross-references**: [BLOG-001], [BLOG-002]

---

### [BLOG-004] Bidirectional Linking (Phase 1)

**Scope**: Connecting source artifacts to blog ideas.

**Statement**: When a blog idea is captured, the source artifact SHOULD be updated with a reference to the blog idea.

#### In Source Artifact

Add to experiment, research, or other source document:

```markdown
## Blog Potential

This {experiment/research/finding} has been captured as a blog idea:
- [BLOG-IDEA-XXX: {Title}](../Blog/_index.md#blog-idea-xxx)
```

#### Example: Experiment

```markdown
// In noncopyable-sequence-bug/main.swift header

// MARK: - ~Copyable Sequence Module Emission Bug
// ...
// Result: REFUTED - compiler bug #86669
// ...
//
// Blog: BLOG-IDEA-007 "The Hidden ~Copyable Sequence Trap"
```

**Rationale**: Bidirectional links enable traceability and prevent duplicate capture.

**Cross-references**: [BLOG-007]

---

## Phase 2: Draft and Publish

### Phase Contract: Publish

**Scope**: Entry and exit criteria for the drafting and publication phase.

#### Entry Criteria

| Criterion | Required | Verification |
|-----------|----------|--------------|
| Idea in "Ready for Drafting" | MUST | Entry exists with sufficient context |
| Writer assigned | MUST | Someone commits to drafting |
| Entry moved to "In Progress" | MUST | Index updated |

#### Exit Criteria (Publication)

| Criterion | Required | Verification |
|-----------|----------|--------------|
| All required sections complete | MUST | Per [BLOG-005] |
| Technical accuracy verified | MUST | Code examples tested |
| Review completed | MUST | At least one reviewer |
| Publication metadata complete | MUST | Date, slug, category |
| File in Published/ | MUST | With date prefix |
| Ideas Index updated | MUST | Entry moved to "Published" |
| Source artifacts updated | MUST | Links to published post |

---

### [BLOG-005] Blog Post Structure

**Scope**: Required structure for blog post drafts.

**Statement**: Blog posts MUST follow a consistent structure appropriate to their category.

#### Universal Metadata

```markdown
<!--
---
id: BLOG-IDEA-XXX
title: {Final Title}
slug: {url-friendly-slug}
category: {Technical Deep Dive | Pattern Documentation | Announcement | Lessons Learned | Tutorial}
date_drafted: YYYY-MM-DD
date_published: YYYY-MM-DD (when published)
author: {name}
source_artifacts:
  - {path/to/experiment}
  - {path/to/research}
tags:
  - swift
  - {relevant-tags}
---
-->
```

#### Structure by Category

**Technical Deep Dive**:
```markdown
# {Title}

## The Problem
{What we were trying to do}

## What We Found
{The technical finding with code examples}

## Why This Happens
{Root cause explanation}

## Implications
{What this means for Swift developers}

## References
{Links to experiments, documentation, bug reports}
```

**Pattern Documentation**:
```markdown
# {Title}

## Context
{Why this pattern matters}

## The Pattern
{Description with examples}

## Alternatives We Considered
{Brief summary from research}

## When to Use This
{Applicability guidance}

## References
{Links to research, implementation examples}
```

**Announcement**:
```markdown
# {Title}

## What's New
{Brief summary}

## Highlights
{Key features or changes}

## Getting Started
{How to use/adopt}

## What's Next
{Future direction}

## Links
{Package, documentation, forum discussion}
```

**Lessons Learned**:
```markdown
# {Title}

## What We Tried
{The goal and approach}

## What Went Wrong
{The failure or unexpected behavior}

## What We Learned
{The insight}

## The Fix/Workaround
{How we resolved it, if applicable}

## Takeaway
{What readers should remember}

## References
{Links to experiments, bug reports}
```

**Tutorial/How-To**:
```markdown
# {Title}

## Goal
{What readers will accomplish}

## Prerequisites
{What readers need to know/have}

## Steps
### Step 1: {Action}
{Instructions with code}

### Step 2: {Action}
{Instructions with code}

## Complete Example
{Full working code}

## Common Issues
{Troubleshooting}

## References
{Further reading}
```

**Rationale**: Consistent structure aids both writers and readers. Category-specific templates ensure appropriate content.

**Cross-references**: [BLOG-006]

---

### [BLOG-006] Review Process

**Scope**: Quality gate before publication.

**Statement**: Blog posts MUST be reviewed before publication. Review criteria depend on post category.

#### Review Criteria

| Criterion | Required | Description |
|-----------|----------|-------------|
| Technical accuracy | MUST | Code compiles, examples work |
| Clarity | MUST | Understandable to target audience |
| Completeness | MUST | All sections filled appropriately |
| Links verified | MUST | All references accessible |
| Tone appropriate | SHOULD | Professional, educational |
| Length appropriate | SHOULD | Not padded, not truncated |

#### Review Process

| Step | Action | Output |
|------|--------|--------|
| 1 | Move draft to `Blog/Review/` | File relocated |
| 2 | Request review | Reviewer assigned |
| 3 | Address feedback | Draft updated |
| 4 | Reviewer approves | Ready for publication |

#### Metadata Update After Review

```yaml
review_date: 2026-01-25
reviewer: {name}
review_notes: |
  - Clarified example in Step 2
  - Fixed broken link to experiment
```

**Correct**:
```text
Review: BLOG-IDEA-007 "The Hidden ~Copyable Sequence Trap"

Criteria:
✓ Technical accuracy: Code examples compile on Swift 6.0
✓ Clarity: Narrative flows, jargon explained
✓ Completeness: All Lessons Learned sections present
✓ Links verified: Experiment and bug report accessible

Feedback addressed:
- Added Swift version to code examples
- Clarified "module emission" terminology

Status: Ready for publication
```

**Incorrect**:
```text
Review: BLOG-IDEA-007

"Looks good to me"  ❌ No criteria checked
                    ❌ No specific feedback
                    ❌ Links not verified
```

**Rationale**: Review ensures quality and catches errors before public visibility.

**Cross-references**: [BLOG-005], [BLOG-007]

---

### [BLOG-007] Publication Process

**Scope**: Finalizing and publishing blog posts.

**Statement**: When a post passes review, it MUST be published following the standard process.

#### Publication Steps

| Step | Action | Output |
|------|--------|--------|
| 1 | Finalize metadata | `date_published` set |
| 2 | Rename and move file | `Blog/Published/YYYY-MM-DD-{slug}.md` |
| 3 | Update Ideas Index | Entry moved to "Published" section |
| 4 | Update source artifacts | Add link to published post |
| 5 | Publish to platform | Post live on blog |

#### File Naming

```text
Blog/Published/2026-01-25-the-hidden-noncopyable-sequence-trap.md
```

Format: `YYYY-MM-DD-{slug}.md`

#### Ideas Index Update

Move entry from "In Progress" to "Published":

```markdown
## Published

| ID | Title | Published | Post |
|----|-------|-----------|------|
| BLOG-IDEA-007 | The Hidden ~Copyable Sequence Trap | 2026-01-25 | [Post](Published/2026-01-25-the-hidden-noncopyable-sequence-trap.md) |
```

#### Source Artifact Update

Update the originating experiment/research:

```markdown
## Blog Post

This finding was published as:
- [The Hidden ~Copyable Sequence Trap](../Blog/Published/2026-01-25-the-hidden-noncopyable-sequence-trap.md) (2026-01-25)
```

**Correct**:
```text
Publication: BLOG-IDEA-007

Steps completed:
✓ Metadata finalized: date_published: 2026-01-25
✓ File renamed: Draft/noncopyable-trap.md → Published/2026-01-25-the-hidden-noncopyable-sequence-trap.md
✓ Ideas Index updated: Entry in "Published" section
✓ Experiment updated: Link to published post added
✓ Published to blog platform

Traceability: Experiment → Blog Idea → Published Post (bidirectional)
```

**Incorrect**:
```text
Publication: BLOG-IDEA-007

❌ File left in Draft/
❌ Ideas Index not updated
❌ Source artifact not updated
❌ No publication date recorded

Result: Orphaned draft, broken traceability
```

**Rationale**: Consistent publication process ensures traceability and prevents orphaned content.

**Cross-references**: [BLOG-004], [BLOG-006]

---

## Workflow Summary

```text
┌─────────────────────────────────────────────────────────────┐
│                    BLOG POST WORKFLOW                        │
└─────────────────────────────────────────────────────────────┘

                    PHASE 1: IDEA CAPTURE
                    ══════════════════════

1. TRIGGER EVENT [BLOG-001]
   │
   ├─ Experiment result (REFUTED, surprising CONFIRMED)
   ├─ Research decision (DECISION with broad relevance)
   ├─ SE-Pitch/Proposal milestone
   ├─ Package release
   └─ Implementation insight
                    │
                    ▼
2. EVALUATE
   │
   └─ Would external Swift developers benefit?
                    │
        ┌───────────┴───────────┐
        │ No                    │ Yes
        │ → Do not capture      │ → Continue
        └───────────────────────┘
                                │
                                ▼
3. CAPTURE [BLOG-002], [BLOG-003]
   │
   ├─ Add entry to Blog/_index.md
   ├─ Assign ID, category, source link
   ├─ Note context or blockers
   └─ Update source artifact [BLOG-004]
                    │
                    ▼
            ┌───────────────────┐
            │   IDEAS INDEX     │ ← Ideas accumulate here
            └───────────────────┘
                    │
                    │ (when ready and writer available)
                    │
                    PHASE 2: DRAFT AND PUBLISH
                    ═══════════════════════════
                    │
                    ▼
4. DRAFT [BLOG-005]
   │
   ├─ Move entry to "In Progress"
   ├─ Create draft in Blog/Draft/
   ├─ Follow category template
   └─ Include all required sections
                    │
                    ▼
5. REVIEW [BLOG-006]
   │
   ├─ Move to Blog/Review/
   ├─ Technical accuracy check
   ├─ Clarity and completeness check
   └─ Address feedback
                    │
                    ▼
6. PUBLISH [BLOG-007]
   │
   ├─ Move to Blog/Published/YYYY-MM-DD-{slug}.md
   ├─ Update Ideas Index → "Published"
   ├─ Update source artifacts with post link
   └─ Publish to blog platform
```

---

## Topics

### Related Processes

- <doc:Experiment> — Source of technical findings
- <doc:Experiment-Discovery> — Proactive experiment workflow
- <doc:Experiment-Investigation> — Reactive experiment workflow
- <doc:Research> — Source of pattern documentation
- <doc:Research-Discovery> — Proactive research workflow
- <doc:Research-Investigation> — Reactive research workflow
- <doc:SE-Pitch-Process> — Source of announcements
- <doc:SE-Proposal-Process> — Source of announcements

### Cross-Reference Index

| ID | Title | Focus |
|----|-------|-------|
| BLOG-001 | Idea Capture Triggers | When to capture blog ideas |
| BLOG-002 | Ideas Index Format | Structure of the ideas backlog |
| BLOG-003 | Idea Entry Template | Required information per idea |
| BLOG-004 | Bidirectional Linking (Phase 1) | Connecting sources to ideas |
| BLOG-005 | Blog Post Structure | Templates by category |
| BLOG-006 | Review Process | Quality gate before publication |
| BLOG-007 | Publication Process | Finalizing and publishing |
