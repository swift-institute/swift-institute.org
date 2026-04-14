---
name: blog-process
description: |
  Blog post workflows for ideation, drafting, review, and publishing,
  with optional series planning and first-principles technical writing
  patterns. Apply when creating technical blog content.

layer: process

requires:
  - swift-institute

applies_to:
  - blog
  - documentation

migrated_from: Blog/Blog Post Process.md
migration_date: 2026-01-28
last_reviewed: 2026-04-14
---

# Blog Post Process

Two-phase workflow for capturing blog post ideas from ongoing work and developing them into published Swift Institute blog posts, with optional series planning for multi-part content.

| Phase | Purpose | Artifact |
|-------|---------|----------|
| **Phase 1: Capture** | Note blog-worthy findings as they emerge | Ideas Index entry |
| **Phase 2: Draft and Publish** | Draft, review, and publish selected ideas | Published blog post |

**Optional activity — Series Planning**: When developing a multi-part series, create a series plan (see [BLOG-008]) before drafting. Standalone posts proceed directly from capture to drafting.

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
├── Series/                # Series plans (optional activity output)
│   └── {series-slug}.md
├── Draft/                 # Work in progress
│   └── {slug}.md
├── Review/                # Awaiting review
│   └── {slug}.md
└── Published/             # Historical record
    └── YYYY-MM-DD-{slug}.md
