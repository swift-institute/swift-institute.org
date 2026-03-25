---
name: documentation
description: |
  Inline DocC comments and .docc catalogue conventions.
  ALWAYS apply when writing or reviewing documentation comments or .docc articles.

layer: implementation

requires:
  - swift-institute
  - code-surface

applies_to:
  - swift-primitives
  - swift-standards
  - swift-foundations
  - swift-institute
  - documentation
  - docc
last_reviewed: 2026-03-20
---

# Documentation

Conventions for inline DocC comments (`///`) and `.docc` catalogue documentation. Covers type, method, and property documentation; specification-mirroring patterns; .docc catalogue structure; cross-reference formats; and content layering between inline docs and catalogue articles.

## Workflow Position

Documentation is the **synthesis step** — it comes last and captures everything that came before:

```
Research → Experiments → Implementation → Iterate → Testing → Documentation
```

| Phase | Artifact | What it produces |
|-------|----------|-----------------|
| Research | `Research/*.md` | Design rationale, trade-off analysis |
| Experiments | `Experiments/*/` | Empirical verification of design decisions |
| Implementation | `Sources/**/*.swift` | Working code |
| Testing | `Tests/**/*.swift` | Verified behavior |
| **Documentation** | `///` + `.docc/` | **Synthesis of all of the above** |

Documentation does not drive research or experiments — it captures them. Inline `///` describes the implementation as it IS. The `.docc` articles reference the research that informed the design, the experiments that verified it, and the tests that guard it.

Two exemplar projects inform these conventions:
- `swift-us-nv-nrs-78-private-corporations` — .docc as navigation scaffolding
- `wet-zeggenschap-lichaamsmateriaal` — .docc as substantive content layer

**Scope**: All inline DocC comments, `.docc` catalogue files, and code comment quality patterns (workaround/deviation/anticipatory templates). README conventions are covered by the **readme** skill.

---

## Inline DocC Comments

### [DOC-001] Summary Line

**Statement**: Every public declaration MUST have a one-line `///` summary as the first documentation line. The summary describes caller-visible behavior, not implementation details.

**Correct**:
```swift
/// Toestemming bij leven
public struct `Artikel 14`: Sendable { ... }
```

```swift
/// Submits work to the executor pool.
public func submit<T>(_ work: @Sendable () throws -> T) async throws(IO.Lifecycle.Error<IO.Error>) -> T
```

**Incorrect**:
```swift
/// This struct uses @Splat macro and stores arguments in a nested type.
public struct `Artikel 14`: Sendable { ... }  // ❌ Describes implementation, not behavior
```

**Rationale**: The summary line is the first thing readers see in quick help and symbol lists. It must orient, not explain internals.

---

### [DOC-002] Type Documentation Structure

**Statement**: Type declarations (struct, enum, class, actor) MUST follow this documentation structure:

1. One-line summary
2. Blank line
3. Specification section heading (when modeling an external spec)
4. Specification text in blockquote (`>`) when modeling external specs
5. `## Voorbeeld` / `## Example` with working Swift code (when implemented)

