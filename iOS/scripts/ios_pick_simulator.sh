#!/bin/bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runner="$script_dir/../../scripts/validate.py"
exec python3 - "$script_dir/../../scripts" <<'PYTHON'
import sys
sys.path.insert(0, sys.argv[1])
from validate import simulator
print(simulator()["udid"])
PYTHON
