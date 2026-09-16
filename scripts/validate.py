#!/usr/bin/env python3
"""Repository validation entrypoint. Uses only Python's standard library."""

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def config(root=ROOT):
    return json.loads((root / "scripts/workflow.json").read_text())


def project_block(project, identifier):
    match = re.search(
        rf"^\s*{re.escape(identifier)} /\*[^\n]*?\*/ = \{{\n(.*?)^\t\t\}};",
        project, re.M | re.S,
    )
    if not match:
        raise ValueError(f"Missing project object: {identifier}")
    return match.group(1)


def suite_checks(root, suite, require_container=True):
    ios = root / "iOS"
    container = ios / suite["container"]
    if require_container and not container.exists():
        raise ValueError(f"Missing {container}; hosted tests require pod install first")
    scheme = ios / "Agent.xcodeproj/xcshareddata/xcschemes" / (suite["scheme"] + ".xcscheme")
    tree = ET.parse(scheme)
    refs = [ref.find("BuildableReference") for ref in tree.findall(".//TestableReference")
            if ref.get("skipped", "NO") != "YES"]
    targets = {ref.get("BlueprintName"): ref.get("BlueprintIdentifier")
               for ref in refs if ref is not None}
    if suite["target"] not in targets:
        raise ValueError(f"{scheme}: missing enabled Testable {suite['target']}")
    project = (ios / "Agent.xcodeproj/project.pbxproj").read_text()
    target = project_block(project, targets[suite["target"]])
    phase_ids = re.findall(r"([A-F0-9]{24}) /\* Sources \*/", target)
    sources = "\n".join(project_block(project, ident) for ident in phase_ids)
    if not suite["tests"]:
        raise ValueError(f"{suite['scheme']}: no tests configured")
    for test in suite["tests"]:
        path = ios / test["source"]
        text = path.read_text()
        if not re.search(r"\bclass\s+" + re.escape(test["class"]) + r"\b", text):
            raise ValueError(f"Missing test class {test['class']} in {path}")
        if not re.search(r"\bfunc\s+test\w*\s*\(", text):
            raise ValueError(f"No XCTest methods in {path}")
        if f"/* {path.name} in Sources */" not in sources:
            raise ValueError(f"{path} is not compiled by {suite['target']}")
    # Standalone test bundles intentionally have no MacroExpansion/test host.
    if suite["container"].endswith(".xcworkspace") and tree.find(".//MacroExpansion/BuildableReference") is None:
        raise ValueError(f"{scheme}: hosted tests need MacroExpansion")
    return scheme


def junit_counts(paths):
    counts = dict(passed=0, failed=0, skipped=0)
    for directory in paths:
        files = sorted(directory.glob("TEST-*.xml"))
        cases = [case for path in files for case in ET.parse(path).getroot().iter("testcase")]
        if not cases:
            raise ValueError(f"No JUnit test cases in {directory}")
        executed = 0
        for case in cases:
            if case.find("skipped") is not None:
                counts["skipped"] += 1
            elif case.find("failure") is not None or case.find("error") is not None:
                counts["failed"] += 1
                executed += 1
            else:
                counts["passed"] += 1
                executed += 1
        if executed == 0:
            raise ValueError(f"All tests skipped in {directory}")
    return require_tests(counts)


def require_tests(counts):
    if any(type(value) is not int or value < 0 for value in counts.values()):
        raise ValueError("Invalid test counts")
    if counts["failed"] or counts["passed"] == 0:
        raise ValueError(f"Tests did not pass with executed cases: {counts}")
    return counts


def xcresult_counts(summary):
    # Xcode 16+ xcresulttool get test-results summary schema.
    if summary.get("result") != "Passed":
        raise ValueError(f"xcresult did not pass: {summary.get('result')}")
    return require_tests({"passed": summary["passedTests"], "failed": summary["failedTests"],
                          "skipped": summary["skippedTests"]})


def json_command(command, cwd=ROOT):
    result = subprocess.run(command, cwd=cwd, check=True, text=True, stdout=subprocess.PIPE)
    return json.loads(result.stdout)


