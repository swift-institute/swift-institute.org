# Identity: Why "Institute"

@Metadata {
    @TitleHeading("Swift Institute")
}

Organizational identity and the reasoning behind the "institute" framing.

## Overview

This document establishes the organizational identity of the Swift Institute. It explains the naming decision, the requirements that drove it, and the stewardship model that follows from it.

**Applies to**: All packages, documentation, and communications within the Swift Institute ecosystem.

**Does not apply to**: Technical API design decisions (see <doc:API-Requirements>).

---

## [IDENT-001] The Naming Problem

**Scope**: Umbrella organization naming for Swift infrastructure.

Naming an umbrella organization for infrastructure is a consequential architectural decision. The name constrains scope, signals intent, invites or repels collaboration, and ages well or poorly.

The Swift ecosystem presents specific constraints:

- **Apple's gravity well**: Foundation, Core*, and System are semantically occupied
- **Vendor collision risks**: Names that suggest corporate ownership create confusion
- **Community expectations**: Swift infrastructure should feel neutral, not proprietary

The name functions as the top-level namespace for all work. It appears in package names, documentation, and community discussions. A poor choice creates friction; a good choice becomes invisible infrastructure.

**Cross-references**: [IDENT-002], [IDENT-003]

---

## [IDENT-002] Requirements for the Umbrella Name

**Scope**: Evaluation criteria for naming candidates.

The umbrella name must satisfy multiple requirements:

| Category | Requirement |
|----------|-------------|
| **Semantic Scope** | Represent the entire body of work, not a single layer; accommodate internal stratification |
| **Conceptual Meaning** | Imply systematic organization, stewardship, layered knowledge, long-term continuity |
| **Architectural Fit** | Compatible with layered architecture; support future expansion |
| **Legal Safety** | No collision with Apple, OpenAI, or Swift core terminology |
| **Ecosystem Signaling** | Neutral, non-corporate, academically credible |
| **LLM Interpretability** | Map cleanly to "place where structured work lives" |
| **Longevity** | Still make sense in 10-20 years |
| **Tone** | Serious but approachable; authoritative but inviting |

The name must *not* imply: a framework, a product, a company, a monolithic stack, or a closed system.

**Cross-references**: [IDENT-001], [IDENT-003]

---

## [IDENT-003] Why "Institute" Satisfies All Requirements

**Scope**: Justification for the chosen name.

The term "institute" has deep historical roots that align with the project's goals.

### Historical Precedents

**Institutes of Justinian** (533 CE): A systematic organization of Roman law into a layered, teachable structure. The parallel is direct: the Swift Institute organizes Swift infrastructure into a layered, composable structure.

**Research Institutes**: MIT, Max Planck Institute, Santa Fe Institute. Places of rigorous, long-term work that invite collaboration while maintaining standards.

**Technical Institutes**: Imply foundational education and systematic knowledge transfer.

### What "Institute" Is Not

| Term | Why It Does Not Apply |
|------|----------------------|
| **Framework** | Frameworks are consumed; institutes are participated in |
| **Product** | Products are shipped; institutes evolve |
| **Company** | Companies have customers; institutes have contributors |
| **Platform** | Platforms lock in; institutes remain open |

**Cross-references**: [IDENT-002], [IDENT-004]

---

## [IDENT-004] Canonical Definition

**Scope**: The authoritative definition of the Swift Institute.

> **The Swift Institute** is a stewarded body of layered Swift infrastructure, spanning primitives, standards, foundations, components, and applications, designed for correctness, composability, and long-term evolution.

This definition establishes three core properties:

1. **Stewarded**: Active curation rather than passive accumulation
2. **Layered**: Explicit architectural stratification with clear dependencies
3. **Long-term**: Designed for decades of evolution, not immediate convenience

**Cross-references**: [IDENT-003], [IDENT-005]

---

## [IDENT-005] Stewardship Model

**Scope**: Governance principles for the Swift Institute.

An institute implies stewardship, not ownership. This distinction shapes how the organization operates.

### Core Principles

| Principle | Description |
|-----------|-------------|
| **Curation over control** | The institute curates what belongs at each layer; it does not control all development |
| **Standards over mandates** | Layer boundaries are principled, not arbitrary |
| **Invitation over gatekeeping** | Contribution is welcomed within the architectural principles |
| **Evolution over freezing** | The structure can expand without breaking the model |

