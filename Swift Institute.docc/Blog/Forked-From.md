# Forked from: what heritage means at the Swift Institute

@Metadata {
  @TitleHeading("Swift Institute Blog")
  @PageImage(purpose: card, source: "blog-card", alt: "Swift Institute Blog")
}

In 2018, Point-Free gave the Swift ecosystem a small, durable shape: a phantom-typed wrapper that lets two values share storage without sharing meaning. `User.ID` and `Order.ID` can both be `UInt64` underneath, and the type system still refuses to let them compare equal. The Swift Institute's new package, [`swift-tagged-primitives`][tagged-primitives], exists because that shape is still worth building on. It is a fork of [`pointfreeco/swift-tagged`][pointfreeco-tagged]. If you visit the repo on GitHub, the first thing you see under the title is *forked from pointfreeco/swift-tagged*. That placement matters: this post explains what we mean by *fork*.

## What we inherited

`swift-tagged-primitives` is recognizably descended from Point-Free's library. The struct declaration is `Tagged<Tag, RawValue>`. The functor operations are `map` and a tag-coercion equivalent. The `@inlinable` discipline that makes the wrapper zero-cost at -O is the same discipline. The protocol-conformance set is structurally similar; many of our divergences are principled removals rather than redesigns.

The conceptual debt is real. Point-Free shipped the wrapper pattern publicly in 2018 as [Episode #12](https://www.pointfree.co/episodes/ep12-tagged); the package has been part of the Swift ecosystem ever since. Anything we build on top inherits both the original shape and the choices that gave it staying power.

## Why this fork exists

The Institute fork keeps the shape and constrains the surface. `Tagged<Tag, RawValue>` admits `~Copyable` and `~Escapable` on both parameters, which lets `Tagged<File.Descriptor, Ordinal>` and similar move-only constructs work without losing the wrapper's discipline. Foundation is excluded, because the primitives layer never imports it. Operator forwarding is removed, because the primitives layer treats cross-domain arithmetic as a type error: `Index<Graph> + Index<Bit>` should not compile.

These constraints put the package on a separate path. They are not stylistic preferences; they are structural commitments at the primitives layer.

## How the lineage is encoded

For this fork, we wanted four records to agree: the platform record, the git record, the license record, and the human-facing record.

The **platform record** is the GitHub fork badge — *forked from pointfreeco/swift-tagged*, set by the platform at fork-creation time and persistent across history rewrites.

The **git record** is the parent-pointer chain. [The Institute publication][publication-commit] is a single commit on top of upstream's HEAD-at-fork-time, so a fresh clone walks straight back through to Point-Free's history:

```text
0634a1b Initial publication: swift-tagged-primitives (fork of pointfreeco/swift-tagged)
6a85175 Update package versioning (#90)
eea4bc0 Add conditional import to UUID (#86)
68d4daa Add BitwiseCopyable conditional conformance (#83)
```

The first commit is ours; the rest is upstream. Because the divergence is structural and permanent, upstream changes will be re-authored as Institute commits with upstream SHAs cited, not pulled through as merges. The git graph carries the heritage; it is not a live tracking mechanism.

The **license record** is the combined [`LICENSE.md`][license-combined], which is Apache 2.0 followed by an `## Attribution: pointfreeco/swift-tagged` block that preserves the upstream's MIT copyright and license text verbatim. MIT requires that of any derivative work.

The **human-facing record** is the [README][readme-heritage] heritage paragraph, placed under the one-liner before installation instructions or feature list. The repo announces in its first ten seconds that this is a fork, names the upstream by full path, and points readers at the package's per-dimension rationale.

Four records, one lineage. Each record carries part of the same claim.

## The standard we want to follow

License compliance is the floor. The README is where many developers first meet the package, so the lineage belongs at the top. The parent-pointer chain and the fork badge tell the same story by design, because either signal alone is weaker than both agreeing. The Institute will fork more packages in the future, and each one will encode its lineage in the same four places.

`swift-tagged-primitives` is one package; the standard matters beyond this release. When we fork or derive from existing work, we want the lineage visible to anyone encountering the package. That is what being a good neighbour in the Swift ecosystem means to us.

## References

- [pointfreeco/swift-tagged][pointfreeco-tagged]: the upstream this fork is built on.
- [swift-tagged-primitives][tagged-primitives]: the Institute fork.
- [The publication commit][publication-commit]: single Institute commit on top of the fork-point.
- [LICENSE combined block][license-combined]: Apache 2.0 + MIT attribution shape.
- [README heritage paragraph][readme-heritage]: top-of-README disclosure.

[pointfreeco-tagged]: https://github.com/pointfreeco/swift-tagged
[tagged-primitives]: https://github.com/swift-primitives/swift-tagged-primitives
[publication-commit]: https://github.com/swift-primitives/swift-tagged-primitives/commit/0634a1b
[license-combined]: https://github.com/swift-primitives/swift-tagged-primitives/blob/main/LICENSE.md
[readme-heritage]: https://github.com/swift-primitives/swift-tagged-primitives/blob/main/README.md
