# Experiments

@Metadata {
    @TitleHeading("Swift Institute")
}

Runnable Swift packages that verify compiler and runtime behaviour — so claims are demonstrated, not asserted.

## Overview

Every repository in the ecosystem contains an `Experiments/` directory at its root. Each experiment is a standalone Swift package that isolates one hypothesis — a compiler behaviour, a language constraint, an architectural approach — with a runnable build that readers can clone and verify.

Experiments are the ecosystem's receipts. When a blog post claims "the compiler rejects this pattern," the experiment proves it. When a research document says "approach A compiles but approach B does not," the experiment shows both.

---

## When experiments are created

An experiment is created when a technical claim needs empirical verification — typically during design research, implementation work, or blog post drafting.

| Trigger | Example |
|---------|---------|
| Compiler behaviour claim | "Does `~Copyable` work with `ManagedBuffer` across module boundaries?" |
| Language constraint discovery | "Can `@MainActor` compile in Embedded Swift mode?" |
| Architectural verification | "Does the re-export chain produce the expected symbol visibility?" |
| Blog post evidence | "Back the claim about typed throws with a runnable package" |

---

## Structure

Each experiment is a Swift package with a descriptive name. Multi-variant experiments encode related claims as separate targets — one hypothesis per variant.

```
Experiments/
├── noncopyable-sequence-emit-module-bug/
│   ├── Package.swift
│   └── Sources/
├── property-view-class-accessor/
│   ├── Package.swift
│   └── Sources/
└── ownership-overloading-limitation/
    ├── Package.swift
    └── Sources/
```

Each experiment records its result:

| Result | Meaning |
|--------|---------|
| CONFIRMED | The hypothesis holds |
| REFUTED | The hypothesis does not hold |
| SUPERSEDED | Replaced by a later experiment (e.g., compiler fix landed) |

---

## Where experiments live

Like research, experiments live at the root of the repository they concern:

| Scope | Location |
|-------|----------|
| Ecosystem-wide | `swift-institute/Experiments/` |
| Primitives-specific | `swift-primitives/Experiments/` |
| Standards-specific | `swift-standards/Experiments/` |
| Foundations-specific | `swift-foundations/Experiments/` |

---

## Relationship to other artifacts

Experiments verify *whether*. Research (see <doc:Research>) explains *why*. Code explains *what*.

Blog posts link to experiments that back load-bearing claims, so readers can verify by running the code. A claim without a linked experiment is an assertion; a claim with one is a demonstration.
