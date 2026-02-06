# Documentation Maintenance

@Metadata {
    @TitleHeading("Swift Institute")
}

Process for maintaining the health and organization of permanent documentation.

## Overview

**Scope**: This document defines the process for auditing and refactoring permanent institutional documentation.

**Applies to**: All permanent documentation files in the Swift Institute corpus.

**Does not apply to**: Reflection entries (see <doc:_Reflections-Consolidation>), plan files, or temporary documents.

As reflection entries are consolidated into permanent documentation, documents grow. Without maintenance, documents accumulate content that drifts from their original scope, overlap with other documents, or become too large for effective retrieval. Documentation maintenance addresses these concerns through periodic audit and refactoring.

**Trigger**: Manual only. User explicitly requests maintenance by pointing to this file.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## 1. The Maintenance Process

**Applies to**: Each invocation of documentation maintenance.

**Does not apply to**: Reflection consolidation or document creation.

---

### Process Overview

**Scope**: The sequence of maintenance activities.

**Statement**: Documentation maintenance MUST execute these phases in order:

1. **Inventory** - List all permanent documents with metadata
2. **Audit** - Analyze each document for maintenance issues
3. **Report** - Present findings and proposed actions to user
4. **Execute** - With user approval, perform maintenance actions
5. **Verify** - Confirm changes maintain corpus integrity

**Correct**:
```
Phase 1: Inventory
- Listed 8 documents with metadata

Phase 2: Audit
- Checked all 8 documents against criteria
- Found 3 issues

Phase 3: Report
- Presented findings to user
- User approved 2 of 3 proposed actions

Phase 4: Execute
- Performed approved actions

Phase 5: Verify
- All cross-references valid
- Maintenance complete
```

**Incorrect**:
```
Starting maintenance...
Moving to Implementation-Patterns.md
Splitting Primitives-Architecture.md...
Done.

❌ Skipped inventory, audit, report, and verification phases.
❌ Executed without user approval.
```

**Rationale**: Phased execution ensures issues are identified before changes are made, and changes are approved before execution.

---

### Inventory Phase

**Scope**: Cataloging the documentation corpus.

**Statement**: The inventory phase MUST produce a list of all permanent documents with:

| Field | Description |
|-------|-------------|
| Document name | File name without extension |
| Stated scope | The "Applies to" / "Does not apply to" from Overview |
| Requirement count | Number of `[XXX-YYY-NNN]` identifiers |
| Word count | Approximate document length |
| Last updated | From metadata or git history |
| Cross-references | Documents this document references |

**Correct**:
```markdown
## Documentation Inventory

| Document | Scope | Requirements | Words | Updated |
|----------|-------|--------------|-------|---------|
| API-Requirements | API design, naming, error handling | 45 | 8,200 | 2026-01-17 |
| Primitives-Architecture | Package structure, naming, tiers | 28 | 5,100 | 2026-01-17 |
| Implementation-Patterns | C shims, platform conditionals | 18 | 3,800 | 2026-01-16 |

Cross-reference graph:
- API-Requirements → Primitives-Architecture (12 refs)
- Primitives-Architecture → API-Requirements (8 refs)
- Implementation-Patterns → API-Requirements (5 refs)
```

**Incorrect**:
```markdown
## Documentation Inventory

Documents: API-Requirements, Primitives-Architecture, Implementation-Patterns

❌ Missing: stated scope, requirement counts, word counts, dates
❌ Missing: cross-reference analysis
❌ Cannot identify size issues or relationship patterns
```

**Rationale**: Inventory provides the baseline for identifying maintenance issues.

---

## 2. Audit Criteria

**Applies to**: Evaluating each document during the audit phase.

**Does not apply to**: Reflection entries or temporary documents.

---

### Scope Drift Detection

**Scope**: Identifying content that doesn't belong in a document.

**Statement**: For each document, compare the stated scope (from Overview) against actual content. Flag requirements that fall outside the stated scope.

**Indicators of scope drift**:
- Requirement addresses a domain not mentioned in "Applies to"
- Requirement would be more discoverable in a different document
- Requirement duplicates content in another document
- Requirement references concepts foreign to the document's domain