```

---

## Writing Modes

### [BLOG-010] First-Principles Writing Pattern

**Statement**: Posts SHOULD follow one of two writing modes. The first-principles mode prioritizes discovery over declaration — the post guides the reader through the same journey of exploration that produced the insight. The conventional expository mode communicates conclusions, guidance, or reference information directly.

#### First-principles mode

| Principle | Description |
|-----------|-------------|
| **Problem before solution** | Demonstrate the pain before introducing the fix |
| **Ground in source material** | Reference SE proposals, official docs, compiler source — not just opinions |
| **Build through code** | Start with a minimal example and evolve it step by step |
| **Let the reader discover** | Use exploratory framing: "let's try... surprisingly... but what if..." |
| **Tests or evidence blocks as proof** | Back claims with running tests or compiler-verifiable code samples that readers can reproduce. For posts about type-system properties or compiler behavior, evidence blocks — exact signatures and minimal samples that reproduce the claimed behavior — are a valid alternative to test suites. |
| **Hit the wall honestly** | Show where things break — limitations build credibility |
| **Earn the abstraction** | Show concrete cases before generalizing into patterns or rules |

**Anti-pattern**: Stating the conclusion upfront and then walking through justification. This is appropriate for documentation but wrong for first-principles posts. The reader should *arrive* at the insight alongside the author.

**Exception — destination-first hook**: Showing the end-state upfront is valid when the reader can see *what* the code does but cannot yet understand *why* it matters. The significance is discovered through the journey, not declared at the outset. This differs from the anti-pattern because the reader sees syntax without understanding — the journey still produces genuine discovery.

#### Mode selection

| Situation | Default mode |
|-----------|-------------|
| Compiler behavior, language semantics, unexpected limitations | First-principles |
| Reconstructing design rationale through the choices that led there | First-principles |
| Non-obvious implementation solution, workaround discovery | First-principles |
| Release notes, package announcements, status updates | Conventional expository |
| Stable conventions intended as reference material | Conventional expository |
| Design rationale where the conclusion is well-established | Writer's judgment — first-principles if the journey adds value |

Some posts may blend modes. Use first-principles for discovery sections, conventional for reference sections.

Choose first-principles mode when the value of the post lies in the reader experiencing the reasoning, discovery, or constraint process. Choose conventional expository mode when the value lies primarily in communicating conclusions, guidance, updates, or reference information efficiently.

---

### [BLOG-011] Post Narrative Arc

**Statement**: Posts using the first-principles writing mode SHOULD follow a narrative arc with these beats.

| Beat | Purpose | Example |
|------|---------|---------|
| **Hook** | Show why this matters in 2–3 sentences | A concrete problem the reader has felt |
| **Scope** | (Optional) State what the post/series is *not* claiming | "This series is not arguing that all public APIs should use typed throws" |
| **Foundation** | Establish shared ground — define terms from source material | Reference the SE proposal, quote the key paragraph |
| **Build** | Evolve a working code example step by step | Start simple, add complexity incrementally |
| **Surprise** | Reveal something unexpected — positive or negative | "This compiles, and it works" or "This should work, but..." |
| **Wall** | Show the boundary of what works today | Where the approach breaks down, and why |
| **Resolution** | Provide the takeaway — what to do given the wall | A decision framework, workaround, or design principle |
| **Tease** | (Series only) Open the question that motivates the next post | "But what happens when you try this with..." |

Not every post needs every beat. Short posts may combine Foundation and Build. Standalone posts omit the Tease. The Scope beat is recommended for posts that argue for a specific approach — pre-empting strawman interpretations buys credibility with skeptical audiences. But the arc from Hook through Resolution is the backbone.

Posts using the first-principles pattern SHOULD contain at least one genuine moment of discovery — a compiler error, semantic limitation, surprising success, tradeoff, or failed intuition. This is often what makes the reasoning legible and the lesson stick. Do not manufacture drama where none exists. If a post has no natural moment of discovery, the conventional expository mode is likely a better fit.

---

### [BLOG-012] Running Example Design

**Statement**: Each post (or series) using the first-principles mode SHOULD center on a single running example that evolves, rather than presenting disconnected code snippets.

| Property | Requirement |
|----------|-------------|
| Minimal start | Begin with the simplest possible version |
| Motivated additions | Each change to the example is driven by a problem or question |
| Reproducible at every step | Every intermediate state can be reproduced by the reader. Intentionally failing states (compiler errors, crashes, test failures) are allowed when they are clearly labeled as the point of the step. |
| Realistic enough | Not a toy — the reader should see their own code in the example |
| Small enough | The reader can hold the full example in their head |

**Evolving the example**: When the example grows across a post, show only the diff (new or changed lines) with enough surrounding context to locate the change. Show the full example at most once near the end.

---

## Phase 1: Capture

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

## Optional Activity: Series Planning

### [BLOG-008] Series Concept

**Statement**: When related ideas form a natural progression, they SHOULD be planned as a multi-part series with a shared arc.

A series groups posts under a shared title where each part builds on what came before. The key property: a reader can start at Part 1 with no prior knowledge and follow the entire arc.

| Property | Requirement |
|----------|-------------|
| Ordered but accessible | Parts are designed to be read in sequence. Each part opens with a brief orientation (2–3 sentences) so readers arriving mid-series can understand the local goal, but prior parts are assumed for full depth. Each part should also advance the shared example, conceptual model, or both. |
| Shared running example | A single example evolves across parts, not a new example per post |
| Cliffhanger endings | Each part (except the last) ends with a question that motivates the next |
| Consistent voice | Same tone and style across all parts |

**When to use a series vs. standalone posts**:

| Series | Standalone |
|--------|------------|
| Topic requires layered understanding | Insight is complete in one post |
| Natural "walls" create dramatic pauses | No progression needed |
| Running example benefits from evolution | Examples are independent |
| 3+ related ideas in the index | 1–2 ideas |

---

### [BLOG-009] Series Plan Format

**Statement**: Each series MUST have a plan document in `Blog/Series/{series-slug}.md`.

```markdown
# {Series Title}

## Arc

{One paragraph describing the journey from start to finish.}

## Parts

### Part 1: {subtitle}
- **Opens with**: {the problem or question}
- **Builds to**: {the key insight}
- **Ends with**: {the cliffhanger}
- **Source ideas**: BLOG-IDEA-XXX, BLOG-IDEA-YYY

