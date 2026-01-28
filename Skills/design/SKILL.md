---
name: design
description: |
  API design patterns, package layering, concurrency coordination, typealias architecture.
  Apply when making architectural decisions about API shape, layer boundaries, or type sharing.

layer: implementation

requires:
  - swift-institute
  - naming

applies_to:
  - swift
  - swift6
  - primitives
  - standards
  - foundations

migrated_from:
  - Implementation/Design.md
  - Implementation/Layering.md
  - Implementation/Concurrency.md
migration_date: 2026-01-28
---

# Design Patterns

API design, package layering, concurrency coordination, and typealias architecture.

---

## Package Layering

### [API-LAYER-001] Explicit Target Layers

**Statement**: Code MUST be designed in layers, each depending only on layers below it.

Typical shape:

1. **Primitives** — Minimal tokens, IDs, events, handles. Zero policy, zero platform choice.
2. **Driver / backend contracts** — Capability interfaces, leaf errors, stable testable contracts.
3. **Platform backends** — kqueue, epoll, IOCP, etc.
4. **Runtime orchestration** — Lifecycles, scheduling, cancellation, cross-thread coordination.
5. **User-facing convenience** — Ergonomic wrappers, default policies, platform factories.

| Question | Expected Answer |
|----------|-----------------|
| Depends only on layers below? | Yes |
| Can be tested in isolation? | Yes |
| Avoids lifecycle policy? | Yes (for primitives) |
| Errors typed and layer-appropriate? | Yes |
| Platform backends swappable? | Yes (for abstractions) |

**Cross-references**: [API-LAYER-002]

---

### [API-LAYER-002] Responsibility Separation

**Statement**: Lower layers MUST NOT embed lifecycle policy, introduce cancellation or shutdown semantics, construct user-facing errors requiring runtime context, or depend on higher-level scheduling decisions.

Higher layers are the only place where lifecycle semantics, cancellation/shutdown unification, and backpressure/retry policy exist.

**Cross-references**: [API-LAYER-001], [API-ERR-002]

---

### Cross-Platform Requirements

Platform selection MUST be centralized. Callers MUST NOT use `#if`. Handles MUST be opaque and platform-agnostic. Backends MUST satisfy the same contract: `register`, `modify`, `deregister`, deterministic shutdown, defined behavior for late events (drop).

**Cross-references**: [API-LAYER-001], [PATTERN-004]

---

## API Design Patterns

### [PATTERN-017] Fallback as Feature, Not Compromise

**Statement**: When a native/optimized path handles only a subset of cases, the fallback to a slower but complete path is an intentional feature, not defensive programming. The API SHOULD accept all valid inputs and route internally.

```swift
// CORRECT — Internal routing
public static func parse(_ string: String) -> UUID? {
    if string.count == 36 {
        if let uuid = nativeParse(string) { return uuid }
    }
    return pureSwiftParse(string)
}

// INCORRECT — Forcing callers to pre-validate
public static func parseHyphenated(_ string: String) -> UUID?
public static func parseCompact(_ string: String) -> UUID?
```

**Cross-references**: [API-ERR-003]

---

### [PATTERN-024] Type Aliases as Architectural Boundaries

**Statement**: When a package consistently uses a specific generic instantiation — especially one involving unsafe escapes — a typealias SHOULD be defined to localize the decision.

```swift
// CORRECT — One typealias, documented justification
typealias Box<I> = Reference.Indirect<I>.Unchecked
// 27 usage sites just use Box<MyIterator>

// INCORRECT — Decision scattered across 27 files
let storage: Reference.Indirect<MyIterator>.Unchecked
```

**Cross-references**: [API-IMPL-006]

---

### [PATTERN-032] Bound vs Independent Typealias Parameters

**Statement**: When exposing nested types through generic parents via typealias, parameters MUST be bound to the parent's parameters, not independent.

```swift
// CORRECT — Bound to parent
extension Cache {
    public typealias Evict = __CacheEvict<Key, Value>
}
// Usage: Cache<String, Int>.Evict

// INCORRECT — Independent parameters
extension Cache {
    public typealias Evict<K, V> = __CacheEvict<K, V>
}
// Usage: Cache.Evict<String, Int>  — Ambiguous
```

**Cross-references**: [API-NAME-001]

---

### [PATTERN-034] Requirements as Design Pressure

**Statement**: API requirements documents function as type systems for design decisions. Rigorous application of requirements redirects "easy" solutions toward correct solutions.

```text
Initial design: UserManager.fetchUserData()
After [API-NAME-002]: User.Manager.fetch.data()
After review: User.fetch() — simplified when requirements applied
```

