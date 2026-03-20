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

migrated_from:
  - Research/Research.md
  - Research/Research Investigation.md
  - Research/Research Discovery.md
migration_date: 2026-01-28
last_reviewed: 2026-03-20
---

# Research Process

Workflows for conducting design research. Three source documents define the research system:

| Document | Purpose | IDs |
|----------|---------|-----|
| Research.md | Shared infrastructure | RES-002 – RES-010, RES-020 – RES-026 |
| Research Investigation.md | Reactive workflow | RES-001, RES-001a, RES-004, RES-004a, RES-011 |
| Research Discovery.md | Proactive workflow | RES-012 – RES-017 |

**Research vs Experiment**: Research analyzes design decisions (Markdown). Experiments verify compiler/runtime behavior (Swift packages). Use experiments for "does X compile?"; use research for "should we use X or Y?"

---

## Investigation Workflow (Reactive)

**Entry point**: Design question arose during implementation.

### [RES-001] Investigation Triggers

**Statement**: An investigation research document MUST be created when a design decision cannot be made without systematic analysis of alternatives. SHOULD NOT be created when existing conventions clearly answer the question.

| Category | Description | Action |
|----------|-------------|--------|
| Naming ambiguity | Multiple valid names | Create research |
| Pattern selection | Multiple patterns could apply | Create research |
| Trade-off resolution | Competing concerns | Create research |
| Architecture choice | Structural decision | Create research |
| Convention clarity | Existing convention answers it | Read docs first |
| Implementation detail | Does not affect API | No research needed |

**Cross-references**: [RES-001a], [RES-004], [API-DESIGN-004]

---

### [RES-001a] Research Granularity

**Statement**: Research documents SHOULD NOT be created when: (1) conventions clearly answer the question, (2) no meaningful alternatives were considered, or (3) the rationale is implementation-specific rather than design-level.

If the decision affects HOW code is written → code comments. If it affects WHAT is built or WHY → research.

**Cross-references**: [RES-001], [RES-004a]

---

### [RES-004] Investigation Methodology

**Statement**: Design questions MUST be investigated by enumerating options, identifying evaluation criteria, and systematically comparing alternatives.

| Step | Action | Output |
|------|--------|--------|
| 1 | State the question precisely | Clear question |
| 2 | Enumerate all viable options | Option list |
| 3 | Identify evaluation criteria | Criteria list |
| 4 | Analyze each option against criteria | Comparison table |
| 5 | Document constraints | Constraint list |
| 6 | Make recommendation or decision | Outcome |

**Cross-references**: [RES-005], [RES-006]

---

### [RES-004a] Convention Consultation

**Statement**: Before creating a research document, existing conventions MUST be consulted. Research SHOULD only be created when conventions do not clearly answer the question.

Consultation process: (1) Identify decision category, (2) consult convention doc (Naming.md, Design.md, etc.), (3) if convention answers → follow it, no research; if ambiguous → create research.

**Cross-references**: [RES-001], [API-NAME-001]

---

### [RES-011] Research-First Design

**Statement**: When implementation is blocked by a design question, a research document SHOULD be created to resolve the question BEFORE attempting multiple implementation approaches.

Sequence: Identify blocking question → Create research → Enumerate options → Analyze trade-offs → Make decision → Implement chosen approach.

Research-first prevents implementation thrashing, documents rationale, and creates institutional knowledge.

**Cross-references**: [RES-001], [RES-004]

---

## Shared Infrastructure

### [RES-002] Document Location Convention

**Statement**: Research documents MUST be created in a `Research/` directory with a descriptive, kebab-case filename.

| Scope | Location |
|-------|----------|
| Package-specific | `{package-repo}/Research/` |
| Primitives-wide | `swift-primitives/.../docc/Research/` |
| Ecosystem-wide (Swift) | `swift-institute/.../docc/Research/` |
| Legislature-wide (legal) | `swift-nl-wetgever/Research/` |
| Ecosystem-wide (legal) | `rule-law/Research/` |

**Cross-references**: [RES-002a], [RES-008]

---

### [RES-002a] Research Triage

**Statement**: Before creating a research document, determine scope. Package-specific decisions go in the package repo. Primitives-wide patterns go in swift-primitives. Ecosystem-wide analysis goes in swift-institute.

