---
name: statute-encoding
description: |
  Algebraic domain modeling for encoding statute text as Swift types.
  Literal encoding per provision, sum-of-products for statutory alternatives,
  composition at article level.
  ALWAYS apply when encoding statute text as executable Swift types.

layer: implementation

requires:
  - swift-institute
  - naming
  - implementation
  - errors

applies_to:
  - legislature
  - statute
  - legal-encoding

---

# Statute Encoding

Encode statute text as algebraic Swift types. Each provision is encoded literally —
the statute text is the sole source of truth. Domain modeling uses enums for statutory
alternatives and structs for conjunctions. Composition happens at the article level;
cross-article composition belongs in the law layer (`rule-law-*`).

**Layer context**: This skill governs the legislature layer (`swift-*-legislature`).
See ARCHITECTURE.md §1 for the full layer stack (legislature → judiciary → law → legal).

---

## Foundational Principle

### [LEG-ENC-001] Literal Encoding

**Statement**: Each provision (lid) MUST encode its own statutory text literally. The inputs
are the facts the provision mentions. The outputs are the conclusions the provision's text
derives. Nothing more, nothing less.

- If the statute says "indien X" → X is an input
- If the statute says "dan Y" → Y is an output
- If the statute says "tenzij Z" → Z is an input (negated in logic)
- If the text doesn't mention a fact → the provision does NOT take it as input

The legislature layer encodes ONLY the literal text. No interpretation, no jurisprudence,
no case law, no policy. If the text contains a condition, it becomes an input. If the text
states an obligation unconditionally, it's normative. The statute text is the sole source
of truth.

**Cross-references**: ARCHITECTURE.md §1

---

## Domain Modeling

### [LEG-ENC-002] Enums for Distinct Procedural Paths

**Statement**: When a statute defines distinct procedural paths with different conditions
or legal consequences (typically using lettered sub-items a/b/c, semicolons separating
categories, or "hetzij... hetzij"), the paths MUST be modeled as an enum. Each case
corresponds to exactly one path and carries only its own conditions as associated data.

**When to use an enum**: The statute defines distinct paths where:
- Each path has its own conditions or consequences
- The caller must choose ONE path (they are procedurally exclusive)
- The path choice determines which conditions are relevant

**Correct** — statute defines 6 distinct ontbindingsgronden, each with own conditions:
```swift
public enum Grond: Sendable {
    case a(Besluit)           // besluit — has sub-structure (AV vs bestuur)
    case b(... : Bool?)       // statutaire gebeurtenis — has condition
    case c(Faillissement)     // faillissement — has sub-structure
    case d(Ledenverband)      // ontbreken leden — encodes rechtsvorm constraint
    case e                    // KvK beschikking
    case f                    // rechterlijk
}
```

**When NOT to use an enum**: The statute merely lists entities or items that share the
same legal consequence without distinct conditions per item. Use a struct with `Bool?`
per item instead (see [LEG-ENC-002a]).

**Cross-references**: [LEG-ENC-002a], [LEG-ENC-003], [API-NAME-001], ARCHITECTURE.md §2.3

---

### [LEG-ENC-002a] Structs for Listed Items

**Statement**: When a statute lists entities, types, or items that all share the same
legal consequence (e.g., "X, Y, Z bezitten rechtspersoonlijkheid"), the list MUST be
modeled as a struct with one `Bool?` property per item. Do NOT invent a collective
enum type.

**Correct** — statute says "De Staat, de provincies, de gemeenten, de waterschappen, alsmede alle lichamen waaraan krachtens de Grondwet verordenende bevoegdheid is verleend, bezitten rechtspersoonlijkheid":
```swift
public struct `1`: Sendable {
    public let `betreft het de Staat`: Bool?
    public let `betreft het een provincie`: Bool?
    public let `betreft het een gemeente`: Bool?
    public let `betreft het een waterschap`: Bool?
    public let `is het een lichaam waaraan krachtens de Grondwet verordenende bevoegdheid is verleend`: Bool?

    public let `het bezit rechtspersoonlijkheid`: Bool?  // OR of above
}
```