**Correct**:
```
## Scope Drift: API-Requirements.md "Platform Conditional Compilation"
- Stated scope: "API design, naming conventions, method signatures"
- Actual content: Platform-specific compilation patterns
- Recommendation: Move to Implementation-Patterns.md
```

**Incorrect**:
```
## Scope Drift: API-Requirements.md

No scope drift detected.

❌ Did not compare stated scope against actual content
❌ addresses platform patterns, not API design
❌ Missed opportunity to improve discoverability
```

---

### Size Threshold Analysis

**Scope**: Identifying documents that have grown too large.

**Statement**: Flag documents exceeding these thresholds:

| Metric | Warning | Critical |
|--------|---------|----------|
| Requirements | >40 | >60 |
| Words | >8,000 | >12,000 |
| Sections | >8 | >12 |

**Correct**:
```
## Size Analysis: API-Requirements.md

- Requirements: 52 (WARNING: exceeds 40)
- Words: 9,450 (WARNING: exceeds 8,000)
- Sections: 7 (OK)
- Recommendation: Consider splitting by domain
```

**Incorrect**:
```
## Size Analysis: API-Requirements.md

- Requirements: 52
- Words: 9,450

Document looks fine.

❌ Did not compare against thresholds
❌ Missed WARNING level on both metrics
❌ No actionable recommendation provided
```

---

### Cross-Reference Integrity

**Scope**: Verifying cross-references are valid and bidirectional.

**Statement**: For each cross-reference (`[XXX-YYY-NNN]`), verify:

1. The referenced requirement exists
2. The reference is bidirectional where appropriate
3. No orphaned references (pointing to deleted requirements)

**Correct**:
```
## Cross-Reference Issues references
- Status: Valid, bidirectional ✓ references
- Status: INVALID - does not exist
- Recommendation: Update or remove reference
```

**Incorrect**:
```
## Cross-Reference Issues

All cross-references checked. No issues found.

❌ does not exist in corpus
❌ Reference from is broken
```

**Rationale**: Broken cross-references degrade document connectivity.

---

### Pattern Consistency

**Scope**: Verifying all requirements follow structural patterns.

**Statement**: Each requirement MUST include these elements:

| Element | Required | Description |
|---------|----------|-------------|
| Rule identifier | Yes | `[PREFIX-CAT-NNN]` format |
| Scope | Yes | What this requirement covers |
| Statement | Yes | Normative requirement with MUST/SHOULD/MAY |
| Correct example | Yes | Code or text showing correct application |
| Incorrect example | Yes | Code or text showing violation |
| Rationale | Yes | Why this requirement exists |
| Cross-references | No | Related requirements (if any) |

**Correct**:
```
## Pattern Issues: Primitives-Architecture.md Missing elements:
- ❌ No Incorrect example
- ❌ No Rationale
- Recommendation: Add missing elements Complete ✓
- Rule identifier: ✓
- Scope: ✓
- Statement: ✓
- Correct example: ✓
- Incorrect example: ✓
- Rationale: ✓
```

**Incorrect**:
```
## Pattern Issues: Primitives-Architecture.md

All requirements follow correct patterns.

❌ is missing Incorrect example
❌ is missing Rationale
```

---

### Duplicate Detection

**Scope**: Identifying overlapping content across documents.

**Statement**: Flag requirements that substantially overlap with requirements in other documents. Overlap indicators:

- Same concept expressed with different wording
- Same code examples in multiple places
- Conflicting guidance on the same topic

**Correct**:
```
## Duplicate Detection in API-Requirements.md in Primitives-Architecture.md

- Both address naming conventions for packages
- Content overlap: ~70%
- Recommendation: Consolidate into one location, cross-reference from other
```

**Incorrect**:
```
## Duplicate Detection

No duplicates found.

❌ and both cover naming conventions
❌ 70% content overlap not detected
❌ Future updates may create inconsistency between duplicates
```

**Rationale**: Duplicates create maintenance burden and risk inconsistency.

---

## 2a. Document Architecture

**Applies to**: Evaluating document scope and organization during audit.

**Does not apply to**: Reflection entries or single-purpose reference documents.

Document architecture governs how the corpus is organized—not just what each document contains, but what *kind* of document it is and how documents relate to each other.

