#!/usr/bin/env python3
import importlib.util
import json
import tempfile
import threading
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).parent


def load_module(name, filename):
    path = TOOLS_DIR / filename
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = load_module("release_iteration_runner", "run_release_iteration.py")


class FakeExecutor:
    def __init__(
        self,
        ux_required=True,
        hld_required=True,
        scripted=None,
        source_refs=None,
    ):
        self.ux_required = ux_required
        self.hld_required = hld_required
        self.scripted = {key: list(value) for key, value in (scripted or {}).items()}
        self.source_refs = source_refs or ["product:REQ-1"]
        self.calls = []
        self._lock = threading.Lock()
        self._sequence = 0

    def execute(self, run_path, node, prompt, attempt):
        agent = node["id"]
        with self._lock:
            self.calls.append((agent, attempt))
            self._sequence += 1
            sequence = self._sequence
            overrides = self.scripted.get(agent, [])
            override = overrides.pop(0) if overrides else {}
        if isinstance(override, BaseException):
            raise override
        result = self._default_result(agent, attempt)
        result.update(override)
        return {
            "result": result,
            "provenance": {
                "agent": agent,
                "attempt": attempt,
                "thread_id": f"thread-{sequence}-{agent}-{attempt}",
                "model": node["model"],
                "reasoning_effort": node["reasoning_effort"],
                "sandbox": node["sandbox"],
                "working_directory": node["working_directory"],
                "output": f"attempts/{attempt:02d}/role-results/{agent}.json",
                "result": "completed",
            },
        }

    def _default_result(self, agent, attempt):
        outputs = {"result": f"{agent} completed"}
        artifacts = []
        validation = []
        artifact_names = {
            "product": "requirement-brief.md",
            "knowledge": "repo-context.md",
            "architect": "architecture-decision.json",
            "ux-design": "ux-spec.json",
            "test-design": "test-matrix.json",
            "android": "android-result.json",
            "ios": "ios-result.json",
            "test-verification": "test-verification.json",
            "ux-acceptance": "ux-acceptance.json",
            "acceptance-reviewer": "acceptance-review.json",
        }
        if agent == "product":
            outputs.update(
                {
                    "ux_required": self.ux_required,
                    "ux_reason": (
                        "user-visible interaction changes"
                        if self.ux_required
                        else "no user-visible behavior changes"
                    ),
                    "platforms": ["android", "ios"],
                    "acceptance_criteria": ["criterion-1"],
                }
            )
        elif agent == "architect":
            outputs.update(
                {
                    "hld_required": self.hld_required,
                    "hld_rationale": (
                        "cross-platform architecture changes"
                        if self.hld_required
                        else "no system-boundary change"
                    ),
                }
            )
            if self.hld_required:
                outputs["hld_review"] = {
                    "status": "approved",
                    "reviewed_by": "architecture-reviewer",
                    "reviewed_at": "2026-07-10T00:00:00+00:00",
                }
                artifacts.append(
                    {"path": "hld.md", "content": "# HLD\n\nApproved design.\n"}
                )
        elif agent == "test-design":
            outputs["covered_criteria"] = ["criterion-1"]
        elif agent in {"android", "ios"}:
            validation.append(
                {
                    "command": f"{agent} test",
                    "result": "passed",
                    "evidence": f"{agent} checks passed",
                }
            )
        elif agent == "test-verification":
            outputs.update(
                {
                    "verified_platforms": ["android", "ios"],
                    "covered_criteria": ["criterion-1"],
                }
            )
            validation.extend(
                [
                    {
                        "command": "verify android evidence",
                        "result": "passed",
                        "evidence": "android independently verified",
                    },
                    {
                        "command": "verify ios evidence",
                        "result": "passed",
                        "evidence": "ios independently verified",
                    },
                ]
            )
        artifacts.insert(
            0,
            {
                "path": artifact_names[agent],
                "content": json.dumps(outputs, indent=2) + "\n",
            },
        )
        return {
            "agent": agent,
            "phase": "delivery",
            "attempt": attempt,
            "status": "passed",
            "summary": f"{agent} passed",
            "source_refs": self.source_refs if agent == "product" else [],
            "outputs": outputs,
            "artifacts": artifacts,
            "findings": [],
            "gaps": [],
            "accepted_gaps": [],
            "validation": validation,
        }


