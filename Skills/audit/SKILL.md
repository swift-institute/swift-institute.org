---
name: audit
description: |
  Systematic compliance audit of code against skill requirement IDs.
  Apply when checking code for convention violations, running compliance checks,
  or when the user invokes /audit. Produces standardized findings tables in
  Research/audit.md, updated in place.

layer: process

requires:
  - swift-institute

applies_to:
  - swift-primitives
  - swift-standards
  - swift-foundations
  - rule-law
  - swift-nl-wetgever
  - swift-us-nv-legislature

last_reviewed: 2026-03-26
---

# Audit

Systematic compliance audit of code against skill requirement IDs. Produces a
standardized findings table in `Research/audit.md`, updated in place.

## Invocation Quick Reference

```
/audit swift-kernel                            → general audit of swift-kernel
/audit regarding /implementation               → audit current package against implementation
/audit regarding /code-surface /implementation  → multi-skill audit (separate sections)
```

**`/audit {package}`** (no "regarding") runs a general audit against at minimum
**code-surface**, **implementation**, and **modularization**. Additional skills are
loaded when the code warrants it:

| Condition detected | Also load |
|--------------------|-----------|
| `~Copyable`, `consuming`, `borrowing`, `unsafe` | **memory-safety** |
| `#if os(...)`, platform conditionals | **platform** |
| Test files present and in scope | **testing** |
| L1 package | **primitives** (Foundation-free, tier rules) |

This produces one section per skill in the package's `Research/audit.md`. Each section
is independently replaceable on re-audit.

---

**Scope boundary**: Audits check code against skill requirement IDs. Investigative
work without requirement IDs to check against — operations completeness inventories,
ecosystem adoption surveys, dependency analysis — is Discovery research ([RES-012]),
not an audit.

---

### [AUDIT-001] Single Output File

**Statement**: All audit output for a given scope MUST be written to `Research/audit.md`. No other filenames are permitted for audit output.

**Correct**:
```
swift-buffer-primitives/Research/audit.md
swift-primitives/Research/audit.md
swift-institute/Research/audit.md
```

**Incorrect**:
```
swift-buffer-primitives/Research/implementation-audit.md      // ❌ Named file
swift-institute/Research/modularization-audit-v2.md           // ❌ Versioned file
swift-institute/Research/prompts/naming-audit.md              // ❌ Prompt file
```

**Rationale**: One predictable location per scope eliminates orphan files, naming chaos, and discoverability problems. 82 existing audit files across 7 naming patterns demonstrate the cost of uncontrolled output.

**Cross-references**: [AUDIT-002], [AUDIT-007], [AUDIT-008]

---

### [AUDIT-002] Location Triage

**Statement**: Audit location MUST follow [RES-002] triage:

| Scope | Location |
|-------|----------|
| Single package | `{package}/Research/audit.md` |
| Superrepo-wide | `{superrepo}/Research/audit.md` |
| Ecosystem-wide (Swift) | `swift-institute/Research/audit.md` |
| Legislature-wide (legal) | `swift-nl-wetgever/Research/audit.md` |
| Ecosystem-wide (legal) | `rule-law/Research/audit.md` |

**Rationale**: Mirrors the established research location convention. Predictable from scope alone.

**Cross-references**: [RES-002], [AUDIT-001], [AUDIT-014]

---

### [AUDIT-003] Section-Per-Skill Structure

**Statement**: Each target skill MUST get one section in `audit.md`, headed `## {Skill Name} — {YYYY-MM-DD}`. Each section MUST contain: Scope, Findings table, Summary.

**Template**:
```markdown
# Audit: {scope-name}

## {Skill Name} — {YYYY-MM-DD}

### Scope

- **Target**: {package(s) audited}
- **Skill**: {skill name} — {requirement IDs checked}
- **Files**: {N source files, N test files}

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | CRITICAL | [IMPL-010] | Foo.swift:42 | Description | OPEN |

### Summary

{N} findings: {X} critical, {Y} high, {Z} medium, {W} low.
{Systemic patterns, overall assessment.}
```

**Rationale**: Section-per-skill enables independent replacement on re-audit. The structured template ensures consistent, machine-parseable output.

**Cross-references**: [AUDIT-004], [AUDIT-005], [AUDIT-013]

---

### [AUDIT-004] Findings Table Format

**Statement**: Findings MUST use the standardized table: `| # | Severity | Rule | Location | Finding | Status |`.

