# Swift Standards

@Metadata {
    @TitleHeading("Swift Institute")
}

Faithful Swift implementations of external normative specifications — RFCs, ISO standards, W3C specifications, and the rest.

## Overview

Standards implement external specifications. The semantics are dictated elsewhere; correctness is defined by conformance. When a type carries the name `RFC_3986.URI` or `ISO_32000.Page`, the type's behaviour is exactly what the specification prescribes — no implementation drift, no convenience shortcuts, no silent divergence.

Specifications are stable documents; the packages that implement them change rarely.

---

## Per-authority organizations

Standards are distributed across GitHub organizations, one per authority body:

| Organization | Authority |
|--------------|-----------|
| [swift-ietf](https://github.com/swift-ietf) | IETF (RFCs) |
| [swift-iso](https://github.com/swift-iso) | ISO |
| [swift-w3c](https://github.com/swift-w3c) | W3C |
| [swift-whatwg](https://github.com/swift-whatwg) | WHATWG |
| Additional per-authority organizations | Other standards bodies |

Organization membership signals authority at a glance. A repository in `swift-ietf` is an IETF document implementation; the name identifies the RFC number. A repository in `swift-iso` is an ISO standard implementation.

---

## The -standard convergence pattern

Some domain concepts are defined by multiple specifications, or by one specification that undergoes revision. For these cases, the [swift-standards](https://github.com/swift-standards) organization publishes **-standard** packages that converge spec implementations into a single canonical type.

```
swift-standards/swift-{concept}-standard    Convergence + stability
         ↑
swift-{body}/swift-{spec-id}                Individual spec implementations
```

A -standard package for a multi-spec domain converges several related specs into a single stable type. Consumers depend on the -standard package and import its stable module; when a new revision is published, the -standard package absorbs it internally, and consumer code does not need to change.

Even single-spec concepts benefit from the pattern. When a specification is revised, consumers continue importing the stable `*_Standard` module without code change.

| Pattern | Consumer imports | When a spec changes |
|---------|------------------|---------------------|
| Direct spec package | The spec-specific module | Consumer code references the new spec |
| Convergence (-standard) | The stable `*_Standard` module | -standard package updates; consumer unchanged |

-standard packages are policy-free. They do not add opinion or ecosystem integration — they faithfully compose externally-defined concepts. Higher-layer opinion lives in foundations; see <doc:Swift-Foundations>.

---

## Foundation independence

Standards do not import Foundation. Specifications define their concepts in terms of octets, integers, and structured data — not in terms of any Swift framework. The layer preserves that purity. See the <doc:FAQ> for the current platform matrix.
