---
name: skill-creation
description: |
  Process for adding new skills to the Swift Institute ecosystem.
  Apply when creating a new skill or converting documentation to a skill.

layer: process

requires:
  - swift-institute-core

applies_to:
  - skills
  - documentation
  - swift-institute
---

# Skill Creation

Process for correctly adding new skills to the Swift Institute ecosystem. Covers planning, authoring, integration, and verification.

---

## Phase 1: Planning

### [SKILL-CREATE-001] Planning Requirements

**Statement**: Before creating a skill, you MUST determine: (1) the skill's purpose, (2) its layer, (3) its requirement ID prefix, and (4) its dependencies.

| Decision | Question | Output |
|----------|----------|--------|
| Purpose | What rules or process does this skill codify? | One-sentence summary |
| Layer | What category? | `meta`, `architecture`, `implementation`, or `process` |
| ID Prefix | What prefix for requirement IDs? | Unique prefix like `[SKILL-CREATE-*]` |
| Dependencies | What skills must be loaded first? | List for `requires:` field |

**Rationale**: Planning prevents mid-authoring rework and ensures the skill fits the ecosystem.

---

### [SKILL-CREATE-002] Layer Classification

**Statement**: Skills MUST be classified into exactly one layer based on their content.

| Layer | Description | Examples |
|-------|-------------|----------|
| `meta` | System manifest, skill loading order | `swift-institute-core` |
| `architecture` | Foundational conventions, layer rules | `swift-institute`, `primitives` |
| `implementation` | Code rules, API patterns | `naming`, `errors`, `memory`, `design` |
| `process` | Workflows, methodologies | `research-process`, `experiment-process`, `skill-creation` |

**Rationale**: Layer classification determines where the skill fits in the loading order and when it applies.

---

### [SKILL-CREATE-003] Requirement ID Assignment

**Statement**: Each skill MUST use a unique requirement ID prefix. IDs MUST follow the format `[PREFIX-NUMBER]` or `[PREFIX-SECTION-NUMBER]`.

**Existing prefixes** (DO NOT reuse):
- `API-NAME`, `API-ERR`, `API-IMPL`, `API-LAYER`, `API-DESIGN`
- `PATTERN-001–050`
- `MEM-COPY`, `MEM-OWN`, `MEM-LINEAR`, `MEM-SAFE`, `MEM-SEND`, `MEM-REF`, `MEM-LIFE`
- `PRIM-*`
- `COPY-FIX`, `COPY-REM`
- `ARCH-LAYER`
- `RES-*`, `EXP-*`, `BLOG-*`
- `SKILL-CREATE`

**Rationale**: Unique prefixes enable cross-references and prevent ID collisions.

---

### [SKILL-CREATE-004] Dependency Declaration

**Statement**: The `requires:` field MUST list all skills that must be loaded before this skill. At minimum, require `swift-institute-core` or `swift-institute`.

**Rules**:
- Dependencies form a DAG — no cycles allowed
- Only require skills that exist
- Require the most specific applicable skill (e.g., `naming` not `swift-institute` if naming rules are used)

**Verify no cycles**:
```
A requires B, B requires C ✓ (valid chain)
A requires B, B requires A ✗ (cycle)
```

**Rationale**: The `requires:` DAG determines skill loading order. Cycles would cause infinite loops.

---

## Phase 2: Authoring

### [SKILL-CREATE-005] SKILL.md Structure

**Statement**: A skill MUST be a single `SKILL.md` file in a directory matching the skill name. The file MUST contain YAML frontmatter followed by Markdown content.

**Directory structure**:
```
Skills/{skill-name}/
└── SKILL.md
```

**YAML frontmatter template**:
```yaml
---
name: {skill-name}
description: |
  {One-line summary of the skill's purpose.}
  {ALWAYS apply when... OR Apply when...}

layer: {meta|architecture|implementation|process}

requires:
  - {parent-skill}
  - {other-dependency}

applies_to:
  - {domain-tag}

migrated_from: {source-path}      # Optional
migration_date: YYYY-MM-DD        # Optional
---
```

