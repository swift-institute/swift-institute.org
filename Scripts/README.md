# Scripts

Automation scripts used by the swift-institute maintenance workflow. All
scripts target a local developer checkout of the Swift Institute ecosystem
(`swift-primitives`, `swift-standards`, `swift-foundations`, plus the
per-authority organizations and `swift-institute` itself) sitting in a
flat layout under a single parent directory.

## Scripts

| Script | Purpose |
|--------|---------|
| `ecosystem-timeline.sh` | Scan every Swift ecosystem repository and write per-repo commit chronology to CSV for release-reporting and blog posts |
| `sync-gitignore.sh` | Regenerate `.gitignore` files across every repo from the canonical + per-repo overrides defined inside the script |
| `sync-skills.sh` | Refresh `.claude/skills/` symlinks for repos that do not yet use the submodule-based skill-sharing setup |
| `sync-swift-settings.sh` | Standardize the `for target in package.targets { ... }` Swift-settings loop across every `Package.swift` in the ecosystem |

## Assumptions

- The scripts are executed from within `swift-institute/` (via
  `./Scripts/{name}.sh`). `SCRIPT_DIR` resolves the script's own
  location, and `DEVELOPER_DIR` is the parent of `swift-institute/`.
- Sibling repositories live at `$DEVELOPER_DIR/swift-*`. The scripts
  silently skip any missing directory.
- `sync-skills.sh` reads symlink targets from a local Claude skills
  directory that is not part of the public repository. External
  contributors can ignore this script.
- Several scripts take a `--dry-run` flag; see each script's header for
  its specific flags.

## Running

```sh
./Scripts/sync-gitignore.sh --dry-run
./Scripts/ecosystem-timeline.sh
```

These are one-shot maintenance utilities, not part of the CI pipeline.
