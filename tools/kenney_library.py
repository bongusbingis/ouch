"""Index local CC0 Kenney packs and vendor selected files with provenance."""

from pathlib import Path

from asset_policy import check_provenance
from workflow_common import ROOT, atomic_write, digest, file_lock, project_path, read_json, write_json


def index_pack(pack_id, directory, source_url, license_file):
    import re

    if not re.fullmatch(r"[a-z0-9-]+", pack_id) or not source_url.startswith("https://kenney.nl/assets/"):
        raise ValueError("Use a lowercase pack ID and its official Kenney source URL")
    directory = project_path(directory)
    if not directory.is_relative_to(ROOT / "asset-library/kenney/raw"):
        raise ValueError("Extract raw packs under asset-library/kenney/raw")
    license_path = project_path(license_file)
    license_text = license_path.read_text(encoding="utf-8-sig")
    if "CC0" not in license_text or not any(word in license_text.lower() for word in ("creative commons", "creativecommons.org", "public domain")):
        raise ValueError("Pack must contain explicit CC0 licensing evidence")
    with file_lock(ROOT / ".agent-cache/manifests.lock"):
        index = read_json(ROOT / "asset-library/kenney/index.json")
        index["packs"] = [p for p in index["packs"] if p["id"] != pack_id]
        index["packs"].append({"id": pack_id, "source_url": source_url, "license": "CC0-1.0", "license_file": license_path.relative_to(ROOT).as_posix(), "local_path": directory.relative_to(ROOT).as_posix()})
        index["packs"].sort(key=lambda p: p["id"])
        index["assets"] = {key: value for key, value in index["assets"].items() if not key.startswith("kenney:" + pack_id + "/")}
        for path in sorted(directory.rglob("*")):
            if not path.is_file() or path.suffix.lower() not in {".svg", ".png", ".jpg", ".jpeg"}:
                continue
            if not path.resolve().is_relative_to(directory.resolve()):
                raise ValueError("Pack file escapes library directory")
            identifier = "kenney:" + pack_id + "/" + path.relative_to(directory).as_posix()
            index["assets"][identifier] = {"author": "Kenney", "provider": "Kenney", "collection": pack_id, "source_id": identifier,
                "source_url": source_url, "license": "CC0-1.0", "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
                "license_text": license_text, "attribution_required": False, "modifications": [], "local_path": path.relative_to(ROOT).as_posix(), "sha256": digest(path.read_bytes())}
        write_json(ROOT / "asset-library/kenney/index.json", index)
    return {"indexed_pack": pack_id, "asset_count": sum(key.startswith("kenney:" + pack_id + "/") for key in index["assets"])}


def acquire(identifier, output, size=256):
    record = dict(read_json(ROOT / "asset-library/kenney/index.json")["assets"][identifier])
    source = project_path(record["local_path"])
    data = source.read_bytes()
    if digest(data) != record["sha256"]:
        raise ValueError("Local pack changed; reindex and review it")
    destination = project_path(output)
    if not destination.is_relative_to(ROOT / "assets"):
        raise ValueError("Output must live under assets/")
    original = ROOT / "assets/source/external" / record["collection"] / source.name
    if source.suffix.lower() == ".svg" and destination.suffix.lower() == ".png":
        import resvg_py

        if not 16 <= size <= 2048:
            raise ValueError("Raster size must be 16..2048")
        production = resvg_py.svg_to_bytes(svg_string=data.decode("utf-8"), width=size, height=size)
        record["modifications"] = [f"Rasterized SVG to {size}x{size} PNG with resvg"]
    elif source.suffix.lower() == destination.suffix.lower():
        production = data
    else:
        raise ValueError("Preserve the source format or explicitly rasterize SVG to PNG")
    check_provenance(record)
    with file_lock(ROOT / ".agent-cache/manifests.lock"):
        for path, content in ((original, data), (destination, production)):
            if path.exists() and path.read_bytes() != content:
                raise ValueError("Destination collision; choose a unique output/source name")
        atomic_write(original, data)
        atomic_write(destination, production)
        record.update(original_file=original.relative_to(ROOT).as_posix(), original_sha256=digest(data), production_file=destination.relative_to(ROOT).as_posix(), sha256=digest(production))
        catalog = read_json(ROOT / "manifests/external-assets.json")
        catalog["assets"][record["production_file"]] = record
        write_json(ROOT / "manifests/external-assets.json", catalog)
        from generate_credits import generate

        generate()
    return record
