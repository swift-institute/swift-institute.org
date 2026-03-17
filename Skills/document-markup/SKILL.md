---
name: document-markup
description: |
  Document creation using HTML, PDF, and Markdown rendering packages.
  Apply when creating HTML pages, generating PDFs, rendering markdown,
  or composing documents using swift-html, swift-pdf, swift-pdf-rendering,
  swift-pdf-html-rendering, or swift-markdown-html-rendering.

layer: implementation

requires:
  - swift-institute
  - naming

applies_to:
  - swift-html
  - swift-pdf
  - swift-pdf-rendering
  - swift-pdf-html-rendering
  - swift-markdown-html-rendering
  - swift-foundations
---

# Document Markup

How to create documents — HTML pages, PDFs, and markdown-rendered content — using the document markup packages in the Swift Institute ecosystem.

---

## Package Map

### [DOC-MARKUP-001] Package Selection

**Statement**: Choose the correct package based on your output format and content source.

| Goal | Import | Layer |
|------|--------|-------|
| Generate HTML pages | `import HTML` | L3 (swift-foundations) |
| Generate PDFs from HTML content | `import PDF` | L4 (coenttb/swift-pdf) |
| Generate PDFs directly (low-level) | `import PDF_Rendering` | L3 (swift-foundations) |
| Render Markdown as HTML | `import HTML` | L3 (includes Markdown_HTML_Rendering) |
| Render Markdown as PDF | `import PDF` | L4 (includes HTML + PDF_HTML_Rendering) |

**Package dependency chain**:
```
swift-pdf (L4)
  └─ swift-pdf-html-rendering (L3)     HTML → PDF bridge
       ├─ swift-pdf-rendering (L3)      PDF.View, PDF.Context, PDF.Document
       └─ swift-html-rendering (L3)     HTML.View, HTML.Context
  └─ swift-html (L3)                   Aggregator: HTML + CSS + SVG + Markdown
       └─ swift-markdown-html-rendering (L3)   Markdown → HTML
```

**Rationale**: `import PDF` gives you everything. Use narrower imports only when you need to avoid pulling in the full stack.

---

## HTML Documents

### [DOC-MARKUP-010] HTML Document Structure

**Statement**: Create HTML pages using `HTML.Document` with body and head builders. Use lowercase typealiases for elements.

```swift
import HTML

let page = HTML.Document {
    // Body
    div {
        h1 { "Welcome" }
        p { "This is a paragraph." }
        a(href: "/about") { "Learn more" }
    }
} head: {
    // Head
    title { "My Page" }
    meta(charset: .utf8)
    meta(name: .viewport, content: "width=device-width, initial-scale=1")
}
```

**Rendering to string**:
```swift
let html = try String(page)                              // Minified
let pretty = try String(page, configuration: .pretty)    // Indented
```

**Rendering to bytes**:
```swift
let bytes = try ContiguousArray(page)
let bytes = try [UInt8](page)
```

**Rationale**: `HTML.Document` provides the full `<!DOCTYPE html><html>` wrapper. The lowercase typealiases (`div`, `h1`, `p`, `a`) mirror HTML tag syntax.

---

### [DOC-MARKUP-011] HTML Elements

**Statement**: Use lowercase typealiases for standard HTML elements. These map to WHATWG specification types.

**Common elements**:

| Typealias | WHATWG Type | Purpose |
|-----------|-------------|---------|
| `div` | `ContentDivision` | Block container |
| `span` | `Span` | Inline container |
| `p` | `Paragraph` | Paragraph |
| `h1`–`h6` | `H1`–`H6` | Headings |
| `a` | `Anchor` | Link |
| `img` | `Image` | Image |
| `ul`, `ol` | `UnorderedList`, `OrderedList` | Lists |
| `li` | `ListItem` | List item |
| `table` | `Table` | Table |
| `thead`, `tbody` | `TableHead`, `TableBody` | Table sections |
| `tr` | `TableRow` | Table row |
| `th`, `td` | `TableHeader`, `TableDataCell` | Table cells |
| `form` | `Form` | Form |
| `input` | `Input` | Form input |
| `button` | `Button` | Button |
| `pre` | `PreformattedText` | Preformatted text |
| `code` | `Code` | Code |
| `strong` | `StrongImportance` | Bold |
| `em` | `Emphasis` | Italic |
| `br` | `LineBreak` | Line break |
| `hr` | `ThematicBreak` | Horizontal rule |
| `header`, `footer`, `main`, `nav`, `section`, `article`, `aside` | Semantic elements | Page structure |

