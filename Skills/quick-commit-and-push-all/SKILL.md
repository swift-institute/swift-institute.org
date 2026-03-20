---
name: quick-commit-and-push-all
description: |
  Commit all changes and push every sub-repo across all Swift Institute and legal encoding
  directories to remote. Apply when the user wants to save progress across all repositories.

layer: process

requires:
  - swift-institute-core

applies_to:
  - swift-primitives
  - swift-standards
  - swift-ietf
  - swift-iso
  - swift-w3c
  - swift-whatwg
  - swift-ieee
  - swift-iec
  - swift-ecma
  - swift-incits
  - swift-foundations
  - swift-institute
  - rule-law
  - swift-nl-wetgever
last_reviewed: 2026-03-20
---

# Quick Commit and Push All

Commit all uncommitted changes in every git repository across Swift Institute and legal
encoding directories and push to remote. This is a quick "save everything" workflow —
not for crafting meaningful commit messages.

---

### [SAVE-001] Directory and Repository Structure

**Statement**: The skill MUST process repositories at two levels:

1. **Parent-level git repos** — The directory itself if it has a `.git` directory (not file).
2. **Sub-repos** — Each subdirectory that has a `.git` directory or `.git` file (submodule).

All directories are flat siblings under `/Users/coen/Developer/`.

The skill MUST iterate over these directories:

| # | Directory | Parent is git repo? | Sub-repo pattern |
|---|-----------|---------------------|------------------|
| 1 | `swift-primitives/` | Yes (standalone `.git/`) | `swift-*/` with standalone `.git/` directories |
| 2 | `swift-ietf/` | No | `swift-rfc-*/`, `swift-bcp-*/` with standalone `.git/` directories |
| 3 | `swift-iso/` | No | `swift-iso-*/` with standalone `.git/` directories |
| 4 | `swift-w3c/` | No | `swift-w3c-*/` with standalone `.git/` directories |
| 5 | `swift-whatwg/` | No | `swift-whatwg-*/` with standalone `.git/` directories |
| 6 | `swift-ieee/` | No | `swift-ieee-*/` with standalone `.git/` directories |
| 7 | `swift-iec/` | No | `swift-iec-*/` with standalone `.git/` directories |
| 8 | `swift-ecma/` | No | `swift-ecma-*/` with standalone `.git/` directories |
| 9 | `swift-incits/` | No | `swift-incits-*/` with standalone `.git/` directories |
| 10 | `swift-standards/` | No | `swift-*-standard/` with standalone `.git/` directories |
| 11 | `swift-foundations/` | Yes (standalone `.git/`) | `swift-*/` with submodule `.git` files |
| 12 | `swift-institute/` | Yes (standalone `.git/`) | No sub-repos |
| 13 | `swift-nl-wetgever/` | Yes (standalone `.git/`) | `*/` with standalone `.git/` directories (1057 statute packages) |
| 14 | `swift-us-nv-legislature/` | Yes (standalone `.git/`) | `*/` with standalone `.git/` directories (820 NRS packages) |
| 15 | `swift-law/` | Yes (standalone `.git/`) | Submodules to org-repos (not checked out locally) |
| 16 | `rule-law/` | Yes (standalone `.git/`) | `rule-*/` with standalone `.git/` directories |

**Statement**: For each directory, first process all sub-repos (`swift-*/`), then process the
parent repo (if it is a git repo). Parent must go last so submodule pointer updates are captured
in the parent commit.

**Statement**: Sub-directories without `.git` (directory or file) MUST be silently skipped.

**Rationale**: Standards body directories (swift-ietf, swift-iso, etc.) and swift-standards have no
parent git repo. Some sub-directories are not yet initialized as git repos. Processing sub-repos
before the parent ensures submodule pointer changes are included.

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

# All directories with sub-repos (standards body orgs + layer repos)
DIRS=(
  "swift-primitives"
  "swift-ietf"
  "swift-iso"
  "swift-w3c"
  "swift-whatwg"
  "swift-ieee"
  "swift-iec"
  "swift-ecma"
  "swift-incits"
  "swift-standards"
  "swift-foundations"
  "swift-nl-wetgever"
  "swift-us-nv-legislature"
  "rule-law"
)

# swift-law (org-of-orgs, no sub-repos to iterate)
cd /Users/coen/Developer/swift-law
if [ -n "$(git status --porcelain)" ]; then
  echo "COMMIT: swift-law"
  git add -A
  git commit -m "Save progress: $DATE"
  git push
fi

for parent_dir in "${DIRS[@]}"; do
  base="/Users/coen/Developer/$parent_dir"
  [ -d "$base" ] || continue
  for repo in "$base"/*/; do
    [ -d "$repo/.git" ] || [ -f "$repo/.git" ] || continue
    cd "$repo"
    if [ -n "$(git status --porcelain)" ]; then
      echo "COMMIT: $repo"
      git add -A
      git commit -m "Save progress: $DATE"
      git push
    fi
  done
  # Then handle parent if it has .git directory
  if [ -d "$base/.git" ]; then
    cd "$base"
    if [ -n "$(git status --porcelain)" ]; then
      echo "COMMIT: $base"
      git add -A
      git commit -m "Save progress: $DATE"
      git push
    fi
  fi
done

# swift-institute (no sub-repos)
cd /Users/coen/Developer/swift-institute
if [ -n "$(git status --porcelain)" ]; then
  echo "COMMIT: swift-institute"
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
