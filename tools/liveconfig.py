#!/usr/bin/env python3
"""Create the Roblox experience configs declared in src/config/LiveConfig.luau.

Every key the game allows to be overridden is declared in LiveConfig.luau, and
its default is the value baked into the matching module in src/config. This
script reads both, so the configs it creates start out identical to what the
game ships with and the two cannot drift. It also uploads the per-player AB
schema keys (PlayerAssist.luau), read at runtime via GetConfigForPlayerAsync,
which live in the same repository and would otherwise be dropped by --overwrite.

Docs: https://create.roblox.com/docs/cloud/guides/configs

  export ROBLOX_API_KEY=...            # needs universe:write (and universe:read)
  python liveconfig.py --dry-run
  python liveconfig.py --universe-id 1234567
  python liveconfig.py --universe-id 1234567 --publish
  python liveconfig.py --universe-id 1234567 --wipe --publish   # clear ALL keys

By default the script stages a draft with PATCH, which adds these keys and
leaves any other config in the repository alone. Publishing is opt-in. --wipe
overwrites the draft with an empty set so publishing it removes every key,
which is the fast way to clear out stale configs before re-seeding.
"""

from __future__ import annotations

import argparse
import ast
import json
import os
import re
import ssl
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent
REGISTRY = REPO_ROOT / "src" / "config" / "LiveConfig.luau"

# Module name as it appears in a config key -> the Luau file that defines it.
# Config modules are grouped into domain folders under src/config; a live key's
# first segment is the registration name, which need not equal its file name
# (e.g. Combat lives in Gameplay/Combat.luau).
_CONFIG = REPO_ROOT / "src" / "config"
MODULE_SOURCES = {
    "Combat": _CONFIG / "Gameplay" / "Combat.luau",
    "AimAssist": _CONFIG / "Gameplay" / "AimAssist.luau",
    "GameModes": _CONFIG / "Gameplay" / "GameModes.luau",
    "MapFeatures": _CONFIG / "Gameplay" / "MapFeatures.luau",
    "Modes": _CONFIG / "Gameplay" / "Modes.luau",
    "Shop": _CONFIG / "Economy" / "Shop.luau",
    "Crates": _CONFIG / "Economy" / "Crates.luau",
    "Matchmaking": REPO_ROOT / "places" / "lobby" / "shared" / "Matchmaking" / "Config.luau",
}

# Per-player AB schemas (PlayerConfigService). Unlike the module.leaf keys above,
# each of these declares its own flat keys and inline Default, and the game reads
# them per player through ConfigService:GetConfigForPlayerAsync. They live in the
# same repository, so they must be uploaded here too -- otherwise an --overwrite
# drops them and the game logs "Config value not found" for every key.
PLAYER_CONFIG_SOURCES = [
    _CONFIG / "PlayerAssist.luau",
]

BASE_URL = "https://apis.roblox.com/creator-configs-public-api/v1/configs"
REPOSITORY = "InExperienceConfig"
MAX_KEYS_PER_REPOSITORY = 100
MAX_KEY_LENGTH = 256
DEFAULT_MESSAGE = "Seed live config defaults from src/config"


class ConfigError(Exception):
    pass


# --- reading the Luau sources -------------------------------------------------


def strip_noise(source: str) -> str:
    """Blank out comments and string bodies so brace matching cannot be fooled.

    Replaces them with spaces rather than deleting them so every offset still
    lines up with the original text.
    """
    out = list(source)
    index = 0
    length = len(source)
    while index < length:
        char = source[index]
        if char == "-" and source.startswith("--", index):
            if source.startswith("--[[", index):
                end = source.find("]]", index + 4)
                end = length if end == -1 else end + 2
            else:
                end = source.find("\n", index)
                end = length if end == -1 else end
            for position in range(index, end):
                if out[position] != "\n":
                    out[position] = " "
            index = end
            continue
        if char == '"' or char == "'":
            quote = char
            position = index + 1
            while position < length:
                if source[position] == "\\":
                    position += 2
                    continue
                if source[position] == quote:
                    break
                position += 1
            end = min(position + 1, length)
            for position in range(index, end):
                if out[position] != "\n":
                    out[position] = " "
            index = end
            continue
        index += 1
    return "".join(out)


