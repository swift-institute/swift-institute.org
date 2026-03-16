---
name: statute-encoding
description: |
  Encoding statute text as flat structs of Bool? questions with ternary logic conclusions.
  Legislature layer only — composition and questioning strategy belong in rule-law-*.
  Includes namespace packaging: root namespace enums, multi-book three-package pattern
  (core/per-book/umbrella), and composition layer integration.
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

---

## Statute Namespace Packaging

### [LEG-ENC-040] Root Namespace Type

**Statement**: Every statute MUST define a root namespace enum so that its types
can be disambiguated at the composition layer. Without a namespace, multiple
statutes exporting `Artikel 1` collide when imported together.

**Single-statute packages** define the namespace directly:
```swift
// advocatenwet/Sources/Advocatenwet/Advocatenwet.swift
public enum Advocatenwet {}

// advocatenwet/Sources/Advocatenwet/Artikel 1.swift
extension Advocatenwet {
    @Splat
    public struct `Artikel 1`: Sendable { ... }
}
```

Access: `Advocatenwet.`Artikel 1`.`1``

**Multi-book statutes** use a separate core package (see [LEG-ENC-041]).

**Naming convention**: The canonical namespace uses the full Dutch legal name.
A typealias provides the standard abbreviation for convenience:

```swift
public enum `Burgerlijk Wetboek` {}
public typealias BW = `Burgerlijk Wetboek`
```

| Statute | Canonical | Typealias |
|---------|-----------|-----------|
| Burgerlijk Wetboek | `` `Burgerlijk Wetboek` `` | `BW` |
| Wetboek van Strafrecht | `` `Wetboek van Strafrecht` `` | `WvSr` |
| Wetboek van Strafvordering | `` `Wetboek van Strafvordering` `` | `WvSv` |
| Wetboek van Burgerlijke Rechtsvordering | `` `Wetboek van Burgerlijke Rechtsvordering` `` | `Rv` |
| Wetboek van Koophandel | `` `Wetboek van Koophandel` `` | `WvK` |
| Advocatenwet | `Advocatenwet` | — (no standard abbreviation) |

Both paths are valid:
- `` `Burgerlijk Wetboek`.`2`.`Artikel 1`.`1` `` (canonical)
- `` BW.`2`.`Artikel 1`.`1` `` (convenience)

**Cross-references**: ARCHITECTURE.md §4, §12

---

### [LEG-ENC-041] Multi-Book Statute Packaging

**Statement**: When a statute comprises multiple books, it MUST use a three-package
pattern:

1. **Core package** (`{statute}-core`): Exports the root namespace enum only
2. **Per-book packages** (`{statute}-boek-{N}`): Depend on core, extend namespace
3. **Umbrella package** (`{statute}`): Depends on all book packages, re-exports all

```
swift-nl-wetgever/
├── burgerlijk-wetboek-core/           # public enum BW {}
├── burgerlijk-wetboek-boek-1/         # extension BW { public enum `1` {} }
├── burgerlijk-wetboek-boek-2/         # extension BW { public enum `2` {} }
├── ...
├── burgerlijk-wetboek-boek-10/        # extension BW { public enum `10` {} }
└── burgerlijk-wetboek/                # umbrella: @_exported import all
```

**Rationale**: Consumers can depend on individual books (pay only for what you use)
or the umbrella (convenience). The core ensures all books share the same root
namespace type.

**Cross-references**: [LEG-ENC-040], ARCHITECTURE.md §4

---

### [LEG-ENC-042] Core Package

**Statement**: The core package MUST export exactly one type — the root namespace
enum. It has no dependencies beyond standard infrastructure.

```swift
// burgerlijk-wetboek-core/Sources/Burgerlijk Wetboek Core/Burgerlijk Wetboek.swift
public enum `Burgerlijk Wetboek` {}
public typealias BW = `Burgerlijk Wetboek`
```

The core package name follows the pattern `{statute}-core`. The module name is
the statute name plus "Core" (e.g., `Burgerlijk Wetboek Core`). The canonical
type uses the full legal name; the typealias provides the standard abbreviation.

