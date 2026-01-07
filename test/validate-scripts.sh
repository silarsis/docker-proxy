#!/usr/bin/env bash

set -euo pipefail

scripts=(
  "run.sh"
  "start_squid.sh"
  "test/install-tools.sh"
  "test/detect-proxy.sh"
  "test/test-proxy.sh"
)

for script in "${scripts[@]}"; do
  if [[ ! -f "$script" ]]; then
    echo "Missing script: $script" >&2
    exit 1
  fi
  bash -n "$script"
  echo "Validated bash syntax: $script"
done
