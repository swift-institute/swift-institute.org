---
name: save-all
description: |
  Commit all changes and push all Swift Institute monorepos to remote.
  Apply when the user wants to save progress across repositories.

layer: process

requires:
  - swift-institute-core

applies_to:
  - swift-primitives
  - swift-standards
  - swift-foundations
  - swift-institute
---

# Save All

Commit all uncommitted changes across Swift Institute monorepos and push to remote.
This is a quick "save everything" workflow — not for crafting meaningful commit messages.

---

### [SAVE-001] Repository Scope

**Statement**: The skill MUST iterate over all four Swift Institute repositories in this order:

| # | Repository | Path |
|---|-----------|------|
| 1 | swift-primitives | `/Users/coen/Developer/swift-primitives/` |
| 2 | swift-standards | `/Users/coen/Developer/swift-standards/` |
| 3 | swift-foundations | `/Users/coen/Developer/swift-foundations/` |
| 4 | swift-institute | `/Users/coen/Developer/swift-institute/` |

**Statement**: Repositories with no uncommitted changes MUST be skipped with a note.

**Rationale**: Predictable ordering makes output easy to scan. Skipping clean repos avoids empty commits.

---

### [SAVE-002] Commit Procedure

**Statement**: For each repository with changes, you MUST:

1. Run `git add -A` to stage all changes (tracked and untracked).
2. Run `git status` to display what will be committed.
3. Create a single commit with the message format: `Save progress: <date>` where `<date>` is today's date in `YYYY-MM-DD` format.
4. Run `git push` to push to the remote tracking branch.

**Statement**: All changes in a repository MUST be committed in a single commit. Do NOT split changes into multiple commits.

**Statement**: Do NOT use `--force` or `--no-verify` flags.

**Rationale**: This is a bulk save operation. One commit per repo keeps history clean enough while being fast.

---

### [SAVE-003] Output Summary

**Statement**: After processing all repositories, you MUST print a summary table:

```
| Repository | Status | Commit | Pushed |
|-----------|--------|--------|--------|
| swift-primitives | 12 files changed | abc1234 | yes |
| swift-standards | clean | — | — |
| swift-foundations | 3 files changed | def5678 | yes |
| swift-institute | 1 file changed | 789abcd | yes |
```

**Rationale**: A summary table gives quick confirmation that everything was saved.
