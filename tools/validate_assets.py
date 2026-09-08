"""Validate proposed content and manifest provenance without changing asset bytes."""

import argparse
import json
from asset_policy import check_provenance, validate_bytes
from workflow_common import ROOT, digest, project_path, read_json


def manifest_errors():
    errors = []
    records = read_json(ROOT / "manifests/external-assets.json", {"assets": {}})["assets"]
    for key, record in records.items():
        try:
            check_provenance(record)
            path = project_path(record["production_file"])
            if digest(path.read_bytes()) != record["sha256"]:
                raise ValueError("production bytes differ from recorded SHA-256")
        except (ValueError, KeyError, OSError) as exc:
            errors.append(f"{key}: {exc}")
    for key, record in read_json(ROOT / "manifests/assets.json", {"assets": {}})["assets"].items():
        if record.get("production_ready") and (record.get("state") != "COMPLETE" or record.get("moderation_state") != "MODERATION_STATE_APPROVED" or not record.get("asset_id")):
            errors.append(f"{key}: invalid production-ready state")
    for key, record in read_json(ROOT / "manifests/assets.json", {"assets": {}})["assets"].items():
        try:
            check_provenance(record["provenance"])
            if digest(project_path(key).read_bytes()) != record["sha256"]:
                raise ValueError("Registered production file changed after approval")
        except (ValueError, KeyError, OSError) as exc:
            errors.append(f"{key}: {exc}")
    credits = read_json(ROOT / "manifests/attribution.json", {"entries": []})["entries"]
    expected = {key for key, record in records.items() if record.get("attribution_required")}
    actual = {entry["production_file"] for entry in credits}
    if not expected.issubset(actual):
        errors.append("Attribution manifest omits required production assets; regenerate credits")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--file")
    parser.add_argument("--asset-type", default="Decal")
    args = parser.parse_args()
    if args.file:
        path = project_path(args.file)
        print(json.dumps(validate_bytes(path.read_bytes(), path.name, args.asset_type), indent=2))
    else:
        errors = manifest_errors()
        print(json.dumps({"valid": not errors, "errors": errors}, indent=2))
        return bool(errors)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
