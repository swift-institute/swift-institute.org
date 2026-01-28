# API Design

<!--
---
title: API Design
version: 1.0.0
last_updated: 2026-01-18
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Design validation patterns and requirements for architectural decisions.

## Overview

This document defines design validation requirements for Swift Institute packages. These patterns ensure architectural decisions are grounded in empirical evidence rather than theoretical argumentation.

**Applies to**: Architectural decisions where multiple approaches exist.

**Does not apply to**: Purely aesthetic preferences without functional implications.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## Document Structure

| Section | Requirements | Focus |
|---------|--------------|-------|
| [Type-Safe Containers](#type-safe-containers) | 1 | Subscript syntax for type-keyed access |
| [Language Constraints](#language-constraints) | 2 | Simplification when features don't compose |
| [Design Principles](#design-principles) | 3 | Policy/storage separation, empirical measurement |
| [Design Validation](#design-validation) | 2 | Surfacing hidden premises, adversarial review |

---

## Type-Safe Containers

**Applies to**: APIs providing type-keyed access to values.

---

### [API-DESIGN-001] Subscript Syntax as Correct API for Type-Safe Containers

**Scope**: APIs providing type-keyed access to values (dependency containers, heterogeneous storage).

**Statement**: When implementing type-keyed containers in a modular system, subscript syntax with explicit type parameters (`container[Key.self]`) is the CORRECT API design, not a compromise. Property syntax (`container.key`) requires compile-time mappings from names to types that cannot exist in modular systems.

#### Why Property Syntax Cannot Work

Property syntax for type-keyed access would require:
1. **Implicit resolution** (Scala's `implicit`) - Swift lacks this
2. **Open type families** (extensible type-level mappings) - Swift lacks this
3. **Type-to-name reflection** (deriving `apiClient` from `APIClient`) - Swift lacks this

Without these features, there is no way to provide `context.apiClient` that resolves to a specific type without central registration—which defeats the purpose of modular, independently-compiled witness definitions.

**Correct**:
```swift
// Subscript with type parameter - works in modular systems
let client = context[APIClient.self]
let logger = values[Logger.self]

// The type parameter IS the name
extension Witness.Values {
    public subscript<W: Witness>(type: W.Type) -> W.Value {
        // Resolution uses W as the key
    }
}
```

**Incorrect**:
```swift
// ❌ Property syntax requiring central registration
let client = context.apiClient  // Requires @dynamicMemberLookup
                                 // Which requires compile-time name→type mapping
                                 // Which requires central registration
                                 // Which defeats modular witness definitions

// ❌ Attempting registry patterns
extension WitnessRegistry {
    static func register<W: Witness>(_ type: W.Type, name: String)
}
// Now every module must call register() at startup - fragile, order-dependent
```

#### Cross-Language Analysis as Design Tool

Examining how other languages solve a problem is a systematic design methodology, not idle curiosity. Each language's solution reveals a different point in the design space:

| Language | Solution | Why It Works |
|----------|----------|--------------|
| Scala (ZIO) | `implicit` resolution | Open resolution without registration |
| Haskell (mtl) | Type classes | Distributed `Has` instances |
| TypeScript (Effect-TS) | String tags | Explicit name mapping accepted |
| Swift | Type parameter subscript | Type parameter serves as name |

Swift's subscript solution achieves the same goal through different means. The type parameter `[Key.self]` serves as both identifier and type constraint—it is Swift's idiom for type-keyed access.

The exercise of sketching "ideal" syntax maps each desire to a specific missing feature. These sketches become specifications for what language evolution would need to provide—and proof that current constraints are real, not accidental.

**Rationale**: Proving an ergonomic desire is impossible within language constraints is as valuable as implementing it. The analysis prevents wasted effort exploring impossible paths and transforms the team's relationship to the API—there is no lingering sense that "we should find a better way." Design maturity includes knowing when to stop searching.

**Cross-references**: [API-NAME-002], [FUTURE-006]

---

## Language Constraints

**Applies to**: API design when Swift language features conflict.

---

### [API-DESIGN-002] Simplify When Features Don't Compose

**Scope**: API design decisions when Swift language features conflict.

**Statement**: When a language feature does not compose with another required feature, the correct response is simplification—removing the non-composing feature—rather than elaborate workarounds.

**Correct**:
```swift
// Typed throws desired, but Mutex.withLock cannot propagate typed errors
// Correct response: simplify to non-throwing API

extension Witness {
    public struct Preparation: ~Copyable, Sendable {
        // Non-throwing API - clean composition with Mutex
        public consuming func finalize() -> Witness.Values {
            storage.withLock { $0 }
        }
    }
}
```

**Incorrect**:
```swift
// ❌ Fighting the constraint with workarounds
extension Witness {
    public struct Preparation<E: Error>: ~Copyable, Sendable {
        // Typed throws with Result wrapper to work around Mutex limitation
        public consuming func finalize() -> Result<Witness.Values, E> {
            // Complex error threading...
        }
    }
}
// Adds complexity without achieving the goal cleanly
```

#### Categories of Non-Composition

| Constraint Type | Response |
|-----------------|----------|
| **Fundamental** (Atomic's non-copyability, macro declaration rules) | Adapt immediately |
| **Accidental** (Mutex's throwing limitation) | Still adapt—fighting wastes more time |
| **Temporary** (Swift version gap) | Document and adapt; revisit when Swift evolves |

**Rationale**: Elaborate workarounds add complexity, obscure intent, and create maintenance burden. Simplification often produces better APIs than the original design would have—constraints reveal over-specification.

**Cross-references**: [API-EXC-001], [API-IMPL-004]

---

### [API-DESIGN-003] Separate Policy from Storage

**Scope**: Types that store data and may behave differently in different contexts.

**Statement**: Storage types MUST be inert—they hold data but do not interpret it. Policy types interpret data. Storage and policy MUST NOT be mixed in the same type when the data might cross context boundaries.

**Correct**:
```swift
// Storage is inert - holds data only
public struct Values: Sendable {
    var overrides: [ObjectIdentifier: Any]
    var storage: Storage  // Cache reference
}

// Policy is separate - interprets data
public struct Context: Sendable {
    public enum Mode { case live, test, preview }
    let mode: Mode
    let values: Values

    // Policy determines behavior
    public func value<W: Witness>(_: W.Type) -> W.Value {
        switch mode {
        case .test: return values.testValue(W.self)
        case .live: return values.liveValue(W.self)
        case .preview: return values.previewValue(W.self)
        }
    }
}
```

**Incorrect**:
```swift
// ❌ Storage carries its own policy
public struct Values: Sendable {
    var isTestContext: Bool  // Policy mixed into storage
    var overrides: [ObjectIdentifier: Any]

    public func value<W: Witness>(_: W.Type) -> W.Value {
        if isTestContext { ... }  // Storage interprets itself
    }
}
// Problem: Values prepared at app launch (isTestContext: false)
// inherited into test scope carries wrong policy
```

#### Why Separation Matters

| Concern | Consequence of Mixing |
|---------|----------------------|
| Inheritance | Child contexts inherit wrong policy |
| Reuse | Same data can't behave differently in different contexts |
| Testing | Test values carry production policy flags |
| Debugging | Policy state hidden inside storage |

The same `Values` instance might be used in different contexts. A values container prepared at app launch (mode: `.live`) might be inherited into a test scope. If mode were stored in Values, inheritance would carry the wrong policy.

**Rationale**: Storage types should be pure data. Policy types should interpret data. Mixing them creates subtle bugs when the same data crosses policy boundaries. Separation makes policy visible and data reusable.

**Cross-references**: [API-IMPL-002], [API-IMPL-010], [PATTERN-020]

---

## Design Principles

**Applies to**: Validating design decisions through evidence.

---

### [API-DESIGN-004] Empirical Measurement Resolves Design Debates

**Scope**: Design decisions where multiple approaches have theoretical merit.

**Statement**: When design debates become theoretical—with arguments citing patterns, precedents, and abstractions on both sides—empirical measurement MUST be introduced to ground the discussion. Measurement takes precedence over theoretical argumentation.

#### Measurement Techniques by Concern

| Design Concern | Measurement Approach |
|----------------|---------------------|
| API usage patterns | Search/grep for actual usage across codebase |
| Type frequency | Count instances of each type variant |
| "Primary" vs "secondary" claims | Quantify which is actually used more |
| Performance assertions | Benchmark the alternatives |
| "Typical" usage claims | Verify against actual call sites |

**Correct**:
```
Design debate: Reference<T> (outer-generic) vs Reference.Box (namespace)?

Theoretical arguments (unresolved):
- "Array<Element> precedent supports outer-generic"
- "Types form hierarchy rooted at immutable box"
- "Namespace patterns suit peer groupings"

Empirical resolution (30 seconds):
$ grep -r "Reference.Indirect" | wc -l    → 21
$ grep -r "Reference.Box" | wc -l         → 8
$ grep -r "Reference.Transfer" | wc -l    → 37

Result: Transfer dominates. No canonical "root" type exists.
Conclusion: Namespace pattern is correct—premises falsified by data.
```

**Incorrect**:
```
Design debate continues for hours through theoretical territory.
Each side cites valid precedents (Array<Element>, peer groupings).
Neither party stops to verify claims about "typical usage."
Decision made based on argument persuasion, not evidence.

❌ Ungrounded debates waste time and may reach wrong conclusions.
```

#### When to Measure

Measurement is REQUIRED when:
1. Both positions cite valid precedents or patterns
2. Arguments rest on claims about "typical usage" or "primary abstractions"
3. The debate has cycled through the same points more than twice
4. A hidden premise could be empirically verified or falsified

The measurement need not be perfect—a crude grep across the workspace often suffices. What matters is that *something empirical* enters the discussion.

**Rationale**: Theoretical arguments can continue indefinitely when both sides have valid points. Each position seems defensible on its own terms. Empirical measurement—even imperfect measurement—introduces data that can falsify premises. The grep takes 30 seconds; the ungrounded debate can take hours. This applies beyond API design to package organization, module boundaries, and abstraction choices.

**Cross-references**: [API-DESIGN-001], [API-DESIGN-002], [API-DESIGN-005]

---

### [API-DESIGN-005] Surface Hidden Premises Through Challenge

**Scope**: Design proposals with hierarchies, "primary types," or "canonical" designations.

**Statement**: Design proposals often contain hidden premises that feel like universal truths until articulated. Reviewers MUST identify and explicitly state the load-bearing premises underlying any proposed hierarchy or abstraction. Once stated, premises become falsifiable.

#### Identifying Hidden Premises

Hidden premises typically take these forms:

| Premise Type | Example | Challenge Question |
|--------------|---------|-------------------|
| Canonical designation | "Box is the canonical Reference" | "What makes Box more canonical than Indirect?" |
| Hierarchy root | "All types derive from X" | "What premise makes X the natural root?" |
| Primary abstraction | "The outer type is primary" | "Would stakeholders accept that claim if stated explicitly?" |
| Implicit definition | "This is what X means" | "Is that a definition or an assertion?" |

**Correct**:
```
Proposal: Use Reference<T> with nested types (Box, Indirect, etc.)
Stated arguments: Array<Element> precedent, shorter syntax, ergonomics

Challenge: "Your hierarchy argument is valid only if we commit to the
           premise that immutable strong box is the canonical 'Reference to T'."

Result: Premise was never stated. Once articulated:
        - It became testable (grep for actual usage)
        - The data falsified it (Transfer dominates, not Box)
        - The design decision became clear (keep namespace)
```

**Incorrect**:
```
Proposal: Use Reference<T> with nested types
Arguments proceed through analogy, precedent, ergonomics
Each argument seems valid on its own terms
Design seems defensible

❌ Hidden premise: "Immutable strong box is the canonical Reference"
   - Never stated explicitly
   - Load-bearing for entire design
   - Would be controversial if articulated
   - Empirically false, but never tested
```

#### The Challenge Protocol

For any proposed hierarchy or "primary type":

1. **Identify the root claim**: What is being designated as primary/canonical/root?
2. **State the premise explicitly**: "This design requires the premise that X is the canonical Y."
3. **Test acceptance**: Would stakeholders accept that premise if stated directly?
4. **Verify empirically**: Can the premise be measured? (See [API-DESIGN-004])

If the premise is controversial or empirically questionable, the hierarchy is suspect.

#### "Definition" vs "Assertion" Trap

Claims that masquerade as definitions are particularly insidious:

```
"The canonical Reference is the immutable strong box"

This sounds like a definition ("canonical" = "immutable strong").
But it's actually an assertion about which type should be privileged.
Assertions require justification; definitions do not.
The disguise prevents scrutiny.
```

**Rationale**: Monologic analysis rarely surfaces hidden premises—the designer has no incentive to articulate premises they implicitly accept. Adversarial challenge creates that incentive. Each challenge forces a more precise statement of the position. The final conclusion may not match where analysis started—but it will be *correct*, arrived at through iterative refinement under pressure.

**Cross-references**: [API-DESIGN-004], [API-DESIGN-006]

---

### [API-DESIGN-006] Matrix vs Tree Structure Test

**Scope**: Choosing between outer-generic patterns (`Container<T>`) and namespace patterns (`Namespace.Type`).

**Statement**: Before choosing between outer-generic and namespace patterns, the axes of variation MUST be analyzed. If types vary on orthogonal axes (matrix structure), namespace patterns are correct. If types vary along a single primary axis with derived variants (tree structure), outer-generic patterns are correct.

#### Structural Analysis

| Structure | Characteristics | Pattern |
|-----------|-----------------|---------|
| **Tree** | One axis is clearly primary; other types are derived/variations | Outer-generic (`Container<Element>`) |
| **Matrix** | Multiple orthogonal axes; no cell is naturally "root" | Namespace (`Namespace.TypeA`, `Namespace.TypeB`) |

#### Reference Types as Matrix Example

|  | Immutable | Mutable | Move/Take |
|--|-----------|---------|-----------|
| **Strong** | `Box` | `Indirect` | `Slot` |
| **Weak** | — | `Weak` | — |
| **Unowned** | `Unowned` | — | — |

The Reference types vary on two orthogonal axes—ownership (strong/weak/unowned) and mutability (immutable/mutable/move). Not all cells are filled. Neither axis is clearly "primary."

**Correct**:
```swift
// Matrix structure → Namespace pattern
enum Reference {}

extension Reference {
    struct Box<Value> { }      // Strong + Immutable
    struct Indirect<Value> { } // Strong + Mutable
    struct Slot<Value> { }     // Strong + Move
    struct Weak<Value> { }     // Weak + Mutable
    struct Unowned<Value> { }  // Unowned + Immutable
}

// Tree structure → Outer-generic pattern
struct Array<Element> {
    struct Iterator { }  // Derived from Array
    struct Index { }     // Derived from Array
}
// Array is clearly primary; Iterator/Index are variations
```

**Incorrect**:
```swift
// ❌ Forcing matrix into tree
struct Reference<Value> {
    // Must pick a "canonical" cell as root
    // But which is canonical? Box? Indirect?
    struct Weak { }    // Now appears derived from Reference<T>
    struct Slot { }    // But it's not—they're orthogonal peers
}
// Creates artificial hierarchy where none exists
```

#### The Three-Step Heuristic

1. **List the axes of variation**: What dimensions do the types vary along?
2. **Check axis relationship**: Is one axis clearly primary (tree) or are axes orthogonal (matrix)?
3. **Match pattern to structure**: Matrix → namespace; Tree → outer-generic.

#### Why Forcing Matters

The outer-generic pattern (`Reference<T>`) implies a tree: one root, with variations branching from it. Using this pattern for a matrix forces picking a "canonical" cell to serve as root—even when no cell is naturally canonical. This creates:

- Artificial hierarchy (Box appears more fundamental than Indirect)
- Hidden premises (see [API-DESIGN-005])
- Misleading API ergonomics

**Rationale**: Namespace patterns correctly represent matrices by treating types as peers. Outer-generic patterns correctly represent trees by establishing a primary type with variations. Mismatching pattern to structure creates artificial hierarchy and obscures the actual type relationships.

**Cross-references**: [API-DESIGN-004], [API-DESIGN-005], [API-NAME-001]

---

## Design Validation

**Applies to**: Review process for significant architectural decisions.

---

### [API-DESIGN-007] Adversarial Review as Design Mechanism

**Scope**: Design review process for significant architectural decisions.

**Statement**: Significant design decisions MUST undergo adversarial review—review by parties with different optimization targets than the author. Monologic analysis (self-review, single-perspective analysis) is insufficient for surfacing hidden premises and validating design choices.

#### Why Adversarial Review Works

| Step | What Happens |
|------|--------------|
| 1. Position stated | Author articulates design proposal |
| 2. Counterargument | Reviewer with different priors challenges |
| 3. Premises exposed | Challenge forces articulation of hidden assumptions |
| 4. Testability gained | Exposed premises become falsifiable claims |
| 5. Verification | Claims can be measured (see [API-DESIGN-004]) |

**Correct**:
```
Initial: Reference<T> follows Array<Element> pattern, therefore principled.
After challenge: Pattern applies only when outer type is primary abstraction.
After deeper challenge: "Primary abstraction" requires explicit canonical premise.
After measurement: Premise is empirically false.

Result: Final conclusion (keep namespace) differs from initial position
        but is *correct*, arrived at through iterative refinement.
```

**Incorrect**:
```
Author: "I've thought this through carefully. Reference<T> is right."
Author: "I'll review my own reasoning to make sure."
Author: "Yes, my arguments hold up."

❌ Self-review cannot generate genuine counterarguments.
   Author has no incentive to articulate premises they accept.
   Hidden assumptions remain hidden.
```

#### Why Self-Review Fails

Monologic analysis rarely surfaces hidden premises because:

1. **No incentive to articulate accepted premises**: The author implicitly accepts their own assumptions
2. **Confirmation bias**: Self-review tends to strengthen existing position
3. **Same optimization target**: Cannot simultaneously prioritize competing concerns equally

The value of adversarial review is not that reviewers are smarter—it's that they optimize for different things:

| Author Focus | Reviewer Focus | Flaw Found |
|--------------|----------------|------------|
| API elegance | Safety invariants | Safety erosion hidden by elegance |
| Safety | Usability | Usability problems masked by safety focus |
| Performance | Maintenance | Technical debt obscured by speed gains |

#### Requirements for Genuine Adversarial Review

1. **Different priors**: Reviewer must have genuinely different optimization targets
2. **Actual pushback**: Reviewer must actually challenge, not just validate
3. **Iterated refinement**: Multiple rounds of challenge-response are expected
4. **Willingness to revise**: Author must accept that initial solution may not be final

**Rationale**: "Debate with yourself" advice fails because you cannot simultaneously hold competing optimization targets with equal weight. Genuine adversarial pressure requires a party who will actually push back. The resulting design may not match where analysis started—but it will be arrived at through iterative refinement under pressure, not persuasion.

**Cross-references**: [API-DESIGN-004], [API-DESIGN-005], [API-DESIGN-006]

---

### [API-DESIGN-008] Detecting Over-Engineering During Implementation

**Scope**: Recognizing when implementation reveals incorrect planning assumptions.

**Statement**: Plans are hypotheses; implementation is the experiment. When implementation reveals a plan was based on incorrect premises, the correct response is to update the plan—not to force implementation to match it. Signs of over-engineering MUST trigger plan revision.

#### Signs of Over-Engineering

| Signal | What It Indicates |
|--------|------------------|
| A primitive's primary feature goes unused | Wrong primitive for this use case |
| Wrapping things just to satisfy type requirements | API mismatch, not missing glue |
| "Before" and "after" behavior are identical | Change adds complexity without benefit |
| Justification requires explaining why the simple thing won't work | Simple thing probably works |

**Correct**:
```
Plan: "Add Cache<ObjectIdentifier, UnsafeRawPointer> for in-flight coordination"

Implementation discovery:
- Witness resolution uses static properties (liveValue, testValue)
- These are synchronous
- No async computation where multiple callers might race
- Cache excels at async compute-once-with-waiters—pattern doesn't exist here

Response: Defer Cache integration—it wasn't needed.
Update plan to reflect actual requirements.
```

**Incorrect**:
```
Plan: "Add Cache<ObjectIdentifier, UnsafeRawPointer> for in-flight coordination"

Implementation discovery: Same as above.

Response: "Plan says Cache, so find a way to use Cache."
Force integration despite no use case.
Add complexity to justify the plan.

❌ Plans serve implementation, not the reverse.
```

#### When to Revise Plans

Revise the plan when:
1. The primary reason for a choice no longer applies
2. A simpler solution achieves the same outcome
3. The use case the plan addressed doesn't exist
4. Implementation difficulty stems from fundamental mismatch, not incidental complexity

The plan was written before full context. It optimized for a problem that subsequent analysis revealed wasn't present. Updating the plan is not failure—it's learning.

**Rationale**: Plans are written with incomplete information. Implementation provides new information. Treating plans as immutable leads to over-engineering. The correct response to "this doesn't fit" is often "it wasn't needed," not "make it fit."

**Cross-references**: [API-DESIGN-004], [API-DESIGN-007]

---

### [API-DESIGN-009] Research Papers as Architecture Validation Instruments

**Scope**: Using technical research to validate existing architectural decisions.

**Statement**: Technical research papers, architecture explorations, and constraint analyses SHOULD be used to validate existing architecture, not just to discover changes. When thorough analysis concludes "no changes required," that outcome is as valuable as discovering necessary modifications.

#### Validation vs Discovery

| Outcome | Value |
|---------|-------|
| **Discovery** (changes needed) | Identifies improvements, prevents bugs |
| **Validation** (no changes needed) | Confirms architecture, documents rationale |

Both outcomes require the same analytical rigor. The absence of findings is itself a finding when supported by thorough investigation.

#### Signs of Validated Architecture

Architecture is validated (not merely untested) when:

1. **Code comments anticipate constraints**: Documentation already explains why certain patterns aren't used
2. **Layering boundaries match constraint boundaries**: Concerns are isolated to their semantic homes
3. **No accidental coupling exists**: New constraints don't propagate through layers

**Correct**:
```swift
// Example: Parsing primitives already anticipated ~Escapable limitations

// In Parsing.Parser.swift (written before constraint analysis):
/// For bytes parsing, use `Parsing.Bytes.Input` (an escapable cursor type)
/// rather than `Span<UInt8>` directly. Swift 6.2 does not allow `~Escapable`
/// constraints on protocol associated types.
associatedtype Input

// Constraint analysis discovers this limitation
// Code already documents it → Architecture validated
```

**Incorrect**:
```swift
// Architecture lacks anticipatory documentation
// Constraint analysis reveals limitation
// Code must be restructured to accommodate

// ❌ This indicates architecture was not designed with constraint awareness
```

#### The Validation Process

1. **Research constraint**: Understand the limitation through documentation, proposals, or experimentation
2. **Map to architecture**: Identify which layers the constraint affects
3. **Check existing design**: Does the architecture already account for this constraint?
4. **Document outcome**: Whether validated or invalidated, record the analysis

#### Why Negative Findings Matter

A task that concludes "no changes required" may appear to produce no work product. This is incorrect. The work product is:

- Confirmation that architecture correctly defers concerns to appropriate layers
- Documentation of why the separation is correct
- Recorded analysis for future reference
- Understanding of bridge patterns for cross-layer interoperability

**Rationale**: Well-designed architecture anticipates constraints that haven't yet been encountered. Research that validates existing design confirms the architecture's quality. Research that invalidates existing design reveals improvement opportunities. Both outcomes require the same analytical investment and produce equivalent value—they differ only in what they reveal, not in their worth.

**Cross-references**: [API-DESIGN-004], [API-DESIGN-007], [DOC-CODE-004]

---

## Topics

### Related Documents

- <doc:Memory>
- <doc:API-Requirements>
- <doc:API-Implementation>
- <doc:API-Errors>
- <doc:Primitives-Architecture>
- <doc:Implementation-Patterns>

### Process Documents

- <doc:Documentation-Maintenance>
