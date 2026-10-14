#!/usr/bin/env python3
"""Run the Foundation-only manual turn XCTest suite on the native Swift host."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

SOURCES = [
    Path("iOS/Scenes/ConvoAI/ConvoAI/ConvoAI/Classes/Main/Chat/PushToTalkController.swift"),
]
TEST = Path("iOS/AgentTests/PushToTalkControllerTests.swift")
PACKAGE_PREFIX = "manual-eos-swift-"


def prepare_package(repo: Path, package: Path) -> None:
    source_dir = package / "Sources/ManualEos"
    test_dir = package / "Tests/ManualEosTests"
    source_dir.mkdir(parents=True)
    test_dir.mkdir(parents=True)
    for source in SOURCES:
        shutil.copy2(repo / source, source_dir)
    shutil.copy2(repo / TEST, test_dir)
    (package / "Package.swift").write_text(
        '// swift-tools-version: 5.9\n'
        'import PackageDescription\n'
        'let package = Package(name: "ManualEos", targets: ['
        '.target(name: "ManualEos"), '
        '.testTarget(name: "ManualEosTests", dependencies: ["ManualEos"])])\n'
    )


def run_tests(repo: Path, package: Path) -> int:
    prepare_package(repo, package)
    command = [
        "swift", "test", "--disable-sandbox", "--package-path", str(package),
        "--scratch-path", str(package / ".build"),
        "--cache-path", str(package / "cache"),
        "--config-path", str(package / "config"),
        "-Xswiftc", "-module-cache-path", "-Xswiftc", str(package / "module-cache"),
    ]
    # SwiftPM leaves lock files and TemporaryDirectory.* in TMPDIR; keep them inside the package.
    temporary = package / "tmp"
    temporary.mkdir(exist_ok=True)
    result = subprocess.run(
        command, text=True, capture_output=True,
        env=dict(os.environ, CLANG_MODULE_CACHE_PATH=str(package / "clang-cache"), TMPDIR=str(temporary)),
    )
    output = result.stdout + result.stderr
    print(output, flush=True)
    if result.returncode:
        return result.returncode
    if not re.search(r"Executed [1-9][0-9]* tests, with 0 failures", output):
        print("No successful XCTest execution was found.")
        return 1
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep", action="store_true", help="keep the temporary Swift package and print its path")
    args = parser.parse_args(argv)
    repo = Path(__file__).resolve().parents[1]
    if args.keep:
        package = Path(tempfile.mkdtemp(prefix=PACKAGE_PREFIX))
        print(f"Keeping the native Swift test package: {package}", flush=True)
        return run_tests(repo, package)
    # The package and its build output are removed on success, failure and exceptions.
    with tempfile.TemporaryDirectory(prefix=PACKAGE_PREFIX) as temporary:
        return run_tests(repo, Path(temporary))


if __name__ == "__main__":
    raise SystemExit(main())
