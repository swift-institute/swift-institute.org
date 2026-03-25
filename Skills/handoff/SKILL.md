---
name: handoff
description: |
  Structured agent-to-agent handoff via file-based documents.
  Apply when handing off work to a new session or spinning off an investigation.

layer: process

requires: []

applies_to:
  - agent-workflow
  - session-management
---

# Handoff

Structured agent-to-agent handoff via file-based documents. Two modes:
sequential (continue work in a new session) and branching (spin off a
focused investigation while the current session continues).

**Research**: `swift-institute/Research/agent-handoff-patterns.md`

---

## Mode Selection

### [HANDOFF-001] Invocation

**Statement**: The handoff skill MUST select mode based on arguments.

| Invocation | Mode | Output File |
|------------|------|-------------|
| `/handoff` | Sequential | `HANDOFF.md` |
| `/handoff` with no prior HANDOFF.md | Sequential (initial) | `HANDOFF.md` |
| `/handoff` with existing HANDOFF.md | Sequential (update) | `HANDOFF.md` (updated in place) |
| `/handoff investigate {topic}` | Branching | `HANDOFF-{topic-kebab}.md` |

The ARGUMENTS string is available after skill loading. Parse it:
- Empty or absent: sequential mode
- Starts with `investigate `: branching mode, remainder is the topic

---

## Sequential Handoff

### [HANDOFF-002] Sequential Procedure

**Statement**: Sequential handoff MUST follow this procedure.

**Step 1 — Gather facts** (tool-assisted, not from memory):
```bash
git diff --stat          # what files changed
git status -s            # untracked and staged files
```

**Step 2 — Check for existing handoff**:
- If `HANDOFF.md` exists at working directory root, read it (this is an update per [HANDOFF-009])
- If not, create from scratch

**Step 3 — Fill template** per [HANDOFF-004]:
- Fill mandatory sections from conversation context
- Auto-populate Changed Files from git output
- Include conditional sections only when they have content
- Respect token budget per [HANDOFF-007]

**Step 4 — Write file**:
- Write `HANDOFF.md` to working directory root

**Step 5 — Report**:
- Tell the user the file path
- Suggest: "To resume in a new session, tell the agent to read HANDOFF.md"

---

### [HANDOFF-004] Sequential Template

**Statement**: Sequential handoff documents MUST use this structure.

**Mandatory sections**: Goal, Current State, Next Steps
**Auto-populated**: Changed Files
**Conditional** (omit if empty): Key Decisions, Dead Ends, Open Questions, Constraints

```markdown
# Handoff: {Brief Task Description}

> To resume: read this file and verify the current state before proceeding.
> Ask if anything is unclear.

## Goal
{The user's original intent — what we're trying to achieve and why}

## Current State
{What has been accomplished. Build/test status. What works, what doesn't yet.}

## Key Decisions
{Each: one-line decision + one-line rationale. Most important first.
Include rejected alternatives to prevent retreading.}

## Dead Ends
{Each: what was tried + why it failed. Prevents the new agent from repeating.}

## Changed Files
{Auto-populated from git. One line per file: path — what changed.}

## Open Questions
{Unresolved issues. Ambiguities needing user input.}

## Next Steps
{Prioritized, actionable items. Numbered. Specific enough to act on.}

## Constraints
{Non-obvious limitations: compiler bugs, API gaps, performance bounds, etc.}
```

**Section ordering rationale** (from "lost in the middle" research):
- Goal at the top — establishes context in the highest-attention position
- Next Steps at the bottom — action items in the second-highest-attention position
- Background in the middle — the new agent reads it but doesn't need to recall it verbatim

---

## Branching Handoff

### [HANDOFF-003] Branching Procedure

**Statement**: Branching handoff MUST follow this procedure.

**Step 1 — Gather conflict boundaries**:
```bash
git status -s            # files with uncommitted changes → Do Not Touch
```

**Step 2 — Fill template** per [HANDOFF-005]:
- Focus exclusively on the investigation topic
- Auto-populate Do Not Touch from git output
- Keep tight — the investigation agent needs a brief, not a novel