def matching_brace(clean: str, open_index: int) -> int:
    depth = 0
    for index in range(open_index, len(clean)):
        if clean[index] == "{":
            depth += 1
        elif clean[index] == "}":
            depth -= 1
            if depth == 0:
                return index
    raise ConfigError("unbalanced braces")


def child_ends(clean: str, name: str, lo: int, hi: int) -> list[int]:
    """Offsets past the `=` of every `name =` that is a *direct* child of the
    table whose braces span [lo, hi) (lo points at its `{`).

    Only brace-depth 1 is considered, so a same-named key inside a nested
    sub-table does not collide with the one being resolved. A Luau type
    annotation (`name: Type =`) is tolerated.
    """
    pattern = re.compile(r"\b" + re.escape(name) + r"\s*(?::[^=\n]*?)?=(?!=)")
    ends = []
    for match in pattern.finditer(clean, lo, hi):
        depth = clean.count("{", lo, match.start()) - clean.count("}", lo, match.start())
        if depth == 1:
            ends.append(match.end())
    return ends


def local_def_end(clean: str, name: str) -> int:
    """Offset past the `=` of the top-level `local name =` definition."""
    pattern = re.compile(r"\blocal\s+" + re.escape(name) + r"\s*(?::[^=\n]*?)?=(?!=)")
    matches = list(pattern.finditer(clean))
    if len(matches) != 1:
        raise ConfigError("expected exactly one 'local " + name + " =', found " + str(len(matches)))
    return matches[0].end()


def resolve_value(clean: str, source: str, after: int) -> tuple[str, int, int]:
    """Classify the value that begins just past a `=` at `after`, following a
    bare-identifier re-export alias to the local it names.

    Returns ("table", brace, end) with the braces of a table literal, or
    ("scalar", start, end) bounding the literal's text in `source`.
    """
    index = after
    while index < len(source) and source[index] in " \t":
        index += 1
    if index < len(clean) and clean[index] == "{":
        return ("table", index, matching_brace(clean, index) + 1)
    end = index
    while end < len(source) and source[end] not in ",\n}":
        end += 1
    token = source[index:end].strip()
    if re.fullmatch(r"[A-Za-z_]\w*", token):
        return resolve_value(clean, source, local_def_end(clean, token))
    return ("scalar", index, end)


def find_root(clean: str, source: str, key: str) -> tuple[int, int]:
    """Braces of the table the module returns, following `return Ident` back to
    its `local Ident = {` definition."""
    # The module's own return sits at column 0; a nested function's return
    # (e.g. a sort comparator) is indented, so anchor on the line start.
    matches = list(re.finditer(r"^return\b", clean, re.MULTILINE))
    if not matches:
        raise ConfigError(key + ": module has no top-level return")
    kind, lo, hi = resolve_value(clean, source, matches[-1].end())
    if kind != "table":
        raise ConfigError(key + ": module does not return a table")
    return lo, hi


def read_leaf(clean: str, source: str, path: list[str], key: str) -> str:
    """Walks `path` through the returned table and returns the leaf's literal.

    Each segment must name exactly one direct child of its parent so a near-miss
    fails loudly instead of silently seeding the wrong default.
    """
    lo, hi = find_root(clean, source, key)
    for depth, segment in enumerate(path):
        found = child_ends(clean, segment, lo, hi)
        if len(found) != 1:
            where = "the returned table" if depth == 0 else "'" + ".".join(path[:depth]) + "'"
            raise ConfigError(
                key + ": expected exactly one '" + segment + " =' in " + where
                + ", found " + str(len(found))
            )
        kind, vlo, vhi = resolve_value(clean, source, found[0])
        if depth == len(path) - 1:
            if kind != "scalar":
                raise ConfigError(key + ": '" + segment + "' is a table, not a leaf")
            return source[vlo:vhi].strip()
        if kind != "table":
            raise ConfigError(key + ": '" + segment + "' is not a table")
        lo, hi = vlo, vhi
    raise ConfigError(key + ": empty path")


def parse_registry(text: str) -> list[dict[str, Any]]:
    pattern = re.compile(
        r"\{\s*Key\s*=\s*\"(?P<key>[^\"]+)\"\s*,\s*Type\s*=\s*\"(?P<type>[^\"]+)\""
        r"(?:\s*,\s*Minimum\s*=\s*(?P<min>-?[\d.]+))?"
        r"(?:\s*,\s*Maximum\s*=\s*(?P<max>-?[\d.]+))?"
    )
    entries = []
    for match in pattern.finditer(text):
        entries.append(
            {
                "key": match.group("key"),
                "type": match.group("type"),
                "minimum": float(match.group("min")) if match.group("min") else None,
                "maximum": float(match.group("max")) if match.group("max") else None,
            }
        )
    return entries


