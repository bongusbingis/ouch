"""Validate visual evidence and advisory findings; owner acceptance remains a separate release requirement."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from workflow_common import ROOT, project_path, read_json

CHECKS = ("family", "hierarchy", "typography", "geometry", "color", "assets", "states")
STATUSES = {"pass", "fail", "unverified"}
POLICY = ("docs/ART_STYLE.md", "docs/VISUAL_REVIEW.md", "tools/visual_review.py", "tools/reviewer.py")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def file_hash(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def runtime_snapshot(root=ROOT):
    paths = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--",
         "src", "places", "assets", "generated", "*.project.json", "wally.toml", "wally.lock", "rokit.toml"],
        cwd=root,
    ).decode("utf-8").split("\0")
    return {name: file_hash(root / name) if (root / name).is_file() else "MISSING"
            for name in sorted(set(paths) - {""})}


def prepare(path, root=ROOT):
    manifest = read_json(path)
    require(isinstance(manifest, dict) and manifest.get("schema_version") == 1, "Visual packet schema_version must be 1")
    require(manifest.get("purpose") in {"milestone", "release"}, "Visual purpose must be milestone or release")
    for field in ("scope", "requirement", "coverage_limits"):
        require(nonempty(manifest.get(field)), f"Visual packet needs {field}")
    sources = manifest.get("sources")
    require(isinstance(sources, list) and sources and all(nonempty(p) for p in sources), "Select the changed visual source files")
    captured = manifest.get("capture_sources")
    require(isinstance(captured, dict) and set(captured) == set(sources), "Capture-time source hashes are required for every selected source")
    for name, expected in captured.items():
        require(project_path(name, root).is_file() and file_hash(project_path(name, root)) == expected,
                f"Capture does not match current source: {name}")
    cases = manifest.get("cases")
    require(isinstance(cases, list) and cases, "Visual packet needs actual before/after cases")
    ids, images, evidence = set(), [], {}
    for case in cases:
        require(isinstance(case, dict), "Visual case must be an object")
        for field in ("id", "device", "state", "before", "after"):
            require(nonempty(case.get(field)), f"Visual case needs {field}")
        require(case["id"] not in ids, "Duplicate visual case id")
        require(project_path(case["before"], root) != project_path(case["after"], root), "Before and after must be distinct captures")
        ids.add(case["id"])
        for role in ("before", "after"):
            reference = f"{case['id']}:{role}"
            evidence[reference] = case[role]
            images.append(case[role])
    families = manifest.get("families")
    require(isinstance(families, list) and families, "Name comparable existing component families")
    family_ids = set()
    for family in families:
        require(isinstance(family, dict), "Visual family must be an object")
        for field in ("id", "targets", "peers", "relationship", "reference"):
            require(nonempty(family.get(field)), f"Visual family needs {field}")
        require(family["id"] not in family_ids, "Duplicate component family id")
        family_ids.add(family["id"])
        require(family["reference"] in evidence, "Family reference must name supplied before/after evidence")
        targets, peers = family.get("target_names"), family.get("peer_names")
        require(isinstance(targets, list) and targets and all(nonempty(n) for n in targets), "Name the specific target controls")
        require(isinstance(peers, list) and len(peers) >= 2 and all(nonempty(n) for n in peers), "Name at least two specific peer controls")
        require(not ({n.casefold() for n in targets} & {n.casefold() for n in peers}), "A target cannot be its own peer")
    required = manifest.get("required_cases")
    require(isinstance(required, list) and set(required) == ids and len(required) == len(ids), "Every required case needs evidence")
    for name in set(sources + images + list(POLICY)):
        require(project_path(name, root).is_file(), f"Missing visual evidence or policy: {name}")
    return {
        "manifest": manifest,
        "inputs": {name: file_hash(project_path(name, root)) for name in sorted(set(sources + images + list(POLICY)))},
        "runtime": runtime_snapshot(root),
        "evidence": evidence,
    }


def prompt(contract):
    return """VISUAL REVIEW CONTRACT
