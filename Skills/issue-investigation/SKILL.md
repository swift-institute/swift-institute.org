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
diagnoses. Strengthened by literature study and comparative analysis across Rust, LLVM,
GCC, and GHC ecosystems (Research: `issue-investigation-best-practices.md`).

The ordering of steps reflects empirical cost: checking the dev toolchain (30s)
has prevented hours of unnecessary compiler source analysis in multiple sessions.

---

## Step 0: Classify the Issue

### [ISSUE-010] Bug Classification

**Statement**: Before investigation, classify the issue into one of five categories. The category determines the investigation strategy and the kind of evidence needed.

| Category | Description | Evidence Needed |
|----------|-------------|-----------------|
| **ICE/Crash** | Compiler itself crashes (signal, assertion, verifier) | Stack trace, reproducer, SIL dump |
| **Miscompile** | Compiles but produces wrong output | Expected vs actual output, optimization level |
| **Rejects-valid** | Correct code rejected with error | Code sample, expected behavior, diagnostic ID |
| **Accepts-invalid** | Incorrect code accepted without error | Code sample, spec reference |
| **Diagnostic** | Confusing or incorrect error message | Diagnostic text, `-debug-diagnostic-names` output |

**Crash/ICE** and **Miscompile** follow the full pipeline below (Steps 1-6). **Rejects-valid**, **Accepts-invalid**, and **Diagnostic** skip SIL analysis (Step 3) and focus on type checker (`-debug-constraints`) or diagnostic investigation (`-debug-diagnostic-names`).

**Rationale**: Adopted from GCC, LLVM, Rust, and GHC -- all four ecosystems use this taxonomy. Explicit classification prevents applying crash-investigation techniques to diagnostic issues and vice versa.

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

# Print functions whose mangled name contains a substring:
swiftc -O -Xllvm '-sil-print-functions=MyType' reproducer.swift 2>&1

# Verify ownership after every pass (finds the first failing pass):
swiftc -Xfrontend -sil-verify-all reproducer.swift 2>&1
```

**Read the error message carefully**. The compiler often prints:
- The exact SIL value and instruction that violate ownership
- The function name (mangled)
- The pass that detected the violation
- Suggested flags for further diagnosis

---

### [ISSUE-011] Pass Bisection

**Statement**: For optimization bugs (crash or miscompile at `-O` but not `-Onone`), use pass count bisection to identify the exact failing pass. For multi-transformation passes, use sub-pass bisection.

```bash
# Step 1: Binary search for the bad pass number
swiftc -O -Xllvm -sil-opt-pass-count=100 reproducer.swift    # works?
swiftc -O -Xllvm -sil-opt-pass-count=1000 reproducer.swift   # crashes?
# Binary search between 100 and 1000...

# Step 2: Once found, print SIL before/after the bad pass
swiftc -O -Xllvm -sil-opt-pass-count=550 -Xllvm -sil-print-last reproducer.swift 2>sil.txt

# Step 3: For multi-transformation passes (SILCombine, SimplifyCFG):
swiftc -O -Xllvm '-sil-opt-pass-count=550.25' reproducer.swift

