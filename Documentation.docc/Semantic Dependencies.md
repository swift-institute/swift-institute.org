# Semantic Dependencies

@Metadata {
    @TitleHeading("Swift Institute")
}

Declaring the conceptually correct relationships between packages, independent of current implementation usage.

## Overview

> This document answers: "What dependencies should a package declare beyond those it currently imports?"

Package dependencies form two distinct graphs:

- **Implementation Dependency Graph (IDG)**: Edges required for compilation. "This package must be available for the build to succeed."
- **Semantic Dependency Graph (SDG)**: Edges implied by domain relationships. "This package's meaning conceptually contains or operates on another package's meaning."

The IDG is enforced by the compiler. The SDG must be declared explicitly through conventions defined in this document. Both graphs must respect tier constraints; both are architectural artifacts.

**Why this matters for Swift Institute**: Strict layering, totality expectations, and Foundation-free constraints mean that concepts like "string-ness," "error-ness," and "lifetime" are architectural atoms, not incidental details. The SDG makes domain relationships visible even when the IDG is silent, preventing architecture drift while allowing implementation to evolve.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## The Core Insight

Consider `swift-formatting-primitives`. Its purpose is to format values into human-readable representations. Formatting produces *strings*. Therefore, formatting has an SDG edge to string primitives—even if no current API requires `String_Primitives.String`.

This is the gap between:
- **What a package imports** — the IDG, driven by current implementation
- **What a package is about** — the SDG, driven by semantic domain

SDG edges bridge this gap by declaring relationships that are architecturally correct but not yet implemented.

---

## Dependency Classification

**Scope**: All package dependency declarations.

**Statement**: Dependencies MUST be classified into exactly one of three categories:

| Category | Definition | Graph | Package.swift Representation |
|----------|------------|-------|------------------------------|
| Implementation | Code imports and uses types | IDG edge | Uncommented, active dependency |
| Semantic | Conceptually correct, not yet used | SDG edge | Commented with structured marker |
| Incorrect | Neither implemented nor semantic | — | MUST NOT appear |

**Example**:

```swift
dependencies: [
    // IDG edge: actively used
    .package(path: "../swift-identity-primitives"),

    // SDG(produces): formatting produces string output
    // .package(path: "../swift-string-primitives"),
],
```

**Rationale**: Explicit classification prevents accidental dependencies while documenting architectural intent. The structured marker serves as both documentation and a placeholder for future activation.

---

## Marker Format and Rationale Requirement

**Scope**: All SDG edge declarations.

**Statement**: Every SDG edge MUST use the structured marker format:

```
// SDG(<relation>): <rationale referencing discovery question>
```

### Closed Relation Set (v1.1)

| Relation | Meaning | Discovery Question |
|----------|---------|-------------------|
| `produces` | A produces values of type B | "What does this package produce?" |
| `operates-on` | A operates on values of type B | "What does this package operate on?" |
| `specializes` | A is a specialization of B | "Is A a specialization of B?" |
| `wraps` | A wraps/contains B semantically | "What does this package wrap or contain?" |

**Constraints**:
- `<relation>` MUST be one of the four relations above (kebab-case, no whitespace)
- `<rationale>` MUST reference the corresponding discovery question language
- Extensions to the relation set require a version increment

**Correct**:
```swift
// SDG(wraps): loader errors wrap platform error codes (errno/GetLastError)
// .package(path: "../swift-error-primitives"),

// SDG(wraps): library handles wrap scoped lifetimes
// .package(path: "../swift-lifetime-primitives"),

// SDG(produces): formatting produces string output
// .package(path: "../swift-string-primitives"),
```

**Incorrect**:
```swift
// .package(path: "../swift-error-primitives"),  // ❌ No marker

// Semantic dependency: errors
// .package(path: "../swift-error-primitives"),  // ❌ Old format, no relation

// SDG(uses): we use errors  // ❌ "uses" not in closed set
// .package(path: "../swift-error-primitives"),

// Might need this later
// .package(path: "../swift-random-primitives"),  // ❌ "Might need" is not semantic
```

