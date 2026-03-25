---
name: ecosystem-data-structures
description: |
  Complete catalog of data structures across swift-primitives and swift-foundations
  with selection guidance. Consult before choosing a container, buffer, storage, or
  memory type. ALWAYS apply when selecting or recommending a data structure type.

layer: implementation

requires:
  - swift-institute

applies_to:
  - swift-primitives
  - swift-standards
  - swift-foundations
---

# Ecosystem Data Structures

Catalog and selection guide for all data structure types in the Swift Institute ecosystem.
Types are organized in a four-layer composition architecture: Memory -> Storage -> Buffer -> Collection.

---

## Composition Architecture

### [DS-001] Four-Layer Composition

**Statement**: Data structures in the ecosystem are composed in four layers. Each layer adds exactly one concern. When building new containers, compose from these layers — do not bypass them.

```
Collection  (user-facing API: subscript, iteration, protocol conformances)
    |
Buffer      (mutation logic: grow, insert, remove, rebalance + Header state)
    |
Storage     (element lifecycle: init/deinit tracking, reference-counted backing)
    |
Memory      (raw allocation: malloc, bump, pool, inline)
```

| Layer | Concern | Consumer |
|-------|---------|----------|
| Memory (Tier 13) | Allocation/deallocation | Infrastructure builders only |
| Storage (Tier 14) | Element lifecycle tracking | Buffer/custom container builders |
| Buffer (Tier 15) | Mutation semantics + state | Collection builders |
| Collection (Tiers 16-18) | User ergonomics | Application code |

**Rationale**: Most code should use Collection types. Drop to Buffer when you need direct mutation control. Drop to Storage when building a new Buffer discipline. Drop to Memory only for raw allocator work.

---

## Variant System

### [DS-002] Variant Selection

**Statement**: When a collection type offers multiple variants, select based on allocation strategy. The variant pattern is uniform across all collection families.

| Variant | Storage | Allocation | Growth | Select When |
|---------|---------|------------|--------|-------------|
| *(base)* | Heap | Dynamic | Growable | General purpose; unknown or variable size |
| `.Bounded` | Heap | Fixed at init | Fixed capacity | Known max capacity; heap but non-growable |
| `.Static<N>` | Stack (inline) | Compile-time | Fixed capacity | Capacity known at compile time; zero heap allocation |
| `.Small<N>` | Inline -> Heap | Spills on overflow | Growable | Usually small, occasionally large (SmallVec pattern) |
| `.Fixed` | Heap | Fixed at init | Immutable | Fixed count; immutable after creation |

**Copyability rules**:
- Base types: `~Copyable`; become `Copyable` when `Element: Copyable` (enables CoW)
- `.Fixed` / `.Bounded` variants: `~Copyable`; become `Copyable` when `Element: Copyable` (heap-backed, CoW)
- `.Static<N>` / `.Small<N>` variants: **unconditionally `~Copyable`** — `@_rawLayout` prevents conditional `Copyable` even when `Element: Copyable` (compiler limitation, not design choice)

**Sendability rules**:
- `~Copyable` types: `@unchecked Sendable` (exclusive ownership = thread safety)
- `Copyable` types: conditional `Sendable` when `Element: Sendable`

