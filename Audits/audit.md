# Audit: Swift Primitives Ecosystem

## Conversions — 2026-03-24

### Scope

- **Target**: swift-primitives, swift-standards, swift-foundations (ecosystem-wide)
- **Skill**: conversions — [CONV-001], [CONV-016], [IDX-007]
- **Files**: All `Sources/` across three superrepos
- **Subject**: Bare `Cardinal`/`Ordinal` used where phantom-tagged `Index<T>.Count`/`Index<T>` is semantically correct

### Pattern

A property uses a bare type (`Cardinal`, `Ordinal`) when the value is semantically scoped to a specific domain. This forces every consumer to construct a phantom-typed wrapper from scratch rather than transforming an already-typed value.

```swift
// Anti-pattern: bare Cardinal at the source
public let count: Cardinal

// Consumer must construct from scratch — domain information is lost
var count: Index<Element>.Count {
    Index<Element>.Count(_storage.count)    // wrapping bare value
}
```

The fix: type the property with the narrowest correct phantom-tagged type. Consumers then use `.retag` to change domain, keeping the full chain typed.

```swift
// Fixed: typed at the source
public let count: Index<UInt8>.Count

// Consumer retags — zero-cost, typed transformation
var count: Index<Element>.Count {
    _storage.count.retag(Element.self)      // tag-to-tag, no bare value
}
```

**Why this matters**:

1. **Domain safety** — bare `Cardinal` mixes freely with any other `Cardinal`; `Tagged<UInt8, Cardinal>` is domain-locked (`where O.Domain == C.Domain` on arithmetic).
2. **Typed chain preservation** — `.retag` is a typed transformation; construction from bare is trust-me untyped.
3. **Zero-cost** — `Tagged<Tag, Cardinal>` has identical layout to `Cardinal`. Retagging is a no-op at runtime.
4. **Boundary clarity** — bare types belong only at true system boundaries (`Int(bitPattern: count.cardinal)` at stdlib/C interface).

**When bare types are correct**:

- **Abstraction-over-self** — `Cardinal.Protocol.cardinal` and `Ordinal.Protocol.ordinal` abstract over the bare type itself. Tagged would be circular.
- **Domain-defining values** — `Algebra.Modular.Modulus.cardinal` and `Cyclic.Group.Modulus.value` represent group orders as pure mathematical quantities. The modulus *defines* the domain, not a value *within* a domain.
- **Stdlib intake boundaries** — `Cardinal(UInt(span.count))` wrapping a stdlib `Int` into bare `Cardinal` at intake is correct. The anti-pattern is *storing* and *propagating* bare after intake.

**Diagnostic**:

```bash
# Bare Cardinal/Ordinal stored properties
grep -rn 'let \w\+: Cardinal\b\|var \w\+: Cardinal\b' Sources/
grep -rn 'let \w\+: Ordinal\b\|var \w\+: Ordinal\b' Sources/

# Construction-from-bare symptom (consumer side)
grep -rn 'Index<.*>.Count(.*\.count)\|Index<.*>.Offset(.*\.offset)' Sources/

# Double .rawValue code smell
grep -rn '\.rawValue\.rawValue' Sources/ Tests/
```

**Mechanical fix** (per instance):

1. Change the stored property / protocol requirement type
2. Update initializers (push typed boundary outward to callers)
3. Update stdlib boundary conversions: `Int(bitPattern: count)` → `Int(bitPattern: count.cardinal)`
4. Update consumers: construction from bare → `.retag(Element.self)`

### Findings — Protocol Requirements

5 protocols in swift-primitives declare bare `Cardinal`/`Ordinal` in requirements.

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | HIGH | [CONV-016] | `Finite.Capacity.swift:12` | `static var capacity: Cardinal` → `Index<Self>.Count`. 2 conformers (`Finite.Bound<let N>`, `Algebra.Residue<let n>`). | OPEN |
| 2 | HIGH | [CONV-016] | `Finite.Enumerable.swift:38,41,50` | 3 bare requirements: `count: Cardinal` → `Index<Self>.Count`, `ordinal: Ordinal` → `Index<Self>`, `init(__unchecked:ordinal: Ordinal)` → `Index<Self>`. 16 conformers. Largest blast radius in this audit. | OPEN |
| 3 | MEDIUM | [CONV-016] | `Sequence.Iterator.Protocol.swift:125` | `nextSpan(maximumCount: Cardinal)` — caller-supplied batch limit. Bare `Cardinal` here acts as universal "how many" without requiring callers to tag their batch size. If changed, `next()` default (line 142) and `skip(by:)` (line 160) also need updating. | DEFERRED — domain-free argument; caller rarely has a tagged count in scope |
| 4 | — | — | `Cardinal.Protocol.swift:39,42` | `cardinal: Cardinal` / `init(_ cardinal: Cardinal)` — abstraction-over-self. Bare type is the thing being abstracted. | FALSE_POSITIVE |
| 5 | — | — | `Ordinal.Protocol.swift:51,54` | `ordinal: Ordinal` / `init(_ ordinal: Ordinal)` — abstraction-over-self. Same rationale. | FALSE_POSITIVE |

### Findings — Stored Properties

24 stored properties across swift-primitives use bare `Cardinal` or `Ordinal`. swift-standards and swift-foundations: zero hits.

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 6 | HIGH | [CONV-016] | `Sequence.Difference.Hunk.swift:26-32` | 4 public stored properties: `oldStart: Ordinal`, `oldCount: Cardinal`, `newStart: Ordinal`, `newCount: Cardinal`. All semantically scoped to diff line positions. Needs phantom tag design decision (`Sequence.Difference.Old`/`.New` or a single `Line` tag). | OPEN |
| 7 | MEDIUM | [CONV-016] | `Swift.Span.Iterator.swift:32,35` + `Batch.swift:33,36` | 4 `@usableFromInline` properties: `_position: Ordinal` → `Index<Element>`, `_count: Cardinal` → `Index<Element>.Count`. No public API impact. | OPEN |
| 8 | MEDIUM | [CONV-016] | `Sequence.Drop.First.swift:32` + `Iterator.swift:41` + `Prefix.First.swift:33` + `Iterator.swift:30` | 4 `@usableFromInline` properties: `_count`/`_remaining: Cardinal` → `Index<Base.Element>.Count`. No public API impact. | OPEN |
| 9 | MEDIUM | [CONV-016] | `Steps.Iterator.swift:15,18` + `Changes.Iterator.swift:15,18` | 4 `@usableFromInline` properties: `_index: Ordinal` → `Index<Step/Change>`, `_count: Cardinal` → `Index<Step/Change>.Count`. | OPEN |
| 10 | MEDIUM | [CONV-016] | `Cyclic.Group.Static.swift:80` + `Iterator.swift:28,31` + `Element.swift:43` | 4 properties: `position: Ordinal` (public), `current: Ordinal`, `bound: Cardinal` (internal), `residue: Ordinal` (public). Tagged replacements: `Ordinal.Finite<modulus>` or `Index<Element>`. Needs design decision for cyclic group domain tagging. | OPEN |
| 11 | LOW | [CONV-016] | `Parser.Machine.Memoization.Key.swift:18` | `node: Ordinal` (package let) → `Index<Parser.Machine.Node>`. Textbook case for phantom tagging but low priority (internal to parser machine). | OPEN |
| 12 | MEDIUM | [CONV-016] | `Theme.swift:30` | `ordinal: Ordinal` (public stored) → `Index<Theme>`. Depends on finding #2 (`Finite.Enumerable` protocol fix). Will resolve automatically when the protocol changes. | OPEN |
| 13 | — | [CONV-016] | `Buffer.Aligned.swift` | `count: Cardinal` → `Index<UInt8>.Count`. 4 files changed, zero downstream breakage. Commit `4167371`. | RESOLVED 2026-03-22 |
| 14 | — | — | `Cyclic.Group.Modulus.swift:26`, `Algebra.Modular.Modulus.swift:18` | `value: Cardinal` / `cardinal: Cardinal`. Modulus *defines* the domain — bare type is correct. Containing type provides semantic safety. | FALSE_POSITIVE |

### Remediation Plan

#### Prerequisites

| Prerequisite | Status | Notes |
|---|---|---|
| Cross-type comparison (`Index<T> < Index<T>.Count`) | DONE | Generic operators in `Ordinal+Cardinal.swift` with `where O.Domain == C.Domain`. [IDX-007]. |
| `Tagged: ExpressibleByIntegerLiteral` | DEFERRED | See `swift-identity-primitives/Research/tagged-literal-conformances.md` v3.0 DECISION. Conformers use tier 4 typed initializers: `Index<Self>.Count(2)` instead of bare `2`. Acceptable per [CONV-016]. |

#### Phases

```
Phase 0: Prerequisites ─── DONE (comparison exists, literals deferred)
    │
Phase 1: Finite.Capacity ──── smallest protocol, 2 conformers (finding #1)
    │
Phase 2: Finite.Enumerable ── largest blast radius, 16 conformers (finding #2)
    │
    ├── Phase 3: Sequence iterator internals (findings #7, #8) — independent
    │
    ├── Phase 4: Sequence.Iterator.Protocol (finding #3) — depends on Phase 3
    │
    ├── Phase 5: Sequence.Difference.Hunk (finding #6) — needs design decision
    │
    └── Phase 6: Cyclic + parser (findings #10, #11) — independent
```

Phases 1→2 are sequential. Phases 3–6 are independent and can proceed in any order after Phase 2.

#### Phase 1: `Finite.Capacity` (finding #1)

**Package**: `swift-finite-primitives`
**Change**: `static var capacity: Cardinal` → `static var capacity: Index<Self>.Count`

| Conformer | File | Current | After |
|-----------|------|---------|-------|
| `Finite.Bound<let N: Int>` | `Finite.Capacity.swift:21` | `Cardinal(UInt(N))` | `Index<Self>.Count(Cardinal(UInt(N)))` |
| `Algebra.Residue<let n: Int>` | `Algebra.Residue.swift:11` | `.init(integerLiteral: UInt(n))` | `Index<Self>.Count(Cardinal(UInt(n)))` |

Downstream: `Tagged where Tag: Finite.Capacity` uses `Tag.capacity` to provide `Finite.Enumerable.count`.

#### Phase 2: `Finite.Enumerable` (finding #2)

**Package**: `swift-finite-primitives`
**Depends on**: Phase 1

Protocol change:

```swift
// Before
public protocol Enumerable: CaseIterable, Sendable {
    static var count: Cardinal { get }
    var ordinal: Ordinal { get }
    init(__unchecked: Void, ordinal: Ordinal)
}

// After
public protocol Enumerable: CaseIterable, Sendable {
    static var count: Index<Self>.Count { get }
    var ordinal: Index<Self> { get }
    init(__unchecked: Void, ordinal: Index<Self>)
}
```

**Conformer blast radius: `count`** (16 conformers)

| Conformer | Current | After |
|-----------|---------|-------|
| `Bit` | `Cardinal(2)` | `Index<Self>.Count(2)` |
| `Bit.Order` | `2` | `Index<Self>.Count(2)` |
| `Gradient` | `2` | `Index<Self>.Count(2)` |
| `Endpoint` | `2` | `Index<Self>.Count(2)` |
| `Boundary` | `2` | `Index<Self>.Count(2)` |
| `Bound` | `2` | `Index<Self>.Count(2)` |
| `Parity` | `2` | `Index<Self>.Count(2)` |
| `Comparison` | `3` | `Index<Self>.Count(3)` |
| `Monotonicity` | `3` | `Index<Self>.Count(3)` |
| `Ternary` | `3` | `Index<Self>.Count(3)` |
| `Polarity` | `3` | `Index<Self>.Count(3)` |
| `Sign` | `3` | `Index<Self>.Count(3)` |
| `Rotation.Phase` | `4` | `Index<Self>.Count(4)` |
| `Axis<N>` | `Cardinal.init(integerLiteral: UInt(N))` | `Index<Self>.Count(Cardinal(UInt(N)))` |
| `Theme` | `= 2` (stored let) | `= Index<Theme>.Count(2)` |
| `Tagged (conditional)` | `Tag.capacity` | `Tag.capacity.retag(Self.self)` (tier 1 retag) |

**Conformer blast radius: `ordinal`** (16 conformers)

| Conformer | Current | After |
|-----------|---------|-------|
| 11 enum conformers | switch returning `0`, `1`, `2` | switch returning `Index<Self>(0)`, `Index<Self>(1)`, `Index<Self>(2)` |
| `Bit` | `Ordinal(UInt(rawValue))` | `Index<Self>(Ordinal(UInt(rawValue)))` |
| `Rotation.Phase` | `Ordinal(UInt(rawValue))` | `Index<Self>(Ordinal(UInt(rawValue)))` |
| `Axis<N>` | `.init(UInt8(rawValue))` | `Index<Self>(Ordinal(UInt8(rawValue)))` |
| `Tagged (conditional)` | `rawValue` | `Index<Self>(rawValue)` |
| `Theme` | stored `let ordinal: Ordinal` | stored `let ordinal: Index<Theme>` |

**Conformer blast radius: `init(__unchecked:ordinal:)`** (16 conformers)

| Conformer | Current | After |
|-----------|---------|-------|
| 11 enum conformers | `[.cases][ordinal]` | `[.cases][ordinal.ordinal]` |
| `Bit` | `UInt8(truncatingIfNeeded: ordinal.rawValue)` | `UInt8(truncatingIfNeeded: ordinal.ordinal.rawValue)` |
| `Rotation.Phase` | `Int(ordinal.rawValue)` | `Int(ordinal.ordinal.rawValue)` |
| `Axis<N>` | `Int(bitPattern: ordinal)` | `Int(bitPattern: ordinal.ordinal)` |
| `Tagged (conditional)` | `self.init(__unchecked: (), ordinal)` | `self.init(__unchecked: (), ordinal.ordinal)` |
| `Theme` | `self.ordinal = ordinal` | `self.ordinal = ordinal` (types match) |

**Consumer improvements**:

| Consumer | Current | After | Tier |
|----------|---------|-------|------|
| `Finite.Enumeration.endIndex` | `Index.Count(Element.count).map(Ordinal.init)` | `Element.count.map(Ordinal.init)` | 4→2 |
| `Finite.Enumeration.Iterator.next()` | `index < Element.count` | `index < Element.count` (cross-type comparison) | unchanged |
| `Finite.Enumeration.count` | `Int(clamping: Element.count)` | `Int(clamping: Element.count.cardinal)` | boundary |

Files touched: `Finite.Enumerable.swift`, `Finite.Capacity.swift`, `Tagged+Finite.Enumerable.swift`, `Finite.Enumeration.swift`, `Finite.Bounded.swift` (swift-finite-primitives); `Bit+Finite.Enumerable.swift` (swift-bit-primitives); `Rotation.Phase.swift` (swift-symmetry-primitives); `Axis+CaseIterable.swift` (swift-dimension-primitives); `Theme.swift` (swift-color-standard).

