---
name: reflect-session
description: |
  Structured post-session reflection capture.
  Apply at the end of any non-trivial work session, or when significant
  learning occurs mid-session. Creates a reflection entry in Research/Reflections/.

layer: process

requires:
  - swift-institute

applies_to:
  - reflection
  - session
  - learning

migrated_from:
  - Documentation.docc/_Reflections.md
  - Documentation.docc/_Reflections Consolidation.md
  - Research/session-reflection-meta-process.md
migration_date: 2026-02-12
---

# Reflect Session

Structured capture of post-session learning. Each invocation produces one reflection entry file in `Research/Reflections/`, following a template grounded in Gibbs' reflective cycle (1988) and bounded by the retrospective literature (Derby & Larsen 2006).

**Theoretical basis**: Boud, Keogh & Walker (1985) demonstrate that structured reflection yields deeper learning than freeform journaling. Gibbs' six-stage cycle (1988), adapted here to four sections, provides the prompting structure. The 3-item cap on action items comes from retrospective practice (Derby & Larsen 2006) to prevent action-item decay.

**Relationship to other skills**:
- Entries are processed by **reflections-processing** skill
- Action items tagged `[research]` follow **research-process** skill
- Action items tagged `[experiment]` follow **experiment-process** skill
- Action items tagged `[blog]` follow **blog-process** skill

---

## When to Invoke

### [REFL-001] Invocation Triggers

**Statement**: `/reflect_session` SHOULD be invoked at the end of any session that produced non-trivial learning. It MAY be invoked mid-session when a significant insight occurs.

| Trigger | Priority | Example |
|---------|----------|---------|
| Design decision with non-obvious trade-offs | High | Chose class wrapper over struct for ~Copyable storage |
| Compiler/language constraint discovered | High | `#expect` macro cannot capture ~Copyable types |
| Pattern recognized across sessions | High | "Every wrapper doubles projection depth" |
| Plan deviated from reality | Medium | Typed throws planned but Mutex.withLock doesn't propagate them |
| Process friction identified | Medium | Reflection entries accumulate but never get processed |
| Session completed nominal work only | Low | Routine implementation matching existing patterns |

**Statement**: `/reflect_session` SHOULD NOT be invoked for sessions that produced only routine work matching existing skill patterns. Not every session warrants reflection.

**Rationale**: Reflection has value proportional to novelty. Routine sessions confirm existing skills (valuable, but captured implicitly by the skills being correct). Novel sessions produce new knowledge that needs explicit capture.

**Cross-references**: [REFL-002], [RES-001] (investigation triggers), [EXP-001] (experiment triggers)

---

## Entry Structure

### [REFL-002] Reflection Entry Template

**Statement**: Each reflection entry MUST be a single Markdown file in `swift-institute/Research/Reflections/` following the naming convention and template below.

**Filename convention**: `YYYY-MM-DD-{descriptive-slug}.md`

```
Research/Reflections/
├── _index.md
├── 2026-02-12-cache-primitives-waiter-coordination.md
├── 2026-02-12-typed-index-boundary.md
└── 2026-02-13-algebra-law-harnesses.md
```

Multiple reflections per day are permitted (different slugs). The slug MUST be descriptive of the session content, not a sequential number.

**Template**:

```markdown
---
date: YYYY-MM-DD
session_objective: What the session set out to accomplish
packages:
  - package-name-1
  - package-name-2
status: pending
---

# {Descriptive Title}

## What Happened

{Factual account: session objective, what was built or decided, key events,
deviations from plan. Be specific — name types, files, and decisions.}

## What Worked and What Didn't

{Evaluation: successes and failures. Where confidence was high or low.
What the AI got right or wrong. What the developer got right or wrong.
Blameless — focus on conditions, not attribution.}

## Patterns and Root Causes

{Analysis: why things went well or poorly. Connections to previous sessions.
Recurring themes. This is the highest-value section — push past description
into genuine analysis. Ask "what pattern does this instance belong to?"}

## Action Items

{Max 3 items. Each tagged with target type. These become the input to
/reflections_processing.}

- [ ] **[skill]** {skill-name}: {specific change to requirement}
- [ ] **[doc]** {document}: {specific improvement}
- [ ] **[research]** {question to investigate}
- [ ] **[experiment]** {hypothesis to test}
- [ ] **[blog]** {insight worth publishing}
- [ ] **[package]** {package-name}: {package-specific insight}
```

**Rationale**: The four-section structure adapts Gibbs' reflective cycle (Description, Evaluation, Analysis, Action Plan) for technical work. "Feelings" is reframed as confidence assessment within "What Worked and What Didn't" — where the developer felt uncertain about AI output is a leading indicator of skill gaps.

**Cross-references**: [REFL-003], [REFL-004], [REFL-005]

---

### [REFL-003] Action Item Tags

**Statement**: Each action item MUST be tagged with exactly one target type. The tag determines how `/reflections_processing` routes the item.