**Cross-references**: [LEG-ENC-040], [LEG-ENC-041]

---

### [LEG-ENC-043] Book Extension Pattern

**Statement**: Each per-book package MUST depend on the core package and extend
the root namespace with a book-level enum. All article types nest under the book.

```swift
// burgerlijk-wetboek-boek-2/Sources/Burgerlijk Wetboek Boek 2/Burgerlijk Wetboek.2.swift
import Burgerlijk_Wetboek_Core

extension `Burgerlijk Wetboek` {
    public enum `2` {}
}
```

```swift
// burgerlijk-wetboek-boek-2/Sources/Burgerlijk Wetboek Boek 2/Artikel 1.swift
extension `Burgerlijk Wetboek`.`2` {
    @Splat
    public struct `Artikel 1`: Sendable {
        // ... (same @Splat + Arguments + Error pattern as [LEG-ENC-003])
    }
}
```

```swift
// burgerlijk-wetboek-boek-2/Sources/Burgerlijk Wetboek Boek 2/Artikel 1.1.swift
extension `Burgerlijk Wetboek`.`2`.`Artikel 1` {
    @Splat
    public struct `1`: Sendable {
        // ... lid encoding
    }
}
```

**Access paths** (both valid):
- `` `Burgerlijk Wetboek`.`2`.`Artikel 1`.`1` `` (canonical)
- `` BW.`2`.`Artikel 1`.`1` `` (via typealias)

Books use bare numeric identifiers (`` `2` ``, not `` `Boek 2` ``), consistent with
the lid naming convention (`` `1` `` not `` `Lid 1` ``).

**Name resolution warning**: After nesting under a namespace, bare type names
in extension bodies may not resolve. Inside `extension BW.\`2\`.\`Artikel 24\``,
a reference to `` `Artikel 24`.\`1\`.Aanwijzing `` fails because `` `Artikel 24` ``
is not at module level. Use fully qualified paths in enum associated values and
type references within extensions:

```swift
// ❌ Fails — `Artikel 24` not found at module level
case aangewezen(`Artikel 24`.`1`.Aanwijzing)

// ✅ Fully qualified
case aangewezen(`Burgerlijk Wetboek`.`2`.`Artikel 24`.`1`.Aanwijzing)
```

Inside the struct body itself, self-references like `` `Artikel 24`.\`1\` ``
resolve correctly (Swift finds the enclosing type). The issue is only in
**extension** bodies and **enum case associated values**.

**Cross-references**: [LEG-ENC-041], [LEG-ENC-003]

---

### [LEG-ENC-044] Umbrella Package

**Statement**: The umbrella package MUST `@_exported import` all book modules
and the core module. It contains no types of its own.

```swift
// burgerlijk-wetboek/Sources/Burgerlijk Wetboek/exports.swift
@_exported import Burgerlijk_Wetboek_Core
@_exported import Burgerlijk_Wetboek_Boek_1
@_exported import Burgerlijk_Wetboek_Boek_2
@_exported import Burgerlijk_Wetboek_Boek_3
@_exported import Burgerlijk_Wetboek_Boek_4
@_exported import Burgerlijk_Wetboek_Boek_5
@_exported import Burgerlijk_Wetboek_Boek_6
@_exported import Burgerlijk_Wetboek_Boek_7
@_exported import Burgerlijk_Wetboek_Boek_7A
@_exported import Burgerlijk_Wetboek_Boek_8
@_exported import Burgerlijk_Wetboek_Boek_10
```

Consumers choose their dependency granularity:
- `import Burgerlijk_Wetboek_Boek_2` — single book, minimal compilation
- `import Burgerlijk_Wetboek` — all books via umbrella

Both give access through the `BW` namespace.

**Cross-references**: [LEG-ENC-041], [LEG-ENC-042], [LEG-ENC-043]

---

### [LEG-ENC-045] Four-Layer Stack

**Statement**: The full legal encoding stack has four layers. Each layer is a
separate GitHub organization with one repo per unit. Dependencies flow strictly
downward.

```
Layer 4: rule-legal-{jurisdiction}/          Products (commercial)
             rule-besloten-vennootschap          Aandeelhoudersregister, etc.
                 │
