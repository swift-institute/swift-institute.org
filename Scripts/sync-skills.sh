#!/bin/bash
# sync-skills.sh - Auto-create .claude/skills/ symlinks for all Skills/
#
# Usage: ./Scripts/sync-skills.sh [--global]
#   --global: Also sync to ~/.claude/skills/ for global access
#
# This script scans Skills/*/ directories and creates symlinks in .claude/skills/

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_NAME="$(basename "$REPO_ROOT")"

echo "Syncing skills for $REPO_NAME..."

# Create project-level .claude/skills/
mkdir -p "$REPO_ROOT/.claude/skills"

# Find all skill directories (contain SKILL.md)
skill_count=0
for skill_dir in "$REPO_ROOT"/Skills/*/; do
  if [ -f "${skill_dir}SKILL.md" ]; then
    skill_name=$(basename "$skill_dir")
    ln -sfn "../../Skills/$skill_name" "$REPO_ROOT/.claude/skills/$skill_name"
    echo "  ✓ $skill_name"
    ((skill_count++)) || true
  fi
done

echo "Synced $skill_count skills to $REPO_ROOT/.claude/skills/"

# Global sync if requested
if [ "$1" = "--global" ]; then
  echo ""
  echo "Syncing to global ~/.claude/skills/..."
  mkdir -p ~/.claude/skills

  for skill_dir in "$REPO_ROOT"/Skills/*/; do
    if [ -f "${skill_dir}SKILL.md" ]; then
      skill_name=$(basename "$skill_dir")
      ln -sfn "$skill_dir" ~/.claude/skills/$skill_name
      echo "  ✓ $skill_name -> ~/.claude/skills/"
    fi
  done
fi

echo "Done."
