# Contributor Guidelines

@Metadata {
    @TitleHeading("Swift Institute")
}

Engineering requirements and standards for contributing to Swift Institute packages.

## Overview

This document defines the non-negotiable requirements for all packages in the Swift Institute. It covers contribution workflow, layer selection, and engineering practices.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

All requirements apply across all packages and targets unless an explicit, reviewed exception is recorded.

---

## Scope and Goals

**Applies to**: All contributors to Swift Institute packages.

**Does not apply to**: External dependencies or third-party integrations.

The requirements serve three interconnected purposes:

1. **Consistency** - Uniform patterns across 61+ packages reduce cognitive load
2. **Correctness** - Typed errors, lifecycle semantics, and memory safety are enforced by construction
3. **Longevity** - Timeless infrastructure requires disciplined engineering from day one

---

## Layer Selection

**Applies to**: All new contributions and architectural decisions.

**Does not apply to**: Bug fixes within existing layers.

---

### Layer Decision Tree

**Scope**: Determining where a contribution belongs.

**Statement**: Contributors MUST place code in the lowest applicable layer. Types MAY be promoted upward if they prove more general than initially thought.

Use this decision tree to determine where your contribution belongs:

```
Is it a type that standards require but do not define?
+-- Yes -> swift-primitives
|   Examples: Affine transforms, binary parsers, angle types
|
+-- No
    |
    Is it implementing an international specification (ISO, RFC, IEEE)?
    +-- Yes -> swift-standards
    |   Examples: ISO 32000 (PDF), RFC 3986 (URI), IEEE 754 (floating-point)
    |
    +-- No
        |
        Is it composing standards into domain-specific building blocks?
        +-- Yes -> swift-foundations
        |   Examples: swift-pdf, swift-http, swift-crypto
        |
        +-- No
            |
            Is it an opinionated UI component or application module?
            +-- Yes -> swift-components
            |   Examples: Document viewer, network client
            |
            +-- No -> swift-applications (end-user products)
```

**Rationale**: Starting at the lowest applicable layer ensures maximum reusability and prevents coupling to higher-level concerns.

---

## Contribution Workflow

**Applies to**: All pull requests and code submissions.

**Does not apply to**: Documentation-only changes (which follow a simplified process).

---

### Fork and Clone

**Scope**: Initial repository setup.

**Statement**: Contributors MUST fork the target repository and verify successful build and test execution before making changes.

**Correct**:
```bash
# Fork via GitHub UI, then:
git clone https://github.com/YOUR_USERNAME/swift-primitives.git
cd swift-primitives
swift build
swift test
```

**Incorrect**:
```bash
# Cloning directly without forking
git clone https://github.com/swift-institute/swift-primitives.git
# Making changes without verifying build
```

**Rationale**: Verifying the build environment before changes ensures issues are attributable to new code, not environment problems.

---

### Feature Branch Creation

**Scope**: Branch management.

**Statement**: Contributors MUST create feature branches from `main` with descriptive names following the pattern `feature/`, `fix/`, or `docs/`.

**Correct**:
```bash
git checkout -b feature/add-quaternion-rotation
git checkout -b fix/ordinal-overflow-check
git checkout -b docs/update-api-requirements
```

**Incorrect**:
```bash
# Non-descriptive branch names
git checkout -b my-changes
git checkout -b update
git checkout -b wip
```

**Rationale**: Descriptive branch names communicate intent and simplify code review and git history navigation.

---

### Implementation Requirements

**Scope**: All code changes.

**Statement**: All implementations MUST follow the requirements in <doc:API-Requirements>, <doc:Documentation-Standards>, and <doc:Testing-Requirements>.

Key requirements summary:

| Requirement | Layer | Reference |
|-------------|-------|-----------|
| No Foundation types | primitives, standards | |
| All public API documented | all | |
| All public API tested | all | |
| Typed errors only | all | |

**Correct**:
```swift
// In swift-primitives: No Foundation, typed errors
public struct Angle: Sendable {
    public let radians: Double

    public init(_ radians: Double) throws(Angle.Error) {
        guard radians.isFinite else { throw .notFinite }
        self.radians = radians
    }
}
```

**Incorrect**:
```swift
// Using Foundation in primitives
import Foundation
public struct Angle {
    public let radians: Double

    // Untyped throws
    public init(_ radians: Double) throws {
        guard radians.isFinite else { throw NSError(...) }
        self.radians = radians
    }
}
```

**Rationale**: Consistent adherence to requirements ensures interoperability across the 61+ package ecosystem.

---

### Local Testing