def eval_number(text: str) -> float:
    """Evaluate a purely arithmetic numeric literal (e.g. `7 * 24 * 60 * 60`).

    Only number literals and +-*/ and parentheses are accepted; any name or call
    raises, so this cannot execute arbitrary Luau.
    """
    try:
        node = ast.parse(text, mode="eval").body
    except SyntaxError as error:
        raise ValueError(text) from error

    def visit(current: ast.AST) -> float:
        if isinstance(current, ast.Constant) and isinstance(current.value, (int, float)):
            return current.value
        if isinstance(current, ast.UnaryOp) and isinstance(current.op, (ast.UAdd, ast.USub)):
            operand = visit(current.operand)
            return operand if isinstance(current.op, ast.UAdd) else -operand
        if isinstance(current, ast.BinOp) and isinstance(current.op, (ast.Add, ast.Sub, ast.Mult, ast.Div)):
            left, right = visit(current.left), visit(current.right)
            if isinstance(current.op, ast.Add):
                return left + right
            if isinstance(current.op, ast.Sub):
                return left - right
            if isinstance(current.op, ast.Mult):
                return left * right
            return left / right
        raise ValueError(text)

    return float(visit(node))


def coerce(entry: dict[str, Any], literal: str) -> Any:
    key = entry["key"]
    kind = entry["type"]
    if kind == "number":
        try:
            value: Any = eval_number(literal)
        except ValueError as error:
            raise ConfigError(key + ": '" + literal + "' is not a number") from error
        if value.is_integer():
            value = int(value)
        if entry["minimum"] is not None and value < entry["minimum"]:
            raise ConfigError(
                key + ": baked default " + str(value) + " is below its declared minimum "
                + str(entry["minimum"])
            )
        if entry["maximum"] is not None and value > entry["maximum"]:
            raise ConfigError(
                key + ": baked default " + str(value) + " is above its declared maximum "
                + str(entry["maximum"])
            )
        return value
    if kind == "boolean":
        if literal not in ("true", "false"):
            raise ConfigError(key + ": '" + literal + "' is not a boolean")
        return literal == "true"
    if kind == "string":
        return literal.strip("\"'")
    raise ConfigError(key + ": unsupported type '" + kind + "'")


def parse_schema_entries(text: str) -> list[dict[str, str]]:
    """Parse a per-player schema's `{ Key = .., Type = .., Default = .. }` rows."""
    pattern = re.compile(
        r"\{\s*Key\s*=\s*\"(?P<key>[^\"]+)\"\s*,\s*Type\s*=\s*\"(?P<type>[^\"]+)\""
        r"\s*,\s*Default\s*=\s*(?P<default>[^,}\n]+)"
    )
    rows = []
    for match in pattern.finditer(text):
        rows.append(
            {"key": match.group("key"), "type": match.group("type").strip(), "default": match.group("default").strip()}
        )
    return rows


def coerce_default(key: str, kind: str, literal: str) -> Any:
    if kind == "boolean":
        if literal not in ("true", "false"):
            raise ConfigError(key + ": '" + literal + "' is not a boolean")
        return literal == "true"
    if kind == "number":
        try:
            value = eval_number(literal)
        except ValueError as error:
            raise ConfigError(key + ": '" + literal + "' is not a number") from error
        return int(value) if value.is_integer() else value
    raise ConfigError(key + ": unsupported per-player type '" + kind + "'")


def collect_player_config_entries() -> dict[str, Any]:
    values: dict[str, Any] = {}
    for path in PLAYER_CONFIG_SOURCES:
        if not path.exists():
            raise ConfigError("missing per-player config source " + str(path))
        rows = parse_schema_entries(path.read_text(encoding="utf-8"))
        if not rows:
            raise ConfigError("no entries parsed from " + str(path))
        for row in rows:
            key = row["key"]
            if len(key) > MAX_KEY_LENGTH:
                raise ConfigError(key + ": key exceeds " + str(MAX_KEY_LENGTH) + " characters")
            if key in values:
                raise ConfigError("duplicate per-player key " + key)
            values[key] = coerce_default(key, row["type"], row["default"])
    return values


