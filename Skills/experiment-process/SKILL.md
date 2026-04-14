---
name: experiment-process
description: |
  Experiment workflows: hypothesis, validation, documentation.
  Apply when testing implementation approaches or validating designs.

layer: process

requires:
  - swift-institute

applies_to:
  - experiments
  - validation

migrated_from:
  - Experiments/Experiment.md
  - Experiments/Experiment Investigation.md
  - Experiments/Experiment Discovery.md
migration_date: 2026-01-28
last_reviewed: 2026-03-20
---

# Experiment Process

Workflows for conducting implementation experiments. Three source documents define the experiment system:

| Document | Purpose | IDs |
|----------|---------|-----|
| Experiment.md | Shared infrastructure | EXP-002 – EXP-010d |
| Experiment Investigation.md | Reactive workflow | EXP-001, EXP-004, EXP-004a, EXP-011 |
| Experiment Discovery.md | Proactive workflow | EXP-012 – EXP-017 |

**Experiment vs Unit Test**: Experiments verify Swift compiler/language capabilities. Unit tests verify your implementation. If it tests YOUR code → unit test. If it tests SWIFT behavior → experiment.

**Experiment vs Research**: Experiments produce empirical results (CONFIRMED/REFUTED). Research produces analysis and recommendations (DECISION/RECOMMENDATION). Experiments are Swift packages; research is Markdown.

---

## Investigation Workflow (Reactive)

**Entry point**: Something failed, behaves unexpectedly, or a technical claim needs empirical verification.

### [EXP-001] Investigation Triggers

**Statement**: An investigation experiment MUST be created when a technical claim cannot be verified without executing code. SHOULD NOT be created when documentation answers the question.

| Category | Action |
|----------|--------|
| Compiler behavior uncertainty ("Does X compile?") | Create experiment |
| Documentation contradiction ("Docs say X, I see Y") | Create experiment |
| Feature interaction ("Do A and B work together?") | Create experiment |
| Error diagnosis ("What causes this error?") | Create experiment |
| Syntax question ("What's the syntax?") | Read docs first |
| API lookup | Read docs first |

**Cross-references**: [API-DESIGN-004]

---

### [EXP-004] Reduction Methodology

**Statement**: Code MUST be reduced until removing any single element would eliminate the behavior being tested.

Reduction steps: (1) Start with failing code, (2) remove unused imports, (3) remove uninvolved types, (4) inline function calls, (5) remove unexercised properties/methods, (6) simplify type hierarchies, (7) remove generic parameters if possible. Verify behavior persists after each step.

**Build verification**: Each reduction step MUST use a verified clean build. `rm -rf .build` can silently fail (locked files, nested structures). After deletion, confirm the directory is actually gone (`! test -d .build`) before building. Alternatively, build with `swiftc` directly (no build cache). Stale caches have caused false reductions in multiple investigations — a "crashing" reduction may actually be running cached SIL from a previous variant.

```swift
// CORRECT — Minimal reproduction
struct Resource: ~Copyable {
    consuming func use() throws(SimpleError) { }
}
enum SimpleError: Error { case failed }

// INCORRECT — Non-minimal (Foundation, unused properties, unexercised conformances)
```

**Cross-references**: [EXP-004a]

---

### [EXP-004a] Incremental Construction Methodology

**Statement**: When investigating a hypothesis without existing failing code, complexity SHOULD be added incrementally — one feature at a time — until the behavior appears.

This is the inverse of [EXP-004]. Reduction strips down; construction builds up. Use construction when testing hypotheses or when production code is too complex to port.

**Context-sensitive bugs**: When all experiment variants pass but production fails, the bug requires the *combination* of factors. The experiments proved no single factor causes it — only their interaction does. Experiments that "fail to reproduce" are still valuable: they narrow the search space.

**Cross-references**: [EXP-004], [EXP-011]

---

### [EXP-011] Experiment-First Debugging

**Statement**: When production code fails with uncertain cause, an experiment SHOULD verify the capability works in isolation BEFORE debugging production.

Sequence: (1) Identify uncertainty, (2) create minimal experiment, (3) run — success proves capability works, (4) apply to production, (5) if production fails, compare delta between experiment and production.

**Workaround validation trap**: Minimal reproductions validate that a bug exists. They CANNOT validate that a workaround works at scale. Test workarounds in the actual codebase — the production code may have structural properties the reproduction lacks.

**Cross-references**: [EXP-001], [EXP-004a]

---

### [EXP-018] Experiment Consolidation