**Scope**: Pre-submission verification.

**Statement**: Contributors MUST run the full test suite locally before submitting a pull request. Cross-package changes MUST be tested using the workspace.

**Correct**:
```bash
# Single package testing
swift test

# Cross-package changes (when instructed to use workspace)
xcodebuild -workspace Standards.xcworkspace -scheme "Package Tests" test
```

**Incorrect**:
```bash
# Submitting without running tests
git push origin feature/my-change

# Running only a subset of tests
swift test --filter SomeSpecificTest
```

**Rationale**: Local test execution catches regressions before CI and reduces review iteration cycles.

---

### Pull Request Submission

**Scope**: Pull request content and format.

**Statement**: Pull requests MUST include a clear description of the change, links to relevant issues or discussions, and confirmation that tests pass locally.

**Correct**:
```markdown
## Summary
Add quaternion rotation support to Geometry module.

## Changes
- Add `Quaternion` type with SLERP interpolation
- Add `Rotation3D` protocol
- Update `Transform3D` to support quaternion composition

## Related Issues
Closes #142

## Testing
- [x] `swift test` passes locally
- [x] Added unit tests for all public API
```

**Incorrect**:
```markdown
Fixed stuff
```

**Rationale**: Detailed pull request descriptions enable efficient review and create valuable documentation for future maintainers.

---

## Commit Practices

**Applies to**: All commits to Swift Institute repositories.

**Does not apply to**: Squash-merged pull requests (where commit history is collapsed).

---

### Selective Staging for Focused Commits

**Scope**: Staging changes for commit.

**Statement**: Each commit MUST tell a single story. When a working directory contains unrelated changes, contributors MUST stage selectively to create focused commits.

**Correct**:
```bash
# Working directory has UUID addition + unrelated fixes
# Stage only the UUID-related files
git add Sources/Windows/Windows.Identity.UUID.swift
git add Tests/WindowsTests/UUIDTests.swift
git commit -m "Add native UUID parsing using Windows RPC"

# Remaining changes stay unstaged for a separate commit
```

**Incorrect**:
```bash
# Committing everything together
git add .
git commit -m "Add UUID parsing and fix various issues"
# ❌ Muddled story - git bisect becomes harder
```

Selective staging is documentation through git. Future readers (and bisectors) benefit from commits that change one thing.

**Rationale**: Focused commits create a navigable history. When debugging, `git bisect` works best when each commit represents a single logical change.

---

### Commit Message Contracts

**Scope**: Commit message content.

**Statement**: Commit messages MUST name the mechanism (how) and MAY explain the motivation (why). Platform-specific commits MUST identify the platform API used.

**Correct**:
```bash
# Platform primitives: name the mechanism
git commit -m "Add native UUID parsing using Darwin's uuid_parse"
git commit -m "Add native UUID parsing using libuuid"
git commit -m "Add native UUID parsing using Windows RPC"

# Consumer packages: explain the motivation
git commit -m "Add native platform UUID parsing for near-Foundation performance"
```

**Incorrect**:
```bash
git commit -m "Add UUID support"
# ❌ Missing mechanism - if UUID has issues, where do you look?

git commit -m "Performance improvements"
# ❌ Missing specificity - what was improved?
```

| Package Type | Message Focus | Example |
|--------------|---------------|---------|
| Platform primitives | Mechanism (how) | "using Darwin's uuid_parse" |
| Standards/consumers | Motivation (why) | "for near-Foundation performance" |

**Rationale**: Mechanisms matter for debugging. If a platform has issues, the commit message tells maintainers exactly where to investigate.

---

### Multi-Package Commit Ordering

**Scope**: Commits spanning multiple packages.

**Statement**: When committing related changes across multiple packages, commits SHOULD follow the dependency direction: primitives first, consumers last.

**Correct**:
```bash
# Platform primitives are independent peers - any order works
git commit -m "Add UUID parsing to Darwin primitives"
git commit -m "Add UUID parsing to Linux primitives"
git commit -m "Add UUID parsing to Windows primitives"

# Consumer depends on primitives - commit last
git commit -m "Integrate native UUID parsing in RFC 4122"
```

Platform primitives are architectural peers—they don't depend on each other. Standards packages depend on primitives but conditionally (builds succeed even if some primitives aren't committed yet). The primitives-first order matches the dependency graph.

**Rationale**: Following dependency order ensures the build remains valid at each commit point, supporting bisection and rollback.

---

## Topics

### Requirements

- <doc:API-Requirements>
- <doc:Documentation-Standards>
- <doc:Testing-Requirements>