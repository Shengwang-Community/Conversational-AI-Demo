#!/usr/bin/env python3
import argparse
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TOOLS_DIR = Path(__file__).parent
POLICY_PATH = ROOT / ".agents/skills/release-iteration/references/workflow-policy.json"
OUTPUT_SCHEMA = ROOT / ".agents/skills/release-iteration/templates/role-result.schema.json"
RUNS_DIR = ROOT / "docs/ai-engineering/pilot-runs"
STATE_FILE = "run-state.json"
INPUT_FILE = "run-input.json"
MANIFEST_FILE = "acceptance-manifest.json"

ROLE_CONTRACTS = {
    "product": "Read every declared source. Return exact source_refs plus outputs: ux_required, ux_reason, platforms, and acceptance_criteria.",
    "knowledge": "Ground the requirement in current repository behavior and platform-owned guidance; identify constraints and unresolved evidence.",
    "architect": "Return outputs: hld_required and hld_rationale. When required, include approved hld_review metadata and hld.md.",
    "ux-design": "Define user-visible interaction, copy, visual states, and UX acceptance criteria without implementing product code.",
    "test-design": "Return covered_criteria for every Product acceptance criterion and a test matrix spanning selected platforms.",
    "test-verification": "Independently verify platform evidence and covered_criteria. Do not modify tracked repository files.",
    "ux-acceptance": "Compare the implementation evidence against UX Design and report concrete findings.",
    "acceptance-reviewer": "Review current evidence independently in read-only mode and route each finding to a policy category and owner.",
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
codex_executor = load_module("codex_executor", "codex_executor.py")
manifest_validator = load_module(
    "acceptance_validator", "validate_acceptance_manifest.py"
)


def load_policy(path=POLICY_PATH):
    return workflow_policy.load_policy(path)


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
    return workflow_workspace.load_json(_state_path(run_path))


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
):
    policy = policy or load_policy()
    selected = list(platforms)
    _validate_inputs(goal, source_refs, selected, policy)
    current = today or date.today().isoformat()
    run_path = Path(RUNS_DIR) / f"{current}-{slugify(name)}"
    if run_path.exists() and any(run_path.iterdir()):
        raise FileExistsError(f"run workspace already exists: {run_path}")
    run_path.mkdir(parents=True, exist_ok=True)
    ensure_ignored(run_path / STATE_FILE)

    run_input = {
        "name": name,
        "goal": goal,
        "source_refs": list(source_refs),
        "platforms": selected,
        "implementation_authorized": bool(implementation_authorized),
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
        }
    )
    workflow_workspace.atomic_write_json(run_path / INPUT_FILE, run_input)
    _write_state(run_path, state)
    finalize_run(run_path, state, policy)
    return run_path