**Incorrect** — invented collective noun, adds interpretation:
```swift
public enum Overheidslichaam: Sendable {   // ❌ "Overheidslichaam" is not in the statute
    case `de Staat`                         // ❌ De Staat is not a "lichaam"
    ...
}
```

**Rationale**: Three reasons to prefer the struct approach for listed items:

1. **Literal encoding** — the property names ARE the statute text. An enum requires
   inventing a collective noun not present in the statute.
2. **Ternary logic preservation** — each item is independently assessable. You might
   know "it is NOT de Staat" (`false`) while not yet knowing about the others (`nil`).
   An enum collapses "not one of these" and "don't know" into the same `nil`.
3. **No added interpretation** — the statute does not assert mutual exclusivity.
   Even if the items happen to be mutually exclusive in the real world, encoding that
   is interpretation, not literal transcription.

The conclusion (`het bezit rechtspersoonlijkheid`) is derived via `Bool?.any { }` (OR)
from the individual items. If ANY item is `true`, the conclusion is `true`. If ALL are
`false`, it's `false`. If some are `nil` with none `true`, it's `nil` (indeterminate).

**Cross-references**: [LEG-ENC-001], [LEG-ENC-006]

---

### [LEG-ENC-003] Sum-of-Products for Conditional Alternatives

**Statement**: When different statutory alternatives carry different conditions, each enum
case MUST carry only the associated data relevant to that alternative. A case MUST NOT
require data that is irrelevant to its statutory path.

**Correct** — each case carries only its relevant conditions:
```swift
public enum Verzoeker: Sendable {
    /// Alleen indien stichting
    case belanghebbende(`betreft het een stichting`: Bool?)
    /// Alleen indien bestuur niet voldaan aan art 19b lid 1
    case schuldeiser(`heeft het bestuur voldaan aan artikel 19b lid 1`: Bool?)
    /// Moet redelijk belang aantonen
    case `voormalig betrokkene`(betrokkenheid: Betrokkenheid, `toont redelijk belang aan`: Bool?)
}
```

**Incorrect** — flat product type, every field for every case:
```swift
public struct Arguments: Sendable {
    public let `betreft het een stichting`: Bool?           // ❌ Irrelevant for schuldeiser
    public let `heeft het bestuur voldaan`: Bool?            // ❌ Irrelevant for belanghebbende
    public let `toont redelijk belang aan`: Bool?            // ❌ Irrelevant for both above
    public let hoedanigheid: Hoedanigheid?                   // ❌ Irrelevant for first two
}
```

**Rationale**: The statute ties specific conditions to specific alternatives. A flat product
type allows irrelevant combinations (asking a belanghebbende about redelijk belang). The
sum-of-products makes illegal states unrepresentable.

**Cross-references**: [IMPL-INTENT], ARCHITECTURE.md §2.2, §2.3

---

### [LEG-ENC-004] Nested Enums for Sub-Alternatives

**Statement**: When a statutory alternative itself contains sub-choices, the sub-choices
MUST be modeled as a nested enum on the parent case or type.

**Correct** — the statute distinguishes the appointing organ by rechtsvorm:
```swift
extension Aanwijzing {
    public enum Orgaan: Sendable {
        case `de algemene vergadering`  // non-stichting
        case `het bestuur`              // stichting
    }
}
```

**Rationale**: Nesting mirrors the statute's hierarchical structure. Per [API-NAME-001],
sub-concepts are nested within their parent concept.

**Cross-references**: [API-NAME-001], [LEG-ENC-002]

---

### [LEG-ENC-005] Case Selection Encodes Constraints

