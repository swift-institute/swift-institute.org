# Pattern: Audit and Refactoring

<!--
---
title: Pattern Audit and Refactoring
version: 1.0.0
last_updated: 2026-01-21
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Patterns for systematic auditing, verification, and refactoring of Swift Institute packages.

## Overview

> This document answers: "What patterns govern systematic package auditing and refactoring?"

This document defines implementation patterns for auditing and refactoring: minimal reproduction for verification, centralization principles, and audit-driven improvement.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## [PATTERN-023] Minimal Reproduction as Verification Tool

**Scope**: Resolving debates about compiler behavior, runtime semantics, or "what Swift does."

**Statement**: When technical debates rest on claims about compiler behavior, runtime semantics, or language mechanics, a minimal reproduction package MUST be built to verify the claim.

> **Full methodology**: See <doc:Pattern-Experiment-Package> for complete experiment package creation protocol, including location conventions, reduction methodology, and result documentation.

**Cross-references**: [API-DESIGN-004], [API-DESIGN-007], <doc:Pattern-Experiment-Package>

---

## [PATTERN-026] Centralization as Architectural Principle

**Scope**: Decisions about whether to use primitives or domain-specific implementations.

**Statement**: Common patterns MUST be centralized in primitives, even when it adds verbosity at call sites. The same argument that could justify `Foundation.Date` in each package applies to ad-hoc wrappers—and is equally wrong.

**Correct**:
```swift
// Using centralized primitive
import Time_Primitives
let instant = Time.Instant.now()
```

**Incorrect**:
```swift
// Ad-hoc wrapper in each package
struct MyTimestamp {
    let seconds: Int64
    let nanoseconds: Int32
}
// Duplicated across packages, inconsistent APIs
```

**Rationale**: Centralization ensures consistent behavior, reduces maintenance burden, and enables ecosystem-wide improvements.

**Cross-references**: [API-IMPL-011], [PATTERN-024], <doc:Ecosystem-Process#ECO-CENT-001>

---

## [PATTERN-027] Custom Deinit as Migration Boundary

**Scope**: Evaluating whether domain-specific wrappers can be replaced with primitives.

**Statement**: Custom `deinit` marks an architectural boundary for migration to primitives. When a wrapper class has cleanup logic beyond "deallocate memory," that logic encodes domain knowledge the primitive cannot provide.

**Assessment checklist**:

| Deinit Content | Migration Possible? |
|----------------|---------------------|
| Empty or trivial | Yes - pure wrapper |
| Resource release (close file, etc.) | Maybe - if primitive handles lifecycle |
| Domain-specific cleanup | No - domain knowledge required |

**Cross-references**: [PATTERN-026], [PATTERN-014], <doc:Ecosystem-Process#ECO-EXTR-004>

---

## [PATTERN-028] Audit-Driven Refactoring

**Scope**: Systematic identification of architectural debt through consistency audits.

**Statement**: Refactoring MAY be driven by consistency audits rather than bug reports or feature requests. When centralized primitives exist, the question "what's still ad-hoc?" reveals patterns that would never surface through bug reports.

**Audit questions**:

1. What types duplicate functionality available in primitives?
2. What patterns are repeated across packages without centralization?
3. What APIs violate naming conventions?
4. What error handling uses untyped throws?

**Cross-references**: [PATTERN-026], [PATTERN-027], <doc:Ecosystem-Process#ECO-AUDIT-001>, <doc:API-Audit-Process>

---

## Topics

### Related Documents

- <doc:Implementation-Patterns>
- <doc:Pattern-Experiment-Package>
- <doc:API-Audit-Process>
- <doc:Ecosystem-Process>