**Statement**: When an investigation produces 5 or more experiments exploring related aspects of the same bug, feature, or design question, they SHOULD be consolidated into thematically coherent groups before further investigation. Each consolidated experiment groups variants by the specific hypothesis they test, with a shared `EXPERIMENT.md` documenting the relationships between variants.

**Consolidation procedure**:

| Step | Action |
|------|--------|
| 1. Categorize | Group experiments by the distinct hypothesis each tests |
| 2. Create | One consolidated package per category, containing the relevant variants |
| 3. Archive | Add `SUPERSEDED.md` to originals pointing to the consolidated package (do not delete) |
| 4. Update | Fix cross-references in all research documents that referenced the originals |
| 5. Index | Update `_index.md` |

**Why consolidate**: Scattered experiments obscure the investigation's structure. Consolidation makes the evidence base visible as a whole — which hypotheses have been tested, which remain open, and how findings relate to each other. This visibility often reveals the investigation's actual structure (e.g., "three distinct bugs, not one") and accelerates root-cause identification.

**When NOT to consolidate**: Independent experiments that happen to involve the same package but test unrelated hypotheses SHOULD remain separate.

**Standalone vs context-sensitive reproducers**: If a consolidated experiment includes a standalone reproducer (one that crashes without the full dependency graph), elevate it to its own package. Context-sensitive experiments that only fail within the full dependency graph should be clearly documented as such — their value is in narrowing the search space, not in standalone bug reporting.

**Cross-references**: [EXP-004], [EXP-004a], [EXP-011]

---

## Shared Infrastructure

### [EXP-002] Package Location Convention

**Statement**: Experiment packages MUST be in an `Experiments/` directory at the
root of the appropriate repository, with descriptive kebab-case names.

| Scope | Repository |
|-------|------------|
| Ecosystem-wide | `swift-institute/Experiments/` |
| Primitives-specific | `swift-primitives/Experiments/` |
| Standards-specific | `swift-standards/Experiments/` |
| Foundations-specific | `swift-foundations/Experiments/` |

**Superrepo note**: `swift-primitives`, `swift-standards`, and `swift-foundations`
are superrepos containing many packages as targets. `Experiments/` lives at the
superrepo root, not inside individual target directories. Experiments about a
specific target (e.g., `Buffer_Primitives`) still go in the superrepo's
`Experiments/` directory — the experiment directory name identifies the target
(e.g., `buffer-primitives-noncopyable-test/`).

**Cross-references**: [EXP-002a], [EXP-008]

---

### [EXP-002a] Experiment Triage

**Statement**: Before creating an experiment, determine scope. Experiments specific
to one superrepo go in that superrepo. Ecosystem-wide experiments go in
swift-institute.

| Criterion | Repo |
|-----------|------|
| One target's types, reproducing a bug in one module | The superrepo containing that target |
| Multiple targets within one superrepo | That superrepo |
| General Swift behavior (language feature, compiler) | `swift-institute` |
| Cross-package interaction across layers | `swift-institute` |

**Decision rule**: If the experiment only exercises types from one superrepo, it
goes there. If it tests general Swift behavior or cross-repo interaction, it goes
in swift-institute.

**Cross-references**: [EXP-002], [EXP-006a]

---

### [EXP-002b] Package Isolation

**Statement**: Each experiment directory MUST contain its own `Package.swift`. The parent package MUST NOT reference experiments as targets, products, or dependencies.

**Cross-references**: [EXP-002], [EXP-003]

---

### [EXP-003] Minimal Package Structure

**Statement**: Experiment packages MUST contain only what is needed to verify the behavior. No unnecessary files, dependencies, or complexity.

```text
Experiments/sendable-closure-test/
├── Package.swift
└── Sources/
    └── main.swift
```

**Cross-references**: [EXP-003a], [EXP-003b]

---

### [EXP-003a] Package.swift Template

**Statement**: Package.swift MUST specify minimum configuration. Experiments MUST use Swift 6.2 and v26 platforms. Only include Swift settings being tested.

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sendable-closure-test",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "sendable-closure-test",
            swiftSettings: [
                // Only flags being tested
            ]
        )
    ]
)
```

**Cross-references**: [EXP-003], [EXP-003b]

---

### [EXP-003b] main.swift Template

**Statement**: main.swift MUST include a header comment with: purpose, hypothesis, toolchain, platform, result, date.

```swift
// MARK: - Sendable Closure Verification
// Purpose: Verify @Sendable closures compile in Embedded Swift
// Hypothesis: @Sendable attribute is available without runtime
//
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-01-18-a
// Platform: macOS 15.0 (arm64)
//
// Result: CONFIRMED - compiles and links successfully
// Date: 2026-01-19

