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
last_reviewed: 2026-03-20
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

### [PKG-EXPORT-007] Script-Based Export

**Statement**: Use this single bash script for fast package exports:

```bash
#!/bin/bash
# Usage: export-package <package-path> [--with-tests]

PACKAGE_PATH="$1"
WITH_TESTS="$2"
PACKAGE_NAME=$(basename "$PACKAGE_PATH")
OUTPUT="/tmp/${PACKAGE_NAME}-sources.swift"

# Verify package exists
if [ ! -f "$PACKAGE_PATH/Package.swift" ]; then
    echo "Error: Package.swift not found at $PACKAGE_PATH" >&2
    exit 1
fi

# Function to sort files with namespace roots first
sort_with_roots() {
    local dir="$1"
    # Get all swift files
    find "$dir" -name "*.swift" -type f 2>/dev/null | while read -r file; do
        basename="${file##*/}"
        dirname="${file%/*}"
        # Check if this is a namespace root (other files start with its prefix)
        prefix="${basename%.swift}"
        if find "$dirname" -maxdepth 1 -name "${prefix}.*" -type f 2>/dev/null | grep -q .; then
            echo "0:$file"  # Root files sort first
        else
            echo "1:$file"  # Non-roots sort after
        fi
    done | sort -t: -k1,1 -k2,2 | cut -d: -f2
}

# Build sources export
{
    echo "# $PACKAGE_NAME"
    echo ""
    echo "## Package Manifest"
    echo ""
    cat "$PACKAGE_PATH/Package.swift"
    echo ""
    echo "## File Structure"
    echo ""
    find "$PACKAGE_PATH/Sources" -name "*.swift" -type f 2>/dev/null | sort
    echo ""
    echo "## Source Files"

    sort_with_roots "$PACKAGE_PATH/Sources" | while read -r file; do
        rel_path="${file#$PACKAGE_PATH/}"
        echo ""
        echo "### File: $rel_path"
        echo ""
        cat "$file"
    done
} > "$OUTPUT"

# Report
chars=$(wc -c < "$OUTPUT")
tokens=$((chars / 4))
echo "Exported: $OUTPUT"
echo "Size: $chars characters (~$tokens tokens)"

if [ $tokens -gt 100000 ]; then
    echo "⚠️  WARNING: Exceeds most model limits (100K). Must split."
elif [ $tokens -gt 32000 ]; then
    echo "⚠️  WARNING: Exceeds ChatGPT Plus limit (32K). Consider splitting."
fi

# Export tests if requested
if [ "$WITH_TESTS" = "--with-tests" ] && [ -d "$PACKAGE_PATH/Tests" ]; then
    TEST_OUTPUT="/tmp/${PACKAGE_NAME}-tests.swift"
    {
        echo "# $PACKAGE_NAME Tests"
        echo ""
        echo "## Test File Structure"
        echo ""
        find "$PACKAGE_PATH/Tests" -name "*.swift" -type f 2>/dev/null | sort
        echo ""
        echo "## Test Files"

        sort_with_roots "$PACKAGE_PATH/Tests" | while read -r file; do
            rel_path="${file#$PACKAGE_PATH/}"
            echo ""
            echo "### File: $rel_path"
            echo ""
            cat "$file"
        done
    } > "$TEST_OUTPUT"

    test_chars=$(wc -c < "$TEST_OUTPUT")
    test_tokens=$((test_chars / 4))
    echo "Exported: $TEST_OUTPUT"
    echo "Size: $test_chars characters (~$test_tokens tokens)"
fi
```

### [PKG-EXPORT-008] Quick Export Command

**Statement**: For immediate use, run this single command:

```bash
# Sources only
PKG="/path/to/package" && echo "# $(basename $PKG)" > /tmp/$(basename $PKG)-sources.swift && echo -e "\n## Package Manifest\n" >> /tmp/$(basename $PKG)-sources.swift && cat $PKG/Package.swift >> /tmp/$(basename $PKG)-sources.swift && echo -e "\n## Source Files" >> /tmp/$(basename $PKG)-sources.swift && find $PKG/Sources -name "*.swift" -type f | sort | while read f; do echo -e "\n### File: ${f#$PKG/}\n" >> /tmp/$(basename $PKG)-sources.swift && cat "$f" >> /tmp/$(basename $PKG)-sources.swift; done && wc -c /tmp/$(basename $PKG)-sources.swift
```

### [PKG-EXPORT-009] Claude Execution

**Statement**: When executing this skill, Claude MUST:

1. Run the quick export command via Bash tool (single invocation)
2. Report the output path and token estimate
3. Warn if tokens exceed thresholds

**Example invocation**:
```bash
DEV_ROOT="${DEV_ROOT:-${HOME}/Developer}" && \
PKG="${DEV_ROOT}/swift-primitives/swift-storage-primitives" && \
OUT="/tmp/$(basename $PKG)-sources.swift" && \
{ echo "# $(basename $PKG)"; \
  echo -e "\n## Package Manifest\n"; \
  cat "$PKG/Package.swift"; \
  echo -e "\n## Source Files"; \
  find "$PKG/Sources" -name "*.swift" -type f | sort | while read f; do \
    echo -e "\n### File: ${f#$PKG/}\n"; cat "$f"; \
  done; \
} > "$OUT" && \
chars=$(wc -c < "$OUT") && \
echo "Exported: $OUT ($chars chars, ~$((chars/4)) tokens)"
```

**Rationale**: Single bash invocation is 10-50x faster than multiple Read tool calls

---

## Examples

### [PKG-EXPORT-010] Invocation Examples

**Export sources only** (default):
```
User: "export swift-test-primitives for chatgpt"
Claude: [Runs single bash command, exports to /tmp/swift-test-primitives-sources.swift]
```

**Export with tests**:
```
User: "export swift-test-primitives with tests"
Claude: [Runs bash command for sources, then tests]
       [Exports to /tmp/swift-test-primitives-sources.swift]
       [Exports to /tmp/swift-test-primitives-tests.swift]
```

**Export specific package by path**:
```
User: "export swift-primitives/swift-buffer-primitives for llm"
Claude: [Exports to /tmp/swift-buffer-primitives-sources.swift]
```

---

## ChatGPT Context Limits Reference

### [PKG-EXPORT-011] Context Window Reference

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

- Research: `Research/swift-package-export-for-llm.md`
- **swift-institute-core** skill for package locations
