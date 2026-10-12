#!/bin/bash
# Installs skills from code-yeongyu/oh-my-openagent into .claude/skills at the
# start of each Claude Code cloud session. The skill files are fetched from the
# pinned commit below rather than committed here, because that repo is under
# the Sustainable Use License (copied alongside each skill as LICENSE-oh-my-openagent.md).
#
# To add or remove a skill, edit SKILLS. Available names are the folders in
# https://github.com/code-yeongyu/oh-my-openagent/tree/<OMO_REV>/packages/shared-skills/skills
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

OMO_REPO="https://github.com/code-yeongyu/oh-my-openagent"
OMO_REV="a59ed36915931554588545639bd015ab50a0bdc2"
SKILLS=(
  debugging
  git-master
  refactor
  remove-ai-slops
  review-work
  data-scientist
  init-deep
)

SKILLS_DIR="$CLAUDE_PROJECT_DIR/.claude/skills"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-openagent/$OMO_REV"
STAMP="$SKILLS_DIR/.omo-installed"
WANT="$OMO_REV ${SKILLS[*]}"

if [ -f "$STAMP" ] && [ "$(head -n 1 "$STAMP")" = "$WANT" ]; then
  exit 0
fi

fetch() {
  rm -rf "$CACHE_DIR" &&
    git init -q "$CACHE_DIR" &&
    git -C "$CACHE_DIR" remote add origin "$OMO_REPO" &&
    git -C "$CACHE_DIR" sparse-checkout set packages/shared-skills/skills &&
    git -C "$CACHE_DIR" fetch -q --depth 1 --filter=blob:none origin "$OMO_REV" &&
    git -C "$CACHE_DIR" checkout -q FETCH_HEAD &&
    touch "$CACHE_DIR/.complete"
}

if [ ! -f "$CACHE_DIR/.complete" ] && ! fetch; then
  echo "session-start: could not fetch oh-my-openagent skills; continuing without them" >&2
  exit 0
fi

# Drop skills a previous run installed that are no longer listed.
if [ -f "$STAMP" ]; then
  tail -n +2 "$STAMP" | while read -r old; do
    [ -n "$old" ] && rm -rf "${SKILLS_DIR:?}/$old"
  done
fi

mkdir -p "$SKILLS_DIR"
for name in "${SKILLS[@]}"; do
  rm -rf "${SKILLS_DIR:?}/$name"
  cp -R "$CACHE_DIR/packages/shared-skills/skills/$name" "$SKILLS_DIR/$name"
  cp "$CACHE_DIR/LICENSE.md" "$SKILLS_DIR/$name/LICENSE-oh-my-openagent.md"
done

{ echo "$WANT"; printf '%s\n' "${SKILLS[@]}"; } > "$STAMP"