**Known compiler limitations** (Swift 6.2):
- **Element leak on drop** (swiftlang/swift#86652): `deinit` is commented out for `.Static<N>` and `.Small<N>` variants due to a release-mode LLVM verifier crash with `@_rawLayout`. **Elements are NOT automatically deinitialized when the container is dropped.** Consumer must drain all elements before the container goes out of scope.
- **LLVM verifier crash in Small variants**: Struct containing both `@_rawLayout` (Storage.Inline) and reference-type field (Storage.Heap) triggers IRGen crash in release builds. Workaround uses enum `_Representation` to ensure only one variant is destroyed at a time.

---

## Collection Types (Tiers 16-18)

### [DS-003] Container Selection

**Statement**: Select the collection type that matches the access pattern. Do not use a lower-level Buffer or Storage type when a Collection type exists for the use case.

#### Sequential — Contiguous

| Type | Import | Access | Use When |
|------|--------|--------|----------|
| `Array<E>` | `Array_Primitives` | O(1) random, O(n) insert | General-purpose growable sequence |
| `Array<E>.Static<N>` | | O(1) random | Compile-time fixed capacity; zero heap |
| `Array<E>.Small<N>` | | O(1) random | Usually small; spills to heap |
| `Array<E>.Bounded<N>` | | O(1) random | Compile-time dimensioned; fixed capacity |
| `Array<E>.Fixed` | | O(1) random | Immutable after creation |

#### Sequential — LIFO

| Type | Import | Use When |
|------|--------|----------|
| `Stack<E>` | `Stack_Primitives` | General-purpose LIFO |
| `Stack<E>.Bounded<N>` | | Fixed-capacity LIFO |
| `Stack<E>.Static<N>` | | Inline LIFO; zero heap |
| `Stack<E>.Small<N>` | | SmallVec LIFO; inline with heap spill |

#### Sequential — FIFO / Deque

| Type | Import | Use When |
|------|--------|----------|
| `Queue<E>` | `Queue_Primitives` | General-purpose FIFO (ring buffer) |
| `Queue<E>.Fixed` | | Fixed-capacity FIFO; throws on overflow |
| `Queue<E>.Static<N>` | | Inline FIFO; zero heap |
| `Queue<E>.Small<N>` | | SmallVec FIFO |
| `Queue<E>.Linked` | | Linked-list FIFO |
| `Queue<E>.Linked.Bounded` | | Fixed-capacity linked-list FIFO |
| `Queue<E>.Linked.Inline<N>` | | Inline linked-list FIFO; zero heap |
| `Queue<E>.Linked.Small<N>` | | SmallVec linked-list FIFO |
| `Queue<E>.DoubleEnded` | | Deque; push/pop from both ends |
| `Queue<E>.DoubleEnded.Static<N>` | | Inline deque; zero heap |
| `Queue<E>.DoubleEnded.Small<N>` | | SmallVec deque |

#### Sequential — Linked

| Type | Import | Use When |
|------|--------|----------|
| `List.Linked<E, N>` | `List_Primitives` | Linked list; N=1 singly, N=2 doubly; O(1) positional insert/remove |
| `List.Linked<E, N>.Bounded` | | Fixed-capacity linked list |
| `List.Linked<E, N>.Inline` | | Inline linked list; zero heap |
| `List.Linked<E, N>.Small` | | SmallVec linked list |

#### Associative — Key-Value

| Type | Import | Use When |
|------|--------|----------|
| `Dictionary<K: Hash.Protocol, V>` | `Dictionary_Primitives` | Unordered hash map; slab-backed; O(1) lookup/insert/remove |
| `Dictionary<K, V>.Ordered` | | Insertion-ordered; linear-backed; O(n) removal |
| `Dictionary<K, V>.Ordered.Bounded` | | Fixed-capacity ordered dictionary |
| `Dictionary<K, V>.Ordered.Static<N>` | | Inline ordered dictionary; zero heap |
| `Dictionary<K, V>.Ordered.Small<N>` | | SmallVec ordered dictionary |

#### Associative — Membership

| Type | Import | Use When |
|------|--------|----------|
| `Set.Ordered<E: Hash.Protocol>` | `Set_Primitives` | Insertion-ordered hash set; O(1) membership |
| `Set.Ordered<E>.Fixed` | | Fixed-capacity ordered set |
| `Set.Ordered<E>.Static<N>` | | Inline ordered set; zero heap |
| `Set.Ordered<E>.Small<N>` | | SmallVec ordered set |
| `Bitset` | `Bitset_Primitives` | Integer domain membership; packed bits |
| `Bitset.Static` / `.Small` / `.Fixed` | | Inline/SmallVec/fixed variants |

#### Priority

| Type | Import | Use When |
|------|--------|----------|
| `Heap<E: Comparison.Protocol>` | `Heap_Primitives` | Binary min-heap; priority queue |
| `Heap<E>.Fixed` | | Fixed-capacity heap |
| `Heap<E>.Static<N>` | | Inline heap; zero heap |
| `Heap<E>.Small<N>` | | SmallVec heap |
| `Heap<E>.MinMax` | | Double-ended priority queue (min and max) |

#### Sparse / Stable-Index

| Type | Import | Use When |
|------|--------|----------|
| `Slab<E>` | `Slab_Primitives` | O(1) insert/remove; stable indices across mutations |
| `Slab<E>.Static<wordCount>` | | Inline slab; zero heap |
| `Slab<E>.Indexed<Tag>` | | Phantom-typed index wrapper for type-safe access |

#### Tree

| Type | Import | Use When |
|------|--------|----------|
| `Tree.N<E, n>` | `Tree_Primitives` | N-ary tree; bounded arity |
| `Tree.Binary` (= `Tree.N<2>`) | | Binary tree |
| `Tree.N<E, n>.Bounded` / `.Inline` / `.Small` | | Fixed/inline/SmallVec variants |
| `Tree.Unbounded<E>` | | Variable-arity tree |
| `Tree.Keyed<K: Hash.Protocol>` | | Key-indexed tree (trie-like) |

#### Graph

`Graph` (`Graph_Primitives`) — algorithm namespace, not a container. Operates on external graph representations via witnesses.

#### Text

`String` (`String_Primitives`) — owned null-terminated platform string; `~Copyable`, `@unchecked Sendable`. No variants. Support types: `.View`, `.Char`, `.Length`.

---

## Buffer Types (Tier 15)

### [DS-004] Buffer Selection

**Statement**: When a Collection type does not exist for your use case, or when you need direct mutation control, select from the six Buffer disciplines. Each discipline composes a specific Storage type.

| Discipline | Storage | Pattern | Backs |
|------------|---------|---------|-------|
| `Buffer.Linear<E>` | `Storage<E>.Heap` | Contiguous growable | Array, Stack, Heap, Dictionary.Ordered, Set.Ordered |
| `Buffer.Ring<E>` | `Storage<E>.Heap` | Circular FIFO/LIFO | Queue, Queue.DoubleEnded |
| `Buffer.Slab<E>` | `Storage<E>.Slab` | Sparse index-addressable | Slab, Dictionary |
| `Buffer.Linked<E, N>` | `Storage<Node>.Pool` | Pool-backed linked list | List.Linked, Queue.Linked |
| `Buffer.Slots<E, M>` | `Storage<E>.Split<M>` | Parallel metadata+element | Hash.Table |
| `Buffer.Arena<E>` | `Storage<E>.Arena` | Generation-token arena | Tree types |

**Import**: `Buffer_Primitives`

Each discipline offers the same variant pattern as Collections: `.Bounded`, `.Inline<N>`, `.Small<N>` where applicable.

**Additional byte-level buffers**:
- `Buffer.Aligned` — fixed-size aligned memory block (UInt8 only); ~Copyable
- `Buffer.Unbounded` — resizable byte buffer; configurable `Buffer.Growth.Policy` (struct with closure; factories: `.doubling`, `.factor(scale)`, `.exact`, `.pageAligned(alignment)`)

**Key associated types**:
- `Buffer.Ring.Checkpoint` — save/restore snapshot for ring buffers
- `Buffer.Arena.Position` — 8-byte handle (index:UInt32 + token:UInt32) for safe arena access

---

## Storage Types (Tier 14)

### [DS-005] Storage Selection

**Statement**: When building a new Buffer discipline or custom container, select the Storage type that matches the lifecycle management pattern. Storage handles element init/deinit tracking; you handle mutation logic.

| Type | Semantics | Lifecycle | Select When |
|------|-----------|-----------|-------------|
| `Storage<E>.Heap` | Reference (class) | Range-based auto deinit | Contiguous elements with tracked initialization ranges |
| `Storage<E>.Inline<N>` | Value, ~Copyable | Per-slot bitmap tracking | Stack-allocated; N <= 256; zero heap |
| `Storage<E>.Arena` | Reference (class) | Generation-token deinit | SoA layout; elements with generational tokens |
| `Storage<E>.Arena.Inline<N>` | Value, ~Copyable | Inline arena | Stack-allocated arena |
| `Storage<E>.Slab` | Reference (class) | Bitmap-driven deinit | Sparse elements with O(1) slot-level occupancy |
| `Storage<E>.Pool` | Reference (class) | Bitmap-tracked alloc | Fixed-capacity O(1) alloc/dealloc for uniform elements |
| `Storage<E>.Pool.Inline<N>` | Value, ~Copyable | Bitmap-scanned | Inline pool; no in-band free list |
| `Storage<E>.Split<Lane>` | Reference (class) | NO element deinit | Dual-array SoA; consumer manages element lifecycle |

**Import**: `Storage_Primitives`

`Storage.Initialization` — tracks initialized element ranges: `.empty`, `.one(Range)`, `.two(first:second:)`.

---

## Memory Types (Tier 13)

### [DS-006] Memory Layer Selection

**Statement**: Memory types provide raw allocation with no element lifecycle management. Use these only when building Storage-level or lower infrastructure. Consumer is fully responsible for initialization and deinitialization.

#### Allocators

| Type | Pattern | Select When |
|------|---------|-------------|
| `Memory.Allocator` | System malloc/free | General-purpose heap allocation |
| `Memory.Arena` | Bump allocator; O(1) alloc, bulk reset | Many short-lived allocations; no individual dealloc needed |
| `Memory.Pool` | O(1) alloc/dealloc; in-band free list | Fixed-capacity uniform-size slot allocation |

#### Buffers & Storage

| Type | Select When |
|------|-------------|
| `Memory.Buffer` / `.Mutable` | Raw byte buffer with non-null guarantee |
| `Memory.Contiguous<E: BitwiseCopyable>` | Self-owning heap buffer; bulk deallocation; BitwiseCopyable only |
| `Memory.Inline<E, N>` | Raw fixed inline storage; no tracking; consumer manages lifecycle |

#### Alignment & Addressing

| Type | Purpose |
|------|---------|
| `Memory.Address` | Non-null memory address (Tagged ordinal); typed arithmetic |
| `Memory.Address.Offset` | Signed byte displacement |
| `Memory.Address.Count` | Byte count |
| `Memory.Shift` | Bit shift count (alignment exponent, 0-63) |
| `Memory.Alignment` | Power-of-2 alignment value |

**Import**: `Memory_Primitives`

---

## Bit-Level Types (Tiers 8-12)

### [DS-007] Bit-Level Selection

**Statement**: Select bit-level types based on the abstraction level needed.

| Type | Import | Select When |
|------|--------|-------------|
| `Bitset` | `Bitset_Primitives` | User-facing packed bit set; integer domain membership |
| `Bit.Vector` | `Bit_Vector_Primitives` | Infrastructure bitmap; occupancy tracking for Storage/Buffer |
| `Bit.Pack<Word>` | `Bit_Pack_Primitives` | Layout witness for bit field packing; not a container |

**Bitset vs Bit.Vector**: Bitset is the user-facing set type for integer domains. Bit.Vector is infrastructure used internally by Storage and Buffer types. Use Bitset for application logic; use Bit.Vector only when building containers.

---

## Foundations Types (Layer 3)

### [DS-008] Foundations Selection

**Statement**: Layer 3 types compose Layer 1 primitives with platform capabilities. Use these when the task requires OS integration, concurrency, or serialization.

| Type | Import | Select When |
|------|--------|-------------|
| `Memory.Map` | `Memory` | Memory-mapped file regions; safe mmap wrapper |
| `Pool.Blocking` | `Pool` | Thread-safe blocking resource pool; connection/worker pools |
| `Async.Stream<E>` | `Async` | Composable async sequences with operators |
| `IO.Event.Channel` | `IO` | Non-blocking I/O; socket operations |
| `JSON` | `JSON` | JSON value type (wraps RFC_8259.Value) |
| `XML` | `XML` | XML element representation |
| `Plist` | `Plist` | Property list value type |
| `Path` | `Path` | Filesystem path; Copyable, Sendable, Hashable |

---

## Supporting Infrastructure

### [DS-009] Index and Tagging Types

**Statement**: These types are not containers but are used pervasively by data structures for type-safe access.

| Type | Import | Purpose |
|------|--------|---------|
| `Index<E>` | `Index_Primitives` | Phantom-typed index for type-safe collection access |
| `Index<E>.Offset` | | Typed signed displacement |
| `Index<E>.Count` | | Typed element count |
| `Tagged<Tag, Value>` | `Affine_Primitives` | Phantom-typed value wrapper; base for Index, Memory.Address |
| `Hash.Value` | `Hash_Primitives` | Typed hash value |
| `Hash.Protocol` | `Hash_Primitives` | ~Copyable-compatible hashing protocol |
| `Hash.Table<E>` | `Hash_Table_Primitives` | Open-addressed hash table; backing for Dictionary/Set (not standalone) |
| `Property<Tag, Base>` | `Property_Primitives` | CoW-safe mutation namespace |
| `Property<Tag, Base>.View` | | Pointer-based view for ~Copyable borrowed/consuming access |

---

## Decision Trees

### [DS-010] Container Selection Flowcharts

**Statement**: Use these decision trees to select the appropriate container type. After selecting the type, apply [DS-002] to choose the right variant.

**Sequential container**:
```
Need random access?
  Yes → Array<E>
  No  → Need ordering constraint?
    LIFO → Stack<E>
    FIFO → Need O(1) middle removal?
      Yes → Queue<E>.Linked
      No  → Queue<E>              (ring buffer)
    Both ends → Queue<E>.DoubleEnded
    Positional insert/remove → List.Linked<E, N>
```

**Associative container**:
```
Key-value pairs?
  Yes → Need insertion ordering?
    Yes → Dictionary<K, V>.Ordered  (linear-backed, O(n) remove)
    No  → Dictionary<K, V>          (slab-backed, O(1) remove)
  No (membership only) → Integer domain?
    Yes → Bitset                     (packed bits, no hashing)
    No  → Set.Ordered<E>            (hash set, insertion-ordered)
```

**Stable-index / arena container**:
```
Need use-after-free detection?
  Yes → Buffer.Arena<E>  (generation tokens via Position)
  No  → Slab<E>          (O(1) insert/remove, stable indices)
```

**Priority container**:
```
Need both min and max?
  Yes → Heap<E>.MinMax
  No  → Heap<E>
```

**Tree container**:
```
Key-indexed?  → Tree.Keyed<K>
Bounded arity? → Tree.N<E, n>  (Tree.Binary = Tree.N<2>)
Variable arity? → Tree.Unbounded<E>
```

**Memory allocator**:
```
Bulk reset, no individual dealloc?  → Memory.Arena
Fixed-capacity O(1) alloc/dealloc? → Memory.Pool
General-purpose?                    → Memory.Allocator
```

**Building a new container**:
1. Pick a Storage discipline → [DS-005]
2. Compose into a Buffer with Header → [DS-004]
3. Build Collection API on top → [DS-003]

---

## Cross-References

- **existing-infrastructure** skill for typed operators, boundary overloads, and Standard Library Integration modules
- **memory** skill for ~Copyable ownership, Sendable, and lifecycle rules
- **conversions** skill for Index<T>, Offset, Count arithmetic
- **memory-arithmetic** skill for Memory.Address typed arithmetic
- Research: `swift-institute/Research/ecosystem-data-structures-inventory.md` (full inventory with provenance)
- Research: `swift-institute/Research/comparative-*.md` (per-package deep dives against swift-io usage)
- Research: `swift-institute/Research/storage-buffer-abstraction-analysis.md` (Storage/Buffer design rationale)
