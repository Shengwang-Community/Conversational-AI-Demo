#!/usr/bin/env python3
import hashlib
import json
import os
import stat
import tempfile
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path


INVALIDATES = {
    "product": [
        "knowledge",
        "architect",
        "ux-design",
        "test-design",
        "platforms",
        "test-verification",
        "ux-acceptance",
        "acceptance-reviewer",
    ],
    "knowledge": [
        "architect",
        "ux-design",
        "test-design",
        "platforms",
        "test-verification",
        "ux-acceptance",
        "acceptance-reviewer",
    ],
    "architect": [
        "ux-design",
        "test-design",
        "platforms",
        "test-verification",
        "ux-acceptance",
        "acceptance-reviewer",
    ],
    "ux-design": [
        "test-design",
        "platforms",
        "test-verification",
        "ux-acceptance",
        "acceptance-reviewer",
    ],
    "test-design": [
        "platforms",
        "test-verification",
        "ux-acceptance",
        "acceptance-reviewer",
    ],
    "platforms": [
        "test-verification",
        "ux-acceptance",
        "acceptance-reviewer",
    ],
    "test-verification": ["ux-acceptance", "acceptance-reviewer"],
    "ux-acceptance": ["acceptance-reviewer"],
}


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def resolve_under(base, relative_path):
    base = Path(base).resolve()
    path = Path(relative_path)
    if path.is_absolute():
        raise ValueError(f"absolute artifact path is not allowed: {relative_path}")
    resolved = (base / path).resolve()
    if resolved != base and base not in resolved.parents:
        raise ValueError(f"path escapes run workspace: {relative_path}")
    return resolved


def canonical_hash(value):
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode(
        "utf-8"
    )
    return hashlib.sha256(encoded).hexdigest()


def _regular_file_identity(path):
    try:
        metadata = path.lstat()
    except FileNotFoundError:
        return None
    if not stat.S_ISREG(metadata.st_mode):
        return None
    return metadata.st_dev, metadata.st_ino


def _unlink_owned_regular_file(path, identity):
    if identity is not None and _regular_file_identity(path) == identity:
        path.unlink()


def atomic_write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    parent = path.parent.resolve()
    path = parent / path.name
    descriptor, pending_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=parent
    )
    pending = Path(pending_name)
    identity = None
    try:
        metadata = os.fstat(descriptor)
        identity = metadata.st_dev, metadata.st_ino
        handle = os.fdopen(descriptor, "w", encoding="utf-8")
        descriptor = None
        with handle:
            handle.write(json.dumps(value, indent=2) + "\n")
            handle.flush()
        pending.replace(path)
        identity = None
    finally:
        if descriptor is not None:
            os.close(descriptor)
        _unlink_owned_regular_file(pending, identity)


def load_json(path):
    with Path(path).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def initial_state(run_id, run_input, node_ids, max_attempts):
    input_snapshot = deepcopy(run_input)
    return {
        "schema_version": 1,
        "run_id": run_id,
        "input": input_snapshot,
        "input_hash": canonical_hash(input_snapshot),
        "attempt": 1,
        "max_attempts": max_attempts,
        "nodes": {
            node_id: {
                "status": "pending",
                "attempt": None,
                "input_hash": None,
                "artifact_hash": None,
                "reason": None,
            }
            for node_id in node_ids
        },
        "events": [],
    }


def expanded_targets(state, targets):
    platform_ids = [
        node_id for node_id in state["nodes"] if node_id in {"android", "ios"}
    ]
    result = []
    for target in targets:
        result.extend(platform_ids if target == "platforms" else [target])
    return [target for target in result if target in state["nodes"]]


def invalidate_from(state, node_id, reason):
    queue = list(INVALIDATES.get(node_id, []))
    visited = set()
    invalidated = []
    while queue:
        target = queue.pop(0)
        for concrete in expanded_targets(state, [target]):
            if concrete in visited:
                continue
            visited.add(concrete)
            node = state["nodes"][concrete]
            if node["status"] != "not_required":
                node.update(
                    {
                        "status": "pending",
                        "reason": reason,
                        "input_hash": None,
                        "artifact_hash": None,
                    }
                )
                invalidated.append(concrete)
            queue.extend(INVALIDATES.get(concrete, []))
    state["events"].append(
        {
            "type": "invalidation",
            "source": node_id,
            "targets": invalidated,
            "reason": reason,
            "at": now_iso(),
        }
    )
    return invalidated


def resume_candidates(state):
    return [
        node_id
        for node_id, node in state["nodes"].items()
        if node["status"] in {"pending", "running", "blocked", "failed"}
    ]


def attempt_result_path(run_path, attempt, agent):
    return resolve_under(
        run_path, f"attempts/{attempt:02d}/role-results/{agent}.json"
    )


def promote_artifact(run_path, relative_path, content, privacy_scan):
    run_path = Path(run_path).resolve()
    destination = resolve_under(run_path, relative_path)
    if destination == run_path or destination.is_dir():
        raise ValueError(f"artifact destination must be a file: {relative_path}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    pending = destination.with_suffix(destination.suffix + ".pending")
    identity = None
    try:
        with pending.open("x", encoding="utf-8") as handle:
            metadata = os.fstat(handle.fileno())
            identity = metadata.st_dev, metadata.st_ino
            handle.write(content)
        errors = privacy_scan([str(pending)])
        if errors:
            raise RuntimeError(errors[0])
        if _regular_file_identity(pending) != identity:
            raise RuntimeError("pending artifact changed before promotion")
        pending.replace(destination)
        identity = None
        return destination
    finally:
        _unlink_owned_regular_file(pending, identity)
