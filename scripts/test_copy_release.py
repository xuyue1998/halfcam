"""Release copy regressions: behavior, localization coverage and field limits."""

import ast

from pathlib import Path
import unittest

import check_copy
from test_camera_session import method


ROOT = Path(__file__).resolve().parents[1]


class CopyReleaseChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = check_copy.load_json(ROOT / "HalfCam/Localizable.xcstrings")

    def values(self, key):
        entry = self.catalog["strings"][key]
        return {locale: entry["localizations"][locale]["stringUnit"]["value"]
                for locale in check_copy.LANGUAGES}

    def test_unload_button_does_not_promise_to_start_development(self):
        values = self.values("卸卷并送去显影")
        self.assertEqual(values["zh-Hans"], "卸下胶卷")
        self.assertEqual(values["en"], "Unload roll")
        self.assertNotIn("现像", values["ja"])
        self.assertNotIn("현상", values["ko"])

    def test_all_actionable_new_messages_have_five_reviewed_translations(self):
        keys = (
            "卸卷不会返还本月已使用的装卷额度。", "正在购买",
            "购买待处理，完成后将自动更新。",
            "购买买断不会自动取消现有年卡。请在系统设置中取消年卡续订，以免继续扣费。",
        )
        for key in keys:
            with self.subTest(key=key):
                entry = self.catalog["strings"][key]
                for locale in check_copy.LANGUAGES:
                    unit = entry["localizations"][locale]["stringUnit"]
                    self.assertEqual(unit["state"], "translated")
                    self.assertTrue(unit["value"].strip())
                    self.assertEqual(check_copy.placeholders(unit["value"]), [])

    def test_strict_mode_and_auto_export_copy_explain_exceptions(self):
        strict = self.values("拍过就不能中途卸卷")
        self.assertIn("关闭", strict["zh-Hans"])
        self.assertIn("Turn off", strict["en"])
        auto = self.values("只倒还没倒走的。一对两格，一格一张。")
        self.assertIn("体验卷不自动导出", auto["zh-Hans"])
        self.assertIn("Trial rolls are not exported automatically", auto["en"])

    def test_failed_export_copy_is_compatible_with_partial_success(self):
        values = self.values("倒出失败")
        self.assertIn("未完成", values["zh-Hans"])
        self.assertIn("incomplete", values["en"])
        self.assertNotIn("Your negatives are safe", self.values("显影未完成，底片已保留")["en"])

    def test_restore_label_does_not_describe_all_purchases_as_restoring(self):
        for name in ("HalfCam/Store/PaywallView.swift", "HalfCam/Album/AlbumView.swift"):
            text = (ROOT / name).read_text()
            self.assertNotIn('purchasing ? L("正在恢复")', text)
            self.assertIn('restoring ? L("正在恢复")', text)
        text = (ROOT / "HalfCam/Store/Entitlements.swift").read_text()
        restore = method(text, "restore")
        self.assertIn("restoring = true", restore)
        self.assertIn("restoring = false", restore)
        self.assertIn('case .pending:', text)
        self.assertIn('note = L("购买待处理，完成后将自动更新。")', text)

    def test_permission_fallbacks_match_source_catalog(self):
        catalog = check_copy.load_json(ROOT / "HalfCam/InfoPlist.xcstrings")
        self.assertEqual(check_copy.check_permission_fallbacks(catalog), [])

    def test_pending_notice_clears_only_for_its_own_delivered_transaction(self):
        text = (ROOT / "HalfCam/Store/Entitlements.swift").read_text()
        self.assertIn("pendingPurchase = (product.id, note)", method(text, "buy"))
        listener = method(text, "listen")
        self.assertIn("pendingPurchase.productID == tx.productID", listener)
        self.assertIn('if note == pendingPurchase.message { note = "" }', listener)
        self.assertIn("self.pendingPurchase = nil", listener)

    def test_storekit_metadata_length_limits(self):
        product = {"productID": "test", "localizations": [
            {"locale": "en_US", "displayName": "A" * 30, "description": "B" * 45}
        ]}
        self.assertEqual(check_copy.check_product_copy(product), [])
        product["localizations"][0]["description"] += "B"
        self.assertIn("45", check_copy.check_product_copy(product)[0])
        product["localizations"][0]["displayName"] += "A"
        self.assertEqual(len(check_copy.check_product_copy(product)), 2)
        self.assertEqual(check_copy.check_storekit(), [])

    def test_public_privacy_copy_covers_automatic_export_and_full_access(self):
        text = (ROOT / "docs/privacy.html").read_text()
        self.assertIn("或已开启自动导出", text)
        self.assertIn("or auto-export is enabled", text)
        self.assertIn("获得完整访问权限后", text)
        self.assertIn("With full access", text)
        self.assertNotIn("您未主动导出时", text)

    def test_public_copy_distinguishes_delete_from_offload(self):
        for name in ("docs/privacy.html", "docs/legal.html"):
            text = (ROOT / name).read_text()
            self.assertIn("“卸载 App”会保留", text)
            self.assertIn("Offload App", text)
            self.assertNotIn("卸载应用将删除", text)
            self.assertNotIn("卸载应用后余数清除", text)

    def test_store_screenshot_ticket_terms_match_app(self):
        tree = ast.parse((ROOT / "scripts/store_screenshots.py").read_text())
        copy = next(ast.literal_eval(node.value) for node in tree.body
                    if isinstance(node, ast.Assign)
                    and any(isinstance(target, ast.Name) and target.id == "COPY"
                            for target in node.targets))
        self.assertIn(self.values("加急券")["ja"], copy["ja"]["rush"])
        self.assertIn(self.values("加急券")["ko"], copy["ko"]["rush"])


if __name__ == "__main__":
    unittest.main()