---

### Document Archetypes

**Scope**: Classifying documents by their purpose.

**Statement**: Each document MUST serve exactly one archetype. Documents mixing archetypes SHOULD be split by archetype before considering domain-based splits.

| Archetype | Question Answered | Characteristics | Examples |
|-----------|------------------|-----------------|----------|
| **Definition** | What is X? | Authoritative specifications, tier structures, constraints | Primitives Tiers, Five Layer Architecture |
| **Decision** | How do I decide about X? | Decision trees, flowcharts, worked examples | Primitives Layering, Layer Flowchart |
| **Policy** | What rules apply to X? | Requirements with MUST/SHOULD, mandates | Primitives Requirements, API Requirements |
| **Reference** | What instances of X exist? | Catalogs, inventories, glossaries | Package Inventory, Glossary |
| **Process** | How do I do X? | Step-by-step procedures, workflows | Documentation Maintenance, Reflections Consolidation |

**Correct**:
```
Primitives Tiers.md (Definition archetype)
- Answers: "What tiers exist?"
- Contains: Tier definitions, constraints, package assignments
- Does NOT contain: Decision procedures, policy mandates

Primitives Layering.md (Decision archetype)
- Answers: "How do I decide tier/scope?"
- Contains: Decision trees, worked examples, split criteria
- Does NOT contain: Tier definitions, policy mandates
```

**Incorrect**:
```
Primitives Architecture.md (MIXED archetypes)
- Contains tier definitions (Definition)
- Contains decision procedures (Decision)
- Contains policy mandates (Policy)
- Contains extraction process (Process)

❌ Four archetypes in one document
❌ "Junk drawer" mixing unrelated concerns
❌ Should be split into 3-4 focused documents
```

**Detection**: Ask "What question does this document answer?" If the answer requires "and" (e.g., "what tiers exist AND how to decide AND what rules apply"), the document mixes archetypes.

**Rationale**: Archetype mixing is the primary cause of "junk drawer" documents. A document answering multiple kinds of questions lacks coherent scope and grows unboundedly.

---

### Audience Statement Requirement

**Scope**: Document scope declaration.

**Statement**: Each document SHOULD include an audience statement in its Overview section declaring what question it answers.

**Format**:
```markdown
> This document answers: "[single question matching archetype]"
```

**Correct**:
```markdown
## Overview

> This document answers: "What tiers exist, and what are their hard dependency constraints?"

The primitives layer is organized as a directed acyclic graph...
```

**Incorrect**:
```markdown
## Overview

This document covers the nine-tier dependency hierarchy, naming conventions,
Foundation independence requirements, extraction procedures, and design philosophy.

❌ No audience statement
❌ Multiple concerns listed (indicates archetype mixing)
❌ Future content will drift without clear scope constraint
```

**Detection**: If the Overview lists multiple topics with "and", the document likely mixes archetypes.

**Rationale**: Audience statements constrain scope. A document that cannot state its question in one sentence is scoped too broadly.

---

### Index Document Pattern

**Scope**: Documents that have grown to contain multiple sub-domains.

**Statement**: When a document exceeds size thresholds AND contains multiple coherent sub-domains, it SHOULD be refactored into the Index + Focused Documents pattern:

1. **Index document**: Provides overview, quick reference, and routes to sub-documents
2. **Focused documents**: Each covers one sub-domain exhaustively

| Index Document | Focused Sub-documents |
|----------------|----------------------|
| API Requirements | API-Naming, API-Errors, API-Implementation, API-Concurrency, API-Layering, API-Design |
| Implementation Patterns | Pattern-C-Shims, Pattern-Platform-Compilation, Pattern-Swift-6, Pattern-Advanced |
| Memory | Memory-Ownership, Memory-Copyable, Memory-Sendable, Memory-Safety, Memory-Reference |
| Primitives Architecture | Primitives-Tiers, Primitives-Layering, Primitives-Requirements |

