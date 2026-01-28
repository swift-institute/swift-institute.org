# Embedded Swift

@Metadata {
    @TitleHeading("Swift Institute")
}

Requirements and patterns for Embedded Swift compatibility.

## Overview

This document defines requirements for writing Swift packages compatible with Embedded Swift compilation mode. Embedded Swift is a language subset targeting baremetal and resource-constrained environments.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## Quick Reference

| Section | Requirements | Focus |
|---------|--------------|-------|
| [Compilation](#compilation) | 3 | Toolchain, flags, build commands |
| [Concurrency Model](#concurrency-model) | 4 | What works, what doesn't, why |
| [Compatibility Patterns](#compatibility-patterns) | 3 | Writing dual-target code |

---

## Compilation

**Scope**: Building Swift code for Embedded targets.

---

### Development Toolchain Requirement

**Scope**: Toolchain selection for Embedded compilation.

**Statement**: Embedded Swift compilation MUST use a development snapshot toolchain. Release toolchains (Swift 6.x) fail with "module 'Swift' cannot be imported in embedded Swift mode."

**Correct**:
```bash
# Development snapshot toolchain
/path/to/swift-DEVELOPMENT-SNAPSHOT-2026-01-07-a.xctoolchain/usr/bin/swiftc \
    -enable-experimental-feature Embedded ...
```

**Incorrect**:
```bash
# Release toolchain - will fail
swiftc -enable-experimental-feature Embedded ...
# error: module 'Swift' cannot be imported in embedded Swift mode
```

**Rationale**: Embedded Swift is experimental. Release toolchains don't include the necessary runtime stubs.

---

### Required Compiler Flags

**Scope**: Compiler flags for Embedded compilation.

**Statement**: Embedded Swift compilation MUST include these flags:

| Flag | Purpose |
|------|---------|
| `-enable-experimental-feature Embedded` | Enable Embedded mode |
| `-wmo` | Whole module optimization (required) |
| `-parse-as-library` | Library code without main entry |
| `-package-name <name>` | Required if using `package` access level |

**Correct**:
```bash
swiftc -enable-experimental-feature Embedded -wmo -parse-as-library \
    -package-name MyPackage Sources/*.swift
```

---

### Cross-Compilation Flags

**Scope**: Targeting specific embedded architectures.

**Statement**: Cross-compilation for embedded targets SHOULD use architecture-specific flags:

```bash
# ARM Cortex-M example
swiftc -enable-experimental-feature Embedded -wmo \
    -target armv7em-none-none-eabi \
    -Osize \
    -Xfrontend -disable-stack-protector \
    Sources/*.swift
```

The `-Osize` flag optimizes for binary size. The `-disable-stack-protector` removes stack canaries (unavailable on baremetal).

---

## Concurrency Model

**Scope**: Concurrency feature availability in Embedded Swift.

---

### Three-Tier Availability Model

**Scope**: Understanding which concurrency features work.

**Statement**: Concurrency features in Embedded Swift fall into three categories:

| Tier | Behavior | Features |
|------|----------|----------|
| **Fully available** | Compile AND link | `Sendable`, `@Sendable`, `sending`, `nonisolated`, `actor` (sync only) |
| **Compile-only** | Compile, fail to link | `async/await`, `Task`, `AsyncSequence`, `#isolation` |
| **Unavailable** | Fail to compile | `@MainActor` |

**Rationale**: Swift's concurrency *type system* is present in Embedded mode. The *runtime* (scheduler, task creation) is not.

---

### Compile-Only Features

**Scope**: Features that compile but fail to link.

**Statement**: Features in the "compile-only" tier produce linker errors referencing missing runtime symbols:

```
Undefined symbols for architecture arm64:
  "_swift_task_switch"
  "_swift_task_create"
  "_swift_task_asyncMainDrainQueue"
```

This boundary reveals the architectural split: type checking works; runtime dispatch doesn't.

**Implication**: Libraries MAY define async API surfaces with `#if !hasFeature(Embedded)` guards. The guards are about runtime availability, not language availability.

---

### The @MainActor Exception

**Scope**: Why `@MainActor` fails differently.

**Statement**: `@MainActor` produces "unknown attribute" at parse time, not link time:

```swift
@MainActor
struct Data { }
// error: unknown attribute 'MainActor'
```

**Rationale**: `MainActor` has platform semantics (main dispatch queue, main thread). Embedded systems have no standard "main execution context." The attribute is undefined because the concept is undefined.

Custom global actors (`@MyGlobalActor`) compile (though they fail to link). The difference: custom actors have no platform-specific meaning.

---

### Sendable as the Embedded Story

**Scope**: What concurrency model is actually available.

**Statement**: The fully-available concurrency subset centers on `Sendable`:

- `Sendable` protocol conformance
- `@Sendable` closure annotation
- `sending` parameter modifier
- `@unchecked Sendable` escape hatch
- `nonisolated` function modifier
- `actor` keyword (sync usage only)

Every item is a compile-time annotation informing the type checker. None require runtime support.

**Design implication**: For Embedded systems, this enables types designed for concurrent access without actual concurrent execution—suitable for interrupt contexts and event loops.

---

### Explicit Concurrency Import

**Scope**: Import requirements for concurrency types.

**Statement**: Concurrency types (`Task`, `Actor`) require explicit `import _Concurrency` in Embedded mode:

```swift
import _Concurrency  // Required in Embedded, implicit in standard Swift

actor Counter { ... }
```

Without the import, `Task` produces "cannot find 'Task' in scope." This asymmetry can trap developers porting async code to Embedded.

---

## Compatibility Patterns

**Scope**: Writing code that works in both standard and Embedded Swift.

---

### Conditional Compilation Guards

**Scope**: Feature guards for Embedded compatibility.

**Statement**: Packages targeting Embedded Swift MUST use `#if !hasFeature(Embedded)` guards around unavailable features:

**Correct**:
```swift
#if !hasFeature(Embedded)
extension Tagged: Codable where RawValue: Codable { }
#endif

#if !hasFeature(Embedded)
public func fetchAsync() async throws -> Data { ... }
#endif
```

**Features requiring guards**:

| Feature | Reason |
|---------|--------|
| `Codable` | Requires reflection |
| `CustomStringConvertible` | May require reflection |
| `async` functions | Runtime unavailable |
| Existentials (`any`) | Not supported |
| Foundation types | Not available |

---

### Sync Alternatives Pattern

**Scope**: Providing non-async APIs alongside async APIs.

**Statement**: Libraries with async APIs SHOULD provide sync alternatives for Embedded compatibility:

```swift
// Available everywhere
public func read(from descriptor: Descriptor) throws(IO.Error) -> Data

// Standard Swift only
#if !hasFeature(Embedded)
public func read(from descriptor: Descriptor) async throws(IO.Error) -> Data
#endif
```

The `Sendable` annotations carry forward into Embedded builds. The async APIs disappear. What remains is type-safe data structures ready for manual concurrency coordination.

---

### Binary Size as Feedback

**Scope**: Using binary size to verify Embedded compilation.

**Statement**: Embedded compilation SHOULD produce significantly smaller binaries than standard compilation. A 60-70% size reduction indicates Embedded mode is working correctly:

| Target | Size | Indicates |
|--------|------|-----------|
| macOS arm64 | ~22KB | Full runtime metadata |
| ARM Cortex-M | ~6KB | Embedded mode working |

The size reduction proves what Embedded mode removes: runtime metadata, reflection support, existential containers, dynamic dispatch infrastructure.

---

## Compiler Behavior

**Scope**: Understanding compiler responses in Embedded mode.

---

### Crash vs Error Distinction

**Scope**: Interpreting compiler failures.

**Statement**: Compiler crashes (signal 11) and error messages have different implications:

| Response | Indicates | Example |
|----------|-----------|---------|
| Error message | Intentional restriction | `@MainActor` → "unknown attribute" |
| Compiler crash | Incomplete implementation | `actor` + `await` → signal 11 |

A crash during SIL generation suggests the feature is partially implemented and may work in future toolchains. Documentation SHOULD note this as "not yet implemented" rather than "crashes."

---

## Topics

### Related Documents

- <doc:Swift-Embedded-compilation> - Step-by-step compilation procedures
- <doc:API-Requirements>
- <doc:Implementation-Patterns>
- <doc:Primitives-Architecture>

### Cross-References

- Conditional Compilation Foresight
- Empirical Verification as Documentation Source
