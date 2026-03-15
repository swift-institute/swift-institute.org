---
name: statute-encoding
description: |
  Encoding statute text as flat structs of Bool? questions with ternary logic conclusions.
  Legislature layer only — composition and questioning strategy belong in rule-law-*.
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

Encode statute text as flat structs of `Bool?` questions. Each provision is a struct
where every statutory condition becomes a `Bool?` property, and every statutory
conclusion becomes a derived `Bool?` output. Property names are the literal statute
text. Nothing more.

The legislature layer answers: **given these facts, what does the statute conclude?**

The composition layer (`rule-law-*`) answers: **given what we know so far, what
should we ask next?** That logic does not belong here.

---

## Foundational Principles

### [LEG-ENC-001] Literal Encoding

**Statement**: Each provision (lid) MUST encode its own statutory text literally. The inputs
are the facts the provision mentions. The outputs are the conclusions the provision's text
derives. Nothing more, nothing less.

- If the statute says "indien X" → X is a `Bool?` input
- If the statute says "dan Y" → Y is a `Bool?` output
- If the statute says "tenzij Z" → Z is a `Bool?` input (negated in logic)
- If the text doesn't mention a fact → the provision does NOT take it as input
- If the statute lists items → one `Bool?` per item, not an invented enum

The legislature layer encodes ONLY the literal text. No interpretation, no jurisprudence,
no case law, no policy, no invented collective nouns.

**Cross-references**: ARCHITECTURE.md §1

---

### [LEG-ENC-002] Flat Struct of Bool? Questions

**Statement**: Every provision MUST be a flat struct where each statutory condition is a
`Bool?` property. This is the uniform, deterministic approach — the same structure every
time. No enums, no nested domain types, except where the statute itself defines
categorized paths (see [LEG-ENC-010]).

Every `Bool?` represents a question the statute asks:
- `true` — yes
- `false` — no
- `nil` — not yet assessed / unknown

Each question is independently assessable. The consumer decides which questions to answer
and in what order. The legislature layer does not prescribe a questioning strategy.

**Cross-references**: [LEG-ENC-001], ARCHITECTURE.md §3

---

### [LEG-ENC-003] @Splat + Arguments + Error

**Statement**: Every conditional provision MUST use the `@Splat` + `Arguments` +
`Error` + `CustomStringConvertible` pattern.

```swift
@Splat
public struct `1`: Sendable {
    @_documentation(visibility: package)
    public let arguments: Arguments

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
- `Arguments` — flat struct of `Bool?` questions, one per statutory condition
- `Error` — stores the arguments for substantiation
- `@Splat` — generates convenience `init` with labeled arguments
- `CustomStringConvertible` — human-readable Dutch substantiation
- `Bool?.any { }` / `Bool?.all { }` — Kleene ternary logic composition

**Cross-references**: [LEG-ENC-001], [LEG-ENC-002], ARCHITECTURE.md §5

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

**Cross-references**: [LEG-ENC-001]

---

### [LEG-ENC-005] Conditional Provisions

**Statement**: When a provision contains conditions, it MUST use the @Splat pattern
[LEG-ENC-003] with those conditions as `Bool?` inputs and derive `Bool?` conclusions.

**Logic composition**:
- Listed items with shared consequence → `Bool?.any { }` (disjunction/OR)
- Cumulative requirements ("en", "alsmede") → `Bool?.all { }` (conjunction/AND)
- Exception ("tenzij") → `.map { !$0 }` (negation)
- Nested: `Bool?.any { Bool?.all { a; b }; c }` for `(a && b) || c`

**Dutch condition indicators** (non-exhaustive):
- "indien" / "wanneer" / "als" → condition
- "voor zover" / "in zoverre" → scope condition
- "tenzij" → exception (negated)
- "mits" → prerequisite
- "kan... op verzoek van" → requires request
- "op grond van" / "krachtens" → basis condition

**Cross-references**: [LEG-ENC-001], [LEG-ENC-002], [LEG-ENC-003]

---

## Layer Boundary

### [LEG-ENC-006] What the Legislature Layer Provides

**Statement**: The legislature layer provides:
1. **Questions** — `Bool?` properties named after the statute text
2. **Conclusions** — `Bool?` properties derived from the questions
3. **Substantiation** — `Error` with `CustomStringConvertible` explaining why

The legislature layer does NOT provide:
- Which question to ask next (questioning strategy)
- Which question matched (witness/proof)
- Cross-article composition
- Legal interpretation

These belong in `rule-law-*` (the composition layer), which consumes the legislature
encoding and adds reasoning:
- **What to ask next**: inspect which `Bool?` inputs are still `nil`
- **Which one matched**: inspect which `Bool?` inputs are `true`
- **Cross-article**: compose multiple article structs
- **Interpretation**: apply case law, doctrine, policy

**Cross-references**: ARCHITECTURE.md §1, §12

---

## Enums (Narrow Exception)

### [LEG-ENC-010] When to Use Enums

**Statement**: An enum SHOULD be used only when the statute itself defines distinct
categories where different conditions are bound to different categories, AND asking
the wrong category's conditions would be meaningless.

This is rare. The test: would a flat struct of `Bool?` force the consumer to answer
irrelevant questions? If yes, use an enum. If the questions are all independently
meaningful, use a flat struct.

**Example** — Art 24 lid 4 defines three categories of persons, each with own gate:
```swift
public enum Verzoeker: Sendable {
    case belanghebbende(`betreft het een stichting`: Bool?)
    case schuldeiser(`heeft het bestuur voldaan aan artikel 19b lid 1`: Bool?)
    case `voormalig betrokkene`(betrokkenheid: Betrokkenheid, `toont redelijk belang aan`: Bool?)
}
```

A `belanghebbende` should never be asked about `toont redelijk belang aan`.

**When NOT to use an enum**: The statute lists items sharing the same consequence
(e.g., "X, Y, Z bezitten rechtspersoonlijkheid"). Use flat `Bool?` per item.

**Cross-references**: [LEG-ENC-002]

---

## Provision Structure

### [LEG-ENC-020] Each Provision Is Self-Contained

**Statement**: Each provision (lid) MUST define its own types as nested types within
its struct. Types MUST NOT be shared across provisions. The composition layer can
unify later.

**Cross-references**: [LEG-ENC-001]

---

### [LEG-ENC-021] Composition at Article Level

**Statement**: The article coordinator composes its provisions:
1. Instantiates each provision with relevant inputs
2. Feeds conclusions from earlier provisions into later provisions where the statute
   requires it
3. Derives article-level conclusions

```swift
self.`2` = `Artikel 24`.`2`(
    `ontbreekt er een bewaarder`: aanwijzing == nil,  // derived from lid 1
    ...
)
```

Cross-article composition belongs in `rule-law-*`.

**Cross-references**: ARCHITECTURE.md §1, §12

---

## Naming

### [LEG-ENC-030] Backticked Dutch Legal Terminology

**Statement**: Properties encoding Dutch statutory language MUST use backticked
identifiers preserving the exact Dutch phrasing from the statute text.

```swift
public let `is de laatste vereffenaar bereid te bewaren`: Bool?
public let `betreft het de Staat`: Bool?
```

Do NOT invent terms not in the statute. Legislative cross-references belong in
documentation comments, not in identifiers.

**Cross-references**: Legal Encoding Standard.md §Naming Conventions