| Criterion | Package-Specific | Primitives-Wide | Ecosystem-Wide (Swift) | Legislature-Wide | Ecosystem-Wide (Legal) |
|-----------|------------------|-----------------|------------------------|-----------------|----------------------|
| One package's types | ✓ | | | | |
| Multiple primitives packages | | ✓ | | | |
| Swift packages across layers | | | ✓ | | |
| General Swift design philosophy | | | ✓ | | |
| One statute's encoding | ✓ | | | | |
| Cross-statute legal patterns | | | | ✓ | |
| Cross-layer legal architecture | | | | | ✓ |
| Legal skill/process design | | | | | ✓ |

**Cross-references**: [RES-002], [RES-006a]

---

### [RES-003] Document Structure

**Statement**: Research documents MUST contain: Title, Metadata, Context, Question, Analysis, Outcome. SHOULD include References.

Template:

```markdown
# {Topic Title}

<!--
---
version: 1.0.0
last_updated: YYYY-MM-DD
status: DECISION | RECOMMENDATION | DEFERRED | IN_PROGRESS
---
-->

## Context
{Why this research is needed}

## Question
{The specific design question}

## Analysis
### Option A: {Name}
{Description, pros, cons}

### Comparison
| Criterion | Option A | Option B |
|-----------|----------|----------|

## Outcome
**Status**: {DECISION | RECOMMENDATION | DEFERRED}
{Conclusion and rationale}

## References
```

**Cross-references**: [RES-003a], [RES-003b]

---

### [RES-003a] Metadata Requirements

**Statement**: Research documents MUST include metadata: version, last_updated date, and status.

| Status | Meaning |
|--------|---------|
| IN_PROGRESS | Analysis ongoing |
| DECISION | Complete, decision made and implemented |
| RECOMMENDATION | Complete, not yet implemented |
| DEFERRED | Complete, awaiting future information |
| SUPERSEDED | Replaced by newer research |

**Cross-references**: [RES-003], [RES-008]

---

### [RES-003b] Naming Alignment

**Statement**: Filename (kebab-case) and title (natural language) MUST be aligned. Example: `heap-storage-variants.md` → `# Heap Storage Variants`.

**Cross-references**: [RES-002], [RES-003]

---

### [RES-003c] Research Index

**Statement**: If `Research/` contains 2+ documents, `Research/_index.md` MUST exist. Must contain a table with: Document, Topic, Date, Status. `_index.md` is the only allowed non-research file.

**Cross-references**: [RES-002], [RES-008]

---

### [RES-004b] Scope Escalation

**Statement**: If analysis reveals implications beyond the original scope: cross-package → recommend Discovery; single-package → MAY spawn targeted Investigation. Must record escalation with cross-reference.

**Cross-references**: [RES-002a], [RES-012]

---

### [RES-005] Analysis Methodology

**Statement**: Research analysis MUST be systematic: enumerate options, identify criteria, analyze trade-offs.

| Component | Required |
|-----------|----------|
| Options enumeration | MUST |
| Criteria identification | MUST |
| Trade-off analysis | MUST |
| Constraints documentation | SHOULD |
| Prior art review | SHOULD |

**Cross-references**: [RES-006]

---

### [RES-006] Outcome Documentation

**Statement**: Outcomes MUST include clear status, rationale, and implementation notes.

| Outcome | Action |
|---------|--------|
| DECISION | Document choice, rationale, implementation path |
| RECOMMENDATION | Document recommendation with caveats |
| DEFERRED | Document why deferred, what would resolve it |
| IN_PROGRESS | Document current state, next steps |

**Cross-references**: [RES-006a], [RES-003]

---

### [RES-006a] Documentation Promotion

**Statement**: When research establishes conventions or patterns, findings SHOULD be promoted to authoritative documentation.

| Criterion | Action |
|----------|--------|
| New convention | Promote to Naming.md or similar |
| Documents pattern | Promote to Implementation Patterns |
| Reveals constraint | Promote to requirements doc |
| One-time decision | Keep in Research only |

The outcome status remains unchanged. Promotion is elevation, not invalidation.

**Cross-references**: [RES-006], [API-NAME-001]

---

### [RES-007] Context Documentation