func takeSendableClosure(_ closure: @Sendable () -> Int) -> Int {
    return closure()
}
let result = takeSendableClosure { 42 }
print(result)  // Output: 42
```

**Cross-references**: [EXP-005], [EXP-006]

---

### [EXP-003c] Output Artifacts

**Statement**: Outputs are ephemeral by default. Capture during execution via `tee`. MUST NOT commit unless the header excerpt is insufficient (multi-page diagnostics, benchmark tables). If committed, use `Outputs/` directory with stable names (`build.txt`, `build-release.txt`, `run.txt`, `build-embedded.txt`).

**Cross-references**: [EXP-003], [EXP-005]

---

### [EXP-003d] Naming Alignment

**Statement**: Directory name, `Package.name`, and executable target name MUST be identical.

**Cross-references**: [EXP-002], [EXP-003]

---

### [EXP-003e] Experiment Index

**Statement**: If `Experiments/` contains 2+ directories, `Experiments/_index.md` MUST exist. Must contain: Directory, Purpose, Date, Toolchain, Status (CONFIRMED/REFUTED/SUPERSEDED). `_index.md` is the only allowed non-experiment file.

**Cross-references**: [EXP-002], [EXP-008]

---

### [EXP-005] Execution Protocol

**Statement**: Experiments MUST be built with standard commands and output captured verbatim.

```bash
cd Experiments/sendable-closure-test
mkdir -p Outputs
swift package clean
swift build 2>&1 | tee Outputs/build.txt        # Standard
swift build -c release 2>&1 | tee Outputs/build-release.txt  # Release
swift run 2>&1 | tee Outputs/run.txt             # Runtime
```

Output files are working artifacts, NOT committed by default. The main.swift header is the primary evidence record.

**Cross-references**: [EXP-003c], [EXP-006], [EXP-007]

---

### [EXP-006] Result Documentation

**Statement**: Results MUST be documented in the main.swift header immediately after execution.

| Outcome | Action |
|---------|--------|
| Confirmed | `Result: CONFIRMED` + evidence ([EXP-006b]) |
| Refuted | `Result: REFUTED` + primary diagnostic line + command |
| Unexpected | Update header, consider filing bug report |
| Limitation | Update header, reference in relevant docs |

For REFUTED: header MUST include (1) primary diagnostic line, (2) command that produced it, (3) pointer to full output only if committed.

**Cross-references**: [EXP-006a], [EXP-006b], [EXP-003b]

---

### [EXP-006a] Documentation Promotion

**Statement**: When results affect Swift Institute packages, findings MUST be promoted to relevant documentation with: rule ID, scope, statement, test package path, toolchain, date.

**Cross-references**: [EXP-006]

---

### [EXP-006b] Confirmation Evidence

**Statement**: If `Result: CONFIRMED`, the header MUST include at least one form of evidence: output snippet (`// Output: 42`), measured value (`// Time: 0.003s`), or compile-time proof (`// Build Succeeded`). Bare "CONFIRMED" without evidence is insufficient.

**Cross-references**: [EXP-006]

---

### [EXP-007] Toolchain Specification

**Statement**: Results MUST record exact toolchain. Development snapshots MUST include snapshot date.

```swift
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-01-18-a
// Platform: macOS 15.0 (arm64)
// Xcode: 16.2
```

**Cross-references**: [EXP-005], [EXP-006]

---

### [EXP-008] Experiment Package Lifecycle

**Statement**: Experiments are persistent and git-tracked. Lifecycle: Active → Documented → Referenced → Superseded → Archived (optional, `_archived/` directory).

When superseded, add header note with reason and link to replacement. Git history provides: historical record, collaboration, discoverability, bisection capability.

**Cross-references**: [EXP-002], [EXP-006a]

---

### [EXP-009] Multi-Variant Testing

**Statement**: Multiple related scenarios SHOULD be organized in clearly delimited `MARK` sections with individual results.

```swift
// MARK: - Variant 1: Basic Sendable
// Hypothesis: Basic Sendable struct compiles
// Result: CONFIRMED

struct V1: Sendable { let value: Int }

// MARK: - Variant 2: Sendable with closure
// Hypothesis: Sendable with @Sendable closure compiles
// Result: CONFIRMED

struct V2: Sendable { let action: @Sendable () -> Void }

// MARK: - Results Summary
// V1: CONFIRMED
// V2: CONFIRMED
```

For complex variants, use multi-file organization with `Variant1_*.swift` files.

