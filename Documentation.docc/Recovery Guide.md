# Recovering Deleted Files from .claude Cache

This guide explains how to recover accidentally deleted files using Claude Code's local cache at `~/.claude`.

## Overview

Claude Code maintains several caches that may contain file contents:

| Location | Contents |
|----------|----------|
| `~/.claude/file-history/` | Versioned snapshots of files read during sessions |
| `~/.claude/projects/*/tool-results/` | Cached outputs from tool invocations |
| `~/.claude/plans/` | Plan files that may reference or contain file content |
| `~/.claude/projects/*/session-memory/` | Session summaries with partial content |

## Recovery Strategy

### 1. Search for File References

First, find which cache locations contain references to your deleted files:

```bash
# Search for file path references
grep -rh "path/to/deleted" ~/.claude/ 2>/dev/null | head -20

# Search for document titles/headers
grep -rh "# Your Document Title" ~/.claude/ 2>/dev/null | head -20

# Search for unique content (rule IDs, function names, etc.)
grep -rh "UNIQUE-IDENTIFIER" ~/.claude/ 2>/dev/null | head -20
```

### 2. Check file-history (Best Source)

The `file-history` directory contains versioned snapshots with the actual file content:

```bash
# List all cached file versions (sorted by size, largest first)
find ~/.claude/file-history -name "*@v*" -size +5k -exec ls -la {} \; | sort -k5 -rn | head -30

# Search by document header
find ~/.claude/file-history -name "*@v*" -exec sh -c 'head -1 "$1" | grep -q "# Your Title" && echo "$1"' _ {} \;

# Search by content pattern
find ~/.claude/file-history -name "*@v*" -exec grep -l "unique pattern" {} \; 2>/dev/null
```

**Example from Research recovery:**
```bash
# Found ordinal-cardinal-foundations.md via:
grep -rh "Ordinal and Cardinal" ~/.claude/file-history/ 2>/dev/null

# Result: /Users/coen/.claude/file-history/dfa43cdc.../b79764e2ae1f5353@v1
```

### 3. Check tool-results (Second Best Source)

Tool results contain file contents that were read during sessions:

```bash
# Project directories use dashes instead of slashes:
# /Users/coen/Developer/swift-institute → -Users-coen-Developer-swift-institute

# Find tool-results with your content
grep -rl "unique pattern" ~/.claude/projects/-Users-*/*/tool-results/toolu_*.txt 2>/dev/null

# List tool-results by size (files are named toolu_*.txt)
find ~/.claude/projects -name "toolu_*.txt" -path "*/tool-results/*" -size +10k | head -20

# Search within a specific project's tool-results
ls ~/.claude/projects/-Users-coen-Developer-swift-institute/*/tool-results/
```

**Example from Research recovery:**
```bash
# Found Experiment.md via:
grep -l "EXP-002" ~/.claude/projects/*/tool-results/*.txt 2>/dev/null
```

### 4. Extract Content

File-history files have line number prefixes that need stripping:

```bash
# View format (notice the →)
head -5 /path/to/cached/file
#      1→# Document Title
#      2→
#      3→Content here

# Strip line numbers using awk
awk -F'→' '{print $NF}' "/path/to/cached/file" > /path/to/restored/file
```

Tool-results files (named `toolu_*.txt`) may have double line number prefixes:

```bash
# Double line-number format in tool-results:
#      1→     1→# Content
#      2→     2→
#      3→     3→More content

# The same awk command handles both formats:
awk -F'→' '{print $NF}' "/path/to/tool-result.txt" > /path/to/restored/file
```

### 5. Verify and Commit

```bash
# Check the restored content
head -20 /path/to/restored/file
wc -l /path/to/restored/file

# Commit if correct
git add /path/to/restored/file
git commit -m "Recover file.md from .claude cache"
git push
```

## Useful Search Patterns

### By Document Type

```bash
# Markdown documents with specific headers
find ~/.claude/file-history -name "*@v*" -exec sh -c \
  'head -1 "$1" | grep -qE "^# (Research|Experiment|API)" && echo "$1: $(head -1 "$1")"' _ {} \;

# Swift files
find ~/.claude/file-history -name "*@v*" -exec sh -c \
  'head -1 "$1" | grep -q "^import\|^public\|^struct\|^class" && echo "$1"' _ {} \;
```

### By Rule/ID References

```bash
# Find documents with rule IDs
grep -rh "RES-0[0-9][0-9]" ~/.claude/plans/*.md 2>/dev/null | sort -u
grep -rh "EXP-0[0-9][0-9]" ~/.claude/ 2>/dev/null | sort -u
grep -rh "API-NAME-" ~/.claude/ 2>/dev/null | sort -u
```

### By Directory Structure

```bash
# Find references to specific directories
grep -rh "swift-institute/Research/" ~/.claude/ 2>/dev/null | grep -oE "Research/[a-z][a-z0-9-]*\.md" | sort -u
grep -rh "swift-institute/Experiments/" ~/.claude/ 2>/dev/null | grep -oE "Experiments/[a-z][a-z0-9-]*" | sort -u
```

## Session-Specific Searches

If you know approximately when the file was last read:

```bash
# List sessions by modification time
ls -lt ~/.claude/file-history/

# Search within a specific session
grep -r "pattern" ~/.claude/file-history/SESSION-UUID/
```

## What Cannot Be Recovered

- Files never read by Claude Code
- Files read in sessions older than cache retention
- Files only mentioned but never opened
- Content that was only in working memory (not persisted)

## Prevention

1. **Use git**: Commit early and often
2. **Remote backup**: Push to remote repositories
3. **Time Machine**: macOS automatic backups catch most deletions
4. **Don't delete directories**: Move to trash instead of `rm -rf`

## Recovery Checklist

- [ ] Search file-history for exact file name
- [ ] Search file-history for document title/header
- [ ] Search tool-results for unique content patterns
- [ ] Search plans for file references
- [ ] Check session-memory for partial content
- [ ] Strip line number prefixes when extracting
- [ ] Verify content integrity before committing
- [ ] Update any index files (_index.md)
