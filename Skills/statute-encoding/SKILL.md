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

Encode statute text as executable Swift types. Stay as close to the legal text as
possible, introducing as few new concepts as possible. The statute text is the sole
source of truth.

The approach is **uniform and deterministic**: every provision uses the same
`@Splat` + `Arguments` + `Error` + `CustomStringConvertible` pattern. Inputs are
`Bool?` properties named after the literal statutory conditions. Outputs are `Bool?`
conclusions derived via `Bool?.all { }` / `Bool?.any { }` from Logic Ternary Primitives.
Composition happens at the article level; cross-article composition belongs in the
law layer (`rule-law-*`).

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

## The Uniform Pattern

### [LEG-ENC-002] @Splat + Arguments + Error

**Statement**: Every conditional provision MUST use the `@Splat` + `Arguments` +
`Error` + `CustomStringConvertible` pattern. This is the uniform, deterministic
approach — the same structure every time.

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
        public let `betreft het een gemeente`: Bool?
        public let `betreft het een waterschap`: Bool?
        public let `is het een lichaam waaraan krachtens de Grondwet verordenende bevoegdheid is verleend`: Bool?

        public init(
            `betreft het de Staat`: Bool? = nil,
            `betreft het een provincie`: Bool? = nil,
            `betreft het een gemeente`: Bool? = nil,
            `betreft het een waterschap`: Bool? = nil,
            `is het een lichaam waaraan krachtens de Grondwet verordenende bevoegdheid is verleend`: Bool? = nil
        ) { /* assign each */ }
    }

    @_documentation(visibility: package)
    public init(_ arguments: Arguments) throws(Error) {
        self.`het bezit rechtspersoonlijkheid` = Bool?.any {
            arguments.`betreft het de Staat`
            arguments.`betreft het een provincie`
            arguments.`betreft het een gemeente`
            arguments.`betreft het een waterschap`
            arguments.`is het een lichaam waaraan krachtens de Grondwet verordenende bevoegdheid is verleend`
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

**The pattern provides**:
- `Arguments` — captures all inputs as a reusable type
- `Error` — stores the arguments for substantiation
- `@Splat` — generates convenience `init` with labeled arguments
- `CustomStringConvertible` — human-readable Dutch substantiation
- `Bool?.any { }` / `Bool?.all { }` — Kleene ternary logic composition

**Inputs**: `Bool?` properties named after the literal statutory conditions.
Property names ARE the statute text. Do NOT invent terms not in the statute.

**Outputs**: `Bool?` conclusions derived from the inputs. Property names describe
the legal effect in the statute's own words.

**Cross-references**: [LEG-ENC-001], ARCHITECTURE.md §3, §5

---

### [LEG-ENC-003] Bool? for All Factual Conditions

**Statement**: Every factual condition from the statute MUST be modeled as `Bool?`
using ternary logic (Kleene K₃).

- `true` — condition is met
- `false` — condition is not met
- `nil` — condition is not assessed / unknown

Each condition is independently assessable. You might know "it is NOT de Staat"
(`false`) while not yet knowing about the others (`nil`).

Use `Bool?.all { }` for AND composition and `Bool?.any { }` for OR composition
from Logic Ternary Primitives.

**Cross-references**: [LEG-ENC-002], ARCHITECTURE.md §3

---

### [LEG-ENC-004] Normative Provisions

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

### [LEG-ENC-005] Conditional Provisions

**Statement**: When a provision contains conditions, it MUST use the @Splat pattern
[LEG-ENC-002] with those conditions as `Bool?` inputs and derive `Bool?` conclusions.

**Dutch condition indicators** (non-exhaustive):
- "indien" / "wanneer" / "als" → condition
- "voor zover" / "in zoverre" → scope condition
- "tenzij" → exception (negated condition)
- "mits" → prerequisite condition
- "kan... op verzoek van" → requires request
- "op grond van" / "krachtens" → basis condition
- Listed items with shared consequence → OR (`Bool?.any { }`)
- Cumulative requirements ("en", "alsmede") → AND (`Bool?.all { }`)

**Cross-references**: [LEG-ENC-001], [LEG-ENC-002], [LEG-ENC-003]

---

## Enums (Narrow Exception)

Enums are the exception, not the default. Use them ONLY when the statute itself
defines categorized paths where different conditions are bound to different categories.
Even then, the enum serves the statute's own structure — do not invent collective nouns
or impose mutual exclusivity the statute doesn't state.

### [LEG-ENC-010] When to Use Enums

**Statement**: An enum SHOULD be used only when the statute defines distinct categories
where:
1. Each category carries its own conditions (not shared across categories)
2. Asking the wrong category's conditions would be meaningless
3. The category choice is a factual input, not derived

**Example** — Art 24 lid 4 defines three categories of persons, each with own gate:
```swift
public enum Verzoeker: Sendable {
    case belanghebbende(`betreft het een stichting`: Bool?)
    case schuldeiser(`heeft het bestuur voldaan aan artikel 19b lid 1`: Bool?)
    case `voormalig betrokkene`(betrokkenheid: Betrokkenheid, `toont redelijk belang aan`: Bool?)
}
```

A `belanghebbende` should never be asked about `toont redelijk belang aan`.
The category determines which conditions are relevant. The enum captures this.

**When NOT to use an enum**: The statute lists items that share the same consequence
without distinct conditions per item (e.g., "X, Y, Z bezitten rechtspersoonlijkheid").
Use `Bool?` per item with the @Splat pattern instead.

**Cross-references**: [LEG-ENC-002], [LEG-ENC-001]

---

### [LEG-ENC-011] Sum-of-Products

**Statement**: When using enums per [LEG-ENC-010], each case MUST carry only the
associated data relevant to that alternative. Do not mix enum and flat Bool? for
the same set of alternatives.

**Cross-references**: [LEG-ENC-010]

---

### [LEG-ENC-012] Nested Enums and Case Constraints

**Statement**: When an enum case itself has sub-choices, model as a nested enum.
When a case is restricted to a specific context, the choice of case encodes that
constraint — no separate boolean needed.

```swift
public enum Orgaan: Sendable {
    case `de algemene vergadering`   // choosing this asserts: non-stichting
    case `het bestuur`               // choosing this asserts: stichting
}
```

**Cross-references**: [API-NAME-001], [LEG-ENC-010]

---

### [LEG-ENC-013] Conclusion Enums

**Statement**: When the statute's conclusion distinguishes categories or bases,
the output MAY be modeled as an enum that preserves the statutory basis.

```swift
public enum Conclusie: Sendable {
    case gekwalificeerd(Grond)
    case `niet gekwalificeerd`
    case onbeoordeeld
}
```

**When Bool? IS sufficient**: When the provision's conclusion is genuinely binary
(the statute says "X happens" or "X does not happen" with no further distinction),
`Bool?` is the correct output type. This is the common case.

**Cross-references**: [LEG-ENC-001]

---

## Provision Structure

### [LEG-ENC-020] Each Provision Is Self-Contained

**Statement**: Each provision (lid) MUST define its own types as nested types within
its struct. Types MUST NOT be shared across provisions. If two provisions use similar
concepts, they each define their own version. The composition layer (`rule-law-*`)
can unify later.

**Cross-references**: [LEG-ENC-001]

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