**Statement**: When a statutory alternative is restricted to a specific context (e.g.,
a particular rechtsvorm), the choice of enum case MUST encode that constraint. Selecting
the case asserts the constraint. No separate boolean input is needed for the constraint.

**Correct** — choosing `het bestuur` asserts stichting:
```swift
case `door het bevoegde orgaan`(Orgaan)

enum Orgaan: Sendable {
    case `de algemene vergadering`   // choosing this asserts: has an AV (non-stichting)
    case `het bestuur`               // choosing this asserts: stichting
}
```

**Incorrect** — redundant boolean alongside the case:
```swift
case `door het bestuur`(`betreft het een stichting`: Bool?)  // ❌ The case IS the assertion
```

**Rationale**: If a statutory path is only available in context X, constructing that path
IS the proof of context X. A separate boolean creates representable-but-illegal states
(e.g., `door het bestuur` with `betreft het een stichting: false`).

**Exception**: When the statute states a condition as a separate testable fact rather than
a contextual restriction. Use judgment: if the condition gates availability of the path,
encode it in the case. If the condition is a factual input that the provision evaluates,
use associated data.

**Cross-references**: [LEG-ENC-003]

---

### [LEG-ENC-006] Bool? for Simple Factual Conditions

**Statement**: When the statute asks a simple yes/no factual question (not a structured
choice), the condition MUST be modeled as `Bool?` using ternary logic.

- `true` — condition is met
- `false` — condition is not met
- `nil` — condition is not assessed / unknown

```swift
public let `is de laatste vereffenaar bereid te bewaren`: Bool?
public let `is er een verzoek van een belanghebbende`: Bool?
```

Use `Bool?.all { }` and `Bool?.any { }` from Logic Ternary Primitives for Kleene
composition of multiple conditions.

**Cross-references**: ARCHITECTURE.md §3

---

### [LEG-ENC-007] Conclusion Types for Structured Outputs

**Statement**: When the statute's conclusion distinguishes categories, grounds, or bases,
the output MUST be modeled as an enum that preserves the statutory basis. A flat `Bool?`
is insufficient when the statute tells you not just "yes/no" but "yes, because X."

**Correct** — the statute distinguishes three qualifying bases:
```swift
public enum Conclusie: Sendable {
    case gekwalificeerd(Grond)
    case `niet gekwalificeerd`
    case onbeoordeeld
}

extension Conclusie {
    public enum Grond: Sendable {
        case `belanghebbende bij stichting`
        case `schuldeiser bij niet-nakoming artikel 19b lid 1`
        case `voormalig betrokkene met redelijk belang`(Betrokkenheid)
    }
}
```

**Incorrect** — loses the statutory basis:
```swift
public let `de kantonrechter kan machtiging geven`: Bool?  // ❌ Which category? Which basis?
```

**When Bool? IS sufficient**: When the provision's conclusion is genuinely binary (the
statute says "X happens" or "X does not happen" with no further distinction), `Bool?` is
the correct output type.

**Cross-references**: [IMPL-INTENT], [LEG-ENC-001]

---

## Provision Structure

### [LEG-ENC-010] Each Provision Is Self-Contained

**Statement**: Each provision (lid) MUST define its own domain types (enums, structs)
as nested types within its struct. Types MUST NOT be shared across provisions within
the same article. Each provision has its own input types, its own conclusion types,
and its own logic.

```swift
extension `Artikel 24` {
    public struct `1`: Sendable { ... }       // own Aanwijzing enum
}
extension `Artikel 24` {
    public struct `4`: Sendable { ... }       // own Verzoeker enum, own Conclusie enum
}
```

If two provisions happen to use similar concepts, they each define their own version.
The composition layer (`rule-law-*`) can unify later.

**Rationale**: The legislature layer encodes literal text. Different provisions may use
the same word with different legal meaning. Self-containment prevents accidental semantic
coupling.

**Cross-references**: [LEG-ENC-001]

---

### [LEG-ENC-011] Normative Provisions