#### Phase 3: Sequence iterator internals (findings #7, #8)

**Package**: `swift-sequence-primitives`
**Independent of Phases 1–2.** All `@usableFromInline` — no public API change.

| Type | Property | Current | After |
|------|----------|---------|-------|
| `Swift.Span<Element>.Iterator` | `_position` | `Ordinal` | `Index<Element>` |
| `Swift.Span<Element>.Iterator` | `_count` | `Cardinal` | `Index<Element>.Count` |
| `Swift.Span<Element>.Iterator.Batch` | `_position` | `Ordinal` | `Index<Element>` |
| `Swift.Span<Element>.Iterator.Batch` | `_count` | `Cardinal` | `Index<Element>.Count` |
| `Sequence.Drop.First` | `_count` | `Cardinal` | `Index<Base.Element>.Count` |
| `Sequence.Drop.First.Iterator` | `_remaining` | `Cardinal` | `Index<Base.Element>.Count` |
| `Sequence.Prefix.First` | `_count` | `Cardinal` | `Index<Base.Element>.Count` |
| `Sequence.Prefix.First.Iterator` | `_remaining` | `Cardinal` | `Index<Base.Element>.Count` |
| `Sequence.Difference.Steps.Iterator` | `_index` | `Ordinal` | domain-dependent |
| `Sequence.Difference.Steps.Iterator` | `_count` | `Cardinal` | domain-dependent |
| `Sequence.Difference.Changes.Iterator` | `_index` | `Ordinal` | domain-dependent |
| `Sequence.Difference.Changes.Iterator` | `_count` | `Cardinal` | domain-dependent |

#### Phase 4: `Sequence.Iterator.Protocol` (finding #3)

**Package**: `swift-sequence-primitives`
**Depends on**: Phase 3

```swift
// Before
mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element>

// After
mutating func nextSpan(maximumCount: Index<Element>.Count) -> Swift.Span<Element>
```

Update default implementations (`next()`, `skip(by:)`) and all conformers. Currently DEFERRED — `maximumCount` is a caller-supplied limit where callers rarely have a tagged count in scope.

#### Phase 5: `Sequence.Difference.Hunk` (finding #6)

**Package**: `swift-sequence-primitives`

| Property | Current | After |
|----------|---------|-------|
| `oldStart` | `Ordinal` | needs phantom tag decision |
| `oldCount` | `Cardinal` | needs phantom tag decision |
| `newStart` | `Ordinal` | needs phantom tag decision |
| `newCount` | `Cardinal` | needs phantom tag decision |

**Open question**: what phantom tags represent "old line" vs "new line"? Options: `Sequence.Difference.Old`/`.New`, or a single `Line` tag with old/new as separate properties.

#### Phase 6: Cyclic groups + parser (findings #10, #11)

| Type | Property | Current | After |
|------|----------|---------|-------|
| `Cyclic.Group.Static<N>.Element` | `position` | `Ordinal` | `Ordinal.Finite<N>` |
| `Cyclic.Group.Static<N>.Iterator` | `current` | `Ordinal` | `Ordinal.Finite<N>` or `Index<Element>` |
| `Cyclic.Group.Static<N>.Iterator` | `bound` | `Cardinal` | `Cardinal.Finite<N>` or `Index<Element>.Count` |
| `Cyclic.Group.Element` | `residue` | `Ordinal` | case-by-case |
| `Parser.Machine.Memoization.Key` | `node` | `Ordinal` | `Index<Parser.Machine.Node>` |

### Precedent

**Buffer.Aligned.count** (`swift-buffer-primitives`): `Cardinal` → `Index<UInt8>.Count`. Commit `4167371`. Four files changed, zero downstream breakage across the full swift-primitives superrepo. This established the mechanical pattern used throughout this audit.

### Conversion Tier Reference

Per [CONV-016], conformer code uses tier 4 typed initializers (`Index<Self>.Count(2)`). Consumer code improves to tier 1–2 (retag/map). See `/conversions` skill for the full hierarchy.

### Summary

14 findings: 0 critical, 3 high, 7 medium, 1 low, 1 deferred, 2 false positives. 1 resolved (Buffer.Aligned.count).

**Systemic pattern**: All bare-type violations are in swift-primitives L1 (tiers 1–5). swift-standards and swift-foundations already use tagged types throughout — the anti-pattern exists only at the lowest infrastructure level where the typed index system was introduced after the original APIs were written.

**High-priority**: Findings #1–2 (`Finite.Capacity` + `Finite.Enumerable`) are the keystone — fixing the protocol requirements automatically propagates through all 16 conformers and unlocks consumer improvements. Finding #6 (`Sequence.Difference.Hunk`) is the only other public API violation.

**Design decisions needed**: Finding #6 (Hunk phantom tag: `Old`/`New` vs `Line`) and finding #10 (cyclic group domain tagging strategy).

### Execution Priority

```
Priority 1: Phase 1 — Finite.Capacity (finding #1)
    └── 2 conformers, smallest blast radius, validates protocol-level pattern
    └── Unblocks Phase 2

Priority 2: Phase 2 — Finite.Enumerable (finding #2)
    └── 16 conformers across 5 packages — keystone change
    └── Unlocks consumer improvements (tier 4→2)
    └── Unblocks Phases 3–6

Priority 3: Phase 3 — Sequence iterator internals (findings #7, #8)
    └── Mechanical, all @usableFromInline, no public API, no design decisions
    └── Independent of Phases 1–2 but benefits from validated pattern

Priority 4: Phase 5 — Sequence.Difference.Hunk (finding #6)
    └── Public API — last HIGH finding after Phases 1–2
    └── BLOCKED on design decision: phantom tag for old/new line positions

Priority 5: Phase 6 — Cyclic groups + parser (findings #10, #11)
    └── BLOCKED on design decision: cyclic group domain tagging strategy
    └── Parser.Machine.Memoization.Key is independent and trivial

Priority 6: Phase 4 — Sequence.Iterator.Protocol (finding #3)
    └── Currently DEFERRED — revisit after Phases 1–3 establish pattern
```

## Memory Safety — 2026-03-25

### Scope

- **Target**: swift-primitives, swift-standards, swift-foundations (ecosystem-wide)
- **Skill**: memory — [MEM-SAFE-001], [MEM-SAFE-002], [MEM-SAFE-010], [MEM-SAFE-012], [MEM-SAFE-014], [MEM-SAFE-020–025], [MEM-UNSAFE-003], [MEM-SEND-001]
- **Reference**: `swift-institute/Research/swift-safety-model-reference.md`
- **Files**: All `Sources/` across three superrepos

### Per-Package Triage

| Superrepo | Findings | Worst Severity | Notes |
|-----------|----------|---------------|-------|
| swift-primitives | 19 actionable | HIGH | Bare `@unchecked Sendable` (4 types), Arena pointer exposure (1 HIGH), Property.View family (MEDIUM), ~Escapable views (LOW) |
| swift-standards | 4 | MEDIUM | Test sub-packages missing `.strictMemorySafety()`; zero unsafe code |
| swift-foundations | 26 actionable | MEDIUM | 13 packages missing `.strictMemorySafety()`, `Async.*` Sendable gaps |

### Findings — Strict Memory Safety Enablement [MEM-SAFE-001]

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | — | [MEM-SAFE-001] | swift-primitives `Package.swift:537-552` | `.strictMemorySafety()` enabled globally via loop over all targets. Every sub-package also has it. | CLEAN |
| 2 | — | [MEM-SAFE-001] | swift-standards — all 17 active packages | `.strictMemorySafety()` enabled in all main packages. | CLEAN |
| 3 | MEDIUM | [MEM-SAFE-001] | swift-standards `swift-html-standard/Tests/Package.swift:36` | Test sub-package missing `.strictMemorySafety()`. Main package has it. | OPEN |
| 4 | LOW | [MEM-SAFE-001] | swift-standards `swift-pdf-standard/Tests/Package.swift:49` | Test sub-package missing `.strictMemorySafety()`. | OPEN |
| 5 | LOW | [MEM-SAFE-001] | swift-standards `swift-svg-standard/Tests/Package.swift:35` | Test sub-package missing `.strictMemorySafety()`. | OPEN |
| 6 | LOW | [MEM-SAFE-001] | swift-standards `swift-rfc-template/Package.swift.template` | Template stale: lacks `.strictMemorySafety()`, still on tools-version 6.0, imports Foundation. New packages scaffolded from this will not have strict safety. | OPEN |
| 7 | MEDIUM | [MEM-SAFE-001] | swift-foundations — 13 packages | `swift-copy-on-write`, `swift-css`, `swift-css-html-rendering`, `swift-dependency-analysis`, `swift-html`, `swift-html-rendering`, `swift-markdown-html-rendering`, `swift-pdf-html-rendering`, `swift-pdf-rendering`, `swift-svg`, `swift-svg-rendering`, `swift-svg-rendering-worktree`, `swift-translating` — all missing `.strictMemorySafety()`. Entire rendering/HTML/CSS cluster. | RESOLVED 2026-04-16 — verified all 13 packages now declare `.strictMemorySafety()` |

### Findings — Unsafe Pointer Exposure [MEM-SAFE-023], [MEM-SAFE-012], [MEM-SAFE-014]

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 8 | HIGH | [MEM-SAFE-023] | `swift-memory-primitives/.../Memory.Arena.swift:65` | `@safe` Escapable struct exposes `public var start: UnsafeMutableRawPointer` without `@unsafe`. Arena is `~Copyable` but NOT `~Escapable` — pointer can outlive arena if extracted. Genuinely dangerous. | OPEN |
| 9 | LOW | [MEM-SAFE-023] | `swift-path-primitives/.../Path.View.swift:37` | `public let pointer: UnsafePointer<Char>` on `@safe ~Escapable` type. **Structurally safe** — type system prevents pointer from outliving source. `@unsafe` recommended for documentation but not a safety issue. | OPEN |
| 10 | LOW | [MEM-SAFE-023] | `swift-string-primitives/.../String.View.swift:35` | `public let pointer: UnsafePointer<Char>` on `@safe ~Escapable` type. Same analysis as Path.View — structurally safe. | OPEN |
| 11 | MEDIUM | [MEM-SAFE-023] | `swift-property-primitives/.../Property.View.swift:150` | `public var base: UnsafeMutablePointer<Base>` — Property.View is `~Copyable` but NOT `~Escapable` (omitted per [MEM-COPY-013] compiler bug). Safe by coroutine scope convention, not by type system. 7 variants affected. | OPEN |
| 12 | MEDIUM | [MEM-SAFE-012] | `swift-memory-primitives/.../Memory.Buffer.Base.swift:37,52` | `public var nullable/nonNull: UnsafeRawBufferPointer` on Property extensions — stdlib bridge properties without `@unsafe`. Mutable variant at `Memory.Buffer.Mutable.Base.swift` has same issue. | OPEN |
| 13 | MEDIUM | [MEM-SAFE-014] | swift-foundations `swift-memory/.../Memory.Map.swift:149,155` | `public var baseAddress: UnsafeRawPointer?` and `mutableBaseAddress: UnsafeMutableRawPointer?` — no Span normative accessor alongside these pointer properties. | OPEN |
| 14 | MEDIUM | [MEM-SAFE-012] | swift-foundations `swift-file-system/.../File.Path.Component.swift:66` | `public init(utf8 buffer: UnsafeBufferPointer<UInt8>)` — should have a `Span<UInt8>` overload as normative interface. | OPEN |

### Findings — Sendable Safety [MEM-SAFE-024], [MEM-SEND-001]

Per [MEM-SAFE-024], each `@unchecked Sendable` is classified into a semantic category:
- **Cat A**: Synchronized (mutex/atomic) — add `@unsafe` + doc
- **Cat B**: Ownership transfer (`~Copyable`) — add `@unsafe` + doc
- **Cat C**: Thread-confined — DEFER for `~Sendable` (SE-0518)

See `swift-institute/Research/tilde-sendable-semantic-inventory.md` for the full framework.

| # | Severity | Rule | Location | Finding | Cat | Status |
|---|----------|------|----------|---------|-----|--------|
| 15 | HIGH | [MEM-SAFE-024] | `swift-handle-primitives/.../Generation.Tracker.swift:205` | `@unchecked Sendable` without `@unsafe`. `~Copyable` ownership transfer pattern. Doc comment "Not thread-safe" refers to concurrent mutation, not transfer safety — but wording is misleading and should be clarified. | B | OPEN |
| 16 | HIGH | [MEM-SAFE-024] | `swift-bit-vector-primitives/.../Bit.Vector.swift:146` | `@unchecked Sendable` without `@unsafe`. `~Copyable` unique ownership makes transfer sound. Lacks safety invariant doc. | B | OPEN |
| 17 | HIGH | [MEM-SAFE-024] | `swift-memory-primitives/.../Memory.Arena.swift:125` | `@unchecked Sendable` without `@unsafe`. `~Copyable` ownership transfer. Required by `Storage.Arena`. | B | OPEN |
| 18 | HIGH | [MEM-SAFE-024] | `swift-memory-primitives/.../Memory.Pool.swift:370` | `@unchecked Sendable` without `@unsafe`. `~Copyable` ownership transfer. No current cross-layer consumers but consistent with Arena. | B | OPEN |
| 19 | MEDIUM | [MEM-SAFE-024] | `swift-predicate-primitives/.../Predicate.swift:29` | `@unchecked Sendable` on Copyable type storing `(T) -> Bool` closure. Closures are not `@Sendable` by default. Neither synchronized (A) nor `~Copyable` (B). Potentially unsound. | — | OPEN |
| 20 | MEDIUM | [MEM-SAFE-024] | `swift-lifetime-primitives/.../Lifetime.Lease.swift:74` | `@unchecked Sendable where Value: Sendable` — `~Copyable` conditional ownership transfer. Sound, lacks `@unsafe`. | B | OPEN |
| 21 | MEDIUM | [MEM-SAFE-024] | `swift-machine-primitives/.../Machine.Capture.Slot.swift:17` | `@unchecked Sendable` on outer `Slot` struct — inner `_Storage` is synchronized (atomic). | A | OPEN |
| 22 | MEDIUM | [MEM-SAFE-024] | swift-foundations `swift-async/.../Async.Filter.swift:88` | `Async.Filter: @unchecked Sendable` — stores non-`@Sendable` closures. 8 types (Filter/Map/CompactMap/FlatMap + iterators). Needs analysis: are closures captured once and confined, or potentially shared? | — | OPEN |
| 23 | MEDIUM | [MEM-SAFE-024] | swift-foundations `swift-file-system/.../File.Directory.Contents.IteratorHandle.swift:14` | `@unchecked Sendable` wrapping thread-confined `Kernel.Directory.Stream`. Tier 1 in `~Sendable` inventory. Replace `@unchecked Sendable` with `~Sendable`. | C | OPEN |

