#!/usr/bin/env python3
import importlib.util
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("validate_artifact_privacy.py")
SPEC = importlib.util.spec_from_file_location("privacy", MODULE_PATH)
privacy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(privacy)


class PrivacyScanTest(unittest.TestCase):
    def test_scan_text_detects_private_marker_without_a_file(self):
        marker = "raw_" + "jira_body:"

        errors = privacy.scan_text(f"{marker} private requirement", source="role output")

        self.assertEqual(
            [f"role output: private source marker found: {marker}"],
            errors,
        )

    def test_scan_text_detects_credential_without_a_file(self):
        key = "client" + "_secret"

        errors = privacy.scan_text(f'{key}="abc123"')

        self.assertEqual(["<memory>: possible credential or token literal"], errors)

    def test_scan_text_detects_json_and_prefixed_environment_credentials(self):
        secret_key = "client" + "_secret"
        environment_key = "OPENAI" + "_API_KEY"
        authorization_key = "Author" + "ization"
        self.assertTrue(
            privacy.scan_text(f'{{"{secret_key}":"abc123"}}', source="json")
        )
        self.assertTrue(
            privacy.scan_text(f"{environment_key}=sk-abc123", source="environment")
        )
        self.assertTrue(
            privacy.scan_text(
                f'{{"{authorization_key}":"Bearer secret-token"}}',
                source="headers",
            )
        )

    def test_scan_text_allows_documented_placeholders(self):
        placeholders = [
            "client_secret=example",
            "OPENAI_API_KEY=<your-key>",
            "ACCESS_TOKEN=${ACCESS_TOKEN}",
            "password=redacted",
            "app_certificate=******",
        ]

        for value in placeholders:
            with self.subTest(value=value):
                self.assertEqual([], privacy.scan_text(value))

    def test_private_markers_are_case_insensitive(self):
        marker = "RAW_" + "JIRA_BODY:"
        self.assertTrue(privacy.scan_text(f"{marker} private"))

    def test_public_safe_source_ref_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "brief.md"
            path.write_text("source_refs: [jira:PROJECT-123]\ncontent_policy: reference-only\n", encoding="utf-8")
            self.assertEqual([], privacy.scan([str(path)]))

    def test_raw_source_marker_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "brief.md"
            marker = "raw_" + "jira_body:"
            path.write_text(f"{marker} private requirement text\n", encoding="utf-8")
            self.assertTrue(any(marker in error for error in privacy.scan([str(path)])))

    def test_secret_literal_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.md"
            key = "client" + "_secret"
            value = "abc" + "123"
            path.write_text(f"{key} = \"{value}\"\n", encoding="utf-8")
            self.assertTrue(any("credential" in error for error in privacy.scan([str(path)])))

    def test_unquoted_token_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.md"
            key = "ACCESS" + "_TOKEN"
            path.write_text(f"{key}=abc123\n", encoding="utf-8")
            self.assertTrue(any("credential" in error for error in privacy.scan([str(path)])))

    def test_app_certificate_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.md"
            key = "APP" + "_CERTIFICATE"
            path.write_text(f"{key}: abcdef123456\n", encoding="utf-8")
            self.assertTrue(any("credential" in error for error in privacy.scan([str(path)])))

    def test_spaced_app_id_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.md"
            key = "App" + " ID"
            path.write_text(f"{key}: abcdef123456\n", encoding="utf-8")
            self.assertTrue(any("credential" in error for error in privacy.scan([str(path)])))

    def test_spaced_app_certificate_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.md"
            key = "App" + " Certificate"
            path.write_text(f"{key}: abcdef123456\n", encoding="utf-8")
            self.assertTrue(any("credential" in error for error in privacy.scan([str(path)])))


if __name__ == "__main__":
    unittest.main()
