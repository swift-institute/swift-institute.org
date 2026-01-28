# Issue Submission

@Metadata {
    @TitleHeading("Swift Institute")
}

Workflow for creating minimal reproduction packages and submitting Swift compiler issues after experiments identify genuine compiler bugs.

## Overview

This document defines the *issue submission workflow*—the process followed after an experiment (per the **experiment-process** skill (investigation workflow)) surfaces behavior that appears to be a genuine Swift compiler bug. Issue packages are created in `/Users/coen/Developer/coenttb/` under the `coenttb` GitHub organization.

**Entry point**: An experiment concluded with `Result: REFUTED` or unexpected behavior that appears to be a compiler bug, not user error.

**Prerequisites**:
1. Completed experiment per the **experiment-process** skill
2. Verified the behavior is not documented/expected
3. Reduced the reproduction to minimal form per

**Output**: A standalone GitHub repository containing a minimal reproduction, comprehensive README, and inline documentation suitable for a Swift compiler issue report.

**Applies to**: Compiler crashes, silent wrong behavior, incorrect code generation, memory leaks.

**Does not apply to**: Feature requests (use Swift Forums), documented limitations, user errors, or bugs in third-party libraries.

 Compiler Bug

An experiment result of `REFUTED` indicates that the original hypothesis ("this should work") is disproven. When the refutation cannot be explained by documented behavior or user error, it is treated as evidence of a compiler defect and becomes eligible for issue submission.

---

## Quick Reference: Issue Submission Decision

**Scope**: Decision criteria for creating issue packages.

| Criterion | Create Issue Package | Do Not Create |
|-----------|---------------------|---------------|
| Compiler crash (signal 11, assertion) | ✓ | |
| Silent incorrect behavior (wrong output) | ✓ | |
| Documented limitation | | ✓ |
| User error (constraint violation) | | ✓ |
| Feature request | | ✓ (use forums) |
| Regression from previous version | ✓ (high priority) | |
| Affects multiple Swift Institute packages | ✓ (note in impact) | |

---

## Assistant-Driven Workflow

**Scope**: Automated issue submission when this document is referenced after an experiment.

**Statement**: When pointed to this document after an experiment surfaces a compiler bug, the assistant MUST execute the following interactive workflow.

### Phase 1: Preparation

1. **Gather context** from the completed experiment:
   - Minimal reproduction code
   - Conditions required to trigger the bug
   - Verified working cases
   - Crash output (if applicable)
   - Swift version and environment

2. **Draft the issue package**:
   - Generate repository name per
   - Create Package.swift per
   - Create source file(s) with inline documentation per
   - Create README.md per
   - Create test target if runtime bug per

3. **Present for review**:
   - Display the complete package structure
   - Display the README content
   - Display the source file content
   - Highlight the conditions and minimal reproduction

### Phase 2: Confirmation

4. **Ask for confirmation**:

   > **Ready to submit issue?**
   >
   > Repository: `swift-issue-{name}`
   > Conditions: {N} conditions identified
   > Minimal reproduction: {N} lines
   > Workaround: {Yes/No}
   >
   > Please confirm:
   > - [ ] Reproduction is correct and minimal
   > - [ ] Conditions are accurately documented
   > - [ ] README accurately describes the bug
   >
   > **Proceed with GitHub submission?**

5. **Await explicit approval** before proceeding. Do NOT create repositories or file issues without confirmation.

### Phase 3: Submission

Upon confirmation:

6. **Create the repository**:
   ```bash
   cd /Users/coen/Developer/coenttb/
   mkdir swift-issue-{name}
   cd swift-issue-{name}
   git init
   # Write all files
   git add .
   git commit -m "Minimal reproduction: {short description}"
   gh repo create coenttb/swift-issue-{name} --public --source=. --remote=origin --push
   ```

7. **Search for duplicates**:
   ```bash
   gh search issues --repo swiftlang/swift "{key terms}" --limit 10
   ```

8. **Present duplicate check results** and ask whether to proceed or link to existing issue.

