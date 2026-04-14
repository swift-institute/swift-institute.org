#!/bin/bash
# ecosystem-timeline.sh
#
# Scans every Swift ecosystem repo under the development root and gathers
# commit chronology data into a CSV. Each row is a single git repo.
#
# Output: <repo>/Research/ecosystem-timeline-data.csv
# Columns: organization,package,first_commit_date,last_commit_date,commit_count,first_month
#
# Usage:
#   bash ecosystem-timeline.sh                     # auto-detects DEV_ROOT
#   DEV_ROOT=/path/to/dev bash ecosystem-timeline.sh
#
# Auto-detection assumes this script lives at <DEV_ROOT>/swift-institute/Scripts/
# and that the other ecosystem organizations (swift-primitives, swift-foundations,
# etc.) are siblings of swift-institute under DEV_ROOT.
#
# To audit: open the CSV, verify row-per-repo counts match expectations, and
# cross-check a sample against `git log --reverse --format=%ai | head -1` and
# `git log --oneline | wc -l` in the repo itself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_ROOT="${DEV_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
OUTPUT="${SCRIPT_DIR}/../Research/ecosystem-timeline-data.csv"

mkdir -p "$(dirname "$OUTPUT")"
echo "organization,package,first_commit_date,last_commit_date,commit_count,first_month" > "$OUTPUT"

# Scans one organization directory. For each immediate subdirectory that is a
# git repo (has .git as dir or file), append one row to the output CSV.
scan_org() {
    local org_path="$1"
    local org_name="$2"
    if [ ! -d "$org_path" ]; then
        echo "SKIP: $org_path does not exist" >&2
        return
    fi
    local found=0
    for dir in "$org_path"/*/; do
        # skip if not a directory or not a git repo
        [ -d "$dir" ] || continue
        if [ ! -d "$dir/.git" ] && [ ! -f "$dir/.git" ]; then
            continue
        fi
        local pkg_name
        pkg_name=$(basename "$dir")
        # get first commit, last commit, commit count
        local first_commit
        local last_commit
        local commit_count
        first_commit=$(cd "$dir" && git log --reverse --format="%ai" 2>/dev/null | head -1 || echo "")
        last_commit=$(cd "$dir" && git log -1 --format="%ai" 2>/dev/null || echo "")
        commit_count=$(cd "$dir" && git log --oneline 2>/dev/null | wc -l | tr -d ' ')
        if [ -z "$first_commit" ]; then
            continue
        fi
        # extract YYYY-MM from first commit for monthly bucketing
        local first_month
        first_month=$(echo "$first_commit" | awk '{print $1}' | cut -c1-7)
        echo "${org_name},${pkg_name},${first_commit},${last_commit},${commit_count},${first_month}" >> "$OUTPUT"
        found=$((found + 1))
    done
    echo "${org_name}: ${found} repos" >&2
}

echo "Scanning ecosystem repos..." >&2

# Swift Institute core layers
scan_org "${DEV_ROOT}/swift-primitives" "swift-primitives"
scan_org "${DEV_ROOT}/swift-standards" "swift-standards"
scan_org "${DEV_ROOT}/swift-foundations" "swift-foundations"

# Per-spec-body organizations (standards refactor)
scan_org "${DEV_ROOT}/swift-ietf" "swift-ietf"
scan_org "${DEV_ROOT}/swift-iso" "swift-iso"
scan_org "${DEV_ROOT}/swift-w3c" "swift-w3c"
scan_org "${DEV_ROOT}/swift-whatwg" "swift-whatwg"
scan_org "${DEV_ROOT}/swift-ieee" "swift-ieee"
scan_org "${DEV_ROOT}/swift-iec" "swift-iec"
scan_org "${DEV_ROOT}/swift-ecma" "swift-ecma"
scan_org "${DEV_ROOT}/swift-incits" "swift-incits"
scan_org "${DEV_ROOT}/swift-arm-ltd" "swift-arm-ltd"
scan_org "${DEV_ROOT}/swift-intel" "swift-intel"
scan_org "${DEV_ROOT}/swift-riscv" "swift-riscv"
scan_org "${DEV_ROOT}/swift-microsoft" "swift-microsoft"
scan_org "${DEV_ROOT}/swift-linux-foundation" "swift-linux-foundation"

# Umbrella / application / component layers
scan_org "${DEV_ROOT}/swift-institute" "swift-institute"
scan_org "${DEV_ROOT}/swift-applications" "swift-applications"
scan_org "${DEV_ROOT}/swift-components" "swift-components"
scan_org "${DEV_ROOT}/swift-server" "swift-server"

# Existing public org being absorbed
scan_org "${DEV_ROOT}/coenttb" "coenttb"

total=$(($(wc -l < "$OUTPUT") - 1))
echo "" >&2
echo "Done. ${total} repos written to: ${OUTPUT}" >&2
