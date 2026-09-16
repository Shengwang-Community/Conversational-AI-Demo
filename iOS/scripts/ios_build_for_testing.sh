#!/bin/bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runner="$script_dir/../../scripts/validate.py"
if [[ $# -lt 2 || $# -gt 4 ]]; then
  echo "usage: $0 <container> <scheme> [derived_data] [simulator_uuid]" >&2
  exit 2
fi
args=(ios --build-only --container "$1" --scheme "$2")
if [[ -n "${3:-}" ]]; then args+=(--derived-data "$3"); fi
if [[ -n "${4:-}" ]]; then args+=(--destination "$4"); fi
exec python3 "$runner" "${args[@]}"
