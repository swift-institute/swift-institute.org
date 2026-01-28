---
name: blog-process
description: |
  Blog post workflows: ideation, drafting, review, publishing.
  Apply when creating technical blog content.

layer: process

requires:
  - swift-institute

applies_to:
  - blog
  - documentation

migrated_from: Blog/Blog Post Process.md
migration_date: 2026-01-28
---

# Blog Post Process

Two-phase workflow for capturing blog post ideas from ongoing work and developing them into published Swift Institute blog posts.

| Phase | Purpose | Artifact |
|-------|---------|----------|
| **Phase 1: Capture** | Note blog-worthy findings as they emerge | Ideas Index entry |
| **Phase 2: Publish** | Draft, review, and publish selected ideas | Published blog post |

**Applies to**: Technical deep dives, pattern documentation, announcements, lessons learned, tutorials derived from Swift Institute work.

**Does not apply to**: Marketing content, community management, or content not derived from documented processes.

---

## Quick Reference: Trigger Points

| Source | Trigger | Blog Category |
|--------|---------|---------------|
| Experiment | `Result: REFUTED` with novel insight | Lessons Learned |
| Experiment | Compiler limitation discovered | Technical Deep Dive |
| Experiment | Surprising `Result: CONFIRMED` | Technical Deep Dive |
| Research | DECISION with broader relevance | Pattern Documentation |
| Research | Novel convention established | Pattern Documentation |
| SE-Pitch | Pitch submitted to Swift Forums | Announcement |
| SE-Proposal | Proposal accepted/rejected | Announcement / Lessons Learned |
| Package | v1.0 or major release | Announcement |
| Discovery | Cross-cutting pattern identified | Pattern Documentation |
| Implementation | Non-obvious solution found | Tutorial/How-To |

---

## Blog Categories

| Category | Description | Typical Source |
|----------|-------------|----------------|
| **Technical Deep Dive** | Compiler behavior, language semantics, implementation details | Experiments |
| **Pattern Documentation** | Conventions, patterns, design rationale | Research |
| **Announcement** | Package releases, SE proposal status, milestones | SE work, packages |
| **Lessons Learned** | What didn't work and why | REFUTED experiments, rejected proposals |
| **Tutorial/How-To** | Step-by-step implementation guidance | Implementation work |

---

## Directory Structure

```text
swift-institute/.../Blog/
├── _index.md              # Ideas Index (Phase 1 output)
├── Draft/                 # Work in progress
│   └── {slug}.md
├── Review/                # Awaiting review
│   └── {slug}.md
└── Published/             # Historical record
    └── YYYY-MM-DD-{slug}.md
```

---

## Phase 1: Idea Capture

### Phase Contract

**Entry criteria**: Trigger event occurred, source artifact exists, insight is communicable to external Swift developers.

**Exit criteria**: Ideas Index entry created per [BLOG-003], source documents linked bidirectionally, category assigned, working title provided.

---

### [BLOG-001] Idea Capture Triggers

**Statement**: A blog idea SHOULD be captured when work produces an insight valuable to the broader Swift community that is not adequately served by internal documentation alone.

| Signal | Priority |
|--------|----------|
| Novel insight (not documented elsewhere) | High |
| Common pitfall (mistake others will make) | High |
| Pattern emergence (broad applicability) | Medium |
| Milestone (significant release/acceptance) | Medium |
| Narrative (interesting journey) | Low |

**Integration with other processes**: When these events occur, evaluate for blog capture:

| Process | Event | Question |
|---------|-------|----------|
| Experiment [EXP-006] | Result documented | Would external developers benefit? |
| Experiment [EXP-006a] | Findings promoted | Significant enough for broader communication? |
| Research [RES-006] | DECISION reached | Does this establish an adoptable pattern? |
| Research [RES-006a] | Findings promoted | Would the rationale interest the community? |

**Filter**: Not everything interesting internally is worth a public blog post. The test is "would external Swift developers benefit?"

**Cross-references**: [BLOG-002], [BLOG-003]

---

### [BLOG-002] Ideas Index Format

**Statement**: The Ideas Index MUST be maintained in `Blog/_index.md` with entries organized by status and sorted by capture date.

Sections (in order): **Ready for Drafting**, **Needs More Context**, **In Progress**, **Published**.

Each section uses a table with these fields:

| Section | Required Columns |
|---------|-----------------|
| Ready for Drafting | ID, Title, Category, Source, Captured, Notes |
| Needs More Context | ID, Title, Category, Source, Captured, Blocker |
| In Progress | ID, Title, Category, Writer, Started, Draft |
| Published | ID, Title, Published, Post |

Ideas are numbered sequentially: `BLOG-IDEA-001`, `BLOG-IDEA-002`, etc.