**Index document template**:
```markdown
# [Topic]

[Brief description]

## Overview

This document serves as an index to [topic]. Each [category] is documented
in its own focused document for maintainability.

## Document Index

| Document | Requirements | Focus |
|----------|--------------|-------|
| <doc:Sub-Doc-1> | PREFIX-001 through PREFIX-010 | [focus area] |
| <doc:Sub-Doc-2> | PREFIX-011 through PREFIX-020 | [focus area] |

## Quick Reference

[Most-used requirements with brief summaries and links to full details]

## Topics

- <doc:Sub-Doc-1>
- <doc:Sub-Doc-2>
```

**When to apply**:
- Document exceeds WARNING thresholds (>40 requirements OR >8,000 words)
- Content naturally groups into 3+ coherent sub-domains
- Sub-domains are independently useful (users may need only one)

**When NOT to apply**:
- Document is below thresholds and coherently scoped
- Content cannot be meaningfully separated
- Separation would require duplicating context in each sub-document

**Rationale**: The index pattern improves retrieval (smaller chunks), human navigation (clear entry point), and maintenance (changes isolated to relevant sub-document).

---

### Archetype-Based Split Priority

**Scope**: Ordering split decisions.

**Statement**: When a document requires splitting, evaluate in this order:

1. **Archetype split first**: If mixing archetypes, split by archetype
2. **Domain split second**: If single archetype but multiple domains, split by domain
3. **Size split last**: If single archetype and domain but too large, split by sub-topic

**Correct**:
```
Document: Primitives-Architecture.md (736 lines)

Step 1 - Archetype analysis:
- Contains tier definitions (Definition)
- Contains decision procedures (Decision)
- Contains policy mandates (Policy)
→ SPLIT BY ARCHETYPE FIRST

Result:
- Primitives-Tiers.md (Definition)
- Primitives-Layering.md (Decision)
- Primitives-Requirements.md (Policy)

Step 2 - Domain analysis: Each new document is single-domain ✓
Step 3 - Size analysis: Each new document is within thresholds ✓
```

**Incorrect**:
```
Document: Primitives-Architecture.md (736 lines)

Analysis: Document exceeds 8,000 words
Action: Split into Primitives-Architecture-Part1.md and Primitives-Architecture-Part2.md

❌ Split by size without analyzing archetypes
❌ Both parts still mix Definition + Decision + Policy
❌ Problem not solved, just distributed
```

**Rationale**: Archetype mixing is a more fundamental problem than size. Splitting by size without fixing archetype mixing produces multiple junk drawers instead of one.

---

## 3. Split Criteria

**Applies to**: Decisions about dividing a document into multiple documents.

**Does not apply to**: Documents below size thresholds with coherent scope.

---

### When to Split

**Scope**: Criteria for document splitting.

**Statement**: A document SHOULD be split when ANY of these conditions apply:

| Condition | Threshold | Example |
|-----------|-----------|---------|
| **Archetype mixing** | >1 archetype in document | Definition AND Decision AND Policy in same document |
| **Size exceeded** | >60 requirements OR >12,000 words | API-Requirements with 65 requirements |
| **Multiple domains** | >2 distinct conceptual domains | Error handling AND naming conventions AND concurrency |
| **Discovery failure** | Related content hard to find | Users consistently look in wrong document |
| **Natural boundary** | Clear semantic division exists | "Platform" vs "Cross-platform" patterns |

**Correct split decision**:
```
## Split Recommendation: API-Requirements.md

Current state:
- 52 requirements across 4 domains
- Domains: Naming (15), Error Handling (12), Concurrency (10), Implementation (15)

Recommendation: Split into:
1. API-Naming.md (15 requirements)
2. API-Error-Handling.md (12 requirements)
3. API-Concurrency.md (10 requirements)
4. API-Implementation.md (15 requirements)

Rationale: Each domain is independently coherent and large enough to justify separation.
```

**Incorrect split decision**:
```
Splitting API-Requirements.md because it has 42 requirements.
❌ Below critical threshold, no domain fragmentation identified.
```

**Rationale**: Premature splitting creates navigation overhead without improving discoverability.

---

### Split Execution

**Scope**: How to perform a document split.

**Statement**: When splitting a document:

1. Create new document(s) following <doc:_Reflections-Consolidation#CONS-CREATE-001> template
2. Move requirements to appropriate new documents
3. Update all cross-references in moved requirements
4. Update all cross-references pointing TO moved requirements
5. Add cross-references between new documents where appropriate
6. Update Topics sections in all affected documents
7. Retain original document if content remains, or delete if fully split

