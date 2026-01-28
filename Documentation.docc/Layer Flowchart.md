# Layer Flowchart

@Metadata {
    @TitleHeading("Swift Institute")
}

A visual decision tree and reference matrix for determining which architectural layer a package belongs to.

## Overview

This document provides a visual aid for layer assignment decisions within the Five Layer Architecture. The flowchart encodes the decision logic as a series of yes/no questions, while the companion matrices provide quick-reference summaries. This is a non-normative visual aid; the authoritative layer definitions are in <doc:Five-Layer-Architecture>.

**Purpose**: Enable rapid, consistent layer classification by providing:
1. A sequential decision tree with unambiguous branching
2. A criteria matrix comparing all layers across key dimensions
3. A quick-reference table mapping conceptual questions to layers

---

## Decision Tree

The following flowchart guides layer assignment through a sequence of five questions. Start at the top and follow the branches based on your package's characteristics.

### [FLOW-001] Layer Assignment Flowchart

```
START: Does the package implement an external specification?
       (RFC, ISO, IEEE, W3C, or similar formal standard)
       │
       ├─ YES ──────────────────────────────────────────► STANDARDS
       │
       └─ NO
           │
           Does it depend on standards or other foundations?
           │
           ├─ NO ───────────────────────────────────────► PRIMITIVES
           │
           └─ YES
               │
               Does it encode significant policy or defaults?
               │
               ├─ NO ───────────────────────────────────► FOUNDATIONS
               │
               └─ YES
                   │
                   Is it intended for end users?
                   (UI, branding, workflows)
                   │
                   ├─ NO ───────────────────────────────► COMPONENTS
                   │
                   └─ YES ──────────────────────────────► APPLICATIONS
```

### Textual Decision Logic

For LLM parsing and accessibility, here is the decision tree expressed as sequential logic:

1. **Question 1**: Does the package implement an external specification (RFC, ISO, IEEE)?
   - If YES: Assign to **STANDARDS** layer. Stop.
   - If NO: Continue to Question 2.

2. **Question 2**: Does the package depend on standards-layer or foundations-layer packages?
   - If NO: Assign to **PRIMITIVES** layer. Stop.
   - If YES: Continue to Question 3.

3. **Question 3**: Does the package encode significant policy or defaults?
   - If NO: Assign to **FOUNDATIONS** layer. Stop.
   - If YES: Continue to Question 4.

4. **Question 4**: Is the package intended for end users (UI, branding, workflows)?
   - If NO: Assign to **COMPONENTS** layer. Stop.
   - If YES: Assign to **APPLICATIONS** layer. Stop.

---

## Decision Criteria Matrix

This matrix compares all five layers across key classification criteria. Use it to verify layer assignment or to understand the distinguishing characteristics of each layer.

### [FLOW-002] Criteria Comparison

| Criterion | Primitives | Standards | Foundations | Components | Applications |
|-----------|------------|-----------|-------------|------------|--------------|
| **External spec** | No | Yes | No | No | No |
| **Depends on standards** | No | Peer only | Yes | Yes | Yes |
| **Policy/defaults** | None | None | Minimal | Moderate | High |
| **Reusable** | Yes | Yes | Yes | Yes | No |
| **User-facing** | No | No | No | No | Yes |

### Criteria Definitions

- **External spec**: Package implements a formal external specification (RFC, ISO, IEEE, W3C)
- **Depends on standards**: Package has dependencies on standards-layer packages
- **Policy/defaults**: Degree to which the package embeds opinionated choices or default behaviors
- **Reusable**: Package is designed for use across multiple contexts/applications
- **User-facing**: Package directly serves end-user needs (UI, workflows, branding)

---

## Quick Reference

Use this table for rapid layer identification based on the conceptual role of a package.

### [FLOW-003] Layer Identification Guide

| Layer | Guiding Question | Package Example |
|-------|------------------|-----------------|
| **Primitives** | What must exist before anything else? | `swift-geometry-primitives` |
| **Standards** | What is specified by an external body? | `swift-iso-32000` |
| **Foundations** | What can be composed safely without policy? | `swift-json` |
| **Components** | What is reusable with embedded defaults? | `swift-http-server` |
| **Applications** | What is a complete end-user system? | Email client app |

---

## Primitives Tier Flowchart

