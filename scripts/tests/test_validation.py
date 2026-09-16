"""Exercise validation failures with real subprocesses and a stub toolchain."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("validation", ROOT / "scripts/validate.py")
validation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validation)

STUB = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
root = pathlib.Path(os.environ["FIXTURE_ROOT"])
with (root / "calls.jsonl").open("a") as out:
    out.write(json.dumps([pathlib.Path(sys.argv[0]).name] + sys.argv[1:]) + "\n")
tool = pathlib.Path(sys.argv[0]).name
if tool == "xcrun":
    if sys.argv[1:3] == ["simctl", "list"]:
        print(json.dumps({"devices": {"runtime": [{"name": "iPhone Test", "udid": "TEST-UUID", "state": "Booted", "isAvailable": True}]}}))
    elif sys.argv[1] == "xcresulttool":
        mode = os.environ.get("TEST_RESULT", "passed")
        if mode == "malformed":
            print("not JSON")
        else:
            print(json.dumps({"result": "Failed" if mode == "failed" else "Passed", "passedTests": 6 if mode == "passed" else 0, "failedTests": 1 if mode == "failed" else 0, "skippedTests": 6 if mode == "skipped" else 0}))
elif tool == "xcodebuild":
    if "test" not in sys.argv and "build-for-testing" not in sys.argv:
        sys.exit("Expected a current-source build")
    if (root / "iOS/input.txt").read_text() == "broken":
        sys.exit(65)
    result = pathlib.Path(sys.argv[sys.argv.index("-resultBundlePath") + 1])
    result.mkdir()
elif tool == "gradlew":
    if os.environ.get("GRADLE_FAIL"):
        sys.exit(7)
    if not os.environ.get("NO_SOURCE"):
        cfg = json.loads((root / "scripts/workflow.json").read_text())
        for rel in cfg["android"]["test_reports"]:
            report = root / "Android" / rel
            report.mkdir(parents=True, exist_ok=True)
            (report / "TEST-current.xml").write_text('<testsuite tests="1"><testcase name="current"/></testsuite>')
    if os.environ.get("LINT_FAIL"):
        sys.exit(7)
'''


class ValidationRegressionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="convoai-validation-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.cfg = validation.config(ROOT)
        files = ["scripts/validate.py", "scripts/workflow.json", "iOS/Agent.xcodeproj/project.pbxproj"]
        files += [str(p.relative_to(ROOT)) for p in (ROOT / "iOS/AgentTests").glob("*.swift")]
        files += ["iOS/Agent.xcodeproj/xcshareddata/xcschemes/" + suite["scheme"] + ".xcscheme"
                  for suite in self.cfg["ios"]["suites"].values()]
        for rel in set(files):
            target = self.root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / rel, target)
        (self.root / "iOS/input.txt").write_text("valid")
        (self.root / "iOS/Agent.xcworkspace").mkdir()
        binary = self.root / "bin"
        binary.mkdir()
        for name in ["xcrun", "xcodebuild"]:
            path = binary / name
            path.write_text(STUB)
            path.chmod(0o755)
        (self.root / "Android").mkdir()
        wrapper = self.root / "Android/gradlew"
        wrapper.write_text(STUB)
        wrapper.chmod(0o755)
        self.env = {**os.environ, "FIXTURE_ROOT": str(self.root), "PATH": str(binary) + os.pathsep + os.environ["PATH"],
                    "PYTHONDONTWRITEBYTECODE": "1"}
        for name in ["TEST_RESULT", "GRADLE_FAIL", "LINT_FAIL", "NO_SOURCE", "SIM_ARCH", "IOS_SIMULATOR_UDID"]:
            self.env.pop(name, None)

    def run_cli(self, *args, env=None):
        return subprocess.run([sys.executable, str(self.root / "scripts/validate.py"), *args,
                               "--results-dir", str(self.root / "results")],
                              cwd=self.root, env={**self.env, **(env or {})},
                              text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def calls(self):
        path = self.root / "calls.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def evidence(self):
        paths = list((self.root / "results").glob("*/validation.json"))
        return [json.loads(path.read_text()) for path in paths]

    def test_ios_executes_current_sources_after_cached_run(self):
        derived = self.root / "DerivedData"
        products = derived / "Build/Products"
        products.mkdir(parents=True)
        (products / "old.xctestrun").write_text("old passing build")
        first = self.run_cli("ios", "--derived-data", str(derived))
        self.assertEqual(first.returncode, 0, first.stderr)
        (self.root / "iOS/input.txt").write_text("broken")
        second = self.run_cli("ios", "--derived-data", str(derived))
        self.assertNotEqual(second.returncode, 0)
        builds = [call for call in self.calls() if call[0] == "xcodebuild"]
        self.assertEqual(len(builds), 2)
        self.assertTrue(all(call[1] == "test" for call in builds))
        self.assertEqual({e["status"] for e in self.evidence()}, {"passed", "failed"})
        self.assertFalse(Path(str(derived) + ".lock").exists())

    def test_ios_rejects_empty_skipped_failed_and_malformed_results(self):
        for mode in ["zero", "skipped", "failed", "malformed"]:
            with self.subTest(mode=mode):
                result = self.run_cli("ios", "--derived-data", str(self.root / "DerivedData"), env={"TEST_RESULT": mode})
                self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertTrue(all(e["status"] == "failed" for e in self.evidence()))

    def test_preflight_rejects_missing_scheme_before_tool_execution(self):
        scheme = self.cfg["ios"]["suites"]["ains"]["scheme"]
        (self.root / f"iOS/Agent.xcodeproj/xcshareddata/xcschemes/{scheme}.xcscheme").unlink()
        result = self.run_cli("ios", "--preflight")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_preflight_rejects_deleted_test_class(self):
        (self.root / "iOS/AgentTests/OnDeviceAinsTests.swift").write_text("// test removed")
        result = self.run_cli("ios", "--preflight")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_preflight_rejects_test_removed_from_target_sources(self):
        path = self.root / "iOS/Agent.xcodeproj/project.pbxproj"
        path.write_text(path.read_text().replace("OnDeviceAinsTests.swift in Sources", "Removed.swift in Sources"))
        result = self.run_cli("ios", "--preflight")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_standalone_preflight_does_not_require_pods_or_macro_expansion(self):
        (self.root / "iOS/Agent.xcworkspace").rmdir()
        result = self.run_cli("ios", "--preflight")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.evidence()[0]["status"], "preflight-only")
        self.assertFalse(any(call[0] == "xcodebuild" for call in self.calls()))

    def test_unknown_suite_and_test_selector_fail_before_build(self):
        for args in [("--suite", "removed-feature"), ("--only-testing", "MissingTarget/RemovedTests")]:
            with self.subTest(args=args):
                result = self.run_cli("ios", *args)
                self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_build_only_cannot_report_ut_passed(self):
        result = self.run_cli("ios", "--build-only", "--derived-data", str(self.root / "DerivedData"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.evidence()[0]["status"], "built-not-tested")
        self.assertFalse(any(call[1] == "xcresulttool" for call in self.calls() if call[0] == "xcrun"))

    def test_derived_data_lock_preserves_other_owner(self):
        derived = self.root / "DerivedData"
        lock = Path(str(derived) + ".lock")
        lock.mkdir()
        result = self.run_cli("ios", "--derived-data", str(derived))
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(lock.exists())
        self.assertFalse(any(call[0] == "xcodebuild" for call in self.calls()))

    def test_android_runs_only_configured_brand_and_retains_current_evidence(self):
        result = self.run_cli("android")
        self.assertEqual(result.returncode, 0, result.stderr)
        call = next(call for call in self.calls() if call[0] == "gradlew")
        flavor = self.cfg["android"]["flavor"]
        self.assertIn(f":app:test{flavor.capitalize()}DebugUnitTest", call)
        wrong = "China" if flavor == "global" else "Global"
        self.assertFalse(any(wrong in arg for arg in call))
        self.assertEqual(self.evidence()[0]["tests"]["passed"], len(self.cfg["android"]["test_reports"]))

    def test_android_does_not_accept_old_reports_when_tests_become_no_source(self):
        self.assertEqual(self.run_cli("android").returncode, 0)
        result = self.run_cli("android", env={"NO_SOURCE": "1"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No JUnit test cases", result.stderr)

    def test_android_gradle_failure_is_not_reported_as_passed(self):
        result = self.run_cli("android", env={"GRADLE_FAIL": "1"})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.evidence()[0]["status"], "failed")

    def test_android_rejects_ios_only_flags_without_running_builds(self):
        result = self.run_cli("android", "--preflight")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_ios_rejects_a_different_container_without_running_tests(self):
        result = self.run_cli("ios", "--container", "Other.xcodeproj")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_android_preserves_junit_reports_in_result_directory(self):
        result = self.run_cli("android")
        self.assertEqual(result.returncode, 0, result.stderr)
        reports = Path(self.evidence()[0]["junit_path"])
        self.assertEqual(len(list(reports.glob("*.xml"))), len(self.cfg["android"]["test_reports"]))

    def test_lint_failure_preserves_test_counts_without_passing_validation(self):
        result = self.run_cli("android", env={"LINT_FAIL": "1"})
        self.assertNotEqual(result.returncode, 0)
        evidence = self.evidence()[0]
        self.assertEqual(evidence["status"], "failed")
        self.assertEqual(evidence["tests"]["passed"], len(self.cfg["android"]["test_reports"]))


if __name__ == "__main__":
    unittest.main()