def collect_entries() -> dict[str, Any]:
    if not REGISTRY.exists():
        raise ConfigError("registry not found: " + str(REGISTRY))
    registry = parse_registry(REGISTRY.read_text(encoding="utf-8"))
    if not registry:
        raise ConfigError("no entries parsed from " + str(REGISTRY))

    cache: dict[str, tuple[str, str]] = {}
    values: dict[str, Any] = {}
    for entry in registry:
        key = entry["key"]
        if len(key) > MAX_KEY_LENGTH:
            raise ConfigError(key + ": key exceeds " + str(MAX_KEY_LENGTH) + " characters")
        module_name, _, remainder = key.partition(".")
        if not remainder:
            raise ConfigError(key + ": key needs a module and a leaf path")
        if module_name not in MODULE_SOURCES:
            raise ConfigError(key + ": no source file mapped for module '" + module_name + "'")
        if module_name not in cache:
            source_path = MODULE_SOURCES[module_name]
            if not source_path.exists():
                raise ConfigError(key + ": missing source file " + str(source_path))
            source = source_path.read_text(encoding="utf-8")
            cache[module_name] = (strip_noise(source), source)
        clean, source = cache[module_name]
        values[key] = coerce(entry, read_leaf(clean, source, remainder.split("."), key))

    for key, value in collect_player_config_entries().items():
        if key in values:
            raise ConfigError("key collision between LiveConfig and a per-player schema: " + key)
        values[key] = value
    return values


# --- Open Cloud ---------------------------------------------------------------


def tls_context() -> ssl.SSLContext:
    """A verifying TLS context that works on a python.org build whose system CA
    store is empty: prefer certifi's bundle, else the OpenSSL defaults."""
    try:
        import certifi

        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        return ssl.create_default_context()


