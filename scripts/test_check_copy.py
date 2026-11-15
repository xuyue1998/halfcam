import unittest

import check_copy


class CopyChecks(unittest.TestCase):
    def test_nested_interpolation(self):
        self.assertEqual(
            check_copy.swift_template(r"约 \(Int(ceil(seconds))) 秒"), "约 {} 秒"
        )

    def test_escaped_interpolation_is_literal(self):
        self.assertEqual(check_copy.swift_template(r"\\(value)"), r"\(value)")

    def test_unclosed_interpolation_is_rejected(self):
        with self.assertRaises(ValueError):
            check_copy.swift_template(r"\(Int(value)")

    def test_missing_source_lookup_is_rejected(self):
        errors = check_copy.check_references('Text(L("新增文案"))', {"strings": {}}, "test.swift")
        self.assertEqual(len(errors), 1)
        self.assertIn("not registered", errors[0])

    def test_stale_source_lookup_is_rejected(self):
        catalog = {"strings": {"新文案": {"extractionState": "stale"}}}
        errors = check_copy.check_references('L("新文案")', catalog, "test.swift")
        self.assertEqual(len(errors), 1)
        self.assertIn("marked stale", errors[0])

    def test_nested_source_lookup_matches_catalog(self):
        catalog = {"strings": {"约 %lld 秒": {}}}
        source = r'L("约 \(Int(ceil(seconds))) 秒")'
        self.assertEqual(check_copy.check_references(source, catalog, "test.swift"), [])

    def test_multiple_interpolations_match_positional_key(self):
        catalog = {"strings": {"%1$lld 卷 · %2$lld 张": {}}}
        source = r'L("\(rolls) 卷 · \(photos) 张")'
        self.assertEqual(check_copy.check_references(source, catalog, "test.swift"), [])

    def test_new_english_copy_is_not_silently_skipped(self):
        self.assertTrue(check_copy.is_copy("Export failed", {}))

    def test_meter_markings_are_exempt(self):
        self.assertFalse(check_copy.is_copy("ISO %lld", {}))

    def test_reordered_placeholders_keep_argument_types(self):
        self.assertEqual(
            check_copy.placeholders("%lld · %@"),
            check_copy.placeholders("%2$@ · %1$lld"),
        )

    def test_changed_format_type_is_rejected(self):
        self.assertNotEqual(check_copy.placeholders("%lld"), check_copy.placeholders("%d"))

    def test_escaped_percent_is_not_an_argument(self):
        self.assertEqual(check_copy.placeholders("100%% · %lld"), [(1, "lld")])

    def test_duplicate_json_key_is_rejected(self):
        with self.assertRaises(ValueError):
            check_copy.unique_object([("key", 1), ("key", 2)])


if __name__ == "__main__":
    unittest.main()