def simulator(destination=None):
    data = json_command(["xcrun", "simctl", "list", "devices", "available", "-j"])
    devices = [device for runtime in data["devices"].values() for device in runtime
               if device.get("isAvailable") and device.get("name", "").startswith("iPhone")]
    if destination:
        devices = [d for d in devices if d["udid"] == destination]
    devices.sort(key=lambda d: d["state"] != "Booted")
    if not devices:
        raise ValueError("No matching available iPhone simulator; install a runtime or set IOS_SIMULATOR_UDID")
    return devices[0]


def run_logged(command, cwd, log):
    print("$ " + shlex.join(command), flush=True)
    with log.open("a") as stream:
        stream.write("$ " + shlex.join(command) + "\n")
        stream.flush()
        result = subprocess.run(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        raise subprocess.CalledProcessError(result.returncode, command)


@contextmanager
def build_lock(derived_data):
    lock = Path(str(derived_data) + ".lock")
    lock.parent.mkdir(parents=True, exist_ok=True)
    try:
        lock.mkdir()
    except FileExistsError:
        raise ValueError(f"DerivedData is in use: {derived_data}; verify ownership before removing stale {lock}")
    try:
        yield
    finally:
        lock.rmdir()


def run_ios(args, root, cfg, output, evidence):
    suites = cfg["ios"]["suites"]
    if args.suite not in suites:
        raise ValueError(f"Unknown suite {args.suite!r}; available: {', '.join(suites)}")
    suite = suites[args.suite]
    if args.scheme:
        scheme = args.scheme
        if scheme == cfg["ios"]["app_target"]:
            scheme = cfg["ios"].get("integration_scheme", scheme)
        suite = next((value for value in suites.values() if value["scheme"] == scheme), None)
        if suite is None:
            raise ValueError(f"Unconfigured test scheme {scheme}; add its actual test scope to scripts/workflow.json")
    suite = dict(suite)
    if args.container:
        supplied = (root / "iOS" / args.container).resolve()
        expected = (root / "iOS" / suite["container"]).resolve()
        if supplied != expected:
            raise ValueError(f"Scheme {suite['scheme']} uses {expected}, not {supplied}")
    scheme_file = suite_checks(root, suite)
    selected = args.only_testing or [suite["target"] + "/" + test["class"] for test in suite["tests"]]
    known = {test["class"]: root / "iOS" / test["source"] for test in suite["tests"]}
    for ident in selected:
        parts = ident.split("/")
        if not 1 <= len(parts) <= 3 or parts[0] != suite["target"] or (len(parts) > 1 and parts[1] not in known):
            raise ValueError(f"Unknown test identifier: {ident}")
        if len(parts) == 3 and not re.search(r"\bfunc\s+" + re.escape(parts[2].removesuffix("()")) + r"\s*\(", known[parts[1]].read_text()):
            raise ValueError(f"Unknown test method: {ident}")
    evidence.update(scheme=suite["scheme"], selected_tests=selected, scheme_file=str(scheme_file))
    device = simulator(args.destination or os.environ.get("IOS_SIMULATOR_UDID"))
    evidence["simulator"] = device["udid"]
    if args.preflight:
        evidence["status"] = "preflight-only"
        return
    log = output / "xcodebuild.log"
    if device["state"] != "Booted":
        run_logged(["xcrun", "simctl", "boot", device["udid"]], root, log)
    run_logged(["xcrun", "simctl", "bootstatus", device["udid"], "-b"], root, log)
    arch = os.environ.get("SIM_ARCH", "")
    if arch not in ("", "arm64", "x86_64"):
        raise ValueError(f"Invalid SIM_ARCH: {arch}")
    key = hashlib.sha256(str(root).encode()).hexdigest()[:12]
    derived = Path(args.derived_data) if args.derived_data else Path(tempfile.gettempdir()) / "convoai-validation" / key / suite["scheme"] / (arch or "native") / "DerivedData"
    result = output / "tests.xcresult"
    command = ["xcodebuild", "build-for-testing" if args.build_only else "test",
               "-workspace" if suite["container"].endswith(".xcworkspace") else "-project",
               str(root / "iOS" / suite["container"]), "-scheme", suite["scheme"],
               "-destination", "platform=iOS Simulator,id=" + device["udid"] + (",arch=" + arch if arch else ""),
               "-derivedDataPath", str(derived), "-parallel-testing-enabled", "NO",
               "-resultBundlePath", str(result), "CODE_SIGNING_ALLOWED=NO"]
    command += ["-only-testing:" + ident for ident in selected]
    if arch:
        command += ["ONLY_ACTIVE_ARCH=YES", "ARCHS=" + arch, "EXCLUDED_ARCHS=" + ("arm64" if arch == "x86_64" else "x86_64")]
    evidence.update(command=shlex.join(command), artifacts="incremental-build", log_path=str(log), xcresult_path=str(result))
    with build_lock(derived):
        run_logged(command, root / "iOS", log)
        if args.build_only:
            evidence["status"] = "built-not-tested"
            return
        summary = json_command(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result)], root)
        (output / "xcresult-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        evidence["tests"] = xcresult_counts(summary)
        evidence["status"] = "passed"


def run_android(root, cfg, output, evidence):
    android = cfg["android"]
    command = ["./gradlew", "--console=plain"]
    for task in android["test_tasks"]:
        command += [task, "--rerun"]  # Gradle 8.9: rerun tests, retain incremental dependency builds.
    command += android["lint_tasks"]
    log = output / "gradle.log"
    evidence.update(command=shlex.join(command), log_path=str(log), flavor=android["flavor"])
    # Isolate invocations before clearing only generated test reports. Gradle otherwise
    # leaves old XML behind when a test source set becomes empty (NO-SOURCE).
    with build_lock(root / "Android/.gradle/workflow-validation"):
        for rel in android["test_reports"]:
            for path in (root / "Android" / rel).glob("TEST-*.xml"):
                path.unlink()
        try:
            run_logged(command, root / "Android", log)
            evidence["tests"] = junit_counts([root / "Android" / rel for rel in android["test_reports"]])
            evidence["status"] = "passed"
        finally:
            # Lint may fail after all tests passed. Keep their actual result while
            # preserving the failing overall exit status.
            if "tests" not in evidence:
                try:
                    evidence["tests"] = junit_counts([root / "Android" / rel for rel in android["test_reports"]])
                except (OSError, ValueError, ET.ParseError) as error:
                    evidence["test_error"] = str(error)
            reports = output / "junit"
            reports.mkdir()
            for number, rel in enumerate(android["test_reports"]):
                for path in (root / "Android" / rel).glob("TEST-*.xml"):
                    shutil.copy2(path, reports / (str(number) + "-" + path.name))
            evidence["junit_path"] = str(reports)


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    platforms = p.add_subparsers(dest="platform", required=True)
    android = platforms.add_parser("android", help="Run this brand's UT and lint")
    ios = platforms.add_parser("ios", help="Run a configured iOS test suite")
    ios.add_argument("--suite", default="ains", help="iOS suite from scripts/workflow.json")
    ios.add_argument("--list", action="store_true", help="List iOS suites without invoking Xcode")
    ios.add_argument("--preflight", action="store_true")
    ios.add_argument("--build-only", action="store_true", help="Compatibility build entrypoint; never reports UT passed")
    ios.add_argument("--container")
    ios.add_argument("--scheme")
    ios.add_argument("--only-testing", action="append")
    ios.add_argument("--destination", help="Simulator UUID (or IOS_SIMULATOR_UDID)")
    ios.add_argument("--derived-data")
    for platform in (android, ios):
        platform.add_argument("--results-dir", default=os.environ.get("WORKFLOW_RESULTS_DIR"))
    return p


def main(argv=None):
    args = parser().parse_args(argv)
    cfg = config()
    if getattr(args, "list", False):
        print("\n".join(cfg["ios"]["suites"]))
        return 0
    parent = Path(args.results_dir) if args.results_dir else Path(tempfile.gettempdir()) / "convoai-validation-results"
    parent.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix=args.platform + "-", dir=parent)).resolve()
    evidence = {"platform": args.platform, "status": "failed", "results_dir": str(output)}
    try:
        if args.platform == "ios":
            run_ios(args, ROOT, cfg, output, evidence)
        else:
            run_android(ROOT, cfg, output, evidence)
        return 0
    except (OSError, ValueError, KeyError, ET.ParseError, subprocess.CalledProcessError) as error:
        evidence["error"] = str(error)
        print(str(error), file=sys.stderr)
        return 1
    finally:
        (output / "validation.json").write_text(json.dumps(evidence, indent=2) + "\n")
        print(json.dumps(evidence, ensure_ascii=False, indent=2), flush=True)


if __name__ == "__main__":
    sys.exit(main())