**Rationale**: The structured marker enables machine extraction (regex: `// SDG\(([^)]+)\):`) while forcing explicit reasoning about domain relationships. The closed relation set prevents vocabulary drift.

---

## Tier Constraint Preservation

**Scope**: SDG edge tier relationships.

**Statement**: SDG edges MUST respect the same tier constraints as IDG edges. A package at tier N MUST NOT declare SDG edges to packages at tier N or higher.

**Correct**:
```swift
// swift-formatting-primitives (Tier 1)
// SDG(produces): formatting produces string output
// .package(path: "../swift-string-primitives"),  // Tier 1 - valid
```

**Incorrect**:
```swift
// swift-ascii-primitives (Tier 0)
// ❌ SDG edge to Tier 1 package - tier violation
// SDG(operates-on): ASCII used in formatting
// .package(path: "../swift-formatting-primitives"),
```

**Rationale**: SDG edges represent intended architecture. If the intended architecture violates tier constraints, either the semantic relationship is incorrect or the package is misplaced.

---

## Activation Protocol

**Scope**: Transitioning SDG edges to IDG edges.

**Statement**: When implementation begins using an SDG edge, it MUST be uncommented and activated. The SDG marker SHOULD be removed.

**Before** (SDG edge):
```swift
// SDG(produces): formatting produces string output
// .package(path: "../swift-string-primitives"),
```

**After** (IDG edge):
```swift
.package(path: "../swift-string-primitives"),
```

### Drift Prevention

SDG edges SHOULD be reviewed whenever the package's public API surface changes materially. Stale SDG edges (where the rationale no longer applies) MUST be removed.

**Rationale**: SDG edges are placeholders for architectural intent. Once implemented, they become IDG edges and the semantic marker is no longer needed. Regular review prevents comment drift.

---

## Lateral Dependency Warning

**Scope**: SDG edges between same-tier packages.

**Statement**: An SDG edge to a same-tier package indicates a potential architectural issue. Such edges SHOULD trigger review to determine whether:

1. One package should be at a higher tier
2. The packages should be merged
3. A shared lower-tier package should be extracted
4. A join-point package should be introduced ([SEM-DEP-008])

**Example**:
```
swift-formatting-primitives (Tier 1) has SDG edge to
swift-text-primitives (Tier 1)

Analysis options:
1. text-primitives should be Tier 0 (no primitive deps)
2. formatting and text should merge (same semantic domain)
3. Extract shared concept to Tier 0
4. Introduce join-point at Tier 2
```

### String as Peer Substrate Risk

A common manifestation of lateral pressure is **string-primitives becoming an implicit peer dependency** across Tier 1. When multiple packages (formatting, diagnostics, serialization, logging) all produce strings, string-primitives risks becoming a de facto lateral web connector.

**Mitigations**:
- Ensure string-primitives is at the correct tier (currently Tier 1, depends on ascii-primitives)
- Consider whether the "string output" relationship is essential or incidental ([SEM-DEP-006])
- Use join-points for integration semantics rather than forcing lateral edges

**Rationale**: Lateral dependencies—SDG or IDG—flatten the tier hierarchy and suggest incomplete domain analysis.

---

## The Domain Ordering Principle

### Larger Domain Depends on Smaller

**Scope**: Determining SDG edge direction.

**Statement**: When concept A "operates on" or "is composed of" concept B, package A MUST have an edge (SDG or IDG) to package B. The larger, more specialized domain depends on the smaller, more fundamental domain.

**Domain containment examples**:

```
ASCII ⊂ String ⊂ Text

Therefore:
 string-primitives  (Text operates on String)
 ascii-primitives   (String can be ASCII-only)
```

```
Error ⊂ Platform Error ⊂ Loader Error

Therefore:
 error-primitives   (Loader errors wrap Error)
```

**Decision procedure**:

| Question | Relation | If Yes | If No |
|----------|----------|--------|-------|
 B | — |
 B | — |
 B | — |
 B | — |
| Can A exist without the concept of B? | — | No edge | — |

### Essential vs Incidental Relationships

