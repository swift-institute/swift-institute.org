# Implementation

@Metadata {
    @TitleHeading("Swift Institute")
}

Index of implementation patterns for Swift Institute packages.

## Overview

This document serves as an index to implementation patterns. Each pattern category is documented in its own focused document for maintainability.

**Normative language**: All pattern documents use RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## Pattern Index

| Document | Patterns | Focus |
|----------|----------|-------|
| <doc:C-Shims> | PATTERN-001, PATTERN-018 | C shim layer structure, semantic boundaries |
| <doc:Multi-Library> | PATTERN-002, PATTERN-003 | Fine-grained libraries, circular dependency breaking |
| <doc:Platform-Compilation> | PATTERN-004, 004a-c, PATTERN-019, PATTERN-036 | Platform conditionals, module naming, linker flags |
| <doc:Swift-6> | PATTERN-005, 005a-b, PATTERN-006-008, PATTERN-035 | Language mode, upcoming features, parameter packs |
| <doc:Anti-Patterns> | PATTERN-009-013, PATTERN-015 | Common mistakes, Foundation ban, macro naming |
| <doc:API-Concurrency> | API-CONC-010-012 | Lock-free resumption, inout-await, type erasure |
| <doc:Ecosystem-Process> | ECO-TECH-001-003 | Minimal reproduction, migration boundaries, audit patterns |
| <doc:API-Design> | API-DESIGN-010-014 | Fallbacks, typealiases, extension points |
| <doc:Experiment> | EXP-001–010d | Minimal reproduction packages, empirical verification |

---

## Quick Reference: Most-Used Patterns

### C Shim Layer Structure

Packages requiring platform-specific functionality MUST use minimal C shim targets isolated from Swift code.

> **Full details**: <doc:C-Shims>

---

### SwiftPM Platform Conditions

Platform-specific dependencies MUST use SwiftPM condition directives.

> **Full details**: <doc:Platform-Compilation>

---

### Swift 6 Language Mode

All packages MUST require Swift 6.2+ and use Swift 6 language mode.

> **Full details**: <doc:Swift-6>

---

### No Foundation Types

Primitive and standard packages MUST NOT use Foundation types.

> **Full details**: <doc:Anti-Patterns>

---

### Linear Types for Invariant Enforcement

Types encoding exactly-once or at-most-once semantics MUST be `~Copyable`.

> **Full details**: the **memory** skill

---

## Pattern Categories

### Infrastructure Patterns

| Pattern | Summary |
|---------|---------|
| PATTERN-001 | C Shim Layer Structure |
| PATTERN-002 | Fine-Grained Library Exposure |
| PATTERN-003 | Nested Test Package Pattern |
| PATTERN-004 | SwiftPM Platform Conditions |
| PATTERN-018 | C Shim as Semantic Boundary |

### Language Feature Patterns

| Pattern | Summary |
|---------|---------|
| PATTERN-005 | Swift 6 Language Mode |
| PATTERN-006 | Upcoming Feature Flags |
| PATTERN-007 | Experimental Feature Flags |
| PATTERN-008 | Parameter Packs for N-Ary Types |
| PATTERN-035 | Import Visibility as Module Contract |

### Anti-Patterns (Avoid)

| Pattern | Summary |
|---------|---------|
| PATTERN-009 | No Foundation Types |
| PATTERN-010 | Nested Type Names (not compound) |
| PATTERN-011 | Typed Error Enums (not strings) |
| PATTERN-012 | Initializers as Canonical Implementation |
| PATTERN-013 | Concrete Types Before Abstraction |

### Ownership Patterns

> **Full document**: the **memory** skill

| Pattern | Summary |
|---------|---------|
| MEM-LINEAR-001 | Exactly-Once Types (Linear) |
| MEM-LINEAR-002 | At-Most-Once Types (Affine) |
| MEM-COPY-003 | Class Wrapper for ~Copyable in Collections |
| MEM-COPY-010 | Noncopyable Workarounds for Associated Types |
| MEM-COPY-011 | Two-World Separation for Owned and Borrowed Types |

### Concurrency Patterns

> **Full document**: <doc:API-Concurrency>

| Pattern | Summary |
|---------|---------|
| API-CONC-010 | Never Resume Under Lock |
| API-CONC-011 | Inout-Across-Await Hazard |
| API-CONC-012 | Type Erasure vs Sendable Tension |

### Audit Patterns

> **Full document**: <doc:Ecosystem-Process>

| Pattern | Summary |
|---------|---------|
| ECO-TECH-001 | Minimal Reproduction as Verification Tool |
| ECO-TECH-002 | Custom Deinit as Migration Boundary |
| ECO-TECH-003 | Audit Search Patterns |
| EXP-001–010 | Experiment Package Methodology (see <doc:Experiment>) |

### API Design Patterns

> **Full document**: <doc:API-Design>

| Pattern | Summary |
|---------|---------|
| API-DESIGN-010 | Fallback as Feature, Not Compromise |
| API-DESIGN-011 | Type Aliases as Architectural Boundaries |
| API-DESIGN-012 | Bound vs Independent Typealias Parameters |
| API-DESIGN-013 | Typealiases as the Reuse Primitive |
| API-DESIGN-014 | Never as Closed Default for Extension Points |

### Safety Patterns

> **Full document**: the **memory-safety** skill

| Pattern | Summary |
|---------|---------|
| MEM-SAFE-010 | Dual-Overload Anti-Pattern |
| MEM-SAFE-011 | Inline Clarity Over Helper Consolidation |
| MEM-SAFE-012 | Span as Normative Interface |
| MEM-SAFE-013 | API Surface Reduction as Safety |
| MEM-SAFE-014 | Closure Scope Over Property Access for Unsafe Operations |

---

## Topics

### Infrastructure Patterns

- <doc:C-Shims>
- <doc:Multi-Library>
- <doc:Platform-Compilation>
- <doc:Swift-6>
- <doc:Anti-Patterns>

### Domain Pattern Documents

- <doc:API-Concurrency>
- <doc:Ecosystem-Process>
- <doc:API-Design>

### Related Documents

- <doc:Memory>
- <doc:API-Requirements>
- <doc:Five-Layer-Architecture>
- <doc:Testing-Requirements>
