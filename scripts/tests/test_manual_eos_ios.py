import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "test_manual_eos_ios.py"
spec = importlib.util.spec_from_file_location("manual_eos_host", SCRIPT)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class NativeManualEosRunnerTests(unittest.TestCase):
    def test_package_uses_current_sources_and_xctest(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo = root / "repo"
            for path in [*runner.SOURCES, runner.TEST]:
                file = repo / path
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text("current revision: " + str(path))
            package = root / "package"
            runner.prepare_package(repo, package)
            for source in runner.SOURCES:
                self.assertEqual((package / "Sources/ManualEos" / source.name).read_text(), (repo / source).read_text())
            self.assertEqual((package / "Tests/ManualEosTests" / runner.TEST.name).read_text(), (repo / runner.TEST).read_text())
            self.assertIn('.testTarget(name: "ManualEosTests"', (package / "Package.swift").read_text())

    def test_missing_source_fails_instead_of_testing_stale_artifacts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaises(FileNotFoundError):
                runner.prepare_package(root / "missing", root / "package")

    def run_main(self, output):
        packages = []

        def fake_run(command, **kwargs):
            packages.append(Path(command[command.index("--package-path") + 1]))
            self.assertTrue(packages[-1].is_dir())
            temporary = Path(kwargs["env"]["TMPDIR"])
            self.assertTrue(temporary.is_dir())
            self.assertEqual(temporary.parent, packages[-1])
            return subprocess.CompletedProcess(command, 0, stdout=output, stderr="")

        with mock.patch.object(runner.subprocess, "run", side_effect=fake_run), \
                contextlib.redirect_stdout(io.StringIO()):
            code = runner.main([])
        self.assertEqual(len(packages), 1)
        return code, packages[0]

    def test_main_removes_temporary_package(self):
        code, package = self.run_main("Executed 3 tests, with 0 failures (0 unexpected)")
        self.assertEqual(code, 0)
        self.assertFalse(package.exists())

    def test_zero_tests_output_fails_and_removes_package(self):
        code, package = self.run_main("Executed 0 tests, with 0 failures (0 unexpected)")
        self.assertEqual(code, 1)
        self.assertFalse(package.exists())
