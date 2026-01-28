# Ecosystem Process

@Metadata {
    @TitleHeading("Swift Institute")
}

Systematic processes for maintaining ecosystem health across all layers of the Swift Institute ecosystem.
This document defines how primitives are reused, extracted, identified as missing, and created, while enforcing architectural integrity and long-term maintainability.

All processes in this document are grounded in the Centralization Principle ([ECO-CENT-001]) and the Mechanism/Policy distinction ([ECO-CENT-002]).

---

## 1. Overview

**Scope**: This document operationalizes the Five-Layer Architecture by defining concrete, repeatable processes for ecosystem maintenance.

**Two-axis approach**:

1. **Top-down**: Ensure higher layers discover and reuse existing primitives.
2. **Bottom-up**: Extract misplaced or duplicated code into its correct semantic home.

This document is normative. Requirements are identified by `[ECO-*]` identifiers and are enforceable during review, refactoring, and contribution workflows.

---

## 1.1 Artifact Lifecycle Vocabulary

To avoid conflating concerns, artifact state is described along two orthogonal dimensions.

**Location**:

| State | Definition |
|-------|------------|
| Ad-hoc | Local to a package, provisional or contextual |
| Candidate | Identified for extraction or centralization |
| Centralized | Lives in the appropriate shared package |

**Status**:

| State | Definition |
|-------|------------|
| Active | Intended for use |
| Deprecated | Discouraged but supported |
| Superseded | Replaced by a newer artifact |

These dimensions form a 2×3 matrix and are referenced throughout this document to describe process transitions precisely.

---

## 2. Dependency Maximization (Reuse)

**Purpose**: Ensure higher-layer packages systematically discover and reuse lower-layer primitives.

### Dependency Audit Triggers

A dependency audit MUST be performed when:

- Creating a new package
- Adding a new feature
- Conducting code review
- Performing refactoring

An audit is complete when either:

- (a) an existing primitive is adopted, or
- (b) a Reuse Rejection Justification ([ECO-REUSE-004]) is recorded.

### Primitive Discovery Protocol

Discovery MUST follow this order:

1. swift-primitives (tiers 0→9)
2. swift-standards
3. swift-foundations

The Package Inventory is the authoritative discovery index.

Cross-reference: No Ad-Hoc Helpers.

### Composition Over Reimplementation

Existing primitives MUST be composed before introducing new abstractions.

Cross-reference: Unification Over Proliferation.

### Reuse Rejection Justification

If an existing primitive is not reused, the rejection MUST fall into exactly one category:

1. **Semantic mismatch** — the primitive's semantics do not align with the use case
2. **Missing dependency layer** — adopting would violate layer constraints
3. **Policy contamination** — the primitive contains policy incompatible with the target layer

The justification MUST be recorded in code review or the Package Inventory.

---

## 3. Code Extraction (Migration)

**Purpose**: Relocate misplaced code to its correct semantic layer.

### Extraction Indicators

Code MUST be considered for extraction when one or more of the following are present:

- Multiple unrelated packages require the same functionality
- Naming reflects origin rather than mechanism
- Generality increases when decoupled
- The answer to "Is this a more general concept?" is yes

Cross-reference: The Relocation Principle.

### Layer Decision Tree

Layer placement MUST follow:

1. **External specification** → swift-standards
2. **Policy-free atomic mechanism** → swift-primitives
3. **Composition without policy** → swift-foundations
4. **Opinionated but reusable** → swift-components

Cross-reference:,.

### Extraction Execution

Extractions MUST follow:

- Extraction Ordering
- Extraction Template
- Backward Compatibility During Migration

### Migration Boundaries

Code MUST NOT be extracted when it contains:

1. Custom deinit with domain policy ()
2. Implicit ownership of external resources (file descriptors, sockets, task handles)
3. Cleanup sequencing that depends on domain state

Such code remains localized.

---

## 4. Gap Identification

**Purpose**: Identify missing primitives.

### Gap Heuristics

Signals of a missing primitive include:

- Repeated ad-hoc wrappers across packages
- Scattered `@unchecked Sendable` markers without centralized justification
- Repeated transformations appearing in multiple locations

### Gap Threshold

A gap MUST be formally evaluated once the same mechanism appears in three or more locations.

### Gap Verification

Before creating a new primitive:

1. Exhaust ecosystem search (Package Inventory)
2. Verify the gap is mechanism, not policy
3. Verify multi-package benefit
4. Verify no semantic duplicate exists

Failed first migrations ([ECO-AUDIT-004]) serve as gap verification evidence.

---

## 5. New Primitive Creation

**Purpose**: Define when and how new primitives are introduced.