**Element attributes**:
```swift
a(href: "/path") { "Link text" }
img(src: "/photo.jpg", alt: "Description")
input(type: .email, name: "email", placeholder: "you@example.com")
```

**Rationale**: Lowercase typealiases provide familiar HTML-like syntax while maintaining full type safety.

---

### [DOC-MARKUP-012] CSS Styling

**Statement**: Apply CSS styles using the `.css` fluent accessor on any HTML view. CSS property names use specification-mirroring per [API-NAME-003] — `.fontSize()` mirrors CSS `font-size`, `.backgroundColor()` mirrors `background-color`, etc.

```swift
h1 { "Title" }
    .css
    .color(.red)
    .fontSize(.rem(2.5))
    .margin(.px(16))
    .padding(.px(8))

div {
    p { "Styled content" }
}
.css
.display(.flex)
.backgroundColor(light: .white, dark: .hex("1a1a1a"))
.border(.px(1), .solid, .gray300)
.borderRadius(.px(8))
```

**Available CSS properties** (via `.css`):
- **Typography**: `.color()`, `.fontSize()`, `.fontWeight()`, `.fontStyle()`, `.lineHeight()`, `.textAlign()`, `.textTransform()`, `.letterSpacing()`, `.wordSpacing()`, `.whiteSpace()`
- **Box model**: `.margin()`, `.padding()`, `.width()`, `.height()`, `.minWidth()`, `.maxWidth()`, `.minHeight()`, `.maxHeight()`
- **Borders**: `.border()`, `.borderColor()`, `.borderRadius()`, `.borderWidth()`
- **Layout**: `.display()`, `.position()`, `.overflow()`
- **Background**: `.backgroundColor()`
- **Dark mode**: `.backgroundColor(light:dark:)`, `.color(light:dark:)`

**Rationale**: The `.css` accessor chains CSS properties fluently. Values use typed CSS units (`.px()`, `.rem()`, `.em()`, `.percent()`). Property names mirror the W3C CSS specification directly [API-NAME-003].

---

### [DOC-MARKUP-013] Custom HTML Views

**Statement**: Create reusable views by conforming to `HTML.View`. Custom views MUST use the Nest.Name pattern per [API-NAME-001].

```swift
// Per [API-NAME-001]: Card is nested within its domain namespace
extension MyApp {
    struct Card: HTML.View {
        let title: String
        let description: String

        var body: some HTML.View {
            div {
                h3 { title }
                p { description }
            }
            .css
            .border(.px(1), .solid, .gray200)
            .borderRadius(.px(8))
            .padding(.px(16))
        }
    }
}

// Usage
HTML.Document {
    MyApp.Card(title: "Feature", description: "Description here")
}
```

**Composition patterns**:
```swift
// Conditional rendering
element.if(condition) { view in
    view.css.color(.red)
}

// Loops
ForEach(items) { item in
    li { item.name }
}

// String content (String conforms to HTML.View)
div { "Direct string content" }
```

**Rationale**: `HTML.View` mirrors SwiftUI's compositional pattern. Views compose via `@HTML.Builder` result builders.

---

## PDF from HTML

### [DOC-MARKUP-020] PDF Document from HTML

**Statement**: Create PDF documents from HTML content using `PDF.Document` with an `@HTML.Builder`.

```swift
import PDF

let document = PDF.Document {
    h1 { "Report Title" }
    p { "Introduction paragraph." }
    h2 { "Section 1" }
    p {
        "Normal text with "
        strong { "bold" }
        " and "
        em { "italic" }
        " formatting."
    }
}

// Serialize to bytes
let bytes = [UInt8](document)
```

**With metadata**:
```swift
let document = PDF.Document(
    info: .init(title: "Annual Report", author: "Engineering"),
    generateOutline: true
) {
    HTML.Document {
        h1 { "Annual Report 2026" }
        h2 { "Q1 Results" }
        p { "..." }
        h2 { "Q2 Results" }
        p { "..." }
    }
}
```

When `generateOutline: true`, H1–H6 headings become PDF bookmarks.

