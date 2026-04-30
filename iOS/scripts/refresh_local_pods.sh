#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
skip_demo_resource_download="${SKIP_DEMO_RESOURCE_DOWNLOAD:-0}"

usage() {
  cat <<'EOF'
usage:
  scripts/refresh_local_pods.sh
  scripts/refresh_local_pods.sh --skip-demo-resource-download

notes:
  - default behavior matches plain `pod install --no-repo-update`
  - pass `--skip-demo-resource-download` or set `SKIP_DEMO_RESOURCE_DOWNLOAD=1`
    only when you explicitly want the faster local path
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-demo-resource-download)
      skip_demo_resource_download="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[refresh-local-pods][error] unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v pod >/dev/null 2>&1; then
  echo "[refresh-local-pods][error] CocoaPods is not installed or not on PATH." >&2
  exit 127
fi

echo "[refresh-local-pods] repo_root: $repo_root"
echo "[refresh-local-pods] SKIP_DEMO_RESOURCE_DOWNLOAD=$skip_demo_resource_download"
echo "[refresh-local-pods] running: pod install --no-repo-update"

(
  cd "$repo_root"
  export SKIP_DEMO_RESOURCE_DOWNLOAD="$skip_demo_resource_download"
  pod install --no-repo-update
)
