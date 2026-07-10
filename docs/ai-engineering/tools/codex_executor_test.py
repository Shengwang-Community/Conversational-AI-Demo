#!/usr/bin/env python3
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace


TOOLS_DIR = Path(__file__).parent


def load_module(name, filename):
    path = TOOLS_DIR / filename
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


sys.path.insert(0, str(TOOLS_DIR))
try:
    executor_module = load_module("codex_executor", "codex_executor.py")
finally:
    sys.path.remove(str(TOOLS_DIR))

privacy = load_module("artifact_privacy", "validate_artifact_privacy.py")


REQUIRED_RESULT = {
    "agent": "android",
    "phase": "implementation",
    "attempt": 3,
    "status": "passed",
    "summary": "completed",
    "source_refs": [],
    "outputs": {},
    "artifacts": [],
    "findings": [],
    "gaps": [],
    "accepted_gaps": [],
    "validation": [],
}


class FakeSubprocessRunner:
    def __init__(self, role_result=REQUIRED_RESULT, stdout=None, returncode=0):
        self.role_result = role_result
        self.stdout = stdout or '{"type":"thread.started","thread_id":"thread-123"}\n'
        self.returncode = returncode
        self.write_output = True
        self.calls = []

    def __call__(self, command, **kwargs):
        self.calls.append((command, kwargs))
        if self.write_output:
            pending = Path(command[command.index("-o") + 1])
            if isinstance(self.role_result, str):
                pending.write_text(self.role_result, encoding="utf-8")
            else:
                pending.write_text(json.dumps(self.role_result), encoding="utf-8")
        return SimpleNamespace(
            returncode=self.returncode,
            stdout=self.stdout,
            stderr="diagnostic output that must remain in memory",
        )