**Correct** (specification-mirroring type):
```swift
/// Toestemming bij leven
///
/// ## Wetsartikel
///
/// > **Toestemming bij leven**
/// >
/// > [1.](<doc:Artikel 14/Lid 1>) Het bij leven [afnemen](<doc:Artikel 1/Afnemen>)
/// > van [lichaamsmateriaal](<doc:Artikel 1/Lichaamsmateriaal>) en het
/// > [bewaren](<doc:Artikel 1/Bewaren>) of gebruiken daarvan vindt niet plaats dan
/// > nadat de [beslissingsbevoegde](<doc:Artikel 1/Beslissingsbevoegde>) voor deze
/// > [handelingen](<doc:Artikel 1/Handelingen met lichaamsmateriaal>)
/// > [toestemming](<doc:Artikel 1/Toestemming>) heeft gegeven.
///
/// ## Voorbeeld
///
/// ```swift
/// let artikel14 = try `Artikel 14`(
///     `Artikel 14`.Arguments(
///         lid1: .init(
///             `beslissingsbevoegde heeft toestemming gegeven voor afnemen`: true
///         ),
///         ...
///     )
/// )
/// ```
public struct `Artikel 14`: Sendable { ... }
```

**Correct** (infrastructure type):
```swift
/// A bump allocator for batch allocations.
///
/// Arena allocation provides:
/// - O(1) allocation (bump pointer)
/// - No individual deallocation overhead
/// - Single bulk deallocation via `reset()`
///
/// ## Invariants
///
/// - Capacity is always > 0 (enforced at construction)
/// - `_storage` is always non-null
public struct Arena: ~Copyable { ... }
```

**Rationale**: Consistent structure enables predictable navigation. The specification heading signals "this is normative text from an external source."

**Cross-references**: [DOC-005], [DOC-033]

---

### [DOC-003] Method Documentation

**Statement**: Public methods MUST document: parameters (`- Parameter name:`), return value (`- Returns:`), thrown errors (`- Throws:`). Methods with concurrency concerns MUST also document executor/threading guarantees and cancellation behavior.

**Correct**:
```swift
/// Submits work to the executor pool.
///
/// - Parameter work: The work item to execute.
/// - Returns: The result of the work execution.
/// - Throws: `IO.Lifecycle.Error` if the pool is shutting down or the task is cancelled.
///
/// This method is safe to call from any thread. Work executes on the pool's
/// dedicated threads, not the Swift cooperative thread pool.
public func submit<T>(_ work: @Sendable () throws -> T) async throws(IO.Lifecycle.Error<IO.Error>) -> T
```

**Incorrect**:
```swift
/// Submits work.
public func submit<T>(_ work: @Sendable () throws -> T) async throws(IO.Lifecycle.Error<IO.Error>) -> T
// ❌ Missing parameter, return, throws, threading docs
```

**Rationale**: Complete method documentation enables correct use without reading implementation code.

**Cross-references**: [API-ERR-001]

---

### [DOC-004] Property Documentation

**Statement**: Properties MUST NOT be documented when self-evident. Properties MUST be documented when: (a) computed with side effects, (b) has non-obvious invariants, (c) deviates from an established pattern in the codebase.

**Correct**:
```swift
/// Whether the actions with body material are permitted.
public let `de handelingen met lichaamsmateriaal zijn toegestaan`: Bool
```

```swift
var count: Int  // ✓ Self-evident, no documentation needed
```

**Incorrect**:
```swift
/// The count.
var count: Int  // ❌ Documentation adds no information
```

**Rationale**: Redundant documentation creates noise that dilutes meaningful content.

---

### [DOC-005] Specification-Mirroring Documentation

**Statement**: When a type models an external specification (statute, RFC, ISO), the inline documentation MUST contain:

1. Summary line = specification section title
2. Specification section heading (domain-appropriate, see [DOC-041])
3. Specification text in blockquote (`>` prefix) — verbatim or summarized
4. Cross-references to related specification sections via DocC links

**Correct**:
```swift
/// Committees of board of directors; Designation.
///
/// # Statute
///
/// > [1.](<doc:NRS 78/125/1>) Unless otherwise provided in articles, board
/// > may designate one or more committees with powers of the board in
/// > management of business and affairs.
/// >
/// > [2.](<doc:NRS 78/125/2>) Each committee must include at least one
/// > director.
public struct `125` { ... }
```

**Incorrect**:
```swift
/// Deals with board committees.
public struct `125` { ... }  // ❌ No spec text, no section heading, vague summary
```

**Rationale**: Specification-mirroring types exist to model a specification. The documentation must carry that specification text so developers don't need to consult external sources.

**Cross-references**: [API-NAME-003], [DOC-033]

---

### [DOC-006] Subsection Enumeration

**Statement**: When a specification section has numbered subsections, each MUST be listed with a DocC link and one-line summary:

**Correct**:
```swift
/// > [1.](<doc:Artikel 14/Lid 1>) Het bij leven afnemen van lichaamsmateriaal
/// > en het bewaren of gebruiken daarvan vindt niet plaats dan nadat de
/// > beslissingsbevoegde toestemming heeft gegeven.
/// >
/// > [2.](<doc:Artikel 14/Lid 2>) De beheerder draagt zorg voor het vragen
/// > van de in het eerste lid bedoelde toestemming.
/// >
/// > [3.](<doc:Artikel 14/Lid 3>) Een eenmaal verleende toestemming kan te
/// > allen tijde worden ingetrokken.
```

**Rationale**: Subsection links create a navigable table of contents within the parent type's documentation, enabling direct navigation to specific clauses.

**Cross-references**: [DOC-024]

---

### [DOC-007] Abbreviated Subsection Syntax

**Statement**: When subsections are too dense to reproduce verbatim, they MAY be abbreviated using bracketed descriptions:

**Correct**:
```swift
/// > 3.-6. [Provisions for remote participation via electronic communications,
/// > videoconferencing, or teleconferencing with identity verification and
/// > reasonable participation opportunities]
```

**Rationale**: Brackets signal summarization versus verbatim text, preserving the reader's ability to distinguish between exact specification language and editorial summaries.

---

### [DOC-008] Cross-Reference Formats

**Statement**: Two cross-reference formats are recognized:

| Format | Use Case | Example |
|--------|----------|---------|
| DocC link | Explicit authored links, cross-article, defined terms | `[artikel 8](<doc:Artikel 8>)` |
| Backtick auto-link | Casual sibling references | `` ``195`` `` |

DocC links MUST be used when linking to a different specification section or a defined term. Backtick auto-links MAY be used for sibling references within the same parent scope.

**Correct**:
```swift
/// > De [beheerder](<doc:Artikel 1/Beheerder>) draagt zorg voor het vragen van
/// > [toestemming](<doc:Artikel 1/Toestemming>), met dien verstande dat degene die
/// > de toestemming feitelijk vraagt, zich er voor het vragen van de toestemming van
/// > vergewist dat de beslissingsbevoegde bekend is met de informatie, bedoeld in
/// > [artikel 8](<doc:Artikel 8>).
```

```swift
/// unless the articles authorize the board of directors to fix and
/// determine these matters as provided in ``195`` and ``196``.
```

**Rationale**: Consistent link formatting enables navigation. DocC links for cross-article references create clickable paths; backtick links for siblings keep local references lightweight.

---

### [DOC-009] Definition Index Pattern

**Statement**: When a section defines multiple terms (e.g., a definitions article), the documentation SHOULD list each definition with an italic title and DocC link:

**Correct**:
```swift
/// > _[afnemen](<doc:Artikel 1/Afnemen>)_: handeling waardoor stoffen,
/// > bestanddelen of delen van de donor worden afgescheiden...
/// >
/// > _[beheerder](<doc:Artikel 1/Beheerder>)_: de rechtspersoon die
/// > lichaamsmateriaal bewaart of verstrekt...
```

```swift
/// NRS 78.3782: _[Acquiring person](<doc:NRS 78/3782>)_
/// NRS 78.3783: _[Acquisition](<doc:NRS 78/3783>)_
```

**Rationale**: Definition indices create a navigable glossary. The italic-plus-link pattern is visually consistent and DocC-renderable.

---

### [DOC-010] Explanatory Material Exclusion

**Statement**: Explanatory material (legislative rationale, design commentary, Memorie van Toelichting, explanatory memoranda) MUST NOT appear in inline `///` comments. References to Research/ documents and Experiments/ packages MUST NOT appear in inline `///` comments. Inline docs contain specification text, code examples, and cross-references only. Explanatory material and research/experiment references belong exclusively in `.docc` articles.

