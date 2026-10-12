#!/bin/bash
# Installs third-party skills into .claude/skills at the start of each Claude
# Code cloud session. Each source is fetched at a pinned commit instead of being
# committed here; its license is copied alongside every skill it provides.
#
# To add or remove a skill, edit the name list in the matching install_skills
# call. Names are folders under the source's skills directory at that commit.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

SKILLS_DIR="$CLAUDE_PROJECT_DIR/.claude/skills"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/claude-skill-sources"

fetch() {
  local cache=$1 repo=$2 rev=$3 subdir=$4
  rm -rf "$cache" &&
    git init -q "$cache" &&
    git -C "$cache" remote add origin "$repo" &&
    git -C "$cache" sparse-checkout set "$subdir" &&
    git -C "$cache" fetch -q --depth 1 --filter=blob:none origin "$rev" &&
    git -C "$cache" checkout -q FETCH_HEAD &&
    touch "$cache/.complete"
}

# install_skills <id> <repo> <rev> <skills subdir> <license file> <skill>...
install_skills() {
  local id=$1 repo=$2 rev=$3 subdir=$4 license=$5
  shift 5
  local cache="$CACHE_ROOT/$id/$rev"
  local stamp="$SKILLS_DIR/.$id-installed"
  local want="$rev $*"

  if [ -f "$stamp" ] && [ "$(head -n 1 "$stamp")" = "$want" ]; then
    return 0
  fi

  if [ ! -f "$cache/.complete" ] && ! fetch "$cache" "$repo" "$rev" "$subdir"; then
    echo "session-start: could not fetch $repo skills; continuing without them" >&2
    return 0
  fi

  # Drop skills a previous run installed from this source that are no longer listed.
  if [ -f "$stamp" ]; then
    tail -n +2 "$stamp" | while read -r old; do
      [ -n "$old" ] && rm -rf "${SKILLS_DIR:?}/$old"
    done
  fi

  mkdir -p "$SKILLS_DIR"
  local name
  for name in "$@"; do
    rm -rf "${SKILLS_DIR:?}/$name"
    cp -R "$cache/$subdir/$name" "$SKILLS_DIR/$name"
    cp "$cache/$license" "$SKILLS_DIR/$name/LICENSE-$id"
  done

  { echo "$want"; printf '%s\n' "$@"; } > "$stamp"
}

# Sustainable Use License, which limits redistribution, so these are never committed.
install_skills oh-my-openagent \
  https://github.com/code-yeongyu/oh-my-openagent \
  a59ed36915931554588545639bd015ab50a0bdc2 \
  packages/shared-skills/skills LICENSE.md \
  debugging git-master refactor remove-ai-slops review-work data-scientist init-deep

# MIT. The image-generation, Google Stitch, GPT-specific and legacy v1 skills are left out.
install_skills taste-skill \
  https://github.com/leonxlnx/taste-skill \
  d237dd399d57524945c0c81327da5da19f7a468d \
  skills LICENSE \
  taste-skill redesign-skill soft-skill minimalist-skill brutalist-skill output-skill