When evaluating `operates-on`, distinguish **essential** from **incidental** relationships:

- **Essential**: Removing B would change A's semantic domain. The dependency is intrinsic to what A *is*.
- **Incidental**: B is merely a convenient representation that could be substituted. The dependency is about how A is currently *implemented*.

**Example**:
 `string-primitives` is **essential** (formatting's purpose is to produce readable output; strings are intrinsic to that purpose)
 `string-primitives` would be **incidental** (hashes produce bytes; string representation is a debugging convenience)

**Reviewer guidance**: `operates-on` must be domain-essential, not "we happen to take a B parameter once." If the relationship is incidental, there is no SDG edge.

**Rationale**: Domain ordering reflects conceptual containment. The essential/incidental distinction prevents SDG edge inflation.

---

## SDG Closure Review

**Scope**: Package creation and major refactoring.

**Statement**: For Tier 1+ packages, SDG edge analysis MUST be performed at package creation using the discovery questions checklist. The analysis SHOULD be documented in the initial commit or PR.

**Tier 0 exception**: Tier 0 packages are presumed SDG-empty unless explicitly annotated. They are atomic by definition and typically have no semantic dependencies on other primitives.

**Discovery questions checklist**:

 SDG(produces) to output type's package
 SDG(operates-on) to input type's package
 SDG(wraps) to error-primitives
 SDG(wraps) to lifetime-primitives
 SDG(operates-on) to identity-primitives

**Rationale**: Upfront SDG analysis prevents architectural drift and ensures domain relationships are captured before implementation obscures them.

---

## Join-Point Resolution

**Scope**: Resolving SDG conflicts where two domains have mutual semantic relevance.

**Statement**: When adding an SDG edge from A to B would create a lateral dependency or invert the domain partial order, a **join-point package** MUST be introduced instead. The join-point package J owns the integration semantics "A-in-context-of-B."

### Decision Procedure

| Condition | Action |
|-----------|--------|
| A and B at different tiers, edge respects ordering | Add SDG edge directly |
| A and B at same tier (lateral) | Create join-point J |
| Edge would invert domain ordering | Create join-point J |

### Tier Placement

Join-point packages SHOULD be placed at the **minimal tier above max(tier(A), tier(B))** that satisfies existing tier constraints. Avoid "jumping" to unnecessarily high tiers.

### Join-Point Creation Criteria

Join-point packages are justified when:

1. Both source domains are stable and independently useful
2. The integration semantics are stable and reused by multiple higher packages
3. The alternative (forcing one domain to depend on the other) would violate tier constraints or domain ordering

### SDG-First Join-Points

Join-point packages MAY start as SDG-only intent (commented edges declaring the planned integration) and activate IDG edges when integration code lands. This keeps and aligned.

### Example: Error Formatting

```
Problem: "formatted error messages" requires both error and formatting domains

Current state:
  error-primitives (Tier 0): error modeling, propagation, typed failures
  formatting-primitives (Tier 1): format specifications, formatting engines

Analysis:
 Tier 0)
  - But "formatted error messages" is integration semantics, not core formatting
 Tier 1)

Solution: diagnostic-primitives (Tier 2) as join-point

  diagnostic-primitives depends on:
    - error-primitives (structured error values)
    - formatting-primitives (rendering machinery)
    - string-primitives (output representation)

  Exports: Diagnostic, Renderer, formatted message surface
```

**Rationale**: Join-points prevent lateral dependency webs and keep base domains focused. The criteria constrain when package proliferation is justified.

---

## Verification and Audit

### SDG Audit Checklist

When auditing a package's dependencies:

| Check | Action |
|-------|--------|
| Missing SDG edges | Add with `// SDG(<relation>):` marker |
| SDG edges without proper marker | Convert to structured format |
| SDG edges violating tier | Fix tier assignment or remove edge |
| Lateral SDG edges | Analyze for merge/split/extract/join-point |
| "Might need someday" comments | Remove—these are not SDG edges |
| Activated SDG edges still commented | Uncomment and convert to IDG edge |
| Stale SDG edges (rationale no longer applies) | Remove |

### Machine Extraction

SDG edges can be extracted programmatically:

```bash
# Find all SDG edges in a package
grep -E '// SDG\([^)]+\):' Package.swift

# Extract relation types
grep -oE 'SDG\([^)]+\)' Package.swift | sort | uniq -c

# Future: validate against tier registry (tooling TBD)
```

---

## Examples from swift-primitives

### Tier 1 SDG Edges to Tier 0

| Package | SDG Edge | Marker |
|---------|----------|--------|
| formatting-primitives | string-primitives | `SDG(produces): formatting produces string output` |
| loader-primitives | error-primitives | `SDG(wraps): loader errors wrap platform error codes` |
| loader-primitives | lifetime-primitives | `SDG(wraps): library handles wrap scoped lifetimes` |
| locale-primitives | ascii-primitives | `SDG(operates-on): locale codes operate on ASCII identifiers` |
| dependency-primitives | property-primitives | `SDG(operates-on): dependency injection operates on property patterns` |
| dependency-primitives | optic-primitives | `SDG(operates-on): dependency injection operates on lens/prism patterns` |

### Activated SDG Edges (now IDG)

| Package | Dependency | Activation Reason |
|---------|------------|-------------------|
| string-primitives | ascii-primitives | Added `init(ascii: StaticString)` |
| text-primitives | string-primitives | Text processing operates on strings |

---

## Anti-Patterns

### Anti-Pattern: Speculative Dependencies

```swift
// ❌ "Might need" is not a semantic relationship
// Might need this for future features
// .package(path: "../swift-random-primitives"),
```

SDG edges express domain relationships, not feature speculation.

### Anti-Pattern: Dependency Hoarding

```swift
// ❌ Listing every Tier 0 package "just in case"
// SDG(operates-on): might operate on ASCII
// .package(path: "../swift-ascii-primitives"),
```

Each SDG edge must have a specific, essential rationale tied to the package's domain.

### Anti-Pattern: Incidental operates-on

```swift
// ❌ Incidental relationship claimed as essential
// SDG(operates-on): we have one function that takes a String parameter
// .package(path: "../swift-string-primitives"),
```

If removing the dependency wouldn't change the package's semantic domain, there is no SDG edge.

### Anti-Pattern: Using SDG to Avoid Tier Issues

```swift
// swift-ascii-primitives (Tier 0)
// ❌ SDG edge to higher tier to "document intent"
// SDG(produces): ASCII is used in formatting
// .package(path: "../swift-formatting-primitives"),  // Tier 1!
```

If a package semantically depends on a higher-tier package, the analysis is wrong or the package is misplaced.

### Anti-Pattern: Missing Marker

```swift
// ❌ No structured marker - not machine-extractable
// Semantic dependency: optics
// .package(path: "../swift-optic-primitives"),
```

Use the `// SDG(<relation>):` format.

---

## Future Directions

The following enhancements are explicitly deferred from v1.1:

### Edge-Type Ontology Extension

The closed relation set (`produces`, `operates-on`, `specializes`, `wraps`) may be extended in future versions. Candidates include:
- `encodes` / `decodes` — for serialization relationships
- `names` / `identifies` — for identity relationships

Extensions will be added conservatively based on demonstrated need.

### External SDG Registry

A dedicated machine-readable SDG registry (separate from Package.swift comments) could enable:
- Automated tier constraint validation
- Lateral edge detection
- Cross-package SDG visualization

### Dedicated Tooling

Beyond `grep`-based extraction:
- SwiftPM plugin for SDG validation
- Pre-commit hooks for marker format enforcement
- Integration with architectural review workflows

### Feature-Like Activation

Inspired by Cargo's optional dependencies, a mechanism where SDG edges could be "activated" programmatically rather than by uncommenting. This would require SwiftPM evolution or external tooling.

---

## Topics

### Related Documents

- <doc:API-Layering>
- <doc:Five-Layer-Architecture>
- <doc:Primitives-Architecture>

<!-- Cross-layer documents in swift-primitives: Primitives Tiers, Primitives Layering -->
