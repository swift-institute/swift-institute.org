# Identity: Why "Institute"

@Metadata {
    @TitleHeading("Swift Institute")
}

Organizational identity and the reasoning behind the "institute" framing.

## Overview

Naming an umbrella organization for infrastructure is an architectural decision. The name constrains scope, signals intent, and ages well or poorly. This document explains why "Swift Institute" was chosen and what the name commits to.

---

## The naming problem

The Swift ecosystem presents specific constraints:

- Apple's gravity well: `Foundation`, `Core*`, and `System` are semantically occupied
- Vendor collision risks: names that suggest corporate ownership create confusion
- Community expectations: Swift infrastructure should read as neutral, not proprietary

The umbrella name functions as a top-level namespace for all work across the ecosystem. It appears in package names, documentation, and community discussions. A poor choice creates friction; a good choice becomes invisible.

---

## Requirements for the name

The umbrella name had to satisfy several criteria at once:

| Category | Requirement |
|----------|-------------|
| Semantic scope | Represent the entire body of work, not a single layer; accommodate internal stratification |
| Conceptual meaning | Imply systematic organization, stewardship, layered knowledge, long-term continuity |
| Architectural fit | Compatible with a layered architecture; support future expansion |
| Legal safety | No collision with Apple, OpenAI, or Swift core terminology |
| Ecosystem signaling | Neutral, non-corporate, academically credible |
| Interpretability | Map cleanly to "place where structured work lives" |
| Longevity | Still make sense in 10–20 years |
| Tone | Serious but approachable; authoritative but inviting |

The name must not imply a framework, a product, a company, a monolithic stack, or a closed system.

---

## Why "Institute" works

The term "institute" has historical roots that align with the project's goals.

The Institutes of Justinian (533 CE) systematically organized Roman law into a layered, teachable structure. The parallel is direct: the Swift Institute organizes Swift infrastructure into a layered, composable structure.

Research institutes — MIT, Max Planck, Santa Fe — are places of rigorous, long-term work that invite collaboration while maintaining standards. Technical institutes imply foundational education and systematic knowledge transfer.

What "institute" is not:

| Term | Why it does not apply |
|------|----------------------|
| Framework | Frameworks are consumed; institutes are participated in |
| Product | Products are shipped; institutes evolve |
| Company | Companies have customers; institutes have contributors |
| Platform | Platforms lock in; institutes remain open |

---

## Canonical definition

The Swift Institute is a stewarded body of layered Swift infrastructure, spanning primitives, standards, foundations, components, and applications, designed for correctness, composability, and long-term evolution.

This definition establishes three core properties:

1. Stewarded — active curation rather than passive accumulation
2. Layered — explicit architectural stratification with clear dependencies
3. Long-term — designed for decades of evolution, not immediate convenience

---

## Stewardship model

An institute implies stewardship, not ownership. This distinction shapes how the organization operates.

| Principle | Description |
|-----------|-------------|
| Curation over control | The institute curates what belongs at each layer; it does not control all development |
| Standards over mandates | Layer boundaries are principled, not arbitrary |
| Invitation over gatekeeping | Contribution is welcomed within the architectural principles |
| Evolution over freezing | The structure can expand without breaking the model |

Stewardship means accepting responsibility for long-term coherence while enabling independent contribution. The institute maintains architectural integrity; contributors maintain implementation quality.

This model enables:

- Independent package development within shared constraints
- Clear boundaries that prevent scope creep
- Sustainable growth without organizational bloat

---

## Project goals

### Timeless infrastructure

Software is designed to remain valid as compilers evolve and platforms emerge. APIs avoid coupling to specific compiler versions or platform capabilities that may change. Infrastructure code has long operational lifetimes, and designing for timelessness reduces maintenance burden and extends useful life.

### Cross-platform correctness

Code is expected to exhibit consistent behavior across Darwin, Linux, Windows, and Embedded Swift. Platform-specific behavior is explicitly documented and isolated. Cross-platform correctness lets the ecosystem serve Swift developers regardless of target.

### Explicit dependency direction

Each layer depends only on layers below it. Circular dependencies are prohibited. Dependency direction is documented and enforced through package structure. Explicit dependency direction enables independent testing, incremental adoption, and clear reasoning about change impact.

### Sustainable licensing leverage

License restrictions align with policy content. Permissive licenses cover foundational primitives and standards; more restrictive terms are reserved for higher-value, policy-laden components. Strategic licensing enables sustainable development while maximizing ecosystem adoption. See <doc:Five-Layer-Architecture>.

### AI-assisted development

Code includes explicit invariants and boundaries that improve automated reasoning. AI-assisted development is increasingly common, and explicit invariants help both human and machine consumers understand system behavior. The ecosystem's conventions are also captured as Skills — structured, machine-readable documents under `Skills/` that describe naming, error handling, memory safety, testing, and related practices.

---

## Project non-goals

### No convenience competition

The stack does not compete with Apple frameworks on convenience. Correctness and composability take precedence over ergonomic shortcuts. Matching Apple's convenience APIs would require compromising on correctness guarantees and cross-platform support.

### No monolithic ecosystem

Each package is independently versioned and consumable. No package requires adoption of the entire ecosystem. Independent packages enable incremental adoption and reduce the barrier to entry for new consumers.

### No premature API freezing

APIs are not marked stable (1.0.0) until they have been validated through production use. The 0.x version range explicitly signals that breaking changes may still occur. Premature freezing locks in design mistakes.

---

## Topics

### Related

- <doc:Five-Layer-Architecture>
- <doc:Glossary>
- <doc:FAQ>
