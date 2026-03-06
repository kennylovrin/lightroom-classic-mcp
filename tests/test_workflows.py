from __future__ import annotations

import unittest

from lightroom_mcp_custom.workflows import (
    get_group_parameters,
    get_preset_settings,
    list_group_descriptions,
    list_preset_descriptions,
    merge_preset_overrides,
    validate_group_values,
)


class WorkflowTests(unittest.TestCase):
    def test_get_group_parameters_with_alias(self) -> None:
        canonical, parameters = get_group_parameters("basic")
        self.assertEqual(canonical, "basic_tone")
        self.assertIn("Exposure", parameters)

    def test_validate_group_values_rejects_out_of_group_keys(self) -> None:
        with self.assertRaises(ValueError):
            validate_group_values("detail_noise", {"Exposure": 1.0})

    def test_validate_group_values_accepts_subset(self) -> None:
        canonical, scoped = validate_group_values("detail_noise", {"Sharpness": 45})
        self.assertEqual(canonical, "detail_noise")
        self.assertEqual(scoped["Sharpness"], 45)

    def test_get_preset_settings_with_alias(self) -> None:
        canonical, settings = get_preset_settings("portrait")
        self.assertEqual(canonical, "portrait_clean")
        self.assertIn("Exposure", settings)

    def test_merge_preset_overrides(self) -> None:
        canonical, merged = merge_preset_overrides(
            "landscape_pop",
            {"Exposure": 0.4, "Dehaze": 22},
        )
        self.assertEqual(canonical, "landscape_pop")
        self.assertEqual(merged["Exposure"], 0.4)
        self.assertEqual(merged["Dehaze"], 22)

    def test_group_and_preset_listing_not_empty(self) -> None:
        groups = list_group_descriptions()
        presets = list_preset_descriptions()
        self.assertGreater(len(groups), 0)
        self.assertGreater(len(presets), 0)


if __name__ == "__main__":
    unittest.main()