### Creation Triggers

Create a primitive when:

- Gap verification ([ECO-GAP-003]) confirms need
- Extraction reveals a reusable pattern
- An external specification requires a new building block

### Layer Placement

Placement MUST:

- Follow the Layer Decision Tree ([ECO-EXTR-002])
- Respect primitive tiering ([PRIM-ARCH-001])
- Introduce no upward dependencies

### Primitive Design Requirements

New primitives MUST satisfy:

- No Foundation usage ([PRIM-FOUND-001])
- `-primitives` naming suffix ([PRIM-NAME-001])
- Mechanism-based naming ([PRIM-NAME-003])
- API totality ()
- All API Requirements

### Creation Template

1. Create package in appropriate swift-primitives tier
2. Implement minimal API surface
3. Add comprehensive tests
4. Document with examples
5. Update Package Inventory
6. Migrate existing ad-hoc implementations

### Creation Deferral Rule

If a proposed primitive cannot satisfy all design requirements, creation MUST be deferred.

The code remains localized until requirements are met or the design is revised.

---

## 6. Decision Resolution

**Purpose**: Resolve ambiguous layer placement and extraction decisions.

### Tie-Breaker Hierarchy

When multiple layers or approaches are plausible, apply in order:

1. **Dependency direction safety** — prefer the option that cannot create upward dependencies
2. **Mechanism purity** ([ECO-CENT-002]) — prefer the layer where code contains zero policy
3. **Reuse count** — prefer the option benefiting more packages
4. **Simplest API surface** — prefer fewer public symbols

### Decision Recording

Tie-breaker rationale MUST be documented in:

- The relevant PR description, or
- Package Inventory notes

This ensures future reviewers understand non-obvious placements.

---

## 7. Audit-Driven Maintenance

**Purpose**: Continuously surface inconsistencies through event-triggered audits.

### Audit Process

Audits are triggered by:

- New primitive creation
- Code review
- Refactoring efforts

Question format: "We have [Primitive X]. What's still ad-hoc?"

Cross-reference: Audit-Driven Refactoring.

### Audit Search Patterns

Audits MUST, at minimum, search for:

- `final class.*: @unchecked Sendable` (wrapper classes)
- Duplicate implementations of the same transformation
- `import Foundation` in primitives or standards
- Compound type names where `Nest.Name` should be used

### Migration Criteria

Migrate only when all criteria are met:

1. The code is a pure wrapper with no custom cleanup
2. Semantics match the existing primitive
3. The primitive dependency is available
4. Total code size decreases, not increases

### First Migration as Diagnostic

The first migration attempt is diagnostic.

Failures reveal infrastructure gaps and feed gap verification ([ECO-GAP-003]).

Plan for iteration: audit → attempt → learn → fix → continue.

Cross-reference: First Migration as Diagnostic.

---

## 8. Centralization Principles

**Purpose**: Guiding philosophy for ecosystem decisions.

### Centralization Principle

Duplicating mechanisms locally is architecturally equivalent to reimplementing Foundation in each package.

The same argument that would justify `Foundation.Date` appearing ad-hoc in each package is equally wrong for ad-hoc wrappers providing reference semantics, heap allocation, or other mechanisms.

Cross-reference: Centralization as Architectural Principle.

### Mechanism vs Policy

| Category | Layer | Example |
|----------|-------|---------|
| Mechanism | Primitives | Reference semantics, heap allocation |
| Policy | Higher layers | Cleanup logic, "close" semantics, sequencing |

When in doubt, ask: "Does this code make decisions, or does it provide capability?"

- Capability without decisions → Mechanism → Primitives
- Decisions about when/how → Policy → Higher layers

---

## 9. Global Constraints

**Purpose**: Architectural invariants that apply across all processes.

### Dependency Direction

All dependencies MUST point downward through the layer hierarchy.

- No upward dependencies
- No lateral dependencies within the same layer

Cross-reference:.

### Fine-Grained Dependencies

Packages MUST depend on specific primitive packages, not umbrella packages.

**Verification**: Umbrella imports in `Package.swift` constitute a violation unless explicitly justified.

```bash
# Violation detection
grep -r "import.*_Primitives$" --include="Package.swift"
```

Cross-reference: Fine-Grained Library Exposure.

---

## Topics

### Architecture

- <doc:Five-Layer-Architecture>
- <doc:Primitives-Architecture>
- <doc:Layer-Flowchart>

### Process Documents

- <doc:Ecosystem-Process>

### Reference

- <doc:Package-Inventory>
- <doc:API-Implementation>
- <doc:Implementation-Patterns>

### Contribution

- <doc:Contributor-Guidelines>
