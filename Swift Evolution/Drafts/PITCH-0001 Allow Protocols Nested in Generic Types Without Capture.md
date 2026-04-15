# Pitch: Allow Protocols Nested in Generic Types (Without Capture)

<!--
---
pitch_id: PITCH-AAAA
date: 2026-02-13
status: DRAFT
depends_on: ~
related_experiments: ~
identification_report: swift-institute/Research/nested-protocols-in-generic-types.md
---
-->

## Problem

SE-0404 (Swift 5.10) allows protocols to be nested inside non-generic types, enabling
clean namespace-scoped protocols:

```swift
// Works — Bit.Vector is non-generic
extension Bit.Vector {
    public protocol `Protocol`: ~Copyable {
        var bitCapacity: Bit.Index.Count { get }
        borrowing func word(at index: Int) -> UInt
        mutating func setWord(at index: Int, to value: UInt)
        subscript(index: Bit.Index) -> Bool { get set }
    }
}
```

Five concrete types (`Bit.Vector`, `.Static`, `.Dynamic`, `.Bounded`, `.Inline`) conform
to this single protocol with ~4 lines each. All higher-level operations (`popcount`,
`clearAll`, `popFirst`, etc.) are default implementations on the protocol. This pattern
eliminates hundreds of lines of duplicated logic.

However, attempting the same pattern inside a generic type fails:

```swift
// ERROR: protocol 'Protocol' cannot be nested in a generic context
enum Buffer<Element: ~Copyable> {
    struct Arena: ~Copyable { ... }
}

extension Buffer.Arena {
    protocol `Protocol`: ~Copyable {
        // ❌ "protocol 'Protocol' cannot be nested in a generic context"
    }
}
```

`Buffer.Arena` has four variants (`Arena`, `.Bounded`, `.Inline`, `.Small`) that share
identical allocation, deallocation, and token-validation logic — exactly the same
variant-family pattern as `Bit.Vector`. But because `Buffer<Element>` is generic,
the nested protocol pattern is unavailable.

The workaround is a top-level protocol with a double-underscore name:

```swift
public protocol __BufferArenaProtocol<Element>: ~Copyable {
    associatedtype Element: ~Copyable
    // ...
}
```

This works, but:
- **Breaks discoverability**: Users cannot find `Buffer.Arena.Protocol` through
  autocomplete or dot-syntax navigation.
- **Pollutes the module namespace**: The protocol exists at top level alongside
  hundreds of other declarations.
- **Creates naming asymmetry**: Non-generic types get `Namespace.Protocol`,
  generic types get `__NamespaceProtocol`. Two patterns for the same concept.

## Proposed Direction

Extend SE-0404 to allow protocols nested in generic types, **without capturing
the outer type's generic parameters**.

The nested protocol would:
- **Not have access** to the outer type's generic parameters in its body.
- Have a **single identity** regardless of outer specialization:
  `Buffer<Int>.Arena.Protocol` and `Buffer<String>.Arena.Protocol` would be
  the **same protocol**.
- Be free to declare its own `associatedtype`s independently.

```swift
enum Buffer<Element: ~Copyable> {
    struct Arena: ~Copyable { ... }
}

extension Buffer.Arena {
    // Allowed: protocol does not reference outer 'Element'
    protocol `Protocol`: ~Copyable {
        associatedtype Element: ~Copyable  // Own associated type, not captured

        var header: Header { get }
        mutating func allocate(_ element: consuming Element) throws -> Position
        mutating func deallocate(at position: Position) throws
    }
}

// Conformance ties the associated type to the concrete Element:
extension Buffer.Arena: Buffer.Arena.`Protocol` { }
```

The critical design constraint is that the protocol **does not close over** the
enclosing type's generic parameters. This avoids the fundamental problem that
blocked generic contexts in SE-0404: there is no need for "generic protocols"
or parameter-to-associated-type mapping. The nesting is **purely for namespacing**.

This is the "without captures" approach first suggested by Paul Cantrell during
the original 2016 pitch discussion and explicitly left as a future direction
in SE-0404.

