# Experiments

@Metadata {
    @TitleHeading("Swift Institute")
    @PageImage(purpose: card, source: "card-experiments", alt: "Experiments")
}

Runnable Swift packages that verify compiler and runtime behaviour — so claims are demonstrated, not asserted.

## Overview

Each experiment is a standalone Swift package that isolates one hypothesis — a compiler behaviour, a language constraint, an architectural approach — with a runnable build that readers can clone and verify. Multi-variant experiments encode related claims as separate targets within the same package.

Experiments are the ecosystem's receipts. When a blog post claims "the compiler rejects this pattern," the experiment proves it. When a research document says "approach A compiles but approach B does not," the experiment shows both.

## Where to browse

Ecosystem-wide experiments are published in [swift-institute/Experiments](https://github.com/swift-institute/Experiments). Each subdirectory is a standalone Swift package — clone the repository and run `swift build` (or `swift run`) inside the experiment of interest:

```
git clone https://github.com/swift-institute/Experiments.git
cd Experiments/{experiment-name}
swift build
```

Requires Swift 6.3 or newer.

Per-layer experiments live alongside the code they concern — in the `Experiments/` directory of each superrepo (primitives, standards, foundations).

## What gets an experiment

An experiment is created when a technical claim needs empirical verification — typically during design research, implementation work, or blog post drafting.

| Trigger | Example |
|---------|---------|
| Compiler behaviour claim | "Does `~Copyable` work with `ManagedBuffer` across module boundaries?" |
| Language constraint discovery | "Can `@MainActor` compile in Embedded Swift mode?" |
| Architectural verification | "Does the re-export chain produce the expected symbol visibility?" |
| Blog post evidence | "Back the claim about typed throws with a runnable package" |

## Result tagging

Each experiment records its outcome in the repository's index:

| Result | Meaning |
|--------|---------|
| CONFIRMED | The hypothesis holds |
| REFUTED | The hypothesis does not hold |
| SUPERSEDED | Replaced by a later experiment (e.g., compiler fix landed) |

## Relationship to other artifacts

Experiments verify *whether*. Research (see <doc:Research>) explains *why*. Code explains *what*. Blog posts link to experiments that back load-bearing claims, so readers can verify by running the code rather than trusting the prose.
