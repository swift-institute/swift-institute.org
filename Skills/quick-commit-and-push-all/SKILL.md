---
name: quick-commit-and-push-all
description: |
  Commit all changes and push every sub-repo across all Swift Institute directories to remote.
  Apply when the user wants to save progress across all repositories.

layer: process

requires:
  - swift-institute-core

applies_to:
  - swift-primitives
  - swift-standards
  - swift-foundations
  - swift-institute
---

# Quick Commit and Push All

Commit all uncommitted changes in every git repository across Swift Institute directories
and push to remote. This is a quick "save everything" workflow — not for crafting meaningful
commit messages.

---

### [SAVE-001] Directory and Repository Structure

**Statement**: The skill MUST process repositories at two levels:

1. **Parent-level git repos** — The directory itself if it has a `.git` directory (not file).
2. **Sub-repos** — Each `swift-*/` subdirectory that has a `.git` directory or `.git` file (submodule).

The skill MUST iterate over these directories:

| # | Directory | Parent is git repo? | Sub-repo pattern |
|---|-----------|---------------------|------------------|
| 1 | `/Users/coen/Developer/swift-primitives/` | Yes (standalone `.git/`) | `swift-*/` with standalone `.git/` directories |
| 2 | `/Users/coen/Developer/swift-standards/` | **No** (no `.git` at all) | `swift-*/` with standalone `.git/` directories |
| 3 | `/Users/coen/Developer/swift-foundations/` | Yes (standalone `.git/`) | `swift-*/` with submodule `.git` files |
| 4 | `/Users/coen/Developer/swift-institute/` | Yes (standalone `.git/`) | No sub-repos |

**Statement**: For each directory, first process all sub-repos (`swift-*/`), then process the
parent repo (if it is a git repo). Parent must go last so submodule pointer updates are captured
in the parent commit.

**Statement**: Sub-directories without `.git` (directory or file) MUST be silently skipped.

**Rationale**: swift-standards has no parent git repo. Some sub-directories are not yet initialized
as git repos. Processing sub-repos before the parent ensures submodule pointer changes are included.

---

### [SAVE-002] Commit and Push Procedure

**Statement**: Use a shell script approach. For each git repository with uncommitted changes, you MUST:

1. `git add -A` to stage all changes (tracked and untracked).
2. `git commit -m "Save progress: <date>"` where `<date>` is today's date in `YYYY-MM-DD` format.
3. `git push` to push to the remote tracking branch.

**Statement**: Repositories with no uncommitted changes (clean working tree) MUST be skipped silently.

**Statement**: Do NOT use `--force` or `--no-verify` flags.

**Statement**: To process efficiently, use a single bash script that iterates over all directories
rather than making individual tool calls per repo. This avoids hundreds of sequential tool calls.

Example script structure:

```bash
DATE=$(date +%Y-%m-%d)
DIRS=("swift-primitives" "swift-standards" "swift-foundations")

for parent_dir in "${DIRS[@]}"; do
  base="/Users/coen/Developer/$parent_dir"
  for repo in "$base"/swift-*/; do
    [ -d "$repo/.git" ] || [ -f "$repo/.git" ] || continue
    cd "$repo"
    if [ -n "$(git status --porcelain)" ]; then
      git add -A
      git commit -m "Save progress: $DATE"
      git push
    fi
  done
  # Then handle parent if it has .git directory
  if [ -d "$base/.git" ]; then
    cd "$base"
    if [ -n "$(git status --porcelain)" ]; then
      git add -A
      git commit -m "Save progress: $DATE"
      git push
    fi
  fi
done

# swift-institute (no sub-repos)
cd /Users/coen/Developer/swift-institute
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "Save progress: $DATE"
  git push
fi
```

**Rationale**: A single script is far more efficient than ~200 individual tool calls.

---

### [SAVE-003] Output Summary

**Statement**: After the script completes, you MUST report which repos had changes committed
and which were clean. A brief summary is sufficient — no need to list every clean repo.

**Rationale**: The user needs confirmation that everything was saved, but doesn't need to see
120+ "clean" lines.