**Severity levels**:

| Severity | Definition | Action |
|----------|-----------|--------|
| CRITICAL | Correctness or safety issue; code is wrong | Must fix before next release |
| HIGH | Convention violation with material impact on API consumers or maintainability | Should fix in current cycle |
| MEDIUM | Convention violation with minor impact | Fix when touching adjacent code |
| LOW | Style preference or minor inconsistency | Optional |

**Finding status values**:

| Status | Meaning |
|--------|---------|
| OPEN | Not yet addressed |
| RESOLVED {date} | Fixed |
| DEFERRED — {reason} | Known, intentionally postponed |
| FALSE_POSITIVE — {reason} | Not actually a violation |

**Rationale**: Standardized severity and status enable filtering, triage, and tracking across audit runs.

**Cross-references**: [AUDIT-003], [AUDIT-005]

---

### [AUDIT-005] Update In Place

**Statement**: Re-auditing the same skill on the same scope MUST replace the existing section entirely. DEFERRED findings carry forward with their original reason. All other findings are fresh. Git preserves history.

**Update semantics**:

1. Read existing `audit.md` and extract DEFERRED findings from the target skill's section
2. Run fresh audit producing new findings
3. Merge: DEFERRED findings that still apply are included with their original reason; DEFERRED findings where the violation no longer exists are dropped
4. Replace the section entirely with the merged result
5. Update the section date to today

**Rationale**: Update-in-place eliminates version proliferation (v1/v2/deep files). Git diff shows exactly what changed between runs.

**Cross-references**: [AUDIT-003], [AUDIT-007]

---

### [AUDIT-006] Skill Loading

**Statement**: `/audit regarding /{skill}` MUST load the target skill's requirement IDs and check code systematically against each. `/audit` without "regarding" MUST load default skills for the package's architecture layer.

**Methodology**:

1. **Load target skill(s)** — read the skill's requirement IDs
2. **Determine scope** — from conversation context or explicit parameter
3. **Read code** — walk all files in scope (see [AUDIT-012] for file scoping)
4. **Check each requirement** — evaluate code against each loaded requirement ID; report only violations found
5. **Verify findings against source** — every finding reported by an agent or parallel scan MUST be verified against the actual source code before inclusion. Raw agent accuracy for code-surface rules with exceptions ([PATTERN-024], [MEM-COPY-006], [IMPL-024]) is ~45%. Common false-positive categories: hallucinated types, misapplied rules that have exceptions, and over-application to standard naming conventions (e.g., `isEmpty` flagged as compound identifier)
6. **Classify findings** — assign severity per [AUDIT-004]
7. **Write to `audit.md`** — create or update the section per [AUDIT-003]

**General audit** (`/audit {package}` or `/audit` without "regarding"):

Baseline skills (always loaded): **code-surface**, **implementation**, **modularization**.

Additional skills loaded by context:

| Condition | Also load |
|-----------|-----------|
| `~Copyable`, `consuming`, `borrowing`, `unsafe` | **memory-safety** |
| `#if os(...)`, platform conditionals | **platform** |
| Test files present and in scope | **testing** |
| L1 package | **primitives** (Foundation-free, tier rules) |

**Rationale**: Explicit skill loading makes audits reproducible. Layer-based defaults provide sensible general audits without requiring the user to specify every skill.

**Cross-references**: [AUDIT-011], [AUDIT-012]

---

### [AUDIT-007] No Version Files

**Statement**: Version-suffixed filenames (`-v2`, `-deep`) are forbidden. No delta files. The single `audit.md` section is always current.

**Incorrect**:
```
swift-io-deep-audit.md        // ❌ "deep" variant
swift-io-deep-audit-v2.md     // ❌ Version suffix
modularization-audit-delta.md  // ❌ Delta file
```

**Rationale**: Version files proliferate without supersession markers and create discovery confusion. Update-in-place ([AUDIT-005]) with git history eliminates the need.

**Cross-references**: [AUDIT-001], [AUDIT-005]

---

### [AUDIT-008] No Prompt Files

**Statement**: Separate audit prompt documents are forbidden. The skill invocation is self-documenting.

**Incorrect**:
```
Research/prompts/naming-audit.md   // ❌ Separate prompt
```

**Rationale**: Prompt/result pairs create intermingling where neither file is clearly authoritative. The skill invocation (`/audit regarding /implementation`) is the prompt.

