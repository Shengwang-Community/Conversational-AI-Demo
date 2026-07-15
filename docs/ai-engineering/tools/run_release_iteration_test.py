#!/usr/bin/env python3
import importlib.util
import io
import hashlib
import json
import os
import tempfile
import threading
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace


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
        platforms=None,
        workflow_profile="full",
    ):
        self.ux_required = ux_required
        self.hld_required = hld_required
        self.scripted = {key: list(value) for key, value in (scripted or {}).items()}
        self.source_refs = source_refs or ["product:REQ-1"]
        self.platforms = platforms or ["android", "ios"]
        self.workflow_profile = workflow_profile
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
        self.materialize_artifacts(run_path, result)
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
            "web": "web-result.json",
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
                    "platforms": self.platforms,
                    "acceptance_criteria": ["criterion-1"],
                    "contract_status": "confirmed",
                    "contract_evidence": [
                        {
                            "type": "json_schema",
                            "path": "contract-evidence/contract.schema.json",
                            "sha256": "pending",
                        }
                    ],
                    "workflow_profile": self.workflow_profile,
                }
            )
            if self.workflow_profile in {"direct", "standard"}:
                outputs.update(
                    {
                        "hld_required": False,
                        "hld_rationale": "no cross-component design is required",
                        "covered_criteria": ["criterion-1"],
                    }
                )
            artifacts.append(
                {
                    "path": "contract-evidence/contract.schema.json",
                    "content": '{"type":"object"}\n',
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
        elif agent in self.platforms:
            outputs["covered_criteria"] = ["criterion-1"]
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
                    "verified_platforms": self.platforms,
                    "covered_criteria": ["criterion-1"],
                }
            )
            validation.extend(
                {
                    "command": f"verify {platform} evidence",
                    "result": "passed",
                    "evidence": f"{platform} independently verified",
                }
                for platform in self.platforms
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
            "accepted_gap_refs": [],
            "validation": validation,
        }

    @staticmethod
    def materialize_artifacts(run_path, result):
        references = []
        hashes = {}
        for artifact in result["artifacts"]:
            if set(artifact) == {"path", "sha256"}:
                references.append(artifact)
                hashes[artifact["path"]] = artifact["sha256"]
                continue
            content = artifact["content"]
            if not isinstance(content, str):
                content = json.dumps(content, indent=2) + "\n"
            path = Path(run_path) / artifact["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            hashes[artifact["path"]] = digest
            references.append({"path": artifact["path"], "sha256": digest})
        result["artifacts"] = references
        evidence = result.get("outputs", {}).get("contract_evidence", [])
        for item in evidence:
            if item.get("path") in hashes:
                item["sha256"] = hashes[item["path"]]


class RunnerTest(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.runs_dir = Path(self.tempdir.name) / "pilot-runs"
        self.runs_dir.mkdir()
        self.original_runs_dir = runner.RUNS_DIR
        self.original_ensure_ignored = runner.ensure_ignored
        self.original_repository_fingerprint = runner.repository_fingerprint
        self.original_changed_line_findings = runner.privacy.changed_line_findings
        runner.RUNS_DIR = self.runs_dir
        runner.ensure_ignored = lambda path: None
        runner.repository_fingerprint = lambda: "f" * 64
        runner.privacy.changed_line_findings = lambda root: []

    def tearDown(self):
        runner.RUNS_DIR = self.original_runs_dir
        runner.ensure_ignored = self.original_ensure_ignored
        runner.repository_fingerprint = self.original_repository_fingerprint
        runner.privacy.changed_line_findings = self.original_changed_line_findings
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

    def write_native_result(self, run_path, role_result):
        dispatches = runner.native_dispatch(run_path)
        dispatch = next(
            (
                item
                for item in dispatches
                if item["agent"] == role_result["agent"]
            ),
            None,
        )
        if dispatch and dispatch.get("repository_fingerprint"):
            role_result["repository_fingerprint"] = dispatch[
                "repository_fingerprint"
            ]
        FakeExecutor.materialize_artifacts(run_path, role_result)
        path = run_path / "native-results" / (
            f"{role_result['attempt']:02d}-{role_result['agent']}.json"
        )
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(role_result), encoding="utf-8")
        return path

    def test_execute_run_rejects_implicit_nested_cli(self):
        run_path = self.create_run()

        with self.assertRaisesRegex(RuntimeError, "native Agent orchestration"):
            runner.execute_run(run_path)

    def test_execute_run_blocks_before_platform_without_authorization(self):
        run_path = runner.create_run(
            "unauthorized-executor",
            "Deliver a product requirement",
            ["product:REQ-1"],
            ["android", "ios"],
            False,
            today="2026-07-10",
        )
        executor = FakeExecutor()

        self.assertEqual("blocked", runner.execute_run(run_path, executor=executor))

        called = [agent for agent, _ in executor.calls]
        self.assertNotIn("android", called)
        self.assertNotIn("ios", called)
        self.assertNotIn("test-verification", called)
        self.assertNotIn("acceptance-reviewer", called)

    def test_execute_run_blocks_before_platform_on_privacy_delta(self):
        run_path = self.create_run()
        executor = FakeExecutor()
        runner.privacy.changed_line_findings = lambda root: [
            {
                "path": "Android/Secret.kt",
                "line": 9,
                "message": " possible credential or token literal",
                "content_sha256": "a" * 64,
            }
        ]

        self.assertEqual("blocked", runner.execute_run(run_path, executor=executor))

        called = [agent for agent, _ in executor.calls]
        self.assertNotIn("android", called)
        self.assertNotIn("ios", called)
        self.assertNotIn("test-verification", called)

    def test_native_dispatch_starts_with_product_without_mutating_state(self):
        run_path = self.create_run()
        before = self.read_json(run_path, "run-state.json")

        dispatches = runner.native_dispatch(run_path)

        self.assertEqual(["product"], [item["agent"] for item in dispatches])
        self.assertEqual(1, dispatches[0]["attempt"])
        self.assertIn("Read every declared source", dispatches[0]["prompt"])
        self.assertTrue(Path(dispatches[0]["result_path"]).parent.is_dir())
        self.assertEqual(before, self.read_json(run_path, "run-state.json"))

    def test_native_product_result_advances_to_knowledge(self):
        run_path = self.create_run()
        role_result = FakeExecutor()._default_result("product", 1)
        result_path = self.write_native_result(run_path, role_result)

        outcome = runner.ingest_native_results(
            run_path,
            [(result_path, "product-agent-1")],
        )

        state = self.read_json(run_path, "run-state.json")
        self.assertEqual("passed", state["nodes"]["product"]["status"])
        self.assertEqual(["knowledge"], [item["agent"] for item in outcome["ready"]])
        provenance = state["execution"]["runs"]["product"]
        self.assertEqual("native:product-agent-1:1", provenance["thread_id"])
        self.assertEqual("completed", provenance["result"])
        self.assertEqual("unavailable", provenance["attestation_status"])
        self.assertIn("requested_model", provenance)
        self.assertIn("requested_sandbox", provenance)
        self.assertNotIn("model", provenance)
        self.assertNotIn("sandbox", provenance)

    def test_unauthorized_standard_run_blocks_platform_without_reviewer_dispatch(self):
        run_path = runner.create_run(
            "unauthorized-standard",
            "Deliver a product requirement",
            ["product:REQ-1"],
            ["android"],
            False,
            today="2026-07-10",
            workflow_profile="standard",
        )
        product = FakeExecutor(
            platforms=["android"],
            ux_required=False,
            hld_required=False,
            workflow_profile="standard",
        )._default_result("product", 1)

        outcome = runner.ingest_native_results(
            run_path,
            [(self.write_native_result(run_path, product), "product-agent")],
        )

        self.assertEqual("blocked", outcome["status"])
        self.assertEqual([], outcome["ready"])
        state = self.read_json(run_path, "run-state.json")
        self.assertEqual("pending", state["nodes"]["android"]["status"])
        self.assertEqual("not_required", state["nodes"]["acceptance-reviewer"]["status"])

        run_input = self.read_json(run_path, "run-input.json")
        run_input["implementation_authorized"] = True
        (run_path / "run-input.json").write_text(
            json.dumps(run_input, indent=2) + "\n", encoding="utf-8"
        )
        resumed = runner.prepare_native_resume(run_path)

        self.assertEqual(["android"], [item["agent"] for item in resumed["ready"]])
        state = self.read_json(run_path, "run-state.json")
        self.assertEqual("passed", state["nodes"]["product"]["status"])
        self.assertTrue(
            any(event["type"] == "authorization_update" for event in state["events"])
        )

    def test_platform_result_is_rejected_when_privacy_delta_appears(self):
        run_path = self.create_run(platforms=["android"])
        state = self.read_json(run_path, "run-state.json")
        state["routing"].update(
            {
                "platforms": ["android"],
                "ux_required": False,
                "ux_reason": "no UX change",
                "hld_required": False,
                "hld_rationale": "no architecture change",
            }
        )
        for agent in ("product", "knowledge", "architect", "test-design"):
            state["nodes"][agent]["status"] = "passed"
        for agent in ("ux-design", "ux-acceptance"):
            state["nodes"][agent]["status"] = "not_required"
        runner._write_state(run_path, state)
        android = FakeExecutor(platforms=["android"])._default_result("android", 1)
        result_path = self.write_native_result(run_path, android)
        runner.privacy.changed_line_findings = lambda root: [
            {
                "path": "Android/Secret.kt",
                "line": 9,
                "message": " possible credential or token literal",
                "content_sha256": "a" * 64,
            }
        ]

        with self.assertRaisesRegex(ValueError, "repository privacy delta rejected"):
            runner.ingest_native_results(
                run_path, [(result_path, "android-agent")]
            )

    def test_finalizer_revalidates_artifact_hash(self):
        run_path = self.create_run(platforms=["android"])
        self.assertEqual(
            "passed",
            runner.execute_run(
                run_path,
                executor=FakeExecutor(platforms=["android"]),
            ),
        )
        (run_path / "android-result.json").write_text(
            "tampered\n", encoding="utf-8"
        )
        state = self.read_json(run_path, "run-state.json")

        self.assertEqual(
            "blocked", runner.finalize_run(run_path, state, runner.load_policy())
        )
        state = self.read_json(run_path, "run-state.json")
        self.assertIn(
            "artifact hash mismatch: android-result.json",
            state["finalization_errors"],
        )

    def test_finalizer_clears_resolved_integrity_error(self):
        run_path = self.create_run(platforms=["android"])
        state = self.read_json(run_path, "run-state.json")
        state["finalization_errors"] = ["resolved privacy delta"]
        runner._write_state(run_path, state)

        self.assertEqual(
            "in_progress", runner.finalize_run(run_path, state, runner.load_policy())
        )

        self.assertNotIn(
            "finalization_errors", self.read_json(run_path, "run-state.json")
        )

    def test_product_reselect_restores_not_required_platform(self):
        run_path = self.create_run(platforms=["android", "ios"])
        state = self.read_json(run_path, "run-state.json")
        first = FakeExecutor(platforms=["android"])._default_result("product", 1)
        first["outputs"].update(
            {"contract_status": "mock", "contract_evidence": []}
        )
        runner.update_routing_from_product(state, first)
        self.assertEqual("not_required", state["nodes"]["ios"]["status"])
        second = FakeExecutor(platforms=["android", "ios"])._default_result(
            "product", 1
        )
        second["outputs"].update(
            {"contract_status": "mock", "contract_evidence": []}
        )

        runner.update_routing_from_product(state, second)

        self.assertEqual("pending", state["nodes"]["ios"]["status"])
        self.assertEqual("reselected by Product", state["nodes"]["ios"]["reason"])

    def test_v1_state_migration_preserves_passed_planning(self):
        run_path = self.create_run(platforms=["android"])
        state = self.read_json(run_path, "run-state.json")
        state["schema_version"] = 1
        state.pop("artifact_index")
        state.pop("privacy")
        state["input"].pop("workflow_profile")
        state["routing"].pop("workflow_profile")
        state["routing"].pop("contract_status")
        state["routing"].pop("contract_evidence")
        state["nodes"]["product"]["status"] = "passed"
        state["results"]["product"] = {
            "agent": "product",
            "attempt": 1,
            "outputs": {},
            "artifacts": [],
            "accepted_gaps": [{"gap": "mock contract"}],
        }
        state["execution"]["runs"]["product"] = {
            "agent": "product",
            "attempt": 1,
            "thread_id": "native:product:1",
            "model": "primary",
            "sandbox": "read-only",
            "working_directory": ".",
            "output": "attempts/01/role-results/product.json",
            "result": "completed",
        }
        runner._write_state(run_path, state)

        migrated = runner._load_state(run_path)

        self.assertEqual(3, migrated["schema_version"])
        self.assertEqual("passed", migrated["nodes"]["product"]["status"])
        self.assertEqual("full", migrated["routing"]["workflow_profile"])
        self.assertEqual("mock", migrated["routing"]["contract_status"])
        self.assertTrue(
            migrated["results"]["product"]["accepted_gaps"][0]["gap_id"].startswith(
                "gap-"
            )
        )
        self.assertEqual(
            [], migrated["results"]["product"]["accepted_gap_refs"]
        )
        self.assertEqual([], migrated["privacy"]["changed_line_baseline"])
        provenance = migrated["execution"]["runs"]["product"]
        self.assertEqual("primary", provenance["requested_model"])
        self.assertEqual("unavailable", provenance["attestation_status"])

    def test_v2_state_migration_updates_legacy_profile_input_and_hash(self):
        run_path = self.create_run(platforms=["android"])
        state = self.read_json(run_path, "run-state.json")
        state["schema_version"] = 2
        state["input"]["workflow_profile"] = "fast"
        state["input_hash"] = runner.workflow_workspace.canonical_hash(state["input"])
        state["routing"]["workflow_profile"] = "fast"
        runner._write_state(run_path, state)
        run_input = self.read_json(run_path, "run-input.json")
        run_input["workflow_profile"] = "fast"
        runner.workflow_workspace.atomic_write_json(
            run_path / "run-input.json", run_input
        )

        migrated = runner._load_state(run_path)

        self.assertEqual("standard", migrated["input"]["workflow_profile"])
        self.assertEqual("standard", migrated["routing"]["workflow_profile"])
        self.assertEqual(
            runner.workflow_workspace.canonical_hash(migrated["input"]),
            migrated["input_hash"],
        )
        self.assertEqual(
            "standard",
            self.read_json(run_path, "run-input.json")["workflow_profile"],
        )

    def test_native_blocked_product_dispatches_acceptance_reviewer(self):
        run_path = self.create_run()
        role_result = FakeExecutor()._default_result("product", 1)
        role_result.update(
            {
                "status": "blocked",
                "summary": "Product input is incomplete",
                "gaps": ["server contract missing"],
            }
        )
        result_path = self.write_native_result(run_path, role_result)

        outcome = runner.ingest_native_results(
            run_path,
            [(result_path, "product-agent-1")],
        )

        self.assertEqual("blocked", outcome["status"])
        self.assertEqual(
            ["acceptance-reviewer"],
            [item["agent"] for item in outcome["ready"]],
        )

    def test_requested_standard_blocked_product_stops_without_reviewer(self):
        run_path = runner.create_run(
            "blocked-standard",
            "Deliver a product requirement",
            ["product:REQ-1"],
            ["android"],
            True,
            today="2026-07-10",
            workflow_profile="standard",
        )
        role_result = FakeExecutor(
            platforms=["android"],
            ux_required=False,
            hld_required=False,
            workflow_profile="standard",
        )._default_result("product", 1)
        role_result.update(
            {
                "status": "blocked",
                "summary": "Product input is incomplete",
                "gaps": ["server contract missing"],
            }
        )

        outcome = runner.ingest_native_results(
            run_path,
            [(self.write_native_result(run_path, role_result), "product-agent-1")],
        )

        self.assertEqual("blocked", outcome["status"])
        self.assertEqual([], outcome["ready"])

    def test_native_exhausted_failure_dispatches_acceptance_reviewer(self):
        run_path = self.create_run()
        state = self.read_json(run_path, "run-state.json")
        state["repair_attempt"] = state["max_attempts"]
        state["execution"]["repair_attempt"] = state["max_attempts"]
        runner._write_state(run_path, state)
        role_result = FakeExecutor()._default_result("product", 1)
        role_result.update({"status": "failed", "summary": "Product failed"})

        outcome = runner.ingest_native_results(
            run_path,
            [
                (
                    self.write_native_result(run_path, role_result),
                    "product-agent-1",
                )
            ],
        )

        self.assertEqual("failed", outcome["status"])
        self.assertEqual(
            ["acceptance-reviewer"],
            [item["agent"] for item in outcome["ready"]],
        )

        reviewer_result = FakeExecutor()._default_result("acceptance-reviewer", 1)
        outcome = runner.ingest_native_results(
            run_path,
            [
                (
                    self.write_native_result(run_path, reviewer_result),
                    "acceptance-reviewer-agent-1",
                )
            ],
        )

        self.assertEqual("failed", outcome["status"])
        self.assertEqual([], outcome["ready"])

    def test_native_platform_batch_retries_only_failed_web(self):
        platforms = ["android", "ios", "web"]
        run_path = self.create_run(platforms=platforms)
        state = self.read_json(run_path, "run-state.json")
        state["routing"].update(
            {
                "platforms": platforms,
                "ux_required": False,
                "ux_reason": "no user-visible behavior changes",
                "hld_required": False,
                "hld_rationale": "no architecture change",
            }
        )
        for agent in ("product", "knowledge", "architect", "test-design"):
            state["nodes"][agent]["status"] = "passed"
        for agent in ("ux-design", "ux-acceptance"):
            state["nodes"][agent]["status"] = "not_required"
        runner._write_state(run_path, state)

        executor = FakeExecutor(platforms=platforms)
        submissions = []
        for agent in platforms:
            role_result = executor._default_result(agent, 1)
            if agent == "web":
                role_result.update({"status": "failed", "summary": "web test failed"})
            submissions.append(
                (self.write_native_result(run_path, role_result), f"{agent}-agent-1")
            )

        outcome = runner.ingest_native_results(run_path, submissions)

        state = self.read_json(run_path, "run-state.json")
        self.assertEqual(2, state["attempt"])
        self.assertEqual("passed", state["nodes"]["android"]["status"])
        self.assertEqual("passed", state["nodes"]["ios"]["status"])
        self.assertEqual("pending", state["nodes"]["web"]["status"])
        self.assertEqual(["web"], [item["agent"] for item in outcome["ready"]])

    def test_native_batch_validation_is_atomic_when_later_result_is_invalid(self):
        platforms = ["android", "ios"]
        run_path = self.create_run(platforms=platforms)
        state = self.read_json(run_path, "run-state.json")
        state["routing"].update(
            {
                "platforms": platforms,
                "ux_required": False,
                "ux_reason": "no user-visible behavior changes",
                "hld_required": False,
                "hld_rationale": "no architecture change",
            }
        )
        for agent in ("product", "knowledge", "architect", "test-design"):
            state["nodes"][agent]["status"] = "passed"
        for agent in ("ux-design", "ux-acceptance"):
            state["nodes"][agent]["status"] = "not_required"
        runner._write_state(run_path, state)
        before = self.read_json(run_path, "run-state.json")
        android = FakeExecutor(platforms=platforms)._default_result("android", 1)
        ios = FakeExecutor(platforms=platforms)._default_result("ios", 2)

        with self.assertRaisesRegex(ValueError, "attempt must be 1"):
            runner.ingest_native_results(
                run_path,
                [
                    (self.write_native_result(run_path, android), "android-agent"),
                    (self.write_native_result(run_path, ios), "ios-agent"),
                ],
            )

        self.assertEqual(before, self.read_json(run_path, "run-state.json"))

    def test_artifact_reference_never_overwrites_existing_file(self):
        run_path = self.create_run(platforms=["android"])
        artifact = run_path / "requirement-brief.md"
        artifact.write_text("complete requirement brief\n", encoding="utf-8")
        role_result = FakeExecutor(platforms=["android"])._default_result("product", 1)
        role_result["repository_fingerprint"] = runner.native_dispatch(run_path)[0][
            "repository_fingerprint"
        ]
        role_result["artifacts"] = [
            {"path": "requirement-brief.md", "content": "summary only\n"}
        ]

        result_path = run_path / "native-results" / "01-product.json"
        result_path.write_text(json.dumps(role_result), encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "path and sha256"):
            runner.ingest_native_results(
                run_path,
                [(result_path, "product-agent")],
            )

        self.assertEqual(
            "complete requirement brief\n", artifact.read_text(encoding="utf-8")
        )

    def test_new_run_reports_in_progress_instead_of_blocked(self):
        run_path = self.create_run(platforms=["android"])
        state = self.read_json(run_path, "run-state.json")

        self.assertEqual(
            "in_progress", runner.finalize_run(run_path, state, runner.load_policy())
        )

    def test_native_preflight_cli_validates_without_ingesting(self):
        run_path = self.create_run(platforms=["android"])
        result_path = self.write_native_result(
            run_path,
            FakeExecutor(platforms=["android"])._default_result("product", 1),
        )
        before = self.read_json(run_path, "run-state.json")
        stdout = io.StringIO()

        with redirect_stdout(stdout):
            code = runner.main(
                [
                    "run_release_iteration.py",
                    "--resume",
                    str(run_path),
                    "--validate-native-result",
                    str(result_path),
                ]
            )

        self.assertEqual(0, code)
        self.assertEqual("preflight_passed", json.loads(stdout.getvalue())["status"])
        self.assertEqual(before, self.read_json(run_path, "run-state.json"))

    def test_native_preflight_rejects_read_only_repository_mutation(self):
        run_path = self.create_run(platforms=["android"])
        result_path = self.write_native_result(
            run_path,
            FakeExecutor(platforms=["android"])._default_result("product", 1),
        )
        runner.repository_fingerprint = lambda: "e" * 64

        with self.assertRaisesRegex(ValueError, "read-only Agent changed repository"):
            runner.preflight_native_results(
                run_path, [(result_path, "product-agent")]
            )

        runner.repository_fingerprint = lambda: "f" * 64

    def test_confirmed_contract_without_evidence_is_rejected(self):
        run_path = self.create_run(platforms=["android"])
        role_result = FakeExecutor(platforms=["android"])._default_result("product", 1)
        role_result["outputs"]["contract_evidence"] = []
        role_result["artifacts"] = [
            item
            for item in role_result["artifacts"]
            if item["path"] != "contract-evidence/contract.schema.json"
        ]

        with self.assertRaisesRegex(ValueError, "confirmed contract requires"):
            runner.ingest_native_results(
                run_path,
                [(self.write_native_result(run_path, role_result), "product-agent")],
            )

    def test_complete_mock_contract_flow_has_non_production_terminal_status(self):
        run_path = self.create_run(platforms=["android"])
        executor = FakeExecutor(platforms=["android"])
        outcome = {"status": "in_progress", "ready": runner.native_dispatch(run_path)}

        while outcome["ready"]:
            submissions = []
            for dispatch in outcome["ready"]:
                result = executor._default_result(
                    dispatch["agent"], dispatch["attempt"]
                )
                if dispatch["agent"] == "product":
                    result["outputs"].update(
                        {"contract_status": "mock", "contract_evidence": []}
                    )
                    result["artifacts"] = [
                        item
                        for item in result["artifacts"]
                        if item["path"] != "contract-evidence/contract.schema.json"
                    ]
                    result["accepted_gaps"] = [
                        {
                            "gap_id": "production-contract-unavailable",
                            "gap": "Production server contract is unavailable.",
                            "rationale": "Mock delivery was explicitly approved.",
                            "owner": "server-contract",
                            "release_impact": "Production readiness is blocked.",
                            "approved_at": "2026-07-14T00:00:00+00:00",
                        }
                    ]
                submissions.append(
                    (
                        self.write_native_result(run_path, result),
                        f"native-{dispatch['agent']}-{dispatch['attempt']}",
                    )
                )
            outcome = runner.ingest_native_results(run_path, submissions)

        self.assertEqual("passed_with_mock_contract", outcome["status"])
        manifest = self.read_json(run_path, "acceptance-manifest.json")
        self.assertEqual("mock", manifest["routing"]["contract_status"])

    def test_main_rejects_execute_before_creating_run(self):
        with self.assertRaisesRegex(ValueError, "native Agent dispatch"):
            runner.main(
                [
                    "run_release_iteration.py",
                    "--name",
                    "no-nested-cli",
                    "--goal",
                    "Deliver requirement",
                    "--source",
                    "product:REQ-1",
                    "--platform",
                    "android",
                    "--execute",
                ]
            )

        self.assertEqual([], list(runner.RUNS_DIR.iterdir()))

    def test_main_new_run_returns_native_product_dispatch(self):
        stdout = io.StringIO()
        with redirect_stdout(stdout):
            code = runner.main(
                [
                    "run_release_iteration.py",
                    "--name",
                    "native-flow",
                    "--goal",
                    "Deliver requirement",
                    "--source",
                    "product:REQ-1",
                    "--profile",
                    "full",
                    "--platform",
                    "android",
                ]
            )

        payload = json.loads(stdout.getvalue())
        self.assertEqual(0, code)
        self.assertEqual("native", payload["mode"])
        self.assertEqual("full", payload["workflow_profile"])
        self.assertEqual(["product"], [item["agent"] for item in payload["ready"]])

    def test_main_ingests_native_result_and_returns_next_dispatch(self):
        run_path = self.create_run()
        result_path = self.write_native_result(
            run_path, FakeExecutor()._default_result("product", 1)
        )
        stdout = io.StringIO()

        with redirect_stdout(stdout):
            code = runner.main(
                [
                    "run_release_iteration.py",
                    "--resume",
                    str(run_path),
                    "--native-result",
                    str(result_path),
                    "--native-agent-id",
                    "product-agent-1",
                ]
            )

        payload = json.loads(stdout.getvalue())
        self.assertEqual(0, code)
        self.assertEqual(["knowledge"], [item["agent"] for item in payload["ready"]])

    def test_native_result_path_accepts_cwd_relative_path_inside_run(self):
        run_path = self.create_run()
        result_path = self.write_native_result(
            run_path, FakeExecutor()._default_result("product", 1)
        )
        cwd_relative = os.path.relpath(result_path, Path.cwd())

        resolved = runner._validated_native_result_path(run_path, cwd_relative)

        self.assertEqual(result_path.resolve(), resolved)

    def test_native_result_path_rejects_existing_file_outside_run(self):
        run_path = self.create_run()
        outside = Path(self.tempdir.name) / "outside.json"
        outside.write_text("{}", encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "under the run workspace"):
            runner._validated_native_result_path(
                run_path, os.path.relpath(outside, Path.cwd())
            )

    def test_native_retry_blocked_run_preserves_implementation_authorization(self):
        run_path = runner.create_run(
            "blocked-native-flow",
            "Deliver a product requirement",
            ["product:REQ-1"],
            ["android"],
            False,
            today="2026-07-10",
        )
        role_result = FakeExecutor()._default_result("product", 1)
        role_result.update(
            {
                "status": "blocked",
                "summary": "source unavailable",
                "gaps": ["source unavailable"],
            }
        )
        runner.ingest_native_results(
            run_path,
            [(self.write_native_result(run_path, role_result), "product-agent-1")],
        )

        outcome = runner.prepare_native_resume(run_path)

        state = self.read_json(run_path, "run-state.json")
        run_input = self.read_json(run_path, "run-input.json")
        self.assertEqual(2, state["attempt"])
        self.assertFalse(run_input["implementation_authorized"])
        self.assertEqual(["product"], [item["agent"] for item in outcome["ready"]])

    def test_complete_native_three_platform_flow_passes(self):
        platforms = ["android", "ios", "web"]
        run_path = self.create_run(platforms=platforms)
        executor = FakeExecutor(platforms=platforms)
        outcome = {"status": "blocked", "ready": runner.native_dispatch(run_path)}

        while outcome["ready"]:
            submissions = []
            for dispatch in outcome["ready"]:
                agent = dispatch["agent"]
                role_result = executor._default_result(agent, dispatch["attempt"])
                submissions.append(
                    (
                        self.write_native_result(run_path, role_result),
                        f"native-{agent}-{dispatch['attempt']}",
                    )
                )
            outcome = runner.ingest_native_results(run_path, submissions)

        manifest = self.read_json(run_path, "acceptance-manifest.json")
        self.assertEqual("passed", outcome["status"])
        self.assertEqual("passed", manifest["status"])
        self.assertEqual(platforms, manifest["platforms"])
        self.assertEqual([], runner.native_dispatch(run_path))
        self.assertTrue(
            all(
                record["thread_id"].startswith("native:")
                for record in manifest["execution"]["history"]
            )
        )

    def test_standard_profile_completes_single_platform_in_three_agent_runs(self):
        run_path = self.create_run(platforms=["android"])
        executor = FakeExecutor(
            platforms=["android"],
            ux_required=False,
            hld_required=False,
            workflow_profile="standard",
        )
        outcome = {"status": "in_progress", "ready": runner.native_dispatch(run_path)}

        while outcome["ready"]:
            submissions = []
            for dispatch in outcome["ready"]:
                result = executor._default_result(
                    dispatch["agent"], dispatch["attempt"]
                )
                submissions.append(
                    (
                        self.write_native_result(run_path, result),
                        f"native-{dispatch['agent']}-{dispatch['attempt']}",
                    )
                )
                executor.calls.append((dispatch["agent"], dispatch["attempt"]))
            outcome = runner.ingest_native_results(run_path, submissions)

        self.assertEqual("passed", outcome["status"])
        self.assertEqual(
            ["product", "android", "test-verification"],
            [agent for agent, _ in executor.calls],
        )
        state = self.read_json(run_path, "run-state.json")
        self.assertEqual("standard", state["routing"]["workflow_profile"])
        for agent in ("knowledge", "architect", "test-design", "acceptance-reviewer"):
            self.assertEqual("not_required", state["nodes"][agent]["status"])

    def test_direct_profile_completes_with_product_and_platform_only(self):
        run_path = self.create_run(platforms=["android"])
        executor = FakeExecutor(
            platforms=["android"],
            ux_required=False,
            hld_required=False,
            workflow_profile="direct",
        )
        outcome = {"status": "in_progress", "ready": runner.native_dispatch(run_path)}

        while outcome["ready"]:
            submissions = []
            for dispatch in outcome["ready"]:
                result = executor._default_result(
                    dispatch["agent"], dispatch["attempt"]
                )
                submissions.append(
                    (
                        self.write_native_result(run_path, result),
                        f"native-{dispatch['agent']}-{dispatch['attempt']}",
                    )
                )
                executor.calls.append((dispatch["agent"], dispatch["attempt"]))
            outcome = runner.ingest_native_results(run_path, submissions)

        self.assertEqual("passed", outcome["status"])
        self.assertEqual(
            ["product", "android"], [agent for agent, _ in executor.calls]
        )
        state = self.read_json(run_path, "run-state.json")
        self.assertEqual("direct", state["routing"]["workflow_profile"])
        self.assertEqual(
            "not_required", state["nodes"]["test-verification"]["status"]
        )

    def test_standard_profile_rejects_ux_or_hld_routing(self):
        run_path = self.create_run(platforms=["android"])
        result = FakeExecutor(
            platforms=["android"], workflow_profile="standard"
        )._default_result("product", 1)

        with self.assertRaisesRegex(ValueError, "standard profile"):
            runner.ingest_native_results(
                run_path,
                [(self.write_native_result(run_path, result), "product-agent")],
            )

    def test_native_result_validation_is_internal_to_runner(self):
        result = FakeExecutor(platforms=["android"])._default_result("android", 1)
        result["artifacts"] = [
            {"path": "android-result.json", "content": {}}
        ]

        errors = runner.validate_native_result_structure(result)

        self.assertTrue(any("path and sha256" in error for error in errors))

    def test_informational_findings_do_not_enter_repair_dag(self):
        result = FakeExecutor(platforms=["android"])._default_result("android", 1)
        result["findings"] = [
            {
                "id": "NOTE-1",
                "category": "implementation",
                "owner": "android",
                "severity": "informational",
                "description": "context only",
            }
        ]

        errors = runner.validate_native_result_structure(result)

        self.assertTrue(any("informational notes" in error for error in errors))

    def test_native_validation_rejects_invalid_gap_and_validation_records(self):
        result = FakeExecutor(platforms=["android"])._default_result("android", 1)
        result["validation"] = [
            {"command": "test", "result": "unknown", "evidence": "output"}
        ]
        result["accepted_gaps"] = [
            {
                "gap_id": "missing-contract",
                "gap": "missing contract",
                "rationale": "approved mock",
                "owner": "server",
                "release_impact": "not production ready",
                "approved_at": "not-a-date",
            }
        ]

        errors = runner.validate_native_result_structure(result)

        self.assertTrue(any("validation result" in error for error in errors))
        self.assertTrue(any("ISO date-time" in error for error in errors))

    def test_native_preflight_rejects_gap_approval_from_platform(self):
        run_path = self.create_run(platforms=["android"])
        executor = FakeExecutor(
            platforms=["android"],
            ux_required=False,
            hld_required=False,
            workflow_profile="standard",
        )
        product = executor._default_result("product", 1)
        runner.ingest_native_results(
            run_path,
            [(self.write_native_result(run_path, product), "product-agent")],
        )
        android = executor._default_result("android", 1)
        android["accepted_gaps"] = [
            {
                "gap_id": "device-unavailable",
                "gap": "Physical device is unavailable.",
                "rationale": "Platform approved its own exception.",
                "owner": "android",
                "release_impact": "Device behavior is unverified.",
                "approved_at": "2026-07-14T00:00:00+00:00",
            }
        ]

        with self.assertRaisesRegex(ValueError, "only Product may approve"):
            runner.ingest_native_results(
                run_path,
                [(self.write_native_result(run_path, android), "android-agent")],
            )

    def test_native_preflight_accepts_only_product_approved_gap_refs(self):
        run_path = self.create_run(platforms=["android"])
        executor = FakeExecutor(
            platforms=["android"],
            ux_required=False,
            hld_required=False,
            workflow_profile="standard",
        )
        product = executor._default_result("product", 1)
        product["accepted_gaps"] = [
            {
                "gap_id": "device-unavailable",
                "gap": "Physical device is unavailable.",
                "rationale": "Product approved mock-only validation.",
                "owner": "release-owner",
                "release_impact": "Device behavior remains unverified.",
                "approved_at": "2026-07-14T00:00:00+00:00",
            }
        ]
        runner.ingest_native_results(
            run_path,
            [(self.write_native_result(run_path, product), "product-agent")],
        )
        android = executor._default_result("android", 1)
        android["accepted_gap_refs"] = ["device-unavailable"]

        outcome = runner.ingest_native_results(
            run_path,
            [(self.write_native_result(run_path, android), "android-agent")],
        )

        self.assertEqual(
            ["test-verification"], [item["agent"] for item in outcome["ready"]]
        )

    def test_native_validation_handles_malformed_nested_values(self):
        result = FakeExecutor(platforms=["android"])._default_result("android", 1)
        result["artifacts"] = [{"path": {}, "sha256": "bad"}]
        result["source_refs"] = [{}]
        result["findings"] = [
            {
                "id": {},
                "category": "implementation",
                "owner": "android",
                "severity": "high",
                "description": "broken id",
            }
        ]

        errors = runner.validate_native_result_structure(result)

        self.assertTrue(any("artifact path" in error for error in errors))
        self.assertTrue(any("source_refs" in error for error in errors))
        self.assertTrue(any("finding fields" in error for error in errors))

    def test_product_result_without_profile_uses_standard_workflow(self):
        run_path = self.create_run(platforms=["android"])
        result = FakeExecutor(
            platforms=["android"],
            ux_required=False,
            hld_required=False,
            workflow_profile="standard",
        )._default_result("product", 1)
        result["outputs"].pop("workflow_profile")

        outcome = runner.ingest_native_results(
            run_path,
            [(self.write_native_result(run_path, result), "product-agent")],
        )

        self.assertEqual(["android"], [item["agent"] for item in outcome["ready"]])
        state = self.read_json(run_path, "run-state.json")
        self.assertEqual("standard", state["routing"]["workflow_profile"])

    def test_standard_test_coverage_finding_restarts_planning(self):
        run_path = self.create_run(platforms=["android"])
        executor = FakeExecutor(
            platforms=["android"],
            ux_required=False,
            hld_required=False,
            workflow_profile="standard",
        )
        product = executor._default_result("product", 1)
        outcome = runner.ingest_native_results(
            run_path,
            [(self.write_native_result(run_path, product), "product-agent")],
        )
        self.assertEqual(["android"], [item["agent"] for item in outcome["ready"]])
        android = executor._default_result("android", 1)
        outcome = runner.ingest_native_results(
            run_path,
            [(self.write_native_result(run_path, android), "android-agent")],
        )
        self.assertEqual(
            ["test-verification"], [item["agent"] for item in outcome["ready"]]
        )
        verification = executor._default_result("test-verification", 1)
        verification["findings"] = [
            {
                "id": "FAST-COVERAGE-1",
                "category": "test_coverage",
                "owner": "product",
                "severity": "high",
                "description": "Planning omitted a required test case.",
            }
        ]

        outcome = runner.ingest_native_results(
            run_path,
            [
                (
                    self.write_native_result(run_path, verification),
                    "verification-agent",
                )
            ],
        )

        self.assertEqual(["product"], [item["agent"] for item in outcome["ready"]])
        self.assertEqual(2, outcome["ready"][0]["attempt"])

    def test_requested_full_profile_cannot_be_downgraded_by_planning(self):
        run_path = runner.create_run(
            "forced-full",
            "Deliver a product requirement",
            ["product:REQ-1"],
            ["android"],
            True,
            today="2026-07-10",
            workflow_profile="full",
        )
        result = FakeExecutor(
            platforms=["android"],
            ux_required=False,
            hld_required=False,
            workflow_profile="standard",
        )._default_result("product", 1)

        with self.assertRaisesRegex(ValueError, "honor requested profile: full"):
            runner.ingest_native_results(
                run_path,
                [(self.write_native_result(run_path, result), "product-agent")],
            )

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

    def test_complete_flow_supports_web_platform(self):
        platforms = ["android", "ios", "web"]
        run_path = self.create_run(platforms=platforms)
        executor = FakeExecutor(platforms=platforms)

        status = runner.execute_run(run_path, executor=executor)
        manifest = self.read_json(run_path, "acceptance-manifest.json")

        self.assertEqual("passed", status)
        self.assertEqual(1, sum(agent == "web" for agent, _ in executor.calls))
        self.assertTrue((run_path / "web-result.json").is_file())
        verification = next(
            stage for stage in manifest["stages"] if stage["agent"] == "test-verification"
        )
        self.assertEqual(platforms, verification["outputs"]["verified_platforms"])

    def test_product_reroute_to_non_ux_discards_stale_optional_results(self):
        run_path = self.create_run()
        state = self.read_json(run_path, "run-state.json")
        for agent, artifact in (
            ("ux-design", "ux-spec.json"),
            ("ux-acceptance", "ux-acceptance.json"),
        ):
            state["nodes"][agent]["status"] = "passed"
            state["results"][agent] = {
                "agent": agent,
                "artifacts": [{"path": artifact}],
            }
            state["artifacts"].append(artifact)
            state["execution"]["runs"][agent] = {"agent": agent}

        runner.update_routing_from_product(
            state,
            {
                "outputs": {
                    "platforms": ["android", "ios"],
                    "ux_required": False,
                    "ux_reason": "no user-visible behavior changes",
                    "workflow_profile": "full",
                    "contract_status": "mock",
                    "contract_evidence": [],
                }
            },
        )

        manifest = runner._manifest_from_state(state)
        stages = {stage["agent"]: stage for stage in manifest["stages"]}
        self.assertEqual("not_required", stages["ux-design"]["status"])
        self.assertEqual("not_required", stages["ux-acceptance"]["status"])
        self.assertNotIn("ux-spec.json", manifest["artifacts"])
        self.assertNotIn("ux-acceptance.json", manifest["artifacts"])
        self.assertNotIn("ux-design", state["execution"]["runs"])
        self.assertNotIn("ux-acceptance", state["execution"]["runs"])

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

    def test_failed_web_retries_without_rerunning_passed_native_platforms(self):
        platforms = ["android", "ios", "web"]
        run_path = self.create_run(platforms=platforms)
        executor = FakeExecutor(
            platforms=platforms,
            scripted={"web": [{"status": "failed", "summary": "web test failed"}]},
        )

        status = runner.execute_run(run_path, executor=executor)

        self.assertEqual("passed", status)
        self.assertEqual(1, sum(agent == "android" for agent, _ in executor.calls))
        self.assertEqual(1, sum(agent == "ios" for agent, _ in executor.calls))
        self.assertEqual(2, sum(agent == "web" for agent, _ in executor.calls))

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
        self.assertEqual(
            1, sum(agent == "acceptance-reviewer" for agent, _ in executor.calls)
        )

    def test_design_failure_exhaustion_still_runs_acceptance_reviewer(self):
        run_path = self.create_run()
        failure = {"status": "failed", "summary": "test design failed"}
        executor = FakeExecutor(scripted={"test-design": [failure, failure, failure]})

        self.assertEqual("failed", runner.execute_run(run_path, executor=executor))
        self.assertEqual(
            [1, 2, 3],
            [attempt for agent, attempt in executor.calls if agent == "test-design"],
        )
        self.assertEqual(
            1, sum(agent == "acceptance-reviewer" for agent, _ in executor.calls)
        )

    def test_finalizer_block_can_resume_through_acceptance_reviewer(self):
        run_path = self.create_run()
        executor = FakeExecutor(
            scripted={"test-verification": [{"validation": []}]}
        )

        self.assertEqual("blocked", runner.execute_run(run_path, executor=executor))
        blocked_state = self.read_json(run_path, "run-state.json")
        self.assertEqual(
            "blocked", blocked_state["nodes"]["acceptance-reviewer"]["status"]
        )
        self.assertTrue(blocked_state["finalization_errors"])
        blocked_manifest = self.read_json(run_path, "acceptance-manifest.json")
        reviewer_stage = next(
            stage
            for stage in blocked_manifest["stages"]
            if stage["agent"] == "acceptance-reviewer"
        )
        self.assertEqual("blocked", reviewer_stage["status"])
        self.assertEqual(
            blocked_state["finalization_errors"],
            blocked_manifest["finalization_errors"],
        )

        resumed = FakeExecutor(
            scripted={
                "acceptance-reviewer": [
                    {
                        "findings": [
                            {
                                "id": "F-FINALIZER",
                                "category": "test_evidence",
                                "owner": "test-verification",
                                "severity": "high",
                                "description": "Independent validation evidence is missing",
                            }
                        ]
                    }
                ]
            }
        )

        self.assertEqual("passed", runner.resume_run(run_path, executor=resumed))
        self.assertEqual("acceptance-reviewer", resumed.calls[0][0])
        self.assertIn("test-verification", [agent for agent, _ in resumed.calls])

    def test_unknown_finding_category_blocks_reviewer_instead_of_raising(self):
        run_path = self.create_run()
        executor = FakeExecutor(
            scripted={
                "acceptance-reviewer": [
                    {
                        "findings": [
                            {
                                "id": "F-UNKNOWN",
                                "category": "unexpected-category",
                                "owner": "android",
                                "severity": "high",
                                "description": "Category is outside the policy contract",
                            }
                        ]
                    }
                ]
            }
        )

        self.assertEqual("blocked", runner.execute_run(run_path, executor=executor))
        state = self.read_json(run_path, "run-state.json")
        reviewer = state["nodes"]["acceptance-reviewer"]
        self.assertEqual("blocked", reviewer["status"])
        self.assertIn("unknown finding category", reviewer["reason"])

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

    def test_cli_rejects_external_resume_path_before_modifying_run_input(self):
        with tempfile.TemporaryDirectory() as tmp:
            external_run = Path(tmp)
            input_path = external_run / "run-input.json"
            original = json.dumps(
                {"implementation_authorized": False}, indent=2
            ) + "\n"
            input_path.write_text(original, encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "resume path must be under pilot-runs"):
                runner.main(
                    [
                        "run_release_iteration.py",
                        "--resume",
                        str(external_run),
                    ]
                )

            self.assertEqual(original, input_path.read_text(encoding="utf-8"))

    def test_prompts_include_role_contract_and_platform_entrypoints(self):
        run_path = self.create_run()
        state = self.read_json(run_path, "run-state.json")
        policy = runner.load_policy()
        nodes = runner._nodes_for_state(policy, state)

        product_prompt = runner.build_prompt(run_path, state, nodes["product"], 1)
        android_prompt = runner.build_prompt(run_path, state, nodes["android"], 1)

        self.assertIn("acceptance_criteria", product_prompt)
        self.assertIn("ux_required", product_prompt)
        self.assertNotIn("--validate-native-result", product_prompt)
        self.assertIn("Completion bar", product_prompt)
        self.assertIn(
            f"- {(runner.ROOT / 'Android/AGENTS.md').resolve()}", android_prompt
        )
        self.assertIn(
            f"- {(runner.ROOT / 'Android/.agents/skills/ac-workflow/SKILL.md').resolve()}",
            android_prompt,
        )

    def test_repository_fingerprint_hashes_untracked_file_contents(self):
        original_run = runner.subprocess.run
        untracked_content = b"first"

        def fake_run(command, **kwargs):
            if command[1] == "diff":
                return SimpleNamespace(returncode=0, stdout=b"tracked-diff")
            self.assertEqual("ls-files", command[1])
            return SimpleNamespace(returncode=0, stdout=b"new-file.txt\0")

        original_read_bytes = Path.read_bytes

        def fake_read_bytes(path):
            if path == runner.ROOT / "new-file.txt":
                return untracked_content
            return original_read_bytes(path)

        runner.subprocess.run = fake_run
        Path.read_bytes = fake_read_bytes
        try:
            first = self.original_repository_fingerprint()
            untracked_content = b"second"
            second = self.original_repository_fingerprint()
        finally:
            Path.read_bytes = original_read_bytes
            runner.subprocess.run = original_run

        self.assertNotEqual(first, second)

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
