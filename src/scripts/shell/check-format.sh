#!/bin/sh
# Checks formatting of the given source directory with StyLua (installed via Rokit).
set -e

TARGET="${1:?Usage: check-format.sh <path>}"

stylua --check "$TARGET"
