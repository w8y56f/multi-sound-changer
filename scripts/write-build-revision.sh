#!/bin/bash
set -euo pipefail

source_dir=$1
output=$2
revision=uncommitted-dirty

# Require this project's own worktree. A source archive could sit inside another repository.
if worktree=$(/usr/bin/git -C "$source_dir" rev-parse --show-toplevel 2>/dev/null) &&
    [[ "$worktree" == "$source_dir" ]] &&
    commit=$(/usr/bin/git -C "$source_dir" rev-parse --short=8 --verify HEAD 2>/dev/null); then
    revision=$commit
    if ! changes=$(/usr/bin/git -C "$source_dir" status --porcelain --untracked-files=normal) ||
        [[ -n "$changes" ]]; then
        revision="$revision-dirty"
    fi
fi

mkdir -p "$(dirname "$output")"
printf '%s\n' "$revision" > "$output"
