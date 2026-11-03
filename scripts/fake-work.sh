#!/usr/bin/env bash
# Simulates a unit of work so the demo produces interesting traces.
# Usage: fake-work.sh <min_seconds> <max_seconds> [fail_percent]
set -euo pipefail

min=${1:?min seconds required}
max=${2:?max seconds required}
fail_pct=${3:-0}

secs=$(( min + RANDOM % (max - min + 1) ))
echo "Working for ${secs}s..."
sleep "$secs"

if (( RANDOM % 100 < fail_pct )); then
  echo "Simulated failure (${fail_pct}% chance)" >&2
  exit 1
fi

echo "Done."