9. **File the issue** (upon confirmation):
   ```bash
   gh issue create --repo swiftlang/swift \
     --title "{Crash/Bug}: {short description}" \
     --body "$(cat <<'EOF'
   ## Description

   {description}

   ## Environment

   - Swift version: {version}
   - Target: {target}

   ## Minimal Reproduction

   ```swift
   {code}
   ```

   ## Reproduction Repository

   https://github.com/coenttb/swift-issue-{name}

   ## Conditions Required

   {conditions table}

   ## Workaround

   {workaround if any}

   ## Impact

   {impact description}
   EOF
   )"
   ```

10. **Update README** with issue link:
    ```bash
    # Append issue link to README.md
    git add README.md
    git commit -m "Link to swiftlang/swift#{number}"
    git push
    ```

11. **Report completion**:
    > Issue filed: https://github.com/swiftlang/swift/issues/{number}
    > Repository: https://github.com/coenttb/swift-issue-{name}

### Abort Conditions

The workflow MUST abort and request clarification if:

- Reproduction does not compile/crash as expected when tested
- No working cases can be identified (bug may not be isolated)
- `gh` CLI is not authenticated
- Repository name already exists
- Duplicate issue found (offer to comment on existing instead)

---

## Repository Location and Naming

**Scope**: Where to create issue packages and how to name them.

**Statement**: Issue packages MUST be created in `/Users/coen/Developer/coenttb/` with the naming pattern `swift-issue-{crash-location}-{key-feature}` or `swift-issue-{behavior}-{key-feature}`.

### Naming Pattern

```text
swift-issue-{identifier}
         │
         └─ Kebab-case description combining:
            • Crash location (irgen, silgen, sema) OR behavior (deinit, inference)
            • Key features involved (async, noncopyable, pack-expansion)
```

### Naming Examples

| Issue Type | Repository Name |
|------------|-----------------|
| IRGen crash with async + typed throws + ~Copyable | `swift-issue-irgen-async-typed-throws-noncopyable` |
| SILGen crash with parameter pack cross-module | `swift-issue-silgen-pack-expansion-cross-module` |
| Deinit not called with InlineArray + value generic | `swift-issue-inlinearray-deinit-value-generic` |
| Type inference failure with autoclosure | `swift-issue-typed-throws-autoclosure-inference` |
| Windows-specific existential crash | `swift-issue-windows-existential-crash` |

### Cross-Module Bug Pattern

When a bug requires multiple packages to reproduce (e.g., SPM resolution issues), create a separate repository for the dependency:

```text
swift-issue-windows-existential-crash/           # Main reproduction
swift-issue-windows-existential-crash-other-package/  # Dependency module
```

**Correct**:
```text
/Users/coen/Developer/coenttb/swift-issue-irgen-async-typed-throws-noncopyable/
/Users/coen/Developer/coenttb/swift-issue-silgen-pack-expansion-cross-module/
```

**Incorrect**:
```text
/Users/coen/Developer/swift-issue-foo/        ❌ Not in coenttb/
~/Developer/coenttb/issue-test/               ❌ Wrong naming pattern
/tmp/swift-bug/                               ❌ Ephemeral location
Experiments/swift-issue-irgen-crash/          ❌ Issues go to coenttb/, not Experiments/
```

### Repository Stability

Once an issue repository is linked from a Swift issue, the repository name MUST NOT be changed. If understanding of the bug evolves, clarify in README.md instead.

**Rationale**: Consistent location and naming enables discovery, links to GitHub issues, and distinguishes issue reproductions from internal experiments. Renaming breaks links from Swift issues.

---

## Package Structure

**Scope**: Required files and directory layout for issue packages.

**Statement**: Issue packages MUST contain the minimum structure required to reproduce the bug. The structure varies based on whether the bug requires cross-module reproduction.

### Single-Module Structure

For bugs that reproduce within a single module:

**Correct**:
```text
swift-issue-{name}/
├── .git/
├── .gitignore
├── Package.swift
├── README.md
└── Sources/
    └── {TargetName}/
        └── {Name}.swift     # Contains reproduction + inline docs
```

### Multi-Module Structure

For bugs requiring cross-module reproduction (e.g., cross-module inlining, visibility):

**Correct**:
```text
swift-issue-{name}/
├── .git/
├── .gitignore
├── Package.swift
├── README.md
├── Sources/
│   ├── LibraryA/            # Module defining the problematic API
│   │   └── API.swift
│   └── LibraryB/            # Module triggering the bug
│       └── Caller.swift
└── Tests/                   # Optional: if bug manifests at runtime
    └── {Name}Tests/
        └── Tests.swift
```

