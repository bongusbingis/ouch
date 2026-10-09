"""Shared fail-closed upload validation, copied into the installed gate."""

import io
import re
from pathlib import Path

ACCEPTED_LICENSES = {"CC0-1.0", "MIT", "ISC", "Apache-2.0", "CC-BY-3.0", "CC-BY-4.0"}
MAX_BYTES = 20_000_000
MAX_IMAGE_SIDE_EXCLUSIVE = 8000
FORMATS = {
    "Decal": {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".bmp": "image/bmp", ".tga": "image/tga"},
    "Image": {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".bmp": "image/bmp", ".tga": "image/tga"},
    "Model": {".fbx": "model/fbx", ".glb": "model/gltf-binary"},
    "Animation": {".rbxm": "model/x-rbxm"},
}
REVIEW_VIEWS = ("front", "rear", "left", "right", "top", "perspective", "wireframe", "material", "studio")
ANIMATION_VIEWS = ("sheet", "studio")
RBXM_MAGIC = b"<roblox!\x89\xff\r\n\x1a\n"


def evidence_views(asset_type):
    return REVIEW_VIEWS if asset_type == "Model" else ANIMATION_VIEWS if asset_type == "Animation" else ()
POLICY_SOURCE = "https://create.roblox.com/docs/cloud/guides/usage-assets"


def license_status(spdx):
    if spdx in ACCEPTED_LICENSES:
        return "accepted"
    if isinstance(spdx, str) and (spdx.startswith(("CC-BY-SA-", "MPL-")) or spdx == "custom"):
        return "manual_review"
    return "blocked"


def check_provenance(record):
    if not isinstance(record, dict):
        raise ValueError("Provenance record required")
    for field in ("author", "provider", "source_id", "source_url", "license", "license_url"):
        if not isinstance(record.get(field), str) or not record[field].strip():
            raise ValueError(f"Missing provenance: {field}")
    if not isinstance(record.get("modifications"), list):
        raise ValueError("modifications must be a list (empty means unchanged)")
    if not isinstance(record.get("attribution_required"), bool):
        raise ValueError("Explicit attribution_required boolean required")
    if record["license"] != "Project-Owned" or record["provider"] not in {"project", "figma", "blender"}:
        status = license_status(record["license"])
        if status != "accepted":
            raise ValueError(f"License {status}: {record['license']}; resolve before production acquisition")
    if record["license"] != "CC0-1.0" and record["license"] != "Project-Owned":
        if not record["attribution_required"]:
            raise ValueError("Attribution/notice retention required for this license")
        if not record.get("license_text"):
            raise ValueError("Full upstream license/notice text required")


def validate_bytes(data, filename, asset_type, metadata=None):
    suffix = Path(filename).suffix.lower()
    if asset_type not in FORMATS or suffix not in FORMATS[asset_type]:
        raise ValueError("Unsupported gate format/type; supported: images, self-contained FBX/GLB Model, or binary .rbxm Animation")
    if not 0 < len(data) <= MAX_BYTES:
        raise ValueError(f"Asset must contain 1..{MAX_BYTES} bytes")
    result = {"valid": True, "bytes": len(data), "content_type": FORMATS[asset_type][suffix], "checks": ["supported format", "size limit"]}
    if asset_type in {"Image", "Decal"}:
        from PIL import Image

        with Image.open(io.BytesIO(data)) as image:
            expected = {".png": "PNG", ".jpg": "JPEG", ".jpeg": "JPEG", ".bmp": "BMP", ".tga": "TGA"}[suffix]
            if image.format != expected or getattr(image, "n_frames", 1) != 1:
                raise ValueError("Image encoding/extension mismatch or animated input")
            if max(image.size) >= MAX_IMAGE_SIDE_EXCLUSIVE or min(image.size) < 1:
                raise ValueError("Image must be smaller than 8000x8000")
            result["dimensions"] = list(image.size)
            image.verify()
        result["checks"].append("decoded image and dimensions")
    elif suffix == ".glb":
        import struct
        import json

        if len(data) < 20 or data[:4] != b"glTF":
            raise ValueError("Invalid GLB header")
        version, size, chunk_size, kind = struct.unpack_from("<IIII", data, 4)
        if version != 2 or size != len(data) or kind != 0x4E4F534A:
            raise ValueError("Invalid GLB container")
        document = json.loads(data[20:20 + chunk_size])
        for entry in document.get("buffers", []) + document.get("images", []):
            if "uri" in entry and not entry["uri"].startswith("data:"):
                raise ValueError("External GLB dependencies are not supported")
    elif suffix == ".rbxm":
        if not data.startswith(RBXM_MAGIC) or len(data) < 32 or data[14:16] != b"\x00\x00":
            raise ValueError("Invalid binary .rbxm header")
        if b"END\x00" not in data[-64:]:
            raise ValueError("Truncated .rbxm (missing END chunk)")
        result["checks"].append("binary rbxm header and END chunk")
    elif not (data.startswith(b"Kaydara FBX Binary  \x00\x1a\x00") or b"FBXHeaderExtension" in data[:4096]):
        raise ValueError("Invalid FBX header")
    if metadata:
        if not re.fullmatch(r"(?:user|group):[1-9][0-9]*", metadata.get("creator", "")):
            raise ValueError("creator must be user:ID or group:ID")
        if not isinstance(metadata.get("display_name"), str) or not metadata.get("display_name", "").strip() or len(metadata["display_name"]) > 50:
            raise ValueError("Display name must be 1..50 characters")
        if not isinstance(metadata.get("description"), str) or len(metadata["description"]) > 1000:
            raise ValueError("Description must be at most 1000 characters")
        target = metadata.get("target_asset_id")
        if target and (not re.fullmatch(r"[1-9][0-9]*", str(target)) or suffix != ".fbx" or asset_type != "Model"):
            raise ValueError("Content updates support only FBX Model with a positive target asset ID")
        check_provenance(metadata.get("provenance"))
        if asset_type == "Model":
            evidence = metadata.get("model_evidence", {})
            if not all(evidence.get(view) for view in REVIEW_VIEWS):
                raise ValueError("Model needs all nine review views, including Studio")
            if not evidence.get("statistics") or not evidence.get("source_blend"):
                raise ValueError("Model statistics and saved .blend source required")
            result["model_statistics"] = evidence["statistics"]
            result["checks"].append("review evidence declared; human must assess model geometry/materials")
        elif asset_type == "Animation":
            evidence = metadata.get("model_evidence") or {}
            if not all(evidence.get(view) for view in ANIMATION_VIEWS):
                raise ValueError("Animation needs a Blender contact sheet and a Studio capture as review evidence")
            statistics = evidence.get("statistics")
            if not isinstance(statistics, dict) or not evidence.get("source_blend"):
                raise ValueError("Animation statistics and saved .blend source required")
            for field in ("keyframes", "duration", "looped", "joints"):
                if field not in statistics:
                    raise ValueError(f"Animation statistics missing {field}")
            if not (isinstance(statistics["keyframes"], int) and statistics["keyframes"] >= 2):
                raise ValueError("Animation must declare at least two keyframes")
            if not (isinstance(statistics["duration"], (int, float)) and 0 < statistics["duration"] <= 30):
                raise ValueError("Animation duration must be within 0..30 seconds")
            result["model_statistics"] = statistics
            result["checks"].append("review evidence declared; human must assess motion, timing and rig compatibility")
    return result