**Rationale**: Inline docs are the self-sufficient developer reference read alongside source code. Explanatory material and research/experiment links would bloat source files and mix normative specification text with non-normative commentary. The .docc catalogue is the appropriate layer for this depth.

**Cross-references**: [DOC-027], [DOC-028], [DOC-029]

---

## .docc Catalogue

### [DOC-020] Catalogue Location

**Statement**: Every module MUST have a `.docc` catalogue directory inside its `Sources/` directory, named to match the module:

```
Sources/{Module Name}/{Module Name}.docc/
```

**Rationale**: DocC discovers catalogue content by matching directory names to module names. Mismatched names prevent catalogue association.

---

### [DOC-021] Root Page

**Statement**: The catalogue MUST contain a root page matching the module name. Structure:

```markdown
# ``{Module_Identifier}``

@Metadata {
    @DisplayName("{Human-Readable Name}")
    @TitleHeading("{Domain Heading}")
}

> Important: {Legal disclaimers or version notes if applicable.}

{Preamble text if applicable (e.g., legislative enacting clause).}

## Topics

### {Domain Section Name}

- ``{Symbol}``
```

`@DisplayName` provides human-readable title. `@TitleHeading` provides domain context (e.g., "Nevada Revised Statutes", "Wet zeggenschap lichaamsmateriaal", "Swift Institute").

**Correct**:
```markdown
# ``Wet_Zeggenschap_Lichaamsmateriaal``

@Metadata {
    @DisplayName("Wet zeggenschap lichaamsmateriaal")
    @TitleHeading("Regels voor handelingen met lichaamsmateriaal...")
}

> Important: Geconsolideerde tekst...

## Topics

### Hoofdstuk 1: Begripsbepalingen

- ``Artikel 1``
```

**Rationale**: The root page is the entry point for the entire module's documentation. Consistent structure enables predictable navigation.

**Cross-references**: [DOC-025]

---

### [DOC-022] Article Pages — Navigation Level

**Statement**: Article pages at minimum MUST contain @Metadata:

```markdown
# ``{Module_Identifier}/{Symbol Path}``

@Metadata {
    @DisplayName("{Human-Readable Title}")
    @TitleHeading("{Domain Heading}")
}
```

This is sufficient for early development, shell types, or types whose inline documentation is self-contained.

**Rationale**: Even minimal article pages provide human-readable titles and domain context in rendered documentation.

---

### [DOC-023] Article Pages — Substantive Level

**Statement**: Article pages MAY expand with substantive content sections. Recognized sections, in order:

