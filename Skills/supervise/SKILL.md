---
name: supervise
description: |
  Ongoing principal-agent oversight of subordinate work in Claude Code:
  ground-rules block, question-answering protocol, drift detection,
  termination criteria, escalation triggers.
  Apply when a principal agent dispatches work to a subordinate agent
  (sub-agent task or new session) and must remain engaged while it runs.

layer: process

requires:
  - swift-institute-core

applies_to:
  - agent-workflow
  - session-management

created: 2026-04-15
last_reviewed: 2026-04-15
---

# Supervise

Ongoing oversight of a subordinate agent's in-flight work. The principal
articulates scope, fields questions, catches drift, and decides when the
subordinate is done. Distinct from `/handoff`, which packages context for
a discrete transfer moment — `/supervise` governs the phase in between.

**Research**: `swift-institute/Research/agent-supervision-patterns.md`

---

## Mode Selection

### [SUPER-001] Invocation

**Statement**: The supervise skill MUST be invoked in either of two situations.

| Situation | Trigger |
|-----------|---------|
| Pre-dispatch | Principal is about to dispatch a subordinate (Task tool sub-agent, or a new-session subordinate via `/handoff`) |
| Mid-flight | Principal has already dispatched a subordinate and recognizes it now needs explicit oversight |

In both situations the procedure is the same: produce the ground-rules
block per [SUPER-002], then enter the runtime posture defined in the
end-to-end procedure per [SUPER-016].

**Sub-agent caveat**: Task-tool sub-agents return atomically — the
principal cannot intervene mid-execution, only pre-dispatch (ground rules
in the prompt) and post-return (review and re-dispatch). The
boundary-triggered intervention model in [SUPER-007] assumes a serial
new-session subordinate where each turn is a boundary; for sub-agents,
boundaries collapse to "before dispatch" and "after return."

**Cross-references**: [HANDOFF-001] (the discrete-transfer counterpart)

---

### [SUPER-001a] Distinguishing Supervise from Handoff

**Statement**: Supervision is ongoing; handoff is discrete. They compose, but they are not interchangeable.

| | `/handoff` | `/supervise` |
|---|---|---|
| Temporal shape | One moment | A phase |
| Author | Authoring agent (sequential, who MAY be departing or still running mid-session per [HANDOFF-009] progressive capture) or parent agent (branching) | Principal (still running) |
| Reader | New agent (cold start) | Principal itself, reviewing subordinate output |
| Artifact | `HANDOFF.md` — self-contained brief | Ground-rules block — re-injected into subordinate prompts |
| Paradox addressed | Departing agent's degraded recall | Subordinate's lack of shared context |
| Verification | New agent verifies before starting | Principal verifies at each intervention point |

**Composition**: A handoff MAY set up the conditions a supervisor then enforces. On re-handoff termination, [SUPER-011] governs how the ground-rules status is recorded in the resulting `HANDOFF.md`.

**Rationale**: Conflating the two produces either a handoff that depends on a still-living principal (broken when the session ends) or a supervisor that can only intervene after the fact (no in-flight oversight).

---

## Ground Rules Block

### [SUPER-002] Block Structure

**Statement**: Before the subordinate begins work, the principal MUST emit a *ground-rules block*. The block MUST contain 4–6 enumerated entries. Each entry MUST be one of four types.

| Type | Symbol | Use for |
|------|--------|---------|
| Required behavior | **MUST** | The subordinate is required to do this |
| Forbidden approach | **MUST NOT** | The subordinate is forbidden from doing this, especially when a plausible-looking document or pattern suggests otherwise |
| Scope fact | **fact:** | An architectural boundary, platform guard, or API contract that bounds what the subordinate can implement |
| Stop-and-ask | **ask:** | A specific condition under which the subordinate MUST escalate to the principal instead of deciding |

Longer than 6 entries: compress, or split the work into sub-phases each with its own block.

**Rationale**: 4–6 entries is the size at which the subordinate can hold the full block in working memory while writing each turn. Larger blocks become wallpaper and stop being checked.

---

### [SUPER-003] Mandatory Fields

**Statement**: The subordinate's task description MUST include four mandatory fields, separate from the ground-rules block.

| Field | Content |
|-------|---------|
| Objective | What the subordinate is producing — concrete, verifiable |
| Output format | What artifact, where (file path), what shape |
| Tools / sources | Which tools to use, which files/docs to read |
| Task boundaries | Explicit "do not touch" — files, packages, decisions out of scope |

