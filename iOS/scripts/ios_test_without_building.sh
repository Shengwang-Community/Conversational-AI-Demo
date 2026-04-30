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
sim_arch="${SIM_ARCH:-x86_64}"
lock_dir="${derived_data}.lock"

destination="platform=iOS Simulator,id=${simulator_uuid},arch=${sim_arch}"
xctestrun_path="$(
  find "$derived_data/Build/Products" -maxdepth 1 -name '*.xctestrun' -print \
    | sort \
    | head -n1
)"

cleanup_lock() {
  rm -rf "$lock_dir"
}

if ! mkdir "$lock_dir" 2>/dev/null; then
  echo "[test-without-building][error] derived data is already in use: $derived_data" >&2
  echo "[test-without-building][error] if this is stale, remove: $lock_dir" >&2
  exit 73
fi

trap cleanup_lock EXIT INT TERM

if [[ -z "$xctestrun_path" ]]; then
  echo "[test-without-building] no .xctestrun found under $derived_data/Build/Products" >&2
  echo "[test-without-building] run build-for-testing first" >&2
  exit 1
fi

echo "[test-without-building] workspace: $workspace"
echo "[test-without-building] scheme: $scheme"
echo "[test-without-building] only_testing: $only_testing"
echo "[test-without-building] derived_data: $derived_data"
echo "[test-without-building] destination: $destination"
echo "[test-without-building] xctestrun: $xctestrun_path"

args=(
  xcodebuild
  test-without-building
  -xctestrun "$xctestrun_path"
  -destination "$destination"
  "-only-testing:${only_testing}"
)

"${args[@]}"
