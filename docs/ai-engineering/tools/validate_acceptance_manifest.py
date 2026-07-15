#!/usr/bin/env python3
import argparse
import copy
import hashlib
import importlib.util
import json
import sys
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
POLICY_PATH = ROOT / ".agents/skills/release-iteration/references/workflow-policy.json"
PRIVACY_PATH = Path(__file__).with_name("validate_artifact_privacy.py")
PRIVACY_SPEC = importlib.util.spec_from_file_location(
    "artifact_privacy", PRIVACY_PATH
)
privacy = importlib.util.module_from_spec(PRIVACY_SPEC)
PRIVACY_SPEC.loader.exec_module(privacy)


TOP_LEVEL_FIELDS = {
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
}


def load_json(path):
    with Path(path).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def load_policy(path=POLICY_PATH):
    return load_json(path)


def latest_attempt_results(manifest):
    latest = {}
    for result in manifest.get("stages", []):
        if not isinstance(result, dict) or not isinstance(result.get("agent"), str):
            continue
        attempt = result.get("attempt")
        if not isinstance(attempt, int):
            continue
        current = latest.get(result["agent"])
        if current is None or attempt >= current.get("attempt", -1):
            latest[result["agent"]] = result
    return latest


def required_nodes(manifest, policy):
    platforms = manifest.get("platforms", [])
    routing = manifest.get("routing", {})
    profile = routing.get("workflow_profile", "full")
    if profile == "direct":
        return ["product", *platforms]
    if profile == "standard":
        return ["product", *platforms, "test-verification"]
    nodes = ["product", "knowledge", "architect"]
    if routing.get("ux_required") is True:
        nodes.append("ux-design")
    nodes.append("test-design")
    nodes.extend(platforms)
    nodes.append("test-verification")
    if routing.get("ux_required") is True:
        nodes.append("ux-acceptance")
    nodes.append("acceptance-reviewer")
    return nodes


def validate_routing(manifest, policy):
    errors = []
    routing = manifest.get("routing")
    if not isinstance(routing, dict):
        return ["routing must be an object"]
    platforms = manifest.get("platforms")
    if not isinstance(platforms, list) or not platforms:
        errors.append("platforms must be a non-empty list")
        platforms = []
    elif len(platforms) != len(set(platforms)):
        errors.append("duplicate platforms are not allowed")
    unknown = sorted(set(platforms) - set(policy.get("platforms", {})))
    if unknown:
        errors.append(f"unknown platform: {', '.join(unknown)}")
    if routing.get("platforms") != platforms:
        errors.append("routing platforms must match manifest platforms")
    workflow_profile = routing.get("workflow_profile", "full")
    if workflow_profile not in {"direct", "standard", "full"}:
        errors.append(
            "routing.workflow_profile must be direct, standard, or full"
        )
    ux_required = routing.get("ux_required")
    if not isinstance(ux_required, bool):
        errors.append("routing.ux_required must be boolean")
    elif not ux_required and not str(routing.get("ux_reason") or "").strip():
        errors.append("non-UX routing reason is required")
    hld_required = routing.get("hld_required")
    if not isinstance(hld_required, bool):
        errors.append("routing.hld_required must be boolean")
    if not str(routing.get("hld_rationale") or "").strip():
        errors.append("HLD routing rationale is required")
    if workflow_profile in {"direct", "standard"} and (
        ux_required or hld_required
    ):
        errors.append(f"{workflow_profile} profile cannot require UX or HLD")
    return errors


def validate_hld(manifest):
    routing = manifest.get("routing", {})
    if routing.get("hld_required") is not True:
        return []
    errors = []
    if "hld.md" not in manifest.get("artifacts", []):
        errors.append("required HLD artifact is missing")
    review = routing.get("hld_review")
    required = {"status", "reviewed_by", "reviewed_at"}
    if not isinstance(review, dict) or required - set(review):
        errors.append("required HLD review is incomplete")
    elif review.get("status") != "approved":
        errors.append("required HLD review is not approved")
    return errors


