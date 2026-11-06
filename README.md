# trace-github-actions-demo

**Turn every GitHub Actions run into an OpenTelemetry trace in Grafana Cloud.** Each step becomes a span, and test shards show up as child spans. You get durations, nesting, and pass/fail without digging through logs.

```
ci pipeline          [=========================================]
  install deps       [====]
  unit tests              [==================]
    test: api             [===]
    test: ui                  [===]
    test: e2e                     [==========]
  build image                                  [==============]
```

## Quickstart (about 5 minutes)

**1. Fork and clone**

```bash
gh auth login
gh repo fork grafana/trace-github-actions-demo --clone
cd trace-github-actions-demo
gh repo set-default "$(git remote get-url origin)"
```

**2. Enable Actions on your fork**

> [!IMPORTANT]
> GitHub turns off workflows on new forks. Until you enable them, `gh workflow run` won't start anything.

```bash
gh workflow enable traced-ci.yml
```

If that doesn't work, open your fork on GitHub, go to the **Actions** tab, and click **I understand my workflows, go ahead and enable them**.

**3. Get Grafana Cloud credentials**

In Grafana Cloud, go to **Connections → Add new connection → OpenTelemetry (OTLP) → Serverless/Other** and create a token. Copy these two values:

| Secret | Value |
|---|---|
| `GC_OTLP_ENDPOINT` | `OTEL_EXPORTER_OTLP_ENDPOINT`, the URL ending in `/otlp` |
| `GC_OTLP_AUTH` | The base64 string **after** `Authorization=Basic ` (or `Basic%20`) |

```bash
gh secret set GC_OTLP_ENDPOINT
gh secret set GC_OTLP_AUTH
```

**4. Run it**

```bash
gh workflow run traced-ci.yml
gh run watch
```

**5. See the trace**

In Grafana, go to **Explore** and pick your traces data source. Then either paste the trace ID from the "Start the trace" step, or run:

```
{ span:name = "ci pipeline" }
```

## Good to know

- **Force a failure:** `gh workflow run traced-ci.yml -f force_failure=true`
- **No secrets?** The workflow still passes. It just doesn't send spans.
- **The work is fake.** `scripts/fake-work.sh` simulates it. One shard fails about 20% of the time. Swap in `npm ci`, `npm test`, and so on to trace real work.

## Try it locally (no Grafana account needed)

```bash
go install github.com/equinix-labs/otel-cli@v0.4.5
otel-cli server tui                      # terminal 1
export OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4317
otel-cli exec --name "unit tests" -- bash ./scripts/test.sh   # terminal 2
```

## Handy TraceQL queries

```
# Failed runs
{ span:name = "ci pipeline" && span:status = error }

# Slow test work
{ span:name = "unit tests" } >> { span:duration > 30s }

# p95 per test shard over time
{ span.cicd.pipeline.task.type = "test" } | quantile_over_time(span:duration, .95) by (span:name)
```

<details>
<summary><b>How it works</b></summary>

1. **Start the trace** creates a trace ID and records the start time. It then writes `TRACEPARENT` to `$GITHUB_ENV`.
2. **Each step** runs under `otel-cli exec`, which creates a child span. A non-zero exit marks the span as an error.
3. **Finish the trace** always runs, even after failures. It creates the root span from the recorded start time, and `--tp-ignore-env` stops the root span from becoming its own parent.

Attributes follow the [OpenTelemetry CI/CD semantic conventions](https://opentelemetry.io/docs/specs/semconv/cicd/).

</details>

<details>
<summary><b>Caveats</b></summary>

- [otel-cli](https://github.com/equinix-labs/otel-cli) is experimental (this demo pins v0.4.5). For production, send spans through a local collector such as Grafana Alloy, not straight to a backend.
- To cover a whole org without editing workflows, use the OpenTelemetry Collector's GitHub receiver.

</details>

## Related reading

- From grep to waterfall *(blog post coming soon)*
