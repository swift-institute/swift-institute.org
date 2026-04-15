# Initial Public Alpha Readiness

<!--
---
version: 1.0.0
last_updated: 2026-04-14
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The swift-institute repository is being prepared for its first public release. A wholesale cleanup pass has removed legal references, local-path leaks, and internal-tooling artifacts. The repository has been committed and pushed to origin (currently private).

Before making the repository public, a readiness audit is needed to confirm that the contents match the expectations of an open-source project at initial alpha status — both the mechanical GitHub conventions and the substantive content a new visitor would seek.

**Trigger**: Pre-launch milestone (per [RES-012], package milestones are high-priority discovery triggers).

## Question

Does the swift-institute repository contain everything expected at initial public alpha launch, and what gaps should be closed before making it public?

## Analysis

### Scope

swift-institute as a meta-repository (documentation, conventions, research, experiments, blog) — not a consumable Swift package. The four Swift package layers it describes (swift-primitives, swift-standards, swift-foundations, and per-authority Layer 2 organizations) are out of scope for this audit — they will be evaluated separately as they approach public release.

### Decision inventory

Everything currently in the repository, grouped by category.

#### Root-level files

| File | Status | Notes |
|------|--------|-------|
| `README.md` | Present | Refreshed, matches swift-standards family convention |
| `LICENSE.md` | Present | Apache 2.0, 190 lines |
| `.gitignore` | Present | Fixed to whitelist `Blog/`, `Swift Evolution/`, `Documentation.docc/`, `Scripts/` |
| `.swift-format` | Present | Tooling config |
| `.swiftlint.yml` | Present | Tooling config |
| `.swift-version` | Present | Swift version pin |
| `CHANGELOG.md` | **Absent** | No versioned change history |
| `CONTRIBUTING.md` | **Absent at root** | Exists at `CONTRIBUTING.md` at root but GitHub's standard location is root |
| `CODE_OF_CONDUCT.md` | **Absent** | Standard for open-source; GitHub surfaces this |
| `SECURITY.md` | **Absent** | Standard for open-source; GitHub surfaces this |

#### .github/ infrastructure

| Item | Status | Notes |
|------|--------|-------|
| `FUNDING.yml` | Present | Points to GitHub Sponsors for `coenttb` |
| `dependabot.yml` | Present | Monthly Swift + GitHub Actions updates |
| `workflows/ci.yml` | Present | CI workflow |
| `workflows/swift-format.yml` | Present | Formatting check |
| `workflows/swiftlint.yml` | Present | Lint check |
| `profile/README.md` | Present, **near-empty** | Single line `# Swift Institute` — this is the org profile shown at github.com/swift-institute |
| `Swift Ecosystem Architecture/` | Empty directory | Likely stale placeholder |
| Issue templates | **Absent** | No `.github/ISSUE_TEMPLATE/` |
| Pull request template | **Absent** | No `.github/pull_request_template.md` |

#### Content directories

| Directory | Item count | Status |
|-----------|-----------:|--------|
| `Documentation.docc/` | 8 files | Refactored — human-facing, skill-free |
| `Skills/` | 31 skills | All reviewed within 25 days; healthy |
| `Research/` | 224 indexed entries | Bulk cleanup complete; see status breakdown below |
| `Experiments/` | 290 entries | Cleaned; paths and legal content removed |
| `Blog/Draft/` | 5 items | 2 final drafts (intro post, associated-type-trap), 3 typed-throws series drafts |
| `Blog/Published/` | 0 items | No published posts yet |
| `Blog/Series/` | 1 item | typed-throws series plan |
| `Swift Evolution/` | 1 draft | Directory structure established (Drafts, Pitches, Proposals, Accepted, Implemented, Declined) |
| `Scripts/` | 1 script | `ecosystem-timeline.sh` (portable) |

#### Research corpus status distribution

| Status | Count | Note |
|--------|------:|------|
| RECOMMENDATION | 61 | Complete, actionable |
| SUPERSEDED | 56 | Could be archived per [META-005] |
| DECISION | 49 | Complete, implemented |
| IN_PROGRESS | 21 | Work-in-progress — acceptable for a research corpus |
| COMPLETE | 12 | |
| INVENTORY, DEFERRED | 5 each | |
| Other (MOVED, IMPLEMENTED, DRAFT, FIX_IMPLEMENTED, TRANSCRIPT, ANALYSIS) | ~15 | Long tail of status values |
| `—` (em-dash / blank) | 4 | Ambiguous status — minor index cleanup needed |

#### Unusual / empty items

| Item | Status | Action |
|------|--------|--------|
| `.work-temp/` | Empty directory at root | Should be deleted |
| `.github/Swift Ecosystem Architecture/` | Empty directory | Should be deleted |
| `.DS_Store` files | Present in multiple dirs | Ignored by `.gitignore`, but visible on disk — harmless |

### Evaluation criteria

For an initial public alpha of an open-source project, common expectations include:

| Criterion | Source |
|-----------|--------|
| License declared | Universal OSS norm |
| README explains what it is | Universal OSS norm |
| Contribution pathway documented | GitHub community profile |
| Code of conduct | GitHub community profile |
| Security reporting | GitHub community profile |
| Issue/PR templates | GitHub community profile |
| CI / status signals | Modern OSS norm |
| Changelog / release notes | Semver-adjacent norm |
| Navigable documentation | Depends on project type |
| Non-stale artifacts | General hygiene |

### Evaluation

