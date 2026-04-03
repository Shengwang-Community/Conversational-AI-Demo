#!/bin/bash
set -euo pipefail

extract_uuid() {
  sed -n 's/.*(\([A-F0-9-]\{36\}\)).*/\1/p'
}

simulator_list="$(xcrun simctl list devices available)"

booted_uuid="$(
  printf '%s\n' "$simulator_list" \
    | grep 'Booted' \
    | grep 'iPhone' \
    | extract_uuid \
    | head -n1 || true
)"

if [[ -n "$booted_uuid" ]]; then
  printf '%s\n' "$booted_uuid"
  exit 0
fi

available_uuid="$(
  printf '%s\n' "$simulator_list" \
    | grep 'iPhone' \
    | extract_uuid \
    | head -n1 || true
)"

if [[ -z "$available_uuid" ]]; then
  echo "[pick-simulator] no available iPhone simulator found" >&2
  exit 1
fi

printf '%s\n' "$available_uuid"