# Step 4: Disable a suspect pass entirely:
swiftc -O -Xllvm '-sil-disable-pass=sil-combine' reproducer.swift
```

**For large projects**: Read pass counts from a file with `-Xllvm -sil-pass-count-config-file=<file>`.

**Automated bisection**: The `llvm/utils/bisect` utility automates the binary search:
```bash
llvm-project/llvm/utils/bisect --start=0 --end=10000 ./invoke_swift_passing_N.sh "%(count)s"
```

**Rationale**: Pass bisection is the primary technique used by the Swift compiler team (documented in `DebuggingTheCompiler.md`). Sub-pass notation (`<n>.<m>`) was contributed by meg-gupta for multi-transformation passes. Issue swiftlang/swift#66312 demonstrates the gold standard: bisection to sub-pass 13669.10 got a same-day fix from the SIL optimizer owner.

---

### [ISSUE-006] Hypothesis Discipline

**Statement**: Form hypotheses from evidence, not from prior investigations. Each hypothesis MUST be testable by a specific code change or compiler flag.

**Anti-pattern**: "This looks like Bug 2 (#88022) because it's also a CopyPropagation crash" — different CopyPropagation crashes have different root causes. The pass name is not a diagnosis.

**Correct pattern**: "The SIL shows `load [take]` on `$*Optional<Bool>` which is trivial. Hypothesis: the enum destructuring generates `load [take]` unconditionally for all tuple elements, including trivial ones. Test: remove the trivial field from the enum."

**Rationale**: The 2026-03-31 investigation initially hypothesized SILCloner forwarding ownership, then generic specialization, then multi-pass interaction — each more complex than the actual root cause (SILGen using `createLoad(...Take)` instead of `TypeLowering::emitLoad()`). The SIL evidence was available from the first dump.

---

### [ISSUE-012] Compiler Source Reading

**Statement**: For optimizer bugs, reading the compiler source SHOULD be attempted early — particularly when the SIL dump reveals the failing pass and instruction. Look for TODO/FIXME comments, known-limitation guards, and bailout conditions near the crash site.

**When to read source**:
1. The SIL dump clearly identifies the crashing pass and the specific operation
2. Multiple experiments have failed to reproduce in isolation (the bug is in how the optimizer handles a pattern)
3. The bug has been narrowed to a specific pass but the root cause is unclear

**What to look for**:
- `TODO` / `FIXME` comments acknowledging known limitations (the Bug 2 TODO at `OSSACanonicalizeOwned.cpp:40-46` provided more signal than 7 experiments)
- Bailout conditions for specific IR patterns (e.g., `PointerEscape` classification in `OperandOwnership.cpp`)
- Assertions that guard the failing code path

**Rationale**: The 2026-03-22 investigation resolved Bug 2 by reading compiler source — a TODO comment confirmed the hypothesis before any fix was written. The 2026-03-22 rawlayout investigation fixed the compiler in 21 lines after reading `GenStruct.cpp`. In both cases, source reading was more efficient than continued empirical exploration.

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

## Step 7: Context-Sensitive Reproduction

### [ISSUE-013] Variable Isolation for Context-Sensitive Bugs

**Statement**: When a bug reproduces in the full build but not in a standalone experiment, systematically vary one integration dimension at a time to build a constraint model.

**Variables to test independently**:

| Variable | Test |
|----------|------|
| Access level | `public` vs `internal` (different codegen paths) |
| Field count | 1-field vs 2+ fields |
| Dependencies | Zero deps vs full dependency graph |
| Generic vs concrete | Generic type parameters vs concrete types |
| Optimization mode | `-Onone` vs `-O` vs `-Osize` |
| Compilation mode | Single-file vs WMO |
| Module isolation | Same-module vs cross-module |

**Build a constraint model**:
```
Required: public + 2+ fields + @_rawLayout + deinit + release = crash
Removing any one dimension: passes
```

**Rationale**: The 2026-03-22 investigation discovered the access-level trigger (`public` crashes, `internal` works) through systematic variable isolation. Without testing `public` access, the combined @_rawLayout approach appeared to work — a false positive.

---

### [ISSUE-014] File-Level Elimination

**Statement**: For WMO or cross-module bugs that don't reduce to a single file, use file-level elimination: empty all source files in the target, add back one at a time, rebuild after each. This identifies the trigger file in minutes.

```bash
# Save originals, empty all files
for f in Sources/MyTarget/*.swift; do cp "$f" "$f.bak"; echo "" > "$f"; done

# Add files back one at a time, rebuild between each
cp Sources/MyTarget/Buffer.swift.bak Sources/MyTarget/Buffer.swift
swift build -c release  # Crash? → Buffer.swift is involved.
```

**Rationale**: Proved decisive for the LLVM verifier crash investigation (2026-03-20). File-level elimination took minutes and gave definitive answers, while code-level modification consumed hours without progress.

---

### [ISSUE-015] Superrepo Validation

**Statement**: For ecosystems with layered superrepos, sub-repo release builds are necessary but NOT sufficient. The full superrepo build MUST be used for release-mode validation because deeper cross-module inlining exposes bugs invisible in isolation.

**Evidence**: Bug 2 affected 5 functions in sub-repo builds but 60+ functions across 9 repos in the superrepo. CMO bugs are latent in existing passes, only exposed when cross-module inlined code creates new patterns.

---

## Reduction Tooling

### [ISSUE-016] Available Reduction Tools

**Statement**: Use the appropriate reduction tool for the abstraction level of the bug.

**Source-level reduction**:
- **C-Reduce** (external, works on Swift via language-agnostic passes): Write an interestingness test shell script, run `creduce interestingness_test.sh reproducer.swift`. The C-specific passes fail silently; agnostic passes still achieve significant reduction.
- **Manual reduction** per [EXP-004]: Remove imports, types, functions, generics one at a time. Verify behavior persists after each step.

**SIL-level reduction**:
- **`bug_reducer.py`** (`swiftlang/swift/utils/bug_reducer/`): Reduces pass count and function set to minimal triggering configuration. Alpha quality; function-level only.
- **`sil-func-extractor`**: Extract specific SIL functions for targeted analysis.

**Pass-level reduction**:
- **`-sil-opt-pass-count=<n>`** with binary search per [ISSUE-011].
- **`-sil-disable-pass=<tag>`** to confirm a specific pass is involved.

**Interestingness test pattern** (from C-Reduce/llvm-reduce):
```bash
#!/bin/bash
# interestingness_test.sh — exit 0 if bug reproduces, 1 if not
swiftc -O "$1" 2>&1 | grep -q "Found ownership error"
```

**Rationale**: Swift has a significant tooling gap in test case reduction compared to C/C++ (C-Reduce, llvm-reduce) and Rust (treereduce, icemelter, cargo-bisect-rustc). Documenting available tools and the interestingness test pattern makes the best of what exists.

---

## Issue Filing

### [ISSUE-017] Issue Report Format

**Statement**: When filing a swiftlang/swift issue, the report MUST include at minimum: classification ([ISSUE-010]), environment, reproducer, and observed behavior. Reports with pass bisection results get same-day fixes.

**Template**:
```markdown
**Classification**: [ICE/Miscompile/Rejects-valid/Accepts-invalid/Diagnostic]
**Environment**: Swift X.Y, macOS/Linux, -O/-Onone/-Osize, WMO/single-file
**Reproducer**: [standalone .swift file, buildable with bare swiftc]

[code block]

**Command**: swiftc -O reproducer.swift
**Observed**: [crash output / wrong behavior / wrong diagnostic]
**Expected**: [what should happen]

**Investigation** (if done):
- Pass bisection: crashes at pass #N (PASS_NAME), passes at N-1
- Before/after SIL: [diff or description]
- Ingredient list: [what's required to trigger]
```

**What gets quick attention** (empirical, from merged PRs):
1. Standalone single-file reproducer buildable with bare `swiftc`
2. Pass bisection to specific pass or sub-pass number
3. Before/after SIL diff
4. Clear explanation of the invariant violation

**What gets deprioritized**:
- Issues requiring SwiftPM project or external dependencies to reproduce
- Issues without version/platform information
- Issues where the reporter hasn't attempted reduction

**Rationale**: Academic research (Bettenburg et al. 2008) confirms: steps to reproduce (89% importance), stack traces, and test cases are the top-3 elements correlated with fast resolution. swiftlang/swift#66312 demonstrates the gold standard — bisection to sub-pass 13669.10 got a same-day fix.

---

## Extended Debugging Toolkit

### [ISSUE-018] Diagnostic Investigation Tools

**Statement**: For non-crash issues (rejects-valid, diagnostic quality), use the appropriate diagnostic tool.

| Tool | Flag | Purpose |
|------|------|---------|
| Diagnostic names | `-Xfrontend -debug-diagnostic-names` | Appends `[diagnostic_id]` to every error — search compiler source for this ID |
| Type checker trace | `-Xfrontend -debug-constraints` | Full constraint solver log (verbose; essential for type inference bugs) |
| Assert on error | `-Xllvm -swift-diagnostics-assert-on-error=1` | Stack trace at the exact point the error is emitted |
| AST dump | `swiftc -dump-ast file.swift` | Type-checked AST (identifies type inference results) |
| Parse-only dump | `swiftc -dump-parse file.swift` | Parse tree without type checking (isolates parsing issues) |
| Type-check only | `swiftc -typecheck file.swift` | Fastest way to check for type errors (no codegen) |

---

### [ISSUE-019] SIL Pipeline Stages

**Statement**: When investigating, dump SIL at the appropriate pipeline stage to isolate whether the bug is in SILGen, mandatory passes, or optimization passes.

| Stage | Command | What it shows |
|-------|---------|---------------|
| Raw SIL | `swiftc -emit-silgen file.swift` | SIL immediately after SILGen (before any optimization) |
| Canonical SIL | `swiftc -emit-sil -Onone file.swift` | After mandatory passes |
| Optimized SIL | `swiftc -emit-sil -O file.swift` | After full optimization pipeline |
| LLVM IR (pre-opt) | `swiftc -emit-irgen -O file.swift` | After IRGen, before LLVM optimization |
| LLVM IR (post-opt) | `swiftc -emit-ir -O file.swift` | After LLVM optimization |

Use `-save-sil`, `-save-irgen`, `-save-ir` to save alongside normal compilation output.

If the bug is in raw SIL (`-emit-silgen`), the problem is in SILGen. If raw SIL is correct but canonical SIL is broken, a mandatory pass is at fault. If canonical SIL is correct but optimized SIL is broken, an optimization pass is at fault. Use [ISSUE-011] pass bisection to narrow further.

---

## Quick Reference

```
0. Classify: ICE / Miscompile / Rejects-valid / Accepts-invalid / Diagnostic
1. TOOLCHAINS=swift xcrun swiftc -O repro.swift    # Fixed? → Stop.
2. Reduce to single swiftc-reproducible file        # Clean build each step.
3. Verify each ingredient independently              # Remove one, rebuild clean.
4. Bisect: -Xllvm -sil-opt-pass-count=<n>           # Find the bad pass.
5. Dump SIL: -Xllvm -sil-print-last (with count)    # Read the before/after diff.
6. Read compiler source if pass is identified        # Look for TODOs, bailouts.
7. Search github.com/swiftlang/swift/issues          # Duplicate?
8. File issue or apply workaround                     # Document everything.
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
