---
name: swift-pull-request
description: |
  Submit pull requests to swiftlang/swift: fork, branch, commit, test, PR, CI, reviewers.
  Apply when contributing a fix or feature to the Swift compiler upstream.

layer: process

requires:
  - swift-institute-core

applies_to:
  - swiftlang-swift
  - compiler-contribution

last_reviewed: 2026-03-24
---

# Swift Pull Request Process

Workflow for submitting PRs to `swiftlang/swift` from the `coenttb` GitHub account.

**Provenance**: Research conducted 2026-03-22 from CONTRIBUTING.md, GettingStarted.md, FirstPullRequest.md, ContinuousIntegration.md, CODEOWNERS, and empirical analysis of 10+ merged PRs. Full findings at `/Users/coen/Developer/swift-institute/Research/pr-submission-research.md`.

---

## Setup

### [SWIFT-PR-001] Fork and Remote

**Statement**: Contributors without commit access MUST fork `swiftlang/swift` and push to the fork. Direct push to `swiftlang/swift` requires commit access (granted after 5+ accepted non-trivial PRs).

**One-time setup**:
```bash
cd /Users/coen/Developer/swiftlang/swift

# Fork (if not already forked):
gh repo fork swiftlang/swift --clone=false

# Add fork as remote:
git remote add coenttb https://github.com/coenttb/swift.git
```

**Verify**:
```bash
git remote -v
# Should show both origin (swiftlang) and coenttb (fork)
```

**Rationale**: The upstream repo restricts push access. All external contributions go through fork-based PRs.

---

## Pre-Investigation: Verify Against Latest Toolchain

### [SWIFT-PR-011] Check Latest Swift Before Deep-Diving

**Statement**: Before investigating a compiler bug, the reproducer MUST be tested against the latest available Swift development toolchain. If the bug does not reproduce, no PR or issue is needed — the fix is already upstream.

**Procedure**:
```bash
# List installed toolchains:
ls /Library/Developer/Toolchains/

# Test with the dev toolchain:
TOOLCHAINS=swift xcrun swiftc -O reproducer.swift -o /tmp/test 2>&1

# Or via SwiftPM:
TOOLCHAINS=swift swift build -c release
```

**Rationale**: Compiler bugs on released Xcode toolchains may already be fixed on `main`. Deep-diving into compiler source, creating experiments, or preparing a PR for a bug that's already fixed wastes significant effort. This check takes 30 seconds and can save hours.

**Provenance**: Session 2026-03-31 — spent hours investigating a CopyPropagation crash (`swiftlang/swift#85743`) that was already fixed in Swift 6.4-dev by commit `e93ea1db266`.

---

## Branch and Commit

### [SWIFT-PR-002] Branch Creation

**Statement**: Create a descriptive kebab-case branch. Target `main` for all new work. Release branches (`release/x.y`) have a separate, stricter process requiring branch manager approval.

```bash
git checkout -b descriptive-branch-name
```

**Observed patterns** (no enforced convention):
- Short descriptive slugs: `fix-embedded-swift-build`, `add-tests`
- Username-prefixed: `owenv/benchpath`
- Component-prefixed: `mandatory-temprvalue-elimination`

**Rationale**: No formal convention exists. Descriptive names aid review triage.

---

### [SWIFT-PR-003] Commit Message Format

**Statement**: Commit messages MUST use a tag prefix indicating the compiler component, followed by a concise subject. Body is optional, separated by a blank line.

**Format**:
```
[Component] Brief description of the change

Optional body explaining rationale.
Link to issue if applicable.
```

**Tag conventions**:
- Square brackets: `[SILOptimizer]`, `[Sema]`, `[stdlib]`, `[test]`
- Colon style (also accepted): `IRGen:`, `AST:`, `SILGen:`
- `NFC:` prefix for refactoring-only changes (No Functional Change)
- Backticks for code identifiers in subject: `` [Sema] Use `defaultUnboundTypeOpener` ``

**Common tags by area**:

| Area | Tags |
|------|------|
| SIL Optimizer | `[SILOptimizer]`, `SILCombine:` |
| SIL | `[SIL]` |
| SILGen | `[SILGen]`, `SILGen:` |
| Type Checker | `[Sema]` |
| AST | `[AST]`, `AST:` |
| IRGen | `[IRGen]`, `IRGen:` |
| Standard Library | `[stdlib]` |
| Tests only | `[test]` |
| Embedded Swift | `[Embedded]`, `Embedded:` |

**Issue links**: Include `Resolves https://github.com/swiftlang/swift/issues/NNNNN` in the body or PR. Before using `Resolves`, read the issue and confirm it describes the same bug you are fixing. If your fix addresses a different bug (even in the same area), file a new issue first.

**Rationale**: From CONTRIBUTING.md: "Include a [tag] at the start in square brackets" and "make the title concise to be easily read within a commit log."

---

### [SWIFT-PR-004] New Source File Headers

**Statement**: New source files MUST include the Apache 2.0 + Runtime Library Exception header with the current year.

**Swift files**:
```swift
//===--- FileName.swift ---------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
```

**SIL test files**: No header required (test files in `test/` do not carry the header).

**Issue references in code**: Use GitHub URLs, not `rdar://` (which is Apple-internal). Follow existing conventions in the file being modified. Examples:
```cpp
// https://github.com/swiftlang/swift/issues/12345
// FIXME: Support X (https://github.com/swiftlang/swift/issues/12345)
```

**Rationale**: Required by CONTRIBUTING.md. No CLA or DCO is needed — contributions are implicitly licensed under the project license.

---

## Testing

### [SWIFT-PR-005] Test Requirements

**Statement**: Every bug fix MUST include a test case. Tests MUST be written at the abstraction level nearest to the feature being tested. Tests MUST be reduced as much as possible.

**Abstraction level selection**:

| Change area | Test type | Directory | Tool |
|-------------|-----------|-----------|------|
| SIL optimization pass | SIL test (`.sil` file) | `test/SILOptimizer/` | `sil-opt` + FileCheck |
| SILGen | SIL output test | `test/SILGen/` | `swift -emit-silgen` + FileCheck |
| Type checker / Sema | Swift source test | `test/Sema/` or `test/decl/` | `swift -typecheck` |
| IRGen | IR output test | `test/IRGen/` | `swift -emit-ir` + FileCheck |
| End-to-end behavior | Executable test | `test/Interpreter/` | Compile + run |
| Lifetime dependence | SIL test | `test/SILOptimizer/lifetime_dependence/` | `sil-opt` or `swift` |

**SIL test pattern**:
```sil
// RUN: %target-sil-opt %s -pass-name -enable-experimental-feature FeatureName | %FileCheck %s

// REQUIRES: swift_in_compiler
// REQUIRES: swift_feature_FeatureName

sil_stage canonical

import Swift
import Builtin

// CHECK-LABEL: sil [ossa] @test_function_name
// CHECK:         expected_instruction
// CHECK-LABEL: } // end sil function 'test_function_name'
sil [ossa] @test_function_name : $@convention(thin) (...) -> ... {
  ...
}
```

**Key flags**:
- `-enable-experimental-feature Lifetimes` — required for `~Escapable` types
- `-disable-availability-checking` — required when tests use features gated on newer deployment targets (value generics, etc.). Without this, `llvm-lit` fails because it targets an older macOS version.
- `-sil-print-types` — shows types in SIL output (useful for FileCheck)
- `// REQUIRES: swift_in_compiler` — skip when running outside compiler build
- `// REQUIRES: swift_feature_X` — skip when feature flag unavailable

**Local test execution**:
```bash
# Single test via sil-opt + FileCheck:
$BUILD_DIR/bin/sil-opt [flags] test/SILOptimizer/your_test.sil 2>&1 \
  | $LLVM_BUILD_DIR/bin/FileCheck test/SILOptimizer/your_test.sil

# Via llvm-lit (preferred, handles REQUIRES):
llvm-lit -sv test/SILOptimizer/your_test.sil

# Run an entire directory:
llvm-lit -sv test/SILOptimizer/lifetime_dependence/
```