### Part 2: {subtitle}
- **Opens with**: {picks up from Part 1's cliffhanger}
- **Builds to**: {the key insight}
- **Ends with**: {the cliffhanger}
- **Source ideas**: BLOG-IDEA-ZZZ

### Part N: {subtitle}
...

## Target audience

{Who is this series for? What should they already know?}

## Entry assumptions

{What knowledge is assumed? What is explicitly NOT assumed?}

## Shared example

{Description of the running example that evolves across parts.}

## References

- {SE proposals, research docs, experiments that feed into this series}
```

**Series metadata in post frontmatter**:

```markdown
series: {series-slug}
series_part: 1
series_title: {Series Title}
```

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
series: {series-slug}           # optional — omit for standalone posts
series_part: {N}                # optional — part number within series
series_title: {Series Title}    # optional — shared series title
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

#### Relationship to writing modes

The category structures above define minimum section coverage and deliverable expectations. Posts following the first-principles writing pattern [BLOG-010] use the narrative arc [BLOG-011] as their rhetorical progression *within* these sections. Posts using conventional expository mode follow the category structure directly. See the mode selection table in [BLOG-010] for guidance on which mode to use.

Example: a Technical Deep Dive may include sections such as "Why this happens" and "Implications," while the reasoning inside those sections follows the first-principles arc from setup through discovery to resolution.

**Cross-references**: [BLOG-006], [BLOG-010], [BLOG-011]

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

**Series-level review**: For multi-part series, conduct a series-level review pass in addition to per-post checks. Evaluate: tone consistency across parts, evidence standards, rhetoric calibration, running example continuity, and cross-part forward/backward references.

**Collaborative review**: For posts targeting critical audiences (e.g., Swift Forums) or first-of-its-kind content, the **collaborative-discussion** skill can be used as a review mechanism. This is especially useful when the review surfaces contested editorial points that require explicit convergence rather than unilateral resolution.

**Cross-references**: [BLOG-005], [BLOG-007]

---

### [BLOG-013] Receipts: Link Every Load-Bearing Claim to a Runnable Experiment

**Statement**: Each load-bearing technical claim in a blog post MUST be backed by a reproducible experiment per [EXP-002], and the post MUST link from the claim's prose directly to the experiment's source on GitHub.

A *load-bearing claim* is any assertion the post relies on for its argument: "the compiler rejects X with diagnostic Y", "approach A compiles but approach B does not", "this fix produces these specific lines of code". Style claims, opinions, and expository background are exempt — only claims that the reader could in principle dispute by running code.

**Why**: Blog posts are written for external audiences who do not start from a position of trust. Every claim is implicitly a "trust me on this." Linking each claim to a runnable Swift package converts the post from assertion to demonstration. The reader can clone, build, and verify. This is the same evidence-over-assertion ethos that grounds [EXP-002] for internal research.

**How to apply**:

| Step | Action |
|------|--------|
| 1. Audit claims | Before drafting, list every claim in the post that asserts compiler/runtime/language behavior. Each one is a candidate for a backing experiment. |
| 2. Map to experiments | For each claim, identify whether an experiment already exists (often yes, since posts emerge from experimental work). If no, plan a variant. |
| 3. Add experiment variants | Create per-claim variants in the existing experiment package most relevant to the claim, never in a per-post directory. The experiment is named by what it tests, not by who consumes it. Naming: `V{N}_{descriptive}` (e.g., `V7_Retroactive`, `V8_ModuleSelectors`). Each variant should be minimal and prove exactly one claim. If no existing experiment fits, create a new package in `Experiments/` flat (no `blog-` prefix) per [EXP-002]. |
| 4. Link inline | In the post, link from the claim's prose to the variant's GitHub URL. Format: parenthetical or inline reference, not a footnote. |
| 5. Verify on draft completion | Before moving to Review per [BLOG-006], every load-bearing claim must have its link in place. |

**Inline link format** — preferred:

```markdown
Every variant fails. Identical error.
([V1–V5](https://github.com/swift-institute/swift-institute/tree/main/Experiments/{experiment-name}))
```

**Acceptable alternative** — footnote-style for dense passages:

```markdown
The compiler emits a different error here[^v7].

[^v7]: [V7_Retroactive](https://github.com/swift-institute/swift-institute/tree/main/Experiments/{experiment-name}/Sources/V7_Retroactive)
```

**Anti-pattern**: A claim asserted in prose without a link, when an experiment exists or could trivially be added. Any reader who wants to verify must hunt through the repo. Trust degrades.

**Anti-pattern**: A blanket "see this experiment for all claims" link at the bottom of the post. Per-claim links are higher-friction to write but dramatically lower-friction to verify. The asymmetry is the point.

**Exception**: Posts published while the author is still establishing their public footprint MAY ship with partial receipts (the author commits to backfilling). The post's Notes column in `Blog/_index.md` SHOULD record what's pending.

**Cross-references**: [EXP-002], [EXP-005], [EXP-006], [BLOG-005], [BLOG-006]

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
- `Blog/_Styleguide.md` for formatting, voice, and style conventions
