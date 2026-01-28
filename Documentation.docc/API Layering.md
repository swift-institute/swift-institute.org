# API Layering

@Metadata {
    @TitleHeading("Swift Institute")
}

Package and target architecture: explicit layers and responsibility separation.

## Overview

This document defines layering requirements for package and target organization.

**Applies to**: All package and target architecture decisions.

**Does not apply to**: Single-file scripts, prototypes, or exploration code.

---

## Explicit Target Layers

**Scope**: Package and target organization.

**Statement**: Code MUST be designed in layers, each depending only on layers below it.

Typical shape:

1. **Primitives**
   - Minimal tokens, IDs, events, handles
   - Zero policy, zero platform choice

2. **Driver / backend contracts**
   - Capability interfaces
   - Leaf errors
   - Stable, testable contracts

3. **Platform backends**
   - kqueue, epoll, IOCP, etc.

4. **Runtime orchestration**
   - Lifecycles
   - Scheduling
   - Cancellation
   - Cross-thread coordination

5. **User-facing convenience**
   - Ergonomic wrappers
   - Default policies
   - Platform factories

**Rationale**: Layered architecture enables testing at each level, platform portability, and clear dependency boundaries.

---

## Responsibility Separation

**Scope**: Layer boundaries.

**Statement**: Lower layers MUST NOT embed lifecycle policy, introduce cancellation or shutdown semantics, construct user-facing errors requiring runtime context, or depend on higher-level scheduling decisions.

Higher layers are the only place where:
- Lifecycle semantics exist
- Cancellation and shutdown are unified
- Backpressure and retry policy are applied

**Rationale**: Separation ensures lower layers remain testable and reusable across different runtime contexts.

---

## Layer Boundary Checklist

When designing a new target or package, verify:

| Question | Expected Answer |
|----------|-----------------|
| Does this target depend only on layers below it? | Yes |
| Can this target be tested in isolation? | Yes |
| Does this target avoid lifecycle policy? | Yes (for primitives) |
| Are errors typed and layer-appropriate? | Yes |
| Can platform backends be swapped? | Yes (for abstractions) |

---

## Cross-Platform Requirements

**Scope**: Platform-specific code.

**Statement**:
- Platform selection MUST be centralized.
- Callers MUST NOT use `#if`.
- Handles MUST be opaque and platform-agnostic.
- Backends MUST satisfy the same contract:
  - `register`
  - `modify`
  - `deregister`
  - Deterministic shutdown
  - Defined behavior for late events (drop)

**Rationale**: Centralized platform selection enables consistent behavior and easier testing.

---

## Topics

### Related Documents

- <doc:API-Requirements>
- <doc:Five-Layer-Architecture>
- <doc:Primitives-Architecture>
