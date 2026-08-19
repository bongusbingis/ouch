#!/usr/bin/env python3
"""Create the Roblox experience configs declared in src/config/LiveConfig.luau.

Every key the game allows to be overridden is declared in LiveConfig.luau, and
its default is the value baked into the matching module in src/config. This
script reads both, so the configs it creates start out identical to what the
game ships with and the two cannot drift.

Docs: https://create.roblox.com/docs/cloud/guides/configs

  export ROBLOX_API_KEY=...            # needs universe:write (and universe:read)
  python liveconfig.py --dry-run
  python liveconfig.py --universe-id 1234567
  python liveconfig.py --universe-id 1234567 --publish

By default the script stages a draft with PATCH, which adds these keys and
leaves any other config in the repository alone. Publishing is opt-in.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent
REGISTRY = REPO_ROOT / "src" / "config" / "LiveConfig.luau"

# Module name as it appears in a config key -> the Luau file that defines it.
MODULE_SOURCES = {
    "Combat": REPO_ROOT / "src" / "config" / "Combat.luau",
    "AimAssist": REPO_ROOT / "src" / "config" / "AimAssist.luau",
    "GameModes": REPO_ROOT / "src" / "config" / "GameModes.luau",
    "MapFeatures": REPO_ROOT / "src" / "config" / "MapFeatures.luau",
    "Matchmaking": REPO_ROOT / "places" / "lobby" / "src" / "shared" / "Matchmaking" / "Config.luau",
}

BASE_URL = "https://apis.roblox.com/creator-configs-public-api/v1/configs"
REPOSITORY = "InExperienceConfig"
MAX_KEYS_PER_REPOSITORY = 100
MAX_KEY_LENGTH = 256


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


def assignments(clean: str, name: str, lo: int, hi: int) -> list[int]:
    """Offsets just past every `name =` assignment inside [lo, hi)."""
    pattern = re.compile(r"\b" + re.escape(name) + r"\s*=(?!=)")
    return [lo + match.end() for match in pattern.finditer(clean[lo:hi])]


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


def read_leaf(clean: str, source: str, path: list[str], key: str) -> str:
    """Walks `path` through nested Luau tables and returns the leaf's literal.

    Requires each name to be unambiguous within its parent so a near-miss fails
    loudly instead of silently seeding the wrong default.
    """
    lo, hi = 0, len(clean)
    for depth, segment in enumerate(path):
        found = assignments(clean, segment, lo, hi)
        if len(found) != 1:
            where = "the file" if depth == 0 else "'" + ".".join(path[:depth]) + "'"
            raise ConfigError(
                key + ": expected exactly one '" + segment + " =' in " + where
                + ", found " + str(len(found))
            )
        after = found[0]
        if depth == len(path) - 1:
            end = after
            while end < hi and clean[end] not in ",\n}":
                end += 1
            return source[after:end].strip()
        brace = clean.find("{", after)
        if brace == -1:
            raise ConfigError(key + ": '" + segment + "' is not a table")
        lo, hi = brace, matching_brace(clean, brace) + 1
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


def coerce(entry: dict[str, Any], literal: str) -> Any:
    key = entry["key"]
    kind = entry["type"]
    if kind == "number":
        try:
            value: Any = float(literal)
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
    return values


# --- Open Cloud ---------------------------------------------------------------


def request(method: str, url: str, api_key: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"x-api-key": api_key, "Accept": "application/json"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    call = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(call) as response:
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
        raise ConfigError(method + " " + url + " failed: " + str(error.reason)) from error


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
        "--publish",
        action="store_true",
        help="publish the draft so the values go live; without this the draft is only staged",
    )
    parser.add_argument(
        "--message",
        default="Seed live config defaults from src/config",
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

    try:
        entries = collect_entries()
    except ConfigError as error:
        print("error: " + str(error), file=sys.stderr)
        return 1

    print("Resolved " + str(len(entries)) + " config entries from LiveConfig.luau and src/config:\n")
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

        strategy = "GradualRollout" if args.gradual else "Immediate"
        published = request(
            "POST",
            base + "/publish",
            args.api_key,
            {"draftHash": draft_hash, "message": args.message, "deploymentStrategy": strategy},
        )
        print("Published (" + strategy + ") as config version " + str(published.get("configVersion", "?")) + ".")
        print("Live servers pick this up within about 5 minutes.")
    except ConfigError as error:
        print("\nerror: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
