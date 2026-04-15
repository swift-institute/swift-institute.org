# Platform

@Metadata {
    @TitleHeading("Swift Institute")
}

Cross-platform Swift infrastructure — how the ecosystem achieves portability, and what is specific to each platform.

## Overview

The Swift Institute ecosystem is designed for cross-platform correctness. The same code compiles on Darwin, Linux, and (soon) Embedded Swift and Windows. Platform-specific behaviour is isolated to designated packages; consumer code is unconditional.

| Platform | Status |
|----------|--------|
| Darwin (macOS, iOS, tvOS, watchOS, visionOS) | Supported |
| Linux (glibc, musl) | Supported |
| Embedded Swift | Coming soon |
| Windows | Coming soon |

---

## How cross-platform abstraction works

Platform code is organized into three levels:

```
Foundations   swift-kernel            Unified cross-platform module — `import Kernel`
                    ↑
              swift-darwin             Darwin-specific extensions
              swift-linux              Linux-specific extensions
              swift-windows            Windows-specific extensions
                    ↑
Standards     swift-iso-9945           POSIX (IEEE 1003.1) — shared by Darwin and Linux
              swift-linux-standard     Linux kernel API (epoll, io_uring)
              swift-darwin-standard    Darwin kernel API (kqueue, mach)
              swift-windows-standard   Windows kernel API (IOCP, WinSock)
                    ↑
Primitives    swift-kernel-primitives  Cross-platform syscall vocabulary
              swift-cpu-primitives     CPU vocabulary (atomics, barriers, spin hints)
```

Consumer code writes one import:

```swift
import Kernel

// The right platform is wired automatically. No platform conditionals.
let descriptor = try Kernel.File.open(path, .read)
```

Platform conditionals exist in exactly two places across the ecosystem: the `Exports.swift` files inside `swift-kernel`, and `Package.swift` dependency conditions. Everywhere else is unconditional.

---

## Unified types

A single `Kernel.Descriptor` type represents file handles, socket handles, and OS resource handles on all platforms. It wraps `Int32` on POSIX systems and `HANDLE` on Windows; platform-specific veneers provide access to the underlying representation when needed.

```swift
// Consumer code — platform-agnostic.
let fd: Kernel.Descriptor = try Kernel.File.open(path, .read)

// POSIX veneer — available on Darwin and Linux.
let posixFD: Int32 = fd.fileDescriptor

// Windows veneer — available on Windows.
let handle: HANDLE = fd.handle
```

Cross-platform code never sees `Int32` or `HANDLE` directly. Platform-specific code that needs raw access uses the appropriate veneer.

---

## Darwin

Supported. Darwin covers macOS, iOS, tvOS, watchOS, and visionOS.

**Standards layer**: `swift-darwin-standard` models the Darwin/XNU kernel API — `kqueue`, mach ports, `clonefile`, `copyfile`, Mach-O loader types, Darwin-specific memory and thread APIs.

**Foundations layer**: `swift-darwin` extends `swift-kernel` with Darwin-specific L3 code — NUMA, entropy, thread affinity, and other capabilities that exist only on Apple platforms.

**Shared with Linux**: The POSIX surface is implemented in `swift-iso-9945` (IEEE 1003.1 specification). Code that targets POSIX works identically on Darwin and Linux.

---

## Linux

Supported. Targets glibc and musl C libraries.

**Standards layer**: `swift-linux-standard` models the Linux kernel API — `epoll`, `io_uring`, `futex`, `eventfd`, Linux-specific syscalls and their ABI.

**Foundations layer**: `swift-linux` extends `swift-kernel` with Linux-specific L3 code — NUMA via libnuma, Linux-specific thread affinity, cgroups integration points.

**Shared with Darwin**: POSIX surface is implemented in `swift-iso-9945`. Code that targets POSIX works identically on Darwin and Linux.

---

## Embedded Swift

Coming soon.

Embedded Swift is a language subset targeting baremetal and resource-constrained environments. Primitives and standards packages are designed for Embedded compatibility: no Foundation, no reflection, no existentials in public API, minimal standard-library dependencies.

Foundations packages that compose only Embedded-compatible dependencies are also Embedded-compatible. Packages using async runtimes, existentials, or features unavailable in Embedded mode are guarded with `#if !hasFeature(Embedded)`.

See <doc:Embedded-Swift> for the patterns and constraints involved.

---

## Windows

Coming soon.

**Standards layer**: `swift-windows-standard` will model the Windows kernel API — I/O Completion Ports (IOCP), WinSock, Windows loader types, Windows-specific memory and thread APIs.

**Foundations layer**: `swift-windows` will extend `swift-kernel` with Windows-specific L3 code.

The `Kernel.Descriptor` type is already designed to wrap `HANDLE` on Windows; the scaffolding is in place.

---

## Placement rules

Platform code placement follows strict rules so platform-specific logic never leaks into consumer packages:

| The code is... | Placed in... |
|----------------|-------------|
| Cross-platform syscall vocabulary | `swift-kernel-primitives` |
| A POSIX syscall shared by Darwin and Linux | `swift-iso-9945` |
| A raw syscall specific to one platform | `swift-{platform}-standard` |
| A higher-level abstraction over platform primitives | `swift-{platform}` (L3) |
| Cross-platform composed behaviour | `swift-kernel` (L3) |

Consumer code writes `import Kernel` and sees the correct platform automatically. No consumer package contains platform conditionals.
