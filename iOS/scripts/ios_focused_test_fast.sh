#!/bin/bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <workspace> <scheme> <only_testing> [derived_data_path] [simulator_uuid]" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace="$1"
scheme="$2"
only_testing="$3"
derived_data="${4:-/tmp/AgentDerivedData-${scheme}-x86}"
simulator_uuid="${5:-$("$script_dir/ios_pick_simulator.sh")}"
force_build="${FORCE_BUILD:-0}"

xctestrun_exists() {
  find "$derived_data/Build/Products" -maxdepth 1 -name '*.xctestrun' -print -quit 2>/dev/null | grep -q .
}

if [[ "$force_build" == "1" ]] || ! xctestrun_exists; then
  echo "[focused-test-fast] build artifacts missing or FORCE_BUILD=1, running build-for-testing"
  "$script_dir/ios_build_for_testing.sh" "$workspace" "$scheme" "$derived_data" "$simulator_uuid"
else
  echo "[focused-test-fast] reusing existing build artifacts from $derived_data"
fi

"$script_dir/ios_test_without_building.sh" "$workspace" "$scheme" "$only_testing" "$derived_data" "$simulator_uuid"
