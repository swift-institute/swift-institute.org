#!/bin/zsh
# sync-swift-settings.sh - Synchronize Swift package settings across all repos
#
# Usage: ./Scripts/sync-swift-settings.sh
#
# This script standardizes the `for target in package.targets` settings loop
# in every Package.swift across the Swift Institute ecosystem.
#
# Settings are split into two categories:
#   - ecosystem: Universal settings shared by ALL packages
#   - package:   Package-specific experimental features (BuiltinModule, RawLayout, etc.)
#
# On first run, converts single `let settings` arrays to the ecosystem/package split.
# On subsequent runs, updates the ecosystem array while preserving package-specific settings.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTITUTE_ROOT="$(dirname "$SCRIPT_DIR")"
DEVELOPER_DIR="$(dirname "$INSTITUTE_ROOT")"

# ── Canonical ecosystem settings ─────────────────────────────────────────────
# These are applied to ALL packages. Edit this block to change ecosystem-wide settings.

ECOSYSTEM_LINES=(
    '        .strictMemorySafety(),'
    '        .enableUpcomingFeature("ExistentialAny"),'
    '        .enableUpcomingFeature("InternalImportsByDefault"),'
    '        .enableUpcomingFeature("MemberImportVisibility"),'
    '        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),'
    '        .enableExperimentalFeature("Lifetimes"),'
    '        .enableExperimentalFeature("SuppressedAssociatedTypes"),'
)

# ── Package-specific features ────────────────────────────────────────────────
# Returns space-separated list of experimental features for a given package name.

package_features() {
    case "$1" in
        swift-buffer-primitives)     echo "BuiltinModule RawLayout" ;;
        swift-dictionary-primitives) echo "RawLayout" ;;
        swift-list-primitives)       echo "RawLayout" ;;
        swift-storage-primitives)    echo "RawLayout" ;;
        swift-tree-primitives)       echo "RawLayout" ;;
        swift-sequence-primitives)   echo "BuiltinModule" ;;
        *)                           echo "" ;;
    esac
}

# ── Repository roots to process ──────────────────────────────────────────────

REPOS=(
    "$DEVELOPER_DIR/swift-primitives"
    "$DEVELOPER_DIR/swift-standards"
    "$DEVELOPER_DIR/swift-foundations"
)

# ── Helper: write the replacement block to a file ────────────────────────────

write_replacement() {
    local pkg_name="$1"
    local out_file="$2"
    local features
    features="$(package_features "$pkg_name")"

    {
        echo 'for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {'
        echo '    let ecosystem: [SwiftSetting] = ['
        for line in "${ECOSYSTEM_LINES[@]}"; do
            echo "$line"
        done
        echo '    ]'
        echo ''
        if [ -z "$features" ]; then
            echo '    let package: [SwiftSetting] = []'
        else
            echo '    let package: [SwiftSetting] = ['
            for feature in ${=features}; do
                echo "        .enableExperimentalFeature(\"$feature\"),"
            done
            echo '    ]'
        fi
        echo ''
        echo '    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package'
        echo '}'
    } > "$out_file"
}

# ── Main: process a single Package.swift ─────────────────────────────────────

process_file() {
    local file="$1"
    local pkg_name
    pkg_name="$(basename "$(dirname "$file")")"

    if ! grep -q 'for target in package\.targets' "$file"; then
        return 0
    fi

    # Generate replacement
    local repl_file
    repl_file="$(mktemp)"
    write_replacement "$pkg_name" "$repl_file"

    # Find the line range of the for-loop block
    local start_line
    start_line=$(grep -n 'for target in package\.targets' "$file" | head -1 | cut -d: -f1)

    if [ -z "$start_line" ]; then
        rm -f "$repl_file"
        return 0
    fi

    # Count braces from start_line to find end_line
    local end_line depth
    depth=0
    end_line="$start_line"
    local total_lines
    total_lines=$(wc -l < "$file")

    while [ "$end_line" -le "$total_lines" ]; do
        local line_text opens closes
        line_text=$(sed -n "${end_line}p" "$file")
        opens=$(echo "$line_text" | tr -cd '{' | wc -c | tr -d ' ')
        closes=$(echo "$line_text" | tr -cd '}' | wc -c | tr -d ' ')
        depth=$((depth + opens - closes))
        if [ "$depth" -le 0 ] && [ "$end_line" -gt "$start_line" ]; then
            break
        fi
        end_line=$((end_line + 1))
    done

    # Splice: lines before + replacement + lines after
    local out_file
    out_file="$(mktemp)"
    {
        if [ "$start_line" -gt 1 ]; then
            head -n $((start_line - 1)) "$file"
        fi
        cat "$repl_file"
        if [ "$end_line" -lt "$total_lines" ]; then
            tail -n $((total_lines - end_line)) "$file"
        fi
    } > "$out_file"

    mv "$out_file" "$file"
    rm -f "$repl_file"
    echo "  Updated: $pkg_name"
}

# ── Run ──────────────────────────────────────────────────────────────────────

total=0
updated=0

for repo in "${REPOS[@]}"; do
    if [ ! -d "$repo" ]; then
        echo "Skipping $(basename "$repo") (not found)"
        continue
    fi

    echo "Processing $(basename "$repo")..."

    for pkg_dir in "$repo"/swift-*/; do
        [ -d "$pkg_dir" ] || continue
        local_file="$pkg_dir/Package.swift"
        [ -f "$local_file" ] || continue
        ((total++)) || true

        if grep -q 'for target in package\.targets' "$local_file"; then
            process_file "$local_file"
            ((updated++)) || true
        fi
    done

    # Root Package.swift
    if [ -f "$repo/Package.swift" ] && grep -q 'for target in package\.targets' "$repo/Package.swift"; then
        process_file "$repo/Package.swift"
        ((updated++)) || true
        ((total++)) || true
    fi
done

echo ""
echo "Done. Updated $updated of $total packages."
