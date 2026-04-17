# Whitepaper

@Metadata {
    @TitleHeading("Swift Institute")
    @PageImage(purpose: card, source: "card-whitepaper", alt: "Whitepaper")
}

The Swift Institute is an integrated Swift package ecosystem — organized into layers, released as individually versioned packages, and built through a documented method in which every load-bearing technical claim is either written down as research or executable as an experiment.

## Overview

Two questions shape what the Institute is. The first is architectural: what must the ecosystem contain, and how should those contents be organized so that packages can be adopted independently and evolve at different speeds? The second is methodological: by what process do design decisions become code that deserves to be called timeless infrastructure?

The two questions are linked. The layering makes scope tractable — it gives each design decision a home with known neighbours and known dependencies. The method keeps the layering honest — it forces each non-obvious choice to leave a written or runnable record. Neither half works alone. A layered ecosystem without a method drifts under pressure; a method without clear layering produces receipts that nobody can locate.

*Integrated* is the load-bearing word. The packages are individually versioned, individually released, and individually consumable — there is no umbrella dependency that brings the whole ecosystem in. What integrates them is the layering, the conventions they share, and the method by which they were built. A consumer who depends on two packages from different layers gets two Swift packages in their manifest; what they also get — implicitly — is the guarantee that the design decisions behind each were made through the same process and left the same kind of record.

The rest of this page describes each half and the properties the combination produces.

## The layered ecosystem

The ecosystem organizes packages into five layers. Three are currently released; two are planned. Each layer answers a distinct question, and dependencies flow in one direction only: packages may depend on packages in their own layer or lower, never above.

| Layer | Question answered | Status |
|-------|-------------------|--------|
| Primitives | What must exist? | Released |
| Standards | What is specified externally? | Released |
| Foundations | What can be composed? | Released |
| Components | What is reusable with defaults? | Planned |
| Applications | What is an end-user system? | Planned |

### Why layers

Three concerns motivate the layering.

The first is **separating what cannot change from what must evolve**. A coordinate in two-dimensional space is a mathematical concept; its definition should be stable across decades. An HTTP server composes operating-system syscalls, TLS handshakes, and protocol versions that evolve continuously. Bundling them into the same package drags the stable concept at the speed of the volatile one. Layering separates the two so each can evolve at its own rate.

The second is **dependency clarity**. When dependencies flow in one direction only, a change at a given layer has a finite blast radius — only layers above it can be affected. Circular dependencies are structurally impossible. A reader tracing why a change is needed can walk down the layers; a maintainer tracing what a change affects can walk up. Both directions are short and finite.

The third is **flexible licensing**. The three released layers are Apache 2.0 — foundational substrate where value comes from ubiquity and permissive reuse. Higher layers — Components and Applications, once released — may carry different licenses where policy and opinion accumulate. The layering lets each layer pick the license that matches its role without forcing a single choice across the whole ecosystem.

### Primitives

Primitives are atomic building blocks — types that standards require but do not define. Geometry, algebra, memory, time, collections, concurrency, parsing, and kernel abstractions all live here. A primitive package exposes minimal API surface, carries no defaults, and is designed to be stable across decades. Primitives depend only on other primitives.

A geometry primitive does not just declare what a point or an affine transformation is — it implements the operations that hold universally over them: addition, inversion, composition. A kernel primitive declares the shape of a file descriptor and exposes the operations every implementing platform supports. Primitives have behaviour. What they do not have is *policy*. A primitive resolves the universally correct answer to its question; choices between sensible alternatives are deferred to higher layers, where context makes them decidable.

The effect is a layer of atomic units that compose predictably. When one affine transformation composes with another, the result is determined by the mathematics, not by implementation preference. When a buffer flows through a parser, the interaction follows from the types, not from an implementer's taste. Absence of policy is what makes primitives independently verifiable — each unit is specified tightly enough to be reasoned about on its own terms, and composition preserves that tightness rather than blurring it.

