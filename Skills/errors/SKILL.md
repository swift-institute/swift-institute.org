---
name: errors
description: |
  Error handling conventions: typed throws, error type naming, case naming.
  ALWAYS apply when declaring throwing functions or error types.

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

migrated_from: Implementation/Errors.md
migration_date: 2026-01-28
---

# Error Handling Conventions

All error handling MUST follow these rules.

---

## Typed Throws

### [API-ERR-001] Typed Throws Required

All throwing functions MUST use typed throws.

```swift
// CORRECT
func read() throws(IO.Error) -> Data
func parse() throws(Parse.Error) -> Document

// INCORRECT
func read() throws -> Data       // Erases error type - FORBIDDEN
func parse() throws(any Error)   // Existential error - FORBIDDEN
```

**Rationale**: Typed throws enable exhaustive error handling at compile time and eliminate runtime type checking overhead.

---

## Error Type Naming

### [API-ERR-002] Nested Error Types

Error types MUST be nested as `Domain.Error` following [API-NAME-001].

```swift
// CORRECT
enum IO {
    enum Error: Swift.Error {
        case posix(errno: CInt, operation: Operation, path: FilePath)
        case timeout(duration: Duration, operation: Operation)
    }
}

// INCORRECT
enum IOError: Error {           // Compound name - FORBIDDEN
    case posix(...)
}
```

---

## Error Case Naming

### [API-ERR-003] Describe Failure, Not Recovery

Error cases SHOULD describe the failure condition, not the recovery action.

```swift
// CORRECT
case invalidHeader(expected: UInt32, found: UInt32)
case insufficientCapacity(required: Int, available: Int)
case connectionRefused(host: String, port: UInt16)

// INCORRECT
case retryLater              // Describes recovery, not failure
case useDefaultValue         // Describes recovery, not failure
```

---

### [API-ERR-004] Include Diagnostic Information

Error cases SHOULD include associated values with diagnostic information.

```swift
// CORRECT - Rich diagnostic information
case invalidHeader(expected: UInt32, found: UInt32)
case outOfBounds(index: Int, count: Int)

// INCORRECT - No diagnostic information
case invalidHeader
case outOfBounds
```

---

## Cross-References

See also:
- **naming** skill for general naming rules
- **code-organization** skill for error file placement
