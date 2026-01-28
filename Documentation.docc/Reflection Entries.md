# Reflection Entries

@Metadata {
    @TitleHeading("Swift Institute")
}

Post-work reflections on infrastructure design, collaboration, and craft.

## Overview

This document collects reflections that emerge after completing work—observations about the craft of building infrastructure, insights that don't fit into technical specifications, and wisdom gained from the process of design.

**Document type**: Informal collection (not normative requirements).

**Entry order**: Oldest entries first, newest entries last. New entries are appended at the END.

**Consolidation**: Entries are processed oldest-first (top of file) by the consolidation process. See <doc:_Reflections-Consolidation>.

---

## 2026-01-20: The Nested Type Escape Hatch for ~Copyable Propagation [Package: swift-queue-primitives]

*Context: Fixing Queue.Linked to work with ~Copyable elements after discovering that external generic type references fail to propagate the constraint suppression.*

### The Fundamental Discovery

Swift's `~Copyable` constraint suppression has a propagation boundary that wasn't documented in official sources. When a generic type parameter has its Copyable requirement suppressed (via `~Copyable`), that suppression propagates correctly to:
- Nested types declared **inside** the same type body
- Extensions on the same type
- Local variables and parameters

But suppression **fails to propagate** to:
- Cross-module generic type instantiations (e.g., `List<Element>.Linked<1>`)
- Module-level generic types accessed with the outer type's generic parameter
- Generic typealiases that reference external types

The critical insight: the propagation boundary isn't about module boundaries per se—it's about **lexical nesting**. The generic parameter must be in the same lexical scope as the types that use it. External generic types, even in the same module, create a new scope where the constraint suppression doesn't reach.

### Why Module-Level Types Also Fail

The first attempted workaround was duplicating storage types at module level:

```swift
@usableFromInline
final class __QueueLinkedStorage<Element: ~Copyable>: ManagedBuffer<...> { ... }
```

This failed with the same error. The `Element` in `Queue.Linked` and the `Element` in `__QueueLinkedStorage<Element>` are **different generic parameters** that happen to share a name. The compiler sees them as unrelated. The `~Copyable` suppression on `Queue<Element>` doesn't automatically transfer to `__QueueLinkedStorage<Element>` just because you pass `Element` as a type argument.

This is conceptually similar to how type inference works—generics are resolved at the call site, not at the definition site. The definition of `__QueueLinkedStorage` requires `Element: Copyable` (implicitly), and that requirement must be satisfied when you write `__QueueLinkedStorage<Element>`.

### The Working Pattern

The only pattern that works is nesting the storage types **inside** the type that has the `~Copyable` parameter:

```swift
public struct Queue<Element: ~Copyable>: ~Copyable {
    public struct Linked: ~Copyable {
        struct Header { ... }
        struct Node: ~Copyable {
            var element: Element  // This Element IS the outer Element
        }
        final class Storage: ManagedBuffer<Header, Node> { ... }

        var _storage: Storage  // Works because Storage is nested
    }
}
```

When `Node` references `Element`, it's the **same** `Element` from the enclosing `Queue` type, with its constraint suppression intact. The nesting creates lexical scope inheritance for generic parameters.

### Implications for Library Design

This has significant implications for how move-only container types should be structured:

1. **Storage cannot be shared across container types** via module-level abstractions when supporting `~Copyable`. Each container needs its own nested storage hierarchy.

2. **Code duplication is sometimes necessary**. The Queue.Linked storage is essentially a copy of List.Linked storage, nested differently. This is a workaround for a compiler limitation, not a design choice.

3. **Copyable-constrained variants can still share storage**. `Queue.Linked.Inline` and `Queue.Linked.Small` use `List<Element>.Linked<1>.Inline` because they're constrained to `where Element: Copyable`. The bug only manifests when Element is `~Copyable`.

4. **Document the workaround explicitly**. The code includes prominent comments marking this as temporary, with tracking references for when the compiler is fixed.

### The Experiment That Revealed the Scope

What made this investigation interesting was that standalone experiments in isolation **passed**. A minimal reproduction:

```swift
// In separate experiment package
import List_Primitives

struct TestQueue<Element: ~Copyable>: ~Copyable {
    var _storage: List<Element>.Linked<1>  // WORKS in isolation!
}
```

This compiles. But the **same pattern** inside the full Queue implementation fails. The difference: Queue has other nested types (Bounded, Inline, Small) and a Storage class. The interaction between multiple nested types in a non-empty struct triggers the bug.

This reinforces the value of the [EXP-004a] Incremental Construction methodology—test patterns in isolation, then in increasing complexity, to find exactly where behavior changes.

---

## 2026-01-20: The Hierarchy of ~Copyable Workarounds

*Context: Systematically trying different approaches to fix the Queue.Linked cross-module reference failure.*

### Workarounds Attempted (Failure to Success)

The session tried multiple approaches, each revealing something about the compiler's constraint propagation:

**1. Extension placement (FAILED)**
Moving Queue.Linked to an extension with explicit `where Element: ~Copyable` didn't help. Extensions don't create new constraint contexts—they must satisfy the existing constraints.

**2. Module-level wrapper types (FAILED)**
Creating `__QueueLinkedStorage<Element: ~Copyable>` at module scope fails because the generic parameter is a different `Element` than the one in `Queue<Element>`.

**3. Module-level typealiases (FAILED)**
`typealias __LinkedStorage<Element: ~Copyable> = SomeType<Element>.Nested` fails for the same reason—the typealias parameter isn't the same as the outer type's parameter.

**4. @_exported import (NO EFFECT)**
Re-exporting List_Primitives doesn't change constraint propagation. The bug is about generic parameter identity, not module visibility.

**5. Nested storage types (SUCCESS)**
Defining Header, Node, and Storage as nested types inside Queue.Linked inherits the `Element` parameter with its constraint suppression intact.

### The Lesson About Generic Parameter Identity

Swift's generics aren't just about type constraints—they're about **identity**. When you write:

```swift
struct Outer<T: ~Copyable> {
    struct Inner {
        var value: T  // Same T as Outer
    }
}
```

The `T` in Inner is **the same generic parameter** as in Outer, not a new one that happens to be constrained identically. This identity relationship is what allows the constraint suppression to propagate.

When you instead write:

```swift
struct Helper<T: ~Copyable> { var value: T }

struct Outer<T: ~Copyable> {
    var helper: Helper<T>  // Different T parameters!
}
```

Even though both `T`s are `~Copyable`, they're different generic parameters. The constraint suppression on Outer's `T` doesn't transfer to Helper's `T` when you instantiate `Helper<T>`.

This is consistent with how Swift handles other generic features. Generic specialization, for instance, is based on the **call site's** type arguments, not the definition's constraints.

### When This Bug Will Be Fixed

The bug is tracked as [MEM-COPY-006] Category 3 in the Memory Copyable documentation. The expected fix involves either:
- Cross-module constraint propagation in the type checker
- Or special handling for generic type instantiation with `~Copyable` parameters

Until fixed, the nested type pattern is the only reliable workaround for containers that need to support move-only elements with external storage types.

---

## 2026-01-20: Experiment Investigation as Debugging Methodology

*Context: Using the Pattern Experiment Investigation methodology to isolate the Queue.Linked failure.*

### The Value of Controlled Experiments

The investigation followed [EXP-004a] Incremental Construction—building up complexity to find where behavior changes. The experiment package tested 8 variants:

| Variant | Configuration | Result |
|---------|---------------|--------|
| V1 | Empty enum, cross-module storage | PASS |
| V2 | Struct with no stored properties | PASS |
| V3 | Struct with unrelated property (Int) | PASS |
| V4 | Struct with Storage class | PASS |
| V5 | Nested type in extension | PASS |
| V6 | Nested type in body | PASS |
| V7 | Intermediate local wrapper | PASS |
| V8 | @_exported import | PASS |

All passed. Every variant compiled successfully in isolation.

### The Paradox Resolved

The paradox—why do minimal reproductions pass when the full implementation fails?—resolved when understanding that the bug is **context-sensitive**. The combination of:
- Non-empty struct (Queue has Storage, _storage, _cachedPtr)
- Multiple nested types (Bounded, Inline, Small, Linked)
- Cross-module generic reference in one nested type

...creates conditions that don't exist in isolation. The experiment isolating individual factors couldn't reproduce the failure because it's the **interaction** of factors that triggers it.

### Lessons for Future Investigations

1. **Minimal reproductions can be TOO minimal**. Sometimes you need to reproduce the structural complexity, not just the specific pattern.

2. **When experiments pass but production fails**, the bug is likely context-sensitive. Look at what the production code has that the experiment lacks.

3. **Document what the experiments PROVED**, not just what they tested. The experiments proved that none of the individual factors cause the bug—it's their combination.

4. **Experiments that "fail to reproduce" are still valuable**. They narrow the search space and eliminate hypotheses.

---

## 2026-01-20: Code Duplication as Conscious Technical Debt

*Context: Accepting storage duplication between List.Linked and Queue.Linked as temporary workaround.*

### When Duplication Is The Right Choice

The Queue.Linked storage implementation is a near-copy of List.Linked storage, violating DRY. This was a conscious choice:

1. **The alternative is worse**: Restructuring Queue as an empty enum (like List) would break the semantic model. Queue IS something—a container with state. Making it an empty namespace just to work around a compiler bug inverts the design for the wrong reasons.

2. **The duplication is bounded**: It's a single storage class with clear boundaries. The maintenance burden is documented with explicit comments pointing to the source of truth.

3. **The duplication is temporary**: When the compiler is fixed, the nested storage types can be deleted and Queue.Linked can directly use `List<Element>.Linked<1>`.

4. **The duplication is documented**: Comments at the top of the nested types explain WHY they exist, WHEN to remove them, and WHERE to track the compiler fix.

### The Documentation Strategy

```swift
// ============================================================================
// TEMPORARY WORKAROUND - DO NOT MODIFY WITHOUT CHECKING COMPILER STATUS
// ============================================================================
//
// WHY THIS EXISTS:
// Swift compiler bug [MEM-COPY-006] Category 3...
//
// WHEN TO REMOVE:
// Delete these types when compiler fixes cross-module ~Copyable propagation
//
// MAINTENANCE:
// If List.Linked storage changes, these MUST be updated to match.
// Source of truth: swift-list-primitives/Sources/List Primitives/List.Linked.swift
```

This documentation ensures:
- Future maintainers understand this isn't intentional design
- The workaround can be found and removed when appropriate
- Changes to the source of truth trigger review of the copy

### Principled Technical Debt

Not all technical debt is bad. **Intentional, documented, bounded** debt with clear removal criteria is a legitimate engineering tool. The Queue.Linked storage duplication meets all criteria:

- **Intentional**: Chosen after evaluating alternatives
- **Documented**: Explicit comments explain the situation
- **Bounded**: Limited to one file, one class hierarchy
- **Removal criteria**: Specific compiler fix to track

This is different from accidental debt that accumulates through neglect. Conscious debt with an exit plan is part of pragmatic infrastructure development.

---

## 2026-01-20: The Single-File Workaround for Module Emission Bugs [Package: swift-heap-primitives]

*Context: Discovering that a compiler bug affecting ~Copyable Sequence conformance can be bypassed by consolidating all source files into one.*

### The Discovery Through Elimination

After documenting and filing Swift issue #86669—a compiler bug that breaks Sequence conformance for types with compound generic constraints (`Element: ~Copyable & Protocol`)—the investigation turned to workarounds. The original attempt (moving `borrowing Element` methods to the main file) worked for the minimal reproduction but failed for the full Heap implementation.

The breakthrough came from asking a simple question: "What if we put everything in one file?"

This wasn't a sophisticated architectural insight. It was desperation. But it worked. A 4000-line consolidated file compiles successfully with Sequence conformance enabled, while the same code split across 12 files fails during module emission.

### Why File Boundaries Matter to the Compiler

The bug manifests specifically in the `-emit-module` phase. Module emission processes files in a particular order and builds cross-file relationships. The bug appears to be a constraint propagation failure that occurs when:

