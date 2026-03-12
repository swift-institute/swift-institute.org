# Blog styleguide

Style conventions for Swift Institute blog posts, extracted from industry research and best-in-class technical writing standards.

## Overview

**Scope**: Formatting, voice, and structural conventions for all Swift Institute blog posts.

**Goal**: Create blog posts that feel human, engaging, and accessible while maintaining technical rigor.

**Applies to**: All posts in `Blog/Draft/`, `Blog/Review/`, and `Blog/Published/`.

**Research basis**:
- [Best-in-Class Blog Post Pattern](../Research/Best-in-Class%20Blog%20Post%20Pattern.md)
- [Google Developer Documentation Style Guide](https://developers.google.com/style)
- [Draft.dev Technical Blogging Style Guide](https://draft.dev/learn/styleguide)
- [Apple Style Guide](https://help.apple.com/pdf/applestyleguide/en_US/apple-style-guide.pdf)

---

## Voice and tone

### Second person by default

**Statement**: Address readers directly using "you" and "your." Reserve "we" for actions taken by Swift Institute specifically.

Every major style guide—[Google](https://developers.google.com/style/person), [Microsoft](https://www.microsoft.com/en-us/microsoft-365-life-hacks/writing/sentence-case-vs-title-case), [Apple](https://help.apple.com/pdf/applestyleguide/en_US/apple-style-guide.pdf), and [Draft.dev](https://draft.dev/learn/styleguide)—recommends second person for developer content. It creates engagement and puts the reader at the center.

| Correct | Incorrect |
|---------|-----------|
| "You can create a pointer wrapper..." | "We can create a pointer wrapper..." |
| "Your base type determines..." | "Our base type determines..." |
| "If you need borrowing access..." | "If one needs borrowing access..." |

**When to use "we"**:
- Speaking on behalf of Swift Institute: "We discovered this during our experiment..."
- Describing shared experience: "We've all encountered this error..."
- **Exploring together**: In posts that follow the first-principles writing pattern [BLOG-010], "we" is appropriate when guiding the reader through a journey of discovery: "Let's try this... we get a compiler error... so we need to..." This creates the sense of joint exploration that makes the pattern work. Use "we" for the shared journey and "you" for direct instructions.

### Conversational, not casual

**Statement**: Write as you would explain to a colleague—professional but approachable. Avoid both stiff academic prose and excessive informality.

| Do | Don't |
|----|-------|
| "This fails because..." | "This fails due to the fact that..." |
| "Let's look at why" | "We shall now examine the causative factors" |
| "Here's the key insight" | "yo check this out" |

Per [Google's style guide](https://developers.google.com/style/highlights): "Be conversational and friendly without being frivolous."

### Avoid gatekeeping language

**Statement**: Never use language that makes readers feel inadequate. Phrases like "simply," "obviously," "just," or "of course" imply the reader should already know—and alienate those who don't.

| Avoid | Write instead |
|-------|---------------|
| "Simply add the constraint" | "Add the constraint" |
| "Obviously, this requires Escapable" | "This requires Escapable" |
| "Just use a borrowing API" | "Use a borrowing API" |
| "As everyone knows..." | [Omit and state the fact] |

**Rationale**: [Draft.dev](https://draft.dev/learn/styleguide) explicitly warns against gatekeeping language. Accessible content serves developers at all experience levels.

### Active voice

**Statement**: Use active voice to clarify who performs actions. Passive voice obscures agency and creates weaker prose.

| Active (preferred) | Passive (avoid) |
|--------------------|-----------------|
| "The compiler detects escape" | "Escape is detected by the compiler" |
| "You create a pointer wrapper" | "A pointer wrapper is created" |
| "Swift requires Escapable" | "Escapable is required" |

Per [Apple Style Guide](https://help.apple.com/pdf/applestyleguide/en_US/apple-style-guide.pdf): Avoid "The setup assistant is displayed." Prefer "The setup assistant appears."

---

## Headings

### Sentence case

**Statement**: All headings MUST use sentence case. Capitalize only the first word and proper nouns.

This aligns with [Google Developer Documentation Style Guide](https://developers.google.com/style/headings): "Use sentence case for all headings and titles."

| Correct | Incorrect |
|---------|-----------|
| `# Why you can't build a ~Escapable Pointer` | `# Why You Can't Build a ~Escapable Pointer` |
| `## The problem` | `## The Problem` |
| `## What we found` | `## What We Found` |
| `### How this manifests` | `### How This Manifests` |

**Why sentence case?** Per [technical writing research](https://resources.ascented.com/ascent-blog/technical-writing-tip-title-case-vs-sentence-case):
- Easier to read, especially for non-native English speakers
- Eliminates ambiguity about which words to capitalize
- More accessible and modern
- Aligns with Google, Microsoft, and international standards

### Proper nouns

**Statement**: Proper nouns retain their capitalization within sentence case headings.

| Correct | Incorrect |
|---------|-----------|
| `### Property.View requires Escapable` | `### property.view requires escapable` |
| `### UnsafeMutablePointer works for ~Copyable` | `### unsafemutablepointer works for ~copyable` |
| `## Swift Evolution proposals` | `## swift evolution proposals` |

**Proper nouns include**:
- Swift type names: `Escapable`, `Copyable`, `UnsafeMutablePointer`, `Builtin.load`
- Protocol names: `Sequence`, `Collection`, `BorrowingIteratorProtocol`
- Language features: Swift, Swift Evolution
- Project names: swift-primitives, Property.View

### Heading structure

**Statement**: Per [Google's guidelines](https://developers.google.com/style/headings):
- Each page MUST have exactly one H1 heading
- Don't skip heading levels (no jumping from H1 to H3)
- Never create empty headings with no content following

| Post length | Minimum H2 headings |
|-------------|---------------------|
| < 500 words | 2–3 |
| 500–1000 words | 3–5 |
| 1000–2000 words | 5–7 |
| > 2000 words | 7+ |

### Heading content

**Statement**: Start task-based headings with bare infinitive verbs. Use noun phrases for conceptual headings.

| Type | Example |
|------|---------|
| Task-based | "Create a pointer wrapper", "Test with ~Copyable values" |
| Conceptual | "The pointer support matrix", "Implications for library design" |

**Avoid**:
- Starting with "-ing" verbs: ~~"Creating a pointer wrapper"~~
- Putting code in headings when avoidable
- Links within headings (confuses styling)

---

## Titles

### Blog post titles

**Statement**: Blog post titles MUST use sentence case and signal specific value.

```yaml
# Correct
title: Why you can't build a ~Escapable Pointer (and what Builtin.load teaches us)

# Incorrect
title: Why You Can't Build a ~Escapable Pointer (And What Builtin.load Teaches Us)
```

### Title types

| Type | Example | When to use |
|------|---------|-------------|
| **Problem statement** | "Why you can't build a ~Escapable Pointer" | Technical Deep Dive, Lessons Learned |
| **Surprising fact** | "Builtin.load requires both Copyable and Escapable" | Technical Deep Dive |
| **Question** | "Why does Comparable require exact ownership matching?" | Technical Deep Dive |
| **Promise** | "A complete guide to conditional Copyable" | Tutorial |
| **Announcement** | "Introducing swift-heap-primitives 1.0" | Announcement |

**Avoid**:
- Vague titles: "Working with Swift", "Some thoughts on pointers"
- Clickbait: "You won't believe what Builtin.load does!"
- Excessive length: Keep under 70 characters

---

## Introductions

### Strong openings

**Statement**: The title plus first three sentences MUST establish who the post is for and what they'll gain.

Per [Refactoring English](https://refactoringenglish.com/chapters/write-blog-posts-developers-read/): "Give yourself the title plus your first three sentences to establish (1) whether the piece targets the reader and (2) what benefit they'll gain."

**Correct**:
```markdown
If you're building a pointer-backed buffer, a `Property.View`-style wrapper,
or any generic abstraction over Swift's new ownership types, you will eventually
try to support `~Escapable`. You will fail—not because the API is missing, but
because a pointer to a `~Escapable` value is a contradiction under Swift's
current type system.

This post explains why, what we learned attempting it, and what it means for
library design.
```

**Incorrect**:
```markdown
Swift is a powerful programming language. In this blog post, we will explore
some interesting aspects of pointers and ownership that developers might find
useful when working with various types.
```

### Avoid filler openings

**Statement**: Cut directly to content. No filler phrases.

| Avoid | Write instead |
|-------|---------------|
| "In this blog post, we will discuss..." | [Start with the content] |
| "Today we're going to look at..." | [Start with the content] |
| "Let me start by saying..." | [Start with the content] |
| "Before we begin, I should mention..." | [Integrate or omit] |

---

## Code blocks

### Language identifiers

**Statement**: All code blocks MUST specify a language identifier.

````markdown
```swift
// Correct: Language specified
func example() { }
```
````

### Code requirements

**Statement**: Code examples MUST be complete, tested, and minimal. Per Pattern 3 (Working Code).

| Requirement | Implementation |
|-------------|----------------|
| Language identifier | Always specify: ` ```swift ` |
| Completeness | Runnable without missing context |
| Tested | Verified to compile and produce stated output |
| Minimal | Only code necessary for the concept |
| Line length | Max 80 characters (no horizontal scroll) |
| Swift version | Note if version-specific: `// Swift 6.2+` |

Per [MDN Code Style Guide](https://developer.mozilla.org/en-US/docs/MDN/Writing_guidelines/Code_style_guide): "Readers will copy and paste examples into their own code and may put it into production."

### Code explanation

**Statement**: Code blocks MUST be accompanied by explanatory text. Never assume readers understand without explanation.

**Correct**:
```markdown
The `borrowing` modifier prevents copying the parameter:

```swift
// Swift 6.0+
func process(_ value: borrowing LargeStruct) {
    print(value.data)  // Read-only access, no copy
}
```

Without `borrowing`, Swift would copy `LargeStruct` on every call.
```

**Incorrect**:
```markdown
Here's the code:

```swift
func process(value) {
    // do stuff
}
```

This shows processing.
```

### Cautionary code samples

**Statement**: When showing a code sample to illustrate *why not* to do something, add a framing sentence immediately after the code block — before any analysis. Readers will otherwise assume the sample is prescriptive.

**Correct**:
```markdown
```swift
init(from decoder: any Decoder) throws(DecodingError) {
    // ... preconditionFailure in catch-all ...
}
```

This example is intentionally cautionary, not prescriptive: the catch-all
exists to show why narrowing this conformance is usually not worth it.

The wrapping works, but the cost is high:
```

**Incorrect**:
```markdown
```swift
init(from decoder: any Decoder) throws(DecodingError) {
    // ... preconditionFailure in catch-all ...
}
```

The wrapping works, but the cost is high:
```

In the incorrect version, the reader reaches the cost analysis only after absorbing the pattern as if it were recommended.

---

## Inline code

### Code references

**Statement**: Use backticks for all code elements. Preserve exact casing.

| Correct | Incorrect |
|---------|-----------|
| `Builtin.load` | `builtin.load`, Builtin.load |
| `~Escapable` | `~escapable`, ~Escapable |
| `UnsafeMutablePointer` | `unsafemutablepointer` |
| `withUnsafeMutablePointer(to:_:)` | `withUnsafeMutablePointer` |

### When to use backticks

| Use backticks | Don't use backticks |
|---------------|---------------------|
| Type names: `String`, `Int` | Concepts: "the string", "an integer" |
| Function names: `process()` | General references: "the process function" |
| Parameters: `value` | Natural language: "the value parameter" |
| Keywords: `borrowing`, `consuming` | When discussing generally |
| File paths: `Sources/main.swift` | Directory concepts: "the Sources directory" |

---

## Tables

### When to use tables

**Statement**: Use tables when comparing 2+ options or presenting structured data.

| Use tables for | Don't use tables for |
|----------------|---------------------|
| Feature comparisons | Single items |
| Support matrices | Prose explanations |
| Decision summaries | Sequential steps (use numbered lists) |
| Quick reference | Long-form content |

### Table formatting

**Statement**: Tables MUST have a header row and consistent alignment.

```markdown
| Type constraints | UnsafeMutablePointer | Builtin.load |
|------------------|---------------------|--------------|
| Copyable & Escapable | ✓ | ✓ |
| ~Copyable & Escapable | ✓ | ✗ |
```

Use `✓` and `✗` for boolean values, not "Yes"/"No" or checkboxes.

---

## Lists

### Bulleted lists

**Statement**: Use bulleted lists for unordered items (3+ items). Items SHOULD be parallel in structure.

**Correct**:
```markdown
The pattern requires:
- Complete, tested code examples
- Explanatory text for each block
- Swift version annotations where relevant
```

**Incorrect**:
```markdown
The pattern requires:
- You need complete code
- Explanatory text
- Swift versions should be noted
```

### Numbered lists

**Statement**: Use numbered lists for sequential steps or ranked items.

```markdown
1. Define the type constraints
2. Implement the pointer wrapper
3. Test with ~Copyable values
```

---

## Emphasis

### Bold text

**Statement**: Use bold for key terms and emphasis. Maximum 1–3 bold phrases per paragraph.

**Correct**:
```markdown
A pointer to a `~Escapable` value is a **structural contradiction** in Swift's type system.
```

**Incorrect**:
```markdown
A **pointer** to a **~Escapable** **value** is a **structural** **contradiction**.
```

### Italic text

**Statement**: Use italics for introducing terms or light emphasis.

```markdown
The problem is *having* the pointer, not *using* it.
```

### Bold vs italic

| Use bold for | Use italic for |
|--------------|----------------|
| Key concepts: **structural contradiction** | Introducing terms: *non-addressability* |
| Critical warnings | Light emphasis |
| Table headers | Book/document titles |

---

## Blockquotes

### Rule of thumb callouts

**Statement**: Use blockquotes for memorable takeaways or rules of thumb.

```markdown
> If you think you want a pointer to a `~Escapable` value, you actually want a borrowing API.
```

### Attribution

**Statement**: When quoting external sources, include attribution.

```markdown
> "Give yourself the title plus your first three sentences to establish whether the piece targets the reader."
> — Refactoring English
```

---

## Links

### Internal links

**Statement**: Use relative paths for internal links.

```markdown
See the **blog-process** skill for the workflow.
```

### External links

**Statement**: Use descriptive link text. Avoid "click here" or bare URLs.

| Correct | Incorrect |
|---------|-----------|
| [SE-0446: Nonescapable types](https://...) | [https://github.com/...](https://...) |
| the [Swift Forums discussion](https://...) | click [here](https://...) |

### Reference sections

**Statement**: All posts MUST include a References section with source links.

```markdown
## References

- [SE-0390: Noncopyable structs and enums](https://github.com/swiftlang/swift-evolution/...)
- [SE-0446: Nonescapable types](https://github.com/swiftlang/swift-evolution/...)
```

---

## Visual anchors

### Frequency

**Statement**: Posts SHOULD include visual elements every ~300 words.

| Post length | Minimum visuals |
|-------------|-----------------|
| < 500 words | 1–2 |
| 500–1000 words | 2–4 |
| 1000–2000 words | 4–6 |
| > 2000 words | 6+ |

### Visual element types

| Type | When to use |
|------|-------------|
| Code blocks | Demonstrating implementation |
| Tables | Comparing options, support matrices |
| Diagrams | Explaining architecture, flow |
| Terminal output | Showing command results |

**Note**: Code blocks and tables count as visual anchors.

---

## Perspective and authenticity

### Explain "why," not just "what"

**Statement**: Include your perspective on *why* something works a certain way. This distinguishes blog posts from documentation.

Per [Mixmax Engineering](https://www.mixmax.com/engineering/how-to-write-an-engineering-blog-post): "What makes a great post is the author's view on why something ought to work a certain way."

**Correct**:
```markdown
We chose phantom generics because they provide type safety without runtime
overhead. The trade-off is that the generic parameter can feel unusual at first.
```

**Incorrect**:
```markdown
Use phantom generics for index types.
```

### Discuss trade-offs

**Statement**: Present both advantages and disadvantages. Honest trade-off discussion builds credibility.

Per [eatonphil](https://notes.eatonphil.com/2024-04-10-what-makes-a-great-tech-blog.html): "Discuss trade-offs. Present both advantages and disadvantages to build credibility."

### Be honest about limitations

**Statement**: Document what doesn't work and why. Acknowledge uncertainty where it exists.

| Do | Don't |
|----|-------|
| "This approach doesn't work when..." | Pretend limitations don't exist |
| "We're not certain why, but..." | Guess without acknowledging uncertainty |
| "The workaround has drawbacks..." | Present workarounds as perfect solutions |

---

## Anti-patterns

### Content anti-patterns

| Anti-pattern | Problem | Fix |
|--------------|---------|-----|
| Burying the lede | Value unclear until halfway | Lead with the insight |
| Wall of text | No visual breaks | Add headings, code, visuals |
| Incomplete code | Examples don't compile | Test all code |
| Missing "why" | Describes what, not why | Add perspective, trade-offs |
| No takeaway | Reader gains nothing actionable | Add practical application |
| Assumed context | Reader lacks background | Provide necessary context |

### Style anti-patterns

| Anti-pattern | Example | Fix |
|--------------|---------|-----|
| Clickbait | "You won't believe..." | Honest, specific titles |
| Gatekeeping | "Simply", "Obviously" | Remove qualifying words |
| Excessive hedging | "might possibly maybe" | Confident statements |
| Unexplained jargon | "ARC with COW semantics" | Define on first use |
| Apologizing | "Sorry this is long" | Edit to appropriate length |
| Filler phrases | "In this post we will..." | Cut directly to content |

---

## Quick reference

### Pre-submission checklist

Before submitting for review:

- [ ] Title uses sentence case and signals specific value
- [ ] Opening 3 sentences identify audience and benefit
- [ ] All headings use sentence case
- [ ] Second person ("you") used throughout
- [ ] No gatekeeping language ("simply", "obviously")
- [ ] All code blocks have language identifiers
- [ ] All code is tested and compiles
- [ ] Code blocks have explanatory text
- [ ] Inline code uses backticks with correct casing
- [ ] Links use descriptive text
- [ ] References section included
- [ ] Visual elements every ~300 words
- [ ] Trade-offs and "why" explained
- [ ] Practical takeaway included

### Pattern compliance

| Pattern | Styleguide sections |
|---------|---------------------|
| 1. Immediate Value Signal | Titles, Introductions |
| 2. Scannable Structure | Headings, Tables, Lists |
| 3. Working Code | Code blocks |
| 4. Authentic Perspective | Voice and tone, Perspective |
| 5. Practical Takeaway | (See Blog Post Process) |
| 6. Visual Anchors | Visual anchors |
| 7. Professional Polish | All sections |

---

## References

### Primary sources

- [Google Developer Documentation Style Guide](https://developers.google.com/style) — Comprehensive technical writing standard
- [Draft.dev Technical Blogging Style Guide](https://draft.dev/learn/styleguide) — Developer blog-specific conventions
- [Apple Style Guide](https://help.apple.com/pdf/applestyleguide/en_US/apple-style-guide.pdf) — Apple terminology and conventions
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) — Swift naming conventions

### Research

- [Best-in-Class Blog Post Pattern](../Research/Best-in-Class%20Blog%20Post%20Pattern.md) — Seven patterns from industry analysis
- [What makes a great tech blog](https://notes.eatonphil.com/2024-04-10-what-makes-a-great-tech-blog.html) — Phil Eaton
- [Write blog posts developers read](https://refactoringenglish.com/chapters/write-blog-posts-developers-read/) — Refactoring English
- [Title case vs sentence case](https://resources.ascented.com/ascent-blog/technical-writing-tip-title-case-vs-sentence-case) — Ascent Technical Writing
