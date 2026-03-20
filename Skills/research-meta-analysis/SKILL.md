---
name: research-meta-analysis
description: |
  Meta-analysis of research and experiment corpus: staleness detection,
  findings verification, supersession protocol, consolidation, scope migration,
  experiment revalidation/spawning, index freshness, and pruning.
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
last_reviewed: 2026-03-20
---

# Research Meta-Analysis

Workflows for maintaining the health of the research and experiment corpus across
the Swift Institute ecosystem. Covers staleness detection, findings verification,
supersession, consolidation, scope migration, experiment revalidation/spawning,
index freshness, infrastructure compliance, and full corpus sweeps.

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

## Findings Verification

### [META-015] Findings Verification Sweep

**Statement**: During meta-analysis, RECOMMENDATION and DECISION documents MUST have
their key findings verified against current source. Each finding MUST be tagged with
a verification status.

| Tag | Meaning | Action |
|-----|---------|--------|
| `Verified: YYYY-MM-DD` | Finding confirmed against current code | No action |
| `Resolved: YYYY-MM-DD` | Finding no longer applies | Update finding with resolution note |
| `Stale (unverified)` | Not checked this sweep | Flag for next sweep or verify now |

**Verification process**:
1. For each finding in the document, identify the specific code it references
   (files, types, functions, patterns)
2. Check whether the referenced code still exhibits the described behavior
3. If resolved (e.g., by refactoring, migration, or deletion), update the finding
   inline with a resolution note and date
4. If the document's priority matrix includes the finding, update it there too
5. If all findings are resolved, consider marking the document SUPERSEDED or
   updating its status to reflect completion

**Scope**: This sweep covers all documents with actionable findings — primarily
audits and RECOMMENDATION documents. Pure analysis documents (design rationale,
trade-off discussions) are exempt unless they contain specific code-level claims.

**Rationale**: Metadata-based staleness detection ([META-001]) catches documents
that stop being updated. Findings verification catches documents that are current
by date but stale by content — their findings were resolved by code changes that
occurred independently of the research process. This was demonstrated when the
swift-pdf-stack-audit (2026-03-15) carried forward three resolved findings from a
prior audit (2026-03-12) because the witness migration (2026-03-13) occurred between
the two documents.

**Cross-references**: [RES-013a], [META-001], [META-002]

---

### [META-015a] Verification Prioritization

**Statement**: Not all findings require equal verification effort. Prioritize by
severity and age.

| Priority | Criteria |
|----------|----------|
| HIGH | Findings rated High/Critical in the original document |
| HIGH | Findings from documents that synthesize prior documents ([RES-013a]) |
| MEDIUM | Findings rated Medium, or any finding >30 days old |
| LOW | Findings rated Low, or documents recently authored with original analysis |

**Statement**: When time is limited, verify HIGH-priority findings first. LOW-priority
findings MAY be deferred to the next sweep with a `Stale (unverified)` tag.

**Cross-references**: [META-015], [META-019]

---

## Consolidation

### [META-016] Consolidation Protocol

**Statement**: When multiple research documents cover overlapping ground, they MUST
be consolidated into a single authoritative document. The remaining documents MUST
be marked SUPERSEDED with a reference to the consolidated document.

**Detection rules** — documents are candidates for consolidation when:
- Two or more documents share the same Question or investigate the same subsystem
- A synthesis/audit document repeats findings from a prior focused audit
- Multiple package-specific documents reveal the same ecosystem-wide pattern

**Consolidation process**:
1. **Identify** the candidate set (overlapping documents)
2. **Designate** one document as the consolidation target — prefer the most recent,
   broadest-scoped, or most complete document
3. **Merge** non-overlapping findings from other documents into the target. For each
   merged finding, add a provenance note: `(from {source-filename}, {date})`
4. **Verify** merged findings against current source per [META-015]
5. **Mark** source documents as SUPERSEDED per [META-003] or [META-004], with a
   reference to the consolidated document
6. **Update** all `_index.md` files affected

**Statement**: Consolidation MUST NOT discard findings. Every finding from every
source document must appear in the consolidated document (as active, resolved, or
explicitly out-of-scope with rationale).