**Cross-references**: [AUDIT-001]

---

### [AUDIT-009] Index Entry

**Statement**: `audit.md` MUST be listed in `Research/_index.md` with status reflecting the current state.

**Format**:
```markdown
| audit.md | Systematic code audit against skill requirements | {YYYY-MM-DD} | {status} |
```

**Status values**:

| Status | Meaning |
|--------|---------|
| ACTIVE | Has OPEN findings |
| CLEAN | All findings resolved or no findings |
| STALE | Needs re-audit (flagged by meta-analysis) |

**Rationale**: Index integration per [RES-003c] ensures audit files are discoverable alongside other research documents.

**Cross-references**: [RES-003c], [AUDIT-010]

---

### [AUDIT-010] Staleness

**Statement**: An audit section is stale when its date is >60 days old AND source files in scope have been modified since the audit date. Meta-analysis ([META-*]) SHOULD flag stale sections.

**Detection**:
```bash
# Check if source files changed since audit date
git log --since="{audit-section-date}" --oneline -- Sources/
```

If output is non-empty and the section is >60 days old, the section is stale.

**Rationale**: Audits against code that has changed since are unreliable. The dual condition (time + changes) avoids flagging audits of stable packages.

**Cross-references**: [META-*], [AUDIT-009]

---

### [AUDIT-011] Scope Boundary

**Statement**: The audit skill MUST target a skill with requirement IDs. Work without requirement IDs to check against is Discovery research ([RES-012]), not an audit.

| Work type | Workflow |
|-----------|----------|
| Does code comply with [IMPL-*] rules? | `/audit regarding /implementation` |
| What operations does this data structure provide? | Discovery research ([RES-012]) |
| Who in the ecosystem uses this pattern? | Discovery research ([RES-012]) |
| Is this dependency being reused optimally? | Discovery research ([RES-012]) |

**Distinguishing criterion**: Audits produce a findings table with violations against requirement IDs. If the output is an inventory, a survey, or an analysis without requirement IDs, it is research.

**Rationale**: A clear boundary prevents the audit skill from becoming a catch-all and keeps investigative work in the research workflow where it belongs.

**Cross-references**: [RES-012], [RES-013], [AUDIT-006]

---

### [AUDIT-012] File Scoping

**Statement**: Non-testing skill audits MUST audit source files only. Testing skill audits MUST audit test files only. General `/audit` invocations audit source files for implementation skills and test files for the testing skill.

| Target skill | Files audited |
|-------------|---------------|
| Any non-testing skill (`/implementation`, `/code-surface`, `/memory-safety`, etc.) | Source files only (under `Sources/`) |
| `/testing` | Test files only (under `Tests/`) |
| `/audit` (general, no "regarding") | Source files for implementation/code-surface/memory-safety; test files for testing |

**Rationale**: Test code conventions differ from source code conventions. An implementation audit finding in a test helper is noise.

**Cross-references**: [AUDIT-006]

---

### [AUDIT-013] Multi-Skill Output

**Statement**: Multi-skill invocations (`/audit regarding /X /Y`) MUST produce separate sections per skill, each independently replaceable on re-audit.

**Example**: `/audit regarding /code-surface /implementation` produces:
```markdown
## Code Surface — 2026-03-24
### Scope
...
### Findings
...
### Summary
...

## Implementation — 2026-03-24
### Scope
...
### Findings
...
### Summary
...
```

**Rationale**: Per-skill sections preserve the update-in-place property. Re-auditing just `/implementation` later replaces only that section without touching the Code Surface section.

**Cross-references**: [AUDIT-003], [AUDIT-005]

---

### [AUDIT-014] Broad-Then-Narrow Routing

**Statement**: Superrepo-wide or ecosystem-wide audits MUST write synthesis to the appropriate scope-level `audit.md`. Per-package detail MUST be written to each package's `Research/audit.md` when a follow-up audit is scoped to that package, not upfront.

**Workflow**: broad audit for triage → narrow audit for detail → fix code → re-audit to confirm.

**Broad audit section includes**:
- Systemic patterns and cross-cutting recommendations
- Aggregate counts (N packages, M total findings)
- Per-package triage table:

```markdown
| Package | Findings | Worst Severity | Notes |
|---------|----------|---------------|-------|
| swift-buffer-primitives | 12 | CRITICAL | 3 safety issues |
| swift-array-primitives | 4 | MEDIUM | Naming only |
| swift-set-primitives | 0 | — | Clean |
```

