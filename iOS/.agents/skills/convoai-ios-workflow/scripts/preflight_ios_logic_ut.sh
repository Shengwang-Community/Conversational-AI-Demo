#!/bin/zsh
set -euo pipefail

WORKSPACE_PATH="${1:-Agent.xcworkspace}"
PROJECT_PATH="${2:-Agent.xcodeproj}"
SCHEME_NAME="${3:-Agent-cn}"
SCHEME_FILE="${4:-Agent.xcodeproj/xcshareddata/xcschemes/Agent-cn.xcscheme}"

echo "[preflight] workspace: ${WORKSPACE_PATH}"
echo "[preflight] project: ${PROJECT_PATH}"
echo "[preflight] scheme: ${SCHEME_NAME}"

xcodebuild -list -workspace "${WORKSPACE_PATH}"

echo "[preflight] checking project targets"
xcodebuild -list -project "${PROJECT_PATH}" | sed -n '/Targets:/,/Build Configurations:/p'

if [[ -f "${SCHEME_FILE}" ]]; then
  echo "[preflight] checking shared scheme wiring: ${SCHEME_FILE}"
  if ! rg -q "<Testables>" "${SCHEME_FILE}"; then
    echo "[preflight][error] shared scheme is missing <Testables>: ${SCHEME_FILE}" >&2
    exit 2
  fi
  if ! rg -q "<MacroExpansion>" "${SCHEME_FILE}"; then
    echo "[preflight][error] shared scheme is missing <MacroExpansion>: ${SCHEME_FILE}" >&2
    exit 2
  fi
else
  echo "[preflight][warn] shared scheme file not found: ${SCHEME_FILE}" >&2
fi

echo "[preflight] available simulators"
xcrun simctl list devices available