def validate_test_coverage(manifest):
    results = latest_attempt_results(manifest)
    product = results.get("product", {}).get("outputs", {})
    test_design = results.get("test-design", {}).get("outputs", {})
    verification = results.get("test-verification", {}).get("outputs", {})
    criteria = product.get("acceptance_criteria", [])
    if not isinstance(criteria, list) or not criteria:
        return ["Product acceptance criteria are required"]
    errors = []
    profile = manifest.get("routing", {}).get("workflow_profile", "full")
    design_coverage = (
        product.get("covered_criteria", [])
        if profile in {"direct", "standard"}
        else test_design.get("covered_criteria", [])
    )
    verification_coverage = verification.get("covered_criteria", [])
    design_owner = (
        "Product planning" if profile in {"direct", "standard"} else "Test Matrix"
    )
    for criterion in criteria:
        if criterion not in design_coverage:
            errors.append(f"{design_owner} does not cover criterion: {criterion}")
        if profile == "direct":
            for platform in manifest.get("platforms", []):
                platform_coverage = results.get(platform, {}).get("outputs", {}).get(
                    "covered_criteria", []
                )
                if criterion not in platform_coverage:
                    errors.append(
                        f"platform does not cover criterion: {platform}: {criterion}"
                    )
        elif criterion not in verification_coverage:
            errors.append(
                f"Test Verification does not cover criterion: {criterion}"
            )
    if profile == "direct":
        return errors
    verified_platforms = verification.get("verified_platforms", [])
    for platform in manifest.get("platforms", []):
        if platform not in verified_platforms:
            errors.append(
                f"platform lacks Test Verification evidence: {platform}"
            )
    return errors


def validate_ux(manifest):
    routing = manifest.get("routing", {})
    if routing.get("workflow_profile") in {"direct", "standard"}:
        return []
    results = latest_attempt_results(manifest)
    errors = []
    if routing.get("ux_required") is True:
        for agent in ("ux-design", "ux-acceptance"):
            if results.get(agent, {}).get("status") != "passed":
                errors.append(f"required UX stage must pass: {agent}")
    elif routing.get("ux_required") is False:
        reason = str(routing.get("ux_reason") or "").strip()
        if not reason:
            errors.append("non-UX routing reason is required")
        for agent in ("ux-design", "ux-acceptance"):
            result = results.get(agent)
            if not result or result.get("status") != "not_required":
                errors.append(f"non-UX stage must be not_required: {agent}")
            elif not str(result.get("summary") or "").strip():
                errors.append(f"non-UX stage reason is required: {agent}")
    return errors


def _resolve_under(run_path, relative_path):
    base = Path(run_path).resolve()
    path = Path(relative_path)
    if path.is_absolute():
        raise ValueError("artifact path escapes run workspace")
    resolved = (base / path).resolve()
    if resolved != base and base not in resolved.parents:
        raise ValueError("artifact path escapes run workspace")
    return resolved


