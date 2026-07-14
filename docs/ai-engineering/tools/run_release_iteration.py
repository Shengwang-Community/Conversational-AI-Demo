#!/usr/bin/env python3
import argparse
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import sys
from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TOOLS_DIR = Path(__file__).parent
POLICY_PATH = ROOT / ".agents/skills/release-iteration/references/workflow-policy.json"
OUTPUT_SCHEMA = ROOT / ".agents/skills/release-iteration/templates/role-result.schema.json"
RUNS_DIR = ROOT / "docs/ai-engineering/pilot-runs"
STATE_FILE = "run-state.json"
INPUT_FILE = "run-input.json"
MANIFEST_FILE = "acceptance-manifest.json"
NATIVE_RESULT_REQUIRED_FIELDS = {
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
}
NATIVE_RESULT_OPTIONAL_FIELDS = {"files_changed", "repository_fingerprint"}
NATIVE_RESULT_STATUSES = {"passed", "failed", "blocked", "not_required"}
STATE_SCHEMA_VERSION = 3
FINDING_SEVERITIES = {"critical", "high", "medium", "low"}
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
READ_ONLY_NATIVE_AGENTS = {
    "product",
    "knowledge",
    "architect",
    "ux-design",
    "test-design",
    "test-verification",
    "ux-acceptance",
    "acceptance-reviewer",
}
PROFILE_SKIPPED_AGENTS = {
    "direct": {
        "knowledge",
        "architect",
        "ux-design",
        "test-design",
        "test-verification",
        "ux-acceptance",
        "acceptance-reviewer",
    },
    "standard": {
        "knowledge",
        "architect",
        "ux-design",
        "test-design",
        "ux-acceptance",
        "acceptance-reviewer",
    },
    "full": set(),
}

ROLE_CONTRACTS = {
    "product": "Read every declared source and return outputs: workflow_profile, ux_required, ux_reason, platforms, acceptance_criteria, contract_status, and contract_evidence. Use standard by default; use direct only for low-risk, non-UX work with no HLD, security, migration, compatibility, or cross-platform design risk; use full when any of those risks apply. For direct or standard, also return hld_required=false, a short hld_rationale, and covered_criteria. Product alone may approve accepted_gaps; give each approval a stable gap_id.",
    "knowledge": "Ground the requirement in current repository behavior and platform guidance. Return only constraints and unresolved evidence that change implementation or acceptance.",
    "architect": "Decide hld_required with a rationale. If required, produce hld.md and approved hld_review metadata.",
    "ux-design": "Define the user-visible states and UX acceptance criteria needed to implement and verify the requirement.",
    "test-design": "Cover every Product acceptance criterion with a cross-platform test matrix.",
    "test-verification": "Independently verify selected-platform evidence and covered_criteria without changing tracked repository files.",
    "ux-acceptance": "Compare runtime evidence with UX Design and report actionable findings.",
    "acceptance-reviewer": "Independently review the evidence and route actionable findings to policy owners.",
}


def load_module(name, filename):
    path = TOOLS_DIR / filename
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


workflow_policy = load_module("workflow_policy", "workflow_policy.py")
workflow_workspace = load_module("workflow_workspace", "workflow_workspace.py")
sys.modules.setdefault("workflow_workspace", workflow_workspace)
privacy = load_module("artifact_privacy", "validate_artifact_privacy.py")
manifest_validator = load_module(
    "acceptance_validator", "validate_acceptance_manifest.py"
)


def load_policy(path=POLICY_PATH):
    return workflow_policy.load_policy(path)


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_native_result_structure(result):
    if not isinstance(result, dict):
        return ["native result must be an object"]
    errors = []
    missing = NATIVE_RESULT_REQUIRED_FIELDS - set(result)
    extra = set(result) - NATIVE_RESULT_REQUIRED_FIELDS - NATIVE_RESULT_OPTIONAL_FIELDS
    if missing:
        errors.append(f"native result missing fields: {', '.join(sorted(missing))}")
    if extra:
        errors.append(f"native result has unknown fields: {', '.join(sorted(extra))}")
    for field in ("agent", "phase", "summary"):
        if not isinstance(result.get(field), str) or not result.get(field, "").strip():
            errors.append(f"native result {field} must be a non-empty string")
    if not isinstance(result.get("attempt"), int) or result.get("attempt", 0) < 1:
        errors.append("native result attempt must be a positive integer")
    if result.get("status") not in NATIVE_RESULT_STATUSES:
        errors.append("native result status is invalid")
    if not isinstance(result.get("outputs"), dict):
        errors.append("native result outputs must be an object")
    list_fields = (
        "source_refs",
        "artifacts",
        "findings",
        "gaps",
        "accepted_gaps",
        "accepted_gap_refs",
        "validation",
    )
    for field in list_fields:
        if not isinstance(result.get(field), list):
            errors.append(f"native result {field} must be a list")
    if errors:
        return errors
    for artifact in result["artifacts"]:
        if not isinstance(artifact, dict) or set(artifact) != {"path", "sha256"}:
            errors.append("artifact records must contain only path and sha256")
            continue
        if not isinstance(artifact["path"], str) or not artifact["path"].strip():
            errors.append("artifact path must be a non-empty string")
        if not isinstance(artifact["sha256"], str) or not SHA256_PATTERN.fullmatch(
            artifact["sha256"]
        ):
            errors.append(f"artifact sha256 is invalid: {artifact.get('path')}")
    artifact_paths = [
        item.get("path")
        for item in result["artifacts"]
        if isinstance(item, dict) and isinstance(item.get("path"), str)
    ]
    if len(artifact_paths) != len(set(artifact_paths)):
        errors.append("artifact paths must be unique")
    valid_source_refs = [
        item for item in result["source_refs"] if isinstance(item, str)
    ]
    if len(valid_source_refs) != len(result["source_refs"]) or any(
        not item.strip() for item in valid_source_refs
    ):
        errors.append("source_refs must contain non-empty strings")
    if len(valid_source_refs) != len(set(valid_source_refs)):
        errors.append("source_refs must be unique")
    if any(not isinstance(item, str) for item in result["gaps"]):
        errors.append("gaps must contain strings")
    finding_fields = {"id", "category", "owner", "severity", "description"}
    for finding in result["findings"]:
        if not isinstance(finding, dict) or set(finding) != finding_fields:
            errors.append("finding records have invalid fields")
            continue
        if any(
            not isinstance(finding[key], str) or not finding[key].strip()
            for key in finding_fields
        ):
            errors.append("finding fields must be non-empty strings")
        if finding.get("severity") not in FINDING_SEVERITIES:
            errors.append(
                "finding severity must be critical, high, medium, or low; "
                "informational notes belong in outputs or gaps"
            )
    finding_ids = [
        item.get("id")
        for item in result["findings"]
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    ]
    if len(finding_ids) != len(set(finding_ids)):
        errors.append("finding IDs must be unique")
    accepted_fields = {
        "gap_id",
        "gap",
        "rationale",
        "owner",
        "release_impact",
        "approved_at",
    }
    for accepted in result["accepted_gaps"]:
        if not isinstance(accepted, dict) or set(accepted) != accepted_fields:
            errors.append("accepted gap records have invalid fields")
            continue
        if any(
            not isinstance(accepted[key], str) or not accepted[key].strip()
            for key in accepted_fields
        ):
            errors.append("accepted gap fields must be non-empty strings")
            continue
        try:
            approved_at = accepted["approved_at"]
            parsed = datetime.fromisoformat(approved_at.replace("Z", "+00:00"))
            if "T" not in approved_at or parsed.tzinfo is None:
                raise ValueError
        except ValueError:
            errors.append("accepted gap approved_at must be an ISO date-time")
    accepted_gap_ids = [
        item.get("gap_id")
        for item in result["accepted_gaps"]
        if isinstance(item, dict) and isinstance(item.get("gap_id"), str)
    ]
    if len(accepted_gap_ids) != len(set(accepted_gap_ids)):
        errors.append("accepted gap IDs must be unique")
    accepted_gap_refs = result["accepted_gap_refs"]
    if any(not isinstance(item, str) or not item.strip() for item in accepted_gap_refs):
        errors.append("accepted_gap_refs must contain non-empty strings")
    elif len(accepted_gap_refs) != len(set(accepted_gap_refs)):
        errors.append("accepted_gap_refs must be unique")
    validation_fields = {"command", "result", "evidence"}
    for validation in result["validation"]:
        if not isinstance(validation, dict) or set(validation) != validation_fields:
            errors.append("validation records have invalid fields")
            continue
        if validation.get("result") not in {"passed", "failed", "blocked"}:
            errors.append("validation result is invalid")
        if any(
            not isinstance(validation.get(key), str)
            or not validation.get(key, "").strip()
            for key in validation_fields
        ):
            errors.append("validation fields must be non-empty strings")
    files_changed = result.get("files_changed")
    if files_changed is not None:
        if not isinstance(files_changed, list) or any(
            not isinstance(item, str) for item in files_changed
        ):
            errors.append("files_changed must be a list of strings")
        elif len(files_changed) != len(set(files_changed)):
            errors.append("files_changed must be unique")
    fingerprint = result.get("repository_fingerprint")
    if fingerprint is not None and (
        not isinstance(fingerprint, str) or not SHA256_PATTERN.fullmatch(fingerprint)
    ):
        errors.append("repository_fingerprint must be a sha256 value")
    return errors