For packages within the **Primitives** layer, use this additional flowchart to determine the correct tier (0-9).

### [FLOW-004] Tier Assignment Flowchart

```
START: Does the package have zero primitive dependencies?
│
├─ YES ─────────────────────────────────────────────────► Tier 0 (Atomic)
│
└─ NO
    │
    Does it depend only on stdlib-extensions?
    │
    ├─ YES ─────────────────────────────────────────────► Tier 1 (Foundation Layer)
    │
    └─ NO
        │
        Is it memory/buffer management?
        │
        ├─ YES (deps ≤ Tier 1) ─────────────────────────► Tier 2 (Memory/Storage)
        │
        └─ NO
            │
            Is it binary/numeric primitives?
            │
            ├─ YES (deps ≤ Tier 2) ─────────────────────► Tier 3 (Binary/Numeric)
            │
            └─ NO
                │
                Is it dimensional/unit types?
                │
                ├─ YES (deps ≤ Tier 3) ─────────────────► Tier 4 (Dimensional)
                │
                └─ NO
                    │
                    Is it linear algebra?
                    │
                    ├─ YES (deps ≤ Tier 4) ─────────────► Tier 5 (Linear Algebra)
                    │
                    └─ NO
                        │
                        Is it geometry/layout?
                        │
                        ├─ YES (deps ≤ Tier 5) ─────────► Tier 6 (Geometry)
                        │
                        └─ NO
                            │
                            Is it system abstraction?
                            │
                            ├─ YES (cross-platform) ────► Tier 7 (System)
                            ├─ YES (platform-specific) ─► Tier 8 (Platform)
                            └─ NO (parsing/infra) ──────► Tier 9 (Infrastructure)
```

### Tier Quick Reference

| Tier | Name | Key Characteristic |
|------|------|--------------------|
| 0 | Atomic | Zero primitive dependencies |
| 1 | Foundation Layer | Only stdlib-extensions |
| 2 | Memory/Storage | Memory, buffer management |
| 3 | Binary/Numeric | Bit manipulation, numbers |
| 4 | Dimensional | Units, time, regions |
| 5 | Linear Algebra | Vectors, matrices, affine |
| 6 | Geometry | Shapes, symmetry, layout |
| 7 | System | Cross-platform kernel abstractions |
| 8 | Platform | Darwin, Linux, POSIX, Windows |
| 9 | Infrastructure | Lexers, tokens, syntax |

For detailed tier definitions and package assignments, see the Primitives Tiers documentation in swift-primitives.

---

## Contribution Layer Selection

When contributing new code to the Swift Institute, use the following decision tree to determine the correct target repository and layer.

### [CONTRIB-001] Contributor Layer Decision Tree

**Scope**: Determining where a contribution belongs.

**Statement**: Contributors MUST place code in the lowest applicable layer. Types MAY be promoted upward if they prove more general than initially thought.

```
Is it a type that standards require but do not define?
+-- Yes -> swift-primitives
|   Examples: Affine transforms, binary parsers, angle types
|
+-- No
    |
    Is it implementing an international specification (ISO, RFC, IEEE)?
    +-- Yes -> swift-standards
    |   Examples: ISO 32000 (PDF), RFC 3986 (URI), IEEE 754 (floating-point)
    |
    +-- No
        |
        Is it composing standards into domain-specific building blocks?
        +-- Yes -> swift-foundations
        |   Examples: swift-pdf, swift-http, swift-crypto
        |
        +-- No
            |
            Is it an opinionated UI component or application module?
            +-- Yes -> swift-components
            |   Examples: Document viewer, network client
            |
            +-- No -> swift-applications (end-user products)
```

**Rationale**: Starting at the lowest applicable layer ensures maximum reusability and prevents coupling to higher-level concerns.

**Cross-references**: [FLOW-001], <doc:API-Requirements> [API-LAYER-001], <doc:Ecosystem-Process#ECO-EXTR-002>

---

## Cross-References

- <doc:Five-Layer-Architecture>: Authoritative layer definitions, dependency rules, and detailed characteristics
- <doc:Primitives-Tiers>: Authoritative primitives tier definitions and package assignments
- <doc:Primitives-Layering>: Decision process for tier assignment and package scoping
- <doc:API-Requirements>: Engineering patterns and requirements that apply across all layers
- <doc:Contributor-Guidelines>: Contribution workflow process