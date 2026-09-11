"""Reproducible icon atlases and upload metadata for the UI redesign.

Original Iconify SVGs and notices remain in the acquisition manifest. Atlases
keep each collection's license separate, and white masks can be tinted in UI.
"""

import io
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
import resvg_py
import httpx

from workflow_common import ROOT, digest, read_json, write_json

ICONS = {
    "Confetti": ("ph:confetti-fill", "effect-confetti"),
    "Star": ("ph:star-fill", "effect-star"),
    "Cloud": ("ph:cloud-fill", "effect-cloud"),
    "Crown": ("ph:crown-fill", "effect-crown"),
    "Diamond": ("ph:diamond-fill", "effect-diamond"),
    "Planet": ("ph:planet-fill", "effect-planet"),
    "Sparkle": ("ph:sparkle-fill", "effect-sparkle"),
    "IceCream": ("ph:ice-cream-fill", "effect-icecream"),
    "Bubbles": ("ph:circles-three-fill", "effect-bubbles-round"),
    "Candy": ("ph:cookie-fill", "effect-candy"),
    "Bell": ("ph:bell-fill", "sound-bell"),
    "Speaker": ("ph:speaker-high-fill", "sound-speaker"),
    "Target": ("ph:target-fill", "quest-target"),
    "Hand": ("ph:hand-grabbing-fill", "quest-hand"),
    "Trophy": ("ph:trophy-fill", "quest-trophy"),
    "Controller": ("ph:game-controller-fill", "quest-controller"),
    "Hammer": ("ph:hammer-fill", "quest-hammer"),
    "Ball": ("ph:baseball-fill", "quest-ball"),
    "Check": ("ph:check-bold", "ui-check"),
    "Celebration": ("material-symbols:celebration-rounded", "effect-celebration"),
    "Explosion": ("material-symbols:explosion-rounded", "effect-explosion"),
    "Drop": ("material-symbols:water-drop-rounded", "effect-drop"),
}


def acquire_from_mirror(identifier, path, catalog):
    """Use Iconify's canonical GitHub data when its public API is throttled."""
    prefix, name = identifier.split(":")
    url = f"https://raw.githubusercontent.com/iconify/icon-sets/master/json/{prefix}.json"
    cache = ROOT / f".agent-cache/redesign-{prefix}.json"
    if not cache.exists():
        response = httpx.get(url, timeout=45)
        response.raise_for_status()
        cache.write_bytes(response.content)
    pack = json.loads(cache.read_text(encoding="utf-8"))
    icon = pack["icons"][name]
    width, height = icon.get("width", pack.get("width", 24)), icon.get("height", pack.get("height", 24))
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}">{icon["body"]}</svg>'
    original = ROOT / f"assets/source/external/{prefix}/{name}.svg"
    if original.exists() and original.read_text(encoding="utf-8") != svg:
        raise ValueError(f"Existing source differs: {original}")
    original.write_text(svg, encoding="utf-8")
    data = resvg_py.svg_to_bytes(svg_string=svg, width=256, height=256)
    (ROOT / path).write_bytes(data)
    peer = next(r for r in catalog.values() if r.get("collection") == prefix)
    record = {k: peer[k] for k in ("author", "provider", "collection", "license", "license_url", "license_text", "attribution_required", "collection_metadata")}
    record.update(source_id=identifier, source_url=f"https://icon-sets.iconify.design/{prefix}/{name}/", retrieval_url=url,
                  original_file=original.relative_to(ROOT).as_posix(), original_sha256=digest(svg.encode()),
                  production_file=path, sha256=digest(data), modifications=["Rasterized original Iconify glyph from canonical GitHub mirror to 256px PNG with resvg"])
    catalog[path] = record
    write_json(ROOT / "manifests/external-assets.json", {"schema_version": 1, "assets": catalog})


