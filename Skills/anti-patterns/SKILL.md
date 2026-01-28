---
name: anti-patterns
description: |
  Common mistakes and anti-patterns to avoid.
  Reference this skill when reviewing code for correctness.

layer: implementation

requires:
  - swift-institute
  - naming
  - errors
  - code-organization

applies_to:
  - swift
  - swift6
  - primitives
  - standards
  - foundations

migrated_from: Implementation/Anti-Patterns.md
migration_date: 2026-01-28
---

# Anti-Patterns

Common mistakes to avoid in Swift Institute code.

---

## Naming Anti-Patterns

### [ANTI-001] Compound Type Names

```swift
// ANTI-PATTERN
struct FileDirectoryWalk { }
enum ConnectionState { }
class NetworkRequestHandler { }

// CORRECT
struct File.Directory.Walk { }
enum Connection.State { }
class Network.Request.Handler { }
```

---

### [ANTI-002] Compound Method Names

```swift
// ANTI-PATTERN
func walkFiles() { }
func openWrite() { }

// CORRECT
func walk.files() { }
func open.write() { }
// Or use nested accessor pattern with Property<Tag, Base>
```

---

## Error Handling Anti-Patterns

### [ANTI-003] Untyped Throws

```swift
// ANTI-PATTERN
func read() throws -> Data {
    // Error type erased
}

// CORRECT
func read() throws(IO.Error) -> Data {
    // Error type preserved
}
```

---

### [ANTI-004] Compound Error Types

```swift
// ANTI-PATTERN
enum ParseError: Error {
    case invalidHeader(expected: UInt32, found: UInt32)
}

// CORRECT
enum Parse {
    enum Error: Swift.Error {
        case invalidHeader(expected: UInt32, found: UInt32)
    }
}
```

---

## File Organization Anti-Patterns

### [ANTI-005] Multiple Types Per File

```swift
// ANTI-PATTERN - File: Models.swift
struct User { }
struct Profile { }
struct Settings { }

// CORRECT - Separate files
// User.swift
struct User { }

// Profile.swift
struct Profile { }

// Settings.swift
struct Settings { }
```

---

## Memory Anti-Patterns

### [ANTI-006] Storage in Extensions

```swift
// ANTI-PATTERN - Storage loses ~Copyable context
extension Stack {
    final class Storage: ManagedBuffer<Int, Element> { }
}

// CORRECT - Storage in type body
struct Stack<Element: ~Copyable>: ~Copyable {
    final class Storage: ManagedBuffer<Int, Element> { }
}
```

---

### [ANTI-007] Foundation in Primitives

```swift
// ANTI-PATTERN - Foundation in primitives
import Foundation

struct Event {
    let timestamp: Date   // Foundation.Date
    let payload: Data     // Foundation.Data
}

// CORRECT - Use primitives types
import Time_Primitives
import Binary_Primitives

struct Event {
    let timestamp: Instant
    let payload: Binary.Buffer
}
```

---

## Cross-References

See also:
- **naming** skill for correct naming patterns
- **errors** skill for correct error handling
- **memory** skill for correct ~Copyable patterns