1. A nested type has `UnsafeMutablePointer<Element>` where `Element: ~Copyable & Protocol`
2. A conditional `Sequence` conformance exists (`where Element: Copyable`)
3. A separate file contains methods with `(borrowing Element)` closure parameters

When all code is in one file, the constraint solver sees the complete picture in a single pass. When split across files, the module emission phase loses track of the `~Copyable` suppression somewhere in the cross-file linking.

This isn't a lesson about file organization. It's an observation about compiler implementation details leaking through abstractions.

### The Trade-Off Accepted

Consolidating swift-heap-primitives into a single 4084-line file violates [API-IMPL-005] (one type per file). This is explicitly documented as temporary:

```swift
// WORKAROUND: This Sequence conformance only compiles because all source code
// is consolidated into a single file. When the compiler bug is fixed, this
// package can be restructured into multiple files per [API-IMPL-005].
```

The violation is:
- **Intentional**: Chosen to enable Sequence conformance
- **Documented**: Comments explain why and reference the tracking issue
- **Bounded**: One package, clear scope
- **Reversible**: Can split when bug is fixed

Users get `for-in` loops, `map`, `filter`, and all standard Sequence operations. The cost is internal organization that maintainers must navigate carefully.

### The Investigation Pattern That Led Here

The path to this workaround followed the [EXP-004a] methodology:

1. **Isolate**: Created minimal reproduction, confirmed the bug
2. **Document**: Filed Swift issue #86669 with exact trigger conditions
3. **Workaround attempt 1**: Move borrowing methods to main file → FAILED for real codebase
4. **Workaround attempt 2**: Single-file consolidation → SUCCEEDED

The key insight from failed workaround #1: patterns that work in minimal reproductions don't always scale. The real Heap package has complexity that the minimal reproduction lacks. When a workaround works in isolation but fails in context, the context itself is a factor.

---

## 2026-01-20: Category 4 Compiler Bug Discovery

*Context: Identifying a new failure mode beyond the documented MEM-COPY-006 categories.*

### Beyond Known Patterns

The existing documentation ([MEM-COPY-006]) catalogued three categories of `~Copyable` constraint propagation failures:

1. **Category 1**: Nested types in extensions
2. **Category 2**: Implicit Copyable constraints in generic contexts
3. **Category 3**: Cross-module generic type instantiation

The Heap investigation revealed **Category 4**: Module emission phase constraint solver failure with conditional Sequence conformance and borrowing closures in extension files.

This category is distinct because:
- It only manifests during `-emit-module`, not during parse or type-check
- It requires the specific combination of Sequence (not other protocols)
- It requires `borrowing Element` closures in **separate files** (same-file works)
- It requires compound constraints (`~Copyable & Protocol`), not single `~Copyable`

### The Significance of Six Required Conditions

The bug requires ALL of:
1. Compound generic constraint (`Element: ~Copyable & Protocol`)
2. Nested type with `UnsafeMutablePointer<Element>` stored property
3. Conditional Sequence conformance (`where Element: Copyable`)
4. Extension file with `(borrowing Element)` closure parameter
5. Library target (uses `-emit-module`)
6. `-enable-experimental-feature Lifetimes` flag

This specificity is both a curse and a blessing. The curse: it's hard to reproduce and easy to accidentally trigger. The blessing: it's narrowly scoped, so workarounds have room to operate.

### The Documentation Update Needed

The Memory Copyable documentation needs updating to include Category 4. The pattern is now confirmed in production code (Heap) and documented in a filed Swift issue. This adds to the institutional knowledge about what NOT to do with `~Copyable` types until compiler support matures.

---

## 2026-01-20: When Minimal Reproductions Lie

*Context: Discovering that workarounds which pass in isolation fail in production codebases.*

### The Seductive Minimal Reproduction

The first workaround attempt—moving `borrowing Element` methods to the main file—was validated with a minimal reproduction:

```swift
// Container.swift
struct Container<Element: ~Copyable & Ordering>: ~Copyable {
    struct Bounded: ~Copyable { ... }
}
extension Container.Bounded: Sequence where Element: Copyable { ... }

// In SAME file (workaround):
extension Container.Bounded where Element: ~Copyable {
    func withMin<R>(_ body: (borrowing Element) -> R) -> R? { ... }
}
```

This compiled. The minimal reproduction passed. Confidence was high.

Then the workaround was applied to the full Heap package. It failed with the same error. The workaround that "worked" didn't actually work.

### What Minimal Reproductions Can't Capture

The full Heap package has:
- 12 source files (before consolidation)
- Multiple nested types (Bounded, Inline, Small)
- A Storage class with ManagedBuffer inheritance
- Extensive unsafe pointer manipulation
- Multiple extension files with various constraints

The minimal reproduction had:
- 2 source files
- One nested type
- Simple storage
- One borrowing method

The complexity difference matters. The compiler processes these differently. Interactions between multiple nested types, multiple files, and multiple conditional conformances create conditions that don't exist in isolation.

### The Lesson for Future Bug Investigations

1. **Don't trust minimal reproductions for workaround validation**. They validate that the bug exists. They don't validate that a workaround works at scale.

2. **Test workarounds in the actual codebase**. The only reliable test is applying the change and running the full build.

3. **When a workaround fails unexpectedly**, the production code has structural properties the reproduction lacks. Ask: what does the real code have that the test code doesn't?

4. **Document both successes and failures**. The failed workaround attempt is valuable information. It narrows the solution space for future attempts.

---

## 2026-01-20: The Experiment Infrastructure Payoff

*Context: Reflecting on how the Pattern Experiment Investigation methodology accelerated bug isolation.*

### From Hours to Minutes

The Heap bug investigation could have taken days of trial-and-error. Instead, by following [EXP-001] through [EXP-011], the exact trigger conditions were isolated in under an hour:

1. **[EXP-002] Minimal Package**: Created isolated `noncopyable-sequence-bug` experiment
2. **[EXP-004] Binary Search**: Systematically enabled/disabled code blocks
3. **[EXP-005] Isolation**: Tested file placement, constraint variations
4. **[EXP-011] Production Replication**: Verified in actual swift-heap-primitives

The binary search was particularly effective. Starting from "works" (Sequence disabled) and "fails" (Sequence enabled), the investigation narrowed:

- Does removing `borrowing Element` methods fix it? → Yes
- Does moving them to the main file fix it? → In isolation, yes
- Does that fix work in production? → No
- Does consolidating all files fix it? → Yes

Each experiment answered a specific question. No wasted effort exploring irrelevant paths.

### The Investment Repaid

Building the experiment infrastructure (Pattern Experiment.md, Pattern Experiment Investigation.md) took significant effort. That investment repaid itself in this single investigation. The methodology turned an opaque compiler error into a documented bug with filed issue and working workaround.

### Infrastructure Enables Velocity

This is why infrastructure matters. Not for the first time you need it—for every time after. The experiment methodology will be used again for the next compiler bug, the next mysterious failure, the next "it works on my machine."

The lesson isn't about this specific bug. It's about building systems that make future problems tractable.

---

## 2026-01-20: Filing Swift Issues—What Makes a Report Actionable

*Context: Creating swift/issues/86669 following Pattern Issue Submission methodology.*

### The Minimal Reproduction Discipline

The filed issue reduced a 4000-line heap implementation to a 60-line reproduction. This required:

1. **Removing everything unnecessary**: No actual heap operations, just structure
2. **Keeping everything necessary**: All 6 trigger conditions present
3. **Making it copy-pasteable**: Single package, `swift build` reproduces

The result is something a Swift compiler engineer can investigate without understanding heap data structures.

### The Table of Conditions

The issue includes a conditions table:

| # | Condition | Description |
|---|-----------|-------------|
| 1 | Compound constraint | `Element: ~Copyable & Protocol` |
| 2 | Unsafe pointer | `UnsafeMutablePointer<Element>` in nested type |
| 3 | Sequence conformance | Conditional `where Element: Copyable` |
| 4 | Extension file | `borrowing Element` closure in separate file |
| 5 | Library target | Uses `-emit-module` |
| 6 | Lifetimes feature | Experimental feature enabled |

This table serves multiple purposes:
- **Reproducibility**: Anyone can verify each condition
- **Investigation guidance**: Compiler team knows where to look
- **Future discovery**: Others hitting similar issues can compare conditions

### The Verification Matrix

The issue also includes:

| Test | Description | Result |
|------|-------------|--------|
| Parse only | `-parse` flag | ✅ Compiles |
| Single constraint | Remove protocol | ✅ Compiles |
| Custom protocol | Non-Sequence | ✅ Compiles |
| Same-file borrowing | Move method | ✅ Compiles |
| Emit module | `-emit-module` | ❌ Fails |

This matrix proves the bug is specific to module emission, not parsing or type-checking. It narrows the investigation to the emit-module phase.

### What Distinguishes Good Bug Reports

1. **Exact environment**: Swift version, platform, flags
2. **Minimal reproduction**: Smallest code that triggers the bug
3. **Condition isolation**: Which factors are required
4. **Verification evidence**: What was tested, what passed/failed
5. **Impact statement**: Why this matters for real code

The Pattern Issue Submission methodology codifies these requirements. Following it produces issues that get attention and resolution.

---

## 2026-01-20: Workarounds as First-Class Documentation

*Context: Documenting the single-file workaround in production code.*

### The Comment That Matters

```swift
// WORKAROUND: This Sequence conformance only compiles because all source code
// is consolidated into a single file. When the compiler bug is fixed, this
// package can be restructured into multiple files per [API-IMPL-005].
//
// Tracked: https://github.com/swiftlang/swift/issues/86669
```

This comment does four things:

1. **Explains the "why"**: Future readers understand the single-file structure isn't a design choice
2. **References the constraint**: [API-IMPL-005] violation is acknowledged
3. **Provides exit criteria**: "When the compiler bug is fixed"
4. **Links to tracking**: Issue URL for status checking

### Workarounds Without Documentation Are Time Bombs

Undocumented workarounds become permanent. Six months from now, someone might try to "clean up" the single-file structure, not knowing it's load-bearing. They'll split the files, the build will break, and they'll spend hours rediscovering what we learned today.

The comment prevents this. It's not about explaining the code—it's about explaining why the code looks wrong but shouldn't be changed.

### The Broader Pattern

Every workaround in the codebase should follow this pattern:

```swift
// WORKAROUND: [What this works around]
// WHY: [Why normal approach doesn't work]
// WHEN TO REMOVE: [Specific removal criteria]
// TRACKING: [Issue URL or internal reference]
```

This transforms workarounds from technical debt into managed constraints with clear lifecycles.

---

## 2026-01-20: The Accessor Pattern Boundary [Package: swift-heap-primitives]

*Context: Attempting to unify Heap API by replacing compound methods (`takeMin()`, `popMin()`) with accessor patterns (`heap.take.min`, `heap.pop.min()`) per [API-NAME-002].*

### The Fundamental Constraint

The nested accessor pattern requires an accessor struct that holds a reference to the container:

```swift
public struct Take {
    var heap: Heap<Element>.Bounded  // Must hold the container
}
```

For a `~Copyable` container, this is impossible. The accessor struct needs to store the container, but storing a `~Copyable` value requires the accessor itself to be `~Copyable`. A `~Copyable` accessor defeats the purpose—accessors need to be freely passable as intermediate values.

The [MEM-COPY-005] documentation predicted this exactly:

> "Non-consuming nested accessor patterns are fundamentally incompatible with `~Copyable` containers. The accessor struct must store a reference to the container, which requires copying—impossible for `~Copyable` types."

### The Class Storage Red Herring

`Heap.Bounded` uses class-based storage (`ManagedBuffer`), which initially suggested the accessor pattern might work. The reasoning: "The Storage class is a reference type, so the Bounded struct is lightweight and should be copyable."

This reasoning is wrong. The Bounded struct is declared `~Copyable`:

```swift
public struct Bounded: ~Copyable { ... }
```

Even with class-based storage, the struct itself is `~Copyable` to support `~Copyable` elements. The struct becomes `Copyable` only when `Element: Copyable` via conditional conformance. For `~Copyable` elements, the container is `~Copyable`, and the accessor pattern fails.

