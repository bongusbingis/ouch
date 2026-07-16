#!/bin/sh
# Builds, merges, tests, and deploys the place through Open Cloud:
#   rojo build -> merge-places (graft rojo code into the asset place) ->
#   test-and-deploy (save version -> cloud TestEZ suite -> publish on green).
# With --test-only, skips build/merge/upload and runs the cloud suite against
# the current version of the place.
# Env: ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID, ROBLOX_PLACE_ID
# Exit codes: 0 = green (published unless --test-only); 1 = failure;
#             2 = Open Cloud busy after retries (nothing published).
set -e

PROJECT="${1:?Usage: deploy.sh <project.json> <base-place.rbxl> [--test-only]}"
BASE_PLACE="${2:?Usage: deploy.sh <project.json> <base-place.rbxl> [--test-only]}"
MODE="${3:-}"

TASK_FILE="src/scripts/cloud/RunTests.luau"

if [ "$MODE" = "--test-only" ]; then
    lune run src/scripts/lune/test-and-deploy.luau dist.rbxl "$TASK_FILE" --test-only
    exit 0
fi

if [ -n "$MODE" ]; then
    echo "error: unknown option '$MODE' (expected --test-only)" >&2
    exit 1
fi

rojo build "$PROJECT" --output build.rbxl
lune run src/scripts/lune/merge-places.luau "$PROJECT" "$BASE_PLACE" build.rbxl dist.rbxl
lune run src/scripts/lune/test-and-deploy.luau dist.rbxl "$TASK_FILE"