### Cross-Package Structure

For bugs requiring separate SPM packages (rare—for package resolution issues):

**Correct**:
```text
swift-issue-{name}/                    # Main package
├── Package.swift                      # Depends on other-package
└── ...

swift-issue-{name}-other-package/      # Dependency package
├── Package.swift                      # Standalone
└── ...
```

**Incorrect**:
```text
swift-issue-{name}/
├── Package.swift
├── README.md
├── Sources/
│   └── {Name}/
│       ├── Main.swift
│       ├── Helpers.swift           ❌ Unnecessary file
│       └── Extensions.swift        ❌ Unnecessary file
├── Tests/                          ❌ Unless bug manifests at runtime
├── Resources/                      ❌ Unnecessary directory
└── Benchmarks/                     ❌ Unnecessary directory
```

**Rationale**: Minimal structure isolates the bug. Multi-module structure when the bug involves cross-module semantics; cross-package when SPM resolution is involved.

---

## Package.swift Template

**Scope**: Standard Package.swift content for issue packages.

**Statement**: The Package.swift file MUST specify only the minimum configuration required to reproduce the bug. Use Swift 6.2 and macOS v26 unless testing version-specific behavior.

### Single-Target Template (Compiler Crash)

**Correct**:
```swift
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "{BugName}",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "{BugName}", targets: ["{BugName}"]),
    ],
    targets: [
        .target(name: "{BugName}")
    ],
    swiftLanguageModes: [.v6]
)
```

### Multi-Target Template (Cross-Module Bug)

**Correct**:
```swift
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "{BugName}",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "LibraryA", targets: ["LibraryA"]),
        .library(name: "LibraryB", targets: ["LibraryB"]),
    ],
    targets: [
        .target(name: "LibraryA"),
        .target(name: "LibraryB", dependencies: ["LibraryA"]),
    ],
    swiftLanguageModes: [.v6]
)
```

### With Test Target (Runtime Bug)

**Correct**:
```swift
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "{BugName}",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ContainerLib", targets: ["ContainerLib"]),
    ],
    targets: [
        .target(name: "ContainerLib"),
        .testTarget(name: "ContainerTests", dependencies: ["ContainerLib"]),
    ],
    swiftLanguageModes: [.v6]
)
```

### With Required Swift Settings

Only include swift settings that are necessary to trigger the bug:

**Correct**:
```swift
// Add to Package.swift only if required to reproduce
for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let existing = target.swiftSettings ?? []
    target.swiftSettings = existing + [
        .enableExperimentalFeature("ValueGenerics"),    // Only if bug requires this
    ]
}
```

**Incorrect**:
```swift
// ❌ Unnecessary complexity
let package = Package(
    name: "{BugName}",
    platforms: [.macOS(.v26), .iOS(.v26), .watchOS(.v26)],  // ❌ Extra platforms
    products: [
        .library(name: "{BugName}", targets: ["{BugName}"]),
        .executable(name: "{BugName}CLI", targets: ["{BugName}CLI"]),  // ❌ Unnecessary
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),  // ❌ Unnecessary
    ],
    targets: [
        .target(name: "{BugName}"),
        .target(name: "{BugName}CLI", dependencies: ["{BugName}"]),
        .testTarget(name: "{BugName}Tests", dependencies: ["{BugName}"]),  // ❌ Unless needed
    ]
)
```

### Version-Specific Bugs

If the bug reproduces only on a specific Swift version or snapshot, the Package.swift and README MUST reflect the minimal version required rather than the default Swift 6.2 baseline.

**Rationale**: Minimal Package.swift makes it clear what is required to trigger the bug vs. what is incidental. Version-specific bugs need version-specific manifests.

---

## Source File Documentation

**Scope**: Required inline documentation in source files.

**Statement**: Source files MUST include comprehensive doc comments explaining the bug, conditions, and verified test cases directly in the code.

### Source File Header Template