**Narrow follow-up** (e.g., `/audit regarding /implementation` scoped to swift-buffer-primitives) then creates `swift-buffer-primitives/Research/audit.md` with the full findings table for that package.

**Rationale**: Creating hundreds of per-package files upfront is impractical. The triage table in the broad audit directs attention; the narrow audit provides actionable detail.

**Cross-references**: [AUDIT-001], [AUDIT-002]

---

### [AUDIT-015] Prior Findings Review

**Statement**: Before producing fresh findings, the audit MUST consolidate any old-style audit files in scope, then read the existing `audit.md` (including any legacy sections). Previously identified patterns, recurring issues, and DEFERRED items inform the fresh audit.

**Procedure**:

1. **Consolidate on contact** — check the target scope's `Research/` directory for old-style `*-audit*.md` files (any file containing "audit" in its name that is not `audit.md` itself). For each:
   a. Read the old file and extract substantive findings
   b. Append as a legacy subsection in `Research/audit.md` (creating the file if needed)
   c. Delete the old file
   d. Remove the old file's entry from `_index.md`
2. Read `Research/audit.md` at the target scope level
3. Note any DEFERRED findings for the target skill (carry forward per [AUDIT-005])
4. Note systemic patterns from legacy sections relevant to the target skill
5. Produce fresh findings informed by this context
6. After writing the fresh section, remove the corresponding legacy subsection (if present) — its content has been superseded by the fresh findings

**Legacy section format**:

```markdown
## Legacy — Consolidated {YYYY-MM-DD}

### From: {original-filename} ({original-date})
{extracted findings}

### From: {original-filename} ({original-date})
{extracted findings}
```

Legacy subsections are removed one-by-one as fresh audits supersede them. When all legacy subsections are gone, the `## Legacy` heading is removed.

**Version pairs**: When old-style files include version pairs (`-v1`, `-v2`, `-deep`), consolidate only the newest. Older versions are deleted without extraction.

**Rationale**: On-contact consolidation migrates old files into the new system incrementally, only for packages being actively audited. No wasted effort on packages that may never be re-audited. Reading prior findings prevents rediscovering known issues and ensures DEFERRED items are not silently dropped.

**Cross-references**: [AUDIT-005], [AUDIT-006]

---

### [AUDIT-016] Wrong-Scope File Discovery

**Statement**: When consolidating prior audit files ([AUDIT-015]), the search MUST also check parent and ecosystem-level scope directories for misplaced files. Old-style audit files are often stored at a higher scope than their content warrants (e.g., package-specific audits in `swift-institute/Research/` instead of `{package}/Research/`).

**Extended search procedure**:

| Step | Search Location | Pattern |
|------|-----------------|---------|
| 1 | Target scope's `Research/` | `*-audit*.md` (per [AUDIT-015]) |
| 2 | Parent scope's `Research/` | `*{package-name}*audit*.md` |
| 3 | `swift-institute/Research/` | `*{package-name}*audit*.md`, `*{package-name}*deep*.md` |

Files found at wrong scope levels are consolidated into the target scope's `Research/audit.md` and deleted from the wrong location, following the same extraction procedure as [AUDIT-015].

**Rationale**: Before the audit skill existed, audit files were placed at whichever scope the session happened to use. An automated staleness check per [AUDIT-010] that only examines the correct scope would miss these misplaced files entirely.

**Provenance**: Reflection `2026-03-24-swift-io-audit-consolidation.md`.

**Cross-references**: [AUDIT-015], [AUDIT-010], [AUDIT-002]

---

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| **research-process** | Audit is compliance; Discovery research ([RES-012]) is investigative. An audit may trigger research; research may trigger an audit. |
| **research-meta-analysis** | Meta-analysis flags stale audit sections ([AUDIT-010]) and checks index entries ([AUDIT-009]). |
| **implementation** | Common audit target. Load via `/audit regarding /implementation`. |
| **code-surface** | Common audit target. Load via `/audit regarding /code-surface`. |
| **memory-safety** | Audit target for ~Copyable/ownership code. |
| **modularization** | Audit target for package structure. |
| **testing** | Audit target for test code. Audits test files only ([AUDIT-012]). |

---

## Provenance

- Research: [generalized-audit-skill-design.md](../../Research/generalized-audit-skill-design.md) (v1.1.0, 2026-03-24)