Released at [swift-primitives](https://github.com/swift-primitives). See <doc:Swift-Primitives> for details.

### Standards

Standards packages implement external normative specifications — RFCs, ISO standards, protocol formats, file formats — where the semantics are dictated by the specification and correctness is defined by conformance.

A type in a standards package mirrors the specification that defines it. `RFC_4122.UUID` names the UUID specification explicitly; `ISO_32000.Page` names the PDF 1.7 specification explicitly; `RFC_3986.URI` names the URI specification explicitly. When a reader sees the type name, they know which document governs its behaviour — which is what conformance means, made visible at the type level.

The distinctive organizational claim at this layer is that **standards is an organization of organizations**. Each standards body has its own governance, its own release cadence, and its own natural audience. The repository structure reflects that: every authority body that produces specifications the Institute implements gets its own GitHub organization, holding the packages specific to that authority.

| Organization | Authority |
|--------------|-----------|
| [swift-ietf](https://github.com/swift-ietf) | IETF (RFCs) |
| [swift-iso](https://github.com/swift-iso) | ISO |
| [swift-w3c](https://github.com/swift-w3c) | W3C |
| [swift-whatwg](https://github.com/swift-whatwg) | WHATWG |
| [swift-ieee](https://github.com/swift-ieee), [swift-iec](https://github.com/swift-iec), [swift-ecma](https://github.com/swift-ecma), [swift-incits](https://github.com/swift-incits) | IEEE, IEC, Ecma, INCITS |
| [swift-arm-ltd](https://github.com/swift-arm-ltd), [swift-intel](https://github.com/swift-intel), [swift-riscv](https://github.com/swift-riscv), [swift-microsoft](https://github.com/swift-microsoft) | Vendor ISAs and platform specs |

The pattern is not cosmetic. Each standards body issues version-numbered documents at its own pace and serves a distinct audience. An IETF practitioner browsing swift-ietf sees the corpus of RFC implementations; an ISO practitioner browsing swift-iso sees ISO standards; a vendor-specification practitioner browsing swift-arm-ltd sees ARM ISA documents. Neither has to filter the other's noise, and neither group is captive to release decisions made outside their domain.

An external reader looking for an RFC implementation knows where to look; a package for a ratified specification sits alongside other packages from the same authority. Cross-body and convergence packages remain under [swift-standards](https://github.com/swift-standards) itself. See <doc:Swift-Standards> for details.

### Foundations

Foundations compose primitives and standards into reusable domain abstractions — file I/O, JSON, TLS, HTML, HTTP servers, networking. A foundations package carries more opinion than a primitive (defaults are present; trade-offs are encoded) but less than a product (no end-user shell, no commercial positioning). Foundations depend on primitives and standards.

A file-I/O foundation composes kernel primitives that describe file descriptors with the POSIX standard that specifies their syscalls. An HTTP server composes the IETF RFCs for HTTP/1.1 and HTTP/2 with the TLS standard and with the I/O foundation. The ingredients come from below; the composition — the choices about how to arrange them, what defaults to expose, which trade-offs to encode — is what lives at the foundations layer.

Released at [swift-foundations](https://github.com/swift-foundations). See <doc:Swift-Foundations> for details.

### Components and applications

Two higher layers are planned. Components are opinionated assemblies built on foundations — a rendering pipeline, an HTTP server preset, a CLI framework. Applications are end-user systems. Neither is released yet; their place in the dependency chart is stable.

### Per-package model

Every repository in the ecosystem is a standalone Swift package. It has its own version history, its own release tags, and its own `Package.swift`. Consumers depend on packages individually; there is no umbrella import that pulls the whole layer in. The layers organize authorship and release cadence, not distribution.

The consequence is that a breaking change in one package propagates only to packages that actually depend on it. A consumer needing nothing but affine transformations accepts only that package's version constraints and is insulated from churn elsewhere. Release coordination remains per-package, not per-layer; a single layer can hold tens of packages at tens of different versions. The ecosystem is a federation of independently releasable units held together by the layering rules, not a monolith that ships on a single cadence.

## The loop

Design decisions in the Institute move through four public artifact types. Each has a purpose, a location, and a citation model; together they form a loop.

1. **Research documents** — design rationale and trade-off analysis. When a decision has non-obvious alternatives, the question, the options, the criteria, and the outcome are written down before code changes settle the matter. See <doc:Research>.
2. **Experiments** — runnable Swift packages that isolate one hypothesis. When a claim depends on compiler or runtime behaviour, the experiment proves it. Multi-variant experiments encode related claims as separate targets. See <doc:Experiments>.
3. **Code** — the packages themselves. Code implements what research and experiments have resolved; the implementation carries the decision forward into the versioned record.
4. **Blog posts** — external communication that cites research and experiments as load-bearing evidence. A claim about compiler behaviour links to the experiment that verifies it; a claim about design rationale links to the research document that records it. See <doc:Blog>.

The sequence is: design question → research document → experiment → code → blog post citing the first three. It is a loop rather than a pipeline because blog posts frequently raise new design questions, which re-enter at the first node.

A worked example makes the sequence concrete. A design question arises: how should a non-copyable resource be transferred safely between two actors? Multiple approaches are plausible — closure-based transfer, an ownership-transfer cell, a move-only channel — so a research document enumerates them and compares them against criteria like compiler support, safety, and ergonomics. One approach appears to depend on a specific compiler capability; an experiment is built as a minimal Swift package that either compiles or does not under a target Swift version. The experiment CONFIRMS the capability; the research document records the outcome and selects the approach. Code in the relevant package adopts the pattern. A blog post drafted later explains the problem and the solution, linking to the research document for the rationale and to the experiment for the compiler-behaviour evidence. If a reader encounters the blog post and wonders whether the claim still holds on a newer compiler, they clone the experiment and re-run it. If the compiler has regressed, a new research document updates the record.

The loop is what makes the ecosystem's claims robust over time. Each node cross-cites the others; changes at one node trigger updates at the others; the evidence trail for any design decision is reconstructable years later from the artifacts alone. There is no separate institutional memory that must be preserved — the memory is the artifacts, and the artifacts are in git.

## Receipts

The Institute commits to a stronger epistemic discipline than typical open-source documentation: every load-bearing technical claim in the ecosystem is either written down as research or executable as an experiment. *Load-bearing* means a claim that other code or other reasoning depends on — architectural decisions, naming conventions, compiler-behaviour assertions, performance characteristics, compatibility guarantees.

A research document is a written record; an experiment is a runnable one. Both are versioned artifacts under git, independently citable. When a reader encounters a claim in the code or in a blog post, they can follow the citation to a primary source and either read the reasoning or run the verification.

This is what distinguishes the Institute's receipts model from release notes or blog archives: the receipts are structured, persistent, and addressable. A release note describes a change; a research document explains a decision; an experiment demonstrates a behaviour. The three do different work. The receipts do not replace documentation — the reference documentation for each package lives alongside the code — but they back the reasoning behind the API that the reference describes.

*Load-bearing* is a specific threshold, not a universal obligation. Convenience aliases, comment-level explanations, and ordinary implementation details do not need receipts — they are self-evident from the code or the reference documentation. A receipt is required when the claim is one that other code or other reasoning depends on. Examples: the assertion that a particular pattern compiles under a target Swift version (→ experiment); the decision to use one naming convention rather than another across the ecosystem (→ research document); the guarantee that a type provides a specific safety property under concurrent access (→ test or experiment). Each is a commitment that could be silently broken by a well-intentioned change, so each is pinned to an artifact that would fail visibly if the commitment slipped.

The discipline has a cost. Writing the research document takes time; building the experiment takes more. The pay-off is not immediate — it is deferred to the moment, months or years later, when the original author is no longer available and a new reader needs to reconstruct why a choice was made. Open-source ecosystems routinely fail this test; decisions accumulate whose rationale vanished with the commit that implemented them, and downstream maintainers are left guessing. The receipts model is an attempt to avoid that failure mode at the cost of slower writing up front.

## Why this shape

Three properties fall out of the layering and the loop working together.

**Correctness.** Claims about compiler, runtime, or design behaviour are verified rather than asserted. When the ecosystem states that a pattern compiles, that a design choice has a specific trade-off, or that a package behaves a certain way under load, there is an experiment or a research document that backs the statement. Readers do not have to trust the prose. A reader who doubts a claim can clone the experiment and run it. As a concrete example, the ecosystem's claim of Foundation independence is backed by the cross-platform build matrix; specific Foundation-free techniques — date handling without `Date`, path handling without `URL`, buffered I/O without `Data` — are backed by named experiments that demonstrate each technique in isolation. A reader who doubts any of these can inspect the matrix or run the experiment. The evidence is addressable.

**Composability.** The layers compose packages; the loop composes artifacts. A blog post composes research documents and experiments. A research document composes experiments. An experiment composes primitives and standards. The ecosystem is built out of parts that link to the parts they depend on, at both the code and the prose level. Composition is the design principle that runs through the architecture and the method alike. The graph is fractal in a useful sense: the shape of the dependency relations looks similar at the package level and at the prose level. A package depends on five other packages; a research document cites two experiments and three other research documents; a blog post anchors to one research document and one experiment. Composition is not restricted to code — it is how the written record is built as well.

**Long-term evolution.** The written and runnable record survives refactors, renames, and reorganizations. When a type moves between packages or a convention changes, the research documents that explained the original decision remain as history. A reader encountering the current code can trace back through the record to understand what was considered, what was rejected, and why. The ecosystem is designed to be legible in a decade, which is a high bar; the receipts are how it is met. The name *Institute* points at this explicitly. An institute is an organization designed to outlive its individual members and individual projects; the artifacts it produces are intended as a record that survives. The ecosystem's tagline — *timeless infrastructure* — is a durability claim, and the receipts are how the claim is backed. Without them, a decade-old package would be a black box; with them, it is the package plus the reconstructable rationale for every non-obvious decision it carries.

The combination is what the word *Institute* names. The layering gives the ecosystem structural shape; the loop gives it evidential discipline. A layered ecosystem without the loop would be a catalogue; a loop without layering would be a blog with receipts. Together they produce infrastructure that can be adopted incrementally, reasoned about precisely, and evolved over long horizons.

The combination does not guarantee that the ecosystem is correct, composable, or durable in every respect. It guarantees that where it fails on any of those dimensions, there is a record of the decision that produced the failure — which is what makes failures recoverable rather than mysterious. A reader encountering an unfortunate API can trace it back to the decision that shaped it; a maintainer reconsidering an old choice can find the reasoning it replaced. The shape is a discipline, not a proof.

## Relationship to other artifacts

The Whitepaper names the *loop*. <doc:Research> describes the design-rationale artifact type — where to browse, what gets recorded, how documents are structured. <doc:Experiments> describes the runnable-verification artifact type — how to clone and run, what gets an experiment, how outcomes are tagged. <doc:Blog> publishes external communication that cites both as load-bearing evidence. <doc:Layers>, <doc:Swift-Primitives>, <doc:Swift-Standards>, and <doc:Swift-Foundations> go deeper into each layer's contents. <doc:FAQ> addresses common questions about platform support, Foundation independence, and package granularity. This page sits above all of them, explaining the system as a whole.