def request(method: str, url: str, api_key: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"x-api-key": api_key, "Accept": "application/json"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    call = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(call, context=tls_context()) as response:
            payload = response.read().decode("utf-8")
            return json.loads(payload) if payload.strip() else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace").strip()
        hint = ""
        if error.code in (401, 403):
            hint = "  (check the key's universe:write scope and its allowed universes)"
        raise ConfigError(
            method + " " + url + " failed: HTTP " + str(error.code) + " " + str(error.reason)
            + hint + "\n" + detail
        ) from error
    except urllib.error.URLError as error:
        hint = ""
        if isinstance(error.reason, ssl.SSLCertVerificationError):
            hint = (
                "  (TLS verification failed. Install certifi: `python3 -m pip install --upgrade certifi`,"
                " or run the bundled '/Applications/Python 3.x/Install Certificates.command'.)"
            )
        raise ConfigError(method + " " + url + " failed: " + str(error.reason) + hint) from error


def publish_draft(base: str, api_key: str, draft_hash: str, message: str, gradual: bool) -> None:
    strategy = "GradualRollout" if gradual else "Immediate"
    published = request(
        "POST",
        base + "/publish",
        api_key,
        {"draftHash": draft_hash, "message": message, "deploymentStrategy": strategy},
    )
    print("Published (" + strategy + ") as config version " + str(published.get("configVersion", "?")) + ".")
    print("Live servers pick this up within about 5 minutes.")


def wipe(args: argparse.Namespace) -> int:
    if not args.universe_id:
        print("\nerror: --universe-id is required (or set ROBLOX_UNIVERSE_ID)", file=sys.stderr)
        return 1

    print("WIPE: overwrites the draft with an empty set, dropping EVERY key in")
    print("  " + REPOSITORY + " for universe " + str(args.universe_id) + ".")
    if not args.publish:
        print("This only stages an empty draft; add --publish to remove the live keys.")

    if args.dry_run:
        print("\nDry run: nothing sent.")
        return 0

    if not args.api_key:
        print("\nerror: --api-key is required (or set ROBLOX_API_KEY)", file=sys.stderr)
        return 1

    if not args.yes:
        if not sys.stdin.isatty():
            print("\nerror: refusing to wipe without --yes in a non-interactive shell", file=sys.stderr)
            return 1
        if input("\nType the universe id to confirm the wipe: ").strip() != str(args.universe_id):
            print("Aborted: confirmation did not match.")
            return 0

    base = BASE_URL + "/universes/" + str(args.universe_id) + "/repositories/" + REPOSITORY
    message = args.message if args.message != DEFAULT_MESSAGE else "Wipe all live configs"
    try:
        result = request("PUT", base + "/draft:overwrite", args.api_key, {"entries": {}})
        draft_hash = result.get("draftHash")
        if not draft_hash:
            raise ConfigError("no draftHash in response: " + json.dumps(result))
        print("\nEmpty draft staged: " + str(draft_hash))
        if not args.publish:
            print("Not published. Review in Creator Hub, or re-run with --publish to remove the keys.")
            return 0
        publish_draft(base, args.api_key, draft_hash, message, args.gradual)
    except ConfigError as error:
        print("\nerror: " + str(error), file=sys.stderr)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--universe-id",
        default=os.environ.get("ROBLOX_UNIVERSE_ID"),
        help="target universe id (or set ROBLOX_UNIVERSE_ID)",
    )
    parser.add_argument(
        "--api-key",
        default=os.environ.get("ROBLOX_API_KEY"),
        help="Open Cloud API key (or set ROBLOX_API_KEY)",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="replace the whole draft with PUT instead of adding with PATCH; "
        "this DROPS any config key not listed in LiveConfig.luau",
    )
    parser.add_argument(
        "--wipe",
        action="store_true",
        help="overwrite the draft with an EMPTY set, dropping every key in the repository "
        "(clears stale configs). Combine with --publish to remove the live keys",
    )
    parser.add_argument(
        "--yes",
        "-y",
        action="store_true",
        help="skip the typed confirmation prompt (required for --wipe in a non-interactive shell)",
    )
    parser.add_argument(
        "--publish",
        action="store_true",
        help="publish the draft so the values go live; without this the draft is only staged",
    )
    parser.add_argument(
        "--message",
        default=DEFAULT_MESSAGE,
        help="publish message recorded in the config history",
    )
    parser.add_argument(
        "--gradual",
        action="store_true",
        help="publish with GradualRollout (about 15 minutes) instead of Immediate",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print the entries that would be sent, then exit without calling Roblox",
    )
    args = parser.parse_args()

    if args.wipe:
        if args.overwrite:
            print("error: --wipe and --overwrite are mutually exclusive", file=sys.stderr)
            return 1
        return wipe(args)

    try:
        entries = collect_entries()
    except ConfigError as error:
        print("error: " + str(error), file=sys.stderr)
        return 1

    print(
        "Resolved " + str(len(entries)) + " config entries from LiveConfig.luau, the per-player"
        " schemas, and src/config:\n"
    )
    for key in sorted(entries):
        print("  " + key.ljust(44) + " " + json.dumps(entries[key]))

    if len(entries) > MAX_KEYS_PER_REPOSITORY:
        print(
            "\nerror: " + str(len(entries)) + " keys exceeds the "
            + str(MAX_KEYS_PER_REPOSITORY) + "-key repository limit",
            file=sys.stderr,
        )
        return 1

    if args.dry_run:
        print("\nDry run: nothing sent.")
        return 0

    if not args.universe_id:
        print("\nerror: --universe-id is required (or set ROBLOX_UNIVERSE_ID)", file=sys.stderr)
        return 1
    if not args.api_key:
        print("\nerror: --api-key is required (or set ROBLOX_API_KEY)", file=sys.stderr)
        return 1

    base = BASE_URL + "/universes/" + str(args.universe_id) + "/repositories/" + REPOSITORY
    try:
        if args.overwrite:
            print("\nOverwriting draft (PUT): any key not listed above will be dropped.")
            result = request("PUT", base + "/draft:overwrite", args.api_key, {"entries": entries})
        else:
            print("\nStaging draft (PATCH): existing keys not listed above are left alone.")
            result = request("PATCH", base + "/draft", args.api_key, {"entries": entries})

        draft_hash = result.get("draftHash")
        if not draft_hash:
            raise ConfigError("no draftHash in response: " + json.dumps(result))
        print("Draft staged: " + str(draft_hash))

        if not args.publish:
            print("\nNot published. Review the draft in Creator Hub, or re-run with --publish.")
            return 0

        publish_draft(base, args.api_key, draft_hash, args.message, args.gradual)
    except ConfigError as error:
        print("\nerror: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
