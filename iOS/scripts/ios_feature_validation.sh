#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage:
  scripts/ios_feature_validation.sh --list
  scripts/ios_feature_validation.sh <feature> [workspace] [scheme] [derived_data_path] [simulator_uuid]

features:
  turn-finished        focused logic UT for turn.finished parsing
  latency-storage      focused logic UT for LatencyMetricsManager persistence
  chat-latency-ui      focused UT for chat latency message wiring
EOF
}

list_features() {
  cat <<'EOF'
turn-finished
latency-storage
chat-latency-ui
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

feature="$1"

if [[ "$feature" == "--list" || "$feature" == "list" ]]; then
  list_features
  exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace="${2:-Agent.xcworkspace}"
scheme="${3:-Agent-cn}"
derived_data="${4:-/tmp/AgentDerivedData-${scheme}-${feature}-x86}"
simulator_uuid="${5:-$("$script_dir/ios_pick_simulator.sh")}"

case "$feature" in
  turn-finished)
    echo "[feature-validation] feature: turn-finished"
    echo "[feature-validation] mode: focused-test-fast"
    "$script_dir/ios_focused_test_fast.sh" \
      "$workspace" \
      "$scheme" \
      "Agent-cnTests/ConversationalAIAPITurnFinishedTests" \
      "$derived_data" \
      "$simulator_uuid"
    ;;
  latency-storage)
    echo "[feature-validation] feature: latency-storage"
    echo "[feature-validation] mode: focused-test-fast"
    "$script_dir/ios_focused_test_fast.sh" \
      "$workspace" \
      "$scheme" \
      "Agent-cnTests/LatencyMetricsManagerTests" \
      "$derived_data" \
      "$simulator_uuid"
    ;;
  chat-latency-ui)
    echo "[feature-validation] feature: chat-latency-ui"
    echo "[feature-validation] mode: focused-test-fast"
    "$script_dir/ios_focused_test_fast.sh" \
      "$workspace" \
      "$scheme" \
      "Agent-cnTests/ChatMessageViewModelLatencyTests" \
      "$derived_data" \
      "$simulator_uuid"
    ;;
  *)
    echo "[feature-validation] unknown feature: $feature" >&2
    echo "[feature-validation] available features:" >&2
    list_features >&2
    exit 1
    ;;
esac
