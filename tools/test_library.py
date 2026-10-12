"""Local pack validation and acquisition regressions using disposable CC0 fixtures."""

import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image
import kenney_library as library
import generate_credits
from workflow_common import read_json, write_json


class LibraryTests(unittest.TestCase):
    def test_index_acquire_and_detect_modified_pack(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            raw = root / "asset-library/kenney/raw/test-pack"
            raw.mkdir(parents=True)
            license_file = raw / "License.txt"
            license_file.write_text("CC0 1.0 Universal - Creative Commons public domain fixture")
            buffer = io.BytesIO()
            Image.new("RGB", (8, 8)).save(buffer, format="PNG")
            (raw / "icon.png").write_bytes(buffer.getvalue())
            write_json(root / "asset-library/kenney/index.json", {"packs": [], "assets": {}})
            write_json(root / "manifests/external-assets.json", {"assets": {}})
            write_json(root / "manifests/assets.json", {"assets": {}})
            with patch.object(library, "ROOT", root), patch.object(library, "project_path", side_effect=lambda name: root / name), patch.object(generate_credits, "ROOT", root):
                result = library.index_pack("test-pack", raw, "https://kenney.nl/assets/test-pack", license_file)
                self.assertEqual(result["asset_count"], 1)
                asset = library.acquire("kenney:test-pack/icon.png", "assets/ui/icon.png")
                self.assertFalse(asset["attribution_required"])
                self.assertEqual((root / "assets/ui/icon.png").read_bytes(), buffer.getvalue())
                self.assertEqual(read_json(root / "manifests/attribution.json")["entries"], [])
                (raw / "icon.png").write_bytes(b"changed")
                with self.assertRaises(ValueError):
                    library.acquire("kenney:test-pack/icon.png", "assets/ui/icon.png")

    def test_unknown_pack_license_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            raw = root / "asset-library/kenney/raw/test"
            raw.mkdir(parents=True)
            license_file = raw / "License.txt"
            license_file.write_text("unknown rights")
            with patch.object(library, "ROOT", root), patch.object(library, "project_path", side_effect=lambda name: root / name):
                with self.assertRaises(ValueError):
                    library.index_pack("test", raw, "https://kenney.nl/assets/test", license_file)
