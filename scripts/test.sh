#!/usr/bin/env bash
# Each shard becomes a child span of "unit tests", because otel-cli exec
# passes its own trace context (TRACEPARENT) to the commands it runs.
set -euo pipefail
cd "$(dirname "$0")"

otel-cli exec --name "test: api" --attrs cicd.pipeline.task.type=test -- bash ./fake-work.sh 5 10
otel-cli exec --name "test: ui"  --attrs cicd.pipeline.task.type=test -- bash ./fake-work.sh 5 10 "${UI_FAIL_PCT:-20}"  # flaky: fails ~20% of runs
otel-cli exec --name "test: e2e" --attrs cicd.pipeline.task.type=test -- bash ./fake-work.sh 10 45     # slow and unpredictable
