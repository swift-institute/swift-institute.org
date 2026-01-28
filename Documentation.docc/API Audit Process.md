# API Audit Process

@Metadata {
    @TitleHeading("Swift Institute")
}

Process for systematically auditing package APIs against Swift Institute requirements.

## Overview

> This document answers: "How do I audit an existing package's API for compliance with Swift Institute requirements?"

This document defines the documentation-driven audit process for reviewing existing package APIs. The audit process ensures APIs are consistent, justified, and traceable to authoritative requirements.

**Normative language**: This document uses RFC 2119 conventions:
- **MUST** / **MUST NOT**: Absolute requirement or prohibition
- **SHOULD** / **SHOULD NOT**: Recommended unless valid reason exists
- **MAY**: Optional

**Applies to**: Review of existing packages for API compliance.

**Does not apply to**: Initial implementation (which should follow requirements from the start).

---

## Documentation-Driven API Audit

**Scope**: Systematic review of package APIs against Swift Institute requirements.

**Statement**: When auditing a package's API, contributors MUST follow a documentation-first process. The authoritative documentation determines correctness—not intuition or opinion.

### Audit Process

| Step | Action | Outcome |
|------|--------|---------|
| 1 | Read authoritative docs | Use CLAUDE.md routing table to find relevant requirements |
| 2 | Enumerate public API | List every public type, method, property |
| 3 | Check compliance | Does each symbol comply, violate, or add redundancy? |
| 4 | Research ambiguous cases | Web search for Swift Evolution guidance when docs don't cover |
| 5 | Apply changes systematically | Remove, rename, or gate as needed with explicit citations |
| 6 | Verify | Build and test |

**Correct**:
```text
Question: "Should we remove withSpan(_:)?"
Process: Check Memory Copyable.md -> mandates property-based access
         Check SE-0456 -> "Closure-taking API can be difficult to compose"
Result: Remove withSpan(_:), cite and SE-0456
```

**Incorrect**:
```text
Question: "Should we remove withSpan(_:)?"
Process: "It feels redundant to me"
Result: Remove without citation
# No audit trail; inconsistent decisions across packages
```

---

## Anti-Pattern: Intuition-First Changes

Starting with code changes based on intuition, then rationalizing afterward, produces inconsistent APIs. Some methods get removed because they "feel" redundant; others stay because they "seem" useful. No coherent principle.

Documentation-first inverts this:
1. **Principle comes first** - requirements define correctness
2. **Changes follow** - modifications implement the principle
3. **Citations prove** - "why was X removed?" has an answer

When someone asks "why was `withSpan` removed?", the answer is "[MEM-SPAN-001] and SE-0456 establish property-based access as canonical," not "I thought it was redundant."

---

## Audit Checklist

Use this checklist when auditing a package:

- [ ] Identify applicable requirement documents using CLAUDE.md routing table
- [ ] Read Overview and Scope sections of each requirement document
- [ ] List all public symbols in the package
- [ ] For each symbol, verify:
  - [ ] Naming follows [API-NAME-*] requirements
  - [ ] Error handling follows [API-ERR-*] requirements
  - [ ] Implementation follows [API-IMPL-*] requirements
  - [ ] Concurrency follows [API-CONC-*] requirements (if applicable)
- [ ] Document all violations with requirement citations
- [ ] Propose specific changes with rationale
- [ ] Build and test after changes

---

## Audit Report Template

```markdown
## API Audit Report: [Package Name]

### Audited Against
- API Requirements v[X.Y.Z]
- Memory Requirements v[X.Y.Z]
- [Other applicable documents]

### Findings

| Symbol | Status | Issue | Requirement | Recommended Action |
|--------|--------|-------|-------------|-------------------|
| `Foo.bar()` | Violation | Compound method name | | Rename to `Foo.bar.action()` |
| `Baz.Error` | Compliant | — | — | — |

### Summary
- Symbols audited: [N]
- Violations: [N]
- Warnings: [N]
- Compliant: [N]
```

**Rationale**: Documentation-driven audits produce consistent, justifiable API surfaces. The audit trail enables future maintainers to understand decisions without re-investigating.

---

## Topics

### Related Documents

- <doc:API-Requirements>
- <doc:Contributor-Guidelines>
- <doc:Ecosystem-Process>