**Correct**:
```
Splitting API-Requirements.md → API-Naming.md + API-Error-Handling.md

1. Created API-Naming.md with [API-NAME-*] requirements
2. Created API-Error-Handling.md with [API-ERR-*] requirements
3. Updated cross-reference from → still valid
4. Updated reference to → now in API-Naming.md
5. Added mutual cross-references between new documents
6. Updated Topics in: API-Naming.md, API-Error-Handling.md, Primitives-Architecture.md
7. Retained API-Requirements.md with remaining [API-IMPL-*] and [API-CONC-*]
```

**Incorrect**:
```
Splitting API-Requirements.md → API-Naming.md + API-Error-Handling.md

1. Created API-Naming.md with [API-NAME-*] requirements
2. Created API-Error-Handling.md with [API-ERR-*] requirements
3. Done.

❌ Skipped cross-reference updates
❌ now has broken reference to
❌ Topics sections not updated—new documents not discoverable
❌ Original document status unclear
```

**Rationale**: Systematic execution prevents broken references and orphaned content.

---

## 4. Merge Criteria

**Applies to**: Decisions about combining multiple documents into one.

**Does not apply to**: Documents with distinct, well-defined scopes.

---

### When to Merge

**Scope**: Criteria for document merging.

**Statement**: Documents SHOULD be merged when ANY of these conditions apply:

| Condition | Indicator | Example |
|-----------|-----------|---------|
| **Too small** | <10 requirements AND <2,000 words | Orphaned document from over-splitting |
| **Overlapping scope** | >50% content overlap | Two documents covering same domain |
| **Artificial separation** | Split created navigation overhead | Users must check both documents |
| **Single consumer** | Only one other document references it | Utility document with narrow use |

**Correct**:
```
## Merge Recommendation: API-Naming.md + API-Identifiers.md

Current state:
- API-Naming.md: 8 requirements, 1,800 words
- API-Identifiers.md: 6 requirements, 1,200 words
- Content overlap: 40%
- Both referenced only by API-Requirements.md

Recommendation: Merge into API-Naming.md
Rationale: Combined size (14 requirements) is manageable, scope is coherent.
```

**Incorrect**:
```
## Merge Recommendation: API-Naming.md + API-Identifiers.md

These documents should remain separate.

❌ Both documents are below minimum size threshold (<10 requirements)
❌ 40% content overlap creates maintenance burden
❌ Artificial separation forces users to check two documents
❌ Keeping them separate does not improve discoverability
```

**Rationale**: Over-fragmented documentation creates navigation overhead without improving discoverability.

---

## 5. Maintenance Actions

**Applies to**: Actions taken after audit and user approval.

**Does not apply to**: Actions taken without user approval.

---

### Action Approval

**Scope**: User approval before maintenance execution.

**Statement**: Before executing any maintenance action, present a summary to the user and obtain explicit approval.

**Correct**:
```
## Proposed Maintenance Actions

1. MOVE from API-Requirements.md to Implementation-Patterns.md
2. SPLIT Primitives-Architecture.md into Primitives-Architecture.md + Primitives-Naming.md
3. FIX cross-reference → (was)
4. ADD missing Rationale to

Approve all? [User confirms or modifies]

User: "Approve 1, 3, 4. Skip 2 for now."

Proceeding with approved actions only...
```

**Incorrect**:
```
Performing maintenance actions:
- Moving...
- Splitting Primitives-Architecture.md...
- Fixing cross-references...
- Adding missing elements...
Done.

❌ No approval requested before execution
❌ User had no opportunity to review or modify actions
❌ Unintended changes may have been made
```

**Rationale**: Maintenance actions are significant refactoring. User oversight prevents unintended changes.

---

### Move Requirement

**Scope**: Relocating a requirement to a different document.

**Statement**: When moving a requirement:

1. Copy the requirement to the target document in the appropriate section
2. Update the requirement's cross-references for new location
3. Update all documents that reference this requirement
4. Remove the requirement from the source document
5. Verify no broken references remain

