---
name: reflections-processing
description: |
  Triage accumulated session reflections into skill updates, documentation
  improvements, research topics, and package insights.
  Apply periodically when Research/Reflections/ contains pending entries.

layer: process

requires:
  - swift-institute
  - reflect-session
  - skill-creation
  - research-process

applies_to:
  - reflection
  - triage
  - knowledge-management

migrated_from:
  - Documentation.docc/_Reflections Consolidation.md
  - Research/session-reflection-meta-process.md
migration_date: 2026-02-12
---

# Reflections Processing

Triage accumulated session reflections into knowledge improvements. Each invocation reads pending entries from `Research/Reflections/`, processes action items through a three-loop triage function, and routes improvements to their canonical destinations.

**Theoretical basis**: The triage function implements Argyris & Schon's (1978) learning loops: single-loop (DocImprovement — explain existing norms better), double-loop (SkillUpdate — change the norms), and triple-loop (ResearchTopic — question whether the norm categories are adequate). Anti-drift mechanisms from FORTE (Richards & Mooney 1995, minimal revision), Stojanovic (2004, ontology consistency), and Derby & Larsen (2006, bounded action items) prevent knowledge degradation.

**Supersedes**: `Documentation.docc/_Reflections Consolidation.md` — the consolidation process is now codified in this skill. The consolidation document remains as historical reference.

**Relationship to other skills**:
- Reads entries created by **reflect-session** skill
- SkillUpdate outcomes modify Skills per **skill-creation** process
- ResearchTopic outcomes follow **research-process** workflow
- PackageInsight outcomes follow package routing from the consolidation process

---

## When to Invoke

### [REFL-PROC-001] Invocation Triggers

**Statement**: `/reflections_processing` SHOULD be invoked when `Research/Reflections/` contains 3 or more pending entries. It MAY be invoked with fewer entries if processing is timely. It MUST NOT be invoked during an active implementation session — processing is a distinct activity (Basili et al. 1994, Experience Factory separation).

| Condition | Action |
|-----------|--------|
| 3+ pending entries | Invoke processing |
| 1-2 pending entries, end of week | Invoke processing |
| 0 pending entries | Nothing to process |
| Mid-implementation session | Defer — do not mix production with learning |

**Rationale**: Basili's Experience Factory model (1994) demonstrates that learning must be organizationally separated from production to avoid being deprioritized. Batch processing (3+ entries) amortizes the context-switching cost.

**Cross-references**: [REFL-001], [REFL-005]

---

## Processing Loop

### [REFL-PROC-002] Processing Sequence

**Statement**: For each pending entry in `Research/Reflections/` (oldest first, by date), the processing sequence MUST be:

1. **Read** the entry fully
2. **For each action item**, apply the triage function ([REFL-PROC-003])
3. **Execute** each triage outcome ([REFL-PROC-005] through [REFL-PROC-010])
4. **Mark** the entry as processed (update YAML: `status: processed`, add `processed_date` and `triage_outcomes`)
5. **Update** `Research/Reflections/_index.md`
6. **Commit** with structured message ([REFL-PROC-012])
7. **Report** progress and continue to next entry

**Statement**: Entries MUST be processed oldest-first (chronological order). This preserves logical development of ideas — later reflections may build on earlier ones.

**Statement**: Entries MUST NOT be deleted after processing. They are permanent records. Only the `status` field changes.

**Rationale**: Wenger (1998) argues that original practice artifacts contain situated knowledge that compiled documents cannot fully represent. Preserving reflections alongside processed skills maintains the full knowledge chain.

**Cross-references**: [REFL-005], [REFL-PROC-003], [RES-008] (document lifecycle)

---

## Triage Function

### [REFL-PROC-003] Triage Outcomes

**Statement**: Each action item MUST receive exactly one triage outcome. The tag on the action item ([REFL-003]) determines the primary routing. The triage function validates and may override the tag if the item is miscategorized.

| Tag | Primary Outcome | Learning Loop | Destination |
|-----|----------------|---------------|-------------|
| `[skill]` | SkillUpdate | Double-loop | Named skill's SKILL.md |
| `[doc]` | DocImprovement | Single-loop | Named Documentation.docc/ file |
| `[research]` | ResearchTopic | Triple-loop | New Research/ document |
| `[experiment]` | ExperimentTopic | Validation | New Experiments/ package |
| `[blog]` | BlogIdea | Communication | Blog/_index.md |
| `[package]` | PackageInsight | Package-specific | Package's `Research/_Package-Insights.md` |

**Override rules**:
- If a `[doc]` item implies the normative rule itself is wrong (not just poorly explained), reclassify as `[skill]`
- If a `[skill]` item challenges a foundational assumption, reclassify as `[research]`
- If any item is already captured in existing skills/docs, classify as NoAction with rationale

