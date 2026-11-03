# trace-github-actions-demo

A small demo that turns a GitHub Actions workflow into an OpenTelemetry trace using [otel-cli](https://github.com/equinix-labs/otel-cli), then sends it to Grafana Cloud.

Each run becomes one trace. Each step becomes a span, and the test step contains child spans for each test shard. You get durations, nesting, and pass/fail status without computing anything from logs.

```
ci pipeline          [=========================================]
  install deps       [====]
  unit tests              [==================]
    test: api             [===]
    test: ui                  [===]
    test: e2e                     [==========]
  build image                                  [==============]
```

The work is simulated by `scripts/fake-work.sh`, so the demo runs anywhere. One test shard fails about 20% of the time, and another has a random duration, so you get interesting traces to look at.

## Quickstart

Fork the demo into your GitHub account, store your Grafana Cloud credentials as Actions secrets, and run the workflow.

1. **Log in and fork the repo.** The fork is your copy, so you can set secrets and run Actions without write access here.

   ```bash
   gh auth login
   gh repo fork grafana/trace-github-actions-demo --clone
   cd trace-github-actions-demo
   ```

   `gh auth login` opens a browser. Keep repository access when it asks for scopes. That access is what `gh` uses to set Actions secrets and start workflow runs.

   Set the default repository to your fork. `gh repo fork --clone` also keeps this repository as `upstream`, and `gh secret set` and `gh workflow run` follow the default. Point that at your fork, for example `https://github.com/myuser/trace-github-actions-demo`:

   ```bash
   gh repo set-default "$(git remote get-url origin)"
   ```

   Enable workflows on the fork. Open your fork on GitHub, select the **Actions** tab, and click **Enable workflows**. GitHub does not run workflows on a new fork until you do this, so `gh workflow run traced-ci.yml` will not start a run before then.

2. **Create a Grafana Cloud token.** In your Grafana Cloud stack, go to **Connections > Add new connection > OpenTelemetry (OTLP)**. Under **Choose your infrastructure**, select **Serverless** or **Other**. Create a token and give it a name you will recognize later, such as `trace-github-actions-demo`.

   Grafana then shows a generated configuration. Copy two values from it:

   - `OTEL_EXPORTER_OTLP_ENDPOINT`, a URL ending in `/otlp`, for example `https://otlp-gateway-prod-us-west-0.grafana.net/otlp`
   - `OTEL_EXPORTER_OTLP_HEADERS`, a Basic auth header, for example `Authorization=Basic MTI4NzY5MDpnbGNf...`

   That page does not list an instance ID. The header is already the base64 of `instanceID:token`. Keep the base64 part and drop the prefix.

3. **Add two repository secrets** on your fork. Run these from the clone so they land on your repository.

   | Secret | Value |
   | --- | --- |
   | `GC_OTLP_ENDPOINT` | The `OTEL_EXPORTER_OTLP_ENDPOINT` URL, with nothing after `/otlp` |
   | `GC_OTLP_AUTH` | Only the base64 string after `Authorization=Basic ` |

   Grafana sometimes writes the prefix as `Authorization=Basic%20`. Strip that the same way. Paste `MTI4NzY5MDpnbGNf...` for `GC_OTLP_AUTH`. The workflow adds `Authorization=Basic ` when it sends the header, so leave that prefix off the secret.

   ```bash
   gh secret set GC_OTLP_ENDPOINT
   gh secret set GC_OTLP_AUTH
   gh secret list
   ```

   `gh secret set` prompts for each value. `gh secret list` should show both names. Values stay hidden.

4. **Run the workflow.**

   ```bash
   gh workflow run traced-ci.yml
   gh run watch
   ```

5. **Find the trace.** The "Start the trace" step prints the trace ID. In Grafana Cloud, open **Explore**, pick your traces data source, and paste the ID. Or search with TraceQL:

   ```traceql
   { span:name = "ci pipeline" }
   ```

Want a failure on demand for a demo or screenshot? This makes the `test: ui` shard fail every time:

```bash
gh workflow run traced-ci.yml -f force_failure=true
```

No secrets set? The workflow still passes. otel-cli runs in non-recording mode when no endpoint is configured.

## Rehearse locally

You can see spans without a Grafana Cloud account:

```bash
go install github.com/equinix-labs/otel-cli@v0.4.5

# Terminal 1: a local OTLP server that prints spans
otel-cli server tui

# Terminal 2
export OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4317
otel-cli exec --name "unit tests" -- bash ./scripts/test.sh
```

## Useful TraceQL queries

```traceql
# Failed runs
{ span:name = "ci pipeline" && span:status = error }

# Slow work anywhere under the test step
{ span:name = "unit tests" } >> { span:duration > 30s }

# p95 duration per test shard over time (TraceQL metrics)
{ span.cicd.pipeline.task.type = "test" } | quantile_over_time(span:duration, .95) by (span:name)
```

## How it works

- **Start the trace** generates a trace ID and root span ID, records the start time, and writes a `TRACEPARENT` to `$GITHUB_ENV` so later steps can use it.
- **Each wrapped step** runs under `otel-cli exec`, which reads `TRACEPARENT` and creates a child span. A non-zero exit marks the span as an error.
- **Finish the trace** runs even after failures and creates the root span from the recorded start time. `--tp-ignore-env` keeps the root span from becoming its own parent.
- Span attributes follow the OpenTelemetry [CI/CD semantic conventions](https://opentelemetry.io/docs/specs/semconv/registry/attributes/cicd/), such as `cicd.pipeline.name` and `cicd.pipeline.task.type`.

## Notes

- otel-cli is labeled experimental, and this demo pins v0.4.5. Its docs recommend sending through a local collector (such as Grafana Alloy) for production use rather than straight to a backend.
- For org-wide coverage without editing workflows, look at the OpenTelemetry Collector's GitHub receiver, which builds spans from workflow webhooks.
- To use your own app, replace the `fake-work.sh` calls with real commands like `npm ci`, `npm test`, or `docker build`.

## Related reading

From grep to waterfall (blog post link coming soon)
