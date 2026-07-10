#!/usr/bin/env python3
import json
import os
import stat
import subprocess
from pathlib import Path

from workflow_workspace import atomic_write_json, attempt_result_path


REQUIRED_ROLE_RESULT_FIELDS = {
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
    "validation",
}


def find_thread_id(events):
    for line in (events or "").splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        thread_id = event.get("thread_id") if isinstance(event, dict) else None
        if (
            isinstance(event, dict)
            and event.get("type") == "thread.started"
            and isinstance(thread_id, str)
            and 0 < len(thread_id) <= 200
        ):
            return thread_id
    return None


def _identity(path):
    try:
        metadata = Path(path).lstat()
    except FileNotFoundError:
        return None
    if not stat.S_ISREG(metadata.st_mode):
        return None
    return metadata.st_dev, metadata.st_ino


def _validate_role_result(result, node, attempt):
    if not isinstance(result, dict):
        raise ValueError("role result must be an object")
    missing = REQUIRED_ROLE_RESULT_FIELDS - set(result)
    if missing:
        raise ValueError(
            f"role result missing fields: {', '.join(sorted(missing))}"
        )
    if result["agent"] != node["id"]:
        raise ValueError(f"role result agent must be {node['id']}")
    if result["attempt"] != attempt:
        raise ValueError(f"role result attempt must be {attempt}")
    if result["status"] not in {"passed", "failed", "blocked", "not_required"}:
        raise ValueError("role result status is invalid")
    if not isinstance(result["summary"], str) or not result["summary"].strip():
        raise ValueError("role result summary must be non-empty")
    if not isinstance(result["outputs"], dict):
        raise ValueError("role result outputs must be an object")
    if not isinstance(result["source_refs"], list):
        raise ValueError("role result source_refs must be a list")
    for field in ("artifacts", "findings", "gaps", "accepted_gaps", "validation"):
        if not isinstance(result[field], list):
            raise ValueError(f"role result {field} must be a list")


class CodexExecutor:
    def __init__(
        self,
        root,
        output_schema,
        privacy_module,
        subprocess_run=subprocess.run,
    ):
        self.root = Path(root).resolve()
        self.output_schema = Path(output_schema).resolve()
        self.privacy = privacy_module
        self.subprocess_run = subprocess_run

    def build_command(self, run_path, node, pending_output):
        relative_working_directory = Path(node["working_directory"])
        if relative_working_directory.is_absolute():
            raise ValueError("working directory escapes repository root")
        working_directory = (self.root / relative_working_directory).resolve()
        if working_directory != self.root and self.root not in working_directory.parents:
            raise ValueError("working directory escapes repository root")
        if not working_directory.is_dir():
            raise ValueError(f"working directory does not exist: {working_directory}")
        if node["sandbox"] not in {"read-only", "workspace-write"}:
            raise ValueError(f"unsupported sandbox: {node['sandbox']}")
        command = [
            "codex",
            "exec",
            "-m",
            node["model"],
            "-c",
            f'model_reasoning_effort="{node["reasoning_effort"]}"',
            "-s",
            node["sandbox"],
            "-C",
            str(working_directory),
            "--add-dir",
            str(Path(run_path).resolve()),
            "--ephemeral",
            "--json",
            "--output-schema",
            str(self.output_schema),
            "-o",
            str(pending_output),
            "-",
        ]
        return command, working_directory

    def execute(self, run_path, node, prompt, attempt):
        run_path = Path(run_path).resolve()
        output = attempt_result_path(run_path, attempt, node["id"])
        pending = output.with_suffix(output.suffix + ".pending")
        pending.parent.mkdir(parents=True, exist_ok=True)
        command, working_directory = self.build_command(run_path, node, pending)
        if pending.exists() or pending.is_symlink():
            raise RuntimeError(f"pending output already exists: {pending}")
        descriptor = os.open(
            pending,
            os.O_CREAT | os.O_EXCL | os.O_WRONLY | getattr(os, "O_NOFOLLOW", 0),
            0o600,
        )
        metadata = os.fstat(descriptor)
        owned_identity = metadata.st_dev, metadata.st_ino
        os.close(descriptor)
        try:
            completed = self.subprocess_run(
                command,
                input=prompt,
                text=True,
                capture_output=True,
                cwd=working_directory,
            )
            if completed.returncode != 0:
                raise RuntimeError(
                    f"Codex role failed for {node['id']} with exit {completed.returncode}"
                )
            thread_id = find_thread_id(completed.stdout)
            if not thread_id or _identity(pending) != owned_identity:
                raise RuntimeError(
                    f"Codex role output or thread provenance missing: {node['id']}"
                )
            flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
            descriptor = os.open(pending, flags)
            try:
                metadata = os.fstat(descriptor)
                if (metadata.st_dev, metadata.st_ino) != owned_identity:
                    raise RuntimeError("pending role output changed during execution")
                with os.fdopen(descriptor, "r", encoding="utf-8") as handle:
                    descriptor = None
                    content = handle.read()
            finally:
                if descriptor is not None:
                    os.close(descriptor)
            if not content:
                raise RuntimeError(
                    f"Codex role output or thread provenance missing: {node['id']}"
                )
            errors = self.privacy.scan_text(content, source=str(pending))
            if errors:
                raise RuntimeError(f"private role output rejected: {errors[0]}")
            role_result = json.loads(content)
            _validate_role_result(role_result, node, attempt)
            atomic_write_json(output, role_result)
        finally:
            if _identity(pending) == owned_identity:
                pending.unlink()

        return {
            "result": role_result,
            "provenance": {
                "agent": node["id"],
                "attempt": attempt,
                "thread_id": thread_id,
                "model": node["model"],
                "reasoning_effort": node["reasoning_effort"],
                "sandbox": node["sandbox"],
                "working_directory": node["working_directory"],
                "output": str(output.relative_to(run_path)),
                "result": "completed",
            },
        }