**Rationale**: Anthropic's multi-agent research system identified vague subagent briefs ("research the semiconductor shortage") as the dominant cause of duplicated and off-mark subagent work. The four fields are the empirically-grounded fix. The ground-rules block (per [SUPER-002]) is the *constraint* layer; the four mandatory fields are the *task* layer.

---

### [SUPER-004] Rationale on Forbidden Entries

**Statement**: Every **MUST NOT** entry MUST include a one-line rationale. Bare prohibitions are forbidden.

Each entry is one line stating the rule, optionally followed by an indented `(why: …)` sub-field with the rationale. The sub-field is required on every **MUST NOT** entry; optional on the others.

**Correct**:
```
MUST NOT add shadow types to bridge ownership.
  (why: per memory feedback_language_features_over_custom_types — language semantics (borrowing/consuming/~Copyable) replace shadow types. Architecture v1.2 §4.A.0 suggests one; that note is superseded.)
```

**Incorrect**:
```
MUST NOT add shadow types.   ❌ no (why: …) sub-field
```

**Rationale**: A MUST NOT with no rationale will be broken the moment a plausible-looking document, research note, or alternative pattern suggests the forbidden approach is sensible. The rationale lets the subordinate recognize the rule's grounding and the principal recognize when the rule could legitimately stop applying.

---

## Runtime Posture

### [SUPER-005] Question Classification

**Statement**: When the subordinate asks a question, the principal MUST classify it before answering.

| Class | Test | Action |
|-------|------|--------|
| (a) Inside ground rules | The answer is in the block | Quote the rule and cite its entry number |
| (b) Inside principal's scope | Factual / technical question within the principal's authority | Answer cooperatively, then append the decision to the ground-rules block as a new entry |
| (c) Outside principal's authority | Would change the user's stated goal, relax a user-declared constraint, or commit resources outside the agreed task | Escalate to the user per [SUPER-012] |

The principal MUST NOT answer class (c) questions from first principles.

