# Five Layer Architecture

@Metadata {
    @TitleHeading("Swift Institute")
}

The organizational model: primitives, standards, foundations, components, and applications.

## Overview

The Swift Institute is organized as a five-layer architecture along two orthogonal axes: semantic irreducibility (what cannot be decomposed further) and policy introduction (where defaults, opinions, and workflows begin).

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

Every repository in the ecosystem is a standalone Swift package with its own version history, release tags, and `Package.swift`. Consumers depend on individual packages directly — a `.package(url: ...)` entry per dependency — rather than on an umbrella import. The three super-repositories (`swift-primitives`, `swift-standards`, `swift-foundations`) are git submodule aggregators that exist for browsing, not for consumption.

---

## Layer summary

| Layer | Question answered | Policy content |
|-------|-------------------|----------------|
| Primitives | What must exist? | None |
| Standards | What is specified externally? | None (externally dictated) |
| Foundations | What can be composed safely? | Minimal |
| Components | What is reusable with defaults? | Moderate |
| Applications | What is an end-user system? | High |

---

## Layer definitions

### Primitives

Irreducible, policy-free substrate.

Primitives are types that standards require but do not define: memory abstractions, atomics, async primitives, kernel and OS shims, buffers, geometric types, algebraic structures. They have minimal surface area, no defaults, and are designed to be timeless. The Primitives layer currently comprises 127 repositories.

### Standards

Faithful implementations of external normative specifications, plus domain-concept packages that converge and stabilize them.

The standards layer has two sub-layers:

**Specification implementations** — RFCs, ISO standards, protocol formats, wire encodings, cryptographic specs, file formats. Semantics are dictated externally; correctness is defined by conformance. Housed in per-authority organizations (`swift-ietf/`, `swift-w3c/`, `swift-iso/`, etc.).

**Domain-concept packages** — Converge multiple specs that define the same concept into a single canonical type, and insulate consumers from spec evolution. Housed in `swift-standards/`. For example, `swift-emailaddress-standard` unifies RFC 2822, 5321, 5322, and 6531 into a single `EmailAddress` type. Even single-spec packages like `swift-epub-standard` provide stability: when a spec is updated or obsoleted, only the `-standard` package changes internally — consumers keep importing the stable module name.

Both sub-layers are policy-free. Domain-concept packages do not add opinion or ecosystem integration — they faithfully compose externally-defined concepts. The distinction is granularity (individual spec vs. unified domain concept), not layer.

The Standards layer is split across `swift-standards` itself (for cross-body or historical packages) and per-authority organizations (swift-ietf for RFCs, swift-iso, swift-w3c, swift-whatwg, and single-package organizations for IEEE, IEC, ECMA, INCITS, ARM, Intel, RISC-V, and Microsoft).

### Foundations

Composed building blocks from primitives and standards, still policy-light.

File systems, IO abstractions, HTTP types, JSON, TLS plumbing, diagnostics, configuration parsing, logging backends, scheduling primitives. Reusable across domains, infrastructure-level, minimal defaults, no application workflows. The Foundations layer currently comprises 136 repositories.

**Distinction from Standards**: Foundations are ecosystem integrations, not implementations of external specifications. A JSON parser implements RFC 8259 (standards layer), but a configuration system that uses JSON is a foundation — it composes the standard with file I/O, validation, and type coercion. Similarly, `swift-emailaddress-standard` (standards layer) converges multiple RFCs into a canonical `EmailAddress` type, while `swift-emailaddress` (foundations layer) would integrate that type with validation middleware, database storage, and service APIs.

**Distinction from Primitives**: Foundations have dependencies on standards. A TLS foundation depends on cryptographic standards; a logging foundation may depend on timestamp standards. Primitives depend only on other primitives.

### Components

Reusable, opinionated assemblies built on foundations.

Servers, PDF rendering engines, job systems, protocol adapters, integration layers, "batteries included" subsystems. Defaults are present, trade-offs are encoded. Still reusable, but no longer irrefutable.

Components introduce opinions. A foundation provides HTTP types; a component provides an HTTP server with a specific concurrency model, timeout policy, and middleware architecture.

### Applications

End-user systems and domain workflows.

Calendar systems, reminders, email clients and services, CLIs, vertical products. Domain-specific, user-facing, with branding and UX. Not intended as general infrastructure.