### The Documentation Consultation Failure

The documentation already contained the answer. [MEM-COPY-005] explicitly describes this limitation with a decision table:

| Form | Ownership | ~Copyable Compatible |
|------|-----------|---------------------|
| Consuming | Transfers ownership | ✅ Yes |
| Non-consuming | Borrows or copies | ❌ No |

The accessor pattern is non-consuming—it borrows the container. This is exactly the pattern documented as incompatible.

The session spent significant effort implementing, debugging, and analyzing compiler errors before consulting the documentation. The documentation would have prevented the entire detour.

### The Decision: Accept Compound Methods

For `~Copyable` containers, compound methods (`takeMin()`, `popMin()`) remain the correct pattern. This violates [API-NAME-002] (no compound identifiers), but [MEM-COPY-005] provides the exception:

> "For `~Copyable` containers requiring the nested accessor pattern, choose one:
> 1. Keep container Copyable - Accept that ~Copyable elements aren't supported
> 2. Use direct methods - `container.peekBack()` instead of `container.peek.back`
> 3. Wait for language evolution"

Option 2 is the only viable choice for heap variants that support `~Copyable` elements.

---

## 2026-01-20: When the Documentation Predicts Your Failure

*Context: Discovering that attempted API unification was already documented as impossible.*

### The Cost of Skipped Documentation

The session followed this path:

1. Identified API inconsistency (accessor pattern in base Heap, compound methods in variants)
2. Designed solution (add accessors to all variants)
3. Implemented solution (Pop/Take structs with accessor properties)
4. Hit compiler errors (cannot hold `~Copyable` container in Copyable struct)
5. Attempted workarounds (swap-based mutation, shared storage)
6. All workarounds failed
7. Finally read [MEM-COPY-005]
8. Found the exact limitation documented with explanation and alternatives

Steps 2-6 were unnecessary. The documentation existed specifically to prevent this exploration.

### Why We Didn't Check First

The assumption was that the accessor pattern "should work" for `Heap.Bounded` because:
- It has class-based storage (reference semantics)
- The base `Heap` type successfully uses accessors
- The pattern feels natural and consistent

These assumptions masked the fundamental constraint: the container struct's copyability, not its storage mechanism, determines accessor compatibility.

### The Pattern for Future Work

Before attempting to unify or standardize APIs across types with different constraint profiles:

1. **Check [MEM-COPY-005]** for `~Copyable` container patterns
2. **Identify the container's copyability**: Is it unconditionally `~Copyable`, conditionally `Copyable`, or always `Copyable`?
3. **Match the API pattern to the constraint**: Accessor patterns for `Copyable` containers, direct methods for `~Copyable` containers

The documentation routing table in CLAUDE.md includes this:

| Task | Primary Document |
|------|------------------|
| ~Copyable/move-only types | `Memory Copyable.md` |

Future API unification attempts should start here.

---

## 2026-01-20: Accessor Patterns and Container Identity

*Context: Understanding why different Heap variants require different API patterns.*

### The Heap Type Family

The Heap package provides multiple container variants:

| Variant | Storage | ~Copyable? | Accessor Pattern? |
|---------|---------|------------|-------------------|
| `Heap` (base) | Class-based (CoW) | Conditional | ✅ Yes |
| `Heap.Bounded` | Class-based | Conditional | ❌ No (struct is ~Copyable) |
| `Heap.Inline` | Inline | Always | ❌ No |
| `Heap.Small` | Hybrid | Always | ❌ No |

The base `Heap` type has conditional copyability that aligns with its accessor pattern. When `Element: Copyable`, the heap is copyable and accessors work. When `Element: ~Copyable`, the heap provides different API entry points (borrowing closures like `withMin`).

The variants are different. `Heap.Bounded` declares `~Copyable` on the struct even though storage is class-based. `Heap.Inline` and `Heap.Small` have inline storage requiring deinit, making them unconditionally `~Copyable`.

### The API Divergence Is Intentional

Initially, the compound methods in variants appeared to be inconsistency needing correction. Understanding the constraint reveals they're intentional:

- **Base Heap**: Accessor pattern works because the container is `Copyable` when elements are
- **Variants**: Compound methods required because containers are `~Copyable` by design

The divergence reflects the underlying type constraints, not oversight.

### Implications for Documentation

The Heap documentation should explain:

1. Why base `Heap` uses `heap.take.min` but variants use `heap.takeMin()`
2. That this isn't inconsistency but constraint-driven design
3. That code working with `~Copyable` elements should expect direct methods

This isn't a "gotcha" to document—it's the correct design given Swift's current ownership model.

---

## 2026-01-20: The Value of Failing Fast with Compiler Errors

*Context: How compiler errors revealed the constraint before runtime testing.*

### Errors as Design Feedback

The attempt to add accessor patterns to `Heap.Bounded` produced this error:

```
error: stored property 'heap' of 'Copyable'-conforming struct 'Pop'
has non-Copyable type 'Heap<Element>.Bounded'
```

This error is precise and informative. It states exactly why the design fails:
- The `Pop` struct is `Copyable` (implicitly)
- It holds `Heap<Element>.Bounded`
- That type is `~Copyable` (for `~Copyable` elements)
- Contradiction: cannot hold non-copyable in copyable

The compiler prevented a design that would have failed at runtime or, worse, silently broken move-only element support.

### The Alternative Path

Without this error, the implementation might have "worked" by:
- Only supporting `Copyable` elements in the accessor pattern
- Silently dropping `~Copyable` support
- Creating a subtle API inconsistency where accessors exist but don't work for all element types

The error forced confrontation with the fundamental constraint early, before such compromises accumulated.

### Compiler Errors as Documentation

The error message effectively documents the constraint:

> struct 'Bounded' has '~Copyable' constraint preventing 'Copyable' conformance

This is the same insight as [MEM-COPY-005], expressed in compiler diagnostic form. Swift's error messages for ownership violations often contain the conceptual explanation alongside the technical failure.

---

## 2026-01-20: Experiments as Institutional Memory [Package: swift-heap-primitives]

*Context: Creating the `noncopyable-accessor-pattern` experiment package after discovering the accessor pattern limitation.*

### The Retroactive Experiment

The investigation discovered the accessor pattern limitation through production code failure, not through systematic experimentation. The experiment package was created *after* the conclusion was reached, as a way to preserve the finding.

This inversion—conclusion first, experiment second—is valid. The experiment serves as:

1. **Reproducible proof**: Anyone can verify the limitation by uncommenting the failing code
2. **Future reference**: When Swift's ownership model evolves, the experiment can be re-run
3. **Onboarding documentation**: New contributors understand why compound methods exist
4. **Issue filing support**: If filing a Swift issue, the experiment is ready

### The Structure That Preserves Knowledge

The experiment uses a specific structure:

```
noncopyable-accessor-pattern/
├── Package.swift
└── Sources/
    ├── main.swift              # Working code (V1, V2 workaround, V3 workaround)
    └── error-demo.swift.txt    # Failing code with captured compiler output
```

The `.swift.txt` extension is intentional. It preserves the exact failing code and compiler output without breaking the build. Renaming to `.swift` reproduces the error on demand.

### Why Both Files Matter

`main.swift` proves the positive cases work—Copyable containers with accessors compile and run. This establishes that the accessor pattern itself is sound; the limitation is specifically about `~Copyable` containers.

`error-demo.swift.txt` preserves the exact error messages. Compiler diagnostics change between versions. Capturing the output means the experiment remains useful even if future Swift versions change the error text.

### The Incremental Construction Record

The experiment documents the [EXP-004a] methodology even though it was applied mentally during debugging:

| Variant | Configuration | Result |
|---------|---------------|--------|
| V1 | Copyable container + accessor | PASS |
| V2 | ~Copyable container + accessor | FAIL |
| V3 | Conditional Copyable + accessor in ~Copyable context | FAIL |

This table in `main.swift`'s header makes the investigation reproducible. Someone encountering this experiment can understand the progression without reading the full code.

---

## 2026-01-20: The Value of "Obvious" Experiments

*Context: Creating an experiment for a limitation already documented in [MEM-COPY-005].*

### When Documentation Isn't Enough

[MEM-COPY-005] states the limitation clearly:

> "Non-consuming nested accessor patterns are fundamentally incompatible with `~Copyable` containers."

Why create an experiment for something already documented? Because:

1. **Documentation describes; experiments prove.** The document says it's impossible. The experiment shows *exactly why* with compiler output.

2. **Documentation is trusted; experiments are verified.** If [MEM-COPY-005] contained an error, the experiment would reveal it.

3. **Documentation is abstract; experiments are concrete.** The experiment shows the actual types, the actual error, the actual workaround.

### The Experiment as Living Documentation

Documentation can become stale. The experiment is executable:

```bash
cd Experiments/noncopyable-accessor-pattern
swift build  # Works with current code
mv Sources/error-demo.swift.txt Sources/error-demo.swift
swift build  # Fails with documented error
```

If a future Swift version changes the behavior, running the experiment reveals it immediately. The documentation might not be updated; the experiment fails or succeeds definitively.

### Experiment Granularity

This experiment tests one specific question: "Can the accessor pattern work with `~Copyable` containers?" It doesn't test:

- Whether compound methods work (that's production code's job)
- Whether `~Copyable` works in general (other experiments cover that)
- Whether [MEM-COPY-005] is complete (it covers multiple patterns)

Single-question experiments are more valuable than comprehensive ones. They're easier to understand, faster to run, and clearer when they fail.

---

## 2026-01-20: Retroactive Protocol Compliance

*Context: Creating experiment artifacts after the fact to match the Pattern Experiment Investigation methodology.*

### The Honest Sequence

The actual sequence was:

1. Attempted to unify Heap API with accessor pattern
2. Hit compiler errors
3. Tried workarounds (swap-based mutation, shared storage)
4. All failed
5. Read [MEM-COPY-005]
6. Accepted compound methods
7. Created experiment to document finding

The methodology ([EXP-001] through [EXP-011]) prescribes:

1. Hit uncertainty
2. Create experiment
3. Test hypothesis
4. Document result
5. Apply to production

The actual sequence inverted steps 2-4 with steps 5-6. Production was attempted first; the experiment was created to preserve the finding.

### Why Retroactive Experiments Are Valid

The methodology is prescriptive for efficiency, not for validity. Creating the experiment first would have saved debugging time. But the experiment created afterward has the same value:

- Same reproducible proof
- Same institutional memory
- Same future reference utility

The difference is cost, not outcome. The finding is valid regardless of when it was formalized.

### The Meta-Lesson

Process exists to prevent wasted effort. Following it saves time. But not following it doesn't invalidate the result—it just means the result cost more to achieve.

