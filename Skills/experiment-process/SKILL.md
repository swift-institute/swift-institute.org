---
name: experiment-process
description: |
  Experiment workflows: hypothesis, validation, documentation.
  Apply when testing implementation approaches or validating designs.

layer: process

requires:
  - swift-institute

applies_to:
  - experiments
  - validation

migrated_from: Experiments/Experiment.md
migration_date: 2026-01-28
---

# Experiment Process

Workflows for conducting implementation experiments.

---

## Experiment Types

### Investigation (Reactive)

Triggered by:
- Build failure
- Test failure
- Unexpected behavior

### Discovery (Proactive)

Triggered by:
- New feature design
- Performance optimization
- API exploration

---

## Experiment Structure

```
Experiments/
└── {experiment-name}/
    ├── README.md           # Hypothesis and results
    ├── Package.swift       # Minimal reproduction
    └── Sources/
        └── main.swift      # Test code
```

---

## Experiment Document Template

```markdown
# Experiment: [Name]

## Hypothesis
What we expect to observe.

## Setup
How to reproduce.

## Results
What we observed.

## Conclusion
What we learned.

## Next Steps
Follow-up actions.
```

---

## Cross-References

See also:
- **research-process** skill for design research