**Statement**: Every NoAction outcome MUST include a rationale explaining why no action was taken. This prevents silent knowledge loss.

**Rationale**: Explicit triage with mandatory rationale ensures completeness (every item processed) and traceability (every decision documented).

**Cross-references**: [REFL-003], [REFL-PROC-005] through [REFL-PROC-010]

---

### [REFL-PROC-004] Triage Validation

**Statement**: Before executing a triage outcome, the processor MUST validate:

| Check | Condition | Action if failed |
|-------|-----------|-----------------|
| Staleness | Reflection's claims match current code state | Verify implementation before integrating — code may have evolved since the reflection was captured. Reclassify or NoAction with rationale. |
| Duplication | Insight already captured in target | NoAction with rationale |
| Consistency | Proposed change contradicts existing requirements | Escalate to ResearchTopic |
| Scope | Change affects requirements outside the named target | Expand scope or escalate |
| Specificity | Action item is too vague to execute | Return to reflection author for refinement |

**The Meta-Reflection Trap**: Reflections about the reflection process itself (this skill, the triage function, documentation structure) are valuable but MUST NOT be integrated into skills/docs if the insight is already captured in the skill system. Check process skills first.

**Rationale**: Stojanovic (2004) demonstrates that ontology changes without consistency checking introduce contradictions. Validation before execution prevents cascading inconsistencies.

**Cross-references**: [REFL-PROC-003], [REFL-PROC-011]

---

## Triage Execution

### [REFL-PROC-005] SkillUpdate Execution

**Statement**: When the triage outcome is SkillUpdate, the processor MUST:

1. **Read** the target skill's SKILL.md
2. **Verify current code state** — check the actual implementation to confirm the reflection's claims are still accurate. Reflections are point-in-time observations; subsequent sessions may have changed the code. If the implementation has evolved, adjust the proposed skill update to reflect current reality, or reclassify as NoAction if the item is now moot.
3. **Identify** the specific requirement to modify (or determine a new requirement is needed)
4. **Apply minimal revision** — the smallest edit that addresses the reflection (FORTE principle, Richards & Mooney 1995)
4. **Verify consistency** — check that the modification does not contradict requirements in dependent or depended-on skills
5. **Classify the change** as backward-compatible (safe) or breaking (requires discussion)
6. **If breaking**: flag for explicit discussion before applying. Do not apply unilaterally.
7. **If new requirement**: assign the next available ID in the skill's prefix range

**Correct**:
```markdown
Reflection: "#expect macro cannot capture ~Copyable types"
Target: testing skill
Action: Add [TEST-019] documenting the workaround (extract values before assertion)
Classification: Backward-compatible (new requirement, no existing requirements change)
```

**Incorrect**:
```markdown
Reflection: "Naming convention doesn't work for macros"
Target: naming skill
Action: Rewrite [API-NAME-001] to allow compound names for macros

// ❌ This changes a foundational requirement. Classify as breaking.
// Should escalate to ResearchTopic first.
```

**Rationale**: Minimal revision prevents knowledge drift. Consistency checking prevents cascading errors. Breaking change flagging preserves the "no drift without discussion" collaboration protocol.

**Cross-references**: [REFL-PROC-003], [SKILL-CREATE-005], [SKILL-CREATE-006]

---

### [REFL-PROC-006] DocImprovement Execution

**Statement**: When the triage outcome is DocImprovement, the processor MUST:

1. **Read** the target document
2. **Identify** the section to improve
3. **Transform voice** from reflective to normative (impersonal, timeless)
4. **Match** the document's structural patterns (Scope/Statement/Correct/Incorrect/Rationale)
5. **Expand** terse reflections into full treatment ([REFL-PROC-008])
6. **Verify** no duplication with existing content

**Voice transformation examples**:

| Reflective (before) | Normative (after) |
|---------------------|-------------------|
| "The native UUID work revealed a recurring pattern: C shims exist not just for technical bridging but as semantic boundaries." | "C shims serve as semantic boundaries, not just technical bridges. The shim declares the contract while the system library provides the implementation." |
| "Today I discovered that namespace collisions force fully-qualified paths." | "Namespace collisions with system modules require fully-qualified type paths." |
| "We found that typed throws preserve error information." | "Typed throws preserve error type information across API boundaries." |

**Rationale**: Documentation.docc/ files are non-normative but must still follow structural conventions and use impersonal voice for long-term readability.

**Cross-references**: [REFL-PROC-008], **documentation** skill, **readme** skill

---

### [REFL-PROC-007] ResearchTopic Execution

**Statement**: When the triage outcome is ResearchTopic, the processor MUST:

1. **Determine** research tier per [RES-020]:
   - Tier 1: Package-specific, low cost of error
   - Tier 2: Cross-package, reversible precedent
   - Tier 3: Ecosystem-wide, hard-to-undo commitment
2. **Create** a research document in `Research/` per [RES-003] (Context, Question, Analysis stub, placeholder Outcome)
3. **Set status** to IN_PROGRESS
4. **Update** `Research/_index.md`
5. **Cross-reference** the source reflection entry

**Statement**: ResearchTopic outcomes MUST NOT be skipped or downgraded. If the triage function identifies a foundational assumption being challenged, research is mandatory — this is the triple-loop learning escape valve.

**Rationale**: Argyris & Schon (1978) demonstrate that blocking double/triple-loop learning causes organizations to single-loop around increasingly inappropriate governing variables. The research pathway ensures the system can question its own foundations.

**Cross-references**: [RES-001], [RES-003], [RES-020]

---

### [REFL-PROC-008] Expansion Requirement

**Statement**: Reflections are terse observations. Integration into skills or documentation MUST provide full treatment.

| Reflection Form | Integrated Form |
|-----------------|-----------------|
| 3-sentence observation | Full requirement: Scope, Statement, examples |
| Single code snippet | Correct AND Incorrect examples with explanations |
| Implicit rationale | Explicit Rationale section |
| Mentioned related concepts | Formal Cross-references with requirement IDs |

**Correct**:
```markdown
Reflection: "Names should describe mechanism, not origin."

Becomes: Full requirement with Scope, Statement, three Correct examples,
three Incorrect examples, Rationale paragraph, and Cross-references to
[API-NAME-001] and [API-NAME-003].
```

**Incorrect**:
```markdown
Reflection: "Names should describe mechanism, not origin."

Becomes: "Names should describe mechanism, not origin."

// ❌ No expansion — just voice transformation without structural compliance.
```

**Rationale**: Expansion provides the detail that makes requirements actionable. A requirement without examples is ambiguous; without rationale, it invites violation.

**Cross-references**: [SKILL-CREATE-006], [REFL-PROC-006]

---

### [REFL-PROC-009] PackageInsight Execution

**Statement**: When the triage outcome is PackageInsight (tag `[package]`), the processor MUST route the insight to the named package's `Research/_Package-Insights.md`, following the package routing rules below.

**Package location resolution**:

| Package Pattern | Repository | Path |
|-----------------|------------|------|
| `swift-*-primitives` | swift-primitives | `/Users/coen/Developer/swift-primitives/{package}/` |
| `swift-rfc-*`, `swift-iso-*`, `swift-ietf-*` | swift-standards | `/Users/coen/Developer/swift-standards/{package}/` |
| Other `swift-*` | swift-foundations | `/Users/coen/Developer/swift-foundations/{package}/` |

**Research location**: `{package}/Research/_Package-Insights.md`

**If `_Package-Insights.md` does not exist**: Create it using the template:

```markdown
# {Package Name} Insights

<!--
---
title: {Package Name} Insights
version: 1.0.0
last_updated: {YYYY-MM-DD}
applies_to: [{package-name}]
normative: false
---
-->

Design decisions, implementation patterns, and lessons learned specific to this package.

## Overview

This document captures insights that emerged during development of {package-name}.
These are not API requirements — they are recorded decisions and patterns that inform
future work on this package.

**Document type**: Non-normative (recorded decisions, not requirements).

**Consolidation source**: Reflection entries tagged with `[package: {package-name}]`.
```

**Package insight format** (lighter than skill requirements — these are non-normative):

```markdown
---

## {Insight Title}

**Date**: {YYYY-MM-DD}

**Context**: {One sentence describing what prompted this insight}

{2-4 paragraphs describing the insight, pattern, or decision}

**Applies to**: {Specific types, APIs, or subsystems within the package}
```

**Rationale**: Package insights are non-normative design rationale — they belong in `Research/` alongside other design rationale documents, not in `.docc/`. The `.docc` catalogue is the expanded API reference layer per [DOC-027]; it should *link to* research documents per [DOC-028], not contain them. The `.docc` root page SHOULD include a link to `_Package-Insights.md` in its `## Topics` or `## Research` section.

**Cross-references**: [REFL-003], [RES-002a] (research triage by scope), [DOC-027], [DOC-028]

---

### [REFL-PROC-010] BlogIdea and ExperimentTopic Execution

**Statement**: When the triage outcome is BlogIdea, follow [BLOG-002] to add an entry to `Blog/_index.md`. When the outcome is ExperimentTopic, follow [EXP-002] to create a new experiment package.

**Rationale**: These outcomes delegate to existing process skills rather than defining new procedures.

**Cross-references**: [BLOG-002], [BLOG-003], [EXP-002], [EXP-003]

