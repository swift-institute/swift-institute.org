---
name: code-surface
description: |
  API surface conventions: namespace structure, nested accessors, specification-mirroring,
  typed throws, error type naming, file structure, one type per file.
  ALWAYS apply when declaring types, methods, properties, error types, or organizing files.

layer: implementation

requires:
  - swift-institute

applies_to:
  - swift
  - swift6
  - primitives
  - standards
  - foundations

absorbs:
  - naming
  - errors
  - code-organization
last_reviewed: 2026-03-20
---

# Code Surface Conventions

All types, methods, properties, error types, and source files MUST follow these rules.

---

## Namespace Structure

### [API-NAME-001] Nest.Name Pattern

All types MUST use the `Nest.Name` pattern. Compound type names are FORBIDDEN.

**Semantic rule**: In `Nest.Name`, the Nest is the broader domain and Name is the specific concept within it. Read `A.B.C` as "C within B within A" — each level narrows the scope.

| Path | Reading | Hierarchy |
|------|---------|-----------|
| `File.Directory.Walk` | A walk operation, for directories, in the file domain | Domain > Subdomain > Operation |
| `IO.NonBlocking.Selector` | A selector, for non-blocking I/O, in the IO domain | Domain > Variant > Type |
| `Memory.Address.Offset` | An offset, for addresses, in the memory domain | Domain > Concept > Aspect |

**Decision test**: If you can say "X is a kind of Y" or "X belongs to Y", then Y nests X.

```swift
// CORRECT
File.Directory.Walk
IO.NonBlocking.Selector
RFC_4122.UUID

// INCORRECT
FileDirectoryWalk      // Compound name - FORBIDDEN
DirectoryWalk          // Compound name - FORBIDDEN
NonBlockingSelector    // Compound name - FORBIDDEN
```

**Exception — macros** [PATTERN-015]: Swift macros MUST use compound names at file scope (e.g., `@CoW`, `@Defunctionalize`). The language does not support nested macro declarations, so the `Nest.Name` pattern cannot apply.

**Rationale**: Nested types create natural namespaces, improve discoverability via autocomplete, and prevent naming collisions.

---

### [API-NAME-001a] Single-Type-No-Namespace Rule

**Statement**: A namespace that contains only one type is not a namespace — it is a *variant label* — and MUST nest under its parent type rather than existing as a top-level domain. [API-NAME-001]'s Decision test determines whether X belongs under Y; this rule determines whether Y should exist as a namespace at all.

**Decision procedure**:

| Ask | If yes → | If no → |
|-----|---------|---------|
| Does this namespace (or proposed namespace) have, or plausibly will have, two or more distinct types that co-inhabit it as siblings? | Keep it as a namespace | It is a variant label; nest under the parent type whose variants it represents |

**Correct** — single-type labels nested under their parent:

| Wrong shape | Correct shape | Why |
|-------------|---------------|-----|
| `Cooperative` (top-level, one type) | `Executor.Cooperative` | `Cooperative` has no siblings outside the `Executor` variants |
| `Main` (top-level, one type) | `Executor.Main` | Same reasoning — `Main` is one variant of `Executor` |
| `Scheduled<Base>` (top-level generic) | `Executor.Scheduled<Base>` | The `Scheduled` label describes an `Executor` variant, not a standalone domain |
| `Kernel.Thread.Polling.Executor` | `Kernel.Thread.Executor.Polling` | `Polling` has no siblings outside `Executor`-variants under `Kernel.Thread` |

**Correct** — genuine namespaces (multiple sibling types):

| Shape | Siblings | Why it IS a namespace |
|-------|---------|------------------------|
| `Kernel.Thread` | `Handle`, `Executor`, `Pool`, `Worker`, … | Multiple co-inhabitants; genuine domain |
| `RFC_4122` | `UUID`, `UUID.Variant`, `UUID.Version`, … | Spec-defined domain with multiple types |
| `File.Directory` | `Walk`, `Walk.Options`, `Listing`, … | Multiple concepts under one subdomain |

