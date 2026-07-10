#!/usr/bin/env python3
import argparse
import re
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

PRIVATE_SOURCE_MARKERS = [
    "raw_" + "jira_body:",
    "raw_" + "confluence_body:",
    "raw_" + "lark_body:",
    "raw_" + "figma_payload:",
]

SKIPPED_DIRS = {"__pycache__"}
SKIPPED_SUFFIXES = {".pyc", ".pyo"}


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
            if SKIPPED_DIRS.intersection(path.parts) or path.suffix in SKIPPED_SUFFIXES:
                continue
            yield path


def scan_text(text, source="<memory>"):
    errors = []
    folded = text.casefold()
    for marker in PRIVATE_SOURCE_MARKERS:
        if marker.casefold() in folded:
            errors.append(f"{source}: private source marker found: {marker}")
    matches = [*CREDENTIAL_ASSIGNMENT.finditer(text), *AUTHORIZATION_ASSIGNMENT.finditer(text)]
    if any(not _is_placeholder(match.group("value")) for match in matches):
        errors.append(f"{source}: possible credential or token literal")
    return errors


def _is_placeholder(value):
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
    return normalized and set(normalized) == {"*"}


def scan_file(path):
    text = path.read_text(encoding="utf-8", errors="ignore")
    return scan_text(text, source=path)


def scan(paths):
    errors = []
    for path in iter_files(paths):
        errors.extend(scan_file(path))
    return errors


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args(argv[1:])
    errors = scan(args.paths)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("privacy scan passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
