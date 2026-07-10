#!/usr/bin/env python3
import json
import os
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
POLICY_PATH = ROOT / ".agents/skills/release-iteration/references/workflow-policy.json"


def load_policy(path=POLICY_PATH):
    with Path(path).open("r", encoding="utf-8") as handle:
        policy = json.load(handle)
    validate_policy(policy)
    return policy


def validate_policy(policy):
    if policy.get("surface") != "codex":
        raise ValueError("workflow policy surface must be codex")
    if policy.get("max_attempts") != 3:
        raise ValueError("workflow policy max_attempts must be 3")
    required_roles = {
        "product",
        "knowledge",
        "architect",
        "ux-design",
        "test-design",
        "test-verification",
        "ux-acceptance",
        "acceptance-reviewer",
    }
    if set(policy.get("roles", {})) != required_roles:
        raise ValueError("workflow policy roles are incomplete")
    if not policy.get("platforms"):
        raise ValueError("workflow policy must define platforms")
    if not policy.get("finding_routes"):
        raise ValueError("workflow policy must define finding routes")


def resolve_model(policy, alias, environ=None):
    values = environ if environ is not None else os.environ
    definition = policy["models"][alias]
    override = values.get(definition.get("env", ""), "").strip()
    return override or definition["default"]


def node_from_definition(
    node_id, definition, policy, initial_status="pending", environ=None
):
    node = deepcopy(definition)
    node.update(
        {
            "id": node_id,
            "initial_status": initial_status,
            "model": resolve_model(policy, definition["model"], environ=environ),
        }
    )
    return node


def expand_dag(policy, platforms, ux_required, environ=None):
    selected = list(platforms)
    if not selected or len(selected) != len(set(selected)):
        raise ValueError("platform selection must be non-empty and unique")
    unknown = sorted(set(selected) - set(policy["platforms"]))
    if unknown:
        raise ValueError(f"unknown platform: {', '.join(unknown)}")

    roles = policy["roles"]
    nodes = [
        node_from_definition("product", roles["product"], policy, environ=environ),
        node_from_definition("knowledge", roles["knowledge"], policy, environ=environ),
        node_from_definition("architect", roles["architect"], policy, environ=environ),
        node_from_definition(
            "ux-design",
            roles["ux-design"],
            policy,
            "pending" if ux_required else "not_required",
            environ=environ,
        ),
        node_from_definition("test-design", roles["test-design"], policy, environ=environ),
    ]
    for platform in selected:
        definition = deepcopy(policy["platforms"][platform])
        definition.update(
            {
                "required": True,
                "condition": "selected_platform",
                "depends_on": ["test-design"],
                "artifact": f"{platform}-result.json",
            }
        )
        nodes.append(node_from_definition(platform, definition, policy, environ=environ))
    verification = deepcopy(roles["test-verification"])
    verification["depends_on"] = selected
    nodes.append(
        node_from_definition(
            "test-verification", verification, policy, environ=environ
        )
    )
    nodes.append(
        node_from_definition(
            "ux-acceptance",
            roles["ux-acceptance"],
            policy,
            "pending" if ux_required else "not_required",
            environ=environ,
        )
    )
    nodes.append(
        node_from_definition(
            "acceptance-reviewer",
            roles["acceptance-reviewer"],
            policy,
            environ=environ,
        )
    )
    return nodes


def targets_for_findings(policy, findings, selected_platforms):
    routes = policy["finding_routes"]
    selected = list(selected_platforms)
    targets = []
    for finding in findings:
        category = finding.get("category")
        if category not in routes:
            raise ValueError(f"unknown finding category: {category}")
        route = routes[category]
        if route == "platform":
            owner = finding.get("owner")
            if owner not in selected:
                raise ValueError(f"finding platform owner is not selected: {owner}")
            routed = [owner]
        elif route == "platforms":
            routed = selected
        else:
            routed = [route]
        for target in routed:
            if target not in targets:
                targets.append(target)
    return targets