**Correct**:
```
Move to Implementation-Patterns.md

Steps performed:
1. Copied to Implementation-Patterns.md under "Platform Patterns" section
2. Updated cross-references to point to new location
3. Updated reference to → valid (identifier unchanged)
4. Removed from API-Requirements.md
5. Verified: grep for shows only Implementation-Patterns.md

Commit: Move to Implementation-Patterns.md
```

**Incorrect**:
```
Move to Implementation-Patterns.md

1. Copied content to Implementation-Patterns.md
2. Deleted from API-Requirements.md
Done.

❌ Did not update cross-references
❌ now has broken reference
❌ Did not verify no broken references remain
```

**Rationale**: Proper relocation maintains reference integrity.

---

### Deduplicate Content

**Scope**: Resolving content that appears in multiple documents.

**Statement**: When deduplicating:

1. Identify the canonical location (best scope fit)
2. Consolidate content into the canonical requirement
3. Replace duplicate with cross-reference to canonical
4. Optionally add brief summary with "See for details"

**Correct**:
```markdown
## Deduplication: Naming Conventions

Canonical location: API-Requirements.md
Duplicate location: Primitives-Architecture.md

Action:
1. Expanded to cover all package types (general + primitives)
2. Reduced to primitives-specific additions only
3. Added "See for general conventions" to

## After

API-Requirements.md:
- General naming conventions (expanded)
- Covers all package types

Primitives-Architecture.md:
- "See for general naming conventions"
- Primitives-specific additions only
```

**Incorrect**:
```markdown
## Deduplication: Naming Conventions

Both and kept as-is.
Added note to: "See also"

❌ Content still duplicated in both locations
❌ Future updates must be made in two places
❌ Risk of inconsistency remains
```

**Rationale**: Single source of truth prevents inconsistency.

---

### Fix Cross-References

**Scope**: Repairing broken or outdated cross-references.

**Statement**: When fixing cross-references:

1. Identify the correct target requirement
2. Update the reference to use correct identifier
3. If target was deleted, either remove reference or note deletion
4. Verify bidirectional references where appropriate

**Correct**:
```
## Fix Cross-Reference:

Issue: References which does not exist
Analysis: was renumbered to in previous refactor

Action:
1. Updated to reference
2. Verified exists in Primitives-Architecture.md
3. Added reciprocal reference from to

Commit: Fix broken cross-reference →
```

**Incorrect**:
```
## Fix Cross-Reference:

Issue: References which does not exist
Action: Removed the cross-reference line from

❌ Did not identify correct target
❌ Lost valuable connection between related requirements
❌ Did not investigate why reference was broken
```

**Rationale**: Valid cross-references maintain document connectivity.

---

### Add Missing Elements

**Scope**: Completing requirements that lack required structure.

**Statement**: When adding missing elements:

1. Add Correct example if missing (concrete code or text)
2. Add Incorrect example if missing (showing violation)
3. Add Rationale if missing (explaining why requirement exists)
4. Add Cross-references if related requirements exist

**Correct**:
```markdown
## Add Missing Elements:

Before:
### Error Type Naming
**Scope**: Error type names.
**Statement**: Error types MUST use the suffix `Error`.

After:
### Error Type Naming
**Scope**: Error type names.
**Statement**: Error types MUST use the suffix `Error`.

**Correct**:
` ` `swift
struct ParseError: Error { }
enum ValidationError: Error { case invalid }
` ` `

**Incorrect**:
` ` `swift
struct ParseFailure: Error { }  // ❌ Missing Error suffix
enum ValidationIssue: Error { } // ❌ Missing Error suffix
` ` `

**Rationale**: Consistent naming enables discovery—searching for
"Error" finds all error types.
```

**Incorrect**:
```markdown
## Add Missing Elements:

Added placeholder text:
**Correct**: [TODO: add example]
**Incorrect**: [TODO: add example]
**Rationale**: [TODO: add rationale]

❌ Placeholders do not help parsing
❌ Missing concrete examples
❌ Missing meaningful rationale
```

---

## 6. Verification

**Applies to**: Confirming maintenance was successful.

**Does not apply to**: Pre-maintenance state.

---

### Post-Maintenance Verification

