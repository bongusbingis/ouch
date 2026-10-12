#!/usr/bin/env bash
# Reports affected places as JSON; unknown bases conservatively select both.
# Rename sources and destinations are independent changes, including unusual paths.
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: changed-places.sh <base-sha> [head-ref]" >&2
    exit 1
fi

base_ref=$1
head_ref=${2:-HEAD}
if ! head_sha=$(git rev-parse --verify --quiet --end-of-options "${head_ref}^{commit}"); then
    echo "error: head must identify an available commit." >&2
    exit 1
fi

if [ -z "$base_ref" ] || ! base_sha=$(git rev-parse --verify --quiet --end-of-options "${base_ref}^{commit}"); then
    echo "No usable base commit; treating both places as changed." >&2
    printf '%s\n' '["arena","lobby"]'
    exit 0
fi

changed_files=$(mktemp)
trap 'rm -f "$changed_files"' EXIT
printf 'Comparing %s to %s\n' "$base_sha" "$head_sha" >&2
git diff --no-renames --name-only -z "$base_sha" "$head_sha" -- > "$changed_files"

arena=no
lobby=no
while IFS= read -r -d '' file; do
    case "$file" in
        src/*|Packages/*|wally.toml|wally.lock|rokit.toml|aftman.toml|.github/workflows/cicd.yml|.github/actions/*)
            arena=yes
            lobby=yes
            ;;
        places/arena/*|arena.project.json)
            arena=yes
            ;;
        places/lobby/*|lobby.project.json)
            lobby=yes
            ;;
    esac
done < "$changed_files"

if [ "$arena" = yes ] && [ "$lobby" = yes ]; then
    printf '%s\n' '["arena","lobby"]'
elif [ "$arena" = yes ]; then
    printf '%s\n' '["arena"]'
elif [ "$lobby" = yes ]; then
    printf '%s\n' '["lobby"]'
else
    printf '%s\n' '[]'
fi