def validate_execution(manifest, run_path):
    errors = []
    execution = manifest.get("execution")
    if not isinstance(execution, dict) or execution.get("surface") != "codex":
        return ["execution.surface must be codex"]
    runs = execution.get("runs")
    history = execution.get("history")
    if not isinstance(runs, dict):
        return ["execution.runs must be an object"]
    if not isinstance(history, list):
        return ["execution.history must be a list"]
    results = latest_attempt_results(manifest)
    thread_ids = []

    def validate_record(record, label, expected_agent=None, history_record=False):
        record_errors = []
        prefix = "execution history" if history_record else "execution"
        if not isinstance(record, dict):
            return [f"{prefix} record must be an object: {label}"]
        agent = record.get("agent")
        if not isinstance(agent, str) or not agent:
            record_errors.append(f"{prefix} agent is invalid: {label}")
        if expected_agent is not None and agent != expected_agent:
            record_errors.append(f"execution agent mismatch: {expected_agent}")
        attempt = record.get("attempt")
        if not isinstance(attempt, int) or attempt < 1:
            record_errors.append(f"{prefix} attempt is invalid: {label}")
        result = record.get("result")
        if result not in {"completed", "blocked"}:
            record_errors.append(f"{prefix} result is invalid: {label}")
        thread_id = record.get("thread_id")
        if result == "completed" and (
            not isinstance(thread_id, str) or not thread_id
        ):
            record_errors.append(f"execution thread ID is missing: {label}")
        elif thread_id is not None and not isinstance(thread_id, str):
            record_errors.append(f"{prefix} thread ID is invalid: {label}")
        attestation_status = record.get("attestation_status")
        if attestation_status not in {None, "unavailable", "provided"}:
            record_errors.append(f"{prefix} attestation status is invalid: {label}")
        if attestation_status == "unavailable":
            for field in (
                "requested_model",
                "requested_sandbox",
                "requested_working_directory",
            ):
                if not isinstance(record.get(field), str) or not record[field]:
                    record_errors.append(f"{prefix} {field} is missing: {label}")
            for claimed in ("model", "sandbox", "working_directory"):
                if claimed in record:
                    record_errors.append(
                        f"unattested execution must not claim {claimed}: {label}"
                    )
        sandbox = record.get("sandbox") or record.get("requested_sandbox")
        if agent == "acceptance-reviewer" and sandbox != "read-only":
            record_errors.append("acceptance-reviewer must be read-only")
        output = record.get("output")
        if not isinstance(output, str) or not output:
            record_errors.append(f"{prefix} output is missing: {label}")
        elif run_path is not None:
            try:
                _resolve_under(run_path, output)
            except ValueError:
                if history_record:
                    record_errors.append(
                        "execution history output path escapes run workspace"
                    )
                else:
                    record_errors.append(
                        f"execution output path escapes run workspace: {label}"
                    )
        return record_errors

    for agent, record in runs.items():
        errors.extend(validate_record(record, agent, expected_agent=agent))
    for index, record in enumerate(history):
        label = f"history[{index}]"
        errors.extend(validate_record(record, label, history_record=True))
        if isinstance(record, dict) and isinstance(record.get("thread_id"), str):
            thread_ids.append(record["thread_id"])

    for agent in required_nodes(manifest, {}):
        result = results.get(agent)
        if not result or result.get("status") == "not_required":
            continue
        record = runs.get(agent)
        if not isinstance(record, dict):
            errors.append(f"execution record missing: {agent}")
            continue
        if record.get("agent") != agent:
            errors.append(f"execution agent mismatch: {agent}")
        if record.get("attempt") != result.get("attempt"):
            errors.append(f"execution attempt mismatch: {agent}")
        if manifest.get("status") in {
            "passed",
            "passed_with_mock_contract",
        } and record.get("result") != "completed":
            errors.append(f"execution result must be completed: {agent}")
    if len(thread_ids) != len(set(thread_ids)):
        errors.append("execution thread IDs must be unique")
    return errors


def validate_accepted_gaps(manifest):
    errors = []
    gaps = manifest.get("accepted_gaps")
    if not isinstance(gaps, list):
        return ["accepted_gaps must be a list"]
    required = [
        "gap_id",
        "gap",
        "rationale",
        "owner",
        "release_impact",
        "approved_at",
    ]
    by_id = {}
    by_description = {}
    for gap in gaps:
        if not isinstance(gap, dict):
            errors.append("accepted gap must be an object")
            continue
        for field in required:
            if not str(gap.get(field) or "").strip():
                errors.append(f"accepted gap field is required: {field}")
        approved_at = gap.get("approved_at")
        if approved_at:
            try:
                datetime.fromisoformat(approved_at.replace("Z", "+00:00"))
            except (AttributeError, ValueError):
                errors.append("accepted gap approved_at must be ISO-8601")
        gap_id = str(gap.get("gap_id") or "").strip()
        description = str(gap.get("gap") or "").strip()
        approval = (gap.get("owner"), gap.get("release_impact"))
        if gap_id in by_id:
            if approval != by_id[gap_id]:
                errors.append(f"accepted gap approval conflicts for ID: {gap_id}")
            else:
                errors.append(f"duplicate accepted gap ID: {gap_id}")
        elif gap_id:
            by_id[gap_id] = approval
        if description in by_description:
            previous_id, previous_approval = by_description[description]
            if approval != previous_approval:
                errors.append(
                    f"accepted gap approval conflicts for gap: {description}"
                )
            elif gap_id != previous_id:
                errors.append(f"duplicate accepted gap description: {description}")
        elif description:
            by_description[description] = (gap_id, approval)
    return errors