```markdown
## Ready for Drafting

| ID | Title | Category | Source | Captured | Notes |
|----|-------|----------|--------|----------|-------|
| BLOG-IDEA-007 | The Hidden ~Copyable Sequence Trap | Lessons Learned | [experiment](link) | 2026-01-23 | Bug #86669, workaround documented |
```

**Cross-references**: [BLOG-001], [BLOG-003]

---

### [BLOG-003] Idea Entry Template

**Statement**: Each Ideas Index entry MUST include sufficient context for someone else to draft the post.

**Required fields**: ID (`BLOG-IDEA-XXX`), Title (working, can change), Category, Source (link to artifact), Captured (date), Notes/Blocker.

For complex ideas, create extended context in `Blog/Ideas/BLOG-IDEA-XXX-context.md` covering: source links, key points to cover, target audience, estimated complexity.

**Cross-references**: [BLOG-001], [BLOG-002]

---

### [BLOG-004] Bidirectional Linking (Phase 1)

**Statement**: When a blog idea is captured, the source artifact SHOULD be updated with a reference to the blog idea.

In source artifact (experiment header, research document):

```markdown
## Blog Potential

This {experiment/research/finding} has been captured as a blog idea:
- [BLOG-IDEA-XXX: {Title}](../Blog/_index.md#blog-idea-xxx)
```

In experiment main.swift header:
```swift
// Blog: BLOG-IDEA-007 "The Hidden ~Copyable Sequence Trap"
```

**Cross-references**: [BLOG-007]

---

## Phase 2: Draft and Publish

### Phase Contract

**Entry criteria**: Idea in "Ready for Drafting", writer assigned, entry moved to "In Progress".

**Exit criteria**: All required sections complete per [BLOG-005], technical accuracy verified (code examples tested), review completed, publication metadata complete, file in `Published/`, Ideas Index updated, source artifacts updated with post link.

---

### [BLOG-005] Blog Post Structure

**Statement**: Blog posts MUST follow a consistent structure appropriate to their category.

#### Universal Metadata

```markdown
<!--
---
id: BLOG-IDEA-XXX
title: {Final Title}
slug: {url-friendly-slug}
category: {Category}
date_drafted: YYYY-MM-DD
date_published: YYYY-MM-DD
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

**Technical Deep Dive**: The Problem → What We Found → Why This Happens → Implications → References

**Pattern Documentation**: Context → The Pattern → Alternatives We Considered → When to Use This → References

**Announcement**: What's New → Highlights → Getting Started → What's Next → Links

**Lessons Learned**: What We Tried → What Went Wrong → What We Learned → The Fix/Workaround → Takeaway → References

**Tutorial/How-To**: Goal → Prerequisites → Steps (numbered with code) → Complete Example → Common Issues → References

**Cross-references**: [BLOG-006]

---

### [BLOG-006] Review Process

**Statement**: Blog posts MUST be reviewed before publication.

| Criterion | Required |
|-----------|----------|
| Technical accuracy (code compiles, examples work) | MUST |
| Clarity (understandable to target audience) | MUST |
| Completeness (all sections filled) | MUST |
| Links verified (all references accessible) | MUST |
| Tone appropriate (professional, educational) | SHOULD |
| Length appropriate (not padded, not truncated) | SHOULD |

Process: (1) Move draft to `Blog/Review/`, (2) request review, (3) address feedback, (4) reviewer approves.

After review, add metadata: `review_date`, `reviewer`, `review_notes`.

**Cross-references**: [BLOG-005], [BLOG-007]

---

### [BLOG-007] Publication Process

**Statement**: When a post passes review, it MUST be published following the standard process.

| Step | Action |
|------|--------|
| 1 | Finalize metadata (`date_published` set) |
| 2 | Rename and move: `Blog/Published/YYYY-MM-DD-{slug}.md` |
| 3 | Update Ideas Index (entry → "Published" section) |
| 4 | Update source artifacts (add link to published post) |
| 5 | Publish to blog platform |

File naming: `YYYY-MM-DD-{slug}.md` (e.g., `2026-01-25-the-hidden-noncopyable-sequence-trap.md`)

Source artifact update:
```markdown
## Blog Post

This finding was published as:
- [{Title}](../Blog/Published/YYYY-MM-DD-{slug}.md) (YYYY-MM-DD)
```

Traceability chain: Source Artifact → Blog Idea → Published Post (bidirectional).

**Cross-references**: [BLOG-004], [BLOG-006]

---

## Cross-References

See also:
- **research-process** skill for research that becomes blog posts ([RES-006], [RES-006a])
- **experiment-process** skill for experiments that become blog posts ([EXP-006], [EXP-006a])