**Scope**: Verifying corpus integrity after maintenance.

**Statement**: After maintenance execution, verify:

1. All cross-references resolve correctly
2. No orphaned requirements (not referenced, not in Topics)
3. All documents have valid Topics sections
4. No duplicate requirement identifiers across corpus
5. Git commit includes all affected files

**Correct**:
```
## Maintenance Verification

Cross-references: 47 checked, 47 valid ✓
Orphaned requirements: 0 ✓
Topics sections: 8 documents, all valid ✓
Duplicate identifiers: 0 ✓
Git status: All changes committed ✓

Maintenance complete.
```

**Incorrect**:
```
## Maintenance Verification

Changes committed. Maintenance complete.

❌ Did not verify cross-references (3 are now broken)
❌ Did not check for orphaned requirements ( not in any Topics)
❌ Did not verify Topics sections (new document missing from index)
❌ Did not check for duplicate identifiers
❌ Errors will propagate to future maintenance cycles
```

**Rationale**: Verification catches errors before they propagate.

---

## 7. Corpus Compaction

**Does not apply to**: Individual document structure (see Section 2a).

---

### Corpus Size Thresholds

**Scope**: Total documentation corpus size.

**Statement**: Track total word count across all permanent documents. Flag when thresholds are exceeded:

| Metric | Warning | Critical |
|--------|---------|----------|
| Total words | >80,000 | >120,000 |
| Total documents | >40 | >60 |
| Average doc size | >3,000 words | >5,000 words |

**Correct**:
```
## Corpus Size Report

Total documents: 35
Total words: 72,000
Average document: 2,057 words

Status: Within thresholds ✓
```

**Incorrect**:
```
## Corpus Size Report

Total documents: 52
Total words: 134,000
Average document: 2,577 words

❌ Exceeds CRITICAL threshold for total words
❌ Exceeds WARNING threshold for document count
❌ Context exhaustion likely during audits
```

**Action when exceeded**: Trigger compaction review using through.

---

### Cross-Document Redundancy

**Scope**: Eliminating duplicate content across documents.

**Statement**: During compaction review, identify concepts explained in multiple documents. Consolidate to a single canonical location; replace duplicates with cross-references.

**Detection patterns**:
- Same rule explained with different wording in 2+ documents
- Similar code examples across documents
- Overlapping "Rationale" sections

**Correct**:
```
## Cross-Document Redundancy: "No Foundation" rule

Found in:
- API-Requirements.md (3 paragraphs)
- Primitives-Requirements.md (4 paragraphs)
- Pattern-Anti-Patterns.md (2 paragraphs)

Action:
1. Canonical location: Primitives-Requirements.md
2. API-Requirements.md: Replace with "See"
3. Pattern-Anti-Patterns.md: Replace with "See"

Words saved: ~450
```

**Incorrect**:
```
## Cross-Document Redundancy

No redundancy found.

❌ Three documents explain the same rule independently
❌ Future updates must be made in three places
❌ Risk of inconsistency between explanations
```

**Rationale**: Single source of truth reduces corpus size and prevents drift between duplicate explanations.

---

### Content Density

**Scope**: Reducing verbosity within documents.

**Statement**: Each requirement SHOULD be as concise as possible while remaining complete. Apply these density guidelines:

| Element | Target | Maximum |
|---------|--------|---------|
| Rule statement | 1-2 sentences | 3 sentences |
| Correct example | 1 code block | 2 code blocks |
| Incorrect example | 1 code block | 2 code blocks |
| Rationale | 1-2 sentences | 3 sentences |

**Density anti-patterns**:

| Anti-pattern | Fix |
|--------------|-----|
| 3+ examples showing same violation | Keep strongest example, remove others |
| Rationale repeats the Statement | Remove redundant rationale |
| Lengthy preamble before Statement | Move context to Scope or remove |
| Multiple paragraphs of explanation | Summarize; link to deep-dive if needed |

**Correct**:
```markdown
### Typed Throws

**Scope**: All throwing functions.

**Statement**: Functions MUST use typed throws. Existential errors erase information.

**Correct**:
` ` `swift
func parse() throws(Parse.Error) -> Document
` ` `

**Incorrect**:
` ` `swift
func parse() throws -> Document  // ❌ Erases error type
` ` `

**Rationale**: Typed errors enable exhaustive handling and preserve caller information.
```

