#!/bin/bash
set -euo pipefail

SKILL_NAME="db-manager"
TARGET_DIR="$HOME/.claude/skills/$SKILL_NAME"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
  echo "SKILL.md not found in $SOURCE_DIR"
  exit 1
fi

mkdir -p "$HOME/.claude/skills"

if [ -d "$TARGET_DIR" ]; then
  echo "Updating existing installation..."
  rm -rf "$TARGET_DIR"
fi

cp -r "$SOURCE_DIR" "$TARGET_DIR"
rm -rf "$TARGET_DIR/.git"

echo "Installed $SKILL_NAME to $TARGET_DIR"
