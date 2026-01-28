# API Naming

@Metadata {
    @TitleHeading("Swift Institute")
}

Naming conventions: Nest.Name pattern, namespace structure, and identifier rules.

## Overview

This document defines naming requirements for all public APIs.

**Applies to**: All public types, functions, methods, properties, and enum cases across all packages.

**Does not apply to**: Private implementation details, test code, or generated code.

---

## Namespace Structure: Nest.Name Pattern

**Scope**: All type declarations.

**Statement**: All types MUST use the `Nest.Name` pattern where **Nest** is the larger domain and **Name** is the specific concept. This is a foundational, non-negotiable requirement.

### Core Rules

1. **MUST use `Nest.Name` namespaces** - Types are nested within their domain.
2. **MUST NOT use compound type names** - Never concatenate words into a single identifier.
3. **Related concepts MUST share the same domain namespace** - Cohesion over convenience.

**Correct**:
```swift
File.Directory              // File is the domain, Directory is the concept
File.Directory.Walk         // Walk is a sub-concept of Directory
File.Directory.Walk.Options // Options specific to Walk
IO.NonBlocking.Selector     // IO → NonBlocking → Selector
Kernel.Thread.Handle        // Kernel → Thread → Handle
Finite.Ordinal              // Finite → Ordinal
```

**Incorrect**:
```swift
FileDirectory               // ❌ Compound name
DirectoryWalk               // ❌ Compound name
NonBlockingSelector         // ❌ Compound name
ThreadHandle                // ❌ Compound name
```

**Rationale**:
1. **Discoverability**: Type `File.` and autocomplete reveals the entire File domain.
2. **Hierarchy communicates relationships**: `File.Directory.Walk` clearly shows Walk belongs to Directory belongs to File.
3. **Avoids naming collisions**: `IO.Error` vs `File.Error` vs `Kernel.Error` coexist naturally.
4. **Scales gracefully**: New concepts nest without polluting the global namespace.

### Implementation

Nesting is achieved via extensions:

```swift
// In File.swift
public enum File {}

// In File.Directory.swift
extension File {
    public struct Directory: Sendable { ... }
}

// In File.Directory.Walk.swift
extension File.Directory {
    public struct Walk: Sendable { ... }
}
```

### When Nesting Is Blocked vs When Direct Nesting Works

Swift does not allow protocols nested in **generic** types. However, **non-generic namespace enums** CAN nest protocols directly. The decision tree:

| Parent Type | Nested Protocol | Solution |
|-------------|-----------------|----------|
| Generic type (`struct Foo<T>`) | Not allowed | Hoist with `__` prefix + typealias |
| Non-generic struct/class | Allowed | Direct nesting |
| Non-generic enum | Allowed | Direct nesting (preferred for namespaces) |

**Direct nesting (preferred when parent is non-generic namespace enum)**:

```swift
extension Input {
    public enum Access {
        // Directly nested - no hoisting needed
        public protocol Random: Input.`Protocol`, ~Copyable { ... }
    }
}

// Usage: Input.Access.Random (truly nested)
```

**Hoisting (required when parent is generic)**:

```swift
// Hoisted (module level) - necessary because Effect<T> is generic
public protocol __EffectProtocol { ... }

// Typealias provides the correct Nest.Name API
extension Effect {
    public typealias `Protocol` = __EffectProtocol
}

// Usage: Effect.Protocol (appears nested via typealias)
```

### Namespace Enums as Phantom Type Tags

Namespace enums can serve double duty as phantom type tags, eliminating redundant `Tag` sub-enums:

```swift
// AVOID: Redundant Tag enum
extension Input {
    public enum Access {
        public enum Tag {}  // UNNECESSARY
    }
}

// PREFER: Namespace IS the tag
var access: Accessor<Self, Input.Access>
extension Accessor where Tag == Input.Access, Base: Input.Access.Random { ... }
```

The accessor "tagged with `Input.Access`" means "this is an access accessor." The domain name provides the discrimination directly.