**Absentia degenerate case**: when no live principal exists (the principal's session has ended; the subordinate inherited the block via [HANDOFF-012]), class (b) questions re-classify per [SUPER-014a] — the subordinate MUST escalate to the user rather than self-author a new entry.

**Rationale**: Cooperative on facts, strict on scope. The principal's job is to be a useful technical resource for in-scope questions and a reliable boundary for out-of-scope ones. Mixing the two — being strict on facts or cooperative on scope changes — degrades both.

---

### [SUPER-006] Drift Signal Enumeration

**Statement**: The principal MUST enumerate drift signals up front and check each subordinate turn against the list.

**Default signals**:

| # | Signal | Action |
|---|--------|--------|
| 1 | Subordinate repeats itself across turns | Re-inject the relevant ground-rules entry |
| 2 | Subordinate re-proposes a previously rejected alternative | Quote the rejection back; require new evidence |
| 3 | Subordinate expands scope without asking | Reject the expansion; require an explicit `ask:` |
| 4 | Subordinate asks a question whose answer is in the ground-rules block | Quote the rule; do not re-answer |
| 5 | Subordinate modifies files outside the declared Task boundaries (per [SUPER-003]) | Halt; require revert before continuing |
| 6 | Subordinate makes a silent decision on an open question | Halt; require the decision to be surfaced and justified |
| 7 | Subordinate omits required tests / verification at a phase gate | Halt at the gate; do not allow handoff or termination |

The principal MAY add task-specific signals to this list at dispatch time.

**Rationale**: Magentic-One's Progress Ledger demonstrates that drift detection works only when the signals are enumerated and checked counter-style, not inferred ad hoc. Without an explicit list, the principal misses signals it has not pre-named.

---

### [SUPER-007] Boundary-Triggered Intervention

**Statement**: The principal MUST intervene only at *intervention points*. The principal MUST NOT continuously interrupt mid-turn work.

**Intervention points** (distinct from [SUPER-003]'s Task boundaries field, which names *scope*; this list names *temporal* checkpoints):
- Subordinate writes a file
- Subordinate asks a question
- Subordinate completes a declared phase / sub-phase
- Subordinate reports a result for review

Between intervention points, the principal does not interrupt — the subordinate is given the autonomy to execute. At an intervention point, the principal reviews against ground rules and acceptance criteria, then either accepts (subordinate continues), corrects (subordinate redoes with corrected guidance), or terminates (per [SUPER-009]).

**Sub-agent collapse** (per [SUPER-001] caveat): for Task-tool sub-agents the four-point list collapses to two points — *before dispatch* (review the prompt + ground-rules block) and *after return* (review the produced artifact). The middle three points (file write, question mid-run, phase completion mid-run) are inaccessible because sub-agents run to completion in one atomic call. Principals supervising sub-agents skip directly from "before dispatch" to "after return" with no intermediate intervention possible.

**Rationale**: Continuous intervention defeats the subordinate's autonomy and inflates context cost. Zero intervention defeats supervision. Boundary-triggered intervention is the productive middle: the subordinate runs freely between boundaries, the principal verifies at each one.

---

### [SUPER-008] No Takeover

**Statement**: The principal MUST NOT silently rewrite subordinate output. The principal MAY reject output and require the subordinate to redo it with corrected guidance.

**Correct**:
```
Principal: "Reject this Phase 3A diff. The Listener fd typing change
expands scope to iso-9945 — that wasn't in the dispatched task.
Either ask for an explicit scope expansion or pick a non-cross-package
solution. Re-do with corrected guidance."
```

**Incorrect**:
```
Principal silently edits the subordinate's files to fix the issue,
then continues without telling the subordinate why the edit happened.
```

**Rationale**: Silent rewrites destroy the subordinate's ability to learn from correction, produce two half-authored artifacts whose authorship is unclear, and erode the verification trail that supervision exists to preserve. Reject-and-redo preserves authorship and corrective signal.

---

## Termination

### [SUPER-009] Acceptance Criteria

**Statement**: The principal MUST declare acceptance criteria up front, alongside the ground-rules block. Supervision MUST NOT terminate until the principal has verified each criterion.

**Format**: Acceptance criteria are an enumerated checklist. Each criterion is testable from disk, git, or a build/test command — not from subordinate attestation alone.

**Three positive verification sources**: each criterion MUST resolve against at least one of the following, and the principal MUST name which source verifies each criterion:

| Source | What it proves | How the principal checks |
|--------|---------------|--------------------------|
| **Disk / git state** | Files exist (or are absent), paths resolve, commits landed | Read the current file contents, run `git status` / `git log` / `git diff`, list directories |
| **Build / test output** | Code compiles, tests pass, benchmarks hold | Run `swift build` / `swift test` / benchmark harnesses in the principal's own context and read the output |
| **Current file state** | A specific invariant holds at this moment (annotations applied, rule codified, cross-reference fixed) | Re-read the file the principal expects to have changed and verify the invariant without relying on the subordinate's diff summary |

**Example**:
```
Acceptance:
  1. swift test green on macOS for the new Listener events strategy.
     (verified via: build/test output — principal runs `swift test` locally)
  2. swift test green on Linux Docker for blocking + events + completions.
     (verified via: build/test output — principal runs Docker test in its own shell)
  3. No diffs to swift-kernel-primitives or swift-linux-standard.
     (verified via: disk/git state — `git diff --stat` on those packages)
  4. Phase 3A research note written at Research/sockets-phase-3-plan.md.
     (verified via: current file state — principal reads the file)
```

**Forbidden verification sources**:

| Source | Why forbidden |
|--------|---------------|
| Subordinate attestation ("I verified this") | Attestation is self-report, not verification; the principal's job is independent check |
| Principal assumption ("this must have worked because everything else did") | Assumption is inference, not evidence; structurally identical to attestation without the report |

**Rationale**: Subordinate "I'm done" reports are not acceptance. The handoff research's ATC read-back pattern applies here: the principal MUST verify against criteria the principal authored, not against the subordinate's self-report. Naming the positive source per criterion makes the verification step concrete — the principal cannot skip verification by inferring it happened. The three sources are exhaustive for code-bearing supervision; document-only supervision uses only the disk/git-state and current-file-state rows.

---

### [SUPER-010] Three-Way Termination

**Statement**: Supervision ends in exactly one of three ways.

| Mode | Trigger | Procedure |
|------|---------|-----------|
| **Success** | All acceptance criteria verified end-to-end | Report success, cite which criteria verified, end supervision |
| **Re-handoff** | Subordinate quality degrades, or work needs to continue in a fresh session | Invoke `/handoff` per [SUPER-011]; supervision ends when the handoff is written |
| **Escalation** | A scope question only the user can answer arises | Escalate per [SUPER-012]; supervision is paused until the user resolves |

The principal MUST NOT terminate by attrition (silently dropping supervision). Every termination MUST be one of these three modes, explicitly named.

---

### [SUPER-011] Re-Handoff Composition

**Statement**: When supervision terminates via re-handoff, the resulting `HANDOFF.md` Constraints section MUST cite the ground-rules block: which entries were verified, which were unverified at termination, and any new entries that emerged during execution.

**Pattern** (from the swift-io Phase 3 lived example, `HANDOFF.md:55`):
```
Supervisor constraints #1–#4: all verified end-to-end.
```

Or, on partial verification:
```
Supervisor constraints #1, #2, #4: verified.
#3 (Linux completions cell): blocked on toolchain regression — see
Open Question 1.
```

**Verification evidence per entry type**: the four entry types from [SUPER-002] need different evidence forms. The verification line above gives the *count*; a brief evidence phrase per entry MAY follow on the next line when the count alone is ambiguous.

| Entry type | What "verified" means | Evidence form |
|------------|----------------------|---------------|
| **MUST** | The required behavior was performed | Cite the file/test/diff that performed it |
| **MUST NOT** | The forbidden approach was not taken | Either *"not tempted"* (no situation arose) or *"tempted, refused"* (cite the moment + the alternative chosen) |
| **`fact:`** | The scope assertion still holds | Cite the artifact still observing the fact (e.g., `#if os(Linux)` guard at file:line) |
| **`ask:`** | No case arose where escalation was due but didn't happen | *"no triggering condition arose"* — implicit in completed work without unflagged decisions |

**Verification on success termination** (subordinate finishes inherited supervised work without re-handoff): per [HANDOFF-010] step 5, the subordinate MUST stamp the verification line in HANDOFF.md before triggering /reflect-session. Without this stamp [REFL-009] cannot distinguish "fresh dispatch, work not started" from "work done, verification omitted" and will leave the file indefinitely.

**Rationale**: The handoff inherits the supervisor's ground rules. A new principal picking up the handoff should know which constraints have been verified (and so MAY be relied on) versus which are still open. Without this citation the new principal cannot tell whether to re-verify or trust. Without entry-type-specific evidence forms, "verified" collapses to a checkbox with no audit trail.

**Cross-references**: [HANDOFF-002], [HANDOFF-009], [HANDOFF-010], [HANDOFF-012]

---

### [SUPER-012] Escalation Triggers

**Statement**: The principal MUST escalate to the user, rather than answer or decide, when ANY of these hold.

| Trigger | Example |
|---------|---------|
| Question would change the user's stated goal | "Should we drop the events strategy and ship blocking-only?" |
| Question would relax a user-declared constraint | "Can we depend on Foundation for this primitive?" |
| Question would commit resources outside the agreed task | "Should we also rewrite the kqueue backend while we're here?" |
| Subordinate identifies a constraint the user did not anticipate | "Acceptance criterion #3 conflicts with the typed throws migration on the IO type." |

**Format**: Escalation is one short message to the user containing (a) the question, (b) why the principal cannot answer it, (c) the options the principal sees, and (d) the principal's recommendation if any.

**Persistence requirement**: the principal MUST also record the escalated question in a persistent artifact before ending the principal's turn. This protects against the principal's session ending with an escalation outstanding (context overflow, user closes tab) — the un-persisted question would otherwise be lost.

| Situation | Persistence target |
|-----------|--------------------|
| HANDOFF.md exists at the working directory root | Append to its `## Open Questions` section, prefixed `[ESCALATED to user, awaiting answer]` |
| No HANDOFF.md exists | Create `HANDOFF-escalation-{slug}.md` per [HANDOFF-005] branching template; Issue section is the escalated question; Findings Destination is the user's eventual answer |
| Mid-flight supervision with an active block per [SUPER-014] | Annotate the block with a new `ask:` entry referencing the escalation, AND append to HANDOFF.md per the row above |

The supervisor block itself remains in its pre-escalation state — escalation pauses supervision per [SUPER-010] but does not re-author rules.

**Rationale**: Escalation is correct behavior, not failure. The principal is itself a delegate of the user; questions outside the principal's authority must be returned to the user. Answering from first principles in this case is exceeding authority, which is worse than pausing. The persistence requirement closes a real gap: without it, escalation is the only termination mode that produces no on-disk artifact, and a session that ends with an escalation outstanding loses the question entirely.

---

## Cross-Cutting Rules

### [SUPER-013] Re-Injection on Drift

**Statement**: When a drift signal per [SUPER-006] is detected, the principal MUST re-inject the violated ground-rules entry by quoting it back to the subordinate, citing the entry number.

**Correct**:
```
Drift: subordinate proposed adding Kernel.Socket.Descriptor.kernelDescriptor.
Re-inject: "Ground-rules entry #1 says: MUST NOT add shadow types to
bridge ownership (per feedback_language_features_over_custom_types).
The proposed property is a shadow type. Pick a language-semantics
solution (borrowing/consuming) or escalate to me with an explicit
request to revise entry #1."
```

**Incorrect**:
```
"Don't do that, do it differently."  ❌ no citation, no entry quoted
```

**Rationale**: Quoting the rule and citing its number turns drift correction from a personal exchange into a verifiable check against a shared artifact. The subordinate can re-read the cited entry; the principal can re-apply the same check next turn.

---

### [SUPER-014] Block Location

**Statement**: The ground-rules block MUST be stored in a location both principal and subordinate can re-read between turns.

| Subordinate type | Block location |
|-----------------|----------------|
| Sub-agent (Task tool) | Inside the dispatching prompt; one-shot, no re-injection possible (see [SUPER-001] sub-agent caveat) |
| New-session subordinate (post-`/handoff`) | At the top of the working file (`HANDOFF.md` Constraints, or a dedicated file referenced from the handoff) |
| Mid-flight (principal enters supervisory mode for an already-running subordinate) | If `HANDOFF.md` exists at the working directory root: append to its Constraints section. If no `HANDOFF.md` exists (e.g., the new-session subordinate started from a direct conversation with no handoff): create `HANDOFF.md` per [HANDOFF-002] or a topic-specific `HANDOFF-{topic}.md` per [HANDOFF-005] and embed the block in its Constraints section. Mid-flight is not applicable to sub-agents per [SUPER-001] caveat. |

**Rationale**: A block held only in conversation context is lost on session end and re-derivable only from memory. The block must be on disk or in the prompt for re-injection to be reliable.

---

### [SUPER-014a] Supervisor in Absentia

**Statement**: When the supervisor block exists on disk but no live principal is available — the principal's session has ended and the subordinate continues — the interaction model degrades to a *one-way constraint contract*. Existing entries remain binding; no new entries may be authored.

**Subordinate behavior in absentia** (overrides [SUPER-005] and [SUPER-015]):

| Class per [SUPER-005] | With live principal | In absentia |
|---|---|---|
| (a) Inside ground rules | Quote rule, cite entry | Same — subordinate self-quotes |
| (b) Inside principal's scope | Principal answers; appends to block per [SUPER-015] | Re-classify as (c) and escalate to user; the subordinate MUST NOT answer the question by appending a new entry to the block |
| (c) Outside principal's authority | Escalate per [SUPER-012] | Same |

**Pre-escalation check**: before re-classifying a (b) question as (c), the subordinate MUST first re-read the existing block to check whether the question is in fact answerable from an existing entry as class (a). Many "questions for the principal" turn out to be already-answered by an entry the subordinate hadn't connected to the immediate situation. Only when no class (a) match exists does the question escalate.

**Detection**: the subordinate is in absentia when (a) it inherited the block via [HANDOFF-012] from a prior session AND (b) no principal is currently live in the conversation. If a principal IS currently live (the user is acting as principal, or the same agent that authored the block is still running), normal [SUPER-005] applies — absentia is a degenerate case, not the default.

**Block remains a constraint contract**: all other supervise requirements continue to bind the subordinate. Drift detection per [SUPER-006] continues; verification per [HANDOFF-010] step 5 continues; re-handoff status per [SUPER-011] continues. Absentia restricts the *interaction model* (no live answers → no new entries), not the *constraint model* (existing entries are binding).

**Re-establishing live supervision**: when the user re-engages, the user MAY adopt the principal role and answer the queued (b)→(c) escalations. This re-instates live supervision per [SUPER-001]'s mid-flight invocation trigger; the queued questions become a backlog the new principal works through, appending answers to the block per [SUPER-015].

**Rationale**: a subordinate self-authoring constraints in absentia is structurally indistinguishable from drift — re-proposing rejected alternatives, expanding scope, silent decisions on open questions are all [SUPER-006] drift signals, and a subordinate adding new entries to its own constraint set replicates exactly that pattern. The escalation cost (one user-facing question instead of one autonomous answer) is acceptable in exchange for preserving the supervisor block's integrity. The pre-escalation check prevents trivial questions from cluttering the user's inbox when the existing block already answers them.

**Cross-references**: [SUPER-005], [SUPER-006], [SUPER-012], [SUPER-015], [HANDOFF-010], [HANDOFF-012]

---

### [SUPER-015] Progressive Refinement

**Statement**: When the principal answers a class (b) in-scope question per [SUPER-005], the principal MUST append the decision to the ground-rules block as a new entry, typed per [SUPER-002].

**Rationale**: An in-scope answer is a new constraint on the subordinate's remaining work. If it is not added to the block, the subordinate forgets it, the principal re-derives it, and the answer drifts across turns. Appending it freezes the decision and makes it citable for future drift checks.

**Compression on overflow**: when appending would push the block past the [SUPER-002] cap of 6 entries, the principal MUST either (a) compress — author a new entry that subsumes prior entries, annotated `(merges #N, #M)` so the supersession is traceable — or (b) split the work into sub-phases per [SUPER-002], each phase carrying its own block. Compression MUST NOT silently drop prior entries; supersession is named explicitly so a future principal reviewing the block can reconstruct the constraint history. The `(merges #N, #M)` notation is also the verification-status carrier per [SUPER-011]: a merged entry inherits the verification state of all entries it merges.

---

## Procedure

### [SUPER-016] End-to-End Procedure

**Statement**: The supervise skill MUST be applied via this procedure.

**Step 1 — Author the dispatch**:
- Write the four mandatory fields per [SUPER-003]: objective, output format, tools/sources, task boundaries
- Write the ground-rules block per [SUPER-002]: 4–6 typed entries, each MUST NOT carrying rationale per [SUPER-004]
- Write acceptance criteria per [SUPER-009]: testable from disk/git/build
- Place the block per [SUPER-014]

**Step 2 — Dispatch or attach**:
- **Pre-dispatch** (subordinate not yet running):
  - For sub-agents: call the Task tool with the dispatch (mandatory fields + ground-rules block) as the prompt
  - For new-session subordinates: invoke `/handoff` and embed the block in the handoff's Constraints section
- **Mid-flight** (subordinate already running, principal entering supervisory mode):
  - Write the ground-rules block to the location per [SUPER-014]
  - Re-inject the block as a prompt prefix on the principal's next message to the subordinate
  - Per [SUPER-009], state any acceptance criteria the subordinate has not yet been told about

**Step 3 — At each intervention point** (per [SUPER-007]: file write, question, phase completion, result report):
- Classify any question per [SUPER-005]
- Check the subordinate output against the drift signal list per [SUPER-006]
- If drift: re-inject per [SUPER-013]
- If in-scope decision made: append to the block per [SUPER-015]
- If acceptance criterion met: mark verified
- Decide: accept-and-continue, reject-and-redo (per [SUPER-008]), or terminate (per [SUPER-010])

**Step 4 — Terminate**:
- Verify each acceptance criterion per [SUPER-009]
- Pick the termination mode per [SUPER-010]
- If re-handoff: invoke `/handoff` per [SUPER-010] (which will follow [HANDOFF-002] for a fresh sequential handoff or [HANDOFF-009] for progressive update of an existing one), then cite ground-rules status in the resulting `HANDOFF.md` per [SUPER-011]
- If escalation: surface the question to the user per [SUPER-012], AND persist it per the [SUPER-012] persistence-target table
- If success: report verified criteria, stamp the verification line in `HANDOFF.md` per [SUPER-011] (so `[REFL-009]` can correctly classify the file), end supervision

---

## Cross-References

- **handoff** for [HANDOFF-*] discrete-transfer counterpart and `HANDOFF.md` template
- **research-process** for [RES-*] when supervision spawns a research investigation (the research itself is supervised work)
- **reflect-session** for [REFL-*] post-session reflection capture (supervisor lessons go into reflections, not into the ground-rules block)

The `/supervise` skill governs a posture; the `/handoff` skill governs an artifact. Use them together when the supervised work outlives a single session.