| Section | Purpose | Content Source |
|---------|---------|---------------|
| `## Wetsartikel` / `## Specification` | Blockquoted spec text with cross-links | Mirrors inline docs |
| `## Voorbeeld` / `## Example` | Working Swift code example | Mirrors inline docs |
| `## Memorie van Toelichting` / `## Rationale` | Explanatory material | Exclusive to .docc |
| `## Research` | Links to relevant research documents | Exclusive to .docc |
| `## Experiments` | Links to relevant experiment packages | Exclusive to .docc |
| `## Topics → ### Conclusies` | Derived conclusions as navigable symbols | Exclusive to .docc |

When specification text appears in a .docc article, it MUST match the inline `///` version semantically. The .docc article is the superset — it mirrors inline content and adds explanatory depth.

**Correct**:
```markdown
# ``Wet_Zeggenschap_Lichaamsmateriaal/Artikel 14``

@Metadata {
    @DisplayName("Artikel 14 Toestemming bij leven")
}

Wet zeggenschap lichaamsmateriaal

## Wetsartikel

> **Toestemming bij leven**
>
> [1.](<doc:Lid 1>) Het bij leven [afnemen](<doc:Artikel 1/Afnemen>)...

## Voorbeeld

` ` `swift
let artikel14 = try `Artikel 14`(...)
` ` `

## Memorie van Toelichting

Ingevolge artikel 14, eerste lid, mag lichaamsmateriaal bij een levende
donor worden afgenomen indien de beslissingsbevoegde toestemming heeft
gegeven...
```

**Correct** (article with research and experiment references):
```markdown
# ``Buffer_Ring_Inline_Primitives/Buffer.Ring.Inline``

@Metadata {
    @DisplayName("Buffer.Ring.Inline")
    @TitleHeading("Swift Primitives")
}

## Rationale

The inline ring buffer trades dynamic resizing for compile-time capacity,
enabling stack allocation and ~Copyable storage...

## Research

- [Ring Buffer Storage Variants](../../Research/ring-buffer-storage-variants.md) — Compares inline, heap, and hybrid storage strategies. Status: DECISION.
- [Bounded Index Precondition Elimination](../../Research/bounded-index-precondition-elimination.md) — Demonstrates that bounded indices eliminate runtime checks. Status: DECISION.

## Experiments

- [inline-ring-capacity-overflow](../../Experiments/inline-ring-capacity-overflow/) — Verifies compile-time capacity enforcement. Status: CONFIRMED.
```

**Rationale**: The substantive level transforms .docc from navigation scaffolding into a complete documentation layer. Explanatory material, research rationale, and experiment verification that don't belong in source code find their home here.

**Cross-references**: [DOC-010], [DOC-027], [DOC-028], [DOC-029]

---

### [DOC-024] Subsection Pages

**Statement**: When a type has documented subsections (statute lids, RFC sub-clauses), each SHOULD have its own article page:

```markdown
# ``{Module_Identifier}/{Parent}/{Subsection}``

@Metadata {
    @DisplayName("{Parent}.{Subsection} {Title}")
    @TitleHeading("{Domain Heading}")
}
```

**Correct**:
```markdown
# ``NRS_78_Private_Corporations/NRS 78/310/1``

@Metadata {
    @DisplayName("NRS 78.310(1) Location of meetings")
    @TitleHeading("Nevada Revised Statutes")
}
```

**Rationale**: Per-subsection pages enable deep linking into specific clauses, which is essential for cross-reference navigation.

---

### [DOC-025] Topics Organization

**Statement**: The root page's `## Topics` section MUST group symbols by logical domain sections, not alphabetically. Section headings MUST match the domain's own organizational structure.

**Correct** (statute chapters):
```markdown
## Topics

### Hoofdstuk 1: Begripsbepalingen

- ``Artikel 1``

### Hoofdstuk 2: Algemene bepalingen

- ``Artikel 2``
- ``Artikel 3``
```

**Incorrect**:
```markdown
## Topics

### A

- ``Artikel 1``
- ``Artikel 2``
- ``Artikel 3``
```

**Rationale**: Domain-native organization preserves the specification's own structure, making navigation intuitive for domain experts.

---

### [DOC-026] Companion Document Subdirectories

**Statement**: Large companion documents (explanatory memoranda, detailed rationale, legislative history) SHOULD be organized in subdirectories within `.docc/`:

```
Sources/{Module Name}/{Module Name}.docc/
├── {Module Name}.md                    ← Root page
├── {Article}.md                        ← Per-symbol articles
└── {Companion Document Name}/          ← Companion docs
    ├── {Companion Document Name}.md    ← Index with chapter links
    └── {Chapter}.md                    ← Individual chapters
```

The root page MUST link to companion documents in its `## Topics` section.

