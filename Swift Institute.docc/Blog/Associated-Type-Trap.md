# The associated type trap, and the escape hatch I missed

@Metadata {
  @TitleHeading("Swift Institute Blog")
  @PageImage(purpose: card, source: "blog-card", alt: "Swift Institute Blog")
}

I designed an HTML rendering primitive with the natural name — `associatedtype Body`. It collided with `SwiftUI.View.Body` in any type that tried to bridge the two. My first response was defensive: rename it to `RenderBody`. That fixed the symptom and spread the cost through every conforming type. The better fix turned out to be local: `@_implements` on the bridge type. Getting there meant ruling out three plausible explanations before the compiler behavior finally made sense.

## What I tried

The rendering framework provides an HTML DSL. `Rendering.View` is the primitive protocol all rendering types conform to, analogous to `SwiftUI.View` for UI elements. The natural shape:

```swift
extension Rendering {
    public protocol View: ~Copyable {
        associatedtype Body: View & ~Copyable
        var body: Body { get }
        static func _render(_ view: borrowing Self, context: inout Context)
    }
}
```

`HTML.View` refines `Rendering.View`. `HTML.Document` is the top-level document type with two generic parameters — `Body` and `Head`:

```swift
extension HTML {
    public struct Document<Body: HTML.View, Head: HTML.View>: HTML.Document.`Protocol` {
        public let head: Head
        public let body: Body
    }
}
```

This compiles on its own. The generic parameter `Body` (bounded by `HTML.View`) binds the inherited associated type.

Now the goal: make `HTML.Document` work in a SwiftUI `#Preview`, so rendered HTML can be live-previewed without leaving Xcode.

```swift
#Preview {
    HTML.Document {
        Markdown { "# Hello world" }
    }
}
```

`#Preview` requires its body to be a `SwiftUI.View`. The standard bridge is `NSViewRepresentable`, which refines `SwiftUI.View` with `Self.Body == Never`. Add the conformance:

```swift
extension HTML.Document: NSViewRepresentable
where Body: HTML.View, Head: HTML.View {
    public typealias NSViewType = WKWebView
    public func makeNSView(context: Context) -> WKWebView { /* ... */ }
    public func updateNSView(_ view: WKWebView, context: Context) { /* ... */ }
}
```

It doesn't compile.

```text
error: type 'HTML.Document<Body, Head>' does not conform to protocol 'View'
note: possibly intended match 'HTML.Document<Body, Head>.Body' (aka 'Body')
      does not conform to 'View'
note: protocol requires nested type 'Body'
```

`HTML.Document.Body` is the generic parameter — bounded by `HTML.View`. It does not conform to `SwiftUI.View`. But which `Body` requirement is the compiler talking about? Both protocols declare an associated type called `Body`. Both demand a concrete type. Only one binding is possible.

### Wrong theory 1: MemberImportVisibility

First hypothesis: imports. Maybe the access-level modifiers on `import` declarations are letting `SwiftUI.View` leak into files where `HTML.Document` lives, and the compiler is mistakenly trying to satisfy `SwiftUI.View.Body` with the generic parameter. Five variants permute the import configuration:

| Variant | Import config | MIV | Result |
|---------|--------------|-----|--------|
| V1 | Same file, `public import SwiftUI` | on | Fails |
| V2 | Different file, `public import SwiftUI` | on | Fails |
| V3 | Different file, `public import SwiftUI` | **off** | **Fails** |
| V4 | Different file, `internal import SwiftUI` | on | Fails |
| V5 | Different file, `package import SwiftUI` | on | Fails |

