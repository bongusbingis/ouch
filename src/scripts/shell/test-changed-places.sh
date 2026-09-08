#!/usr/bin/env bash
# Exercises deployment selection against isolated Git history, never the checkout.
set -euo pipefail

script_dir=$(dirname -- "${BASH_SOURCE[0]}")
script_dir=$(cd "$script_dir" && pwd)
detector="$script_dir/changed-places.sh"
fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT
mkdir "$fixture_dir/repo"
cd "$fixture_dir/repo"
git init -q --template=
git config user.name "CI regression tests"
git config user.email "ci-tests@example.invalid"
git config commit.gpgsign false
git config core.hooksPath /dev/null
git config diff.renames true

for file in \
    places/arena/example.luau \
    places/lobby/example.luau \
    src/shared/example.luau \
    Packages/example.luau \
    arena.project.json lobby.project.json \
    wally.toml wally.lock rokit.toml aftman.toml \
    .github/workflows/cicd.yml \
    .github/actions/setup-tools/action.yml \
    docs/example.md; do
    mkdir -p "$(dirname -- "$file")"
    printf '%s\n' "$file" > "$file"
done
git add .
git commit -qm base
base_sha=$(git rev-parse HEAD)
tests_passed=0

reset_fixture() {
    git reset --hard -q "$base_sha"
    git clean -fdq
}

commit_fixture() {
    git add -A
    git commit -qm "$1"
}

assert_places() {
    local label=$1
    local expected=$2
    shift 2
    local actual
    if ! actual=$(bash "$detector" "$@" 2> "$fixture_dir/diagnostics"); then
        printf 'FAIL: %s: detector failed\n' "$label" >&2
        cat "$fixture_dir/diagnostics" >&2
        exit 1
    fi
    if [ "$actual" != "$expected" ]; then
        printf 'FAIL: %s: expected %s, got %s\n' "$label" "$expected" "$actual" >&2
        cat "$fixture_dir/diagnostics" >&2
        exit 1
    fi
    tests_passed=$((tests_passed + 1))
}

assert_places "unchanged commit" '[]' "$base_sha"

for file in docs/example.md places/arena/example.luau places/lobby/example.luau \
    arena.project.json lobby.project.json; do
    reset_fixture
    printf 'changed\n' >> "$file"
    commit_fixture "modify $file"
    case "$file" in
        docs/*) expected='[]' ;;
        places/arena/*|arena.project.json) expected='["arena"]' ;;
        *) expected='["lobby"]' ;;
    esac
    assert_places "modify $file" "$expected" "$base_sha"
done

for file in src/shared/example.luau Packages/example.luau \
    wally.toml wally.lock rokit.toml aftman.toml \
    .github/workflows/cicd.yml .github/actions/setup-tools/action.yml; do
    reset_fixture
    printf 'changed\n' >> "$file"
    commit_fixture "modify $file"
    assert_places "modify $file" '["arena","lobby"]' "$base_sha"
done

reset_fixture
git mv places/arena/example.luau places/lobby/moved.luau
commit_fixture "move arena module to lobby"
assert_places "cross-place rename" '["arena","lobby"]' "$base_sha"

reset_fixture
git mv src/shared/example.luau places/lobby/moved.luau
commit_fixture "move shared module to lobby"
assert_places "shared-to-place rename" '["arena","lobby"]' "$base_sha"

reset_fixture
git mv places/arena/example.luau docs/retired.luau
commit_fixture "move arena module outside deployment paths"
assert_places "rename out of deployment paths" '["arena"]' "$base_sha"

reset_fixture
git rm -q places/lobby/example.luau
commit_fixture "delete lobby module"
assert_places "deleted module" '["lobby"]' "$base_sha"

reset_fixture
printf 'new module\n' > places/arena/new.luau
printf 'new module\n' > places/lobby/new.luau
commit_fixture "add to both places"
assert_places "additions to both places" '["arena","lobby"]' "$base_sha"

reset_fixture
printf 'unusual path\n' > $'places/arena/space and\nnewline.luau'
commit_fixture "add unusual arena path"
assert_places "unusual deployment path" '["arena"]' "$base_sha"

reset_fixture
mkdir -p $'docs/newline\nplaces/lobby'
printf 'unusual documentation path\n' > $'docs/newline\nplaces/lobby/example.md'
commit_fixture "add unusual documentation path"
assert_places "newline cannot invent deployment path" '[]' "$base_sha"

assert_places "explicit historical head" '[]' "$base_sha" "$base_sha"
assert_places "unknown base" '["arena","lobby"]' missing-base
assert_places "zero base" '["arena","lobby"]' 0000000000000000000000000000000000000000
assert_places "empty base" '["arena","lobby"]' ''

if bash "$detector" "$base_sha" missing-head > "$fixture_dir/output" 2> "$fixture_dir/diagnostics"; then
    echo "FAIL: unknown head must fail." >&2
    exit 1
fi
if [ -s "$fixture_dir/output" ]; then
    echo "FAIL: unknown head must not emit a deploy matrix." >&2
    exit 1
fi
tests_passed=$((tests_passed + 1))

printf 'Changed-place regressions passed: %s\n' "$tests_passed"