def slugify(value):
    slug = []
    for char in value.lower():
        if char.isalnum():
            slug.append(char)
        elif char in {"-", "_", " "}:
            slug.append("-")
    result = "".join(slug).strip("-")
    while "--" in result:
        result = result.replace("--", "-")
    return result or "release-iteration"


def ensure_ignored(path):
    completed = subprocess.run(
        ["git", "check-ignore", "-q", str(path)],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise RuntimeError(f"run workspace is not git ignored: {path}")


def _validate_inputs(goal, source_refs, platforms, policy):
    if not goal.strip():
        raise ValueError("goal must not be empty")
    if not source_refs or len(source_refs) != len(set(source_refs)):
        raise ValueError("source references must be non-empty and unique")
    if any(":" not in source for source in source_refs):
        raise ValueError("source refs must use type:value format")
    if not platforms or len(platforms) != len(set(platforms)):
        raise ValueError("platforms must be non-empty and unique")
    unknown = sorted(set(platforms) - set(policy["platforms"]))
    if unknown:
        raise ValueError(f"unknown platform: {', '.join(unknown)}")


def _state_path(run_path):
    return Path(run_path) / STATE_FILE


def _write_state(run_path, state):
    workflow_workspace.atomic_write_json(_state_path(run_path), state)


def _load_state(run_path):
    state = workflow_workspace.load_json(_state_path(run_path))
    if _migrate_state(run_path, state):
        _write_state(run_path, state)
    return state


def _privacy_finding_key(finding):
    return (
        finding.get("path"),
        finding.get("message"),
        finding.get("content_sha256"),
    )


def _new_privacy_findings(state):
    baseline = {}
    for finding in state.get("privacy", {}).get("changed_line_baseline", []):
        key = _privacy_finding_key(finding)
        baseline[key] = baseline.get(key, 0) + 1
    new_findings = []
    for finding in privacy.changed_line_findings(ROOT):
        key = _privacy_finding_key(finding)
        if baseline.get(key, 0):
            baseline[key] -= 1
        else:
            new_findings.append(finding)
    return new_findings


def _validate_repository_privacy(state):
    findings = _new_privacy_findings(state)
    if findings:
        finding = findings[0]
        raise ValueError(
            "repository privacy delta rejected: "
            f"{finding['path']}:{finding['line']}:{finding['message']}"
        )


def _artifact_index_from_results(run_path, state):
    index = {}
    for agent, result in state.get("results", {}).items():
        normalized = []
        for item in result.get("artifacts", []):
            if not isinstance(item, dict) or not isinstance(item.get("path"), str):
                continue
            path = workflow_workspace.resolve_under(run_path, item["path"])
            if not path.is_file():
                continue
            digest = sha256_file(path)
            normalized.append({"path": item["path"], "sha256": digest})
            index[item["path"]] = {
                "sha256": digest,
                "owner": agent,
                "attempt": result.get("attempt") or 1,
            }
        result["artifacts"] = normalized
    return index


def _migrate_provenance(record):
    changed = False
    for old, new in (
        ("model", "requested_model"),
        ("sandbox", "requested_sandbox"),
        ("working_directory", "requested_working_directory"),
    ):
        if old in record:
            record[new] = record.pop(old)
            changed = True
    if record.get("attestation_status") is None:
        record["attestation_status"] = "unavailable"
        changed = True
    return changed


def _stable_gap_id(gap):
    value = str(gap.get("gap") or "accepted-gap").strip().lower()
    return f"gap-{hashlib.sha256(value.encode('utf-8')).hexdigest()[:12]}"


def _migrate_gap_contract(state):
    results = state.get("results", {})
    product = results.get("product", {})
    approved = {}
    for gap in product.get("accepted_gaps", []):
        if not isinstance(gap, dict):
            continue
        gap.setdefault("gap_id", _stable_gap_id(gap))
        approved[str(gap.get("gap") or "").strip()] = gap["gap_id"]
    product["accepted_gap_refs"] = []
    for agent, result in results.items():
        if not isinstance(result, dict):
            continue
        if agent == "product":
            result.setdefault("accepted_gap_refs", [])
            continue
        refs = list(result.get("accepted_gap_refs", []))
        for gap in result.get("accepted_gaps", []):
            if not isinstance(gap, dict):
                continue
            gap_id = gap.get("gap_id") or approved.get(
                str(gap.get("gap") or "").strip()
            )
            if gap_id in approved.values() and gap_id not in refs:
                refs.append(gap_id)
        result["accepted_gaps"] = []
        result["accepted_gap_refs"] = refs


def _migrate_state(run_path, state):
    version = state.get("schema_version", 1)
    original_version = version
    if version >= STATE_SCHEMA_VERSION:
        return False
    if version < 2:
        state.setdefault("input", {}).setdefault("workflow_profile", "auto")
        routing = state.setdefault("routing", {})
        routing.setdefault("workflow_profile", "full")
        routing.setdefault("contract_evidence", [])
        product = state.get("results", {}).get("product", {})
        product_outputs = product.setdefault("outputs", {})
        product_outputs.setdefault("workflow_profile", routing["workflow_profile"])
        accepted_mock = bool(product.get("accepted_gaps"))
        contract_status = routing.get("contract_status") or (
            "mock" if accepted_mock else "confirmed"
        )
        routing["contract_status"] = contract_status
        product_outputs.setdefault("contract_status", contract_status)
        product_outputs.setdefault("contract_evidence", routing["contract_evidence"])
        execution = state.setdefault("execution", {"runs": {}, "history": []})
        for record in [
            *execution.get("runs", {}).values(),
            *execution.get("history", []),
        ]:
            if isinstance(record, dict):
                _migrate_provenance(record)
        state["artifact_index"] = _artifact_index_from_results(run_path, state)
        state["artifacts"] = list(state["artifact_index"])
        # Existing runs have no trustworthy pre-execution baseline.
        state["privacy"] = {"changed_line_baseline": []}
        version = 2
    if version < 3:
        profile_map = {"fast": "standard"}
        run_input = state.setdefault("input", {})
        input_profile = run_input.get("workflow_profile") or "auto"
        run_input["workflow_profile"] = profile_map.get(input_profile, input_profile)
        routing = state.setdefault("routing", {})
        routing_profile = routing.get("workflow_profile") or "full"
        routing["workflow_profile"] = profile_map.get(
            routing_profile, routing_profile
        )
        product_outputs = (
            state.get("results", {}).get("product", {}).setdefault("outputs", {})
        )
        product_profile = (
            product_outputs.get("workflow_profile") or routing["workflow_profile"]
        )
        product_outputs["workflow_profile"] = profile_map.get(
            product_profile, product_profile
        )
        _migrate_gap_contract(state)
        state["input_hash"] = workflow_workspace.canonical_hash(state["input"])
        input_path = Path(run_path) / INPUT_FILE
        if input_path.is_file():
            persisted_input = workflow_workspace.load_json(input_path)
            persisted_profile = persisted_input.get("workflow_profile") or "auto"
            persisted_input["workflow_profile"] = profile_map.get(
                persisted_profile, persisted_profile
            )
            workflow_workspace.atomic_write_json(input_path, persisted_input)
    state["schema_version"] = STATE_SCHEMA_VERSION
    state.setdefault("events", []).append(
        {
            "type": "state_migration",
            "from": original_version,
            "to": STATE_SCHEMA_VERSION,
            "at": workflow_workspace.now_iso(),
        }
    )
    return True


def _validated_resume_path(run_path):
    resolved = Path(run_path).resolve()
    runs_root = Path(RUNS_DIR).resolve()
    if resolved != runs_root and runs_root not in resolved.parents:
        raise ValueError("resume path must be under pilot-runs")
    return resolved


def create_run(
    name,
    goal,
    source_refs,
    platforms,
    implementation_authorized,
    policy=None,
    today=None,
    workflow_profile="auto",
):
    policy = policy or load_policy()
    selected = list(platforms)
    _validate_inputs(goal, source_refs, selected, policy)
    if workflow_profile not in {"auto", "direct", "standard", "full"}:
        raise ValueError("workflow profile must be auto, direct, standard, or full")
    current = today or date.today().isoformat()
    run_path = Path(RUNS_DIR) / f"{current}-{slugify(name)}"
    if run_path.exists() and any(run_path.iterdir()):
        raise FileExistsError(f"run workspace already exists: {run_path}")
    run_path.mkdir(parents=True, exist_ok=True)
    (run_path / "native-results").mkdir(exist_ok=True)
    (run_path / "native-dispatches").mkdir(exist_ok=True)
    ensure_ignored(run_path / STATE_FILE)

    run_input = {
        "name": name,
        "goal": goal,
        "source_refs": list(source_refs),
        "platforms": selected,
        "implementation_authorized": bool(implementation_authorized),
        "workflow_profile": workflow_profile,
    }
    nodes = workflow_policy.expand_dag(policy, selected, ux_required=True)
    state = workflow_workspace.initial_state(
        run_path.name,
        run_input,
        [node["id"] for node in nodes],
        policy["max_attempts"],
    )
    state.update(
        {
            "routing": {
                "platforms": selected,
                "ux_required": None,
                "ux_reason": None,
                "hld_required": None,
                "hld_rationale": None,
                "hld_review": None,
                "contract_status": None,
                "contract_evidence": [],
                "workflow_profile": None,
            },
            "results": {},
            "repair_attempt": 1,
            "execution": {
                "surface": "codex",
                "runs": {},
                "history": [],
                "repair_attempt": 1,
            },
            "artifacts": [],
            "artifact_index": {},
            "privacy": {
                "changed_line_baseline": privacy.changed_line_findings(ROOT)
            },
        }
    )
    state["schema_version"] = STATE_SCHEMA_VERSION
    workflow_workspace.atomic_write_json(run_path / INPUT_FILE, run_input)
    _write_state(run_path, state)
    finalize_run(run_path, state, policy)
    return run_path


def build_prompt(run_path, state, node, attempt):
    agent = node["id"]
    contract = ROLE_CONTRACTS.get(
        agent,
        "Deliver the requested outcome for this platform. Follow its workflow entrypoints, keep changes in scope, and return files_changed, covered_criteria, and targeted validation evidence.",
    )
    entrypoints = []
    repository_root = Path(ROOT).resolve()
    for raw_path in node.get("workflow_entrypoints", []):
        relative_path = Path(raw_path)
        if relative_path.is_absolute():
            raise ValueError("platform workflow entrypoint must be repository-relative")
        resolved = (repository_root / relative_path).resolve()
        if resolved != repository_root and repository_root not in resolved.parents:
            raise ValueError("platform workflow entrypoint escapes repository root")
        entrypoints.append(str(resolved))
    context = {
        "run_id": state["run_id"],
        "attempt": attempt,
        "agent": node["id"],
        "goal": state["input"]["goal"],
        "source_refs": state["input"]["source_refs"],
        "platforms": state["routing"]["platforms"],
        "routing": state["routing"],
        "approved_gaps": state.get("results", {})
        .get("product", {})
        .get("accepted_gaps", []),
        "expected_artifact": node["artifact"],
        "upstream_artifacts": list(state.get("artifacts", [])),
        "finalization_errors": list(state.get("finalization_errors", [])),
        "workflow_entrypoints": entrypoints,
        "run_workspace": str(Path(run_path).resolve()),
        "requested_workflow_profile": state["input"].get(
            "workflow_profile", "auto"
        ),
    }
    prompt = (
        f"Outcome:\n{contract}\n\n"
        "Completion bar:\n"
        "- Follow repository-local instructions and satisfy the declared acceptance criteria.\n"
        "- Keep private source content and artifacts inside the run workspace.\n"
        "- Return schema-valid role-result JSON; artifact entries contain only path and sha256.\n"
        "- Use only policy finding categories and owners. Only Product may populate "
        "accepted_gaps; other roles cite approved gap IDs in accepted_gap_refs. "
        "Keep gaps for unresolved, unapproved blockers and do not duplicate approved "
        "exceptions there.\n\n"
        "Run context:\n" + json.dumps(context, indent=2)
    )
    if entrypoints:
        prompt += "\n\nRead and follow these platform workflow entrypoints before acting:\n"
        prompt += "\n".join(f"- {path}" for path in entrypoints)
    return prompt


def _expected_artifact(policy, agent):
    if agent in policy["roles"]:
        return policy["roles"][agent]["artifact"]
    if agent in policy["platforms"]:
        return f"{agent}-result.json"
    raise ValueError(f"unknown role artifact owner: {agent}")


def materialize_role_artifacts(run_path, role_result):
    policy = load_policy()
    agent = role_result["agent"]
    expected = _expected_artifact(policy, agent)
    artifacts = role_result.get("artifacts", [])
    paths = [item.get("path") for item in artifacts if isinstance(item, dict)]
    if role_result["status"] == "passed" and expected not in paths:
        raise ValueError(f"required role artifact missing for {agent}: {expected}")
    allowed = {expected}
    if agent == "architect" and role_result.get("outputs", {}).get("hld_required"):
        allowed.add("hld.md")
    contract_evidence = role_result.get("outputs", {}).get("contract_evidence", [])
    if agent == "product" and isinstance(contract_evidence, list):
        allowed.update(
            item.get("path")
            for item in contract_evidence
            if isinstance(item, dict) and isinstance(item.get("path"), str)
        )
    promoted = []
    for item in artifacts:
        if not isinstance(item, dict) or set(item) != {"path", "sha256"}:
            raise ValueError(
                f"invalid artifact record for {agent}; artifacts require path and sha256"
            )
        if item["path"] not in allowed:
            raise ValueError(f"unexpected artifact for {agent}: {item['path']}")
        destination = workflow_workspace.resolve_under(run_path, item["path"])
        if not destination.is_file():
            raise ValueError(f"referenced artifact is missing: {item['path']}")
        if sha256_file(destination) != item["sha256"]:
            raise ValueError(f"artifact hash mismatch: {item['path']}")
        errors = privacy.scan([str(destination)])
        if errors:
            raise ValueError(f"private artifact rejected: {errors[0]}")
        promoted.append(str(destination.relative_to(Path(run_path).resolve())))
    return promoted


def update_routing_from_product(state, role_result):
    outputs = role_result.get("outputs", {})
    selected = outputs.get("platforms")
    declared = state["input"]["platforms"]
    if not isinstance(selected, list) or not selected:
        raise ValueError("Product must confirm at least one platform")
    expansion = sorted(set(selected) - set(declared))
    if expansion:
        raise ValueError(
            f"Product cannot expand declared platforms: {', '.join(expansion)}"
        )
    ux_required = outputs.get("ux_required")
    if not isinstance(ux_required, bool):
        raise ValueError("Product must decide ux_required")
    ux_reason = outputs.get("ux_reason")
    if not isinstance(ux_reason, str) or not ux_reason.strip():
        raise ValueError("Product must provide a UX routing reason")
    workflow_profile = outputs.get("workflow_profile", "standard")
    if workflow_profile not in {"direct", "standard", "full"}:
        raise ValueError("Product workflow_profile must be direct, standard, or full")
    requested_profile = state["input"].get("workflow_profile", "auto")
    if requested_profile != "auto" and workflow_profile != requested_profile:
        raise ValueError(
            f"Product workflow_profile must honor requested profile: {requested_profile}"
        )
    if workflow_profile != "full":
        if ux_required or outputs.get("hld_required") is not False:
            raise ValueError(
                f"{workflow_profile} profile cannot require UX or HLD"
            )
        required_planning = {
            "hld_rationale",
            "covered_criteria",
        }
        missing_planning = [
            field
            for field in required_planning
            if not outputs.get(field)
        ]
        if missing_planning:
            raise ValueError(
                f"{workflow_profile} profile planning output is incomplete: "
                + ", ".join(sorted(missing_planning))
            )
        acceptance_criteria = outputs.get("acceptance_criteria", [])
        covered_criteria = outputs.get("covered_criteria", [])
        if not isinstance(covered_criteria, list) or any(
            criterion not in covered_criteria for criterion in acceptance_criteria
        ):
            raise ValueError(
                f"{workflow_profile} profile must cover every acceptance criterion"
            )
    contract_status = outputs.get("contract_status")
    if contract_status not in {"mock", "confirmed"}:
        raise ValueError("Product contract_status must be mock or confirmed")
    contract_evidence = outputs.get("contract_evidence", [])
    if not isinstance(contract_evidence, list):
        raise ValueError("Product contract_evidence must be a list")
    allowed_evidence = {"sanitized_response", "json_schema", "openapi"}
    for item in contract_evidence:
        if not isinstance(item, dict) or set(item) != {"type", "path", "sha256"}:
            raise ValueError("contract evidence requires type, path, and sha256")
        if item["type"] not in allowed_evidence:
            raise ValueError(f"unsupported contract evidence type: {item['type']}")
        artifact = next(
            (
                candidate
                for candidate in role_result.get("artifacts", [])
                if isinstance(candidate, dict)
                and candidate.get("path") == item["path"]
            ),
            None,
        )
        if artifact is None or artifact.get("sha256") != item["sha256"]:
            raise ValueError(
                f"contract evidence must match an artifact reference: {item['path']}"
            )
    if contract_status == "confirmed" and not contract_evidence:
        raise ValueError(
            "confirmed contract requires sanitized response, JSON Schema, or OpenAPI evidence"
        )
    state["routing"].update(
        {
            "platforms": selected,
            "ux_required": ux_required,
            "ux_reason": ux_reason,
            "contract_status": contract_status,
            "contract_evidence": contract_evidence,
            "workflow_profile": workflow_profile,
        }
    )
    if workflow_profile != "full":
        state["routing"].update(
            {
                "hld_required": False,
                "hld_rationale": outputs["hld_rationale"],
                "hld_review": None,
            }
        )
    else:
        state["routing"].update(
            {"hld_required": None, "hld_rationale": None, "hld_review": None}
        )
    profile_nodes = {
        "knowledge",
        "architect",
        "ux-design",
        "test-design",
        "test-verification",
        "ux-acceptance",
        "acceptance-reviewer",
    }
    skipped = set(PROFILE_SKIPPED_AGENTS[workflow_profile])
    if workflow_profile == "full" and not ux_required:
        skipped.update({"ux-design", "ux-acceptance"})
    reason = f"not required by {workflow_profile} profile"
    for node_id in profile_nodes:
        node = state["nodes"][node_id]
        if node_id not in skipped and node["status"] == "not_required":
            node.update({"status": "pending", "reason": None})
        elif node_id in skipped:
            workflow_workspace.discard_node_output(state, node_id)
            node.update(
                {
                    "status": "not_required",
                    "reason": ux_reason if node_id.startswith("ux-") else reason,
                }
            )
    for platform in set(declared) - set(selected):
        workflow_workspace.discard_node_output(state, platform)
        state["nodes"][platform].update(
            {"status": "not_required", "reason": "not confirmed by Product"}
        )
    for platform in set(selected):
        node = state["nodes"][platform]
        if node["status"] == "not_required":
            workflow_workspace.discard_node_output(state, platform)
            node.update(
                {
                    "status": "pending",
                    "reason": "reselected by Product",
                    "input_hash": None,
                    "artifact_hash": None,
                }
            )


def update_hld_from_architect(state, role_result):
    outputs = role_result.get("outputs", {})
    hld_required = outputs.get("hld_required")
    rationale = outputs.get("hld_rationale")
    if not isinstance(hld_required, bool):
        raise ValueError("Architect must decide hld_required")
    if not isinstance(rationale, str) or not rationale.strip():
        raise ValueError("Architect must provide an HLD rationale")
    review = outputs.get("hld_review")
    if hld_required:
        required = {"status", "reviewed_by", "reviewed_at"}
        if not isinstance(review, dict) or required - set(review):
            raise ValueError("required HLD review metadata is incomplete")
        if review["status"] != "approved":
            raise ValueError("required HLD must be approved")
        if "hld.md" not in {
            item.get("path") for item in role_result.get("artifacts", [])
        }:
            raise ValueError("required HLD artifact is missing")
    state["routing"].update(
        {
            "hld_required": hld_required,
            "hld_rationale": rationale,
            "hld_review": review if hld_required else None,
        }
    )


def _effective_workflow_profile(state):
    routed = state.get("routing", {}).get("workflow_profile")
    if routed in {"direct", "standard", "full"}:
        return routed
    requested = state.get("input", {}).get("workflow_profile")
    return requested if requested in {"direct", "standard", "full"} else "full"


def _nodes_for_state(policy, state):
    ux_required = state["routing"]["ux_required"] is not False
    workflow_profile = _effective_workflow_profile(state)
    nodes = {
        node["id"]: node
        for node in workflow_policy.expand_dag(
            policy,
            state["routing"]["platforms"],
            ux_required,
            workflow_profile=workflow_profile,
        )
    }
    return nodes


def _ready_node_ids(state, policy):
    nodes = _nodes_for_state(policy, state)
    blocked_agents = [
        node_id
        for node_id, node in state["nodes"].items()
        if node_id != "acceptance-reviewer" and node["status"] == "blocked"
    ]
    failed_agents = [
        node_id
        for node_id, node in state["nodes"].items()
        if node_id != "acceptance-reviewer" and node["status"] == "failed"
    ]
    repair_exhausted = state.get("repair_attempt", 1) >= state["max_attempts"]
    reviewer = state["nodes"].get("acceptance-reviewer")
    if blocked_agents or (failed_agents and repair_exhausted):
        if reviewer and reviewer["status"] in {"pending", "failed"}:
            if _effective_workflow_profile(state) == "full":
                return ["acceptance-reviewer"]
        return []
    ready = []
    for node_id, node in nodes.items():
        if state["nodes"][node_id]["status"] not in {"pending", "failed"}:
            continue
        dependencies = node.get("depends_on", [])
        if all(
            state["nodes"][dependency]["status"] in {"passed", "not_required"}
            for dependency in dependencies
        ):
            if (
                node_id in state["routing"]["platforms"]
                and not state["input"].get("implementation_authorized")
            ):
                continue
            if node_id in state["routing"]["platforms"]:
                try:
                    _validate_repository_privacy(state)
                except ValueError:
                    continue
            ready.append(node_id)
    return ready


def native_dispatch(run_path):
    run_path = _validated_resume_path(run_path)
    state = _load_state(run_path)
    policy = load_policy()
    nodes = _nodes_for_state(policy, state)
    attempt = state["attempt"]
    dispatches = []
    for agent in _ready_node_ids(state, policy):
        node = nodes[agent]
        record_path = workflow_workspace.resolve_under(
            run_path, f"native-dispatches/{attempt:02d}-{agent}.json"
        )
        if record_path.is_file():
            record = workflow_workspace.load_json(record_path)
            fingerprint = record.get("repository_fingerprint")
        else:
            fingerprint = (
                repository_fingerprint()
                if agent in READ_ONLY_NATIVE_AGENTS
                else None
            )
            record = {
                "agent": agent,
                "attempt": attempt,
                "repository_fingerprint": fingerprint,
            }
            workflow_workspace.atomic_write_json(record_path, record)
        prompt = build_prompt(run_path, state, node, attempt)
        if fingerprint:
            prompt += (
                "\n\nRead-only repository fingerprint: "
                f"{fingerprint}. Return it unchanged as repository_fingerprint; "
                "ingestion rejects repository mutation."
            )
        dispatch = {
            "agent": agent,
            "attempt": attempt,
            "model": node["model"],
            "reasoning_effort": node["reasoning_effort"],
            "sandbox": node["sandbox"],
            "working_directory": str(
                (Path(ROOT) / node["working_directory"]).resolve()
            ),
            "result_path": str(
                (
                    Path(run_path)
                    / "native-results"
                    / f"{attempt:02d}-{agent}.json"
                ).resolve()
            ),
            "prompt": prompt,
        }
        if fingerprint:
            dispatch["repository_fingerprint"] = fingerprint
        dispatches.append(dispatch)
    return dispatches


def _validate_role_result(role_result, agent, attempt, state):
    structure_errors = validate_native_result_structure(role_result)
    if structure_errors:
        raise ValueError(structure_errors[0])
    if role_result.get("agent") != agent:
        raise ValueError(f"role result agent must be {agent}")
    if role_result.get("attempt") != attempt:
        raise ValueError(f"role result attempt must be {attempt}")
    if role_result.get("status") not in {"passed", "failed", "blocked"}:
        raise ValueError(f"invalid role status for {agent}")
    if not isinstance(role_result.get("source_refs"), list):
        raise ValueError(f"role result source_refs must be a list: {agent}")
    if agent == "product" and set(role_result["source_refs"]) != set(
        state["input"]["source_refs"]
    ):
        raise ValueError("Product source evidence does not match declared inputs")
    if agent == "product" and role_result["accepted_gap_refs"]:
        raise ValueError("Product must approve gaps directly, not by reference")
    if agent != "product" and role_result["accepted_gaps"]:
        raise ValueError("only Product may approve accepted gaps")
    approved_ids = {
        item.get("gap_id")
        for item in state.get("results", {})
        .get("product", {})
        .get("accepted_gaps", [])
        if isinstance(item, dict)
    }
    unknown_refs = sorted(set(role_result["accepted_gap_refs"]) - approved_ids)
    if unknown_refs:
        raise ValueError(
            f"accepted gap reference was not approved by Product: {', '.join(unknown_refs)}"
        )


def _validate_finding_semantics(
    policy, role_result, platforms, workflow_profile="full"
):
    findings = role_result.get("findings", [])
    workflow_policy.targets_for_findings(
        policy, findings, platforms, workflow_profile=workflow_profile
    )
    routes = policy["finding_routes"][workflow_profile]
    for finding in findings:
        route = routes[finding["category"]]
        owner = finding["owner"]
        if route == "platform" and owner not in platforms:
            raise ValueError(f"finding platform owner is not selected: {owner}")
        if route == "platforms" and owner not in {*platforms, "platforms"}:
            raise ValueError(
                f"cross-platform finding owner must be platforms or a selected platform: {owner}"
            )
        if route not in {"platform", "platforms", "blocked"} and owner != route:
            raise ValueError(
                f"finding owner does not match route {route}: {owner}"
            )


def _apply_execution(state, role_result, provenance, promoted):
    agent = role_result["agent"]
    attempt = role_result["attempt"]
    for path in promoted:
        if path not in state["artifacts"]:
            state["artifacts"].append(path)
    for artifact in role_result.get("artifacts", []):
        state.setdefault("artifact_index", {})[artifact["path"]] = {
            "sha256": artifact["sha256"],
            "owner": agent,
            "attempt": attempt,
        }
    state["results"][agent] = role_result
    state["nodes"][agent].update(
        {
            "status": role_result["status"],
            "attempt": attempt,
            "input_hash": workflow_workspace.canonical_hash(
                {"input": state["input_hash"], "routing": state["routing"]}
            ),
            "artifact_hash": workflow_workspace.canonical_hash(role_result),
            "reason": role_result["summary"],
        }
    )
    state["execution"]["runs"][agent] = provenance
    state["execution"]["history"].append(provenance)


def _persist_execution(run_path, state, role_result, provenance):
    agent = role_result["agent"]
    attempt = role_result["attempt"]
    result_path = workflow_workspace.attempt_result_path(run_path, attempt, agent)
    promoted = materialize_role_artifacts(run_path, role_result)
    workflow_workspace.atomic_write_json(result_path, role_result)
    _apply_execution(state, role_result, provenance, promoted)
    _write_state(run_path, state)


def repository_fingerprint():
    tracked = subprocess.run(
        [
            "git",
            "diff",
            "--binary",
            "HEAD",
            "--",
            ".",
            ":(exclude)docs/ai-engineering/pilot-runs",
        ],
        cwd=ROOT,
        capture_output=True,
    )
    if tracked.returncode != 0:
        raise RuntimeError("unable to fingerprint repository changes")
    untracked = subprocess.run(
        [
            "git",
            "ls-files",
            "--others",
            "--exclude-standard",
            "-z",
            "--",
            ".",
            ":(exclude)docs/ai-engineering/pilot-runs",
        ],
        cwd=ROOT,
        capture_output=True,
    )
    if untracked.returncode != 0:
        raise RuntimeError("unable to fingerprint untracked repository files")
    digest = hashlib.sha256()
    digest.update(tracked.stdout)
    repository_root = Path(ROOT).resolve()
    for raw_path in sorted(filter(None, untracked.stdout.split(b"\0"))):
        relative_path = Path(os.fsdecode(raw_path))
        path = (repository_root / relative_path).resolve()
        if path != repository_root and repository_root not in path.parents:
            raise RuntimeError("untracked repository path escapes root")
        try:
            content = path.read_bytes()
        except OSError as error:
            raise RuntimeError(
                f"unable to fingerprint untracked repository file: {relative_path}"
            ) from error
        digest.update(b"\0untracked\0")
        digest.update(raw_path)
        digest.update(b"\0")
        digest.update(content)
    return digest.hexdigest()


def _blocked_execution(node, attempt, error):
    agent = node["id"]
    summary = f"{type(error).__name__}: {error}"
    return {
        "result": {
            "agent": agent,
            "phase": "execution",
            "attempt": attempt,
            "status": "blocked",
            "summary": summary,
            "source_refs": [],
            "outputs": {},
            "artifacts": [],
            "findings": [],
            "gaps": [summary],
            "accepted_gaps": [],
            "accepted_gap_refs": [],
            "validation": [],
        },
        "provenance": {
            "agent": agent,
            "attempt": attempt,
            "thread_id": None,
            "requested_model": node["model"],
            "reasoning_effort": node["reasoning_effort"],
            "requested_sandbox": node["sandbox"],
            "requested_working_directory": node["working_directory"],
            "attestation_status": "unavailable",
            "output": f"attempts/{attempt:02d}/role-results/{agent}.json",
            "result": "blocked",
        },
    }


def _call_executor(run_path, state, node, executor, attempt):
    fingerprint = repository_fingerprint() if node["id"] == "test-verification" else None
    try:
        execution = executor.execute(
            run_path,
            node,
            build_prompt(run_path, state, node, attempt),
            attempt,
        )
        if fingerprint is not None and repository_fingerprint() != fingerprint:
            raise RuntimeError("Test Verification modified tracked repository files")
        return execution
    except Exception as error:
        return _blocked_execution(node, attempt, error)


def _execute_node(run_path, state, node, executor, attempt):
    agent = node["id"]
    state["nodes"][agent].update(
        {"status": "running", "attempt": attempt, "reason": None}
    )
    _write_state(run_path, state)
    execution = _call_executor(run_path, state, node, executor, attempt)
    try:
        role_result = execution["result"]
        provenance = execution["provenance"]
        _validate_role_result(role_result, agent, attempt, state)
        if provenance.get("agent") != agent or provenance.get("attempt") != attempt:
            raise ValueError(f"execution provenance mismatch for {agent}")
        if agent == "product" and role_result["status"] == "passed":
            update_routing_from_product(state, role_result)
        if agent == "architect" and role_result["status"] == "passed":
            update_hld_from_architect(state, role_result)
        _persist_execution(run_path, state, role_result, provenance)
    except Exception as error:
        execution = _blocked_execution(node, attempt, error)
        role_result = execution["result"]
        _persist_execution(run_path, state, role_result, execution["provenance"])
    return role_result


def _execute_platforms(run_path, state, nodes, executor, attempt):
    selected = [
        platform
        for platform in state["routing"]["platforms"]
        if state["nodes"][platform]["status"] in {"pending", "failed"}
    ]
    if not selected:
        return []
    for platform in selected:
        state["nodes"][platform].update(
            {"status": "running", "attempt": attempt, "reason": None}
        )
    _write_state(run_path, state)

    def execute(platform):
        node = nodes[platform]
        return platform, _call_executor(
            run_path, state, node, executor, attempt
        )

    executions = []
    with ThreadPoolExecutor(max_workers=len(selected)) as pool:
        futures = [pool.submit(execute, platform) for platform in selected]
        for future in futures:
            executions.append(future.result())
    results = []
    for platform, execution in executions:
        node = nodes[platform]
        try:
            role_result = execution["result"]
            provenance = execution["provenance"]
            _validate_role_result(role_result, platform, attempt, state)
            if provenance.get("agent") != platform or provenance.get("attempt") != attempt:
                raise ValueError(f"execution provenance mismatch for {platform}")
            _persist_execution(run_path, state, role_result, provenance)
        except Exception as error:
            blocked = _blocked_execution(node, attempt, error)
            role_result = blocked["result"]
            _persist_execution(run_path, state, role_result, blocked["provenance"])
        results.append(role_result)
    return results


def _blocked_result(state):
    return any(node["status"] == "blocked" for node in state["nodes"].values())


def _failed_nodes(state):
    return [
        node_id
        for node_id, node in state["nodes"].items()
        if node["status"] == "failed"
    ]


def _schedule_target(state, target, reason):
    if target in state["routing"]["platforms"]:
        workflow_workspace.discard_node_output(state, target)
        state["nodes"][target].update({"status": "pending", "reason": reason})
        workflow_workspace.invalidate_from(state, "platforms", reason)
        return
    if target not in state["nodes"]:
        raise ValueError(f"repair target is not in the run DAG: {target}")
    if state["nodes"][target]["status"] != "not_required":
        workflow_workspace.discard_node_output(state, target)
        state["nodes"][target].update({"status": "pending", "reason": reason})
    workflow_workspace.invalidate_from(state, target, reason)


def _prepare_retry(run_path, state, targets, reason, persist=True):
    repair_attempt = state.get("repair_attempt", 1)
    if repair_attempt >= state["max_attempts"]:
        return False
    state["attempt"] += 1
    state["repair_attempt"] = repair_attempt + 1
    state["execution"]["repair_attempt"] = state["repair_attempt"]
    for target in targets:
        _schedule_target(state, target, reason)
    if persist:
        _write_state(run_path, state)
    return True


def _route_findings(run_path, state, policy, results, persist=True):
    findings = [
        finding
        for result in results
        for finding in result.get("findings", [])
    ]
    if not findings:
        return None
    try:
        targets = workflow_policy.targets_for_findings(
            policy,
            findings,
            state["routing"]["platforms"],
            workflow_profile=_effective_workflow_profile(state),
        )
    except ValueError as error:
        for result in results:
            if result.get("findings"):
                state["nodes"][result["agent"]].update(
                    {"status": "blocked", "reason": str(error)}
                )
        if persist:
            _write_state(run_path, state)
        return "blocked"
    if "blocked" in targets:
        for result in results:
            if result.get("findings"):
                state["nodes"][result["agent"]].update(
                    {"status": "blocked", "reason": "external finding blocks run"}
                )
        if persist:
            _write_state(run_path, state)
        return "blocked"
    if _prepare_retry(
        run_path, state, targets, "finding repair", persist=persist
    ):
        return "retry"
    for result in results:
        if result.get("findings"):
            state["nodes"][result["agent"]]["status"] = "failed"
    if persist:
        _write_state(run_path, state)
    return "exhausted"


def _validated_native_result_path(run_path, result_path):
    run_path = Path(run_path).resolve()
    result_path = Path(result_path)
    candidates = (
        [result_path.resolve()]
        if result_path.is_absolute()
        else [result_path.resolve(), (run_path / result_path).resolve()]
    )
    confined = [
        candidate
        for candidate in candidates
        if candidate == run_path or run_path in candidate.parents
    ]
    for candidate in confined:
        if candidate.is_file():
            return candidate
    if not confined:
        raise ValueError("native result path must be under the run workspace")
    raise ValueError(f"native result file does not exist: {confined[0]}")


def preflight_native_results(run_path, submissions, require_agent_ids=True):
    run_path = _validated_resume_path(run_path)
    if not submissions:
        raise ValueError("at least one native result is required")
    state = _load_state(run_path)
    policy = load_policy()
    nodes = _nodes_for_state(policy, state)
    ready = set(_ready_node_ids(state, policy))
    attempt = state["attempt"]
    prepared = []
    seen_agents = set()
    validation_state = deepcopy(state)

    for result_path, native_agent_id in submissions:
        if require_agent_ids and not str(native_agent_id).strip():
            raise ValueError("native agent ID must not be empty")
        path = _validated_native_result_path(run_path, result_path)
        errors = privacy.scan([str(path)])
        if errors:
            raise ValueError(f"private native result rejected: {errors[0]}")
        role_result = workflow_workspace.load_json(path)
        agent = role_result.get("agent")
        if agent in state["routing"]["platforms"]:
            _validate_repository_privacy(state)
        if agent not in ready:
            raise ValueError(f"native result agent is not ready: {agent}")
        if agent in seen_agents:
            raise ValueError(f"duplicate native result agent: {agent}")
        seen_agents.add(agent)
        _validate_role_result(role_result, agent, attempt, validation_state)
        workflow_profile = (
            role_result.get("outputs", {}).get("workflow_profile", "standard")
            if agent == "product"
            else validation_state["routing"].get("workflow_profile") or "full"
        )
        _validate_finding_semantics(
            policy,
            role_result,
            validation_state["routing"]["platforms"],
            workflow_profile=workflow_profile,
        )
        if agent in READ_ONLY_NATIVE_AGENTS:
            dispatch_record = workflow_workspace.resolve_under(
                run_path, f"native-dispatches/{attempt:02d}-{agent}.json"
            )
            if not dispatch_record.is_file():
                raise ValueError(f"native dispatch record is missing: {agent}")
            expected_fingerprint = workflow_workspace.load_json(
                dispatch_record
            ).get("repository_fingerprint")
            if role_result.get("repository_fingerprint") != expected_fingerprint:
                raise ValueError(f"repository fingerprint evidence mismatch: {agent}")
            if repository_fingerprint() != expected_fingerprint:
                raise ValueError(f"read-only Agent changed repository: {agent}")
        promoted = materialize_role_artifacts(run_path, role_result)
        if agent == "product" and role_result["status"] == "passed":
            update_routing_from_product(validation_state, role_result)
        elif agent == "architect" and role_result["status"] == "passed":
            update_hld_from_architect(validation_state, role_result)
        provenance = {
            "agent": agent,
            "attempt": attempt,
            "thread_id": (
                f"native:{native_agent_id}:{attempt}" if native_agent_id else None
            ),
            "requested_model": nodes[agent]["model"],
            "reasoning_effort": nodes[agent]["reasoning_effort"],
            "requested_sandbox": nodes[agent]["sandbox"],
            "requested_working_directory": nodes[agent]["working_directory"],
            "attestation_status": "unavailable",
            "output": str(
                workflow_workspace.attempt_result_path(run_path, attempt, agent).relative_to(
                    run_path
                )
            ),
            "result": "completed",
        }
        prepared.append(
            {
                "role_result": role_result,
                "provenance": provenance,
                "promoted": promoted,
            }
        )
    return run_path, state, policy, prepared


def ingest_native_results(run_path, submissions):
    run_path, state, policy, prepared = preflight_native_results(
        run_path, submissions
    )
    working_state = deepcopy(state)
    results = []
    for item in prepared:
        role_result = item["role_result"]
        agent = role_result["agent"]
        if agent == "product" and role_result["status"] == "passed":
            update_routing_from_product(working_state, role_result)
        elif agent == "architect" and role_result["status"] == "passed":
            update_hld_from_architect(working_state, role_result)
        _apply_execution(
            working_state,
            role_result,
            item["provenance"],
            item["promoted"],
        )
        results.append(role_result)

    routing = _route_findings(
        run_path, working_state, policy, results, persist=False
    )
    failed = [result["agent"] for result in results if result["status"] == "failed"]
    if routing is None and failed:
        _prepare_retry(
            run_path,
            working_state,
            failed,
            "retry failed native Agent",
            persist=False,
        )
    for item in prepared:
        role_result = item["role_result"]
        workflow_workspace.atomic_write_json(
            workflow_workspace.attempt_result_path(
                run_path, role_result["attempt"], role_result["agent"]
            ),
            role_result,
        )
    _write_state(run_path, working_state)
    status = finalize_run(run_path, working_state, policy)
    return {
        "run": str(run_path),
        "status": status,
        "ready": native_dispatch(run_path),
    }


def _run_acceptance_for_blocked(run_path, state, policy, executor):
    if _effective_workflow_profile(state) != "full":
        return
    nodes = _nodes_for_state(policy, state)
    reviewer = state["nodes"].get("acceptance-reviewer")
    if reviewer and reviewer["status"] in {"pending", "failed"}:
        _execute_node(
            run_path,
            state,
            nodes["acceptance-reviewer"],
            executor,
            state["attempt"],
        )


def execute_run(run_path, executor=None):
    run_path = Path(run_path).resolve()
    state = _load_state(run_path)
    policy = load_policy()
    if executor is None:
        raise RuntimeError(
            "native Agent orchestration requires an explicit executor; "
            "implicit nested Codex process execution is disabled"
        )

    while True:
        attempt = state["attempt"]
        nodes = _nodes_for_state(policy, state)

        phase_results = []
        for agent in ("product", "knowledge", "architect"):
            if state["nodes"][agent]["status"] in {"pending", "failed"}:
                phase_results.append(
                    _execute_node(run_path, state, nodes[agent], executor, attempt)
                )
            if state["nodes"][agent]["status"] in {"failed", "blocked"}:
                break
        routing = _route_findings(run_path, state, policy, phase_results)
        if routing == "retry":
            continue
        if _blocked_result(state):
            _run_acceptance_for_blocked(run_path, state, policy, executor)
            return finalize_run(run_path, state, policy)
        failed = _failed_nodes(state)
        if failed:
            if _prepare_retry(run_path, state, failed, "retry failed prerequisite"):
                continue
            _run_acceptance_for_blocked(run_path, state, policy, executor)
            return finalize_run(run_path, state, policy)

        nodes = _nodes_for_state(policy, state)
        phase_results = []
        for agent in ("ux-design", "test-design"):
            if state["nodes"][agent]["status"] in {"pending", "failed"}:
                phase_results.append(
                    _execute_node(run_path, state, nodes[agent], executor, attempt)
                )
            if state["nodes"][agent]["status"] in {"failed", "blocked"}:
                break
        routing = _route_findings(run_path, state, policy, phase_results)
        if routing == "retry":
            continue
        if _blocked_result(state):
            _run_acceptance_for_blocked(run_path, state, policy, executor)
            return finalize_run(run_path, state, policy)
        failed = _failed_nodes(state)
        if failed:
            if _prepare_retry(run_path, state, failed, "retry failed design gate"):
                continue
            _run_acceptance_for_blocked(run_path, state, policy, executor)
            return finalize_run(run_path, state, policy)

        if not state["input"].get("implementation_authorized"):
            return finalize_run(run_path, state, policy)
        try:
            _validate_repository_privacy(state)
        except ValueError:
            return finalize_run(run_path, state, policy)

        phase_results = _execute_platforms(
            run_path, state, nodes, executor, attempt
        )
        routing = _route_findings(run_path, state, policy, phase_results)
        if routing == "retry":
            continue
        failed = _failed_nodes(state)
        if failed:
            if _prepare_retry(run_path, state, failed, "retry failed platform"):
                continue
            _run_acceptance_for_blocked(run_path, state, policy, executor)
            return finalize_run(run_path, state, policy)
        if _blocked_result(state):
            _run_acceptance_for_blocked(run_path, state, policy, executor)
            return finalize_run(run_path, state, policy)

        nodes = _nodes_for_state(policy, state)
        phase_results = []
        for agent in ("test-verification", "ux-acceptance", "acceptance-reviewer"):
            if state["nodes"][agent]["status"] in {"pending", "failed"}:
                phase_results.append(
                    _execute_node(run_path, state, nodes[agent], executor, attempt)
                )
            if state["nodes"][agent]["status"] in {"failed", "blocked"}:
                break
        routing = _route_findings(run_path, state, policy, phase_results)
        if routing == "retry":
            continue
        if _blocked_result(state):
            _run_acceptance_for_blocked(run_path, state, policy, executor)
            return finalize_run(run_path, state, policy)
        failed = _failed_nodes(state)
        if failed:
            if _prepare_retry(run_path, state, failed, "retry failed acceptance gate"):
                continue
            _run_acceptance_for_blocked(run_path, state, policy, executor)
            return finalize_run(run_path, state, policy)

        return finalize_run(run_path, state, policy)


def _prepare_resume_state(run_path):
    run_path = _validated_resume_path(run_path)
    state = _load_state(run_path)
    state.setdefault("repair_attempt", 1)
    state["execution"].setdefault("repair_attempt", state["repair_attempt"])
    current_input = workflow_workspace.load_json(run_path / INPUT_FILE)
    current_hash = workflow_workspace.canonical_hash(current_input)
    if current_hash != state["input_hash"]:
        previous_input = state["input"]
        state["input"] = current_input
        state["input_hash"] = current_hash
        changed_fields = {
            key
            for key in set(previous_input) | set(current_input)
            if previous_input.get(key) != current_input.get(key)
        }
        if changed_fields == {"implementation_authorized"}:
            state["events"].append(
                {
                    "type": "authorization_update",
                    "authorized": bool(current_input.get("implementation_authorized")),
                    "at": workflow_workspace.now_iso(),
                }
            )
        else:
            workflow_workspace.discard_node_output(state, "product")
            state["nodes"]["product"].update(
                {"status": "pending", "reason": "run input changed"}
            )
            workflow_workspace.invalidate_from(state, "product", "run input changed")
    else:
        candidates = [
            node_id
            for node_id in workflow_workspace.resume_candidates(state)
            if state["nodes"][node_id]["status"]
            in {"running", "blocked", "failed"}
        ]
        for node_id in candidates:
            _schedule_target(state, node_id, "manual resume")
    if state["execution"]["history"]:
        state["attempt"] += 1
    state["repair_attempt"] = 1
    state["execution"]["repair_attempt"] = 1
    _write_state(run_path, state)
    return run_path, state


def prepare_native_resume(run_path):
    run_path, state = _prepare_resume_state(run_path)
    status = finalize_run(run_path, state, load_policy())
    return {
        "run": str(run_path),
        "status": status,
        "ready": native_dispatch(run_path),
    }


def resume_run(run_path, executor=None):
    run_path, _ = _prepare_resume_state(run_path)
    return execute_run(run_path, executor=executor)


def _not_required_result(agent, state):
    return {
        "agent": agent,
        "phase": "conditional",
        "attempt": max(1, state["attempt"]),
        "status": "not_required",
        "summary": state["nodes"][agent].get("reason") or "not required",
        "source_refs": [],
        "outputs": {"reason": state["nodes"][agent].get("reason")},
        "artifacts": [],
        "findings": [],
        "gaps": [],
        "accepted_gaps": [],
        "accepted_gap_refs": [],
        "validation": [],
    }


def _product_accepted_gaps(stages):
    accepted = []
    seen = set()
    for stage in stages:
        if stage.get("agent") != "product":
            continue
        for gap in stage.get("accepted_gaps", []):
            gap_id = gap.get("gap_id") if isinstance(gap, dict) else None
            if not gap_id or gap_id in seen:
                continue
            seen.add(gap_id)
            accepted.append(gap)
    return accepted


def _manifest_from_state(state):
    stages = []
    for agent in state["nodes"]:
        if agent in state["results"]:
            stage = dict(state["results"][agent])
            node = state["nodes"][agent]
            if node["status"] in {"blocked", "failed"} and stage.get(
                "status"
            ) != node["status"]:
                reason = node.get("reason") or f"{agent} {node['status']}"
                stage.update(
                    {
                        "status": node["status"],
                        "summary": reason,
                        "gaps": [*stage.get("gaps", []), reason],
                    }
                )
            stages.append(stage)
        elif state["nodes"][agent]["status"] == "not_required":
            stages.append(_not_required_result(agent, state))
    validation = []
    for stage in stages:
        for item in stage.get("validation", []):
            validation.append({"agent": stage["agent"], **item})
    return {
        "schema_version": 1,
        "run_id": state["run_id"],
        "status": "in_progress",
        "input": state["input"],
        "platforms": state["routing"]["platforms"],
        "sources": [
            {
                "ref": source,
                "status": (
                    "read"
                    if state["nodes"]["product"]["status"] == "passed"
                    else "unread"
                ),
                "content_policy": "reference-only",
            }
            for source in state["input"]["source_refs"]
        ],
        "routing": state["routing"],
        "stages": stages,
        "attempts": {
            agent: node["attempt"] or 0 for agent, node in state["nodes"].items()
        },
        "execution": state["execution"],
        "artifacts": list(state["artifacts"]),
        "validation": validation,
        "accepted_gaps": _product_accepted_gaps(stages),
        "finalization_errors": list(state.get("finalization_errors", [])),
        "private_content_check": {"contains_private_source_bodies": False},
    }


def _final_gate_agent(state):
    return {
        "direct": "product",
        "standard": "test-verification",
        "full": "acceptance-reviewer",
    }.get(state.get("routing", {}).get("workflow_profile"), "acceptance-reviewer")


def finalize_run(run_path, state, policy):
    integrity_errors = []
    try:
        _validate_repository_privacy(state)
    except ValueError as error:
        integrity_errors.append(str(error))
    for relative_path, record in state.get("artifact_index", {}).items():
        path = workflow_workspace.resolve_under(run_path, relative_path)
        if not path.is_file():
            integrity_errors.append(f"referenced artifact is missing: {relative_path}")
        elif sha256_file(path) != record.get("sha256"):
            integrity_errors.append(f"artifact hash mismatch: {relative_path}")
    manifest = _manifest_from_state(state)
    if hasattr(manifest_validator, "derive_status"):
        status = manifest_validator.derive_status(manifest, policy, run_path=run_path)
    else:
        statuses = [node["status"] for node in state["nodes"].values()]
        if "blocked" in statuses:
            status = "blocked"
        elif "failed" in statuses:
            status = "failed"
        elif all(value in {"passed", "not_required"} for value in statuses):
            status = "passed"
        else:
            status = "blocked"
    if status != "blocked" and not integrity_errors and state.get("finalization_errors"):
        state.pop("finalization_errors", None)
        _write_state(run_path, state)
        manifest = _manifest_from_state(state)
    if (
        not state["input"].get("implementation_authorized")
        and state["nodes"]["product"]["status"] == "passed"
        and any(
            state["nodes"][platform]["status"] in {"pending", "failed"}
            for platform in state["routing"]["platforms"]
        )
    ):
        status = "blocked"
        state["finalization_errors"] = ["implementation is not authorized"]
        manifest = _manifest_from_state(state)
    elif integrity_errors:
        status = "blocked"
        state["finalization_errors"] = integrity_errors
        manifest = _manifest_from_state(state)
        _write_state(run_path, state)
    terminal_nodes = {
        node["status"] for node in state["nodes"].values()
    }.issubset({"passed", "not_required"})
    if status == "blocked" and terminal_nodes and not integrity_errors:
        candidate = dict(manifest)
        candidate["status"] = (
            "passed"
            if manifest.get("routing", {}).get("contract_status") == "confirmed"
            else "passed_with_mock_contract"
        )
        errors = manifest_validator.validate(candidate, policy, run_path=run_path)
        state["finalization_errors"] = errors
        gate = state["nodes"][_final_gate_agent(state)]
        gate.update(
            {
                "status": "blocked",
                "reason": errors[0] if errors else "final acceptance gate blocked",
            }
        )
        _write_state(run_path, state)
        manifest = _manifest_from_state(state)
    elif status in {"passed", "passed_with_mock_contract"}:
        state.pop("finalization_errors", None)
        _write_state(run_path, state)
        manifest = _manifest_from_state(state)
    manifest["status"] = status
    workflow_workspace.atomic_write_json(Path(run_path) / MANIFEST_FILE, manifest)
    return status


def main(argv):
    policy = load_policy()
    parser = argparse.ArgumentParser(
        description="Internal state runner for the ConvoAI delivery skill"
    )
    parser.add_argument("--resume")
    parser.add_argument("--name")
    parser.add_argument("--goal")
    parser.add_argument("--source", action="append")
    parser.add_argument(
        "--platform", action="append", choices=sorted(policy["platforms"])
    )
    parser.add_argument("--implementation-authorized", action="store_true")
    parser.add_argument(
        "--profile",
        choices=("auto", "direct", "standard", "full"),
        default="auto",
    )
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--native-result", action="append")
    parser.add_argument("--validate-native-result", action="append")
    parser.add_argument("--native-agent-id", action="append")
    parser.add_argument("--retry-blocked", action="store_true")
    args = parser.parse_args(argv[1:])
    if args.execute:
        raise ValueError(
            "--execute was replaced by native Agent dispatch; "
            "ingest native results with --resume, --native-result, and "
            "--native-agent-id"
        )
    if args.resume:
        run_path = _validated_resume_path(args.resume)
        native_results = args.native_result or []
        validation_results = args.validate_native_result or []
        native_agent_ids = args.native_agent_id or []
        if len(native_results) != len(native_agent_ids):
            raise ValueError(
                "--native-result and --native-agent-id must be provided in matching pairs"
            )
        if args.retry_blocked and native_results:
            raise ValueError("--retry-blocked cannot be combined with native results")
        if validation_results and (native_results or args.retry_blocked):
            raise ValueError(
                "--validate-native-result cannot be combined with ingestion or retry"
            )
        if validation_results:
            preflight_native_results(
                run_path,
                [(path, None) for path in validation_results],
                require_agent_ids=False,
            )
            outcome = {
                "run": str(run_path),
                "status": "preflight_passed",
                "validated": validation_results,
                "ready": native_dispatch(run_path),
            }
        elif args.retry_blocked:
            outcome = prepare_native_resume(run_path)
        elif native_results:
            outcome = ingest_native_results(
                run_path, list(zip(native_results, native_agent_ids))
            )
        else:
            state = _load_state(run_path)
            status = finalize_run(run_path, state, policy)
            outcome = {
                "run": str(run_path),
                "status": status,
                "ready": native_dispatch(run_path),
            }
    else:
        if args.retry_blocked:
            raise ValueError("--retry-blocked requires --resume")
        if args.native_result or args.native_agent_id or args.validate_native_result:
            raise ValueError("native results require --resume")
        if not all((args.name, args.goal, args.source, args.platform)):
            raise ValueError("new runs require name, goal, source, and platform")
        run_path = create_run(
            args.name,
            args.goal,
            args.source,
            args.platform,
            args.implementation_authorized,
            policy=policy,
            workflow_profile=args.profile,
        )
        outcome = {
            "run": str(run_path),
            "status": "in_progress",
            "ready": native_dispatch(run_path),
        }
    outcome["mode"] = "native"
    outcome_state = _load_state(run_path)
    outcome["workflow_profile"] = outcome_state["routing"].get(
        "workflow_profile"
    ) or outcome_state["input"].get("workflow_profile", "auto")
    print(json.dumps(outcome, indent=2))
    successful = {
        "in_progress",
        "preflight_passed",
        "passed_with_mock_contract",
        "passed",
    }
    return 0 if outcome["ready"] or outcome["status"] in successful else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except (json.JSONDecodeError, OSError, RuntimeError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(2)
