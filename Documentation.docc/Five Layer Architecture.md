# Five Layer Architecture

@Metadata {
    @TitleHeading("Swift Institute")
}

The core organizational model: primitives, standards, foundations, components, and applications.

## Overview

The Swift Institute is organized as a five-layer architecture along two orthogonal axes: **semantic irreducibility** (what cannot be decomposed further) and **policy introduction** (where defaults, opinions, and workflows begin).

```
┌─────────────────────────────────────────────────────────┐
│                    swift-institute                       │
│         Stewarded body of layered Swift infrastructure   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌─────────────────────────────────────────────────┐   │
│   │  Applications     Commercial / Proprietary      │   │
│   │  (Email clients, Calendar systems)              │   │
│   │  End-user products                              │   │
│   └─────────────────────────────────────────────────┘   │
│                          ↑                              │
│   ┌─────────────────────────────────────────────────┐   │
│   │  Components        Flexible licensing           │   │
│   │  (PDF rendering, HTTP servers, Jobs)            │   │
│   │  Opinionated assemblies                         │   │
│   └─────────────────────────────────────────────────┘   │
│                          ↑                              │
│   ┌─────────────────────────────────────────────────┐   │
│   │  Foundations       Apache 2.0 + selective       │   │
│   │  (File I/O, JSON, TLS, Logging)                 │   │
│   │  Composed building blocks                       │   │
│   └─────────────────────────────────────────────────┘   │
│                          ↑                              │
│   ┌─────────────────────────────────────────────────┐   │
│   │  Standards         Apache 2.0 only              │   │
│   │  (ISO 32000, RFC 3986, IEEE 754)                │   │
│   │  Specification implementations                  │   │
│   └─────────────────────────────────────────────────┘   │
│                          ↑                              │
│   ┌─────────────────────────────────────────────────┐   │
│   │  Primitives        Apache 2.0 only              │   │
│   │  (Buffer, Geometry, Algebra, Time)              │   │
│   │  Atomic building blocks                         │   │
│   └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Layer Summary

| Layer | Question Answered | Policy Content |
|-------|-------------------|----------------|
| **Primitives** | What must exist? | None |
| **Standards** | What is specified externally? | None (externally dictated) |
| **Foundations** | What can be composed safely? | Minimal |
| **Components** | What is reusable with defaults? | Moderate |
| **Applications** | What is an end-user system? | High |

---

## Layer Definitions

### Primitives

**Role**: Irreducible, policy-free substrate.

Primitives are types that standards require but do not define. Memory abstractions, atomics, async primitives, kernel/OS shims, buffers, geometric types, algebraic structures. They have minimal surface area, no defaults, and are designed to be timeless.

### Standards

**Role**: Faithful implementations of external normative specifications.

RFCs, ISO standards, protocol formats, wire encodings, cryptographic specs, file formats. Semantics are dictated externally; correctness is defined by conformance.

### Foundations

**Role**: Composed building blocks from primitives + standards, still policy-light.

File systems, IO abstractions, HTTP types, JSON, TLS plumbing, diagnostics, configuration parsing, logging backends, scheduling primitives. Reusable across domains, infrastructure-level, minimal defaults, no application workflows.

**Distinction from Standards**: Foundations are *compositions*, not implementations of external specifications. A JSON parser implements RFC 8259 (standards layer), but a configuration system that uses JSON is a foundation—it composes the standard with file I/O, validation, and type coercion.

**Distinction from Primitives**: Foundations have dependencies on standards. A TLS foundation depends on cryptographic standards; a logging foundation may depend on timestamp standards. Primitives depend only on other primitives.

### Components

**Role**: Reusable, opinionated assemblies built on foundations.

Servers, PDF rendering engines, job systems, protocol adapters, integration layers, "batteries included" subsystems. Defaults are present, trade-offs are encoded. Still reusable, but no longer irrefutable.

**The Policy Boundary**: Components introduce opinions. A foundation provides HTTP types; a component provides an HTTP server with a specific concurrency model, timeout policy, and middleware architecture.

### Applications

**Role**: End-user systems and domain workflows.

Calendar systems, reminders, email clients/services, CLIs, vertical products. Domain-specific, user-facing, branding and UX matter. Not intended as general infrastructure.

---

## Repository Organization

The Swift Institute comprises multiple GitHub organizations, one per layer:

| Layer | GitHub Organization | Repository Pattern | Example |
|-------|---------------------|-------------------|---------|
| **Primitives** | `swift-primitives` | `swift-*-primitives` | `swift-geometry-primitives` |
| **Standards** | `swift-standards` | `swift-{spec-id}` | `swift-iso-32000`, `swift-rfc-3986` |
| **Foundations** | `swift-foundations` | `swift-*` (clean names) | `swift-json`, `swift-logging` |
| **Components** | `swift-components` | `swift-*` or product names | `swift-pdf-rendering` |
| **Applications** | Product-specific | Product names | Domain-specific |

The `swift-institute` organization itself serves as the umbrella identity and documentation home, not a package publisher. This separation ensures:

- **Clear layer boundaries**: Organization membership immediately signals layer
- **Independent versioning**: Each layer can evolve at its own pace
- **Focused governance**: Layer-specific maintainers and review standards

---

## Licensing Strategy

The five-layer model enables precise licensing strategy aligned with semantic responsibility:

| Layer | Primary License | Commercial Option | Rationale |
|-------|-----------------|-------------------|-----------|
| **Primitives** | Apache 2.0 | No | Maximum embeddability |
| **Standards** | Apache 2.0 | No | Ubiquity and trust |
| **Foundations** | Apache 2.0 | Selective | Adoption + leverage |
| **Components** | Flexible | Yes | Monetization boundary |
| **Applications** | Commercial | N/A | Products, not infrastructure |

**Key insight**: Licensing leverage increases as policy content increases.

**Primitives and Standards** must be embeddable everywhere. Any restriction at these layers would fragment the ecosystem and undermine composability. These are infrastructure in the strongest sense—value comes from ubiquity, not scarcity.

**Foundations** are where real value accumulates, but reuse must remain frictionless. An Apache baseline ensures adoption; optional commercial terms preserve long-term leverage for embedding, redistribution, or enterprise guarantees.

**Components** are the natural monetization boundary. They are valuable precisely because they encode decisions worth paying for. Keeping them distinct from foundations avoids contaminating lower layers with policy.

**Applications** are products, not infrastructure. They benefit from being built on a permissive stack but do not need to be permissive themselves.

This alignment avoids two failure modes:
1. **Over-restriction at the base**: Licensing primitives restrictively fragments the ecosystem
2. **Under-monetization at the top**: Giving away all components forfeits sustainable leverage

