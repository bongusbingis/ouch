#!/bin/sh
# Downloads the currently-published place file via Open Cloud's Asset
# Delivery API. Env: ROBLOX_API_KEY, ROBLOX_PLACE_ID
set -e

OUTPUT="${1:?Usage: fetch-live-place.sh <output.rbxl>}"

lune run src/scripts/lune/fetch-live-place.luau "$OUTPUT"
