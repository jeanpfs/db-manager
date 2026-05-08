#!/usr/bin/env bash
set -euo pipefail

if [ -z "${HOME:-}" ]; then
  echo "ERROR: \$HOME is not set; refusing to install" >&2
  exit 1
fi

SKILL_NAME="db-manager"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_ROOT="$HOME/.claude/skills"
TARGET_DIR="$SKILLS_ROOT/$SKILL_NAME"

if [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
  echo "ERROR: SKILL.md not found in $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$SKILLS_ROOT"

STAGING_DIR="$(mktemp -d "$SKILLS_ROOT/.${SKILL_NAME}.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

install -m 0644 "$SOURCE_DIR/SKILL.md" "$STAGING_DIR/SKILL.md"
[ -f "$SOURCE_DIR/LICENSE" ] && install -m 0644 "$SOURCE_DIR/LICENSE" "$STAGING_DIR/LICENSE"
[ -f "$SOURCE_DIR/README.md" ] && install -m 0644 "$SOURCE_DIR/README.md" "$STAGING_DIR/README.md"

if [ -d "$SOURCE_DIR/references" ]; then
  mkdir -p "$STAGING_DIR/references"
  find "$SOURCE_DIR/references" -maxdepth 1 -type f -name '*.md' -print0 \
    | while IFS= read -r -d '' f; do
        install -m 0644 "$f" "$STAGING_DIR/references/$(basename "$f")"
      done
fi

if [ -e "$TARGET_DIR" ] && [ ! -L "$TARGET_DIR" ]; then
  BACKUP_DIR="${TARGET_DIR}.bak.$(date +%Y%m%d%H%M%S)"
  mv "$TARGET_DIR" "$BACKUP_DIR"
  echo "Existing install moved to $BACKUP_DIR"
fi

mv "$STAGING_DIR" "$TARGET_DIR"
trap - EXIT

echo "Installed $SKILL_NAME to $TARGET_DIR"