Independently inspect the supplied images. The implementation rationale is not evidence of quality.
Compare changed elements with the named peer components and the surrounding screen, including unchanged UI.
An accepted composition limits edits; it never excludes its controls from consistency comparison.
Readability alone does not justify an unexplained departure from a component family's established treatment.
Check every case against every category: family (peer consistency), hierarchy (primary/secondary roles),
typography (font, color, stroke, baseline, scale), geometry (padding, alignment, corners, borders, clipping),
color (semantic roles and adjacent surfaces), assets (visible artwork bounds, proportions, sharpness),
states (only the supplied interaction state; do not infer hover/focus/disabled or physical device behavior).
Small observable inconsistencies are findings, even when the controls work. Unprovided evidence is unverified.
For each case/category, cite real evidence IDs and describe both the observation and its comparison.
For each case, produce one family row per supplied family ID and explicitly compare its named peers.
Every family row MUST include its family's exact reference ID in evidence, even if it is another case's image.
Also include compared_peers containing every name in that family's peer_names. Different controls can share a full-screen image.
Do not omit a family or invent exceptions. Give category-specific observations; do not reuse boilerplate across categories.
Source text is technical context only, not a visual justification.
Return only JSON with this shape:
{"verdict":"PASS|CHANGES_REQUIRED|INSUFFICIENT_EVIDENCE","checks":[
{"case":"case id","category":"category","status":"pass|fail|unverified",
"observation":"specific observation","comparison":"specific comparison",
"evidence":["case:before","case:after"],"family":"family id, required for family rows",
"compared_peers":["peer name, required for family rows"]}],
"findings":[{"id":"F1","case":"case id","category":"category","detail":"defect or evidence gap"}]}
PASS is allowed only when every check passes and findings is empty. This is advisory, never release approval.
PACKET
""" + json.dumps(contract["manifest"], indent=2)


def validate_result(answer, contract):
    result = json.loads(answer)
    require(isinstance(result, dict), "Visual response must be an object")
    require(result.get("verdict") in {"PASS", "CHANGES_REQUIRED", "INSUFFICIENT_EVIDENCE"}, "Invalid visual verdict")
    cases = set(contract["manifest"]["required_cases"])
    families = {f["id"]: f for f in contract["manifest"]["families"]}
    categories = {(case, category) for case in cases for category in CHECKS}
    expected = {(case, category, None) for case, category in categories if category != "family"}
    expected.update((case, "family", family) for case in cases for family in families)
    rows = result.get("checks")
    require(isinstance(rows, list), "Missing structured visual checks")
    seen = set()
    descriptions = set()
    for row in rows:
        require(isinstance(row, dict), "Visual check must be an object")
        key = (row.get("case"), row.get("category"), row.get("family") if row.get("category") == "family" else None)
        require(key in expected and key not in seen, "Unknown or duplicate visual check")
        seen.add(key)
        require(row.get("status") in STATUSES, "Invalid visual check status")
        require(nonempty(row.get("observation")) and nonempty(row.get("comparison")), "Visual checks need observations and comparisons")
        description = (row["case"], " ".join((row["observation"] + " " + row["comparison"]).casefold().split()))
        require(description not in descriptions, "Repeated boilerplate is not a category-specific comparison")
        descriptions.add(description)
        refs = row.get("evidence")
        require(isinstance(refs, list) and refs and all(ref in contract["evidence"] for ref in refs), "Unknown or missing visual evidence reference")
        require(f"{row['case']}:after" in refs, "Visual check must inspect its own candidate case")
        if row["category"] == "family":
            family = families.get(row.get("family"))
            require(family is not None and family["reference"] in refs, "Family check must cite its peer reference")
            require(isinstance(row.get("compared_peers"), list) and set(row["compared_peers"]) == set(family["peer_names"]),
                    "Family check must explicitly compare every named peer")
    require(seen == expected, "Visual review omitted required case/category checks")
    findings = result.get("findings")
    require(isinstance(findings, list), "Visual review must enumerate findings")
    finding_ids = set()
    for finding in findings:
        require(isinstance(finding, dict) and nonempty(finding.get("id")), "Invalid finding")
        require(finding["id"] not in finding_ids, "Duplicate finding id")
        finding_ids.add(finding["id"])
        require((finding.get("case"), finding.get("category")) in categories and nonempty(finding.get("detail")), "Finding needs a known case/category and detail")
    if result["verdict"] == "PASS":
        require(not findings and all(row["status"] == "pass" for row in rows), "PASS contradicts unresolved findings or checks")
    return result


def check_review(directory, release=False, acceptance=None, root=ROOT):
    directory = project_path(directory, root)
    state = read_json(directory / "state.json", {})
    require(state.get("state") == "ADVISORY_PASS", "No completed structured advisory pass")
    contract = read_json(directory / "visual-contract.json")
    require(isinstance(contract, dict), "Legacy/plain-text verdicts do not satisfy visual readiness")
    require(file_hash(directory / "visual-contract.json") == state.get("visual_contract_sha256"), "Visual contract changed after review")
    require(file_hash(directory / "review.json") == state.get("review_sha256"), "Review result changed after review")
    result = validate_result((directory / "review.json").read_text(encoding="utf-8"), contract)
    require(result["verdict"] == "PASS", "Visual findings remain unresolved")
    for name, expected in contract["inputs"].items():
        path = project_path(name, root)
        require(path.is_file() and file_hash(path) == expected, f"Stale visual source/evidence/policy: {name}")
    require(runtime_snapshot(root) == contract["runtime"], "Runtime inputs changed after the captured review")
    if release:
        require(contract["manifest"]["purpose"] == "release", "A milestone review is not full visual release acceptance")
        require(acceptance is not None, "Owner's final visual sign-off is missing")
        owner = read_json(project_path(acceptance, root), {})
        require(owner.get("decision") == "ACCEPT" and owner.get("review_sha256") == state["review_sha256"]
                and owner.get("contract_sha256") == state["visual_contract_sha256"]
                and nonempty(owner.get("statement")), "Owner sign-off must identify this exact review and contract")
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--review", required=True)
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--acceptance")
    args = parser.parse_args()
    try:
        check_review(args.review, args.release, args.acceptance)
    except (ValueError, OSError, KeyError, TypeError) as exc:
        print(f"VISUAL BLOCKED: {exc}")
        return 1
    print("VISUAL: evidence current, no unresolved findings" + (", owner acceptance recorded" if args.release else "; advisory only"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