**Why this rule exists**: [API-NAME-001] (`Nest.Name`) gives the shape of nested namespaces. It does NOT prevent the author from creating an empty or single-inhabitant namespace that is really just a variant label. Without [API-NAME-001a], sessions discover this case-by-case and bikeshed each instance; the rule collapses the class into one decision.

**When speculative namespace creation is tempting**: when three related types might eventually exist under a label but only one exists today, the rule says: nest the single type under its parent now, and promote the label to a namespace when the second type actually arrives. The promotion is a mechanical rename; the speculative namespace is a permanent wrong shape.

**Rationale**: A namespace containing one type is vocabulary overhead without vocabulary payoff. `Executor.Cooperative` reads as "the Cooperative variant of Executor" — natural. `Cooperative.Executor` reads as "the Executor type in the Cooperative namespace" — suggesting there is more to the Cooperative domain than there is. Naming follows structure; structure follows what types actually exist.

**Provenance**: Reflection `2026-04-15-swift-executors-toolkit-taxonomy.md`.

**Cross-references**: [API-NAME-001], [API-NAME-003]

---

### [API-NAME-002] No Compound Identifiers

Methods and properties MUST NOT use compound names. Use nested accessors.

```swift
// CORRECT
instance.open.write { }
dir.walk.files()

// INCORRECT
instance.openWrite { }  // Compound method - FORBIDDEN
dir.walkFiles()         // Compound method - FORBIDDEN
```

**Exception — boolean naming**: Swift's standard boolean naming convention (`is` + adjective) is NOT a compound identifier. `isEmpty`, `isFinished`, `isFulfilled`, `isClosed` are single-concept boolean properties following API Design Guidelines, not verb-noun compounds.

**Exception — spec-mirroring identifiers**: Static constants, enum cases, and type names that directly mirror specification-defined terminology are exempt. When the compound form IS the specification's term, the identifier mirrors the spec rather than inventing a compound. Examples: HTTP status `.notFound` (RFC 9110 §15.5.5 "404 Not Found"), header field `.contentType` (RFC 9110 §8.3), CSS property `BackgroundColor` (CSS Backgrounds §3.2).

**Rationale**: Nested accessors mirror the nested type philosophy and enable progressive disclosure. Spec-mirroring identifiers are exempt because their names derive from external authority, not internal naming decisions.

**Provenance (boolean exception)**: 2026-04-01-async-primitives-audit-round-two.md
**Provenance (spec-mirroring exception)**: 2026-04-02 pre-publication audit decision

---

### [API-NAME-003] Specification-Mirroring Names

Types implementing specifications MUST mirror the specification terminology.

```swift
// CORRECT
RFC_4122.UUID
ISO_32000.Page
RFC_3986.URI

// INCORRECT
UUID        // No specification context
PDFPage     // Compound, no spec namespace
URL         // No specification context
```

**Rationale**: Specification-mirroring names provide traceability and prevent naming drift.

---

### [API-NAME-004] No Typealiases for Type Unification

**Statement**: When unifying duplicate types across packages, the canonical type MUST be used directly at all call sites. Typealiases MUST NOT be introduced as a unification bridge — they create a false sense of equivalence while adding an indirection layer that complicates navigation and diagnostics.

**Correct**:
```swift
// After unification: all packages use the canonical type directly
import Text_Primitives

func report(at location: Text.Location) { }  // Direct usage
```

**Incorrect**:
```swift
// Typealias bridge — adds indirection without benefit
typealias SourceLocation = Text.Location

func report(at location: SourceLocation) { }  // Obscures actual type
```

**Exception**: [PATTERN-024] typealiases for generic instantiations remain valid — those localize a *specialization decision*, not a *unification bridge*.

**Rationale**: Type unification should eliminate indirection, not add it. Typealiases obscure the canonical type in diagnostics, autocomplete, and documentation.

---

### [API-NAME-004a] Namespace Adoption Typealiases

**Statement**: A typealias that adopts a lower-layer type into a higher-layer namespace for domain extension is PERMITTED when the higher layer builds substantial domain behavior on the type. A typealias that merely saves keystrokes (rename bridge) is FORBIDDEN per [API-NAME-004].