**Step 3 — Write file**:
- Convert topic to kebab-case
- Write `HANDOFF-{topic-kebab}.md` to working directory root

**Step 4 — Report**:
- Tell the user the file path
- Suggest: "Point the new session to HANDOFF-{topic-kebab}.md"

---

### [HANDOFF-005] Branching Template

**Statement**: Branching handoff documents MUST use this structure. All sections are mandatory.

```markdown
# Investigation: {Issue Description}

> To investigate: read this file for full context. The parent conversation
> is continuing separate work — avoid modifying files under "Do Not Touch."

## Issue
{What was observed, where, why it matters — specific and actionable}

## Parent Context
{What the parent conversation is doing — just enough to understand
how this issue relates. Not the full task.}

## Relevant Files
{Files related to the issue — with line numbers where possible}

## Do Not Touch
{Auto-populated: files with uncommitted changes in git.
The investigation MUST NOT modify these to avoid merge conflicts.}

## Scope
{What to investigate. Explicit boundaries: what NOT to change or explore.}

## Findings Destination
{Where to write results. Default: append a "## Findings" section to this file.}
```

---

## Shared Rules

### [HANDOFF-006] Auto-Population

**Statement**: Factual sections MUST be populated from tools, not agent memory.

| Section | Source |
|---------|--------|
| Changed Files (sequential) | `git diff --stat` + `git status -s` |
| Do Not Touch (branching) | `git status -s` (files with uncommitted changes) |

**Rationale**: The handoff paradox — the agent writing the handoff may have degraded recall. Git is ground truth.

---

### [HANDOFF-007] Token Budget

**Statement**: Handoff documents MUST be concise. They replace thousands of tokens of conversation with a compressed summary.

| Mode | Target | Maximum |
|------|--------|---------|
| Sequential | 500–1500 tokens | 2000 tokens |
| Branching | 200–500 tokens | 800 tokens |

**Compression rules**:
- One line per changed file, not paragraphs
- Decisions: the decision + one-line rationale, not the full deliberation
- Reference files by path instead of inlining their content
- If any section exceeds 5 lines, compress further or split into a referenced file

**Rationale**: A bloated handoff consumes the new session's context, accelerating the next degradation cycle.

---

### [HANDOFF-008] File Location and Naming

**Statement**: Handoff files MUST be written to the working directory root.

| Mode | Filename | Example |
|------|----------|---------|
| Sequential | `HANDOFF.md` | `HANDOFF.md` |
| Branching | `HANDOFF-{topic}.md` | `HANDOFF-sendable-conformance.md` |

- Multiple branch handoffs MAY coexist
- Sequential and branching are independent — `/handoff investigate` does not affect `HANDOFF.md`
- Uppercase signals "read me" to both humans and agents

---

### [HANDOFF-009] Progressive Capture

**Statement**: When `HANDOFF.md` already exists, `/handoff` MUST update it in place rather than overwriting from scratch.

**Update rules**:
1. Preserve Goal (unless the user changed direction)
2. Update Current State to reflect progress since last checkpoint
3. Append new decisions and dead ends (don't remove prior entries unless resolved)
4. Re-run git commands for Changed Files (full refresh)
5. Update Next Steps: remove completed items, add new ones

**Rationale**: Progressive capture solves the handoff paradox — important context is captured while the agent is still sharp, not during final degradation. Invoke `/handoff` at natural milestones.

---

### [HANDOFF-010] Resume Protocol

**Statement**: Every handoff document MUST include a resume blockquote at the top (included in both templates). When a new agent reads a handoff, it SHOULD:

1. Read the full document
2. Verify: do listed files exist? Does the code compile? Does git state match?
3. Confirm understanding to the user before starting work
4. Begin from Next Steps (sequential) or investigate the Issue (branching)

**Rationale**: Verification prevents acting on stale context. Confirmation gives the user a chance to correct.

---

## Cross-References

- **research-process** for [RES-*] research that may produce handoff-worthy context
- **reflect-session** for [REFL-*] post-session reflections (complementary, not overlapping — reflections capture durable insights for memory; handoffs capture ephemeral task state for the next session)
