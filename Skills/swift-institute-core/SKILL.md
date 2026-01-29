---
name: swift-institute-core
description: |
  Swift Institute system manifest and skill index.
  This meta-skill declares canonical sources and loading order.
  ALWAYS loaded first when working in Swift Institute repositories.

layer: meta

requires: []

applies_to:
  - swift
  - swift6
  - swift-primitives
  - swift-standards
  - swift-foundations
---

# Swift Institute Core

This is the root meta-skill for the Swift Institute ecosystem.

---

## Skill Index

### Meta Layer
- **swift-institute-core** (this skill) - System manifest

### Architecture Layer
- **swift-institute** - Five-layer architecture, semantic dependencies
- **primitives** - Primitives-specific conventions (in swift-primitives repo)

### Implementation Layer
- **naming** - [API-NAME-*] Type and method naming
- **errors** - [API-ERR-*] Error handling
- **code-organization** - [API-IMPL-*] File structure
- **anti-patterns** - [PATTERN-009–017] Common mistakes to avoid
- **primitives-conversions** - [CONV-*] Conversion APIs and rawValue access rules
- **memory-arithmetic** - [MEM-ARITH-*] Memory.Address typed arithmetic (in swift-memory-primitives)
- **pointer-arithmetic** - [PTR-ARITH-*] Pointer<T> typed access patterns (in swift-pointer-primitives)
- **index** - [IDX-*] Index<T> phantom-typed index patterns (in swift-index-primitives)
- **platform** - [PATTERN-001–008] Build, platform, Swift 6, C shims
- **design** - [API-LAYER-*, PATTERN-017–050] API design, layering, concurrency
- **advanced-patterns** - [PATTERN-014–048] Memory ownership, unsafe ops, refactoring
- **memory** - [MEM-COPY-*, MEM-OWN-*, MEM-LINEAR-*] Ownership, copyability
- **memory-safety** - [MEM-SAFE-*, MEM-SEND-*, MEM-REF-*, MEM-LIFE-*] Strict safety, reference primitives
- **copyable-remediation** - [COPY-FIX-*, COPY-REM-*] ~Copyable constraint fixes
- **testing** - [TEST-001–018] Test organization, Swift Testing patterns

### Process Layer
- **research-process** - [RES-*] Research workflows
- **experiment-process** - [EXP-*] Experiment workflows
- **blog-process** - [BLOG-*] Blog post workflows
- **skill-creation** - [SKILL-CREATE-*] Adding new skills to the ecosystem
- **package-export** - [PKG-EXPORT-*] Export packages for LLM consumption
- **collaborative-discussion** - [COLLAB-*] Claude-ChatGPT collaborative discussions

---

## Loading Order

Skills are loaded based on their `requires:` DAG. The order is:

1. `swift-institute-core` (no requirements)
2. `swift-institute` (requires: swift-institute-core)
3. `naming` (requires: swift-institute)
4. `errors` (requires: swift-institute)
5. `code-organization` (requires: naming, errors)
6. `platform` (requires: swift-institute)
7. `memory` (requires: naming, errors)
8. `memory-safety` (requires: swift-institute, memory)
9. `design` (requires: swift-institute, naming)
10. `copyable-remediation` (requires: memory)
11. `anti-patterns` (requires: naming, errors, code-organization)
12. `primitives-conversions` (requires: swift-institute, naming)
13. `advanced-patterns` (requires: memory, memory-safety, design)
14. `testing` (requires: swift-institute, naming, code-organization)
14. Process skills (requires: swift-institute)

---

## Canonical Sources

| Artifact | Purpose | Authority |
|----------|---------|-----------|
| Skills/ | Rules, requirements, workflows | CANONICAL (WHAT) |
| Research/ | Rationale, trade-offs, history | AUTHORITATIVE (WHY) |
| Documentation.docc/ | Explanation, onboarding | NON-NORMATIVE (HOW) |

---

## Package Locations

| Package | Path |
|---------|------|
| swift-primitives | `/Users/coen/Developer/swift-primitives/` |
| swift-standards | `/Users/coen/Developer/swift-standards/` |
| swift-foundations | `/Users/coen/Developer/swift-foundations/` |
| swift-institute | `/Users/coen/Developer/swift-institute/` |
