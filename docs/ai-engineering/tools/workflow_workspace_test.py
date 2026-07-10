#!/usr/bin/env python3
import importlib.util
import tempfile
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

MODULE_PATH = Path(__file__).with_name("workflow_workspace.py")
SPEC = importlib.util.spec_from_file_location("workflow_workspace", MODULE_PATH)
workspace = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(workspace)


class WorkflowWorkspaceTest(unittest.TestCase):
    def test_resolve_under_rejects_escape(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, "escapes run workspace"):
                workspace.resolve_under(tmp, "../outside.json")

    def test_resolve_under_rejects_absolute_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            absolute = Path(tmp).parent / "outside.json"
            with self.assertRaisesRegex(ValueError, "absolute artifact path"):
                workspace.resolve_under(tmp, absolute)

    def test_resolve_under_rejects_symlink_escape(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            run_path = root / "run"
            outside = root / "outside"
            run_path.mkdir()
            outside.mkdir()
            (run_path / "linked").symlink_to(outside, target_is_directory=True)

            with self.assertRaisesRegex(ValueError, "escapes run workspace"):
                workspace.resolve_under(run_path, "linked/artifact.json")

    def test_resolve_under_normalizes_confined_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            run_path = Path(tmp)
            self.assertEqual(
                run_path.resolve() / "artifacts" / "result.json",
                workspace.resolve_under(
                    run_path, "attempts/../artifacts/result.json"
                ),
            )

    def test_canonical_hash_is_stable_for_mapping_order(self):
        left = {"b": 2, "a": 1}
        right = {"a": 1, "b": 2}
        expected = "43258cff783fe7036d8a43033f830adfc60ec037382473548ac742b888292777"

        self.assertEqual(expected, workspace.canonical_hash(left))
        self.assertEqual(expected, workspace.canonical_hash(right))

    def test_canonical_hash_preserves_list_order(self):
        self.assertNotEqual(
            workspace.canonical_hash({"platforms": ["android", "ios"]}),
            workspace.canonical_hash({"platforms": ["ios", "android"]}),
        )

    def test_atomic_write_json_creates_loadable_state_without_pending_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "nested" / "state.json"
            value = {"run_id": "run-1", "nodes": {"product": "pending"}}

            workspace.atomic_write_json(path, value)

            self.assertEqual(value, workspace.load_json(path))
            self.assertFalse(path.with_suffix(".json.tmp").exists())
            self.assertTrue(path.read_text(encoding="utf-8").endswith("\n"))

    def test_atomic_write_json_keeps_existing_state_and_cleans_temp_when_replace_fails(
        self,
    ):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "state.json"
            path.write_text('{"version": "old"}\n', encoding="utf-8")

            with patch.object(Path, "replace", side_effect=OSError("replace failed")):
                with self.assertRaisesRegex(OSError, "replace failed"):
                    workspace.atomic_write_json(path, {"version": "new"})

            self.assertEqual(
                '{"version": "old"}\n', path.read_text(encoding="utf-8")
            )
            self.assertFalse(path.with_suffix(".json.tmp").exists())
            self.assertEqual([], list(path.parent.glob(".state.json.*.tmp")))

    def test_atomic_write_json_does_not_follow_fixed_temp_symlink(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            run_path = root / "run"
            run_path.mkdir()
            path = run_path / "state.json"
            fixed_pending = run_path / "state.json.tmp"
            outside = root / "outside.json"
            path.write_text('{"version": "old"}\n', encoding="utf-8")
            outside.write_text("outside content", encoding="utf-8")
            fixed_pending.symlink_to(outside)

            workspace.atomic_write_json(path, {"version": "new"})

            self.assertEqual({"version": "new"}, workspace.load_json(path))
            self.assertFalse(path.is_symlink())
            self.assertTrue(fixed_pending.is_symlink())
            self.assertEqual("outside content", outside.read_text(encoding="utf-8"))

    def test_atomic_write_json_supports_overlapping_writers(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "state.json"
            values = [
                {"writer": "first", "items": list(range(100))},
                {"writer": "second", "items": list(range(100, 200))},
            ]
            barrier = threading.Barrier(2)
            original_replace = Path.replace

            def overlapping_replace(pending, destination):
                barrier.wait(timeout=2)
                return original_replace(pending, destination)

            with patch.object(Path, "replace", overlapping_replace):
                with ThreadPoolExecutor(max_workers=2) as executor:
                    futures = [
                        executor.submit(workspace.atomic_write_json, path, value)
                        for value in values
                    ]
                    for future in futures:
                        future.result(timeout=3)

            self.assertIn(workspace.load_json(path), values)
            self.assertEqual([], list(path.parent.glob(".state.json.*.tmp")))

    def test_initial_state_records_input_hash_and_node_fields(self):
        run_input = {
            "goal": "Deliver behavior",
            "sources": ["jira:PROJECT-123"],
            "platforms": ["android"],
        }
        state = workspace.initial_state(
            "run-1", run_input, ["product", "knowledge"], max_attempts=3
        )

        self.assertEqual(1, state["schema_version"])
        self.assertEqual("run-1", state["run_id"])
        self.assertEqual(run_input, state["input"])
        self.assertEqual(workspace.canonical_hash(run_input), state["input_hash"])
        self.assertEqual(1, state["attempt"])
        self.assertEqual(3, state["max_attempts"])
        self.assertEqual([], state["events"])
        expected_node = {
            "status": "pending",
            "attempt": None,
            "input_hash": None,
            "artifact_hash": None,
            "reason": None,
        }
        self.assertEqual(expected_node, state["nodes"]["product"])
        self.assertEqual(expected_node, state["nodes"]["knowledge"])

    def test_initial_state_hash_uses_snapshot_not_later_nested_mutation(self):
        run_input = {
            "goal": "Deliver behavior",
            "request": {
                "platforms": ["android"],
                "source": {"reference": "jira:PROJECT-123"},
            },
        }
        state = workspace.initial_state("run-1", run_input, ["product"], 3)
        expected_snapshot = {
            "goal": "Deliver behavior",
            "request": {
                "platforms": ["android"],
                "source": {"reference": "jira:PROJECT-123"},
            },
        }

        run_input["request"]["platforms"].append("ios")
        run_input["request"]["source"]["reference"] = "jira:PROJECT-456"

        self.assertEqual(expected_snapshot, state["input"])
        self.assertEqual(
            workspace.canonical_hash(state["input"]), state["input_hash"]
        )
        self.assertNotEqual(workspace.canonical_hash(run_input), state["input_hash"])

    def test_invalidate_architect_change_invalidates_all_dependents(self):
        state = workspace.initial_state(
            "run-1",
            {
                "goal": "Deliver behavior",
                "sources": ["jira:PROJECT-123"],
                "platforms": ["android"],
            },
            [
                "product",
                "knowledge",
                "architect",
                "ux-design",
                "test-design",
                "android",
                "test-verification",
                "ux-acceptance",
                "acceptance-reviewer",
            ],
            max_attempts=3,
        )
        for node in state["nodes"].values():
            node["status"] = "passed"

        workspace.invalidate_from(state, "architect", "architecture output changed")

        self.assertEqual("passed", state["nodes"]["product"]["status"])
        self.assertEqual("passed", state["nodes"]["knowledge"]["status"])
        self.assertEqual("passed", state["nodes"]["architect"]["status"])
        self.assertEqual("pending", state["nodes"]["test-design"]["status"])
        self.assertEqual(
            "pending", state["nodes"]["acceptance-reviewer"]["status"]
        )

    def test_invalidation_expands_platforms_deterministically_and_logs_event(self):
        node_ids = [
            "architect",
            "ux-design",
            "test-design",
            "ios",
            "android",
            "test-verification",
            "ux-acceptance",
            "acceptance-reviewer",
        ]
        state = workspace.initial_state("run-1", {"goal": "Goal"}, node_ids, 3)
        state["events"].append({"type": "existing"})
        for node in state["nodes"].values():
            node.update(
                {
                    "status": "passed",
                    "input_hash": "old-input",
                    "artifact_hash": "old-artifact",
                }
            )

        invalidated = workspace.invalidate_from(
            state, "architect", "architecture output changed"
        )

        expected = [
            "ux-design",
            "test-design",
            "ios",
            "android",
            "test-verification",
            "ux-acceptance",
            "acceptance-reviewer",
        ]
        self.assertEqual(expected, invalidated)
        for node_id in expected:
            node = state["nodes"][node_id]
            self.assertEqual("pending", node["status"])
            self.assertEqual("architecture output changed", node["reason"])
            self.assertIsNone(node["input_hash"])
            self.assertIsNone(node["artifact_hash"])
        self.assertEqual({"type": "existing"}, state["events"][0])
        event = state["events"][1]
        self.assertEqual("invalidation", event["type"])
        self.assertEqual("architect", event["source"])
        self.assertEqual(expected, event["targets"])
        self.assertEqual("architecture output changed", event["reason"])
        self.assertEqual(
            timezone.utc, datetime.fromisoformat(event["at"]).tzinfo
        )

    def test_invalidation_preserves_not_required_nodes(self):
        state = workspace.initial_state(
            "run-1",
            {"goal": "Goal"},
            [
                "architect",
                "ux-design",
                "test-design",
                "android",
                "test-verification",
                "ux-acceptance",
                "acceptance-reviewer",
            ],
            3,
        )
        ux_design = state["nodes"]["ux-design"]
        ux_design.update(
            {
                "status": "not_required",
                "reason": "run has no UX change",
                "input_hash": "kept-input",
                "artifact_hash": "kept-artifact",
            }
        )

        invalidated = workspace.invalidate_from(
            state, "architect", "architecture changed"
        )

        self.assertEqual("not_required", ux_design["status"])
        self.assertEqual("run has no UX change", ux_design["reason"])
        self.assertEqual("kept-input", ux_design["input_hash"])
        self.assertEqual("kept-artifact", ux_design["artifact_hash"])
        self.assertNotIn("ux-design", invalidated)
        self.assertNotIn("ux-design", state["events"][-1]["targets"])

    def test_invalidation_traverses_not_required_node_without_reporting_it(self):
        state = workspace.initial_state(
            "run-1",
            {"goal": "Goal"},
            ["source", "optional", "dependent"],
            3,
        )
        state["nodes"]["source"]["status"] = "passed"
        state["nodes"]["optional"]["status"] = "not_required"
        state["nodes"]["dependent"]["status"] = "passed"
        graph = {
            "source": ["optional"],
            "optional": ["dependent"],
        }

        with patch.dict(workspace.INVALIDATES, graph, clear=True):
            invalidated = workspace.invalidate_from(
                state, "source", "source output changed"
            )

        self.assertEqual(["dependent"], invalidated)
        self.assertEqual("not_required", state["nodes"]["optional"]["status"])
        self.assertEqual("pending", state["nodes"]["dependent"]["status"])
        self.assertEqual(["dependent"], state["events"][-1]["targets"])

    def test_resume_candidates_exclude_unchanged_passed_nodes(self):
        state = workspace.initial_state(
            "run-1", {"goal": "Goal"}, ["product", "knowledge"], 3
        )
        state["nodes"]["product"]["status"] = "passed"
        state["nodes"]["knowledge"]["status"] = "blocked"
        self.assertEqual(["knowledge"], workspace.resume_candidates(state))

    def test_resume_candidates_include_interrupted_running_nodes(self):
        state = workspace.initial_state("run-1", {"goal": "Goal"}, ["product"], 3)
        state["nodes"]["product"]["status"] = "running"

        self.assertEqual(["product"], workspace.resume_candidates(state))

    def test_resume_candidates_include_pending_blocked_and_failed_in_node_order(self):
        state = workspace.initial_state(
            "run-1",
            {"goal": "Goal"},
            [
                "pending-node",
                "passed-node",
                "blocked-node",
                "failed-node",
                "skipped-node",
            ],
            3,
        )
        state["nodes"]["passed-node"]["status"] = "passed"
        state["nodes"]["blocked-node"]["status"] = "blocked"
        state["nodes"]["failed-node"]["status"] = "failed"
        state["nodes"]["skipped-node"]["status"] = "not_required"

        self.assertEqual(
            ["pending-node", "blocked-node", "failed-node"],
            workspace.resume_candidates(state),
        )

    def test_attempt_result_path_is_confined_and_attempt_is_zero_padded(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(
                Path(tmp).resolve()
                / "attempts"
                / "03"
                / "role-results"
                / "android.json",
                workspace.attempt_result_path(tmp, 3, "android"),
            )

    def test_attempt_result_path_rejects_agent_escape(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, "escapes run workspace"):
                workspace.attempt_result_path(tmp, 1, "../../../../outside")

    def test_promote_artifact_scans_pending_file_then_replaces_destination(self):
        with tempfile.TemporaryDirectory() as tmp:
            run_path = Path(tmp)
            destination = run_path.resolve() / "artifacts" / "result.md"
            destination.parent.mkdir()
            destination.write_text("old content", encoding="utf-8")
            scanned = []

            def privacy_scan(paths):
                scanned.extend(paths)
                pending = Path(paths[0])
                self.assertTrue(pending.is_file())
                self.assertEqual("new content", pending.read_text(encoding="utf-8"))
                return []

            promoted = workspace.promote_artifact(
                run_path, "artifacts/result.md", "new content", privacy_scan
            )

            self.assertEqual(destination, promoted)
            self.assertEqual(
                [str(destination.with_suffix(".md.pending"))], scanned
            )
            self.assertEqual("new content", destination.read_text(encoding="utf-8"))
            self.assertFalse(destination.with_suffix(".md.pending").exists())

    def test_promote_artifact_rejects_workspace_root_destination(self):
        with tempfile.TemporaryDirectory() as tmp:
            run_path = Path(tmp)
            sibling_pending = run_path.with_suffix(run_path.suffix + ".pending")
            scans = []

            with self.assertRaisesRegex(
                ValueError, "artifact destination must be a file"
            ):
                workspace.promote_artifact(run_path, ".", "content", scans.append)

            self.assertEqual([], scans)
            self.assertFalse(sibling_pending.exists())

    def test_promote_artifact_rejects_directory_destination(self):
        with tempfile.TemporaryDirectory() as tmp:
            run_path = Path(tmp)
            directory = run_path / "artifacts"
            directory.mkdir()
            scans = []

            with self.assertRaisesRegex(
                ValueError, "artifact destination must be a file"
            ):
                workspace.promote_artifact(
                    run_path, "artifacts", "content", scans.append
                )

            self.assertEqual([], scans)
            self.assertTrue(directory.is_dir())
            self.assertFalse((run_path / "artifacts.pending").exists())

    def test_promote_artifact_does_not_follow_preexisting_pending_symlink(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            run_path = root / "run"
            run_path.mkdir()
            destination = run_path / "result.md"
            pending = run_path / "result.md.pending"
            outside = root / "outside.md"
            destination.write_text("approved content", encoding="utf-8")
            outside.write_text("outside content", encoding="utf-8")
            pending.symlink_to(outside)
            scans = []

            with self.assertRaises(FileExistsError):
                workspace.promote_artifact(
                    run_path, "result.md", "new content", scans.append
                )

            self.assertEqual([], scans)
            self.assertTrue(pending.is_symlink())
            self.assertEqual("outside content", outside.read_text(encoding="utf-8"))
            self.assertEqual(
                "approved content", destination.read_text(encoding="utf-8")
            )

    def test_promote_artifact_preserves_preexisting_pending_regular_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            run_path = Path(tmp)
            destination = run_path / "result.md"
            pending = run_path / "result.md.pending"
            destination.write_text("approved content", encoding="utf-8")
            pending.write_text("attacker content", encoding="utf-8")
            scans = []

            with self.assertRaises(FileExistsError):
                workspace.promote_artifact(
                    run_path, "result.md", "new content", scans.append
                )

            self.assertEqual([], scans)
            self.assertEqual("attacker content", pending.read_text(encoding="utf-8"))
            self.assertEqual(
                "approved content", destination.read_text(encoding="utf-8")
            )

    def test_promote_artifact_cleans_pending_after_write_exception(self):
        with tempfile.TemporaryDirectory() as tmp:
            run_path = Path(tmp)
            destination = run_path / "result.md"
            pending = run_path / "result.md.pending"
            destination.write_text("approved content", encoding="utf-8")
            scans = []

            with self.assertRaises(TypeError):
                workspace.promote_artifact(
                    run_path, "result.md", b"not text", scans.append
                )

            self.assertEqual([], scans)
            self.assertFalse(pending.exists())
            self.assertEqual(
                "approved content", destination.read_text(encoding="utf-8")
            )

    def test_promote_artifact_cleans_pending_when_privacy_scan_raises(self):
        with tempfile.TemporaryDirectory() as tmp:
            run_path = Path(tmp)
            destination = run_path / "result.md"
            pending = run_path / "result.md.pending"
            destination.write_text("approved content", encoding="utf-8")

            def failing_scan(_):
                raise RuntimeError("privacy scanner unavailable")

            with self.assertRaisesRegex(RuntimeError, "privacy scanner unavailable"):
                workspace.promote_artifact(
                    run_path, "result.md", "new content", failing_scan
                )

            self.assertFalse(pending.exists())
            self.assertEqual(
                "approved content", destination.read_text(encoding="utf-8")
            )

    def test_promote_artifact_cleans_pending_when_atomic_replace_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            run_path = Path(tmp)
            destination = run_path / "result.md"
            pending = run_path / "result.md.pending"
            destination.write_text("approved content", encoding="utf-8")

            with patch.object(Path, "replace", side_effect=OSError("replace failed")):
                with self.assertRaisesRegex(OSError, "replace failed"):
                    workspace.promote_artifact(
                        run_path, "result.md", "new content", lambda _: []
                    )

            self.assertFalse(pending.exists())
            self.assertEqual(
                "approved content", destination.read_text(encoding="utf-8")
            )

    def test_promote_artifact_removes_rejected_pending_file_and_keeps_destination(self):
        with tempfile.TemporaryDirectory() as tmp:
            run_path = Path(tmp)
            destination = run_path / "result.md"
            destination.write_text("approved content", encoding="utf-8")

            with self.assertRaisesRegex(RuntimeError, "private marker found"):
                workspace.promote_artifact(
                    run_path,
                    "result.md",
                    "private content",
                    lambda _: ["private marker found", "another error"],
                )

            self.assertEqual(
                "approved content", destination.read_text(encoding="utf-8")
            )
            self.assertFalse(destination.with_suffix(".md.pending").exists())

    def test_promote_artifact_rejects_escape_before_scanning(self):
        with tempfile.TemporaryDirectory() as tmp:
            calls = []

            with self.assertRaisesRegex(ValueError, "escapes run workspace"):
                workspace.promote_artifact(
                    tmp, "../outside.md", "content", calls.append
                )

            self.assertEqual([], calls)


if __name__ == "__main__":
    unittest.main()
