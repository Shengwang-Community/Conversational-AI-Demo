#!/usr/bin/env python3
import argparse
import hashlib
import re
import subprocess
import sys
from pathlib import Path

CREDENTIAL_ASSIGNMENT = re.compile(
    r"(?im)(?:^|[{\s,])['\"]?"
    r"(?P<key>[a-z0-9_-]*(?:api[\s_-]?key|client[\s_-]?secret|password|"
    r"access[\s_-]?token|app[\s_-]?certificate|ag[\s_-]?app[\s_-]?certificate|"
    r"ag[\s_-]?app[\s_-]?id|app[\s_-]?id))['\"]?\s*[:=]\s*['\"]?"
    r"(?P<value>[^'\"\s,}]+)"
)
AUTHORIZATION_ASSIGNMENT = re.compile(
    r"(?im)(?:^|[{\s,])['\"]?authorization['\"]?\s*[:=]\s*['\"]?"
    r"(?:basic|bearer)\s+(?P<value>[^'\"\s,}]+)"
)
APP_ID_LITERAL = re.compile(r"['\"](?P<value>[0-9a-fA-F]{32})['\"]")

PRIVATE_SOURCE_MARKERS = [
    "raw_" + "jira_body:",
    "raw_" + "confluence_body:",
    "raw_" + "lark_body:",
    "raw_" + "figma_payload:",
]

SKIPPED_DIRS = {"__pycache__", "pilot-runs"}
SKIPPED_SUFFIXES = {".pyc", ".pyo"}
CODE_SUFFIXES = {".java", ".js", ".kt", ".py", ".swift", ".ts", ".tsx"}


def iter_files(paths):
    for raw_path in paths:
        path = Path(raw_path)
        if path.is_dir():
            for child in path.rglob("*"):
                if SKIPPED_DIRS.intersection(child.parts) or child.suffix in SKIPPED_SUFFIXES:
                    continue
                if child.is_file():
                    yield child
        elif path.is_file():
            if "__pycache__" in path.parts or path.suffix in SKIPPED_SUFFIXES:
                continue
            yield path


def scan_text(text, source="<memory>"):
    errors = []
    folded = text.casefold()
    for marker in PRIVATE_SOURCE_MARKERS:
        offset = folded.find(marker.casefold())
        if offset >= 0:
            line = text.count("\n", 0, offset) + 1
            errors.append(f"{source}:{line}: private source marker found: {marker}")
    matches = [*CREDENTIAL_ASSIGNMENT.finditer(text), *AUTHORIZATION_ASSIGNMENT.finditer(text)]
    allow_code_expression = Path(str(source)).suffix.casefold() in CODE_SUFFIXES
    for match in matches:
        value_start = match.start("value")
        quoted = value_start > 0 and text[value_start - 1] in {"'", '"'}
        if not _is_placeholder(
            match.group("value"),
            allow_code_expression=allow_code_expression and not quoted,
        ):
            line = text.count("\n", 0, match.start("value")) + 1
            error = f"{source}:{line}: possible credential or token literal"
            if error not in errors:
                errors.append(error)
    for match in APP_ID_LITERAL.finditer(text):
        line = text.count("\n", 0, match.start("value")) + 1
        error = f"{source}:{line}: possible 32-character APPID literal"
        if error not in errors:
            errors.append(error)
    return errors


def _is_placeholder(value, allow_code_expression=False):
    normalized = value.strip().strip("'\"").casefold()
    if normalized in {
        "",
        "example",
        "sample",
        "test",
        "redacted",
        "masked",
        "changeme",
        "placeholder",
    }:
        return True
    if normalized.startswith(("<", "${", "your_", "your-")):
        return True
    if normalized in {"string", "string?", "str", "str?"}:
        return True
    if allow_code_expression and (
        any(character in value for character in (".", "?", "(", "[", "{"))
        or (re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", value) and any(c.isupper() for c in value))
    ):
        return True
    if normalized.startswith(
        ("test-", "test_", "example-", "example_", "sample-", "sample_", "fake-", "fake_", "dummy-", "dummy_")
    ):
        return True
    return normalized and set(normalized) == {"*"}


def scan_file(path):
    text = path.read_text(encoding="utf-8", errors="ignore")
    return scan_text(text, source=path)


def scan(paths):
    errors = []
    for path in iter_files(paths):
        errors.extend(scan_file(path))
    return errors


def _changed_lines(root):
    root = Path(root).resolve()
    completed = subprocess.run(
        ["git", "diff", "--unified=0", "--no-color", "HEAD", "--", "."],
        cwd=root,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise RuntimeError("unable to read changed lines for privacy scan")
    changed = {}
    current = None
    line_number = None
    for line in completed.stdout.splitlines():
        if line.startswith("+++ b/"):
            current = line[6:]
            changed.setdefault(current, [])
        elif line.startswith("@@"):
            match = re.search(r"\+(\d+)(?:,\d+)?", line)
            line_number = int(match.group(1)) if match else None
        elif current is not None and line_number is not None:
            if line.startswith("+") and not line.startswith("+++"):
                changed[current].append((line_number, line[1:]))
                line_number += 1
            elif not line.startswith("-"):
                line_number += 1
    untracked = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard", "-z"],
        cwd=root,
        capture_output=True,
    )
    if untracked.returncode != 0:
        raise RuntimeError("unable to read untracked files for privacy scan")
    for raw in filter(None, untracked.stdout.split(b"\0")):
        relative = Path(raw.decode(errors="surrogateescape"))
        path = root / relative
        if path.is_file():
            changed[str(relative)] = list(
                enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1)
            )
    return changed


def scan_changed_lines(root):
    return [
        f"{finding['path']}:{finding['line']}:{finding['message']}"
        for finding in changed_line_findings(root)
    ]


def changed_line_findings(root):
    findings = []
    for relative, lines in _changed_lines(root).items():
        groups = []
        for line_number, content in lines:
            if not groups or line_number != groups[-1][-1][0] + 1:
                groups.append([])
            groups[-1].append((line_number, content))
        for group in groups:
            start = group[0][0]
            text = "\n".join(content for _, content in group)
            content_sha256 = hashlib.sha256(text.encode("utf-8")).hexdigest()
            for error in scan_text(text, source=relative):
                prefix = f"{relative}:"
                remainder = error[len(prefix):]
                relative_line, _, message = remainder.partition(":")
                findings.append(
                    {
                        "path": relative,
                        "line": start + int(relative_line) - 1,
                        "message": message,
                        "content_sha256": content_sha256,
                    }
                )
    return findings


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="*")
    parser.add_argument("--changed-lines", metavar="REPOSITORY")
    args = parser.parse_args(argv[1:])
    if args.changed_lines and args.paths:
        parser.error("--changed-lines cannot be combined with paths")
    if not args.changed_lines and not args.paths:
        parser.error("paths or --changed-lines is required")
    errors = scan_changed_lines(args.changed_lines) if args.changed_lines else scan(args.paths)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("privacy scan passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