---

## Repository organization

The Swift Institute comprises multiple GitHub organizations. The standards layer spans multiple organizations — one per standards body plus one for domain-concept packages:

| Layer | GitHub organization | Repository pattern | Example |
|-------|---------------------|-------------------|---------|
| Primitives | `swift-primitives` | `swift-*-primitives` | `swift-geometry-primitives` |
| Standards (specs) | `swift-ietf`, `swift-w3c`, `swift-iso`, `swift-ieee`, `swift-iec`, `swift-ecma`, `swift-whatwg`, `swift-incits` | `swift-{spec-id}` | `swift-rfc-3986`, `swift-iso-32000`, `swift-w3c-css` |
| Standards (domain concepts) | `swift-standards` | `swift-{concept}-standard` | `swift-emailaddress-standard`, `swift-pdf-standard` |
| Foundations | `swift-foundations` | `swift-*` (clean names) | `swift-json`, `swift-logging` |
| Components | `swift-components` | `swift-*` or product names | `swift-pdf-rendering` |
| Applications | Product-specific | Product names | Domain-specific |

### Domain concept packaging

A domain concept may span up to four tiers across the architecture:

```
swift-foundations/swift-{concept}              Layer 3   Ecosystem integration (volatile)
         ↑
swift-standards/swift-{concept}-standard       Layer 2   Convergence + stability (stable)
         ↑
swift-{body}/swift-{spec-id}                   Layer 2   Spec implementation (stable)
         ↑
swift-primitives/swift-{concept}-primitives    Layer 1   Primitive concept (when applicable)
```

Not every domain concept has all four tiers. The domain shape determines which tiers exist:

| Shape | Primitives | Spec implementations | `-standard` | Foundations | Example |
|-------|-----------|---------------------|-------------|-------------|---------|
| Primitive-first, multi-spec | Yes | Multiple | Convergence + stability | Yes | Time |
| Standard-first, multi-spec | No | Multiple | Convergence + stability | Yes | EmailAddress |
| Standard-first, single-spec | No | One | Stability only | Yes | EPUB |
| Mixed | Partial | Multiple, cross-body | Convergence + stability | Yes | Color |

The stable-vs-volatile separation is central: spec implementations and `-standard` packages rarely change, since specifications are stable documents. Foundations packages change frequently as ecosystem integrations evolve. This separation ensures that a Mailgun API change does not touch `swift-emailaddress-standard`, and a new RFC version does not touch `swift-emailaddress` at the foundations layer.

The `swift-institute` organization itself serves as the umbrella identity and documentation home, not a package publisher. This separation delivers:

- Clear layer boundaries — organization membership immediately signals layer
- Independent versioning — each layer evolves at its own pace
- Focused governance — layer-specific maintainers and review standards

---

## Licensing strategy

The five-layer model enables a licensing strategy aligned with semantic responsibility:

| Layer | Primary license | Commercial option | Rationale |
|-------|-----------------|-------------------|-----------|
| Primitives | Apache 2.0 | No | Maximum embeddability |
| Standards | Apache 2.0 | No | Ubiquity and trust |
| Foundations | Apache 2.0 | Selective | Adoption and leverage |
| Components | Flexible | Yes | Monetization boundary |
| Applications | Commercial | N/A | Products, not infrastructure |

Licensing leverage increases as policy content increases.

Primitives and Standards must be embeddable everywhere. Any restriction at these layers would fragment the ecosystem and undermine composability. These are infrastructure in the strongest sense — value comes from ubiquity, not scarcity.

Foundations are where real value accumulates, but reuse must remain frictionless. An Apache baseline ensures adoption; optional commercial terms preserve long-term leverage for embedding, redistribution, or enterprise guarantees.

Components are the natural monetization boundary. They are valuable precisely because they encode decisions worth paying for. Keeping them distinct from foundations avoids contaminating lower layers with policy.

Applications are products, not infrastructure. They benefit from being built on a permissive stack but do not need to be permissive themselves.

This alignment avoids two failure modes:

1. Over-restriction at the base — licensing primitives restrictively fragments the ecosystem
2. Under-monetization at the top — giving away all components forfeits sustainable leverage

## Topics

### Related

- <doc:Glossary>
- <doc:Identity>
- <doc:FAQ>