**Correct**:
```
Wet Zeggenschap Lichaamsmateriaal.docc/
├── Wet Zeggenschap Lichaamsmateriaal.md
├── Artikel 1.md ... Artikel 35.md
└── Memorie van Toelichting/
    ├── Memorie van Toelichting.md
    └── MvT Hoofdstuk 1 ... 14.md
```

**Rationale**: Subdirectories prevent .docc root from becoming cluttered while enabling arbitrarily deep companion material. The index file provides navigable chapter structure.

---

### [DOC-027] Content Layering Principle

**Statement**: Inline `///` documentation is the **self-sufficient developer reference** — reading source alone MUST suffice to understand a type. The `.docc` catalogue is the **expanded reference** — it mirrors core content for navigation AND adds explanatory depth exclusive to .docc.

| Layer | Audience | Contains |
|-------|----------|----------|
| Inline `///` | Developer reading source | Spec text, examples, cross-refs |
| `.docc` article | Reader navigating docs | Same + explanatory material |
| `.docc` companion | Deep reader | Full companion documents |

Specification text appearing in both layers is intentional mirroring, not prohibited duplication.

| Content Type | Inline `///` | .docc Article |
|-------------|:---:|:---:|
| Specification text (blockquoted) | MUST | MAY mirror |
| Code examples | SHOULD | MAY mirror |
| Cross-references | MUST | MAY mirror |
| Explanatory material | MUST NOT | MUST (when available) |
| Companion documents | MUST NOT | MUST (as subdirectories) |
| Research references | MUST NOT | SHOULD (when relevant) |
| Experiment references | MUST NOT | SHOULD (when relevant) |
| @Metadata, @DisplayName | — | MUST |
| Topics organization | — | MUST |

**Rationale**: Documentation is a synthesis of everything that came before — research, experiments, implementation, and tests. Two audiences need this synthesis at different depths. The developer reading source gets the behavioral contract without leaving their editor. The reader navigating rendered DocC gets the same contract plus the research that informed it, the experiments that verified it, and the explanatory material that contextualizes it. Neither layer requires the other.

**Cross-references**: [DOC-010], [DOC-023]

---

### [DOC-028] Research References in .docc Articles

**Statement**: When relevant research documents exist in the package's `Research/` directory, .docc articles SHOULD include a `## Research` section with relative markdown links to those documents. Research/ stays at the package root — .docc articles reference it, not the other way around.

