# Systems Programming

@Metadata {
    @TitleHeading("Swift Institute")
}

Platform abstraction, kernel layer, loader distinction, and memory safety architecture for systems-level Swift packages.

## Overview

This document defines the architectural principles and requirements for systems programming in the Swift Primitives ecosystem. It establishes boundaries between portable abstractions and platform-specific implementations, kernel and userspace operations, and memory safety mechanisms.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## Platform Abstraction

**Applies to**: All cross-platform primitives in swift-primitives, swift-cpu-primitives, and related packages.

**Does not apply to**: Platform-specific extension packages (swift-x86-primitives, swift-arm-primitives).

---

### Weakest-Semantics Guarantee

**Scope**: Portable operations including CPU barriers, spin hints, and timestamps.

**Statement**: Portable primitives MUST guarantee only the semantics provided by the weakest supported architecture. Operations MUST NOT rely on stronger guarantees that exist only on specific platforms.

**Correct**:
```swift
// CPU.Barrier provides memory ordering guarantees
// Semantics match the weakest platform (ARM's relaxed model)
// Code works correctly on both x86 and ARM
CPU.Barrier.memory()  // Explicit barrier required everywhere
```

**Incorrect**:
```swift
// Relying on x86's strong ordering without explicit barriers
// Works on x86, fails subtly on ARM
sharedState = newValue  // No barrier - undefined on ARM
```

**Rationale**: This conservative approach prevents subtle bugs where code works on strongly-ordered x86 but fails on weakly-ordered ARM. The portable API exposes the intersection of platform capabilities, not the union.

---

### Platform-Specific Extensions

**Scope**: Architecture-unique operations not available on all platforms.

**Statement**: Architecture-specific operations MUST exist in dedicated platform packages. These packages MUST be conditionally included based on compilation target. Platform-specific APIs MUST NOT pollute the portable API surface.

**Correct**:
```swift
// swift-x86-primitives: x86-specific operations
#if arch(x86_64)
import X86Primitives
let cpuInfo = X86.CPUID.query()
let timestamp = X86.RDTSCP.read()
let random = X86.RDRAND.generate()
#endif

// swift-arm-primitives: ARM-specific operations
#if arch(arm64)
import ARMPrimitives
ARM.WFE.wait()      // Wait-for-event
ARM.SEV.signal()    // Send-event
#endif
```

**Incorrect**:
```swift
// Platform-specific operations in portable package
// Pollutes API surface for all platforms
public struct CPU {
    public static func rdtscp() -> UInt64  // x86 only
    public static func wfe()               // ARM only
}
```

**Rationale**: Separation enables platform-specific optimizations without requiring `#if` conditionals in user code. Users import platform packages explicitly when needed.

---

## Kernel Abstraction Layer

**Applies to**: swift-kernel-primitives and all syscall-wrapping code.

**Does not apply to**: Userspace library wrappers.

---

### Kernel API Scope

**Scope**: All types and functions in swift-kernel-primitives.

**Statement**: The kernel abstraction layer MUST provide syscall-shaped APIs unified across platforms. Kernel MUST export only: raw descriptors, buffers, primitives, errors, path validation, and system queries. Kernel MUST NOT export: policy, discovery, derived semantics, or third-party types.

**Correct**:
```swift
// Kernel exports raw syscall wrappers
Kernel.File       // File descriptor operations
Kernel.Socket     // Socket operations
Kernel.Thread     // Threading primitives
Kernel.Memory     // Memory management (mmap, mlock)
Kernel.Event      // Event polling (epoll, kqueue, IOCP)

// Raw operations, no policy
let fd = try Kernel.File.open(path, flags: .readOnly)
let bytes = try Kernel.File.read(fd, into: buffer)
```

**Incorrect**:
```swift
// Policy embedded in kernel layer
Kernel.File.openWithRetry(path, maxAttempts: 3)  // Policy

// Discovery in kernel layer
Kernel.File.findExecutable(named: "swift")       // Discovery

// Third-party types
Kernel.File.read(into: foundationData)           // Foundation dependency
```

**Rationale**: The kernel layer remains a thin wrapper over syscalls without imposing architectural decisions. Higher layers in application packages implement policy, retry logic, and discovery.

---

### Kernel Layer Restrictions