**Statement**: Research documents MUST record context: trigger (what prompted it), constraints, timeline, stakeholders.

**Cross-references**: [RES-003]

---

### [RES-008] Research Document Lifecycle

**Statement**: Research documents are persistent and git-tracked. Lifecycle: Active → Concluded → Referenced → Updated → Superseded.

When updating concluded research: increment version, update date, add changelog, preserve original analysis.

**Cross-references**: [RES-002], [RES-003a]

---

### [RES-009] Multi-Option Analysis

**Statement**: When analyzing multiple related options, all viable alternatives MUST be documented with consistent structure enabling comparison.

Each option needs: Description, Advantages, Disadvantages, Constraints. Plus a comparison table.

**Cross-references**: [RES-005], [RES-006]

---

### [RES-010] Common Research Patterns

**Statement**: Research documents SHOULD follow established templates for common analysis types.

**Cross-references**: [RES-003], [RES-005]

---

### [RES-010a] Naming Analysis Template

For naming decisions: Context → Question ("What should X be named?") → Options with rationale, precedent, conflicts → Comparison against spec terminology, existing APIs, Foundation conflicts → Outcome.

---

### [RES-010b] Architecture Analysis Template

For architecture decisions: Context → Question ("How should X be architected?") → Options with structure, complexity, performance, maintainability → Comparison → Outcome.

---

### [RES-010c] Trade-off Analysis Template

For trade-offs: Context → Question ("How to balance A vs B?") → Concerns with importance and impact → Trade-off matrix (prioritize A / prioritize B / balance) → Outcome.

---

## Research Rigor (Tiered)

### [RES-020] Research Tiers

**Statement**: Research MUST be classified into tiers based on precedent risk, not scope alone.

| Criterion | Tier 1: Quick | Tier 2: Standard | Tier 3: Deep |
|-----------|---------------|------------------|--------------|
| Scope | Package-specific | Cross-package | Ecosystem-wide |
| Precedent-setting | No | No or reversible | Yes, hard to undo |
| Semantic commitment | None | Informal | Normative/foundational |
| Cost of error | Low | Medium | Very high |
| Expected lifetime | Single release | Several releases | Timeless infrastructure |
| Formalization | Not required | Optional | Mandatory |

**Tier 3 threshold**: Establishes long-lived semantic contract that future APIs depend on. Exceptional — very few per year.

**Cross-references**: [RES-002a], [RES-004b]

---

### [RES-021] Prior Art Survey

**Statement**: Tier 2+ MUST include Prior Art Survey: Swift Evolution proposals/forums, related languages (Rust RFCs, Haskell GHC, OCaml), academic literature (arXiv, ACM DL, POPL/ICFP/OOPSLA).

**Cross-references**: [RES-005], [RES-022]

---

### [RES-022] Theoretical Grounding

**Statement**: Tier 2+ SHOULD include theoretical grounding (type theory, category theory, operational/denotational semantics) when it improves precision.

**Cross-references**: [RES-023], [RES-024]

---

### [RES-023] Systematic Literature Review

**Statement**: Tier 3 MUST include SLR per Kitchenham methodology: research questions, explicit search strategy, inclusion/exclusion criteria, screening, data extraction, synthesis.

**Cross-references**: [RES-021], [RES-024]

---

### [RES-024] Formal Semantics

**Statement**: Tier 3 MUST include formal semantics with typing rules, operational semantics, and soundness arguments.

| Tier | Main body | Appendices |
|------|-----------|------------|
| Tier 1 | Prose only | None |
| Tier 2 | Light formalism, explained | Optional |
| Tier 3 | Formal definitions inline | Extended proofs |

**Cross-references**: [RES-022], [RES-023]

---

### [RES-025] Empirical Validation

**Statement**: Tier 2+ for API-facing decisions SHOULD include empirical validation using Cognitive Dimensions Framework: visibility, consistency, viscosity, role-expressiveness, error-proneness, abstraction.

**Cross-references**: [RES-005], [RES-009]

---

### [RES-026] Reference Library

**Statement**: `swift-institute/References/` MUST contain discipline-partitioned `.bib` files (swift-evolution.bib, programming-languages.bib, type-theory.bib, category-theory.bib, api-usability.bib, methodology.bib). Tier 2+ SHOULD reference entries; Tier 3 MUST include traceable References section.