**Correct**:
```swift
/// {Short Description of Bug}
///
/// {Detailed explanation of what goes wrong and why it matters}
///
/// {Crash type}: {crash location or behavior}
///
/// Conditions required (ALL must be present):
/// 1. {First condition}
/// 2. {Second condition}
/// 3. {Third condition}
///
/// Note: {Important clarification, e.g., "~Copyable is NOT required"}
```

### Source File Body Template

**Correct**:
```swift
// MARK: - Minimal Reproduction ({N} lines)

{minimal code that triggers the bug}

// MARK: - Verified Working Cases

// ✅ WORKS: {Description of case 1}
{code that works}

// ✅ WORKS: {Description of case 2}
{code that works}

// MARK: - Also crashes with {variation} (but {variation} is not the cause)

{code showing the bug persists with variations}
```

**Incorrect**:
```swift
// Test file  ❌ No purpose stated

public enum Box<T> {
    public enum Error: Swift.Error { case fail }
    public static func go() async throws(Error) {}
}
// ❌ No conditions documented
// ❌ No working cases shown
// ❌ No hypothesis or result recorded
```

### Proportionality for Small Reproductions

For reproductions under 10 lines, the documentation MAY be abbreviated, provided all required conditions and at least one verified working case are documented.

**Rationale**: Inline documentation makes the reproduction self-contained. Anyone reading the source file understands the bug without needing the README. However, ritualistic verbosity should not outweigh the code itself.

---

## Source File Example: Compiler Crash

**Scope**: Example source file for compiler crash bugs.

**Statement**: Compiler crash reproductions SHOULD follow this structure, demonstrating the minimal crash case and all verified working variations.

**Correct**:
```swift
/// IRGen Crash: Async Function with Typed Throws and Nested Error Type Under Generic
///
/// The compiler crashes (signal 11) during IR generation when ALL THREE conditions are met:
/// 1. Generic type (any generic parameter)
/// 2. Nested error type under that generic
/// 3. Async function with typed throws using the nested error
///
/// Note: ~Copyable is NOT required - any generic triggers this.

// MARK: - Minimal Reproduction (4 lines)

public enum Box<T> {
    public enum Error: Swift.Error { case fail }
    public static func go() async throws(Error) {}  // CRASHES
}

// MARK: - Verified Working Cases

// ✅ WORKS: Sync function (no async)
public enum SyncBox<T> {
    public enum Error: Swift.Error { case fail }
    public static func go() throws(Error) {}
}

// ✅ WORKS: Untyped throws
public enum UntypedBox<T> {
    public enum Error: Swift.Error { case fail }
    public static func go() async throws {}
}

// ✅ WORKS: Non-generic container
public enum NonGenericBox {
    public enum Error: Swift.Error { case fail }
    public static func go() async throws(Error) {}
}

// ✅ WORKS: Typealias to hoisted type (WORKAROUND)
public enum HoistedError: Swift.Error { case fail }
public enum TypealiasBox<T> {
    public typealias Error = HoistedError
    public static func go() async throws(Error) {}
}

// MARK: - Also crashes with ~Copyable (but ~Copyable is not the cause)

public enum CopyableBox<T: ~Copyable> {
    public enum Error: Swift.Error { case fail }
    public static func go() async throws(Error) {}  // CRASHES (same bug)
}
```

---

## Source File Example: Runtime Bug

**Scope**: Example source file for runtime behavior bugs.

**Statement**: Runtime bug reproductions SHOULD include buggy, workaround, and control implementations to isolate the condition that triggers the bug.

**Correct**:
```swift
/// Minimal reproduction of InlineArray deinit bug with value generic parameter.
///
/// Bug: When a ~Copyable struct uses `InlineArray<capacity, ...>` where `capacity`
/// is a value generic parameter, and contains only value-type properties, the
/// compiler fails to generate deinit dispatch for cross-module ~Copyable elements.
/// Elements are silently leaked.

// MARK: - Buggy: InlineArray with value generic capacity

/// This container silently leaks ~Copyable elements defined in other modules.
public struct Container<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
    var _count: Int
    // NO reference type properties - this is the buggy configuration

    deinit {
        // This deinit IS executed, but element deinitializers are NOT called
        // for cross-module ~Copyable elements when struct has only value-type properties
    }
}

// MARK: - Fixed: Same but with AnyObject? workaround

/// This container correctly calls deinit on ~Copyable elements.
public struct ContainerFixed<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
    var _count: Int
    var _deinitWorkaround: AnyObject? = nil  // WORKAROUND: Reference type property
}

// MARK: - Control: InlineArray with literal capacity (works correctly)

/// This container works correctly - literal capacity does not trigger the bug.
public struct ContainerLiteral<Element: ~Copyable>: ~Copyable {
    var _storage: InlineArray<4, (Int, Int, Int, Int, Int, Int, Int, Int)>  // Literal 4, not generic
}
```

