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

**Rationale**: Nested types create natural namespaces, improve discoverability via autocomplete, and prevent naming collisions.

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

**Rationale**: Nested accessors mirror the nested type philosophy and enable progressive disclosure.

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

**Reference**: `swift-io/Research/io-event-namespace-typealias-vs-enum.md`

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

If ANY item fails, fix before presenting.

---

## Cross-References

See also:
- **implementation** skill for [IMPL-*] expression style, typed arithmetic, Property.View patterns
- **memory-safety** skill for [MEM-COPY-006] ~Copyable type organization exceptions