def validate_stage_gap_contract(manifest):
    errors = []
    results = latest_attempt_results(manifest)
    approved = {
        gap.get("gap_id"): gap
        for gap in manifest.get("accepted_gaps", [])
        if isinstance(gap, dict) and gap.get("gap_id")
    }
    product_gaps = results.get("product", {}).get("accepted_gaps", [])
    if product_gaps != manifest.get("accepted_gaps", []):
        errors.append("manifest accepted_gaps must come from Product")
    for agent, result in results.items():
        accepted_gaps = result.get("accepted_gaps", [])
        refs = result.get("accepted_gap_refs", [])
        if agent != "product" and accepted_gaps:
            errors.append(f"only Product may approve accepted gaps: {agent}")
        if agent == "product" and refs:
            errors.append("Product must approve gaps directly, not by reference")
        if not isinstance(refs, list):
            errors.append(f"accepted_gap_refs must be a list: {agent}")
            refs = []
        elif len(refs) != len(set(refs)):
            errors.append(f"accepted_gap_refs must be unique: {agent}")
        for gap_id in refs:
            if gap_id not in approved:
                errors.append(
                    f"accepted gap reference was not approved by Product: {agent}: {gap_id}"
                )
        for gap in result.get("gaps", []):
            errors.append(f"unaccepted gap remains: {gap}")
    return errors


def _validate_artifacts(manifest, run_path):
    if run_path is None:
        return []
    errors = []
    paths = []
    for relative_path in manifest.get("artifacts", []):
        if not isinstance(relative_path, str):
            errors.append("artifact path must be a string")
            continue
        try:
            path = _resolve_under(run_path, relative_path)
        except ValueError as error:
            errors.append(str(error))
            continue
        if not path.is_file():
            errors.append(f"referenced artifact is missing: {relative_path}")
            continue
        paths.append(str(path))
    errors.extend(privacy.scan(paths))
    return errors


def _validate_structure(manifest):
    if not isinstance(manifest, dict):
        return ["manifest must be an object"]
    missing = sorted(TOP_LEVEL_FIELDS - set(manifest))
    errors = [f"manifest field is required: {field}" for field in missing]
    if manifest.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    if manifest.get("status") not in {
        "in_progress",
        "blocked",
        "failed",
        "passed_with_mock_contract",
        "passed",
    }:
        errors.append(
            "status must be in_progress, blocked, failed, "
            "passed_with_mock_contract, or passed"
        )
    if not isinstance(manifest.get("stages"), list):
        errors.append("stages must be a list")
    if not isinstance(manifest.get("attempts"), dict):
        errors.append("attempts must be an object")
    return errors