## Evidence

### Working Pattern (non-generic)

`Bit.Vector.Protocol` in [swift-bit-vector-primitives](https://github.com/coenttb/swift-primitives):
- **Protocol**: `Bit.Vector.Protocol` — 4 requirements
- **Defaults**: `popcount`, `allFalse`, `allTrue`, `clearAll`, `setAll`, `popFirst`
  plus `Property.View` accessors
- **Conformers**: 5 types, each ~4 lines of storage-specific accessor code
- **Savings**: Hundreds of lines of duplicated logic eliminated

### Blocked Pattern (generic)

`Buffer.Arena` in [swift-buffer-primitives](https://github.com/coenttb/swift-primitives):
- **Variants**: `Arena`, `Arena.Bounded`, `Arena.Inline`, `Arena.Small`
- **Shared operations**: allocation, deallocation, token validation, iteration
- **Current state**: Duplicated across variants — no shared protocol possible
  under the correct namespace

### Compiler Analysis

The restriction is enforced at `lib/Sema/TypeCheckDeclPrimary.cpp:3008`:

```cpp
if (isa<ProtocolDecl>(NTD) && DC->isGenericContext()) {
    NTD->diagnose(diag::unsupported_nested_protocol_in_generic, NTD);
    NTD->setInvalid();
    return;
}
```

`isGenericContext()` walks up the declaration context hierarchy. Any ancestor with
generic parameters triggers rejection. There is no feature flag or experimental
mode to bypass this.

Full analysis: [nested-protocols-in-generic-types.md](../Research/nested-protocols-in-generic-types.md)

## Open Questions

1. **Should the outer generic parameters be visible but not capturable?**
   If `Buffer<Element>.Arena.Protocol` can "see" `Element` but cannot use it
   in requirements, this could be confusing. Alternatively, the parameters
   could be completely invisible inside the protocol body.

2. **What about protocols nested in protocols?**
   SE-0404 also excludes `protocol Outer { protocol Inner {} }`. Should this
   pitch cover that case, or keep the scope narrow?

3. **Name mangling**: The protocol has a single identity regardless of outer
   specialization. Does the existing mangling scheme handle this naturally,
   or does it need extension?

4. **Transitivity**: If `Buffer<Element>.Arena` nests a protocol, and `Arena`
   itself nests `Bounded`, can `Bounded` also nest protocols? (The answer
   should be yes — the protocol doesn't capture any generic parameters at
   any level.)

## Impact

### Immediate

- Enables `Buffer.Arena.Protocol`, `Buffer.Ring.Protocol`, `Buffer.Linear.Protocol`,
  etc. — unifying variant families behind shared protocols.
- Enables `Storage<Element>.Protocol` for storage abstraction.
- Any generic namespace type can use the nested protocol pattern.

### Ecosystem

- Libraries using generic namespace enums (a common Swift pattern) gain
  first-class protocol namespacing.
- Eliminates the asymmetry where non-generic types get clean naming but
  generic types must use top-level protocols.
- Aligns with SE-0404's stated future direction.

### Precedent

This is the **most conservative** extension of SE-0404:
- No generic protocols (Manifesto: "Unlikely")
- No parameter-to-associated-type mapping
- No new type system features
- Purely a relaxation of the existing restriction for the non-capturing case

## Related Work

| Proposal | Relationship |
|----------|-------------|
| [SE-0404](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0404-nested-protocols.md) | Direct predecessor — this extends its scope |
| [SE-0427](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) | ~Copyable generics make generic namespace types more common |
| [Generics Manifesto](https://github.com/apple/swift/blob/main/docs/GenericsManifesto.md) | "Generic protocols" listed as "Unlikely" — this pitch avoids that |
| [Original pitch (2016)](https://forums.swift.org/t/4291) | Paul Cantrell's "without captures" suggestion |
| [Karl Wagner draft (2017)](https://forums.swift.org/t/5101) | Established "no captures" restriction as viable first step |