**Scope**: Implementation of kernel primitives.

**Statement**: The kernel layer MUST NOT embed lifecycle policy, introduce cancellation or shutdown semantics, construct user-facing errors requiring runtime context, or depend on higher-level scheduling decisions.

**Correct**:
```swift
// Kernel returns raw errors
enum Kernel.Error {
    case posix(errno: CInt)
    case windows(code: DWORD)
}

// No lifecycle semantics
func read(_ fd: Descriptor, into buffer: UnsafeMutableRawBufferPointer)
    throws(Kernel.Error) -> Int
```

**Incorrect**:
```swift
// Lifecycle policy in kernel layer
func read(_ fd: Descriptor) async throws -> Data  // Async implies runtime

// Cancellation in kernel layer
func read(_ fd: Descriptor, cancellation: CancellationToken) throws

// User-facing errors with context
struct ReadError: Error {
    let message: String  // Runtime-constructed message
}
```

**Rationale**: Separation ensures the kernel layer remains testable and reusable across different runtime contexts. Lifecycle, cancellation, and rich errors belong in higher layers.

---

## Loader vs Kernel Distinction

**Applies to**: Dynamic linking operations (dlopen, dlsym, LoadLibrary).

**Does not apply to**: Syscall wrappers (mmap, read, write, socket).

---

### Loader Primitives Separation

**Scope**: Dynamic linker operations.

**Statement**: Dynamic linker operations (`dlopen`, `dlsym` on POSIX; `LoadLibrary`, `GetProcAddress` on Windows) MUST be implemented in swift-loader-primitives, NOT swift-kernel-primitives. These operations are userspace library functions, not syscalls.

**Correct**:
```swift
// Loader operations in swift-loader-primitives
import LoaderPrimitives

let handle = try Loader.open("libfoo.so")
let symbol = try Loader.symbol(handle, named: "initialize")
```

**Incorrect**:
```swift
// Loader operations in kernel package
import KernelPrimitives

let handle = try Kernel.dlopen("libfoo.so")  // Not a syscall
```

**Rationale**: `dlopen`/`dlsym` are implemented by the dynamic linker (libdl on Linux, dyld on Darwin, Win32 loader on Windows), not the kernel. This distinction matters for understanding security boundaries, performance characteristics, and error handling.

| Layer | Package | Operations |
|-------|---------|------------|
| Kernel | swift-kernel-primitives | mmap, read, write, socket, epoll |
| Loader | swift-loader-primitives | dlopen, dlsym, LoadLibrary |

---

## Memory Safety Architecture

**Applies to**: All memory-critical packages in swift-primitives.

**Does not apply to**: Higher-level application code with different safety tradeoffs.

> **Comprehensive guidance**: See <doc:Memory> for complete memory ownership patterns, `~Copyable` types, strict memory safety, and reference primitives.

---

### Strict Memory Safety Mode

**Scope**: Memory-critical packages.

**Statement**: Memory-critical packages MUST enable strict memory safety mode via `.strictMemorySafety()` in the package manifest.

> **Full details**: See <doc:Memory> for configuration and feature flags.

---

### Noncopyable Resource Handles

**Scope**: Resource handles (buffers, file descriptors, allocated memory).

**Statement**: Resource handles MUST use noncopyable types (`~Copyable`) to enforce unique ownership.

> **Full details**: See <doc:Memory> for patterns and code examples.

---

### Lifetime Annotations

**Scope**: APIs exposing temporary pointers or references.

**Statement**: APIs that expose pointers or references with limited lifetime MUST use lifetime annotations (`@_lifetime`) to ensure the compiler enforces scope constraints.

> **Full details**: See <doc:Memory> for lifetime annotation patterns.

---

## Summary

The memory safety mechanisms work together:

| Mechanism | Prevents | Enforcement |
|-----------|----------|-------------|
| Strict Memory Safety | Unsafe operations | Package manifest |
| Noncopyable Types | Double-free, shared mutation | Type system |
| Lifetime Annotations | Use-after-free, escaping pointers | Compiler |

These compile-time guarantees eliminate entire classes of memory safety bugs without runtime overhead.

**Cross-references**: <doc:Memory>, <doc:API-Requirements>, <doc:Five-Layer-Architecture>