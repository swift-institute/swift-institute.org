# Glossary

@Metadata {
    @TitleHeading("Swift Institute")
}

## Overview

This glossary defines the vocabulary used across Swift Institute documentation. Terms are grouped by domain. When a term defined here appears in documentation elsewhere in the ecosystem, it carries the meaning described below.

---

## Architecture layers

Terms describing the layered architecture model used in Swift Institute packages. See [Five Layer Architecture](Five%20Layer%20Architecture.md) for the full treatment.

---

### Primitive (Layer 1)

An atomic building block: a type that is irreducible, policy-free, and not defined in terms of other types. Primitives are types that standards require but do not define. The Primitives layer is organized by semantic irreducibility.

Characteristics:

- Zero policy, zero platform choice
- Minimal tokens, IDs, events, handles
- Total in implementation

---

### Standard (Layer 2)

A faithful implementation of an external normative specification (RFC, ISO, IEEE, W3C, WHATWG, etc.). Semantics are dictated by the external specification, not by implementation convenience. Standards depend only on Primitives.

Examples: RFC 3986 (URI), ISO 32000 (PDF), IEEE 754 (floating-point).

---

### Foundation (Layer 3)

A composed building block constructed from Primitives and Standards. Foundations are reusable across domains with minimal defaults and no application-specific workflows. Not to be confused with Apple's Foundation framework.

Characteristics:

- Composes lower layers
- Reusable across domains
- Minimal policy introduction

---

### Component (Layer 4)

A reusable, opinionated assembly built on Foundations. Components encode defaults and trade-offs but remain reusable across applications. This layer marks the policy boundary where opinions begin to be introduced.

Characteristics:

- Encodes defaults and trade-offs
- Remains reusable
- Introduces policy

---

### Application (Layer 5)

An end-user system with domain-specific workflows, branding, and UX. Applications are not intended as general infrastructure and are built on Components and lower layers.

Characteristics:

- Domain-specific workflows
- End-user facing
- Not reusable as infrastructure

---

### Policy boundary

The point in the layer stack where defaults and opinions begin to be introduced. This occurs at the Components layer (Layer 4). Layers below the policy boundary (Primitives, Standards, Foundations) do not introduce policy.

---

### Semantic irreducibility

The property of types that cannot be decomposed further into simpler constituent types without losing meaning. Semantic irreducibility is the organizing principle for the Primitives layer.

---

## Naming conventions

### Nest.Name

The naming convention used across the ecosystem: types are organized by nesting rather than by compound names. Instead of `FileDirectoryWalk`, the ecosystem uses `File.Directory.Walk`; instead of `NonBlockingSelector`, `IO.NonBlocking.Selector`.

The convention extends to methods and properties: nested accessors such as `instance.open.write { }` or `dir.walk.files()` replace compound method names such as `instance.openWrite { }` or `dir.walkFiles()`.

Types implementing external specifications use specification-mirroring names: `RFC_4122.UUID`, `ISO_32000.Page`, `RFC_3986.URI`. The specification namespace is part of the type identity.

---

## Type system concepts

Terms describing Swift type system features and patterns used in Swift Institute packages.

---

### Noncopyable type

A Swift type marked `~Copyable` that cannot be implicitly copied. Noncopyable types enable move semantics and are used to model resources that must have exactly one owner (handles, tokens, capabilities).

Noncopyable values cannot be embedded in types conforming to `Error`, because `Swift.Error` requires `Copyable`.

---

### Phantom type

A type parameter that appears in a type signature but has no runtime representation. Phantom types are used for compile-time tagging, enabling type-safe distinctions without runtime overhead.

Example: `Geometry<Double, PageSpace>` where `PageSpace` is a phantom type parameter distinguishing coordinate spaces.

---

### Typestate

A pattern where different states of an object are represented as different types. Typestate makes invalid state transitions unrepresentable at compile time.

Example: `UnregisteredToken` and `RegisteredToken` as distinct types rather than a single `Token` with an `isRegistered` flag.

---

### Receipt

A runnable artifact that verifies a documentation claim. Experiments in the ecosystem are structured as receipts: each is a Swift package that exercises one investigation, so readers can reproduce the evidence rather than take the claim on faith. Multi-variant packages encode related claims as separate targets — a receipt link may point at the package as a whole or at a specific variant. Blog posts and research documents link load-bearing claims directly to the experiments that substantiate them.

---

### Skill

A development convention captured as a structured document within the ecosystem. Skills are the canonical source for naming, error handling, memory safety, testing, modularization, and similar cross-cutting conventions. They are written primarily to be loaded by AI-assisted tooling, but they are plain Markdown and readable as reference material. Skills live in the `Skills/` directory of `swift-institute`.

---

## Mathematical foundations

Terms from mathematics used in Swift Institute type design. See [Mathematical Foundations](Mathematical%20Foundations.md) for the full treatment.

---

### Affine space

A geometric structure without a canonical origin. In an affine space, points can be subtracted (yielding vectors/displacements) but not added to each other. This models coordinate systems where absolute position is meaningful but adding positions is not.

Used in typed geometry to distinguish coordinates from displacements.

---

### Category

A mathematical structure consisting of objects and morphisms (arrows) between them, with identity morphisms and composition. Category theory provides the foundation for reasoning about transformations and composability.

Informs API design patterns such as `Prism`, `Lens`, and related optics.

---

### Lie group

A group that is also a smooth manifold. Lie groups represent continuous symmetry operations such as rotations, translations, and scaling.

Used in geometric type systems for representing transformations.

---

### Dimensional analysis

The practice of tracking physical dimensions (length, time, mass) through calculations to ensure correctness. In typed systems, dimensional analysis is encoded in the type system to catch errors at compile time.

Used in geometry and measurement types to prevent invalid operations, for example adding a length to a time.

---

## Platform and runtime

Terms describing platform-specific concepts and runtime behavior.

---

### Foundation (Apple)

Apple's framework providing fundamental types (Date, URL, Data, String bridging). Foundation is unavailable in Embedded Swift environments. Swift Institute packages at the Primitives and Standards layers do not depend on Foundation.

---

### Embedded Swift

A minimal Swift language subset for resource-constrained environments. Embedded Swift lacks Foundation and has a reduced standard library. Packages at the Primitives and Standards layers are compatible with Embedded Swift. See [Embedded Swift](Embedded%20Swift.md) for compatibility patterns.

---

### Syscall

A programmatic request to the operating system kernel for services. Syscalls are the boundary between user-space code and kernel-space operations.

---

## Versioning

### Semantic versioning

A versioning scheme using MAJOR.MINOR.PATCH format where:

- MAJOR is incremented for breaking API changes
- MINOR is incremented for backward-compatible feature additions
- PATCH is incremented for backward-compatible bug fixes

Swift Institute packages follow semantic versioning. Packages in the 0.x range explicitly signal that breaking changes may occur.

---

## Organizational terms

### Swift Institute

A stewarded body of layered Swift infrastructure spanning Primitives, Standards, Foundations, Components, and Applications. The Swift Institute is designed for correctness, composability, and long-term evolution.

See [Identity](Identity.md) for the reasoning behind the name and stewardship model.

---

### Five-layer architecture

The organizational model used by the Swift Institute: Primitives, Standards, Foundations, Components, and Applications. Each layer depends only on layers below it. See [Five Layer Architecture](Five%20Layer%20Architecture.md).
