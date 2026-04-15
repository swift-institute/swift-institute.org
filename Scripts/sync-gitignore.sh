#!/bin/zsh
# sync-gitignore.sh - Synchronize .gitignore files across all repos
#
# Usage: ./Scripts/sync-gitignore.sh [--dry-run]
#
# This script standardizes .gitignore files across the Swift Institute ecosystem.
#
# Settings are split into two categories:
#   - canonical: Universal rules shared by ALL packages
#   - package:   Package-specific overrides (extra whitelisted dirs, etc.)
#
# The script generates complete .gitignore files. The canonical section is
# identical everywhere; package-specific overrides are appended after it.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTITUTE_ROOT="$(dirname "$SCRIPT_DIR")"
DEVELOPER_DIR="$(dirname "$INSTITUTE_ROOT")"

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# ── Canonical .gitignore rules ───────────────────────────────────────────────
# These are applied to ALL packages. Edit this block to change ecosystem-wide rules.

CANONICAL_LINES=(
    '# ========== CANONICAL (auto-synced, do not edit) =========='
    '# Source: swift-institute/Scripts/sync-gitignore.sh'
    ''
    '*~'
    '.DS_Store'
    ''
    'Package.resolved'
    'DerivedData/'
    'Thumbs.db'
    ''
    '# Dot files/directories (opt-in only)'
    '/.*'
    '!/.github'
    '!/.gitignore'
    '!/.spi.yml'
    '!/.swift-format'
    '!/.swiftformat'
    '!/.swiftlint.yml'
    '!/.swiftlint/'
    ''
    '# Top-level entries (opt-in only)'
    '# First ignore all, then whitelist specific folders and files'
    '/*'
    '!/Sources/'
    '!/Tests/'
    '!/Benchmarks/'
    '!/Experiments/'
    '!/Research/'
    '!/Skills/'
    '!/.github/'
    '!/Package.swift'
    '!/LICENSE.md'
    '!/README.md'
    ''
    '# Documentation (opt-in for whitelisted .md files and .docc catalogs only)'
    '# Blocks all .md files by default to prevent AI-generated content from being committed'
    '*.md'
    '!README.md'
    '!LICENSE.md'
    '!CHANGELOG.md'
    '!CONTRIBUTING.md'
    '!CODE_OF_CONDUCT.md'
    '!SECURITY.md'
    '!CLAUDE.md'
    '!**/*.docc/**/*.md'
    '!**/Research/**/*.md'
    '!**/Experiments/**/*.md'
    '!**/Skills/**/*.md'
    ''
    '# Package insights are non-normative working logs accumulating through'
    '# reflections-processing. They stay on disk for the author but do not ship.'
    '**/_Package-Insights.md'
    ''
    '# Research working-artifact prevention: underscore-prefixed and prompt dirs'
    '# are non-canonical and must not ship. _archived/ is the one allowed'
    '# exception (holds SUPERSEDED research per [META-005]).'
    '/Research/_*/'
    '!/Research/_archived/'
    '/Research/prompts/'
    ''
    '*.pdf'
    ''
    '# SwiftLint'
    '**/.swiftlint/RemoteConfigCache'
    ''
    '# Swift Package Manager'
    '.build/'
    '.swiftpm/'
    '.benchmarks/'
    ''
    '# ========== END CANONICAL =========='
)

# ── Package-specific overrides ───────────────────────────────────────────────
# Returns lines to append after the canonical section.
# Each line is printed on its own line. Empty string = no overrides.

package_overrides() {
    local pkg_name="$1"
    local repo_name="$2"   # parent repo: swift-primitives, swift-standards, etc.
    local is_parent="$3"   # "parent" if this is a monorepo root, "" otherwise

    # ── Monorepo parents ──
    if [[ "$is_parent" == "parent" ]]; then
        case "$pkg_name" in
            swift-primitives)
                cat <<'OVERRIDES'

# Monorepo structure
!/swift-*/
!/Scripts/
!/Documentation.docc/
!/.gitmodules
OVERRIDES
                ;;
            swift-standards)
                cat <<'OVERRIDES'

# Monorepo structure
!/swift-*/
!/Scripts/
!/Documentation.docc/
OVERRIDES
                ;;
            swift-foundations)
                cat <<'OVERRIDES'

