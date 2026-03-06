from __future__ import annotations

import unittest

from lightroom_mcp_custom.validators import (
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


if __name__ == "__main__":
    unittest.main()
