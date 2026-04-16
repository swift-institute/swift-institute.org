# Restarting the blog: nine months, an ecosystem, and a way to write about it

@Metadata {
  @TitleHeading("Swift Institute Blog")
  @PageImage(purpose: card, source: "blog-card", alt: "Swift Institute Blog")
}

My last post went up in July 2025. Since then I have written no blog posts and roughly 9,800 git commits. This is a short post about what happened in between, and why the next few posts will look different from what I've published before.

## What I've been building

A layered Swift package ecosystem, built continuously since last summer. It is organized into layers, each a separate GitHub organization:

| Layer | Organization | Repositories | Role |
|-------|--------------|-------------|------|
| 1 | swift-primitives | 127 | Atomic building blocks — buffer, geometry, algebra, memory, kernel |
| 2 | swift-standards | an organization of organizations (see below) | Specification implementations |
| 3 | swift-foundations | 136 | Composed building blocks — IO, HTML, CSS, SVG, PDF, networking |

Every repository in the ecosystem is a standalone Swift package. It has its own version history, its own release tags, and its own `Package.swift`. You consume it the same way you consume any other Swift package — a `.package(url: ...)` line in your manifest.

What the layers share is a dependency rule: packages in each layer may depend on packages in their own layer and layers below, never above. Primitives depend only on each other. Standards may depend on primitives. Foundations may depend on both.

Each layer also has a superrepo — `swift-primitives`, `swift-standards`, `swift-foundations` — whose only content is git submodule pointers to every package in that layer. The superrepos exist for browsing convenience: clone one, and you have the whole layer on disk to explore with a single IDE or `grep`. The code itself lives in the individual package repositories; the superrepo just aggregates the pointers.

An umbrella organization, swift-institute, holds cross-cutting documentation, development conventions, and the blog workflow that produced this post.

## The standards refactor

In March I restructured swift-standards. The middle layer had grown to roughly 90 specification packages from eight different standards bodies — IETF, ISO, W3C, WHATWG, IEEE, IEC, Ecma, INCITS, plus vendor specs from ARM, Intel, RISC-V, and Microsoft. They all lived in the same organization, and browsing it had become noisy. Each standards body has its own governance, its own release cadence, and its own natural audience. The repository structure should reflect that.

swift-standards is now primarily an organization of organizations. Each standards body gets its own GitHub org, holding the packages specific to that authority:

| Organization | Packages | Authority |
|--------------|---------|-----------|
| swift-ietf | 54 | IETF (RFCs) |
| swift-iso | 9 | ISO |
| swift-w3c | 6 | W3C |
| swift-whatwg | 2 | WHATWG |
| swift-ieee, swift-iec, swift-ecma, swift-incits | 1 each | IEEE, IEC, Ecma, INCITS |
| swift-arm-ltd, swift-intel, swift-riscv, swift-microsoft | 1 each | Vendor specs |

swift-standards itself retains 19 cross-body or historical packages. The question each organization name answers is "who standardized this?" — an external reader looking for an RFC implementation now has one obvious place to look.

## The shape of the work

| Month | New repos | Commits | Focus |
|-------|----------|--------|-------|
| Jul 2025 | 11 | 37 | First standards bootstrap — domain, email, DNS, HTTP auth |
| Aug 2025 | 1 | 5 | |
| Sep 2025 | 0 | 2 | Quiet period |
| Oct 2025 | 0 | 27 | |
| Nov 2025 | 50 | 864 | Standards acceleration — RFC and ISO implementations |
| Dec 2025 | 14 | 630 | Continued standards |
| Jan 2026 | **237** | 2,646 | Primitives and foundations layers created; repo-creation peak |
| Feb 2026 | 15 | 1,472 | Architecture hardening — module splits, testing, skills |
| Mar 2026 | 31 | 2,605 | Typed throws conversion across every layer; standards refactor |
| Apr 2026 (to date) | 3 | 1,559 | Swift 6.3 ecosystem migration, kernel event consolidation, IO redesign |

Two things are worth reading out of that table. January 2026 produced 237 new repositories in a single month — this is when the primitives and foundations layers were created wholesale and every atomic concept got its own package. It is not a sustainable rate, and I do not want it to be. After that, the pace drops to the tens of new repos per month, and the activity shifts inside existing packages — typed throws conversions, audits, architectural tightening, the 6.3 migration.

Most of the ecosystem is currently private. It is being released publicly on a rolling basis. Some links in this post and the next few will point to repositories that are not yet world-readable — they will be, one by one, as I cut the release tags.

## Why I stopped writing

Not because I stopped working. I stopped writing *about* the working.

The July 2025 series on modular Swift architecture was written the traditional way: do the work, write about it, edit, publish. Each post took days. The writing was decoupled from the building — a separate activity with its own time budget.

When the pace of infrastructure work accelerated in January 2026, that model broke. Every week produced insights, patterns, compiler discoveries, and architectural decisions worth documenting. Writing a post about each one would have consumed the time I was using to produce the next one. So the internal record grew — research documents, experiment reports, reflection logs — and the external record flatlined.

## The AI-assisted approach

These posts are drafted with AI assistance. I want to say that upfront rather than have you infer it from the prose.

**What I provide**: the technical substance. Every claim traces back to code I wrote, an experiment I ran, compiler behavior I observed, or an architectural decision I made.

**What AI provides**: the writing at scale. Claude Code drafts prose from my technical context, follows a documented style guide, and iterates through a review workflow.

The alternative to AI-assisted writing is not "write it manually." At the current ratio of built-to-written material, the alternative is "do not write." I would rather publish AI-assisted writing that is technically accurate and honest about its process than publish nothing.

A later post will cover the methodology in detail — how drafting, receipts, style conventions, and review fit together. This post is the restart, not the methodology manifesto.

## What's coming

The next few posts are warm-ups. I'm using them to test the writing system, to establish the voice, and to confirm that the claim-to-evidence loop works end-to-end before I get to the pieces that actually matter.

The first technical post after this one is a short standalone piece on an associated-type trap — a specific pattern where flat, common-noun associated types like `associatedtype Body` quietly fracture generic constraints when a conforming type adopts a second protocol with the same name. It's a small observation, but it's the kind of thing the old writing cadence never would have surfaced.

After that, the backlog is roughly fifty topics deep. A series on typed throws across a real ecosystem conversion. An audit of an IO library with about 85 findings. Compiler bugs and workarounds for `~Copyable` types. Algebra package decomposition. Foundation-free standards. Cross-layer code navigation tooling.

Not all of them will ship. The ones that do will follow the same shape as this one: real technical substance, AI-assisted drafting, rigorous review, and transparency about the method.

## References

- [Modern Swift Library Architecture (Part 3)](https://coenttb.com/blog/modern-swift-library-architecture-part-3) — my last published post, July 21, 2025
