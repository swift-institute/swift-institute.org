# C Shims

<!--
---
title: C Shims
version: 1.0.0
last_updated: 2026-01-19
applies_to: [swift-primitives, swift-institute, swift-standards]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

C shim layer structure for platform-specific functionality.

## Overview

This document defines the C shim architecture for Swift Institute packages requiring platform-specific functionality.

**Applies to**: Packages requiring platform-specific functionality (math primitives, system calls, hardware access).

**Does not apply to**: Pure Swift packages with no platform dependencies.

---

## [PATTERN-001] C Shim Layer Structure

**Scope**: Package organization for platform-specific code.

**Statement**: Where platform-specific functionality is required, packages MUST use minimal C shim targets isolated from Swift code.

**Correct**:
```
swift-numeric-primitives/
├── _Shims/                          # C target
│   └── include/
│       └── shims.h                  # C declarations (sin, cos, exp, etc.)
└── Real Primitives/
    └── Numeric.Math.swift           # Swift wrapper
```

**Incorrect**:
```
swift-numeric-primitives/
└── Real Primitives/
    ├── Numeric.Math.swift
    └── platform_shims.c             # ❌ C code mixed with Swift
```

The C shim layer:
- Isolates platform-specific inline assembly
- Provides unified interface across Darwin (libm), Glibc, Musl
- Remains internal—not exposed in public API

**Rationale**: Isolating C code minimizes unsafe code exposure while providing access to platform primitives. Separation enables independent testing and platform-specific optimization.

**Cross-references**: [API-PLAT-001], [PATTERN-002]

---

## C Shim as Semantic Boundary

**Scope**: Swift/C interop in platform primitives.

C shims exist not just for technical bridging but as semantic boundaries. Each platform's shim MUST be independent—even when wrapping identical C functions—to maintain independent compilability.

**Correct**:
```c
// CDarwinKernelShim/uuid_shim.h
#include <uuid/uuid.h>
static inline int swift_uuid_parse(const char* str, unsigned char* out) {
    return uuid_parse(str, out);
}

// CLinuxKernelShim/uuid_shim.h (SEPARATE FILE - same content but independent)
#include <uuid/uuid.h>
static inline int swift_uuid_parse(const char* str, unsigned char* out) {
    return uuid_parse(str, out);
}
```

**Incorrect**:
```c
// ❌ Shared header with conditionals
#if defined(__APPLE__)
#include <uuid/uuid.h>
#elif defined(__linux__)
#include <uuid/uuid.h>
#elif defined(_WIN32)
#include <rpc.h>
// Windows has different semantics - corrupts the abstraction
#endif
```

**Why Duplication is Intentional**:

Darwin's `uuid_parse` and Linux's `uuid_parse` have identical signatures and semantics, yet they live in separate shim files. This duplication ensures:
1. Packages compile independently
2. No conditional compilation hell
3. Platform-specific semantics (like Windows byte reordering) stay isolated

The Windows case proves the necessity: `UuidFromStringA` produces mixed-endian bytes. If shims were unified, Windows-specific logic would corrupt the "shared" layer.

**Rationale**: The shim declares "this is the contract" while the system library provides the implementation. Separation keeps platform accidents from leaking across boundaries.

**Cross-references**: [PRIM-ORG-003], [PATTERN-004c]

---

## Topics

### Related Documents

- <doc:Implementation>
- <doc:Multi-Library>
- <doc:Platform-Compilation>
