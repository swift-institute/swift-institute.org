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
- **anti-patterns** - [PATTERN-009–016] Common mistakes to avoid
- **platform** - [PATTERN-001–008] Build, platform, Swift 6, C shims
- **design** - [API-LAYER-*, PATTERN-017–050] API design, layering, concurrency
- **advanced-patterns** - [PATTERN-014–048] Memory ownership, unsafe ops, refactoring
- **memory** - [MEM-COPY-*, MEM-OWN-*, MEM-LINEAR-*] Ownership, copyability
- **memory-safety** - [MEM-SAFE-*, MEM-SEND-*, MEM-REF-*, MEM-LIFE-*] Strict safety, reference primitives
- **copyable-remediation** - [COPY-FIX-*, COPY-REM-*] ~Copyable constraint fixes

### Process Layer
- **research-process** - [RES-*] Research workflows
- **experiment-process** - [EXP-*] Experiment workflows
- **blog-process** - [BLOG-*] Blog post workflows
- **skill-creation** - [SKILL-CREATE-*] Adding new skills to the ecosystem

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
12. `advanced-patterns` (requires: memory, memory-safety, design)
13. Process skills (requires: swift-institute)

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