**Rationale**: Without consolidation, the same finding lives in multiple documents
at different stages of resolution. Fixing it in one place doesn't update the others,
creating the false-positive problem that triggered this requirement. A single
authoritative document per topic eliminates this class of staleness.

**Cross-references**: [META-003], [META-004], [META-015]

---

## Scope Migration

### [META-017] Scope Migration Protocol

**Statement**: During meta-analysis, research and experiment documents MUST be
evaluated for scope correctness. Documents at the wrong scope level MUST be migrated.

| Current Scope | Signal for Promotion | New Scope |
|---------------|---------------------|-----------|
| Package-specific | Finding applies to 3+ packages | Primitives-wide or ecosystem-wide |
| Package-specific | Finding is about architecture, not one package | Ecosystem-wide |
| Primitives-wide | Finding applies to standards or foundations too | Ecosystem-wide |

| Current Scope | Signal for Demotion | New Scope |
|---------------|---------------------|-----------|
| Ecosystem-wide | Finding only affects one package | Package-specific |
| Primitives-wide | Finding only affects one package | Package-specific |

**Migration process**:
1. **Move** the document to the correct `Research/` directory per [RES-002a]:
   - Package-specific: `{package-repo}/{package}/Research/`
   - Primitives-wide: `swift-primitives/Documentation.docc/Research/`
   - Ecosystem-wide: `swift-institute/Research/`
2. **Update** the document's metadata to reflect the new scope
3. **Update** `_index.md` in both the source and destination directories
4. **Update** any cross-references in other documents that pointed to the old path
5. **Git-move** (not copy-delete) to preserve history

**Statement**: Scope migration also applies to experiments. An experiment that
validates a cross-package pattern belongs in `swift-institute/Experiments/`, not
in a single package.

**Rationale**: Documents at the wrong scope are either invisible to the audience
that needs them (too narrow) or create noise for an audience that doesn't (too broad).
Correct scoping per [RES-002a] ensures research reaches the right consumers.

**Cross-references**: [RES-002a], [RES-004b], [META-016]

---

## Research–Experiment Linkage

### [META-018] Research→Experiment Spawning

**Statement**: During meta-analysis, RECOMMENDATION documents MUST be checked for
findings that require empirical validation but have no corresponding experiment.

**Detection rule**: A finding needs an experiment when:
- It recommends a code change but the recommendation's feasibility is unproven
- It identifies a compiler/runtime behavior that should be verified
- It proposes an architectural pattern that has not been tested in isolation

**Spawning process**:
1. **Identify** the unvalidated recommendation
2. **Check** whether an experiment already exists (search `Experiments/` directories
   and `_index.md` files across all repos)
3. If no experiment exists, **create** one per [EXP-002] with a cross-reference
   back to the research document
4. **Update** the research document's finding with a link to the spawned experiment
5. **Update** relevant `_index.md` files

**Statement**: The reverse link also applies. When an experiment's results contradict
or resolve a research finding, the research document MUST be updated. Experiments
are not fire-and-forget — their results flow back into the research corpus.

**Rationale**: Research without validation produces recommendations that may be
infeasible. Experiments without research context produce results that may be
misinterpreted. The bidirectional link ensures the corpus is self-correcting.

**Cross-references**: [EXP-002], [RES-011], [META-015]

---

## Full Corpus Sweep

### [META-019] Full Corpus Sweep Sequence

**Statement**: A full corpus sweep is a single activatable process that runs all
META-* checks in a defined order. It is the primary entry point for corpus
maintenance.

**Sequence**:

| Phase | Check | IDs | Scope |
|-------|-------|-----|-------|
| 1. Staleness | Triage stale IN_PROGRESS documents | [META-001], [META-002] | All repos |
| 2. Verification | Verify findings in RECOMMENDATION/DECISION docs | [META-015], [META-015a] | All repos |
| 3. Supersession | Identify and mark superseded documents | [META-003], [META-004] | All repos |
| 4. Consolidation | Merge overlapping documents | [META-016] | All repos |
| 5. Scope migration | Promote/demote misscoped documents | [META-017] | All repos |
| 6. Experiment linkage | Spawn experiments, back-propagate results | [META-018] | All repos |
| 7. Experiment revalidation | Re-run experiments if toolchain changed | [META-006], [META-007] | All repos |
| 8. Index freshness | Audit all `_index.md` files | [META-008], [META-009] | All repos |
| 9. Infrastructure | References, Reflections, Blog pipeline | [META-010]–[META-012] | swift-institute |
| 10. Report | Produce corpus health report | [META-013] | Conversation output |

**Statement**: Phases 1–6 are the core loop. Phases 7–9 are supplementary checks.
When time is limited, the sweep MAY stop after phase 6 and defer phases 7–9 to the
next sweep. Phase 10 (report) MUST always be produced, covering whichever phases
were executed.

**Statement**: The sweep operates across all four repositories: swift-institute,
swift-primitives, swift-standards, swift-foundations. Each repository's `Research/`
and `Experiments/` directories are included.

**Parallelization**: Phases 1 and 2 may run concurrently (staleness is metadata-only,
verification is content-based — they examine different things). Phases 3–6 are
sequential because each may change document status that affects the next phase.
Phase 7 is independent of 3–6 and may run in parallel with them. Phases 8–9 run
last because prior phases may have created or moved documents.

**Rationale**: Without a defined sequence, individual META-* checks are invoked
ad hoc and inconsistently. A single sweep ensures completeness and prevents the
"I checked staleness but forgot verification" failure mode. The defined order
prevents cascading issues (e.g., consolidating before verifying would merge
stale findings into the consolidated document).

**Cross-references**: [META-013], [META-014]

---

## Corpus Health Report

### [META-013] Report Structure

**Statement**: A meta-analysis session MUST produce a summary report covering:

| Section | Content | Phase |
|---------|---------|-------|
| Corpus Size | Total counts by type (research, experiments, reflections) and status | — |
| Staleness | IN_PROGRESS documents exceeding threshold, with triage decisions | 1 |
| Verification | Findings checked against current source: verified, resolved, or stale | 2 |
| Supersession | Newly identified superseded documents, with actions taken | 3 |
| Consolidation | Overlapping documents merged, with provenance trail | 4 |
| Scope Migration | Documents promoted or demoted, with rationale | 5 |
| Experiment Linkage | Experiments spawned from research, results back-propagated | 6 |
| Revalidation | Experiments due for toolchain revalidation | 7 |
| Index Freshness | Missing or stale `_index.md` files | 8 |
| Infrastructure | Gaps in References/, Reflections/, Blog/ | 9 |
| Future Work | Research or experiments identified as needed but not yet created | — |

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

## Skill Health

### [META-020] Skill Health Check

**Statement**: During corpus sweeps, skills MUST be checked for:

| Check | Condition | Action |
|-------|-----------|--------|
| Staleness | `last_reviewed` date exceeds review cadence ([SKILL-LIFE-012]: 90 days for implementation, 180 days for process) | Flag for review |
| Instability | 3+ updates within 30 days | Flag for review — the skill may need restructuring |
| Superseded retention | `superseded_by` set but skill directory still exists after 90 days | Delete directory and symlink |
| Cross-reference rot | Referenced skills that no longer exist or have been superseded | Update references to point to absorbing skill |
| PIC drift | Post-Implementation Checklist items that don't match current requirements | Update PIC to reflect current rules |

**Integration with [META-019] full corpus sweep**: Skill health checks run as phase 10 (after index freshness, before final report).

**Cross-references**: [SKILL-LIFE-010], [SKILL-LIFE-011], [SKILL-LIFE-012], [SKILL-LIFE-020]

---

## Cross-References

See also:
- **research-process** skill for [RES-*] document lifecycle
- **experiment-process** skill for [EXP-*] experiment lifecycle
- **reflect-session** skill for [REFL-*] reflection capture
- **reflections-processing** skill for [REFL-PROC-*] triage process
- **skill-creation** skill for skill creation and integration
