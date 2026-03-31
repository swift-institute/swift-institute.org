---
name: issue-investigation
description: |
  Systematic investigation of compiler and toolchain issues: reproduce, reduce, verify, resolve.
  Apply when encountering a compiler crash, SIL verification failure, miscompile, or
  unexpected toolchain behavior that blocks development.

layer: process

requires:
  - swift-institute-core
  - experiment-process

applies_to:
  - compiler-issue
  - toolchain-issue
  - silgen-bug
  - sil-optimizer-bug

last_reviewed: 2026-03-31
---

# Issue Investigation

Systematic workflow for investigating compiler and toolchain issues. Designed to minimize
wasted effort by front-loading cheap checks before expensive analysis.

**Provenance**: Distilled from five compiler bug investigations (2026-02 through 2026-03):
CopyPropagation Bug 2 (#88022), @_rawLayout LLVM verifier crash, SILGen trivial field
load ownership (#85743), mark_dependence simplification, and multiple release-mode crash
diagnoses. The ordering of steps reflects empirical cost: checking the dev toolchain (30s)
has prevented hours of unnecessary compiler source analysis in multiple sessions.

---

## Step 1: Verify Against Latest Toolchain

### [ISSUE-001] Check Dev Toolchain First

**Statement**: Before ANY investigation, the issue MUST be tested against the latest available Swift development toolchain. If the issue does not reproduce, it is already fixed upstream — stop investigation.

```bash
# Test with installed dev toolchain:
TOOLCHAINS=swift xcrun swiftc -O reproducer.swift -o /tmp/test 2>&1

# Or via SwiftPM:
TOOLCHAINS=swift swift build -c release
```

**If it passes on dev**: Record the finding ("fixed in 6.x-dev"), apply `@_optimize(none)` or other workaround for current Xcode, and move on. No issue or PR needed.

**If it fails on dev**: Proceed to Step 2.

**Rationale**: This is the single highest-ROI check. In the 2026-03-31 session, hours were spent investigating a CopyPropagation crash that was already fixed in Swift 6.4-dev (swiftlang/swift#85743). A 30-second toolchain check would have prevented the entire deep-dive.

---

## Step 2: Create Minimal Reproduction

### [ISSUE-002] Standalone Reproducer

**Statement**: A reproducer MUST compile with `swiftc` directly (no SwiftPM). It MUST be a single `.swift` file. It MUST crash or fail without any project structure, dependencies, or build system.

```bash
# The gold standard: single file, single command
swiftc reproducer.swift -o /tmp/test
# or
swiftc -O reproducer.swift -o /tmp/test
```

**If the issue requires SwiftPM** (WMO, multi-module): document this as a constraint, but continue trying to reduce to `swiftc`.

**Rationale**: `swiftc`-reproducible bugs are unambiguous. SwiftPM-only bugs can be conflated with build system behavior, caching artifacts, or dependency interactions.

---

### [ISSUE-003] Reduction Protocol

**Statement**: Reduce per [EXP-004] with ONE critical addition: **every reduction step MUST use a clean build**. Verify `rm -rf .build` succeeded (check exit code or confirm directory absence) before trusting any build result.

**Reduction order** (remove one element per step, verify crash persists):
1. Remove async/await, closures, actors
2. Remove framework dependencies (Synchronization, Dispatch, etc.)
3. Remove class wrappers — use structs or top-level code
4. Remove protocol conformances (Sendable, Equatable, etc.)
5. Remove generic parameters — use concrete types
6. Remove extra enum cases — try single-case
7. Remove extra tuple fields
8. Remove function wrapping — try top-level code
9. Remove SwiftSettings (strictMemorySafety, experimental features)

**At each step**: If removal eliminates the crash, that element is REQUIRED — restore it and continue reducing other elements.

**Stale build trap**: SwiftPM's `.build` directory can survive `rm -rf` (locked files, nested structures). If a reduction appears to crash but shouldn't, test with `swiftc` directly to rule out cached artifacts.

**Rationale**: The 2026-03-31 investigation produced multiple false reductions because `rm -rf .build` silently failed, leaving stale artifacts from earlier variants. Every "crash" in the reduction series was actually running against cached SIL from the first successful reproduction.

---

### [ISSUE-004] Required Ingredient Verification

**Statement**: After reduction, each remaining element MUST be independently verified as necessary. For each element, remove ONLY that element and rebuild from clean. If the crash disappears, that element is required. If the crash persists, remove it permanently.

**Document the ingredient list**:
```markdown
Required ingredients (removing any one makes it pass):
1. Generic ~Copyable enum (non-generic passes)
2. Tuple payload with trivial field (single-payload passes)
3. Consuming switch destructuring (borrowing passes)
```

**Rationale**: Systematic ingredient verification prevents over-reduction (removing something that happens to coincide with the fix) and under-reduction (keeping unnecessary elements).

---

## Step 3: Diagnose

### [ISSUE-005] SIL Dump Analysis

**Statement**: For SIL-level bugs (CopyPropagation, ownership verification, etc.), dump the SIL around the failing pass to identify the exact instruction sequence.

```bash
# Print SIL before/after the crashing pass:
swiftc -O -Xllvm -sil-print-around=CopyPropagation reproducer.swift 2>&1 | head -200

# Print SIL for a specific function:
swiftc -O -Xllvm '-sil-print-function=MANGLED_NAME' reproducer.swift 2>&1

# Verify ownership after every pass (finds the first failing pass):
swiftc -Xfrontend -sil-verify-all reproducer.swift 2>&1
```

**Read the error message carefully**. The compiler often prints:
- The exact SIL value and instruction that violate ownership
- The function name (mangled)
- The pass that detected the violation
- Suggested flags for further diagnosis

---

### [ISSUE-006] Hypothesis Discipline

**Statement**: Form hypotheses from evidence, not from prior investigations. Each hypothesis MUST be testable by a specific code change or compiler flag.

**Anti-pattern**: "This looks like Bug 2 (#88022) because it's also a CopyPropagation crash" — different CopyPropagation crashes have different root causes. The pass name is not a diagnosis.

**Correct pattern**: "The SIL shows `load [take]` on `$*Optional<Bool>` which is trivial. Hypothesis: the enum destructuring generates `load [take]` unconditionally for all tuple elements, including trivial ones. Test: remove the trivial field from the enum."

**Rationale**: The 2026-03-31 investigation initially hypothesized SILCloner forwarding ownership, then generic specialization, then multi-pass interaction — each more complex than the actual root cause (SILGen using `createLoad(...Take)` instead of `TypeLowering::emitLoad()`). The SIL evidence was available from the first dump.

---

## Step 4: Search for Duplicates

### [ISSUE-007] Duplicate Search

**Statement**: Before filing an issue or PR, search for duplicates using the exact error message, the SIL instruction pattern, and the Swift feature combination.

**Search strategy**:
```
site:github.com/swiftlang/swift/issues "EXACT ERROR MESSAGE"
site:github.com/swiftlang/swift/issues FEATURE1 FEATURE2 crash
```

**Also search**:
- The swiftlang/swift commit log for recent fixes matching the pattern
- The compiler source for TODO comments mentioning the limitation

**If a fix exists on main**: Check if it's in the dev toolchain (Step 1 should have caught this, but the fix may be very recent).

---

## Step 5: Resolve

### [ISSUE-008] Resolution Paths

**Statement**: Choose the resolution path based on the diagnosis.

| Situation | Path |
|-----------|------|
| Fixed on dev toolchain, not in Xcode | Apply workaround, document, wait for release |
| Unfixed, clear root cause, small fix | File issue with reproducer, optionally prepare PR per `/swift-pull-request` |
| Unfixed, unclear root cause | File issue with reproducer and SIL dump evidence |
| Our code triggers a known limitation | Restructure our code to avoid the trigger |

**Workaround documentation**: When applying `@_optimize(none)` or other workarounds, ALWAYS include:
```swift
// WORKAROUND: {what it works around}
// WHY: {root cause}
// TRACKING: {issue URL or commit hash of fix}
// WHEN TO REMOVE: {condition — e.g., "when Xcode ships Swift 6.4+"}
```

---

## Step 6: Record

### [ISSUE-009] Investigation Record

**Statement**: Every investigation MUST be recorded in the relevant package's `Research/audit.md` with: severity, location, finding, status (WORKAROUND/RESOLVED/DEFERRED), and tracking reference.

**For experiments created during investigation**: Follow [EXP-006] to document results in the experiment's main.swift header.

**For reflections**: If the investigation produced significant learning, invoke `/reflect-session` per [REFL-001].

---

## Quick Reference

```
1. TOOLCHAINS=swift xcrun swiftc -O repro.swift    # Fixed? → Stop.
2. Reduce to single swiftc-reproducible file        # Clean build each step.
3. Verify each ingredient independently              # Remove one, rebuild clean.
4. Dump SIL: -Xllvm -sil-print-around=PassName      # Read the error.
5. Search github.com/swiftlang/swift/issues          # Duplicate?
6. File issue or apply workaround                     # Document everything.
```

---

## Cross-References

- **experiment-process** skill for [EXP-004] reduction methodology, [EXP-004a] incremental construction
- **swift-pull-request** skill for [SWIFT-PR-011] dev toolchain check, PR submission workflow
- **reflect-session** skill for [REFL-001] post-investigation reflection
- **implementation** skill for [IMPL-061] compiler fix over workaround accumulation
- Research: `swift-institute/Research/Reflections/2026-03-22-copypropagation-nonescapable-root-cause-and-fix.md`
- Research: `swift-institute/Research/Reflections/2026-03-31-noncopyable-io-completion-cascade-and-silgen-bug-discovery.md`
- Research: `swift-institute/Research/compiler-pr-copypropagation-mark-dependence-handoff.md`
