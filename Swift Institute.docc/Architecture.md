# Architecture

@Metadata {
    @TitleHeading("Swift Institute")
}

The organizational and architectural model of the Swift Institute ecosystem — why it looks the way it does, and how the parts fit together.

## Overview

The Swift Institute is a stewarded body of layered Swift infrastructure — primitives, standards, foundations, components, and applications — designed for correctness, composability, and long-term evolution.

Three design decisions shape the architecture:

1. **Separate what cannot change from what must evolve.** A coordinate type is a mathematical concept — it should be stable for decades. An HTTP server composes OS syscalls and evolves with platform support. Bundling them forces everything to move at the speed of the most volatile piece.

2. **Dependencies flow one way.** Each layer depends only on layers below it. Circular dependencies are prohibited. This enables independent testing, incremental adoption, and clear reasoning about change impact.

3. **Licensing aligns with policy content.** Permissive licenses cover foundational substrate where value comes from ubiquity. More flexible terms are reserved for higher layers where policy and opinion accumulate.

---

## Why "Institute"

The term was chosen deliberately. "Institute" signals stewardship rather than ownership; a body of work rather than a product; long-term continuity rather than a release cycle.

The Institutes of Justinian (533 CE) systematically organized Roman law into a layered, teachable structure. Research institutes like MIT, Max Planck, and Santa Fe are places of rigorous long-term work that invite collaboration while maintaining standards. Both parallels are intentional.

| Term | Why it does not apply |
|------|----------------------|
| Framework | Frameworks are consumed; institutes are participated in |
| Product | Products are shipped; institutes evolve |
| Company | Companies have customers; institutes have contributors |
| Platform | Platforms lock in; institutes remain open |

The organization curates what belongs at each layer; it does not control all development. Layer boundaries are principled, not arbitrary. Contribution is welcomed within the architectural principles. The structure can expand without breaking the model.

---

## The three active layers

Three layers carry released packages as of this alpha:

### Primitives

Irreducible, policy-free substrate. Types that standards require but do not define — memory abstractions, atomics, async primitives, kernel and OS shims, buffers, geometric types, algebraic structures. Minimal surface area, no defaults, designed to be timeless.

