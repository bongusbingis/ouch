#!/bin/sh
# Builds, merges, tests, and deploys the place through Open Cloud:
#   rojo build -> merge-places (graft rojo code into the asset place) ->
#   test-and-deploy (save version -> cloud TestEZ suite -> publish on green).
# --test-only tests the current saved version; --stage-only saves and tests a
# new merged version without publishing it.
# Env: ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID, ROBLOX_PLACE_ID
# Exit codes: 0 = green (published only without a mode flag); 1 = failure;
#             2 = Open Cloud busy after retries (nothing published).
set -e

PROJECT="${1:?Usage: deploy.sh <project.json> <base-place.rbxl> [--test-only|--stage-only]}"
BASE_PLACE="${2:?Usage: deploy.sh <project.json> <base-place.rbxl> [--test-only|--stage-only]}"
MODE="${3:-}"

TASK_FILE="src/scripts/cloud/RunTests.luau"

if [ "$MODE" = "--test-only" ]; then
    lune run src/scripts/lune/test-and-deploy.luau dist.rbxl "$TASK_FILE" --test-only
    exit 0
fi

if [ -n "$MODE" ] && [ "$MODE" != "--stage-only" ]; then
    echo "error: unknown option '$MODE' (expected --test-only or --stage-only)" >&2
    exit 1
fi

rojo build "$PROJECT" --output build.rbxl
lune run src/scripts/lune/merge-places.luau "$PROJECT" "$BASE_PLACE" build.rbxl dist.rbxl
if [ "$MODE" = "--stage-only" ]; then
    lune run src/scripts/lune/test-and-deploy.luau dist.rbxl "$TASK_FILE" --stage-only
else
    lune run src/scripts/lune/test-and-deploy.luau dist.rbxl "$TASK_FILE"
fi