| Tag | Triage Outcome | Destination | Learning Loop |
|-----|----------------|-------------|---------------|
| `[skill]` | SkillUpdate | Named skill's SKILL.md | Double-loop |
| `[doc]` | DocImprovement | Named Documentation.docc/ file | Single-loop |
| `[research]` | ResearchTopic | New Research/ document per [RES-003] | Triple-loop |
| `[experiment]` | ExperimentTopic | New Experiments/ package per [EXP-002] | Validation |
| `[blog]` | BlogIdea | Blog/_index.md per [BLOG-002] | Communication |
| `[package]` | PackageInsight | Package's `_Package-Insights.md` | Package-specific |

**Statement**: Action items MUST name a specific target. `[skill] naming` not `[skill]`. `[doc] API-Requirements.md` not `[doc]`. `[package] swift-kernel` not `[package]`.

**Correct**:
```markdown
- [ ] **[skill]** testing: Add guidance for ~Copyable types in #expect macros [TEST-004]
- [ ] **[research]** Should Storage.Inline support Span for Copyable elements?
- [ ] **[package]** swift-witnesses: Document Witness.Cycle naming collision
```

**Incorrect**:
```markdown
- [ ] **[skill]** Update skills based on today's learning  // ❌ No specific target
- [ ] Fix the naming issue  // ❌ No tag
- [ ] **[skill]** **[doc]** naming: Update naming  // ❌ Multiple tags
```

**Rationale**: Specific targets enable deterministic routing. Vague items decay into inaction (Derby & Larsen 2006).

**Cross-references**: [REFL-002], [REFL-PROC-001]

---

### [REFL-004] Action Item Cap

**Statement**: Each reflection entry MUST contain at most 3 action items. If a session produces more than 3 actionable insights, prioritize by impact and defer the remainder to a future reflection or a note in "Patterns and Root Causes."

**Rationale**: The retrospective literature (Derby & Larsen 2006) demonstrates that unbounded action items lead to none being implemented. Three is the empirical sweet spot: enough to capture significant learning, few enough to be processed. This also prevents the EBL utility problem (Mitchell et al. 1986) — unbounded rule generation from every observation.

**Cross-references**: [REFL-003], [REFL-PROC-004]

---

### [REFL-005] Entry Metadata

**Statement**: The YAML frontmatter MUST include `date`, `session_objective`, and `status: pending`. The `packages` field SHOULD be included when the session touched specific packages.

| Field | Required | Purpose |
|-------|----------|---------|
| `date` | MUST | ISO 8601 date (YYYY-MM-DD) |
| `session_objective` | MUST | One-sentence session goal |
| `packages` | SHOULD | List of packages touched |
| `status` | MUST | `pending` on creation; `processed` after triage |
| `processed_date` | — | Added by `/reflections_processing` |
| `triage_outcomes` | — | Added by `/reflections_processing` |

**Rationale**: Metadata enables automated tracking. `status` is the interface between the two skills: `/reflect_session` writes `pending`; `/reflections_processing` transitions to `processed`.

**Cross-references**: [REFL-002], [REFL-PROC-002]

---

## Quality Guidance

### [REFL-006] Reflection Depth

**Statement**: Reflections SHOULD push past description (Bloom's Remember level) into analysis (Bloom's Analyze level) and synthesis (Bloom's Create level). The "Patterns and Root Causes" section is where depth happens.

| Bloom Level | Prompt | Quality |
|-------------|--------|---------|
| Remember | "What did I do?" | Low — captures events only |
| Understand | "Why was it important?" | Low-medium — adds context |
| Apply | "Where could I use this again?" | Medium — identifies transfer |
| Analyze | "What patterns do I see?" | High — identifies structure |
| Evaluate | "How well did this approach work?" | High — enables judgment |
| Create | "What should change?" | Highest — produces action items |

**Correct**:
```markdown
## Patterns and Root Causes

The `clamping:` init treated a symptom. The real disease was `truncate(to newCount: Int)`
— an Int parameter on a method that only makes sense with non-negative counts. The 12
call sites that needed clamping existed because the API accepted the wrong type. Making
the clamping conversion prettier didn't change the fact that it shouldn't exist at all.

This is a recurring pattern: when a conversion feels ceremonial, the type boundary is
in the wrong place. [IMPL-010] says "push Int to the edge." The typed parameter pushes
Int past the edge entirely.
```

**Incorrect**:
```markdown
## Patterns and Root Causes

We added a clamping initializer but then changed to typed parameters instead.
```

**Rationale**: Shallow reflections (Pappas 2010) generate documentation but not learning. Deep reflections generate the insights that improve skills.

**Cross-references**: [REFL-002], [REFL-004]

---

## Index Maintenance

### [REFL-007] Reflections Index

**Statement**: `Research/Reflections/_index.md` MUST be updated when a new entry is created. The index MUST contain a table with: Filename, Date, Title, Packages, Status.

**Rationale**: The index provides an overview of reflection state. Per [RES-003c], a directory with 2+ documents requires an index.

**Cross-references**: [RES-003c], [REFL-PROC-002]

---

## Cross-References

See also:
- **reflections-processing** skill for triage and integration [REFL-PROC-*]
- **research-process** skill for [RES-*] research workflows
- **experiment-process** skill for [EXP-*] experiment workflows
- **blog-process** skill for [BLOG-*] blog workflows
- **skill-creation** skill for [SKILL-CREATE-*] adding new skills
- `Research/session-reflection-meta-process.md` for Tier 3 theoretical grounding