Released at the [swift-primitives](https://github.com/swift-primitives) organization. See <doc:Swift-Primitives> for details.

### Standards

Faithful implementations of external normative specifications (RFCs, ISO standards, protocol formats, file formats), plus domain-concept packages that converge and stabilize them. Semantics are dictated externally; correctness is defined by conformance.

Standards span multiple organizations — one per authority body plus one aggregator for cross-body and convergence packages. See <doc:Swift-Standards> for details.

### Foundations

Composed building blocks from primitives and standards. File systems, IO abstractions, HTTP stacks, data formats, TLS plumbing, diagnostics, logging backends, schedulers. Reusable across domains, infrastructure-level, minimal defaults.

Released at the [swift-foundations](https://github.com/swift-foundations) organization. See <doc:Swift-Foundations> for details.

---

## The full five-layer design

The architecture supports two additional layers that are not yet released:

- **Components** (planned) — Reusable, opinionated assemblies built on foundations. Servers, rendering engines, job systems, protocol adapters. Defaults are present, trade-offs are encoded.
- **Applications** (planned) — End-user systems and domain workflows. Calendar systems, email clients, CLIs, vertical products.

```
┌─────────────────────────────────────────────────┐
│  Applications     Commercial / Proprietary      │   planned
│  End-user products                              │
└─────────────────────────────────────────────────┘
                        ↑
┌─────────────────────────────────────────────────┐
│  Components        Flexible licensing           │   planned
│  Opinionated assemblies                         │
└─────────────────────────────────────────────────┘
                        ↑
┌─────────────────────────────────────────────────┐
│  Foundations       Apache 2.0 + selective       │   released
│  Composed building blocks                       │
└─────────────────────────────────────────────────┘
                        ↑
┌─────────────────────────────────────────────────┐
│  Standards         Apache 2.0 only              │   released
│  Specification implementations                  │
└─────────────────────────────────────────────────┘
                        ↑
┌─────────────────────────────────────────────────┐
│  Primitives        Apache 2.0 only              │   released
│  Atomic building blocks                         │
└─────────────────────────────────────────────────┘
```

| Layer | Question answered | Policy content |
|-------|-------------------|----------------|
| Primitives | What must exist? | None |
| Standards | What is specified externally? | None (externally dictated) |
| Foundations | What can be composed safely? | Minimal |
| Components | What is reusable with defaults? | Moderate |
| Applications | What is an end-user system? | High |

Every repository is a standalone Swift package with its own version history, release tags, and `Package.swift`. Consumers depend on individual packages directly — a `.package(url: ...)` entry per dependency — rather than on an umbrella import. The superrepos (`swift-primitives`, `swift-standards`, `swift-foundations`) are git submodule aggregators that exist for browsing, not for consumption.

---

## Organizations

The Swift Institute comprises multiple GitHub organizations. Each organization has a specific purpose; membership signals layer and authority at a glance.

| Organization | Purpose | Repository pattern |
|--------------|---------|-------------------|
| [swift-primitives](https://github.com/swift-primitives) | Primitives layer | `swift-{concept}-primitives` |
| [swift-ietf](https://github.com/swift-ietf) | IETF RFC implementations | `swift-rfc-{number}` |
| [swift-iso](https://github.com/swift-iso) | ISO standard implementations | `swift-iso-{number}` |
| [swift-w3c](https://github.com/swift-w3c) | W3C specification implementations | `swift-w3c-{name}` |
| [swift-whatwg](https://github.com/swift-whatwg) | WHATWG specification implementations | `swift-whatwg-{name}` |
| Single-body organizations | IEEE, IEC, ECMA, INCITS, ARM, Intel, RISC-V, Microsoft | Per-authority |
| [swift-standards](https://github.com/swift-standards) | Standards convergence + cross-body concepts | `swift-{concept}-standard` |
| [swift-foundations](https://github.com/swift-foundations) | Foundations layer | `swift-*` (clean names) |
| [swift-institute](https://github.com/swift-institute) | Documentation home | Not a package publisher |

The `swift-institute` organization itself serves as the umbrella identity and documentation home. This separation between identity and packaging delivers clear layer boundaries, independent versioning, and focused governance.

### Per-domain layering

A single domain concept may span up to four tiers across the architecture:

```
swift-foundations/swift-{concept}              Layer 3   Ecosystem integration
         ↑
swift-standards/swift-{concept}-standard       Layer 2   Convergence + stability
         ↑
swift-{body}/swift-{spec-id}                   Layer 2   Spec implementation
         ↑
swift-primitives/swift-{concept}-primitives    Layer 1   Primitive concept
```

Not every domain has all four tiers. `EmailAddress`, for example, has no primitive-layer package but has multiple RFC implementations (2822, 5321, 5322, 6531) converged into `swift-emailaddress-standard`, then integrated in `swift-emailaddress` at the foundations layer.

The stable-vs-volatile separation is central: spec implementations and `-standard` packages rarely change, since specifications are stable documents. Foundations packages change frequently as ecosystem integrations evolve. A Mailgun API change does not touch `swift-emailaddress-standard`, and a new RFC revision does not touch `swift-emailaddress` at the foundations layer.

---

## Licensing strategy

Licensing aligns with semantic responsibility:

| Layer | Primary license | Commercial option | Rationale |
|-------|-----------------|-------------------|-----------|
| Primitives | Apache 2.0 | No | Maximum embeddability |
| Standards | Apache 2.0 | No | Ubiquity and trust |
| Foundations | Apache 2.0 | Selective | Adoption and leverage |
| Components | Flexible | Yes | Monetization boundary |
| Applications | Commercial | N/A | Products, not infrastructure |

Primitives and Standards must be embeddable everywhere. Any restriction at these layers would fragment the ecosystem — value comes from ubiquity, not scarcity.

Foundations are where real value accumulates, but reuse must remain frictionless. An Apache baseline ensures adoption; optional commercial terms preserve long-term leverage for embedding, redistribution, or enterprise guarantees.

Components are the natural monetization boundary. They are valuable precisely because they encode decisions worth paying for. Keeping them distinct from foundations avoids contaminating lower layers with policy.

Applications are products, not infrastructure. They benefit from being built on a permissive stack but do not need to be permissive themselves.

Every repository carries its own `LICENSE.md`. Licensing leverage increases as policy content increases.

---

## Project goals

### Timeless infrastructure

Software is designed to remain valid as compilers evolve and platforms emerge. APIs avoid coupling to specific compiler versions or platform capabilities that may change. Infrastructure code has long operational lifetimes; designing for timelessness reduces maintenance burden and extends useful life.

### Cross-platform correctness

Code is expected to exhibit consistent behavior across Darwin, Linux, Embedded Swift, and Windows. Platform-specific behavior is explicitly documented and isolated. See <doc:Platform>.

### Explicit dependency direction

Each layer depends only on layers below it. Circular dependencies are prohibited. Dependency direction is documented and enforced through package structure.

### AI-assisted development

Code includes explicit invariants and boundaries that improve automated reasoning. Ecosystem conventions are captured as Skills — structured documents describing naming, error handling, memory safety, testing, and related practices — that both humans and AI tooling consume.

---

## Project non-goals

### No convenience competition

The stack does not compete with Apple frameworks on convenience. Correctness and composability take precedence over ergonomic shortcuts.

### No monolithic ecosystem

Each package is independently versioned and consumable. No package requires adoption of the entire ecosystem.

### No premature API freezing

APIs are not marked stable (1.0.0) until they have been validated through production use. The 0.x version range explicitly signals that breaking changes may still occur.
