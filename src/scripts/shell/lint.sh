#!/bin/sh
# Lints the given source directory with Selene (installed via Aftman).
set -e

TARGET="${1:?Usage: lint.sh <path>}"

selene "$TARGET"
