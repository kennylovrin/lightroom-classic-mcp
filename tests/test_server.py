from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from lightroom_mcp_custom.server import _normalize_photo_for_inspection


class ServerInspectionTests(unittest.TestCase):
    def test_normalize_photo_for_inspection_existing_file(self) -> None:
        with tempfile.NamedTemporaryFile(suffix=".jpg") as tmp:
            photo = {
                "local_id": 42,
                "file_name": "test.jpg",
                "path": tmp.name,
                "dimensions": "100 x 200",
            }
            result = _normalize_photo_for_inspection(photo)

            self.assertEqual(result["local_id"], 42)
            self.assertIn("inspection", result)
            self.assertTrue(result["inspection"]["file_exists"])
            self.assertTrue(result["inspection"]["is_readable"])
            self.assertTrue(result["inspection"]["is_inspectable"])
            self.assertEqual(result["inspection"]["path"], tmp.name)
            self.assertEqual(result["inspection"]["suffix"], ".jpg")
            self.assertIsInstance(result["inspection"]["file_size_bytes"], int)

    def test_normalize_photo_for_inspection_missing_file(self) -> None:
        missing = Path(tempfile.gettempdir()) / "lightroom-mcp-missing-file.nef"
        photo = {
            "local_id": 9,
            "file_name": missing.name,
            "path": str(missing),
        }
        result = _normalize_photo_for_inspection(photo)

        self.assertFalse(result["inspection"]["file_exists"])
        self.assertFalse(result["inspection"]["is_readable"])
        self.assertFalse(result["inspection"]["is_inspectable"])
        self.assertEqual(result["inspection"]["path"], str(missing))


if __name__ == "__main__":
    unittest.main()