# Monorepo structure
!/swift-*/
!/Scripts/
!/Documentation.docc/
!/.gitmodules
OVERRIDES
                ;;
            swift-institute)
                cat <<'OVERRIDES'

# Institute directories
!/Audits/
!/Blog/
!/Documentation.docc/
!/Scripts/
!/Swift Evolution/

# Additional markdown whitelists
!**/Audits/**/*.md
!**/Blog/**/*.md
!**/Documentation.docc/**/*.md
!**/Swift Evolution/**/*.md
OVERRIDES
                ;;
        esac
        return
    fi

    # ── Sub-repo overrides ──
    # (none currently — add cases here as needed)
}

# ── Repository roots to process ──────────────────────────────────────────────

REPOS=(
    "$DEVELOPER_DIR/swift-primitives"
    "$DEVELOPER_DIR/swift-standards"
    "$DEVELOPER_DIR/swift-foundations"
)

# ── Helper: write .gitignore to a file ───────────────────────────────────────

write_gitignore() {
    local pkg_name="$1"
    local repo_name="$2"
    local is_parent="$3"
    local out_file="$4"

    {
        # Write canonical section
        for line in "${CANONICAL_LINES[@]}"; do
            echo "$line"
        done

        # Write overrides section header
        echo ''
        echo '# ========== LOCAL OVERRIDES =========='
        echo '# Package-specific rules below (managed by sync-gitignore.sh)'

        # Write package-specific overrides
        package_overrides "$pkg_name" "$repo_name" "$is_parent"

        # Trailing newline
        echo ''
    } > "$out_file"
}

# ── Main: process a single repo ─────────────────────────────────────────────

process_repo() {
    local target_file="$1"
    local pkg_name="$2"
    local repo_name="$3"
    local is_parent="$4"

    local new_file
    new_file="$(mktemp)"
    write_gitignore "$pkg_name" "$repo_name" "$is_parent" "$new_file"

    if [ -f "$target_file" ]; then
        if diff -q "$target_file" "$new_file" > /dev/null 2>&1; then
            rm -f "$new_file"
            return 1  # no change
        fi
    fi

    if $DRY_RUN; then
        if [ -f "$target_file" ]; then
            echo "  Would update: $pkg_name"
            diff --unified=3 "$target_file" "$new_file" | head -40 || true
        else
            echo "  Would create: $pkg_name"
        fi
        rm -f "$new_file"
    else
        mv "$new_file" "$target_file"
        echo "  Updated: $pkg_name"
    fi
    return 0
}

# ── Run ──────────────────────────────────────────────────────────────────────

total=0
updated=0

if $DRY_RUN; then
    echo "DRY RUN — no files will be modified"
    echo ""
fi

for repo in "${REPOS[@]}"; do
    repo_name="$(basename "$repo")"

    if [ ! -d "$repo" ]; then
        echo "Skipping $repo_name (not found)"
        continue
    fi

    echo "Processing $repo_name..."

    # Sub-repos first
    for pkg_dir in "$repo"/swift-*/; do
        [ -d "$pkg_dir" ] || continue
        # Must be a git repo (directory or file)
        [ -d "$pkg_dir/.git" ] || [ -f "$pkg_dir/.git" ] || continue

        pkg_name="$(basename "$pkg_dir")"
        ((total++)) || true

        if process_repo "$pkg_dir/.gitignore" "$pkg_name" "$repo_name" ""; then
            ((updated++)) || true
        fi
    done

    # Parent repo
    if [ -d "$repo/.git" ] || [ -f "$repo/.git" ]; then
        ((total++)) || true
        if process_repo "$repo/.gitignore" "$repo_name" "$repo_name" "parent"; then
            ((updated++)) || true
        fi
    fi
done

# swift-institute (standalone)
echo "Processing swift-institute..."
((total++)) || true
if process_repo "$INSTITUTE_ROOT/.gitignore" "swift-institute" "swift-institute" "parent"; then
    ((updated++)) || true
fi

echo ""
if $DRY_RUN; then
    echo "Dry run complete. Would update $updated of $total repos."
else
    echo "Done. Updated $updated of $total repos."
fi
