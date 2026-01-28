# Errors

<!--
---
title: Errors
version: 1.0.0
last_updated: 2026-01-28
applies_to: [swift-primitives, swift-standards, swift-foundations]
normative: true
---
-->

@Metadata {
    @TitleHeading("Implementation")
}

Error handling conventions for all Swift Institute packages.

## Overview

This document defines error handling requirements. All packages MUST use typed throws for precise error propagation.

---

## Typed Throws

### [API-ERR-001] Typed Throws

**Scope**: All throwing functions.

**Statement**: All throwing functions MUST use typed throws.

**Correct**:
```swift
func read() throws(IO.Error) -> Data
func parse() throws(Parse.Error) -> Document
```

**Incorrect**:
```swift
func read() throws -> Data       // Erases error type
func parse() throws(any Error)   // Existential error
```

**Rationale**: Typed throws enable exhaustive error handling at compile time and eliminate runtime type checking overhead.

---

### [API-ERR-002] Error Type Naming

**Scope**: All error type declarations.

**Statement**: Error types MUST be nested as `Domain.Error` following [API-NAME-001].

**Correct**:
```swift
enum IO {
    enum Error: Swift.Error {
        case posix(errno: CInt, operation: Operation, path: FilePath)
        case timeout(duration: Duration, operation: Operation)
    }
}
```

**Incorrect**:
```swift
enum IOError: Error {           // Compound name
    case posix(...)
}
```

---

### [API-ERR-003] Error Case Naming

**Scope**: All error cases.

**Statement**: Error cases SHOULD describe the failure condition, not the recovery action.

**Correct**:
```swift
case invalidHeader(expected: UInt32, found: UInt32)
case insufficientCapacity(required: Int, available: Int)
```

**Incorrect**:
```swift
case retryLater              // Describes recovery, not failure
case useDefaultValue         // Describes recovery, not failure
```

---

## Topics

### Related
- <doc:Naming>
- <doc:Code-Organization>
