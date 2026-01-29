---
name: package-export
description: |
  Export Swift packages to single files for LLM consumption (ChatGPT, Claude, etc.).
  Apply when asked to export, dump, or concatenate a package for sharing with an LLM.

layer: process

requires:
  - swift-institute-core

applies_to:
  - export
  - chatgpt
  - llm
  - package
---

# Package Export for LLM

Export Swift packages to single text files optimized for LLM consumption. Supports separate sources and tests exports.

---

## Export Format

### [PKG-EXPORT-001] Output Structure

**Statement**: Package exports MUST follow this structure:

```
# {package-name}

## Package Manifest

{Package.swift contents, raw}

## File Structure

{tree of Sources/ directory}

## Source Files

### File: {relative-path}

{file contents, raw}

### File: {next-relative-path}

{file contents, raw}
```

**Rationale**: This format provides:
- Package manifest context at top for dependency understanding
- File tree for structural orientation
- Clear `### File:` headers for LLM navigation
- Minimal overhead (~3-5% tokens vs ~15% for full markdown code fences)
- Copy-paste friendly (works in plain text contexts)

---

### [PKG-EXPORT-002] Tests Export Structure

**Statement**: When tests are exported separately, they MUST use this structure:

```
# {package-name} Tests

## Test File Structure

{tree of Tests/ directory}

## Test Files

### File: {relative-path}

{file contents, raw}
```

**Rationale**: Separate test files allow sharing tests without sources when discussing test strategies.

---

## File Ordering

### [PKG-EXPORT-003] File Order

**Statement**: Files MUST be ordered to maximize LLM comprehension:

1. **Namespace root files first** — Files defining the root namespace type (e.g., `Test.swift` before `Test.Case.swift`)
2. **Then alphabetically by path** within each directory

**Detection rule**: A file is a namespace root if:
- Its filename is exactly `{Namespace}.swift` (e.g., `Test.swift`)
- Other files in the same directory start with `{Namespace}.` (e.g., `Test.Case.swift`)

**Rationale**: LLMs understand code better when type definitions appear before extensions.

---

### [PKG-EXPORT-004] Exclusions

**Statement**: The following MUST be excluded from exports:

| Pattern | Reason |
|---------|--------|
| `.build/` | Build artifacts |
| `.git/` | Version control |
| `Package.resolved` | Lock file (dependencies, not source) |
| `.DS_Store` | macOS metadata |
| Files matching `.gitignore` | User-excluded files |

**Rationale**: These files add noise without value for code review.

---

## Output Location

### [PKG-EXPORT-005] Output Path

**Statement**: Exports MUST be written to `/tmp/` with these naming conventions:

| Export Type | Filename |
|-------------|----------|
| Sources only | `/tmp/{package-name}-sources.swift` |
| Tests only | `/tmp/{package-name}-tests.swift` |
| Combined | `/tmp/{package-name}-all.swift` |

**Rationale**: `/tmp/` is ephemeral and appropriate for exports intended for external sharing.

---

## Token Estimation

### [PKG-EXPORT-006] Token Warning

**Statement**: After export, you SHOULD report the estimated token count and MUST warn if it exceeds common context limits.

**Estimation formula**: `characters / 4` (approximate tokens for code)

**Warning thresholds**:

| Threshold | Warning |
|-----------|---------|
| > 32,000 tokens | "Exceeds ChatGPT Plus limit (32K). Consider splitting." |
| > 100,000 tokens | "Exceeds most model limits. Must split for any LLM." |

**Rationale**: Users need to know if their export will fit in the target LLM's context window.

---

## Execution Procedure

### [PKG-EXPORT-007] Export Procedure

**Statement**: When asked to export a package, follow this procedure:

**Step 1: Locate package**
```bash
# Find Package.swift to confirm package root
ls {path}/Package.swift
```

**Step 2: Read Package.swift**
```
Use Read tool on {path}/Package.swift
```

**Step 3: Generate file tree**
```bash
find {path}/Sources -name "*.swift" -type f | sort
```

**Step 4: Order files**
- Identify namespace roots (files where other files share their prefix)
- Sort: namespace roots first, then alphabetically

**Step 5: Read all source files**
```
Use Read tool on each file in order
```

**Step 6: Assemble output**
- Write to `/tmp/{package-name}-sources.swift`
- Use the format from [PKG-EXPORT-001]

**Step 7: Report**
- File path
- Character count
- Estimated tokens (chars / 4)
- Warning if > 32K tokens

**If tests requested** (Step 8):
```bash
find {path}/Tests -name "*.swift" -type f | sort
```
- Repeat steps 5-7 for tests using [PKG-EXPORT-002] format
- Output to `/tmp/{package-name}-tests.swift`

---

## Examples

### [PKG-EXPORT-008] Invocation Examples

**Export sources only** (default):
```
User: "export swift-test-primitives for chatgpt"
Claude: [Exports to /tmp/swift-test-primitives-sources.swift]
```

**Export with tests**:
```
User: "export swift-test-primitives with tests separate"
Claude: [Exports to /tmp/swift-test-primitives-sources.swift]
       [Exports to /tmp/swift-test-primitives-tests.swift]
```

**Export specific package by path**:
```
User: "export /Users/coen/Developer/swift-primitives/swift-buffer-primitives for llm"
Claude: [Exports to /tmp/swift-buffer-primitives-sources.swift]
```

---

## ChatGPT Context Limits Reference

### [PKG-EXPORT-009] Context Window Reference

**Statement**: For planning purposes, these are current ChatGPT context limits (as of 2025):

| Model | Context Window | Practical Limit |
|-------|----------------|-----------------|
| GPT-4 (Plus) | 32,000 tokens | ~128 KB code |
| GPT-4o | 128,000 tokens | ~512 KB code |
| GPT-5 (Plus) | 32,000 tokens | ~128 KB code |
| o3/o4-mini | 200,000 tokens | ~800 KB code |

**Note**: ChatGPT reserves ~750-900 tokens for system overhead.

**Rationale**: Understanding limits helps users decide whether to export entire packages or specific modules.

---

## Cross-References

- Research: `/Users/coen/Developer/swift-institute/Research/swift-package-export-for-llm.md`
- **swift-institute-core** skill for package locations
