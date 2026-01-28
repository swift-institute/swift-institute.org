# Five Layer Architecture

<!--
---
title: Five Layer Architecture
version: 1.0.0
last_updated: 2026-01-28
applies_to: [swift-primitives, swift-standards, swift-foundations, swift-components]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

The foundational architecture for all Swift Institute packages.

## Overview

Swift Institute organizes code into five distinct layers, each with clear responsibilities and dependency rules.

---

## Layer Diagram

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

---

## Layer Definitions

### [ARCH-LAYER-001] Dependency Direction

**Statement**: Packages MUST depend only on layers below them. Upward and lateral dependencies are forbidden.

### Layer Descriptions

| Layer | Question Answered | Examples |
|-------|-------------------|----------|
| Primitives | What must exist? | Buffer, Geometry, Time |
| Standards | What is specified externally? | ISO 32000, RFC 3986 |
| Foundations | What can be composed safely? | File I/O, JSON, TLS |
| Components | What is reusable with defaults? | PDF rendering, HTTP servers |
| Applications | What is an end-user system? | Products |

---

## Primitives (Layer 1)

Atomic, policy-free building blocks.

**Characteristics**:
- No Foundation imports ([PRIM-FOUND-001])
- Mechanism over policy
- Zero external dependencies within tier 0
- Nine-tier internal hierarchy

**Package Location**: `/Users/coen/Developer/swift-primitives/`

---

## Standards (Layer 2)

Implementations of external specifications.

**Characteristics**:
- Mirror specification terminology exactly
- Reference specification section numbers
- May depend on primitives only

**Package Location**: `/Users/coen/Developer/swift-standards/`

---

## Foundations (Layer 3)

Composed building blocks without policy.

**Characteristics**:
- Compose primitives and standards
- Provide ergonomic APIs
- Remain policy-free

**Package Location**: `/Users/coen/Developer/swift-foundations/`

---

## Components (Layer 4)

Opinionated, reusable assemblies.

**Characteristics**:
- Make policy decisions
- Provide defaults
- Ready for integration

---

## Applications (Layer 5)

End-user products.

**Characteristics**:
- Commercial licensing allowed
- Full policy decisions
- Complete systems

---

## Topics

### Related
- <doc:Semantic-Dependencies>
- <doc:Implementation>