**Statement**: When a provision states an unconditional obligation, prohibition, or
definition with no conditions, it MUST be modeled as a struct with a parameterless
`init()` and normative output properties defaulting to `true`.

```swift
public struct `3`: Sendable {
    public let `de bewaarder moet zijn naam en adres opgeven aan de registers`: Bool? = true

    public init() {}
}
```

**Rationale**: Normative provisions make statements, not computations. Their truth is
inherent in the statutory text.

**Cross-references**: [LEG-ENC-001]

---

### [LEG-ENC-012] Conditional Provisions

**Statement**: When a provision contains conditions ("indien", "voor zover", "tenzij",
"mits", temporal clauses, "kan... op verzoek van"), it MUST take those conditions as
inputs and derive conclusions.

The input types depend on the statutory structure:
- Simple conditions → `Bool?` per [LEG-ENC-006]
- Enumerated alternatives → enum per [LEG-ENC-002]
- Conditional alternatives → sum-of-products per [LEG-ENC-003]

The output types depend on the conclusion structure:
- Binary conclusion → `Bool?`
- Structured conclusion → enum per [LEG-ENC-007]

**Dutch condition indicators** (non-exhaustive):
- "indien" / "wanneer" / "als" → condition
- "voor zover" / "in zoverre" → scope condition
- "tenzij" → exception (negated condition)
- "mits" → prerequisite condition
- "kan... op verzoek van" → requires request
- "op grond van" / "krachtens" → basis condition
- Enumerated alternatives (a, b, c) → OR conditions
- Cumulative requirements ("en", "alsmede") → AND conditions

**Cross-references**: [LEG-ENC-001], [LEG-ENC-002], [LEG-ENC-006], [LEG-ENC-007]

---

### [LEG-ENC-013] @Splat, Arguments, and Error Pattern

**Statement**: Conditional provisions and provisions with listed items (per [LEG-ENC-002a])
SHOULD use the `@Splat` macro with `Arguments`, `Error`, and `CustomStringConvertible`.

The pattern:

```swift
@Splat
public struct `1`: Sendable {
    @_documentation(visibility: package)
    public let arguments: Arguments

    /// Conclusion derived from the statute text.
    public let `het bezit rechtspersoonlijkheid`: Bool?

    @_documentation(visibility: package)
    public struct Arguments: Sendable {
        public let `betreft het de Staat`: Bool?
        public let `betreft het een provincie`: Bool?
        // ...

        public init(
            `betreft het de Staat`: Bool? = nil,
            `betreft het een provincie`: Bool? = nil,
            // ...
        ) { /* assign */ }
    }

    @_documentation(visibility: package)
    public init(_ arguments: Arguments) throws(Error) {
        self.`het bezit rechtspersoonlijkheid` = Bool?.any {
            arguments.`betreft het de Staat`
            arguments.`betreft het een provincie`
            // ...
        }
        self.arguments = arguments
    }
}

extension `Artikel 1`.`1` {
    @_documentation(visibility: package)
    public struct Error: Swift.Error, Sendable {
        @_documentation(visibility: package)
        public let arguments: Arguments
    }
}

extension `Artikel 1`.`1`.Error: CustomStringConvertible {
    public var description: String {
        """
        Niet voldaan aan de voorwaarden van artikel 1, eerste lid, ...

        Voorwaarden:
        \(conditions.joined(separator: "\n"))
        """
    }
}
```