class RunnerTest(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.runs_dir = Path(self.tempdir.name) / "pilot-runs"
        self.runs_dir.mkdir()
        self.original_runs_dir = runner.RUNS_DIR
        self.original_ensure_ignored = runner.ensure_ignored
        runner.RUNS_DIR = self.runs_dir
        runner.ensure_ignored = lambda path: None

    def tearDown(self):
        runner.RUNS_DIR = self.original_runs_dir
        runner.ensure_ignored = self.original_ensure_ignored
        self.tempdir.cleanup()

    def create_run(self, platforms=None):
        return runner.create_run(
            "complete-flow",
            "Deliver a product requirement",
            ["product:REQ-1"],
            platforms or ["android", "ios"],
            True,
            today="2026-07-10",
        )

    def read_json(self, path, name):
        return json.loads((path / name).read_text(encoding="utf-8"))

    def test_complete_ux_hld_flow_passes(self):
        run_path = self.create_run()
        executor = FakeExecutor()

        status = runner.execute_run(run_path, executor=executor)
        manifest = self.read_json(run_path, "acceptance-manifest.json")

        self.assertEqual("passed", status)
        calls = [agent for agent, _ in executor.calls]
        self.assertEqual(
            ["product", "knowledge", "architect", "ux-design", "test-design"],
            calls[:5],
        )
        self.assertEqual({"android", "ios"}, set(calls[5:7]))
        self.assertEqual(
            ["test-verification", "ux-acceptance", "acceptance-reviewer"],
            calls[7:],
        )
        self.assertTrue((run_path / "hld.md").is_file())
        thread_ids = [item["thread_id"] for item in manifest["execution"]["history"]]
        self.assertEqual(len(thread_ids), len(set(thread_ids)))
        verification = next(
            stage for stage in manifest["stages"] if stage["agent"] == "test-verification"
        )
        self.assertEqual(["android", "ios"], verification["outputs"]["verified_platforms"])

    def test_non_ux_no_hld_flow_passes_without_optional_artifacts(self):
        run_path = self.create_run()
        executor = FakeExecutor(ux_required=False, hld_required=False)

        status = runner.execute_run(run_path, executor=executor)
        manifest = self.read_json(run_path, "acceptance-manifest.json")

        self.assertEqual("passed", status)
        self.assertNotIn("ux-design", [agent for agent, _ in executor.calls])
        self.assertNotIn("ux-acceptance", [agent for agent, _ in executor.calls])
        self.assertFalse((run_path / "ux-spec.json").exists())
        self.assertFalse((run_path / "ux-acceptance.json").exists())
        self.assertFalse((run_path / "hld.md").exists())
        by_agent = {stage["agent"]: stage for stage in manifest["stages"]}
        self.assertEqual("not_required", by_agent["ux-design"]["status"])
        self.assertEqual("not_required", by_agent["ux-acceptance"]["status"])

    def test_failed_android_retries_without_rerunning_passed_ios(self):
        run_path = self.create_run()
        executor = FakeExecutor(
            scripted={
                "android": [
                    {
                        "status": "failed",
                        "summary": "android unit test failed",
                        "validation": [
                            {
                                "command": "android test",
                                "result": "failed",
                                "evidence": "failure",
                            }
                        ],
                    }
                ]
            }
        )

        status = runner.execute_run(run_path, executor=executor)

        self.assertEqual("passed", status)
        self.assertEqual(2, sum(agent == "android" for agent, _ in executor.calls))
        self.assertEqual(1, sum(agent == "ios" for agent, _ in executor.calls))
        self.assertTrue(
            (run_path / "attempts/01/role-results/android.json").is_file()
        )
        self.assertTrue(
            (run_path / "attempts/02/role-results/android.json").is_file()
        )

    def test_test_verification_stops_after_three_attempts(self):
        run_path = self.create_run()
        failure = {"status": "failed", "summary": "verification failed"}
        executor = FakeExecutor(
            scripted={"test-verification": [failure, failure, failure]}
        )

        status = runner.execute_run(run_path, executor=executor)

        self.assertEqual("failed", status)
        self.assertEqual(
            [1, 2, 3],
            [attempt for agent, attempt in executor.calls if agent == "test-verification"],
        )

    def test_reviewer_platform_finding_repairs_affected_path(self):
        run_path = self.create_run()
        executor = FakeExecutor(
            scripted={
                "acceptance-reviewer": [
                    {
                        "findings": [
                            {
                                "id": "F-1",
                                "category": "implementation",
                                "owner": "android",
                                "severity": "high",
                                "description": "Android behavior is incomplete",
                            }
                        ]
                    }
                ]
            }
        )

        status = runner.execute_run(run_path, executor=executor)

        self.assertEqual("passed", status)
        self.assertEqual(2, sum(agent == "android" for agent, _ in executor.calls))
        self.assertEqual(1, sum(agent == "ios" for agent, _ in executor.calls))
        self.assertEqual(
            2, sum(agent == "acceptance-reviewer" for agent, _ in executor.calls)
        )

    def test_architecture_finding_restarts_all_dependents(self):
        run_path = self.create_run()
        executor = FakeExecutor(
            scripted={
                "acceptance-reviewer": [
                    {
                        "findings": [
                            {
                                "id": "F-ARCH",
                                "category": "architecture",
                                "owner": "architect",
                                "severity": "high",
                                "description": "Architecture decision is inconsistent",
                            }
                        ]
                    }
                ]
            }
        )

        self.assertEqual("passed", runner.execute_run(run_path, executor=executor))

        rerun_agents = {
            agent for agent, attempt in executor.calls if attempt == 2
        }
        self.assertEqual(
            {
                "architect",
                "ux-design",
                "test-design",
                "android",
                "ios",
                "test-verification",
                "ux-acceptance",
                "acceptance-reviewer",
            },
            rerun_agents,
        )

    def test_blocked_product_resumes_after_input_change(self):
        run_path = self.create_run()
        blocked = FakeExecutor(
            scripted={
                "product": [
                    {
                        "status": "blocked",
                        "summary": "source unavailable",
                        "gaps": ["source unavailable"],
                    }
                ]
            }
        )

        self.assertEqual("blocked", runner.execute_run(run_path, executor=blocked))
        run_input = self.read_json(run_path, "run-input.json")
        run_input["source_refs"] = ["product:REQ-1-AVAILABLE"]
        (run_path / "run-input.json").write_text(
            json.dumps(run_input, indent=2) + "\n", encoding="utf-8"
        )

        resumed = FakeExecutor(source_refs=["product:REQ-1-AVAILABLE"])
        self.assertEqual("passed", runner.resume_run(run_path, executor=resumed))
        self.assertEqual("product", resumed.calls[0][0])
        self.assertTrue(
            (run_path / "attempts/02/role-results/product.json").is_file()
        )

    def test_parallel_executor_error_preserves_other_platform_result(self):
        run_path = self.create_run()
        executor = FakeExecutor(scripted={"android": [OSError("device unavailable")]})

        status = runner.execute_run(run_path, executor=executor)
        state = self.read_json(run_path, "run-state.json")

        self.assertEqual("blocked", status)
        self.assertEqual("blocked", state["nodes"]["android"]["status"])
        self.assertEqual("passed", state["nodes"]["ios"]["status"])
        self.assertTrue(
            (run_path / "attempts/01/role-results/ios.json").is_file()
        )
        self.assertNotIn("running", {node["status"] for node in state["nodes"].values()})

    def test_test_verification_finding_routes_to_affected_platform(self):
        run_path = self.create_run()
        executor = FakeExecutor(
            scripted={
                "test-verification": [
                    {
                        "status": "failed",
                        "summary": "Android evidence failed",
                        "findings": [
                            {
                                "id": "F-TV",
                                "category": "implementation",
                                "owner": "android",
                                "severity": "high",
                                "description": "Android implementation mismatch",
                            }
                        ],
                    }
                ]
            }
        )

        self.assertEqual("passed", runner.execute_run(run_path, executor=executor))

        self.assertEqual(2, sum(agent == "android" for agent, _ in executor.calls))
        self.assertEqual(1, sum(agent == "ios" for agent, _ in executor.calls))

    def test_manual_resume_is_not_limited_by_automatic_attempt_budget(self):
        run_path = self.create_run()
        self.assertEqual(
            "blocked",
            runner.execute_run(
                run_path,
                executor=FakeExecutor(
                    scripted={"product": [{"status": "blocked"}]}
                ),
            ),
        )
        for generation in (2, 3):
            run_input = self.read_json(run_path, "run-input.json")
            source = f"product:REQ-{generation}"
            run_input["source_refs"] = [source]
            (run_path / "run-input.json").write_text(
                json.dumps(run_input, indent=2) + "\n", encoding="utf-8"
            )
            self.assertEqual(
                "blocked",
                runner.resume_run(
                    run_path,
                    executor=FakeExecutor(
                        source_refs=[source],
                        scripted={"product": [{"status": "blocked"}]},
                    ),
                ),
            )
        run_input = self.read_json(run_path, "run-input.json")
        run_input["source_refs"] = ["product:REQ-4"]
        (run_path / "run-input.json").write_text(
            json.dumps(run_input, indent=2) + "\n", encoding="utf-8"
        )

        self.assertEqual(
            "passed",
            runner.resume_run(
                run_path,
                executor=FakeExecutor(source_refs=["product:REQ-4"]),
            ),
        )
        self.assertTrue(
            (run_path / "attempts/04/role-results/product.json").is_file()
        )

    def test_prompts_include_role_contract_and_platform_entrypoints(self):
        run_path = self.create_run()
        state = self.read_json(run_path, "run-state.json")
        policy = runner.load_policy()
        nodes = runner._nodes_for_state(policy, state)

        product_prompt = runner.build_prompt(run_path, state, nodes["product"], 1)
        android_prompt = runner.build_prompt(run_path, state, nodes["android"], 1)

        self.assertIn("acceptance_criteria", product_prompt)
        self.assertIn("ux_required", product_prompt)
        self.assertIn("Android/AGENTS.md", android_prompt)
        self.assertIn("Android/.agents/skills/ac-workflow/SKILL.md", android_prompt)

    def test_product_must_report_exact_declared_sources(self):
        run_path = self.create_run()

        status = runner.execute_run(
            run_path, executor=FakeExecutor(source_refs=["product:OTHER"])
        )

        self.assertEqual("blocked", status)

    def test_test_verification_cannot_modify_tracked_repository_diff(self):
        run_path = self.create_run()
        executor = FakeExecutor()
        original_fingerprint = runner.repository_fingerprint
        fingerprints = iter(["before", "after"])
        runner.repository_fingerprint = lambda: next(fingerprints)
        try:
            status = runner.execute_run(run_path, executor=executor)
        finally:
            runner.repository_fingerprint = original_fingerprint

        self.assertEqual("blocked", status)
        self.assertIn("acceptance-reviewer", [agent for agent, _ in executor.calls])


if __name__ == "__main__":
    unittest.main()
