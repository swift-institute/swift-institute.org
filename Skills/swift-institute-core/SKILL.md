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
last_reviewed: 2026-03-27
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
- **code-surface** - [API-NAME-*], [API-ERR-*], [API-IMPL-*] Naming, error handling, file structure (absorbs naming, errors, code-organization)
- **implementation** - [IMPL-*], [PATTERN-009–053], [API-LAYER-*], [SEM-DEP-*] Call-site-first patterns, typed arithmetic, boundary overloads, dependency strategy (absorbs anti-patterns, design)
- **conversions** - [IDX-*], [CONV-*] Index<T> patterns, conversion APIs, rawValue access rules (absorbs primitives-conversions)
- **memory-arithmetic** - [MEM-ARITH-*] Memory.Address typed arithmetic (in swift-memory-primitives)
- **platform** - [PLAT-ARCH-*], [PATTERN-001–008] Platform code layering (L1–L3), compilation mechanics, Swift 6, C shims
- **modularization** - [MOD-*] Intra-package target decomposition, constraint isolation
- **memory-safety** - [MEM-COPY-*], [MEM-OWN-*], [MEM-LINEAR-*], [MEM-SAFE-*], [MEM-SEND-*], [MEM-REF-*], [MEM-LIFE-*] Ownership, copyability, strict safety, reference primitives (absorbs advanced-patterns)
- **existing-infrastructure** - [INFRA-*] Catalog of typed boundary overloads, Standard Library Integration modules, Tagged functors, Ratio scaling
- **ecosystem-data-structures** - [DS-*] Complete catalog of data structures (Memory, Storage, Buffer, Collections) with selection guidance
- **testing** - [TEST-*] Umbrella: routing, test support infrastructure, file naming, suite categories
- **testing-swiftlang** - [SWIFT-TEST-*] Swift Testing framework: suites, naming, ~Copyable, async, model testing
- **testing-institute** - [INST-TEST-*] Nested package pattern for snapshot testing and swift-testing isolation
- **benchmark** - [BENCH-*] Performance testing: .timed(), .build cleanup, comparison benchmarks
- **documentation** - [DOC-001–053] Inline DocC comments, .docc catalogue conventions, code comment quality
- **readme** - [README-001–022] README structure, badges, maturity tiers, monorepo patterns
- **document-markup** - [DOC-MARKUP-*] Document creation using HTML, PDF, and Markdown rendering packages

### Process Layer
- **audit** - [AUDIT-*] Systematic compliance audit of code against skill requirement IDs
- **research-process** - [RES-*] Research workflows
- **experiment-process** - [EXP-*] Experiment workflows
- **blog-process** - [BLOG-*] Blog post workflows
- **skill-lifecycle** - [SKILL-CREATE-*], [SKILL-LIFE-*] Skill creation, update, review, and deprecation
- **package-export** - [PKG-EXPORT-*] Export packages for LLM consumption
- **collaborative-discussion** - [COLLAB-*] Claude-ChatGPT collaborative discussions
- **reflect-session** - [REFL-*] Structured post-session reflection capture
- **reflections-processing** - [REFL-PROC-*] Triage reflections into skill/doc/research improvements
- **dutch-law** - [NL-WET-*] Dutch legislation lookup via wetten.overheid.nl
- **corpus-meta-analysis** - [META-*] Corpus health: staleness, supersession, revalidation, pruning
- **quick-commit-and-push-all** - [SAVE-*] Commit and push all sub-repos to remote
- **issue-investigation** - [ISSUE-*] Systematic compiler/toolchain issue investigation: reproduce, reduce, verify, resolve
- **swift-pull-request** - [SWIFT-PR-*] Submit PRs to swiftlang/swift: fork, branch, commit, test, CI, reviewers
- **handoff** - [HANDOFF-*] Structured agent-to-agent handoff: sequential (HANDOFF.md) and branching (HANDOFF-{topic}.md)

### Legal Domain Skills (rule-law/Skills/)
- **rule-law-core** - [RL-CORE-*] Legal ecosystem manifest, skill index, loading order
- **legal-encoding** - [LEG-ENC-*, JUD-ENC-*, COMP-ENC-*, PROD-ENC-*] Statute, judiciary, composition, and product encoding patterns
- **legal-testing** - [LEG-TEST-*] Legal type testing: parametric Bool?, snapshot error descriptions, ternary logic

### Absorption History
- **naming**, **errors**, **code-organization** → absorbed into **code-surface**
- **primitives-conversions** → absorbed into **conversions**
- **design**, **anti-patterns** → absorbed into **implementation**
- **skill-creation** → absorbed into **skill-lifecycle**

---

## Loading Order

Skills are loaded based on their `requires:` DAG. The order is:

1. `swift-institute-core` (no requirements)
2. `swift-institute` (requires: swift-institute-core)
3. `code-surface` (requires: swift-institute)
4. `platform` (requires: swift-institute)
5. `memory-safety` (requires: swift-institute)
6. `modularization` (requires: swift-institute, code-surface)
7. `conversions` (requires: swift-institute)
8. `implementation` (requires: swift-institute, code-surface, conversions)
9. `existing-infrastructure` (requires: swift-institute, implementation, conversions)
10. `testing` (requires: swift-institute, code-surface)
11. `testing-swiftlang` (requires: testing)
12. `testing-institute` (requires: swift-institute-core, testing, platform)
13. `benchmark` (requires: testing)
14. `documentation` (requires: swift-institute, code-surface)
16. `readme` (requires: swift-institute)
17. Process skills (requires: swift-institute)
18. `corpus-meta-analysis` (requires: research-process, experiment-process, reflect-session)

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
