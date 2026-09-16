#!/bin/bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runner="$script_dir/../../scripts/validate.py"
if [[ $# -eq 0 ]]; then
  exec python3 "$runner" ios --preflight
fi
if [[ $# -ne 4 ]]; then
  echo "usage: $0 [<container> <project> <scheme> <shared_scheme_file>]" >&2
  exit 2
fi
if [[ ! -d "$2" || ! -f "$4" ]]; then
  echo "[preflight] Project or shared scheme file is missing" >&2
  exit 2
fi
exec python3 "$runner" ios --preflight --container "$1" --scheme "$3"