### Implications

Stewardship means accepting responsibility for long-term coherence while enabling independent contribution. The institute maintains architectural integrity; contributors maintain implementation quality.

This model enables:
- Independent package development within shared constraints
- Clear boundaries that prevent scope creep
- Sustainable growth without organizational bloat

**Cross-references**: [IDENT-004], <doc:API-Requirements>

---

## Project Goals

**Applies to**: All architectural and design decisions.

**Does not apply to**: Implementation details within individual packages.

---

### [QG-GOAL-001] Timeless Infrastructure

**Scope**: Long-term design philosophy.

**Statement**: Software MUST be designed to remain valid as compilers evolve and platforms emerge. APIs SHOULD avoid coupling to specific compiler versions or platform capabilities that may change.

**Rationale**: Infrastructure code has long operational lifetimes. Designing for timelessness reduces maintenance burden and extends useful life.

**Cross-references**: [QG-GOAL-002], [QG-GOAL-005]

---

### [QG-GOAL-002] Cross-Platform Correctness

**Scope**: Platform support requirements.

**Statement**: Code MUST exhibit consistent behavior across Darwin, Linux, Windows, and Swift Embedded. Platform-specific behavior MUST be explicitly documented and isolated.

**Rationale**: Cross-platform correctness enables the ecosystem to serve all Swift developers regardless of their target platform.

**Cross-references**: [QG-GOAL-001], [QG-GOAL-003]

---

### [QG-GOAL-003] Explicit Dependency Direction

**Scope**: Package and target architecture.

**Statement**: Each layer MUST depend only on layers below it. Circular dependencies are prohibited. Dependency direction MUST be documented and enforced through package structure.

**Rationale**: Explicit dependency direction enables independent testing, incremental adoption, and clear reasoning about change impact.

**Cross-references**: [QG-GOAL-002]

---

### [QG-GOAL-004] Sustainable Licensing Leverage

**Scope**: License selection and management.

**Statement**: License restrictions SHOULD align with policy content. Permissive licenses MAY be used for foundational primitives; restrictive licenses SHOULD be reserved for higher-value, policy-laden components.

**Rationale**: Strategic licensing enables sustainable development while maximizing ecosystem adoption.

---

### [QG-GOAL-005] AI-Friendly Architecture

**Scope**: Documentation and code structure.

**Statement**: Code SHOULD include explicit invariants and boundaries that improve automated reasoning. Documentation SHOULD follow LLM-optimization principles for machine comprehension.

**Rationale**: AI-assisted development is increasingly common. Explicit invariants help both human and machine consumers understand system behavior.

**Cross-references**: [QG-GOAL-001], <doc:LLM-Optimized-Documentation>

---

## Project Non-Goals

**Applies to**: Scope boundary decisions.

**Does not apply to**: Individual package design choices.

---

### [QG-NONGOAL-001] No Convenience Competition

**Scope**: API design philosophy.

**Statement**: The stack MUST NOT compete with Apple frameworks on convenience. The stack MUST prioritize correctness and composability over ergonomic shortcuts.

**Rationale**: Attempting to match Apple's convenience APIs would require compromising on correctness guarantees and cross-platform support.

**Cross-references**: [QG-GOAL-001], [QG-GOAL-002]

---

### [QG-NONGOAL-002] No Monolithic Ecosystem

**Scope**: Package organization.

**Statement**: Each layer MUST remain independently versioned and consumable. Packages MUST NOT require adoption of the entire ecosystem.

**Rationale**: Independent packages enable incremental adoption and reduce the barrier to entry for new consumers.

**Cross-references**: [QG-VER-001], [QG-GOAL-003]

---

### [QG-NONGOAL-003] No Premature API Freezing

**Scope**: API stability timeline.

**Statement**: APIs SHOULD NOT be marked stable (1.0.0) until they have been validated through production use. Semantic versioning MUST be used to allow controlled evolution during the pre-1.0 period.

**Rationale**: Premature freezing locks in design mistakes. The 0.x version range explicitly signals that breaking changes may occur.

**Cross-references**: [QG-VER-001]

---

## Topics

### Related Documents

- <doc:Five-Layer-Architecture>
- <doc:Quality-Assurance>
- <doc:API-Requirements>