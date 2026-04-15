# Swift Foundations

@Metadata {
    @TitleHeading("Swift Institute")
}

Composed building blocks that integrate primitives and standards into reusable infrastructure.

## Overview

Foundations are where primitives and standards become useful infrastructure. A JSON parser at the standards layer implements RFC 8259; a JSON-based configuration system at the foundations layer composes JSON with file I/O, validation, and type coercion. `swift-emailaddress-standard` converges RFC 2822, 5321, 5322, and 6531 into a canonical `EmailAddress` type; `swift-emailaddress` at the foundations layer integrates that type with validation middleware and service APIs.

136 packages are published at the [swift-foundations](https://github.com/swift-foundations) organization, following the naming pattern `swift-{concept}` (clean names, no suffix). Foundations are the first layer where ecosystem integration begins — still policy-light, but composed rather than atomic.

Foundations are Apache 2.0 by default, with selective commercial terms for specific packages where appropriate.

---

## Composition over accretion

The distinction between Standards and Foundations is composition.

**Standards** faithfully implement external specifications. A `JSON` type at the standards layer parses and serializes RFC 8259. An `IPv4Address` implements RFC 791. A `DateTime` implements ISO 8601. Standards depend only on primitives and are policy-free.

**Foundations** compose standards and primitives into reusable abstractions. A `swift-config` package composes JSON, TOML, YAML, file I/O, and environment-variable parsing into a unified configuration system. A `swift-http-server` composes HTTP types, TLS, routing, and executors into a server. Foundations introduce structural decisions — how types relate, what is wired together by default — without prescribing end-user policy.

**Distinction from Primitives**: Foundations have dependencies on standards. A TLS foundation depends on cryptographic standards; a logging foundation may depend on timestamp standards. Primitives depend only on other primitives.

---

## Design principles

Foundations inherit the discipline of lower layers:

- **Typed throws everywhere.** Every fallible operation declares its concrete error type. Consumers get exhaustive switches, not catch-all blocks.
- **No Foundation import.** Timestamps, paths, data buffers, and string processing come from primitives and standards, not `Foundation.Date`/`URL`/`Data`.
- **Cross-platform by default.** Code is designed for Darwin, Linux, Embedded Swift, and Windows. Platform-specific behaviour is isolated. See <doc:Platform>.
- **Granular packaging.** Depend on `swift-http-routing` without pulling in `swift-http-compression`. Each package answers one question well.

---

## Domain coverage

The foundations layer is where the ecosystem visibly spans the full stack of application infrastructure. Major domains:

### Core runtime

Kernel abstractions, async sequences/streams, threads, executors, clocks, memory, I/O, sockets.

`swift-kernel`, `swift-async`, `swift-io`, `swift-threads`, `swift-executors`, `swift-clocks`, `swift-sockets`, `swift-memory`

### Platform abstraction

Cross-platform layer for OS and POSIX APIs. See <doc:Platform> for the full treatment.

`swift-posix`, `swift-linux`, `swift-darwin`, `swift-windows`

### File system and paths

File operations, path manipulation, module loading.

`swift-file-system`, `swift-paths`, `swift-loader`

### Data formats

Parsers and serializers for the common interchange formats.

`swift-json`, `swift-xml`, `swift-plist`, `swift-toml`, `swift-yaml`, `swift-msgpack`, `swift-protobuf`, `swift-json-feed`

### Markup and rendering

HTML, SVG, PDF, Markdown, and EPUB generation and rendering. Compositional: swift-html, swift-html-rendering, swift-pdf-html-rendering, and similar lets you compose markup and rendering independently.

`swift-html`, `swift-svg`, `swift-pdf`, `swift-epub`, plus the corresponding `*-rendering` and `*-html-rendering` packages

### Web and HTTP

A full HTTP stack — types, bodies, headers, cookies, compression, content negotiation, CORS, ETag, range, redirect, routing, HTTP/2, HTTP/3, WebSocket, DNS caching.

15 packages in the `swift-http*` family, plus `swift-websocket` and `swift-dns-cache`.

### Authentication and security

Basic auth, digest auth, OAuth (with PKCE), JWT, JWS, JWE, JWK, TOTP, CSRF, TLS, certificates, cryptography, passwords, secrets.

15 packages covering modern authentication and security primitives.

### Text and internationalization

Strings, ASCII, lexing, translation, plural forms.

`swift-strings`, `swift-ascii`, `swift-lexer`, `swift-translating`

### Database

Abstract SQL with concrete backends for SQLite, MySQL, and PostgreSQL.

`swift-sql`, `swift-sql-sqlite`, `swift-sql-mysql`, `swift-sql-postgres`

### Observability

Structured logging, metrics, distributed tracing.

`swift-log`, `swift-log-json`, `swift-metrics`, `swift-tracing`

### Testing

Test framework, runners, snapshot testing, performance testing.

`swift-testing`, `swift-tests`

### Macros and language tools

Copy-on-write, defunctionalization, dual implementations, compiler and syntax infrastructure.

`swift-copy-on-write`, `swift-defunctionalize`, `swift-dual`, `swift-compiler`, `swift-syntax`, `swift-source`

### Domain utilities

Color, email, IP addresses, URIs, time, environment variables, locale, console, process management, command-line parsing.

`swift-color`, `swift-email`, `swift-emailaddress`, `swift-ip-address`, `swift-uri`, `swift-time`, `swift-environment`, `swift-console`, `swift-locale`, `swift-process`, `swift-command-line`

### Utility infrastructure

Dependency injection, effects, witnesses, graceful shutdown, health checks, scheduling, migrations, feature flags.

`swift-dependencies`, `swift-effects`, `swift-witnesses`, `swift-graceful-shutdown`, `swift-health`, `swift-scheduler`, `swift-migrations`, `swift-feature-flags`

---

## Choosing dependencies

There is no umbrella foundation package. Depend on what you need:

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-http-routing", from: "0.1.0"),
    .package(url: "https://github.com/swift-foundations/swift-json", from: "0.1.0"),
    .package(url: "https://github.com/swift-foundations/swift-log", from: "0.1.0"),
]
```

Each package documents its own dependencies and version support.