**Permitted** — namespace adoption (extends the concept):
```swift
// IO.Event = Kernel.Event — IO builds 52 types on this kernel concept
public typealias Event = Kernel.Event  // Adoption: domain behavior built on top
```

**Forbidden** — rename bridge (saves keystrokes):
```swift
// IO.Deadline = Clock.Suspending.Instant — just a shorter name
public typealias Deadline = Clock.Suspending.Instant  // ❌ No domain behavior added
```

**Decision test**: Does the higher-layer namespace declare 5+ types, extensions, or methods that build on the aliased type? If yes, it's adoption. If the typealias exists in isolation without domain-specific extensions, it's a bridge.

**Rationale**: Namespace adoption makes a lower-layer concept first-class in the higher-layer domain, enabling natural nesting (e.g., `IO.Event.Channel`, `IO.Event.Selector`). Rename bridges add indirection without domain value.

**Reference**: `swift-foundations/swift-io/Research/io-event-namespace-typealias-vs-enum.md`

**Cross-references**: [API-NAME-004], [API-NAME-001]

**Provenance**: 2026-04-01-swift-io-code-surface-remediation.md

---

## Error Handling

### [API-ERR-001] Typed Throws Required

All throwing functions MUST use typed throws.

```swift
// CORRECT
func read() throws(IO.Error) -> Data
func parse() throws(Parse.Error) -> Document

// INCORRECT
func read() throws -> Data       // Erases error type - FORBIDDEN
func parse() throws(any Error)   // Existential error - FORBIDDEN
```

**Rationale**: Typed throws enable exhaustive error handling at compile time and eliminate runtime type checking overhead.

---

### [API-ERR-002] Nested Error Types

Error types MUST be nested as `Domain.Error` following [API-NAME-001].

```swift
// CORRECT
enum IO {
    enum Error: Swift.Error {
        case posix(errno: CInt, operation: Operation, path: FilePath)
        case timeout(duration: Duration, operation: Operation)
    }
}

// INCORRECT
enum IOError: Error {           // Compound name - FORBIDDEN
    case posix(...)
}
```

---

### [API-ERR-003] Describe Failure, Not Recovery

Error cases SHOULD describe the failure condition, not the recovery action.

```swift
// CORRECT
case invalidHeader(expected: UInt32, found: UInt32)
case insufficientCapacity(required: Int, available: Int)
// INCORRECT
case retryLater              // Describes recovery, not failure
case useDefaultValue         // Describes recovery, not failure
```

---

### [API-ERR-004] Explicit Closure Annotation for Typed Throws

**Statement**: When calling a stdlib `rethrows` function from a `throws(E)` context, the closure MUST include an explicit `throws(E)` annotation. Without it, Swift 6.2 infers `any Error`, erasing the typed throw.

**Correct**:
```swift
func transform<E: Error>(_ values: [Int], using f: (Int) throws(E) -> String) throws(E) -> [String] {
    try values.map { (value: Int) throws(E) -> String in
        try f(value)
    }
}
```

**Incorrect**:
```swift
func transform<E: Error>(_ values: [Int], using f: (Int) throws(E) -> String) throws(E) -> [String] {
    try values.map { try f($0) }  // Infers `any Error`, not E
}
```

### [API-ERR-005] stdlib Typed Throws Compatibility (Swift 6.2.4)

**Statement**: Only a subset of stdlib `rethrows` functions preserve typed throws. Do NOT add `@_disfavoredOverload` overloads for functions that already work — they interfere with the stdlib's native support.

**Works with explicit `throws(E)` closure** (Swift 6.2.4):
- `Sequence.map`, `withUnsafeBytes(of:)`, `withUnsafeMutableBytes(of:)`, `Mutex.withLock`

**Does NOT preserve typed throws** (rethrows still erases E):
- `compactMap`, `flatMap`, `filter`, `forEach`, `reduce`, `contains(where:)`, `allSatisfy`, `first(where:)`, `sorted(by:)`, `min(by:)`, `max(by:)`, `drop(while:)`, `prefix(while:)`