**Cross-references**: [EXP-003], [EXP-006]

---

### [EXP-010] Common Experiment Patterns

**Statement**: Experiments SHOULD follow established templates for common types.

**Cross-references**: [EXP-003b], [EXP-006]

---

### [EXP-010a] Feature Availability Test

Template for "Does {feature} compile with {configuration}?": Purpose, hypothesis, toolchain → minimal code using feature → build command → expected result (Build Succeeded / specific error).

---

### [EXP-010b] Runtime Behavior Test

Template for "What does {operation} actually do?": Purpose, hypothesis, toolchain → test function with explicit `print("Input: ...")` and `print("Output: ...")` → run command → expected vs actual output.

---

### [EXP-010c] Error Message Discovery

Template for "What error does {invalid code} produce?": Purpose, hypothesis, toolchain → intentionally invalid code → build command → captured exact diagnostic text verbatim.

---

### [EXP-010d] Configuration Comparison

Template for "Does {behavior} differ between debug and release?": Purpose, hypothesis, toolchain → test code → run both `swift build -c debug` and `-c release` → document debug result, release result, and any differences.

---

## Discovery Workflow (Proactive)

**Entry point**: Audit a package, verify claims, or systematically explore behavior.

### [EXP-012] Discovery Triggers

**Statement**: A discovery experiment SHOULD be created when proactive verification would increase confidence, document evidence for claims, or identify improvements.

| Category | Priority |
|----------|----------|
| Package milestone (v1.0) | High |
| Toolchain update | High |
| Assumption audit | Medium |
| Claim verification | Medium |
| Boundary exploration | Medium |
| Cross-package verification | Medium |
| Improvement hypothesis | Low |

**Discovery vs Investigation**: Investigation starts from broken code to fix it. Discovery starts from working code to verify it.

**Cross-references**: [EXP-001], [EXP-002a]

---

### [EXP-013] Package Audit Methodology

**Statement**: Package audits MUST follow: (1) Inventory public types/APIs, (2) Extract testable claims from docs/comments, (3) Identify implicit assumptions, (4) Prioritize by risk, (5) Generate experiments, (6) Execute, (7) Document.

Claims use `[CLAIM-XXX]` IDs. Assumptions use `[ASSUMP-XXX]` IDs. Prioritize by risk × importance (P0/P1/P2).

**Cross-references**: [EXP-014], [EXP-015], [EXP-016]

---

### [EXP-014] Assumption Inventory

**Statement**: Implicit assumptions MUST be inventoried before creating experiments. Examine: type constraints, memory semantics (~Copyable, ownership), concurrency (Sendable, isolation), platform requirements, performance claims, compiler feature dependencies.

Each assumption becomes an experiment hypothesis. Extract from code patterns like `consuming func` (assumes move semantics), optional returns (assumes empty state valid), `@unchecked Sendable` (assumes thread safety by construction).

**Cross-references**: [EXP-013], [EXP-015]

---

### [EXP-015] Claim Verification

**Statement**: Testable claims in documentation SHOULD be verified through experiments.

| Category | Verification Method |
|----------|---------------------|
| Complexity | Benchmark with varying input sizes |
| Conformance | Compile-time check |
| Behavior | Runtime test with assertions |
| Compatibility | Cross-version compilation |
| Interoperability | Integration test |

**Cross-references**: [EXP-013], [EXP-014]

---

### [EXP-016] Boundary Exploration

**Statement**: Boundary experiments SHOULD test: empty states, capacity limits, type extremes, overflow/underflow, error paths, concurrency contention.

Test boundaries systematically: collection sizes (empty, one, many, max), numeric limits (min, max, overflow), string edge cases (empty, unicode), optional states, all error paths, concurrency levels.

**Cross-references**: [EXP-013], [EXP-009]

---

### [EXP-017] Improvement Discovery

**Statement**: When a potential improvement is identified, an experiment SHOULD test it with baseline comparison.

Template: Purpose, hypothesis, baseline measurement → current implementation → proposed implementation → benchmark comparison → evidence (baseline vs proposed).

| Evidence | Decision |
|----------|----------|
| Significant improvement, no regression | Recommend adoption |
| Marginal improvement, added complexity | Document, defer |
| No improvement | Document, do not adopt |
| Regression in some cases | Document tradeoffs |

**Cross-references**: [EXP-013], [EXP-015]

---

## Cross-References

See also:
- **research-process** skill for design analysis workflows
- **blog-process** skill for publishing findings
- **implementation** skill for [COPY-FIX-*] ~Copyable constraint patterns (often triggers experiments)