The reflection entries document both the finding AND the process deviation. Future work benefits from both: the technical insight (accessor patterns don't work for `~Copyable`) and the process insight (check [MEM-COPY-005] before attempting such changes).

---

## 2026-01-20: The Typealias Migration Pattern [Package: swift-tree-primitives]

*Context: Refactoring Tree.Binary to be a typealias for Tree.N<Element, 2>, completing the migration from specialized binary tree to parameterized n-ary tree.*

### The Backward Compatibility Insight

When consolidating specialized types into parameterized generics, the typealias provides a clean migration path:

```swift
extension Tree {
    public typealias Binary<Element: ~Copyable> = Tree.N<Element, 2>
}
```

This single line preserves all existing `Tree.Binary<Int>` usage while the underlying implementation moves to `Tree.N<Element, 2>`. The old API surface remains valid; existing tests pass unchanged. The typealias is the final step after implementation consolidation, not a parallel compatibility layer maintained alongside the old code.

The pattern works because typealiases are resolved at compile time—there's no runtime cost, no wrapper overhead, no version compatibility matrix. Code written against `Tree.Binary` automatically uses `Tree.N<2>` without modification.

### Position Types Require Migration

The one wrinkle: nested types don't alias automatically. `Tree.Binary<Int>.Position` doesn't exist after the migration because `Position` was hoisted to `Tree.Position` (shared across all tree arities). This requires explicit migration in client code:

```swift
// Before
var positions: [Tree.Binary<Int>.Position] = []

// After
var positions: [Tree.Position] = []
```

The change is mechanical but cannot be papered over with typealiases. The hoisting of `Position` to `Tree.Position` was the correct design decision—positions are tree-agnostic—but it creates a migration step for any code that used the nested type path.

### The Delete-Then-Create Sequencing

The migration followed a specific sequence:

1. Create all `Tree.N.*` variants (Bounded, Inline, Small, Traversal)
2. Migrate tests from `Tree.Binary` to `Tree.N<2>`
3. Verify tests pass with `Tree.N`
4. Delete old `Tree.Binary.*` implementation files
5. Create `Tree.Binary.swift` containing only the typealias

Step 5 reuses the filename of the deleted implementation. This means the typealias file has the same path as the old implementation, which could confuse git history but keeps the logical association between `Tree.Binary` and its definition file.

The alternative—keeping both old and new implementations during transition—was rejected. Parallel implementations diverge, create confusion, and double maintenance burden. The clean break (delete then recreate) forced complete migration rather than gradual rot.

---

## 2026-01-20: Post-Order Traversal and the Rightmost Child Heuristic [Package: swift-tree-primitives]

*Context: Fixing a broken post-order traversal algorithm that returned incorrect ordering for n-ary trees.*

### The Failure Mode

The original `Tree.N` post-order algorithm tracked "unvisited children" using a complex loop:

```swift
// BROKEN: Find first unvisited child from left
for slot in 0..<n {
    if childIndices[slot] >= 0 && !visited[childIndices[slot]] {
        // Push and continue
    }
}
```

This approach failed subtly. The `visited` set grew correctly, but the algorithm re-pushed already-visited children in certain tree configurations, producing incorrect traversal orders like `[3, 1]` instead of `[4, 5, 2, 3, 1]`.

The bug was difficult to diagnose because:
1. Pre-order and level-order (which don't need backtracking) worked correctly
2. Simple trees (single children) traversed correctly
3. Only complete or near-complete trees with multiple children exposed the bug

### The Rightmost Child Heuristic

The fix replaced tracking with a simpler heuristic: process the current node if we just came from its rightmost child:

```swift
let cameFromRightmost = rightmostChildIndex >= 0 && rightmostChildIndex == lastVisited

if isLeaf || cameFromRightmost {
    _ = pending.pop()
    process(current)
    lastVisited = current
}
```

This works because post-order requires visiting all children before the parent. If we're at the parent and just visited its rightmost child, we've necessarily visited all children (we push children right-to-left, so rightmost is processed last).

The heuristic is simpler, faster (no visited set), and correct. It mirrors how humans think about post-order: "go left as far as possible, then right, then up."

### Consistency Across Implementations

The fix had to be applied in four locations:
1. `Tree.N.swift` - `forEachPostOrder` method
2. `Tree.N.swift` - `removeSubtree` method (uses post-order for safe deallocation)
3. `Tree.N.swift` - `Storage.deinit` (uses post-order for ~Copyable element cleanup)
4. `Tree.N.Traversal.swift` - `PostOrderIterator.next()`

All four used the same flawed algorithm. All four needed the same fix. This is a classic DRY violation—the algorithm should be defined once—but the ownership constraints of ~Copyable types make shared iteration difficult. Each context has different requirements:

- `forEachPostOrder`: Borrows elements
- `removeSubtree`: Consumes elements
- `Storage.deinit`: Deinitializes elements
- `PostOrderIterator`: Copies elements (Copyable constraint)

The duplication is unfortunate but necessary given current language constraints.

---

## 2026-01-20: Parameterized Arity as Design Consolidation [Package: swift-tree-primitives]

*Context: Completing the refactor from Tree.Binary (specialized) to Tree.N<n> (parameterized) as the single tree implementation.*

### The Consolidation Payoff

Before: Two separate implementations with duplicated code:
- `Tree.Binary` - Fixed arity of 2, complete implementation
- `Tree.N<n>` - Parameterized arity, parallel implementation

After: One implementation with convenience alias:
- `Tree.N<Element, n>` - Single source of truth for all arities
- `Tree.Binary<Element>` - Typealias for `Tree.N<Element, 2>`

The consolidation eliminated approximately 1200 lines of redundant code (net reduction of 1230 lines in the commit). More importantly, it eliminated a maintenance divergence vector. Bug fixes to `Tree.N` automatically apply to binary trees.

### When Specialization Is Warranted

The parameterized approach wins for tree primitives because:

1. **Algorithm uniformity**: Pre-order, post-order, level-order work identically for any arity
2. **Storage uniformity**: Arena allocation, position tokens, parent tracking are arity-independent
3. **API uniformity**: Insert, remove, peek, navigation have the same semantics

Specialization would be warranted if binary trees had fundamentally different:
- Performance characteristics requiring different algorithms
- Storage layouts that couldn't generalize
- API semantics that don't extend to n-ary

None of these apply. The only binary-specific feature is in-order traversal (left-root-right), which is provided via constrained extension `where n == 2`.

### The InlineArray Enabler

The parameterization depends on `InlineArray<n, Int>` for child index storage:

```swift
struct Node: ~Copyable {
    var element: Element
    var childIndices: InlineArray<n, Int>  // Fixed-size array of n children
    var parentIndex: Int
}
```

Without `InlineArray`, child indices would require either:
- Heap-allocated array (performance cost)
- Unsafe buffer pointer (complexity cost)
- Manual unrolling for each supported arity (maintenance cost)

The `InlineArray` generic parameter `let n: Int` matches the tree's arity parameter, making the storage layout statically determined. This is a case where dependent types (even Swift's limited form) enable designs that would otherwise require code generation.

---

## 2026-01-20: The Variant Proliferation Pattern [Package: swift-tree-primitives]

*Context: Creating Bounded, Inline, and Small variants for Tree.N matching the pattern established by Tree.Binary.*

### Why Three Variants

Each variant serves a distinct use case:

| Variant | Storage | Capacity | Copy Behavior | Use Case |
|---------|---------|----------|---------------|----------|
| `Tree.N` | Heap (CoW) | Unbounded | Copy-on-write | General purpose |
| `Tree.N.Bounded` | Heap (fixed) | Capped | ~Copyable | Bounded memory |
| `Tree.N.Inline` | Inline | Fixed | ~Copyable | Stack allocation |
| `Tree.N.Small` | Inline + spill | Hybrid | ~Copyable | Small trees fast, large possible |

The variants aren't premature optimization—they're distinct semantic choices. `Bounded` guarantees memory limits. `Inline` guarantees no heap allocation (for small trees). `Small` provides the common case optimization with unbounded fallback.

### The Shared Position Type

All variants share `Tree.Position` (hoisted to the Tree namespace):

```swift
public struct Position: Copyable, Sendable {
    var index: Int
    var token: UInt32
}
```

Position validity is variant-specific (each tracks its own tokens), but the representation is shared. This enables generic code that works with any tree variant:

```swift
func processTree<T: TreeProtocol>(tree: T, at position: Tree.Position) { ... }
```

If Position were variant-specific, generic tree algorithms would need phantom type parameters to track which Position matches which tree.

### The Error Type Hoisting Pattern

Each variant has its own error type hoisted to module level:

```swift
public struct __TreeNBoundedError: Error { ... }
public struct __TreeNInlineError: Error { ... }
public struct __TreeNSmallError: Error { ... }
```

The double-underscore prefix and hoisting serve two purposes:

1. **Generic constraint propagation**: Nested error types inside `~Copyable` types inherit that constraint, making them unusable with standard error handling
2. **API clarity**: The underscores signal "implementation detail, not public API"

This pattern appears throughout the primitives layer—any type nested inside a `~Copyable` generic must be hoisted if it needs to be `Copyable` (as errors must be for `throws`).

---

## 2026-01-20: The n==2 Extension Pattern [Package: swift-tree-primitives]

*Context: Providing binary-tree-specific API (left/right, in-order traversal) via constrained extensions.*

### Convenience Without Specialization

Binary trees have semantically meaningful child slots: left and right. N-ary trees have indexed slots. The constrained extension bridges these:

```swift
extension Tree.N where n == 2 {
    public func left(of position: Tree.Position) -> Tree.Position? {
        child(of: position, slot: .init(0))
    }

    public func right(of position: Tree.Position) -> Tree.Position? {
        child(of: position, slot: .init(1))
    }
}
```

The `where n == 2` constraint ensures these methods only exist for binary trees. A `Tree.N<Int, 4>` doesn't have `.left(of:)`—it has `.child(of:slot:)` with slots 0-3.

Similarly, in-order traversal (left-root-right) is meaningfully defined only for binary trees:

```swift
extension Tree.N where n == 2 {
    public var inOrder: InOrderSequence { ... }
    public func forEachInOrder(_ body: (Element) throws -> Void) rethrows { ... }
}
```

### The InsertPosition Parallel

The same pattern applies to `InsertPosition`:

```swift
extension Tree.N.InsertPosition where n == 2 {
    public static func left(of position: Tree.Position) -> Self {
        .child(of: position, slot: .init(0))
    }

    public static func right(of position: Tree.Position) -> Self {
        .child(of: position, slot: .init(1))
    }
}
```

This enables the familiar binary tree insertion syntax:

```swift
let left = try tree.insert(2, at: .left(of: root))
let right = try tree.insert(3, at: .right(of: root))
```

While the general n-ary syntax remains available:

```swift
let child = try tree.insert(2, at: .child(of: root, slot: .init(0)))
```

### Conditional API as Documentation

The constrained extensions serve as implicit documentation. By seeing that `.left(of:)` only exists when `n == 2`, the API communicates that left/right are binary-tree concepts. No documentation needed—the type system encodes the constraint.

---

## 2026-01-20: Dependency Graph Fragility in Monorepo Development

*Context: Build failures in swift-stack-primitives blocking swift-tree-primitives builds.*

### The Cascade Effect

During the tree-primitives refactor, builds failed with errors in swift-stack-primitives—a dependency, not the package being modified. The errors were unrelated to tree code:

```
error: type 'Element' does not conform to protocol 'Copyable'
  Stack.Index.swift:32
```

The tree-primitives refactor didn't touch stack-primitives. But local path dependencies mean `swift build` compiles the entire dependency graph. A bug introduced elsewhere blocks all downstream work.

### The Transient Nature

The errors appeared after one build, then disappeared on the next. This suggests either:
1. Incremental build state corruption
2. Race condition in parallel compilation
3. Toolchain caching inconsistency

The resolution—running `swift package clean` and rebuilding—is the standard fix for mysterious compilation failures. But it highlights how local development with path dependencies differs from pinned version dependencies.

### Implications for Development Workflow

When working in a monorepo with local path dependencies:

1. **Expect transient failures**: Not all build errors indicate code problems
2. **Clean builds resolve mysteries**: When errors don't match your changes, clean and rebuild
3. **Dependency bugs block work**: A broken dependency must be fixed before downstream progress
4. **Version pinning isolates**: Production builds should use pinned versions, not path dependencies

The tree-primitives work could proceed once the transient stack-primitives errors cleared. But if those errors had been real bugs, tree-primitives development would have been blocked until stack-primitives was fixed—even though the two packages have minimal logical coupling.

---

## 2026-01-20: Test Migration as Verification [Package: swift-tree-primitives]

*Context: Migrating tests from Tree.Binary to Tree.N<2> to verify the refactor.*

### The Migration Checklist

Converting Tree.Binary tests to Tree.N<2> required systematic changes:

| Before | After |
|--------|-------|
| `Tree.Binary<Int>` | `Tree.N<Int, 2>` |
| `Tree.Binary<Int>.Position` | `Tree.Position` |
| `Tree.Binary<Int>.Bounded` | `Tree.N<Int, 2>.Bounded` |
| `Tree.Binary<Int>.Small<8>` | `Tree.N<Int, 2>.Small<8>` |
| `__TreeBinaryError` | `__TreeNError` |
| `__TreeBinaryBoundedError` | `__TreeNBoundedError` |

Each change is mechanical. The test logic—what's being verified—remains identical. This mechanical nature is the point: if the refactor is correct, the tests should pass with only name changes.

### Tests That Revealed Bugs

The post-order traversal bug was caught by test migration, not by implementation review:

```swift
// Expected: [4, 5, 2, 3, 1] (post-order: children before parent)
// Actual:   [3, 1]          (broken algorithm skipped subtree)
```

The test existed in Tree.Binary tests. The test passed for Tree.Binary. The test failed for Tree.N<2>. This proved the implementations weren't equivalent—the Tree.N post-order algorithm was buggy.

Without test migration, this bug might have shipped. The typealias would mask it: `Tree.Binary` code would silently use broken `Tree.N` traversal.

### The 65-Test Suite

After migration, the combined suite has 65 tests across 9 suites:

- Tree.N<2> core tests (49 tests)
- Tree.Binary.Performance tests (16 tests)

All passing confirms:
1. Tree.N<2> is behaviorally equivalent to the old Tree.Binary
2. The typealias provides backward compatibility
3. Performance characteristics are preserved

The test suite is now the specification. Any future change that breaks these tests breaks the contract.

---

## 2026-01-20: The ~Copyable Sendable Dance [Package: swift-tree-primitives]

*Context: Adding Sendable conformance to Tree.N.Small after test failures.*

### The Conformance Challenge

`Tree.N.Small` failed Sendable checks in tests:

```
error: type 'Tree.N<Int, 2>.Small<4>' does not conform to protocol 'Sendable'
```

The struct contains:
- `InlineArray<inlineCapacity, InlineNode>` - value type, sendable if InlineNode is
- `Tree.N<Element, n>.Storage?` - optional class reference
- Unsafe cached pointers

The unsafe pointers and optional class reference require `@unchecked Sendable`:

```swift
extension Tree.N.Small: @unchecked Sendable where Element: Sendable {}
```

### Why @unchecked Is Correct Here

The `@unchecked` is justified because:

1. **Storage class is not shared**: Each Small instance owns its Storage exclusively (no CoW sharing)
2. **Cached pointers are derived**: They're computed from owned storage, not independent references
3. **Access is synchronized by value semantics**: The struct is `~Copyable`, preventing concurrent access to the same instance

The unsafe internals don't violate Sendable semantics because the type's ownership model prevents the scenarios where unsafety would manifest.

### The Conditional Conformance Pattern

```swift
extension Tree.N.Small: @unchecked Sendable where Element: Sendable {}
```

This pattern—conditional Sendable with @unchecked—appears throughout container types with unsafe internals:

- `Stack.Small`: Same pattern
- `Queue.Linked`: Same pattern
- `Heap.Bounded`: Same pattern

The `where Element: Sendable` constraint is essential. A `Tree.N<NonSendableType, 2>.Small<4>` should not be Sendable, even with @unchecked on the container. The constraint propagates the element's sendability requirement.

---

## 2026-01-21: The Category Error Between Physical and Semantic Properties [Package: swift-primitives]

*Context: Creating the `re-accessor-bitwisecopyable` experiment to verify claims from the BitwiseCopyable analysis document.*

### The Orthogonality Insight

The session's central discovery is a category error in Swift's current type system: `BitwiseCopyable` (a physical property describing memory layout) is conflated with lifetime independence (a semantic property describing value validity). These concerns operate at different levels of abstraction and should be composable, not mutually exclusive.

A `Span<T>` containing a pointer and an integer is 16 bytes that can be memcpy'd—this is useful information for the optimizer. That same `Span<T>` has lifetime dependencies on the memory it references—this is useful information for the borrow checker. Neither fact implies nor contradicts the other. Yet the compiler currently refuses to infer lifetime dependencies on `_read` accessors when the containing type is `BitwiseCopyable`.

The experiment verified this with a simple test matrix: `ArrayBuffer` (contains `[Int]`, not BitwiseCopyable) allows lifetime inference on `_read`. `TrivialBuffer` (contains only `Int`, BitwiseCopyable) blocks inference. Adding an unused `[Int]` member to `TrivialBuffer` enables inference—a semantically absurd workaround that reveals the underlying design flaw.

### Why This Matters for Primitives

The primitives layer frequently deals with types that are both bitwise-trivial and lifetime-bound. `Input.Access`, `Input.Remove`, and similar accessor types hold pointers to their parent containers. These pointers are physically trivial (8 bytes, memcpy-able) but semantically constrained (only valid while the parent exists).

The current workaround—ensuring containers have non-BitwiseCopyable members like `Array`—works accidentally. `Input.Buffer` stores `[Element]`, which prevents BitwiseCopyable inference, which enables lifetime inference on accessors. This is fragile: a future optimization to inline storage could break the entire accessor pattern without any obvious connection between the changes.

### The Compiler Gap

The investigation also confirmed that `@_lifetime` annotations cannot be applied to `_read` accessors. The compiler demands explicit lifetime annotation for BitwiseCopyable types but provides no syntax to supply it. This is a language gap: either the annotation syntax should be extended to accessors, or the inference restriction should be relaxed, or `~BitwiseCopyable` should exist as an opt-out.

---

## 2026-01-21: Implicit Inference as Hidden Constraint

*Context: Understanding why BitwiseCopyable creates problems despite being an optimization feature.*

### The Inference Trap

`BitwiseCopyable` conformance is inferred, not declared. The compiler examines a struct's members, determines it could be copied bitwise, and implicitly adds the conformance. This invisible conformance then triggers visible restrictions—lifetime inference is blocked, and the programmer receives an error demanding an annotation they cannot provide.

This is a general anti-pattern: implicit inference that creates user-facing constraints. The programmer didn't ask for `BitwiseCopyable`. They might not know it exists. Yet they're now blocked by a requirement that stems from it.

Compare with `Sendable` inference: the compiler also infers `Sendable` for simple structs, but this inference *enables* rather than *restricts*. An inferred Sendable struct can be used in more contexts. An inferred BitwiseCopyable struct can be used in fewer contexts (specifically, fewer lifetime-dependent contexts).

### The Opt-Out Principle

The session reinforced a principle: when inference creates restrictions, opt-out must exist. Swift provides `@unchecked Sendable` when the compiler's analysis is too conservative. There's no `~BitwiseCopyable` to suppress the inference. The only workaround is structural—adding dummy members that break the inference—which pollutes the type's interface to work around a type system limitation.

This suggests a language evolution direction: `~BitwiseCopyable` as explicit opt-out, parallel to `~Copyable` and `~Escapable`. Types that need lifetime dependencies but happen to have trivial physical layout could suppress the inference and proceed with normal borrow-checker analysis.

---

## 2026-01-21: Experiment Discovery as Claim Verification

*Context: Applying [EXP-015] Claim Verification methodology to validate the bitwisecopyable-analysis.md document.*

### From Analysis to Evidence

The `bitwisecopyable-analysis.md` document made several testable claims about compiler behavior. The session transformed those claims into executable experiments:

| Claim | Verification Method | Result |
|-------|---------------------|--------|
| BitwiseCopyable blocks inference | Compile TrivialBuffer.access | VERIFIED |
| Non-BitwiseCopyable allows inference | Compile ArrayBuffer.access | VERIFIED |
| Dummy member enables inference | Compile TrivialBufferWithDummy.access | VERIFIED |
| @_lifetime syntax unavailable | Attempt annotation on _read | VERIFIED |

Each claim became a code block that either compiles or doesn't. The experiment is now executable evidence: anyone can run `swift build` and verify the claims independently.

### The Living Documentation Value

The experiment outlives the analysis document. If a future Swift version changes BitwiseCopyable behavior—either fixing the issue or changing the error messages—the experiment will reveal it immediately. The analysis document might go stale; the experiment cannot lie.

This reinforces the [EXP-015] methodology: testable claims deserve experiments, even when the claims seem obvious or are already documented. The experiment converts assertion into proof.

### The Negative Space Test

The experiment includes commented-out code for claims that produce compiler errors. This "negative space" testing—code that should fail—is as valuable as positive tests. The comments capture the exact error message, creating a snapshot of compiler behavior that can be compared against future versions.

---

## 2026-01-21: The Value Proposition of BitwiseCopyable

*Context: Explaining BitwiseCopyable's purpose after encountering its limitations.*

### Optimization, Not Semantics

The session required articulating what BitwiseCopyable actually provides:

1. **Bulk copy optimization**: `memcpy` instead of element-wise initialization
2. **Generic specialization**: Functions constrained to BitwiseCopyable generate tighter code
3. **ABI documentation**: Stable memory layout for FFI and serialization
4. **Unsafe code soundness**: `copyMemory` operations are provably correct

None of these benefits require blocking lifetime inference. The optimization value is orthogonal to the ownership semantics. A Span can be both memcpy-optimizable and lifetime-constrained.

### The Design Space

The session revealed four quadrants that should all be expressible:

| | Lifetime-bound | Lifetime-independent |
|---|----------------|----------------------|
| **BitwiseCopyable** | Span, Buffer views | Int, primitives |
| **Not BitwiseCopyable** | MutableRef | Array, String |

Current Swift collapses the top-left quadrant. Types that are physically trivial but semantically lifetime-bound require workarounds. This is where primitives frequently operate—lightweight accessor types that borrow from containers.

Understanding the value proposition clarified what's wrong: BitwiseCopyable provides genuine value, but that value shouldn't come with semantic restrictions unrelated to its purpose.

---

## 2026-01-21: The Generalized Accessor Pattern — A Foundational Primitive [Package: swift-identity-primitives]

*Context: Refactoring swift-input-primitives to achieve `Input.Access.Random` naming while preserving `input.access` as the accessor property name. This led to discovering a generalized pattern for borrowing views with phantom type discrimination.*

> **CRITICAL AUDIT REQUIRED**: This reflection documents an extremely high-value architectural insight. All existing accessor-related documentation across Swift Institute and swift-primitives MUST be audited and rewritten to reflect this new `Accessor<Base, Tag>` pattern. This is not incremental improvement—it's a foundational primitive that changes how accessor patterns are implemented.

### The Discovery

The session began with a naming problem: `Input.Random` reads as "a random input" when semantically it means "random access to input." The goal was `Input.Access.Random` for the protocol. But `Input.Access` was a generic struct serving as the accessor, and Swift doesn't allow protocols nested in generic types.

The naive solutions—separate `Tag` enums, `__` hoisted protocols—all felt wrong. The breakthrough came from asking: "Can we generalize the accessor struct itself and use the namespace enum as the phantom type tag?"

This led to `Accessor<Base, Tag>` in identity-primitives: a `~Copyable, ~Escapable` borrowing view discriminated by phantom type. The namespace enum (`Input.Access`, `Input.Remove`, `Input.Restore`) serves double duty as both namespace and tag.

### Why This Is Foundational

The pattern solves a fundamental tension in Swift API design:

1. **Namespace enums** provide clean `Nest.Name` hierarchies
2. **Accessor structs** provide operation scoping via properties
3. **Protocol nesting** is blocked in generic types

`Accessor<Base, Tag>` resolves all three. The namespace enum holds the protocol (directly nested, no hoisting needed when the enum is non-generic), the `Accessor` type is reusable across all domains, and operations are scoped by `Tag ==` constraints on extensions.

The relationship to `Tagged<Tag, RawValue>` is precise:
- `Tagged` wraps **values** with phantom type discrimination
- `Accessor` provides **borrowing views** with phantom type discrimination

Both follow the same pattern. Both can share tag types. They're siblings in identity-primitives, not derivations of each other.

### The Experiment That Proved It

Per [EXP-015], the design was verified with a discovery experiment before implementation. The experiment tested whether a single-generic `Accessor<Base>` (without Tag) could discriminate operations. It cannot. When `Base` conforms to multiple protocols, all operations from all conformances appear on the accessor. Only `Tag ==` constraints enable compile-time operation discrimination.

This experiment now serves as living documentation: anyone questioning why Tag is required can run the experiment and see the problem firsthand.

---

## 2026-01-21: Namespace Enums as Phantom Type Tags

*Context: Realizing that dedicated `Tag` enums are unnecessary when the namespace enum itself can serve as the tag.*

> **DOCUMENTATION AUDIT**: This insight eliminates the `Tag` enum pattern from accessor documentation. All references to `Input.Access.Tag`, `Input.Remove.Tag`, etc. must be removed. The namespace IS the tag.

### The Redundancy Eliminated

The initial plan included:

```swift
extension Input {
    public enum Access {
        public typealias Random = __InputAccessRandom
        public enum Tag {}  // UNNECESSARY
    }
}
```

The `Tag` enum exists only to be a type. The `Access` enum already is a type. Using `Input.Access` directly as the tag eliminates the redundant nesting:

```swift
var access: Accessor<Self, Input.Access>  // Not Accessor<Self, Input.Access.Tag>
extension Accessor where Tag == Input.Access, Base: Input.Access.Random { ... }
```

This isn't just fewer characters—it's conceptual clarity. The accessor "tagged with `Input.Access`" means "this is an access accessor." The domain name IS the discrimination.

### When Nested Tags Are Still Needed

Nested `Tag` enums remain necessary when:
1. The namespace needs multiple distinct tags (rare)
2. The namespace is a generic type (can't use generic types as tags)
3. The tag needs to carry type-level information (associated types)

For typical accessor patterns, the namespace-as-tag approach is cleaner.

---

## 2026-01-21: Protocol Nesting in Namespace Enums

*Context: Discovering that protocols CAN be nested directly in non-generic enums, eliminating the need for `__` hoisted protocols in many cases.*

> **DOCUMENTATION AUDIT**: [API-NAME-001] describes hoisting with `__` prefix as the solution for protocol nesting. This needs updating: hoisting is only needed when the parent type is generic. Non-generic namespace enums can nest protocols directly.

### The Cleaner Pattern

The [API-NAME-001] pattern:
```swift
public protocol __InputAccessRandom: ... { ... }
extension Input.Access {
    public typealias Random = __InputAccessRandom
}
```

The direct nesting pattern (when namespace is non-generic enum):
```swift
extension Input {
    public enum Access {
        public protocol Random: Input.`Protocol`, ~Copyable { ... }
    }
}
```

The linter corrected our implementation to use direct nesting. The protocol documentation, examples, and full implementation all live in one place. No `__` prefix pollution. No typealias indirection.

### When Hoisting Is Still Required

Direct nesting fails when:
1. The parent type is generic (`struct Foo<T>` cannot nest protocols)
2. The protocol needs to reference the parent's generic parameters
3. Swift's parser/type-checker has specific limitations (rare edge cases)

For `Input.Access`, `Input.Remove`, and `Input.Restore`—all non-generic namespace enums—direct nesting works and is preferred.

---

## 2026-01-21: The Value/Borrow Duality in Identity Primitives [Package: swift-identity-primitives]

*Context: Understanding why Accessor belongs alongside Tagged in identity-primitives, not as a separate package.*

### The Conceptual Pairing

`Tagged` and `Accessor` are duals:

| Aspect | Tagged | Accessor |
|--------|--------|----------|
| Purpose | Phantom-typed value | Phantom-typed borrow |
| Storage | Owns the value | Holds pointer to value |
| Copyability | Copyable | ~Copyable, ~Escapable |
| Lifetime | Independent | Bound to borrowed value |
| Use case | Type-safe wrappers | Operation-scoped views |

Both use the same phantom type pattern. Both can share tag types:

```swift
enum Domain.Tag {}

// For values
typealias DomainID = Tagged<Domain.Tag, Int>

// For borrows
var operation: Accessor<Self, Domain.Tag>
```

The package is `identity-primitives` because both types are about **identity**—distinguishing otherwise-identical types through phantom type parameters. `Tagged<UserID, Int>` and `Tagged<OrderID, Int>` have the same runtime representation but different compile-time identities. `Accessor<Buffer, Access>` and `Accessor<Buffer, Remove>` have the same runtime representation but different compile-time operation sets.

---

## 2026-01-21: Experiment-Driven Architecture

*Context: Using [EXP-015] Claim Verification to validate design assumptions before implementation.*

### The Methodology Applied

The refactoring followed a critical question: "Is a Tag parameter actually required, or can we discriminate without it?" Rather than assuming, we built an experiment.

The experiment tested three configurations:
1. `SingleGenericAccessor<Base>` with protocol-constrained extensions
2. A type conforming to multiple protocols
3. Method availability on the accessor

Result: Without Tag, ALL methods from ALL conforming protocols appear. The accessor for `remove` would have `element(at:)` from `Access.Random`. The accessor for `access` would have `first()` from `Streaming`. Total conflation.

With Tag:
```swift
extension Accessor where Tag == Input.Access, Base: Input.Access.Random { ... }
extension Accessor where Tag == Input.Remove, Base: Input.Streaming { ... }
```

Each accessor only has its designated operations. The experiment proved the design necessity before a single line of production code was written.

### The Documentation That Resulted

The experiment is checked in to `swift-identity-primitives/Experiments/`. It serves as:
- Proof of the design constraint
- Onboarding material for future contributors
- Living documentation that can be re-run if Swift evolves

---

## 2026-01-21: Documentation Audit Requirements

*Context: Identifying all documentation that must be rewritten to reflect the Accessor pattern.*

> **CRITICAL**: This is not optional polish. The Accessor pattern changes fundamental API patterns across the primitives layer. Outdated documentation will mislead future development.

### Documents Requiring Full Audit

**Swift Institute (cross-cutting)**:
- `API Naming.md` - [API-NAME-001] hoisting pattern needs conditional guidance
- `API Implementation.md` - Accessor pattern implementation guidance needed
- `Memory Copyable.md` - [MEM-COPY-005] accessor limitations need updating with Accessor<Base, Tag> solution
- `Pattern Anti-Patterns.md` - Add anti-pattern: using nested Tag enum when namespace suffices

**swift-primitives documentation**:
- All package-level docs describing accessor structs
- Type documentation for any `Input.Access`, `Input.Remove`, `Input.Restore` usage
- Examples showing `Input.Random` (now `Input.Access.Random`)

**Specific patterns to update**:
1. Replace `Input.Random` → `Input.Access.Random` throughout
2. Replace `Input.Access<Base>` → `Accessor<Base, Input.Access>`
3. Replace `Input.Remove<Base>` → `Accessor<Base, Input.Remove>`
4. Replace `Input.Restore<Base>` → `Accessor<Base, Input.Restore>`
5. Update error type references: `Input.Remove<Base>.Error` → `Input.Remove.Error`

### The Urgency

Other primitives packages (binary, file, stream) likely have similar accessor patterns. If they're implemented before documentation is updated, they'll follow the old pattern, requiring another refactoring cycle. The documentation audit should precede or accompany any new accessor implementations.

---

## 2026-01-21: Error Type Simplification

*Context: Realizing that namespace enums enable non-generic error types, eliminating `__` hoisting for errors.*

### The Previous Pattern

```swift
public enum __InputRemoveError: Error { ... }
extension Input.Remove where Base: ~Copyable {
    public typealias Error = __InputRemoveError
}
```

This hoisting was required because `Input.Remove<Base>` was generic—you can't nest types in generic types without inheriting the constraints.

### The New Pattern

```swift
extension Input.Remove {
    public enum Error: Swift.Error, Sendable, Equatable {
        case empty
        case insufficientElements(requested: Int, available: Int)
    }
}
```

With `Input.Remove` as a non-generic namespace enum, `Error` nests directly. No `__` prefix. No typealias indirection. The error type is `Input.Remove.Error`, not `Input.Remove<SomeBase>.Error`.

This simplification propagates to all error handling code:
- Cleaner throw expressions: `throw Input.Remove.Error.empty`
- Simpler catch patterns: `catch Input.Remove.Error.empty`
- Better documentation: errors are at the namespace level, not the accessor level

---

## 2026-01-21: Semantic Naming vs Safety Qualifiers [Package: swift-input-primitives]

*Context: Refactoring Input protocol primitives from `__restoreUnchecked`, `__removeFirstUnchecked` to `setPosition`, `advance`.*

### The Category Error in "Unchecked" Naming

The `__unchecked` naming pattern describes what a method *doesn't* do rather than what it *does*. This is a category error. Method names should be positive descriptions of behavior, not negative assertions about absent behavior.

`__restoreUnchecked(to:)` tells you: "this is like restore but without checking." It doesn't tell you what it actually does. `setPosition(to:)` tells you exactly what happens: the cursor position is set. The validation absence is an implementation detail, not the method's identity.

This extends to all the primitives: `__removeFirstUnchecked()` becomes `advance()`, `__isValidCheckpoint(_:)` becomes `isValid(_:)`. Each new name describes the physical operation performed, not the safety guarantees it lacks.

### The API vs Primitive Distinction

The session reframed the distinction entirely. The old mental model was "checked vs unchecked"—two versions of the same operation with different safety guarantees. The new mental model is "API vs primitive"—two different conceptual layers.

| Layer | Purpose | Example |
|-------|---------|---------|
| API | What the user wants | `restore.to(checkpoint)` — restore safely |
| Primitive | How the cursor moves | `setPosition(to:)` — set internal position |

These aren't variations of the same operation. The API is a high-level intent; the primitive is a low-level mechanism. The accessor (`restore.to()`) provides validation then calls the primitive. Neither is "unchecked"—one validates, one doesn't need to because it's an implementation detail.

### The `__unchecked` Principle

The user articulated a clear principle: `__unchecked` should only appear when breaking overloads. If two methods have the same semantic meaning but different safety guarantees, `__unchecked` disambiguates. But if methods have different semantic meanings—like "restore to checkpoint safely" vs "set cursor position"—they should have different names describing those meanings.

This principle eliminates safety qualifiers from method names entirely when the methods aren't true overloads. The Input protocol primitives aren't overloads of the accessors; they're implementation details with their own semantic identity.

---

## 2026-01-21: Experiment Discovery for API Design Decisions

*Context: Using [EXP-017] Improvement Discovery methodology to evaluate naming alternatives for Input protocol primitives.*

### The Systematic Comparison

The session applied the Experiment Discovery methodology to a naming decision—not a performance optimization or bug investigation, but a pure API design question. The experiment compared five alternatives:

| Alternative | Approach | Verdict |
|-------------|----------|---------|
| A: Semantic | `setPosition`, `advance` | Excellent clarity |
| B: Flip default | Direct method is checked | Two methods for same concept |
| C: Witness | Separate `Primitives` protocol | Too complex |
| D: Underscore | `_restore`, `_removeFirst` | Doesn't describe action |
| E: Hybrid | `moveTo`, `consumeNext` | Good, similar to A |

The comparison matrix evaluated: clarity of what method does, conformer simplicity, user discoverability, compiler complexity, and Swift convention alignment. Alternatives A and E emerged as clear winners—both describe the physical operation rather than qualifying the safety.

### Why Experiments Apply to Naming

The methodology seemed overkill for "just naming." But naming decisions have lasting consequences. The wrong name creates cognitive load across every usage, every conformance, every documentation page. Systematic comparison prevents bikeshedding and documents the rationale.

The experiment is now checked in. Future maintainers questioning "why `setPosition` not `_restore`?" can read the comparison. The decision isn't arbitrary—it's documented with evaluation criteria.

### The Verdict Drove Implementation

The experiment produced a clear recommendation before any code changed. Implementation then followed the recommendation exactly: `setPosition(to:)`, `advance()`, `advance(by:)`, `isValid(_:)`. No iteration during implementation, no second-guessing. The design phase was complete; execution was mechanical.

This is the value of front-loaded design: implementation becomes transcription, not exploration.

---

## 2026-01-21: The Input Primitives Value Proposition

*Context: Understanding why swift-input-primitives exists and its relationship to swift-deque-primitives.*

### The Abstraction Boundary

The session began with "why does this package exist?" The answer reveals a clean abstraction: Input primitives define *what it means to consume a sequence with backtracking*, without prescribing data structures.

The three-tier protocol hierarchy (`Input.Streaming` → `Input.Protocol` → `Input.Access.Random`) factors capabilities:
- Streaming: forward-only consumption (`advance`, `isEmpty`, `first`)
- Protocol: checkpoint/restore for backtracking (`checkpoint`, `setPosition`, `isValid`)
- Random: O(1) lookahead (`subscript(offset:)`)

Each tier enables different use cases. Network streams need only Streaming. Trial parsers need Protocol. Efficient lookahead parsers need Random. The factoring lets types conform to exactly the capabilities they can support.

### Deque as Consumer

Deque's conformance to all three Input protocols transforms it from "just a container" to "a resumable input source." You can parse from a Deque with checkpoint/restore semantics, treating it as a buffering layer for streaming data.

The Checkpoint stores `(head: Int, count: Int)`—the ring buffer's logical position. Restoring is O(1): set head and count back. This is possible because Deque already tracks these values for its own operations; the Input conformance just exposes them.

### The Complexity Was Necessary

The session's initial concern—"getting quite complex due to the protocols involved"—resolved when understanding that the complexity serves real purposes. Different checkpoint representations (Int for Buffer, Base.Index for Slice, (head, count) for Deque), typed throws per operation category, three-tier capability hierarchy—each serves a distinct use case.

The protocol complexity is the minimum viable abstraction for "consumable cursors with backtracking over arbitrary backends." Simplifying further would lose capabilities that real parsers need.

---

## 2026-01-21: Documentation Drift as Technical Debt [Package: swift-primitives]

*Context: Updating Primitives Tiers.md from 9-tier to 16-tier structure after verification revealed significant divergence between documentation and implementation.*

### The Discovery

The Primitives Tiers documentation stated "nine-tier dependency hierarchy" while the actual package dependencies formed a sixteen-tier DAG (tiers 0-15). This wasn't a small discrepancy—the documentation was missing seven tiers and had incorrect package assignments throughout.

The gap didn't happen through negligence. It accumulated as packages were added, refactored, and reorganized. Each change was small; the cumulative effect was documentation that described a different system than the one that existed.

### The Lesson About Tier Verification

Tier assignment isn't semantic—it's mechanical. A package's tier is determined by the maximum tier of its dependencies plus one. The tier definitions table ("Tier 6: Collections/Shapes") describes semantic clusters that emerged from the dependency structure, not categories that were designed first.

This inverted relationship matters: the DAG determines the tiers; the documentation describes what we observe. When packages change dependencies, tiers shift automatically. Documentation that treats tiers as fixed categories will drift as dependencies evolve.

### The Audit Pattern

The fix required complete regeneration, not incremental updates. The verified tier list came from analyzing every Package.swift file and computing dependency depth. Partial updates would have perpetuated errors.

For documentation describing mechanical relationships (dependencies, tiers, counts), periodic full regeneration from source of truth is more reliable than incremental maintenance.

---

## 2026-01-21: The "Most Depended-Upon" Metric [Package: swift-primitives]

*Context: Adding dependency impact information to tier documentation.*

### Why This Metric Matters

The updated documentation includes a table of most-depended-upon packages:

| Package | Dependents |
|---------|------------|
| index-primitives | 21 |
| collection-primitives | 16 |
| input-primitives | 12 |

This isn't decorative. These numbers represent change propagation scope. A breaking change to `index-primitives` forces recompilation of 21 packages. A bug in `collection-primitives` potentially affects 16 downstream consumers.

### Practical Application

When planning API changes, consult this list first. Packages with many dependents warrant more careful review, more extensive testing, and explicit migration guidance. Packages with few dependents can evolve more freely.

The tier number tells you where a package sits. The dependent count tells you how much its changes matter.

### The Inverse Relationship

Interestingly, the most-depended-upon packages are all in lower tiers (index at tier 1, collection at tier 2). This is structural: lower-tier packages can be depended upon by more packages (everything above them). Higher-tier packages can only be depended upon by the few packages above them.

This confirms the architectural intent: foundational packages should be stable; specialized packages can evolve.

---

## 2026-01-21: Semantic Tier Names vs Mechanical Tier Numbers

*Context: Observing tension between tier names ("Atomic", "Foundation") and tier positions (0, 1, ..., 15).*

### The Naming Problem

The updated documentation assigns names to tiers: "Tier 5: Bit/Dimension", "Tier 9: Complex Structures". These names describe the packages currently at those tiers—they're descriptive, not prescriptive.

When a package's dependencies change, its tier number shifts mechanically. If `parser-primitives` adds a dependency on a tier 10 package, it moves to tier 11 (at minimum). The "Tier 9: Complex Structures" name no longer accurately describes what's at tier 9.

### Why Keep Names At All

Tier names serve cognitive function. "Tier 7" is opaque; "Advanced Numerical" suggests what kinds of packages belong there. The names are a snapshot of current semantic clustering, useful for orientation but not for rule enforcement.

The documentation should treat names as commentary: "As of this version, tier 7 contains linear algebra and input handling packages." Not: "Tier 7 is for advanced numerical packages."

### The Verification Cadence

This suggests a maintenance pattern: when running full tier verification (as done today), also verify that tier names still describe their contents. Names may need updating even if package assignments are correct.

---

## 2026-01-21: Major Version Bumps for Structural Documentation

*Context: Incrementing Primitives Tiers.md version from 1.0.0 to 2.0.0.*

### When Documentation Warrants Major Versions

The version bump from 1.0.0 to 2.0.0 reflected the scope of change: nine tiers became sixteen, all package assignments were re-verified, and new sections were added. This wasn't a typo fix or clarification—it was structural revision.

Applying semver to documentation is unusual but valuable for normative documents. Other documents reference [PRIM-ARCH-001]; a major version signals "re-read this, the model changed."

### The Signal to Consumers

The version number creates an audit trigger. Any code or documentation citing "the nine-tier hierarchy" is now outdated. The major version makes this visible: version 2.x describes a different structure than version 1.x.

For architectural documentation that other documents depend on, version numbers are communication infrastructure.

---

## 2026-01-21: Plan-to-Implementation Fidelity

*Context: Implementing a detailed plan from the previous session without deviation.*

### The Value of Exhaustive Plans

The plan provided exact tier counts, package assignments, and section-by-section edit instructions. Implementation became mechanical: update header, replace table, update examples, verify build.

This mechanical quality is desirable. The planning session did the thinking; the implementation session did the typing. Errors could only come from typos, not from design decisions made under time pressure.

### When Plans Should Be Exact

For documentation updates with known-correct source data (verified tier list), exact plans accelerate execution. For exploratory implementation where discoveries change the approach, loose plans are appropriate.

The tier documentation update was a data migration: known inputs, known outputs, known transformation. Exact plans suit data migrations.

### The Build Verification Step

The plan included `swift build` as the final step. This caught nothing (documentation changes don't affect builds), but the habit is correct. Even documentation changes can break DocC compilation, and the verification step would catch that.

---

## 2026-01-21: Value Generics Cannot Carry Conditional Copyable [Package: swift-set-primitives]

*Context: Implementing `Set<Bit>.Packed.Small<let inlineWordCount: Int>` and attempting to follow the `~Copyable` + conditional Copyable pattern from `Stack<Element>`.*

### The Compiler Limitation

Swift's conditional Copyable pattern requires a **type** generic parameter to constrain on. The canonical pattern from `Stack<Element: ~Copyable>`:

```swift
public struct Stack<Element: ~Copyable>: ~Copyable { ... }
extension Stack: Copyable where Element: Copyable {}
extension Stack: Sequence where Element: Copyable { ... }
```

This works because `Element: Copyable` is a valid constraint—you're constraining a type parameter.

For `Set<Bit>.Packed.Small<let inlineWordCount: Int>`, the attempt was:

```swift
public struct Small<let inlineWordCount: Int>: ~Copyable, Sendable { ... }
extension Set<Bit>.Packed.Small: Copyable {}  // ❌ COMPILER ERROR
```

The error: `generic struct 'Small' required to be 'Copyable' but is marked with '~Copyable'`

The value generic parameter `inlineWordCount` provides no type to constrain on. There's nothing analogous to `where Element: Copyable` because `Int` isn't a type parameter—it's a value parameter. The compiler sees an unconditional request to add `Copyable` to a `~Copyable` type, which is forbidden.

### The Orthogonal Concerns

Value generics (`let N: Int`) and type generics (`Element: ~Copyable`) serve orthogonal purposes:

| Generic Kind | Purpose | Can Constrain Copyable? |
|--------------|---------|-------------------------|
| Type (`Element`) | Parameterize over types | ✅ `where Element: Copyable` |
| Value (`let N: Int`) | Parameterize over values | ❌ No type to constrain |

`Stack<Element>` needs conditional Copyable because `Element` might or might not be Copyable at instantiation time. The struct must be `~Copyable` to support move-only elements, then grants Copyable when elements permit.

`Small<let inlineWordCount: Int>` stores `InlineArray<inlineWordCount, UInt>`. The `UInt` is always trivial—Copyable isn't conditional on anything. There's no scenario where `Small<4>` should be Copyable but `Small<8>` shouldn't.

### The Correct Design Decision

For types with value generics that store only trivial data:

**DO NOT** declare `~Copyable` then try to add Copyable. It's syntactically impossible.

**DO** simply omit `~Copyable` entirely. The type is unconditionally Copyable because its storage is unconditionally trivial.

```swift
// Correct for Set<Bit>.Packed.Small
public struct Small<let inlineWordCount: Int>: Sendable {
    var _inlineStorage: InlineArray<inlineWordCount, UInt>
    var _heapStorage: ContiguousArray<UInt>?
    var _capacity: Int
    // All members are trivial → type is trivially Copyable
}
```

---

## 2026-01-21: The ~Copyable Decision Framework [Package: swift-set-primitives]

*Context: Deciding whether `Set<Bit>.Packed.Small` should be `~Copyable` after discovering the value generic limitation.*

### When ~Copyable Is Required

A type MUST be declared `~Copyable` when:

1. **It stores generic elements that could be move-only**: `Stack<Element: ~Copyable>` stores `Element`, which might be `~Copyable` at instantiation.

2. **It has a deinit that must run**: `Stack.Small<Element>` has inline storage requiring element-by-element destruction. The deinit is essential, so the type must be `~Copyable` to prevent implicit copying that would skip it.

3. **Copying would violate semantics**: Types representing unique ownership (file handles, locks) where copy would create aliasing.

### When ~Copyable Is Wrong

A type should NOT be `~Copyable` when:

1. **Storage is unconditionally trivial**: `Set<Bit>.Packed.Small` stores `UInt` words and optional `ContiguousArray`—both always Copyable.

2. **There's no generic element type**: Fixed-type containers don't need conditional Copyable because there's nothing to condition on.

3. **Protocol conformances are needed**: `Sequence`, `Equatable`, `Hashable` require Copyable. A `~Copyable` type without conditional Copyable cannot conform.

4. **You want value semantics without manual implementation**: Copyable types get automatic memberwise copying. `~Copyable` types need explicit `borrowing`/`consuming` handling.

### The Design Table

| Storage Pattern | Generic Element? | Use ~Copyable? |
|-----------------|------------------|----------------|
| `Element` (might be ~Copyable) | Yes | ✅ Yes + conditional Copyable |
| `[Element]` (array of elements) | Yes | ✅ Yes + conditional Copyable |
| `UInt` / trivial types only | No | ❌ No, just use Sendable |
| Value generic (`let N: Int`) only | No | ❌ No, cannot condition Copyable |
| Inline storage with deinit | Yes | ✅ Yes (deinit requirement) |

`Set<Bit>.Packed.Small` falls in row 3/4: trivial storage, value generic, no generic element. The correct choice is plain `Sendable` without `~Copyable`.

---

## 2026-01-21: Documenting Deviation from Established Patterns [Package: swift-set-primitives]

*Context: Adding documentation to `Set<Bit>.Packed.Small` explaining why it differs from `Stack.Small`.*

### The Documentation Obligation

When a type deviates from an established pattern in the same codebase, that deviation must be documented. The code comment added:

```swift
/// ## Copyable
///
/// Unlike `Stack.Small<Element>` which is `~Copyable` because it stores
/// potentially move-only elements, `Set<Bit>.Packed.Small` stores only `UInt`
/// words (always trivial) and has no generic element type. Therefore it is
/// unconditionally `Copyable`, enabling `Sequence`, `Equatable`, and `Hashable`.
```

This comment does three things:

1. **Acknowledges the pattern**: "Unlike `Stack.Small`..." signals awareness of the expected pattern.
2. **Explains the difference**: "stores only `UInt` words (always trivial)" gives the concrete reason.
3. **States the consequence**: "enabling `Sequence`, `Equatable`, and `Hashable`" shows the benefit.

### Why Future Readers Need This

Without the comment, a future maintainer might:

1. See `Stack.Small` is `~Copyable`
2. See `Set<Bit>.Packed.Small` is not `~Copyable`
3. Assume the latter is wrong and "fix" it
4. Discover it doesn't compile
5. Spend hours understanding why

The comment short-circuits this: the deviation is intentional, the reason is documented, the investigation is unnecessary.

### The Pattern for Documenting Deviation

```swift
/// ## [Property Name]
///
/// Unlike `[Reference Type]` which [does X] because [reason],
/// `[This Type]` [does Y] because [different reason].
/// Therefore it [has consequence].
```

This template applies whenever a type intentionally differs from a similar type in the same layer.

---

## 2026-01-21: The Naming Mirror — Set<Bit>.Packed from Array<Bit>.Packed [Package: swift-set-primitives]

*Context: Renaming `Bit.Set` to `Set<Bit>.Packed` to mirror `Array<Bit>.Packed`.*

### The Naming Principle

The existing naming was:
- `Array<Bit>.Packed` — array of bits packed into words
- `Bit.Set` — set of bits packed into words

The asymmetry is jarring. Both are packed bit containers; their names should reflect this:
- `Array<Bit>.Packed` — packed bit array
- `Set<Bit>.Packed` — packed bit set

The new naming follows [API-NAME-003]: types implementing the same concept for different container semantics should mirror each other's structure.

### The Implementation Pattern

```swift
// Array<Bit>.Packed uses:
extension Array where Element == Bit {
    public struct Packed: Sendable { ... }
}

// Set<Bit>.Packed now uses:
extension Set where Element == Bit {
    public struct Packed: Sendable { ... }
}
```

This works because `Bit: Hashable`, satisfying `Set`'s element requirement. The extension constraint `where Element == Bit` pins the namespace to exactly the bit-set case.

### The Variant Hierarchy Parallel

Both types now have matching variant hierarchies:

| Array<Bit>.Packed | Set<Bit>.Packed | Purpose |
|-------------------|-----------------|---------|
| `.init()` | `.init()` | Dynamic heap-backed |
| `.Inline<N>` | `.Inline<N>` | Fixed inline capacity |
| `.Bounded` | `.Bounded` | Fixed heap capacity |
| — | `.Small<N>` | Inline + heap spill |

The `Small` variant exists for `Set<Bit>.Packed` but not yet for `Array<Bit>.Packed`. This is intentional: bit sets commonly need small-buffer optimization (tracking a handful of flags), while packed bit arrays are typically used for larger data (images, binary data).

---

## 2026-01-21: The Spill-to-Heap Bug and Defensive State Management [Package: swift-set-primitives]

*Context: Fixing a data-loss bug in `Set<Bit>.Packed.Small._spillToHeap` that occurred when growing already-spilled storage.*

### The Bug Pattern

The initial implementation had a subtle state management bug:

```swift
// BROKEN
mutating func _spillToHeap(toInclude bitIndex: Int) {
    let requiredWords = (bitIndex / Self._bitsPerWord) + 1
    var heap = ContiguousArray<UInt>(repeating: 0, count: requiredWords)
    for i in 0..<inlineWordCount {
        heap[i] = _inlineStorage[i]  // ❌ Wrong when already spilled!
    }
    _heapStorage = heap
}
```

When called after already spilling, this code:
1. Creates new heap storage
2. Copies from `_inlineStorage` (which is stale after first spill)
3. Discards existing `_heapStorage` (which contained the actual data)

The bug manifested only on the *second* spill—the first spill worked correctly. Tests inserting a single value beyond inline capacity passed. Tests inserting two values beyond inline capacity lost the first value.

### The Fix: Branch on Current State

```swift
// CORRECT
mutating func _spillToHeap(toInclude bitIndex: Int) {
    let requiredWords = (bitIndex / Self._bitsPerWord) + 1

    if var existingHeap = _heapStorage {
        // Growing existing heap
        existingHeap.append(contentsOf: repeatElement(0 as UInt, count: requiredWords - existingHeap.count))
        _heapStorage = existingHeap
    } else {
        // First spill from inline
        var heap = ContiguousArray<UInt>(repeating: 0, count: requiredWords)
        for i in 0..<inlineWordCount {
            heap[i] = _inlineStorage[i]
        }
        _heapStorage = heap
    }
    _capacity = requiredWords * Self._bitsPerWord
}
```

The method now checks which storage mode is active and handles each case correctly.

### The Defensive Programming Principle

State-dependent operations must explicitly handle all states. The bug occurred because the original code *assumed* it was always in inline mode. The fix *checks* which mode is active.

For small-buffer-optimization types with dual storage:
1. Every mutating operation should know which storage is active
2. Transitions between modes must preserve data from the *current* mode
3. Tests must exercise sequences that cross modes multiple times

---

## 2026-01-21: Clear vs RemoveAll — Semantic Distinction in Small Variants [Package: swift-set-primitives]

*Context: Designing the API for resetting `Set<Bit>.Packed.Small` to empty state.*

### The Two Operations

```swift
/// Removes all bits and returns to inline storage mode.
public mutating func clear() {
    _inlineStorage = .init(repeating: 0)
    _heapStorage = nil
    _capacity = Self.inlineCapacity
}

/// Removes all bits but keeps current storage mode.
public mutating func removeAll() {
    if _heapStorage != nil {
        for i in _heapStorage!.indices {
            _heapStorage![i] = 0
        }
    } else {
        _inlineStorage = .init(repeating: 0)
    }
    // _capacity unchanged, _heapStorage retained
}
```

### Why Both Are Needed

**`clear()`** is for "reset to initial state":
- User finished with current data
- Next use case may be small (likely fits inline)
- Deallocating heap storage is desirable

**`removeAll()`** is for "empty but reuse":
- Batch processing multiple datasets
- Each dataset likely similar size
- Avoiding repeated spill/deallocate cycles

The distinction mirrors `Array.removeAll(keepingCapacity:)` but split into two methods for clarity. The small-buffer optimization makes the distinction more significant: `clear()` actually changes the storage mode, not just the count.

### The Naming Convention

Both are single-word methods per [API-NAME-002]. The names communicate:
- `clear`: thorough, complete reset (returns to initial state)
- `removeAll`: removes elements, might preserve structure

This semantic distinction should be consistent across small-variant types. `Stack.Small`, `Queue.Small`, `Set.Ordered.Small` should follow the same pattern if they have similar storage modes.

---

## 2026-01-22: Documentation Drift and Automated Verification [Package: swift-primitives]

*Context: Performing a systematic tier audit of all 105 swift-primitives packages, discovering the documented 16-tier structure didn't match actual dependencies.*

### The Scale of Drift

The Primitives Tiers document (v2.0.0) specified a 16-tier hierarchy (0-15). A complete dependency scan of all Package.swift files revealed the actual structure requires only 13 tiers (0-12). Packages were scattered across incorrect tiers—some 3-4 tiers away from their correct position. This wasn't isolated errors; it was systemic drift affecting over 30% of packages.

The drift accumulated through incremental changes. Each Package.swift modification was locally correct, but no one ran a global verification. The documentation became a historical artifact rather than a living specification.

### Computational Truth

A 30-line Python script computed the correct tier for every package in seconds:

```
tier[pkg] = max(tier[dep] for dep in pkg.dependencies) + 1
```

This trivial algorithm exposed months of accumulated drift. The lesson: for any property that can be computed from source, the documentation should either be generated or verified automatically. Human curation of derived information cannot scale.

### Recommended Practice

Primitives Tiers.md should include a verification step in CI: compute tiers from Package.swift files, compare to documented tiers, fail if they diverge. The document's version should increment only when computed tiers change. Human judgment belongs in tier *naming* and *description*, not tier *assignment*.

---

## 2026-01-22: SDG Edges as Architectural Intent

*Context: Analyzing SDG (Semantic Dependency Graph) edges and encountering the lateral edge case of formatting-primitives → string-primitives (both Tier 1).*

### The Subtle Distinction

The Semantic Dependencies framework (v1.1) states: "SDG edges MUST respect the same tier constraints as IDG edges." Yet an example in the document shows `formatting-primitives` (T1) with an SDG edge to `string-primitives` (T1)—a lateral edge. How can this be valid?

The resolution: SDG edges document *architectural intent*, not current position. When formatting-primitives declares `SDG(produces): string-primitives`, it's saying "when this package eventually produces string output, it will need to depend on string-primitives and move to Tier 2." The SDG is a forward-looking placeholder, a declared future rather than a present constraint.

### Implications for SDG Review

This means SDG edges answer a different question than IDG edges:
- **IDG**: "What does this package currently use?"
- **SDG**: "What would this package need if it fully realized its semantic purpose?"

A lateral SDG edge is a signal, not a violation. It indicates the package's current tier is temporary—it will rise when implementation catches up to intent. The [SEM-DEP-005] review process should treat lateral SDG edges as tier placement predictions, not errors.

---

## 2026-01-22: Error and Lifetime as Semantic Attractors

*Context: Adding 8 new SDG markers and noticing all of them pointed to just two Tier 0 packages: error-primitives and lifetime-primitives.*

### The Pattern

Of 14 total SDG edges in swift-primitives:
- 6 point to `error-primitives` (wraps)
- 4 point to `lifetime-primitives` (wraps)
- 2 point to `property-primitives` (operates-on)
- 1 points to `optic-primitives` (operates-on)
- 1 points to `string-primitives` (produces)

Error and lifetime together account for 71% of all semantic dependencies. They are *attractor* types—packages that represent concepts so fundamental that most higher-level abstractions eventually need to reference them semantically, even when they don't import them yet.

### Design Implications

This concentration suggests:

1. **error-primitives and lifetime-primitives should be exceptionally stable**. Changes ripple semantically across the entire package hierarchy.

2. **The SDG graph has a narrow waist**. Despite 16 Tier 0 packages, semantic dependencies converge on just two. The others (decimal, random, positioning, etc.) are more self-contained.

3. **"What errors does this represent?" and "What lifetimes does this manage?" are the most productive discovery questions**. When auditing for missing SDG edges, these two questions found 10 of 14 total edges.

The Semantic Dependencies framework should highlight this: some Tier 0 packages are semantic attractors; most are not. The discovery questions should be weighted accordingly.

---

## 2026-01-22: The Essential vs Incidental Boundary in SDG Analysis

*Context: Initially proposing SDG edges that turned out to be incidental (ordinal-primitives → error) or already in IDG (coder-primitives → binary).*

### False Positives

Two early proposals were rejected:

1. **ordinal-primitives → error-primitives**: Ordinal defines `Ordinal.Error` with throwing initializers. But this is a domain-specific error conforming to `Swift.Error`, not a wrapper around error-primitives concepts. The semantic relationship is to Swift's Error protocol, not to our error-primitives package.

2. **coder-primitives → binary-primitives**: Coders produce binary output—seemingly a clear `SDG(produces)`. But coder-primitives already has binary-primitives as an active IDG dependency. SDG edges are for relationships that *should* exist but *don't yet*. An active dependency doesn't need an SDG placeholder.

### The Decision Procedure

SDG edges require passing three filters:

1. **Essential, not incidental**: Would removing B change A's semantic domain? (ordinal's errors are incidental)
2. **Not already IDG**: Is the dependency currently inactive? (coder already imports binary)
3. **Tier-respecting**: Does the edge flow downward or document future upward movement?

The third filter is the subtlest. A lateral SDG edge is valid if it documents architectural intent. A lateral edge that *isn't* intended for future activation is an architectural error—the packages should merge or extract a common ancestor.

---

## Topics

### Related Documents

- <doc:_Reflections>
- <doc:_Reflections-Consolidation>
- <doc:API-Requirements>
- <doc:Identity>
- <doc:_Future-Directions>