**Incorrect**:
```markdown
### Typed Throws

**Scope**: All throwing functions in all packages across the ecosystem.

**Statement**: All functions that can throw errors MUST use typed throws
with a specific error type. They MUST NOT use untyped throws which would
erase the error type information. They also MUST NOT use existential
error types like `any Error` because this also erases type information.

**Correct**:
` ` `swift
func parse() throws(Parse.Error) -> Document
` ` `

` ` `swift
func validate() throws(Validation.Error) -> Bool
` ` `

` ` `swift
func load() throws(IO.Error) -> Data
` ` `

**Incorrect**:
` ` `swift
func parse() throws -> Document
` ` `

` ` `swift
func validate() throws -> Bool
` ` `

**Rationale**: When you use typed throws, the compiler knows exactly what
error types can be thrown. This enables exhaustive pattern matching in
catch blocks. It also preserves information for the caller about what
went wrong. Untyped throws erases this information, forcing callers to
use catch-all handlers or attempt unsafe downcasts.

❌ Statement is 4 sentences (target: 1-2)
❌ 3 Correct examples (target: 1)
❌ Rationale is 4 sentences (target: 1-2)
❌ ~180 words → could be ~60 words
```

**Rationale**: Dense documentation is more retrievable. Verbose documentation exhausts context before conveying essential rules.

---

### Essential vs Extended Content

**Scope**: Separating core rules from extended guidance.

**Statement**: When a document exceeds size thresholds AND contains both essential rules and extended content (deep examples, edge cases, historical context), consider separating into:

1. **Core document**: Rules with minimal examples (optimized for retrieval)
2. **Extended document**: Deep dives, edge cases, worked examples (for human learning)

| Content Type | Location | Purpose |
|--------------|----------|---------|
| Rule statements | Core | Quick reference |
| Single correct/incorrect example | Core | Illustrate the rule |
| Multiple examples | Extended | Show variations |
| Edge cases | Extended | Handle unusual situations |
| Historical context | Extended | Explain why rule exists |
| Worked walkthroughs | Extended | Teaching material |

**Correct**:
```
API-Errors.md (Core - 400 words)
- through
- One example each
- Concise rationales

API-Errors-Extended.md (Extended - 1,200 words)
- Complex error hierarchy examples
- Migration guide from untyped throws
- Edge cases for generic error types
```

**When NOT to apply**:
- Document is within size thresholds
- Extended content is minimal
- Separation would fragment coherent narrative

**Rationale**: Dense, retrievable rule statements serve quick reference. Extended examples serve deeper understanding. Separating these serves both needs.

---

### Compaction Execution

**Scope**: Performing compaction changes.

**Statement**: When executing compaction, follow this sequence:

1. **Measure**: Record current corpus size (total words, document count)
2. **Identify**: List redundancies, verbose sections, extended content
3. **Propose**: Present compaction actions with estimated word savings
4. **Approve**: Obtain user approval before changes
5. **Execute**: Apply compaction changes
6. **Verify**: Confirm corpus size reduction; verify no content loss
7. **Report**: Document before/after metrics

**Correct**:
```
## Compaction Report

Before: 134,000 words across 52 documents
After: 89,000 words across 48 documents

Actions taken:
- Consolidated 3 "No Foundation" explanations → saved 450 words
- Reduced API-ERR examples from 3 to 1 each → saved 890 words
- Extracted API-Errors-Extended.md → moved 1,200 words to extended doc
- Merged 4 undersized Pattern docs → reduced doc count by 3

Reduction: 33% fewer words, 8% fewer documents
```

**Rationale**: Measured compaction ensures meaningful reduction without content loss.

---

## Topics

### Related Processes

- <doc:_Reflections-Consolidation> - Process that grows documentation
- <doc:_Reflections> - Entry point for reflection capture
-  - Principles guiding document structure

### Documentation Corpus

- <doc:API-Requirements>
- <doc:Five-Layer-Architecture>
- <doc:Implementation-Patterns>
- <doc:Identity>
