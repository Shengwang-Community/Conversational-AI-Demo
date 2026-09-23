#!/bin/bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runner="$script_dir/../../scripts/validate.py"
if [[ $# -lt 4 || $# -gt 5 ]]; then
  echo "usage: $0 <container> <scheme> <simulator_uuid> <only_testing> [derived_data]" >&2
  exit 2
fi
args=(ios --container "$1" --scheme "$2" --destination "$3" --only-testing "$4")
if [[ -n "${5:-}" ]]; then args+=(--derived-data "$5"); fi
exec python3 "$runner" "${args[@]}"