**Cross-references**: [API-NAME-001], [API-NAME-002]

---

### [PATTERN-049] Typealiases as the Reuse Primitive

**Statement**: When multiple packages need to expose the same types with local names, typealiases MUST be used instead of wrapper types. Zero-cost sharing at the ABI level.

```swift
// CORRECT — Facade re-exports with local name
public typealias Value = Machine_Primitives.Machine.Value
public typealias Transform = Machine_Primitives.Machine.Transform<Instruction>
public typealias Program = Machine_Primitives.Machine.Program<Instruction, Fault>

// INCORRECT — Wrapper type reintroduces duplication
public struct BinaryValue {
    public let inner: Machine_Primitives.Machine.Value
    // Every method must be forwarded
}
```

**Generic typealias extension limitation**: You cannot extend a generic typealias. Workaround: use static functions on the facade namespace instead of instance methods.

```swift
extension Binary.Bytes.Machine {
    public static func run(program: Program, root: ID, ...) -> Result { ... }
}
```

**MemberImportVisibility**: Use `public import` only where `@inlinable` code references the module's types by name. Otherwise, keep imports internal.

**Cross-references**: [PATTERN-024], [PATTERN-032], [PATTERN-006]

---

### [PATTERN-050] Never as Closed Default for Extension Points

**Statement**: When designing shared types that may need facade-specific extensions, the extension capability SHOULD be encoded as a generic type parameter with `Never` as the closed default.

```swift
// Core shared type with extension point
public enum Frame<NodeID, Checkpoint, Failure: Error, Extra> {
    case call(child: NodeID)
    case sequence(a: NodeID, b: NodeID, combine: Combine)
    case choice(first: NodeID, second: NodeID)
    case extra(Extra)  // Extension point
}

// Facade A: Extra = Memoization<Checkpoint>
// Facade B: Extra = Never (compile-time elimination)
```

When `Extra = Never`, `switch never {}` compiles to nothing — a type-level assertion of impossibility. No `fatalError` needed.

**Cross-references**: [PATTERN-049], [PATTERN-024], [PATTERN-014]

---

## Concurrency Patterns

### [PATTERN-020] Never Resume Under Lock

**Statement**: Continuations MUST NOT be resumed while holding a lock. Collect resumption thunks under lock, release lock, then execute resumptions.

```swift
// CORRECT — Deferred resumption
func complete(with value: T) {
    let resumptions: [Async.Waiter.Resumption]
    lock.withLock {
        resumptions = waiters.drain().map { $0.resumption }
        state = .completed(value)
    }
    // Lock released — now safe to resume
    for resumption in resumptions {
        resumption.resume()
    }
}

// INCORRECT — Resuming under lock
lock.withLock {
    for waiter in waiters.drain() {
        waiter.continuation.resume(returning: value)  // DANGER
    }
}
```

**Cross-references**: [PATTERN-014]

---

### [PATTERN-022] Inout-Across-Await Hazard

**Statement**: When an async method accesses mutable state through a `_modify` accessor, the exclusivity check operates within a single execution context — it does NOT prevent concurrent access from different tasks.

```swift
// HAZARD
actor Container {
    var items: [Item] = []
    func process() async {
        items.append(await fetchItem())  // Suspension point!
        // Another task could access items during the await
    }
}
```

Mitigation: Use local copies across suspension points, or restructure to avoid inout access across await.

**Cross-references**: [PATTERN-020]

---

### [PATTERN-025] Type Erasure vs Sendable Tension

**Statement**: Type erasure mechanisms (raw pointers, `Unmanaged`, unsafe bitcasts) are explicitly non-Sendable in Swift 6. When type erasure is required for heterogeneous storage, the composition with Sendable-requiring primitives creates a tension that MUST be resolved explicitly.

| Approach | Trade-off |
|----------|-----------|
| Sendable wrapper (`Reference.Pointer`) | Encapsulates unsafety in one place |
| Accept limitation | Some compositions aren't possible without unsafe opt-in |
| `@unchecked Sendable` at use site | Makes unsafety visible but scattered |

**Cross-references**: [PATTERN-021]

---

## Cross-References

See also:
- **naming** skill for [API-NAME-*] naming conventions
- **errors** skill for [API-ERR-*] error handling
- **platform** skill for [PATTERN-004-008] build infrastructure
- **advanced-patterns** skill for memory/ownership and unsafe operation patterns
- **memory-safety** skill for Sendable conformance rules [MEM-SEND-*]
