#!/bin/bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runner="$script_dir/../../scripts/validate.py"
if [[ $# -lt 3 || $# -gt 5 ]]; then
  echo "usage: $0 <container> <scheme> <only_testing> [derived_data] [simulator_uuid]" >&2
  exit 2
fi
args=(ios --container "$1" --scheme "$2" --only-testing "$3")
if [[ -n "${4:-}" ]]; then args+=(--derived-data "$4"); fi
if [[ -n "${5:-}" ]]; then args+=(--destination "$5"); fi
exec python3 "$runner" "${args[@]}"