### Findings — `nonisolated(unsafe)` Without Safety Annotation [MEM-SAFE-025]

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 24 | MEDIUM | [MEM-SAFE-025] | `swift-memory-primitives/.../Memory.Buffer.swift:29,37` | `nonisolated(unsafe) let _emptyBufferSentinelMutable` and `_emptyBufferSentinel` — allocated-once globals safely encapsulated; should have `@safe`. Duplicate at `Memory Primitives/Memory.Buffer.swift`. | OPEN |
| 25 | MEDIUM | [MEM-SAFE-025] | `swift-memory-primitives/.../Memory.Buffer.Mutable.swift:19` | `nonisolated(unsafe) let _emptyMutableBufferSentinel` — same pattern, lacks `@safe`. Duplicate at `Memory Primitives/Memory.Buffer.Mutable.swift`. | OPEN |
| 26 | LOW | [MEM-SAFE-025] | swift-foundations `swift-css/.../Color.Theme.swift:13` + `Font.Theme.swift:13` | `nonisolated(unsafe) private static var _prepared` — mutable static with public `_prepare()` mutator. Data race possible if called concurrently. Consider `Mutex` or `Atomic`. | OPEN |

### Findings — Expression Placement [MEM-SAFE-002]

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 27 | LOW | [MEM-SAFE-002] | swift-foundations `swift-file-system/.../File.Handle.swift:104,160,190` | `guard unsafe !buffer.isEmpty` — `.isEmpty` on `UnsafeMutableRawBufferPointer` is a safe property. `unsafe` is over-specified here. Harmless but noisy. | OPEN |

### Findings — Annotation Correctness [MEM-UNSAFE-003]

No violations found. All three superrepos correctly avoid `@unsafe struct` on encapsulating types. All `@safe` annotations are on types with genuine unsafe internal storage.

One exemplary pattern worth noting: `Loader.Section.Bounds` (`swift-loader-primitives`) uses `@safe` struct with `@unsafe public nonisolated(unsafe) let` on individual escape-hatch properties — the canonical pattern per the research document.

### Summary

