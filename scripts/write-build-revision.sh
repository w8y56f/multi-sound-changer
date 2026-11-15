#!/bin/bash
set -euo pipefail

source_dir=$(cd "$1" && pwd -P)
output=$2
revision=unknown

git_for_source=(/usr/bin/git -C "$source_dir")
if ! worktree=$("${git_for_source[@]}" rev-parse --show-toplevel 2>/dev/null) ||
    [[ "$worktree" != "$source_dir" ]]; then
    # Local builds can use separate Git metadata when the checkout has no .git.
    git_for_source+=(--git-dir="$source_dir/.source-git" --work-tree="$source_dir")
fi

# Require this project's own worktree. A source archive could sit inside another repository.
if worktree=$("${git_for_source[@]}" rev-parse --show-toplevel 2>/dev/null) &&
    [[ "$worktree" == "$source_dir" ]] &&
    commit=$("${git_for_source[@]}" rev-parse --short=8 --verify HEAD 2>/dev/null); then
    revision=$commit
    if ! changes=$("${git_for_source[@]}" status --porcelain --untracked-files=normal) ||
        [[ -n "$changes" ]]; then
        revision="$revision-dirty"
    fi
fi

mkdir -p "$(dirname "$output")"
printf '%s\n' "$revision" > "$output"