**Rationale**: `PDF.Document` accepts HTML views directly. The same HTML tree renders to PDF via the `PDF.HTML.Context` rendering context.

---

### [DOC-MARKUP-021] PDF Configuration

**Statement**: Configure page layout, typography, and styling via `PDF.HTML.Configuration`.

```swift
let config = PDF.HTML.Configuration(
    paperSize: .a4,                    // .a4, .letter, .legal, .tabloid
    margins: .init(all: 72),           // 72pt = 1 inch
    defaultFont: .helvetica,           // .times, .courier, .helvetica
    defaultFontSize: 11,               // Points
    defaultColor: .black,
    lineHeight: .multiple(1.4),        // .normal, .multiple(N), .lengthPercentage(...)
    table: .init(
        headerBackground: .gray(0.9),
        alternatingRowColor: .gray(0.95)
    ),
    outline: .init(openToLevel: 2)
)

let document = PDF.Document(
    info: .init(title: "Styled Report"),
    configuration: config,
    generateOutline: true
) {
    h1 { "Styled Report" }
    p { "Using Helvetica at 11pt on A4 paper." }
}
```

**Paper sizes**:
- `.a3`, `.a4`, `.a5` (ISO)
- `.letter`, `.legal`, `.tabloid` (US)
- Custom: `PDF.UserSpace.Rectangle(x: .init(0), y: .init(0), width: .init(W), height: .init(H))`

**Fonts** (PDF Standard 14):
- `.times`, `.timesBold`, `.timesItalic`, `.timesBoldItalic`
- `.helvetica`, `.helveticaBold`, `.helveticaOblique`, `.helveticaBoldOblique`
- `.courier`, `.courierBold`, `.courierOblique`, `.courierBoldOblique`

**Rationale**: Configuration is immutable after construction. Defaults match common document conventions (A4, 72pt margins, Times 12pt).

---

### [DOC-MARKUP-022] Headers and Footers

**Statement**: Use two-pass rendering for headers and footers with accurate page numbers.

```swift
let config = PDF.HTML.Configuration(
    paperSize: .a4,
    margins: .init(all: 72),
    header: .init(height: 30),
    footer: .init(height: 30),
    documentTitle: "Annual Report"
)

let pages = PDF.HTML.pages(
    configuration: config,
    header: { pageInfo in
        p { pageInfo.documentTitle ?? "" }
            .css.fontSize(.pt(9)).color(.gray)
    },
    footer: { pageInfo in
        p { "Page \(pageInfo.pageNumber) of \(pageInfo.totalPages)" }
            .css.fontSize(.pt(9)).color(.gray).textAlign(.center)
    },
    content: {
        h1 { "Annual Report" }
        p { "Content here..." }
    }
)

let document = PDF.Document(pages: pages)
```

**`Page.Info` fields**:
- `pageNumber: Int` (1-indexed)
- `totalPages: Int`
- `sectionTitle: String?` (from most recent heading)
- `documentTitle: String?`
- `date: String?`

**Rationale**: Two-pass rendering (pass 1 counts pages, pass 2 renders with headers/footers) provides accurate "Page X of Y" numbering.

---

### [DOC-MARKUP-023] Tables in PDF

**Statement**: HTML tables render to PDF with automatic column sizing, cell spanning, and structure tags for accessibility.

```swift
PDF.Document {
    table {
        thead {
            tr {
                th { "Name" }
                th { "Role" }
                th { "Status" }
            }
        }
        tbody {
            tr {
                td { "Alice" }
                td { "Engineer" }
                td { "Active" }
            }
            tr {
                td { "Bob" }
                td { "Designer" }
                td { "On Leave" }
            }
        }
    }
}
```

Tables support `colspan` and `rowspan` attributes, automatic page breaks between rows, and ISO 32000-2 structure tagging (TH, TD, TR, etc.) for PDF/UA accessibility.

---

### [DOC-MARKUP-024] Lists in PDF

**Statement**: Ordered and unordered lists render with depth-based markers.

```swift
PDF.Document {
    h2 { "Features" }
    ul {
        li { "First item" }
        li {
            "Second item with nested list"
            ul {
                li { "Nested item" }
            }
        }
        li { "Third item" }
    }
    h2 { "Steps" }
    ol {
        li { "Do this first" }
        li { "Then this" }
        li { "Finally this" }
    }
}
```

