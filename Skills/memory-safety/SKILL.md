---
name: memory-safety
description: |
  SUPERSEDED by **memory** skill.
  All MEM-SAFE-*, MEM-SEND-*, MEM-REF-*, MEM-LIFE-* rules are now in the memory skill.
  This skill remains for backwards compatibility only.

layer: implementation

superseded_by: memory

requires:
  - swift-institute

applies_to:
  - swift
  - swift6
  - primitives
---

# Memory Safety (SUPERSEDED)

**This skill has been superseded by the `memory` skill.** All rules — [MEM-SAFE-*], [MEM-SEND-*], [MEM-REF-*], [MEM-LIFE-*], [MEM-UNSAFE-*] — have been absorbed into that skill.

Use `/memory` instead of `/memory-safety`.
