#!/usr/bin/env python3
import importlib.util
import json
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("workflow_policy.py")
SPEC = importlib.util.spec_from_file_location("workflow_policy", MODULE_PATH)
policy_module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(policy_module)

TEMPLATE_ROOT = policy_module.ROOT / ".agents/skills/release-iteration/templates"


def load_schema(name):
    with (TEMPLATE_ROOT / name).open("r", encoding="utf-8") as handle:
        return json.load(handle)


class WorkflowPolicyTest(unittest.TestCase):
    def test_complete_dag_contains_all_product_stages(self):
        policy = policy_module.load_policy()
        nodes = policy_module.expand_dag(
            policy, ["android", "ios", "web"], ux_required=True
        )
        self.assertEqual(
            [
                "product",
                "knowledge",
                "architect",
                "ux-design",
                "test-design",
                "android",
                "ios",
                "web",
                "test-verification",
                "ux-acceptance",
                "acceptance-reviewer",
            ],
            [node["id"] for node in nodes],
        )

    def test_non_ux_run_marks_ux_nodes_not_required(self):
        policy = policy_module.load_policy()
        nodes = policy_module.expand_dag(policy, ["android"], ux_required=False)
        by_id = {node["id"]: node for node in nodes}
        self.assertEqual("not_required", by_id["ux-design"]["initial_status"])
        self.assertEqual("not_required", by_id["ux-acceptance"]["initial_status"])

    def test_selected_platforms_expand_between_design_and_verification(self):
        policy = policy_module.load_policy()
        nodes = policy_module.expand_dag(policy, ["ios"], ux_required=False)
        by_id = {node["id"]: node for node in nodes}
        self.assertEqual(["test-design"], by_id["ios"]["depends_on"])
        self.assertEqual("ios-result.json", by_id["ios"]["artifact"])
        self.assertEqual(["ios"], by_id["test-verification"]["depends_on"])

    def test_standard_profile_skips_experts_but_keeps_independent_verification(self):
        policy = policy_module.load_policy()
        nodes = policy_module.expand_dag(
            policy,
            ["android"],
            ux_required=False,
            workflow_profile="standard",
        )
        by_id = {node["id"]: node for node in nodes}

        self.assertEqual(["product"], by_id["android"]["depends_on"])
        self.assertEqual("pending", by_id["test-verification"]["initial_status"])
        self.assertEqual("not_required", by_id["knowledge"]["initial_status"])
        self.assertEqual(
            "not_required", by_id["acceptance-reviewer"]["initial_status"]
        )

    def test_direct_profile_stops_after_platform_validation(self):
        policy = policy_module.load_policy()
        nodes = policy_module.expand_dag(
            policy,
            ["android"],
            ux_required=False,
            workflow_profile="direct",
        )
        by_id = {node["id"]: node for node in nodes}

        self.assertEqual(["product"], by_id["android"]["depends_on"])
        self.assertEqual(
            "not_required", by_id["test-verification"]["initial_status"]
        )

    def test_web_platform_uses_voice_agent_working_directory(self):
        policy = policy_module.load_policy()
        nodes = policy_module.expand_dag(policy, ["web"], ux_required=False)
        by_id = {node["id"]: node for node in nodes}

        self.assertEqual("Web/Scenes/VoiceAgent", by_id["web"]["working_directory"])
        self.assertEqual([], by_id["web"]["workflow_entrypoints"])
        self.assertEqual(["web"], by_id["test-verification"]["depends_on"])

    def test_model_and_sandbox_policy_are_applied(self):
        policy = policy_module.load_policy()
        nodes = policy_module.expand_dag(
            policy,
            ["android"],
            ux_required=True,
            environ={
                "AI_ENGINEERING_PRIMARY_MODEL": "primary-override",
                "AI_ENGINEERING_SUPPORT_MODEL": "support-override",
                "AI_ENGINEERING_REVIEW_MODEL": "review-override",
            },
        )
        by_id = {node["id"]: node for node in nodes}
        self.assertEqual(
            ("support-override", "read-only"),
            (by_id["product"]["model"], by_id["product"]["sandbox"]),
        )
        self.assertEqual(
            ("primary-override", "workspace-write"),
            (by_id["android"]["model"], by_id["android"]["sandbox"]),
        )
        self.assertEqual(
            ("review-override", "workspace-write"),
            (by_id["test-verification"]["model"], by_id["test-verification"]["sandbox"]),
        )
        self.assertEqual(
            ("review-override", "read-only"),
            (by_id["acceptance-reviewer"]["model"], by_id["acceptance-reviewer"]["sandbox"]),
        )

    def test_policy_uses_three_attempts(self):
        self.assertEqual(3, policy_module.load_policy()["max_attempts"])

    def test_policy_defaults_to_standard_profile_and_medium_effort(self):
        policy = policy_module.load_policy()

        self.assertEqual("standard", policy["default_profile"])
        self.assertEqual("medium", policy["roles"]["product"]["reasoning_effort"])
        self.assertEqual("medium", policy["platforms"]["android"]["reasoning_effort"])
        self.assertEqual("high", policy["roles"]["architect"]["reasoning_effort"])

    def test_policy_requires_native_execution_mode(self):
        policy = policy_module.load_policy()
        self.assertEqual("native", policy["execution_mode"])

        invalid = dict(policy)
        invalid["execution_mode"] = "nested-cli"
        with self.assertRaisesRegex(ValueError, "execution mode must be native"):
            policy_module.validate_policy(invalid)

    def test_findings_route_through_policy(self):
        policy = policy_module.load_policy()
        findings = [
            {"category": "implementation", "owner": "android"},
            {"category": "cross_platform_parity", "owner": "platforms"},
            {"category": "architecture", "owner": "architect"},
        ]

        self.assertEqual(
            ["android", "ios", "web", "architect"],
            policy_module.targets_for_findings(
                policy, findings, ["android", "ios", "web"]
            ),
        )

    def test_environment_finding_blocks_repair(self):
        policy = policy_module.load_policy()

        self.assertEqual(
            ["blocked"],
            policy_module.targets_for_findings(
                policy,
                [{"category": "environment", "owner": "test-verification"}],
                ["android"],
            ),
        )

    def test_platform_entrypoints_exist(self):
        policy = policy_module.load_policy()
        for definition in policy["platforms"].values():
            self.assertTrue((policy_module.ROOT / definition["working_directory"]).is_dir())
            for entrypoint in definition["workflow_entrypoints"]:
                self.assertTrue((policy_module.ROOT / entrypoint).is_file())

    def test_standard_profile_routes_split_planning_findings_back_to_product(self):
        policy = policy_module.load_policy()
        findings = [
            {
                "category": "architecture",
                "owner": "product",
            },
            {
                "category": "test_coverage",
                "owner": "product",
            },
        ]

        self.assertEqual(
            ["product"],
            policy_module.targets_for_findings(
                policy,
                findings,
                ["android"],
                workflow_profile="standard",
            ),
        )

    def test_role_result_schema_requires_complete_stage_evidence(self):
        schema = load_schema("role-result.schema.json")
        self.assertEqual(
            [
                "agent",
                "phase",
                "attempt",
                "status",
                "summary",
                "source_refs",
                "outputs",
                "artifacts",
                "findings",
                "gaps",
                "accepted_gaps",
                "accepted_gap_refs",
                "validation",
            ],
            schema["required"],
        )
        self.assertEqual(
            ["passed", "failed", "blocked", "not_required"],
            schema["properties"]["status"]["enum"],
        )
        expected_items = {
            "artifacts": ["path", "sha256"],
            "findings": ["id", "category", "owner", "severity", "description"],
            "accepted_gaps": [
                "gap_id",
                "gap",
                "rationale",
                "owner",
                "release_impact",
                "approved_at",
            ],
            "validation": ["command", "result", "evidence"],
        }
        for property_name, required in expected_items.items():
            self.assertEqual(
                required,
                schema["properties"][property_name]["items"]["required"],
            )
        self.assert_accepted_gap_contract(
            schema["properties"]["accepted_gaps"]["items"]
        )

    def test_acceptance_manifest_schema_requires_finalizer_inputs(self):
        schema = load_schema("acceptance-manifest.schema.json")
        self.assertEqual(
            [
                "schema_version",
                "run_id",
                "status",
                "platforms",
                "routing",
                "stages",
                "attempts",
                "execution",
                "accepted_gaps",
                "private_content_check",
            ],
            schema["required"],
        )
        self.assert_accepted_gap_contract(
            schema["properties"]["accepted_gaps"]["items"]
        )

    def assert_accepted_gap_contract(self, item_schema):
        fields = [
            "gap_id",
            "gap",
            "rationale",
            "owner",
            "release_impact",
            "approved_at",
        ]
        self.assertEqual(fields, item_schema["required"])
        self.assertEqual(fields, list(item_schema["properties"]))
        self.assertFalse(item_schema["additionalProperties"])
        for field in fields:
            self.assertEqual(1, item_schema["properties"][field]["minLength"])
        self.assertEqual(
            "date-time", item_schema["properties"]["approved_at"]["format"]
        )


if __name__ == "__main__":
    unittest.main()