def main():
    catalog = read_json(ROOT / "manifests/external-assets.json")["assets"]
    previous = {a["file"]: a.get("roblox") for a in read_json(ROOT / "tools/redesign-assets.json", {"assets": []})["assets"]}
    for key, (source_id, stem) in ICONS.items():
        path = f"assets/ui/{stem}.png"
        if path not in catalog:
            print(f"Acquire {source_id}", flush=True)
            acquire_from_mirror(source_id, path, catalog)
            catalog = read_json(ROOT / "manifests/external-assets.json")["assets"]
        assert catalog[path]["source_id"] == source_id, key

    bindings = {"icons": {}, "assets": []}
    for collection in ("ph", "material-symbols"):
        entries = [(k, v) for k, v in ICONS.items() if v[0].startswith(collection + ":")]
        cell = 192
        cols = min(5, len(entries))
        rows = (len(entries) + cols - 1) // cols
        atlas = Image.new("RGBA", (cell * cols, cell * rows))
        sheet = Image.new("RGB", (cols * 192, rows * 220), "#1185CC")
        draw = ImageDraw.Draw(sheet)
        sources = []
        for i, (key, (_, stem)) in enumerate(entries):
            record = catalog[f"assets/ui/{stem}.png"]
            svg = (ROOT / record["original_file"]).read_text(encoding="utf-8")
            svg = svg.replace("currentColor", "#FFFFFF")
            glyph = Image.open(io.BytesIO(resvg_py.svg_to_bytes(svg_string=svg, width=160, height=160))).convert("RGBA")
            x, y = i % cols * cell, i // cols * cell
            atlas.alpha_composite(glyph, (x + 16, y + 16))
            sx, sy = x, i // cols * 220
            draw.rounded_rectangle((sx+16, sy+12, sx+176, sy+172), radius=12, fill="#1E2024")
            glyph_preview = glyph.resize((112, 112), Image.Resampling.LANCZOS)
            sheet.paste(glyph_preview, (sx+40, sy+36), glyph_preview)
            draw.text((sx+16, sy+182), key, fill="white")
            bindings["icons"][key] = {"file": f"assets/ui/redesign-{collection}.png", "offset": [x, y], "size": [cell, cell], "source_id": record["source_id"]}
            sources.append(record)
        output = ROOT / f"assets/ui/redesign-{collection}.png"
        atlas.save(output)
        review = ROOT / ".review/production/2026-09-10-redesign/completion"
        review.mkdir(parents=True, exist_ok=True)
        sheet.save(review / f"icons-{collection}.png")
        provenance = {k: sources[0][k] for k in ("author", "provider", "license", "license_url", "license_text", "attribution_required")}
        provenance.update(source_id=f"{collection}:ouch-redesign-atlas", source_url=sources[0]["source_url"],
                          modifications=["Packed licensed SVGs into 192px cells; currentColor rendered white with 16px gutters for Roblox tinting."],
                          sources=[{k: r[k] for k in ("source_id", "source_url", "original_file", "original_sha256")} for r in sources],
                          production_file=output.relative_to(ROOT).as_posix(), sha256=digest(output.read_bytes()))
        catalog[provenance["production_file"]] = provenance
        provpath = ROOT / f"assets/source/external/redesign-{collection}.provenance.json"
        write_json(provpath, provenance)
        bindings["assets"].append({"file": provenance["production_file"], "provenance": provpath.relative_to(ROOT).as_posix(), "name": f"OUCH UI icons {collection}"})
    for stem, name in (("page-panel-9slice", "OUCH page panel R16"), ("well-9slice", "OUCH inner well R12")):
        destination = ROOT / f"assets/ui/{stem}.png"
        destination.write_bytes((ROOT / f"assets/source/figma/exports/{stem}.png").read_bytes())
        bindings["assets"].append({"file": destination.relative_to(ROOT).as_posix(), "provenance": f"assets/source/figma/{stem}.provenance.json", "name": name})
    write_json(ROOT / "manifests/external-assets.json", {"schema_version": 1, "assets": catalog})
    for asset in bindings["assets"]:
        if previous.get(asset["file"]):
            asset["roblox"] = previous[asset["file"]]
    write_json(ROOT / "tools/redesign-assets.json", bindings)
    from generate_credits import generate
    generate()
    print(f"Prepared {len(ICONS)} icons in two atlases plus the two Figma panel exports.")


if __name__ == "__main__":
    main()
