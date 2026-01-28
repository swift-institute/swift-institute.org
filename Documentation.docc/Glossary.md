# Glossary

@Metadata {
    @TitleHeading("Swift Institute")
}

## Overview

This glossary defines the canonical meaning of terms used across Swift Institute specifications. Terms are grouped by domain and include cross-references to the specification sections where they are defined or applied.

**Normative language**: Definitions in this glossary are normative. When documentation uses a term defined here, it carries the meaning specified below.

---

## Architecture Layers

Terms describing the layered architecture model used in Swift Institute packages.

---

### Primitive (Layer 1)

An atomic building block; a type that is irreducible, policy-free, and not defined in terms of other types. Primitives are types that standards require but do not define. The Primitives layer is organized by semantic irreducibility.

**Characteristics**:
- Zero policy, zero platform choice
- Minimal tokens, IDs, events, handles
- MUST be total in implementation

---

### Standard (Layer 2)

A faithful implementation of an external normative specification (RFC, ISO, IEEE). Semantics are dictated by the external specification, not by implementation convenience. Standards depend only on Primitives.

**Examples**: RFC 3986 (URI), ISO 32000 (PDF), IEEE 754 (floating-point)

---

### Foundation (Layer 3)

A composed building block constructed from Primitives and Standards. Foundations are reusable across domains with minimal defaults and no application-specific workflows. Not to be confused with Apple's Foundation framework.

**Characteristics**:
- Composes lower layers
- Reusable across domains
- Minimal policy introduction

---

### Component (Layer 4)

A reusable, opinionated assembly built on Foundations. Components encode defaults and trade-offs but remain reusable across applications. This layer marks the policy boundary where opinions begin to be introduced.

**Characteristics**:
- Encodes defaults and trade-offs
- Remains reusable
- Introduces policy

---

### Application (Layer 5)

An end-user system with domain-specific workflows, branding, and UX. Applications are not intended as general infrastructure and are built upon Components and lower layers.

**Characteristics**:
- Domain-specific workflows
- End-user facing
- Not reusable as infrastructure

---

### Policy Boundary

The point in the layer stack where defaults and opinions begin to be introduced. This occurs at the Components layer (Layer 4). Layers below the policy boundary (Primitives, Standards, Foundations) MUST NOT introduce policy.

---

### Semantic Irreducibility

The property of types that cannot be decomposed further into simpler constituent types without losing meaning. Semantic irreducibility is the organizing principle for the Primitives layer.

---

## Type System Concepts

Terms describing Swift type system features and patterns used in Swift Institute packages.

---

### Noncopyable Type

A Swift type marked `~Copyable` that cannot be implicitly copied. Noncopyable types enable move semantics and are used to model resources that must have exactly one owner (handles, tokens, capabilities).

**Usage**: Noncopyable values MUST NOT be embedded in types conforming to `Error` because `Swift.Error` requires `Copyable`.

> **Comprehensive guidance**: See <doc:Memory> for complete ownership patterns, linear/affine types, strict memory safety, and reference primitives.

---

### Phantom Type

A type parameter that appears in a type signature but has no runtime representation. Phantom types are used for compile-time tagging, enabling type-safe distinctions without runtime overhead.

**Example**: `Geometry<Double, PageSpace>` where `PageSpace` is a phantom type parameter distinguishing coordinate spaces.

---

### Typestate

A pattern where different states of an object are represented as different types. Typestate makes invalid state transitions unrepresentable at compile time.

**Example**: `UnregisteredToken` and `RegisteredToken` as distinct types rather than a single `Token` with an `isRegistered` flag.

---

## Mathematical Foundations

Terms from mathematics used in Swift Institute type design.

---

### Affine Space

A geometric structure without a canonical origin. In an affine space, points can be subtracted (yielding vectors/displacements) but not added to each other. This models coordinate systems where absolute position is meaningful but adding positions is not.

**Application**: Used in typed geometry to distinguish coordinates from displacements.

---

### Category

A mathematical structure consisting of objects and morphisms (arrows) between them, with identity morphisms and composition. Category theory provides the foundation for thinking about transformations and composability.

**Application**: Informs API design patterns like `Prism`, `Lens`, and other optics.

---

### Lie Group

A group that is also a smooth manifold. Lie groups are used to represent continuous symmetry operations such as rotations, translations, and scaling.

**Application**: Used in geometric type systems for representing transformations.

---

## Platform and Runtime

Terms describing platform-specific concepts and runtime behavior.

---

### Foundation (Apple)

Apple's framework providing fundamental types (Date, URL, Data, String bridging). Foundation is unavailable in Swift Embedded environments. Swift Institute packages in swift-standards and swift-primitives MUST NOT depend on Foundation.

---

### Swift Embedded

A minimal Swift runtime for resource-constrained environments. Swift Embedded lacks Foundation and has a reduced standard library. All swift-primitives and swift-standards packages MUST be compatible with Swift Embedded.

---

### Syscall

A programmatic request to the operating system kernel for services. Syscalls are the boundary between user-space code and kernel-space operations.

---

## Versioning and Evolution

Terms describing versioning conventions.

---

### Semantic Versioning

A versioning scheme using MAJOR.MINOR.PATCH format where:
- **MAJOR**: Incremented for breaking API changes
- **MINOR**: Incremented for backward-compatible feature additions
- **PATCH**: Incremented for backward-compatible bug fixes

Swift Institute packages follow semantic versioning.

---

## Organizational Terms

Terms describing the Swift Institute itself.

---

### Swift Institute

A stewarded body of layered Swift infrastructure spanning Primitives, Standards, Foundations, Components, and Applications. The Swift Institute is designed for correctness, composability, and long-term evolution.

**Principles**:
- Timeless infrastructure quality
- Layered architecture with clear boundaries
- No Foundation dependency in lower layers
- Swift Embedded compatibility for Primitives and Standards

---

### Dimensional Analysis

The practice of tracking physical dimensions (length, time, mass) through calculations to ensure correctness. In typed systems, dimensional analysis is encoded in the type system to catch errors at compile time.

**Application**: Used in geometry and measurement types to prevent invalid operations (e.g., adding a length to a time).

**Cross-references**: Geometry module in swift-standards