**Required YAML fields**:
- `name`: Must match directory name, kebab-case
- `description`: Summary + invocation trigger (ALWAYS/Apply when)
- `layer`: One of the four layers
- `requires`: List of dependency skills
- `applies_to`: Domain tags that trigger invocation

**Markdown content structure**:
```markdown
# {Skill Title}

{Brief introduction paragraph.}

---

### [{ID-PREFIX}-001] {Requirement Title}

**Statement**: {The actual rule, using MUST/SHOULD/MAY language.}

{Code examples if applicable:}

**Correct**:
```swift
// Good example
```

**Incorrect**:
```swift
// Bad example  // ❌ Explanation
```

**Rationale**: {Why this rule exists.}

**Cross-references**: [{OTHER-ID}], **other-skill** skill

---

### [{ID-PREFIX}-002] {Next Requirement}
...
```

**Rationale**: Consistent structure enables machine parsing and human scanning.

---

### [SKILL-CREATE-006] Requirement Content

**Statement**: Each requirement section MUST include a Statement. SHOULD include code examples for implementation skills. SHOULD include Rationale. MAY include Cross-references.

| Component | Required | Purpose |
|-----------|----------|---------|
| Statement | MUST | The actual rule |
| Code examples | SHOULD (implementation layer) | Show correct/incorrect patterns |
| Rationale | SHOULD | Explain why |
| Cross-references | MAY | Link related requirements |

**Statement language**:
- `MUST` / `MUST NOT` — Absolute requirement
- `SHOULD` / `SHOULD NOT` — Strong recommendation
- `MAY` — Optional

**Rationale**: Complete requirements reduce ambiguity and enable consistent application.

---

## Phase 3: Integration

### [SKILL-CREATE-007] swift-institute-core Updates

**Statement**: After creating a skill, you MUST update `swift-institute-core/SKILL.md` to add the skill to the Skill Index section.

**Location**: `/Users/coen/Developer/swift-institute/Skills/swift-institute-core/SKILL.md`

**Add to Skill Index table**:
```markdown
| {skill-name} | {layer} | {brief description} | [{ID-PREFIX}-*] |
```

**If skill has dependents**, also update the Loading Order section to show where it fits in the DAG.

**Rationale**: The Skill Index is the canonical list of all skills. Unlisted skills may be overlooked.

---

### [SKILL-CREATE-008] CLAUDE.md Updates

**Statement**: After creating a skill, you MUST update relevant CLAUDE.md files to reference it.

**Files to update**:

1. **Workspace CLAUDE.md** (`/Users/coen/Developer/CLAUDE.md`):
   - Add row to Skill Routing table:
   ```markdown
   | {Task description} | **{skill-name}** | [{ID-PREFIX}-*] |
   ```

2. **Repo CLAUDE.md files** (if skill is mandatory for that repo):
   - Add to "Before Writing Code" section:
   ```markdown
   N. `{skill-name}` — {brief purpose}
   ```

**Which repos to update**:
- `swift-institute/CLAUDE.md` — if skill applies to documentation/research
- `swift-primitives/CLAUDE.md` — if skill applies to primitives development
- `swift-standards/CLAUDE.md` — if skill applies to standards development
- `swift-foundations/CLAUDE.md` — if skill applies to foundations development

**Rationale**: CLAUDE.md files drive mandatory skill invocation. Unlisted skills won't be automatically invoked.

---

## Phase 4: Sync and Verify

### [SKILL-CREATE-009] Sync Infrastructure

**Statement**: After creating a skill in swift-institute, you MUST run the sync script and verify symlinks.

**For institute-level skills**:
```bash
cd /Users/coen/Developer/swift-institute
./Scripts/sync-skills.sh
```