def build_prompt(run_path, state, node, attempt):
    agent = node["id"]
    contract = ROLE_CONTRACTS.get(
        agent,
        "Follow the existing platform workflow, implement only this platform, and return changed files and validation evidence.",
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
        "expected_artifact": node["artifact"],
        "upstream_artifacts": list(state.get("artifacts", [])),
        "finalization_errors": list(state.get("finalization_errors", [])),
        "workflow_entrypoints": entrypoints,
        "run_workspace": str(Path(run_path).resolve()),
    }
    prompt = (
        "Execute this ConvoAI Demo product-delivery role. Follow repository-local "
        "instructions, keep private requirement content in the run workspace, and "
        "return only the configured role-result JSON. Findings must use a category "
        "defined by workflow-policy.json and identify the owning role or platform.\n\n"
        f"Required role contract:\n{contract}\n\n"
        + json.dumps(context, indent=2)
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
    promoted = []
    for item in artifacts:
        if not isinstance(item, dict) or set(item) != {"path", "content"}:
            raise ValueError(f"invalid artifact record for {agent}")
        if item["path"] not in allowed:
            raise ValueError(f"unexpected artifact for {agent}: {item['path']}")
        content = item["content"]
        if not isinstance(content, str):
            content = json.dumps(content, indent=2) + "\n"
        destination = workflow_workspace.promote_artifact(
            run_path, item["path"], content, privacy.scan
        )
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
    state["routing"].update(
        {
            "platforms": selected,
            "ux_required": ux_required,
            "ux_reason": ux_reason,
        }
    )
    for node_id in ("ux-design", "ux-acceptance"):
        node = state["nodes"][node_id]
        if ux_required and node["status"] == "not_required":
            node.update({"status": "pending", "reason": None})
        elif not ux_required:
            workflow_workspace.discard_node_output(state, node_id)
            node.update({"status": "not_required", "reason": ux_reason})
    for platform in set(declared) - set(selected):
        state["nodes"][platform].update(
            {"status": "not_required", "reason": "not confirmed by Product"}
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


def _nodes_for_state(policy, state):
    ux_required = state["routing"]["ux_required"] is not False
    return {
        node["id"]: node
        for node in workflow_policy.expand_dag(
            policy, state["routing"]["platforms"], ux_required
        )
    }


def _validate_role_result(role_result, agent, attempt, state):
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


def _persist_execution(run_path, state, role_result, provenance):
    agent = role_result["agent"]
    attempt = role_result["attempt"]
    result_path = workflow_workspace.attempt_result_path(run_path, attempt, agent)
    promoted = materialize_role_artifacts(run_path, role_result)
    workflow_workspace.atomic_write_json(result_path, role_result)
    for path in promoted:
        if path not in state["artifacts"]:
            state["artifacts"].append(path)
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
            "validation": [],
        },
        "provenance": {
            "agent": agent,
            "attempt": attempt,
            "thread_id": None,
            "model": node["model"],
            "reasoning_effort": node["reasoning_effort"],
            "sandbox": node["sandbox"],
            "working_directory": node["working_directory"],
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
    if target in {"android", "ios"}:
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


def _prepare_retry(run_path, state, targets, reason):
    repair_attempt = state.get("repair_attempt", 1)
    if repair_attempt >= state["max_attempts"]:
        return False
    state["attempt"] += 1
    state["repair_attempt"] = repair_attempt + 1
    state["execution"]["repair_attempt"] = state["repair_attempt"]
    for target in targets:
        _schedule_target(state, target, reason)
    _write_state(run_path, state)
    return True


def _route_findings(run_path, state, policy, results):
    findings = [
        finding
        for result in results
        for finding in result.get("findings", [])
    ]
    if not findings:
        return None
    try:
        targets = workflow_policy.targets_for_findings(
            policy, findings, state["routing"]["platforms"]
        )
    except ValueError as error:
        for result in results:
            if result.get("findings"):
                state["nodes"][result["agent"]].update(
                    {"status": "blocked", "reason": str(error)}
                )
        _write_state(run_path, state)
        return "blocked"
    if "blocked" in targets:
        for result in results:
            if result.get("findings"):
                state["nodes"][result["agent"]].update(
                    {"status": "blocked", "reason": "external finding blocks run"}
                )
        _write_state(run_path, state)
        return "blocked"
    if _prepare_retry(run_path, state, targets, "finding repair"):
        return "retry"
    for result in results:
        if result.get("findings"):
            state["nodes"][result["agent"]]["status"] = "failed"
    _write_state(run_path, state)
    return "exhausted"


def _run_acceptance_for_blocked(run_path, state, policy, executor):
    nodes = _nodes_for_state(policy, state)
    reviewer = state["nodes"].get("acceptance-reviewer")
    if reviewer and reviewer["status"] not in {"passed", "blocked"}:
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
    executor = executor or codex_executor.CodexExecutor(
        ROOT, OUTPUT_SCHEMA, privacy
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


def resume_run(run_path, executor=None):
    run_path = _validated_resume_path(run_path)
    state = _load_state(run_path)
    state.setdefault("repair_attempt", 1)
    state["execution"].setdefault("repair_attempt", state["repair_attempt"])
    current_input = workflow_workspace.load_json(run_path / INPUT_FILE)
    current_hash = workflow_workspace.canonical_hash(current_input)
    if current_hash != state["input_hash"]:
        state["input"] = current_input
        state["input_hash"] = current_hash
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
        "validation": [],
    }


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
    accepted_gaps = []
    for stage in stages:
        for item in stage.get("validation", []):
            validation.append({"agent": stage["agent"], **item})
        accepted_gaps.extend(stage.get("accepted_gaps", []))
    return {
        "schema_version": 1,
        "run_id": state["run_id"],
        "status": "blocked",
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
        "accepted_gaps": accepted_gaps,
        "finalization_errors": list(state.get("finalization_errors", [])),
        "private_content_check": {"contains_private_source_bodies": False},
    }


def finalize_run(run_path, state, policy):
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
    terminal_nodes = {
        node["status"] for node in state["nodes"].values()
    }.issubset({"passed", "not_required"})
    if status == "blocked" and terminal_nodes:
        candidate = dict(manifest)
        candidate["status"] = "passed"
        errors = manifest_validator.validate(candidate, policy, run_path=run_path)
        state["finalization_errors"] = errors
        reviewer = state["nodes"]["acceptance-reviewer"]
        reviewer.update(
            {
                "status": "blocked",
                "reason": errors[0] if errors else "final acceptance gate blocked",
            }
        )
        _write_state(run_path, state)
        manifest = _manifest_from_state(state)
    elif status == "passed":
        state.pop("finalization_errors", None)
        _write_state(run_path, state)
        manifest = _manifest_from_state(state)
    manifest["status"] = status
    workflow_workspace.atomic_write_json(Path(run_path) / MANIFEST_FILE, manifest)
    return status


def main(argv):
    policy = load_policy()
    parser = argparse.ArgumentParser(
        description="Run the repo-level ConvoAI Demo product workflow"
    )
    parser.add_argument("--resume")
    parser.add_argument("--name")
    parser.add_argument("--goal")
    parser.add_argument("--source", action="append")
    parser.add_argument(
        "--platform", action="append", choices=sorted(policy["platforms"])
    )
    parser.add_argument("--implementation-authorized", action="store_true")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args(argv[1:])
    if args.resume:
        if not args.execute:
            raise ValueError("--resume requires --execute")
        run_path = _validated_resume_path(args.resume)
        run_input_path = run_path / INPUT_FILE
        run_input = workflow_workspace.load_json(run_input_path)
        if not run_input.get("implementation_authorized"):
            run_input["implementation_authorized"] = True
            workflow_workspace.atomic_write_json(run_input_path, run_input)
        status = resume_run(run_path)
    else:
        if not all((args.name, args.goal, args.source, args.platform)):
            raise ValueError("new runs require name, goal, source, and platform")
        run_path = create_run(
            args.name,
            args.goal,
            args.source,
            args.platform,
            args.implementation_authorized or args.execute,
            policy=policy,
        )
        status = execute_run(run_path) if args.execute else "created"
    print(json.dumps({"run": str(run_path), "status": status}, indent=2))
    return 0 if status in {"created", "passed"} else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except (json.JSONDecodeError, OSError, RuntimeError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(2)
