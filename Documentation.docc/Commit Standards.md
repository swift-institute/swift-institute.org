# Commit Standards

<!--
---
title: Commit Standards
version: 1.0.0
last_updated: 2026-01-21
applies_to: [swift-primitives, swift-institute, swift-standards, swift-foundations, swift-components, swift-applications]
normative: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Standards for commit messages and commit organization in Swift Institute repositories.

## Overview

> This document answers: "What rules govern commit messages and commit organization in Swift Institute repositories?"

This document defines the commit standards for all Swift Institute packages. These standards ensure navigable git history, effective bisection, and clear communication of changes.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

**Applies to**: All commits to Swift Institute repositories.

**Does not apply to**: Squash-merged pull requests (where commit history is collapsed).

---

## [CONTRIB-007] Selective Staging for Focused Commits

**Scope**: Staging changes for commit.

**Statement**: Each commit MUST tell a single story. When a working directory contains unrelated changes, contributors MUST stage selectively to create focused commits.

**Correct**:
```bash
# Working directory has UUID addition + unrelated fixes
# Stage only the UUID-related files
git add Sources/Windows/Windows.Identity.UUID.swift
git add Tests/WindowsTests/UUIDTests.swift
git commit -m "Add native UUID parsing using Windows RPC"

# Remaining changes stay unstaged for a separate commit
```

**Incorrect**:
```bash
# Committing everything together
git add .
git commit -m "Add UUID parsing and fix various issues"
# Muddled story - git bisect becomes harder
```

Selective staging is documentation through git. Future readers (and bisectors) benefit from commits that change one thing.

**Rationale**: Focused commits create a navigable history. When debugging, `git bisect` works best when each commit represents a single logical change.

**Cross-references**: [CONTRIB-008]

---

## [CONTRIB-008] Commit Message Contracts

**Scope**: Commit message content.

**Statement**: Commit messages MUST name the mechanism (how) and MAY explain the motivation (why). Platform-specific commits MUST identify the platform API used.

**Correct**:
```bash
# Platform primitives: name the mechanism
git commit -m "Add native UUID parsing using Darwin's uuid_parse"
git commit -m "Add native UUID parsing using libuuid"
git commit -m "Add native UUID parsing using Windows RPC"

# Consumer packages: explain the motivation
git commit -m "Add native platform UUID parsing for near-Foundation performance"
```

**Incorrect**:
```bash
git commit -m "Add UUID support"
# Missing mechanism - if UUID has issues, where do you look?

git commit -m "Performance improvements"
# Missing specificity - what was improved?
```

| Package Type | Message Focus | Example |
|--------------|---------------|---------|
| Platform primitives | Mechanism (how) | "using Darwin's uuid_parse" |
| Standards/consumers | Motivation (why) | "for near-Foundation performance" |

**Rationale**: Mechanisms matter for debugging. If a platform has issues, the commit message tells maintainers exactly where to investigate.

**Cross-references**: [CONTRIB-007], [CONTRIB-009]

---

## [CONTRIB-009] Multi-Package Commit Ordering

**Scope**: Commits spanning multiple packages.

**Statement**: When committing related changes across multiple packages, commits SHOULD follow the dependency direction: primitives first, consumers last.

**Correct**:
```bash
# Platform primitives are independent peers - any order works
git commit -m "Add UUID parsing to Darwin primitives"
git commit -m "Add UUID parsing to Linux primitives"
git commit -m "Add UUID parsing to Windows primitives"

# Consumer depends on primitives - commit last
git commit -m "Integrate native UUID parsing in RFC 4122"
```

Platform primitives are architectural peers—they don't depend on each other. Standards packages depend on primitives but conditionally (builds succeed even if some primitives aren't committed yet). The primitives-first order matches the dependency graph.

**Rationale**: Following dependency order ensures the build remains valid at each commit point, supporting bisection and rollback.

**Cross-references**: [CONTRIB-007], [CONTRIB-008]. See also the Primitives Tiers documentation in swift-primitives.

---

## Topics

### Related Documents

- <doc:Contributor-Guidelines>
- <doc:API-Requirements>
