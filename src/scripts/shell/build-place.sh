#!/bin/sh
# Builds a merged artifact and provenance manifest without publishing.
set -eu

exec lune run src/scripts/lune/build-place.luau "$@"