**Unordered markers by depth**: disc (level 1) -> circle (level 2) -> square (level 3+).
**Ordered markers**: Arabic numerals with period (1. 2. 3.).

---

## Markdown Rendering

### [DOC-MARKUP-030] Markdown to HTML

**Statement**: Use the `Markdown` view to render markdown strings as HTML.

```swift
import HTML

Markdown {
    """
    # Introduction

    This is a **bold** statement with *emphasis*.

    ## Features

    - Type-safe HTML generation
    - CSS styling support
    - PDF rendering pipeline

    ```swift
    let doc = PDF.Document {
        h1 { "Hello" }
    }
    ```
    """
}
```

`Markdown` conforms to `HTML.View`, so it composes anywhere HTML views are accepted:

```swift
HTML.Document {
    header { nav { a(href: "/") { "Home" } } }
    main {
        Markdown {
            """
            # Blog Post
            Content goes here...
            """
        }
    }
    footer { p { "Copyright 2026" } }
}
```

**Rationale**: `Markdown` parses at render time via Apple's swift-markdown. The result builder closure returns a `String`.

---

### [DOC-MARKUP-031] Markdown Configuration

**Statement**: Customize markdown rendering via `Markdown.Configuration` and `Markdown.Rendering`.

```swift
var config = Markdown.Configuration.default
var rendering = Markdown.Rendering.default

// Custom heading style
rendering.elements.heading = .init { input in
    Markdown.Rendering.Frame {
        ContentDivision { Rendering.Frame.Placeholder() }
            .css.borderBottom(.px(1), .solid, .gray300)
            .css.paddingBottom(.rem(0.5))
    }
    .applying(children: input.children)
}

// Custom code block style
rendering.elements.codeBlock = .init { input in
    Markdown.Rendering.Frame {
        PreformattedText {
            Code { Rendering.Frame.Placeholder() }
        }
        .css.backgroundColor(.gray100).padding(.rem(1)).borderRadius(.px(4))
    }
    .applying(children: [.text(input.code)])
}

// Custom slug generator for heading anchors
config.slugGenerator = .prefixed("doc")  // "# Intro" -> id="doc-intro"

Markdown(configuration: config, rendering: rendering) {
    "# Hello World"
}
```

**Rationale**: Configuration separates structure (slug generation, directives) from presentation (element rendering). The `Rendering.Frame` pattern caches static HTML structure for performance.

---

### [DOC-MARKUP-032] Markdown to PDF

**Statement**: Embed `Markdown` views inside `PDF.Document` to render markdown as PDF.

```swift
import PDF

let document = PDF.Document(
    info: .init(title: "Technical Spec"),
    configuration: .init(defaultFont: .helvetica, defaultFontSize: 11),
    generateOutline: true
) {
    Markdown {
        """
        # Technical Specification

        ## Overview
        This document describes the system architecture.

        ## Components
        - **Frontend**: Swift HTML rendering
        - **Backend**: Server-side PDF generation

        ## API Reference

        | Endpoint | Method | Description |
        |----------|--------|-------------|
        | /api/docs | GET | List documents |
        | /api/docs | POST | Create document |
        """
    }
}

let bytes = [UInt8](document)
```

**Rationale**: Because `Markdown` is an `HTML.View`, the same HTML-to-PDF rendering pipeline handles it automatically. Headings become PDF bookmarks when `generateOutline: true`.

---

### [DOC-MARKUP-033] Table of Contents from Markdown

**Statement**: Extract section structure from markdown for navigation using `Markdown.tableOfContents()`.

```swift
let sections = Markdown.tableOfContents(
    from: markdownString,
    configuration: config,
    rendering: rendering
)

// sections: [Markdown.Section]
//   .title: String
//   .id: String (slug)
//   .level: Int (1-6)
//   .timestamp: Timestamp? (for video transcripts)
```

**Rationale**: Useful for generating sidebar navigation, jump links, or PDF outlines from markdown content.

---

### [DOC-MARKUP-034] Block Directives

**Statement**: Use block directives for custom content types in markdown.

Built-in directives:
- `@Button(href)` — Styled link button
- `@Comment` — Suppressed content (invisible in output)
- `@Video(source)` — Video element with controls
- `@T(timestamp)` — Timestamp marker (for transcripts)

