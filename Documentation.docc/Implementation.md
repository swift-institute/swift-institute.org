# Implementation

<!--
---
title: Implementation
version: 1.0.0
last_updated: 2026-01-23
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Index of all implementation requirements and patterns.

## Overview

This document serves as the index to all implementation documentation. For sequenced reading guidance, see <doc:Checklist>.

**Normative language**: All documents use RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## Document Index

### Entry Point

| Document | Purpose |
|----------|---------|
| <doc:Checklist> | Sequenced reading guide—start here |

### Design Requirements

| Document | Requirements | Focus |
|----------|--------------|-------|
| <doc:Naming> | API-NAME-001 through API-NAME-008 | Type names, nesting, identifiers |
| <doc:Errors> | API-ERR-001 through API-ERR-009 | Typed throws, error types |
| <doc:Code-Organization> | API-IMPL-001 through API-IMPL-014 | File organization, totality |
| <doc:Concurrency> | API-CONC-001 through API-CONC-012 | Async, actors, resumption, Sendable |
| <doc:Design> | API-DESIGN-001 through API-DESIGN-014 | Architectural validation |
| <doc:Layering> | API-LAYER-001 through API-LAYER-002 | Package architecture, layer separation |
| <doc:Audit-Process> | — | API audit methodology |

### Implementation Patterns

| Document | Patterns | Focus |
|----------|----------|-------|
| <doc:C-Shims> | PATTERN-001, PATTERN-018 | C shim layer structure |
| <doc:Multi-Library> | PATTERN-002, PATTERN-003 | Fine-grained libraries |
| <doc:Platform-Compilation> | PATTERN-004, PATTERN-019, PATTERN-036 | Platform conditionals |
| <doc:Swift-6> | PATTERN-005 through PATTERN-008, PATTERN-035 | Language features |
| <doc:Anti-Patterns> | PATTERN-009 through PATTERN-015 | Common mistakes |

---

## Quick Reference: Foundational Requirements

| Requirement | Domain | Summary |
|-------------|--------|---------|
| [API-NAME-001](doc:Naming#API-NAME-001) | Naming | `Nest.Name` pattern for all types |
| [API-NAME-002](doc:Naming#API-NAME-002) | Naming | No compound identifiers |
| [API-ERR-001](doc:Errors#API-ERR-001) | Errors | Typed throws throughout |
| [API-IMPL-003](doc:Code-Organization#API-IMPL-003) | Implementation | Primitives must be total |
| [API-IMPL-005](doc:Code-Organization#API-IMPL-005) | Organization | One type per file |

---

## Requirement Numbering

| Prefix | Domain | Document |
|--------|--------|----------|
| API-NAME-* | Naming | Naming.md |
| API-ERR-* | Errors | Errors.md |
| API-IMPL-* | Code organization | Code Organization.md |
| API-DESIGN-* | Design validation | Design.md |
| API-CONC-* | Concurrency | Concurrency.md |
| API-LAYER-* | Layering | Layering.md |
| PATTERN-* | Implementation patterns | Various |
| MEM-* | Memory ownership | Memory *.md |
| DOC-* | Documentation | Documentation Requirements.md |
| TEST-* | Testing | Testing Requirements.md |

---

## Topics

### Entry Point

- <doc:Checklist>

### Design Requirements

- <doc:Naming>
- <doc:Errors>
- <doc:Code-Organization>
- <doc:Concurrency>
- <doc:Design>
- <doc:Layering>
- <doc:Audit-Process>

### Implementation Patterns

- <doc:C-Shims>
- <doc:Multi-Library>
- <doc:Platform-Compilation>
- <doc:Swift-6>
- <doc:Anti-Patterns>

### Related Documents

- <doc:Memory>
- <doc:Testing-Requirements>
- <doc:Documentation-Requirements>
