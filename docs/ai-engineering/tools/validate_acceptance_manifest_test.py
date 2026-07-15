#!/usr/bin/env python3
import copy
import hashlib
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
        "accepted_gap_refs": [],
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
                "contract_status": "confirmed",
                "contract_evidence": [
                    {
                        "type": "json_schema",
                        "path": "contract-evidence/contract.schema.json",
                        "sha256": "0" * 64,
                    }
                ],
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
        "contract-evidence/contract.schema.json",
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
            "contract_status": "confirmed",
            "contract_evidence": [
                {
                    "type": "json_schema",
                    "path": "contract-evidence/contract.schema.json",
                    "sha256": "0" * 64,
                }
            ],
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
        evidence = self.run_path / "contract-evidence/contract.schema.json"
        digest = hashlib.sha256(evidence.read_bytes()).hexdigest()
        self.manifest["routing"]["contract_evidence"][0]["sha256"] = digest
        product = next(
            item for item in self.manifest["stages"] if item["agent"] == "product"
        )
        product["outputs"]["contract_evidence"][0]["sha256"] = digest

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

    def test_mock_contract_passes_local_gates_but_not_production_gate(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["status"] = "passed_with_mock_contract"
        manifest["routing"].update(
            {"contract_status": "mock", "contract_evidence": []}
        )
        product = next(
            item for item in manifest["stages"] if item["agent"] == "product"
        )
        product["outputs"].update(
            {"contract_status": "mock", "contract_evidence": []}
        )
        manifest["accepted_gaps"] = [
            {
                "gap_id": "production-contract-unavailable",
                "gap": "Production contract is unavailable.",
                "rationale": "Mock delivery was approved.",
                "owner": "server-contract",
                "release_impact": "Production readiness is blocked.",
                "approved_at": "2026-07-14T00:00:00+00:00",
            }
        ]
        product["accepted_gaps"] = copy.deepcopy(manifest["accepted_gaps"])

        self.assertEqual([], self.errors(manifest))
        self.assertEqual(
            "passed_with_mock_contract",
            validator.derive_status(manifest, POLICY, run_path=self.run_path),
        )

        execution = manifest["execution"]["runs"]["android"]
        execution.update({"result": "blocked", "thread_id": None})
        self.assert_error("execution result must be completed: android", manifest)

        manifest["status"] = "passed"
        self.assert_error("requires confirmed contract", manifest)

    def test_contract_evidence_hash_must_match_file(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["routing"]["contract_evidence"][0]["sha256"] = "f" * 64
        product = next(
            item for item in manifest["stages"] if item["agent"] == "product"
        )
        product["outputs"]["contract_evidence"][0]["sha256"] = "f" * 64

        self.assert_error("contract evidence hash mismatch", manifest)

    def test_missing_knowledge_is_rejected(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["stages"] = [
            item for item in manifest["stages"] if item["agent"] != "knowledge"
        ]
        self.assert_error("required stage missing: knowledge", manifest)

    def test_standard_profile_does_not_require_split_planning_or_reviewer_stages(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["routing"].update(
            {
                "workflow_profile": "standard",
                "ux_required": False,
                "ux_reason": "no user-visible behavior changes",
                "hld_required": False,
                "hld_rationale": "no cross-component design is required",
                "hld_review": None,
            }
        )
        product = next(
            item for item in manifest["stages"] if item["agent"] == "product"
        )
        product["outputs"].update(
            {
                "workflow_profile": "standard",
                "covered_criteria": ["criterion-1"],
                "hld_required": False,
                "hld_rationale": "no cross-component design is required",
            }
        )
        skipped = {
            "knowledge",
            "architect",
            "ux-design",
            "test-design",
            "ux-acceptance",
            "acceptance-reviewer",
        }
        manifest["stages"] = [
            item for item in manifest["stages"] if item["agent"] not in skipped
        ]
        manifest["execution"]["runs"] = {
            key: value
            for key, value in manifest["execution"]["runs"].items()
            if key not in skipped
        }
        manifest["execution"]["history"] = [
            item
            for item in manifest["execution"]["history"]
            if item["agent"] not in skipped
        ]

        self.assertEqual([], self.errors(manifest))

    def test_direct_profile_uses_platform_validation_without_verifier(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["routing"].update(
            {
                "workflow_profile": "direct",
                "ux_required": False,
                "ux_reason": "no user-visible behavior changes",
                "hld_required": False,
                "hld_rationale": "no cross-component design is required",
                "hld_review": None,
            }
        )
        product = next(
            item for item in manifest["stages"] if item["agent"] == "product"
        )
        product["outputs"].update(
            {
                "workflow_profile": "direct",
                "covered_criteria": ["criterion-1"],
                "hld_required": False,
                "hld_rationale": "no cross-component design is required",
            }
        )
        for platform in ("android", "ios"):
            next(
                item for item in manifest["stages"] if item["agent"] == platform
            )["outputs"]["covered_criteria"] = ["criterion-1"]
        skipped = {
            "knowledge",
            "architect",
            "ux-design",
            "test-design",
            "test-verification",
            "ux-acceptance",
            "acceptance-reviewer",
        }
        manifest["stages"] = [
            item for item in manifest["stages"] if item["agent"] not in skipped
        ]
        manifest["execution"]["runs"] = {
            key: value
            for key, value in manifest["execution"]["runs"].items()
            if key not in skipped
        }
        manifest["execution"]["history"] = [
            item
            for item in manifest["execution"]["history"]
            if item["agent"] not in skipped
        ]

        self.assertEqual([], self.errors(manifest))

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
                "gap_id": "manual-evidence-missing",
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

    def test_blocked_manifest_still_checks_artifact_privacy_and_paths(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["status"] = "blocked"
        marker = "raw_" + "jira_body:"
        (self.run_path / "requirement-brief.md").write_text(
            marker + " private text\n", encoding="utf-8"
        )
        manifest["artifacts"].append("../outside.md")

        self.assert_error("private source marker found", manifest)
        self.assert_error("artifact path escapes run workspace", manifest)

    def test_failed_manifest_still_checks_existing_execution_provenance(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["status"] = "failed"
        manifest["execution"]["runs"]["android"]["attempt"] = 2
        manifest["execution"]["runs"]["ios"]["output"] = "../outside.json"

        self.assert_error("execution attempt mismatch: android", manifest)
        self.assert_error("execution output path escapes run workspace: ios", manifest)

    def test_blocked_manifest_checks_history_and_extra_run_provenance(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["status"] = "blocked"
        manifest["execution"]["history"][0] = {
            **manifest["execution"]["history"][0],
            "output": "../outside.json",
        }
        manifest["execution"]["runs"]["stale-agent"] = {
            "agent": "different-agent",
            "attempt": 0,
            "thread_id": "stale-thread",
            "sandbox": "workspace-write",
            "output": "../stale.json",
            "result": "completed",
        }

        self.assert_error("execution history output path escapes run workspace", manifest)
        self.assert_error("execution agent mismatch: stale-agent", manifest)
        self.assert_error("execution attempt is invalid: stale-agent", manifest)
        self.assert_error("execution output path escapes run workspace: stale-agent", manifest)

    def test_product_source_evidence_must_cover_declared_inputs(self):
        manifest = copy.deepcopy(self.manifest)
        product = next(
            item for item in manifest["stages"] if item["agent"] == "product"
        )
        product["source_refs"] = ["product:OTHER"]
        self.assert_error("Product source evidence does not match declared inputs", manifest)

    def test_non_product_stage_cannot_approve_a_gap(self):
        manifest = copy.deepcopy(self.manifest)
        android = next(
            item for item in manifest["stages"] if item["agent"] == "android"
        )
        android["gaps"] = ["physical device evidence missing"]
        android["accepted_gaps"] = [
            {
                "gap_id": "different-gap",
                "gap": "different gap",
                "rationale": "approved exception",
                "owner": "release-owner",
                "release_impact": "limited coverage",
                "approved_at": "2026-07-10T00:00:00+00:00",
            }
        ]
        manifest["accepted_gaps"] = list(android["accepted_gaps"])

        self.assert_error("only Product may approve accepted gaps: android", manifest)
        self.assert_error("manifest accepted_gaps must come from Product", manifest)
        self.assert_error("unaccepted gap remains: physical device evidence missing", manifest)

    def test_downstream_gap_reference_must_exist_in_product_approvals(self):
        manifest = copy.deepcopy(self.manifest)
        android = next(
            item for item in manifest["stages"] if item["agent"] == "android"
        )
        android["accepted_gap_refs"] = ["unknown-gap"]

        self.assert_error(
            "accepted gap reference was not approved by Product: android: unknown-gap",
            manifest,
        )

    def test_duplicate_and_conflicting_gap_ids_are_rejected(self):
        manifest = copy.deepcopy(self.manifest)
        first = {
            "gap_id": "server-contract",
            "gap": "Server contract is unavailable.",
            "rationale": "Mock delivery is approved.",
            "owner": "server",
            "release_impact": "Mock-only acceptance.",
            "approved_at": "2026-07-10T00:00:00+00:00",
        }
        duplicate = copy.deepcopy(first)
        conflict = {**first, "owner": "client"}
        manifest["accepted_gaps"] = [first, duplicate, conflict]
        product = next(
            item for item in manifest["stages"] if item["agent"] == "product"
        )
        product["accepted_gaps"] = copy.deepcopy(manifest["accepted_gaps"])

        self.assert_error("duplicate accepted gap ID: server-contract", manifest)
        self.assert_error(
            "accepted gap approval conflicts for ID: server-contract", manifest
        )


if __name__ == "__main__":
    unittest.main()
