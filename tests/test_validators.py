from __future__ import annotations

import unittest

from lightroom_mcp_custom.validators import (
    validate_batch_metadata_entries,
    validate_develop_settings,
    validate_local_ids,
    validate_pick_status,
    validate_rating,
)


class ValidatorTests(unittest.TestCase):
    def test_validate_rating(self) -> None:
        self.assertEqual(validate_rating(0), 0)
        self.assertEqual(validate_rating(5), 5)
        with self.assertRaises(ValueError):
            validate_rating(6)

    def test_validate_pick_status(self) -> None:
        self.assertEqual(validate_pick_status(-1), -1)
        self.assertEqual(validate_pick_status(0), 0)
        self.assertEqual(validate_pick_status(1), 1)
        with self.assertRaises(ValueError):
            validate_pick_status(2)

    def test_validate_local_ids(self) -> None:
        self.assertEqual(validate_local_ids([1, 2, 3]), [1, 2, 3])
        self.assertIsNone(validate_local_ids(None))
        with self.assertRaises(ValueError):
            validate_local_ids([0])

    def test_validate_develop_settings_clamps(self) -> None:
        result = validate_develop_settings({"Exposure": 12}, clamp=True)
        self.assertEqual(result.sanitized["Exposure"], 5.0)
        self.assertTrue(result.warnings)

    def test_validate_develop_settings_strict_unknown(self) -> None:
        with self.assertRaises(ValueError):
            validate_develop_settings({"MyUnknownParam": 5}, strict=True)

    def test_validate_develop_settings_boolean_param(self) -> None:
        result = validate_develop_settings({"EnableProfileCorrections": "true"}, strict=True)
        self.assertIs(result.sanitized["EnableProfileCorrections"], True)

    def test_validate_develop_settings_enum_param(self) -> None:
        result = validate_develop_settings({"WhiteBalance": "auto"}, strict=True)
        self.assertEqual(result.sanitized["WhiteBalance"], "Auto")

    def test_validate_develop_settings_known_passthrough(self) -> None:
        curve = [0, 0, 255, 255]
        result = validate_develop_settings({"ToneCurvePV2012": curve}, strict=True)
        self.assertEqual(result.sanitized["ToneCurvePV2012"], curve)
        self.assertTrue(result.warnings)


class BatchMetadataValidatorTests(unittest.TestCase):
    def test_valid_entry_with_both(self) -> None:
        entries = [{"local_ids": [1, 2], "caption": "Hello", "keywords": ["a", "b"]}]
        result = validate_batch_metadata_entries(entries)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["local_ids"], [1, 2])
        self.assertEqual(result[0]["caption"], "Hello")
        self.assertEqual(result[0]["keywords"], ["a", "b"])

    def test_valid_entry_caption_only(self) -> None:
        entries = [{"local_ids": [1], "caption": "Hello"}]
        result = validate_batch_metadata_entries(entries)
        self.assertEqual(len(result), 1)
        self.assertNotIn("keywords", result[0])

    def test_valid_entry_keywords_only(self) -> None:
        entries = [{"local_ids": [1], "keywords": ["tag"]}]
        result = validate_batch_metadata_entries(entries)
        self.assertEqual(len(result), 1)
        self.assertNotIn("caption", result[0])

    def test_empty_entries_raises(self) -> None:
        with self.assertRaises(ValueError):
            validate_batch_metadata_entries([])

    def test_not_a_list_raises(self) -> None:
        with self.assertRaises(TypeError):
            validate_batch_metadata_entries("bad")

    def test_missing_local_ids_raises(self) -> None:
        with self.assertRaises(ValueError):
            validate_batch_metadata_entries([{"caption": "Hello"}])

    def test_empty_local_ids_raises(self) -> None:
        with self.assertRaises(ValueError):
            validate_batch_metadata_entries([{"local_ids": [], "caption": "Hello"}])

    def test_no_caption_or_keywords_raises(self) -> None:
        with self.assertRaises(ValueError):
            validate_batch_metadata_entries([{"local_ids": [1]}])

    def test_empty_keywords_raises(self) -> None:
        with self.assertRaises(ValueError):
            validate_batch_metadata_entries([{"local_ids": [1], "keywords": []}])

    def test_invalid_local_id_raises(self) -> None:
        with self.assertRaises(ValueError):
            validate_batch_metadata_entries([{"local_ids": [0], "caption": "Hello"}])

    def test_boolean_local_id_raises(self) -> None:
        with self.assertRaises(TypeError):
            validate_batch_metadata_entries([{"local_ids": [True], "caption": "Hello"}])

    def test_entry_not_a_dict_raises(self) -> None:
        with self.assertRaises(TypeError):
            validate_batch_metadata_entries(["not a dict"])

    def test_invalid_second_entry_raises(self) -> None:
        entries = [
            {"local_ids": [1], "caption": "ok"},
            {"local_ids": [2]},  # missing caption and keywords
        ]
        with self.assertRaises(ValueError):
            validate_batch_metadata_entries(entries)

    def test_keywords_non_list_raises(self) -> None:
        with self.assertRaises(ValueError):
            validate_batch_metadata_entries([{"local_ids": [1], "keywords": "flat string"}])


if __name__ == "__main__":
    unittest.main()