def validate(manifest, policy, run_path=None):
    errors = _validate_structure(manifest)
    errors.extend(validate_accepted_gaps(manifest))
    errors.extend(validate_stage_gap_contract(manifest))
    private_check = manifest.get("private_content_check", {})
    if private_check.get("contains_private_source_bodies") is not False:
        errors.append("private content check must be false")
    errors.extend(validate_execution(manifest, run_path))
    errors.extend(_validate_artifacts(manifest, run_path))
    if manifest.get("status") not in {"passed", "passed_with_mock_contract"}:
        return errors

    contract_status = manifest.get("routing", {}).get("contract_status")
    contract_evidence = manifest.get("routing", {}).get("contract_evidence", [])
    if manifest.get("status") == "passed" and contract_status != "confirmed":
        errors.append("production-ready passed status requires confirmed contract")
    if (
        manifest.get("status") == "passed_with_mock_contract"
        and contract_status != "mock"
    ):
        errors.append("passed_with_mock_contract requires mock contract_status")
    if contract_status == "mock" and not manifest.get("accepted_gaps"):
        errors.append("mock contract requires an explicitly accepted gap")
    if contract_status == "confirmed" and not contract_evidence:
        errors.append(
            "confirmed contract requires sanitized response, JSON Schema, or OpenAPI evidence"
        )
    allowed_contract_evidence = {"sanitized_response", "json_schema", "openapi"}
    for item in contract_evidence:
        if not isinstance(item, dict) or set(item) != {"type", "path", "sha256"}:
            errors.append("contract evidence requires type, path, and sha256")
            continue
        if item["type"] not in allowed_contract_evidence:
            errors.append(f"unsupported contract evidence type: {item['type']}")
        if item["path"] not in manifest.get("artifacts", []):
            errors.append(f"contract evidence is not indexed: {item['path']}")
        if run_path is not None:
            try:
                evidence_path = _resolve_under(run_path, item["path"])
            except ValueError as error:
                errors.append(str(error))
            else:
                if evidence_path.is_file():
                    actual = hashlib.sha256(evidence_path.read_bytes()).hexdigest()
                    if actual != item["sha256"]:
                        errors.append(f"contract evidence hash mismatch: {item['path']}")

    errors.extend(validate_routing(manifest, policy))
    results = latest_attempt_results(manifest)
    product_contract = results.get("product", {}).get("outputs", {})
    product_profile = product_contract.get("workflow_profile", "full")
    routing_profile = manifest.get("routing", {}).get("workflow_profile", "full")
    if product_profile != routing_profile:
        errors.append("Product workflow_profile does not match routing")
    if product_contract.get("contract_status") != contract_status:
        errors.append("Product contract_status does not match routing")
    if product_contract.get("contract_evidence", []) != contract_evidence:
        errors.append("Product contract_evidence does not match routing")
    for agent in required_nodes(manifest, policy):
        result = results.get(agent)
        if result is None:
            errors.append(f"required stage missing: {agent}")
            continue
        if result.get("status") != "passed":
            errors.append(f"required stage must pass: {agent}")
        if result.get("findings"):
            errors.append(f"open findings remain: {agent}")
    errors.extend(validate_hld(manifest))
    errors.extend(validate_test_coverage(manifest))
    errors.extend(validate_ux(manifest))
    validation_agents = list(manifest.get("platforms", []))
    if routing_profile != "direct":
        validation_agents.append("test-verification")
    for platform in validation_agents:
        result = results.get(platform, {})
        validations = result.get("validation", [])
        if not validations:
            errors.append(f"mandatory validation is missing: {platform}")
        elif any(item.get("result") != "passed" for item in validations):
            errors.append(f"mandatory validation did not pass: {platform}")
    for source in manifest.get("sources", []):
        if source.get("content_policy") != "reference-only":
            errors.append("source content policy must be reference-only")
        if source.get("status") != "read":
            errors.append(f"source was not read: {source.get('ref')}")
    declared_sources = manifest.get("input", {}).get("source_refs", [])
    product_sources = results.get("product", {}).get("source_refs", [])
    manifest_sources = [source.get("ref") for source in manifest.get("sources", [])]
    if set(product_sources) != set(declared_sources):
        errors.append("Product source evidence does not match declared inputs")
    if set(manifest_sources) != set(declared_sources):
        errors.append("manifest sources do not match declared inputs")
    if not manifest.get("input", {}).get("implementation_authorized"):
        errors.append("implementation was not authorized")
    return errors


def derive_status(manifest, policy, run_path=None):
    results = latest_attempt_results(manifest)
    statuses = {agent: result.get("status") for agent, result in results.items()}
    if "blocked" in statuses.values():
        return "blocked"
    failed = [agent for agent, status in statuses.items() if status == "failed"]
    if failed:
        repair_attempt = manifest.get("execution", {}).get("repair_attempt", 1)
        if repair_attempt >= policy.get("max_attempts", 3):
            return "failed"
        return "in_progress"
    required = set(required_nodes(manifest, policy))
    completed = {
        agent
        for agent, status in statuses.items()
        if status in {"passed", "not_required"}
    }
    if not required.issubset(completed):
        return "in_progress"
    candidate = copy.deepcopy(manifest)
    contract_status = manifest.get("routing", {}).get("contract_status")
    candidate["status"] = (
        "passed" if contract_status == "confirmed" else "passed_with_mock_contract"
    )
    return (
        candidate["status"]
        if not validate(candidate, policy, run_path=run_path)
        else "blocked"
    )


def validate_file(path, policy=None):
    manifest_path = Path(path)
    return validate(
        load_json(manifest_path),
        policy or load_policy(),
        run_path=manifest_path.parent,
    )


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest")
    parser.add_argument("--policy", default=str(POLICY_PATH))
    args = parser.parse_args(argv[1:])
    errors = validate_file(args.manifest, policy=load_policy(args.policy))
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("acceptance manifest valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
