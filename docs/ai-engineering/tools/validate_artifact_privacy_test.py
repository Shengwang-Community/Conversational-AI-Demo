#!/usr/bin/env python3
import importlib.util
import subprocess
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
            [f"role output:1: private source marker found: {marker}"],
            errors,
        )

    def test_scan_text_detects_credential_without_a_file(self):
        key = "client" + "_secret"

        errors = privacy.scan_text(f'{key}="abc123"')

        self.assertEqual(["<memory>:1: possible credential or token literal"], errors)

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

    def test_type_annotation_and_standard_test_placeholder_pass(self):
        self.assertEqual([], privacy.scan_text("app_id: String?", source="fixture.kt"))
        self.assertEqual([], privacy.scan_text('app_id = "test-app-id"'))

    def test_environment_value_with_dot_is_not_treated_as_code(self):
        self.assertTrue(
            privacy.scan_text("app_id=real.secret", source="config.env")
        )

    def test_privacy_error_reports_file_and_line(self):
        key = "APP" + "_ID"

        errors = privacy.scan_text(
            f"safe line\n{key}=real-value\n", source="fixture.kt"
        )

        self.assertEqual(
            ["fixture.kt:2: possible credential or token literal"], errors
        )

    def test_32_character_app_id_literal_is_rejected(self):
        value = "a" * 32

        self.assertEqual(
            ["fixture.kt:1: possible 32-character APPID literal"],
            privacy.scan_text(f'assertEquals("{value}", actual)', source="fixture.kt"),
        )

    def test_changed_lines_gate_ignores_baseline_and_reports_new_literal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            key = "app" + "_id"
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            config = root / "Config.kt"
            config.write_text(
                f'{key} = "existing-production-value"\nmode = "old"\n',
                encoding="utf-8",
            )
            subprocess.run(["git", "add", "Config.kt"], cwd=root, check=True)
            subprocess.run(
                [
                    "git",
                    "-c",
                    "user.name=Test",
                    "-c",
                    "user.email=test@example.com",
                    "-c",
                    "core.hooksPath=/dev/null",
                    "commit",
                    "-qm",
                    "baseline",
                ],
                cwd=root,
                check=True,
            )
            config.write_text(
                f'{key} = "existing-production-value"\nmode = "new"\n',
                encoding="utf-8",
            )
            self.assertEqual([], privacy.scan_changed_lines(root))

            config.write_text(
                f'{key} = "existing-production-value"\nmode = "new"\n'
                f'{key} = "new-production-value"\n',
                encoding="utf-8",
            )

            self.assertEqual(
                ["Config.kt:3: possible credential or token literal"],
                privacy.scan_changed_lines(root),
            )

    def test_changed_lines_gate_detects_multiline_yaml_credential(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            key = "app" + "_id"
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            config = root / "config.yaml"
            config.write_text("mode: baseline\n", encoding="utf-8")
            subprocess.run(["git", "add", "config.yaml"], cwd=root, check=True)
            subprocess.run(
                [
                    "git",
                    "-c",
                    "user.name=Test",
                    "-c",
                    "user.email=test@example.com",
                    "-c",
                    "core.hooksPath=/dev/null",
                    "commit",
                    "-qm",
                    "baseline",
                ],
                cwd=root,
                check=True,
            )
            config.write_text(
                f"mode: baseline\n{key}:\n  abc123\n", encoding="utf-8"
            )

            self.assertEqual(
                ["config.yaml:3: possible credential or token literal"],
                privacy.scan_changed_lines(root),
            )


if __name__ == "__main__":
    unittest.main()