**Cross-references**: [RES-003], [RES-021]

---

## Discovery Workflow (Proactive)

**Entry point**: Audit design decisions, verify convention compliance, or document architectural rationale.

### [RES-012] Discovery Triggers

**Statement**: A discovery research document SHOULD be created when proactive analysis would improve consistency, document rationale, or identify improvements.

| Category | Priority |
|----------|----------|
| Package milestone (v1.0) | High |
| Cross-package review | High |
| Convention evolution | Medium |
| Rationale documentation | Medium |
| Pattern extraction | Medium |
| Retrospective | Low |

**Discovery vs Investigation**: Investigation starts from uncertainty to make a decision. Discovery starts from a working design to verify/document it.

**Cross-references**: [RES-001], [RES-002a]

---

### [RES-013] Design Audit Methodology

**Statement**: Design audits MUST follow systematic methodology: (1) Scope definition, (2) Decision inventory, (3) Evaluation criteria, (4) Evaluate, (5) Synthesize, (6) Recommend.

Scope defines: packages, decision types, relevant conventions. Inventory catalogs all design decisions. Evaluation uses criteria like convention compliance and cross-package consistency. Recommendations propose actions.

**Cross-references**: [RES-013a], [RES-014], [RES-015]

---

### [RES-013a] Synthesis Verification

**Statement**: When a research document synthesizes findings from prior documents, each carried-forward finding MUST be verified against current source before inclusion. Prior documents are leads, not ground truth.

Each finding MUST include a verification tag:

| Tag | Meaning |
|-----|---------|
| `Verified: YYYY-MM-DD` | Finding confirmed against current code |
| `Carried forward (unverified)` | Taken from prior document, not re-checked |
| `Resolved: YYYY-MM-DD` | Finding no longer applies (with explanation) |

**Rationale**: Code changes between the prior document's date and the synthesis date can silently resolve findings. Carrying forward stale findings without verification creates false positives that waste investigation effort and erode trust in the research corpus.

**Cross-references**: [RES-013], [RES-008], [META-*]

---

### [RES-014] Consistency Analysis

**Statement**: Consistency analysis MUST compare related design decisions across packages, identifying deviations and evaluating whether deviations are justified.

Categories: naming patterns, structural patterns, API patterns, error patterns, convention compliance.

Use template: Pattern definition → Current state table → Deviations (with justification assessment) → Recommendations.

**Cross-references**: [RES-013], [RES-015]

---

### [RES-015] Convention Compliance Verification

**Statement**: Convention compliance verification MUST check decisions against relevant convention rules, documenting compliance and justified exceptions.

Convention sources: Naming.md [API-NAME-*], Errors.md [API-ERR-*], Design.md [API-DESIGN-*], Code Organization.md [API-IMPL-*].

Use template: Convention reference → Items checked (compliance table) → Non-compliant items (current, required, resolution) → Summary.

**Cross-references**: [RES-013], [RES-014]

---

### [RES-016] Rationale Documentation

**Statement**: Significant design decisions SHOULD have documented rationale. Discovery research MAY retroactively document rationale.

| Criterion | Requirement |
|-----------|-------------|
| Affects multiple packages | SHOULD document |
| Establishes precedent | MUST document |
| Deviates from convention | MUST document |
| Has non-obvious trade-offs | SHOULD document |
| Frequently questioned | SHOULD document |

Use template: Decision → Context → Alternatives considered (with rejection reasons) → Chosen approach → Implications → References.

**Cross-references**: [RES-006], [RES-013]

---

### [RES-017] Pattern Extraction

**Statement**: When similar solutions appear across multiple packages, the pattern SHOULD be extracted and documented.

Process: (1) Identify recurring solution, (2) Collect instances, (3) Abstract common elements, (4) Document variations, (5) Propose standardization.

Use template: Pattern definition → Instances found table → Common elements → Variations → Standardized pattern → Application guidance.

**Cross-references**: [RES-014], [RES-006a]

---

## Cross-References

See also:
- **experiment-process** skill for validation workflows
- **blog-process** skill for publishing findings
- **naming** skill for [API-NAME-*] conventions
- **errors** skill for [API-ERR-*] conventions