Every variant fails with the identical unification error. The bug is not in the import strategy. ([V1–V5](https://github.com/swift-institute/Experiments/tree/main/member-import-visibility-body-conflict/Sources))

### Wrong theory 2: `@retroactive`

Swift 6 introduced `@retroactive` for cross-module protocol conformances declared outside both the protocol's module and the conforming type's module.

```swift
extension HTML.Document: @retroactive NSViewRepresentable { /* ... */ }
```

The compiler rejects this: `HTML.Document` lives in the same module as the conformance, so `@retroactive` doesn't apply. Different error, same root cause unchanged. ([V7_Retroactive](https://github.com/swift-institute/Experiments/tree/main/member-import-visibility-body-conflict/Sources/V7_Retroactive))

### Wrong theory 3: SE-0491 module selectors

Swift 6.3 added module selectors. You can write `SwiftUI::View` and `Rendering::View` to disambiguate type names.

```swift
extension HTML.Document: Rendering::View, SwiftUI::View { /* ... */ }
```

The compiler accepts the syntax but still fails with the unification error. SE-0491 is explicit about why, in the section on member types of type parameters:

> A member type of a type parameter must not be qualified by a module selector.
>
> This is because, when a generic parameter conforms to two protocols that have associated types with the same name, the member type actually refers to *both* of those associated types. It doesn't make sense to use a module name to select one associated type or the other — it will always encompass both of them.

The compiler diagnostic for the dependent-member form (`SwiftUI::View.Body`) states the same rule directly: *"module selector is not allowed on generic member type; associated types with the same name are merged instead of shadowing one another."*

*Merged*. Not disambiguated. Not shadowed. The syntax position varies; the underlying rule does not. ([V8_ModuleSelectors](https://github.com/swift-institute/Experiments/tree/main/member-import-visibility-body-conflict/Sources/V8_ModuleSelectors))

## Why Swift merges: the mechanism

Swift's rule is unconditional: when a single type conforms to two protocols that each declare an associated type with the same name, the two requirements are unified into one binding. The type provides one concrete type that must satisfy both protocols' constraints simultaneously.

The compiler implements this through an *associated type anchor* — a canonical declaration that same-named associated types in a refinement hierarchy fold into. From [`lib/AST/Decl.cpp`](https://github.com/swiftlang/swift/blob/main/lib/AST/Decl.cpp):

```cpp
auto overridden = ATD->getOverriddenDecls();

// If this declaration does not override any other declarations, it's
// the anchor.
if (overridden.empty()) return const_cast<AssociatedTypeDecl *>(ATD);

// Find the best anchor among the anchors of the overridden decls.
```

The anchor walk is recursive: each associated type declaration checks its overridden chain, and the first declaration with no overrides becomes the canonical anchor. The generic signature builder then uses anchors as the canonical names of dependent member types in conformance constraints.

This is what makes refinements like `Collection: Sequence` work. Both protocols declare `associatedtype Element`. The anchor lookup folds them into a single requirement, so a type conforming to `Collection` provides exactly one `Element`, not two. Without anchors, every refinement chain would have to repeat its associated type bindings.

The same mechanism wedges the `Rendering.View` + `SwiftUI.View` case. Neither protocol refines the other — but the requirement machinery runs *per associated type name on the conforming type*. When both protocols demand a `Body` binding, the solver tries to satisfy both with one type. The constraints fight:

| Source | Constraint on the unified `Body` |
|--------|----------------------------------|
| `Rendering.View` (via `HTML.View`) | `Body: Rendering.View` |
| `NSViewRepresentable` | `Body == Never` |

`Never` does not conform to `Rendering.View`. The generic parameter does not conform to `SwiftUI.View`. Unsatisfiable by construction.

## The escape hatches

### Wrapper (works, taxes you forever)

One option is to route around the collision by not conforming `HTML.Document` to `SwiftUI.View` at all. Expose a `.swiftUIView` property that returns a private wrapper type that does conform:

```swift
#Preview {
    HTML.Document {
        Markdown { "# Hello" }
    }
    .swiftUIView   // ← required at every call site
}
```

This compiles. It's also unacceptable if the design goal is that `HTML.Document` works directly in `#Preview`. A permanent `.swiftUIView` suffix at every call site is an ergonomic tax you've traded a protocol conflict for. ([V9_Wrapper_Escape_Hatch](https://github.com/swift-institute/Experiments/tree/main/member-import-visibility-body-conflict/Sources/V9_Wrapper_Escape_Hatch))

### `@_implements`

`@_implements(Protocol, Name)` lets a declaration satisfy a named requirement of a specific protocol — including associated-type requirements. It's underscored, but not experimental. From [`Features.def`](https://github.com/swiftlang/swift/blob/main/include/swift/Basic/Features.def):

```
BASELINE_LANGUAGE_FEATURE(AssociatedTypeImplements, 0, "@_implements on associated types")
```

`BASELINE_LANGUAGE_FEATURE` means always-on.

Applied to `HTML.Document`:

```swift
public struct Document<Body: HTML.View, Head: HTML.View>: HTML.Document.`Protocol` {
    @_implements(Rendering.View, Body)
    public typealias _RenderingBody = Body   // Rendering.View.Body = Body (generic param)

    // SwiftUI.View.Body = Never is satisfied by NSViewRepresentable's
    // makeNSView / updateNSView witnesses — no stamp needed here.

    public let head: Head
    public let body: Body
}
```

Two same-named associated types, bound to different concrete types, no rename of anyone's protocol. Release-mode verified: `-Onone`, `-O`, and `-O -whole-module-optimization` all dispatch correctly — the two witness tables resolve `Self.Body` independently per protocol. Works under `~Copyable` + `SuppressedAssociatedTypes`, which matches the `Rendering.View` shape exactly. ([V11_Implements](https://github.com/swift-institute/Experiments/tree/main/member-import-visibility-body-conflict/Sources/V11_Implements))

Three caveats worth naming:

1. **Stable in practice, underscored in status.** Always-on baseline feature. The underscore signals "not part of the promoted API surface"; it doesn't mean unstable. If Apple ever promotes this to `@implements`, the syntax is straightforward to migrate.
2. **Per-bridge-type boilerplate.** The cost is local, not global. If only a few bridge types hit the collision, this is usually the right trade. If many do, the repetition becomes a design signal worth reevaluating.
3. **You must own the conforming type.** The stamp lives in the type's own declaration.

## What I actually shipped

Walking back the `RenderBody` rename was the first step. The rename was defensive — it pushed a collision concern into the protocol's own API and forced every conformer to carry a compound name motivated by a problem only a small number of types actually hit. `@_implements` meant I could handle the collision where it actually happens — at a conforming type that bridges two frameworks — and let the protocol keep its idiomatic name. So:

1. Renamed `associatedtype RenderBody` → `associatedtype Body` on the protocol.
2. Cascaded the rename through every conforming type (`typealias Body = Never`).
3. Added `@_implements` to `HTML.Document`, the type that bridges the two `View` protocols.

Step 3 is where I went down a dead end.

### The dead end: narrowing candidates

The single-stamp shape above compiles in isolation. Added to the real package, it doesn't:

```text
error: type 'HTML.Document<Body, Head>' does not conform to protocol 'Rendering.View'
note: multiple matching types named 'Body'
note: possibly intended match 'HTML.Document<Body, Head>._RenderingBody' (aka 'Body')
```

"Multiple matching types" suggests name ambiguity. I tried narrowing candidates: renamed the generic parameter to something distinctive, looked for other types named `Body` in the package's imports, tightened what was in scope. Nothing flipped the error. Each narrowing move left another candidate visible or exposed a different one. The compiler kept seeing "multiple matching types" no matter what I hid.

### The fix: two `@_implements` stamps

The `@_implements(Rendering.View, Body)` stamp splits `Rendering.View`'s `Body` requirement, but `SwiftUI.View`'s `Body` requirement is still being resolved through default inference — and default inference still sees the unified binding. The fix is to split *both* protocols' requirements, with one stamp each:

```swift
public struct Document<Body: HTML.View, Head: HTML.View>: HTML.Document.`Protocol` {
    @_implements(Rendering.View, Body)
    public typealias _RenderingBody = Body

    #if canImport(SwiftUI)
    @_implements(SwiftUI.View, Body)
    public typealias _SwiftUIBody = Never
    #endif

    public let head: Head
    public let body: Body
    // ...
}
```

The generic parameter goes back to `Body`. Two stamps, one per protocol. Release mode, 150/150 tests pass, `#Preview` works. ([V12_ImplementsBridge](https://github.com/swift-institute/Experiments/tree/main/member-import-visibility-body-conflict/Sources/V12_ImplementsBridge) mirrors the two-stamp shape in minimal form; [applied in swift-html-rendering](https://github.com/swift-foundations/swift-html-rendering/blob/main/Sources/HTML%20Rendering%20Core/HTML.Document.swift))

That was the part I had missed: the diagnostic pushed me toward narrowing candidates, but the real fix was to pin the second protocol requirement explicitly.

## Takeaway

Same-named associated types unify unconditionally. This is a deliberate language property — it's what makes refinement chains work cleanly. You cannot disambiguate through imports, module selectors, or `@retroactive`. The compiler source says so, and SE-0491 says so in plain language.

Three responses, each for a different role:

| Where you are | Tool |
|---------------|------|
| You design the protocol | Pick the idiomatic name. `Body` is fine. Don't pre-optimize for hypothetical collisions. |
| You design a conforming type that bridges two protocols | `@_implements(Protocol, Name)` — one or two stamps at the bridge type, zero cost elsewhere. When in doubt, stamp both. |
| You need a fallback and can tolerate call-site ceremony | Wrapper with a `.someView` or `.swiftUIView` property — ergonomic tax per call site. |

Two meta-lessons:

- **Defensive naming at the protocol declaration is optimizing for the wrong thing.** Same-named-associated-type collisions are a property of individual conforming types — solve them there. The property name `body` was always fine; only the *associated type* name needed handling, and only at bridge types.
- **If `@_implements` produces "multiple matching types," suspect another unpinned protocol requirement before you start narrowing names.**

## References

- [SE-0491: Module selectors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0491-module-selectors.md) — cannot disambiguate merged associated types
- Swift compiler: [`lib/AST/Decl.cpp`](https://github.com/swiftlang/swift/blob/main/lib/AST/Decl.cpp) — `AssociatedTypeDecl::getAssociatedTypeAnchor`
- Swift compiler: [`lib/Sema/TypeCheckType.cpp`](https://github.com/swiftlang/swift/blob/main/lib/Sema/TypeCheckType.cpp) — `resolveDependentMemberType` rejects module selectors on dependent member types
- Swift compiler: [`include/swift/AST/DiagnosticsSema.def`](https://github.com/swiftlang/swift/blob/main/include/swift/AST/DiagnosticsSema.def) — `module_selector_dependent_member_type_not_allowed`
- Swift compiler: [`include/swift/Basic/Features.def`](https://github.com/swiftlang/swift/blob/main/include/swift/Basic/Features.def) — `BASELINE_LANGUAGE_FEATURE(AssociatedTypeImplements, 0, ...)`
- Swift compiler: [`UnderscoredAttributes.md`](https://github.com/swiftlang/swift/blob/main/docs/ReferenceGuides/UnderscoredAttributes.md) — `@_implements(ProtocolName, Requirement)`
- Experiment: [`member-import-visibility-body-conflict`](https://github.com/swift-institute/Experiments/tree/main/member-import-visibility-body-conflict) — twelve variants. V1–V5 prove `MemberImportVisibility` is innocent; V7 covers `@retroactive`; V8 covers SE-0491 module selectors; V9 demonstrates the wrapper escape hatch; V6/V10 show rename approaches; V11 demonstrates single-stamp `@_implements`; V12 demonstrates the two-stamp production pattern.
- Applied fix: [`swift-html-rendering/HTML.Document.swift`](https://github.com/swift-foundations/swift-html-rendering/blob/main/Sources/HTML%20Rendering%20Core/HTML.Document.swift) — two-stamp production pattern in situ