27 findings: 0 critical, 5 high, 14 medium, 8 low. (Revised 2026-03-25: findings #9, #10 downgraded HIGH→LOW per `~Escapable` structural safety analysis.)

**Systemic patterns**:

1. **`@unchecked Sendable` without `@unsafe`** (findings #15–23): The most widespread issue. 13 types across primitives and foundations use bare `@unchecked Sendable`. Most are sound due to `~Copyable` unique ownership, but all lack the `@unsafe` annotation required by SE-0458 and safety invariant documentation. The `Async.*` sequence cluster in swift-foundations is the largest group (8 types).

2. **Pointer property exposure without `@unsafe`** (findings #8–14): Public properties returning unsafe pointer types on `@safe` types. Severity depends on escapability of the containing type:
   - `~Escapable` types (Path.View, String.View): **structurally safe** — pointer cannot outlive source. LOW severity.
   - Coroutine-scoped types (Property.View family): safe by convention but not type system. MEDIUM severity.
   - Escapable types (Memory.Arena): **genuinely dangerous** — pointer can outlive container. HIGH severity.

3. **`.strictMemorySafety()` gaps** (finding #7): ~~13 swift-foundations packages in the rendering/HTML/CSS cluster lack the flag.~~ RESOLVED 2026-04-16 — all 13 packages now declare `.strictMemorySafety()` in their Package.swift `swiftSettings`.

4. **`nonisolated(unsafe)` sentinel globals** (findings #24–25): Safely encapsulated globals that should have `@safe` annotation for SE-0458 compliance.

**Positive observations**:

- swift-primitives has 100% `.strictMemorySafety()` coverage
- swift-standards has zero unsafe code — architecturally clean Layer 2
- All `@safe`/`@unsafe` type-level annotations are correct across the ecosystem
- The IO subsystem in swift-foundations has exemplary safety documentation on every `@unchecked Sendable`
- No anti-patterns from research document Section 14 detected (no wrong-side assignment, no double unsafe, no unsafe on allocate)
- `~Escapable` types (Path.View, String.View) achieve structural pointer safety through the type system — the strongest form of isolation

### Remediation Priority

```
Priority 1: Cat B — @unchecked Sendable → add @unsafe + Pattern B doc (findings #15–18, #20)
    └── 5 ~Copyable types: Bit.Vector, Generation.Tracker, Memory.Arena, Memory.Pool, Lifetime.Lease

Priority 2: Cat A — @unchecked Sendable → add @unsafe + sync doc (finding #21)
    └── Machine.Capture.Slot (synchronized via atomic)

Priority 3: Cat C — Thread-confined → replace @unchecked Sendable with ~Sendable (finding #23)
    └── File.Directory.Contents.IteratorHandle → ~Sendable
    └── Also: IO.Completion.IOUring.Ring, IO.Completion.IOCP.State (Tier 1 per ~Sendable inventory)

Priority 4: Memory.Arena.start → add @unsafe (finding #8)
    └── Only HIGH pointer exposure finding after ~Escapable reassessment

Priority 5: Property.View family → add @unsafe to base properties (finding #11)
    └── 7 variants, MEDIUM (coroutine-scoped but not ~Escapable)

Priority 6: Sentinel globals → add @safe (findings #24–25)
    └── 4 globals in swift-memory-primitives

Priority 7: .strictMemorySafety() gaps (finding #7)
    └── 13 swift-foundations rendering packages

Priority 8: Needs analysis (findings #19, #22)
    └── Predicate closure soundness, Async.* category determination

Priority 9: Documentation improvements (findings #9, #10, #12–14, #26, #27)
    └── @unsafe on ~Escapable pointer properties (optional), CSS theming, over-specified unsafe
```

### Remediation Plan — Concrete Code Changes

Each fix maps to a finding above. Grouped by category with exact file, current code, and target change.

**Canonical references**:
- `swift-institute/Research/swift-safety-model-reference.md` — safety model semantics
- `swift-institute/Research/tilde-sendable-semantic-inventory.md` — Sendable category framework
- `memory-safety` skill — [MEM-SAFE-020–025], [MEM-SEND-001–003]

#### P1: Category B — `@unsafe @unchecked Sendable` + Pattern B doc (findings #15–18, #20)

**Pattern B safety invariant** (use verbatim for all 5 types):
```
/// @unchecked Sendable: Category B (ownership transfer).
/// ~Copyable unique ownership ensures only one thread can own the value
/// at a time. Transfer via `consuming` relinquishes the sender's access.
```

| # | File | Current | Target |
|---|------|---------|--------|
| F15 | `swift-handle-primitives/.../Generation.Tracker.swift:205` | `extension Generation.Tracker: @unchecked Sendable {}` | `extension Generation.Tracker: @unsafe @unchecked Sendable {}` + Pattern B doc. Also fix doc at line 40: "Not thread-safe. External synchronization required" → "Not concurrently mutable. Ownership transfer is safe via ~Copyable." |
| F16 | `swift-bit-vector-primitives/.../Bit.Vector.swift:146` | `extension Bit.Vector: @unchecked Sendable {}` | `extension Bit.Vector: @unsafe @unchecked Sendable {}` + Pattern B doc |
| F17 | `swift-memory-primitives/.../Memory.Arena.swift:125` | `extension Memory.Arena: @unchecked Sendable {}` | `extension Memory.Arena: @unsafe @unchecked Sendable {}` + Pattern B doc |
| F18 | `swift-memory-primitives/.../Memory.Pool.swift:370` | `extension Memory.Pool: @unchecked Sendable {}` | `extension Memory.Pool: @unsafe @unchecked Sendable {}` + Pattern B doc |
| F20 | `swift-lifetime-primitives/.../Lifetime.Lease.swift:74` | `extension Lifetime.Lease: @unchecked Sendable where Value: Sendable {}` | `extension Lifetime.Lease: @unsafe @unchecked Sendable where Value: Sendable {}` + Pattern B doc |

**Design rationale**: Cannot be made checked `Sendable` — `UnsafeMutablePointer` storage prevents it. `~Copyable` unique ownership provides the proof the compiler cannot verify. Type system gap, not a design problem.

#### P2: Category A — `@unsafe @unchecked Sendable` + sync doc (finding #21)

| # | File | Current | Target |
|---|------|---------|--------|
| F21 | `swift-machine-primitives/.../Machine.Capture.Slot.swift:17` | `public struct Slot: @unchecked Sendable {` | `public struct Slot: @unsafe @unchecked Sendable {` + doc: "Category A (synchronized). Inner `_Storage` uses atomic operations for thread-safe slot management." |

#### P3: Category C — Replace `@unchecked Sendable` with `~Sendable` (finding #23 + Tier 1 inventory)

Enable via `.enableExperimentalFeature("TildeSendable")` in Package.swift.

| # | File | Current | Target |
|---|------|---------|--------|
| F23 | `swift-file-system/.../File.Directory.Contents.IteratorHandle.swift:14` | `final class IteratorHandle: @unchecked Sendable` | `final class IteratorHandle: ~Sendable` — thread-confined directory stream. Transfer site uses explicit `unsafe`. |
| T1a | `swift-io/.../IO.Completion.IOUring.Ring` | `@unchecked Sendable` | `~Sendable` — confined to poll thread. Tier 1 per inventory. |
| T1b | `swift-io/.../IO.Completion.IOCP.State` | `@unchecked Sendable` | `~Sendable` — confined to completion port thread. Tier 1 per inventory. |

**Design rationale**: These types are NOT safe to send arbitrarily. `@unchecked Sendable` is a semantic lie. `~Sendable` expresses the truth: the type is non-Sendable, and the single transfer to the confined thread is an explicit unsafe boundary crossing.

#### P4: Pointer exposure — add `@unsafe` (finding #8)

| # | File | Current | Target |
|---|------|---------|--------|
| F8 | `swift-memory-primitives/.../Memory.Arena.swift:65` | `public var start: UnsafeMutableRawPointer { unsafe _storage }` | `@unsafe public var start: UnsafeMutableRawPointer { unsafe _storage }` |

**Design rationale**: Arena is `~Copyable` but NOT `~Escapable`. Pointer can outlive arena. Cannot eliminate — `Storage.Arena` requires mutable typed pointer computation. `@unsafe` is the correct end state.

#### P5: Property.View family — add `@unsafe` to base properties (finding #11)

7 variants, same pattern:

| # | File |
|---|------|
| F11a | `swift-property-primitives/.../Property.View.swift` |
| F11b | `swift-property-primitives/.../Property.View.Typed.swift` |
| F11c | `swift-property-primitives/.../Property.View.Read.swift` |
| F11d | `swift-property-primitives/.../Property.View.Read.Typed.swift` |
| F11e | `swift-property-primitives/.../Property.View.Typed.Valued.swift` |
| F11f | `swift-property-primitives/.../Property.View.Read.Typed.Valued.swift` |
| F11g | `swift-property-primitives/.../Property.View.Typed.Valued.Valued.swift` |

**Target**: Add `@unsafe` to each `public var base: UnsafeMutablePointer<Base>` property.

**Design rationale**: `~Copyable` but NOT `~Escapable` (omitted per [MEM-COPY-013]). Safe by coroutine scope, not type system. When the compiler bug is fixed and `~Escapable` is added, these downgrade to LOW.

#### P6: Sentinel globals — add `@safe` (findings #24–25)

| # | File | Global |
|---|------|--------|
| F24a | `swift-memory-primitives/.../Memory Buffer Primitives/Memory.Buffer.swift:29` | `_emptyBufferSentinelMutable` |
| F24b | `swift-memory-primitives/.../Memory Buffer Primitives/Memory.Buffer.swift:37` | `_emptyBufferSentinel` |
| F25 | `swift-memory-primitives/.../Memory Buffer Primitives/Memory.Buffer.Mutable.swift:19` | `_emptyMutableBufferSentinel` |
| F24a' | `swift-memory-primitives/.../Memory Primitives/Memory.Buffer.swift:29` | duplicate of F24a |
| F24b' | `swift-memory-primitives/.../Memory Primitives/Memory.Buffer.swift:37` | duplicate of F24b |
| F25' | `swift-memory-primitives/.../Memory Primitives/Memory.Buffer.Mutable.swift:19` | duplicate of F25 |

**Target**: Add `@safe` to each `nonisolated(unsafe) let` declaration.

**Design rationale**: Cannot eliminate `nonisolated(unsafe)` — Swift 6 requires it for lazy-initialized globals. Sentinels are `let`, allocated once, address-only comparisons. `@safe` asserts the invariant.

#### P7: `.strictMemorySafety()` gaps (finding #7)

Add `.strictMemorySafety()` to `swiftSettings` for 13 swift-foundations packages:

```
swift-copy-on-write          swift-html-rendering
swift-css                    swift-markdown-html-rendering
swift-css-html-rendering     swift-pdf-html-rendering
swift-dependency-analysis    swift-pdf-rendering
swift-html                   swift-svg
swift-svg-rendering          swift-svg-rendering-worktree
swift-translating
```

Plus 3 swift-standards test sub-packages and the stale `swift-rfc-template/Package.swift.template`.

#### P8: Needs analysis before fixing

| # | Type | Question | Options |
|---|------|----------|---------|
| F19 | `Predicate<T>: @unchecked Sendable` | Copyable type stores `(T) -> Bool` — not `@Sendable`. Neither synchronized (A) nor `~Copyable` (B). | (a) Make closure `@Sendable` in API, (b) Remove `Sendable` conformance, (c) Determine if type should be `~Copyable` |
| F22 | `Async.Filter/Map/CompactMap/FlatMap` (8 types) | Store non-`@Sendable` closures with `@unchecked Sendable`. | (a) Make closures `@Sendable`, (b) Category C → `~Sendable`, (c) Accept as Category A if async runtime provides confinement |

#### P9: Documentation improvements (LOW — optional)

| # | File | Change |
|---|------|--------|
| F9 | `swift-path-primitives/.../Path.View.swift:37` | Optionally add `@unsafe` to `pointer` (structurally safe via `~Escapable`) |
| F10 | `swift-string-primitives/.../String.View.swift:35` | Same as F9 |
| F12–14 | Various | Minor: `Memory.Buffer` properties, `File.Path.Component` init, `Memory.Map` addresses |
| F26 | `swift-css/.../Color.Theme.swift:13`, `Font.Theme.swift:13` | Mutable static with data race risk. Consider `Mutex` or `Atomic`. |
| F27 | `swift-file-system/.../File.Handle.swift:104,160,190` | Remove over-specified `unsafe` on `.isEmpty` |

## Variant Naming — 2026-03-25

### Scope

- **Target**: swift-primitives ecosystem (6 packages) + swift-foundations (2 source files)
- **Skill**: code-surface — [API-NAME-001], [API-NAME-003]; academic definitions from `variant-naming-audit.md`
- **Files**: ~50 source files, ~10 test files across 6 packages + 2 downstream files
- **Subject**: 7 types named "Fixed" with bounded-buffer semantics; 2 types named "Inline" at collection level where convention is "Static"

### Triage (2026-04-16)

| Finding | Disposition | Reason |
|---------|-------------|--------|
| #1 Queue.Fixed → .Bounded | **EXECUTE** | Now strictly worse than 2026-03-25: `Queue.Static<let capacity: Int>` exists alongside `Queue.Fixed`, so "Fixed" is actively misleading (Static IS the truly fixed variant). Doc rot: `Queue.Fixed.swift` already references nonexistent `Queue<Int>.Bounded(capacity:)` API. |
| #2 Queue.DoubleEnded.Fixed → .Bounded | **EXECUTE** | Same; `Queue.DoubleEnded.Static<N>` exists. |
| #3 Queue.Linked.Fixed → .Bounded | **EXECUTE** | Same; `Queue.Linked.Bounded` already exists at `Queue Linked Primitives/Queue.Linked.Bounded.swift` as a separate struct with the correct name — `Queue.Linked.Fixed` is now a duplicate semantic. |
| #4 Heap.Fixed → .Bounded | **EXECUTE** | Same; `Heap.Static<N>` exists, `Heap.swift` doc overview already lists "Heap/Fixed: Fixed capacity, heap-allocated" + "Heap/Static: Compile-time capacity". |
| #5 Heap.MinMax.Fixed → .Bounded | **EXECUTE** | Same; `Heap.MinMax.Static<N>` exists. |
| #6 Set.Ordered.Fixed → .Bounded | **EXECUTE** | Same; `Set.Ordered.Static<N>` exists. |
| #7 Bitset.Fixed → .Bounded | **EXECUTE** | Same; `Bitset.Static<wordCount>` exists. |
| #8 List.Linked.Inline<N> → .Static<N> | **EXECUTE** | Diverges from established collection-level convention (Queue/Heap/Set/Bitset all use Static). `List.Linked.Bounded` already exists separately; this rename is purely the collection/storage layer naming distinction (variant-naming-audit §3). |
| #9 Tree.N.Inline<N> → .Static<N> | **EXECUTE** | Same as #8; `Tree.N.Bounded` already exists with full directory + 14 files. |

**Severity unchanged: HIGH.** All 9 dispositions are EXECUTE; none warrant DEFER or WONTFIX. The audit's existing per-package sed + `git mv` plan (above) remains the correct execution path. The `variant-naming-audit.md` research doc (v2.0.0, 2026-03-24) provides the academic justification and full inventory; the taxonomy is stable.

**Pre-execution risk**: Findings #1–7 require renaming the underlying `struct Fixed` declaration, not just files. Sed pattern `s/struct Fixed/struct Bounded/g` is safe inside the 6 affected packages (no other "Fixed" struct declarations there) but will not match `Array.Fixed` (in `swift-array-primitives`), which must remain. Safety constraint #1 in the existing plan ("Never touch swift-array-primitives") covers this.

### Partial Progress (2026-04-16 re-verification)

The execution plan below describes a binary `Fixed → Bounded` and `Inline → Static` rename. Re-verification on 2026-04-16 shows the ecosystem has instead evolved a tripartite taxonomy:

- **`Static<let capacity: Int>`** (added): compile-time-fixed capacity. New types: `Queue.Static`, `Queue.DoubleEnded.Static`, `Heap.Static`, `Heap.MinMax.Static`, `Set.Ordered.Static`, `Bitset.Static` — each in its own `* Static Primitives/` directory or alongside the legacy declarations.
- **`Bounded`** (added in linked variants): runtime-bounded mutable count. New types: `Queue.Linked.Bounded`, `List.Linked.Bounded`, `Tree.N.Bounded` (full `Tree N Bounded Primitives/` directory with order/iterator/sequence variants).
- **`Fixed` / `Inline`** (legacy, still declared): Original `public struct Fixed` and `public struct Inline<let capacity: Int>` declarations remain at the cited locations. The original audit findings (rename `Fixed → Bounded`, `Inline → Static`) remain OPEN at the struct-declaration level even though parallel directories and types have been added.

The `Queue.Bounded.swift` file at `Sources/Queue Fixed Primitives/` is an extension file on the still-existing `Queue.Fixed` struct, not a renamed declaration. Cited line numbers below are still accurate within ±1 line.

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | HIGH | [API-NAME-003] | swift-queue-primitives: `Queue.Fixed` | Bounded-buffer semantics (mutable count, capacity-limited) named "Fixed" instead of "Bounded" (Dijkstra 1965). `struct Fixed` declared in Queue.Fixed.swift:43. | OPEN |
| 2 | HIGH | [API-NAME-003] | swift-queue-primitives: `Queue.DoubleEnded.Fixed` | Same as #1. Declared in Queue.DoubleEnded.swift:47. | OPEN |
| 3 | HIGH | [API-NAME-003] | swift-queue-primitives: `Queue.Linked.Fixed` | Same as #1. Declared in Queue.Linked.swift:87. | OPEN |
| 4 | HIGH | [API-NAME-003] | swift-heap-primitives: `Heap.Fixed` | Same as #1. Declared in Heap.swift:103. `comparative-heap-primitives.md` line 154 already calls it "bounded capacity" in prose. | OPEN |
| 5 | HIGH | [API-NAME-003] | swift-heap-primitives: `Heap.MinMax.Fixed` | Same as #1. Declared in Heap.MinMax.Fixed.swift. | OPEN |
| 6 | HIGH | [API-NAME-003] | swift-set-primitives: `Set.Ordered.Fixed` | Same as #1. Declared in Set.swift:73. | OPEN |
| 7 | HIGH | [API-NAME-003] | swift-bitset-primitives: `Bitset.Fixed` | Same as #1. Declared in Bitset.Fixed.swift. | OPEN |
| 8 | MEDIUM | convention | swift-list-primitives: `List.Linked.Inline<N>` | Collection-level variant uses "Inline" (infrastructure name) instead of "Static" (collection convention). Declared in List.Linked.swift:146. | OPEN |
| 9 | MEDIUM | convention | swift-tree-primitives: `Tree.N.Inline<N>` | Same as #8. Declared in Tree.N.Inline.swift:37. | OPEN |

### Execution Plan

Each rename touches 5 layers: struct declarations, all type references, module/target names, file names, directory names. The replacement is mechanical and per-package safe (no "Fixed" variant in any affected package should remain "Fixed"). Full academic rationale in `variant-naming-audit.md`.

#### Reference Patterns (all must be caught)

| Pattern | Example | Replacement |
|---------|---------|-------------|
| `.Fixed` (type position) | `extension Queue.Fixed where...` | `.Bounded` |
| `struct Fixed` | `public struct Fixed: ~Copyable` | `struct Bounded` |
| `Queue<Element>.Fixed` | `throws(Queue<Element>.Fixed.Error)` | `Queue<Element>.Bounded` |
| `Queue<Int>.Fixed` | `Queue<Int>.Fixed(capacity: 10)` | `Queue<Int>.Bounded` |
| `Queue<ConcreteType>.*.Fixed` | `Queue<IO...>.DoubleEnded.Fixed(...)` | `...DoubleEnded.Bounded(...)` |
| `__*FixedError` | `__QueueDoubleEndedFixedError` | `__QueueDoubleEndedBoundedError` |
| `__*FixedError` | `__SetOrderedFixedError` | `__SetOrderedBoundedError` |
| `__*FixedError` | `__BitsetFixedError` | `__BitsetBoundedError` |
| `*FixedTests` | `QueueFixedTests` | `QueueBoundedTests` |
| `*_Fixed_Primitives` | `Queue_Fixed_Primitives` | `Queue_Bounded_Primitives` |
| `"* Fixed Primitives"` | `"Queue Fixed Primitives"` | `"Queue Bounded Primitives"` |
| `Queue/Fixed` (DocC) | DocC link syntax | `Queue/Bounded` |
| `"Queue.Fixed"` (strings) | test suite name | `"Queue.Bounded"` |
| File names | `Queue.Fixed.swift` | `Queue.Bounded.swift` |
| Directory names | `Queue Fixed Primitives/` | `Queue Bounded Primitives/` |
| `List.Linked.Inline` | `extension List.Linked.Inline where...` | `List.Linked.Static` |
| `Tree.N.Inline` | `extension Tree.N.Inline where...` | `Tree.N.Static` |
| `struct Inline<let capacity` | collection-level declaration | `struct Static<let capacity` |
| `__ListLinkedInlineError` | hoisted error | `__ListLinkedStaticError` |
| `__TreeNInlineError` | hoisted error | `__TreeNStaticError` |
| `Tree_N_Inline_Primitives` | module import | `Tree_N_Static_Primitives` |
| `Tree N Inline Primitives` | target name | `Tree N Static Primitives` |

#### Per-Package Content Replacement (sed)

**swift-queue-primitives** (3 Fixed types, 1 hoisted error, 1 module/target):

```bash
PKG="swift-queue-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/\.Fixed/.Bounded/g' \
  -e 's/struct Fixed/struct Bounded/g' \
  -e 's/__QueueDoubleEndedFixedError/__QueueDoubleEndedBoundedError/g' \
  -e 's/QueueFixedTests/QueueBoundedTests/g' \
  -e 's/Queue_Fixed_Primitives/Queue_Bounded_Primitives/g' \
  -e 's/Queue Fixed Primitives/Queue Bounded Primitives/g'
```

**swift-heap-primitives** (2 Fixed types, 1 module/target):

```bash
PKG="swift-heap-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/\.Fixed/.Bounded/g' \
  -e 's/struct Fixed/struct Bounded/g' \
  -e 's/Heap_Fixed_Primitives/Heap_Bounded_Primitives/g' \
  -e 's/Heap Fixed Primitives/Heap Bounded Primitives/g'
```

**swift-set-primitives** (1 Fixed type, 1 hoisted error, no separate module):

```bash
PKG="swift-set-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/\.Fixed/.Bounded/g' \
  -e 's/struct Fixed/struct Bounded/g' \
  -e 's/__SetOrderedFixedError/__SetOrderedBoundedError/g'
```

**swift-bitset-primitives** (1 Fixed type, 1 hoisted error, no separate module):

```bash
PKG="swift-bitset-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/\.Fixed/.Bounded/g' \
  -e 's/struct Fixed/struct Bounded/g' \
  -e 's/__BitsetFixedError/__BitsetBoundedError/g'
```

**swift-list-primitives** (1 Inline→Static, 1 hoisted error):

```bash
PKG="swift-list-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/List\.Linked\.Inline/List.Linked.Static/g' \
  -e 's/__ListLinkedInlineError/__ListLinkedStaticError/g'
# Declaration rename (only in the one file):
sed -i '' 's/public struct Inline<let capacity/public struct Static<let capacity/g' \
  "$PKG/Sources/List Primitives Core/List.Linked.swift"
```

**swift-tree-primitives** (1 Inline→Static, 1 hoisted error, 1 module/target):

```bash
PKG="swift-tree-primitives"
find "$PKG" \( -name '*.swift' -o -name '*.md' \) -not -path '*/.build/*' | xargs sed -i '' \
  -e 's/Tree\.N\.Inline/Tree.N.Static/g' \
  -e 's/__TreeNInlineError/__TreeNStaticError/g' \
  -e 's/Tree_N_Inline_Primitives/Tree_N_Static_Primitives/g' \
  -e 's/Tree N Inline Primitives/Tree N Static Primitives/g'
# Declaration rename:
sed -i '' 's/public struct Inline<let capacity/public struct Static<let capacity/g' \
  "$PKG/Sources/Tree N Inline Primitives/Tree.N.Inline.swift"
```

**swift-foundations** (downstream, 3 references):

```bash
sed -i '' 's/\.Fixed/.Bounded/g' \
  "swift-io/Sources/IO Blocking Threads/IO.Blocking.Threads.Worker.swift" \
  "swift-io/Sources/IO Blocking Threads/IO.Blocking.Threads.Runtime.State.swift"
sed -i '' 's/Queue\.Fixed/Queue.Bounded/g; s/Heap\.Fixed/Heap.Bounded/g; s/DoubleEnded\.Fixed/DoubleEnded.Bounded/g' \
  "swift-io/Research/data-structure-ecosystem-triage.md"
```

#### File and Directory Renames (git mv)

**swift-queue-primitives:**

```bash
cd swift-queue-primitives
git mv "Sources/Queue Fixed Primitives" "Sources/Queue Bounded Primitives"
git mv "Sources/Queue Primitives Core/Queue.Fixed.swift" "Sources/Queue Primitives Core/Queue.Bounded.swift"
git mv "Sources/Queue Bounded Primitives/Queue.Fixed Copyable.swift" "Sources/Queue Bounded Primitives/Queue.Bounded Copyable.swift"
```

**swift-heap-primitives:**

```bash
cd swift-heap-primitives
git mv "Sources/Heap Fixed Primitives" "Sources/Heap Bounded Primitives"
git mv "Sources/Heap Primitives Core/Heap.Fixed.Error.swift" "Sources/Heap Primitives Core/Heap.Bounded.Error.swift"
git mv "Sources/Heap Bounded Primitives/Heap.Fixed ~Copyable.swift" "Sources/Heap Bounded Primitives/Heap.Bounded ~Copyable.swift"
git mv "Sources/Heap Bounded Primitives/Heap.Fixed Copyable.swift" "Sources/Heap Bounded Primitives/Heap.Bounded Copyable.swift"
git mv "Sources/Heap MinMax Primitives/Heap.MinMax.Fixed.swift" "Sources/Heap MinMax Primitives/Heap.MinMax.Bounded.swift"
git mv "Sources/Heap MinMax Primitives/Heap.MinMax.Fixed ~Copyable.swift" "Sources/Heap MinMax Primitives/Heap.MinMax.Bounded ~Copyable.swift"
git mv "Sources/Heap MinMax Primitives/Heap.MinMax.Fixed Copyable.swift" "Sources/Heap MinMax Primitives/Heap.MinMax.Bounded Copyable.swift"
git mv "Tests/Heap Primitives Tests/Heap.Fixed Tests.swift" "Tests/Heap Primitives Tests/Heap.Bounded Tests.swift"
```

**swift-set-primitives:**

```bash
cd swift-set-primitives
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded.swift"
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed Copyable.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded Copyable.swift"
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed.Indexed.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded.Indexed.swift"
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed+Sequence.Consume.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded+Sequence.Consume.swift"
git mv "Sources/Set Ordered Primitives/Set.Ordered.Fixed+Sequence.Drain.swift" "Sources/Set Ordered Primitives/Set.Ordered.Bounded+Sequence.Drain.swift"
```

**swift-bitset-primitives:**

```bash
cd swift-bitset-primitives
git mv "Sources/Bitset Primitives/Bitset.Fixed.swift" "Sources/Bitset Primitives/Bitset.Bounded.swift"
git mv "Sources/Bitset Primitives/Bitset.Fixed.Error.swift" "Sources/Bitset Primitives/Bitset.Bounded.Error.swift"
git mv "Sources/Bitset Primitives/Bitset.Fixed.Algebra.swift" "Sources/Bitset Primitives/Bitset.Bounded.Algebra.swift"
git mv "Sources/Bitset Primitives/Bitset.Fixed.Algebra.Symmetric.swift" "Sources/Bitset Primitives/Bitset.Bounded.Algebra.Symmetric.swift"
git mv "Sources/Bitset Primitives/Bitset.Fixed.Relation.swift" "Sources/Bitset Primitives/Bitset.Bounded.Relation.swift"
```

**swift-list-primitives:**

```bash
cd swift-list-primitives
git mv "Sources/List Linked Primitives/List.Linked.Inline.swift" "Sources/List Linked Primitives/List.Linked.Static.swift"
```

**swift-tree-primitives:**

```bash
cd swift-tree-primitives
git mv "Sources/Tree N Inline Primitives" "Sources/Tree N Static Primitives"
git mv "Sources/Tree N Static Primitives/Tree.N.Inline.swift" "Sources/Tree N Static Primitives/Tree.N.Static.swift"
git mv "Sources/Tree N Static Primitives/Tree.N.Inline.Error.swift" "Sources/Tree N Static Primitives/Tree.N.Static.Error.swift"
```

#### Verification

```bash
# Per package:
cd {package} && swift build && swift test

# Downstream:
cd swift-foundations && swift build
```

#### Safety Constraints

1. **Never touch swift-array-primitives**: `Array.Fixed` is genuinely fixed (immutable count).
2. **Inline→Static must not touch buffer/storage layer**: `Buffer.Linked.Inline`, `Buffer.Arena.Inline`, `Storage.Inline` are correct. The sed patterns `List.Linked.Inline` and `Tree.N.Inline` are specific enough.
3. **`.Fixed` sed catches all nested Fixed types**: `Queue.Fixed`, `DoubleEnded.Fixed`, `Linked.Fixed`, `MinMax.Fixed` — all correct.
4. **Hoisted error renames are substring-safe**: `.FixedError` → `.BoundedError` via the `.Fixed` rule works correctly.
5. **`struct Inline<let capacity` in List/Tree**: Scoped to specific files to avoid touching buffer-layer declarations.
6. **Exclude `.build/` directories**: The `find` commands exclude build artifacts.

### Summary

9 findings: 0 critical, 7 high, 2 medium.

All 9 are naming violations where the code uses an academically incorrect term. The execution plan is fully mechanical: content sed, git mv, swift build/test verification. Cross-package impact is contained to 2 source files + 1 research doc in swift-foundations. Research document at `variant-naming-audit.md` provides the full academic rationale, cross-document contradiction analysis, and corrected variant system definition.

## ASCII Serialization Migration — 2026-03-25

### Scope

- **Target**: swift-ascii (L3) + 73 conformers across `swift-ietf/` and `swift-whatwg/`
- **Research**: [ascii-serialization-migration.md](ascii-serialization-migration.md) (v2.0.0, IN_PROGRESS)
- **Trigger**: 22 deprecation warnings in `swift-ascii` from `Binary.ASCII.Serializable`

### Phase Status

| Phase | Description | Types | Status |
|-------|-------------|-------|--------|
| 0 | Infrastructure (Parseable, Serializable, Codable, parsers, serializers) | — | **MOSTLY DONE** — 3 convenience extensions remain |
| 1 | Primitive integer types (Int, UInt, Int64, UInt64, etc.) | 4 | **L1 DONE** — L3 cleanup TODO |
| 2 | Simple formats (IPv4, IPv6, DNS) | 7 | TODO |
| 3 | URI (RFC 3986) | 9 | TODO |
| 4 | Date/Time (RFC 3339) | 2 | TODO |
| 5 | Email (RFC 2822, 5322, 5321, 6531, 6068) | 26 | TODO |
| 6 | MIME (RFC 2045, 2046, 2183, 2369, 2387) | 16 | TODO |
| 7 | Remaining (RFC 3987, 7519, 7617, 9557, WHATWG URL/Form) | 13 | TODO |
| 8 | Cleanup (delete protocol, Wrapper, RawRepresentable) | — | Blocked on Phases 2-7 |

### Findings

| # | Severity | Source | Location | Finding | Status |
|---|----------|--------|----------|---------|--------|
| 1 | MEDIUM | Phase 0 gap | swift-parser-primitives or swift-ascii | `Parseable.init(_: StringProtocol)` convenience missing — types cannot parse from strings via canonical protocol | OPEN |
| 2 | MEDIUM | Phase 0 gap | swift-serializer-primitives or swift-ascii | `Serializable` → String conversion missing — no `String.init` or `.asciiString` on Serializable | OPEN |
| 3 | MEDIUM | Phase 0 gap | swift-binary-primitives or swift-ascii | `Serializable` → `Binary.Serializable` bridge missing — types lose `.bytes` and `String(value)` | OPEN |
| 4 | HIGH | Phase 1 cleanup | `swift-ascii/.../Int+ASCII.Serializable.swift:103-183` | 4 redundant `Binary.ASCII.Serializable` conformances for Int/Int64/UInt/UInt64 — superseded by L1 `Parseable` + `Serializable` | OPEN |
| 5 | MEDIUM | Deprecation cascade | `swift-ascii/.../Binary.ASCII.Serializable.swift` (14 sites) | Extensions on deprecated protocol produce 14 warnings — required by 73 external conformers until Phases 2-7 complete | OPEN |
| 6 | MEDIUM | Deprecation cascade | `swift-ascii/.../Binary.ASCII.Wrapper.swift` (2 sites) | Wrapper struct and `.ascii` accessor reference deprecated protocol — 2 warnings | OPEN |
| 7 | MEDIUM | Deprecation cascade | `swift-ascii/.../Binary.ASCII.RawRepresentable.swift` (1 site) | Sub-protocol inherits from deprecated protocol — 1 warning | OPEN |
| 8 | MEDIUM | Deprecation cascade | `swift-ascii/.../StringProtocol+INCITS_4_1986.swift:221` | `init<T: Binary.ASCII.Serializable>` references deprecated protocol — 1 warning | OPEN |

### Next Actions

1. **Phase 1 cleanup** — Delete 4 integer `Binary.ASCII.Serializable` conformances (finding #4). Verify `Binary.ASCII.Decimal` namespace has no remaining consumers, or keep if needed. Eliminates 4 of 22 warnings.
2. **Deprecation cascade** — Add `@available(*, deprecated)` to findings #5-#8 (18 sites). This is the correct Swift pattern for protocol infrastructure that must stay for external conformers. Eliminates remaining 18 warnings.
3. **Phase 0 gaps** — Build findings #1-#3 (convenience extensions) to unblock Phase 2+ migration.
4. **Phases 2-7** — Migrate 73 conformers per [ascii-serialization-migration.md](ascii-serialization-migration.md) per-type checklist.

### Summary

8 findings: 0 critical, 1 high, 7 medium.

77 types across the ecosystem conform to the deprecated `Binary.ASCII.Serializable` protocol. The replacement infrastructure (`Parseable`, `Serializable`, `Serializer.Protocol`) is operational at L1. Phase 1 (integers) is done at L1 but the redundant L3 conformances remain. 22 deprecation warnings in swift-ascii: 4 from redundant conformances (deletable), 18 from protocol infrastructure (deprecation cascade). Three Phase 0 convenience extensions needed before Phases 2-7 can proceed at scale.

## Path Type Compliance — 2026-04-16

### Scope

- **Target**: swift-primitives, swift-standards (swift-iso-9945), swift-foundations (ecosystem-wide); also swift-microsoft (new superrepo since 2026-03-31)
- **Principle**: [string-path-type-inventory-file-system.md](string-path-type-inventory-file-system.md) v3.0 — "APIs that semantically operate on file system paths should accept/return path types. `Swift.String` should appear only at display boundaries and at explicit conversion points."
- **Files**: Sources/ and Tests/ across all superrepos
- **Subject**: `Swift.String` used where `Kernel.Path`, `Path_Primitives.Path`, `Paths.Path`, or `Path.View` is semantically correct
- **Re-audit basis**: Replaces 2026-03-31 section per [AUDIT-005]. Significant ecosystem restructuring landed 2026-04-09 through 2026-04-15: atomic-write code relocated from `swift-kernel` to `swift-file-system`; `swift-iso-9945` decomposed from a single "ISO 9945 Kernel" target into ~16 sub-targets; Windows.Loader extracted to new `swift-microsoft` superrepo; audit infrastructure moved from `Research/` to `Audits/`.

### Type Hierarchy Reference

```
Layer 1 (Primitives)
  Path_Primitives.Path           (~Copyable, platform-encoded, owns memory)
  Path_Primitives.Path.View      (~Copyable, ~Escapable, borrowed view)
  Path_Primitives.Path.Protocol  (decomposition algebra: parent/component/appending) ← NEW (2026-04-07)
  Kernel.Path = Tagged<Kernel, Path_Primitives.Path>
  Kernel.Path.View               (non-escapable borrowed view)

Layer 3 (Foundations)
  Paths.Path                     (Copyable, Sendable, validated, user-facing)
  Paths.Path.View                (~Copyable, ~Escapable, borrowed)
  Paths.Path.Component           (validated single component)
  File.Path = Paths.Path         (typealias in swift-file-system)
```

**Conversion boundary**: `Kernel.Path.scope(_:)` bridges `Swift.String` → scoped `Kernel.Path.View` for syscall use. Code that calls `.scope()` internally is evidence that the parameter should have been typed at the API boundary instead.

### Progress Since 2026-03-31

| Phase | Status | Evidence |
|-------|--------|----------|
| **Phase 4a — L1 decomposition (POSIX)** | **COMPLETE** | `swift-path-primitives/Sources/Path Primitives/Path.Protocol.swift` (commit `a96dddf`, 2026-04-07). POSIX conformance at `swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.Path.View+Path.Protocol.swift` (commit `a90491b`, 2026-04-07; relocated to `Kernel File` sub-target during target decomposition). `Path.init(_ span: Span<Char>)` exists at L1. |
| **Phase 4a — L1 decomposition (Windows)** | **PENDING** | No `Path.View+Path.Protocol` conformance file in `swift-windows-primitives` or any Windows L1 location. |
| **Phase 4b — Paths.Path delegation** | **NOT STARTED** | `swift-paths/Sources/Paths/Path.Navigation.swift` last touched 2026-03-04; still uses `string.lastIndex(of: "/")` and String concatenation. Package.swift gained no new dependency. Architectural decision discussion (2026-04-08): protocol delegation rejected as too heavy (would pull 6 transitive deps); agreed approach is direct `[Char]` byte scanning at L3 — yet to be implemented. |
| **Phase 4c — Write pipeline migration** | **NOT STARTED** (file relocated only) | Atomic-write code relocated 2026-04-09 from `swift-kernel/Sources/Kernel File/Kernel.File.Write+Shared.swift` to `swift-file-system/Sources/File System Core/File.System.Write+Shared.swift`. The String pipeline is **byte-for-byte intact** — `resolvePaths`, `posixParentDirectory`, `windowsParentDirectory`, `fileName(of:)`, `normalizeWindowsPath`, `fileExists`, `atomicRename`, `syncDirectory` all still take and return `Swift.String`. |
| **Phase 1 — POSIX Glob (directory parameter)** | **RESOLVED** | `swift-posix/Sources/POSIX Kernel Glob/Kernel.Glob+Match.swift:34` — `match(pattern:in directory:)` now `borrowing Kernel.Path.View`. |
| **Phase 1 — POSIX Glob (callback yield)** | **OPEN** | Body callback still `(Swift.String) -> Void`. |
| **Phase 1 — Windows Glob** | **OPEN** | `Windows.Kernel.Glob.Match.swift` String-typed end to end. |
| **Phase 2 — Windows.Loader** | **OPEN (relocated)** | Moved to `swift-microsoft/swift-windows-standard/Sources/Windows Loader Standard/Windows.Loader.Library.swift`. Still `open(path: String)`. |
| **Phase 3 — Test.Reporter, Source.Cache** | **OPEN** | Test.Reporter relocated to `swift-tests/Sources/Tests Reporter/`; signatures unchanged. Source.Cache file unchanged. |
| **Phase 5 — Test helpers** | **OPEN** | All test helpers from #32–58 still String-typed. |
| **Phase 6 — Error types** | **DEFERRED** (carried) | `File.System.Write.Atomic.Error` (relocated, was `Kernel.File.Write.Atomic.Error`); deferred per original audit pending Phase 4c. |

### Per-Package Triage (Refreshed)

| Superrepo | Package | Source OPEN | Test OPEN | Resolved/Partial | Notes |
|-----------|---------|-------------|-----------|------------------|-------|
| swift-primitives | swift-path-primitives | 0 | 0 | n/a | Phase 4a L1 decomposition shipped here |
| swift-microsoft | swift-windows-standard | 2 | 0 | 0 | Windows.Loader relocated from swift-windows-primitives |
| swift-standards | swift-iso-9945 | 0 | 15 | n/a | Test helpers unchanged. Phase 4a POSIX conformance lives here. |
| swift-foundations | swift-file-system | 10 (relocated) | 1 + relocated | 0 | Atomic-write code relocated from swift-kernel; pipeline intact |
| swift-foundations | swift-kernel | 0 | 7 | 10 (relocated) | Source findings #15–24 moved to swift-file-system |
| swift-foundations | swift-posix | 1 (callback yield) | 4 | 1 (directory parameter) | Phase 1 partial |
| swift-foundations | swift-windows | 2 | 1 | 0 | Glob unchanged |
| swift-foundations | swift-tests | 2 | 0 | 0 | Reporters relocated, signatures unchanged |
| swift-foundations | swift-source | 4 | 0 | 0 | Source.Cache unchanged |
| swift-foundations | swift-paths | 0 | 0 | 0 | Phase 4b not started |
| **Total** | | **21 OPEN** | **27 OPEN + 10 relocated-OPEN** | **2 RESOLVED/PARTIAL** | **49 OPEN + 7 DEFERRED carried** |

### Findings — Sources: Public API (Refreshed)

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| 1 | HIGH | `swift-microsoft/swift-windows-standard/Sources/Windows Loader Standard/Windows.Loader.Library.swift` | `open(path: String)` — DLL path as bare String. `Windows.Kernel.File.Open` already uses `borrowing Kernel.Path`. | OPEN (relocated from swift-windows-primitives) |
| 2 | HIGH | (same file as #1) | `open(path: String, flags: DWORD)` — flags variant. | OPEN (relocated) |
| 3 | HIGH | `swift-posix/Sources/POSIX Kernel Glob/Kernel.Glob+Match.swift:34` | `match(pattern:in directory:)` — directory parameter | RESOLVED 2026-04-13 — now `borrowing Kernel.Path.View` |
| 4 | HIGH | `swift-posix/Sources/POSIX Kernel Glob/Kernel.Glob+Match.swift:36` | `body: (Swift.String) -> Void` — callback still yields String | OPEN — callback yield not migrated |
| 5 | HIGH | `swift-posix/Sources/POSIX Kernel Glob/Kernel.Glob+Match.swift:83` | Multi-pattern variant — directory parameter | RESOLVED 2026-04-13 — now `borrowing Kernel.Path.View` |
| 6 | HIGH | `swift-posix/Sources/POSIX Kernel Glob/Kernel.Glob+Match.swift:85` | Multi-pattern body callback `(Swift.String) -> Void` | OPEN |
| 7 | HIGH | `swift-windows/Sources/Windows Kernel/Windows.Kernel.Glob.Match.swift:33` | Windows Glob `match(in directory: Swift.String)` | OPEN |
| 8 | HIGH | `swift-windows/Sources/Windows Kernel/Windows.Kernel.Glob.Match.swift:35` | Windows Glob `-> [Swift.String]` | OPEN |
| 9 | MEDIUM | `swift-tests/Sources/Tests Reporter/Test.Reporter.JSON.swift:28` | `json(to path: Swift.String?)` | OPEN (file relocated from `Tests/`) |
| 10 | MEDIUM | `swift-tests/Sources/Tests Reporter/Test.Reporter.Structured.swift:21` | `structured(to path: Swift.String)` | OPEN (file relocated) |
| 11 | MEDIUM | `swift-source/Sources/Source/Source.Cache.swift:36` | `_loaded: [Swift.String: [UInt8]]` | OPEN |
| 12 | MEDIUM | `swift-source/Sources/Source/Source.Cache.swift:54` | `load(contentsOf path: Swift.String)` | OPEN |
| 13 | MEDIUM | `swift-source/Sources/Source/Source.Cache.swift:72` | `contains(path: Swift.String)` | OPEN |
| 14 | MEDIUM | `swift-source/Sources/Source/Source.Cache.swift:81` | `remove(path: Swift.String)` | OPEN |

### Findings — Sources: Internal Implementation (Refreshed)

**Relocated 2026-04-09** from `swift-kernel/Sources/Kernel File/Kernel.File.Write+Shared.swift` to `swift-file-system/Sources/File System Core/File.System.Write+Shared.swift`. The String pipeline is byte-for-byte intact — only the namespace changed (`Kernel.File.Write` → `File.System.Write`). All findings remain OPEN.

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| 15 | MEDIUM | `swift-file-system/Sources/File System Core/File.System.Write+Shared.swift:17–19` | `resolvePaths(_ pathString: Swift.String) -> (resolved: Swift.String, parent: Swift.String)` | OPEN (relocated) |
| 16 | MEDIUM | `:31` | `normalizeWindowsPath(_ path: Swift.String) -> Swift.String` | OPEN (relocated) |
| 17 | MEDIUM | `:47` | `windowsParentDirectory(of path: Swift.String) -> Swift.String` | OPEN (relocated) |
| 18 | MEDIUM | `:63` | `fileName(of path: Swift.String) -> Swift.String` (Windows) | OPEN (relocated) |
| 19 | MEDIUM | `:70` | `posixParentDirectory(of path: Swift.String) -> Swift.String` | OPEN (relocated) |
| 20 | MEDIUM | `:82` | `fileName(of path: Swift.String) -> Swift.String` (POSIX) | OPEN (relocated) |
| 21 | MEDIUM | `:94` | `fileExists(_ pathString: Swift.String) -> Bool` — wraps `Kernel.Path.scope` | OPEN (relocated) |
| 22 | MEDIUM | `File.System.Write+Shared.swift` (further in file) | `atomicRename(from source: Swift.String, to dest: Swift.String)` | OPEN (relocated) |
| 23 | MEDIUM | (same file) | `atomicRenameNoClobber(from source: Swift.String, to dest: Swift.String)` | OPEN (relocated) |
| 24 | MEDIUM | (same file) | `syncDirectory(_ pathString: Swift.String)` — wraps `Kernel.Path.scope` | OPEN (relocated) |

### Findings — Sources: Error Types (Refreshed — DEFERRED carried forward per [AUDIT-005])

Relocated 2026-04-09 to `swift-file-system/Sources/File System Core/File.System.Write.Atomic.Error.swift`. All path fields still `Swift.String`. Per original audit, deferred pending Phase 4c.

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| 25 | LOW | `swift-file-system/Sources/File System Core/File.System.Write.Atomic.Error.swift` | `parentVerificationFailed(path: Swift.String, ...)` | DEFERRED — resolve with Phase 4c |
| 26 | LOW | (same file) | `destinationStatFailed(path: Swift.String, ...)` | DEFERRED — same |
| 27 | LOW | (same file) | `tempFileCreationFailed(directory: Swift.String, ...)` | DEFERRED — same |
| 28 | LOW | (same file) | `renameFailed(from: Swift.String, to: Swift.String, ...)` | DEFERRED — same |
| 29 | LOW | (same file) | `destinationExists(path: Swift.String)` | DEFERRED — same |
| 30 | LOW | (same file) | `directorySyncFailed(path: Swift.String, ...)` | DEFERRED — same |
| 31 | LOW | (same file) | `directorySyncFailedAfterCommit(path: Swift.String, ...)` | DEFERRED — same |

### Findings — Tests: swift-iso-9945 (Layer 2) (Refreshed)

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| 32 | HIGH | `swift-iso-9945/Tests/Support/Kernel.IO.Test.Helpers.swift:40` | `makeTempPath(prefix:) -> Swift.String` | OPEN |
| 33 | HIGH | `swift-iso-9945/Tests/Support/Kernel.IO.Test.Helpers.swift:45` | `open(at path: Swift.String)` | OPEN |
| 34 | HIGH | `swift-iso-9945/Tests/Support/Kernel.IO.Test.Helpers.swift:65` | `cleanup(path: Swift.String)` | OPEN |
| 35 | HIGH | `swift-iso-9945/Tests/Support/Kernel.Temporary.swift:39` | `directory: Swift.String` | OPEN |
| 36 | HIGH | `swift-iso-9945/Tests/Support/Kernel.Temporary.swift:60` | `filePath(prefix:) -> Swift.String` | OPEN |
| 37 | MEDIUM | `swift-iso-9945/Tests/ISO 9945 Kernel Tests/ISO 9945.Kernel.File.Handle Tests.swift` | `cleanup(path: Swift.String)` test-local duplicate | OPEN |
| 38 | MEDIUM | `swift-iso-9945/Tests/ISO 9945 Kernel Tests/ISO 9945.Kernel.File.Clone Tests.swift` | `createTempFileWithContent(prefix:content:) -> Swift.String` | OPEN |
| 39 | MEDIUM | (same file) | `readFileContent(_ path: Swift.String) -> Swift.String?` | OPEN |
| 40 | MEDIUM | (same file) | `cleanup(_ path: Swift.String)` | OPEN |
| 41 | MEDIUM | `swift-iso-9945/Tests/ISO 9945 Kernel Tests/ISO 9945.Kernel.Lock.Integration Tests.swift` | `isExecutable(_ path: Swift.String)` | OPEN |
| 42 | MEDIUM | (same file) | `spawn(lockingFile filePath: Swift.String, ...)` | OPEN |
| 43 | MEDIUM | (same file) | `makeLockTestFile(prefix:) -> Swift.String` | OPEN |
| 44 | MEDIUM | `swift-iso-9945/Tests/ISO 9945 Kernel Tests/ISO 9945.Kernel.Process.Execute Tests.swift` | `findTruePath() -> Swift.String` | OPEN |
| 45 | MEDIUM | (Lock.Integration Tests) | `isExecutable(_ path: Swift.String)` (duplicate of #41 — TestHelper.swift no longer present at original path) | OPEN |
| 46 | MEDIUM | `swift-iso-9945/Tests/ISO 9945 Kernel Tests/ISO 9945.Kernel.File.Open Tests.swift` | Test bodies threading String paths via `KernelIOTest.makeTempPath(...)` | OPEN |

### Findings — Tests: swift-foundations (Layer 3) (Refreshed)

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| 47 | MEDIUM | `swift-kernel/Tests/Support/Kernel.Temporary.swift:39` | `directory: Swift.String` — duplicates iso-9945 pattern | OPEN |
| 48 | MEDIUM | `swift-kernel/Tests/Support/Kernel.Temporary.swift:60` | `filePath(prefix:) -> Swift.String` | OPEN |
| 49 | MEDIUM | `swift-kernel/Tests/Kernel Tests/Kernel.File.Open Tests.swift:27` | `makeTempFile(prefix:content:) -> Swift.String` | OPEN |
| 50 | MEDIUM | `swift-kernel/Tests/Kernel Tests/Kernel.File.Open Tests.swift:41` | `removeTempFile(_ path: Swift.String)` | OPEN |
| 51 | MEDIUM | `swift-kernel/Tests/Kernel Tests/Kernel.File.Clone Tests.swift:28` | `createTempFile(prefix:content:) -> Swift.String` | OPEN |
| 52 | MEDIUM | `swift-kernel/Tests/Kernel Tests/Kernel.File.Clone Tests.swift:42` | `readFileContent(_ path: Swift.String) -> Swift.String?` | OPEN |
| 53 | MEDIUM | `swift-kernel/Tests/Kernel Tests/Kernel.File.Clone Tests.swift:55` | `cleanup(_ path: Swift.String)` | OPEN |
| 54 | MEDIUM | `swift-file-system/Tests/File System Core Tests/File.System Tests.swift:35` | `createTempPath() -> Swift.String` | OPEN |
| 55 | MEDIUM | `swift-file-system/Tests/File System Core Tests/File.System Tests.swift:39` | `cleanup(_ path: Swift.String)` | OPEN |
| 56 | MEDIUM | `swift-file-system/Tests/Support/File.Directory.Temporary.swift:39` | `directory: Swift.String` | OPEN |
| 57 | MEDIUM | `swift-posix/Tests/POSIX Kernel Tests/POSIX.Kernel.Glob Tests.swift:38+` | `removeDirectoryRecursively`, `parentDirectory(of:)`, `withTestDirectory`, `createTestFiles(in:)` | OPEN |
| 58 | MEDIUM | `swift-windows/Tests/Windows Kernel Tests/Windows.Kernel.Glob Tests.swift` | Windows mirror of #57 | OPEN |

### False Positives / Legitimate String Usage (Unchanged from 2026-03-31)

8 entries remain valid: `Source.File.filePath`, `Source.Location.filePath`, `Kernel.Glob.Error` path fields, `Kernel.Glob.Pattern.init(_ pattern: String)`, `Test.Snapshot.Result` path fields, `Test.Snapshot.Diff.Result.StructuralOperation`, `Darwin.Loader.Image.pathString(at:)`, `Kernel.File.Write.randomToken`/`hexEncode`.

### Systemic Patterns (Refreshed)

1. **`.scope()` as symptom** (still active): The relocated `File.System.Write+Shared.swift` wraps `Kernel.Path.scope()` inside `fileExists`, `atomicRename`, `syncDirectory`.

2. **Test helper duplication** (still active): `Kernel.Temporary` appears in three locations (swift-iso-9945, swift-kernel, swift-file-system) with identical String-based signatures.

3. **Glob pipeline** (partially resolved): POSIX glob directory parameter now `borrowing Kernel.Path.View` (2026-04-13). Callback yield and Windows glob still String.

4. **Error type coupling** (still active): `File.System.Write.Atomic.Error` (relocated from `Kernel.File.Write.Atomic.Error`) stores paths as `Swift.String`.

5. **Layer-correct types** (still active): L2 → `Kernel.Path`/`Kernel.Path.View`; L3 → `Paths.Path`/`File.Path` at public boundaries.

6. **Missing L1 decomposition** (**PARTIALLY RESOLVED**): `Path.Protocol` (L1) now provides `parent`/`component`/`appending`. POSIX conformance ships via `swift-iso-9945`. Windows conformance pending. Consumers have not yet adopted.

### Architectural Decisions (Preserved + Updated)

**Decision 1 — Path decomposition at L1** (2026-03-31, IMPLEMENTED for POSIX):

`Path.Protocol` declares the algebra (`parent`/`component`/`appending`); platform packages provide conformances. POSIX → `swift-iso-9945` (`ISO 9945 Kernel File` sub-target); Windows → `swift-windows-primitives` (pending).

**Decision 2 — Phase 4b approach revision** (2026-04-08):

Original plan: `Paths.Path` delegates to L1 by importing `swift-iso-9945`. Rejected — pulls 6 transitive deps for trivial separator scanning. **Approved approach**: `Paths.Path` operates directly on its `[Char]` storage with byte scanning. Same algebra, different representation, no protocol indirection.

**Decision 3 — Phase 4c uses Paths.Path, not Kernel.Path.View** (2026-04-16):

Atomic-write code relocated to L3 `swift-file-system` (2026-04-09). The original rationale ("swift-kernel must not depend on swift-paths") is moot at L3. `File.System.Write` already imports `swift-paths` (defines `File.Path = Paths.Path`). **Decided**: Phase 4c internal pipeline uses `Paths.Path` throughout. Decomposition via `.parent`/`.appending` (Phase 4b byte scanning). Syscall access via `.kernelPath` (zero-alloc on POSIX). This eliminates the need to import the L2 POSIX conformance for `Kernel.Path.View.parent`. **Consequence**: Phase 4b must land before Phase 4c.

**Layer responsibilities** (updated for atomic-write relocation):

| Layer | Package | Responsibility | Path Type |
|-------|---------|---------------|-----------|
| L1 | path-primitives | Decomposition algebra (`Path.Protocol`) + construction | `Path` (~Copyable), `Path.View` (~Escapable) |
| L2 | swift-iso-9945 | POSIX conformance (`0x2F` scanning) | `Path.View` conforms `Path.Protocol` |
| L3 | swift-file-system | Atomic/streaming write (**relocated** from swift-kernel 2026-04-09) | Currently `Swift.String` pipeline |
| L3 | swift-paths | Copyable user-facing wrapper | Currently String-based decomposition |

### Remaining Tasks (Prioritized)

**P0 — Architectural keystone** (unblocks Windows consumers)
1. **Phase 4a Windows conformance** — `swift-windows-primitives/.../Windows.Kernel.Path.View+Path.Protocol.swift`. Dual separator (`/` and `\`), drive letters, UNC.

**P1 — Highest impact, lowest risk**
2. **Phase 4b — Paths.Path direct byte scanning** (~50 lines in `Path.Navigation.swift`). No new deps. Eliminates 3 allocations + UTF-8 round-trip per `parent`/`appending` call. Scope: `parent`, `appending(Component)`, `appending(Path)`, `appending(String)`. Defer `lastComponent`/`components` (semantic mismatch with L1).

**P2 — Pipeline elimination**
3. **Phase 4c — File.System.Write pipeline migration**. Replace `Swift.String` in `File.System.Write+Shared.swift` with `Paths.Path`. Delete `resolvePaths`, `*ParentDirectory`, `fileName(of:)`, `normalizeWindowsPath`. Use `.parent`/`.appending` for decomposition, `.kernelPath` at syscall boundaries. **Depends on P1 (Phase 4b).**

**P3 — Public API typed boundaries**
4. **Phase 1 — POSIX Glob callback yield**: `(Swift.String) -> Void` → typed path yield.
5. **Phase 1 — Windows Glob**: mirror POSIX migration (after P0).
6. **Phase 2 — Windows.Loader**: `open(path: borrowing Kernel.Path)`. File at `swift-microsoft` superrepo.
7. **Phase 3 — Test.Reporter, Source.Cache**: typed `File.Path` parameters.

**P4 — Test infrastructure**
8. **Phase 5 — Test helper unification**: collapse three `Kernel.Temporary` copies.

**P5 — Cleanup (depends on P2)**
9. **Phase 6 — Error type path fields** (carried DEFERRED).

### Summary

58 original findings. **Current status**: 2 RESOLVED (findings #3, #5 — POSIX glob directory parameter). 49 OPEN. 7 DEFERRED carried forward. 10 findings relocated from swift-kernel to swift-file-system (pipeline unchanged).

**Progress since 2026-03-31**: Phase 4a (POSIX) complete — L1 `Path.Protocol` shipped. POSIX glob directory parameter migrated. Everything else unstarted; swift-kernel → swift-file-system relocation moved the String pipeline without altering it.

**Key architectural decision**: `File.System.Write` (now L3) will consume `Paths.Path` directly for Phase 4c, using `.kernelPath` for zero-alloc syscall access. Phase 4b (byte scanning in `Paths.Path`) must land first.

<!-- END Path Type Compliance -->

## Pre-Publication — 2026-04-02

### Scope

- **Target**: Priority 1 packages (unpushed commits) from the GitHub organization migration plan
- **Skills**: code-surface, implementation, platform, modularization, documentation
- **Requirement IDs**: [API-NAME-001–004a], [API-ERR-001–005], [API-IMPL-003–011], [IMPL-002–060], [PLAT-ARCH-001–005], [MOD-001–014], [DOC-001–005]
- **Packages**: 7 (swift-rfc-4648, swift-rfc-9110, swift-iso-8601, swift-iso-32000, swift-iso-3166, swift-w3c-css, swift-base62-primitives)
- **Purpose**: Verify code quality before making all standards-body and primitives repos public

### Per-Package Triage

| Package | Findings | Worst | Blocker Summary |
|---------|----------|-------|-----------------|
| swift-rfc-4648 | 23 | HIGH | Multi-type files (6), compound convenience methods on String/Data/Collection extensions |
| swift-rfc-9110 | 65 (45 after spec-mirror exception) | CRITICAL | 5 compound type names, multi-type files (8), 20 bare-throws Codable (deferred), avoidable compound methods (~8) |
| swift-iso-8601 | 59 | CRITICAL | 4 top-level `__`-prefixed compound error types, multi-type files (17), methods in type bodies (5), compound property names (7) |
| swift-iso-32000 | 87 | CRITICAL | Foundation import (1), ContentStream compound methods (~37), multi-type files (~12), pervasive `.rawValue` extraction (~40 sites) |
| swift-iso-3166 | 22 | CRITICAL | Multi-type error file (4 types in 1 file), validation logic in type bodies (3), extension separation (6) |
| swift-w3c-css | 10 (systemic) | CRITICAL | **All ~724 types** use flat compound names (`BackgroundColor` not `CSS.Background.Color`). Entire package requires restructuring. |
| swift-base62-primitives | 11 | CRITICAL | Multi-type file (4 types in 1 file), methods in type bodies (4), compound method names (3) |

**Aggregate: 277 findings across 7 packages. 45 CRITICAL, 122 HIGH, 76 MEDIUM, 27 LOW, 7 informational.**

### Systemic Patterns

#### 1. [API-IMPL-005] One Type Per File — ALL 7 PACKAGES

The most pervasive violation. Every package bundles multiple type declarations into single files. Common patterns:
- Parser + Formatter + Output in one file (swift-iso-8601)
- Namespace enum + 4–15 concrete types in one file (swift-iso-32000 `7.3 Objects.swift`)
- Multiple error types in one file (swift-iso-3166, swift-iso-8601)
- Struct + Iterator in one file (swift-rfc-9110)

**Recommendation**: This is the highest-volume fix. Consider a script-assisted split: for each file with >1 type declaration, extract each type into `{Namespace}.{Type}.swift`.

#### 2. [API-NAME-002] Compound Identifiers — 5/7 PACKAGES

Compound method/property names are widespread, with two distinct categories:

**Spec-mirroring compounds** (EXCEPTED): HTTP status names (`notFound`, `badRequest`), header field names (`contentType`, `userAgent`), CSS property names. These mirror specification terminology. **Decision (2026-04-02): spec-mirroring static constants, enum cases, and type names that directly encode spec-defined terms are exempt from [API-NAME-002].** This exception covers identifiers whose compound form IS the specification's terminology.

**Avoidable compounds**: `saveGraphicsState()`, `setStrokeColorRGB()`, `headerValue`, `base64URLEncodedString()`, `formatHeader()`. These are NOT spec terms — they are implementation choices. They should use nested accessor patterns (`graphicsState.save()`, `stroke.color.rgb()`, `header.value`, etc.).

**Recommendation**: Fix avoidable compounds. Spec-mirroring compounds are now excepted.

#### 3. [API-IMPL-008] Minimal Type Body — 6/7 PACKAGES

Computed properties, validation logic, methods, and protocol conformance implementations inside type bodies instead of extensions. The most common violations:
- Computed properties (`isZero`, `description`, `headerValue`) in type body
- Init with validation logic (guard/throw) in type body
- `Equatable`/`Hashable` implementations in type body

**Recommendation**: Mechanical fix — move everything except stored properties and the canonical init into extensions.

#### 4. [API-ERR-001] Codable Bare Throws — SYSTEMIC (4 PACKAGES)

Every package with `Codable` conformance has bare `throws` on `init(from:)` and `encode(to:)`. This is a protocol-imposed limitation: Swift's `Codable` protocol declarations use untyped `throws`, and conformances cannot narrow to typed throws.

**Recommendation**: Mark as DEFERRED — known protocol limitation. Not fixable without custom coding patterns or Swift language changes.

#### 5. [API-NAME-001] Compound Type Names — 3 PACKAGES (1 SYSTEMIC)

- **swift-w3c-css**: ALL ~724 types use flat compound names. Entire package requires namespace restructuring.
- **swift-rfc-9110**: 5 types (`ContentNegotiation`, `ContentEncoding`, `ContentLanguage`, `EntityTag`, `MediaType`).
- **swift-iso-8601**: 5 top-level `__`-prefixed error types violate both naming and nesting conventions.

**Recommendation**: swift-w3c-css needs a dedicated restructuring pass. swift-rfc-9110 and swift-iso-8601 are localized fixes.

#### 6. [PRIM-FOUND-001] Foundation Import — 1 PACKAGE

swift-iso-32000 imports Foundation in `12.8 Digital signatures.swift`. Foundation is forbidden in L2 Standards packages.

**Recommendation**: Fix immediately — single file.

### Known Deviations

| Pattern | Packages | Status | Reason |
|---------|----------|--------|--------|
| Codable bare `throws` | swift-rfc-9110, swift-iso-8601, swift-iso-3166, swift-iso-32000 | DEFERRED | Protocol-imposed: `Codable` declares `throws`, not `throws(E)` |
| HTTP status/header compound names | swift-rfc-9110 | EXCEPTED | Spec-mirroring static constants are exempt from [API-NAME-002] per 2026-04-02 decision |
| Relative path dependencies in Package.swift | All 7 packages | DEFERRED | Required for local development; publication uses versioned URLs via subtree extraction |
| Platform minimum `.v26` | All 7 packages | DEFERRED | Matches current development toolchain; adjustable at publication time |

### Publication Blockers (Must Fix)

| Priority | Issue | Packages | Estimated Scope |
|----------|-------|----------|-----------------|
| P0 | Foundation import in L2 | swift-iso-32000 | 1 file |
| P0 | Top-level `__` compound error types | swift-iso-8601 | 4 types → nest as `.Parse.Error` |
| P1 | Compound type names | swift-rfc-9110 (5 types), swift-w3c-css (724 types) | swift-rfc-9110: localized; swift-w3c-css: full restructure |
| P1 | One-type-per-file | All 7 packages | ~80 files need splitting |
| P2 | Methods in type bodies | 6/7 packages | ~60 types need method extraction |
| P2 | Compound method/property names (avoidable) | 5/7 packages | ~50 identifiers |
| P3 | Missing doc comments | All 7 packages | ~70 declarations |

### Verdict

**Not ready for publication.** The P0 and P1 blockers must be resolved first. swift-w3c-css requires the most work (full namespace restructuring). The remaining 6 packages have localized issues that can be fixed incrementally. Recommend:

1. Fix P0 items (Foundation import, `__` error types) — immediate
2. Fix swift-rfc-9110 compound type names — localized rename
3. Make a decision on spec-mirroring compound identifiers (HTTP status/header names)
4. Script-assisted one-type-per-file split across all packages
5. Defer swift-w3c-css restructuring — flag as blocked on namespace design decision
6. After P0–P1 clean, proceed to Priority 2 packages (swift-file-system transitive closure)

### Summary

277 findings across 7 packages: 45 critical, 122 high, 76 medium, 27 low.
Dominant patterns: multi-type files (all 7), compound identifiers (5/7), methods in type bodies (6/7), Codable bare throws (systemic).

---

## Corpus Meta-Analysis — 2026-04-16

### Scope

- **Target**: Research corpus, experiments, reflections, blog pipeline, and index files across swift-institute, swift-primitives, swift-standards, swift-foundations, rule-law, swift-nl-wetgever
- **Skill**: corpus-meta-analysis — [META-001]..[META-026]
- **Basis**: Re-audit of the 30 action items (P0–P3) from the 2026-04-08 full corpus sweep, verified against current ecosystem state after 8 days of heavy activity (reflection-processing pass on 2026-04-11, audit relocation to `Audits/` on 2026-04-13, Swift 6.3 revalidation, pre-alpha readiness passes).
- **Work artifact**: `swift-institute/Research/_work/meta-analysis-audit-2026-04-16.md` (detailed item-by-item evidence)

### Resolution Since 2026-04-08

| Priority | Items | Resolved | Partial | Open |
|----------|-------|----------|---------|------|
| P0 (status corrections) | 15 | 9 | 0 | 6 |
| P1 (triage decisions) | 11 | 11 | 0 | 0 |
| P2 (corpus maintenance) | 4 | 1 | 0 | 3 |
| P3 (strategic) | 3 | 0 | 0 | 3 |
| **Total** | **33** | **21** | **0** | **12** |

Resolution rate: **64%** of action items resolved in 8 days. Biggest wins: reflections backlog drained from 46 pending to 6 (40 processed + 7 research stubs per commit d21c397); all 6 experiment-triage items carry explicit Result/Revalidation lines; swift-foundations/Experiments/_index.md created; `soort-of-aanduiding` frontmatter/body mismatch resolved.

### Findings (Remaining Tasks)

Only OPEN findings are listed. RESOLVED items are tracked in the work artifact and omitted here per [AUDIT-005].

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | MEDIUM | [META-003] | swift-institute/Research/benchmark-implementation-conventions.md | Recommendations absorbed into `benchmark` skill ([BENCH-001..009]); still carries `status: RECOMMENDATION`. Should be SUPERSEDED. | RESOLVED 2026-04-16 — status: SUPERSEDED, superseded_by benchmark skill [BENCH-001..009] |
| 2 | MEDIUM | [META-003] | swift-institute/Research/agent-handoff-patterns.md | Recommendations absorbed into `handoff` skill ([HANDOFF-*]); still `status: RECOMMENDATION`. | RESOLVED 2026-04-16 — status: SUPERSEDED, superseded_by handoff skill [HANDOFF-001..016] |
| 3 | MEDIUM | [META-003] | swift-institute/Research/generalized-audit-skill-design.md | Recommendations absorbed into `audit` skill ([AUDIT-001..016]); still `status: RECOMMENDATION`. | RESOLVED 2026-04-16 — status: SUPERSEDED, superseded_by audit skill [AUDIT-001..019] (skill grew to 019) |
| 4 | MEDIUM | [META-003] | swift-primitives/Research/intra-package-modularization-patterns.md | 13 patterns absorbed into `modularization` skill ([MOD-001..014]); still `status: RECOMMENDATION`. | RESOLVED 2026-04-16 — status: SUPERSEDED, superseded_by modularization skill [MOD-001..016] (skill grew to 016) |
| 5 | MEDIUM | [META-003] | swift-primitives/Research/modularization-theoretical-foundations.md | Literature foundations absorbed into `modularization` skill rationale; still `status: RECOMMENDATION`. | RESOLVED 2026-04-16 — status: SUPERSEDED, superseded_by modularization skill rationale |
| 6 | MEDIUM | [META-003] | swift-primitives/Research/bounded-index-precondition-elimination.md | Core recommendations absorbed into `implementation` skill ([IMPL-050..053]); still `status: RECOMMENDATION`. | RESOLVED 2026-04-16 — status: SUPERSEDED, superseded_by implementation skill [IMPL-050..053] |
| 7 | MEDIUM | [META-002] | rule-law/Research/aandeelhoudersregister-comparative-analysis.md | No YAML frontmatter `status:` field. Body indicates RECOMMENDATION or DECISION. | RESOLVED 2026-04-16 — frontmatter added: status: RECOMMENDATION (priority action items + do-not-bring-forward lists indicate recommendation, not yet decided) |
| 8 | MEDIUM | [META-002] | swift-nl-wetgever/Research/conclusion-types-converged-plan.md | No frontmatter `status:` field. Title ("Converged Plan") suggests DECISION. | RESOLVED 2026-04-16 — frontmatter added: status: DECISION; companion field points at the discussion transcript |
| 9 | MEDIUM | [META-002] | swift-nl-wetgever/Research/conclusion-types-discussion-transcript.md | No frontmatter `status:` field. Discussion reached convergence; classify as supporting material or DECISION. | RESOLVED 2026-04-16 — frontmatter added: status: INFO (transcript is supporting material; converged plan is the canonical decision artifact) |
| 10 | MEDIUM | [META-008] | swift-institute/Research/_index.md | 6 research docs missing from index: apple-http-api-proposal-patterns.md, apple-http-middleware-chain-isolation.md, apple-http-outputspan-writer-pattern.md, apple-http-withclient-scoped-pattern.md, claurst-analysis.md, claurst-rust-patterns.md. (Re-verify — may have been addressed during audit relocation.) | RESOLVED 2026-04-16 — re-verified, all 6 entries already present in index (added incidentally between 2026-04-08 and 2026-04-16) |
| 11 | MEDIUM | [META-008] | swift-institute/Experiments/_index.md | 6 experiments missing from index (2026-04-08): async-closure-noncopyable-escaping, async-let-typed-throws, callasfunction-noncopyable-consuming-sending, mutablespan-async-read, sending-vs-sendable-structured-concurrency, span-async-parameter. Re-verify. | RESOLVED 2026-04-16 — re-verified, all 6 entries already present in index |
| 12 | MEDIUM | [META-008] | swift-primitives/Research/_index.md | 2 research docs missing: linked-list-cursor-and-arena-backing-improvements.md, linked-list-theoretical-perfect.md. Re-verify. | RESOLVED 2026-04-16 — both entries added to index between kernel-atomic-memory-ordering and linux-io-uring-api-reference |
| 13 | MEDIUM | [META-008] | swift-primitives/Experiments/_index.md | 2 experiments missing: link-topology-element-free, sendable-noncopyable-conditional-conformance. Re-verify. | RESOLVED 2026-04-16 — both entries added to index after optional-take-sending-region-isolation |
| 14 | MEDIUM | [META-015] | swift-institute/Audits/audit.md → Memory Safety section | Audit finding #7 (13 swift-foundations packages missing `.strictMemorySafety()`) was RESOLVED per Phase 2 verification, but the Memory Safety section still marks it OPEN. Update the section's status. | RESOLVED 2026-04-16 — Memory Safety finding #7 marked RESOLVED in-section; summary updated |
| 15 | MEDIUM | [META-015] | swift-institute/Audits/audit.md → Variant Naming section | Findings #1–7 (7 types named "Fixed" should be "Bounded"): `Queue.Bounded.swift` now exists alongside `Queue.Fixed.swift`. Section does not reflect the partial rename in progress. | RESOLVED 2026-04-16 — Variant Naming section now carries a "Partial Progress" subsection documenting the Static/Bounded/Fixed tripartite evolution |
| 16 | MEDIUM | [META-015] | swift-institute/Research/swift-6.3-ecosystem-opportunities.md | Claim: "36 `_deinitWorkaround` sites pending #86652 verification". The related `value-generic-nested-type-bug` experiment is FIXED 6.2.4 per its Revalidation header. Back-propagate: verify whether some or all 36 sites can now be removed. | RESOLVED 2026-04-16 — bugs are distinct (value-generic nested types vs `@_rawLayout` deinit IR domination). #86652 still broken in 6.3 per `swift-6.3-revalidation-status.md`; 36 sites must remain. Re-evaluation note appended to doc. |
| 17 | MEDIUM | [META-015] | swift-institute/Research/feature-flags-assessment.md | CoroutineAccessors WAIT recommendation predates the `noncopyable-accessor-incompatibility` FIXED 6.2.4 result. Re-evaluate whether WAIT still applies. | RESOLVED 2026-04-16 — WAIT verdict is grounded in absence of SE proposal + `FUTURE` availability gate, both unaffected by the 6.2.4 ~Copyable accessor fix. CoroutineAccessors not listed as fixed in 6.3 revalidation status. Re-evaluation note appended to doc; verdict unchanged. |
| 18 | MEDIUM | [META-026] | swift-institute/Experiments/{consuming-iteration-pattern,noncopyable-access-patterns,foreach-consuming-accessor} | CLAIM-001..005 IDs are not globally unique — reused across experiments with different meanings (V01: "Iterator deinit cleanup"; V02/V03: "consuming can consume original container"). Define a namespacing convention (e.g., `[CLAIM-EXP-NAME-001]`) or deprecate if unused. | OPEN |
| 19 | LOW | [META-012] | swift-institute/Blog/_index.md | 6 blog ideas captured 2026-01-23/24 are labeled "Stalled 80 days — needs writer assignment" (BLOG-IDEA-007, 010, 014, 024, 025, 026). Explicit labeling is acknowledgment but not triage. Decide: draft, demote to "Needs More Context", or archive. | OPEN |
| 20 | LOW | [META-018] | swift-institute/Research/discrete-scaling-morphisms.md | RECOMMENDATION for cross-domain scaling factor type design has no experimental validation of API ergonomics or type-checker behavior. Spawn experiment if recommendation will inform type infrastructure. | OPEN |
| 21 | LOW | [META-016] | swift-institute/Research/benchmark-*.md cluster | 6-document benchmark cluster is a consolidation candidate once `benchmark-inline-strategy.md` (IN_PROGRESS) resolves. Non-urgent. | OPEN |
| 22 | LOW | [AUDIT-002] | swift-institute/Audits/audit.md | Per updated [AUDIT-002], ecosystem-wide audits should be standalone files with descriptive slugs, not sections in `audit.md`. The 6 pre-existing sections + this section predate the convention change. Consider migrating ecosystem sweeps to standalone files, or treat this `audit.md` as the meta-repo's own superrepo audit file. | OPEN |

### Known Deviations

| Pattern | Items | Status | Reason |
|---------|-------|--------|--------|
| P1 triage status "stronger than recommended" | next-steps-parsers (→DECISION), developer-tool-package-architecture (→DECISION), primitives-public-api-graph-analysis (→RECOMMENDATION), knowledge-encoding (→RECOMMENDATION) | ACCEPTED | Three IN_PROGRESS docs were promoted to DECISION/RECOMMENDATION rather than the recommended DEFERRED. This is a stronger, not weaker, outcome — finding recommendation was treated as a minimum, not a ceiling. |
| `document-infrastructure-ergonomic-audit.md` | Missing | DELETED 2026-04-14 | File removed in commit a774bac (321 lines). Item 5b from 2026-04-08 report closed by deletion. |
| No version tags in any superrepo | [META-025] | DEFERRED | Pre-alpha — first release not yet cut. Discovery coverage check N/A until first tag. |
| ASSUMP-* namespace unused | [META-026] | INFO | Namespace defined but has zero uses ecosystem-wide. Keep or formally deprecate on next sweep. |

### Phase 2 Resolution (2026-04-16, same-day)

17 of the 22 listed findings resolved later on 2026-04-16 per `HANDOFF-corpus-meta-analysis.md`:

| Block | Findings | Outcome |
|-------|----------|---------|
| Back-propagation of 6.2.4 fixes | 14, 15, 16, 17 | RESOLVED — Memory Safety #7 marked RESOLVED in-section, Variant Naming gained Partial Progress note, swift-6.3-ecosystem-opportunities + feature-flags-assessment got re-evaluation notes (verdicts unchanged) |
| Skill-absorption supersession | 1–6 | RESOLVED — 6 docs flipped to `status: SUPERSEDED` with `superseded_by:` pointing at the absorbing skill |
| Legal-domain frontmatter | 7–9 | RESOLVED — frontmatter blocks added (RECOMMENDATION / DECISION / INFO) |
| Index freshness | 10–13 | RESOLVED — findings 10, 11 already incidentally in index; findings 12, 13 added (4 new entries) |

5 findings remain OPEN by design (LOW priority, out of scope per handoff): 18 (CLAIM-* namespacing), 19 (BLOG-IDEA stalled triage), 20 (discrete-scaling-morphisms experiment), 21 (benchmark-* cluster consolidation candidate), 22 (ecosystem-wide audit placement migration).

### Summary

22 remaining findings: 0 critical, 0 high, 18 medium, 4 low.

Dominant patterns:
1. **Incomplete skill-absorption supersession** (6/22): 6 of 10 research documents whose recommendations were absorbed into skills still carry `status: RECOMMENDATION`. The "design" docs for skills (skill-creation, readme-skill, collaborative-llm, session-reflection) were correctly marked SUPERSEDED; process/architecture docs (benchmark, handoff, audit, modularization ×3, bounded-index) were not.
2. **Missing frontmatter on legal-domain docs** (3/22): 3 documents in rule-law/swift-nl-wetgever still lack `status:` frontmatter. The convention is less consistently enforced in legal corpus.
3. **Index freshness drift** (4/22): 16 total missing entries across 4 `_index.md` files flagged on 2026-04-08 — need re-verification after audit-relocation activity. Some may have been addressed incidentally.
4. **Unpropagated toolchain-fix consequences** (3/22 in [META-015]): Three bugs fixed in Swift 6.2.4 (accessor incompatibility, value-generic nested type, workaround sites) have corresponding Result updates on experiments but have not been back-propagated to the RECOMMENDATION documents that cited them as blockers.
5. **Ecosystem-wide audit placement** (1/22): Per updated [AUDIT-002], ecosystem-wide audits should be standalone descriptive-slug files, not sections in `audit.md`. This section and the 6 pre-existing sections predate the convention. Low-priority migration candidate.

**Verdict**: Corpus is in better shape than it was 8 days ago. The P1 triage layer is fully cleared, the reflections backlog is functionally drained (6 pending, all today's), and the experiment-result layer is fully consistent. Remaining work is largely mechanical: 6 status updates, 3 frontmatter additions, 4 index re-verifications, and 3 back-propagation passes. No CRITICAL or HIGH findings remain.

---

## Xylem Lessons — Cross-Package Assignment — 2026-04-16

### Scope

- **Assignment**: Apply parsing lessons from `compnerd/xylem` to the ecosystem's parser/lexer stack
- **Packages touched**: swift-lexer-primitives (L1), swift-text-primitives (L1), swift-parsers (L3), swift-lexer (L3)
- **Skills checked**: code-surface, implementation, memory-safety, existing-infrastructure
- **Provenance**: Comparative analysis of xylem's XML.Lexer vs our parser/lexer primitives (2026-04-08)

### Per-Package Triage

| Package | Findings | Worst Open | Status |
|---------|----------|-----------|--------|
| swift-lexer-primitives | 2 low (1 deferred, 1 cosmetic) | LOW | Functional — scanner operational, 25 tests pass |
| swift-lexer (foundation) | 0 | — | CLEAN — `Lexer.tokenize` entry point + 6 tests |
| swift-parsers | 0 open (5 resolved) | — | CLEAN — classification routed through `ASCII.Classification` |
| swift-text-primitives | 2 low (both deferred) | LOW | Functional — `Text.Location.Tracker` operational, 58 tests pass |

### Completed Lessons

| # | Lesson | Delivered | Key Commit |
|---|--------|-----------|-----------|
| 1 | Span-based `~Copyable, ~Escapable` scanner | `Lexer.Scanner` in swift-lexer-primitives | `be0dc0c` |
| 2 | `[IMPL-042]` Failure==Never specialization | Rule added to /implementation skill | N/A (skill update) |
| 3 | Route classification through `ASCII.Classification` | 6 swift-parsers files, net -25 lines | `09151a2` |
| 5 | `Text.Location.Tracker` (amortized line/column) | New type in swift-text-primitives | `1b06d5c` |
| — | L3 `Lexer.tokenize` entry point | `Lexer.Tokenized` + `Lexer.tokenize(_: Span<UInt8>)` | `1684120` |
| — | Package.swift path fix in swift-lexer | `../` → `../../` matching swift-parsers convention | `1684120` |

### Outstanding Work

| # | Lesson | Scope | Dependency | Priority |
|---|--------|-------|-----------|----------|
| 5b | Wire `Text.Location.Tracker` into `Lexer.Scanner` | swift-lexer-primitives | None (Tracker exists) | MEDIUM — enables per-token live position |
| 4 | SIMD/SWAR tiered bulk scanning | New primitives package or extension of parser-primitives | Benchmark harness (`/benchmark` skill) | HIGH impact, benchmark-gated |
| 6 | Flat `Lexer.Buffer` for packed token streams | swift-lexer-primitives or swift-lexer | Scanner functional | LOW — most consumers don't materialize token streams |
| 7 | Expand Token.Kind coverage | swift-lexer-primitives | Scanner functional | MEDIUM — hex/binary/octal literals, string interpolation, `#if` directives, prefix/postfix operator disambiguation |
| — | Align `ASCII.Byte.` → `.ascii.` in lexer-primitives | swift-lexer-primitives | None | LOW — cosmetic consistency with swift-parsers |

### Deferred Infrastructure Gaps (cross-cutting)

| Gap | Location | Impact |
|-----|----------|--------|
| No `Int(bitPattern: some Ordinal.Protocol)` overload | swift-ordinal-primitives | 3 boundary methods in Lexer.Scanner need `.rawValue` extraction |
| No typed increment on `Text.Line.Number` | swift-text-primitives | `Text.Location.Tracker.newline(at:)` uses `rawValue + 1` |
| `Cardinal.+` shadows `Cardinal.Protocol.+` in operator resolution | swift-cardinal-primitives | `Text.Location.Tracker.location(at:)` requires explicit type annotations on all intermediates |

### Verdict

6 of 7 planned xylem lessons delivered. Scanner operational with 37 tests, typed state throughout, no CRITICAL or HIGH open findings. Second session (2026-04-16) added: Location.Tracker integration, hex/binary/octal/float literals, `#if`/`#else`/`#elseif`/`#endif` directives, `.ascii.` form alignment.

**Remaining work** (all moderate-to-hard):

| Item | Difficulty | Blocker |
|------|-----------|---------|
| SIMD/SWAR tiered bulk scanning | Hard | `/benchmark` harness |
| Prefix/postfix operator disambiguation | Moderate | Ordinal subtraction + spacing heuristic |
| String interpolation `\(...)` | Hard | Mode stack / recursive scanner |
| Flat `Lexer.Buffer` | **Already realized** | `[Lexer.Lexeme]` + source Span IS flat storage |

The three infrastructure gaps (missing `Ordinal.Protocol` overload, missing `Text.Line.Number` increment, `Cardinal.+` shadowing) remain LOW severity but systemic.
