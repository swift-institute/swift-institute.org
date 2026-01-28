#!/bin/bash
# sync-all-skills.sh - Sync all skills from Swift Institute repos to ~/.claude/skills/
#
# Usage: ./Scripts/sync-all-skills.sh
#
# Scans known repositories for Skills/ directories and creates global symlinks.
# Also scans monorepo packages for per-package skills.

set -e

DEVELOPER_DIR="/Users/coen/Developer"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"

# Known repositories with skills
REPOS=(
  "swift-institute"
  "swift-primitives"
  "swift-standards"
  "swift-foundations"
)

echo "Syncing all skills to $GLOBAL_SKILLS_DIR..."
mkdir -p "$GLOBAL_SKILLS_DIR"

total_count=0

for repo in "${REPOS[@]}"; do
  repo_path="$DEVELOPER_DIR/$repo"

  if [ ! -d "$repo_path" ]; then
    echo "  Skipping $repo (not found)"
    continue
  fi

  # Repo-level skills
  if [ -d "$repo_path/Skills" ]; then
    for skill_dir in "$repo_path"/Skills/*/; do
      if [ -f "${skill_dir}SKILL.md" ]; then
        skill_name=$(basename "$skill_dir")
        ln -sfn "$skill_dir" "$GLOBAL_SKILLS_DIR/$skill_name"
        echo "  ✓ $skill_name ($repo)"
        ((total_count++)) || true
      fi
    done
  fi

  # Package-level skills (for monorepos like swift-primitives)
  for package_dir in "$repo_path"/swift-*/; do
    if [ -d "${package_dir}Skills" ]; then
      for skill_dir in "${package_dir}"Skills/*/; do
        if [ -f "${skill_dir}SKILL.md" ]; then
          skill_name=$(basename "$skill_dir")
          package_name=$(basename "$package_dir")
          ln -sfn "$skill_dir" "$GLOBAL_SKILLS_DIR/$skill_name"
          echo "  ✓ $skill_name ($package_name)"
          ((total_count++)) || true
        fi
      done
    fi
  done
done

echo ""
echo "Synced $total_count skills to $GLOBAL_SKILLS_DIR"
echo ""
echo "Current skills:"
ls -1 "$GLOBAL_SKILLS_DIR" | sed 's/^/  /'
