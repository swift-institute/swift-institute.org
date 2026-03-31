#!/bin/zsh
# sync-swift-settings.sh - Synchronize Swift package settings across all repos
#
# Usage: ./Scripts/sync-swift-settings.sh
#
# This script standardizes the `for target in package.targets` settings loop
# in every Package.swift across the Swift Institute ecosystem.
#
# Settings are split into two categories:
#   - ecosystem: Universal settings shared by ALL packages (managed by this script)
#   - package:   Package-specific settings (preserved by this script, managed manually)
#
# The script ONLY replaces the ecosystem array. Package-specific settings in the
# `let package: [SwiftSetting]` array are never touched. This prevents the script
# from wiping manually-maintained settings like .define() with platform conditions.
#
# On first run (no ecosystem/package split), converts to the split format with
# an empty package array. Manually add package-specific settings afterward.

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
    '        .enableExperimentalFeature("TildeSendable"),'
)

# ── Repository roots to process ──────────────────────────────────────────────

REPOS=(
    "$DEVELOPER_DIR/swift-primitives"
    "$DEVELOPER_DIR/swift-standards"
    "$DEVELOPER_DIR/swift-foundations"
)

# ── Helper: extract existing package settings from a file ────────────────────
# Extracts everything between `let package: [SwiftSetting] = [` and its closing `]`
# (inclusive of contents, exclusive of the brackets themselves).
# Returns the lines, or empty string if not found or empty.

extract_package_settings() {
    local file="$1"
    local start_line end_line depth

    # Find `let package:` within the for-loop block
    start_line=$(grep -n 'let package: \[SwiftSetting\] = \[' "$file" | tail -1 | cut -d: -f1)
    if [ -z "$start_line" ]; then
        echo ""
        return
    fi

    # Check if it's `= []` on one line (empty)
    local line_text
    line_text=$(sed -n "${start_line}p" "$file")
    if echo "$line_text" | grep -q '\[\]'; then
        echo ""
        return
    fi

    # Find the closing `]` by counting brackets
    local total_lines
    total_lines=$(wc -l < "$file")
    depth=0
    local scan_line=$start_line
    local found_open=false

    while [ "$scan_line" -le "$total_lines" ]; do
        line_text=$(sed -n "${scan_line}p" "$file")
        local opens closes
        opens=$(echo "$line_text" | tr -cd '[' | wc -c | tr -d ' ')
        closes=$(echo "$line_text" | tr -cd ']' | wc -c | tr -d ' ')
        depth=$((depth + opens - closes))
        if [ "$depth" -le 0 ] && [ "$scan_line" -gt "$start_line" ]; then
            end_line=$scan_line
            break
        fi
        scan_line=$((scan_line + 1))
    done

    if [ -z "$end_line" ]; then
        echo ""
        return
    fi

    # Extract lines between opening [ and closing ] (exclusive of bracket lines)
    if [ $((end_line - start_line)) -gt 1 ]; then
        sed -n "$((start_line + 1)),$((end_line - 1))p" "$file"
    else
        echo ""
    fi
}

# ── Helper: write the replacement block to a file ────────────────────────────

write_replacement() {
    local pkg_name="$1"
    local out_file="$2"
    local existing_package_settings="$3"

    {
        echo 'for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {'
        echo '    let ecosystem: [SwiftSetting] = ['
        for line in "${ECOSYSTEM_LINES[@]}"; do
            echo "$line"
        done
        echo '    ]'
        echo ''
        if [ -z "$existing_package_settings" ]; then
            echo '    let package: [SwiftSetting] = []'
        else
            echo '    let package: [SwiftSetting] = ['
            echo "$existing_package_settings"
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

    # Extract existing package-specific settings before replacing
    local existing_package_settings
    existing_package_settings="$(extract_package_settings "$file")"

    # Generate replacement
    local repl_file
    repl_file="$(mktemp)"
    write_replacement "$pkg_name" "$repl_file" "$existing_package_settings"

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

    if [ -n "$existing_package_settings" ]; then
        echo "  Updated: $pkg_name (preserved package settings)"
    else
        echo "  Updated: $pkg_name"
    fi
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