**Benefits**:
- `Arguments` captures all inputs as a reusable type
- `Error` stores the arguments for substantiation (explaining WHY something didn't qualify)
- `@Splat` generates a convenience `init` with labeled arguments
- `CustomStringConvertible` on Error provides human-readable Dutch substantiation

**When to omit**: Normative provisions [LEG-ENC-011] and provisions where the input
is a single domain enum (e.g., `Verzoeker`) do not benefit from @Splat — the domain
type IS the argument.

**Cross-references**: [LEG-ENC-011], [LEG-ENC-012], ARCHITECTURE.md §5

---

## Composition

### [LEG-ENC-020] Composition at Article Level

**Statement**: The article coordinator (the `Artikel N` struct) MUST compose its
provisions. Provisions MUST NOT compose with other provisions in the same article —
that is the coordinator's job.

The coordinator:
1. Instantiates each provision with relevant inputs
2. Feeds conclusions from earlier provisions into later provisions where the statute
   requires it (e.g., lid 2 references "ontbreekt een bewaarder" from lid 1)
3. Derives article-level conclusions by composing provision conclusions

```swift
// Coordinator feeds lid 1's conclusion into lid 2's input
self.`2` = `Artikel 24`.`2`(
    `ontbreekt er een bewaarder`: aanwijzing == nil,  // derived from lid 1
    ...
)
```

**Rationale**: The statute defines the article as a unit. Intra-article composition
is part of the literal encoding. Cross-article composition belongs in `rule-law-*`.

**Cross-references**: ARCHITECTURE.md §1, §12

---

### [LEG-ENC-021] Article-Level Conclusion Types

**Statement**: When an article's provisions compose into a meaningful whole, the article
coordinator SHOULD define its own conclusion type that synthesizes the provisions.

```swift
extension `Artikel 24` {
    public enum Bewaarder: Sendable {
        case aangewezen(`1`.Aanwijzing)
        case `benoemd door de kantonrechter`
        case `niet vastgesteld`
    }
}
```

This is composition, not interpretation — it combines provisions that the statute itself
places in the same article for a reason.

**Cross-references**: [LEG-ENC-020], [API-NAME-001]

---

## Naming

### [LEG-ENC-030] Backticked Dutch Legal Terminology

**Statement**: Properties and enum cases encoding Dutch statutory language MUST use
backticked identifiers preserving the exact Dutch phrasing from the statute text.

```swift
public let `is de laatste vereffenaar bereid te bewaren`: Bool?
case `bij de statuten`
case `voormalig aandeelhouder`
```

Legislative cross-references ("als bedoeld in artikel X") belong in documentation
comments, not in identifiers.

**Cross-references**: Legal Encoding Standard.md §Naming Conventions

---

### [LEG-ENC-031] Type Nesting Mirrors Statutory Structure

**Statement**: Domain types MUST be nested following [API-NAME-001], mirroring the
statute's hierarchical structure.

```
`Artikel 24`.`4`.Verzoeker.Betrokkenheid
    Article  → Lid → Input type → Sub-type
```

Each level narrows scope: article → provision → domain concept → sub-concept.

**Cross-references**: [API-NAME-001], [LEG-ENC-004]

---

## Reference Implementation

**Artikel 24** of Burgerlijk Wetboek Boek 2 serves as the reference implementation
for this skill. It demonstrates:

- **Lid 1**: Definitional provision with `Aanwijzing` enum (4 statutory paths) and
  nested `Orgaan` enum (rechtsvorm-dependent sub-choice). Case selection encodes
  constraints [LEG-ENC-005].
- **Lid 2**: Conditional provision with `Bool?` inputs and `Bool?.all { }` composition.
  Input `ontbreekt er een bewaarder` stated literally in the lid's text [LEG-ENC-001].
- **Lid 3**: Normative provision [LEG-ENC-011].
- **Lid 4**: Conditional provision with `Verzoeker` sum-of-products [LEG-ENC-003],
  `Betrokkenheid` nested enum [LEG-ENC-004], and `Conclusie` with `Grond` [LEG-ENC-007].
- **Coordinator**: `Bewaarder` article-level conclusion composing leden 1+2 [LEG-ENC-021].

**Location**: `/Users/coen/Developer/swift-nl-wetgever/burgerlijk-wetboek-boek-2/Sources/Burgerlijk Wetboek Boek 2/Artikel 24*.swift`