Layer 3: rule-law-{jurisdiction}/            Composition (commercial)
             rule-burgerlijk-wetboek-2           Binds statute + case law
                 │
         ┌───────┴───────┐
         │               │
Layer 2a: swift-{jurisdiction}-wetgever/     Legislature (open source)
              burgerlijk-wetboek-boek-2          BW.`2`.`Artikel N`.`M`
                  │
Layer 2b: swift-{jurisdiction}-hoge-raad/    Judiciary (open source)
              ecli-nl-hr-YYYY-NNN                1 repo per verdict
                  │
Layer 1:  burgerlijk-wetboek-core/           Namespace (open source)
              public enum `Burgerlijk Wetboek` {}
```

| Layer | GitHub org (NL) | Responsibility | License |
|-------|-----------------|---------------|---------|
| Products | `rule-legal-nl` | Domain products (BV, register) | Commercial |
| Composition | `rule-law-nl` | Statute + case law binding | Commercial |
| Legislature | `swift-nl-wetgever` | 1 repo per statute, literal encoding | Apache 2.0 |
| Judiciary | `swift-nl-hoge-raad` | 1 repo per verdict, literal encoding | Apache 2.0 |

**Naming conventions**:

| Layer | Package name pattern | Example |
|-------|---------------------|---------|
| Products | `rule-{domain}` | `rule-besloten-vennootschap` |
| Composition | `rule-{statute}` | `rule-burgerlijk-wetboek-2` |
| Legislature | `{statute-name}` | `burgerlijk-wetboek-boek-2` |
| Judiciary | `ecli-{court}-{year}-{number}` | `ecli-nl-hr-2019-377` |

**Dependency inversion**: Legislature and judiciary packages have ZERO
cross-dependencies. Statutes do not import other statutes. Verdicts do not
import statutes or other verdicts. Cross-references are modeled as `Bool?`
inputs using dependency inversion. The composition layer is the only place
where statute conclusions feed into verdict inputs and vice versa.

**Validated dependency chain** (BW2 case study, all compile):
```
rule-besloten-vennootschap          (product)
  → rule-burgerlijk-wetboek-2       (composition)
    → burgerlijk-wetboek-boek-2     (legislature)
      → burgerlijk-wetboek-core     (namespace)
```

**Cross-references**: [LEG-ENC-006], [LEG-ENC-040], ARCHITECTURE.md §1, §12

---

## Judiciary Encoding

### [LEG-ENC-050] Verdict Encoding Pattern

**Statement**: Each court verdict MUST be encoded as a standalone package
following the same `@Splat` + `Arguments` + `Bool?` pattern as statutes.
One repo per verdict. Zero cross-dependencies — verdicts do NOT import
statutes or other verdicts.

**Package naming**: `ecli-{court}-{year}-{number}` (kebab-case from ECLI).
Example: `ecli-nl-hr-2019-377` for ECLI:NL:HR:2019:377.

**GitHub org**: `swift-{jurisdiction}-hoge-raad` (or equivalent per court level).
Example: `swift-nl-hoge-raad/ecli-nl-hr-2019-377`.

**Dependency inversion**: When a verdict's reasoning depends on whether a
statutory condition was met, that becomes a `Bool?` input — NOT an import
of the statute package:

```swift
// ❌ WRONG — verdict imports statute
import Burgerlijk_Wetboek_Boek_2
let result = try BW.`2`.`Artikel 194`(...)

// ✅ CORRECT — statutory condition as Bool? input
public let `is voldaan aan artikel 194 lid 1`: Bool?
```

The composition layer (`rule-law-*`) is where statute conclusions are wired
into verdict inputs and vice versa.

**Status**: Pattern established, no reference implementation yet. First
verdict encoding will validate the pattern.

**Cross-references**: [LEG-ENC-001], [LEG-ENC-045], ARCHITECTURE.md §1
