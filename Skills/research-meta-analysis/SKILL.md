---
name: research-meta-analysis
description: |
  Meta-analysis of research and experiment corpus: staleness detection,
  supersession protocol, experiment revalidation, index freshness, and pruning.
  Apply periodically (monthly or at milestones) to maintain corpus health.

layer: process

requires:
  - research-process
  - experiment-process
  - reflect-session

applies_to:
  - swift-institute
  - swift-primitives
  - swift-standards
  - swift-foundations
---

# Research Meta-Analysis

Workflows for maintaining the health of the research and experiment corpus across
the Swift Institute ecosystem. Covers staleness detection, supersession, experiment
revalidation, index freshness, infrastructure compliance, and pruning.

**Trigger**: Apply periodically (monthly or at ecosystem milestones), or when the
corpus exceeds a size where manual tracking becomes unreliable.

---

## Staleness Detection

### [META-001] Staleness Threshold

**Statement**: An IN_PROGRESS research document MUST be triaged if it has not been
updated for 21 days (3 weeks). The triage outcome is one of: resolve to DECISION,
resolve to RECOMMENDATION, mark DEFERRED with reason, or confirm still active and
update `last_updated`.

| Age Since Last Update | Action |
|-----------------------|--------|
| < 21 days | No action required |
| 21–42 days | SHOULD triage |
| > 42 days | MUST triage |

**Rationale**: IN_PROGRESS documents that stall silently create a false impression
of ongoing work. Explicit DEFERRED status with a reason preserves the document's
value while signaling it is not being worked on.

**Cross-references**: [RES-003a], [RES-008]

---

### [META-002] Triage Protocol

**Statement**: When triaging a stale IN_PROGRESS document, the reviewer MUST read the
Outcome section and determine:

| Condition | New Status | Action |
|-----------|-----------|--------|
| Analysis complete, recommendation clear | RECOMMENDATION | Update status, write outcome |
| Analysis complete, decision made and adopted | DECISION | Update status, reference implementation |
| Analysis complete, blocked on external factor | DEFERRED | Update status, document blocker and resumption trigger |
| Analysis incomplete, low priority | DEFERRED | Update status, document what remains and why deferred |
| Analysis incomplete, high priority | IN_PROGRESS | Update `last_updated`, add next-steps section |

When marking DEFERRED, the Outcome section MUST include:
- What the blocker is
- What would resolve the blocker (resumption trigger)
- Date of deferral

**Rationale**: Deferred is not abandoned. A clear resumption trigger ensures the
document will be picked up when conditions change.

**Cross-references**: [RES-006]

---

## Supersession Protocol

### [META-003] Skill Absorption Supersession

**Statement**: When a research document's recommendations are fully absorbed into a
skill, the document MUST be marked SUPERSEDED with a reference to the absorbing skill.

**Detection rule**: If a skill exists with requirement IDs that cover the same
ground as the research document's recommendations, the research is superseded.

**Update template**:
```markdown
**Status**: SUPERSEDED (YYYY-MM-DD)
**Superseded by**: **{skill-name}** skill [{ID-PREFIX}-*]
This research designed the {skill/convention} that is now canonical.
It remains as historical rationale.
```

**Metadata update**: Increment version, set `last_updated`, set `status: SUPERSEDED`.

**Rationale**: Research that designed a skill has served its purpose. Keeping it
IN_PROGRESS or RECOMMENDATION when the skill is live creates confusion about the
source of truth. The skill is canonical ([RES-006a] Documentation Promotion).

**Cross-references**: [RES-006a], [RES-008]

---

### [META-004] Research Chain Supersession

**Statement**: When a newer research document explicitly replaces an older one on
the same topic, the older document MUST be marked SUPERSEDED with a reference to
the replacement.

**Detection rule**: Look for documents with overlapping Questions or Outcomes where
the newer document references the older one and provides a more complete analysis.

**Cross-references**: [RES-008]

---

### [META-005] Archival

**Statement**: SUPERSEDED documents MAY be moved to `Research/_archived/` if the
directory has more than 20 SUPERSEDED documents. Archived documents MUST retain
their original filenames and metadata.

**Rules**:
- `_archived/` is a flat directory (no subdirectories)
- Moving to `_archived/` is optional — SUPERSEDED status alone is sufficient
- Git history preserves the full document lifecycle regardless of location
- Do NOT archive DEFERRED documents — they may be resumed

**Rationale**: Archival reduces visual noise in the Research directory while
preserving documents for historical reference via git.

**Cross-references**: [RES-008], [EXP-008]

---

## Experiment Revalidation

### [META-006] Toolchain-Triggered Revalidation

**Statement**: When the ecosystem upgrades to a new Swift toolchain version,
experiments in the following categories SHOULD be revalidated:

| Category | Priority | Rationale |
|----------|----------|-----------|
| BUG REPRODUCED / BUG FILED | HIGH | Bug may be fixed in new toolchain |
| REFUTED (compiler limitation) | HIGH | Limitation may be lifted |
| CONFIRMED (workaround) | MEDIUM | Workaround may no longer be needed |
| CONFIRMED (feature) | LOW | Feature unlikely to regress |

**Revalidation process**:
1. `cd` into the experiment directory
2. `swift package clean && swift build 2>&1`
3. If behavior changed, update the `main.swift` header with new toolchain and result
4. If a bug is fixed, mark original result as historical and add new result

**Cross-references**: [EXP-005], [EXP-006], [EXP-007]

---

### [META-007] Experiment Supersession

**Statement**: An experiment is SUPERSEDED when:
- A newer experiment covers the same behavior with a more minimal reproduction
- The tested behavior is now part of a unit test in the production codebase
- A bug filed against the experiment has been resolved and verified

SUPERSEDED experiments MUST have a header note added:
```swift
// SUPERSEDED: [reason]. See [replacement path or bug resolution].
```

Experiments MAY be moved to `Experiments/_archived/` using the same rules as
[META-005].

**Cross-references**: [EXP-008]

---

## Index Freshness

### [META-008] Index Audit

**Statement**: During meta-analysis, every `_index.md` file in `Research/` and
`Experiments/` directories MUST be checked for completeness.

**Checks**:
1. Every document/directory in the parent has a corresponding row in `_index.md`
2. Status values in `_index.md` match the actual document metadata
3. Dates in `_index.md` match the actual `last_updated` values
4. No rows reference documents that no longer exist

**Cross-references**: [RES-003c], [EXP-003e]

---

### [META-009] Missing Index Detection

**Statement**: If a `Research/` or `Experiments/` directory contains 2+ items but
no `_index.md`, a missing index MUST be flagged during meta-analysis.

**Action**: Create the `_index.md` per [RES-003c] or [EXP-003e] conventions.

**Cross-references**: [RES-003c], [EXP-003e]

---

## Infrastructure Compliance

### [META-010] References Directory

**Statement**: Meta-analysis MUST check that `swift-institute/References/` contains
the discipline-partitioned `.bib` files required by [RES-026].

**Required files** (per [RES-026]):
- `swift-evolution.bib`
- `programming-languages.bib`
- `type-theory.bib`
- `category-theory.bib`
- `api-usability.bib`
- `methodology.bib`

If missing, flag as infrastructure gap with priority based on how many Tier 2+
research documents exist without traceable references.

**Cross-references**: [RES-026]

---

### [META-011] Reflections Triage Status

**Statement**: Meta-analysis MUST check `Research/Reflections/` for pending (unprocessed)
entries and flag them for triage per the **reflections-processing** skill.

**Cross-references**: [REFL-PROC-*]

---

### [META-012] Blog Pipeline Status

**Statement**: Meta-analysis SHOULD check `Blog/_index.md` for ideas marked
"Ready for Drafting" that have not been drafted. Flag as pipeline stall if any
idea has been ready for >30 days.

**Cross-references**: [BLOG-*]

---

## Corpus Health Report

### [META-013] Report Structure

**Statement**: A meta-analysis session MUST produce a summary report covering:

| Section | Content |
|---------|---------|
| Corpus Size | Total counts by type (research, experiments, reflections) and status |
| Staleness | IN_PROGRESS documents exceeding threshold, with triage decisions |
| Supersession | Newly identified superseded documents, with actions taken |
| Revalidation | Experiments due for toolchain revalidation |
| Index Freshness | Missing or stale `_index.md` files |
| Infrastructure | Gaps in References/, Reflections/, Blog/ |
| Future Work | Research or experiments identified as needed but not yet created |

**Output location**: The report is ephemeral (conversation output). Durable actions
(status changes, archival, index updates) are committed to git.

**Rationale**: The report provides a snapshot; the git commits provide the durable
record.

---

### [META-014] Frequency

**Statement**: Meta-analysis SHOULD be performed:
- Monthly, as part of ecosystem maintenance
- Before major version releases (v1.0, v2.0)
- After toolchain upgrades
- When the corpus exceeds ~500 documents (current threshold)

**Rationale**: More frequent analysis at scale prevents accumulation of stale documents
that become harder to triage over time.

---

## Cross-References

See also:
- **research-process** skill for [RES-*] document lifecycle
- **experiment-process** skill for [EXP-*] experiment lifecycle
- **reflect-session** skill for [REFL-*] reflection capture
- **reflections-processing** skill for [REFL-PROC-*] triage process
- **skill-creation** skill for skill creation and integration