---

## README.md Structure

**Scope**: Required README structure for issue packages.

**Statement**: The README MUST follow a standard structure that enables Swift compiler team members to understand, reproduce, and triage the issue efficiently.

### Required Sections

| Section | Required | When to Include |
|---------|----------|-----------------|
| Description | ✓ | Always |
| Environment | ✓ | Always |
| Minimal Reproduction | ✓ | Always |
| To Reproduce | ✓ | Always |
| Crash Output | ✓ | For crashes |
| Conditions Required | ✓ | Always |
| Verified Test Results | ✓ | Always |
| Workaround | If exists | When workaround found |
| Related Issues | If found | When related issues exist |
| Impact | ✓ | Always |

**Rationale**: Standardized README enables efficient triage. The Swift team can quickly understand severity, reproduce, and locate the bug in the compiler.

---

## README.md Template

**Scope**: Complete README template for issue packages.

**Statement**: README files MUST use this template structure.

**Correct**:
````markdown
# Swift {Crash Location} {Crash Type}: {Short Description}

## Description

{1-2 sentence description of what goes wrong}

{Optional: Important clarification, e.g., "Note: This bug does NOT require ~Copyable"}

## Environment

- **Swift version**: {exact version from swift --version}
- **Target**: {e.g., arm64-apple-macosx26.0}
- **Crash location**: {function name from stack trace, if crash}

## Minimal Reproduction ({N} lines)

```swift
{absolute minimal code}
```

## To Reproduce

```bash
git clone https://github.com/coenttb/{repo-name}
cd {repo-name}
swift build  # or swift test
```

Or directly:

```bash
{one-liner to reproduce without cloning}
```

## Crash Output

```
{verbatim crash output, truncated if very long}
```

## Conditions Required

All {N} conditions must be present to trigger the {crash/bug}:

| Condition | Description |
|-----------|-------------|
| 1. {Condition} | {Description} |
| 2. {Condition} | {Description} |
| 3. {Condition} | {Description} |

## Verified Test Results

| Test | Description | Result |
|------|-------------|--------|
| {Test name} | {What it tests} | ✅ Compiles / ❌ Crashes |

**Key finding**: {The key insight from testing}

## Workaround

{Description of workaround}

```swift
{workaround code}
```

## Related Issues

This {appears related to / may be a duplicate of}:

