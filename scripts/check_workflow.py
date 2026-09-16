#!/usr/bin/env python3
"""Check workflow entrypoints, platform configuration and test wiring without builds."""

import argparse
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
from validate import ROOT, config, suite_checks

SKILLS = ["ac-workflow", "ac-memory", "ac-plan", "ac-execute", "ac-review",
          "requesting-code-review", "receiving-code-review", "writing-skills"]
SHARED_FILES = ["AGENTS.md", "CLAUDE.md", "AI_WORKFLOW.md", "scripts/validate.py",
                "scripts/check_workflow.py", "scripts/tests/test_validation.py",
                "Android/docs/TASK_STATE_TEMPLATE.md", "Android/docs/STATE_INDEX_TEMPLATE.md",
                "Android/docs/REVIEW_TEMPLATES.md", "iOS/docs/TASK_STATE_TEMPLATE.md",
                "iOS/docs/STATE_INDEX_TEMPLATE.md",
                "Android/.agents/skills/requesting-code-review/code-reviewer.md"]
SHARED_FILES += [f"Android/.agents/skills/{name}/SKILL.md" for name in SKILLS]
SHARED_FILES += [f"Android/.agents/skills/{name}/agents/openai.yaml" for name in SKILLS[:5]]
SHARED_FILES += ["iOS/.agents/skills/convoai-ios-workflow/" + name for name in
                 ["SKILL.md", "agents/openai.yaml", "references/contracts.md", "references/ios_logic_ut.md"]]


def check(root, peer=None):
    cfg = config(root)
    errors = []
    app = (root / "Android/app/build.gradle").read_text()
    match = re.search(r"productFlavors\s*\{\s*(\w+)\s*\{", app)
    flavor = cfg["android"]["flavor"]
    if not match or match[1] != flavor:
        errors.append(f"Configured Android flavor {flavor} does not match app/build.gradle")
    expected = ":app:assemble" + flavor.capitalize() + "Debug"
    if expected not in (root / "Android/AGENTS.md").read_text():
        errors.append(f"Android/AGENTS.md must document {expected}")
    other = "China" if flavor == "global" else "Global"
    if "assemble" + other in (root / "Android/AGENTS.md").read_text():
        errors.append("Android instructions request the other brand's APK")
    if f":app:test{flavor.capitalize()}DebugUnitTest" not in cfg["android"]["test_tasks"]:
        errors.append("App UT task does not match flavor")
    if cfg["android"]["lint_tasks"] != [f":app:lint{flavor.capitalize()}Debug"]:
        errors.append("App lint task does not match flavor")
    if len(cfg["android"]["test_reports"]) != len(cfg["android"]["test_tasks"]):
        errors.append("Each Android UT task must have an expected report directory")
    for rel in cfg["android"]["test_reports"]:
        path = Path(rel)
        if path.is_absolute() or ".." in path.parts or "build/test-results" not in rel:
            errors.append(f"Unsafe test report path: {rel}")
    for name, suite in cfg["ios"]["suites"].items():
        try:
            scheme = suite_checks(root, suite, require_container=False)
            ignored = subprocess.run(["git", "check-ignore", "-q", str(scheme)], cwd=root).returncode
            if ignored == 0:
                errors.append(f"Suite {name}: shared scheme is ignored by Git")
        except (OSError, ValueError, KeyError, ET.ParseError) as error:
            errors.append(f"Suite {name}: {error}")
    assets = SHARED_FILES + ["Android/AGENTS.md", "Android/docs/WORKFLOW_TEMPLATES.md",
                            "iOS/AGENTS.md", "iOS/CLAUDE.md", "iOS/docs/VALIDATION.md"]
    for rel in assets:
        path = root / rel
        if not path.is_file():
            errors.append(f"Missing workflow asset: {rel}")
            continue
        if path.suffix != ".md":
            continue
        text = path.read_text()
        if path.name == "SKILL.md":
            if not re.match(r"---\nname: [a-z0-9-]+\ndescription: .+\n---", text):
                errors.append(f"Invalid skill frontmatter: {rel}")
        for target in re.findall(r"(?<!!)\[[^\]]+\]\(([^\s)]+)\)", text):
            if "://" in target or target.startswith("#"):
                continue
            dest = path.parent / target.split("#", 1)[0]
            if not dest.exists():
                errors.append(f"Broken link in {rel}: {target}")
    policy = root / "iOS/.agents/skills/convoai-ios-workflow/agents/openai.yaml"
    if "allow_implicit_invocation: true" not in policy.read_text():
        errors.append("Normal iOS requests must be able to invoke the workflow")
    if peer:
        for rel in SHARED_FILES:
            if not (peer / rel).is_file() or (root / rel).read_bytes() != (peer / rel).read_bytes():
                errors.append(f"Shared workflow drift: {rel}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--peer", type=Path, help="Optionally compare shared assets with the sibling checkout")
    args = parser.parse_args()
    errors = check(ROOT, args.peer)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Workflow checks passed: {config()['brand']}; platform commands, schemes, test sources and links are consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