**Verify symlink created**:
```bash
ls -la /Users/coen/Developer/.claude/skills/{skill-name}
# Should show: {skill-name} -> /Users/coen/Developer/swift-institute/Skills/{skill-name}
```

**For self-managing repos** (swift-institute, swift-primitives, swift-foundations):
- Symlinks are tracked in git via relative paths
- After sync, commit the new symlink:
```bash
cd /Users/coen/Developer/swift-institute
git add .claude/skills/{skill-name}
git commit -m "Add {skill-name} skill"
```

**Rationale**: The sync script creates symlinks for skill discovery. Without symlinks, Claude Code won't find the skill.

---

### [SKILL-CREATE-010] Verification

**Statement**: After sync, you MUST verify the skill is discoverable and invocable.

**Verification checklist**:
- [ ] Symlink exists at `/Users/coen/Developer/.claude/skills/{skill-name}`
- [ ] Symlink resolves: `ls /Users/coen/Developer/.claude/skills/{skill-name}/SKILL.md`
- [ ] YAML is valid: no syntax errors when skill is loaded
- [ ] Skill appears in swift-institute-core Skill Index
- [ ] Skill Routing table updated in workspace CLAUDE.md

**Test invocation**:
```
User: "invoke the {skill-name} skill"
Claude: [Uses Skill tool with skill: "{skill-name}"]
```

**Rationale**: Verification catches integration errors before the skill is needed.

---

## Repository-Specific Skills

### [SKILL-CREATE-011] Repo-Specific Skill Pattern

**Statement**: Skills specific to one repository SHOULD live in that repository's `Skills/` directory, not in swift-institute.

**Pattern** (using `primitives` as example):

**Source location**:
```
/Users/coen/Developer/swift-primitives/Skills/primitives/SKILL.md
```

**Symlink target**:
```
/Users/coen/Developer/.claude/skills/primitives -> /Users/coen/Developer/swift-primitives/Skills/primitives
```

**YAML `applies_to`** should be specific:
```yaml
applies_to:
  - swift-primitives
```

**Discovery**: The sync script scans both `{repo}/Skills/*/` and `{repo}/swift-*/Skills/*/`, so repo-specific skills are discovered automatically.

**Rationale**: Repo-specific skills stay with their repo, reducing swift-institute scope and enabling repo-level evolution.

---

## Complete Checklist

### Creating a New Institute-Level Skill

- [ ] **Plan**: Determine purpose, layer, ID prefix, dependencies
- [ ] **Create directory**: `mkdir Skills/{skill-name}`
- [ ] **Author SKILL.md**: YAML frontmatter + Markdown content
- [ ] **Update swift-institute-core**: Add to Skill Index
- [ ] **Update workspace CLAUDE.md**: Add to Skill Routing table
- [ ] **Update repo CLAUDE.md files**: If skill is mandatory for any repo
- [ ] **Run sync**: `./Scripts/sync-skills.sh`
- [ ] **Commit symlink**: `git add .claude/skills/{skill-name}`
- [ ] **Verify**: Symlink resolves, skill invocable, index updated
- [ ] **Commit all changes**: Research, skill, CLAUDE.md updates

### Creating a Repo-Specific Skill

- [ ] **Plan**: Same as above
- [ ] **Create in repo**: `mkdir {repo}/Skills/{skill-name}`
- [ ] **Author SKILL.md**: Same structure, `applies_to` targets specific repo
- [ ] **Update swift-institute-core**: Add to Skill Index (even for repo-specific skills)
- [ ] **Update repo CLAUDE.md**: Add to that repo's "Before Writing Code"
- [ ] **Run sync**: Creates symlink automatically
- [ ] **Verify**: Symlink resolves

---

## Cross-References

- **swift-institute-core** skill for Skill Index and Loading Order
- **research-process** skill for [RES-006a] Documentation Promotion (skills are promoted documentation)
