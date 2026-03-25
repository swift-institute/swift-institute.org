---
name: swift-institute
description: |
  Five-layer architecture and core conventions for Swift Institute.
  ALWAYS apply when working in any Swift Institute repository.

layer: architecture

requires:
  - swift-institute-core

applies_to:
  - swift
  - swift6
  - swift-primitives
  - swift-standards
  - swift-foundations
last_reviewed: 2026-03-20
---

# Swift Institute Conventions

Core architectural conventions for all Swift Institute packages.

---

## Five-Layer Architecture

```
Layer 5: Applications    (Commercial)   - End-user products
              ↑
Layer 4: Components      (Flexible)     - Opinionated assemblies
              ↑
Layer 3: Foundations     (Apache 2.0)   - Composed building blocks
              ↑
Layer 2: Standards       (Apache 2.0)   - Specification implementations
              ↑
Layer 1: Primitives      (Apache 2.0)   - Atomic building blocks
```

### [ARCH-LAYER-001] Dependency Direction

Packages MUST depend only on layers below them. Upward and lateral dependencies are FORBIDDEN.

| Layer | Question Answered | Examples |
|-------|-------------------|----------|
| Primitives | What must exist? | Buffer, Geometry, Time |
| Standards | What is specified externally? | ISO 32000, RFC 3986 |
| Foundations | What can be composed safely? | File I/O, JSON, TLS |
| Components | What is reusable with defaults? | PDF rendering, HTTP |
| Applications | What is an end-user system? | Products |

---

## Collaboration Protocol

You are a co-architect on production infrastructure. Requirements:

1. **Challenge implementations** - If you see issues, say so directly
2. **Cite specific lines** - Reference exact file paths and line numbers
3. **No drift** - Deviation from converged design requires explicit discussion
4. **Complete answers** - Do not summarize or abbreviate
5. **Ask before assuming** - If ambiguous, ask

This is "timeless infrastructure" quality. Treat every decision as permanent.

---

## Semantic Dependencies

Package dependencies are classified as Implementation (IDG) or Semantic (SDG). Key rules:

| Rule | Statement |
|------|-----------|
| [SEM-DEP-006] | Distinguish essential vs incidental relationships |
| [SEM-DEP-008] | Join-point packages resolve domain conflicts |
| [SEM-DEP-009] | Package dependencies MUST be essential; orthogonal integrations require separate packages |

For full rules, see `Documentation.docc/Semantic Dependencies.md`.

---

## Cross-References

Child skills:
- **code-surface** - Naming, error handling, and file structure rules
- **memory** - Ownership and copyability rules
- **design** - API design, layering, semantic dependencies

Repository-specific:
- **primitives** (in swift-primitives) - Primitives layer conventions
