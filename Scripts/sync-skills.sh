#!/bin/bash
# sync-skills.sh - Synchronize .claude/skills/ symlinks for repos without submodule-based skills
#
# Usage: ./Scripts/sync-skills.sh
#
# Repos that track .claude/skills/ in git via swift-institute submodule (swift-institute,
# swift-primitives) are self-managing and NOT handled by this script.
#
# This script handles:
#   - Repos not yet using submodule-based skills (swift-standards, swift-foundations)
#   - Workspace-level Developer/.claude/skills/ (absolute symlinks, no submodule)
#
# Discovers skills from:
#   - Repo-level Skills/ in each repo
#   - Package-level Skills/ in monorepos (e.g., swift-primitives/swift-*/Skills/)
#
# Cleans up stale symlinks and removes links to skills that no longer exist.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTITUTE_ROOT="$(dirname "$SCRIPT_DIR")"
# INSTITUTE_ROOT is .../swift-institute/swift-institute.org; the org dir is
# its parent (.../swift-institute), and DEVELOPER_DIR is one level above that.
DEVELOPER_DIR="$(dirname "$(dirname "$INSTITUTE_ROOT")")"

# Repos that self-manage skills via submodule are excluded from REPOS.
# They are still scanned for skill DISCOVERY (source of truth) but not synced to.
SELF_MANAGING="swift-institute swift-primitives swift-foundations"
REPOS="swift-standards"
ALL_REPOS="$SELF_MANAGING $REPOS"

# Path lookup: swift-institute is an org-style directory holding sub-repos;
# the actual website repo lives at swift-institute/swift-institute.org.
# All other ecosystem repos remain flat under DEVELOPER_DIR.
get_repo_path() {
  case "$1" in
    swift-institute) echo "$DEVELOPER_DIR/swift-institute/swift-institute.org" ;;
    *) echo "$DEVELOPER_DIR/$1" ;;
  esac
}

# ── Phase 1: Discover all skills ─────────────────────────────────────────────
# Write discovered skills to a temp file: name<TAB>path

SKILL_LIST=$(mktemp)
trap "rm -f '$SKILL_LIST'" EXIT

# Repo-level skills (institute first, then others — first discovered wins)
for repo in $ALL_REPOS; do
  repo_path="$(get_repo_path "$repo")"
  [ -d "$repo_path" ] || continue
  [ -d "$repo_path/Skills" ] || continue

  for skill_dir in "$repo_path"/Skills/*/; do
    if [ -f "${skill_dir}SKILL.md" ]; then
      skill_name=$(basename "$skill_dir")
      skill_path="$(cd "$skill_dir" && pwd)"
      if ! grep -q "^${skill_name}	" "$SKILL_LIST"; then
        printf '%s\t%s\n' "$skill_name" "$skill_path" >> "$SKILL_LIST"
      fi
    fi
  done
done

# Package-level skills (monorepos)
for repo in $ALL_REPOS; do
  repo_path="$(get_repo_path "$repo")"
  [ -d "$repo_path" ] || continue

  for package_dir in "$repo_path"/swift-*/; do
    [ -d "$package_dir" ] || continue
    [ -d "${package_dir}Skills" ] || continue
    for skill_dir in "${package_dir}"Skills/*/; do
      if [ -f "${skill_dir}SKILL.md" ]; then
        skill_name=$(basename "$skill_dir")
        skill_path="$(cd "$skill_dir" && pwd)"
        if ! grep -q "^${skill_name}	" "$SKILL_LIST"; then
          printf '%s\t%s\n' "$skill_name" "$skill_path" >> "$SKILL_LIST"
        fi
      fi
    done
  done
done

skill_count=$(wc -l < "$SKILL_LIST" | tr -d ' ')
echo "Discovered $skill_count skills:"
sort "$SKILL_LIST" | while IFS=$'\t' read -r name path; do
  echo "  $name"
done
echo ""

# ── Phase 2: Sync to each repo ───────────────────────────────────────────────

sync_target() {
  local target="$1"
  local label="$2"

  mkdir -p "$target"

  # Remove stale symlinks (broken targets)
  local stale=0
  for link in "$target"/*; do
    [ -L "$link" ] || continue
    if [ ! -e "$link" ]; then
      rm "$link"
      ((stale++)) || true
    fi
  done

  # Remove symlinks for skills no longer in the discovered set
  for link in "$target"/*; do
    [ -L "$link" ] || continue
    link_name=$(basename "$link")
    if ! grep -q "^${link_name}	" "$SKILL_LIST"; then
      rm "$link"
      ((stale++)) || true
    fi
  done

  # Create/update symlinks
  local synced=0
  while IFS=$'\t' read -r skill_name skill_path; do
    ln -sfn "$skill_path" "$target/$skill_name"
    ((synced++)) || true
  done < "$SKILL_LIST"

  if [ "$stale" -gt 0 ]; then
    echo "$label: $synced skills synced, $stale stale removed"
  else
    echo "$label: $synced skills synced"
  fi
}

for repo in $REPOS; do
  repo_path="$(get_repo_path "$repo")"
  if [ ! -d "$repo_path" ]; then
    echo "Skipping $repo (not found)"
    continue
  fi
  sync_target "$repo_path/.claude/skills" "$repo"
done

echo ""

# ── Phase 3: Sync to workspace level ─────────────────────────────────────────

sync_target "$DEVELOPER_DIR/.claude/skills" "Developer/.claude/skills/"

echo ""
echo "Done."