**Rationale**: From CONTRIBUTING.md: "Developers are required to create test cases for any bugs fixed and any new features added."

---

## Pull Request

### [SWIFT-PR-006] PR Body

**Statement**: The PR body MUST contain a description of the change and its rationale. It SHOULD link related issues. It MUST NOT contain the default HTML comment template (replace it). It MUST disclose AI assistance if any part of the change was AI-assisted.

**AI disclosure**: Include a line in the PR body stating that the changes were AI-assisted. Example: `> This PR was prepared with AI assistance.`

**Structure for bug fixes**:
```markdown
{Description of the bug and what the fix does.}

> This PR was prepared with AI assistance.

### Root cause
{Explain why the bug occurs.}

### Fix
{Explain what the change does and why this approach.}

### Test plan
- {What tests were added/modified}
- {What existing tests were verified}
- {Link to standalone reproducer if available}

Resolves https://github.com/swiftlang/swift/issues/NNNNN
```

**Structure for features/refactoring**:
```markdown
{Description of the change and motivation.}

> This PR was prepared with AI assistance.

{Technical details if non-obvious.}

### Test plan
- {What tests were added/modified}

{Link to related discussion/pitch if applicable.}
```

**Rationale**: The org-level template says "replace this comment with a description of your changes and rationale." AI disclosure is expected per reviewer feedback (see [PR #88025 review](https://github.com/swiftlang/swift/pull/88025#pullrequestreview-3997094626)).

---

### [SWIFT-PR-007] PR Creation

**Statement**: PRs MUST target `main`. Use `gh pr create` with the fork remote.

```bash
# Stage and commit (see SWIFT-PR-003 for message format):
git add specific-files
git commit -m "$(cat <<'EOF'
[Component] Description

Body with rationale.
Resolves https://github.com/swiftlang/swift/issues/NNNNN
EOF
)"

# Push to fork:
git push --set-upstream coenttb branch-name

# Create PR:
gh pr create \
  --repo swiftlang/swift \
  --base main \
  --head coenttb:branch-name \
  --title "[Component] Description" \
  --body "$(cat <<'EOF'
PR body here (see SWIFT-PR-006).
EOF
)"
```

**Do NOT include**: `.swift-version` or other unrelated files in the commit.

**Rationale**: The `--repo` flag targets upstream; `--head` specifies the fork branch.

---

## CI and Review

### [SWIFT-PR-008] CI Triggers

**Statement**: Contributors without commit access MUST ask a reviewer to trigger CI. Do NOT attempt to trigger CI yourself.

**CI commands** (posted as PR comments by a reviewer with commit access):

| Scope | Command |
|-------|---------|
| Smoke test (all platforms) | `@swift-ci Please smoke test` |
| Full validation (all platforms) | `@swift-ci Please test` |
| macOS only (smoke) | `@swift-ci Please smoke test macOS platform` |
| Linux only (smoke) | `@swift-ci Please smoke test Linux platform` |
| Benchmarks | `@swift-ci Please benchmark` |

- **Smoke test**: builds Swift + stdlib, runs `test` + `validation-test` for one config.
- **Full validation**: clean build, all platforms + simulators, optimized + non-optimized tests.

**Rationale**: From ContinuousIntegration.md: "Contributors without write access are not able to run the continuous integration bot."

---

### [SWIFT-PR-009] Reviewer Identification

**Statement**: CODEOWNERS auto-assigns reviewers on non-draft PRs. For targeted review requests, consult the CODEOWNERS file and empirical review patterns.

**CODEOWNERS lookup**:
```bash
# Find owners for your changed files:
cat /Users/coen/Developer/swiftlang/swift/.github/CODEOWNERS | grep "relevant/path"

# Or check the file on GitHub:
gh api repos/swiftlang/swift/contents/.github/CODEOWNERS --jq '.content' | base64 -d | grep "path"
```

**Key CODEOWNERS (as of 2026-03-22)**:

| Path pattern | Owner(s) |
|-------------|----------|
| `SwiftCompilerSources/` | @eeckstein |
| `lib/SILOptimizer/`, `test/SILOptimizer/` | @eeckstein |
| `include/swift/SIL/`, `lib/SIL/` | @jckarter |
| `lib/SILGen/` | @jckarter, @kavon |
| `lib/SILOptimizer/Mandatory/MoveOnly*` | @kavon |
| `lib/SILOptimizer/Mandatory/AddressLowering*` | @kavon |
| `lib/Sema/` | @slavapestov, @hborla, @xedin |
| `lib/AST/` | @slavapestov, @hborla |
| `stdlib/` | @glessard, @stephentyrone |

**Empirical reviewers for lifetime/dependence SIL work**:
- **@eeckstein** — auto-assigned via CODEOWNERS
- **@meg-gupta** — actively reviews/approves lifetime and dependence PRs
- **@atrick** — frequently requested on SIL optimizer work

**Rationale**: From FirstPullRequest.md: "Reviews are automatically requested from code owners upon opening a non-draft pull request." Empirical patterns help identify domain experts beyond CODEOWNERS.

---

## Complete Execution Checklist

### [SWIFT-PR-010] End-to-End Checklist

**Statement**: Follow this checklist when submitting a PR to `swiftlang/swift`.

**One-time setup** (skip if already done):
- [ ] Fork: `gh repo fork swiftlang/swift --clone=false`
- [ ] Add remote: `git remote add coenttb https://github.com/coenttb/swift.git`

**Per-PR workflow**:
- [ ] **FIRST**: Test reproducer against latest Swift dev toolchain (`TOOLCHAINS=swift xcrun swiftc -O ...`). If it passes, the bug is already fixed — stop here. ([SWIFT-PR-011])
- [ ] Verify the bug reproduces on the Xcode release toolchain you're targeting.
- [ ] Create branch: `git checkout -b descriptive-name`
- [ ] Make changes
- [ ] Add test at the nearest abstraction level ([SWIFT-PR-005])
- [ ] Run test via `llvm-lit` before pushing (catches availability, REQUIRES, FileCheck issues)
- [ ] Run existing related tests to verify no regressions
- [ ] Add Apache header to new source files ([SWIFT-PR-004])
- [ ] Verify referenced issue describes your bug — not a different bug in the same area ([SWIFT-PR-003])
- [ ] Stage specific files (not `.swift-version` or unrelated changes)
- [ ] Commit with `[Component] Description` format ([SWIFT-PR-003])
- [ ] Push to fork: `git push -u coenttb branch-name`
- [ ] Include AI disclosure in PR body if AI-assisted ([SWIFT-PR-006])
- [ ] Create PR via `gh pr create --repo swiftlang/swift` ([SWIFT-PR-007])
- [ ] Verify CODEOWNERS auto-assigned reviewer(s) ([SWIFT-PR-009])
- [ ] Wait for reviewer to trigger CI ([SWIFT-PR-008])
- [ ] Address review feedback, push follow-up commits (do not force-push)

**If asked to split a PR**: Close the current PR with a comment explaining the split. Open new focused PRs. Do NOT force-push to remove commits — force-push is forbidden per FAQ.md.

---

## Cross-References

- **Research**: `/Users/coen/Developer/swift-institute/Research/pr-submission-research.md`
- **Upstream docs**: `/Users/coen/Developer/swiftlang/swift/CONTRIBUTING.md`
- **Upstream docs**: `/Users/coen/Developer/swiftlang/swift/docs/HowToGuides/FirstPullRequest.md`
- **Upstream docs**: `/Users/coen/Developer/swiftlang/swift/docs/ContinuousIntegration.md`
- **CODEOWNERS**: `/Users/coen/Developer/swiftlang/swift/.github/CODEOWNERS`
