---
name: handoff
description: |
  Structured agent-to-agent handoff via file-based documents.
  Apply when handing off work to a new session or spinning off an investigation.

layer: process

requires:
  - swift-institute-core

applies_to:
  - agent-workflow
  - session-management

last_reviewed: 2026-04-15
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
- Output a copy-pastable instruction block per [HANDOFF-011]

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

### Supervisor Ground Rules
{Optional. Present when the handing-off agent invoked /supervise per
[HANDOFF-012]. Typed entries (MUST / MUST NOT / `fact:` / `ask:`) per
[SUPER-002]. The new agent treats these as binding constraints and
verifies each entry per [SUPER-011].}
```

**Heading-vs-prose convention**: the literal markdown heading is
`### Supervisor Ground Rules` (Title Case, no hyphen — matches the style
of the other top-level sections in this template). When referring to
the block in prose, the canonical form is *"supervisor ground-rules block"*
(hyphenated compound modifier). Cleanup tools (e.g., `[REFL-009]`) MUST
match the literal heading exactly when scanning HANDOFF.md.

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
- Output a copy-pastable instruction block per [HANDOFF-011]

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
5. If a `### Supervisor Ground Rules` sub-section is present in Constraints (per [HANDOFF-012]), treat its entries as binding constraints; verify each entry as work proceeds per the evidence-form table in [SUPER-011]; stamp a verification status line in HANDOFF.md before either (a) producing a re-handoff per [SUPER-011], (b) escalating per [SUPER-012], OR (c) successfully completing and triggering /reflect-session — the stamp is required on every termination path so [REFL-009] can correctly classify the file's disposition

**Rationale**: Verification prevents acting on stale context. Confirmation gives the user a chance to correct. The supervisor-block step ensures handoffs that carry ground-rules from a prior supervisory phase do not silently drop those constraints when the supervisor's session ends — the block becomes the supervisor in absentia.

---

### [HANDOFF-011] Copy-Pastable Resumption Prompt

**Statement**: Every handoff report MUST include an inline, copy-pastable instruction block that the user can paste directly into a new chat to resume work.

**Format**: Output a fenced code block (triple backticks) containing a self-contained prompt. The prompt MUST:

1. Tell the new agent to read the handoff file (with its absolute path)
2. Include a one-line summary of the goal
3. Direct the new agent to verify state and then continue from Next Steps (sequential) or investigate the Issue (branching)

**Sequential example**:
````
```
Read {absolute-path-to-HANDOFF.md} — it contains the full handoff context for continuing {brief task description}. Verify the current state (files exist, code compiles, git state matches), then proceed from the Next Steps section.
```
````

**Branching example**:
````
```
Read {absolute-path-to-HANDOFF-{topic-kebab}.md} — it contains a focused investigation brief on {issue description}. Read the full document, then investigate the Issue. Write findings where the Findings Destination section directs. Do not modify files listed under "Do Not Touch."
```
````

**Rationale**: Eliminates friction in the handoff — the user copies one block instead of manually composing instructions for the new agent.

---

### [HANDOFF-012] Supervisor Block (Optional)

**Statement**: When the handed-off work has non-obvious constraints the new agent must honor (architectural commitments, forbidden approaches, scope facts, stop-and-ask conditions), the handing-off agent SHOULD invoke `/supervise` first and embed the resulting typed ground-rules block in the HANDOFF.md `Constraints / ### Supervisor Ground Rules` sub-section per [HANDOFF-004].

**When to use**:

| Situation | Supervisor block? |
|-----------|-------------------|
| Sequential handoff continuing supervised work (per [SUPER-010] re-handoff termination) | **MUST** include the block, with verification status per [SUPER-011] |
| Sequential handoff with non-obvious architectural / strictness constraints | **SHOULD** include the block |
| Branching handoff of a focused investigation (per [HANDOFF-005]) | **MAY** include the block; investigation Scope often substitutes |
| Routine sequential handoff with no constraints beyond the obvious | **SHOULD NOT** include the block — empty supervisor blocks are noise |

**Procedure**: Invoke `/supervise` per [SUPER-002] to author the typed entries (4–6 entries each typed MUST / MUST NOT / `fact:` / `ask:`, with `(why: …)` sub-fields on every MUST NOT per [SUPER-004]). Place the block under `Constraints / ### Supervisor Ground Rules` per [HANDOFF-004]. The new agent picks up the block per [HANDOFF-010] step 5.

**Vocabulary**: /supervise calls the supervising agent the *principal* and the supervised agent the *subordinate* (defined in `[SUPER-001a]`). /handoff's older terms — *authoring agent*, *new agent* — are still used in the rest of this skill; a handing-off principal IS an authoring agent, and the new agent IS the subordinate during the supervised phase.

**Boundary terminology**: three terms refer to overlapping scope concepts: `## Constraints` (this template's section name), `## Do Not Touch` (the branching template's auto-populated section per [HANDOFF-005]), and `Task boundaries` (the field name in `[SUPER-003]`'s mandatory-fields table). They are not synonyms but they overlap:

| Term | Source | Content |
|------|--------|---------|
| `## Constraints` | [HANDOFF-004] sequential template | Non-obvious limitations + (optionally) `### Supervisor Ground Rules` sub-section |
| `## Do Not Touch` | [HANDOFF-005] branching template | Files with uncommitted changes (auto-populated from `git status`) |
| `Task boundaries` | [SUPER-003] mandatory-fields field | Files / packages / decisions out of scope for the dispatched task |

When embedding a supervisor block in a branching handoff, place it under a `## Constraints` section added to the branching template (a deliberate addition; the branching template doesn't have one by default).

**Supervisor in absentia**: After the handing-off agent's session ends, no live supervisor exists. The block plays the *ground-rules role* in the supervisor's absence — it is a one-way constraint contract, not a live supervisor. Per [SUPER-014a]: existing entries remain binding and the new agent self-verifies against them; class (b) questions that would normally be answered by a live principal re-classify as class (c) and escalate to the user rather than the subordinate self-authoring new entries; a future principal (or the user, on re-engagement) MAY resume active supervision by working through the queued escalations.

**Rationale**: Without an explicit handoff↔supervise composition, supervised work degrades on every session boundary — the new agent has no record of the prior supervisor's constraints. The block carries the constraints across the session boundary in a form designed to be re-verified.

**Cross-references**: [HANDOFF-004], [HANDOFF-010], [SUPER-002], [SUPER-011], [SUPER-014]

---

## Cross-References

- **research-process** for [RES-*] research that may produce handoff-worthy context
- **reflect-session** for [REFL-*] post-session reflections (complementary, not overlapping — reflections capture durable insights for memory; handoffs capture ephemeral task state for the next session)
- **supervise** for [SUPER-*] ongoing oversight while a subordinate works (per [HANDOFF-012], handoffs MAY embed a supervisor ground-rules block under Constraints; the in-flight oversight counterpart to this skill's discrete-transfer artifact)
