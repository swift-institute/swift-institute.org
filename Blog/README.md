# Blog

Blog posts for the Swift Institute, following a receipts-based workflow.

## Directory structure

| Directory | Purpose |
|-----------|---------|
| `Draft/` | Posts being written or awaiting publication |
| `Review/` | Posts under review |
| `Published/` | Posts that have been published externally |
| `Series/` | Series plans grouping related posts |

## Current state

`Published/` and `Review/` are currently empty. The first two drafts
(`restarting-the-blog-final.md`, `associated-type-trap-final.md`) are
staged for publication once the repository goes public. They will move
to `Published/` with their publication dates set in frontmatter.

## Naming convention

The `-final` suffix on draft filenames indicates a draft that has
completed internal review and is ready for publication, pending
external gating (e.g., the repository being made world-readable so
receipt links resolve). The directory (`Draft/`) encodes lifecycle
phase; the suffix encodes review completeness within that phase.

## Workflow

See the [`blog-process`](../Skills/blog-process/SKILL.md) skill for
the full two-phase drafting and review workflow, the ideas index at
[`_index.md`](_index.md), and the style guide at
[`_Styleguide.md`](_Styleguide.md).
