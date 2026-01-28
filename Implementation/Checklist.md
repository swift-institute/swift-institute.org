# Implementation Checklist

<!--
---
title: Implementation Checklist
version: 1.0.0
last_updated: 2026-01-28
applies_to: [swift-primitives, swift-standards, swift-foundations]
normative: true
---
-->

@Metadata {
    @TitleHeading("Implementation")
}

Entry point for all implementation tasks. Follow the reading path for your layer.

## Overview

Before starting any implementation task, follow the appropriate reading path below.

---

## Reading Paths

### Primitives Layer

1. <doc:Naming> - [API-NAME-*] rules
2. <doc:Errors> - [API-ERR-*] rules
3. <doc:Code-Organization> - [API-IMPL-*] rules
4. <doc:Memory-Copyable> - [MEM-COPY-*] for ~Copyable types
5. Primitives Tiers (swift-primitives) - Tier assignment
6. Primitives Layering (swift-primitives) - Package scoping

### Standards Layer

1. <doc:Naming> - Specification-mirroring names
2. <doc:Errors> - Typed throws
3. <doc:Code-Organization> - File structure
4. <doc:Five-Layer-Architecture> - Layer rules

### Foundations Layer

1. <doc:Naming> - API naming
2. <doc:Errors> - Error handling
3. <doc:Design> - Design validation
4. <doc:Five-Layer-Architecture> - Dependency rules

---

## Quick Reference

| Task | Document |
|------|----------|
| Naming types | <doc:Naming> |
| Error handling | <doc:Errors> |
| File organization | <doc:Code-Organization> |
| Concurrency | <doc:Concurrency> |
| ~Copyable support | <doc:Memory-Copyable> |
| Package layering | <doc:Layering> |

---

## Topics

### Implementation Documents
- <doc:Naming>
- <doc:Errors>
- <doc:Code-Organization>
- <doc:Concurrency>
- <doc:Design>
- <doc:Layering>