Nested `Tag` enums are only needed when:
1. The namespace needs multiple distinct tags (rare)
2. The namespace is a generic type (can't use generic types as tags)
3. The tag needs to carry type-level information (associated types)

---

## No Compound Identifiers

**Scope**: All identifiers including types, functions, methods, properties, variables, and enum cases.

**Statement**: MUST avoid compound identifiers. Prefer path-like composition via nested values and calls.

**Correct**:
```swift
instance.open.read { … }
File.Directory.Walk
IO.NonBlocking.Selector
```

**Incorrect**:
```swift
instance.openRead { … }    // ❌ Compound method name
FileDirectoryWalk          // ❌ Compound type name
NonBlockingSelector        // ❌ Compound type name
```

**Rationale**: Compound names defeat discoverability and create inconsistent naming patterns. Path-like composition allows autocomplete to guide users through the API.

---

## Specification-Mirroring Type Names

**Scope**: Types implementing external specifications (RFCs, ISOs, W3C, etc.).

**Statement**: When implementing external specifications, type names MUST mirror the specification's terminology exactly. The namespace SHOULD reflect the specification identifier.

**Correct**:
```swift
RFC_4122.UUID              // RFC 4122 UUID
RFC_4122.UUID.Version      // Version as defined in RFC 4122
ISO_32000.Page             // PDF page per ISO 32000
RFC_3986.URI               // URI per RFC 3986
```

**Incorrect**:
```swift
UUID                       // ❌ No specification context
UUIDVersion                // ❌ Compound name, no spec namespace
PDFPage                    // ❌ Compound name, no spec namespace
```

**Rationale**: Each type maps directly to a specification section, enabling compliance verification.

---

## Flat Namespace Constants

**Scope**: Static constants and well-known values on types.

**Statement**: Static constants MUST be direct properties on the type, not nested in unnecessary sub-namespaces.

**Correct**:
```swift
extension RFC_4122.UUID {
    public static let dns = Self(bytes: (...))
    public static let url = Self(bytes: (...))
    public static let `nil` = Self(bytes: (...))
}

// Usage: clean shorthand works
let uuid = RFC_4122.UUID.v5(namespace: .dns, name: "example.com", using: hasher)
```

**Incorrect**:
```swift
// ❌ Unnecessary sub-namespace
extension RFC_4122.UUID {
    public enum Namespace {
        public static let dns = RFC_4122.UUID(bytes: (...))
    }
}
// .dns shorthand won't work
```

---

## Nested Accessor Pattern

**Scope**: Instance methods that group related operations.

**Statement**: Instance methods that group related operations MUST use nested accessor structs rather than compound method names.

**Correct**:
```swift
extension File.Directory {
    public var walk: Walk { Walk(path) }
}

extension File.Directory.Walk {
    public func callAsFunction(options: Options = Options()) throws -> [Entry]
    public func files(options: Options = Options()) throws -> [File]
    public func directories(options: Options = Options()) throws -> [Directory]
}

// Usage becomes path-like:
for entry in try dir.walk() { ... }
for file in try dir.walk.files() { ... }
```

**Incorrect**:
```swift
// ❌ Compound method names
dir.walkFiles()
dir.walkDirectories()
```

---

## API Minimalism

**Scope**: All public APIs.

**Statement**: Public APIs MUST be small, composable, and mechanically predictable.

- Convenience APIs MAY exist only at the highest-level user-facing targets.
- Lower-level targets SHOULD prefer `init(...)`, static factory functions, and pure transformations.
- Methods are allowed only when required by the language, modeling essential mutation, or when ergonomics cannot be achieved otherwise.

---

## Name Evaluation: Information Gained vs Lost

**Scope**: Evaluating proposed name changes and choosing between name candidates.

**Statement**: When evaluating a name change, the decision MUST be based on what information each name carries and what it loses.

| Proposed Change | Information Gained | Information Lost |
|-----------------|-------------------|------------------|
| `Box` → `Strong` | Ownership clarity | Mutability distinction |
| `Indirect` → `Cell` | Mutability clarity | Swift idiom alignment |

Only rename when information gain clearly exceeds transition costs.

---

## Generic Parameter Naming

**Scope**: Generic type parameters on types that conform to protocols with associated types.

**Statement**: Generic parameter names MUST be chosen with awareness of all protocols the type conforms to. When a generic parameter name matches a protocol's associated type name, Swift silently uses the parameter to satisfy the requirement—potentially with wrong semantics.

**Correct**:
```swift
struct __CacheEvict<K, V>: Effect.Protocol {
    typealias Key = K
    typealias Value = Void  // Explicit: this effect returns nothing
}
```

**Incorrect**:
```swift
struct __CacheEvict<Key, Value>: Effect.Protocol {
    // ❌ Value shadows the protocol's associated type
}
```

---

## Module-Scoped Name Resolution

**Scope**: Naming types within modules that use standard library names.

**Statement**: Adding a nested type MUST NOT shadow standard library names used elsewhere in the module. Swift's name resolution is module-scoped, not file-scoped.

**Contested Names** (don't use as namespace enums):
- `Sendable` → Use `Sendability` instead
- `Equatable` → Use `Equality` instead
- `Error` → Use `Errors` instead

---

## Verbosity as Self-Documentation

**Scope**: Type names and type signatures that embed architectural decisions.

**Statement**: Type names and signatures SHOULD be verbose when the verbosity documents architectural decisions. Longer names that reveal design choices are preferable to shorter names that hide them.

**Correct**:
```swift
struct Storage: Sendable {
    let _storage: Reference.Indirect<Async.Mutex<State>>.Unchecked
}
// The type name reveals: Reference, Indirect, Mutex, Unchecked
```

**Incorrect**:
```swift
final class Storage: @unchecked Sendable {
    let state: Async.Mutex<State>
}
// Hidden: Why a class? Why @unchecked?
```

### Grep-ability as Design Goal

Code SHOULD be searchable for its own characteristics:

| Characteristic | Searchable Pattern |
|----------------|-------------------|
| Unchecked Sendable escapes | `\.Unchecked`, `@unchecked Sendable` |
| Unsafe operations | `unsafe` |
| Reference semantics | `Reference\.Indirect` |
| Hoisted protocols | `^public protocol __` |

---

## Names as Constraints

**Scope**: Module, package, and type naming decisions.

**Statement**: Names are constraints, not labels. A well-chosen name MUST prevent future drift by making inappropriate additions feel obviously wrong.

#### The Test

When naming a module or type, ask: does this name describe what the code *is*, or does it describe how it's *used*?

| Name Style | Behavior | Effect |
|------------|----------|--------|
| **Describes what it IS** | Resists scope creep | "ABI" accepts only ABI definitions |
| **Describes how it's USED** | Invites accumulation | "Interop" accepts any cross-module helper |

**Correct**:
```swift
// ISO_9945.ABI - defines POSIX C calling convention projections
// The name constrains the module: only ABI boundary code belongs here

extension ISO_9945 {
    /// Projection of Swift types onto the POSIX C ABI.
    /// Contains ONLY pointer projection initializers.
    public enum ABI {}
}

extension ISO_9945.ABI {
    /// CChar pointer projection - this IS the ABI boundary
    public init(cchar: UnsafePointer<CChar>) { ... }
}

// Question: "Should string construction go in ABI?"
// Answer: Obviously not - string construction is not ABI.
```

**Incorrect**:
```swift
// ❌ ISO_9945.Interop - vague, invites accumulation
extension ISO_9945 {
    /// Interop helpers for POSIX.
    public enum Interop {}  // ❌ What doesn't count as "interop"?
}

// Six months later:
extension ISO_9945.Interop {
    static func formatError(...) { }     // "It's interop!"
    static func bufferHelper(...) { }    // "It's interop!"
    static func stringUtility(...) { }   // "It's interop!"
}
// Module becomes a junk drawer with a respectable name
```

#### Constraint Vocabulary

Names with inherent constraints:

| Name | Constraint | Inappropriate Additions |
|------|------------|------------------------|
| `ABI` | Calling convention boundary only | Utilities, helpers, formatters |
| `Protocol` | Contract definition only | Implementation details |
| `Primitives` | Atomic building blocks only | Composed functionality |
| `Constants` | Static values only | Computed properties, methods |

Names that invite accumulation (avoid):

| Name | Problem | Alternative |
|------|---------|-------------|
| `Interop` | Any cross-module code fits | Name the specific boundary |
| `Helpers` | Anything "helpful" fits | Name the specific mechanism |
| `Utils` | Anything "useful" fits | Name the specific domain |
| `Common` | Anything "shared" fits | Name the specific contract |

**Rationale**: Module names that resist inappropriate additions are self-maintaining. Developers adding code ask "does this fit?" and the name provides the answer. Names that describe usage ("interop") don't constrain because everything could plausibly be described that way.

---

## Topics

### Related Documents

- <doc:API-Requirements>
- <doc:API-Implementation>
- <doc:API-Errors>