#### Strengths

- **Substantive content is in place.** Documentation.docc (8 files), Skills (31), Research (224 indexed, recently swept), Experiments (290), Swift Evolution structure.
- **License, README, CI workflows, dependabot** all present. Mechanical OSS baseline is met.
- **Skills all reviewed recently.** Review cadence is healthy; none are stale per the 90-day skill review convention.
- **Cleanup is thorough.** No `/Users/coen/` paths, no legal references, no embedded-tooling leaks.
- **Backup and recovery paths exist.** A local backup tarball and the latest commit at `origin/main` (`913d9c4`) both provide recovery options.

#### Gaps — blocking

The following gaps meaningfully reduce the quality of first-visitor impressions:

| Gap | Impact |
|-----|--------|
| **`.github/profile/README.md` is one line** | The GitHub org page at `github.com/swift-institute` would display a near-empty profile. First impression for anyone finding the org. |
| **No CODE_OF_CONDUCT.md** | GitHub's "Community Standards" tab flags this as missing. Standard OSS expectation. |
| **No SECURITY.md** | GitHub's Security tab has no vulnerability-reporting policy. Standard for any public repository. |
| **No CONTRIBUTING.md at root** | `CONTRIBUTING.md` at root exists and has the substance, but GitHub looks for root-level `CONTRIBUTING.md` and surfaces it in the "New PR" flow. A one-line root file pointing to the Documentation.docc version would close this. |

#### Gaps — nice-to-have

| Gap | Impact |
|-----|--------|
| No CHANGELOG.md | For a first release, an initial entry ("Initial public alpha release, YYYY-MM-DD") would anchor the timeline. |
| No issue templates | Reduces quality of bug reports / feature requests. Low priority pre-launch. |
| No PR template | Same as above. |
| `.work-temp/` empty dir | Minor hygiene — delete before launch. |
| `.github/Swift Ecosystem Architecture/` empty dir | Minor hygiene — delete before launch. |
| 56 SUPERSEDED research docs | Could be moved to `Research/_archived/` per [META-005]. Acceptable as-is — SUPERSEDED status is informative on its own. |
| 4 Research index rows with `—` / `Status` values | Minor `_index.md` cleanup; not visible damage. |
| 21 IN_PROGRESS research docs | Expected in a healthy research corpus. Flag for future triage if any pass the 42-day threshold per [META-001]. |

#### Unknowns

| Item | Why unknown |
|------|-------------|
| CI workflow health | Have not run the workflows in this audit. Worth verifying `.github/workflows/*.yml` actually works before public launch. |
| Blog publication plan | Blog/Published/ is empty. The two final drafts (intro + associated-type-trap) are ready; the publication decision is orthogonal to the repo being public. |
| Org-level vs repo-level positioning | The org profile README is more important than this repo's README for first-visitor impression. Should be addressed as a dedicated piece of writing. |

### Synthesis

The repository is substantively ready for public release. The cleanup pass has been thorough, the content is in place, and the mechanical OSS baseline (license, README, CI, dependabot, gitignore) is met.

Four gaps are blocking for a credible first impression: the near-empty org profile, missing CODE_OF_CONDUCT.md, missing SECURITY.md, and missing root-level CONTRIBUTING.md. These are low-effort to close — each is a short file following widely-used templates — but they materially affect how a new visitor reads the repository.

Seven gaps are nice-to-have: CHANGELOG, issue/PR templates, directory hygiene (two empty dirs), and small research-index cleanup. These can ship with the alpha or in a subsequent polish pass.

The IN_PROGRESS / SUPERSEDED status distribution in `Research/` is acceptable. A research corpus is expected to contain work in all lifecycle states; the SUPERSEDED entries are historical record.

## Outcome

**Status**: RECOMMENDATION

The repository is ready for public alpha release once the four blocking gaps are closed. Recommended sequence:

### Block 1 — Close gaps before Phase 5 reset (required)

1. **Rewrite `.github/profile/README.md`** — org profile README. Should be a concise introduction to the ecosystem, the "new visitor at github.com/swift-institute" document. Adapts content from the repo README.
2. **Add `CODE_OF_CONDUCT.md`** — Contributor Covenant 2.1 (standard).
3. **Add `SECURITY.md`** — How to report vulnerabilities. Can be a simple pointer document until a formal policy is needed.
4. **Add `CONTRIBUTING.md` at root** — Short file pointing to `CONTRIBUTING.md` at root for the substance, plus a one-line "by contributing you agree to the Code of Conduct."

### Block 2 — Optional polish (can ship or defer)

5. Add `CHANGELOG.md` with initial entry for the alpha release date.
6. Delete empty dirs: `.work-temp/`, `.github/Swift Ecosystem Architecture/`.
7. Clean up 4 ambiguous-status rows in `Research/_index.md`.
8. Run CI workflows once to verify they pass.

### Block 3 — Post-launch, iterative

9. Issue templates in `.github/ISSUE_TEMPLATE/`.
10. PR template in `.github/pull_request_template.md`.
11. Move SUPERSEDED research docs to `Research/_archived/` per [META-005] (when count exceeds 20 per the threshold).

## References

- [RES-012] Discovery Triggers — milestones as proactive research triggers
- [RES-013] Design Audit Methodology — systematic audit procedure
- [META-001], [META-005] — research corpus health
- GitHub Community Standards: https://docs.github.com/en/communities
- Contributor Covenant: https://www.contributor-covenant.org/
