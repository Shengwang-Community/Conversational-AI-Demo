#!/usr/bin/env python3
import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).parent
ROOT = TOOLS_DIR.parents[2]


def load_module(name, filename):
    path = TOOLS_DIR / filename
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


validator = load_module("acceptance_validator", "validate_acceptance_manifest.py")
POLICY = json.loads(
    (ROOT / ".agents/skills/release-iteration/references/workflow-policy.json").read_text(
        encoding="utf-8"
    )
)


def stage(agent, outputs=None, validation=None):
    return {
        "agent": agent,
        "phase": "delivery",
        "attempt": 1,
        "status": "passed",
        "summary": f"{agent} passed",
        "source_refs": ["product:REQ-1"] if agent == "product" else [],
        "outputs": outputs or {"result": "passed"},
        "artifacts": [],
        "findings": [],
        "gaps": [],
        "accepted_gaps": [],
        "validation": validation or [],
    }


def passing_manifest():
    stages = [
        stage(
            "product",
            {
                "ux_required": True,
                "ux_reason": "user-visible change",
                "platforms": ["android", "ios"],
                "acceptance_criteria": ["criterion-1"],
            },
        ),
        stage("knowledge"),
        stage(
            "architect",
            {
                "hld_required": True,
                "hld_rationale": "cross-platform change",
                "hld_review": {
                    "status": "approved",
                    "reviewed_by": "architecture-reviewer",
                    "reviewed_at": "2026-07-10T00:00:00+00:00",
                },
            },
        ),
        stage("ux-design"),
        stage("test-design", {"covered_criteria": ["criterion-1"]}),
        stage(
            "android",
            validation=[
                {
                    "command": "android test",
                    "result": "passed",
                    "evidence": "android passed",
                }
            ],
        ),
        stage(
            "ios",
            validation=[
                {
                    "command": "ios test",
                    "result": "passed",
                    "evidence": "ios passed",
                }
            ],
        ),
        stage(
            "test-verification",
            {
                "verified_platforms": ["android", "ios"],
                "covered_criteria": ["criterion-1"],
            },
            [
                {
                    "command": "verify platform evidence",
                    "result": "passed",
                    "evidence": "both platforms independently verified",
                }
            ],
        ),
        stage("ux-acceptance"),
        stage("acceptance-reviewer"),
    ]
    artifacts = [
        "requirement-brief.md",
        "repo-context.md",
        "architecture-decision.json",
        "hld.md",
        "ux-spec.json",
        "test-matrix.json",
        "android-result.json",
        "ios-result.json",
        "test-verification.json",
        "ux-acceptance.json",
        "acceptance-review.json",
    ]
    runs = {}
    history = []
    for index, item in enumerate(stages, start=1):
        record = {
            "agent": item["agent"],
            "attempt": item["attempt"],
            "thread_id": f"thread-{index}-{item['agent']}",
            "model": "test-model",
            "reasoning_effort": "high",
            "sandbox": (
                "workspace-write"
                if item["agent"] in {"android", "ios", "test-verification"}
                else "read-only"
            ),
            "working_directory": (
                item["agent"].capitalize()
                if item["agent"] in {"android", "ios"}
                else "."
            ),
            "output": f"attempts/01/role-results/{item['agent']}.json",
            "result": "completed",
        }
        runs[item["agent"]] = record
        history.append(record)
    validation = [
        {"agent": item["agent"], **entry}
        for item in stages
        for entry in item["validation"]
    ]
    return {
        "schema_version": 1,
        "run_id": "run-1",
        "status": "passed",
        "input": {
            "goal": "Deliver behavior",
            "source_refs": ["product:REQ-1"],
            "platforms": ["android", "ios"],
            "implementation_authorized": True,
        },
        "platforms": ["android", "ios"],
        "sources": [
            {
                "ref": "product:REQ-1",
                "status": "read",
                "content_policy": "reference-only",
            }
        ],
        "routing": {
            "platforms": ["android", "ios"],
            "ux_required": True,
            "ux_reason": "user-visible change",
            "hld_required": True,
            "hld_rationale": "cross-platform change",
            "hld_review": {
                "status": "approved",
                "reviewed_by": "architecture-reviewer",
                "reviewed_at": "2026-07-10T00:00:00+00:00",
            },
        },
        "stages": stages,
        "attempts": {item["agent"]: 1 for item in stages},
        "execution": {"surface": "codex", "runs": runs, "history": history},
        "artifacts": artifacts,
        "validation": validation,
        "accepted_gaps": [],
        "private_content_check": {"contains_private_source_bodies": False},
    }


