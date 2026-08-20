#!/bin/sh
# Downloads the currently-published place for one or both places and imports it
# into places/<place>/, which is where the deploy pipeline reads its merge base
# from. Use this to seed those files, or to pick up Studio work that was
# published but never committed.
#
# Each place's id comes from its own <place>.project.json servePlaceIds, so
# there is no second copy of those ids to drift.
#
# Usage (from repo root):
#   bash src/scripts/shell/pull-places.sh            # both
#   bash src/scripts/shell/pull-places.sh arena
#   bash src/scripts/shell/pull-places.sh arena lobby
# Env: ROBLOX_API_KEY (needs legacy-asset:manage granted for the place)
set -e

MINIMUM_BYTES=10000

if [ -z "${ROBLOX_API_KEY}" ]; then
    echo "error: ROBLOX_API_KEY is required" >&2
    exit 1
fi

TARGETS="$*"
if [ -z "$TARGETS" ] || [ "$TARGETS" = "all" ]; then
    TARGETS="arena lobby"
fi

for place in $TARGETS; do
    case "$place" in
        arena | lobby) ;;
        *)
            echo "error: unknown place '$place' (expected arena, lobby, or all)" >&2
            exit 1
            ;;
    esac

    project="$place.project.json"
    if [ ! -f "$project" ]; then
        echo "error: $project not found; run from the repo root" >&2
        exit 1
    fi

    place_id=$(grep -o '"servePlaceIds"[^]]*]' "$project" | grep -o '[0-9]\+' | head -1)
    if [ -z "$place_id" ]; then
        echo "error: could not read servePlaceIds from $project" >&2
        exit 1
    fi

    dir="places/$place"
    mkdir -p "$dir"

    # Overwrite the file already there whatever it is called, so the deploy's
    # "exactly one .rbxl per place" rule keeps holding.
    existing_count=$(find "$dir" -maxdepth 1 -name '*.rbxl' | wc -l)
    if [ "$existing_count" -gt 1 ]; then
        echo "error: $dir already holds more than one .rbxl; deploy cannot pick between them" >&2
        find "$dir" -maxdepth 1 -name '*.rbxl' >&2
        exit 1
    elif [ "$existing_count" -eq 1 ]; then
        output=$(find "$dir" -maxdepth 1 -name '*.rbxl')
    else
        output="$dir/$place.rbxl"
    fi

    echo "Pulling $place (place $place_id) into $output"

    # Download beside the target and only move it into place once it looks like a
    # real place file, so a failed or truncated fetch never replaces a good one.
    temp="$output.download"
    rm -f "$temp"
    ROBLOX_PLACE_ID="$place_id" lune run src/scripts/lune/fetch-live-place.luau "$temp"

    size=$(wc -c < "$temp")
    if [ "$size" -lt "$MINIMUM_BYTES" ]; then
        rm -f "$temp"
        echo "error: downloaded $place place is only ${size} bytes; leaving $output untouched" >&2
        exit 1
    fi

    mv -f "$temp" "$output"
    echo "  wrote $output (${size} bytes)"
done

echo "Done. Commit the updated place file(s); they are Git LFS binaries."
