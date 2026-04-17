# Contributing

Thank you for your interest in contributing to the Swift Institute ecosystem.

## Maintainer

Swift Institute is currently maintained by Coen ten Thije Boonkkamp as a
sole-contributor project. Contributions via pull request are welcome; all PRs are
reviewed by the maintainer before merging.

## Where the rules live

Development conventions — naming, errors, memory safety, testing, modularization,
documentation, and more — are defined in the
[swift-institute/Skills](https://github.com/swift-institute/Skills) repository.
Each skill is the canonical source for its area. When you write code inside the
ecosystem, the skills are the reference.

Skills are written to be loaded by AI agents as normative references during
development. Humans can read them directly as specifications.

## Swift Evolution proposals

Language-level changes that need to go through the Swift Evolution process are
tracked in
[swift-institute/Swift-Evolution](https://github.com/swift-institute/Swift-Evolution).
The repository follows the phases of the process — Drafts, Pitches, Proposals,
Accepted, Implemented, Declined. See the
[`swift-evolution`](https://github.com/swift-institute/Skills/blob/main/swift-evolution/SKILL.md)
skill for the pitch workflow.

## Research and experiments

Non-normative design rationale lives in
[swift-institute/Research](https://github.com/swift-institute/Research). Minimal
reproductions and technical-claim evidence live in
[swift-institute/Experiments](https://github.com/swift-institute/Experiments).
Every load-bearing technical claim in a blog post links to the experiment that
backs it — readers can clone the package, build it, and verify the behavior.

## Before opening a pull request

- Follow the conventions in the relevant skill. If a convention seems wrong,
  open a PR against the relevant skill in
  [swift-institute/Skills](https://github.com/swift-institute/Skills) with a
  research document in
  [swift-institute/Research](https://github.com/swift-institute/Research)
  justifying the change. For language-level changes that require upstream Swift
  Evolution, see
  [swift-institute/Swift-Evolution](https://github.com/swift-institute/Swift-Evolution).
- Every new type needs a test. Every bug fix needs a regression test.
- No Foundation imports in Primitives or Standards. Foundation is a
  Foundations-layer concern.
- If your change affects cross-cutting behavior (adds a requirement, changes a
  default), flag it in the PR description so the maintainer can confirm the
  skill is updated.

## Code of Conduct

All participation in the Swift Institute ecosystem is governed by the
[Code of Conduct](CODE_OF_CONDUCT.md). By contributing, you agree to abide by
its terms.

## Security

Do not report security vulnerabilities through public channels. Follow the
[Security Policy](SECURITY.md) for private reporting.

## License

By submitting a contribution, you agree that it will be licensed under the
[Apache License 2.0](LICENSE.md), the license used by all packages in the
ecosystem.