**Custom directives**:
```swift
var config = Markdown.Configuration.default
config.directives = .init { directive in
    switch directive.name {
    case "Alert":
        .rendered(HTML.AnyView {
            div {
                strong { "Alert:" }
                directive.children
            }
            .css.backgroundColor(.yellow100).padding(.rem(1))
        })
    default:
        .useDefault
    }
}
```

Markdown usage:
```markdown
@Alert {
This is an important notice.
}
```

**Rationale**: Directives extend markdown with structured content beyond standard CommonMark.

---

## Direct PDF Rendering

### [DOC-MARKUP-040] PDF.View Protocol

**Statement**: For low-level PDF control without HTML, use `PDF.View` and `@PDF.Builder`. Custom views MUST use Nest.Name per [API-NAME-001].

```swift
import PDF_Rendering

// Per [API-NAME-001]: nested within domain namespace
extension Billing {
    struct Invoice: PDF.View {
        var body: some PDF.View {
            PDF.VStack(spacing: 12) {
                PDF.Text("INVOICE")
                PDF.Divider()
                PDF.HStack(spacing: 8) {
                    PDF.Text("Item")
                    PDF.Spacer(width: 200)
                    PDF.Text("Amount")
                }
                PDF.Divider()
            }
        }
    }
}

let config = PDF.Configuration(
    paperSize: .letter,
    margins: .init(all: 72),
    defaultFont: .helvetica,
    defaultFontSize: 10
)

let document = PDF.Document(configuration: config) {
    Billing.Invoice()
}
```

**PDF.View primitives**:
- `PDF.Text("...")` — Text content
- `PDF.VStack(spacing:) { }` — Vertical layout
- `PDF.HStack(spacing:) { }` — Horizontal layout
- `PDF.Spacer(width:)` / `PDF.Spacer(height:)` — Whitespace
- `PDF.Divider()` — Horizontal line
- `PDF.Rectangle(width:height:fill:stroke:)` — Shapes
- `PDF.Element(tag:) { }` — Structure-tagged content (accessibility)

**Rationale**: `PDF.View` gives direct control over PDF layout without the HTML intermediary. Useful for forms, labels, and structured layouts that don't map to HTML semantics.

---

## Writing PDF to Disk

### [DOC-MARKUP-050] Serialization

**Statement**: Serialize PDF documents to bytes or write to files.

```swift
import PDF

let document = PDF.Document { h1 { "Hello" } }

// To byte array
let bytes = [UInt8](document)

// Write to file (via swift-pdf L4)
try document.write(
    to: File("/path/to/output.pdf"),
    options: .init(createIntermediates: true)
)
```

**Rationale**: `[UInt8](document)` is the primary serialization path. File writing is available through the L4 `swift-pdf` package which re-exports `File_System`.

---

## Naming Compliance Notes

### Existing API Compound Identifiers

The rendering pipeline packages pre-date full [API-NAME-002] enforcement. The following compound identifiers are **existing shipped API** and are documented as-is:

| Compound identifier | Package | Status |
|---------------------|---------|--------|
| `defaultFont`, `defaultFontSize`, `defaultColor` | PDF.HTML.Configuration | Existing API |
| `paperSize`, `lineHeight` | PDF.HTML.Configuration | Existing API |
| `documentTitle`, `documentDate` | PDF.HTML.Configuration | Existing API |
| `pageNumber`, `totalPages`, `sectionTitle` | PDF.HTML.Page.Info | Existing API |
| `generateOutline` | PDF.Document init | Existing API |
| `slugGenerator` | Markdown.Configuration | Existing API |

CSS property names (`.fontSize()`, `.backgroundColor()`, `.borderRadius()`, etc.) are **specification-mirroring** per [API-NAME-003] — they match W3C CSS property names (`font-size`, `background-color`, `border-radius`).

### New Code

When creating new document types or extending these packages, follow [API-NAME-001] (Nest.Name) and [API-NAME-002] (no compound identifiers) strictly.

---

## Cross-References

- **naming** skill for type and method naming conventions ([API-NAME-*])
- **implementation** skill for expression style and call-site-first design ([IMPL-*])
- **swift-institute** skill for five-layer architecture ([ARCH-LAYER-*])
- **testing** skill for snapshot testing rendered output ([TEST-*])