Each link MUST include the document title and its status (from the research document's metadata).

**Correct**:
```markdown
## Research

- [Heap Storage Variants](../../Research/heap-storage-variants.md) — Compares inline, heap, and hybrid storage. Status: DECISION.
- [Bounded Index Precondition Elimination](../../Research/bounded-index-precondition-elimination.md) — Demonstrates bounded indices eliminate runtime checks. Status: DECISION.
```

**Incorrect**:
```swift
/// See Research/heap-storage-variants.md for rationale.
public struct Arena { ... }  // ❌ Research reference in inline docs
```

The `## Research` section SHOULD appear after explanatory material sections and before `## Topics`.

**Rationale**: Research documents explain WHY design decisions were made. Linking them from .docc articles creates a navigable path from "what does this type do" to "why was it designed this way" — without polluting inline source documentation. Research/ stays at the package root per [RES-002]; .docc articles simply point to it.

**Cross-references**: [DOC-010], [DOC-023], [RES-002], [RES-006]

---

### [DOC-029] Experiment References in .docc Articles

**Statement**: When relevant experiments exist in the package's `Experiments/` directory, .docc articles SHOULD include a `## Experiments` section with relative markdown links to those experiment directories. Experiments/ stays at the package root — .docc articles reference it, not the other way around.

Each link MUST include the experiment name and its status (CONFIRMED/REFUTED/SUPERSEDED from the experiment header).

**Correct**:
```markdown
## Experiments

- [inline-ring-capacity-overflow](../../Experiments/inline-ring-capacity-overflow/) — Verifies compile-time capacity enforcement. Status: CONFIRMED.
- [noncopyable-inline-deinit](../../Experiments/noncopyable-inline-deinit/) — Verifies deinit behavior for ~Copyable inline storage. Status: CONFIRMED.
```

**Incorrect**:
```swift
/// Verified in Experiments/inline-ring-capacity-overflow/
public struct Ring { ... }  // ❌ Experiment reference in inline docs
```

The `## Experiments` section SHOULD appear after `## Research` and before `## Topics`.

**Rationale**: Experiments provide empirical verification of design decisions. Linking them from .docc articles closes the loop: specification text (what) → research (why) → experiments (proof). Experiments/ stays at the package root per [EXP-002]; .docc articles simply point to it.

**Cross-references**: [DOC-010], [DOC-023], [EXP-002], [EXP-003]

---

## External Specification References

### [DOC-030] External Links

**Statement**: The root page MUST include a link to the authoritative external specification when the module models one:

**Correct**:
```markdown
- [NRS Chapter 78 — Private Corporations](https://www.leg.state.nv.us/nrs/NRS-078.html)
```

```markdown
Officiële publicatie: [Kamerstuk 35844, nr. 3](https://zoek.officielebekendmakingen.nl/kst-35844-3.html)
```

**Rationale**: The external link enables verification of the Swift model against the authoritative source.

---

### [DOC-031] Cross-Module References

**Statement**: When inline documentation references specifications outside the current module (e.g., a different statute, a different RFC), the reference MUST use the full specification identifier:

**Correct**:
```swift
/// as required by NRS 77.310
```

```swift
/// als bedoeld in artikel 7:446, tweede lid, onderdeel a, van het Burgerlijk Wetboek
```

DocC links SHOULD be used when the referenced specification has a corresponding Swift module.

**Rationale**: Full identifiers are unambiguous. Bare numbers like "77.310" are meaningless without the specification context.

---

### [DOC-032] Range Reference Pattern

**Statement**: When a specification references a range of sections, the documentation MUST link both endpoints and preserve the specification's range language:

**Correct**:
```swift
/// [NRS 78.191](<doc:NRS 78/191>) to [NRS 78.307](<doc:NRS 78/307>), inclusive
```

**Rationale**: Range references are a standard legal citation pattern. Linking both endpoints enables navigation to either bound.

---

### [DOC-033] Blockquote Convention

**Statement**: Verbatim specification text MUST use the `>` blockquote prefix in both inline docs and .docc articles. This delineates normative specification text from original commentary.

**Correct**:
```swift
/// > **Toestemming bij leven**
/// >
/// > [1.](<doc:Artikel 14/Lid 1>) Het bij leven afnemen van
/// > lichaamsmateriaal en het bewaren of gebruiken daarvan...
```

**Incorrect**:
```swift
/// Het bij leven afnemen van lichaamsmateriaal en het bewaren
/// of gebruiken daarvan...
// ❌ No blockquote — reader cannot distinguish spec text from commentary
```

**Rationale**: The blockquote visually and semantically marks text as quoted from an external authority, preventing confusion between the specification's words and the author's commentary.

**Cross-references**: [DOC-005]

---

## Documentation Quality

### [DOC-040] Documentation Tiers

**Statement**: Documentation MUST be classified into tiers based on implementation maturity. Types SHOULD progress through tiers as they gain implementation.

| Tier | .docc Article | Inline Docs | When |
|------|--------------|-------------|------|
| 1 — Full | Spec text + examples + explanatory material + research/experiment refs + companion docs | Spec text + examples + cross-refs | Implemented type with companion material |
| 2 — Standard | Spec text + examples + research/experiment refs | Spec text + examples + cross-refs | Implemented type |
| 3 — Enumerated | @Metadata + Topics | Subsection enumeration with links | Multi-subsection type, not yet implemented |
| 4 — Minimal | @Metadata only | Summary line + abbreviated spec text | Partially documented |
| 5 — Shell | @Metadata only | None or summary only | Namespace container / placeholder |

**Rationale**: The tier system enables incremental documentation without blocking forward progress. Shell types don't need full documentation, but implemented types with available companion material should reach tier 1.

---

### [DOC-041] Section Heading Conventions

**Statement**: Specification section headings SHOULD mirror the specification's own terminology:

| Domain | Spec Heading | Explanatory Heading |
|--------|-------------|---------------------|
| Dutch legislation | `## Wetsartikel` | `## Memorie van Toelichting` |
| US state statutes | `# Statute` | `## Legislative Notes` |
| RFCs | `## RFC {N} Section {M}` | `## Design Notes` |
| ISO standards | `## ISO {N} Section {M}` | `## Rationale` |
| General | `## Specification` | `## Rationale` |

**Rationale**: Domain-native headings help domain experts orient immediately. A lawyer reads "Wetsartikel" and knows what follows; an engineer reads "RFC 4122 Section 4.1" and knows what follows.

---

### [DOC-042] Documentation Currency

**Statement**: When specification text changes, both inline docs and .docc articles MUST be updated. The .docc `@DisplayName` MUST reflect the current specification title.

**Rationale**: Stale documentation that contradicts the current specification is worse than no documentation.

---

## Code Comments and Content Quality

### [DOC-043] Comment Purpose

**Statement**: Comments in source code MUST explain *why*, not *what*.

**Correct**:
```swift
// Use non-blocking to avoid thread pool exhaustion
let selector = IO.NonBlocking.Selector()
```

**Incorrect**:
```swift
// Create a selector
let selector = IO.NonBlocking.Selector()  // ❌ Describes what, not why
```

**Rationale**: Purpose-driven comments add information the code cannot convey.

---

### [DOC-044] Anticipatory Documentation

**Statement**: When code makes a decision that future readers might question, comments MUST anticipate those questions and provide answers. The comment should transform "this looks wrong" into "this is correct for documented reasons."

| Question Type | What to Document |
|---------------|------------------|
| "Can this be done differently?" | Why alternatives don't work |
| "When will this change?" | Migration conditions |
| "Is this a bug or intentional?" | Explicit statement of intent |
| "Why isn't X used here?" | Constraints that prevent X |

**Correct**:
```swift
/// Note: Span<T> is ~Escapable, which requires special handling.
/// For now, we provide conformances only for Escapable collection types.
/// Span-based parsing will be added when lifetime annotations are stable.
associatedtype Input
```

Anticipatory documentation is REQUIRED when:

1. Language limitations prevent obvious patterns — document the limitation and workaround
2. Design defers to future language evolution — specify the trigger for change
3. Code differs from similar code elsewhere — explain why the difference is intentional
4. A pattern looks wrong but is correct — explicitly state it's intentional

**Rationale**: Most developers don't read documentation until their intuitive approach fails. Documentation that addresses failure modes meets developers where they are.

---

### [DOC-045] Workaround Documentation Template

**Statement**: Workarounds MUST be documented using a standard four-part template.

```swift
// WORKAROUND: [What this works around]
// WHY: [Why the normal approach does not work]
// WHEN TO REMOVE: [Specific condition under which the workaround can be removed]
// TRACKING: [Issue URL or internal reference]
```

**Example**:
```swift
// WORKAROUND: This Sequence conformance only compiles because all source code
// is consolidated into a single file.
// WHY: Compiler bug prevents multi-file compilation of this conformance.
// WHEN TO REMOVE: When the compiler bug is fixed.
// TRACKING: https://github.com/swiftlang/swift/issues/86669
```

| Field | Purpose |
|-------|---------|
| `WORKAROUND` | Identifies the comment as a managed workaround, not a design choice |
| `WHY` | Prevents future readers from "fixing" load-bearing structure |
| `WHEN TO REMOVE` | Provides exit criteria so the workaround does not outlive its cause |
| `TRACKING` | Links to an external issue for status checking |

A workaround missing any of these fields is incomplete.

**Rationale**: Workarounds following a standard template are managed constraints with clear lifecycles. Workarounds without documentation become permanent because no one knows whether they are still necessary.

---

### [DOC-046] Deviation Documentation Template

**Statement**: When a type deviates from an established pattern in the same codebase, a standard documentation template MUST be used. The template acknowledges the pattern, explains the difference, and states the consequence.

```swift
/// ## [Property Name]
///
/// Unlike [Reference Type] which [does X] because [reason],
/// [This Type] [does Y] because [different reason].
/// Therefore it [has consequence].
```

**Example**:
```swift
/// ## Copyable
///
/// Unlike `Stack.Small<Element>` which is `~Copyable` because it stores
/// potentially move-only elements, `Set<Bit>.Packed.Small` stores only `UInt`
/// words (always trivial) and has no generic element type. Therefore it is
/// unconditionally `Copyable`, enabling `Sequence`, `Equatable`, and `Hashable`.
```

| Component | Purpose |
|-----------|---------|
| Acknowledge the pattern | Signals awareness of the expected behavior |
| Explain the difference | Provides the concrete reason for deviation |
| State the consequence | Shows the practical effect of the deviation |

**Rationale**: Intentional deviations that are undocumented look identical to accidental deviations. The template short-circuits unnecessary investigation by making intent explicit.

---

### [DOC-047] Learning Path Preservation

**Statement**: Documentation for unfamiliar territory SHOULD preserve learning paths, not just conclusions. A document that says "use pattern X" is less useful than one that explains why obvious alternatives Y and Z fail.

**Correct**:
```markdown
## Unsafe Expression Marking

### The Parenthesization Pattern

For assignments to unsafe storage, parentheses define the expression boundary:

` ` `swift
unsafe (self.raw = value)  // Entire assignment as one expression
` ` `

### Why Other Patterns Fail

| Failed Pattern | Why It Fails |
|----------------|--------------|
| `self.raw = unsafe value` | Only marks the value, not the destination |
| `unsafe { self.raw = value }` | Block creates closure context; can't assign to `let` |
```

**Incorrect**:
```markdown
## Unsafe Expression Marking

Use `unsafe (self.raw = value)` for pointer assignments.

❌ Missing: why the parentheses matter, what alternatives fail, why they fail
```

Apply when: (1) documenting new language features, (2) explaining patterns that contradict intuition, (3) writing migration/remediation guides, (4) capturing knowledge from exploration sessions.

**Rationale**: Developers encountering new features try the obvious patterns first. Documentation that addresses those failures provides faster onboarding.

---

### [DOC-048] Compromise Documentation

**Statement**: Documentation of compromises is more valuable than documentation of ideal code. When workarounds exist, documentation MUST include: (1) why the workaround exists, (2) what the ideal solution would be, (3) when the workaround can be removed.

**Correct**:
```markdown
## Resource Pool Effects

### Current Implementation

Uses `Reference.Box<Resource>` because Swift's associated types
implicitly require `Copyable`.

### Migration Path

When Swift Evolution accepts "Suppressed Associated Types,"
remove the `Box` wrapper and change `Value = Reference.Box<Resource>`
to `Value = Resource`.
```

**Rationale**: Workarounds documented with migration paths are technical debt with known payoff dates. Workarounds without documentation become permanent.

---

### [DOC-049] Escape Hatch Counter-Marketing

**Statement**: Documentation for escape hatches (unsafe wrappers, unchecked markers, compiler bypasses) SHOULD actively discourage use when alternatives exist.

**Correct**:
```markdown
## Sendability.Unchecked

This type bypasses the compiler's `Sendable` checking.
This wrapper provides **no runtime validation** and **no guarantees**.
It is an auditable assertion site, not a safety mechanism.

**Prefer alternatives when possible**: For domain types you control,
mark the containing type `@unchecked Sendable` directly.
```

| Claimed | Actual |
|---------|--------|
| Safety | None — bypasses compiler checking |
| Protection | None — no runtime validation |
| **Auditability** | **Yes** — grep finds every escape site |

**Rationale**: Most documentation sells its subject. Escape hatch documentation must do the opposite — discourage use and honestly state limitations.

---

### [DOC-050] Code Example Quality

**Statement**: All code examples in documentation (inline `///` and `.docc` articles) MUST:

1. Include all required `import` statements
2. Use domain-meaningful identifiers (NOT `Foo`, `Bar`, `x`, `y`)
3. Specify code block language

Non-trivial examples SHOULD demonstrate error handling explicitly.

**Correct**:
```swift
import IO

let connection = try Network.Connection(host: "api.example.com", port: 443)
```

**Incorrect**:
```swift
let foo = try Bar(x: "...", y: 123)  // ❌ Meaningless identifiers, missing import
```

**Rationale**: Complete, realistic examples demonstrate actual usage patterns and enable copy-paste verification.

**Cross-references**: [README-022]

---

## Documentation Maintenance

### [DOC-051] Automated Verification of Derived Information

**Statement**: For any property that can be computed from source (tier assignments, dependency counts, package inventories), documentation SHOULD be generated or verified automatically.

| Property | Source of Truth | Verification Method |
|----------|----------------|---------------------|
| Tier assignments | Package.swift dependency graphs | Compute `tier[pkg] = max(tier[dep] for dep in deps) + 1` |
| Dependency counts | Package.swift files | Parse and count |
| Package inventories | Directory listings | Enumerate targets |
| Module names | Package.swift product declarations | Parse and extract |

Normative documents containing derived information SHOULD include a CI verification step.

**Rationale**: Incremental changes to source produce systemic documentation drift when no global verification exists.

---

### [DOC-052] Semantic Labels vs Computed Values

**Statement**: Computed values (tier numbers, dependency counts) MUST be treated as facts. Human-assigned labels (tier names, category descriptions) MUST be treated as commentary that requires periodic re-evaluation.

**Correct**: "As of this version, tier 7 contains linear algebra and input handling packages."

**Incorrect**: "Tier 7 is for advanced numerical packages." (implies a prescriptive constraint)

**Rationale**: Treating descriptive labels as prescriptive rules creates false constraints when computed values shift.

---

### [DOC-053] Document Versioning

**Statement**: Normative documents that undergo structural revision (not just clarification) warrant major version bumps.

| Change Type | Version Increment | Example |
|-------------|-------------------|---------|
| Typo or wording fix | Patch (x.y.Z) | Fix a misspelling |
| New section or clarification | Minor (x.Y.0) | Add a new subsection |
| Structural model change | Major (X.0.0) | Nine tiers become sixteen |

A major version signals: "Re-read this document. The model changed and cross-references may be stale."

**Rationale**: Without versioned documents, structural changes propagate silently.

---

## Cross-References

- **code-surface** skill for [API-NAME-003] specification-mirroring names, [API-IMPL-005] one type per file, [API-ERR-001] typed throws
- **research-process** skill [RES-002] for research document location and structure
- **experiment-process** skill [EXP-002] for experiment package location and structure
- **readme** skill [README-*] for README conventions (separate skill)
- Research: `swift-institute/Research/documentation-skill-design.md`
- Research: `swift-institute/Research/documentation-research-experiments-integration.md`
