# Swift Standards

@Metadata {
    @TitleHeading("Swift Institute")
}

Faithful Swift implementations of external normative specifications — RFCs, ISO standards, W3C specifications, and the rest.

## Overview

Standards implement external specifications. The semantics are dictated elsewhere; correctness is defined by conformance. When a Swift Institute type carries the name `RFC_5322.EmailAddress` or `ISO_8601.DateTime`, the type's behaviour is exactly what the specification prescribes — no implementation drift, no convenience shortcuts, no silent divergence.

20 packages are published across eight organizations today. Every package is Apache 2.0 licensed. Specifications are stable documents; the packages that implement them change rarely.

---

## Specifications as namespaces

Types mirror the specifications that define them. The specification identifier is the namespace; the type name matches the concept defined in the specification.

```swift
import Email_Standard
import Time_Standard
import Sockets_Standard

let address: RFC_5322.EmailAddress        // RFC 5322 — Internet Message Format
let timestamp: ISO_8601.DateTime          // ISO 8601 — Date and time representation
let tcp_state: RFC_9293.`3`.`3`.State     // RFC 9293 — Transmission Control Protocol, §3.3
```

The convention extends to nested sections: `RFC_9293.`3`.`1`.Header` refers to Section 3.1 of RFC 9293. Backtick-quoted numerics are a Swift syntax requirement; they preserve the specification's own section numbering.

When a consumer reads `RFC_9293.`3`.`3`.State`, the authoritative definition is three clicks away (RFC Editor → RFC 9293 → §3.3). There is no ambiguity about which document governs the type's behaviour.

---

## Per-authority organizations

Standards are distributed across GitHub organizations, one per authority body:

| Organization | Authority | Example |
|--------------|-----------|---------|
| [swift-ietf](https://github.com/swift-ietf) | IETF (RFCs) | `swift-rfc-3986` (URI) |
| [swift-iso](https://github.com/swift-iso) | ISO | `swift-iso-32000` (PDF) |
| [swift-w3c](https://github.com/swift-w3c) | W3C | `swift-w3c-css` |
| [swift-whatwg](https://github.com/swift-whatwg) | WHATWG | `swift-whatwg-url` |
| [swift-ieee](https://github.com/swift-ieee) | IEEE | IEEE 754, IEEE 1003 |
| [swift-iec](https://github.com/swift-iec) | IEC | IEC 61966 (sRGB) |
| [swift-ecma](https://github.com/swift-ecma) | ECMA | ECMA 48 (terminal control) |
| [swift-incits](https://github.com/swift-incits) | INCITS | Per-standard |

Additional single-organization publishers exist for ARM, Intel, RISC-V, and Microsoft platform specifications.

Organization membership signals authority at a glance. A repository in `swift-ietf` is an IETF document implementation; the name identifies the RFC number. A repository in `swift-iso` is an ISO standard implementation.

---

## The -standard convergence pattern

Some domain concepts are defined by multiple specifications, or by one specification that undergoes revision. For these cases, the [swift-standards](https://github.com/swift-standards) organization publishes **-standard** packages that converge spec implementations into a single canonical type.

```
swift-standards/swift-emailaddress-standard    Convergence + stability
         ↑
swift-ietf/swift-rfc-2822
swift-ietf/swift-rfc-5321                     Individual spec implementations
swift-ietf/swift-rfc-5322
swift-ietf/swift-rfc-6531
```

`swift-emailaddress-standard` converges RFC 2822, 5321, 5322, and 6531 into a single `EmailAddress` type. Consumers depend on the -standard package and import `Email_Standard`. When a new RFC is published, the -standard package absorbs it internally; consumers are not forced to choose between RFC versions.

Even single-spec concepts benefit from the pattern. `swift-epub-standard` wraps W3C EPUB. When EPUB is revised, consumers continue importing `EPUB_Standard` without code change.

| Pattern | Consumer imports | When a spec changes |
|---------|------------------|---------------------|
| Direct spec package | `RFC_3986` | Consumer code references the new RFC |
| Convergence (-standard) | `URI_Standard` | -standard package updates; consumer unchanged |

-standard packages are policy-free. They do not add opinion or ecosystem integration — they faithfully compose externally-defined concepts. Higher-layer opinion lives in foundations; see <doc:Swift-Foundations>.

---

## Domain coverage

The 20 released -standard and spec packages cover:

| Domain | Packages |
|--------|----------|
| Identity and addressing | email, domain, emailaddress, ipv4, ipv6, uri |
| Networking | sockets (TCP, UDP) |
| Time | time (ISO 8601 + RFC 3339) |
| Documents | pdf, epub, html, svg, css |
| Syndication | rss, json-feed |
| Localization | locale (ISO 639, 3166, 15924, BCP 47) |
| Color | color (IEC 61966 sRGB, ECMA 48, ISO 9899) |
| Platform | darwin-standard |
| Database | postgresql-standard |

Spec implementation packages at IETF, ISO, W3C, and other authority orgs total 60+.

---

## Foundation independence

Standards do not import Foundation. Specifications define their concepts in terms of octets, integers, and structured data — not in terms of any Swift framework. The layer preserves that purity. See <doc:Platform> for target matrix details.