**Rationale**: Partial stdlib support is undocumented. Adding same-name overloads causes the rethrows version to be selected, which is strictly worse than no overload.

---

## File Structure

### [API-IMPL-005] One Type Per File

Each `.swift` file MUST contain exactly one type declaration.

```
// CORRECT
File.Directory.Walk.swift     -> contains File.Directory.Walk
File.Directory.Walk.Options.swift -> contains File.Directory.Walk.Options

// INCORRECT
// File: Models.swift
struct User { }      // Multiple types - FORBIDDEN
struct Profile { }   // in one file - FORBIDDEN
```

**Clarification**: This rule counts type *declarations* (`struct`, `enum`, `class`, `actor`), not `extension` blocks. A file may contain multiple `extension` blocks adding methods, computed properties, or protocol conformances to an already-declared type.

**Rationale**: Single-type files enable precise naming, easier navigation, clear ownership, and reduced merge conflicts.

**Exception — constraint poisoning ([PATTERN-022])**: When a parent type has conditional generic extensions (e.g., `extension Parent where Element: ~Copyable`), `extension Parent.Child` in a separate file cannot resolve sibling types declared in those extensions. The fix is fully-qualified names (e.g., `Async.Channel<Element>.Bounded.State`). Extraction is blocked only when the type has deep cross-references to many siblings, making full qualification impractical — typically state-machine types with references to multiple peer types. Types with simple field layouts (e.g., iterators, endpoint wrappers) extract cleanly.

**Provenance**: 2026-03-31-async-primitives-code-surface-refactor.md

---

### [API-IMPL-006] File Naming Convention

File names MUST match the type's full nested path with dots.

```
// CORRECT
Array.Dynamic.swift
Array.Dynamic.Iterator.swift
Set.Ordered.Element.swift

// INCORRECT
DynamicArray.swift           // Compound name
ArrayDynamicIterator.swift   // No dot separation
```

---

### [API-IMPL-007] Extension Files

Extensions MUST use `+` suffix pattern.

```
// CORRECT
Array.Dynamic+Sequence.swift
Set.Ordered+Hashable.swift

// File contains:
extension Array.Dynamic: Sequence { ... }
```

---

### [API-IMPL-008] Minimal Type Body

Type declarations MUST contain only stored properties and the canonical initializer. Everything else MUST be in extensions.

```swift
// CORRECT
public struct Buffer {
    @usableFromInline
    var storage: Storage

    @usableFromInline
    var count: Int

    @inlinable
    public init() {
        self.storage = Storage()
        self.count = 0
    }
}

extension Buffer {
    public var isEmpty: Bool { count == 0 }

    public mutating func append(_ element: Element) { ... }
}

extension Buffer: Sequence {
    public func makeIterator() -> Iterator { ... }
}

// INCORRECT -- methods in type body
public struct Buffer {
    var storage: Storage
    var count: Int

    public init() { ... }

    public var isEmpty: Bool { count == 0 }  // Should be in extension

    public mutating func append(_ element: Element) { ... }  // Should be in extension
}
```

**What belongs in the type body**:
- Stored instance properties
- Canonical initializer(s)
- `deinit` (for classes and ~Copyable types)

**What belongs in extensions**:
- Computed properties
- Methods
- Protocol conformances
- Static members
- Nested types (with exception below)

**Exception for ~Copyable types**: Per [MEM-COPY-006], types with `~Copyable` generic parameters MAY include in the body:
- Nested storage types (e.g., `ManagedBuffer` subclasses)
- Nested types referencing the `~Copyable` parameter

This avoids constraint poisoning. Conditional conformances MUST still be in the same file.

**Rationale**: Minimal bodies make storage layout immediately visible, separate stable data from evolving behavior, and simplify code review.

---

### [API-IMPL-009] Hoisted Protocol with Nested Typealias

**Statement**: When a protocol needs to appear as `Outer.Inner.Protocol` on a generic type, the canonical pattern is:

1. **Hoist** the protocol to module scope (e.g., `_InnerProtocol` or hoisted name)
2. **Nest** a `typealias Protocol = _InnerProtocol` inside the generic type's namespace
3. **Conformance in declaring module** uses the hoisted name directly
4. **Consumers** use the typealias path (`Outer.Inner.Protocol`)

```swift
// CORRECT — Declaring module
public protocol _LocatedErrorProtocol: Swift.Error { ... }

extension Parser.Error {
    public struct Located<E: Swift.Error>: _LocatedErrorProtocol {
        public typealias Protocol = _LocatedErrorProtocol  // Consumers use this path
        ...
    }
}

// Consumer module
extension MyError: Parser.Error.Located.Protocol { ... }  // ✓ Uses typealias
```

```swift
// INCORRECT — Self-referential conformance
extension Parser.Error.Located: Parser.Error.Located.Protocol { ... }
// ❌ Cycle: resolving Located.Protocol requires resolving Located's conformances
```

**Three requirements**:
1. Types nested inside `.Error` namespaces MUST use `Swift.Error` (see [PLAT-ARCH-011])
2. Declaring-module conformance MUST use the hoisted name (avoids self-referential cycle)
3. Consumer modules CAN use the typealias path for conformance, constraints, and existentials

**When generic parameters block nesting**: If a nested type needs access to the outer type's generic parameter across a nesting boundary, use a `_Value` typealias on the outer type to capture the generic parameter before the inner type's scope shadows it.

**Provenance**: Reflection `2026-03-20-pass4-compound-renames-and-generic-nesting.md`.

**Cross-references**: [API-NAME-001], [PLAT-ARCH-011]

---

## State Modeling

### [API-IMPL-003] Enum Over Boolean

Use enums instead of boolean flags when state can expand.

```swift
// CORRECT
enum Connection {
    enum State {
        case disconnected
        case connecting
        case connected(Session)
        case disconnecting
    }
}

// INCORRECT
var isConnected: Bool     // Cannot represent connecting/disconnecting
var isConnecting: Bool    // Requires multiple booleans
```

---

### [API-IMPL-010] Visibility Change Triggers Naming Audit

**Statement**: Widening a type's or member's access level (e.g., `private` → `internal`, `internal` → `public`) MUST trigger a naming audit against [API-NAME-001] and [API-NAME-002]. Names that were acceptable at narrower visibility may violate conventions when exposed to a wider audience.

**Correct**:
```swift
// Was private — compound name hidden from scrutiny
// private struct ReadResult { ... }

// Widening to internal: audit catches compound name
// Fix: namespace enum + nested Result
enum Read { struct Result { ... } }
```

**Incorrect**:
```swift
// Was private, now widened to internal
internal struct ReadResult { ... }  // ❌ Compound name now visible
```

**Rationale**: Private names accumulate naming debt invisible to convention enforcement. Widening access exposes this debt. The audit is a one-time cost at the boundary change that prevents convention violations from reaching wider scopes.

**Cross-references**: [API-NAME-001], [API-NAME-002]

**Provenance**: 2026-03-29-channel-split-full-duplex-io.md

---

### [API-IMPL-011] Wrapper Completeness

**Statement**: A wrapper type that owns construction, invariants, and error domain MUST also own the primary operation. A wrapper that encapsulates 90% of an interface is worse than one that encapsulates 100% or 0%, because the escape hatch for the missing 10% dominates the user's experience and makes the wrapper appear useless.

**Correct**:
```swift
// IO.Lane wraps IO.Blocking.Lane
// Owns: factories, error domain, Handle, DI conformance
// Also owns: run() — the primary operation
// → Complete wrapper, _backing never exposed to consumers
```

**Incorrect**:
```swift
// IO.Lane wraps IO.Blocking.Lane
// Owns: factories, error domain, Handle, DI conformance
// Missing: run() — the primary operation
// → Every consumer calls lane._backing.run { }
// ❌ Wrapper looks fake; the 10% escape dominates
```

