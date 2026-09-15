"""Search canonical assets first; acquire licensed icons with immutable provenance."""

import argparse
import io
import json
from pathlib import Path
import re

import httpx

from asset_policy import check_provenance, license_status
from workflow_common import ROOT, atomic_write, digest, file_lock, project_path, read_json, write_json

API = "https://api.iconify.design"


def fetch(path, **params):
    response = httpx.get(API + path, params=params, timeout=30, follow_redirects=False)
    response.raise_for_status()
    return response


def search(query):
    config = read_json(ROOT / "tools/workflow.json")
    canonical = config["canonical_icons"]
    local = read_json(ROOT / "manifests/external-assets.json")["assets"]
    kenney = read_json(ROOT / "asset-library/kenney/index.json")["assets"]
    matches = lambda rows: {key: row for key, row in rows.items() if query.casefold() in (key + " " + json.dumps(row)).casefold()}
    remote = fetch("/search", query=query, prefixes=",".join(config["preferred_icon_prefixes"]), limit=32).json()
    candidates = sorted(remote.get("icons", []), key=lambda name: (not ("rounded" in name or name.endswith(("-bold", "-fill"))), name))
    return {"1_canonical_figma": matches(canonical), "2_project": matches(local), "3_iconify": candidates,
            "4_kenney": matches(kenney), "5_game_icons": fetch("/search", query=query, prefix="game-icons", limit=12).json().get("icons", []),
            "next": "Reuse canonical matches. Inspect license metadata before acquisition. Custom Figma then generated art only if existing sources are inadequate."}


def license_text(url):
    if not url.startswith("https://"):
        raise ValueError("HTTPS license URL required")
    if re.match(r"https://github.com/[^/]+/[^/]+/blob/", url):
        url = url.replace("https://github.com/", "https://raw.githubusercontent.com/", 1).replace("/blob/", "/", 1)
    response = httpx.get(url, timeout=30, follow_redirects=True)
    response.raise_for_status()
    content = response.text
    if "<html" in content[:500].lower() or len(content) > 100_000:
        raise ValueError("License is not plain text; use --license-text with the reviewed upstream license file")
    return content


def acquire(identifier, output, license_file=None, size=256):
    if not re.fullmatch(r"[a-z0-9-]+:[a-z0-9-]+", identifier):
        raise ValueError("Provider identifier must be collection:icon")
    prefix, name = identifier.split(":")
    metadata = fetch("/collection", prefix=prefix, info="true").json()["info"]
    info = metadata.get("license", {})
    spdx = info.get("spdx")
    if license_status(spdx) != "accepted":
        raise ValueError(f"License refused: {spdx or 'unknown'} ({license_status(spdx)})")
    svg = fetch(f"/{prefix}/{name}.svg").content
    destination = project_path(output)
    if not destination.is_relative_to(ROOT / "assets"):
        raise ValueError("Acquisition output must be under assets/")
    if destination.suffix.lower() not in {".svg", ".png"} or not 16 <= size <= 2048:
        raise ValueError("Output must be SVG or PNG; size 16..2048")
    original = ROOT / "assets/source/external" / prefix / (name + ".svg")
    production = svg
    modifications = []
    if destination.suffix.lower() == ".png":
        import resvg_py

        production = resvg_py.svg_to_bytes(svg_string=svg.decode("utf-8"), width=size, height=size)
        modifications.append(f"Rasterized original SVG to {size}x{size} PNG with resvg")
    record = {"author": metadata.get("author", {}).get("name", ""), "provider": "Iconify", "collection": prefix,
              "source_id": identifier, "source_url": f"https://icon-sets.iconify.design/{prefix}/{name}/", "license": spdx,
              "license_url": info.get("url", ""), "attribution_required": spdx != "CC0-1.0", "modifications": modifications,
              "original_file": original.relative_to(ROOT).as_posix(), "original_sha256": digest(svg),
              "production_file": destination.relative_to(ROOT).as_posix(), "sha256": digest(production),
              "license_text": project_path(license_file).read_text(encoding="utf-8") if license_file else license_text(info.get("url", "")),
              "collection_metadata": metadata}
    check_provenance(record)
    with file_lock(ROOT / ".agent-cache/manifests.lock"):
        catalog = read_json(ROOT / "manifests/external-assets.json")
        if destination.exists() and destination.read_bytes() != production:
            raise ValueError("Output already exists with different bytes; choose a new path")
        if original.exists() and original.read_bytes() != svg:
            raise ValueError("Upstream original changed; preserve the old source and acquire a versioned identifier")
        atomic_write(original, svg)
        atomic_write(destination, production)
        catalog["assets"][record["production_file"]] = record
        write_json(ROOT / "manifests/external-assets.json", catalog)
        from generate_credits import generate

        generate()
    return record


def contact_sheet(files, output, reference):
    from PIL import Image, ImageDraw

    paths = [project_path(value) for value in files]
    sheet = Image.new("RGB", (800, 220 * ((len(paths) + 3) // 4) + 400), "#f2eef7")
    draw = ImageDraw.Draw(sheet)
    for index, path in enumerate(paths):
        tile = Image.open(path).convert("RGBA")
        tile.thumbnail((160, 160))
        x, y = (index % 4) * 200 + 20, (index // 4) * 220 + 10
        sheet.paste(tile, (x, y), tile)
        draw.text((x, y + 165), path.stem[:28], fill="#202030")
    context = Image.open(project_path(reference)).convert("RGB")
    context.thumbnail((780, 370))
    sheet.paste(context, (10, sheet.height - 380))
    buffer = io.BytesIO()
    sheet.save(buffer, format="PNG")
    atomic_write(project_path(output), buffer.getvalue())


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    find = commands.add_parser("search")
    find.add_argument("query")
    get = commands.add_parser("acquire")
    get.add_argument("provider_id")
    get.add_argument("--output", required=True)
    get.add_argument("--license-text")
    get.add_argument("--size", type=int, default=256)
    local = commands.add_parser("kenney-index")
    local.add_argument("--pack-id", required=True)
    local.add_argument("--path", required=True)
    local.add_argument("--source-url", required=True)
    local.add_argument("--license-file", required=True)
    sheet = commands.add_parser("contact-sheet")
    sheet.add_argument("files", nargs="+")
    sheet.add_argument("--reference", required=True)
    sheet.add_argument("--output", required=True)
    args = parser.parse_args()
    if args.command == "search":
        print(json.dumps(search(args.query), indent=2))
    elif args.command == "kenney-index":
        from kenney_library import index_pack

        print(json.dumps(index_pack(args.pack_id, args.path, args.source_url, args.license_file), indent=2))
    elif args.command == "acquire":
        if args.provider_id.startswith("kenney:"):
            from kenney_library import acquire as acquire_local

            result = acquire_local(args.provider_id, args.output, args.size)
        else:
            result = acquire(args.provider_id, args.output, args.license_text, args.size)
        print(json.dumps(result, indent=2))
    else:
        contact_sheet(args.files, args.output, args.reference)


if __name__ == "__main__":
    main()
