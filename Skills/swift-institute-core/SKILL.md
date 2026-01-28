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
- **anti-patterns** - [PATTERN-*] Common mistakes to avoid
- **memory** - [MEM-COPY-*, MEM-OWN-*, MEM-LINEAR-*] Ownership, copyability
- **memory-safety** - [MEM-SAFE-*, MEM-SEND-*, MEM-REF-*, MEM-LIFE-*] Strict safety, reference primitives
- **copyable-remediation** - [COPY-FIX-*, COPY-REM-*] ~Copyable constraint fixes

### Process Layer
- **research-process** - Research workflows
- **experiment-process** - Experiment workflows
- **blog-process** - Blog post workflows

---

## Loading Order

Skills are loaded based on their `requires:` DAG. The order is:

1. `swift-institute-core` (no requirements)
2. `swift-institute` (requires: swift-institute-core)
3. `naming` (requires: swift-institute)
4. `errors` (requires: swift-institute)
5. `code-organization` (requires: naming, errors)
6. `memory` (requires: naming, errors)
7. `memory-safety` (requires: swift-institute, memory)
8. `copyable-remediation` (requires: memory)
9. `anti-patterns` (requires: naming, errors, code-organization)
10. Process skills (requires: swift-institute)

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
