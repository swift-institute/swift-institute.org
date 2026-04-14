# Contributing

@Metadata {
    @TitleHeading("Swift Institute")
}

How to contribute to the Swift Institute ecosystem.

## Where the rules live

The canonical source for development conventions is the [`Skills/`](https://github.com/swift-institute/swift-institute/tree/main/Skills) directory in this repository. Each skill is a self-contained specification for one area — naming, error handling, memory safety, testing, modularization, and so on. When you write code inside the ecosystem, the skills are the reference.

Key skill areas relevant to contributors:

| Skill | What it covers |
|-------|---------------|
| [`code-surface`](https://github.com/swift-institute/swift-institute/tree/main/Skills/code-surface) | Type naming, error handling, file structure |
| [`implementation`](https://github.com/swift-institute/swift-institute/tree/main/Skills/implementation) | Expression-first code style, intent over mechanism |
| [`memory-safety`](https://github.com/swift-institute/swift-institute/tree/main/Skills/memory-safety) | Ownership, copyability, strict memory safety |
| [`modularization`](https://github.com/swift-institute/swift-institute/tree/main/Skills/modularization) | Target decomposition, import precision |
| [`platform`](https://github.com/swift-institute/swift-institute/tree/main/Skills/platform) | Cross-platform code layering, Package.swift configuration |
| [`testing`](https://github.com/swift-institute/swift-institute/tree/main/Skills/testing) | Test organization, naming, suite structure |
| [`documentation`](https://github.com/swift-institute/swift-institute/tree/main/Skills/documentation) | Inline DocC comments, `.docc` catalogues |
| [`readme`](https://github.com/swift-institute/swift-institute/tree/main/Skills/readme) | README structure and conventions |

These skills are designed to be loaded by AI agents as normative references during development. Humans can read them directly as specifications.

## Swift Evolution proposals

Language-level changes that need to go through Swift Evolution are tracked in [`Swift Evolution/`](https://github.com/swift-institute/swift-institute/tree/main/Swift%20Evolution). The directory follows the stages of the Swift Evolution process — Drafts, Pitches, Proposals, Accepted, Implemented, Declined. See [`Swift Evolution/Pitch Process.md`](https://github.com/swift-institute/swift-institute/blob/main/Swift%20Evolution/Pitch%20Process.md) for the pitch workflow.

## Research and experiments

Non-normative design rationale lives in [`Research/`](https://github.com/swift-institute/swift-institute/tree/main/Research). Minimal reproductions and technical-claim evidence live in [`Experiments/`](https://github.com/swift-institute/swift-institute/tree/main/Experiments). Every load-bearing technical claim in a blog post links to the experiment that backs it — readers can clone the package, build it, and verify the behavior.

## Before opening a pull request

- Follow the conventions in the relevant skill. If a convention seems wrong, open a pitch rather than an exception.
- Every new type needs a test. Every bug fix needs a regression test.
- No Foundation imports in Primitives or Standards. Foundation is a Foundations-layer concern.
- If your change affects cross-cutting behavior (adds a requirement, changes a default), flag it in the PR description so reviewers can confirm the skill is updated.

## License

All contributions are made under the Apache License 2.0. See [LICENSE.md](../LICENSE.md).
