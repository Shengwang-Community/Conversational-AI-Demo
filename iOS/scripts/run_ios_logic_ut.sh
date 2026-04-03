#!/bin/zsh
set -euo pipefail

WORKSPACE_PATH="${1:-Agent.xcworkspace}"
SCHEME_NAME="${2:-Agent-cn}"
DESTINATION_ID="${3:-}"
ONLY_TESTING_ID="${4:-}"
DERIVED_DATA_PATH="${5:-/tmp/AgentDerivedData}"

if [[ -z "${DESTINATION_ID}" ]]; then
  echo "[run-ut][error] destination UUID is required" >&2
  exit 2
fi

if [[ -z "${ONLY_TESTING_ID}" ]]; then
  echo "[run-ut][error] only-testing identifier is required" >&2
  exit 2
fi

echo "[run-ut] ensuring simulator is booted: ${DESTINATION_ID}"
xcrun simctl boot "${DESTINATION_ID}" 2>/dev/null || true

echo "[run-ut] workspace=${WORKSPACE_PATH} scheme=${SCHEME_NAME} only-testing=${ONLY_TESTING_ID}"
xcodebuild test \
  -workspace "${WORKSPACE_PATH}" \
  -scheme "${SCHEME_NAME}" \
  -destination "id=${DESTINATION_ID}" \
  -only-testing:"${ONLY_TESTING_ID}" \
  -derivedDataPath "${DERIVED_DATA_PATH}"
