#!/bin/bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runner="$script_dir/../../scripts/validate.py"
echo "[validation] Legacy entrypoint now checks current sources with an incremental build." >&2
exec bash "$script_dir/ios_focused_test_fast.sh" "$@"