**Rationale**: Incomplete wrappers create worse impressions than no wrapper at all. If a type owns construction and invariants but forces consumers to reach through to the backing type for the primary operation, the wrapper's encapsulation is perceived as useless — even though it provides genuine value for construction and error handling.

**Cross-references**: [API-LAYER-001], [IMPL-074]

**Provenance**: 2026-03-30-io-lane-boundary-collaborative-review.md

---

## Parameter Ordering

### [API-IMPL-012] Closure Parameters Trail the Signature

**Statement**: All closure parameters MUST occupy the final positions of a function or initializer signature. A non-closure parameter MUST NOT appear after a closure parameter. Typed-throws thunks per [IMPL-092] — `() throws(E) -> T` — are closures for the purpose of this rule.

**Correct**:
```swift
public init(
    id: ID,
    interest: Interest,
    flags: Options = [],
    onEvent: @escaping (Event) -> Void
)
```

**Incorrect**:
```swift
public init(
    id: ID,
    onEvent: @escaping (Event) -> Void,
    flags: Options = []                    // ❌ non-closure after closure
)
```

**Rationale**: Without closure-last ordering, SE-0286 forward-scan cannot match the closure to a trailing-closure call site, and the compiler silently disables trailing-closure syntax. Closure-last is the de-facto universal Swift convention across TSPL, the stdlib, and every surveyed ecosystem signature.

**Scope**: Applies to all public and package-visible signatures. Private signatures SHOULD follow the rule; violations MUST be justified by a `// WHY:` comment per [PATTERN-016].

**Cross-references**: [API-IMPL-013], [API-IMPL-014], [IMPL-092]

**Provenance**: `swift-institute/Research/parameter-ordering-conventions.md` (2026-04-16)

---

### [API-IMPL-013] Multiple Closures Follow Lifecycle Order

**Statement**: For signatures with two or more closure parameters, closures MUST be ordered by lifecycle: setup → body → completion/teardown. The primary body closure MAY be unlabeled; all subsequent closures MUST be labeled per SE-0279.

Labels for secondary closures participate in the call-site surface (`… completion: { … }`, `… onError: { … }`) and MUST name the closure's *role* in the operation, not its Swift type — per [API-NAME-002] and the API Design Guidelines "roles over types" principle.

**Correct** — validated at `swift-primitives/.../Kernel.Completion.Driver.swift:104`:
```swift
public init(
    submit:        @escaping (Submission, borrowing Descriptor) throws(Error) -> Void,
    flush:         @escaping () throws(Error) -> Submission.Count,
    drain:         @escaping ((Event) -> Void) -> Event.Count,
    close:         @escaping () -> Void,
    overflowCount: @escaping () -> Event.Count = { .zero }
)
```

Call site:
```swift
driver.operation { event in
    handle(event)
} completion: { result in
    finish(result)
}
```

**Incorrect**:
```swift
// ❌ completion before body — body loses trailing-closure position at call sites
public func perform(
    completion: @escaping (Result) -> Void,
    body: @escaping () -> Void
)
```

**Cross-references**: [API-IMPL-012], [API-NAME-002]

**Provenance**: `swift-institute/Research/parameter-ordering-conventions.md` (2026-04-16)

---

### [API-IMPL-014] Configuration Parameter Placement

**Statement**: Configuration-bearing parameters — `.Options`, `.Configuration`, `.Context`, or `OptionSet` types — MUST sit at one of two positions:

1. **First**, labeled or unlabeled, when the configuration IS the primary input (the operation's identity or output is fully determined by the configuration).
2. **Last in the non-closure portion of the signature**, labeled, with a default value, when the configuration modifies a primary operation.

Middle placement — configuration between two unrelated domain parameters — is FORBIDDEN. Splitting configuration across sibling parameters when a struct would suffice is FORBIDDEN; bundle into the struct.

**Decision test**: *Can the operation's purpose be stated with only the configuration parameter?* If yes → first. If the operation's purpose is stated with other parameters and the configuration only tunes it → last (before any closures).

**Correct — configuration as primary input** (`swift-foundations/.../SVG.Context.swift:25`):
```swift
public init(_ configuration: Configuration = .default)
```

**Correct — configuration as modifier** (`swift-primitives/.../Kernel.Event.swift:53`):
```swift
public init(id: ID, interest: Interest, flags: Options = [])
```

**Correct — configuration modifier before closures**:
```swift
public func perform(
    on target: Target,
    options: Options = [],
    body: @escaping () -> Void
)
```

**Incorrect**:
```swift
public func perform(
    on target: Target,
    options: Options = [],                 // ❌ middle placement
    mode: Mode,
    body: @escaping () -> Void
)

public func perform(
    with config: Configuration,
    timeout: Duration,                     // ❌ configuration split across siblings
    retryPolicy: RetryPolicy
)
```

**Rationale**: Middle placement is not compatible with SE-0286 forward-scan when a closure trails, and hides the configuration's relationship to the operation. The first/last dichotomy maps onto the semantic role — primary input vs. modifier — and matches every surveyed ecosystem signature.

**Cross-references**: [API-IMPL-012], [API-IMPL-015]

**Provenance**: `swift-institute/Research/parameter-ordering-conventions.md` (2026-04-16)

---

### [API-IMPL-015] Struct Configuration Over Builder Closures

**Statement**: Configuration surfaces MUST use explicit struct parameters (with defaults) rather than builder closures of the shape `(inout Options) -> Void` or `(ConfigBuilder) -> Void`.

**Correct**:
```swift
public func perform(
    options: Options = [],
    body: @escaping () -> Void
)

// Composable at call sites:
let base: Options = .default
target.perform(options: base.with(\.flag, true)) { … }
```

**Incorrect**:
```swift
public func perform(
    configure: (inout Options) -> Void = { _ in },   // ❌ builder closure
    body: @escaping () -> Void
)
```

**Rationale**: Struct parameters are inspectable at the call site, composable across calls, participate in typed-throws and `Sendable` analysis naturally, and preserve the compile-time constraint surface. Builder closures trade all of that for construction syntax sugar. The ecosystem survey found zero builder-closure configurations — this rule codifies the existing practice.

**Cross-references**: [API-IMPL-014]

**Provenance**: `swift-institute/Research/parameter-ordering-conventions.md` (2026-04-16)

---

## Post-Implementation Checklist

Before presenting code as complete, verify EACH item:

- [ ] Every type uses `Nest.Name` pattern — no compound type names [API-NAME-001]
- [ ] Every method/property uses nested accessors — no compound identifiers [API-NAME-002]
- [ ] Spec-implementing types mirror the specification's terminology [API-NAME-003]
- [ ] All throwing functions use typed throws (`throws(E)`) — no untyped `throws` [API-ERR-001]
- [ ] Error types are nested enums with descriptive cases — no string-based errors [API-ERR-002]
- [ ] Each `.swift` file contains exactly one type declaration [API-IMPL-005]
- [ ] File names match the nested type path with dots [API-IMPL-006]
- [ ] Extension files use `+` suffix [API-IMPL-007]
- [ ] Type bodies contain only stored properties and canonical init — all methods in extensions [API-IMPL-008]
- [ ] Protocol typealiases on generic types use hoisted protocol for declaring-module conformance [API-IMPL-009]
- [ ] Access level widening has been audited for naming convention compliance [API-IMPL-010]
- [ ] Closure parameters trail the signature — no non-closure parameter follows a closure [API-IMPL-012]
- [ ] Multiple closures ordered by lifecycle (setup → body → completion); secondary closures labeled per SE-0279 [API-IMPL-013]
- [ ] Configuration sits first (primary input) or last before closures (modifier with default) — never middle [API-IMPL-014]
- [ ] Configuration uses struct parameters, not builder closures [API-IMPL-015]

If ANY item fails, fix before presenting.

---

## Cross-References

See also:
- **implementation** skill for [IMPL-*] expression style, typed arithmetic, Property.View patterns
- **memory-safety** skill for [MEM-COPY-006] ~Copyable type organization exceptions