class CodexExecutorTest(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        (self.root / "Android").mkdir()
        (self.root / "iOS").mkdir()
        self.run_path = self.root / "private-run"
        self.run_path.mkdir()
        self.output_schema = self.root / "role-result.schema.json"
        self.output_schema.write_text("{}\n", encoding="utf-8")
        self.android = {
            "id": "android",
            "model": "resolved-platform-model",
            "reasoning_effort": "high",
            "sandbox": "workspace-write",
            "working_directory": "Android",
        }

    def tearDown(self):
        self.tempdir.cleanup()

    def make_executor(self, runner):
        return executor_module.CodexExecutor(
            self.root,
            self.output_schema,
            privacy,
            subprocess_run=runner,
        )

    def output_paths(self, attempt=3, agent="android"):
        output = (
            self.run_path
            / "attempts"
            / f"{attempt:02d}"
            / "role-results"
            / f"{agent}.json"
        )
        return output, output.with_suffix(".json.pending")

    def test_android_command_uses_expanded_policy_and_private_run_workspace(self):
        pending = self.output_paths()[1]
        command, working_directory = self.make_executor(FakeSubprocessRunner()).build_command(
            self.run_path, self.android, pending
        )

        self.assertEqual(self.root.resolve() / "Android", working_directory)
        self.assertEqual(
            [
                "codex",
                "exec",
                "-m",
                "resolved-platform-model",
                "-c",
                'model_reasoning_effort="high"',
                "-s",
                "workspace-write",
                "-C",
                str((self.root / "Android").resolve()),
                "--add-dir",
                str(self.run_path.resolve()),
                "--ephemeral",
                "--json",
                "--output-schema",
                str(self.output_schema.resolve()),
                "-o",
                str(pending),
                "-",
            ],
            command,
        )

    def test_ios_command_uses_ios_working_directory(self):
        node = {
            **self.android,
            "id": "ios",
            "working_directory": "iOS",
        }
        pending = self.output_paths(agent="ios")[1]

        command, working_directory = self.make_executor(FakeSubprocessRunner()).build_command(
            self.run_path, node, pending
        )

        self.assertEqual(self.root.resolve() / "iOS", working_directory)
        self.assertEqual(str((self.root / "iOS").resolve()), command[command.index("-C") + 1])

    def test_read_only_role_uses_policy_sandbox(self):
        node = {
            **self.android,
            "id": "acceptance-reviewer",
            "sandbox": "read-only",
            "working_directory": ".",
        }
        pending = self.output_paths(agent="acceptance-reviewer")[1]

        command, _ = self.make_executor(FakeSubprocessRunner()).build_command(
            self.run_path, node, pending
        )

        self.assertEqual("read-only", command[command.index("-s") + 1])

    def test_execute_promotes_exact_pending_output_and_keeps_streams_in_memory(self):
        runner = FakeSubprocessRunner()

        execution = self.make_executor(runner).execute(
            self.run_path, self.android, "implement the role", 3
        )

        output, pending = self.output_paths()
        self.assertEqual(REQUIRED_RESULT, json.loads(output.read_text(encoding="utf-8")))
        self.assertFalse(pending.exists())
        self.assertEqual(REQUIRED_RESULT, execution["result"])
        self.assertEqual(
            {
                "agent": "android",
                "attempt": 3,
                "thread_id": "thread-123",
                "model": "resolved-platform-model",
                "reasoning_effort": "high",
                "sandbox": "workspace-write",
                "working_directory": "Android",
                "output": "attempts/03/role-results/android.json",
                "result": "completed",
            },
            execution["provenance"],
        )
        command, kwargs = runner.calls[0]
        self.assertEqual(str(pending.resolve()), command[command.index("-o") + 1])
        self.assertEqual(
            {
                "input": "implement the role",
                "text": True,
                "capture_output": True,
                "cwd": (self.root / "Android").resolve(),
            },
            kwargs,
        )
        persisted_files = {
            str(path.relative_to(self.root))
            for path in self.root.rglob("*")
            if path.is_file()
        }
        self.assertEqual(
            {
                "role-result.schema.json",
                "private-run/attempts/03/role-results/android.json",
            },
            persisted_files,
        )
        self.assertFalse(any(path.name.endswith(".pending") for path in self.root.rglob("*")))

    def test_ios_execute_uses_ios_cwd_and_promotes_output(self):
        node = {
            **self.android,
            "id": "ios",
            "working_directory": "iOS",
        }
        role_result = {**REQUIRED_RESULT, "agent": "ios"}
        runner = FakeSubprocessRunner(role_result=role_result)

        execution = self.make_executor(runner).execute(
            self.run_path, node, "implement the iOS role", 3
        )

        output, pending = self.output_paths(agent="ios")
        command, kwargs = runner.calls[0]
        expected_cwd = self.root.resolve() / "iOS"
        self.assertEqual(str(expected_cwd), command[command.index("-C") + 1])
        self.assertEqual(expected_cwd, kwargs["cwd"])
        self.assertEqual(role_result, json.loads(output.read_text(encoding="utf-8")))
        self.assertEqual(role_result, execution["result"])
        self.assertFalse(pending.exists())

    def test_find_thread_id_parses_jsonl_in_memory(self):
        events = "\n".join(
            [
                "not-json",
                '{"type":"thread.started","thread_id":""}',
                '{"type":"other"}',
                '{"type":"thread.started","thread_id":"first-thread"}',
                '{"type":"turn.completed","thread_id":"ignored-thread"}',
            ]
        )

        self.assertEqual("first-thread", executor_module.find_thread_id(events))

    def test_nonzero_exit_does_not_promote(self):
        runner = FakeSubprocessRunner(returncode=7)

        with self.assertRaisesRegex(RuntimeError, "exit 7"):
            self.make_executor(runner).execute(self.run_path, self.android, "prompt", 3)

        self.assert_no_output_or_pending()

    def test_missing_thread_provenance_does_not_promote(self):
        runner = FakeSubprocessRunner(stdout='{"type":"turn.completed"}\n')

        with self.assertRaisesRegex(RuntimeError, "provenance missing"):
            self.make_executor(runner).execute(self.run_path, self.android, "prompt", 3)

        self.assert_no_output_or_pending()

    def test_missing_role_output_does_not_promote(self):
        runner = FakeSubprocessRunner()
        runner.write_output = False

        with self.assertRaisesRegex(RuntimeError, "output or thread provenance missing"):
            self.make_executor(runner).execute(self.run_path, self.android, "prompt", 3)

        self.assert_no_output_or_pending()

    def test_unsafe_pending_output_is_rejected_before_promotion(self):
        unsafe = dict(REQUIRED_RESULT)
        key = "client" + "_secret"
        unsafe["summary"] = f"{key}=abc123"
        runner = FakeSubprocessRunner(role_result=unsafe)

        with self.assertRaisesRegex(RuntimeError, "private role output rejected"):
            self.make_executor(runner).execute(self.run_path, self.android, "prompt", 3)

        self.assert_no_output_or_pending()

    def test_malformed_json_does_not_promote(self):
        runner = FakeSubprocessRunner(role_result="{not-json")

        with self.assertRaises(json.JSONDecodeError):
            self.make_executor(runner).execute(self.run_path, self.android, "prompt", 3)

        self.assert_no_output_or_pending()

    def test_missing_required_fields_does_not_promote(self):
        incomplete = dict(REQUIRED_RESULT)
        incomplete.pop("validation")
        runner = FakeSubprocessRunner(role_result=incomplete)

        with self.assertRaisesRegex(ValueError, "role result missing fields: validation"):
            self.make_executor(runner).execute(self.run_path, self.android, "prompt", 3)

        self.assert_no_output_or_pending()

    def test_rejects_preexisting_pending_file_without_running_codex(self):
        _, pending = self.output_paths()
        pending.parent.mkdir(parents=True)
        pending.write_text(json.dumps(REQUIRED_RESULT), encoding="utf-8")
        runner = FakeSubprocessRunner()

        with self.assertRaisesRegex(RuntimeError, "pending output already exists"):
            self.make_executor(runner).execute(
                self.run_path, self.android, "prompt", 3
            )

        self.assertEqual([], runner.calls)
        self.assertTrue(pending.exists())

    def test_rejects_result_for_the_wrong_agent_or_attempt(self):
        wrong = {**REQUIRED_RESULT, "agent": "ios", "attempt": 2}

        with self.assertRaisesRegex(ValueError, "agent must be android"):
            self.make_executor(FakeSubprocessRunner(role_result=wrong)).execute(
                self.run_path, self.android, "prompt", 3
            )

        self.assert_no_output_or_pending()

    def test_rejects_escaping_working_directory_and_unsafe_sandbox(self):
        pending = self.output_paths()[1]
        escaping = {**self.android, "working_directory": "../outside"}
        unsafe = {**self.android, "sandbox": "danger-full-access"}

        with self.assertRaisesRegex(ValueError, "working directory escapes"):
            self.make_executor(FakeSubprocessRunner()).build_command(
                self.run_path, escaping, pending
            )
        with self.assertRaisesRegex(ValueError, "unsupported sandbox"):
            self.make_executor(FakeSubprocessRunner()).build_command(
                self.run_path, unsafe, pending
            )

    def test_subprocess_exception_cleans_owned_pending(self):
        class RaisingRunner:
            def __call__(self, command, **kwargs):
                Path(command[command.index("-o") + 1]).write_text(
                    "partial", encoding="utf-8"
                )
                raise OSError("launch failed")

        with self.assertRaisesRegex(OSError, "launch failed"):
            self.make_executor(RaisingRunner()).execute(
                self.run_path, self.android, "prompt", 3
            )

        self.assert_no_output_or_pending()

    def assert_no_output_or_pending(self):
        output, pending = self.output_paths()
        self.assertFalse(output.exists())
        self.assertFalse(pending.exists())


if __name__ == "__main__":
    unittest.main()