- [#{number}](https://github.com/swiftlang/swift/issues/{number}) - {title}

## Impact

This blocks {description of what is blocked}:
- {Impact 1}
- {Impact 2}
````

**Incorrect**:
````markdown
# Bug

The compiler crashes sometimes.

## Code

```swift
// lots of code here without explanation
```

## Steps

Run swift build.
````

---

## Test Target (Runtime Bugs)

**Scope**: When and how to include test targets.

**Statement**: Test targets SHOULD be included when the bug manifests at runtime rather than compile time. Tests MUST clearly demonstrate expected vs actual behavior.

### When to Include Tests

| Bug Type | Include Tests |
|----------|---------------|
| Compiler crash | No (build failure is the test) |
| Silent wrong behavior | Yes |
| Memory leak / missing deinit | Yes |
| Incorrect runtime output | Yes |
| Wrong code generation | Yes |

### Test Naming Convention

| Test Type | Naming Pattern |
|-----------|----------------|
| Demonstrates bug | `{condition} - BUG: {description}` |
| Shows workaround | `{condition} - {workaround} works` |
| Control case | `{condition} - control case (works correctly)` |

**Correct**:
```swift
import Testing
@testable import ContainerLib

@Suite("InlineArray Deinit Bug")
struct InlineArrayDeinitTests {

    @Test("Container with value generic capacity - BUG: deinit NOT called")
    func buggyCase() {
        let tracker = Tracker()
        do {
            var container = Container<TrackedElement, 4>()
            container.push(TrackedElement(0, tracker: tracker))
        }
        // BUG: deinitOrder == [] (elements leaked)
        // Expected: deinitOrder == [0]
        #expect(tracker.deinitOrder == [0], "BUG: Elements leaked (was \(tracker.deinitOrder))")
    }

    @Test("ContainerFixed with AnyObject? workaround - deinit IS called")
    func workaroundCase() {
        let tracker = Tracker()
        do {
            var container = ContainerFixed<TrackedElement, 4>()
            container.push(TrackedElement(0, tracker: tracker))
        }
        #expect(tracker.deinitOrder == [0])
    }

    @Test("ContainerLiteral with literal capacity - control case (works correctly)")
    func controlCase() {
        let tracker = Tracker()
        do {
            var container = ContainerLiteral<TrackedElement>()
            container.push(TrackedElement(0, tracker: tracker))
        }
        #expect(tracker.deinitOrder == [0])
    }
}
```

**Incorrect**:
```swift
import Testing

@Test func test1() {
    // some code
    #expect(true)  // ❌ No clear bug demonstration
}

@Test func test2() {
    // more code  // ❌ No naming convention
}
```

### CI-Friendly Test Assertions

If asserting the buggy behavior would cause CI to abort prematurely, tests MAY assert the expected behavior and include comments indicating the observed incorrect behavior instead.

```swift
@Test("Container - BUG: deinit NOT called")
func buggyCase() {
    let tracker = Tracker()
    do {
        var container = Container<TrackedElement, 4>()
        container.push(TrackedElement(0, tracker: tracker))
    }
    // BUG: Actual behavior is tracker.deinitOrder == [] (elements leaked)
    // This test asserts expected behavior to document the bug without CI abort
    #expect(tracker.deinitOrder == [0], "BUG: Elements leaked (was \(tracker.deinitOrder))")
}
```

**Rationale**: Tests make runtime bugs reproducible and verifiable. Clear naming identifies which test demonstrates the bug vs which are controls. CI-friendly assertions prevent infrastructure issues during investigation.

---

## Reduction Requirements

**Scope**: Standards for code minimization in issue packages.

**Statement**: Issue packages MUST contain the absolute minimal code to reproduce the bug.

### Minimality Invariant

The reproduction MUST be reduced such that removing any single condition, type, or language feature causes the bug to disappear. This is the defining criterion for "minimal."

### Reduction Checklist

| Reduction | Check |
|-----------|-------|
| Remove unused imports | ✓ |
| Remove unused types | ✓ |
| Remove unused properties | ✓ |
| Remove unused methods | ✓ |
| Simplify type names (use `Box`, `Foo`, etc.) | ✓ |
| Remove protocol conformances unless required | ✓ |
| Remove access modifiers unless required | ✓ |
| Remove generic constraints unless required | ✓ |
| Inline nested functions if possible | ✓ |
| Replace complex types with simple ones | ✓ |

### Line Count Targets

| Bug Complexity | Target Lines |
|----------------|--------------|
| Compiler crash | 4-10 lines |
| Type inference bug | 5-15 lines |
| Runtime behavior bug | 20-50 lines |
| Cross-module bug | 10-30 lines per module |

**Correct** (4 lines):
```swift
public enum Box<T> {
    public enum Error: Swift.Error { case fail }
    public static func go() async throws(Error) {}  // CRASHES
}
```

**Incorrect** (over-complicated):
```swift
import Foundation  // ❌ Unnecessary

public protocol Boxable {  // ❌ Unnecessary protocol
    associatedtype Value
}

public enum Box<T>: Boxable {  // ❌ Unnecessary conformance
    public typealias Value = T  // ❌ Unnecessary typealias

    case empty  // ❌ Unnecessary case
    case value(T)  // ❌ Unnecessary case

    public enum Error: Swift.Error, LocalizedError {  // ❌ Unnecessary conformance
        case fail
        case notFound  // ❌ Unnecessary case

        public var errorDescription: String? { nil }  // ❌ Unnecessary
    }

    public static func go() async throws(Error) {}
}
```

**Rationale**: Minimal reproductions isolate the bug precisely, making it easier for the Swift team to identify and fix the root cause.

---

## Git and GitHub Workflow

**Scope**: Version control and repository setup.

**Statement**: Issue packages MUST be git repositories pushed to GitHub under the `coenttb` organization.

### Initial Setup

**Correct**:
```bash
cd /Users/coen/Developer/coenttb/
mkdir swift-issue-{name}
cd swift-issue-{name}
git init
```

### .gitignore Template

**Correct**:
```gitignore
.DS_Store
.build/
.swiftpm/
*.xcodeproj/
*.xcworkspace/
DerivedData/
```

### Commit and Push

**Correct**:
```bash
git add .
git commit -m "Minimal reproduction: {short bug description}"
gh repo create coenttb/swift-issue-{name} --public --source=. --remote=origin --push
```

**Incorrect**:
```bash
git commit -m "test"                    # ❌ Non-descriptive message
git commit -m "WIP"                     # ❌ Non-descriptive message
gh repo create swift-issue-{name} ...   # ❌ Missing coenttb/ org prefix
```

### After Filing Issue

Update README with issue link:

**Correct**:
```markdown
## Swift Issue

Filed as [swiftlang/swift#{number}](https://github.com/swiftlang/swift/issues/{number})
```

### History Stability

Issue repositories MUST NOT rewrite history after the Swift issue is filed. Amendments should be additive commits or README updates.

**Correct**:
```bash
git commit -m "Add clarification: bug also reproduces on Linux"
git push
```

**Incorrect**:
```bash
git rebase -i HEAD~3           # ❌ Rewrites history
git push --force               # ❌ Breaks investigation references
git commit --amend             # ❌ After issue is filed
```

**Rationale**: GitHub repositories provide stable URLs for issue reports and enable Swift team members to clone and reproduce directly. Force-pushes and history rewrites break references during investigation.

---

## Issue Filing Checklist

**Scope**: Pre-submission verification.

**Statement**: Before filing an issue with the Swift compiler team, the following checklist MUST be verified.

### Pre-Filing Checklist

| Category | Item | Verified |
|----------|------|----------|
| **Reproduction** | Code compiles/crashes as described | ☐ |
| | `swift build` or `swift test` reproduces the issue | ☐ |
| | Tested on latest Swift release | ☐ |
| | Tested on development snapshot (if possible) | ☐ |
| **Reduction** | Removed all unnecessary code | ☐ |
| | Verified each condition is required | ☐ |
| | Working cases documented | ☐ |
| **Documentation** | README follows template | ☐ |
| | Source files have inline docs | ☐ |
| | Crash output captured verbatim | ☐ |
| | Environment recorded exactly | ☐ |
| **Git** | Repository pushed to GitHub | ☐ |
| | Clone + build/test instructions verified | ☐ |
| **Search** | Searched existing Swift issues | ☐ |
| | No exact duplicate found | ☐ |
| | Related issues linked | ☐ |
| **Validation** | Reproduction confirmed by third party (optional) | ☐ |

### Filing Location

| Bug Type | Location |
|----------|----------|
| Swift compiler bugs | https://github.com/swiftlang/swift/issues/new |
| Swift Package Manager bugs | https://github.com/swiftlang/swift-package-manager/issues/new |
| Foundation bugs | https://github.com/swiftlang/swift-foundation/issues/new |

### Issue Title Format

**Correct**:
```text
IRGen crash: async function with typed throws and nested error under generic
SILGen crash: cross-module parameter pack expansion
Bug: InlineArray with value generic skips deinit for cross-module ~Copyable
```

**Incorrect**:
```text
Crash                           # ❌ Too vague
Swift doesn't work              # ❌ Not specific
Help needed with typed throws   # ❌ Sounds like question, not bug report
```

**Rationale**: Complete verification prevents duplicate filings and ensures the Swift team can reproduce without follow-up questions.

---

## Issue Submission Workflow Summary

```text
┌─────────────────────────────────────────────────────────────┐
│          ASSISTANT-DRIVEN ISSUE SUBMISSION WORKFLOW          │
└─────────────────────────────────────────────────────────────┘

                    PHASE 1: PREPARATION
                    ════════════════════

1. PREREQUISITE: Experiment completed
   │
   ├─ Result: REFUTED or unexpected behavior
   ├─ Verified: Not documented/expected behavior
   └─ Reduced: Minimal reproduction exists
                                            │
                                            ▼
2. GATHER CONTEXT
   │
   ├─ Minimal reproduction code
   ├─ Conditions required
   ├─ Verified working cases
   └─ Crash output / environment
                                            │
                                            ▼
3. DRAFT PACKAGE [ISSUE-001 through ISSUE-007]
   │
   ├─ Generate repository name
   ├─ Create Package.swift
   ├─ Create source file(s) with inline docs
   ├─ Create README.md
   └─ Create test target (if runtime bug)
                                            │
                                            ▼
4. PRESENT FOR REVIEW
   │
   ├─ Display package structure
   ├─ Display README content
   └─ Display source file content

                    PHASE 2: CONFIRMATION
                    ═════════════════════
                                            │
                                            ▼
               ┌────────────────────────────────────┐
               │     ASK FOR USER CONFIRMATION      │
               │                                    │
               │  ☐ Reproduction is correct         │
               │  ☐ Conditions are accurate         │
               │  ☐ README describes bug correctly  │
               │                                    │
               │     Proceed with submission?       │
               └────────────────────────────────────┘
                                            │
                         ┌──────────────────┴──────────────────┐
                         │                                     │
                      [APPROVED]                           [REJECTED]
                         │                                     │
                         ▼                                     ▼
                    PHASE 3                              Revise and
                                                        re-present

                    PHASE 3: SUBMISSION
                    ═══════════════════
                                            │
                                            ▼
5. CREATE REPOSITORY
   │
   ├─ mkdir /Users/coen/Developer/coenttb/swift-issue-{name}
   ├─ Write all files
   ├─ git init && git add && git commit
   └─ gh repo create coenttb/swift-issue-{name} --public
                                            │
                                            ▼
6. SEARCH FOR DUPLICATES
   │
   └─ gh search issues --repo swiftlang/swift "{terms}"
                                            │
                                            ▼
               ┌────────────────────────────────────┐
               │   PRESENT DUPLICATE CHECK RESULTS  │
               │                                    │
               │   Proceed / Link to existing?      │
               └────────────────────────────────────┘
                                            │
                         ┌──────────────────┴──────────────────┐
                         │                                     │
                    [PROCEED]                          [LINK EXISTING]
                         │                                     │
                         ▼                                     ▼
7. FILE ISSUE                                      Comment on existing
   │                                               issue with new info
   ├─ gh issue create --repo swiftlang/swift
   ├─ Title: {Crash/Bug}: {description}
   └─ Body: README content + repo link
                                            │
                                            ▼
8. UPDATE README
   │
   ├─ Add "Filed as swiftlang/swift#{number}"
   └─ git commit && git push
                                            │
                                            ▼
               ┌────────────────────────────────────┐
               │           REPORT COMPLETION        │
               │                                    │
               │  Issue: github.com/swiftlang/...   │
               │  Repo:  github.com/coenttb/...     │
               └────────────────────────────────────┘
```

---

## Topics

### Foundation Document

- the **experiment-process** skill — Shared infrastructure for experiments

### Related Workflows

- the **experiment-process** skill (investigation workflow) — How experiments identify bugs
- the **experiment-process** skill (discovery workflow) — Proactive package audits

### Cross-Reference Index

| ID | Title | Focus |
|----|-------|-------|
| — | Assistant-Driven Workflow | Automated interactive submission |
| ISSUE-001 | Repository Location and Naming | Where and how to name |
| ISSUE-002 | Package Structure | Directory layout |
| ISSUE-003 | Package.swift Template | Manifest content |
| ISSUE-004 | Source File Documentation | Inline docs header/body |
| ISSUE-004a | Source File Example: Compiler Crash | Crash example |
| ISSUE-004b | Source File Example: Runtime Bug | Runtime example |
| ISSUE-005 | README.md Structure | Required sections |
| ISSUE-005a | README.md Template | Complete template |
| ISSUE-006 | Test Target | When to include tests |
| ISSUE-007 | Reduction Requirements | Code minimization |
| ISSUE-008 | Git and GitHub Workflow | Version control |
| ISSUE-009 | Issue Filing Checklist | Pre-submission verification |
