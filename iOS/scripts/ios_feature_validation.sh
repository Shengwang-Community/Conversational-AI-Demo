#!/bin/bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runner="$script_dir/../../scripts/validate.py"
if [[ $# -gt 1 ]]; then
  echo "Use scripts/validate.py ios --suite <feature> for additional options" >&2
  exit 2
fi
if [[ "${1:-}" == "--list" || "${1:-}" == "list" ]]; then
  exec python3 "$runner" ios --list
fi
exec python3 "$runner" ios --suite "${1:-ains}"
