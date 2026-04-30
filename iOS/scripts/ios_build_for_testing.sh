#!/bin/bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <workspace> <scheme> [derived_data_path] [simulator_uuid]" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace="$1"
scheme="$2"
derived_data="${3:-/tmp/AgentDerivedData-${scheme}-x86}"
simulator_uuid="${4:-$("$script_dir/ios_pick_simulator.sh")}"
sim_arch="${SIM_ARCH:-x86_64}"
lock_dir="${derived_data}.lock"

destination="platform=iOS Simulator,id=${simulator_uuid},arch=${sim_arch}"

cleanup_lock() {
  rm -rf "$lock_dir"
}

if ! mkdir "$lock_dir" 2>/dev/null; then
  echo "[build-for-testing][error] derived data is already in use: $derived_data" >&2
  echo "[build-for-testing][error] if this is stale, remove: $lock_dir" >&2
  exit 73
fi

trap cleanup_lock EXIT INT TERM

echo "[build-for-testing] workspace: $workspace"
echo "[build-for-testing] scheme: $scheme"
echo "[build-for-testing] derived_data: $derived_data"
echo "[build-for-testing] destination: $destination"

args=(
  xcodebuild
  build-for-testing
  -workspace "$workspace"
  -scheme "$scheme"
  -destination "$destination"
  -derivedDataPath "$derived_data"
)

if [[ "$sim_arch" == "x86_64" ]]; then
  args+=(ONLY_ACTIVE_ARCH=YES ARCHS=x86_64 EXCLUDED_ARCHS=arm64)
fi

"${args[@]}"