class AcceptanceManifestTest(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.run_path = Path(self.tempdir.name)
        self.manifest = passing_manifest()
        for artifact in self.manifest["artifacts"]:
            path = self.run_path / artifact
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"safe evidence for {artifact}\n", encoding="utf-8")

    def tearDown(self):
        self.tempdir.cleanup()

    def errors(self, manifest=None):
        return validator.validate(
            manifest or self.manifest, POLICY, run_path=self.run_path
        )

    def assert_error(self, fragment, manifest=None):
        self.assertTrue(
            any(fragment in error for error in self.errors(manifest)),
            self.errors(manifest),
        )

    def test_complete_manifest_passes(self):
        self.assertEqual([], self.errors())
        self.assertEqual(
            "passed",
            validator.derive_status(self.manifest, POLICY, run_path=self.run_path),
        )

    def test_missing_knowledge_is_rejected(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["stages"] = [
            item for item in manifest["stages"] if item["agent"] != "knowledge"
        ]
        self.assert_error("required stage missing: knowledge", manifest)

    def test_architect_cannot_be_skipped(self):
        manifest = copy.deepcopy(self.manifest)
        next(item for item in manifest["stages"] if item["agent"] == "architect")[
            "status"
        ] = "not_required"
        self.assert_error("required stage must pass: architect", manifest)

    def test_required_hld_must_exist_and_be_reviewed(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["artifacts"].remove("hld.md")
        manifest["routing"]["hld_review"] = None
        self.assert_error("required HLD artifact is missing", manifest)
        self.assert_error("required HLD review is incomplete", manifest)

    def test_ux_requirement_needs_ux_acceptance(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["stages"] = [
            item
            for item in manifest["stages"]
            if item["agent"] != "ux-acceptance"
        ]
        self.assert_error("required stage missing: ux-acceptance", manifest)

    def test_non_ux_run_needs_not_required_reason(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["routing"]["ux_required"] = False
        manifest["routing"]["ux_reason"] = ""
        for name in ("ux-design", "ux-acceptance"):
            item = next(stage for stage in manifest["stages"] if stage["agent"] == name)
            item["status"] = "not_required"
            item["summary"] = ""
        self.assert_error("non-UX routing reason is required", manifest)

    def test_acceptance_criteria_must_reach_test_matrix(self):
        manifest = copy.deepcopy(self.manifest)
        next(
            item for item in manifest["stages"] if item["agent"] == "test-design"
        )["outputs"]["covered_criteria"] = []
        self.assert_error("Test Matrix does not cover criterion: criterion-1", manifest)

    def test_platform_self_attestation_needs_independent_verification(self):
        manifest = copy.deepcopy(self.manifest)
        verification = next(
            item
            for item in manifest["stages"]
            if item["agent"] == "test-verification"
        )
        verification["outputs"]["verified_platforms"] = ["android"]
        self.assert_error("platform lacks Test Verification evidence: ios", manifest)

    def test_failed_mandatory_validation_is_rejected(self):
        manifest = copy.deepcopy(self.manifest)
        android = next(
            item for item in manifest["stages"] if item["agent"] == "android"
        )
        android["validation"][0]["result"] = "failed"
        self.assert_error("mandatory validation did not pass: android", manifest)

    def test_duplicate_thread_id_is_rejected(self):
        manifest = copy.deepcopy(self.manifest)
        history = manifest["execution"]["history"]
        history[1]["thread_id"] = history[0]["thread_id"]
        self.assert_error("execution thread IDs must be unique", manifest)

    def test_reviewer_must_be_read_only(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["execution"]["runs"]["acceptance-reviewer"][
            "sandbox"
        ] = "workspace-write"
        self.assert_error("acceptance-reviewer must be read-only", manifest)

    def test_role_output_and_provenance_must_match(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["execution"]["runs"]["android"]["attempt"] = 2
        self.assert_error("execution attempt mismatch: android", manifest)

    def test_accepted_gap_requires_all_approval_fields(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["accepted_gaps"] = [
            {
                "gap": "manual evidence missing",
                "rationale": "external device unavailable",
                "release_impact": "limited device coverage",
                "approved_at": "2026-07-10T00:00:00+00:00",
            }
        ]
        self.assert_error("accepted gap field is required: owner", manifest)

    def test_artifact_path_cannot_escape_run_workspace(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["artifacts"].append("../outside.md")
        self.assert_error("artifact path escapes run workspace", manifest)

    def test_private_content_in_artifact_is_rejected(self):
        marker = "raw_" + "jira_body:"
        (self.run_path / "requirement-brief.md").write_text(
            marker + " private text\n", encoding="utf-8"
        )
        self.assert_error("private source marker found", self.manifest)

    def test_product_source_evidence_must_cover_declared_inputs(self):
        manifest = copy.deepcopy(self.manifest)
        product = next(
            item for item in manifest["stages"] if item["agent"] == "product"
        )
        product["source_refs"] = ["product:OTHER"]
        self.assert_error("Product source evidence does not match declared inputs", manifest)

    def test_accepted_gap_must_match_the_actual_stage_gap(self):
        manifest = copy.deepcopy(self.manifest)
        android = next(
            item for item in manifest["stages"] if item["agent"] == "android"
        )
        android["gaps"] = ["physical device evidence missing"]
        android["accepted_gaps"] = [
            {
                "gap": "different gap",
                "rationale": "approved exception",
                "owner": "release-owner",
                "release_impact": "limited coverage",
                "approved_at": "2026-07-10T00:00:00+00:00",
            }
        ]
        manifest["accepted_gaps"] = list(android["accepted_gaps"])

        self.assert_error("unaccepted gap remains: physical device evidence missing", manifest)


if __name__ == "__main__":
    unittest.main()
