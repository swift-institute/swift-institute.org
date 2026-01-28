# Quality Assurance

@Metadata {
    @TitleHeading("Swift Institute")
}

Test infrastructure, continuous integration, and versioning strategy for Swift Institute packages.

## Overview

> This document answers: "What quality assurance policies govern testing, CI, and versioning across all packages?"

This document defines the quality assurance infrastructure for the Swift Institute ecosystem. These policies apply across all packages unless an explicit, reviewed exception is recorded.

**Related documents**:
- For project goals and non-goals, see <doc:Identity>

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

---

## Test Infrastructure

**Applies to**: All packages in swift-primitives, swift-institute, and swift-standards.

**Does not apply to**: Prototype code, experimental branches, or documentation-only packages.

---

### Unified Test Coordination

**Scope**: Package-level and workspace-level test organization.

**Statement**: The `swift-institute` workspace MUST coordinate testing across all packages using unified test plans. Tests MUST be runnable both individually and as a unified suite to catch cross-package regressions.

**Correct**:
```
Primitives.xctestplan
+-- Algebra Linear Primitives Tests
+-- Algebra Primitives Tests
+-- Affine Primitives Tests
+-- Buffer Primitives Tests
+-- Geometry Primitives Tests
+-- Kernel Primitives Tests
+-- [37 test targets total...]
```

**Incorrect**:
```
// Each package tests in isolation only
// No unified test plan
// Cross-package regressions undetected
```

**Rationale**: Unified test coordination ensures changes in lower-tier packages do not break dependent packages. Cross-package regressions are often subtle and only appear when components interact.

---

## Continuous Integration

**Applies to**: All packages with source code.

**Does not apply to**: Documentation-only repositories.

---

### CI Configuration Requirements

**Scope**: GitHub Actions workflow configuration.

**Statement**: Each package MUST include CI configuration that builds and tests on every push to `main` and every pull request targeting `main`. CI MUST use a specified Xcode version to ensure reproducibility.

**Correct**:
```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.2.app
      - name: Build
        run: swift build
      - name: Test
        run: swift test
```

**Incorrect**:
```yaml
# Missing explicit Xcode version selection
# Missing test step
# Only triggers on push, not pull requests
```

**Rationale**: Consistent CI configuration prevents "works on my machine" failures and ensures all contributors receive immediate feedback on breaking changes.

---

## Versioning Strategy

**Applies to**: All packages in the ecosystem.

**Does not apply to**: Internal tooling or build scripts.

---

### Semantic Versioning

**Scope**: Package version numbering.

**Statement**: All packages MUST use semantic versioning with coordinated releases. Version numbers MUST follow the pattern `MAJOR.MINOR.PATCH` where breaking changes increment MAJOR, new features increment MINOR, and bug fixes increment PATCH.

**Correct**:
```
0.1.0  Initial extraction
0.2.0  API refinements based on usage
0.3.0  Additional refinements
...
1.0.0  Stable API (after production use)
```

**Incorrect**:
```
v1      // Missing minor and patch
1.0     // Missing patch version
1.0.0a  // Non-standard suffix
```

**Rationale**: Semantic versioning enables consumers to understand the impact of updates and pin dependencies appropriately.

---

### Coordinated Breaking Changes

**Scope**: Cross-package dependency updates.

**Statement**: Breaking changes in lower-tier packages MUST trigger coordinated updates to all dependent packages, maintaining graph consistency. A breaking change MUST NOT be released until all dependent packages have been updated and tested.

**Rationale**: Coordinated updates prevent dependency hell where consumers cannot upgrade due to incompatible transitive dependencies.

---

## Topics

### Related Documents

- <doc:Testing-Requirements>
- <doc:Identity>
- <doc:Contributor-Guidelines>
