"""Guard the repository boundary in the mobile PR template."""

import importlib.util
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
spec = importlib.util.spec_from_file_location("workflow_check", ROOT / "scripts/check_workflow.py")
workflow_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(workflow_check)


class MobileTemplateTests(unittest.TestCase):
    def test_template_lists_only_local_targets(self):
        template = (ROOT / ".github/PULL_REQUEST_TEMPLATE/mobile.md").read_text()
        self.assertEqual(workflow_check.mobile_template_targets(template), ["Android", "iOS"])

    def test_cross_repository_rows_are_rejected(self):
        template = "| Target in this repository | Decision | Reason |\n| --- | --- | --- |\n| Android | | |\n| iOS | | |\n| Other Android | | |\n"
        self.assertNotEqual(workflow_check.mobile_template_targets(template), ["Android", "iOS"])


if __name__ == "__main__":
    unittest.main()