---

## Anti-Drift Mechanisms

### [REFL-PROC-011] Convergence Monitoring

**Statement**: The processor SHOULD track triage outcome distribution over time and monitor for these conditions:

| Condition | Signal | Action |
|-----------|--------|--------|
| SkillUpdate fraction not decreasing | Skills are not stabilizing | Review whether updates are minimal revisions or rewrites |
| ResearchTopic fraction is zero for 10+ entries | Triple-loop learning blocked | Review whether challenging reflections are being downgraded to NoAction |
| NoAction fraction > 50% over 10+ entries | Reflection quality low or skills already adequate | Review whether `/reflect_session` invocation criteria are too loose |
| Same skill modified 3+ times in sequence | Unstable requirement | Escalate to research — the requirement may need fundamental rethinking |

**Rationale**: Statistical process control (CMMI Level 4) detects drift before it becomes entrenched. The specific thresholds are heuristic starting points, not formal bounds.

**Cross-references**: [REFL-PROC-003], [RES-020]

---

### [REFL-PROC-013] Absorptive Capacity Audit

**Statement**: Periodically (every 20+ processed entries), the processor SHOULD review all NoAction outcomes to check for systematic blind spots. If a category of reflection is consistently rejected, determine whether: (a) existing skills are adequate for that category (healthy), or (b) the triage process has a blind spot (unhealthy).

**Rationale**: Cohen & Levinthal (1990) demonstrate that existing knowledge creates path-dependent absorptive capacity. The audit prevents lock-in where the skill system systematically filters out paradigm-challenging reflections.

**Cross-references**: [REFL-PROC-011], [REFL-PROC-003]

---

## Entry Lifecycle

### [REFL-PROC-012] Commit Standards

**Statement**: After processing each entry, commit all modified files with this message format:

```
Process reflection: {short title}

Triage outcomes:
- [skill] {skill-name}: {brief description}
- [doc] {document}: {brief description}
- [research] {title}: {brief description}
- [no-action] {rationale}
```

**Correct**:
```
Process reflection: Cache Primitives and Waiter Coordination

Triage outcomes:
- [skill] memory: Add guidance for ~Copyable class wrapper pattern
- [doc] Implementation Patterns.md: Add "Never Resume Under Lock" invariant
- [no-action] Witness.Cycle naming — already resolved in implementation
```

**Incorrect**:
```
Updated docs

// ❌ Missing: reflection title, specific outcomes, triage rationale.
```

**Rationale**: Structured commit messages enable tracking how institutional knowledge evolved from raw reflection to normative documentation.

**Cross-references**: [REFL-PROC-002], Commit Standards

---

### [REFL-PROC-014] Entry Status Update

**Statement**: After processing, update the entry's YAML frontmatter:

```yaml
---
date: 2026-02-12
session_objective: Implement cache primitives for witness resolution
packages:
  - swift-cache-primitives
  - swift-witnesses
status: processed
processed_date: 2026-02-15
triage_outcomes:
  - type: skill_update
    target: memory
    description: Add ~Copyable class wrapper pattern [MEM-COPY-007]
  - type: doc_improvement
    target: Implementation Patterns.md
    description: Add "Never Resume Under Lock" section
  - type: no_action
    description: Witness.Cycle naming already resolved
---
```

**Rationale**: Machine-parseable outcomes enable convergence monitoring ([REFL-PROC-011]) and absorptive capacity audits ([REFL-PROC-013]).

**Cross-references**: [REFL-005], [REFL-PROC-011]

---

## Interruption Handling

### [REFL-PROC-015] Graceful Interruption

**Statement**: If interrupted mid-processing:

1. Complete the current triage outcome (no partial skill/doc edits)
2. Commit any completed outcomes for the current entry
3. If the entry is partially processed, leave `status: pending` — incomplete entries restart from the beginning
4. Report which entry was in progress

The next invocation MUST resume from the oldest pending entry.

**Rationale**: Clean interruption handling ensures no document enters an inconsistent state. Restarting partially processed entries from the beginning is simpler than tracking per-item progress within an entry.

**Cross-references**: [REFL-PROC-002]

---

## Cross-References

See also:
- **reflect-session** skill for entry capture [REFL-*]
- **skill-creation** skill for [SKILL-CREATE-*] when SkillUpdate adds new requirements
- **research-process** skill for [RES-*] when ResearchTopic is created
- **experiment-process** skill for [EXP-*] when ExperimentTopic is created
- **blog-process** skill for [BLOG-*] when BlogIdea is created
- `Research/session-reflection-meta-process.md` for Tier 3 theoretical grounding
- `Documentation.docc/_Reflections Consolidation.md` (superseded, historical reference)
